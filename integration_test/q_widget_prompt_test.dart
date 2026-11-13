import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/api/widget_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/data/stores/settings_store.dart';
import 'package:last_puff/data/stores/widget_prompt_store.dart';
import 'package:last_puff/domain/analytics/analytics.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/taper_engine.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/home/widgets/widget_prompt_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

/// Stage C of docs/15, on a real phone: the one-time home-screen widget card
/// against the REAL launcher.
///
/// The widget suite proves the card with a fake launcher, which is exactly what
/// it cannot see: what `isRequestPinWidgetSupported` answers on this phone,
/// what `getInstalledWidgets` calls the class (`.widget.CirrusWidgetProvider`,
/// not the qualified name — a filter that missed that would count zero on every
/// phone with the widget on it), what the system pin dialog does to the app's
/// lifecycle, and whether the card is really gone after a restart. The data
/// stays on the fake backend and nothing is written anywhere; only the widget
/// store (`HomeWidgetStore`) and the settings (real `SharedPreferences`) are
/// real.
///
/// The system dialog is not Flutter, so the test prints `E2E-MARKER:` lines
/// and waits; an adb driver screenshots it and confirms it. **The app goes
/// `inactive` under the dialog** (recorded on a Pixel 8 as `inactive >
/// resumed`, never `paused`) and resumes by itself when it closes, so the
/// driver's relaunch turned out to be unnecessary. The README warns that a
/// pump can stall once an app is really backgrounded, so that stretch
/// deliberately only awaits real time and polls the real launcher; it never
/// pumps a frame.
///
/// Needs a fresh install on a phone whose home screen has no Cirrus widget, and
/// a launcher that can pin (a Pixel's does):
///
/// ```
/// flutter test integration_test/q_widget_prompt_test.dart \
///   -d <device> --dart-define=LP_BACKEND=fake
/// ```
///
/// The tests run in order and share the device's preferences on purpose: the
/// second is the first one's restart, and the third is the next person to sign
/// in.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 11, 13, 14, 30);
  final today = LpDate.dayStart(now);
  const launcher = HomeWidgetStore();
  final analytics = _Recording();

  /// A taper on plan day 4 — three completed days at their lines, so well past
  /// five puffs over two days — with the Day-1 walkthrough done and the
  /// cigarettes question answered, so nothing else competes for the screen.
  JourneyState taper() {
    final plan = QuitPlan(
      method: QuitMethod.taper,
      paceDays: 30,
      startDate: LpDate.addDays(today, -3),
      baselinePuffsPerDay: 100,
      weeklySpend: 30,
      strength: NicStrength.mg50,
    );
    final days = <DateTime, DayLog>{};
    for (var d = 1; d <= 3; d++) {
      final date = LpDate.addDays(plan.startDate, d - 1);
      final limit = TaperEngine.limitFor(plan, d);
      days[date] = DayLog(
        date: date,
        puffs: limit,
        limit: limit,
        hourBuckets: {10: limit},
      );
    }
    return JourneyState(
      profile: const UserProfile(
        alias: '@matrixfox',
        avatarEmoji: '🦊',
        smoking: SmokingHistory.never,
      ),
      plan: plan,
      days: days,
      cravingsSurvivedTotal: 4,
      repairTokens: 0,
      longestStreak: 0,
      goals: const [],
      earnedBadges: const {},
      day1TasksDone: const {0, 1, 2},
    );
  }

  Future<void> signIn(E2E e2e, [JourneyState? journey]) async {
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
    e2e.container.read(quitStoreProvider.notifier).replaceForTest(journey ?? taper());
    await e2e.waitFor(const Duration(seconds: 2));
  }

  /// The same taper, one puff short of qualifying: four puffs yesterday, none
  /// today. Logging one more makes five over two days, which is the moment the
  /// offer becomes due.
  JourneyState onePuffShort() {
    final base = taper();
    final yesterday = LpDate.addDays(today, -1);
    return JourneyState(
      profile: base.profile,
      plan: QuitPlan(
        method: QuitMethod.taper,
        paceDays: 30,
        startDate: yesterday,
        baselinePuffsPerDay: 100,
        weeklySpend: 30,
        strength: NicStrength.mg50,
      ),
      days: {
        yesterday: DayLog(
          date: yesterday,
          puffs: 4,
          limit: 100,
          hourBuckets: const {10: 4},
        ),
      },
      cravingsSurvivedTotal: 4,
      repairTokens: 0,
      longestStreak: 0,
      goals: const [],
      earnedBadges: const {},
      day1TasksDone: const {0, 1, 2},
    );
  }

  /// The app as a person meets it: the demo account on the fake backend, the
  /// real launcher, the real preferences.
  Future<E2E> open(WidgetTester tester, [JourneyState? journey]) async {
    final e2e = await E2E.boot(
      tester,
      overrides: [
        nowProvider.overrideWithValue(() => now),
        widgetStoreProvider.overrideWithValue(launcher),
        analyticsProvider.overrideWithValue(analytics),
        // Disk, not the suite's no-restore default: the restart is the point.
        settingsStoreProvider.overrideWith(() => SettingsStore()),
      ],
    );
    await e2e.waitFor(const Duration(seconds: 2));
    await signIn(e2e, journey);
    return e2e;
  }

  /// The state a real account with this journey would have started in.
  ///
  /// The fake backend's demo login passes through its seeded day-12 journey
  /// before the fixture replaces it, and that one qualifies: the card is seen
  /// and the one-time offer spent in those few seconds. A real sign-in loads one
  /// real journey, so none of that happens to a person; forget it here.
  Future<void> freshOffer(E2E e2e) async {
    e2e.container.read(settingsStoreProvider.notifier).resetWidgetPrompt();
    e2e.container.invalidate(widgetPromptProvider);
    analytics.events.clear();
    await e2e.waitFor(const Duration(seconds: 2));
  }

  /// Holds the screen still so the adb driver can capture it.
  Future<void> shot(E2E e2e, String name) async {
    // ignore: avoid_print
    print('E2E-MARKER: shot $name');
    await e2e.waitFor(const Duration(milliseconds: 2500));
  }

  void marker(String text) {
    // ignore: avoid_print
    print('E2E-MARKER: $text');
  }

  SettingsState settings(E2E e2e) => e2e.container.read(settingsStoreProvider);

  /// The card's button, on screen the way a person finds it: by scrolling.
  Future<void> scrollToCard(E2E e2e) async {
    final add = find.text(e2e.l10n.widgetPromptAdd);
    if (add.hitTestable().evaluate().isEmpty) {
      await e2e.tester.scrollUntilVisible(
        add,
        150,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
      await e2e.settle();
    }
  }

  /// Ends the process's side of the app and brings it up again over the same
  /// device preferences: a new container, a new fake server, and a fresh read
  /// through the preferences plugin. (The harness uninstalls the app when a
  /// run finishes, so a real process kill cannot span two runs. `reload()` is
  /// NOT a disk read — on Android the plugin's copy lives for the whole
  /// process — so the driver reads the preferences file over adb at the
  /// `prefs-flushed` marker, and that is the disk evidence.)
  Future<void> restart(WidgetTester tester, E2E before) async {
    await before.waitFor(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox.shrink());
    before.container.dispose();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
  }

  testWidgets('the real launcher: it can pin, and no Cirrus widget is placed',
      (tester) async {
    final pin = await launcher.canPin();
    final count = await launcher.installedCount();
    marker('launcher canPin=$pin installed=$count');

    expect(pin, isTrue, reason: 'this launcher cannot add a widget');
    expect(
      count,
      0,
      reason: 'a Cirrus widget is already on the home screen (or the read '
          'failed): remove it, and start from a fresh install',
    );
  });

  testWidgets('the offer is spent only when it is seen: not from another tab',
      (tester) async {
    // Home stays mounted, laid out and sized under the other tabs, and the
    // quick-log `+` is on every one of them, so the fifth puff can be logged
    // from Stats. The offer used to be written and reported right there.
    analytics.events.clear();
    final e2e = await open(tester, onePuffShort());
    final l10n = e2e.l10n;
    await freshOffer(e2e);
    expect(e2e.showing(l10n.widgetPromptAdd), isFalse, reason: 'four puffs');

    e2e.container.read(routerProvider).go(Routes.stats);
    await e2e.waitFor(const Duration(seconds: 2));
    e2e.container.read(quitStoreProvider.notifier).logPuff(); // the fifth
    await e2e.waitFor(const Duration(seconds: 2));

    expect(settings(e2e).widgetPromptShown, isFalse, reason: 'nobody saw it');
    expect(analytics.names, isNot(contains('widget_prompt_shown')));

    e2e.container.read(routerProvider).go(Routes.home);
    await e2e.waitFor(const Duration(seconds: 2));
    await scrollToCard(e2e);
    expect(e2e.visible(l10n.widgetPromptAdd), isTrue, reason: '${e2e.texts()}');
    expect(settings(e2e).widgetPromptShown, isTrue);
    expect(analytics.propsOfAll('widget_prompt_shown'), hasLength(1));
    await shot(e2e, 'spent-when-seen-tab');

    // Leave the flag as a fresh phone has it, for the tests that follow.
    e2e.container.read(quitStoreProvider.notifier).signOut();
    await e2e.waitFor(const Duration(seconds: 2));
    expect(settings(e2e).widgetPromptShown, isFalse);
  });

  testWidgets('the offer is spent only when it is seen: not under a screen '
      'pushed over Home', (tester) async {
    analytics.events.clear();
    final e2e = await open(tester, onePuffShort());
    final l10n = e2e.l10n;
    await freshOffer(e2e);
    expect(e2e.showing(l10n.widgetPromptAdd), isFalse, reason: 'four puffs');

    // Settings is a full-screen route over the whole shell.
    unawaited(e2e.container.read(routerProvider).push(Routes.settings));
    await e2e.waitFor(const Duration(seconds: 2));
    e2e.container.read(quitStoreProvider.notifier).logPuff(); // the fifth
    await e2e.waitFor(const Duration(seconds: 2));

    expect(settings(e2e).widgetPromptShown, isFalse, reason: 'covered');
    expect(analytics.names, isNot(contains('widget_prompt_shown')));

    e2e.container.read(routerProvider).pop();
    await e2e.waitFor(const Duration(seconds: 2));
    await scrollToCard(e2e);
    expect(e2e.visible(l10n.widgetPromptAdd), isTrue, reason: '${e2e.texts()}');
    expect(settings(e2e).widgetPromptShown, isTrue);
    expect(analytics.propsOfAll('widget_prompt_shown'), hasLength(1));

    e2e.container.read(quitStoreProvider.notifier).signOut();
    await e2e.waitFor(const Duration(seconds: 2));
    expect(settings(e2e).widgetPromptShown, isFalse);
  });

  testWidgets('the card is offered to the taper, "Not now" is final, and a '
      'restart brings nothing back', (tester) async {
    analytics.events.clear();
    final e2e = await open(tester);
    final l10n = e2e.l10n;

    await scrollToCard(e2e);
    expect(e2e.visible(l10n.widgetPromptAdd), isTrue, reason: '${e2e.texts()}');
    expect(e2e.visible(l10n.widgetPromptTitle), isTrue);
    expect(e2e.visible(l10n.commonNotNow), isTrue);
    await shot(e2e, 'widget-card');

    expect(analytics.propsOfAll('widget_prompt_shown'), [
      {'way': 'pinDialog'},
    ]);
    expect(settings(e2e).widgetPromptShown, isTrue);

    await e2e.tapText(l10n.commonNotNow);
    expect(e2e.showing(l10n.widgetPromptAdd), isFalse);
    expect(analytics.names, isNot(contains('widget_prompt_accepted')));

    // Let the write-behind land, and let the driver read the file on the device.
    await e2e.waitFor(const Duration(seconds: 1));
    marker('prefs-flushed');
    await e2e.waitFor(const Duration(seconds: 3));

    await restart(tester, e2e);

    analytics.events.clear();
    final again = await open(tester);
    await again.waitFor(const Duration(seconds: 2));
    expect(
      settings(again).widgetPromptShown,
      isTrue,
      reason: 'the flag did not come back from the preferences',
    );
    expect(again.showing(again.l10n.widgetPromptAdd), isFalse);
    // Even at the bottom of Home: nothing is waiting below the fold.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2500));
    await again.settle();
    expect(again.showing(again.l10n.widgetPromptAdd), isFalse);
    expect(analytics.names, isNot(contains('widget_prompt_shown')));
    await shot(again, 'after-restart-no-card');
  });

  testWidgets('the next person to sign in is offered it once, and "Add widget" '
      'opens the real system dialog', (tester) async {
    analytics.events.clear();
    final e2e = await open(tester);
    final l10n = e2e.l10n;
    // The previous account's flag is still on disk until somebody signs out.
    expect(settings(e2e).widgetPromptShown, isTrue);
    expect(e2e.showing(l10n.widgetPromptAdd), isFalse);

    // Something else a sign-out forgets, against the device's real storage.
    e2e.container.read(quitStoreProvider.notifier).signOut();
    await e2e.waitFor(const Duration(seconds: 2));
    expect(settings(e2e).widgetPromptShown, isFalse);
    await e2e.waitFor(const Duration(seconds: 1));
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getBool('settings.widgetPromptShown'), isFalse);

    await signIn(e2e);
    await scrollToCard(e2e);
    expect(e2e.visible(l10n.widgetPromptAdd), isTrue, reason: '${e2e.texts()}');
    expect(analytics.propsOfAll('widget_prompt_shown'), hasLength(1));
    await shot(e2e, 'widget-card-second-account');

    // What the real system dialog does to the app is the one thing no fake can
    // say, so record every lifecycle state from the tap on.
    final seen = <AppLifecycleState>[];
    final listener = AppLifecycleListener(onStateChange: seen.add);
    addTearDown(listener.dispose);

    // Tapped twice before a frame can rebuild: a double tap used to ask the
    // launcher for two dialogs and report two acceptances.
    await e2e.tester.tap(find.text(l10n.widgetPromptAdd), warnIfMissed: false);
    await e2e.tester.tap(find.text(l10n.widgetPromptAdd), warnIfMissed: false);
    // One frame, then no more: the launcher's dialog takes the app off screen.
    await e2e.tester.pump();
    expect(
      analytics.propsOfAll('widget_prompt_accepted'),
      [
        {'way': 'pinDialog'},
      ],
    );

    marker('pin-dialog');
    // The driver screenshots the dialog, confirms it, and brings the app back.
    // Real time only — no pump — until the launcher reports the widget.
    final end = DateTime.now().add(const Duration(seconds: 150));
    var placed = 0;
    while (DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      placed = await launcher.installedCount() ?? 0;
      if (placed > 0) break;
    }
    marker('lifecycle after Add: ${seen.map((s) => s.name).join(' > ')}');
    marker('launcher reports installed=$placed');
    expect(placed, greaterThan(0), reason: 'the dialog was never confirmed');

    // Back in the foreground: the resume must have found it.
    final back = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(back) &&
        !analytics.names.contains('widget_installed')) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    await e2e.waitFor(const Duration(seconds: 2));
    expect(
      analytics.names.where((n) => n == 'widget_installed'),
      hasLength(1),
      reason: 'lifecycle was ${seen.map((s) => s.name).join(' > ')}; '
          'the app was not brought back to the foreground?',
    );
    expect(e2e.showing(l10n.widgetPromptAdd), isFalse);
    await shot(e2e, 'after-add');
  });

  testWidgets('with the widget on the home screen the card does not come back '
      'for the next person, and is not spent on them', (tester) async {
    analytics.events.clear();
    final count = await launcher.installedCount();
    expect(count, greaterThan(0), reason: 'run after the test above');

    final e2e = await open(tester);
    final l10n = e2e.l10n;
    // The previous account was shown the card, so its flag is on disk. Sign out
    // first: that forgets it, which leaves the widget on the home screen as the
    // ONLY thing between the next person and the offer. (Without this the test
    // could not tell "the widget suppresses it" from "it was already shown".)
    e2e.container.read(quitStoreProvider.notifier).signOut();
    await e2e.waitFor(const Duration(seconds: 2));
    expect(settings(e2e).widgetPromptShown, isFalse);
    await signIn(e2e);
    await e2e.waitFor(const Duration(seconds: 2));

    expect(e2e.showing(l10n.widgetPromptAdd), isFalse);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2500));
    await e2e.settle();
    expect(e2e.showing(l10n.widgetPromptAdd), isFalse);
    // Not spent on somebody who did not need it.
    expect(settings(e2e).widgetPromptShown, isFalse);
    expect(analytics.names, isNot(contains('widget_prompt_shown')));
    expect(find.byType(WidgetPromptCard), findsOneWidget);
    await shot(e2e, 'widget-installed-no-card');
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
