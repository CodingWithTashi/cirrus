import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/data/api/firebase/functions_client.dart';
import 'package:last_puff/data/repositories/firebase_panic_repository.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/allowances.dart';
import 'package:last_puff/domain/logic/exercises/exercise.dart';
import 'package:last_puff/domain/logic/games/game_id.dart';
import 'package:last_puff/domain/models/coach_ui.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';
import 'package:last_puff/features/coach/coach_screen.dart';
import 'package:last_puff/features/panic/games/intensity_row.dart';
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

  testWidgets('starting a craving tells the server; building the provider '
      'does not', (tester) async {
    final c = await mount(tester);
    // The notifier is app-lifetime and the arena reads it too, so merely
    // existing must not count as a craving.
    c.read(panicProvider);
    await tester.pumpAndSettle();
    expect(panic.begins, 0);
    expect(c.read(panicProvider).startedAt, isNull);

    c.read(panicProvider.notifier).start();
    await tester.pumpAndSettle();
    expect(panic.begins, 1);
    // And the first step is already on screen — nothing awaited the call.
    expect(c.read(panicProvider).step, 0);
    expect(c.read(panicProvider).startedAt, isNotNull);
  });

  testWidgets('previewStep opens a craving when none is, and only then', (
    tester,
  ) async {
    final c = await mount(tester);
    c.read(panicProvider.notifier).previewStep(2);
    await tester.pumpAndSettle();
    expect(panic.begins, 1);
    expect(c.read(panicProvider).step, 2);

    // A second jump inside the same craving opens nothing new.
    c.read(panicProvider.notifier).previewStep(1);
    await tester.pumpAndSettle();
    expect(panic.begins, 1);
    expect(c.read(panicProvider).step, 1);
  });

  testWidgets('a re-rated craving reports both numbers and the game', (
    tester,
  ) async {
    final c = await mount(tester);
    c.read(quitStoreProvider.notifier).seedDemoJourney();

    final vm = c.read(panicProvider.notifier);
    // The why step is where the slider is; a strength exists from there on.
    vm.previewStep(1);
    vm.setIntensity(8);
    vm.noteGame(GameId.blocks, rounds: 2);
    vm.survive(intensityAfter: 3);
    await tester.pumpAndSettle();

    expect(panic.survivedIntensities, [8]);
    expect(panic.survivedAfter, [3]);
    expect(panic.survivedGames, [GameId.blocks]);

    // The next craving, ended on the breathing step with no game played and
    // the re-ask skipped: nothing is sent in any of their places, never a
    // guess — and nothing is inherited from the craving before it.
    c.read(panicProvider.notifier)
      ..start()
      ..survive();
    await tester.pumpAndSettle();
    expect(panic.survivedIntensities, [8, null]);
    expect(panic.survivedAfter, [3, null]);
    expect(panic.survivedGames, [GameId.blocks, null]);
  });

  testWidgets('a survived craving is reported with its intensity', (
    tester,
  ) async {
    final c = await mount(tester);
    c.read(quitStoreProvider.notifier).seedDemoJourney();
    final before = c.read(quitStoreProvider)!.cravingsSurvivedTotal;

    c.read(panicProvider.notifier)
      ..previewStep(1)
      ..setIntensity(9)
      ..survive();
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
    c.read(panicProvider.notifier).start();
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
    c.read(panicProvider.notifier).start();
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
    c.read(panicProvider.notifier).start();
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
    c.read(panicProvider.notifier).start();
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

    test('the arena is the only place in panic that may carry a door', () {
      // Tiles and Blocks are Premium since Sep 3 2026 (docs/12 §5c), so the
      // arena DOES carry a `panic_game` door — the one exception, and one
      // that is only ever reached by deliberately tapping a locked pill.
      //
      // Pinned in both directions on purpose. The flow's own steps must stay
      // door-free (above), and the arena's door must stay behind the lock
      // card rather than migrating onto the board, the round panel or the
      // paused veil, any of which would put an offer in front of somebody
      // mid-round.
      for (final file in [
        'lib/features/panic/games/round_panel.dart',
        'lib/features/panic/games/paused_veil.dart',
        'lib/features/panic/games/game_switcher.dart',
      ]) {
        expect(
          File(file).readAsStringSync(),
          isNot(contains('paywall')),
          reason: '$file must not sell anything',
        );
      }
      final arena = File('lib/features/panic/game_arena_screen.dart')
          .readAsStringSync();
      expect(
        arena,
        contains("paywallFrom('panic_game')"),
        reason: 'the lock card is the door, and it is tagged',
      );
      expect(
        'paywallFrom'.allMatches(arena).length,
        1,
        reason: 'exactly one door in the arena, on the lock card',
      );
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
  Future<ProviderContainer> mountFlow(
    WidgetTester tester, {
    DateTime Function()? now,
  }) async {
    final c = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(analytics: analytics),
        panicRepositoryProvider.overrideWithValue(panic),
        if (now != null) nowProvider.overrideWithValue(now),
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

    // `_resolved` is set by `survive()` and stays set until the next
    // `start()`, so the flow's dispose has nothing to report.
    expect(tester.takeException(), isNull);
    expect(panic.survivedIntensities, hasLength(1));
    expect(c.read(quitStoreProvider)!.cravingsSurvivedTotal, before + 1);
    final outcomes = analytics.propsOfAll('craving_outcome');
    expect(outcomes, hasLength(1));
    expect(outcomes.single['survived'], 'true');
  });

  /// The same container, the takeover shown again — what pushing `/panic`
  /// a second time does to the app-lifetime notifier.
  Future<void> reopenFlow(WidgetTester tester, ProviderContainer c) async {
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
  }

  testWidgets('a craving closed with back leaks nothing into the next one', (
    tester,
  ) async {
    // The 607:31 timer. The notifier is app-lifetime and used to reset only
    // on "it passed", so a takeover closed at 11:10 PM handed its clock, its
    // step and its intensity to the next morning's craving — which opened on
    // the loop screen, at intensity 9, with ten hours on the pill.
    final clock = _MovableClock(DateTime(2026, 9, 5, 23, 10));
    final c = await mountFlow(tester, now: clock.read);
    expect(panic.begins, 1, reason: 'opening the takeover opens a craving');
    final vm = c.read(panicProvider.notifier)
      ..previewStep(2)
      ..setIntensity(9);
    await tester.pump(const Duration(milliseconds: 400));
    clock.now = clock.now.add(const Duration(hours: 10, minutes: 7));
    expect(vm.elapsed, const Duration(hours: 10, minutes: 7));

    // The back gesture.
    await unmountFlow(tester, c);
    expect(analytics.propsOfAll('craving_outcome').single['survived'], 'false');

    // The next morning.
    await reopenFlow(tester, c);
    expect(panic.begins, 2, reason: 'a new craving is a new server session');
    final session = c.read(panicProvider);
    expect(session.step, 0, reason: 'the breathing ring, not the loop screen');
    expect(session.intensity, 7);
    expect(c.read(panicProvider.notifier).elapsed, Duration.zero);
    expect(tester.takeException(), isNull);
    await unmountFlow(tester, c);
  });

  testWidgets('"it passed" opens no phantom second session', (tester) async {
    // `survive()` used to `invalidateSelf()`, and Riverpod re-ran `build`
    // while the flow was still mounted under the survived screen — a second
    // `begin()` per survived craving, counted by the server as a session
    // nobody had.
    final c = await mountFlow(tester);
    c.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(milliseconds: 400));

    c.read(panicProvider.notifier).survive();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    expect(panic.begins, 1);

    // And the craving after it starts clean.
    await unmountFlow(tester, c);
    await reopenFlow(tester, c);
    expect(panic.begins, 2);
    expect(c.read(panicProvider).step, 0);
    await unmountFlow(tester, c);
  });

  testWidgets('ensureStarted opens one craving, never two', (tester) async {
    // The arena's entry: a no-op from the flow, the start from a deep link.
    final c = await mount(tester);
    c.read(panicProvider.notifier)
      ..ensureStarted()
      ..ensureStarted();
    await tester.pumpAndSettle();
    expect(panic.begins, 1);
  });

  // Everything below runs the real app on the real router: the takeover,
  // the chat and the arena handing one craving between them.
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  /// The real app on the real router, with the server hop counted.
  Future<ProviderContainer> bootApp(
    WidgetTester tester, {
    _MovableClock? clock,
  }) async {
    final c = ProviderContainer(
      overrides: fastBackendOverrides(
        analytics: analytics,
        extra: [
          panicRepositoryProvider.overrideWithValue(panic),
          if (clock != null) nowProvider.overrideWithValue(clock.read),
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
    return c;
  }

  /// Fixed pumps, never `pumpAndSettle`: the takeover and the arena both
  /// animate for as long as they are on screen.
  Future<void> beat(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The takeover on its third step with the slider at [strength].
  Future<void> flowAtLoop(
    WidgetTester tester,
    ProviderContainer c, {
    int strength = 8,
  }) async {
    unawaited(c.read(routerProvider).push(Routes.panic));
    await beat(tester);
    c.read(panicProvider.notifier)
      ..previewStep(2)
      ..setIntensity(strength);
    await beat(tester);
  }

  /// The third option on the loop screen: "talk to the coach".
  Future<void> takeCoachDoor(WidgetTester tester) async {
    await tester.ensureVisible(find.text(l10n.panicLoopCoach));
    await tester.pump();
    await tester.tap(find.text(l10n.panicLoopCoach));
    // Long enough for the takeover's route to finish leaving and dispose.
    await beat(tester);
    await beat(tester);
  }

  /// What a coach card does: the arena pushed over the chat.
  Future<void> openArenaFromChat(
    WidgetTester tester,
    ProviderContainer c,
  ) async {
    unawaited(
      c
          .read(routerProvider)
          .push(Routes.gameFor(GameId.orbs, source: ExerciseSource.coach)),
    );
    await beat(tester);
  }

  Future<void> popTop(WidgetTester tester, ProviderContainer c) async {
    c.read(routerProvider).pop();
    await beat(tester);
    await beat(tester);
  }

  /// A whole 60-second round in 100 ms frames (one long pump would be a
  /// single clamped step), then the panel's fade.
  Future<void> playRound(WidgetTester tester) async {
    for (var i = 0; i < 600; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 400));
  }

  List<Map<String, Object>> outcomes() =>
      analytics.propsOfAll('craving_outcome');

  /// A craving does not end because the person changed screens.
  ///
  /// The panic flow's coach option used to `go` to the chat, which disposed
  /// the flow, whose dispose reported the craving abandoned — at the exact
  /// moment the person asked for more help with it. And a card tapped in
  /// that chat opened a SECOND craving: a new clock, a new server session,
  /// the strength they had just given forgotten. Now the flow parks its
  /// craving on the way to the chat, an exercise opened inside the craving
  /// window joins it, and whoever joined parks it again on the way out. A
  /// parked craving is closed (not survived) only when the next one starts.
  group('a craving handed on', () {
    testWidgets('only an owner is told it owns the craving', (tester) async {
      final c = await mount(tester);
      final vm = c.read(panicProvider.notifier);

      // Nothing open: the caller opens one, and must park it on the way out.
      expect(vm.ensureStarted(), isTrue);
      expect(panic.begins, 1);
      vm.park();
      // Parked a moment ago: joined, not reopened.
      expect(vm.ensureStarted(), isTrue);
      expect(panic.begins, 1);

      // The takeover's own craving stays the takeover's.
      vm
        ..park()
        ..start();
      expect(panic.begins, 2);
      expect(vm.ensureStarted(), isFalse);
      expect(panic.begins, 2);
      await tester.pumpAndSettle();
    });

    testWidgets('parking nothing parks nothing', (tester) async {
      final c = await mount(tester);
      c.read(quitStoreProvider.notifier).seedDemoJourney();
      final vm = c.read(panicProvider.notifier);

      // Idle.
      vm
        ..park()
        ..start();
      expect(outcomes(), isEmpty);

      // Over already: "it passed" leaves nothing behind to close.
      vm
        ..survive()
        ..park()
        ..start();
      await tester.pumpAndSettle();
      expect(outcomes(), hasLength(1));
      expect(outcomes().single, containsPair('survived', 'true'));
    });

    testWidgets('a parked craving does not outlive the session it was parked '
        'in', (tester) async {
      // The shared-phone rule. A parked craving outlives its screen and the
      // next exercise inside the window joins it, so without this the next
      // person to sign in on the phone would inherit the last one's craving:
      // their clock on the timer, and their 8/10 reported as this person's.
      final c = await mount(tester);
      final store = c.read(quitStoreProvider.notifier)
        ..replaceForTest(journeyOnDay(10, now: DateTime(2026, 9, 5, 14)));
      c.read(panicProvider.notifier)
        ..previewStep(2)
        ..setIntensity(8)
        ..park();
      expect(panic.begins, 1);

      // They sign out, and somebody else signs in.
      store.signOut();
      await tester.pumpAndSettle();
      store.replaceForTest(journeyOnDay(1, now: DateTime(2026, 9, 5, 14)));
      await tester.pumpAndSettle();

      // Their first exercise is their own craving, with nothing in it yet.
      final vm = c.read(panicProvider.notifier);
      expect(vm.ensureStarted(), isTrue);
      expect(panic.begins, 2, reason: 'a new craving, not the last one joined');
      expect(vm.ratedIntensity, isNull);
      expect(c.read(panicProvider).step, 0);
      // And the craving that was dropped is not closed under their name.
      expect(outcomes(), isEmpty);
      await tester.pumpAndSettle();
    });

    testWidgets('the coach door parks the craving, it does not abandon it', (
      tester,
    ) async {
      final c = await bootApp(tester);
      await flowAtLoop(tester, c);
      final startedAt = c.read(panicProvider).startedAt;
      expect(startedAt, isNotNull);

      await takeCoachDoor(tester);

      expect(c.read(routerProvider).state.uri.path, Routes.coach);
      expect(find.byType(PanicFlow), findsNothing);
      expect(
        outcomes(),
        isEmpty,
        reason: 'asking Ember for help is not giving up on the craving',
      );
      expect(c.read(panicProvider).intensity, 8);
      expect(c.read(panicProvider).startedAt, startedAt);
    });

    testWidgets('a card inside the window joins the same craving', (
      tester,
    ) async {
      // Review Focus 1: arrives from the panic flow at 8/10 and taps the
      // game card. Same clock, same strength, one server session.
      final c = await bootApp(tester);
      await flowAtLoop(tester, c);
      final startedAt = c.read(panicProvider).startedAt;
      await takeCoachDoor(tester);

      await openArenaFromChat(tester, c);

      expect(panic.begins, 1, reason: 'one craving, one server session');
      expect(c.read(panicProvider).startedAt, startedAt);
      expect(c.read(panicProvider).intensity, 8);

      await playRound(tester);
      await tester.tap(find.text(l10n.panicItPassed));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SurvivedScreen), findsOneWidget);
      expect(outcomes(), hasLength(1));
      expect(outcomes().single, containsPair('survived', 'true'));
      expect(outcomes().single, containsPair('intensity', 8));
      expect(panic.survivedIntensities, [8]);
      expect(panic.begins, 1);
    });

    testWidgets('leaving the arena parks it again', (tester) async {
      final clock = _MovableClock(DateTime(2026, 9, 5, 14));
      final c = await bootApp(tester, clock: clock);
      await flowAtLoop(tester, c);
      final startedAt = c.read(panicProvider).startedAt;
      await takeCoachDoor(tester);
      clock.now = clock.now.add(const Duration(minutes: 15));
      await openArenaFromChat(tester, c);

      await popTop(tester, c);

      expect(c.read(routerProvider).state.uri.path, Routes.coach);
      expect(outcomes(), isEmpty, reason: 'back is not an outcome');

      // And the next card is still the same craving. Fifteen more minutes is
      // thirty since the door, but the window runs from when the craving's
      // screen was last in front of them, which was the arena just now.
      clock.now = clock.now.add(const Duration(minutes: 15));
      await openArenaFromChat(tester, c);
      expect(panic.begins, 1);
      expect(c.read(panicProvider).startedAt, startedAt);
      expect(c.read(panicProvider).intensity, 8);
      expect(outcomes(), isEmpty);

      // Parked for real, not merely left open: once nobody has come back
      // for a whole window, the next card is a new craving and this one is
      // closed.
      await popTop(tester, c);
      clock.now = clock.now.add(const Duration(minutes: 21));
      await openArenaFromChat(tester, c);
      expect(panic.begins, 2);
      expect(outcomes(), hasLength(1));
      expect(outcomes().single, containsPair('survived', 'false'));
    });

    testWidgets(
      'after the window, a card opens a new craving and the old one is closed',
      (tester) async {
        final clock = _MovableClock(DateTime(2026, 9, 5, 14));
        final c = await bootApp(tester, clock: clock);
        await flowAtLoop(tester, c);
        await takeCoachDoor(tester);
        expect(outcomes(), isEmpty);

        // Past the app's own model of a craving (docs/03 §7).
        clock.now = clock.now.add(const Duration(minutes: 21));
        await openArenaFromChat(tester, c);

        expect(panic.begins, 2, reason: 'a new craving is a new session');
        expect(c.read(panicProvider).startedAt, clock.now);
        // The one that was parked, closed with what was known about it.
        expect(outcomes(), hasLength(1));
        expect(outcomes().single, containsPair('survived', 'false'));
        expect(outcomes().single, containsPair('intensity', 8));
      },
    );

    testWidgets('a new SOS press is a new craving', (tester) async {
      final clock = _MovableClock(DateTime(2026, 9, 5, 14));
      final c = await bootApp(tester, clock: clock);
      await flowAtLoop(tester, c);
      await takeCoachDoor(tester);
      // Parked, so nothing has been said about it yet: it is closed BY the
      // next craving, not by the door.
      expect(outcomes(), isEmpty);

      // Two minutes later, well inside the window: the takeover never joins.
      clock.now = clock.now.add(const Duration(minutes: 2));
      unawaited(c.read(routerProvider).push(Routes.panic));
      await beat(tester);

      expect(panic.begins, 2);
      final session = c.read(panicProvider);
      expect(session.step, 0, reason: 'the breathing ring');
      expect(session.intensity, 7);
      expect(session.startedAt, clock.now);
      expect(c.read(panicProvider.notifier).elapsed, Duration.zero);
      expect(outcomes(), hasLength(1));
      expect(outcomes().single, containsPair('survived', 'false'));
      expect(outcomes().single, containsPair('intensity', 8));
    });

    testWidgets(
      'an arena opened with no flow beneath closes behind itself',
      (tester) async {
        // A `?g=` link, a restored route, a coach card with no craving
        // before it: the arena is the craving's first screen and nothing
        // else will ever end it. It used to leave the session open for
        // ever, and the next craving overwrote it without a word.
        final c = await bootApp(tester);
        await openArenaFromChat(tester, c);
        expect(panic.begins, 1);

        await popTop(tester, c);

        // Parked, not abandoned: nothing is reported, and the flow's own
        // exit has nothing to say about a craving it does not own.
        expect(outcomes(), isEmpty);
        c.read(panicProvider.notifier).abandon();
        expect(outcomes(), isEmpty);

        // The next craving closes it, once.
        unawaited(c.read(routerProvider).push(Routes.panic));
        await beat(tester);
        expect(panic.begins, 2);
        expect(outcomes(), hasLength(1));
        expect(outcomes().single, containsPair('survived', 'false'));
        expect(outcomes().single, containsPair('game', 'orbs'));
      },
    );
  });

  /// Amendment A2. Back in the chat after an exercise, the person can say
  /// "It passed" with a chip instead of a button on the exercise's screen.
  /// That is the same statement. If the chip only filled the composer, the
  /// craving would stay parked and the next craving would close it as NOT
  /// survived — the opposite of what they said. `surviveParked` counts a
  /// parked craving through the path every craving takes, and does nothing
  /// at all when there is no parked craving to count.
  group('"it passed", said in the chat', () {
    int total(ProviderContainer c) =>
        c.read(quitStoreProvider)!.cravingsSurvivedTotal;

    /// What the chat's chip calls: the exercise they just did, from the chat.
    bool sayItPassed(
      ProviderContainer c, {
      ExerciseId exercise = ExerciseId.breathing,
    }) => c
        .read(panicProvider.notifier)
        .surviveParked(exercise: exercise, source: ExerciseSource.coach);

    testWidgets('a parked craving the person says has passed is counted once', (
      tester,
    ) async {
      final c = await bootApp(tester);
      await flowAtLoop(tester, c);
      await takeCoachDoor(tester);
      final before = total(c);
      expect(outcomes(), isEmpty);

      expect(sayItPassed(c), isTrue);
      await beat(tester);

      // Counted exactly as `survive` counts one: the strength they gave on
      // the slider rides along, and there is no after-rating to send.
      expect(outcomes(), [
        {
          'survived': 'true',
          'game': 'none',
          'rounds': 0,
          'intensity': 8,
          'exercise': 'breathing',
          'source': 'coach',
        },
      ]);
      expect(panic.survivedExercises, [ExerciseId.breathing]);
      expect(panic.survivedSources, [ExerciseSource.coach]);
      expect(panic.survivedIntensities, [8]);
      expect(panic.survivedAfter, [null]);
      expect(total(c), before + 1);

      // Said twice (the chip is still there): counted once.
      expect(sayItPassed(c), isFalse);
      await beat(tester);
      expect(outcomes(), hasLength(1));
      expect(panic.survivedExercises, hasLength(1));
      expect(total(c), before + 1);
    });

    testWidgets('saying it passed with nothing parked counts nothing', (
      tester,
    ) async {
      final c = await bootApp(tester);
      final before = total(c);

      // Nothing open at all.
      expect(sayItPassed(c), isFalse);

      // Open, and in the takeover's hands: it has its own "It passed".
      await flowAtLoop(tester, c);
      expect(sayItPassed(c), isFalse);
      await beat(tester);

      expect(outcomes(), isEmpty);
      expect(panic.survivedExercises, isEmpty, reason: 'no repository call');
      expect(total(c), before);
      expect(find.byType(PanicFlow), findsOneWidget);
      expect(panic.begins, 1);

      // The refusal was about who holds the craving, not about the craving:
      // once the takeover hands this same one to the chat, the same words
      // count it.
      await takeCoachDoor(tester);
      expect(sayItPassed(c), isTrue);
      await beat(tester);
      expect(outcomes(), hasLength(1));
      expect(outcomes().single, containsPair('survived', 'true'));
      expect(total(c), before + 1);
    });

    testWidgets("a craving an exercise still has open is the exercise's to "
        'end', (tester) async {
      final c = await bootApp(tester);
      final before = total(c);
      // A card's arena, opened cold: it owns the craving while it is up.
      await openArenaFromChat(tester, c);

      expect(sayItPassed(c, exercise: ExerciseId.orbs), isFalse);
      await beat(tester);
      expect(outcomes(), isEmpty);
      expect(panic.survivedExercises, isEmpty);
      expect(total(c), before);

      // Left with back, it is parked, and then it is the chat's to count.
      await popTop(tester, c);
      expect(sayItPassed(c, exercise: ExerciseId.orbs), isTrue);
      await beat(tester);
      expect(outcomes(), hasLength(1));
      expect(total(c), before + 1);
    });

    testWidgets('a craving counted from the chat is not reported again when '
        'the next one starts', (tester) async {
      final c = await bootApp(tester);
      await flowAtLoop(tester, c);
      await takeCoachDoor(tester);
      sayItPassed(c);
      await beat(tester);

      // The next SOS press.
      unawaited(c.read(routerProvider).push(Routes.panic));
      await beat(tester);

      expect(panic.begins, 2, reason: 'the new craving began');
      expect(
        outcomes().where((outcome) => outcome['survived'] == 'false'),
        isEmpty,
        reason: 'they said it passed; it must not also be closed as lost',
      );
      expect(outcomes(), hasLength(1));
      expect(outcomes().single, containsPair('survived', 'true'));
    });

    testWidgets('nor joined, nor closed, by the next exercise they open', (
      tester,
    ) async {
      final clock = _MovableClock(DateTime(2026, 9, 5, 14));
      final c = await bootApp(tester, clock: clock);
      await flowAtLoop(tester, c);
      final first = c.read(panicProvider).startedAt;
      await takeCoachDoor(tester);
      sayItPassed(c);
      await beat(tester);

      // Five minutes on, well inside the window a parked craving is joined
      // in. But that craving is over, so this card opens a new one.
      clock.now = clock.now.add(const Duration(minutes: 5));
      await openArenaFromChat(tester, c);

      expect(panic.begins, 2, reason: 'a new craving, not the old one joined');
      expect(c.read(panicProvider).startedAt, clock.now);
      expect(c.read(panicProvider).startedAt, isNot(first));
      expect(c.read(panicProvider.notifier).ratedIntensity, isNull);
      expect(
        outcomes().where((outcome) => outcome['survived'] == 'false'),
        isEmpty,
      );
      expect(outcomes(), hasLength(1));
    });

    testWidgets('a parked craving that never saw the slider is counted with '
        'no strength', (tester) async {
      // The X3 rule through this door too: a craving that began on a card
      // never showed the why step, so there is no strength to send.
      final c = await bootApp(tester);
      await openArenaFromChat(tester, c);
      await popTop(tester, c);

      sayItPassed(c, exercise: ExerciseId.orbs);
      await beat(tester);

      expect(outcomes(), hasLength(1));
      expect(outcomes().single, {
        'survived': 'true',
        'game': 'orbs',
        'rounds': 0,
        'exercise': 'orbs',
        'source': 'coach',
      });
      expect(panic.survivedIntensities, [null]);
      expect(panic.survivedAfter, [null]);
      expect(panic.survivedGames, [GameId.orbs]);
    });
  });

  /// The strength slider lives on the takeover's why step, and its value
  /// starts at 7. A craving that never showed that step (one opened by a
  /// coach card, a `?g=` link, or closed on the breathing ring) used to
  /// report that untouched 7 as if the person had given it: to analytics, to
  /// the craving document, and from there to anything that later says "you
  /// rated it 7". A number the person never entered is an invented number.
  group('a strength nobody gave is never reported', () {
    testWidgets('a craving that never saw the slider reports no strength', (
      tester,
    ) async {
      final c = await bootApp(tester);
      // Cold: no takeover before it, so no why step and no slider.
      await openArenaFromChat(tester, c);
      await playRound(tester);
      // The panel's own question is theirs to answer, and they do.
      await tester.tap(
        find.descendant(
          of: find.byType(IntensityRow),
          matching: find.text('3'),
        ),
      );
      await tester.pump();
      await tester.tap(find.text(l10n.panicItPassed));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SurvivedScreen), findsOneWidget);
      expect(panic.survivedIntensities, [null]);
      expect(panic.survivedAfter, [3]);
      expect(outcomes(), hasLength(1));
      expect(outcomes().single.containsKey('intensity'), isFalse);
      expect(outcomes().single, containsPair('intensity_after', 3));
      // No "You said 7/10 — now 3/10": they never said 7.
      expect(find.textContaining('/10'), findsNothing);
    });

    testWidgets('a craving from the flow reports the strength on the slider', (
      tester,
    ) async {
      // The other half: the slider was on screen at its default and they
      // left it there. That is still a strength they were shown and let
      // stand, and it is reported as before.
      final c = await bootApp(tester);
      unawaited(c.read(routerProvider).push(Routes.panic));
      await beat(tester);
      await tester.tap(find.text(l10n.panicSkipToWhy));
      await beat(tester);
      expect(find.text('7/10'), findsOneWidget);

      await tester.tap(find.text(l10n.panicItPassed));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SurvivedScreen), findsOneWidget);
      expect(panic.survivedIntensities, [7]);
      expect(outcomes().single, containsPair('intensity', 7));
    });

    testWidgets('a takeover closed on the breathing ring reports no strength', (
      tester,
    ) async {
      final c = await mountFlow(tester);
      await unmountFlow(tester, c);

      expect(outcomes(), hasLength(1));
      expect(outcomes().single, containsPair('survived', 'false'));
      expect(outcomes().single.containsKey('intensity'), isFalse);
    });

    test('the payload omits a strength nobody gave', () async {
      final functions = _RecordingFunctions();
      final repository = FirebasePanicRepository(functions: functions);

      await repository.survived(intensityAfter: 3, game: GameId.orbs);
      await repository.survived(intensity: 7);

      expect([for (final call in functions.calls) call.$1], [
        'panicSession',
        'panicSession',
      ]);
      // A record compares its fields with `==`, which for a map is identity,
      // so the payloads are compared on their own.
      expect([for (final call in functions.calls) call.$2], [
        {'outcome': 'survived', 'intensityAfter': 3, 'game': 'orbs'},
        {'outcome': 'survived', 'intensity': 7},
      ]);
    });
  });

  /// `users/{uid}/cravings` is what Ember's craving lines are written from:
  /// which tools the person has used, and where. Until now the report said
  /// only which arena game was open, so breathing and the chat were
  /// invisible to it.
  group('the craving report says what was used and where it began', () {
    testWidgets('the report names the exercise and where it began', (
      tester,
    ) async {
      final c = await bootApp(tester);
      c.read(routerProvider).go(Routes.coach);
      await tester.pumpAndSettle();
      await openArenaFromChat(tester, c);
      await playRound(tester);

      await tester.tap(find.text(l10n.panicItPassed));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SurvivedScreen), findsOneWidget);
      expect(panic.survivedExercises, [ExerciseId.orbs]);
      expect(panic.survivedSources, [ExerciseSource.coach]);
      expect(panic.survivedGames, [GameId.orbs]);
      expect(outcomes().single, containsPair('exercise', 'orbs'));
      expect(outcomes().single, containsPair('source', 'coach'));
    });

    // Both of the flow's buttons: the why step's and the loop step's.
    for (final (step, name) in [(1, 'why'), (2, 'loop')]) {
      testWidgets("the takeover's own \"it passed\" on the $name step names "
          'the flow and no exercise', (tester) async {
        final c = await bootApp(tester);
        unawaited(c.read(routerProvider).push(Routes.panic));
        await beat(tester);
        c.read(panicProvider.notifier).previewStep(step);
        await beat(tester);

        await tester.tap(find.text(l10n.panicItPassed));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(SurvivedScreen), findsOneWidget);
        expect(panic.survivedExercises, [null]);
        expect(panic.survivedSources, [ExerciseSource.panic]);
        expect(outcomes().single, containsPair('source', 'panic'));
        expect(outcomes().single.containsKey('exercise'), isFalse);
      });
    }

    test('the payload carries both, and neither when there is none', () async {
      final functions = _RecordingFunctions();
      final repository = FirebasePanicRepository(functions: functions);

      await repository.survived(
        game: GameId.orbs,
        exercise: ExerciseId.orbs,
        source: ExerciseSource.coach,
      );
      await repository.survived(
        intensity: 6,
        exercise: ExerciseId.breathing,
        source: ExerciseSource.panic,
      );
      // An older call site that knows nothing about either.
      await repository.survived(intensity: 6);

      expect([for (final call in functions.calls) call.$2], [
        {
          'outcome': 'survived',
          'game': 'orbs',
          'exercise': 'orbs',
          'source': 'coach',
        },
        {
          'outcome': 'survived',
          'intensity': 6,
          'exercise': 'breathing',
          'source': 'panic',
        },
        {'outcome': 'survived', 'intensity': 6},
      ]);
    });
  });
}

/// The app's own door to Cloud Functions, recording what it is handed. Not a
/// Firebase mock: nothing below this seam is constructed.
class _RecordingFunctions implements LpFunctions {
  final calls = <(String, Map<String, Object?>)>[];

  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, Object?> data = const {},
    Duration? timeout,
  ]) async {
    calls.add((name, data));
    return const {};
  }

  @override
  Stream<({String? chunk, Map<String, dynamic>? result})> stream(
    String name, [
    Map<String, Object?> data = const {},
  ]) => const Stream.empty();
}

class _StubPanic implements PanicRepository {
  int begins = 0;
  final survivedIntensities = <int?>[];
  final survivedAfter = <int?>[];
  final survivedGames = <GameId?>[];
  final survivedExercises = <ExerciseId?>[];
  final survivedSources = <ExerciseSource?>[];
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
    int? intensity,
    int? intensityAfter,
    GameId? game,
    ExerciseId? exercise,
    ExerciseSource? source,
  }) async {
    survivedIntensities.add(intensity);
    survivedAfter.add(intensityAfter);
    survivedGames.add(game);
    survivedExercises.add(exercise);
    survivedSources.add(source);
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
    CoachTurnExtras? extras,
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
