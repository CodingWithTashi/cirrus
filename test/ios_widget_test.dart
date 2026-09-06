import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/pending_puffs.dart';
import 'package:last_puff/data/stores/widget_mirror.dart';

/// The iOS half of the home-screen widget, pinned the way
/// `android_widget_test.dart` pins the Android half: as string tests over the
/// native files, because CI runs `flutter test` on Linux and never compiles a
/// line of Swift or opens the Xcode project.
///
/// Every failure below is silent on a device. A key renamed on one side blanks
/// the widget and throws nothing; an extension the project does not embed
/// builds, installs and runs a perfectly working app whose widget simply never
/// appears in the gallery; a build configuration missing its xcconfig link
/// archives, uploads, and is rejected by App Store Connect minutes later.
void main() {
  const folder = 'ios/CirrusWidget';

  String read(String path) => File(path).readAsStringSync();

  /// Comments stripped, so a doc comment that names the very thing an
  /// assertion forbids does not fail it.
  String code(String swift) => swift
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//.*'), '');

  final shared = read('$folder/CirrusShared.swift');
  final outbox = read('$folder/CirrusOutbox.swift');
  final intent = read('$folder/LogPuffIntent.swift');
  final widget = read('$folder/CirrusWidget.swift');
  final pbxproj = read('ios/Runner.xcodeproj/project.pbxproj');
  final dartStore = read('lib/data/api/widget_store.dart');
  final dartMirror = read('lib/data/stores/widget_mirror.dart');
  final dartOutbox = read('lib/data/stores/pending_puffs.dart');

  Set<String> keysIn(String source) => RegExp(
    r'''["'](lp\.[a-zA-Z]+)["']''',
  ).allMatches(source).map((m) => m.group(1)!).toSet();

  group('the wire contract is the same in Swift and Dart', () {
    test('every store key Swift names is one Dart names, and vice versa', () {
      // The four keys and their single-writer rule are documented on
      // `PendingPuffs`; this is the only thing that stops one side renaming a
      // key and the widget going blank with nothing in any log.
      final swift = keysIn(code(shared));
      final dart = keysIn(code(dartOutbox)).union(keysIn(code(dartMirror)));
      expect(swift, isNotEmpty);
      expect(swift, equals(dart));
      expect(swift, containsAll([WidgetMirror.key, PendingPuffs.outboxKey]));
      expect(swift, containsAll([PendingPuffs.cursorKey, PendingPuffs.seqKey]));
    });

    test('schema version and queue ceiling match', () {
      expect(
        code(shared),
        contains('static let schema = ${PendingPuffs.schemaVersion}'),
      );
      expect(WidgetMirror.schemaVersion, PendingPuffs.schemaVersion);
      expect(
        code(outbox),
        contains('static let maxEvents = ${PendingPuffs.maxEvents}'),
      );
    });

    test('every mirror field Swift reads is one Dart writes', () {
      // Field NAMES are cheap to pin, and a rename on one side blanks that
      // value on the widget silently — the day-number bug lived exactly here.
      final reads = RegExp(
        r'(?:json|copy)\["([a-zA-Z]{2,})"\]',
      ).allMatches(code(shared)).map((m) => m.group(1)!).toSet();
      expect(reads, isNotEmpty);
      for (final field in reads) {
        expect(
          dartMirror,
          contains("'$field'"),
          reason: 'Swift reads mirror field "$field" that Dart never writes',
        );
      }
    });

    test('the day line is clamped the way Home clamps it', () {
      // The Android fix of Sep 5 2026 ("day 31" of a 30-day plan on the
      // launcher), applied to the Swift the same day so the two launchers
      // never disagree with Home or each other.
      final src = code(shared);
      expect(src, contains('json["totalDays"] as? Int'));
      expect(src, contains('dayNumber == mirror.totalDays'));
      expect(src, contains('dayNumber - mirror.totalDays'));
      for (final key in ['dayFreedom', 'dayPastOne', 'dayPastOther']) {
        expect(src, contains('copy["$key"]'));
      }
    });

    test('the outbox event Swift writes is the one Dart decodes', () {
      // Single letters, deliberately: the queue is read on every launch.
      for (final field in ['i', 's', 't', 'd']) {
        expect(code(outbox), contains('"$field":'));
        expect(dartOutbox, contains("raw['$field']"));
      }
      // Int, never Double. A fractional `t` used to be dropped by the Dart
      // decoder — and a dropped event never advances the cursor, so it stayed
      // pending for ever and inflated the count on every render.
      expect(
        code(outbox),
        contains('"t": Int(Date().timeIntervalSince1970 * 1000)'),
      );
      expect(code(outbox), contains('"v": CirrusKeys.schema'));
    });

    test('Swift and Dart name the same App Group, in all four places', () {
      final group = RegExp(
        r"appGroupId = '([^']+)'",
      ).firstMatch(dartStore)?.group(1);
      expect(group, isNotNull);
      expect(code(shared), contains('appGroup = "$group"'));
      // The extension's own entitlement, and the HOST app's — a group the app
      // is not entitled to is a container the app cannot write, so the
      // widget shows its empty state for ever.
      expect(read('$folder/CirrusWidget.entitlements'), contains(group!));
      expect(read('ios/Runner/Runner.entitlements'), contains(group));
    });

    test('the intent reloads the kind the Dart side refreshes', () {
      final name = RegExp(
        r"iOSName = '([^']+)'",
      ).firstMatch(dartStore)?.group(1);
      expect(name, isNotNull);
      expect(code(shared), contains('kind = "$name"'));
      expect(
        code(intent),
        contains('reloadTimelines(ofKind: CirrusKeys.kind)'),
      );
      expect(code(widget), contains('kind: CirrusKeys.kind'));
    });
  });

  group('a widget with no journey shows a message, never a counter', () {
    // The founder rule pinned for Android on Sep 5 2026, applied to the Swift
    // half: signed out, freshly installed, account deleted — the empty card,
    // and nothing that looks like anyone's data.
    test('an absent, stale or unreadable mirror reads as no journey', () {
      final src = code(shared);
      expect(src, contains('json["v"] as? Int == CirrusKeys.schema'));
      expect(src, contains('else { return CirrusMirror() }'));
      expect(src, contains('guard json["hasJourney"] as? Bool == true else'));
      expect(src, contains('var hasJourney = false'));
    });

    test('a tap is refused while there is no journey', () {
      expect(
        code(outbox),
        contains('guard mirror.hasJourney else { return nil }'),
      );
    });

    test('a minus at zero is refused', () {
      expect(
        code(outbox),
        contains('if step < 0 && before.count <= 0 { return nil }'),
      );
    });
  });

  group('the tap runs without opening the app', () {
    test('the intent stays in the extension process', () {
      // `openAppWhenRun = false` is the whole feature. And a `static var`
      // here is a global Swift 6 rejects, so it is a `let`.
      expect(code(intent), contains('static let openAppWhenRun: Bool = false'));
      expect(code(intent), contains('@available(iOS 17.0, *)'));
    });

    test('the buttons are labelled in words, and the UI test taps by them', () {
      // A bare glyph reads as "plus" to VoiceOver, and Springboard exposes
      // the label — not any identifier — to XCTest, so the words are also
      // the handle `RunnerUITests` uses. Both sides name them.
      final uiTest = read('ios/RunnerUITests/CirrusWidgetUITests.swift');
      for (final label in ['Log a puff', 'Remove a puff']) {
        expect(code(widget), contains('.accessibilityLabel("$label")'));
        expect(uiTest, contains('"$label"'));
      }
    });

    test('there is no widgetURL: a card tap opens the app by default', () {
      // Android opens MainActivity with a plain explicit intent; nothing
      // routes on the URL. Adding one here would be a second, silent
      // deep-link surface.
      expect(code(widget).contains('widgetURL'), isFalse);
    });
  });

  group('the Xcode project embeds the extension', () {
    // `tool/ios_widget_target.rb` writes this; a `git checkout` of the
    // pbxproj after `flutter_launcher_icons` (which pubspec.yaml prescribes)
    // is the way it silently disappears. Everything below is the difference
    // between a widget and an app that builds, installs, runs and has none.
    const bundleId = 'com.quitvape.lastPuff.CirrusWidget';

    Iterable<String> blocks(String isa) => RegExp(
      r'[0-9A-F]{24} /\* [^*]+ \*/ = \{\n\s+isa = ' + isa + r';.*?\n\t\t\};',
      dotAll: true,
    ).allMatches(pbxproj).map((m) => m.group(0)!);

    final target = blocks(
      'PBXNativeTarget',
    ).firstWhere((b) => b.contains('name = CirrusWidget;'), orElse: () => '');
    final runner = blocks(
      'PBXNativeTarget',
    ).firstWhere((b) => b.contains('name = Runner;'), orElse: () => '');
    final configs = blocks('XCBuildConfiguration')
        .where((b) => b.contains('PRODUCT_BUNDLE_IDENTIFIER = $bundleId;'))
        .toList();

    test('a native app-extension target named CirrusWidget exists', () {
      expect(target, isNotEmpty);
      expect(
        target,
        contains('productType = "com.apple.product-type.app-extension";'),
      );
      expect(target, contains('/* CirrusWidget.appex */'));
    });

    test('its bundle id is prefixed by the host app', () {
      // The host is the one every test and extension bundle id is prefixed
      // by — the shortest, whatever order the project lists them in.
      final host = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);')
          .allMatches(pbxproj)
          .map((m) => m.group(1)!)
          .reduce((a, b) => a.length <= b.length ? a : b);
      expect(bundleId, startsWith('$host.'));
      expect(read('tool/ios_widget_target.rb'), contains("'$bundleId'"));
    });

    test(
      'exactly Debug, Profile and Release, each linked to Generated.xcconfig',
      () {
        // Xcode's wizard creates only Debug and Release; Flutter needs Profile
        // too. And FLUTTER_BUILD_NAME / FLUTTER_BUILD_NUMBER — which the
        // extension's Info.plist reads — are defined nowhere but
        // Generated.xcconfig. Left unlinked, the archive succeeds, the upload
        // finishes, and App Store Connect rejects it with ITMS-90473
        // CFBundleVersion Mismatch.
        final names = configs
            .map((b) => RegExp(r'name = (\w+);').firstMatch(b)!.group(1)!)
            .toSet();
        expect(names, {'Debug', 'Profile', 'Release'});
        for (final config in configs) {
          expect(config, contains('/* Generated.xcconfig */;'));
          expect(config.contains('Pods-'), isFalse);
          expect(config, contains('SKIP_INSTALL = YES;'));
          expect(
            config,
            contains(
              'CODE_SIGN_ENTITLEMENTS = CirrusWidget/CirrusWidget.entitlements;',
            ),
          );
          expect(config, contains('INFOPLIST_FILE = CirrusWidget/Info.plist;'));
          expect(config, contains('IPHONEOS_DEPLOYMENT_TARGET = 16.0;'));
          expect(config, contains('SWIFT_VERSION = 5.0;'));
          expect(config, contains('CODE_SIGN_STYLE = Automatic;'));
        }
      },
    );

    test('Runner depends on it and copies the .appex into PlugIns', () {
      // dstSubfolderSpec 13 is PlugIns. An empty PlugIns/ is the
      // missing-embed-phase failure: everything works and the widget never
      // appears in the gallery, with no error anywhere.
      expect(runner, contains('/* Embed Foundation Extensions */,'));
      final dependency = blocks(
        'PBXTargetDependency',
      ).any((b) => b.contains('/* CirrusWidget */;'));
      expect(dependency, isTrue);
      final embed = blocks('PBXCopyFilesBuildPhase').firstWhere(
        (b) => b.contains('name = "Embed Foundation Extensions";'),
        orElse: () => '',
      );
      expect(embed, contains('dstSubfolderSpec = 13;'));
      expect(
        embed,
        contains('/* CirrusWidget.appex in Embed Foundation Extensions */'),
      );
      expect(
        pbxproj,
        contains(
          RegExp(
            r'CirrusWidget\.appex in Embed Foundation Extensions \*/ = \{[^}]*RemoveHeadersOnCopy',
          ),
        ),
      );
    });

    test('every Swift file in the folder compiles into the extension', () {
      final sources = Directory(folder)
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith('.swift'));
      expect(sources, isNotEmpty);
      for (final name in sources) {
        expect(pbxproj, contains('/* $name in Sources */'));
      }
      // Never the plist or the entitlements — add_file_references would have
      // put them in Sources, where the Swift compiler chokes on them.
      // (Runner's own `AppFrameworkInfo.plist in Resources` is Flutter's and
      // belongs there.)
      expect(
        RegExp(
          r'\* (Info\.plist|CirrusWidget\.entitlements) in (Sources|Resources)',
        ).hasMatch(pbxproj),
        isFalse,
      );
      expect(target.contains('Info.plist in'), isFalse);
    });

    test('the Runner scheme does not build it directly', () {
      // Flutter parses `xcodebuild -showBuildSettings` last-wins and must only
      // ever see Runner's block. The target dependency is what builds the
      // extension, and the UI tests have a scheme of their own.
      final scheme = read(
        'ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme',
      );
      expect(scheme.contains('CirrusWidget'), isFalse);
      expect(scheme.contains('RunnerUITests'), isFalse);
    });

    test('the Springboard driver is a UI-test bundle hosted by Runner', () {
      // Test-only: never embedded, never shipped. It exists because adding a
      // widget, tapping it and killing the app in between all happen outside
      // the app's process, where no Flutter test can go.
      final uiTests = blocks('PBXNativeTarget').firstWhere(
        (b) => b.contains('name = RunnerUITests;'),
        orElse: () => '',
      );
      expect(uiTests, isNotEmpty);
      expect(
        uiTests,
        contains('productType = "com.apple.product-type.bundle.ui-testing";'),
      );
      expect(pbxproj, contains('TEST_TARGET_NAME = Runner;'));
      expect(runner.contains('RunnerUITests'), isFalse);
      expect(
        File(
          'ios/Runner.xcodeproj/xcshareddata/xcschemes/RunnerUITests.xcscheme',
        ).existsSync(),
        isTrue,
      );
    });

    test('the extension Info.plist takes its version from Flutter', () {
      final plist = read('$folder/Info.plist');
      expect(plist, contains(r'$(FLUTTER_BUILD_NAME)'));
      expect(plist, contains(r'$(FLUTTER_BUILD_NUMBER)'));
      expect(plist, contains('com.apple.widgetkit-extension'));
    });
  });

  group('the palette is Midnight Ember, byte for byte', () {
    // A WidgetKit view draws itself, so the widget wears the brand rather than
    // the system theme (the Android deviation is documented in CLAUDE.md).
    // The hexes are written as comments so they stay diffable against the
    // Dart tokens; this checks the comment against the palette AND the
    // components against the comment, so neither can drift alone.
    final midnight = RegExp(
      r'const LpColors\.midnight\(\).*?(?=const LpColors\.)',
      dotAll: true,
    ).firstMatch(read('lib/app/theme/lp_colors.dart'))?.group(0);

    test('every annotated hex is an Ember token', () {
      expect(midnight, isNotNull);
      final colours = RegExp(
        r'Color\(red: ([\d.]+), green: ([\d.]+), blue: ([\d.]+)\) // #([0-9A-F]{6})',
      ).allMatches(widget).toList();
      expect(colours.length, greaterThanOrEqualTo(6));
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
  });
}
