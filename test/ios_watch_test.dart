import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/api/widget_store.dart';

/// Cirrus on the wrist, pinned as string tests over the native files and the
/// Xcode project — the watch twin of `ios_widget_test.dart`, and for the same
/// reason: CI runs `flutter test` on Linux and never compiles a line of Swift
/// or opens the project. `ios_watch_contract_test.dart` runs the logic; this
/// pins everything a compiler cannot see.
///
/// Every failure below is silent on a device. A target the project does not
/// embed builds and installs a perfectly good iPhone app with no watch app
/// inside it; a wrong `WKCompanionAppBundleIdentifier` installs a watch app
/// that is never offered beside the phone; an unlinked xcconfig archives,
/// uploads, and is rejected minutes later.
void main() {
  const app = 'ios/CirrusWatch';
  const complication = 'ios/CirrusWatchComplication';
  const hostBundleId = 'com.quitvape.lastPuff';
  // `.watchkitapp` is the legacy two-target convention and buys nothing; since
  // watchOS 7 the id only has to be prefixed by the host's. NOTE: the suffix is
  // NOT what makes a device build succeed — the complication's App ID has to
  // exist in the developer portal either way (docs/10 §29).
  const appBundleId = '$hostBundleId.watch';
  // NOT `.complication` — Apple reserves that suffix under a watch app and
  // refuses to register it, from automatic signing and from the portal alike
  // (docs/10 §29). `.widget` registers instantly.
  const extBundleId = '$appBundleId.widget';
  const deploymentTarget = '10.0';

  String read(String path) => File(path).readAsStringSync();

  /// Comments stripped, so a doc comment naming the very thing an assertion
  /// forbids does not satisfy or break it.
  String code(String swift) => swift
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//.*'), '');

  final wire = read('$app/WatchWire.swift');
  final link = read('$app/WatchLink.swift');
  final view = read('$app/WatchHomeView.swift');
  final palette = read('$app/WatchPalette.swift');
  final entry = read('$app/CirrusWatchApp.swift');
  final week = read('$app/WatchWeekView.swift');
  final breathe = read('$app/WatchBreatheView.swift');
  final pacer = read('$app/BreathPacer.swift');
  final face = read('$complication/CirrusComplication.swift');
  final phoneLink = read('ios/Runner/CirrusWatchLink.swift');
  final shared = read('ios/CirrusWidget/CirrusShared.swift');
  final outbox = read('ios/CirrusWidget/CirrusOutbox.swift');
  final pbxproj = read('ios/Runner.xcodeproj/project.pbxproj');
  final script = read('tool/ios_watch_target.rb');
  final dartMirror = read('lib/data/stores/widget_mirror.dart');
  final dartStore = read('lib/data/api/widget_store.dart');

  group('the wire is the same on both devices', () {
    test('the phone and the watch name the same envelope fields', () {
      // Both halves of the link read these off `WatchKeys`, so the only way
      // they can disagree is if one of them stops doing that.
      for (final field in [
        'fieldVersion',
        'fieldMirror',
        'fieldEvents',
        'fieldSid',
        'fieldReflected',
      ]) {
        expect(code(wire), contains('static let $field ='));
      }
      // Neither link builds an envelope by hand: both go through `WatchWire`,
      // and the watch's names its fields off `WatchKeys` when it asks for a
      // mirror. A raw `"v"` or `"sid"` in either would be free to drift.
      for (final source in [code(link), code(phoneLink)]) {
        expect(source, contains('WatchWire.'));
        expect(
          RegExp(r'''["'](v|m|e|sid)["']\s*:''').hasMatch(source),
          isFalse,
          reason: 'a raw envelope key here can drift from WatchKeys silently',
        );
      }
      expect(code(link), contains('WatchKeys.fieldVersion'));
    });

    test('the wire imports no WatchConnectivity, so a test can run it', () {
      // The whole reason the two-device loop is provable from `flutter test`.
      // A single import here and `ios_watch_contract_test.dart` stops
      // compiling on the Mac — and the loop goes back to being simulator-only.
      expect(wire.contains('import WatchConnectivity'), isFalse);
      expect(wire.contains('import SwiftUI'), isFalse);
      expect(wire, contains('import Foundation'));
      // And it must stay compilable against the shared contract alone.
      expect(code(wire), contains('CirrusMirror.decode'));
      expect(code(wire), contains('CirrusOutbox.append'));
    });

    test('the watch keys are native-only, and outside the Dart contract', () {
      // `ios_widget_test.dart` pins the `lp.*` set in CirrusShared.swift equal
      // to the Dart one. These two have no Dart reader or writer at all — both
      // sides are native — so they live here instead, and each still has
      // exactly one writer.
      expect(code(wire), contains('static let sid = "lp.watchSid"'));
      expect(code(wire), contains('static let seen = "lp.watchSeen"'));
      expect(code(wire), contains('static let relayed = "lp.watchRelayed"'));
      for (final key in ['lp.watchSid', 'lp.watchSeen', 'lp.watchRelayed']) {
        expect(dartMirror.contains(key), isFalse);
        expect(code(shared).contains(key), isFalse);
      }
    });

    test('the method channel is spelled the same in Dart and Swift', () {
      // Silent when wrong: `MissingPluginException` lands in the store's catch
      // and the wrist simply stops updating, exactly the way a wrong
      // `androidProvider` stops the launcher repainting.
      expect(code(phoneLink), contains('"${HomeWidgetStore.watchChannel}"'));
      expect(code(phoneLink), contains('"${HomeWidgetStore.watchSyncMethod}"'));
      expect(dartStore, contains("watchChannel = '${HomeWidgetStore.watchChannel}'"));
    });

    test('a landed tap is announced to Dart on BOTH delivery paths', () {
      // The phone folds the outbox into the journey on resume and on launch,
      // and a wrist is the one surface that can hand it a tap between those.
      // A relayed tap that is not announced sits in the outbox with Home
      // saying zero until the app is closed and reopened (Sep 8 2026,
      // docs/10 §36). Both the reachable path (`didReceiveMessage`) and the
      // background one (`didReceiveUserInfo`) land taps, so both must say so.
      expect(code(phoneLink), contains('"${HomeWidgetStore.watchQueuedMethod}"'));
      expect(
        dartStore,
        contains("watchQueuedMethod = '${HomeWidgetStore.watchQueuedMethod}'"),
      );
      final announced = RegExp(
        r'announce\(landed: landed\)',
      ).allMatches(code(phoneLink)).length;
      expect(announced, 2, reason: 'one per WCSession delivery path');
      // A platform channel is main-thread only; WatchConnectivity calls back
      // on its own queue.
      expect(code(phoneLink), contains('invokeMethod(Self.methodQueued'));
      expect(code(phoneLink), contains('DispatchQueue.main.async'));
      // And Dart listens on the same channel it sends on.
      expect(dartStore, contains('setMethodCallHandler'));
    });

    test('a background delivery is left to the resume drain', () {
      // Both WCSession paths can wake a backgrounded app that still has an
      // engine. Announcing there would run the Firestore write and its 3 s ack
      // wait in the background — where iOS suspends the process before the
      // cursor lands, replaying the tap on the next launch — and spend
      // WidgetKit's daily reload budget on every wrist tap.
      expect(code(phoneLink), contains('applicationState == .active'));
      // And a `queued` nobody was listening for is logged as such, not as a
      // delivery.
      expect(code(phoneLink), contains('FlutterMethodNotImplemented'));
    });

    test('the mirror names the wrist seq it reflects, and the ledger is phone-only', () {
      // The wrist used to infer "the phone has drained my taps" from a mark
      // taken at hand-over. Draining within the second broke that guess both
      // ways (docs/10 §36), so the phone now says which seq the mirror already
      // counts. `ios_watch_contract_test.dart` plays every case; this pins the
      // shape: the phone computes it from its own cursor, the watch clamps it
      // to its own seq, and the mark survives only as the fallback for a phone
      // built before the field existed.
      expect(code(wire), contains('static func reflected(in defaults: UserDefaults'));
      expect(code(wire), contains('WatchKeys.fieldReflected] = reflected'));
      expect(code(wire), contains('min(reflected, defaults.integer(forKey: CirrusKeys.seq))'));
      expect(code(wire), contains('forKey: WatchKeys.relayed'));
      // Nothing on the watch writes the ledger — one writer per key.
      expect(code(link).contains('WatchKeys.relayed'), isFalse);
      expect(code(view).contains('WatchKeys.relayed'), isFalse);
    });

    test('the mirror field the watch adds is one Dart writes', () {
      // The same one-directional rule `ios_widget_test.dart` applies: anything
      // Swift reads out of the document has to be something `buildMirror`
      // actually puts there.
      final reads = RegExp(r'(?:json|copy)\["([a-zA-Z]{2,})"\]')
          .allMatches(code(shared))
          .map((m) => m.group(1)!)
          .toSet();
      expect(reads, containsAll(['sid', 'watchOpenPhone']));
      for (final field in ['sid', 'watchOpenPhone']) {
        expect(dartMirror, contains("'$field'"));
      }
    });
  });

  group('the wrist forgets what it must forget', () {
    test('only a DIFFERENT account empties the wrist', () {
      // `hasJourney: false` must not be the trigger. Signing out pushes exactly
      // that mirror — but so does every cold start of the phone app, because
      // `_WidgetSync` builds its first mirror before `restoreSession` answers.
      // Wiping on it threw away un-handed-over taps on every launch
      // (docs/10 §29).
      final apply = code(wire);
      expect(
        apply,
        contains(
          'let changed = !stored.isEmpty && !incoming.sid.isEmpty && stored != incoming.sid',
        ),
      );
      expect(apply, contains('if changed { forget(defaults) }'));
      for (final key in [
        'CirrusKeys.outbox',
        'CirrusKeys.cursor',
        'CirrusKeys.seq',
        'WatchKeys.sid',
        'WatchKeys.sent',
        'WatchKeys.mark',
      ]) {
        expect(apply, contains('removeObject(forKey: $key)'));
      }
    });

    test('a handed-over tap keeps counting until the mirror catches up', () {
      // The cursor tracks the MIRROR; `sent` tracks the hand-over. Collapsing
      // the two made the wrist's count drop back a second after a tap, because
      // the phone queues a relayed tap and only folds it into the journey on its
      // next drain — which can be hours away.
      final wireCode = code(wire);
      expect(wireCode, contains('static let sent = "lp.watchSent"'));
      expect(wireCode, contains('static let mark = "lp.watchMark"'));
      // The ack records the hand-over and takes a mark — it does not move the
      // cursor.
      expect(wireCode, contains('defaults.set(seq, forKey: WatchKeys.sent)'));
      // Exactly three mentions, and they are the only three there may be: the
      // phone naming the seq its mirror reflects (the rule since Sep 8 2026),
      // the mark check that advances it for a phone built before that field,
      // and `forget` clearing it. Nothing else on the wrist may move the
      // cursor — and the receipt in particular never does.
      expect(wireCode, contains('defaults.set(String(target), forKey: CirrusKeys.cursor)'));
      expect(
        wireCode,
        contains(
          'defaults.set(String(defaults.integer(forKey: WatchKeys.sent)), forKey: CirrusKeys.cursor)',
        ),
      );
      expect(wireCode, contains('removeObject(forKey: CirrusKeys.cursor)'));
      expect(
        RegExp(r'forKey: CirrusKeys\.cursor').allMatches(wireCode).length,
        3,
        reason: 'the cursor has exactly one writer on the wrist',
      );
      // And the send floor follows the hand-over, so nothing is re-sent while
      // the cursor lags — except deliberately, when retrying.
      expect(
        wireCode,
        contains('let floor = retrying ? cursor : max(cursor, defaults.integer(forKey: WatchKeys.sent))'),
      );
      // A no-journey mirror carries no count, so it may not move the cursor.
      expect(wireCode, contains('if !changed, incoming.hasJourney {'));
    });

    test('a hand-over the mirror never confirmed is asked again', () {
      // `sent` can be advanced by a `didFinish` that lied — watched happen on a
      // simulator. From the wrist an unconfirmed hand-over is indistinguishable
      // from one that never arrived, so a foreground with the phone reachable
      // asks again from the cursor. The id dedupe makes that free; a stranded
      // puff is not.
      expect(code(link), contains('flush(retrying: true)'));
      // Only over the channel that answers — queueing a second copy behind one
      // already in doubt helps nobody.
      expect(
        code(link),
        contains('WatchWire.tapPayload(retrying: retrying && session.isReachable)'),
      );
      // And the ordinary tap path does not retry.
      expect(code(link), contains('flush()'));
    });

    test('the phone refuses a batch minted against another account', () {
      final relay = code(wire);
      expect(relay, contains('guard mine.hasJourney else { return 0 }'));
      expect(relay, contains('sid != mine.sid { return 0 }'));
      // And an id already applied cannot be applied twice.
      expect(relay, contains('!seen.contains(id)'));
      expect(relay, contains('seen.append(id)'));
      expect(relay, contains('WatchKeys.seenLimit'));
    });

    test('the cursor moves only on an acknowledged transfer', () {
      // Fails toward "handed over twice", which the id dedupe absorbs, rather
      // than "silently lost", which nothing can recover.
      expect(code(link), contains('didFinish userInfoTransfer'));
      expect(code(link), contains('if error != nil { return }'));
      expect(
        code(link),
        contains('guard let seq = WatchWire.through(userInfoTransfer.userInfo)'),
      );
      expect(code(link), contains('WatchWire.markHandedOver(through: seq)'));
      // One transfer in flight at a time, so five quick taps do not wake the
      // phone five times over the same events.
      expect(
        code(link),
        contains('guard session.outstandingUserInfoTransfers.isEmpty else { return }'),
      );
      // Two callers, one per route: the receipt when the phone was reachable,
      // and `didFinish` for the durable transfer when it was not. Nowhere else.
      expect(
        RegExp('markHandedOver').allMatches(code(link)).length,
        2,
      );
      // An unreadable reply is not an acknowledgement: the taps stay queued for
      // a build that can read it, rather than being dropped.
      expect(code(link), contains('unreadable receipt, keeping the queue'));
    });

    test('taps prefer a receipt the phone actually wrote', () {
      // `didFinish` is the TRANSPORT's opinion, and on paired simulators it
      // fires with no error for payloads the phone never receives (docs/10 §29).
      // A `sendMessage` reply is an application-level receipt: the phone opened
      // the envelope and named the seq it took. That is what the cursor moves
      // on whenever the phone is reachable.
      final l = code(link);
      expect(l, contains('guard session.isReachable else {'));
      expect(l, contains('session.transferUserInfo(payload)'));
      expect(l, contains('WatchWire.acknowledged(reply)'));
      // A send error falls back to the durable route rather than dropping taps —
      // reachability is a snapshot and the phone can leave between the two.
      expect(l, contains('self?.handOver(payload)'));
      // The phone answers a batch with a receipt, and a request with the mirror.
      expect(code(phoneLink), contains('WatchWire.isTapBatch(message)'));
      expect(code(phoneLink), contains('WatchWire.receipt(for: message)'));
      // And the mirror travels latest-wins, so a stale one is never delivered
      // after a fresh one.
      expect(code(phoneLink), contains('updateApplicationContext(payload)'));
    });
  });

  group('no journey means a message, never a counter', () {
    // The rule CLAUDE.md says every widget surface inherits. A watch is on a
    // wrist all day in front of whoever glances at it, so this is the leak in
    // its most public form.
    test('the screen gates on hasJourney before it draws anything', () {
      expect(code(view), contains('if link.mirror.hasJourney'));
      // And the state order is mirror-derived, not launch-scoped: a cached
      // mirror must not show "waiting" on every cold start.
      expect(code(view), contains('link.mirror.copyEmptyTitle.isEmpty'));
      expect(code(view), contains('WaitingCard()'));
      expect(code(view), contains('EmptyCard(mirror: link.mirror)'));
    });

    test('the complication draws no number without a journey', () {
      expect(code(face), contains('if !entry.mirror.hasJourney'));
      // And it never divides by a limit of zero, which would paint a full ring
      // on exactly the days a single puff puts someone over.
      expect(code(face), contains('guard entry.today.knowsLimit, entry.today.limit > 0'));
    });

    test('the tap refusal comes from the shared queue, not a local copy', () {
      // One implementation of "may this tap be taken", shared with both
      // home-screen widgets.
      expect(code(link), contains('CirrusOutbox.append(delta: delta) != nil'));
      expect(code(outbox), contains('guard mirror.hasJourney else { return nil }'));
      // A refusal is said out loud rather than silently doing nothing.
      expect(code(link), contains('play(.failure)'));
      expect(code(link), contains('play(.click)'));
    });

    test('the watch app cannot run without the phone app', () {
      final plist = read('$app/Info.plist');
      expect(
        plist.contains('<key>WKRunsIndependentlyOfCompanionApp</key>'),
        isFalse,
      );
      expect(plist, contains('<key>WKApplication</key>'));
      expect(plist, contains('<string>$hostBundleId</string>'));
      expect(plist, contains('WKCompanionAppBundleIdentifier'));
    });
  });

  group('one puff per tap, and one day number', () {
    test('there is no ramp and no multiplier on the wrist', () {
      // 18 taps once became 68 logged puffs. `CirrusOutbox.append` clamps the
      // magnitude, and nothing here hands it anything but 1.
      expect(code(view), contains('link.log(delta: 1)'));
      expect(code(view), contains('link.log(delta: -1)'));
      expect(
        RegExp(r'log\(delta: (?!-?1\b)').hasMatch(code(view)),
        isFalse,
      );
      expect(code(outbox), contains('let step = delta > 0 ? 1 : -1'));
    });

    test('the day line is the clamped one, from the shared engine', () {
      // Any rule Home applies to the day number applies to every surface.
      expect(code(view), contains('link.today.dayLabel(link.mirror)'));
      expect(code(face), contains('entry.today.dayLabel(entry.mirror)'));
      // Neither recomputes it.
      for (final source in [code(view), code(face), code(week), code(breathe)]) {
        expect(source.contains('totalDays'), isFalse);
      }
    });

    test('a stale streak is not asserted as a number', () {
      // `mirror.streak` is whatever the phone computed at push time. The flame
      // still burns on a day-old mirror; the count beside it does not.
      expect(code(view), contains('link.mirror.dayKey == cirrusTodayKey()'));
      expect(code(view), contains('if fresh, mirror.streak > 0'));
    });

    test('both controls fit on the smallest watch, without scrolling', () {
      // Stacked full-width buttons measured ~219pt against ~214pt of usable
      // height on a 46mm — and a 41mm is 14pt shorter — so the `−` sat below
      // the fold on every watch made, half-drawn and untappable. Found by
      // tapping it on a simulator and getting nothing (docs/10 §29).
      final v = code(view);
      expect(v, contains('HStack(spacing: 8) {'));
      // The `−` is a fixed column and the `+` takes the rest, which is what
      // bounds the row's height to one button instead of two.
      expect(v, contains('.frame(width: 62)'));
      expect(
        RegExp(r'RemoveButton\(enabled:').allMatches(v).length,
        1,
        reason: 'one remove control, in the row',
      );
    });

    test('the controls are labelled in words for VoiceOver', () {
      // The same two labels the home-screen widget uses, so one UI test
      // vocabulary covers every surface.
      expect(code(view), contains('accessibilityLabel("Log a puff")'));
      expect(code(view), contains('accessibilityLabel("Remove a puff")'));
    });
  });

  group('the Xcode project embeds the watch app', () {
    // `tool/ios_watch_target.rb` writes this; a `git checkout` of the pbxproj
    // after `flutter_launcher_icons` (which pubspec.yaml prescribes) is how it
    // silently disappears. Re-running the script puts it back.
    Iterable<String> blocks(String isa) => RegExp(
      r'[0-9A-F]{24} /\* [^*]+ \*/ = \{\n\s+isa = ' + isa + r';.*?\n\t\t\};',
      dotAll: true,
    ).allMatches(pbxproj).map((m) => m.group(0)!);

    final targets = blocks('PBXNativeTarget');
    final watchApp = targets.firstWhere(
      (b) => b.contains('name = CirrusWatch;'),
      orElse: () => '',
    );
    final watchExt = targets.firstWhere(
      (b) => b.contains('name = CirrusWatchComplication;'),
      orElse: () => '',
    );
    final runner = targets.firstWhere(
      (b) => b.contains('name = Runner;'),
      orElse: () => '',
    );

    List<String> configsFor(String bundleId) => blocks('XCBuildConfiguration')
        .where((b) => b.contains('PRODUCT_BUNDLE_IDENTIFIER = $bundleId;'))
        .toList();

    test('both targets exist, with the right product types', () {
      expect(watchApp, isNotEmpty);
      expect(
        watchApp,
        contains('productType = "com.apple.product-type.application";'),
      );
      expect(watchApp, contains('/* CirrusWatch.app */'));
      expect(watchExt, isNotEmpty);
      expect(
        watchExt,
        contains('productType = "com.apple.product-type.app-extension";'),
      );
      expect(watchExt, contains('/* CirrusWatchComplication.appex */'));
    });

    test('the bundle ids nest under the host, then under the watch app', () {
      final host = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);')
          .allMatches(pbxproj)
          .map((m) => m.group(1)!)
          .reduce((a, b) => a.length <= b.length ? a : b);
      expect(host, hostBundleId);
      expect(appBundleId, startsWith('$host.'));
      expect(extBundleId, startsWith('$appBundleId.'));
      expect(script, contains("'$hostBundleId'"));
    });

    test('each target has Debug, Profile and Release on Generated.xcconfig', () {
      for (final bundleId in [appBundleId, extBundleId]) {
        final configs = configsFor(bundleId);
        final names = configs
            .map((b) => RegExp(r'name = (\w+);').firstMatch(b)!.group(1)!)
            .toSet();
        expect(names, {'Debug', 'Profile', 'Release'}, reason: bundleId);
        for (final config in configs) {
          // FLUTTER_BUILD_NAME / FLUTTER_BUILD_NUMBER are defined nowhere
          // else, and a watch app whose version does not match the host's is
          // rejected on upload — ITMS-90473, exactly as the widget's would be.
          expect(config, contains('/* Generated.xcconfig */;'));
          // Never the Pods xcconfigs: their OTHER_LDFLAGS would drag every iOS
          // Firebase pod onto a watchOS link line.
          expect(config.contains('Pods-'), isFalse);
          expect(config, contains('SDKROOT = watchos;'));
          expect(
            config,
            contains('WATCHOS_DEPLOYMENT_TARGET = $deploymentTarget;'),
          );
          expect(config, contains('TARGETED_DEVICE_FAMILY = 4;'));
          expect(config, contains('SUPPORTED_PLATFORMS = "watchsimulator watchos";'));
          // Both are embedded, so neither may install at the top level.
          expect(config, contains('SKIP_INSTALL = YES;'));
          expect(config, contains('GENERATE_INFOPLIST_FILE = NO;'));
          // Explicit, so Xcode 26's Swift 6 / main-actor defaults never apply.
          expect(config, contains('SWIFT_VERSION = 5.0;'));
          expect(config, contains('CODE_SIGN_STYLE = Automatic;'));
        }
      }
      // Only the app has an icon; the extension would look for one in a
      // catalog it does not have.
      for (final config in configsFor(appBundleId)) {
        expect(config, contains('ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;'));
        expect(config, contains('INFOPLIST_FILE = CirrusWatch/Info.plist;'));
      }
      for (final config in configsFor(extBundleId)) {
        expect(config.contains('ASSETCATALOG_COMPILER_APPICON_NAME'), isFalse);
      }
    });

    test('Runner copies the watch app into Watch/, spec 16', () {
      // Not PlugIns. An .app under PlugIns/ builds and installs and Apple's
      // validator does not recognise it as watch content at all.
      expect(runner, contains('/* Embed Watch Content */,'));
      expect(
        blocks('PBXTargetDependency').any((b) => b.contains('/* CirrusWatch */;')),
        isTrue,
      );
      final embed = blocks('PBXCopyFilesBuildPhase').firstWhere(
        (b) => b.contains('name = "Embed Watch Content";'),
        orElse: () => '',
      );
      expect(embed, contains('dstSubfolderSpec = 16;'));
      expect(embed, contains(r'dstPath = "$(CONTENTS_FOLDER_PATH)/Watch";'));
      expect(embed, contains('/* CirrusWatch.app in Embed Watch Content */'));
    });

    test('the watch app copies the complication into its own PlugIns', () {
      expect(watchApp, contains('/* Embed Foundation Extensions */,'));
      expect(
        blocks('PBXTargetDependency')
            .any((b) => b.contains('/* CirrusWatchComplication */;')),
        isTrue,
      );
    });

    test('every Swift file in each folder compiles into its target', () {
      for (final folder in [app, complication]) {
        final sources = Directory(folder)
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .where((n) => n.endsWith('.swift'));
        expect(sources, isNotEmpty, reason: folder);
        for (final name in sources) {
          expect(pbxproj, contains('/* $name in Sources */'), reason: name);
        }
      }
      // The shared contract has FOUR readers and exactly one copy: the
      // home-screen widget it was written for, the watch app, the complication
      // and Runner (which relays taps in the background, with no Flutter engine
      // up). One file reference added to four targets — a fork of it is how the
      // client and server streak engines drifted.
      expect(
        RegExp(r'/\* CirrusShared\.swift in Sources \*/,').allMatches(pbxproj).length,
        4,
      );
      expect(
        RegExp(r'/\* CirrusOutbox\.swift in Sources \*/,').allMatches(pbxproj).length,
        4,
      );
      expect(
        RegExp(r'/\* WatchWire\.swift in Sources \*/,').allMatches(pbxproj).length,
        2,
      );
      expect(pbxproj, contains('/* CirrusWatchLink.swift in Sources */'));
      // Never a plist or an entitlements file in a build phase.
      expect(
        RegExp(
          r'\* (Info\.plist|CirrusWatch\.entitlements|CirrusWatchComplication\.entitlements) in (Sources|Resources)',
        ).hasMatch(pbxproj),
        isFalse,
      );
    });

    test('the Runner scheme builds neither of them directly', () {
      // Flutter parses `xcodebuild -showBuildSettings` last-wins and must only
      // ever see Runner's block — a watch target leaking into that parse would
      // hand it `SDKROOT = watchos`. Measured after this landed: the command
      // still emits exactly one "Build settings for action" block.
      final scheme = read(
        'ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme',
      );
      expect(scheme.contains('CirrusWatch'), isFalse);
    });

    test('both Info.plists take their version from Flutter', () {
      for (final folder in [app, complication]) {
        final plist = read('$folder/Info.plist');
        expect(plist, contains(r'$(FLUTTER_BUILD_NAME)'), reason: folder);
        expect(plist, contains(r'$(FLUTTER_BUILD_NUMBER)'), reason: folder);
      }
      expect(read('$complication/Info.plist'), contains('com.apple.widgetkit-extension'));
    });

    test('every entitlements file names the one App Group', () {
      final group = RegExp(r"appGroupId = '([^']+)'")
          .firstMatch(dartStore)
          ?.group(1);
      expect(group, isNotNull);
      // On the watch this resolves to a different store than the phone's — an
      // App Group is per-device — and the name is shared only so the contract
      // compiles unchanged on both sides.
      expect(read('$app/CirrusWatch.entitlements'), contains(group!));
      expect(
        read('$complication/CirrusWatchComplication.entitlements'),
        contains(group),
      );
    });

    test('the watch icon is the app icon, and stays it', () {
      // Copied rather than regenerated, so this is what catches it going stale
      // after `dart run flutter_launcher_icons` changes the art.
      final phone = File(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
      ).readAsBytesSync();
      final watch = File(
        '$app/Assets.xcassets/AppIcon.appiconset/Icon-Watch-1024.png',
      ).readAsBytesSync();
      expect(watch, equals(phone));
      final contents = read('$app/Assets.xcassets/AppIcon.appiconset/Contents.json');
      expect(contents, contains('"platform" : "watchos"'));
      expect(contents, contains('"size" : "1024x1024"'));
    });
  });

  group('the palette is Midnight Ember, byte for byte', () {
    // watchOS has no light mode, and a SwiftUI view outside the Flutter engine
    // cannot read `context.lp` — the same documented deviation the iOS widget
    // carries. The hexes are comments so they stay diffable against the Dart
    // tokens; this checks the comment against the palette AND the components
    // against the comment, so neither can drift alone.
    final midnight = RegExp(
      r'const LpColors\.midnight\(\).*?(?=const LpColors\.)',
      dotAll: true,
    ).firstMatch(read('lib/app/theme/lp_colors.dart'))?.group(0);

    test('every annotated hex is an Ember token', () {
      expect(midnight, isNotNull);
      final colours = RegExp(
        r'Color\(red: ([\d.]+), green: ([\d.]+), blue: ([\d.]+)\) // #([0-9A-F]{6})',
      ).allMatches(palette).toList();
      expect(colours.length, greaterThanOrEqualTo(8));
      for (final match in colours) {
        final hex = match.group(4)!;
        expect(
          midnight,
          contains('0xFF$hex'),
          reason: '#$hex is not a Midnight Ember token',
        );
        final expected = [
          int.parse(hex.substring(0, 2), radix: 16),
          int.parse(hex.substring(2, 4), radix: 16),
          int.parse(hex.substring(4, 6), radix: 16),
        ];
        for (var i = 0; i < 3; i++) {
          final component = (double.parse(match.group(i + 1)!) * 255).round();
          expect(
            (component - expected[i]).abs(),
            lessThanOrEqualTo(1),
            reason: 'component ${i + 1} of #$hex is off',
          );
        }
      }
    });

    test('no raw hex anywhere but the palette', () {
      for (final source in [view, entry, link, face, week, breathe]) {
        expect(
          RegExp(r'Color\(red:').hasMatch(code(source)),
          isFalse,
          reason: 'colours belong in WatchPalette.swift',
        );
      }
      // And the face wears no palette at all: a watch face tints its own
      // complications, and the person chose that tint.
      expect(face.contains('import SwiftUI'), isTrue);
      expect(code(face).contains('.cw'), isFalse);
    });
  });

  group('the two new screens draw, and never compute', () {
    test('the week card reads verdicts it was given', () {
      // The bars are counts; which day was HARD and which was BEST are
      // `WeekTrend` answers with real rules, and they arrive decided.
      // The verdicts are applied in `cirrusWeek` — shared, Foundation-only,
      // and executed against Dart by `ios_watch_contract_test`. The VIEW just
      // asks for bars, which is the layering this pins.
      expect(code(shared), contains('mirror.weekHardest'));
      expect(code(shared), contains('mirror.weekBest'));
      expect(code(week), contains('cirrusWeek(link.mirror, today: link.today)'));
      // Money is quoted, never derived: the rule behind it (an unconfirmed day
      // is unknown, never a saving) may have exactly one implementation.
      expect(code(week), contains('mirror.savedText'));
      for (final forbidden in ['isConfirmed', 'savedLifetime', 'DateFormatter']) {
        expect(
          code(week).contains(forbidden),
          isFalse,
          reason: '$forbidden is the phone\'s job',
        );
      }
      // The percent is a template filled with the phone's own signed text.
      expect(code(week), contains('String(format: link.mirror.copyVsLast'));
    });

    test('an absent comparison draws nothing, and 0 still draws', () {
      // `weekVsLast` is the one Optional in the mirror, and the view has to
      // unwrap it rather than default it: 0 means "flat", which is good news
      // and volt, while absent means there is nothing honest to say.
      expect(code(week), contains('if let vsLast = link.mirror.weekVsLast'));
      expect(code(week), contains('vsLast <= 0 ? Color.cwVolt : Color.cwEmber'));
      expect(
        RegExp(r'weekVsLast\s*\?\?').hasMatch(code(week)),
        isFalse,
        reason: 'defaulting it would claim an improvement nobody made',
      );
      // And the decoder must not default it either.
      expect(
        RegExp(r'weekVsLast = json\["weekVsLast"\] as\? Int\s*\?\?')
            .hasMatch(code(shared)),
        isFalse,
      );
    });

    test('the breathing screen is a pacer, and touches nothing else', () {
      // The founder's decision, made executable: it logs nothing, queues
      // nothing and tells no server. Without this the next contributor who
      // thinks a survived breath should count turns `CirrusOutbox` — a puff
      // delta clamped to ±1 — into a general command queue, which is the one
      // thing this design set out to avoid.
      for (final forbidden in ['CirrusOutbox', 'log(delta:', 'WatchWire.tapPayload']) {
        expect(
          code(breathe).contains(forbidden),
          isFalse,
          reason: 'the wrist breathe screen records nothing',
        );
      }
      // And it asserts no journey number — which is what lets it own a clock
      // without inventing anything.
      for (final forbidden in ['today.count', 'today.limit', 'mirror.puffs', 'mirror.streak']) {
        expect(code(breathe).contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('every new surface inherits the no-journey rule', () {
      for (final source in [code(week), code(breathe)]) {
        expect(source, contains('link.mirror.hasJourney'));
        expect(source, contains('EmptyCard(mirror: link.mirror)'));
        expect(source, contains('WaitingCard()'));
      }
    });

    test('the craving clock counts UP, and its key never leaves the wrist', () {
      // The mock counted DOWN to a peak. Nothing on either device can know
      // when a particular craving peaks, so the app's own elapsed line ships.
      expect(code(breathe), contains('copyCravingTimerLate'));
      expect(code(breathe), contains('cirrusTimerText(elapsed)'));
      // Watch-only, like the other native keys: never in the shared contract
      // and never in Dart.
      expect(code(wire), contains('lp.watchBreatheStart'));
      for (final source in [code(shared), dartMirror, dartStore]) {
        expect(source.contains('lp.watchBreatheStart'), isFalse);
      }
    });

    test('the pacer is Flutter\'s cubic, and stays compilable by the harness', () {
      // Foundation only — that absence is what lets `swiftc` compile it into
      // the parity harness with no simulator.
      expect(pacer, contains('import Foundation'));
      for (final forbidden in ['import SwiftUI', 'import WatchKit']) {
        expect(pacer.contains(forbidden), isFalse, reason: forbidden);
      }
      // The constants ARE the contract; `ios_watch_contract_test` proves them
      // against Dart on a Mac, and these pin them on Linux CI too.
      for (final constant in ['0.445', '0.05', '0.55', '0.95', '0.001', '0.4']) {
        expect(code(pacer), contains(constant), reason: constant);
      }
      // `t % 1` in Dart is non-negative; Swift's remainder keeps the sign.
      expect(code(pacer), contains('t - floor(t)'));
      expect(
        code(pacer).contains('truncatingRemainder'),
        isFalse,
        reason: 'it would put a backwards clock mid-exhale',
      );
    });

    test('the second and third pages keep the first one\'s lifecycle', () {
      expect(code(entry), contains('TabView'));
      expect(code(entry), contains('WatchWeekView(link: link)'));
      expect(code(entry), contains('WatchBreatheView(link: link)'));
      // Gated: a signed-out wrist is one card you cannot page away from.
      expect(code(entry), contains('link.mirror.hasJourney'));
      // Exactly one of each, on the container. A hook on a lazily-built page
      // re-fires on every swipe back, and `awake()` pulls and flushes.
      expect(RegExp(r'\.onAppear').allMatches(code(entry)).length, 1);
      expect(RegExp(r'\.onChange\(of: phase\)').allMatches(code(entry)).length, 1);
      expect(code(entry), contains('link.start()'));
      expect(code(entry), contains('link.awake()'));
    });

    test('one oxygen token is enough, and the palette says why', () {
      // The phone's orb and ring are `oxygen` and `oxygenText`, which are the
      // same hex in Midnight Ember — so they collapse to one on the wrist. If
      // a palette change ever splits them, fail HERE rather than mis-tinting a
      // wrist nobody is looking at in a test.
      final colors = read('lib/app/theme/lp_colors.dart');
      final midnight = RegExp(
        r'LpColors\.midnight\(\)[\s\S]*?\n  \)',
      ).firstMatch(colors)?.group(0) ?? colors;
      expect(midnight, contains('oxygen: const Color(0xFF6EE7FF)'));
      expect(midnight, contains('oxygenText: const Color(0xFF6EE7FF)'));
      expect(code(palette), contains('cwOxygen'));
    });
  });

  group('the brand mark is on the wrist, and is the shipped one', () {
    test('both no-journey cards carry it', () {
      // The founder caught this missing: a signed-out wrist showed words with
      // no mark at all, where the store frame shows the ring above them.
      expect(code(view), contains('struct CirrusMark'));
      final cards = RegExp(
        r'struct (EmptyCard|WaitingCard): View \{[\s\S]*?\n\}',
      ).allMatches(code(view)).map((m) => m.group(0)!).toList();
      expect(cards, hasLength(2));
      for (final card in cards) {
        expect(card, contains('CirrusMark()'));
      }
    });

    test('it is the real artwork, byte for byte, at every scale', () {
      // Two earlier attempts were wrong: an arc traced off these measurements
      // was not the logo, and the full monochrome mark was the logo but not
      // this treatment — it carries the vapour wisp the store frame drops.
      // These are the shipped `ic_stat_cirrus` densities, pinned by content so
      // the watch's copy can never drift from the brand's.
      const pairs = {
        'ic_stat_cirrus.png': 'drawable-xhdpi',
        'ic_stat_cirrus@2x.png': 'drawable-xxhdpi',
        'ic_stat_cirrus@3x.png': 'drawable-xxxhdpi',
      };
      pairs.forEach((bundled, density) {
        expect(
          File('$app/Assets.xcassets/CirrusMark.imageset/$bundled').readAsBytesSync(),
          equals(
            File('android/app/src/main/res/$density/ic_stat_cirrus.png')
                .readAsBytesSync(),
          ),
          reason: '$bundled must be the shipped mark',
        );
      });
      // The wisp-carrying launcher mark is NOT what this surface wears.
      expect(
        File('$app/Assets.xcassets/CirrusMark.imageset/cirrus_monochrome.png')
            .existsSync(),
        isFalse,
      );
      final contents = read('$app/Assets.xcassets/CirrusMark.imageset/Contents.json');
      expect(contents, contains('"template-rendering-intent" : "template"'));
      expect(code(view), contains('.renderingMode(.template)'));
      expect(code(view), contains('.foregroundStyle(Color.cwVolt)'));
    });

    test('the no-mirror card says the same thing, never the app name', () {
      // It used to read "Cirrus" over "…to sync your plan." — the app
      // introducing itself, where the store frame gives an instruction. A
      // wrist cannot tell "no journey" from "no mirror yet" and should not
      // have to: the answer is the same either way.
      final waiting = RegExp(
        r'struct WaitingCard: View \{[\s\S]*?\n\}',
      ).firstMatch(code(view))!.group(0)!;
      expect(waiting, contains('Text("Start your plan")'));
      expect(waiting, contains('Text("Open Cirrus on your iPhone")'));
      expect(waiting.contains('Text("Cirrus")'), isFalse);
      // And it matches the English the ARB ships for the same two lines, so
      // the fallback cannot drift from the copy it stands in for.
      final arb = jsonDecode(read('lib/l10n/app_en.arb')) as Map<String, dynamic>;
      expect(waiting, contains('Text("${arb['widgetEmptyTitle']}")'));
      expect(waiting, contains('Text("${arb['widgetWatchOpenPhone']}")'));
    });

    test('nothing redraws the mark by hand', () {
      // The approximation that shipped once and was wrong.
      expect(code(view).contains('struct MarkArc'), isFalse);
      expect(code(view).contains('gapStart'), isFalse);
    });
  });

  group('the three defects the review found stay fixed', () {
    test('an older mirror does not draw a bare 0 as the reader\'s own', () {
      // A phone build older than these screens writes a valid
      // `hasJourney: true` document with none of their fields, and the watch
      // keeps its last mirror across an app update — so this is the ordinary
      // first launch after updating, not an edge case. It drew a blank title,
      // no bars and `0` under a blank label at somebody with forty cravings
      // beaten. Gated in BOTH places.
      expect(code(entry), contains('!link.mirror.weekPuffs.isEmpty'));
      expect(code(entry), contains('!link.mirror.copyBreatheIn.isEmpty'));
      expect(code(week), contains('!link.mirror.weekPuffs.isEmpty'));
    });

    test('the craving clock is on the sign-out forget list', () {
      // Device-scoped `UserDefaults` holding account-shaped state — the same
      // trap `celebratedMilestones` set on the phone. Left behind, the next
      // person to open the page is told they are ten minutes into a craving
      // they never had.
      final forget = RegExp(
        r'static func forget\(_ defaults: UserDefaults\) \{[\s\S]*?\n    \}',
      ).firstMatch(code(wire))!.group(0)!;
      expect(forget, contains('WatchKeys.breatheStartedAt'));
      // And every other key it already forgot.
      for (final key in ['outbox', 'cursor', 'seq', 'sid', 'sent', 'mark']) {
        expect(forget, contains(key), reason: key);
      }
    });

    test('the breath starts at an inhale, whatever the craving clock says', () {
      // `startedAt` is persisted and resumes (a wrist lowered mid-hold must
      // still read 0:40). The BREATH must not: sharing one anchor opened a
      // second craving two-thirds through an inhale, or partway down an
      // exhale — telling somebody to breathe out as they arrived.
      expect(code(breathe), contains('cycleAnchor = Date()'));
      expect(
        code(breathe),
        contains('date.timeIntervalSince(cycleAnchor)'),
        reason: 'the cycle must not be anchored on the craving clock',
      );
      expect(
        RegExp(r'cycleFraction[\s\S]{0,120}timeIntervalSince\(startedAt\)')
            .hasMatch(code(breathe)),
        isFalse,
      );
      // The craving line still reads the persisted clock.
      expect(code(breathe), contains('date.timeIntervalSince(startedAt)'));
    });
  });
}
