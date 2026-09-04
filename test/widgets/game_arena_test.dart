import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/widgets/lp_misc.dart';
import 'package:last_puff/core/widgets/lp_selectables.dart';
import 'package:last_puff/data/api/fake/fake_server.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/games/games.dart';
import 'package:last_puff/features/panic/games/blocks_field.dart';
import 'package:last_puff/features/panic/games/game_result_line.dart';
import 'package:last_puff/features/panic/games/intensity_row.dart';
import 'package:last_puff/features/panic/games/orbs_field.dart';
import 'package:last_puff/features/panic/games/tile_field.dart';
import 'package:last_puff/features/panic/panic_screens.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// The panic arena on the real router (docs/10 §15): one tap is one hit, a
/// miss costs only the combo, sixty seconds end on a choice, the best is
/// never shown before it exists, rounds chain to five, and the pills swap
/// games without recording the round they cut short.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<(ProviderContainer, RecordingAnalytics)> boot(
    WidgetTester tester,
  ) async {
    final analytics = RecordingAnalytics();
    final container = ProviderContainer(
      overrides: fastBackendOverrides(analytics: analytics),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    return (container, analytics);
  }

  /// The same, for an account with no subscription.
  ///
  /// `fastBackendOverrides()` seeds the PAYING demo persona by default, which
  /// is right for the mechanics above and wrong for every gate below.
  Future<(ProviderContainer, RecordingAnalytics)> bootFree(
    WidgetTester tester,
  ) async {
    final analytics = RecordingAnalytics();
    final container = ProviderContainer(
      overrides: fastBackendOverrides(analytics: analytics, premium: false),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    return (container, analytics);
  }

  /// Straight to the arena, on Tiles unless told otherwise.
  ///
  /// Explicit since Orbs became the arena's default (docs/12 §5c): most of
  /// what follows is about the Tiles board specifically, and `Routes.game`
  /// with no `?g=` now lands on Orbs. Never `pumpAndSettle` past this point:
  /// the field animates until the round ends.
  Future<void> openGame(
    WidgetTester tester,
    ProviderContainer c, {
    String? path,
  }) async {
    c.read(routerProvider).go(path ?? Routes.gameFor(GameId.tiles));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// The way a person gets there: the takeover's third step, then the card.
  Future<void> openFromFlow(WidgetTester tester, ProviderContainer c) async {
    c.read(routerProvider).go(Routes.home);
    await tester.pump();
    await tester.pumpAndSettle();
    unawaited(c.read(routerProvider).push(Routes.panic));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    c.read(panicProvider.notifier).previewStep(2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(l10n.panicLoopGame));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // The card lands on the arena's default, which is Orbs. Both callers are
    // about the Tiles board, so take the pill the way a person would.
    await tester.tap(find.text(l10n.gameNameTiles));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  TileGame tiles(WidgetTester tester) =>
      tester.widget<TileField>(find.byType(TileField)).game;
  BlocksGame blocks(WidgetTester tester) =>
      tester.widget<BlocksField>(find.byType(BlocksField)).game;

  /// Pumps game time in 100 ms frames. One pump of sixty seconds would be a
  /// single clamped step (`GameSession.maxStep`) — the clamp is the point.
  Future<void> play(WidgetTester tester, double seconds) async {
    for (var i = 0; i < (seconds * 10).round(); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// A whole round, and the panel's fade.
  Future<void> playRound(WidgetTester tester) async {
    await play(tester, 60);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> tapLane(WidgetTester tester, int lane) async {
    final rect = tester.getRect(find.byType(TileField));
    final x = rect.left + rect.width / TileGame.lanes * (lane + 0.5);
    await tester.tapAt(Offset(x, rect.top + rect.height * 0.75));
    await tester.pump();
  }

  /// Taps the target [times] times, a beat apart — steady play.
  Future<void> hits(WidgetTester tester, TileGame game, int times) async {
    for (var i = 0; i < times; i++) {
      await tapLane(tester, game.targetLane);
      await play(tester, 0.4);
    }
  }

  int wrongLane(TileGame game) => (game.targetLane + 1) % TileGame.lanes;

  int best(ProviderContainer c, [GameId id = GameId.tiles]) =>
      c.read(quitStoreProvider)!.gameBests[id]!;
  int? bestOrNull(ProviderContainer c, [GameId id = GameId.tiles]) =>
      c.read(quitStoreProvider)!.gameBests[id];
  int survived(ProviderContainer c) =>
      c.read(quitStoreProvider)!.cravingsSurvivedTotal;

  group('tiles', () {
    testWidgets('one tap on the target lane is one hit', (tester) async {
      final (c, _) = await boot(tester);
      await openGame(tester, c);
      final game = tiles(tester);

      await tapLane(tester, game.targetLane);

      expect(game.score, 1);
      expect(game.combo, 1);
      expect(
        find.text('1'),
        findsWidgets,
        reason: 'the header shows the count',
      );
    });

    testWidgets(
      'a burst of taps in one lane is never more hits than rows there',
      (tester) async {
        // The tap ramp that turned 18 taps into 68 puffs lives nowhere near
        // this screen, and this is what keeps it out: six pointer-downs in
        // one lane resolve exactly the rows at the head of the board in that
        // lane (one or two — never three, by the deal), and the bounces
        // after them are neither hits nor misses.
        final (c, _) = await boot(tester);
        await openGame(tester, c);
        final game = tiles(tester);
        final lane = game.targetLane;
        var run = 0;
        for (final l in game.rows) {
          if (l != lane) break;
          run++;
        }

        for (var i = 0; i < 6; i++) {
          await tapLane(tester, lane);
          await tester.pump(const Duration(milliseconds: 15));
        }

        expect(game.score, run);
        expect(game.score, lessThan(3));
        expect(game.misses, 0);
      },
    );

    testWidgets('a wrong lane costs the combo and nothing else', (
      tester,
    ) async {
      final (c, _) = await boot(tester);
      await openGame(tester, c);
      final game = tiles(tester);
      await tapLane(tester, game.targetLane);
      expect(game.combo, 1);
      final rows = game.rows;
      await play(tester, 0.3); // past the bounce grace

      await tapLane(tester, wrongLane(game));

      expect(game.combo, 0);
      expect(game.score, 1);
      expect(game.misses, 1);
      expect(game.rows, rows, reason: 'the target is still waiting');
      expect(find.byType(TileField), findsOneWidget, reason: 'no game-over');
    });

    testWidgets('sixty seconds end on a choice, and the round is recorded', (
      tester,
    ) async {
      final (c, analytics) = await boot(tester);
      expect(bestOrNull(c), isNull, reason: 'the demo journey never played');
      final before = survived(c);
      await openGame(tester, c);
      final game = tiles(tester);
      await hits(tester, game, 2);
      final score = game.score;
      expect(score, 2);

      await playRound(tester);

      expect(game.frozen, isTrue, reason: 'the board holds until the choice');
      expect(find.text(l10n.gameMinutesDone(1)), findsOneWidget);
      expect(find.text(l10n.gameAnotherRound), findsOneWidget);
      expect(find.text(l10n.panicItPassed), findsOneWidget);
      expect(find.byType(IntensityRow), findsOneWidget);
      // The first real score is a best, and it is on the journey already.
      expect(best(c), score);
      expect(find.textContaining(l10n.survivedGameNewBest), findsOneWidget);
      // No claim was made on their behalf.
      expect(survived(c), before);
      expect(analytics.names, contains('game_finished'));
      final props = analytics.propsOf('game_finished')!;
      expect(props, containsPair('game', 'tiles'));
      expect(props, containsPair('round', 1));
      expect(props, containsPair('score', score));
      expect(props, containsPair('best_combo', 2));
      // Fifty-odd seconds of tiles nobody tapped got away: misses are real.
      expect(props['misses'], greaterThan(0));
    });

    testWidgets('"it passed" lands on the survived screen carrying the run', (
      tester,
    ) async {
      final (c, analytics) = await boot(tester);
      final before = survived(c);
      await openGame(tester, c);
      final game = tiles(tester);
      await hits(tester, game, 1);
      await playRound(tester);

      await tester.tap(find.text(l10n.panicItPassed));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SurvivedScreen), findsOneWidget);
      expect(find.textContaining(l10n.survivedGameNewBest), findsOneWidget);
      expect(find.textContaining(l10n.gameUnitTiles(1)), findsOneWidget);
      expect(survived(c), before + 1);
      expect(analytics.propsOf('craving_outcome'), {
        'survived': 'true',
        'game': 'tiles',
        'rounds': 1,
        'intensity': 7,
      });
    });

    testWidgets('a re-rating on the panel travels to survived and analytics', (
      tester,
    ) async {
      final (c, analytics) = await boot(tester);
      await openGame(tester, c);
      await hits(tester, tiles(tester), 1);
      await playRound(tester);

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
      expect(find.text(l10n.survivedIntensityDrop(7, 3)), findsOneWidget);
      expect(analytics.propsOf('craving_outcome'), {
        'survived': 'true',
        'game': 'tiles',
        'rounds': 1,
        'intensity': 7,
        'intensity_after': 3,
      });
    });

    testWidgets('a number that did not drop is not shown against them', (
      tester,
    ) async {
      final (c, _) = await boot(tester);
      await openGame(
        tester,
        c,
        path: '${Routes.survived}?g=tiles&score=4&ib=5&ia=8',
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(GameResultLine), findsOneWidget);
      expect(find.textContaining('/10'), findsNothing);
    });

    testWidgets('"still craving" starts a fresh board and claims nothing', (
      tester,
    ) async {
      final (c, _) = await boot(tester);
      final before = survived(c);
      await openGame(tester, c);
      final first = tiles(tester);
      await hits(tester, first, 2);
      await playRound(tester);
      expect(best(c), 2);

      await tester.tap(find.text(l10n.gameAnotherRound));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final second = tiles(tester);
      expect(identical(second, first), isFalse);
      expect(second.score, 0);
      expect(find.text(l10n.gameTimeLeft(60)), findsOneWidget);
      expect(survived(c), before);

      // A lower second round leaves the best where it was and says so.
      await hits(tester, second, 1);
      await playRound(tester);
      expect(best(c), 2);
      expect(find.text(l10n.gameMinutesDone(2)), findsOneWidget);
      expect(find.textContaining(l10n.survivedGameNewBest), findsNothing);
      expect(find.textContaining(l10n.survivedGameBest(2)), findsOneWidget);
    });

    testWidgets('the header never names a best before one exists', (
      tester,
    ) async {
      final (c, _) = await boot(tester);
      await openGame(tester, c);
      final game = tiles(tester);
      expect(find.text(l10n.gameNewBest), findsNothing);

      // The first round ever: a hit is a score, not a "new best".
      await tapLane(tester, game.targetLane);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.gameNewBest), findsNothing);
    });

    testWidgets('passing an existing best mid-round says so, once', (
      tester,
    ) async {
      final (c, _) = await boot(tester);
      c.read(quitStoreProvider.notifier).recordGameScore(GameId.tiles, 1);
      await openGame(tester, c);
      final game = tiles(tester);

      await tapLane(tester, game.targetLane);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.gameNewBest), findsNothing, reason: 'a tie');

      await tapLane(tester, game.targetLane);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.gameNewBest), findsOneWidget);
    });
  });

  group('the arena', () {
    testWidgets('opens on the last game played, Orbs the first time', (
      tester,
    ) async {
      // Orbs, because it is the free one: a free account must never LAND on
      // a lock mid-craving, so `entries.first` is the game everybody can
      // play (docs/12 §5c). This account is a subscriber, so the stored
      // `lastGame` still wins on the second visit.
      final (c, _) = await boot(tester);
      await openGame(tester, c, path: Routes.game);
      expect(find.byType(OrbsField), findsOneWidget);
      expect(c.read(quitStoreProvider)!.lastGame, GameId.orbs);

      c.read(quitStoreProvider.notifier).setLastGame(GameId.blocks);
      await openGame(tester, c, path: Routes.survived);
      await openGame(tester, c, path: Routes.game);
      expect(find.byType(BlocksField), findsOneWidget);
    });

    testWidgets('?g= opens that game', (tester) async {
      final (c, _) = await boot(tester);
      await openGame(tester, c, path: Routes.gameFor(GameId.blocks));
      expect(find.byType(BlocksField), findsOneWidget);
      expect(find.text(l10n.gameHintBlocks), findsOneWidget);
      expect(c.read(quitStoreProvider)!.lastGame, GameId.blocks);
    });

    testWidgets('the pills swap games in place and record no round', (
      tester,
    ) async {
      final (c, analytics) = await boot(tester);
      await openGame(tester, c);
      final game = tiles(tester);
      await hits(tester, game, 2);

      await tester.tap(find.text(l10n.gameNameBlocks));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(BlocksField), findsOneWidget);
      expect(find.byType(TileField), findsNothing);
      expect(find.text(l10n.gameTimeLeft(60)), findsOneWidget);
      expect(analytics.propsOf('game_switched'), {
        'from': 'tiles',
        'to': 'blocks',
      });
      expect(analytics.names, isNot(contains('game_finished')));
      expect(bestOrNull(c), isNull, reason: 'the cut round set no best');
      expect(c.read(quitStoreProvider)!.lastGame, GameId.blocks);
    });

    testWidgets('a game with no best wears the dot; a best takes it off', (
      tester,
    ) async {
      final (c, _) = await boot(tester);
      await openGame(tester, c);
      Set<int> badges() =>
          tester.widget<SegmentedPills>(find.byType(SegmentedPills)).badges;
      expect(badges(), {0, 1, 2});

      await hits(tester, tiles(tester), 1);
      await playRound(tester);
      await tester.tap(find.text(l10n.gameAnotherRound));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Tiles is index 1 in the switcher (orbs, tiles, blocks).
      expect(badges(), {0, 2});
    });

    testWidgets('"60 more" resumes the same Blocks board', (tester) async {
      final (c, _) = await boot(tester);
      await openGame(tester, c, path: Routes.gameFor(GameId.blocks));
      final game = blocks(tester);
      await playRound(tester);
      expect(game.frozen, isTrue);
      expect(find.text(l10n.gameMinutesDone(1)), findsOneWidget);
      final board = game.board;
      final piece = game.active;

      await tester.tap(find.text(l10n.gameAnotherRound));
      await tester.pump();

      // Read at the moment of resuming: a piece that was resting when the
      // round ended locks a few frames later, as it should.
      expect(identical(blocks(tester), game), isTrue);
      expect(game.frozen, isFalse);
      expect(game.board, board);
      expect(game.active.kind, piece.kind);
      expect(game.active.y, piece.y);
      expect(find.text(l10n.gameTimeLeft(60)), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(BlocksField), findsOneWidget);
      expect(identical(blocks(tester), game), isTrue);
    });

    testWidgets('the third round is the dose; the fifth is the last', (
      tester,
    ) async {
      final (c, _) = await boot(tester);
      await openFromFlow(tester, c);
      expect(find.byType(TileField), findsOneWidget);
      for (var round = 1; round <= 4; round++) {
        await playRound(tester);
        expect(
          find.text(
            round == GameSession.targetRounds
                ? l10n.gameDoseDone
                : l10n.gameMinutesDone(round),
          ),
          findsOneWidget,
          reason: 'round $round',
        );
        await tester.tap(find.text(l10n.gameAnotherRound));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
      await playRound(tester);

      expect(find.text(l10n.gameMinutesDone(5)), findsOneWidget);
      expect(find.text(l10n.gameAnotherRound), findsNothing);
      expect(find.text(l10n.gameCapLine), findsOneWidget);
      expect(find.text(l10n.panicItPassed), findsOneWidget);

      await tester.tap(find.text(l10n.gameCapTryElse));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PanicFlow), findsOneWidget);
      expect(find.text(l10n.panicLoopTitle), findsOneWidget);
    });

    testWidgets('leaving by the chevron reports the game abandoned', (
      tester,
    ) async {
      final (c, analytics) = await boot(tester);
      await openFromFlow(tester, c);
      await tester.tap(find.byType(BackChevron));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PanicFlow), findsOneWidget);

      c.read(routerProvider).go(Routes.home);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(analytics.propsOf('craving_outcome'), {
        'survived': 'false',
        'game': 'tiles',
        'rounds': 0,
        'intensity': 7,
      });
    });

    testWidgets('backgrounding freezes the clock; a tap picks it up', (
      tester,
    ) async {
      final (c, _) = await boot(tester);
      await openGame(tester, c);
      await play(tester, 1);
      expect(find.text(l10n.gameTimeLeft(59)), findsOneWidget);

      // The OS walks the states in order; the listener asserts on a skip.
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      expect(find.text(l10n.gamePaused), findsOneWidget);
      await play(tester, 3);
      expect(find.text(l10n.gameTimeLeft(59)), findsOneWidget);
      final game = tiles(tester);
      expect(game.tap(game.targetLane), TapOutcome.hit, reason: 'not frozen');

      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.tap(find.text(l10n.gamePausedTap));
      await tester.pump();
      expect(find.text(l10n.gamePaused), findsNothing);
      await play(tester, 1);
      expect(find.text(l10n.gameTimeLeft(58)), findsOneWidget);
    });

    testWidgets('the survived screen without a game shows no game line', (
      tester,
    ) async {
      final (c, _) = await boot(tester);
      await openGame(tester, c, path: Routes.survived);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SurvivedScreen), findsOneWidget);
      expect(find.byType(GameResultLine), findsNothing);

      await openGame(tester, c, path: '${Routes.survived}?g=hexes&score=3');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(GameResultLine), findsNothing);
    });
  });

  /// Orbs is free forever; Tiles and Blocks need a subscription (founder
  /// decision Sep 3 2026, docs/12 §5c).
  ///
  /// The whole design turns on one thing: a free account must never LAND on a
  /// lock. It opens on Orbs, plays Orbs, and meets the card only by tapping a
  /// pill marked with a padlock — which is a question they asked, not an
  /// offer put in their way at 9/10 craving intensity.
  group('the two Premium games', () {
    testWidgets('a free account opens playable, whatever it played last', (
      tester,
    ) async {
      final (c, _) = await bootFree(tester);
      await openGame(tester, c, path: Routes.game);
      expect(find.byType(OrbsField), findsOneWidget);

      // The case that would otherwise put a lock in front of somebody
      // mid-craving: a lapsed subscriber whose stored `lastGame` is Blocks.
      c.read(quitStoreProvider.notifier).setLastGame(GameId.blocks);
      await openGame(tester, c, path: Routes.survived);
      await openGame(tester, c, path: Routes.game);
      expect(find.byType(OrbsField), findsOneWidget);
      expect(find.byType(BlocksField), findsNothing);

      // …and the same for a deep link that names one.
      await openGame(tester, c, path: Routes.survived);
      await openGame(tester, c, path: Routes.gameFor(GameId.tiles));
      expect(find.byType(OrbsField), findsOneWidget);
      expect(find.byType(TileField), findsNothing);
    });

    testWidgets('the locked pills wear a padlock; the free one does not', (
      tester,
    ) async {
      final (c, _) = await bootFree(tester);
      await openGame(tester, c, path: Routes.game);
      final pills = tester.widget<SegmentedPills>(
        find.byType(SegmentedPills),
      );
      // Switcher order is orbs, tiles, blocks.
      expect(pills.locked, {1, 2});
      // Both sets claim the same corner here — a game you cannot play
      // trivially has no best yet — and `SegmentedPills` resolves that in
      // favour of the padlock, which is the mark that means something.
      expect(pills.badges.intersection(pills.locked), pills.locked);
    });

    testWidgets('tapping a locked pill explains instead of starting a round', (
      tester,
    ) async {
      final (c, analytics) = await bootFree(tester);
      await openGame(tester, c, path: Routes.game);

      await tester.tap(find.text(l10n.gameNameTiles));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(l10n.gameLockedTitle(l10n.gameNameTiles)), findsOneWidget);
      expect(find.byType(TileField), findsNothing);
      expect(find.byType(OrbsField), findsNothing);
      expect(analytics.propsOf('gate_shown')?['source'], 'panic_game');
      // Nothing was played, so nothing is claimed: no round, no best, and
      // `lastGame` still names the game they can actually open.
      expect(analytics.names, isNot(contains('game_finished')));
      expect(analytics.names, isNot(contains('game_switched')));
      expect(c.read(quitStoreProvider)!.lastGame, GameId.orbs);
    });

    testWidgets('the clock stays stopped behind the lock card', (
      tester,
    ) async {
      // The card stops the ticker. Backgrounding and returning must not arm a
      // resume that starts it again with the card still up — the round would
      // tick down invisibly behind an offer nobody has answered yet.
      final (c, _) = await bootFree(tester);
      await openGame(tester, c, path: Routes.game);
      await tester.tap(find.text(l10n.gameNameTiles));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(l10n.gameTimeLeft(60)), findsOneWidget);

      // `AppLifecycleListener` asserts on a skipped state, so walk them.
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      await play(tester, 2);

      expect(find.text(l10n.gameTimeLeft(60)), findsOneWidget);
      expect(find.text(l10n.gamePaused), findsNothing);
    });

    testWidgets('the card leads with the free game, not the purchase', (
      tester,
    ) async {
      final (c, analytics) = await bootFree(tester);
      await openGame(tester, c, path: Routes.game);
      await tester.tap(find.text(l10n.gameNameBlocks));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // "Play Orbs" is the filled button and it works — one tap back onto a
      // board, which is what somebody mid-craving actually came for.
      await tester.tap(find.text(l10n.gameLockedPlayFree(l10n.gameNameOrbs)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(OrbsField), findsOneWidget);
      expect(analytics.names, isNot(contains('gate_tapped')));
    });

    testWidgets('"See Premium" is the door, tagged panic_game', (tester) async {
      final (c, analytics) = await bootFree(tester);
      await openGame(tester, c, path: Routes.game);
      await tester.tap(find.text(l10n.gameNameTiles));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text(l10n.premiumLockCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(analytics.propsOf('gate_tapped'), {'source': 'panic_game'});
      expect(
        analytics.propsOf('paywall_viewed')?['source'],
        'panic_game',
      );
    });

    testWidgets('buying from the card does not run a round behind the paywall', (
      tester,
    ) async {
      // `See Premium` PUSHES the paywall and leaves the arena mounted under
      // it, so the entitlement arrives here while nobody can see the board.
      // Opening the bought game is right; starting its clock is not — a whole
      // 60-second round would finish behind the paywall and hand them a
      // recorded score for a round they never played.
      final (c, analytics) = await bootFree(tester);
      await openGame(tester, c, path: Routes.game);
      await tester.tap(find.text(l10n.gameNameBlocks));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text(l10n.premiumLockCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.read(routerProvider).state.uri.path, Routes.paywall);

      // The purchase lands while the paywall is still on top — the row goes
      // on the fake server and the store rebinds, which is the path a real
      // one takes.
      final fake = c.read(fakeServerProvider)
        ..putEntitlement(FakeServer.demoEntitlementJson(DateTime.now()));
      // NOT awaited. `FakeServer.respond` goes through `Future.delayed`, and
      // even a zero delay is a TIMER — which in a widget test only fires when
      // something pumps. Awaiting it here deadlocks the test outright.
      unawaited(
        c.read(entitlementProvider.notifier).bindSession(fake.ensureSessionId()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await play(tester, 3);

      // The paywall closes itself once there is nothing left to sell, so the
      // arena is back — showing the board they actually bought, not the Orbs
      // they were parked on.
      expect(c.read(routerProvider).state.uri.path, Routes.game);
      expect(find.byType(BlocksField), findsOneWidget);
      expect(find.byType(OrbsField), findsNothing);

      // And no round was quietly played and recorded in the meantime.
      expect(
        analytics.names,
        isNot(contains('game_finished')),
        reason: 'a round ran to the end behind the paywall',
      );
      expect(bestOrNull(c, GameId.blocks), isNull);
      // The paywall's "Premium is on" snack carries a fallback timer
      // (`showLpSnack` force-closes at duration + 250ms); let it run out or
      // the harness reports a pending timer.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a subscriber meets no lock at all', (tester) async {
      final (c, analytics) = await boot(tester);
      await openGame(tester, c, path: Routes.game);
      final pills = tester.widget<SegmentedPills>(
        find.byType(SegmentedPills),
      );
      expect(pills.locked, isEmpty);

      await tester.tap(find.text(l10n.gameNameBlocks));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(BlocksField), findsOneWidget);
      expect(analytics.names, isNot(contains('gate_shown')));
    });
  });
}
