import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/allowances.dart';
import 'package:last_puff/domain/logic/games/game_id.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';
import 'package:last_puff/features/coach/coach_screen.dart';
import 'package:last_puff/features/panic/panic_screens.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// The panic flow's server hop (`panicSession`, docs/03 §7 + docs/04 §7).
///
/// The rule these protect is the one docs/04 §7 states outright: never
/// hard-block someone mid-crisis. The server's answer may take the AI layer
/// away; it may not take the flow away, and it may not make the screen wait
/// for a round-trip.
void main() {
  late _StubPanic panic;
  late RecordingAnalytics analytics;

  setUp(() {
    panic = _StubPanic();
    analytics = RecordingAnalytics();
  });

  /// Mounts just enough app to own a ProviderScope. The panic view model is
  /// route-scoped, so reading the notifier is exactly what a route push does.
  Future<ProviderContainer> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...fastBackendOverrides(analytics: analytics),
          panicRepositoryProvider.overrideWithValue(panic),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox.shrink(),
        ),
      ),
    );
    return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  }

  testWidgets('opening the flow tells the server a craving started', (
    tester,
  ) async {
    final c = await mount(tester);
    c.read(panicProvider);
    await tester.pumpAndSettle();

    expect(panic.begins, 1);
    // And the first step is already on screen — nothing awaited the call.
    expect(c.read(panicProvider).step, 0);
  });

  testWidgets('a re-rated craving reports both numbers and the game', (
    tester,
  ) async {
    final c = await mount(tester);
    c.read(quitStoreProvider.notifier).seedDemoJourney();

    final vm = c.read(panicProvider.notifier);
    vm.setIntensity(8);
    vm.noteGame(GameId.blocks, rounds: 2);
    vm.survive(intensityAfter: 3);
    await tester.pumpAndSettle();

    expect(panic.survivedIntensities, [8]);
    expect(panic.survivedAfter, [3]);
    expect(panic.survivedGames, [GameId.blocks]);

    // Skipping the re-ask sends nothing in its place, never a guess.
    c.read(panicProvider.notifier).survive();
    await tester.pumpAndSettle();
    expect(panic.survivedAfter, [3, null]);
    expect(panic.survivedGames, [GameId.blocks, null]);
  });

  testWidgets('a survived craving is reported with its intensity', (
    tester,
  ) async {
    final c = await mount(tester);
    c.read(quitStoreProvider.notifier).seedDemoJourney();
    final before = c.read(quitStoreProvider)!.cravingsSurvivedTotal;

    c.read(panicProvider.notifier).setIntensity(9);
    c.read(panicProvider.notifier).survive();
    await tester.pumpAndSettle();

    expect(panic.survivedIntensities, [9]);
    // The user's own count still moves locally — the report is telemetry, not
    // the source of truth for the number on their screen.
    expect(c.read(quitStoreProvider)!.cravingsSurvivedTotal, before + 1);
  });

  testWidgets('an unreachable server leaves the AI option offered', (
    tester,
  ) async {
    panic.failure = const NoConnectionException();
    final c = await mount(tester);
    c.read(panicProvider);
    await tester.pumpAndSettle();

    // Optimistic on purpose: withholding help because wifi dropped is the one
    // outcome worse than an over-quota model call.
    expect(c.read(panicProvider).availability.aiAvailable, isTrue);
  });

  testWidgets('a spent free allowance narrows the AI layer, not the flow', (
    tester,
  ) async {
    panic.result = const PanicAvailability(
      aiAvailable: false,
      sessionsToday: 2,
    );
    final c = await mount(tester);
    c.read(panicProvider);
    await tester.pumpAndSettle();

    expect(c.read(panicProvider).availability.aiAvailable, isFalse);
    // The session itself is untouched: breathing, the why card and the tap
    // game are all still where they were.
    expect(c.read(panicProvider).step, 0);

    // …and the narrowing is now visible. Only a free account past its
    // allowance ever gets this answer, and `sessionsToday` is the server's own
    // count — the ceiling is a server constant it does not send, so no
    // `limit` is invented for it.
    expect(analytics.propsOfAll('limit_reached'), [
      {'capability': 'panic_ai', 'tier': 'free', 'used': 2},
    ]);
  });

  testWidgets('an offered AI layer reports no wall', (tester) async {
    final c = await mount(tester);
    c.read(panicProvider);
    await tester.pumpAndSettle();

    expect(analytics.propsOfAll('limit_reached'), isEmpty);
  });

  testWidgets('an unreachable server is not reported as a spent allowance', (
    tester,
  ) async {
    // The optimistic fallback keeps `aiAvailable` true, so this would only
    // regress if someone inverted the check — but an outage counted as a wall
    // would inflate the one number that decides whether 1/day is right.
    panic.failure = const NoConnectionException();
    final c = await mount(tester);
    c.read(panicProvider);
    await tester.pumpAndSettle();

    expect(analytics.propsOfAll('limit_reached'), isEmpty);
  });

  group('the AI option never sells to somebody mid-craving', () {
    // The door itself is gone: `onTap` has no branch left, it always opens the
    // coach with the craving's intensity. This asserts the DELETION, which is
    // the thing a future edit could quietly undo — the same shape as
    // `android_manifest_test`, which pins absences for the same reason.
    test('no paywall door survives anywhere in the panic flow', () {
      final source = File('lib/features/panic/panic_screens.dart')
          .readAsStringSync();
      expect(
        source,
        isNot(contains('paywallFrom')),
        reason: 'a purchase decision at 9/10 craving intensity is the least '
            'considered moment a person has',
      );
      expect(source, isNot(contains('Routes.paywall')));
    });

    /// The coach mounted on its own, entered the way the panic option enters
    /// it, with the cap as its next answer.
    ///
    /// No panic flow and no shell: the breath ring and craving timer animate
    /// for as long as that screen is open, so nothing underneath them ever
    /// settles. And the cap arrives from a stub rather than by spending five
    /// real messages — the fake backend answers through `Future.delayed`, which
    /// never completes under `testWidgets` unless the clock is pumped between
    /// every send.
    Future<ProviderContainer> coachCap(
      WidgetTester tester, {
      required bool fromPanic,
      DateTime Function()? now,
    }) async {
      final c = ProviderContainer(
        overrides: [
          ...fastBackendOverrides(premium: false, analytics: analytics),
          coachRepositoryProvider.overrideWithValue(const _CappedCoach()),
          if (now != null) nowProvider.overrideWithValue(now),
        ],
      );
      addTearDown(c.dispose);
      c.read(quitStoreProvider.notifier).seedDemoJourney();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: LpTheme.midnight(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CoachScreen(panicIntensity: fromPanic ? 9 : null),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await c.read(coachStoreProvider.notifier).send('help');
      await tester.pumpAndSettle();
      expect(
        c.read(coachStoreProvider).messages.last.template,
        CoachTemplate.capReached,
      );
      return c;
    }

    testWidgets('the coach cap holds its tongue when the craving sent you', (
      tester,
    ) async {
      // The other half of deleting the door: routing to the coach instead
      // would only move the mid-craving purchase decision one screen along if
      // the cap bubble still carried its upgrade button.
      await coachCap(tester, fromPanic: true);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // The words still explain what happened. The button does not.
      expect(
        find.text(l10n.coachCapReached(LpAllowances.freeCoachMessages)),
        findsOneWidget,
      );
      expect(find.text(l10n.premiumLockCta), findsNothing);
    });

    testWidgets('and speaks normally when the coach was opened by choice', (
      tester,
    ) async {
      // The guard must not silence the strongest door in the app for everyone
      // — only for the person who arrived mid-craving.
      await coachCap(tester, fromPanic: false);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.premiumLockCta), findsOneWidget);
    });

    testWidgets('and speaks again once the craving has passed', (tester) async {
      // The suppression is a TIMESTAMP, not a flag, precisely so it clears
      // itself. The coach tab is keep-alive — switching to it from the bottom
      // bar pushes no route — so a flag would stay true for the rest of the
      // session and hide the strongest door in the app long after the craving.
      final clock = _MovableClock(DateTime(2026, 9, 3, 14));
      final c = await coachCap(
        tester,
        fromPanic: true,
        now: clock.read,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.premiumLockCta), findsNothing);

      // Past the app's own model of a craving (docs/03 §7: most pass in
      // 15-20 minutes).
      clock.now = clock.now.add(const Duration(minutes: 21));
      // MinuteClock has no public tick; invalidating it re-reads `nowProvider`
      // exactly as its periodic timer would.
      c.invalidate(minuteClockProvider);
      await tester.pumpAndSettle();
      expect(find.text(l10n.premiumLockCta), findsOneWidget);
    });
  });

  /// Mounts the real PanicFlow against a container the TEST owns, so
  /// replacing the tree (what popping the route does) disposes the widget
  /// without disposing the providers underneath it.
  Future<ProviderContainer> mountFlow(WidgetTester tester) async {
    final c = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        panicRepositoryProvider.overrideWithValue(panic),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: LpTheme.midnight(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PanicFlow(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    return c;
  }

  Future<void> unmountFlow(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: LpTheme.midnight(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('closing the takeover does not throw', (tester) async {
    // Found by the on-device run: `dispose()` read `ref`, which Riverpod
    // forbids once the element is gone, so EVERY close of the panic flow threw
    // "Cannot use ref after the widget was disposed". The widget suite missed
    // it because nothing here had ever unmounted PanicFlow.
    final c = await mountFlow(tester);
    await unmountFlow(tester, c);

    expect(tester.takeException(), isNull);
  });

  testWidgets('closing without surviving reports the craving abandoned', (
    tester,
  ) async {
    final c = await mountFlow(tester);
    await unmountFlow(tester, c);

    expect(panic.survivedIntensities, isEmpty);
    expect(c.read(panicProvider).step, 0);
  });

  testWidgets('a survived craving is not also counted as abandoned', (
    tester,
  ) async {
    final c = await mountFlow(tester);
    c.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(milliseconds: 400));
    final before = c.read(quitStoreProvider)!.cravingsSurvivedTotal;

    c.read(panicProvider.notifier).survive();
    await tester.pump(const Duration(milliseconds: 400));
    await unmountFlow(tester, c);

    // survive() invalidates the notifier, so a `ref.read` in dispose would
    // hand back a FRESH, unresolved session and count this same craving twice.
    expect(tester.takeException(), isNull);
    expect(panic.survivedIntensities, hasLength(1));
    expect(c.read(quitStoreProvider)!.cravingsSurvivedTotal, before + 1);
  });
}

class _StubPanic implements PanicRepository {
  int begins = 0;
  final survivedIntensities = <int>[];
  final survivedAfter = <int?>[];
  final survivedGames = <GameId?>[];
  PanicAvailability result = PanicAvailability.unknown;
  Object? failure;

  @override
  Future<PanicAvailability> begin() async {
    begins++;
    if (failure != null) throw failure!;
    return result;
  }

  @override
  Future<void> survived({
    required int intensity,
    int? intensityAfter,
    GameId? game,
  }) async {
    survivedIntensities.add(intensity);
    survivedAfter.add(intensityAfter);
    survivedGames.add(game);
    if (failure != null) throw failure!;
  }
}
/// A coach whose next answer is the daily cap — the server's decision,
/// arriving as the template-only envelope it really sends.
class _CappedCoach implements CoachRepository {
  const _CappedCoach();

  @override
  Stream<CoachEvent> streamReply({
    String? text,
    CoachChip? chip,
    required bool capped,
    int? panicIntensity,
  }) async* {
    yield const CoachDone(CoachReply(template: CoachTemplate.capReached));
  }

  @override
  Future<List<CoachMessage>> history() async => const [];

  @override
  Future<List<CoachMemory>> memories() async => const [];

  @override
  Future<void> seedMemories() async {}

  @override
  Future<void> forgetMemory(String id) async {}
}

/// A clock a test can move forward.
class _MovableClock {
  _MovableClock(this.now);

  DateTime now;

  DateTime read() => now;
}
