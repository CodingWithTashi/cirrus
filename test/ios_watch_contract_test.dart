@Tags(['swift'])
library;

import 'dart:convert';
import 'dart:io';

import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/features/panic/breath_pacer.dart';
import 'package:last_puff/data/seed/seed_data.dart';
import 'package:last_puff/data/stores/pending_puffs.dart';
import 'package:last_puff/data/stores/widget_mirror.dart';
import 'package:last_puff/core/utils/lp_format.dart';
import 'package:last_puff/domain/logic/day_window.dart';
import 'package:last_puff/domain/logic/journey_factory.dart';
import 'package:last_puff/domain/logic/week_trend.dart';
import 'package:last_puff/domain/models/journey_state.dart';

/// The whole phone↔watch loop, executed.
///
/// This is the reason `WatchWire.swift` imports no WatchConnectivity: every
/// decision the feature can get wrong is a pure function over two
/// `UserDefaults` containers, so one process can play both devices and the
/// entire round trip is provable from `flutter test` — no simulator, no radio,
/// no pairing. What is left in `WatchLink`/`CirrusWatchLink` is only activation
/// and delivery, which nothing but a real device can exercise anyway.
///
/// The loop, end to end:
///
///   Dart `buildMirror` → phone container → `WatchWire.contextPayload`
///     → `WatchWire.applyContext` → watch container → `CirrusMirror.read`
///     → `CirrusOutbox.append` × 4 → `WatchWire.tapPayload`
///     → `WatchWire.relay` → phone `lp.outbox` → Dart `PendingPuffs.decode`
///
/// Skipped anywhere without `xcrun swiftc` — CI is Linux and the other dev
/// machine is Windows — so it is a macOS gate, not a CI one.
void main() {
  final sdk = Platform.isMacOS
      ? Process.runSync('xcrun', [
          '--show-sdk-path',
          '--sdk',
          'macosx',
        ]).stdout.toString().trim()
      : '';
  final skip = sdk.isEmpty ? 'needs macOS with Xcode (swiftc)' : false;

  // The harness. Top-level code, so no `@main` and no `-parse-as-library`.
  //
  // Two suites, wiped before and after. On a Mac `UserDefaults(suiteName:)`
  // writes a real file under ~/Library/Preferences, so BOTH are suffixed away
  // from the production name — `ios_widget_contract_test.dart` drives that one,
  // `flutter test` runs suites in parallel, and sharing it made the two
  // harnesses clobber each other's plist. It failed about one run in three and
  // read exactly like flake.
  //
  // On a real pair these are the same group name on two devices; here they are
  // two names in one process, which is the only difference the wire cannot see.
  const harness = r'''
import Foundation

let spec = try! JSONSerialization.jsonObject(
    with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
) as! [String: Any]

let phoneName = CirrusKeys.appGroup + ".phonetest"
let watchName = CirrusKeys.appGroup + ".watchtest"
let phone = UserDefaults(suiteName: phoneName)!
let watch = UserDefaults(suiteName: watchName)!

func wipe() {
    phone.removePersistentDomain(forName: phoneName)
    watch.removePersistentDomain(forName: watchName)
}
wipe()

func snapshot(_ t: CirrusToday, _ m: CirrusMirror) -> [String: Any] {
    [
        "count": t.count, "limit": t.limit, "left": t.left, "over": t.over,
        "knowsLimit": t.knowsLimit, "dayNumber": t.dayNumber,
        "status": t.statusLine(m), "day": t.dayLabel(m),
    ]
}
func today(_ suite: UserDefaults) -> [String: Any] {
    let m = CirrusMirror.read(suite)
    return snapshot(cirrusToday(m, pending: CirrusOutbox.pendingToday(suite)), m)
}
func queued(_ suite: UserDefaults) -> Int {
    CirrusOutbox.queued(above: CirrusOutbox.drained(in: suite), in: suite).count
}
func reIdentified(_ payload: [String: Any], _ tag: String) -> [String: Any] {
    // Fresh ids, so what refuses the batch below is the reason under test and
    // never the id dedupe.
    var out = payload
    if var events = out[WatchKeys.fieldEvents] as? [[String: Any]] {
        for i in events.indices { events[i]["i"] = "\(tag)-\(i)" }
        out[WatchKeys.fieldEvents] = events
    }
    return out
}

// 1. The phone writes the mirror, exactly as `WidgetCoordinator.push` does.
phone.set(spec["mirror"] as! String, forKey: CirrusKeys.mirror)

// 2. It pushes a context; the wrist adopts it.
let context = WatchWire.contextPayload(from: phone) ?? [:]
let forgotFirst = WatchWire.applyContext(context, into: watch)
let watchBefore = today(watch)

// 3. Four taps on the wrist: + + + −.
let taps: [Int?] = [
    CirrusOutbox.append(delta: 1, in: watch),
    CirrusOutbox.append(delta: 1, in: watch),
    CirrusOutbox.append(delta: 1, in: watch),
    CirrusOutbox.append(delta: -1, in: watch),
]
let watchAfter = today(watch)
let watchPendingAtTap = CirrusOutbox.pendingToday(watch)

// 4. It hands the queue over.
let payload = WatchWire.tapPayload(from: watch)
let through = payload.flatMap { WatchWire.through($0) }

// 5. The phone relays it — then relays the SAME batch again, which must land
//    nothing: `transferUserInfo` is delivered once, but a re-send after an
//    unacknowledged failure would otherwise double every puff.
let landedFirst = payload.map { WatchWire.relay($0, into: phone) } ?? 0
let landedRepeat = payload.map { WatchWire.relay($0, into: phone) } ?? 0

// 6. A batch minted on somebody else's wrist, and one from an envelope version
//    this build does not know. Both refused, neither costing a puff.
var foreign = reIdentified(payload ?? [:], "foreign")
foreign[WatchKeys.fieldSid] = "someone-else"
let landedForeign = payload == nil ? -1 : WatchWire.relay(foreign, into: phone)

var future = reIdentified(payload ?? [:], "future")
future[WatchKeys.fieldVersion] = WatchKeys.version + 98
let landedFuture = payload == nil ? -1 : WatchWire.relay(future, into: phone)

// 7. A garbled context must leave a good mirror alone — nil, not a wipe.
let garbled = WatchWire.applyContext(["v": 99, "m": "{}"], into: watch)
let survivedGarbled = CirrusMirror.read(watch).hasJourney

// 8. Acknowledged — which records the hand-over and takes a mark, but does NOT
//    move the cursor: the phone has the taps and has not yet folded them into
//    the journey, so the wrist must keep counting them.
if let through { WatchWire.markHandedOver(through: through, in: watch) }
let watchSent = watch.integer(forKey: WatchKeys.sent)
let watchAfterAck = today(watch)
let watchPendingAfterAck = CirrusOutbox.pendingToday(watch)
let nothingLeftToSend = WatchWire.tapPayload(from: watch) == nil
// The safety net, probed in the only state where it means anything: `sent`
// covers every tap, so a normal flush must stay quiet — but the mirror has
// never confirmed them, so a RETRYING flush must offer them again. Without it a
// `didFinish` that lied strands them on the wrist for ever.
let retryOffers = WatchWire.through(WatchWire.tapPayload(from: watch, retrying: true) ?? [:])

// 9. The phone drains and pushes a mirror that finally includes them. THAT is
//    what moves the cursor.
var afterDrain: [String: Any] = [:]
var cursorAfterDrain = -1
var pendingAfterDrain = -1
if let drained = spec["drained"] as? String {
    // Cursor first, mirror second — the order `WidgetCoordinator` writes them
    // in, and what lets the mirror name the seq it reflects.
    phone.set("\(phone.integer(forKey: CirrusKeys.seq))", forKey: CirrusKeys.cursor)
    phone.set(drained, forKey: CirrusKeys.mirror)
    WatchWire.applyContext(WatchWire.contextPayload(from: phone) ?? [:], into: watch)
    afterDrain = today(watch)
    cursorAfterDrain = CirrusOutbox.drained(in: watch)
    pendingAfterDrain = CirrusOutbox.pendingToday(watch)
}

// 10. Four more taps, so there is a queue on the wrist when the next push lands.
for delta in [1, 1, 1, -1] { CirrusOutbox.append(delta: delta, in: watch) }
let watchQueuedBeforeSecond = queued(watch)

// 10. The second push: sign-out, a different account, or the same one again.
var forgotSecond: Bool? = nil
var watchAfterSecond: [String: Any] = [:]
var watchQueuedAfterSecond = -1
var tapAfterSecond: Int? = nil
var sidAfterSecond = ""
var emptyCopyAfterSecond: [String: String] = [:]
if let next = spec["next"] as? String {
    phone.set(next, forKey: CirrusKeys.mirror)
    forgotSecond = WatchWire.applyContext(
        WatchWire.contextPayload(from: phone) ?? [:], into: watch
    )
    watchAfterSecond = today(watch)
    watchQueuedAfterSecond = queued(watch)
    tapAfterSecond = CirrusOutbox.append(delta: 1, in: watch)
    sidAfterSecond = watch.string(forKey: WatchKeys.sid) ?? ""
    let m = CirrusMirror.read(watch)
    emptyCopyAfterSecond = [
        "hasJourney": m.hasJourney ? "1" : "0",
        "emptyTitle": m.copyEmptyTitle,
        "watchOpenPhone": m.copyWatchOpenPhone,
    ]
}

// 11. A `−` on a wrist at zero, in its own clean container.
let zeroName = CirrusKeys.appGroup + ".zerotest"
let zero = UserDefaults(suiteName: zeroName)!
zero.removePersistentDomain(forName: zeroName)
WatchWire.applyContext(
    [WatchKeys.fieldVersion: WatchKeys.version, WatchKeys.fieldMirror: spec["zero"] as? String ?? ""],
    into: zero
)
let minusAtZero: Int? = CirrusOutbox.append(delta: -1, in: zero)
let plusThenMinus: [Int?] = [
    CirrusOutbox.append(delta: 1, in: zero),
    CirrusOutbox.append(delta: -1, in: zero),
    CirrusOutbox.append(delta: -1, in: zero),
]
let zeroToday = today(zero)
zero.removePersistentDomain(forName: zeroName)

// 12. Real-time draining (docs/10 §36). The phone folds a relayed tap in
//     within the second now, so two hand-overs can bracket one mirror, and a
//     mirror can beat the receipt it belongs with. Across all of it the wrist's
//     count must neither drop nor double. Own containers, so the linear story
//     above is untouched.
var rt: [String: Any] = [:]
if CirrusMirror.decode(spec["mirror"] as! String).hasJourney {
    let rtPhoneName = CirrusKeys.appGroup + ".rtphonetest"
    let rtWatchName = CirrusKeys.appGroup + ".rtwatchtest"
    let rtPhone = UserDefaults(suiteName: rtPhoneName)!
    let rtWatch = UserDefaults(suiteName: rtWatchName)!
    rtPhone.removePersistentDomain(forName: rtPhoneName)
    rtWatch.removePersistentDomain(forName: rtWatchName)
    func count() -> Int { today(rtWatch)["count"] as! Int }
    func cursor() -> Int { CirrusOutbox.drained(in: rtWatch) }
    // What Dart does at the end of a drain: cursor first, mirror second.
    func push(_ key: String, drainedThrough: Int? = nil) -> Any {
        if let drainedThrough { rtPhone.set("\(drainedThrough)", forKey: CirrusKeys.cursor) }
        rtPhone.set(spec[key] as! String, forKey: CirrusKeys.mirror)
        let ctx = WatchWire.contextPayload(from: rtPhone) ?? [:]
        WatchWire.applyContext(ctx, into: rtWatch)
        return (ctx[WatchKeys.fieldReflected] as? Int).map { NSNumber(value: $0) } ?? NSNull()
    }
    // A flush answered over the reachable route: relay, then the receipt.
    func handOver() {
        guard let p = WatchWire.tapPayload(from: rtWatch) else { return }
        WatchWire.relay(p, into: rtPhone)
        if let t = WatchWire.through(p) { WatchWire.markHandedOver(through: t, in: rtWatch) }
    }

    rt["initialR"] = push("mirror")                        // nothing relayed yet
    let base = count()
    _ = CirrusOutbox.append(delta: 1, in: rtWatch)         // wrist seq 1
    handOver()                                             // phone seq 1
    _ = CirrusOutbox.append(delta: 1, in: rtWatch)         // wrist seq 2, while 1 is still draining
    handOver()                                             // phone seq 2
    rt["bothPending"] = count() - base
    // The phone drains the FIRST alone and pushes: only seq 1 may retire.
    rt["r1"] = push("plusOne", drainedThrough: 1)
    rt["afterFirst"] = [count() - base, cursor()]
    rt["r2"] = push("plusTwo", drainedThrough: 2)
    rt["afterSecond"] = [count() - base, cursor(), CirrusOutbox.pendingToday(rtWatch)]

    // A mirror that beats its own receipt: tap 3 is relayed and drained, and
    // the pushed mirror lands on the wrist BEFORE the reply does.
    _ = CirrusOutbox.append(delta: 1, in: rtWatch)         // wrist seq 3
    let p3 = WatchWire.tapPayload(from: rtWatch)!
    WatchWire.relay(p3, into: rtPhone)                     // phone seq 3
    rt["r3"] = push("plusThree", drainedThrough: 3)
    rt["beforeReceipt"] = [count() - base, cursor()]
    WatchWire.markHandedOver(through: WatchWire.through(p3)!, in: rtWatch)
    rt["sameAgainR"] = push("plusThree")                   // the same mirror, re-pushed
    rt["afterReceipt"] = [count() - base, cursor(), CirrusOutbox.pendingToday(rtWatch)]

    // A `−` the phone refuses (it has nothing left to take off) is consumed and
    // retired on the next mirror rather than counted on the wrist for ever.
    rtPhone.set(spec["zeroA"] as! String, forKey: CirrusKeys.mirror)    // a phone at zero…
    _ = CirrusOutbox.append(delta: -1, in: rtWatch)        // …while the wrist still shows a count: seq 4
    let p4 = WatchWire.tapPayload(from: rtWatch)!
    rt["refusedLanded"] = WatchWire.relay(p4, into: rtPhone)
    WatchWire.markHandedOver(through: WatchWire.through(p4)!, in: rtWatch)
    rt["refusedR"] = push("plusThree")                     // nothing new drained (cursor still 3)
    rt["afterRefused"] = [count() - base, cursor(), CirrusOutbox.pendingToday(rtWatch)]

    // The wrist's seq space restarts (the watch app reinstalled, same account):
    // the phone's ledger of its old seqs must not retire its new ones.
    rtWatch.removePersistentDomain(forName: rtWatchName)
    rt["reinstallR"] = push("plusThree")                   // r = 4 arrives on a wrist at seq 0
    rt["reinstallCursor"] = cursor()                       // must stay 0
    _ = CirrusOutbox.append(delta: 1, in: rtWatch)         // wrist seq 1 again, a new id
    handOver()                                             // phone seq 4; the ledger restarts
    rt["restartR"] = push("plusFour", drainedThrough: 4)   // 1, not 4
    rt["restartCursor"] = cursor()

    // A phone from before the field existed still moves the cursor the old
    // way, off the mark.
    _ = CirrusOutbox.append(delta: 1, in: rtWatch)         // wrist seq 2
    handOver()                                             // marks against plusFour
    WatchWire.applyContext(
        [WatchKeys.fieldVersion: WatchKeys.version, WatchKeys.fieldMirror: spec["plusFive"] as! String],
        into: rtWatch
    )
    rt["legacyCursor"] = cursor()                          // 2 = sent

    // Another account on the phone: the ledger is theirs, not the last person's.
    rt["otherR"] = push("other")                           // no r: the ledger is uid-a's
    rt["otherForgot"] = cursor()                           // the wrist forgot: 0
    _ = CirrusOutbox.append(delta: 1, in: rtWatch)         // uid-b's first wrist tap, seq 1
    handOver()
    rt["otherAfterR"] = push("otherPlusOne", drainedThrough: rtPhone.integer(forKey: CirrusKeys.seq))
    rt["otherCursor"] = cursor()

    rtPhone.removePersistentDomain(forName: rtPhoneName)
    rtWatch.removePersistentDomain(forName: rtWatchName)
}

let report: [String: Any] = [
    "forgotFirst": forgotFirst.map { NSNumber(value: $0) } ?? NSNull(),
    "watchSid": watch.string(forKey: WatchKeys.sid) ?? "",
    "watchBefore": watchBefore,
    "taps": taps.map { $0.map { NSNumber(value: $0) } ?? NSNull() },
    "watchAfter": watchAfter,
    "watchPending": watchPendingAtTap,
    "handedThrough": through.map { NSNumber(value: $0) } ?? NSNull(),
    "payloadSid": (payload?[WatchKeys.fieldSid] as? String) ?? NSNull(),
    "landedFirst": landedFirst,
    "landedRepeat": landedRepeat,
    "landedForeign": landedForeign,
    "landedFuture": landedFuture,
    "garbled": garbled.map { NSNumber(value: $0) } ?? NSNull(),
    "survivedGarbled": survivedGarbled,
    "phoneOutbox": phone.string(forKey: CirrusKeys.outbox) ?? "",
    "phoneSeq": phone.integer(forKey: CirrusKeys.seq),
    "phoneToday": today(phone),
    "watchSent": watchSent,
    "watchAfterAck": watchAfterAck,
    "watchPendingAfterAck": watchPendingAfterAck,
    "nothingLeftToSend": nothingLeftToSend,
    "afterDrain": afterDrain,
    "cursorAfterDrain": cursorAfterDrain,
    "pendingAfterDrain": pendingAfterDrain,
    "watchQueuedBeforeSecond": watchQueuedBeforeSecond,
    "forgotSecond": forgotSecond.map { NSNumber(value: $0) } ?? NSNull(),
    "watchAfterSecond": watchAfterSecond,
    "watchQueuedAfterSecond": watchQueuedAfterSecond,
    "tapAfterSecond": tapAfterSecond.map { NSNumber(value: $0) } ?? NSNull(),
    "sidAfterSecond": sidAfterSecond,
    "emptyCopyAfterSecond": emptyCopyAfterSecond,
    "retryOffers": retryOffers.map { NSNumber(value: $0) } ?? NSNull(),
    "minusAtZero": minusAtZero.map { NSNumber(value: $0) } ?? NSNull(),
    "plusThenMinus": plusThenMinus.map { $0.map { NSNumber(value: $0) } ?? NSNull() },
    "zeroCount": zeroToday["count"] ?? NSNull(),
    "rt": rt,
]
print(String(data: try! JSONSerialization.data(withJSONObject: report), encoding: .utf8)!)
wipe()
''';

  group('the phone and the watch over the real wire', () {
    late Directory tmp;
    late String binary;

    setUpAll(() {
      tmp = Directory.systemTemp.createTempSync('cirrus-watch-');
      File('${tmp.path}/main.swift').writeAsStringSync(harness);
      binary = '${tmp.path}/harness';
      final compile = Process.runSync('xcrun', [
        'swiftc',
        '-sdk',
        sdk,
        '-swift-version',
        '5',
        '-O',
        'ios/CirrusWidget/CirrusShared.swift',
        'ios/CirrusWidget/CirrusOutbox.swift',
        'ios/CirrusWatch/WatchWire.swift',
        '${tmp.path}/main.swift',
        '-o',
        binary,
      ]);
      if (compile.exitCode != 0) {
        fail('swiftc failed:\n${compile.stdout}\n${compile.stderr}');
      }
    });

    tearDownAll(() => tmp.deleteSync(recursive: true));

    const copy = WidgetCopy(
      day: r'day %1$d',
      dayFreedom: 'Freedom Day 🏆',
      dayPastOne: r'%1$d day past Freedom Day',
      dayPastOther: r'%1$d days past Freedom Day',
      leftAhead: r'%1$d left · ahead of your curve',
      leftTight: r"%1$d left · tight, you've got this",
      overLimit: 'over today',
      emptyTitle: 'Start your plan',
      emptyBody: 'Tap to open Cirrus',
      watchOpenPhone: 'Open Cirrus on your iPhone',
      weekTitle: 'PUFFS THIS WEEK',
      vsLast: r'%1$@ vs last',
      savedLabel: 'saved so far',
      cravingsLabel: 'cravings beaten',
      breatheIn: 'Breathe in',
      breatheHold: 'Hold',
      breatheOut: 'Breathe out',
      breathePattern: 'In 4 · Hold 7 · Out 8',
      cravingTimer: r'craving timer · %1$@ · peaks ~15 min',
      cravingTimerLate: r'craving timer · %1$@ · past the worst',
    );

    final now = DateTime.now();
    final journey = SeedData.journey(now);
    final snapshot = TodaySnapshot.of(journey, now);

    String document({
      required String? sid,
      bool withJourney = true,
      int extraPuffs = 0,
    }) {
      final mirror = buildMirror(
        journey: withJourney ? journey : null,
        snapshot: withJourney ? snapshot : null,
        copy: copy,
        now: now,
        sid: sid,
        locale: 'en',
      );
      // Stands in for the phone having drained: the same document with the
      // relayed taps folded into the count, which is exactly what the app
      // pushes once `WidgetCoordinator` has applied them.
      if (extraPuffs != 0 && mirror['hasJourney'] == true) {
        mirror['puffs'] = (mirror['puffs'] as int) + extraPuffs;
      }
      return jsonEncode(mirror);
    }

    // A journey whose today holds no puffs at all.
    final freshJourney = InitialJourney.build(
      profile: journey.profile,
      plan: journey.plan,
      now: now,
    );
    String zeroDocumentFor(String sid) => jsonEncode(
      buildMirror(
        journey: freshJourney,
        snapshot: TodaySnapshot.of(freshJourney, now),
        copy: copy,
        now: now,
        sid: sid,
        locale: 'en',
      ),
    );
    final zeroDocument = zeroDocumentFor('uid-zero');

    Map<String, dynamic> run({
      required String mirror,
      String? next,
      String? drained,
    }) {
      final path = '${tmp.path}/spec.json';
      File(path).writeAsStringSync(
        jsonEncode({
          'mirror': mirror,
          'next': ?next,
          'drained': ?drained,
          // A day-1 journey with nothing logged, for the `−`-at-zero probe.
          'zero': zeroDocument,
          // The same, on uid-a: a phone with nothing left to take off.
          'zeroA': zeroDocumentFor('uid-a'),
          // The drained mirrors section 12 pushes, one per wrist tap folded in.
          'plusOne': document(sid: 'uid-a', extraPuffs: 1),
          'plusTwo': document(sid: 'uid-a', extraPuffs: 2),
          'plusThree': document(sid: 'uid-a', extraPuffs: 3),
          'plusFour': document(sid: 'uid-a', extraPuffs: 4),
          'plusFive': document(sid: 'uid-a', extraPuffs: 5),
          'other': document(sid: 'uid-b'),
          'otherPlusOne': document(sid: 'uid-b', extraPuffs: 1),
        }),
      );
      final result = Process.runSync(binary, [path]);
      if (result.exitCode != 0) {
        fail('harness failed:\n${result.stdout}\n${result.stderr}');
      }
      return jsonDecode(result.stdout.toString().trim())
          as Map<String, dynamic>;
    }

    test('a tap on the wrist becomes a puff in the phone\'s outbox', () {
      final report = run(mirror: document(sid: 'uid-a'));

      // The wrist reads the phone's own numbers, through the phone's own
      // engines — the seven-day limit window included.
      final before = report['watchBefore'] as Map<String, dynamic>;
      expect(before['count'], snapshot.puffs);
      expect(before['limit'], snapshot.limit);
      expect(before['knowsLimit'], isTrue);
      expect(before['dayNumber'], snapshot.dayNumber);
      expect(before['day'], 'day ${snapshot.dayNumber}');
      expect(report['forgotFirst'], isFalse);
      expect(report['watchSid'], 'uid-a');

      // + + + − optimistically, on the wrist alone.
      expect(report['taps'], [
        snapshot.puffs + 1,
        snapshot.puffs + 2,
        snapshot.puffs + 3,
        snapshot.puffs + 2,
      ]);
      expect(report['watchPending'], 2);
      expect((report['watchAfter'] as Map)['count'], snapshot.puffs + 2);
      expect(report['payloadSid'], 'uid-a');
      expect(report['handedThrough'], 4);

      // The phone takes all four, mints its OWN sequence, and refuses the
      // re-send. `lp.seq` keeps exactly one writer per container.
      expect(report['landedFirst'], 4);
      expect(report['landedRepeat'], 0);
      expect(report['phoneSeq'], 4);

      // And the bytes the phone now holds decode with the real Dart decoder.
      final events = PendingPuffs.pending(
        PendingPuffs.decode(report['phoneOutbox'] as String),
        0,
      );
      expect(events.length, 4);
      expect(events.map((e) => e.delta), [1, 1, 1, -1]);
      expect(events.map((e) => e.seq), [1, 2, 3, 4]);
      expect(events.map((e) => e.id).toSet().length, 4);
      // The Double-`t` bug, on the relay path this time: the phone re-stamps
      // with the watch's own instant and it must survive as an int.
      final raw = jsonDecode(report['phoneOutbox'] as String) as Map;
      for (final event in raw['e'] as List) {
        expect((event as Map)['t'], isA<int>());
      }
      // The phone folds them exactly as the widget will.
      expect((report['phoneToday'] as Map)['count'], snapshot.puffs + 2);
    }, skip: skip);

    test('a handed-over tap keeps counting until the mirror catches up', () {
      // The bug this pins, watched happen on a simulator (docs/10 §29): the
      // phone acknowledges a tap into its own outbox and only folds it into the
      // journey on its next drain, which can be hours away. Moving the cursor on
      // the receipt made the wrist's count DROP BACK a second after a tap —
      // which is the surest way to make somebody tap again.
      final report = run(
        mirror: document(sid: 'uid-a'),
        drained: document(sid: 'uid-a', extraPuffs: 2),
      );

      // Acknowledged, and still counted.
      expect(report['watchSent'], 4);
      expect(report['watchPendingAfterAck'], 2);
      expect((report['watchAfterAck'] as Map)['count'], snapshot.puffs + 2);
      // But not re-sent: the send floor follows the hand-over, not the cursor.
      expect(report['nothingLeftToSend'], isTrue);

      // The mirror that includes them is what finally moves the cursor, and the
      // count does not move at all across that hand-off — no dip, no double.
      expect(report['cursorAfterDrain'], 4);
      expect(report['pendingAfterDrain'], 0);
      expect((report['afterDrain'] as Map)['count'], snapshot.puffs + 2);
      expect(report['watchQueuedBeforeSecond'], 4);
    }, skip: skip);

    test('a batch from another account, or another version, is dropped', () {
      final report = run(mirror: document(sid: 'uid-a'));
      expect(report['landedForeign'], 0);
      expect(report['landedFuture'], 0);
      // Nothing extra reached the phone: still the four honest taps.
      expect(report['phoneSeq'], 4);
    }, skip: skip);

    test('a garbled context leaves a good mirror alone', () {
      final report = run(mirror: document(sid: 'uid-a'));
      expect(report['garbled'], isNull);
      expect(report['survivedGarbled'], isTrue);
    }, skip: skip);

    test('a no-journey mirror shows the empty card and keeps the queue', () {
      // The second bug from the same simulator pass. Signing out pushes exactly
      // this mirror — but so does EVERY cold start of the phone app, because
      // `_WidgetSync` builds its first mirror before `restoreSession` answers.
      // Wiping on it threw away a wrist full of un-handed-over taps every time
      // the user opened the app.
      final report = run(
        mirror: document(sid: 'uid-a'),
        next: document(sid: null, withJourney: false),
      );
      expect(report['forgotSecond'], isFalse);
      // The numbers are gone from the screen. `cirrusToday` still folds the
      // queue into a count here, but nothing draws it: `WatchHomeView` and the
      // complication both gate on `hasJourney` before any number is rendered,
      // which is the guard `ios_watch_test.dart` pins.
      final empty = report['emptyCopyAfterSecond'] as Map;
      expect(empty['hasJourney'], '0');
      expect(empty['emptyTitle'], 'Start your plan');
      // …and the watch's own line, not the home screen's "Tap to open Cirrus".
      expect(empty['watchOpenPhone'], 'Open Cirrus on your iPhone');
      // …and a `+` is refused outright — no journey, no number, no tap.
      expect(report['tapAfterSecond'], isNull);

      // But the taps survive, and so does the id that attributes them. Clearing
      // the id would be worse than useless: the next flush would arrive with an
      // empty sid, which `relay` cannot tell from "unknown" and therefore
      // accepts — handing the previous account's taps to whoever signs in.
      expect(report['watchQueuedAfterSecond'], 8);
      expect(report['sidAfterSecond'], 'uid-a');
    }, skip: skip);

    test('a different account on the same phone empties the wrist too', () {
      // The sharper half of the shared-phone case: signing straight into
      // another account never shows `hasJourney: false` at all, so the flip
      // cannot be what the watch keys on.
      final report = run(
        mirror: document(sid: 'uid-a'),
        next: document(sid: 'uid-b'),
      );
      expect(report['forgotSecond'], isTrue);
      expect(report['watchQueuedAfterSecond'], 0);
      expect(report['sidAfterSecond'], 'uid-b');
      // And the phone is the backstop for the window before this lands: a batch
      // still carrying uid-a is refused by `relay` against uid-b's mirror.
      // It is somebody's journey, so a tap is allowed — it is just the new
      // person's first one.
      expect(report['tapAfterSecond'], snapshot.puffs + 1);
    }, skip: skip);

    test('the same account again keeps the queue', () {
      final report = run(
        mirror: document(sid: 'uid-a'),
        next: document(sid: 'uid-a'),
      );
      expect(report['forgotSecond'], isFalse);
      expect(report['watchQueuedAfterSecond'], 8);
      expect(report['sidAfterSecond'], 'uid-a');
    }, skip: skip);

    test('a mirror whose id has not resolved yet is not a stranger', () {
      // The race this rule exists for: the phone's first push after a cold
      // launch can beat its own async uid lookup. Reading "not yet" as
      // "different person" would throw away a good mirror and a queue of real
      // taps on every single launch.
      final report = run(
        mirror: document(sid: 'uid-a'),
        next: document(sid: null),
      );
      expect(report['forgotSecond'], isFalse);
      expect(report['watchQueuedAfterSecond'], 8);
      // And the id it already knew is kept, not blanked.
      expect(report['sidAfterSecond'], 'uid-a');
    }, skip: skip);

    test('a hand-over the mirror never confirmed is offered again', () {
      // The hole a lying transport leaves. `didFinish` reported success on a
      // simulator for payloads the phone never received (docs/10 §29), and
      // `sent` advanced on it — so without this those taps would be counted on
      // the wrist for ever and never reach the phone.
      final report = run(mirror: document(sid: 'uid-a'));
      // A normal flush stays quiet: nothing is re-sent while the cursor lags.
      expect(report['nothingLeftToSend'], isTrue);
      // A foreground with the phone reachable asks again, from the cursor —
      // all four taps, not none.
      expect(report['retryOffers'], 4);
    }, skip: skip);

    test('a minus on a wrist at zero is refused, and never goes negative', () {
      final report = run(mirror: document(sid: 'uid-a'));
      // Nothing logged today: the first `−` is refused outright and queues
      // nothing, so it cannot cost a slot or a sequence number.
      expect(report['minusAtZero'], isNull);
      // +1 then −1 lands, and the second −1 is refused at the floor.
      expect(report['plusThenMinus'], [1, 0, null]);
      expect(report['zeroCount'], 0);
    }, skip: skip);

    test('real-time draining: the wrist neither drops nor doubles across a hand-off', () {
      // docs/10 §36. Once the phone drains a relayed tap within the second,
      // the wrist can no longer infer "drained" from a mark taken at hand-over:
      // two hand-overs bracketing one mirror retired the second tap early (the
      // count dropped by one until the next mirror), and a mirror that beat its
      // own receipt left the mark pointing at the drained count, so the tap was
      // never retired (one too high, for ever). The mirror now names the seq it
      // reflects and the wrist follows that exactly.
      final rt = run(mirror: document(sid: 'uid-a'))['rt'] as Map<String, dynamic>;

      expect(rt['initialR'], isNull, reason: 'nothing relayed yet: nothing to claim');
      expect(rt['bothPending'], 2);
      // Draining the first tap alone retires the first tap alone.
      expect(rt['r1'], 1);
      expect(rt['afterFirst'], [2, 1], reason: 'still +2 on the wrist, cursor at 1');
      expect(rt['r2'], 2);
      expect(rt['afterSecond'], [2, 2, 0]);
      // The mirror before the receipt: retired by the mirror, not doubled.
      expect(rt['r3'], 3);
      expect(rt['beforeReceipt'], [3, 3]);
      expect(rt['sameAgainR'], 3);
      expect(rt['afterReceipt'], [3, 3, 0], reason: 'the late receipt changes nothing');
      // A refused tap is consumed, and retired without a new drain.
      expect(rt['refusedLanded'], 0);
      expect(rt['refusedR'], 4);
      expect(rt['afterRefused'], [3, 4, 0]);
      // A reinstalled watch app: the old ledger cannot retire new taps.
      expect(rt['reinstallR'], 4);
      expect(rt['reinstallCursor'], 0);
      expect(rt['restartR'], 1);
      expect(rt['restartCursor'], 1);
      // A phone without the field still works the old way.
      expect(rt['legacyCursor'], 2);
      // Another account: the ledger is theirs.
      expect(rt['otherR'], isNull);
      expect(rt['otherForgot'], 0);
      expect(rt['otherAfterR'], 1);
      expect(rt['otherCursor'], 1);
    }, skip: skip);

    test('a wrist that never had a journey never draws a number', () {
      final report = run(mirror: document(sid: null, withJourney: false));
      expect(report['forgotFirst'], isFalse);
      expect((report['watchBefore'] as Map)['count'], 0);
      expect((report['watchBefore'] as Map)['knowsLimit'], isFalse);
      expect(report['taps'], [null, null, null, null]);
      expect(report['handedThrough'], isNull);
      expect(report['phoneOutbox'], '');
      expect(report['phoneSeq'], 0);
    }, skip: skip);
  }, skip: skip);

  /// The week card, executed rather than string-matched.
  ///
  /// Its own harness and its own binary: `cirrusWeek` is a pure function of a
  /// mirror and a count, so it needs none of the two-container dance above,
  /// and keeping it separate means a failure here names the week card rather
  /// than the wire.
  group('the week the wrist draws is the week the phone computed', () {
    late Directory tmp;
    late String binary;

    setUpAll(() {
      if (sdk.isEmpty) return;
      tmp = Directory.systemTemp.createTempSync('cirrus-week-');
      binary = '${tmp.path}/week';
      File('${tmp.path}/main.swift').writeAsStringSync(r'''
import Foundation

let spec = try! JSONSerialization.jsonObject(
    with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
) as! [String: Any]

let mirror = CirrusMirror.decode(spec["mirror"] as? String)
let today = cirrusToday(mirror, pending: spec["pending"] as! Int)
let bars = cirrusWeek(mirror, today: today)

let report: [String: Any] = [
    "puffs": bars.map { $0.puffs },
    "heights": bars.map { $0.height },
    "tones": bars.map { bar -> String in
        switch bar.tone {
        case .hardest: return "hardest"
        case .best: return "best"
        case .plain: return "plain"
        }
    },
    "vsLast": mirror.weekVsLast as Any? ?? NSNull(),
    "vsLine": mirror.copyVsLast.isEmpty
        ? ""
        : String(format: mirror.copyVsLast, mirror.weekVsLastLabel),
    "saved": mirror.savedText,
    "cravings": mirror.cravingsBeaten,
]
print(String(data: try! JSONSerialization.data(withJSONObject: report), encoding: .utf8)!)
''');
      final compile = Process.runSync('xcrun', [
        'swiftc',
        '-sdk', sdk,
        '-swift-version', '5',
        '-O',
        'ios/CirrusWidget/CirrusShared.swift',
        '${tmp.path}/main.swift',
        '-o', binary,
      ]);
      if (compile.exitCode != 0) {
        fail('swiftc failed:\n${compile.stdout}\n${compile.stderr}');
      }
    });

    tearDownAll(() {
      if (sdk.isEmpty) return;
      tmp.deleteSync(recursive: true);
    });

    Map<String, dynamic> run(Map<String, dynamic> mirror, {int pending = 0}) {
      File('${tmp.path}/spec.json').writeAsStringSync(
        jsonEncode({'mirror': jsonEncode(mirror), 'pending': pending}),
      );
      final result = Process.runSync(binary, ['${tmp.path}/spec.json']);
      if (result.exitCode != 0) {
        fail('harness failed:\n${result.stdout}\n${result.stderr}');
      }
      return jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
    }

    const copy = WidgetCopy(
      day: r'day %1$d',
      dayFreedom: 'Freedom Day 🏆',
      dayPastOne: r'%1$d day past Freedom Day',
      dayPastOther: r'%1$d days past Freedom Day',
      leftAhead: r'%1$d left · ahead of your curve',
      leftTight: r"%1$d left · tight, you've got this",
      overLimit: 'over today',
      emptyTitle: 'Start your plan',
      emptyBody: 'Tap to open Cirrus',
      watchOpenPhone: 'Open Cirrus on your iPhone',
      weekTitle: 'PUFFS THIS WEEK',
      vsLast: r'%1$@ vs last',
      savedLabel: 'saved so far',
      cravingsLabel: 'cravings beaten',
      breatheIn: 'Breathe in',
      breatheHold: 'Hold',
      breatheOut: 'Breathe out',
      breathePattern: 'In 4 · Hold 7 · Out 8',
      cravingTimer: r'craving timer · %1$@ · peaks ~15 min',
      cravingTimerLate: r'craving timer · %1$@ · past the worst',
    );

    final now = DateTime.now();
    final journey = SeedData.journey(now);
    Map<String, dynamic> document() => buildMirror(
      journey: journey,
      snapshot: TodaySnapshot.of(journey, now),
      copy: copy,
      now: now,
      sid: 'uid-week',
      locale: 'en',
    );

    test('every bar is the day the engine put there', () {
      final report = run(document());
      final week = DayWindow.trailing(journey, now, kMirrorLimitDays);
      expect(report['puffs'], [for (final l in week) l.puffs]);
      expect(report['saved'], LpFormat.money(
        TodaySnapshot.of(journey, now).savedLifetime,
        'en',
      ));
      expect(report['cravings'], journey.cravingsSurvivedTotal);
    }, skip: skip);

    test('the ember and volt bars are the engine\'s two verdicts', () {
      final report = run(document());
      final week = DayWindow.trailing(journey, now, kMirrorLimitDays);
      final tones = (report['tones'] as List).cast<String>();
      expect(tones[WeekTrend.hardestIndex(week)], 'hardest');
      expect(tones[WeekTrend.bestIndex(week, now)], 'best');
      // Exactly one of each: two bars claiming to be the hard day is how a
      // reader stops trusting the card.
      expect(tones.where((t) => t == 'hardest'), hasLength(1));
      expect(tones.where((t) => t == 'best'), hasLength(1));
    }, skip: skip);

    test('an empty day is still a visible sliver, never nothing', () {
      // JSON renders a whole 1.0 as `1`, so read them as `num`.
      final heights = [
        for (final h in run(document())['heights'] as List) (h as num).toDouble(),
      ];
      for (final h in heights) {
        expect(h, greaterThanOrEqualTo(0.04));
        expect(h, lessThanOrEqualTo(1.0));
      }
      expect(heights.reduce((a, b) => a > b ? a : b), 1.0);
    }, skip: skip);

    test('a tap the phone has not taken grows TODAY and only today', () {
      // The consistency case: the day card already counts pending taps, so a
      // week chart that ignored them would disagree with the screen beside it.
      final before = (run(document())['puffs'] as List).cast<int>();
      final after = (run(document(), pending: 3)['puffs'] as List).cast<int>();
      expect(after.last, before.last + 3);
      expect(after.sublist(0, after.length - 1), before.sublist(0, before.length - 1));
    }, skip: skip);

    test('a stale mirror never paints pending taps onto yesterday', () {
      // `weekPuffs` ends on the day the mirror was built for. If that is not
      // today, the last bar is yesterday's and today's count belongs nowhere
      // on this chart.
      final stale = document()..['dayKey'] = '2001-01-01';
      final report = run(stale, pending: 5);
      final week = DayWindow.trailing(journey, now, kMirrorLimitDays);
      expect(report['puffs'], [for (final l in week) l.puffs]);
    }, skip: skip);

    test('the percent line is composed from the phone\'s own signed text', () {
      final report = run(document());
      if (report['vsLast'] == null) {
        expect(report['vsLine'], isNot(contains('%1')));
        return;
      }
      final label = LpFormat.signedPercent(report['vsLast'] as int);
      expect(report['vsLine'], '$label vs last');
      expect(report['vsLine'], isNot(contains(r'%1$@')));
    }, skip: skip);

    test('no journey draws no bars at all', () {
      final report = run(buildMirror(
        journey: null,
        snapshot: null,
        copy: copy,
        now: now,
        sid: 'uid-week',
        locale: 'en',
      ), pending: 4);
      expect(report['puffs'], isEmpty);
      expect(report['vsLast'], isNull);
      expect(report['cravings'], 0);
      expect(report['saved'], '');
    }, skip: skip);
  }, skip: skip);

  /// The 4-7-8 pacer, both implementations, every frame.
  ///
  /// The one piece of arithmetic the wrist duplicates, so it is the one that
  /// gets executed rather than string-matched. A sampled subset would not do:
  /// the failure mode of a cubic-Bezier port is a curve that is right at the
  /// ends and wrong in the middle.
  group('the wrist breathes exactly what the phone breathes', () {
    late Directory tmp;
    late String binary;
    late Map<String, dynamic> report;

    const pacer = BreathPacer();

    /// Every frame of a 60 fps cycle, plus the points where floating point and
    /// `.ceil()` are fragile: the exact phase boundaries, a hair either side,
    /// every whole second, and wraps past 1 and below 0.
    final ts = <double>[
      for (var i = 0; i < 19 * 60; i++) i / (19 * 60),
      for (final b in [0.0, 4 / 19, 11 / 19, 1.0]) ...[
        b, b - 1e-9, b + 1e-9, b - 1e-12, b + 1e-12,
      ],
      for (var s = 0; s <= 19; s++) ...[s / 19, (s - 1e-9) / 19],
      // -0.25 is the one that pins `t - floor(t)` against Swift's
      // sign-keeping remainder, which would answer -0.25 and land mid-exhale.
      1.0, 1.5, 2.25, -0.25, -1.75,
    ];
    final curveTs = [for (var i = 0; i <= 1000; i++) i / 1000];
    final timerTs = [0, 1, 59, 60, 61, 299, 300, 3599, 3600];

    setUpAll(() {
      if (sdk.isEmpty) return;
      tmp = Directory.systemTemp.createTempSync('cirrus-breath-');
      binary = '${tmp.path}/breath';
      File('${tmp.path}/main.swift').writeAsStringSync(_breathHarness);
      final compile = Process.runSync('xcrun', [
        'swiftc',
        '-sdk', sdk,
        '-swift-version', '5',
        '-O',
        'ios/CirrusWatch/BreathPacer.swift',
        '${tmp.path}/main.swift',
        '-o', binary,
      ]);
      if (compile.exitCode != 0) {
        fail('swiftc failed:\n${compile.stdout}\n${compile.stderr}');
      }
      File('${tmp.path}/spec.json').writeAsStringSync(
        jsonEncode({'t': ts, 'curve': curveTs, 'timer': timerTs}),
      );
      final result = Process.runSync(binary, ['${tmp.path}/spec.json']);
      if (result.exitCode != 0) {
        fail('harness failed:\n${result.stdout}\n${result.stderr}');
      }
      report = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
    });

    tearDownAll(() {
      if (sdk.isEmpty) return;
      tmp.deleteSync(recursive: true);
    });

    double asDouble(Object? v) => (v as num).toDouble();

    test('every frame of the cycle agrees, on both sides', () {
      final moments = (report['moments'] as List).cast<Map<String, dynamic>>();
      expect(moments, hasLength(ts.length));
      for (var i = 0; i < ts.length; i++) {
        final dart = pacer.at(ts[i]);
        final swift = moments[i];
        final at = 't=${ts[i]}';
        expect(swift['phase'], dart.phase.name, reason: at);
        // A number the user reads. No tolerance.
        expect(swift['remaining'], dart.remaining, reason: at);
        expect(asDouble(swift['progress']), closeTo(dart.progress, 1e-12), reason: at);
        expect(
          asDouble(swift['cycleProgress']),
          closeTo(dart.cycleProgress, 1e-12),
          reason: at,
        );
        expect(asDouble(swift['scale']), closeTo(dart.scale, 1e-12), reason: at);
        expect(asDouble(swift['pulse']), closeTo(dart.pulse, 1e-12), reason: at);
      }
    }, skip: skip);

    test("the easing is Flutter's bisection, not a sine", () {
      final swift = (report['curve'] as List).map(asDouble).toList();
      var sineGap = 0.0;
      for (var i = 0; i < curveTs.length; i++) {
        final t = curveTs[i];
        expect(
          swift[i],
          closeTo(Curves.easeInOutSine.transform(t), 1e-12),
          reason: 't=$t',
        );
        final sine = 0.5 - 0.5 * math.cos(math.pi * t);
        final gap = (swift[i] - sine).abs();
        if (gap > sineGap) sineGap = gap;
      }
      // And it is genuinely NOT the analytic sine somebody will eventually
      // "simplify" it to — which would shift the orb without failing anything
      // that only checked the endpoints.
      expect(
        sineGap,
        greaterThan(0.005),
        reason: 'a cos-based curve would pass every other assertion here',
      );
    }, skip: skip);

    test('4-7-8 and a 0.4 rest, identical on both sides', () {
      final defaults = report['defaults'] as Map<String, dynamic>;
      expect(defaults['inhale'], pacer.inhale);
      expect(defaults['hold'], pacer.hold);
      expect(defaults['exhale'], pacer.exhale);
      expect(asDouble(defaults['minScale']), closeTo(pacer.minScale, 1e-12));
      expect(defaults['cycleSeconds'], pacer.cycleSeconds);
      final starts = (report['phaseStarts'] as List).map(asDouble).toList();
      for (var i = 0; i < starts.length; i++) {
        expect(starts[i], closeTo(pacer.phaseStarts[i], 1e-12), reason: '$i');
      }
    }, skip: skip);

    test('the craving clock reads the same on both screens', () {
      final swift = (report['timer'] as List).cast<String>();
      for (var i = 0; i < timerTs.length; i++) {
        expect(
          swift[i],
          LpFormat.timer(Duration(seconds: timerTs[i])),
          reason: '${timerTs[i]}s',
        );
      }
    }, skip: skip);
  }, skip: skip);
}

