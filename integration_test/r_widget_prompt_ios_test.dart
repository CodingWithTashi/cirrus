import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/data/api/widget_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/data/stores/settings_store.dart';
import 'package:last_puff/data/stores/widget_prompt_store.dart';
import 'package:last_puff/domain/analytics/analytics.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/taper_engine.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

/// Stage C of docs/15 on an iPhone: the walkthrough card against the REAL
/// widget count (`WidgetCenter.getCurrentConfigurations`) and real
/// `SharedPreferences`, the data on the fake backend. The Android twin is
/// `q_widget_prompt_test.dart`; on an iPhone no app can add a widget, so the
/// card shows three steps and "Got it" instead of a system dialog.
///
/// Adding the widget happens in Springboard, outside the app, so the test
/// prints `E2E-MARKER: add-widget` and waits; a Mac-side driver runs the
/// `RunnerUITests` XCUITest `testAddWidget` and relaunches the app. **The app
/// goes to the background while Springboard is driven, so that stretch only
/// awaits real time and polls the launcher — it never pumps a frame.**
///
/// Needs a fresh install on a simulator or phone with no Cirrus widget:
///
/// ```
/// flutter test integration_test/r_widget_prompt_ios_test.dart \
///   -d <udid> --dart-define=LP_BACKEND=fake
/// ```
///
/// The tests run in order and share the device's preferences on purpose.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 11, 13, 14, 30);
  final today = LpDate.dayStart(now);
  const launcher = HomeWidgetStore();
  final analytics = _Recording();

  /// A taper on plan day 4 — three completed days at their lines, so well past
  /// five puffs over two days — with setup finished and the cigarettes question
  /// answered, so nothing else competes for the screen.
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
    e2e.container.read(quitStoreProvider.notifier).replaceForTest(taper());
    await e2e.waitFor(const Duration(seconds: 2));
  }

  Future<E2E> open(WidgetTester tester) async {
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
    await signIn(e2e);
    return e2e;
  }

  /// The fake demo login passes through its seeded journey before the fixture
  /// replaces it, and that one qualifies: the card is seen and the one-time
  /// offer spent in those seconds. A real sign-in loads one real journey; forget
  /// it here so the test starts where a real account would.
  Future<void> freshOffer(E2E e2e) async {
    e2e.container.read(settingsStoreProvider.notifier).resetWidgetPrompt();
    e2e.container.invalidate(widgetPromptProvider);
    analytics.events.clear();
    await e2e.waitFor(const Duration(seconds: 2));
  }

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

  /// The card, on screen the way a person finds it: by scrolling.
  Future<void> scrollToCard(E2E e2e) async {
    final got = find.text(e2e.l10n.widgetPromptGotIt);
    if (got.hitTestable().evaluate().isEmpty) {
      await e2e.tester.scrollUntilVisible(
        got,
        150,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
      await e2e.settle();
    }
  }

  Future<void> restart(WidgetTester tester, E2E before) async {
    await before.waitFor(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox.shrink());
    before.container.dispose();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
  }

  testWidgets('the iPhone launcher: it cannot pin, and no Cirrus widget is '
      'placed', (tester) async {
    final pin = await launcher.canPin();
    final count = await launcher.installedCount();
    marker('launcher canPin=$pin installed=$count');

    expect(pin, isFalse, reason: 'iOS has no pin API');
    expect(
      count,
      0,
      reason: 'null means getCurrentConfigurations failed; 1+ means a Cirrus '
          'widget is already on this device — remove it and reinstall',
    );
  });

  testWidgets('the walkthrough card: three steps, "Got it" and "Not now", never '
      'an "Add widget" button; "Not now" is final, restart included',
      (tester) async {
    analytics.events.clear();
    final e2e = await open(tester);
    final l10n = e2e.l10n;
    await freshOffer(e2e);

    await scrollToCard(e2e);
    expect(e2e.visible(l10n.widgetPromptTitle), isTrue, reason: '${e2e.texts()}');
    expect(e2e.visible(l10n.widgetPromptStep1), isTrue);
    expect(e2e.visible(l10n.widgetPromptStep2), isTrue);
    expect(e2e.visible(l10n.widgetPromptStep3), isTrue);
    expect(e2e.visible(l10n.widgetPromptGotIt), isTrue);
    expect(e2e.visible(l10n.commonNotNow), isTrue);
    expect(e2e.showing(l10n.widgetPromptAdd), isFalse);
    await shot(e2e, 'ios-walkthrough-card');

    expect(analytics.propsOfAll('widget_prompt_shown'), [
      {'way': 'walkthrough'},
    ]);
    expect(settings(e2e).widgetPromptShown, isTrue);

    await e2e.tapText(l10n.commonNotNow);
    expect(e2e.showing(l10n.widgetPromptGotIt), isFalse);
    expect(analytics.names, isNot(contains('widget_prompt_accepted')));

    await e2e.waitFor(const Duration(seconds: 1));
    await restart(tester, e2e);

    analytics.events.clear();
    final again = await open(tester);
    await again.waitFor(const Duration(seconds: 2));
    expect(
      settings(again).widgetPromptShown,
      isTrue,
      reason: 'the flag did not come back from the preferences',
    );
    expect(again.showing(again.l10n.widgetPromptGotIt), isFalse);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2500));
    await again.settle();
    expect(again.showing(again.l10n.widgetPromptGotIt), isFalse);
    expect(analytics.names, isNot(contains('widget_prompt_shown')));
    await shot(again, 'ios-after-restart-no-card');
  });

  testWidgets('the next person is offered it once; "Got it", then the REAL '
      'widget is added in Springboard and found on resume', (tester) async {
    analytics.events.clear();
    final e2e = await open(tester);
    final l10n = e2e.l10n;
    expect(settings(e2e).widgetPromptShown, isTrue);

    e2e.container.read(quitStoreProvider.notifier).signOut();
    await e2e.waitFor(const Duration(seconds: 2));
    expect(settings(e2e).widgetPromptShown, isFalse);
    await signIn(e2e);
    await freshOffer(e2e);
    await scrollToCard(e2e);
    expect(e2e.visible(l10n.widgetPromptGotIt), isTrue, reason: '${e2e.texts()}');
    expect(analytics.propsOfAll('widget_prompt_shown'), hasLength(1));

    final seen = <AppLifecycleState>[];
    final listener = AppLifecycleListener(onStateChange: seen.add);
    addTearDown(listener.dispose);

    // Tapped twice before a frame can rebuild: one acceptance, never two.
    await e2e.tester.tap(find.text(l10n.widgetPromptGotIt), warnIfMissed: false);
    await e2e.tester.tap(find.text(l10n.widgetPromptGotIt), warnIfMissed: false);
    await e2e.tester.pump();
    expect(analytics.propsOfAll('widget_prompt_accepted'), [
      {'way': 'walkthrough'},
    ]);
    // "Got it" asks nothing of the OS: nothing has been added yet.
    expect(await launcher.installedCount(), 0);

    marker('add-widget');
    // The driver adds the widget in Springboard and relaunches the app. Real
    // time only — no pump — until the launcher reports it.
    final end = DateTime.now().add(const Duration(seconds: 420));
    var placed = 0;
    while (DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      placed = await launcher.installedCount() ?? 0;
      if (placed > 0) break;
    }
    marker('lifecycle: ${seen.map((s) => s.name).join(' > ')}');
    marker('launcher reports installed=$placed');
    expect(placed, greaterThan(0), reason: 'the widget was never added');

    final back = DateTime.now().add(const Duration(seconds: 60));
    while (DateTime.now().isBefore(back) &&
        !analytics.names.contains('widget_installed')) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    await e2e.waitFor(const Duration(seconds: 2));
    expect(
      analytics.names.where((n) => n == 'widget_installed'),
      hasLength(1),
      reason: 'lifecycle was ${seen.map((s) => s.name).join(' > ')}',
    );
    expect(e2e.showing(l10n.widgetPromptGotIt), isFalse);
    await shot(e2e, 'ios-after-add');
  });

  testWidgets('with the widget on the home screen the card does not come back '
      'for the next person, and is not spent on them', (tester) async {
    analytics.events.clear();
    final count = await launcher.installedCount();
    expect(count, greaterThan(0), reason: 'run after the test above');

    final e2e = await open(tester);
    final l10n = e2e.l10n;
    e2e.container.read(quitStoreProvider.notifier).signOut();
    await e2e.waitFor(const Duration(seconds: 2));
    expect(settings(e2e).widgetPromptShown, isFalse);
    await signIn(e2e);
    await e2e.waitFor(const Duration(seconds: 2));

    expect(e2e.showing(l10n.widgetPromptGotIt), isFalse);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2500));
    await e2e.settle();
    expect(e2e.showing(l10n.widgetPromptGotIt), isFalse);
    expect(settings(e2e).widgetPromptShown, isFalse);
    expect(analytics.names, isNot(contains('widget_prompt_shown')));
    await shot(e2e, 'ios-widget-installed-no-card');
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
