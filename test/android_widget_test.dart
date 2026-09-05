import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The home-screen widget is native code in a repo whose CI never compiles
/// native code — `.github/workflows/ci.yml` runs `flutter analyze`,
/// `flutter test` and the functions suite, and nothing else. Every failure
/// below is silent on a device: a widget that draws the wrong thing, or the
/// launcher's "Problem loading widget" tile, with the reason only in logcat.
///
/// So the gate is a string test over the native files, exactly as
/// `android_manifest_test.dart` is.
void main() {
  const androidRes = 'android/app/src/main/res';
  const widgetKotlin =
      'android/app/src/main/kotlin/com/quitvape/last_puff/widget';

  String read(String path) => File(path).readAsStringSync();

  /// Markup only. These files explain themselves at length, and a comment that
  /// names the very thing an assertion forbids would fail it — the prose is
  /// documentation, not declaration.
  String markup(String xml) => xml.replaceAll(
    RegExp(r'<!--.*?-->', dotAll: true),
    '',
  );

  final manifestRaw = read('android/app/src/main/AndroidManifest.xml');
  final manifest = markup(manifestRaw);
  final info = markup(read('$androidRes/xml/cirrus_widget_info.xml'));
  final small = markup(read('$androidRes/layout/cirrus_widget_small.xml'));
  final wide = markup(read('$androidRes/layout/cirrus_widget_wide.xml'));
  final kotlin = Directory(widgetKotlin)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.kt'))
      .map((f) => f.readAsStringSync())
      .join('\n');

  const provider = 'com.quitvape.last_puff.widget.CirrusWidgetProvider';

  // The same regex android_manifest_test.dart uses, for the same reason:
  // android:name must appear BEFORE the opening tag's `>` or the receiver is
  // invisible to it.
  final receivers = RegExp(
    r'<receiver[^>]*android:name="([^"]+)"',
    dotAll: true,
  ).allMatches(manifest).map((m) => m.group(1)!).toSet();

  group('the manifest', () {
    test('declares the provider, and never exports it', () {
      expect(receivers, contains(provider));

      final block = RegExp(
        '<receiver[^>]*android:name="$provider".*?</receiver>',
        dotAll: true,
      ).firstMatch(manifest)?.group(0);
      expect(block, isNotNull);

      // Exported, any app on the device could broadcast .PLUS and write puffs
      // into someone else's own record.
      expect(block!, contains('android:exported="false"'));
      expect(
        block,
        contains('android.appwidget.action.APPWIDGET_UPDATE'),
        reason: 'without it the system never calls onUpdate and the widget '
            'draws once and then freezes for ever',
      );
      expect(block, contains('android:name="android.appwidget.provider"'));
      expect(block, contains('@xml/cirrus_widget_info'));
    });

    test('routes every action the provider handles', () {
      // An action the manifest does not name simply never reaches onReceive.
      // The button looks alive and does nothing.
      final actions = RegExp(r'"(com\.quitvape\.last_puff\.widget\.[A-Z_]+)"')
          .allMatches(kotlin)
          .map((m) => m.group(1)!)
          .toSet();

      expect(actions, isNotEmpty, reason: 'the provider declares no actions?');
      for (final action in actions) {
        expect(
          manifest,
          contains('<action android:name="$action"/>'),
          reason: 'onReceive handles $action but nothing routes it there',
        );
      }
    });

    test('registers the receiver that delivers the midnight repaint', () {
      // home_widget does not declare this itself, so that apps which never
      // schedule an update do not inherit the boot permission. Unregistered,
      // the alarm is never delivered and the widget shows yesterday's day
      // number until the 30-minute floor catches it — the plugin only logs a
      // warning.
      expect(
        receivers,
        contains('es.antonborri.home_widget.HomeWidgetScheduledUpdateReceiver'),
      );
      expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
    });

    test('adds no permission, and never names an exact alarm', () {
      // The widget repaints across midnight with updatePeriodMillis — an
      // inexact, batched, non-wakeup alarm the framework owns. Nothing here
      // goes near the permission Play rejected the Sep 2 2026 build for.
      expect(manifest.contains('SCHEDULE_EXACT_ALARM'), isFalse);
      expect(manifest.contains('USE_EXACT_ALARM'), isFalse);

      final declared = RegExp(r'<uses-permission([^>]*)>')
          .allMatches(manifest)
          .map((m) => m.group(1)!)
          .where((tag) => !tag.contains('tools:node="remove"'))
          .length;
      expect(
        declared,
        3,
        reason: 'INTERNET, POST_NOTIFICATIONS and RECEIVE_BOOT_COMPLETED. '
            'A fourth means the widget grew a permission it must justify.',
      );
    });

    test('leaves the App Links filter the first and only verified one', () {
      // android_manifest_test.dart takes the FIRST autoVerify filter and
      // asserts exact-set equality on its scheme, host and pathPrefix. A
      // widget filter placed above it, or carrying autoVerify, would repoint
      // that whole suite at the wrong block.
      expect(
        RegExp('android:autoVerify="true"').allMatches(manifest).length,
        1,
      );
    });
  });

  group('the appwidget-provider metadata', () {
    test('is a 2x2 that reflows', () {
      expect(info, contains('android:minWidth="110dp"')); // 70n-30, n=2
      expect(info, contains('android:minHeight="110dp"'));
      expect(info, contains('android:targetCellWidth="2"')); // API 31+
      expect(info, contains('android:targetCellHeight="2"'));
      expect(info, contains('android:resizeMode="horizontal|vertical"'));
      expect(info, contains('android:widgetCategory="home_screen"'));
      expect(info, contains('android:initialLayout='));
      expect(info, contains('android:previewLayout='));
    });

    test('repaints across midnight, at the platform floor and no faster', () {
      // The day number and the count both change at local midnight and nothing
      // repaints a widget on its own. 30 minutes is the floor the framework
      // enforces; anything smaller is silently ignored, and 0 would mean the
      // widget shows yesterday until something else happens to touch it.
      expect(info, contains('android:updatePeriodMillis="1800000"'));
    });

    test('offers no configuration screen', () {
      // It has to be useful the instant it lands on the home screen.
      expect(info.contains('android:configure='), isFalse);
    });
  });

  group('the layouts', () {
    // THE high-value assertion here. The provider sets the same ids on both
    // layouts; an id in one and not the other makes half the setters no-op at
    // whichever size the user happened to pick, with no exception anywhere.
    final ids = RegExp(r'R\.id\.(cw_[a-z_]+)')
        .allMatches(kotlin)
        .map((m) => m.group(1)!)
        .toSet();

    test('both declare every id the provider sets', () {
      expect(ids, isNotEmpty);
      for (final id in ids) {
        expect(small, contains('@+id/$id'), reason: 'the 2x2 is missing $id');
        expect(wide, contains('@+id/$id'), reason: 'the 4x2 is missing $id');
      }
    });

    test('use only views RemoteViews can inflate', () {
      // <View> and <Space> are NOT on the AppWidget allowlist: either throws at
      // inflation and the launcher shows "Problem loading widget". Spacers are
      // <ImageView> with a layout_weight.
      for (final layout in [small, wide]) {
        expect(RegExp(r'<View[\s/>]').hasMatch(layout), isFalse);
        expect(RegExp(r'<Space[\s/>]').hasMatch(layout), isFalse);
        expect(layout.contains('androidx.'), isFalse);
        expect(layout.contains('<Constraint'), isFalse);
      }
    });

    test('put the day above the count, in both sizes', () {
      // The reading order the founder asked for. Structural, so it survives a
      // later restyle.
      for (final layout in [small, wide]) {
        expect(
          layout.indexOf('@+id/cw_day'),
          lessThan(layout.indexOf('@+id/cw_count')),
        );
      }
    });
  });

  group('resources', () {
    Set<String> namesIn(String path, String tag) => RegExp('<$tag name="([^"]+)"')
        .allMatches(read(path))
        .map((m) => m.group(1)!)
        .toSet();

    test('every widget colour has a night counterpart', () {
      // The launcher inflates our layout in ITS process against ITS config, so
      // values-night/ is what the widget actually follows. A name declared in
      // one file and not the other renders wrong in exactly one theme, and the
      // compiler says nothing.
      expect(
        namesIn('$androidRes/values/cirrus_widget_colors.xml', 'color'),
        namesIn('$androidRes/values-night/cirrus_widget_colors.xml', 'color'),
      );
    });

    test('every style has an API-26 counterpart', () {
      // android:fontFamily="@font/…" is an API 26 attribute; below that the
      // value is read as a family NAME and the reference never resolves. The
      // typeface therefore lives in a style overridden wholesale in values-v26,
      // and a style added to one file and not the other silently loses either
      // its font or its whole appearance on one API band.
      expect(
        namesIn('$androidRes/values/cirrus_widget_styles.xml', 'style'),
        namesIn('$androidRes/values-v26/cirrus_widget_styles.xml', 'style'),
      );
    });

    test('stay out of the two files generated tooling owns', () {
      // `dart run flutter_launcher_icons` rewrites values/colors.xml to plant
      // ic_launcher_background; values/styles.xml is Flutter's own template.
      // Anything of ours in either is deleted by the next tool run.
      expect(read('$androidRes/values/colors.xml').contains('cw_'), isFalse);
      expect(read('$androidRes/values/styles.xml').contains('CirrusWidget'), isFalse);
    });

    test('the launcher-visible strings exist in all five locales', () {
      // The picker label, its description and the previewLayout placeholders
      // are read out of our resources by the launcher before a line of our code
      // runs. They are the only user-visible strings in this app that cannot
      // come from an ARB, so they get the same parity gate the ARBs do.
      final en = namesIn('$androidRes/values/cirrus_widget_strings.xml', 'string');
      expect(en, contains('cw_picker_label'));
      for (final locale in ['es', 'fr', 'de', 'pt']) {
        expect(
          namesIn('$androidRes/values-$locale/cirrus_widget_strings.xml', 'string'),
          en,
          reason: 'values-$locale drifted from the English set',
        );
      }
    });

    test('the brand faces are present under resource-legal names', () {
      // A RemoteViews layout is inflated by the launcher against our res/,
      // which cannot reach assets/flutter_assets/ — so the fonts are copies.
      // res/font names must be [a-z0-9_]; "SpaceGrotesk-Bold.ttf" is not a
      // legal resource name and fails the build.
      expect(File('$androidRes/font/space_grotesk_bold.ttf').existsSync(), isTrue);
      expect(File('$androidRes/font/inter_medium.ttf').existsSync(), isTrue);
    });
  });

  group('the wire contract between Kotlin and Dart', () {
    test('both sides name the same shared-store keys', () {
      // Two halves of one wire format in two languages — the shape of bug this
      // repo has already had twice (streakEngine.ts vs streak_engine.dart,
      // postQuality vs PostQuality). A key renamed on one side blanks the
      // widget and throws nothing.
      Set<String> keysIn(String source) =>
          RegExp(r"""["'](lp\.[a-zA-Z]+)["']""")
              .allMatches(source)
              .map((m) => m.group(1)!)
              .toSet();

      final dart = read('lib/data/stores/pending_puffs.dart') +
          read('lib/data/stores/widget_mirror.dart');

      expect(keysIn(kotlin), isNotEmpty);
      expect(keysIn(kotlin), keysIn(dart));
    });

    test('both sides use the same event field names', () {
      // {"i": id, "s": seq, "t": epochMillis, "d": delta}
      for (final field in ['"i"', '"s"', '"t"', '"d"']) {
        expect(kotlin, contains(field), reason: 'Kotlin never reads $field');
        expect(
          read('lib/data/stores/pending_puffs.dart'),
          contains(field.replaceAll('"', "'")),
          reason: 'Dart never reads $field',
        );
      }
    });

    test('Dart addresses the provider the manifest actually declares', () {
      // `HomeWidget.updateWidget` addresses the provider by fully-qualified
      // name. A stale or wrong one refreshes NOTHING — no exception, no log,
      // and the widget simply keeps drawing whatever it last drew. This
      // shipped wrong once already, naming a class that never existed.
      final store = read('lib/data/api/widget_store.dart');
      expect(store, contains("'$provider'"));
      // And it must travel as `qualifiedAndroidName`. The plugin resolves
      // `androidName` as "<applicationId>.<value>", so a fully-qualified name
      // in that slot is looked up doubled, throws ClassNotFoundException
      // inside the plugin, and returns an error the caller swallows — the
      // mirror updates and the widget never repaints.
      expect(store, contains('qualifiedAndroidName: androidProvider'));
      expect(store.contains('androidName: androidProvider'), isFalse);
    });

    test('Dart and Swift name the same App Group', () {
      // A one-character difference builds, signs, installs and runs:
      // UserDefaults(suiteName:) hands back a usable-looking object and every
      // read returns nil, for ever, with no diagnostic anywhere.
      final group = RegExp(r"appGroupId = '([^']+)'")
          .firstMatch(read('lib/data/api/widget_store.dart'))
          ?.group(1);
      expect(group, isNotNull);
      expect(
        read('ios/CirrusWidget/CirrusWidget.entitlements'),
        contains(group!),
      );
      expect(read('ios/CirrusWidget/CirrusShared.swift'), contains(group));
    });

    test('Dart and Swift name the same WidgetKit kind', () {
      // The `kind` in CirrusWidget.swift must equal the iOSName the Dart side
      // passes to updateWidget and the kind reloadTimelines uses. A mismatch
      // is completely silent.
      final name = RegExp(r"iOSName = '([^']+)'")
          .firstMatch(read('lib/data/api/widget_store.dart'))
          ?.group(1);
      expect(name, isNotNull);
      expect(
        read('ios/CirrusWidget/CirrusShared.swift'),
        contains('kind = "$name"'),
      );
    });

    test('every mirror field Kotlin reads is one Dart writes', () {
      // The day-number bug lived here: a field whose meaning drifted between
      // the two sides with nothing to catch it. Field NAMES are cheap to pin,
      // and a rename on one side blanks that value on the widget silently.
      final dart = read('lib/data/stores/widget_mirror.dart');
      // Two or more characters: the outbox's own fields are the single
      // letters i/s/t/d and belong to pending_puffs.dart, not here.
      final kotlinReads =
          RegExp(r'opt(?:String|Int|Long|Boolean|JSONObject)\("([a-zA-Z]{2,})"')
              .allMatches(kotlin)
              .map((m) => m.group(1)!)
              .toSet();

      expect(kotlinReads, isNotEmpty);
      for (final field in kotlinReads) {
        expect(
          dart,
          contains("'$field'"),
          reason: 'Kotlin reads mirror field "$field" that Dart never writes',
        );
      }
    });

    test('both sides agree on the schema version', () {
      expect(kotlin, contains('const val SCHEMA = 1'));
      expect(
        read('lib/data/stores/pending_puffs.dart'),
        contains('schemaVersion = 1'),
      );
    });
  });

  test('home_widget is a real dependency, not a dev one', () {
    // Flutter's Gradle plugin strips dev-dependency plugins from RELEASE
    // builds. Left under dev_dependencies this ships a debug build that works
    // perfectly and a Play build whose widget never receives a single mirror
    // update — the same silent shape as the B18 receivers that were never
    // declared, and CI cannot catch it because CI never builds Android.
    final pubspec = read('pubspec.yaml');
    final split = pubspec.indexOf('dev_dependencies:');
    expect(split, greaterThan(0));
    expect(
      pubspec.substring(split).contains('home_widget'),
      isFalse,
      reason: 'home_widget is under dev_dependencies and will vanish in release',
    );
    expect(pubspec.substring(0, split).contains('home_widget'), isTrue);
  });

  group('a widget with no journey shows a message, never a counter', () {
    // Founder rule, Sep 5 2026: the home screen outlives the session, so a
    // widget still counting for a signed-out account is the shared-phone leak
    // in its most public form — and unlike the outbox, this one the next
    // person can see. Signed out, freshly installed, account deleted: the
    // empty card, and nothing that looks like anyone's data.
    //
    // The Dart half is pinned in `widget_mirror_test.dart`; these three are
    // the native half, which no compiler and no Dart test can reach.
    final data = read('$widgetKotlin/CirrusWidgetData.kt');
    final provider = read('$widgetKotlin/CirrusWidgetProvider.kt');

    test('an absent, stale or unreadable mirror reads as no journey', () {
      // Three doors into the same answer: no document at all (fresh install),
      // a schema this build does not know, and a parse failure.
      expect(
        data,
        contains('prefs.getString(CirrusKeys.MIRROR, null) ?: return absent'),
      );
      expect(
        data,
        contains('if (json.optInt("v", -1) != CirrusKeys.SCHEMA) return absent'),
      );
      expect(data, contains('absent'), reason: 'the catch falls back too');
      expect(RegExp(r'catch \(error: Throwable\)').hasMatch(data), isTrue);
    });

    test('a tap is refused while there is no journey', () {
      // Without this the buttons keep working on a stale card and the count
      // climbs for an account nobody is signed in to.
      expect(
        data.replaceAll(RegExp(r'\s+'), ' '),
        contains('val mirror = CirrusMirror.read(prefs) if (!mirror.hasJourney) return null'),
      );
    });

    test('the empty card hides the active one, and returns before drawing it', () {
      // `cw_active` carries the count, the day number and both buttons. The
      // early return is what guarantees none of their setters run.
      final empty = provider.substring(
        provider.indexOf('if (!mirror.hasJourney) {'),
      );
      final body = empty.substring(0, empty.indexOf('return views') + 12);
      expect(body, contains('R.id.cw_active, View.GONE'));
      expect(body, contains('R.id.cw_empty, View.VISIBLE'));
      expect(
        body,
        isNot(contains('R.id.cw_count')),
        reason: 'the empty branch must never set a number',
      );
      expect(
        body,
        isNot(contains('cw_plus')),
        reason: 'and must never wire a tap target',
      );
    });
  });

}