/// Constructed with DEFAULTS, never from the spec: a drifted constant must fail
/// the comparison rather than be handed the phone's value and agree with it.
const _breathHarness = r'''
import Foundation

let spec = try! JSONSerialization.jsonObject(
    with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
) as! [String: Any]

let pacer = BreathPacer()
let curve = FlutterCubic.easeInOutSine

let moments = (spec["t"] as! [Double]).map { t -> [String: Any] in
    let m = pacer.at(t)
    return [
        "phase": m.phase.rawValue,
        "progress": m.progress,
        "cycleProgress": m.cycleProgress,
        "remaining": m.remaining,
        "scale": m.scale,
        "pulse": m.pulse,
    ]
}

let report: [String: Any] = [
    "defaults": [
        "inhale": pacer.inhale, "hold": pacer.hold, "exhale": pacer.exhale,
        "minScale": pacer.minScale, "cycleSeconds": pacer.cycleSeconds,
    ],
    "phaseStarts": pacer.phaseStarts,
    "moments": moments,
    "curve": (spec["curve"] as! [Double]).map { curve.transform($0) },
    "timer": (spec["timer"] as! [Double]).map { cirrusTimerText($0) },
]
print(String(data: try! JSONSerialization.data(withJSONObject: report), encoding: .utf8)!)
''';
