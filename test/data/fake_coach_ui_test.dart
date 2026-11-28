import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/api/fake/fake_coach_ui.dart';
import 'package:last_puff/data/dto/coach_codec.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/exercises/exercise.dart';
import 'package:last_puff/domain/models/coach_ui.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

/// The demo backend's coach cards.
///
/// `LP_BACKEND=fake` is what desktop, web, every widget test and the device
/// suite run on, so a fake that invented its own cards would be a second
/// policy nobody reviews. It holds copies of two of the server's fixtures
/// instead, and this suite reads the fixture files to keep them copies.
void main() {
  const everyExercise = ['breathing', 'orbs', 'tiles', 'blocks', 'sos'];
  const breathing = CoachLauncherBlock(ExerciseId.breathing);
  const orbs = CoachLauncherBlock(ExerciseId.orbs);
  const sos = CoachLauncherBlock(ExerciseId.sos);

  Map<String, dynamic> fixture(String name) =>
      jsonDecode(
            File(
              'functions/test/fixtures/coach_ui/$name.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  Map<String, dynamic> caps({
    List<String> exercises = everyExercise,
    bool craving = false,
  }) => {'v': 1, 'exercises': exercises, 'craving': craving};

  ProviderContainer demo({bool premium = true}) {
    final container = ProviderContainer(
      overrides: fastBackendOverrides(premium: premium),
    );
    addTearDown(container.dispose);
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    return container;
  }

  /// One turn through the fake's own endpoint, decoded as the app decodes it.
  Future<List<CoachBlock>> ask(
    ProviderContainer container,
    Map<String, dynamic> request,
  ) async => CoachReplyCodec.decode(
    await container.read(coachApiProvider).requestReply({
      'capped': false,
      ...request,
    }),
  ).blocks;

  test("the fake's cards are the server's", () {
    expect(fakeCoachUi.keys.toSet(), {'panic_default', 'craving_chip'});
    for (final MapEntry(key: name, value: blocks) in fakeCoachUi.entries) {
      expect(blocks, fixture(name)['blocks'], reason: name);
    }
  });

  test('a subscriber who taps the craving chip gets the menu', () async {
    final container = demo();

    expect(await ask(container, {'chip': 'craving', 'ui': caps()}), [
      breathing,
      orbs,
      sos,
    ]);
  });

  test('a free account gets none', () async {
    final container = demo(premium: false);

    expect(await ask(container, {'chip': 'craving', 'ui': caps()}), isEmpty);
    expect(
      await ask(container, {
        'text': 'help',
        'panicIntensity': 9,
        'ui': caps(craving: true),
      }),
      isEmpty,
    );
  });

  test('an app that advertises nothing gets none', () async {
    // An older build, and the Day-1 walkthrough's coach step.
    final container = demo();

    expect(await ask(container, {'chip': 'craving'}), isEmpty);
    expect(
      await ask(container, {'text': 'help', 'panicIntensity': 9}),
      isEmpty,
    );
    // And the envelope is exactly what it was before cards existed.
    final raw = await container.read(coachApiProvider).requestReply({
      'chip': 'craving',
      'capped': false,
    });
    expect(raw.containsKey('ui'), isFalse);
  });

  test('a craving in progress gets one', () async {
    final container = demo();

    // Sent from the panic flow, with its strength.
    expect(
      await ask(container, {
        'text': 'about to cave',
        'panicIntensity': 8,
        'ui': caps(),
      }),
      [breathing],
    );
    // The message after the craving chip: one next step, not the menu again.
    expect(
      await ask(container, {'text': 'still here', 'ui': caps(craving: true)}),
      [breathing],
    );
    // And the chip itself, tapped from inside one.
    expect(
      await ask(container, {'chip': 'craving', 'ui': caps(craving: true)}),
      [breathing],
    );
  });

  test('the fake never offers what was not advertised', () async {
    final container = demo();

    final blocks = await ask(container, {
      'chip': 'craving',
      'ui': caps(exercises: const ['orbs']),
    });

    expect(
      CoachReplyCodec.encode(
        CoachReply(template: CoachTemplate.generic1, blocks: blocks),
      )['ui']['blocks'],
      fixture('narrow_client')['blocks'],
    );
    expect(blocks, [orbs]);
    // Nothing advertised at all is nothing offered.
    expect(
      await ask(container, {
        'chip': 'craving',
        'ui': caps(exercises: const []),
      }),
      isEmpty,
    );
  });

  test('other chips and ordinary messages get none', () async {
    final container = demo();

    for (final chip in ['roughDay', 'slipped', 'progress']) {
      expect(await ask(container, {'chip': chip, 'ui': caps()}), isEmpty);
    }
    expect(await ask(container, {'text': 'hello', 'ui': caps()}), isEmpty);
  });

  test('a card rides on the reply it belongs to, end to end', () async {
    // Store, repository, fake endpoint, codec, store: the whole demo stack.
    final container = demo();
    final store = container.read(coachStoreProvider.notifier);

    await store.sendChip(CoachChip.craving);
    expect(container.read(coachStoreProvider).messages.last.blocks, [
      breathing,
      orbs,
      sos,
    ]);

    await store.send('it is not passing', craving: true);
    expect(container.read(coachStoreProvider).messages.last.blocks, [
      breathing,
    ]);

    await store.send('thank you');
    expect(container.read(coachStoreProvider).messages.last.blocks, isEmpty);
  });

  group('fakeBlocksFor', () {
    test('agrees with the server wherever it has no history to read', () {
      // The fake keeps no craving history, has one audience and no model
      // to say what a reply was about, so it can answer the fixtures whose
      // input has none of those. For each of them it must say exactly what
      // the server's policy says.
      const modelled = [
        'panic_default',
        'craving_chip',
        'trial_tier',
        'free_tier',
        'old_client',
        'narrow_client',
        'other_chip',
        'free_text',
      ];
      for (final name in modelled) {
        final input = fixture(name)['input'] as Map<String, dynamic>;
        expect(input['audience'], 'premium', reason: name);
        expect(input['recentTools'], isEmpty, reason: name);
        expect(input['suggested'], isEmpty, reason: name);
        final inputCaps = input['caps'] as Map<String, dynamic>?;
        final blocks = fakeBlocksFor(
          request: {
            'chip': ?input['chip'],
            'panicIntensity': ?input['panicIntensity'],
            if (inputCaps != null) 'ui': {'v': 1, ...inputCaps},
          },
          tier: input['tier'] as String,
        );
        expect(blocks, fixture(name)['blocks'], reason: name);
      }
    });

    test('reads only a tier that pays, and only a ui that is one', () {
      final request = {'chip': 'craving', 'ui': caps()};
      expect(fakeBlocksFor(request: request, tier: 'premium'), hasLength(3));
      expect(fakeBlocksFor(request: request, tier: 'trial'), hasLength(3));
      for (final tier in ['free', 'expired', '', null]) {
        expect(fakeBlocksFor(request: request, tier: tier), isEmpty);
      }
      for (final ui in ['x', 7, const <Object>[], null]) {
        expect(
          fakeBlocksFor(
            request: {'chip': 'craving', 'ui': ui},
            tier: 'premium',
          ),
          isEmpty,
          reason: '$ui',
        );
      }
      // A ui with no list of exercises advertised nothing.
      expect(
        fakeBlocksFor(
          request: {
            'chip': 'craving',
            'ui': {'v': 1, 'exercises': 'orbs'},
          },
          tier: 'premium',
        ),
        isEmpty,
      );
    });
  });
}
