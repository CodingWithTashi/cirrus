@Tags(['swift'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/seed/seed_data.dart';
import 'package:last_puff/data/stores/pending_puffs.dart';
import 'package:last_puff/data/stores/widget_mirror.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/models/journey_state.dart';

/// The Swift widget logic, executed against a mirror the Dart side built and
/// decoded by the Dart side — the cross-language round trip
/// `ios/CirrusWidget/README.md` asked for.
///
/// `CirrusShared.swift` and `CirrusOutbox.swift` are Foundation-only, so they
/// compile for the Mac the tests run on. `ios_widget_test.dart` pins the
/// NAMES both sides use; this one runs the code, which is the only way to
/// catch a type mismatch (`"t"` written as a Double, `limits` cast to
/// `[String: Int]` collapsing on a fractional value) before a device does.
///
/// Skipped anywhere without `xcrun swiftc` — CI is Linux and the other dev
/// machine is Windows — so it is a macOS gate, not a CI one. On a Mac it runs
/// with the rest of `flutter test` and costs the one compile.
void main() {
  // Through `xcrun`, which is what points swiftc at the macOS SDK; the bare
  // binary cannot find its own standard library.
  final sdk = Platform.isMacOS
      ? Process.runSync('xcrun', [
          '--show-sdk-path',
          '--sdk',
          'macosx',
        ]).stdout.toString().trim()
      : '';
  final skip = sdk.isEmpty ? 'needs macOS with Xcode (swiftc)' : false;

  const folder = 'ios/CirrusWidget';

  // The Swift harness. Top-level code, so no `@main` and no `-parse-as-library`.
  // It wipes the suite before and after: `CirrusKeys.appGroup` is a static, so
  // on a Mac `UserDefaults(suiteName:)` writes a real
  // ~/Library/Preferences/group.com.quitvape.lastPuff.plist.
  const harness = r'''
import Foundation

let args = CommandLine.arguments
let mirrorPath = args[1]
let suite = UserDefaults(suiteName: CirrusKeys.appGroup)!
suite.removePersistentDomain(forName: CirrusKeys.appGroup)

let mirrorJson = try! String(contentsOfFile: mirrorPath, encoding: .utf8)
suite.set(mirrorJson, forKey: CirrusKeys.mirror)

let mirror = CirrusMirror.read()
let before = cirrusToday(mirror, pending: CirrusOutbox.pendingToday())
let appended: [Int?] = [
    CirrusOutbox.append(delta: 1),
    CirrusOutbox.append(delta: 1),
    CirrusOutbox.append(delta: 1),
    CirrusOutbox.append(delta: -1),
]
let pending = CirrusOutbox.pendingToday()
let after = cirrusToday(mirror, pending: pending)

let report: [String: Any] = [
    "hasJourney": mirror.hasJourney,
    "limitsRead": mirror.limits.count,
    "dayKey": mirror.dayKey,
    "before": ["count": before.count, "limit": before.limit, "knowsLimit": before.knowsLimit, "dayNumber": before.dayNumber],
    "appended": appended.map { $0.map { NSNumber(value: $0) } ?? NSNull() },
    "pending": pending,
    "after": ["count": after.count, "left": after.left, "over": after.over, "status": after.statusLine(mirror), "day": after.dayLabel(mirror)],
    "outbox": suite.string(forKey: CirrusKeys.outbox) ?? "",
    "seq": suite.integer(forKey: CirrusKeys.seq),
]
let data = try! JSONSerialization.data(withJSONObject: report)
print(String(data: data, encoding: .utf8)!)
suite.removePersistentDomain(forName: CirrusKeys.appGroup)
''';

  group('CirrusWidget Swift harness', () {
    late Directory tmp;
    late String binary;

    setUpAll(() {
      tmp = Directory.systemTemp.createTempSync('cirrus-widget-');
      File('${tmp.path}/main.swift').writeAsStringSync(harness);
      binary = '${tmp.path}/harness';
      final compile = Process.runSync('xcrun', [
        'swiftc',
        '-sdk',
        sdk,
        '-swift-version',
        '5',
        '-O',
        '$folder/CirrusShared.swift',
        '$folder/CirrusOutbox.swift',
        '${tmp.path}/main.swift',
        '-o',
        binary,
      ]);
      if (compile.exitCode != 0) {
        fail('swiftc failed:\n${compile.stdout}\n${compile.stderr}');
      }
    });

    tearDownAll(() => tmp.deleteSync(recursive: true));

    Map<String, dynamic> run(Map<String, dynamic> mirror) {
      final path = '${tmp.path}/mirror.json';
      File(path).writeAsStringSync(jsonEncode(mirror));
      final result = Process.runSync(binary, [path]);
      if (result.exitCode != 0) {
        fail('harness failed:\n${result.stdout}\n${result.stderr}');
      }
      return jsonDecode(result.stdout.toString().trim())
          as Map<String, dynamic>;
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
    );

    test('Swift reads the Dart mirror and Dart decodes the Swift outbox', () {
      // A real day-12 journey through the real builder — exactly what
      // `_WidgetSync` pushes, with today's count folded in by Swift.
      final now = DateTime.now();
      final journey = SeedData.journey(now);
      final snapshot = TodaySnapshot.of(journey, now);
      final mirror = buildMirror(
        journey: journey,
        snapshot: snapshot,
        copy: copy,
        now: now,
      );

      final report = run(mirror);

      expect(report['hasJourney'], isTrue);
      expect(
        report['limitsRead'],
        kMirrorLimitDays,
        reason: 'limits cast lost values',
      );
      expect(report['dayKey'], LpDate.dayKey(LpDate.dayStart(now)));

      final before = report['before'] as Map<String, dynamic>;
      expect(before['count'], snapshot.puffs);
      expect(before['limit'], snapshot.limit);
      expect(before['knowsLimit'], isTrue);
      expect(before['dayNumber'], snapshot.dayNumber);

      // Three accepted, then a minus accepted because the count is above zero.
      expect(report['appended'], [
        snapshot.puffs + 1,
        snapshot.puffs + 2,
        snapshot.puffs + 3,
        snapshot.puffs + 2,
      ]);
      expect(report['pending'], 2);
      expect(report['seq'], 4);

      final after = report['after'] as Map<String, dynamic>;
      expect(after['count'], snapshot.puffs + 2);
      expect(
        after['left'],
        (snapshot.limit - snapshot.puffs - 2).clamp(0, 1 << 30),
      );
      expect(after['day'], 'day ${snapshot.dayNumber}');
      expect(after['status'], isNot(isEmpty));

      // The Dart decoder, on the bytes Swift wrote.
      final events = PendingPuffs.pending(
        PendingPuffs.decode(report['outbox'] as String),
        0,
      );
      expect(events.map((e) => e.delta), [1, 1, 1, -1]);
      expect(events.map((e) => e.seq), [1, 2, 3, 4]);
      for (final event in events) {
        expect(event.id, isNotEmpty);
        expect(event.at.difference(now).inSeconds.abs(), lessThan(60));
        expect(LpDate.dayKey(event.at), mirror['dayKey']);
      }
      // And `t` is integral on the wire — the bug the review caught first.
      final raw =
          jsonDecode(report['outbox'] as String) as Map<String, dynamic>;
      for (final entry in raw['e'] as List) {
        expect((entry as Map)['t'], isA<int>());
      }
    });

    test('no journey: nothing is read, nothing is queued', () {
      final report = run(
        buildMirror(
          journey: null,
          snapshot: null,
          copy: copy,
          now: DateTime.now(),
        ),
      );
      expect(report['hasJourney'], isFalse);
      expect(report['appended'], [null, null, null, null]);
      expect(report['pending'], 0);
      expect(report['outbox'], isEmpty);
      expect(report['seq'], 0);
    });

    test('a mirror from a schema this build does not know reads as absent', () {
      final report = run({'v': 99, 'hasJourney': true, 'puffs': 40});
      expect(report['hasJourney'], isFalse);
      expect(report['appended'], [null, null, null, null]);
    });

    test('the day line carries Home\'s upper clamp', () {
      // "day 31" of a 30-day plan is what the launcher said before the fix;
      // Home says Freedom Day on the last day and "N days past" after it.
      final now = DateTime.now();
      final journey = SeedData.journey(now);
      final today = LpDate.dayStart(now);
      Map<String, dynamic> planStarted(int daysAgo) {
        final mirror = buildMirror(
          journey: journey,
          snapshot: TodaySnapshot.of(journey, now),
          copy: copy,
          now: now,
        );
        mirror['planStartDayKey'] = LpDate.dayKey(
          LpDate.addDays(today, -daysAgo),
        );
        mirror['totalDays'] = 30;
        return mirror;
      }

      expect((run(planStarted(29))['after'] as Map)['day'], 'Freedom Day 🏆');
      expect(
        (run(planStarted(30))['after'] as Map)['day'],
        '1 day past Freedom Day',
      );
      expect(
        (run(planStarted(33))['after'] as Map)['day'],
        '4 days past Freedom Day',
      );
      expect((run(planStarted(11))['after'] as Map)['day'], 'day 12');
      // An older app's mirror carries no plan length: the plain count stays.
      final legacy = planStarted(33)..['totalDays'] = 0;
      expect((run(legacy)['after'] as Map)['day'], 'day 34');
    });

    test('a stale mirror counts only the pending taps, not yesterday', () {
      final now = DateTime.now();
      final journey = SeedData.journey(now);
      final yesterday = LpDate.addDays(
        LpDate.dayStart(now),
        -1,
      ).add(const Duration(hours: 12));
      final mirror = buildMirror(
        journey: journey,
        snapshot: TodaySnapshot.of(journey, yesterday),
        copy: copy,
        now: yesterday,
      );
      final report = run(mirror);
      final before = report['before'] as Map<String, dynamic>;
      // Yesterday's count must not carry over; today's limit came from the
      // seven-day window shipped inside the mirror.
      expect(before['count'], 0);
      expect(before['knowsLimit'], isTrue);
      expect(before['limit'], journey.limitOn(now));
      expect((report['after'] as Map)['count'], 2);
    });
  }, skip: skip);
}
