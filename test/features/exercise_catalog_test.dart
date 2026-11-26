import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/domain/logic/exercises/exercise.dart';
import 'package:last_puff/features/exercises/exercise_catalog.dart';
import 'package:last_puff/features/panic/games/game_catalog.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

/// The app's half of the exercise registry: what each exercise is called,
/// what it looks like and where it opens.
///
/// `Exercises` (domain) says which exercises exist; this pins that the
/// catalog answers for every one of them and for nothing else, so a new row
/// in the registry fails here until it has an entry.
void main() {
  test('every exercise has exactly one entry, in registry order', () {
    expect(
      [for (final e in ExerciseCatalog.entries) e.id],
      [for (final s in Exercises.all) s.id],
    );
    for (final id in ExerciseId.values) {
      expect(ExerciseCatalog.of(id).id, id);
    }
  });

  test('every entry has words in every language', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final entry in ExerciseCatalog.entries) {
        expect(
          entry.title(l10n).trim(),
          isNotEmpty,
          reason: '${entry.id.name} title, $locale',
        );
        expect(
          entry.subtitle(l10n).trim(),
          isNotEmpty,
          reason: '${entry.id.name} subtitle, $locale',
        );
      }
    }
  });

  test("routes are the catalog's, and sit where the gates already are", () {
    final breathing = ExerciseCatalog.of(
      ExerciseId.breathing,
    ).route(ExerciseSource.coach);
    final orbs = ExerciseCatalog.of(
      ExerciseId.orbs,
    ).route(ExerciseSource.coach);
    final sos = ExerciseCatalog.of(ExerciseId.sos).route(ExerciseSource.coach);

    expect(breathing, '/panic/exercise/breathing?src=coach');
    expect(orbs, '/panic/game?g=orbs&src=coach');
    expect(sos, '/community/compose?tag=sos');
    // Under `/panic`, so the journey gate and the forced-update deferral the
    // router already applies there cover a card's destination too.
    expect(breathing, startsWith(Routes.panic));
    expect(orbs, startsWith(Routes.panic));
  });

  test('a game is premium because its exercise is', () {
    for (final e in GameCatalog.entries) {
      expect(
        e.premium,
        Exercises.of(Exercises.forGame(e.id)!).premium,
        reason: e.id.name,
      );
    }
    // And the registry is the ONLY place that says so. A flag of its own on
    // the game catalog is a second list, and two lists drift.
    final catalog = File(
      'lib/features/panic/games/game_catalog.dart',
    ).readAsStringSync();
    expect(catalog, isNot(contains('this.premium')));
    expect(catalog, isNot(contains('premium: true')));
  });
}
