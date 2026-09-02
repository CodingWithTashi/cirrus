import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/games/games.dart';

/// Orbs' rules, pinned without a widget: the physics keeps every orb inside
/// and moving, the ladder follows the player, and a tap is one pick.
void main() {
  /// Advances in 60 fps frames, the way the ticker does.
  List<GameEvent> run(OrbsGame game, double seconds) {
    final events = <GameEvent>[];
    var t = 0.0;
    while (t < seconds - 1e-9) {
      final step = math.min(1 / 60, seconds - t);
      events.addAll(game.advance(step));
      t += step;
    }
    return events;
  }

  /// Runs until the game is in [phase], returning the events on the way.
  List<GameEvent> runTo(OrbsGame game, OrbPhase phase) {
    final events = <GameEvent>[];
    var guard = 0;
    while (game.phase != phase) {
      events.addAll(game.advance(1 / 60));
      if (++guard > 60 * 60) fail('never reached $phase');
    }
    return events;
  }

  void expectInside(OrbsGame game, {String? reason}) {
    for (final o in game.orbs) {
      expect(
        o.x,
        inInclusiveRange(
          OrbsGame.orbRadius - 1e-9,
          1 - OrbsGame.orbRadius + 1e-9,
        ),
        reason: reason,
      );
      expect(
        o.y,
        inInclusiveRange(
          OrbsGame.orbRadius - 1e-9,
          game.aspect - OrbsGame.orbRadius + 1e-9,
        ),
        reason: reason,
      );
    }
  }

  OrbView target(OrbsGame game) => game.orbs.firstWhere((o) => o.isTarget);
  OrbView distractor(OrbsGame game) => game.orbs.firstWhere((o) => !o.isTarget);

  group('the arena', () {
    test('deals the level\'s orbs without overlap, inside the walls', () {
      for (var seed = 0; seed < 50; seed++) {
        for (final level in [0, 9, OrbsGame.maxLevel]) {
          final game = OrbsGame.atLevel(level, random: math.Random(seed));
          final orbs = game.orbs;
          expect(orbs, hasLength(OrbsGame.ladder[level].orbs));
          expect(
            orbs.where((o) => o.isTarget),
            hasLength(OrbsGame.ladder[level].targets),
          );
          expectInside(game, reason: 'seed $seed level $level');
          for (var i = 0; i < orbs.length; i++) {
            for (var j = i + 1; j < orbs.length; j++) {
              final dx = orbs[i].x - orbs[j].x;
              final dy = orbs[i].y - orbs[j].y;
              expect(
                math.sqrt(dx * dx + dy * dy),
                greaterThanOrEqualTo(2 * OrbsGame.orbRadius),
                reason: 'seed $seed level $level orbs $i,$j overlap',
              );
            }
          }
        }
      }
      final game = OrbsGame(random: math.Random(1));
      expect(game.id, GameId.orbs);
      expect(game.freshEachRound, isFalse);
      expect(game.phase, OrbPhase.cue);
      expect(game.targetsVisible, isTrue);
      expect(game.level, 0);
    });

    test('an orb never leaves the arena in sixty seconds at the top', () {
      for (final seed in [0, 1, 2]) {
        final game = OrbsGame.atLevel(
          OrbsGame.maxLevel,
          random: math.Random(seed),
        );
        for (var i = 0; i < 60 * 60; i++) {
          game.advance(1 / 60);
          expectInside(game, reason: 'seed $seed frame $i');
        }
      }
    });

    test('speed is kept: nothing stalls, nothing rockets', () {
      final game = OrbsGame.atLevel(12, random: math.Random(4));
      var trackEnds = 0;
      for (var i = 0; i < 60 * 60; i++) {
        final events = game.advance(1 / 60);
        final speed = game.speed;
        final lo = OrbsGame.speedClampLo * speed * OrbsGame.pickSpeedFactor;
        final hi = OrbsGame.speedClampHi * speed;
        final speeds = [for (final o in game.orbs) o.speed];
        for (final v in speeds) {
          expect(v, inInclusiveRange(lo - 1e-9, hi + 1e-9), reason: 'frame $i');
        }
        if (events.any((e) => e is PhaseChanged && e.phase == OrbPhase.pick)) {
          trackEnds++;
          // By the end of tracking the orbs have relaxed onto the trial
          // speed — collisions trade speed between pairs, so it is the
          // group that sits on it, not every orb at every instant.
          final mean = speeds.reduce((a, b) => a + b) / speeds.length;
          expect(mean, closeTo(speed, 0.25 * speed), reason: 'end $trackEnds');
        }
      }
      expect(trackEnds, greaterThan(3));
    });

    test('an elastic swap conserves momentum and energy', () {
      final (avx, avy, bvx, bvy) = OrbsGame.elasticSwap(
        0.3,
        0.1,
        -0.2,
        0.4,
        1,
        0,
      );
      expect(avx, -0.2);
      expect(avy, 0.1, reason: 'the tangent is untouched');
      expect(bvx, 0.3);
      expect(bvy, 0.4);
      // Not closing: nothing happens.
      expect(OrbsGame.elasticSwap(-0.2, 0, 0.3, 0, 1, 0), (-0.2, 0, 0.3, 0));
    });

    test('the same seed replays the same positions', () {
      final a = OrbsGame(random: math.Random(7));
      final b = OrbsGame(random: math.Random(7));
      run(a, 20);
      run(b, 20);
      for (var i = 0; i < a.orbs.length; i++) {
        expect(a.orbs[i].x, b.orbs[i].x);
        expect(a.orbs[i].y, b.orbs[i].y);
        expect(a.orbs[i].isTarget, b.orbs[i].isTarget);
      }
      expect(a.phase, b.phase);
    });

    test('a 60 fps frame lands where two 120 fps frames do', () {
      // Within a phase, so the phase clock's frame granularity is not in
      // the comparison — only the physics is.
      final a = OrbsGame(random: math.Random(8));
      final b = OrbsGame(random: math.Random(8));
      runTo(a, OrbPhase.track);
      runTo(b, OrbPhase.track);
      for (var i = 0; i < 180; i++) {
        a.advance(1 / 60);
        b.advance(1 / 120);
        b.advance(1 / 120);
      }
      expect(a.phase, OrbPhase.track);
      for (var i = 0; i < a.orbs.length; i++) {
        expect(a.orbs[i].x, closeTo(b.orbs[i].x, 1e-9));
        expect(a.orbs[i].y, closeTo(b.orbs[i].y, 1e-9));
      }
    });

    test('resizing keeps the layout inside the new walls', () {
      final game = OrbsGame(random: math.Random(9));
      game.resize(2.0);
      expect(game.aspect, 2.0);
      expectInside(game);
      game.resize(1.0);
      expectInside(game);
      run(game, 5);
      expectInside(game);
    });
  });

  group('the trial', () {
    test('runs cue → track → pick → reveal with the ladder\'s times', () {
      for (final level in [0, OrbsGame.maxLevel]) {
        final rung = OrbsGame.ladder[level];
        final game = OrbsGame.atLevel(level, random: math.Random(2));
        expect(game.phase, OrbPhase.cue);
        var events = runTo(game, OrbPhase.track);
        expect(game.elapsed, closeTo(OrbsGame.cueFor, 0.02));
        expect(events.whereType<PhaseChanged>().single.phase, OrbPhase.track);
        expect(game.targetsVisible, isFalse);

        events = runTo(game, OrbPhase.pick);
        expect(
          game.elapsed,
          closeTo(OrbsGame.cueFor + rung.trackFor, 0.02),
          reason: 'level $level',
        );
        expect(game.phaseProgress, closeTo(0, 0.02));

        events = runTo(game, OrbPhase.reveal);
        final pickFor =
            OrbsGame.pickBase + OrbsGame.pickPerTarget * rung.targets;
        expect(
          game.elapsed,
          closeTo(OrbsGame.cueFor + rung.trackFor + pickFor, 0.02),
        );
        expect(events.whereType<PickTimedOut>(), hasLength(1));
        expect(events.whereType<TrialResolved>().single.perfect, isFalse);
        expect(game.targetsVisible, isTrue);

        events = runTo(game, OrbPhase.cue);
        expect(events.whereType<PhaseChanged>().single.phase, OrbPhase.cue);
        expect(game.trials, 1);
        expect(game.misses, 0, reason: 'a timeout is not a miss');
        expect(game.combo, 0);
      }
    });

    test('the ladder climbs one dimension at a time', () {
      expect(OrbsGame.ladder, hasLength(OrbsGame.maxLevel + 1));
      expect(OrbsGame.ladder.first.targets, 2);
      expect(OrbsGame.ladder.first.orbs, 6);
      expect(OrbsGame.ladder.last.targets, 5);
      expect(OrbsGame.ladder.last.orbs, 10);
      expect(OrbsGame.ladder.last.speed, 0.80);
      expect(OrbsGame.ladder.last.trackFor, 8);
      for (var i = 1; i < OrbsGame.ladder.length; i++) {
        final a = OrbsGame.ladder[i - 1];
        final b = OrbsGame.ladder[i];
        final changes = [
          a.targets != b.targets,
          a.orbs != b.orbs,
          a.speed != b.speed,
          a.trackFor != b.trackFor,
        ].where((c) => c).length;
        expect(changes, 1, reason: 'step $i');
        expect(b.targets, greaterThanOrEqualTo(a.targets));
        expect(b.orbs, greaterThanOrEqualTo(a.orbs));
        expect(b.speed, greaterThanOrEqualTo(a.speed));
        expect(b.trackFor, greaterThanOrEqualTo(a.trackFor));
        expect(b.targets, lessThan(b.orbs));
      }
    });

    test(
      'a perfect trial steps up, a slip steps down, never past the ends',
      () {
        final game = OrbsGame.atLevel(3, random: math.Random(5));
        runTo(game, OrbPhase.pick);
        for (final o in game.orbs.where((o) => o.isTarget)) {
          expect(game.pick(o.x, o.y), PickOutcome.found);
        }
        expect(game.phase, OrbPhase.reveal, reason: 'the last pick ends it');
        runTo(game, OrbPhase.cue);
        expect(game.level, 4);
        expect(game.perfectTrials, 1);

        runTo(game, OrbPhase.pick);
        final d = distractor(game);
        expect(game.pick(d.x, d.y), PickOutcome.wrong);
        runTo(game, OrbPhase.cue);
        expect(game.level, 3);

        final floor = OrbsGame.atLevel(0, random: math.Random(5));
        runTo(floor, OrbPhase.pick);
        runTo(floor, OrbPhase.cue);
        expect(floor.level, 0);

        final top = OrbsGame.atLevel(OrbsGame.maxLevel, random: math.Random(5));
        runTo(top, OrbPhase.pick);
        for (final o in top.orbs.where((o) => o.isTarget)) {
          top.pick(o.x, o.y);
        }
        runTo(top, OrbPhase.cue);
        expect(top.level, OrbsGame.maxLevel);
      },
    );

    test('three slips running drop an extra step', () {
      final game = OrbsGame.atLevel(6, random: math.Random(6));
      final seen = <int>[];
      for (var i = 0; i < 3; i++) {
        runTo(game, OrbPhase.pick);
        runTo(game, OrbPhase.cue);
        seen.add(game.level);
      }
      expect(seen, [5, 4, 2]);
    });

    test(
      'a tap is one pick: a target found, a distractor wrong, air nothing',
      () {
        final game = OrbsGame.atLevel(4, random: math.Random(3));
        runTo(game, OrbPhase.pick);
        final t = target(game);
        expect(game.pick(t.x, t.y), PickOutcome.found);
        expect(game.score, 1);
        expect(game.combo, 1);
        expect(game.picks.single.correct, isTrue);
        // Again on the same orb, at once and after the bounce grace: nothing.
        expect(game.pick(t.x, t.y), PickOutcome.ignored);
        run(game, 0.2);
        final again = game.orbs.firstWhere((o) => o.id == t.id);
        expect(game.pick(again.x, again.y), PickOutcome.ignored);
        expect(game.score, 1);

        final d = distractor(game);
        expect(game.pick(d.x, d.y), PickOutcome.wrong);
        expect(game.misses, 1);
        expect(game.combo, 0);
        expect(game.score, 1, reason: 'a miss never takes a find back');
        expect(game.bestCombo, 1);
        expect(
          game.targetsVisible,
          isFalse,
          reason: 'no reveal before its time',
        );
        expect(game.phase, OrbPhase.pick);

        // Far from every orb: nothing.
        var far = (0.0, 0.0);
        var farthest = 0.0;
        for (var x = 0.05; x < 1; x += 0.05) {
          for (var y = 0.05; y < game.aspect; y += 0.05) {
            var nearest = double.infinity;
            for (final o in game.orbs) {
              nearest = math.min(
                nearest,
                math.sqrt(math.pow(o.x - x, 2) + math.pow(o.y - y, 2)),
              );
            }
            if (nearest > farthest) {
              farthest = nearest;
              far = (x, y);
            }
          }
        }
        expect(
          farthest,
          greaterThan(OrbsGame.orbRadius * OrbsGame.tapRadiusFactor),
        );
        expect(game.pick(far.$1, far.$2), PickOutcome.ignored);
        expect(game.misses, 1);
      },
    );

    test('a tap while tracking is nothing', () {
      final game = OrbsGame(random: math.Random(10));
      final t = target(game);
      expect(game.pick(t.x, t.y), PickOutcome.ignored, reason: 'in the cue');
      runTo(game, OrbPhase.track);
      final o = game.orbs.first;
      expect(game.pick(o.x, o.y), PickOutcome.ignored);
      expect(game.score, 0);
      expect(game.misses, 0);
    });

    test(
      'the pick ends at the last target or the ring, and never punishes',
      () {
        final game = OrbsGame.atLevel(4, random: math.Random(11));
        runTo(game, OrbPhase.pick);
        final targets = game.orbs.where((o) => o.isTarget).toList();
        expect(targets, hasLength(3));
        game.pick(targets[0].x, targets[0].y);
        final d = distractor(game);
        game.pick(d.x, d.y);
        expect(game.phase, OrbPhase.pick, reason: 'two of three picks made');
        game.pick(targets[1].x, targets[1].y);
        expect(
          game.phase,
          OrbPhase.reveal,
          reason: 'three picks: the pick is over',
        );
        final events = game.advance(1 / 60);
        final resolved = events.whereType<TrialResolved>().single;
        expect(resolved.perfect, isFalse);
        expect(resolved.found, 2);
        expect(resolved.targets, 3);
        expect(game.combo, 1, reason: 'the last find stands');
        expect(game.misses, 1);
      },
    );
  });

  group('rounds', () {
    test('cut while tracking, the next round deals the trial afresh', () {
      final game = OrbsGame(random: math.Random(12));
      runTo(game, OrbPhase.track);
      run(game, 1);
      final ids = game.orbs.map((o) => o.id).toList();
      game.roundEnded(1);
      expect(game.frozen, isTrue);
      final frozenAt = game.orbs.first.x;
      expect(game.advance(1), isEmpty);
      expect(game.orbs.first.x, frozenAt);
      expect(game.pick(0.5, 0.5), PickOutcome.ignored);

      game.roundStarted(2);
      expect(game.frozen, isFalse);
      expect(game.phase, OrbPhase.cue);
      expect(game.targetsVisible, isTrue);
      expect(game.level, 0, reason: 'the same level');
      expect(game.orbs.map((o) => o.id), ids, reason: 'the same orbs');
      expect(
        game.advance(1 / 60).whereType<PhaseChanged>().single.phase,
        OrbPhase.cue,
      );
    });

    test('cut in the pick, the next round resumes it where it stopped', () {
      final game = OrbsGame(random: math.Random(13));
      runTo(game, OrbPhase.pick);
      run(game, 0.5);
      final progress = game.phaseProgress;
      game.roundEnded(1);
      game.roundStarted(2);
      expect(game.phase, OrbPhase.pick);
      expect(game.phaseProgress, progress);
      final t = target(game);
      expect(game.pick(t.x, t.y), PickOutcome.found);
    });

    test('orbs persist across trials', () {
      final game = OrbsGame(random: math.Random(14));
      final ids = game.orbs.map((o) => o.id).toList();
      runTo(game, OrbPhase.pick);
      runTo(game, OrbPhase.cue);
      expect(game.orbs.map((o) => o.id), ids);
      expect(game.trials, 1);
    });
  });
}
