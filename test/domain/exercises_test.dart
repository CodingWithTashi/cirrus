import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/exercises/exercise.dart';
import 'package:last_puff/domain/logic/games/game_id.dart';

/// The exercise registry: the ONE list of things a person can do during a
/// craving. The catalog, the coach's capability list, the server's card
/// policy, `panicSession`'s validation and the analytics values all derive
/// from it, so a row that drifts between the two sides is a card the server
/// sends and the app cannot open.
void main() {
  group('the registry', () {
    test('the first exercise is free, and ids are unique', () {
      // `all.first` is load-bearing the way `GameCatalog.entries.first` is:
      // it is where `resolveFor` lands when nothing else of a kind is free.
      expect(Exercises.all.first.premium, isFalse);
      expect(
        Exercises.all.map((s) => s.id).toSet().length,
        ExerciseId.values.length,
      );
    });

    test('parse reads a name and nothing else', () {
      expect(Exercises.parse('orbs'), ExerciseId.orbs);
      expect(Exercises.parse('nope'), isNull);
      expect(Exercises.parse(7), isNull);
      expect(Exercises.parse(null), isNull);

      expect(Exercises.parseSource('coach'), ExerciseSource.coach);
      expect(Exercises.parseSource('nope'), isNull);
      expect(Exercises.parseSource(7), isNull);
      expect(Exercises.parseSource(null), isNull);
    });

    test('a locked exercise resolves to a free one of its kind', () {
      expect(
        Exercises.resolveFor(ExerciseId.tiles, premium: false),
        ExerciseId.orbs,
      );
      expect(
        Exercises.resolveFor(ExerciseId.tiles, premium: true),
        ExerciseId.tiles,
      );
      expect(
        Exercises.resolveFor(ExerciseId.breathing, premium: false),
        ExerciseId.breathing,
      );
    });

    test('every arena game is an exercise', () {
      for (final g in GameId.values) {
        final id = Exercises.forGame(g);
        expect(id, isNotNull, reason: '${g.name} has no exercise row');
        expect(Exercises.of(id!).game, g);
      }
    });
  });

  group('the craving window', () {
    test('the craving window is twenty minutes', () {
      final now = DateTime(2026, 11, 25, 21, 30);
      expect(CravingWindow.covers(null, now), isFalse);
      expect(
        CravingWindow.covers(
          now.subtract(const Duration(minutes: 19, seconds: 59)),
          now,
        ),
        isTrue,
      );
      expect(
        CravingWindow.covers(now.subtract(const Duration(minutes: 20)), now),
        isFalse,
      );
    });
  });

  group('parity with functions/src/domain/exercises.ts', () {
    final ts = File('functions/src/domain/exercises.ts');

    List<String> listOf(String source, String name) {
      final block = RegExp(
        'export const $name = \\[(.*?)\\] as const;',
        dotAll: true,
      ).firstMatch(source);
      expect(block, isNotNull, reason: '$name not found in exercises.ts');
      return RegExp(
        r"'(\w+)'",
      ).allMatches(block!.group(1)!).map((m) => m.group(1)!).toList();
    }

    test('the server registry holds the same rows', () {
      // One row per line in exactly this key order: the server's file is read
      // with a regex, so a reformatted row is a row this test cannot see —
      // which fails here rather than passing on a shorter list.
      final source = ts.readAsStringSync();
      final server = [
        for (final m in RegExp(
          r"\{id: '(\w+)', kind: '(\w+)', premium: (true|false), game: (true|false)\}",
        ).allMatches(source))
          (
            m.group(1)!,
            m.group(2)!,
            m.group(3) == 'true',
            m.group(4) == 'true',
          ),
      ];
      expect(server, [
        for (final s in Exercises.all)
          (s.id.name, s.kind.name, s.premium, s.game != null),
      ]);

      expect(listOf(source, 'EXERCISE_KINDS'), [
        for (final k in ExerciseKind.values) k.name,
      ]);
      expect(listOf(source, 'EXERCISE_SOURCES'), [
        for (final s in ExerciseSource.values) s.name,
      ]);
    });
  });
}
