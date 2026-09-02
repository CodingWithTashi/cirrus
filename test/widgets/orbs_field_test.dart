import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/games/games.dart';
import 'package:last_puff/features/panic/games/orbs_field.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// Orbs on the real router: the prompts say what to do, a target tap is a
/// find, a distractor costs only the combo, a tap while tracking is nothing.
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
    container.read(routerProvider).go(Routes.gameFor(GameId.orbs));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(OrbsField), findsOneWidget);
    return container;
  }

  OrbsGame engine(WidgetTester tester) =>
      tester.widget<OrbsField>(find.byType(OrbsField)).game;

  Future<void> playTo(WidgetTester tester, OrbPhase phase) async {
    final game = engine(tester);
    for (var i = 0; i < 200 && game.phase != phase; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(game.phase, phase);
  }

  Offset at(WidgetTester tester, OrbView orb) {
    final rect = tester.getRect(find.byType(OrbsField));
    // The engine's y is in widths, like x.
    return Offset(
      rect.left + orb.x * rect.width,
      rect.top + orb.y * rect.width,
    );
  }

  testWidgets('the field says what to do at every phase', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await boot(tester);
    final game = engine(tester);
    final count = game.targetCount;
    expect(find.text(l10n.orbsCue(count)), findsOneWidget);
    expect(find.text(l10n.orbsCueSub), findsOneWidget);

    await playTo(tester, OrbPhase.track);
    await tester.pump();
    expect(find.text(l10n.orbsTrack), findsOneWidget);

    await playTo(tester, OrbPhase.pick);
    await tester.pump();
    expect(find.text(l10n.orbsPick(count)), findsOneWidget);
    expect(find.text(l10n.orbsProgress(0, count)), findsOneWidget);

    final target = game.orbs.firstWhere((o) => o.isTarget);
    await tester.tapAt(at(tester, target));
    await tester.pump();
    expect(find.text(l10n.orbsProgress(1, count)), findsOneWidget);

    await playTo(tester, OrbPhase.reveal);
    await tester.pump();
    expect(find.text(l10n.orbsProgress(1, count)), findsOneWidget);
    expect(find.text(l10n.orbsRevealSub), findsOneWidget);
  });

  testWidgets('the field hands the engine its real aspect', (tester) async {
    await boot(tester);
    final rect = tester.getRect(find.byType(OrbsField));
    expect(engine(tester).aspect, closeTo(rect.height / rect.width, 1e-9));
  });

  testWidgets('a tap on a target while the ring is up is a find', (
    tester,
  ) async {
    await boot(tester);
    final game = engine(tester);
    await playTo(tester, OrbPhase.pick);
    final target = game.orbs.firstWhere((o) => o.isTarget);

    await tester.tapAt(at(tester, target));
    await tester.pump();

    expect(game.score, 1);
    expect(game.combo, 1);
    expect(find.text('1'), findsWidgets, reason: 'the header shows the count');
  });

  testWidgets('a wrong orb costs the combo and nothing else', (tester) async {
    await boot(tester);
    final game = engine(tester);
    await playTo(tester, OrbPhase.pick);
    final target = game.orbs.firstWhere((o) => o.isTarget);
    await tester.tapAt(at(tester, target));
    await tester.pump();
    expect(game.combo, 1);

    final wrong = game.orbs.firstWhere((o) => !o.isTarget);
    await tester.tapAt(at(tester, wrong));
    await tester.pump();

    expect(game.misses, 1);
    expect(game.combo, 0);
    expect(game.score, 1);
    expect(find.byType(OrbsField), findsOneWidget, reason: 'no game-over');
  });

  testWidgets('a find throws sparks — unless motion is reduced', (
    tester,
  ) async {
    await boot(tester);
    var game = engine(tester);
    await playTo(tester, OrbPhase.pick);
    var scope = tester.widget<OrbsField>(find.byType(OrbsField)).scope;
    await tester.tapAt(at(tester, game.orbs.firstWhere((o) => o.isTarget)));
    await tester.pump();
    expect(scope.particles.aliveAt(game.elapsed), greaterThan(0));

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await boot(tester);
    game = engine(tester);
    await playTo(tester, OrbPhase.pick);
    scope = tester.widget<OrbsField>(find.byType(OrbsField)).scope;
    await tester.tapAt(at(tester, game.orbs.firstWhere((o) => o.isTarget)));
    await tester.pump();
    expect(game.score, 1, reason: 'the game itself still plays');
    expect(scope.particles.aliveAt(game.elapsed), 0);
  });

  testWidgets('a tap while tracking is nothing', (tester) async {
    await boot(tester);
    final game = engine(tester);
    await playTo(tester, OrbPhase.track);
    final orb = game.orbs.first;
    await tester.tapAt(at(tester, orb));
    await tester.pump();
    expect(game.score, 0);
    expect(game.misses, 0);
  });
}
