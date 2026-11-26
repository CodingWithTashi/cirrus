import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/exercises/exercise.dart';
import 'package:last_puff/features/exercises/exercise_launcher_card.dart';
import 'package:last_puff/features/panic/games/orbs_field.dart';
import 'package:last_puff/features/panic/games/tile_field.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';

/// The one card that opens an exercise, on the real router.
///
/// The case this exists for: a lapsed subscriber whose server mirror still
/// says Premium is sent a Tiles card. The card must name and open the free
/// game of the same kind. Nobody lands on a lock mid-craving, and nothing is
/// sold from a card.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<(ProviderContainer, RecordingAnalytics)> boot(
    WidgetTester tester, {
    bool premium = true,
  }) async {
    final analytics = RecordingAnalytics();
    final container = ProviderContainer(
      overrides: fastBackendOverrides(analytics: analytics, premium: premium),
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

  /// One card on a page of its own over Home, inside the app's router, theme
  /// and strings. No screen shows a card yet, so the test brings its own.
  Future<void> showCard(WidgetTester tester, ExerciseId id) async {
    unawaited(
      lpRootNavigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ExerciseLauncherCard(
                  id: id,
                  source: ExerciseSource.coach,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Never `pumpAndSettle` once the arena is up: the field animates until the
  /// round ends.
  Future<void> tapCard(WidgetTester tester) async {
    await tester.tap(find.byType(ExerciseLauncherCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Every location on the router's stack, shell branches and pushed routes
  /// included.
  List<String> stack(ProviderContainer c) {
    final out = <String>[];
    void walk(List<RouteMatchBase> matches) {
      for (final match in matches) {
        out.add(match.matchedLocation);
        if (match is ShellRouteMatch) walk(match.matches);
        if (match is ImperativeRouteMatch) walk(match.matches.matches);
      }
    }

    walk(c.read(routerProvider).routerDelegate.currentConfiguration.matches);
    return out;
  }

  testWidgets('the card says what it opens', (tester) async {
    // Disposed at the end of the body, not in a tearDown: flutter_test checks
    // for live handles BEFORE tearDowns run.
    final handle = tester.ensureSemantics();
    await boot(tester);
    await showCard(tester, ExerciseId.orbs);

    expect(find.text(l10n.gameNameOrbs), findsOneWidget);
    expect(find.text(l10n.exerciseGameSub(60)), findsOneWidget);
    // One button to a screen reader, carrying its own words.
    expect(
      tester.getSemantics(find.byType(ExerciseLauncherCard)),
      isSemantics(
        label: '${l10n.gameNameOrbs}\n${l10n.exerciseGameSub(60)}',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets(
    'a locked exercise is shown and opened as the free one of its kind',
    (tester) async {
      final (c, analytics) = await boot(tester, premium: false);
      await showCard(tester, ExerciseId.tiles);

      expect(find.text(l10n.gameNameOrbs), findsOneWidget);
      expect(find.text(l10n.gameNameTiles), findsNothing);

      await tapCard(tester);

      expect(find.byType(OrbsField), findsOneWidget);
      expect(find.byType(TileField), findsNothing);
      // The lock card would have been a `gate_shown`; there is none to show.
      expect(find.text(l10n.premiumLockCta), findsNothing);
      // What OPENED, not what was asked for.
      expect(analytics.propsOfAll('exercise_opened'), [
        {'exercise': 'orbs', 'source': 'coach'},
      ]);
      expect(c.read(routerProvider).state.uri.path, Routes.game);
      expect(c.read(routerProvider).state.uri.queryParameters['g'], 'orbs');
      expect(
        stack(c).where((location) => location.startsWith(Routes.paywall)),
        isEmpty,
        reason: 'on the stack: ${stack(c)}',
      );
    },
  );

  testWidgets('a subscriber gets what the card names', (tester) async {
    final (c, analytics) = await boot(tester);
    await showCard(tester, ExerciseId.tiles);

    expect(find.text(l10n.gameNameTiles), findsOneWidget);
    expect(find.text(l10n.gameNameOrbs), findsNothing);

    await tapCard(tester);

    expect(find.byType(TileField), findsOneWidget);
    expect(analytics.propsOfAll('exercise_opened'), [
      {'exercise': 'tiles', 'source': 'coach'},
    ]);
    expect(c.read(routerProvider).state.uri.queryParameters['g'], 'tiles');
  });

  test('the folder sells nothing', () {
    final files = Directory('lib/features/exercises')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty);
    for (final file in files) {
      expect(
        file.readAsStringSync().toLowerCase(),
        isNot(contains('paywall')),
        reason: '${file.path} must not sell anything',
      );
    }
  });
}
