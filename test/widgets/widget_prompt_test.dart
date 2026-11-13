import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/api/widget_store.dart';
import 'package:last_puff/data/stores/day1_tour_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/data/stores/settings_store.dart';
import 'package:last_puff/data/stores/widget_prompt_store.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/home/home_screen.dart';
import 'package:last_puff/features/home/widgets/widget_prompt_card.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

/// docs/15 QP-C2: the one-time Home card that offers the home-screen widget.
///
/// Every case drives the real Home through the real stores; only the launcher
/// is a fake ([MemoryWidgetStore]), because the system dialog is not something
/// a widget test can open. What the real launcher answers is proved on a
/// device (`integration_test/q_widget_prompt_test.dart`).
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final now = DateTime(2026, 11, 13, 14, 30);

  /// Plan day 3 of a 30-day taper: days 1 and 2 logged at their lines, today
  /// not. Qualifies on every rule of `WidgetPromptPolicy`.
  JourneyState taper() => journeyOnDay(3, now: now);

  /// An Android launcher that can add a widget, with none placed.
  MemoryWidgetStore android() => MemoryWidgetStore()
    ..pinSupported = true
    ..installed = 0;

  Future<(ProviderContainer, RecordingAnalytics)> pumpHome(
    WidgetTester tester,
    JourneyState journey, {
    required MemoryWidgetStore widgets,
    double height = 2600,
    bool persist = false,
    SettingsStore Function()? settings,
    ProviderContainer? into,
  }) async {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
    tester.view.physicalSize = Size(393, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final analytics = RecordingAnalytics();
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(now: now, analytics: analytics),
        widgetStoreProvider.overrideWithValue(widgets),
        // A restart has to survive on real (mock) preferences, not on state
        // that dies with the container.
        if (persist) settingsStoreProvider.overrideWith(() => SettingsStore()),
        if (settings != null) settingsStoreProvider.overrideWith(settings),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).replaceForTest(journey);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    return (container, analytics);
  }

  Finder inCard(String text) => find.descendant(
    of: find.byType(WidgetPromptCard),
    matching: find.text(text),
  );

  Future<void> tapInCard(WidgetTester tester, String label) async {
    expect(inCard(label), findsOneWidget, reason: '"$label" in the card');
    await tester.ensureVisible(inCard(label));
    await tester.tap(inCard(label));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  /// The app going to the launcher and coming back — what the system pin
  /// dialog does to it. `AppLifecycleListener` asserts on a skipped state, so
  /// the walk is explicit.
  Future<void> backgroundAndReturn(WidgetTester tester) async {
    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  /// Lets write-behind preferences land, then tears the app down.
  Future<void> closeApp(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  }

  group('who sees it', () {
    testWidgets('a taper with five puffs over two days, on Android', (tester) async {
      final (container, analytics) = await pumpHome(
        tester,
        taper(),
        widgets: android(),
      );

      expect(find.byType(WidgetPromptCard), findsOneWidget);
      expect(inCard(l10n.widgetPromptTitle), findsOneWidget);
      expect(inCard(l10n.widgetPromptBody), findsOneWidget);
      expect(inCard(l10n.widgetPromptAdd), findsOneWidget);
      expect(inCard(l10n.commonNotNow), findsOneWidget);
      // One tap to the system dialog; the steps are for an iPhone.
      expect(inCard(l10n.widgetPromptStep1), findsNothing);

      expect(analytics.propsOfAll('widget_prompt_shown'), [
        {'way': 'pinDialog'},
      ]);
      expect(container.read(settingsStoreProvider).widgetPromptShown, isTrue);
    });

    testWidgets('and says it makes logging quicker, not that it helps anybody quit',
        (tester) async {
      await pumpHome(tester, taper(), widgets: android());

      final text = [
        l10n.widgetPromptTitle,
        l10n.widgetPromptBody,
      ].join(' ').toLowerCase();
      expect(text, contains('log'));
      expect(text, isNot(contains('quit')));
      expect(text, isNot(contains('help')));
    });

    testWidgets('the moment the fifth puff is logged, not before', (tester) async {
      // Plan day 2 with three puffs yesterday: two days short of nothing, three
      // puffs short of five.
      final journey = journeyOnDay(2, now: now, puffsByDay: {1: 3});
      final (container, _) = await pumpHome(tester, journey, widgets: android());
      expect(inCard(l10n.widgetPromptAdd), findsNothing, reason: '3 puffs');

      final store = container.read(quitStoreProvider.notifier);
      store.logPuff();
      await tester.pumpAndSettle();
      expect(inCard(l10n.widgetPromptAdd), findsNothing, reason: '4 puffs');

      store.logPuff();
      await tester.pumpAndSettle();
      expect(inCard(l10n.widgetPromptAdd), findsOneWidget, reason: '5 puffs');
    });

    testWidgets('not a cold-turkey account', (tester) async {
      final base = taper();
      final cold = base.copyWith(
        plan: base.plan.copyWith(method: QuitMethod.coldTurkey),
      );
      await pumpHome(tester, cold, widgets: android());

      expect(inCard(l10n.widgetPromptAdd), findsNothing);
    });

    testWidgets('not on a device with no widget host — the fake backend as it is',
        (tester) async {
      // The default fake: cannot pin, cannot count. This is what every other
      // Home fixture in the suite runs on, and why none of them has this card.
      final (container, analytics) = await pumpHome(
        tester,
        taper(),
        widgets: MemoryWidgetStore(),
      );

      expect(inCard(l10n.widgetPromptAdd), findsNothing);
      expect(container.read(settingsStoreProvider).widgetPromptShown, isFalse);
      expect(analytics.names, isNot(contains('widget_prompt_shown')));
    });

    testWidgets('not when a widget is already on the home screen', (tester) async {
      final (container, _) = await pumpHome(
        tester,
        taper(),
        widgets: android()..installed = 1,
      );

      expect(inCard(l10n.widgetPromptAdd), findsNothing);
      // And the one-time offer was not spent on somebody who did not need it.
      expect(container.read(settingsStoreProvider).widgetPromptShown, isFalse);
    });

    testWidgets('not while the Day-1 tour is running, and the offer is not spent',
        (tester) async {
      // Three puffs yesterday and the tour already running: logging two more
      // makes the account qualify in the middle of the tour.
      final journey = journeyOnDay(
        2,
        now: now,
        puffsByDay: {1: 3},
      ).copyWith(day1TasksDone: const {});
      final (container, analytics) = await pumpHome(
        tester,
        journey,
        widgets: android(),
      );
      container.read(day1TourProvider.notifier).start(Day1TourStep.logPuff);
      await tester.pumpAndSettle();
      expect(container.read(day1TourLockedProvider), isTrue);

      final store = container.read(quitStoreProvider.notifier);
      store.logPuff();
      store.logPuff();
      await tester.pumpAndSettle();

      expect(inCard(l10n.widgetPromptAdd), findsNothing);
      expect(container.read(settingsStoreProvider).widgetPromptShown, isFalse);
      expect(analytics.names, isNot(contains('widget_prompt_shown')));

      // The offer waited: it is made once the tour is over.
      container.read(day1TourProvider.notifier).skip();
      await tester.pumpAndSettle();
      expect(inCard(l10n.widgetPromptAdd), findsOneWidget);
    });

    testWidgets('a card already up stands down when the tour starts',
        (tester) async {
      final journey = taper().copyWith(day1TasksDone: const {});
      final (container, _) = await pumpHome(
        tester,
        journey,
        widgets: android(),
      );
      expect(inCard(l10n.widgetPromptAdd), findsOneWidget);

      // A checklist row tapped on a later day starts the tour on Home.
      container.read(day1TourProvider.notifier).start(Day1TourStep.logPuff);
      await tester.pumpAndSettle();

      expect(inCard(l10n.widgetPromptAdd), findsNothing);
    });

    testWidgets('not before settings have hydrated, then once they have',
        (tester) async {
      final cold = _ColdSettings();
      final (container, analytics) = await pumpHome(
        tester,
        taper(),
        widgets: android(),
        settings: () => cold,
      );

      expect(inCard(l10n.widgetPromptAdd), findsNothing);
      expect(container.read(settingsStoreProvider).widgetPromptShown, isFalse);
      expect(analytics.names, isNot(contains('widget_prompt_shown')));

      cold.hydrateNow();
      await tester.pumpAndSettle();

      expect(inCard(l10n.widgetPromptAdd), findsOneWidget);
      expect(analytics.propsOfAll('widget_prompt_shown'), hasLength(1));
    });

    testWidgets('a card nobody has scrolled to is not spent', (tester) async {
      // A short phone: the card sits below the fold. "Shown once" must mean
      // seen once — the day-3 offer card counted 114 impressions from 26 people
      // for want of exactly this, and this card has one chance.
      final (container, analytics) = await pumpHome(
        tester,
        taper(),
        widgets: android(),
        height: 640,
      );
      expect(container.read(settingsStoreProvider).widgetPromptShown, isFalse);
      expect(analytics.names, isNot(contains('widget_prompt_shown')));

      await tester.scrollUntilVisible(
        find.byType(WidgetPromptCard),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(container.read(settingsStoreProvider).widgetPromptShown, isTrue);
      expect(analytics.propsOfAll('widget_prompt_shown'), hasLength(1));
    });
  });

  group('it is spent only when it is seen', () {
    // Home stays mounted under the other tabs and under any route pushed over
    // it, laid out and with a size. A check on the scroll offset alone passes
    // there, so the one-time offer used to be written and reported for a card
    // nobody could see — and the quick-log `+` is on every tab, so the fifth
    // puff can be logged from Stats.
    JourneyState fourPuffs() => journeyOnDay(2, now: now, puffsByDay: {1: 4});

    testWidgets('not while another tab is showing', (tester) async {
      final (container, analytics) = await pumpHome(
        tester,
        fourPuffs(),
        widgets: android(),
      );
      container.read(routerProvider).go(Routes.stats);
      await tester.pumpAndSettle();

      container.read(quitStoreProvider.notifier).logPuff(); // the fifth
      await tester.pumpAndSettle();

      expect(container.read(settingsStoreProvider).widgetPromptShown, isFalse);
      expect(analytics.names, isNot(contains('widget_prompt_shown')));

      container.read(routerProvider).go(Routes.home);
      await tester.pumpAndSettle();

      expect(inCard(l10n.widgetPromptAdd), findsOneWidget);
      expect(container.read(settingsStoreProvider).widgetPromptShown, isTrue);
      expect(analytics.propsOfAll('widget_prompt_shown'), hasLength(1));
    });

    testWidgets('not while a route is pushed over Home', (tester) async {
      final (container, analytics) = await pumpHome(
        tester,
        fourPuffs(),
        widgets: android(),
      );
      unawaited(container.read(routerProvider).push(Routes.settings));
      await tester.pumpAndSettle();

      container.read(quitStoreProvider.notifier).logPuff();
      await tester.pumpAndSettle();

      expect(container.read(settingsStoreProvider).widgetPromptShown, isFalse);
      expect(analytics.names, isNot(contains('widget_prompt_shown')));

      container.read(routerProvider).pop();
      await tester.pumpAndSettle();

      expect(inCard(l10n.widgetPromptAdd), findsOneWidget);
      expect(container.read(settingsStoreProvider).widgetPromptShown, isTrue);
    });
  });

  group('coming back from the launcher', () {
    testWidgets('is noticed with the card nowhere in the tree', (tester) async {
      // Home is a lazily built list: a card beyond its cache extent is not
      // built at all, and one that was built and scrolled away is disposed. A
      // listener that lived in the card was gone in both cases, so a person who
      // added the widget and came back to a Home scrolled elsewhere was never
      // noticed. This viewport is short enough that the card is beyond the
      // cache from the top.
      final widgets = android();
      final (container, analytics) = await pumpHome(
        tester,
        taper(),
        widgets: widgets,
        height: 320,
      );
      expect(find.byType(WidgetPromptCard), findsNothing, reason: 'not built');

      // The offer was put up and taken earlier in the visit (the card's first
      // build is what reads the launcher; nothing has built it here).
      final prompt = container.read(widgetPromptProvider.notifier);
      await prompt.probe();
      prompt.show();
      await prompt.accept();
      await tester.pumpAndSettle();
      expect(widgets.pinRequests, 1);
      expect(find.byType(WidgetPromptCard), findsNothing);

      widgets.placeWidget();
      await backgroundAndReturn(tester);

      expect(
        analytics.names.where((n) => n == 'widget_installed'),
        hasLength(1),
      );
    });
  });

  group('adding it on Android', () {
    testWidgets('"Add widget" opens the system dialog and the card goes',
        (tester) async {
      final widgets = android();
      final (_, analytics) = await pumpHome(tester, taper(), widgets: widgets);

      await tapInCard(tester, l10n.widgetPromptAdd);

      expect(widgets.pinRequests, 1);
      expect(inCard(l10n.widgetPromptAdd), findsNothing);
      expect(analytics.propsOfAll('widget_prompt_accepted'), [
        {'way': 'pinDialog'},
      ]);
      expect(analytics.names, isNot(contains('widget_installed')));
    });

    testWidgets('coming back from the dialog with the widget placed reports it once',
        (tester) async {
      final widgets = android();
      final (_, analytics) = await pumpHome(tester, taper(), widgets: widgets);
      await tapInCard(tester, l10n.widgetPromptAdd);

      widgets.placeWidget();
      await backgroundAndReturn(tester);
      await backgroundAndReturn(tester);

      expect(
        analytics.names.where((n) => n == 'widget_installed'),
        hasLength(1),
      );
      expect(inCard(l10n.widgetPromptAdd), findsNothing);
    });

    testWidgets('coming back from a dialog that was cancelled reports nothing',
        (tester) async {
      final (_, analytics) = await pumpHome(tester, taper(), widgets: android());
      await tapInCard(tester, l10n.widgetPromptAdd);

      await backgroundAndReturn(tester);

      expect(analytics.names, isNot(contains('widget_installed')));
    });
  });

  group('never again', () {
    for (final answer in ['Add widget', 'Not now']) {
      testWidgets('after "$answer", not even after a restart', (tester) async {
        final (first, _) = await pumpHome(
          tester,
          taper(),
          widgets: android(),
          persist: true,
        );
        // Let the first launch's settings read settle before answering.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpAndSettle();
        expect(inCard(l10n.widgetPromptAdd), findsOneWidget);

        await tapInCard(
          tester,
          answer == 'Add widget' ? l10n.widgetPromptAdd : l10n.commonNotNow,
        );
        expect(inCard(l10n.widgetPromptAdd), findsNothing);
        expect(first.read(settingsStoreProvider).widgetPromptShown, isTrue);

        await closeApp(tester);
        first.dispose();

        // The restart: a new process reading the same preferences, a launcher
        // that still has no widget on it.
        final (second, analytics) = await pumpHome(
          tester,
          taper(),
          widgets: android(),
          persist: true,
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpAndSettle();

        expect(second.read(settingsStoreProvider).widgetPromptShown, isTrue);
        expect(inCard(l10n.widgetPromptAdd), findsNothing);
        expect(analytics.names, isNot(contains('widget_prompt_shown')));
      });
    }

    testWidgets('a card that was up and never answered does not return either',
        (tester) async {
      // "Shown once" taken at its word: the flag is written when the card is
      // put up, so a person who ignored it and restarted is not asked again.
      await pumpHome(tester, taper(), widgets: android(), persist: true);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(inCard(l10n.widgetPromptAdd), findsOneWidget);

      await closeApp(tester);

      final (second, _) = await pumpHome(
        tester,
        taper(),
        widgets: android(),
        persist: true,
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(second.read(settingsStoreProvider).widgetPromptShown, isTrue);
      expect(inCard(l10n.widgetPromptAdd), findsNothing);
    });
  });

  group('on an iPhone', () {
    testWidgets('three steps and "Got it", never a button that does nothing',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final widgets = MemoryWidgetStore()..installed = 0;
        final (_, analytics) = await pumpHome(tester, taper(), widgets: widgets);

        expect(inCard(l10n.widgetPromptTitle), findsOneWidget);
        expect(inCard(l10n.widgetPromptStep1), findsOneWidget);
        expect(inCard(l10n.widgetPromptStep2), findsOneWidget);
        expect(inCard(l10n.widgetPromptStep3), findsOneWidget);
        expect(inCard(l10n.widgetPromptAdd), findsNothing);
        expect(analytics.propsOfAll('widget_prompt_shown'), [
          {'way': 'walkthrough'},
        ]);

        await tapInCard(tester, l10n.widgetPromptGotIt);

        expect(widgets.pinRequests, 0);
        expect(inCard(l10n.widgetPromptStep1), findsNothing);
        expect(analytics.propsOfAll('widget_prompt_accepted'), [
          {'way': 'walkthrough'},
        ]);

        widgets.placeWidget();
        await backgroundAndReturn(tester);
        expect(analytics.names, contains('widget_installed'));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('not when the widgets cannot be counted', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        // The fake backend's no-host store: an iPhone this card cannot read.
        await pumpHome(tester, taper(), widgets: MemoryWidgetStore());
        expect(inCard(l10n.widgetPromptGotIt), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('Not now', () {
    testWidgets('takes the card down and says nothing about it', (tester) async {
      final widgets = android();
      final (_, analytics) = await pumpHome(tester, taper(), widgets: widgets);

      await tapInCard(tester, l10n.commonNotNow);

      expect(inCard(l10n.widgetPromptAdd), findsNothing);
      expect(widgets.pinRequests, 0);
      expect(analytics.names, isNot(contains('widget_prompt_accepted')));
    });
  });
}

/// Settings as they are on a cold start before SharedPreferences has answered.
class _ColdSettings extends SettingsStore {
  _ColdSettings() : super(restore: false);

  @override
  SettingsState build() => const SettingsState(hydrated: false);

  void hydrateNow() => state = state.copyWith(hydrated: true);
}
