import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/core/widgets/lp_misc.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/games/games.dart';
import 'package:last_puff/features/panic/games/blocks_field.dart';
import 'package:last_puff/features/panic/games/orbs_field.dart';
import 'package:last_puff/features/panic/games/tile_field.dart';

import 'harness.dart';

/// The panic arcade on a real device (docs/10 §15): a real round, sixty
/// more, "it passed" counted once, then real drags, flicks, pill swaps and
/// a mid-round exit — disposal and the router are what only a device sees.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<E2E> signedIn(WidgetTester tester) async {
    final e2e = await E2E.boot(tester);
    await e2e.waitFor(const Duration(seconds: 2));
    await e2e.tapText(e2e.l10n.authContinueWithEmail);
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
    return e2e;
  }

  /// SOS → skip the breathing → still craving → the game card.
  Future<void> intoTheArena(E2E e2e) async {
    await e2e.tapText(e2e.l10n.homeSos);
    await e2e.waitFor(const Duration(seconds: 2));
    if (e2e.showing(e2e.l10n.panicSkipToWhy)) {
      await e2e.tapText(e2e.l10n.panicSkipToWhy);
    }
    await e2e.waitFor(const Duration(seconds: 1));
    if (e2e.showing(e2e.l10n.panicStillCraving)) {
      await e2e.tapText(e2e.l10n.panicStillCraving);
    }
    await e2e.waitFor(const Duration(seconds: 1));
    expect(
      e2e.showing(e2e.l10n.panicLoopGame),
      isTrue,
      reason: 'no game card; on screen: ${e2e.texts()}',
    );
    await e2e.tapText(e2e.l10n.panicLoopGame);
    await e2e.waitFor(const Duration(seconds: 1));
    // The card lands on the arena's default, which is Orbs since it became
    // the free game (docs/12 §5c). Everything below drives the Tiles board
    // specifically, so take the pill the way a person would — this account is
    // the seeded subscriber, so nothing is locked for it.
    await e2e.tapText(e2e.l10n.gameNameTiles);
    await e2e.waitFor(const Duration(seconds: 1));
  }

  testWidgets(
    'a real round, sixty more, and "it passed" counted once',
    (tester) async {
      final e2e = await signedIn(tester);
      final before = e2e.container
          .read(quitStoreProvider)!
          .cravingsSurvivedTotal;
      await intoTheArena(e2e);
      expect(
        find.byType(TileField),
        findsOneWidget,
        reason: 'the arena did not open on Tiles; on screen: ${e2e.texts()}',
      );

      // A real minute on a real ticker.
      await e2e.waitFor(const Duration(seconds: 61));
      expect(
        e2e.showing(e2e.l10n.gameMinutesDone(1)),
        isTrue,
        reason: 'no check-in after a minute; on screen: ${e2e.texts()}',
      );
      expect(e2e.showing(e2e.l10n.gameAnotherRound), isTrue);

      await e2e.tapText(e2e.l10n.gameAnotherRound);
      await e2e.waitFor(const Duration(seconds: 1));
      expect(
        find.byType(TileField),
        findsOneWidget,
        reason: 'sixty more did not resume; on screen: ${e2e.texts()}',
      );

      await e2e.waitFor(const Duration(seconds: 61));
      expect(
        e2e.showing(e2e.l10n.gameMinutesDone(2)),
        isTrue,
        reason: 'no second check-in; on screen: ${e2e.texts()}',
      );
      await e2e.tapText(e2e.l10n.panicItPassed);
      await e2e.waitFor(const Duration(seconds: 2));

      expect(
        e2e.container.read(quitStoreProvider)!.cravingsSurvivedTotal,
        before + 1,
      );
      expect(e2e.container.read(quitStoreProvider)!.lastGame, GameId.tiles);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  testWidgets('the pills swap games mid-round; drags and flicks are real', (
    tester,
  ) async {
    final e2e = await signedIn(tester);
    await intoTheArena(e2e);

    await e2e.tapText(e2e.l10n.gameNameBlocks);
    await e2e.waitFor(const Duration(seconds: 1));
    expect(
      find.byType(BlocksField),
      findsOneWidget,
      reason: 'the pill did not open Blocks; on screen: ${e2e.texts()}',
    );
    final blocks = tester.widget<BlocksField>(find.byType(BlocksField)).game;
    final rect = tester.getRect(find.byType(BlocksField));
    final cell = math.min(
      rect.width / BlocksGame.cols,
      rect.height / BlocksGame.visibleRows,
    );
    final col = blocks.active.col;

    await tester.drag(find.byType(BlocksField), Offset(2 * cell, 0));
    await tester.pump();
    expect(blocks.active.col, col + 2, reason: 'a real drag moved two cells');

    await tester.fling(find.byType(BlocksField), const Offset(0, 300), 2500);
    await tester.pump();
    expect(blocks.placed, 1, reason: 'a real flick slammed the piece');

    await e2e.tapText(e2e.l10n.gameNameOrbs);
    await e2e.waitFor(const Duration(seconds: 1));
    expect(
      find.byType(OrbsField),
      findsOneWidget,
      reason: 'the pill did not open Orbs; on screen: ${e2e.texts()}',
    );
    expect(e2e.container.read(quitStoreProvider)!.lastGame, GameId.orbs);

    // Leave mid-round: the ticker, the lifecycle listener and the frame
    // clock all tear down under a live route — the case a widget test
    // never sees.
    await e2e.tap(find.byType(BackChevron), why: 'the chevron');
    await e2e.waitFor(const Duration(seconds: 1));
    expect(
      e2e.showing(e2e.l10n.panicLoopTitle),
      isTrue,
      reason: 'the chevron did not return to step 3; on screen: ${e2e.texts()}',
    );
    await e2e.tapText(e2e.l10n.panicItPassed);
    await e2e.waitFor(const Duration(seconds: 2));
    expect(
      e2e.showing(e2e.l10n.survivedPlusOne),
      isTrue,
      reason: 'no survived screen; on screen: ${e2e.texts()}',
    );
  });
}
