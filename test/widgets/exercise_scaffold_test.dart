import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/widgets/lp_misc.dart';
import 'package:last_puff/data/stores/exercise_runs.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/exercises/exercise.dart';
import 'package:last_puff/domain/logic/games/game_id.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';
import 'package:last_puff/features/panic/breath_ring.dart';
import 'package:last_puff/features/panic/games/intensity_row.dart';
import 'package:last_puff/features/panic/panic_screens.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';

/// An exercise on a screen of its own, on the real router: breathing, opened
/// the way a coach card opens it.
///
/// The frame around every such exercise has two exits and they are the
/// arena's two: "It passed" (the craving is counted, once, through the path
/// every craving takes) and back (nothing is counted). Either way the run is
/// filed, so the chat that offered it can tell Ember what they did.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  const pattern = '/panic/exercise/:id';
  final breathing = Routes.exerciseFor(
    ExerciseId.breathing,
    ExerciseSource.coach,
  );

  late RecordingAnalytics analytics;
  late _CountingPanic panic;
  late _Clock clock;

  setUp(() {
    analytics = RecordingAnalytics();
    panic = _CountingPanic();
    clock = _Clock(DateTime(2026, 9, 5, 14));
  });

  /// The app on the coach tab, where a card would be.
  Future<ProviderContainer> boot(WidgetTester tester) async {
    final c = ProviderContainer(
      overrides: fastBackendOverrides(
        analytics: analytics,
        extra: [
          panicRepositoryProvider.overrideWithValue(panic),
          nowProvider.overrideWithValue(clock.read),
        ],
      ),
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const LastPuffApp()),
    );
    c.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    c.read(routerProvider).go(Routes.coach);
    await tester.pumpAndSettle();
    analytics.screens.clear();
    return c;
  }

  /// Fixed pumps, never `pumpAndSettle`: the ring breathes for as long as it
  /// is on screen.
  Future<void> beat(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> open(
    WidgetTester tester,
    ProviderContainer c, [
    String? location,
  ]) async {
    unawaited(c.read(routerProvider).push(location ?? breathing));
    await beat(tester);
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byType(BackChevron));
    await beat(tester);
    await beat(tester);
  }

  Future<void> itPassed(WidgetTester tester) async {
    await tester.tap(find.text(l10n.panicItPassed));
    await tester.pump();
    // Long enough for the replaced page to finish leaving and dispose.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  int survived(ProviderContainer c) =>
      c.read(quitStoreProvider)!.cravingsSurvivedTotal;
  String path(ProviderContainer c) => c.read(routerProvider).state.uri.path;
  List<Map<String, Object>> outcomes() =>
      analytics.propsOfAll('craving_outcome');
  List<Map<String, Object>> runs() => analytics.propsOfAll('exercise_finished');

  testWidgets('breathing opens on its own', (tester) async {
    final c = await boot(tester);

    await open(tester, c);

    expect(find.byType(BreathRing), findsOneWidget);
    expect(find.text(l10n.panicBreatheInstruction), findsOneWidget);
    expect(find.text(l10n.exerciseBreathingTitle), findsOneWidget);
    expect(find.byType(IntensityRow), findsOneWidget);
    expect(find.text(l10n.panicItPassed), findsOneWidget);
    // On its own: no takeover beneath it, and no step counter above it.
    expect(find.byType(PanicFlow), findsNothing);
    // A screen view under the route's pattern, never a filled URL.
    expect(analytics.screens, contains(pattern));
    expect(analytics.screens.where((s) => s.contains('?')), isEmpty);
    expect(analytics.screens.where((s) => s.contains('breathing')), isEmpty);
    // And it is a craving: the clock runs and the server was told, once.
    expect(c.read(panicProvider).startedAt, clock.now);
    expect(panic.begins, 1);
  });

  testWidgets('back leaves, counts nothing, and files the run', (tester) async {
    final c = await boot(tester);
    final before = survived(c);
    await open(tester, c);

    await back(tester);

    expect(find.byType(BreathRing), findsNothing);
    expect(path(c), Routes.coach);
    expect(survived(c), before);
    expect(outcomes(), isEmpty, reason: 'back is not an outcome');
    expect(panic.reports, isEmpty);
    expect(runs(), [
      {
        'exercise': 'breathing',
        'source': 'coach',
        'completed': 'false',
        'passed': 'false',
        'seconds': 0,
      },
    ]);
    // Held for the chat that offered it.
    final run = c
        .read(exerciseRunsProvider.notifier)
        .peekRecent(source: ExerciseSource.coach, now: clock.now);
    expect(run?.id, ExerciseId.breathing);
    expect(run?.passed, isFalse);

    // The craving is parked, not abandoned and not left open: the next one
    // closes it, once.
    unawaited(c.read(routerProvider).push(Routes.panic));
    await beat(tester);
    expect(panic.begins, 2);
    expect(outcomes(), hasLength(1));
    expect(outcomes().single, containsPair('survived', 'false'));
  });

  testWidgets('it passed counts the craving once and files the run', (
    tester,
  ) async {
    final c = await boot(tester);
    final before = survived(c);
    await open(tester, c);

    clock.now = clock.now.add(const Duration(seconds: 60));
    await tester.tap(
      find.descendant(of: find.byType(IntensityRow), matching: find.text('3')),
    );
    await tester.pump();
    await itPassed(tester);

    expect(find.byType(SurvivedScreen), findsOneWidget);
    expect(find.byType(BreathRing), findsNothing);
    expect(survived(c), before + 1);
    // Opened cold, so there is an after-rating and no first one.
    expect(outcomes(), [
      {
        'survived': 'true',
        'game': 'none',
        'rounds': 0,
        'intensity_after': 3,
        'exercise': 'breathing',
        'source': 'coach',
      },
    ]);
    expect(panic.reports, hasLength(1));
    // Filed once: not again when the screen it replaced is torn down.
    expect(runs(), [
      {
        'exercise': 'breathing',
        'source': 'coach',
        'completed': 'true',
        'passed': 'true',
        'seconds': 60,
      },
    ]);
    expect(panic.begins, 1);
  });

  testWidgets('fifty-seven seconds is three breaths, and counts as done', (
    tester,
  ) async {
    final c = await boot(tester);
    await open(tester, c);
    clock.now = clock.now.add(const Duration(seconds: 56));
    await back(tester);

    await open(tester, c);
    clock.now = clock.now.add(const Duration(seconds: 57));
    await back(tester);

    expect(
      [for (final run in runs()) (run['seconds'], run['completed'])],
      [(56, 'false'), (57, 'true')],
    );
    // Back, twice, inside one craving window: still one craving.
    expect(panic.begins, 1);
    expect(outcomes(), isEmpty);
  });

  // `screen_layout_test` has to ignore overflow, because the test font is
  // far wider than the app's. This frame is built so that even that font
  // fits: the title wraps, the ten circles scale down (they are 320 wide and
  // a 360-wide phone leaves 312), and the exercise scrolls when the viewport
  // is too short for it.
  for (final size in const [Size(360, 640), Size(320, 568)]) {
    testWidgets('the frame fits a small phone without overflowing '
        '(${size.width.round()}x${size.height.round()})', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = await boot(tester);

      await open(tester, c);

      expect(find.byType(BreathRing), findsOneWidget);
      expect(tester.takeException(), isNull);
      final row = tester.getRect(find.byType(IntensityRow));
      expect(row.left, greaterThanOrEqualTo(0));
      expect(row.right, lessThanOrEqualTo(size.width));
    });
  }

  testWidgets('an id with no screen is the not-found page', (tester) async {
    final c = await boot(tester);

    // An arena game has no screen of its own; `nope` is not an exercise.
    for (final id in ['orbs', 'nope']) {
      analytics.screens.clear();
      await open(tester, c, '${Routes.exerciseBase}/$id?src=coach');

      expect(find.byType(RouteNotFoundScreen), findsOneWidget, reason: id);
      // The route itself answered, rather than the router giving up.
      expect(analytics.screens, [pattern], reason: id);
      expect(find.byType(IntensityRow), findsNothing, reason: id);
      c.read(routerProvider).pop();
      await beat(tester);
      await beat(tester);
    }
    // Nothing was opened, so there is nothing to close or file.
    expect(panic.begins, 0);
    expect(c.read(panicProvider).startedAt, isNull);
    expect(runs(), isEmpty);
  });

  testWidgets('a craving handed over by the takeover continues here', (
    tester,
  ) async {
    // Review Focus 1, on the card the server actually sends mid-craving
    // (`panic_default`: breathing). Arrives from the flow at 8/10, taps it.
    final c = await boot(tester);
    unawaited(c.read(routerProvider).push(Routes.panic));
    await beat(tester);
    c.read(panicProvider.notifier)
      ..previewStep(2)
      ..setIntensity(8);
    await beat(tester);
    final startedAt = c.read(panicProvider).startedAt;
    await tester.ensureVisible(find.text(l10n.panicLoopCoach));
    await tester.pump();
    await tester.tap(find.text(l10n.panicLoopCoach));
    await beat(tester);
    await beat(tester);
    expect(path(c), Routes.coach);

    clock.now = clock.now.add(const Duration(minutes: 3));
    await open(tester, c);

    expect(find.byType(BreathRing), findsOneWidget);
    expect(panic.begins, 1, reason: 'the same craving, the same session');
    expect(c.read(panicProvider).startedAt, startedAt);
    expect(c.read(panicProvider).intensity, 8);

    await itPassed(tester);
    expect(outcomes(), hasLength(1));
    expect(outcomes().single, containsPair('survived', 'true'));
    expect(outcomes().single, containsPair('intensity', 8));
    expect(outcomes().single, containsPair('exercise', 'breathing'));
    expect(panic.reports.single.intensity, 8);
  });

  testWidgets('reached from the takeover it owns nothing', (tester) async {
    // The same rule as the arena: a craving the takeover opened is the
    // takeover's to close. If this screen parked it on the way out, the
    // flow's own exit would find nothing left to report.
    final c = await boot(tester);
    unawaited(c.read(routerProvider).push(Routes.panic));
    await beat(tester);
    c.read(panicProvider.notifier).previewStep(2);
    await beat(tester);
    await open(
      tester,
      c,
      Routes.exerciseFor(ExerciseId.breathing, ExerciseSource.panic),
    );
    expect(find.byType(BreathRing), findsOneWidget);
    expect(panic.begins, 1);

    await back(tester);
    expect(find.byType(PanicFlow), findsOneWidget);
    expect(outcomes(), isEmpty);
    expect(runs().single, containsPair('source', 'panic'));

    c.read(routerProvider).go(Routes.home);
    await beat(tester);
    await beat(tester);
    expect(outcomes(), hasLength(1));
    expect(outcomes().single, containsPair('survived', 'false'));
  });
}

/// The `panicSession` hop, counted.
class _CountingPanic implements PanicRepository {
  int begins = 0;

  /// Every craving reported survived, as the server would receive it.
  final reports = <_Report>[];

  @override
  Future<PanicAvailability> begin() async {
    begins++;
    return PanicAvailability.unknown;
  }

  @override
  Future<void> survived({
    int? intensity,
    int? intensityAfter,
    GameId? game,
    ExerciseId? exercise,
    ExerciseSource? source,
  }) async {
    reports.add((
      intensity: intensity,
      intensityAfter: intensityAfter,
      game: game,
      exercise: exercise,
      source: source,
    ));
  }
}

typedef _Report = ({
  int? intensity,
  int? intensityAfter,
  GameId? game,
  ExerciseId? exercise,
  ExerciseSource? source,
});

/// A clock a test can move forward.
class _Clock {
  _Clock(this.now);

  DateTime now;

  DateTime read() => now;
}
