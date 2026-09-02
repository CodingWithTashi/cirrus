import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/games/games.dart';
import 'package:last_puff/features/panic/games/blocks_field.dart';

import '../helpers.dart';

/// Blocks on the real router: one gesture is one action — tap turns, drag
/// slides a column per cell, slow drag pulls a row per cell, flick slams.
void main() {
  Future<ProviderContainer> boot(WidgetTester tester) async {
    final container = ProviderContainer(overrides: fastBackendOverrides());
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
    container.read(routerProvider).go(Routes.gameFor(GameId.blocks));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(BlocksField), findsOneWidget);
    return container;
  }

  BlocksGame engine(WidgetTester tester) =>
      tester.widget<BlocksField>(find.byType(BlocksField)).game;

  double cell(WidgetTester tester) {
    final rect = tester.getRect(find.byType(BlocksField));
    return math.min(
      rect.width / BlocksGame.cols,
      rect.height / BlocksGame.visibleRows,
    );
  }

  Future<void> play(WidgetTester tester, double seconds) async {
    for (var i = 0; i < (seconds * 10).round(); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a tap turns the piece', (tester) async {
    await boot(tester);
    final game = engine(tester);
    expect(game.active.state, 0);
    await tester.tap(find.byType(BlocksField));
    await tester.pump();
    expect(game.active.state, 1);
    expect(game.placed, 0);
  });

  testWidgets('a drag slides one column per cell and sticks to the finger', (
    tester,
  ) async {
    await boot(tester);
    final game = engine(tester);
    final c = cell(tester);
    final start = game.active.col;

    await tester.drag(find.byType(BlocksField), Offset(2 * c, 0));
    await tester.pump();
    expect(game.active.col, start + 2);

    await tester.drag(find.byType(BlocksField), Offset(-c, 0));
    await tester.pump();
    expect(game.active.col, start + 1);
    expect(game.active.state, 0, reason: 'a drag never turns');
    expect(game.placed, 0, reason: 'a drag never drops');
  });

  testWidgets('a slow downward drag pulls a row per cell, never a slam', (
    tester,
  ) async {
    await boot(tester);
    final game = engine(tester);
    final c = cell(tester);
    final before = game.active.row;

    await tester.timedDrag(
      find.byType(BlocksField),
      Offset(0, 3 * c),
      const Duration(milliseconds: 600),
    );
    await tester.pump();

    expect(game.active.row, greaterThanOrEqualTo(before + 3));
    expect(game.placed, 0);
    expect(game.active.state, 0);
  });

  testWidgets('a flick slams the piece down and locks it', (tester) async {
    await boot(tester);
    final game = engine(tester);
    await play(tester, 0.3); // past the spawn grace
    final kind = game.active.kind;

    await tester.fling(find.byType(BlocksField), const Offset(0, 240), 2500);
    await tester.pump();

    expect(game.placed, 1);
    expect(game.locks.single.hardDrop, isTrue);
    expect(game.locks.single.tone, kind.tone);
    expect(
      find.byType(BlocksField),
      findsOneWidget,
      reason: 'the round goes on',
    );
  });

  testWidgets('an upward drag does nothing', (tester) async {
    await boot(tester);
    final game = engine(tester);
    final c = cell(tester);
    await tester.drag(find.byType(BlocksField), Offset(0, -4 * c));
    await tester.pump();
    expect(game.placed, 0);
    expect(game.active.row, lessThanOrEqualTo(2));
  });

  testWidgets('a burst of taps is at most a turn each, never a drop', (
    tester,
  ) async {
    await boot(tester);
    final game = engine(tester);
    for (var i = 0; i < 20; i++) {
      await tester.tap(find.byType(BlocksField));
      await tester.pump(const Duration(milliseconds: 15));
    }
    expect(game.placed, 0);
    expect(game.active.state, inInclusiveRange(0, 3));
  });

  testWidgets('a round end freezes the board under the panel', (tester) async {
    await boot(tester);
    final game = engine(tester);
    await play(tester, 60);
    await tester.pump(const Duration(milliseconds: 400));
    expect(game.frozen, isTrue);
    final piece = game.active;
    await play(tester, 1);
    expect(game.active.y, piece.y);
  });
}
