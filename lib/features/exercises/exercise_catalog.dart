import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router/app_router.dart';
import '../../core/utils/l10n_ext.dart';
import '../../data/stores/providers.dart';
import '../../domain/analytics/lp_events.dart';
import '../../domain/logic/exercises/exercise.dart';
import '../../domain/logic/games/games.dart';
import '../../domain/models/models.dart';
import 'breathing_exercise.dart';

/// One exercise as the app shows and opens it: the registry row's other
/// half. `Exercises` (domain) says an exercise exists, what kind it is and
/// whether it is Premium; this says what it is called, what it looks like and
/// where it opens.
class ExerciseEntry {
  const ExerciseEntry({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.screen,
  });

  final ExerciseId id;
  final IconData icon;

  /// Words come from ARB, never from the wire: a card carries an id and
  /// nothing else.
  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) subtitle;

  /// Where the exercise opens. A function of the source, so the screen at the
  /// other end knows where it was opened from and where to go back to.
  final String Function(ExerciseSource source) route;

  /// The exercise's own screen, for one that runs inside `ExerciseScaffold`.
  /// Null for an arena game and for anything that opens a screen the app
  /// already had.
  final Widget Function(ExerciseSource source)? screen;
}

/// Every exercise the app can open, in registry order.
///
/// Adding one is a row in `Exercises`, the same row on the server, and one
/// entry here; `test/features/exercise_catalog_test.dart` fails until the two
/// lists agree.
abstract final class ExerciseCatalog {
  static const List<ExerciseEntry> entries = [
    ExerciseEntry(
      id: ExerciseId.breathing,
      icon: Icons.air_rounded,
      title: _breathingTitle,
      subtitle: _breathingSubtitle,
      route: _breathingRoute,
      screen: _breathingScreen,
    ),
    ExerciseEntry(
      id: ExerciseId.orbs,
      icon: Icons.bubble_chart_rounded,
      title: _orbsTitle,
      subtitle: _gameSubtitle,
      route: _orbsRoute,
    ),
    ExerciseEntry(
      id: ExerciseId.tiles,
      icon: Icons.grid_view_rounded,
      title: _tilesTitle,
      subtitle: _gameSubtitle,
      route: _tilesRoute,
    ),
    ExerciseEntry(
      id: ExerciseId.blocks,
      icon: Icons.view_column_rounded,
      title: _blocksTitle,
      subtitle: _gameSubtitle,
      route: _blocksRoute,
    ),
    ExerciseEntry(
      id: ExerciseId.sos,
      icon: Icons.sos_rounded,
      title: _sosTitle,
      subtitle: _sosSubtitle,
      route: _sosRoute,
    ),
  ];

  static ExerciseEntry of(ExerciseId id) =>
      entries.firstWhere((entry) => entry.id == id);

  /// The ONE way to open an exercise from outside the panic flow: a coach
  /// card, and anything later that says "use this now".
  ///
  /// It opens what this account can actually use. A Premium exercise asked
  /// for by a free account (a lapsed subscriber whose server mirror has not
  /// caught up, an older card) resolves to the free one of the same kind
  /// before anything is reported or pushed, so nobody lands on a lock
  /// mid-craving and `exercise_opened` names what they got.
  ///
  /// The container is read off the context rather than passed in, so a
  /// caller with no `ref` of its own (a widget drawn by a renderer) can call
  /// it too.
  static void launch(
    BuildContext context,
    ExerciseId id, {
    required ExerciseSource source,
  }) {
    final container = ProviderScope.containerOf(context, listen: false);
    final resolved = Exercises.resolveFor(
      id,
      premium: container.read(isPremiumProvider),
    );
    container.read(analyticsProvider).exerciseOpened(resolved, source);
    context.push(of(resolved).route(source));
  }

  // Top-level-style statics rather than closures: the list above is `const`.
  static String _breathingTitle(AppLocalizations l10n) =>
      l10n.exerciseBreathingTitle;
  static String _breathingSubtitle(AppLocalizations l10n) =>
      l10n.panicBreathePattern;
  static String _breathingRoute(ExerciseSource source) =>
      Routes.exerciseFor(ExerciseId.breathing, source);
  static Widget _breathingScreen(ExerciseSource source) =>
      const BreathingExercise();

  static String _orbsTitle(AppLocalizations l10n) => l10n.gameNameOrbs;
  static String _tilesTitle(AppLocalizations l10n) => l10n.gameNameTiles;
  static String _blocksTitle(AppLocalizations l10n) => l10n.gameNameBlocks;

  /// One line for every arena game: a round's length is the arena's own
  /// constant, so the number on the card cannot drift from the clock.
  static String _gameSubtitle(AppLocalizations l10n) =>
      l10n.exerciseGameSub(GameSession.roundSeconds);
  static String _orbsRoute(ExerciseSource source) =>
      Routes.gameFor(GameId.orbs, source: source);
  static String _tilesRoute(ExerciseSource source) =>
      Routes.gameFor(GameId.tiles, source: source);
  static String _blocksRoute(ExerciseSource source) =>
      Routes.gameFor(GameId.blocks, source: source);

  static String _sosTitle(AppLocalizations l10n) => l10n.panicLoopSos;
  static String _sosSubtitle(AppLocalizations l10n) => l10n.panicLoopSosSub;

  /// The composer pre-tagged SOS, exactly where the panic flow's own option
  /// goes. It has one way out (post, or back), so it takes no source.
  static String _sosRoute(ExerciseSource source) =>
      '${Routes.compose}?tag=${PostTag.sos.name}';
}
