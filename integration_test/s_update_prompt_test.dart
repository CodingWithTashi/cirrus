import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/data/stores/update_check_store.dart';
import 'package:last_puff/domain/analytics/analytics.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';

import 'harness.dart';

/// docs/10 §55 on a real phone: the update prompt, the forced update screen
/// and What's New against the REAL Google Play listing, the real installed
/// version, the real preferences and the real Play Store app.
///
/// The widget suite proves every rule with a scripted store answer, which is
/// exactly what it cannot see: whether upgrader can still read Cirrus's Play
/// listing today, what Play calls the version and the notes, whether Update
/// really lands in the Play Store, what the system Back key does to a screen
/// that refuses to pop, and whether a real trip to another app ends the visit
/// the one-modal-a-visit rule counts.
///
/// The data stays on the fake backend (the demo account) and nothing is
/// written anywhere. On the fake backend `upgraderProvider` is null, so
/// `--dart-define=UPGRADER_DEBUG=true` alone would do nothing; each test
/// builds the upgrader that define builds on the Firebase backend
/// (`debugDisplayOnce`: offered once a launch whatever the store says) and
/// the forced test overrides `updateForceDebugProvider` to what
/// `--dart-define=UPDATE_FORCE_DEBUG=true` makes it. Play internal testers
/// never see a real prompt (the track is not public), so this is the only way
/// to put either on a phone before a release.
///
/// The Play Store and the Back key are not Flutter, so the test prints
/// `E2E-MARKER:` lines and waits in real time without pumping a frame; an adb
/// driver screenshots, checks which app has the focus, and presses Back.
///
/// ```
/// flutter test integration_test/s_update_prompt_test.dart \
///   -d <device> --dart-define=LP_BACKEND=fake
/// ```
///
/// The tests run in order and share the device's preferences on purpose: the
/// Update test sees the "Not now" test's clock, and the restart is the Update
/// test's restart. The forced case runs first (see the note on it).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final analytics = _Recording();

  /// The real lookup: real HTTP to Google Play, the real `PackageInfo`.
  Upgrader realStore({bool offerOnce = true}) {
    final upgrader = Upgrader(
      checkOnResume: false,
      debugDisplayOnce: offerOnce,
      debugLogging: true,
    );
    addTearDown(upgrader.dispose);
    return upgrader;
  }

  void marker(String text) {
    // ignore: avoid_print
    print('E2E-MARKER: $text');
  }

  /// Holds the screen still so the adb driver can capture it.
  Future<void> shot(E2E e2e, String name) async {
    marker('shot $name');
    await e2e.waitFor(const Duration(milliseconds: 2500));
  }

  Future<E2E> open(
    WidgetTester tester, {
    Upgrader? upgrader,
    bool forceDebug = false,
  }) async {
    analytics.events.clear();
    final e2e = await E2E.boot(
      tester,
      realInstalledVersion: true,
      overrides: [
        analyticsProvider.overrideWithValue(analytics),
        if (upgrader != null) upgraderProvider.overrideWithValue(upgrader),
        if (forceDebug) updateForceDebugProvider.overrideWithValue(true),
      ],
    );
    // Google Play answers with its whole listing page; give it the store
    // check's own timeout and then some.
    final end = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(end) &&
        !e2e.container.read(updateCheckProvider).settled) {
      await e2e.tester.pump(const Duration(milliseconds: 100));
    }
    final check = e2e.container.read(updateCheckProvider);
    marker(
      'store check: settled=${check.settled} kind=${check.kind.name} '
      'store=${check.storeVersion} '
      'installed=${upgrader?.currentInstalledVersion} '
      'notes=${check.notesFor('en').length}',
    );
    return e2e;
  }

  Future<void> signIn(E2E e2e) async {
    await e2e.emailDoor();
    await e2e.tapSpan(e2e.l10n.authLogIn);
    await e2e.enterField(e2e.l10n.authEmailLabel, 'maya@quitmail.com');
    await e2e.enterField(e2e.l10n.authPasswordLabel, 'secret1');
    await e2e.tapText(e2e.l10n.authLogIn);
    await e2e.waitFor(const Duration(seconds: 3));
    expect(
      e2e.container.read(quitStoreProvider),
      isNotNull,
      reason: 'sign-in failed; on screen: ${e2e.texts()}',
    );
  }

  /// Taps [label], which leaves the app for the Play Store, and waits in real
  /// time — never pumping — until the driver has brought the app back.
  Future<List<AppLifecycleState>> leaveFor(E2E e2e, String label) async {
    final seen = <AppLifecycleState>[];
    final listener = AppLifecycleListener(onStateChange: seen.add);
    await e2e.tester.tap(find.text(label), warnIfMissed: false);
    await e2e.tester.pump();
    marker('play-store');
    final end = DateTime.now().add(const Duration(seconds: 90));
    while (DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final away =
          seen.contains(AppLifecycleState.paused) ||
          seen.contains(AppLifecycleState.hidden);
      if (away && seen.last == AppLifecycleState.resumed) break;
    }
    listener.dispose();
    marker('lifecycle after $label: ${seen.map((s) => s.name).join(' > ')}');
    await e2e.waitFor(const Duration(seconds: 2));
    return seen;
  }

  Future<SharedPreferences> disk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
  }

  // First, on purpose. `TestWidgetsFlutterBinding.postTest()` resets the
  // lifecycle to null after every test and the phone sends no new event, so
  // from the second test on `WidgetsApp` never tells Android it handles Back,
  // and Android keeps the previous app's answer. Placed fourth, the Back key
  // closed the activity on a Pixel 8 (Nov 13 2026) while a plain
  // `flutter run` held on two presses. A launch always reaches `resumed`.
  testWidgets('forced: in front of sign-in, the Back key does nothing, and '
      'Update leaves the screen standing', (tester) async {
    final e2e = await open(
      tester,
      upgrader: realStore(offerOnce: false),
      forceDebug: true,
    );
    final l10n = e2e.l10n;
    String path() => e2e.container.read(routerProvider).state.uri.path;

    await e2e.waitFor(const Duration(seconds: 3));
    expect(path(), Routes.updateRequired, reason: '${e2e.texts()}');
    expect(e2e.visible(l10n.updateRequiredTitle), isTrue);
    expect(e2e.visible(l10n.updateCta), isTrue);
    expect(e2e.showing(l10n.commonNotNow), isFalse);
    expect(analytics.propsOfAll('update_prompt_shown'), [
      {'forced': 'true'},
    ]);
    await shot(e2e, 'forced');

    // The driver presses the system Back key. Real time, no pump: if Back
    // closed the activity, the lifecycle says so.
    final seen = <AppLifecycleState>[];
    final listener = AppLifecycleListener(onStateChange: seen.add);
    marker('press-back');
    await Future<void>.delayed(const Duration(seconds: 8));
    listener.dispose();
    marker('lifecycle after Back: ${seen.map((s) => s.name).join(' > ')}');
    expect(seen, isNot(contains(AppLifecycleState.paused)));
    expect(seen, isNot(contains(AppLifecycleState.hidden)));
    await e2e.settle();
    expect(path(), Routes.updateRequired);
    expect(e2e.visible(l10n.updateRequiredTitle), isTrue);
    await shot(e2e, 'forced-after-back');

    final away = await leaveFor(e2e, l10n.updateCta);
    expect(analytics.names, contains('update_prompt_update'));
    expect(away.last, AppLifecycleState.resumed, reason: 'never came back');
    expect(path(), Routes.updateRequired);
    expect(e2e.visible(l10n.updateRequiredTitle), isTrue);
    await shot(e2e, 'forced-after-store');
  });

  testWidgets('the update sheet over Home from the real Play listing; '
      '"Not now" starts the clock on disk and spends the visit', (
    tester,
  ) async {
    final upgrader = realStore();
    final e2e = await open(tester, upgrader: upgrader);
    final l10n = e2e.l10n;
    final check = e2e.container.read(updateCheckProvider);
    expect(
      check.storeVersion,
      isNotNull,
      reason: 'upgrader could not read the Play listing',
    );
    expect(
      upgrader.currentInstalledVersion,
      (await PackageInfo.fromPlatform()).version,
    );

    await signIn(e2e);
    expect(e2e.visible(l10n.updateTitle), isTrue, reason: '${e2e.texts()}');
    expect(e2e.showing(check.storeVersion!), isTrue, reason: 'the chip');
    expect(e2e.visible(l10n.updateCta), isTrue);
    expect(e2e.visible(l10n.commonNotNow), isTrue);
    // Event props are strings on the wire (`LpEvents.updatePromptShown`).
    expect(analytics.propsOfAll('update_prompt_shown'), [
      {'forced': 'false'},
    ]);
    await shot(e2e, 'update-sheet');

    await e2e.tapText(l10n.commonNotNow);
    await e2e.waitFor(const Duration(seconds: 2));
    expect(e2e.showing(l10n.updateTitle), isFalse);
    expect(analytics.names, contains('update_prompt_later'));
    // One modal a visit: What's New is owed, and waits.
    expect(e2e.showing(l10n.whatsNewTitle), isFalse);
    final prefs = await disk();
    expect(prefs.getString('lastTimeAlerted'), isNotNull);
    expect(prefs.getString('settings.whatsNewSeenVersion'), isNull);
    await shot(e2e, 'after-not-now');
  });

  testWidgets('Update opens the Play Store; back in the app is a new visit, '
      "and What's New comes then", (tester) async {
    final e2e = await open(tester, upgrader: realStore());
    final l10n = e2e.l10n;
    await signIn(e2e);
    expect(e2e.visible(l10n.updateTitle), isTrue, reason: '${e2e.texts()}');

    final seen = await leaveFor(e2e, l10n.updateCta);
    expect(analytics.names, contains('update_prompt_update'));
    expect(
      seen,
      anyOf(contains(AppLifecycleState.paused), contains(AppLifecycleState.hidden)),
      reason: 'nothing opened over the app',
    );
    expect(seen.last, AppLifecycleState.resumed, reason: 'never came back');
    expect(e2e.showing(l10n.updateTitle), isFalse);

    expect(e2e.visible(l10n.whatsNewTitle), isTrue, reason: '${e2e.texts()}');
    final installed = (await PackageInfo.fromPlatform()).version;
    expect(analytics.propsOfAll('whats_new_shown'), [
      {'version': installed},
    ]);
    await shot(e2e, 'whats-new');
    await e2e.tapText(l10n.whatsNewDone);
    expect(e2e.showing(l10n.whatsNewTitle), isFalse);
    await e2e.waitFor(const Duration(seconds: 1));
    expect((await disk()).getString('settings.whatsNewSeenVersion'), installed);
  });

  testWidgets("a restart: What's New is read back from disk and stays away", (
    tester,
  ) async {
    final e2e = await open(tester);
    await signIn(e2e);
    await e2e.waitFor(const Duration(seconds: 2));
    expect(e2e.showing(e2e.l10n.whatsNewTitle), isFalse);
    expect(analytics.names, isNot(contains('whats_new_shown')));
    expect(e2e.showing(e2e.l10n.homeLogPuff), isTrue, reason: '${e2e.texts()}');
    await shot(e2e, 'restart-home');
  });
}

class _Recording implements AnalyticsSink {
  final List<AnalyticsEvent> events = [];

  List<String> get names => [for (final e in events) e.name];

  List<Map<String, Object>> propsOfAll(String name) => [
    for (final e in events)
      if (e.name == name) e.props,
  ];

  @override
  void track(AnalyticsEvent event) => events.add(event);

  @override
  void screenViewed(String name) {}

  @override
  void identify(String userId) {}

  @override
  void reset() {}
}
