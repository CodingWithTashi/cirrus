import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/dto/coach_codec.dart';
import 'package:last_puff/domain/logic/exercises/exercise.dart';
import 'package:last_puff/domain/models/enums.dart';

/// The coach-card fixtures (K6): fourteen `{input, blocks}` files that both
/// sides are pinned to. The server's `planBlocks(input)` must answer `blocks`;
/// this suite proves every `blocks` is something this build can decode, and
/// that the files themselves are well-formed — a fixture with a typo in it
/// pins both sides to the typo.
///
/// They live under `functions/` because the server's policy is what they
/// describe; the app reads them from there.
void main() {
  final dir = Directory('functions/test/fixtures/coach_ui');

  const names = [
    'audience_all_free',
    'audience_off',
    'craving_chip',
    'craving_chip_recent',
    'craving_chip_recent_tiles',
    'craving_followup',
    'free_text',
    'free_tier',
    'narrow_client',
    'old_client',
    'other_chip',
    'panic_default',
    'panic_recent',
    'trial_tier',
  ];

  Map<String, dynamic> read(String name) =>
      jsonDecode(File('${dir.path}/$name.json').readAsStringSync())
          as Map<String, dynamic>;

  test('the folder holds exactly the fourteen fixtures', () {
    final found = [
      for (final entry in dir.listSync())
        if (entry is File && entry.path.endsWith('.json'))
          entry.uri.pathSegments.last.replaceAll('.json', ''),
    ]..sort();
    expect(found, names);
  });

  for (final name in names) {
    group(name, () {
      test('is an input and the blocks it must produce', () {
        final fixture = read(name);
        expect(fixture.keys.toSet(), {'input', 'blocks'});
        expect(fixture['input'], isA<Map<String, dynamic>>());
        expect(fixture['blocks'], isA<List<dynamic>>());
      });

      test(
        'its input carries all six fields, each a value the policy reads',
        () {
          final input = read(name)['input'] as Map<String, dynamic>;
          expect(input.keys.toSet(), {
            'audience',
            'tier',
            'chip',
            'panicIntensity',
            'caps',
            'recentTools',
          });
          expect(input['audience'], isIn(['off', 'premium', 'all']));
          expect(input['tier'], isIn(['free', 'trial', 'premium']));
          expect(
            input['chip'],
            isIn([null, for (final c in CoachChip.values) c.name]),
          );
          expect(input['panicIntensity'], anyOf(isNull, isA<int>()));
          expect(input['recentTools'], everyElement(isA<String>()));

          final caps = input['caps'];
          if (caps != null) {
            caps as Map<String, dynamic>;
            expect(caps.keys.toSet(), {'exercises', 'craving'});
            expect(caps['exercises'], everyElement(isA<String>()));
            expect(caps['craving'], isA<bool>());
          }
        },
      );

      test('every block is a launcher for an exercise this build knows', () {
        final blocks = read(name)['blocks'] as List<dynamic>;
        expect(blocks.length, lessThanOrEqualTo(CoachReplyCodec.maxBlocks));
        for (final block in blocks) {
          block as Map<String, dynamic>;
          // An id and nothing else: never a route, a label or a number.
          expect(block.keys.toSet(), {'t', 'exercise'});
          expect(block['t'], 'launcher');
          expect(
            Exercises.parse(block['exercise']),
            isNotNull,
            reason: '${block['exercise']} is not an ExerciseId',
          );
        }
      });

      test('the app decodes every card the server would send', () {
        final blocks = read(name)['blocks'] as List<dynamic>;
        final reply = CoachReplyCodec.decode({
          'template': 'generic1',
          'ui': {'v': 1, 'blocks': blocks},
        });
        expect(reply.blocks.length, blocks.length);
      });
    });
  }
}
