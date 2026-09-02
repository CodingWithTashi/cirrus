import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/tile_game.dart';
import 'package:last_puff/features/panic/panic_screens.dart';
import 'package:last_puff/features/panic/tile_field.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// The 60-second panic game on the real router (docs/09 §8).
///
/// What these pin, in order of how much it would cost to lose: one tap is
/// one hit and never more (QA H1's lesson, applied to the game); a miss
/// costs the combo and nothing else; sixty seconds end on a choice rather
/// than a claim; the best is a number from real play, recorded on the
/// journey, and never shown before it exists.
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

  /// Home → the game. Never `pumpAndSettle` past this point: the field
  /// animates until the run ends.
  Future<void> openGame(WidgetTester tester, ProviderContainer c) async {
    c.read(routerProvider).go(Routes.game);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TileField), findsOneWidget);
  }

  TileGame engine(WidgetTester tester) =>
      tester.widget<TileField>(find.byType(TileField)).game;

  /// Pumps game time in 100 ms frames. One pump of sixty seconds would be a
  /// single clamped step (`TileGame.maxStep`) — the clamp is the point.
  Future<void> play(WidgetTester tester, double seconds) async {
    for (var i = 0; i < (seconds * 10).round(); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
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

  int best(ProviderContainer c) => c.read(quitStoreProvider)!.bestGameScore!;
  int? bestOrNull(ProviderContainer c) =>
      c.read(quitStoreProvider)!.bestGameScore;
  int survived(ProviderContainer c) =>
      c.read(quitStoreProvider)!.cravingsSurvivedTotal;

  testWidgets('one tap on the target lane is one hit', (tester) async {
    final (c, _) = await boot(tester);
    await openGame(tester, c);
    final game = engine(tester);

    await tapLane(tester, game.targetLane);

    expect(game.score, 1);
    expect(game.combo, 1);
    expect(find.text('1'), findsWidgets, reason: 'the header shows the count');
  });

  testWidgets(
    'a burst of taps in one lane is never more hits than rows there',
    (tester) async {
      // The tap ramp that turned 18 taps into 68 puffs lives nowhere near
      // this screen, and this is what keeps it out: six pointer-downs in one
      // lane resolve exactly the rows at the head of the board in that lane
      // (one or two — never three, by the deal), and the bounces after them
      // are neither hits nor misses.
      final (c, _) = await boot(tester);
      await openGame(tester, c);
      final game = engine(tester);
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

  testWidgets('a wrong lane costs the combo and nothing else', (tester) async {
    final (c, _) = await boot(tester);
    await openGame(tester, c);
    final game = engine(tester);
    await tapLane(tester, game.targetLane);
    expect(game.combo, 1);
    final rows = game.rows;
    await play(tester, 0.3); // past the bounce grace

    await tapLane(tester, wrongLane(game));

    expect(game.combo, 0);
    expect(game.score, 1);
    expect(game.misses, 1);
    expect(game.rows, rows, reason: 'the target is still waiting');
    expect(game.finished, isFalse);
    expect(find.byType(TileField), findsOneWidget, reason: 'no game-over');
  });

  testWidgets('sixty seconds end on a choice, and the run is recorded', (
    tester,
  ) async {
    final (c, analytics) = await boot(tester);
    expect(bestOrNull(c), isNull, reason: 'the demo journey never played');
    final before = survived(c);
    await openGame(tester, c);
    final game = engine(tester);
    await hits(tester, game, 2);
    final score = game.score;
    expect(score, 2);

    await play(tester, 60);
    await tester.pump(const Duration(milliseconds: 400));

    expect(game.finished, isTrue);
    expect(find.text(l10n.gameRoundDone), findsOneWidget);
    expect(find.text(l10n.gameAnotherRound), findsOneWidget);
    expect(find.text(l10n.panicItPassed), findsOneWidget);
    // The first real score is a best, and it is on the journey already.
    expect(best(c), score);
    expect(find.textContaining(l10n.survivedGameNewBest), findsOneWidget);
    // No claim was made on their behalf.
    expect(survived(c), before);
    expect(analytics.names, contains('game_finished'));
    expect(analytics.propsOf('game_finished')!['score'], score);
  });

  testWidgets('"it passed" lands on the survived screen carrying the run', (
    tester,
  ) async {
    final (c, _) = await boot(tester);
    final before = survived(c);
    await openGame(tester, c);
    final game = engine(tester);
    await hits(tester, game, 1);
    await play(tester, 60);
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text(l10n.panicItPassed));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SurvivedScreen), findsOneWidget);
    expect(find.textContaining(l10n.survivedGameNewBest), findsOneWidget);
    expect(survived(c), before + 1);
  });

  testWidgets('"still craving" starts a fresh run and claims nothing', (
    tester,
  ) async {
    final (c, _) = await boot(tester);
    final before = survived(c);
    await openGame(tester, c);
    final first = engine(tester);
    await hits(tester, first, 2);
    await play(tester, 60);
    await tester.pump(const Duration(milliseconds: 400));
    expect(best(c), 2);

    await tester.tap(find.text(l10n.gameAnotherRound));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final second = engine(tester);
    expect(identical(second, first), isFalse);
    expect(second.score, 0);
    expect(find.text(l10n.gameTimeLeft(60)), findsOneWidget);
    expect(survived(c), before);

    // A lower second run leaves the best where it was and says so.
    await hits(tester, second, 1);
    await play(tester, 60);
    await tester.pump(const Duration(milliseconds: 400));
    expect(best(c), 2);
    expect(find.textContaining(l10n.survivedGameNewBest), findsNothing);
    expect(find.textContaining(l10n.survivedGameBest(2)), findsOneWidget);
  });

  testWidgets('the header never names a best before one exists', (
    tester,
  ) async {
    final (c, _) = await boot(tester);
    await openGame(tester, c);
    final game = engine(tester);
    expect(find.text(l10n.gameNewBest), findsNothing);

    // The first run ever: a hit is a score, not a "new best".
    await tapLane(tester, game.targetLane);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.gameNewBest), findsNothing);
  });

  testWidgets('passing an existing best mid-run says so, once', (tester) async {
    final (c, _) = await boot(tester);
    c.read(quitStoreProvider.notifier).recordGameScore(1);
    await openGame(tester, c);
    final game = engine(tester);

    await tapLane(tester, game.targetLane);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.gameNewBest), findsNothing, reason: 'a tie');

    await tapLane(tester, game.targetLane);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.gameNewBest), findsOneWidget);
  });

  testWidgets('the survived screen without a game shows no game line', (
    tester,
  ) async {
    final (c, _) = await boot(tester);
    c.read(routerProvider).go(Routes.survived);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SurvivedScreen), findsOneWidget);
    expect(find.byType(GameResultLine), findsNothing);
  });
}
