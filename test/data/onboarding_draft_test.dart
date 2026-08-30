import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/onboarding_draft_persistence.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/onboarding/onboarding_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

/// The onboarding draft has to survive an app kill.
///
/// The funnel is nineteen screens and about two and a half minutes, and every
/// answer used to live only in a Riverpod notifier — the first and only write
/// happened after the paywall, so a kill at 8/12 lost the lot.
///
/// The round-trip case below is this file's equivalent of
/// `dto_roundtrip_test.dart`: a field that is saved but not read back is
/// exactly the bug the whole-object shape exists to prevent.
void main() {
  const key = 'onboarding.draft';
  final now = DateTime(2026, 8, 30, 14, 0);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer container({DateTime? clock, bool restore = true}) {
    final c = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(now: clock ?? now),
        onboardingProvider.overrideWith(
          () => OnboardingViewModel(restore: restore),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Answers every question, leaving the draft at [ObStep.spend].
  OnboardingViewModel filled(ProviderContainer c) {
    final vm = c.read(onboardingProvider.notifier)
      ..selectGender(Gender.woman)
      ..selectAttempts(QuitAttempts.twoToFive)
      ..selectFrequency(VapeFrequency.always)
      ..selectStrength(NicStrength.mg35)
      ..selectFirstPuff(FirstPuffWindow.fiveToThirty)
      ..toggleWhy(WhyChip.health)
      ..toggleWhy(WhyChip.fitness)
      ..toggleWorry(WorryChip.cravings)
      ..selectMethod(QuitMethod.coldTurkey)
      ..selectPace(60)
      ..setEmail('maya@quitmail.com');
    for (final d in [1, 9, 9, 8]) {
      vm.typeBirthDigit(d);
    }
    for (final d in [2, 0, 0]) {
      vm.typePuffDigit(d);
    }
    for (final d in [4, 5]) {
      vm.typeSpendDigit(d);
    }
    vm.state = vm.state.copyWith(step: ObStep.spend);
    return vm;
  }

  group('the persistence layer', () {
    test('a fresh install has nothing to resume', () async {
      expect(await OnboardingDraftPersistence.load(now: now), isNull);
    });

    test('every field survives a save and a reload', () async {
      // The gate on this file. A field saved but never read back is the exact
      // failure the whole-object shape exists to prevent.
      const draft = OnboardingState(
        step: ObStep.pace,
        email: 'someone@example.com',
        gender: Gender.nonBinary,
        birthYearInput: '1994',
        attempts: QuitAttempts.moreThanFive,
        frequency: VapeFrequency.often,
        puffsInput: '175',
        strength: NicStrength.mg20,
        spendInput: '33',
        firstPuff: FirstPuffWindow.hourPlus,
        whys: {WhyChip.money, WhyChip.family},
        worries: {WorryChip.stress, WorryChip.weight},
        method: QuitMethod.coldTurkey,
        paceDays: 90,
        committed: true,
      );
      await OnboardingDraftPersistence.save(draft, now: now);

      final back = (await OnboardingDraftPersistence.load(now: now))!;
      expect(back.savedAt, now);
      expect(back.state.step, ObStep.pace);
      expect(back.state.email, 'someone@example.com');
      expect(back.state.gender, Gender.nonBinary);
      expect(back.state.birthYearInput, '1994');
      expect(back.state.attempts, QuitAttempts.moreThanFive);
      expect(back.state.frequency, VapeFrequency.often);
      expect(back.state.puffsInput, '175');
      expect(back.state.strength, NicStrength.mg20);
      expect(back.state.spendInput, '33');
      expect(back.state.firstPuff, FirstPuffWindow.hourPlus);
      expect(back.state.whys, {WhyChip.money, WhyChip.family});
      expect(back.state.worries, {WorryChip.stress, WorryChip.weight});
      expect(back.state.method, QuitMethod.coldTurkey);
      expect(back.state.paceDays, 90);
      expect(back.state.committed, isTrue);
      // Never encoded: it describes a draft on disk, not the draft itself.
      expect(back.state.resumable, isNull);
    });

    test('an unknown enum falls back instead of throwing', () async {
      SharedPreferences.setMockInitialValues({
        key: jsonEncode({
          'v': OnboardingDraftPersistence.schemaVersion,
          'savedAt': now.toIso8601String(),
          'step': 'spend',
          'gender': 'martian',
          'whys': ['health', 'telepathy'],
          'method': 'astral',
        }),
      });
      final back = (await OnboardingDraftPersistence.load(now: now))!;
      expect(back.state.gender, isNull);
      expect(back.state.whys, {WhyChip.health});
      expect(back.state.method, QuitMethod.taper);
    });

    test('garbage on disk reads as no draft at all', () async {
      SharedPreferences.setMockInitialValues({key: 'not json {{{'});
      expect(await OnboardingDraftPersistence.load(now: now), isNull);
    });

    test('a draft from another schema is dropped, not just ignored', () async {
      SharedPreferences.setMockInitialValues({
        key: jsonEncode({'v': 999, 'savedAt': now.toIso8601String()}),
      });
      expect(await OnboardingDraftPersistence.load(now: now), isNull);
      expect(
        (await SharedPreferences.getInstance()).getString(key),
        isNull,
        reason: 'a stale shape must not linger',
      );
    });

    test('a stale draft does not resume, but yesterday\'s does', () async {
      const state = OnboardingState(puffsInput: '200');
      await OnboardingDraftPersistence.save(state, now: now);

      // `puffsInput` is the baseline the whole taper curve divides through, so
      // an old one produces a plan that misrepresents the user permanently.
      expect(
        await OnboardingDraftPersistence.load(
          now: now.add(const Duration(days: 8)),
        ),
        isNull,
      );

      await OnboardingDraftPersistence.save(state, now: now);
      expect(
        await OnboardingDraftPersistence.load(
          now: now.add(const Duration(days: 1)),
        ),
        isNotNull,
      );
    });

    test('exactly at the TTL it still resumes', () async {
      await OnboardingDraftPersistence.save(
        const OnboardingState(),
        now: now,
      );
      expect(
        await OnboardingDraftPersistence.load(
          now: now.add(OnboardingDraftPersistence.ttl),
        ),
        isNotNull,
      );
    });

    test('an age-gated draft never resumes, however it got there', () async {
      // docs/02 §3 A3: "No data stored." The read side refuses independently
      // of the write side, because an in-flight write racing process death is
      // not a compliance argument.
      for (final gated in [
        const OnboardingState(step: ObStep.under18),
        OnboardingState(birthYearInput: '${now.year - 15}'),
        const OnboardingState(birthYearInput: '15'),
      ]) {
        SharedPreferences.setMockInitialValues({});
        await OnboardingDraftPersistence.save(gated, now: now);
        expect(
          await OnboardingDraftPersistence.load(now: now),
          isNull,
          reason: '${gated.step} / ${gated.birthYearInput}',
        );
      }
    });

    test('clearing an empty store is a no-op', () async {
      await OnboardingDraftPersistence.clear();
      expect(await OnboardingDraftPersistence.load(now: now), isNull);
    });
  });

  group('the view model', () {
    test('every mutator persists, including ones nobody wired up', () async {
      // Passes only because the `state` setter is the choke point. This is the
      // guard for the twentieth mutator somebody adds later.
      final c = container();
      filled(c);

      final back = (await OnboardingDraftPersistence.load(now: now))!;
      expect(back.state.step, ObStep.spend);
      expect(back.state.gender, Gender.woman);
      expect(back.state.birthYearInput, '1998');
      expect(back.state.puffsInput, '200');
      expect(back.state.spendInput, '45');
      expect(back.state.whys, {WhyChip.health, WhyChip.fitness});
      expect(back.state.paceDays, 60);
      expect(back.state.email, 'maya@quitmail.com');
    });

    test('a killed session comes back as an offer, not a jump', () async {
      filled(container());

      final revived = container();
      // The read is what runs build(), and build() fires _hydrate() without
      // awaiting it — disk answers a few turns of the event loop later.
      revived.read(onboardingProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final offered = revived.read(onboardingProvider);
      expect(offered.step, ObStep.welcome, reason: 'must not teleport');
      expect(offered.resumable, isNotNull);
      expect(offered.resumable!.answered, 12);
      expect(offered.resumable!.total, 12);

      revived.read(onboardingProvider.notifier).resumeDraft();
      final resumed = revived.read(onboardingProvider);
      expect(resumed.step, ObStep.spend);
      expect(resumed.puffsInput, '200');
      expect(resumed.gender, Gender.woman);
    });

    test('start fresh wipes the draft off disk', () async {
      filled(container());

      final revived = container();
      revived.read(onboardingProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      revived.read(onboardingProvider.notifier).discardDraft();

      expect(revived.read(onboardingProvider).step, ObStep.welcome);
      expect(revived.read(onboardingProvider).resumable, isNull);
      expect(await OnboardingDraftPersistence.load(now: now), isNull);
    });

    test('a user who starts answering beats a draft landing late', () async {
      filled(container());

      final revived = container();
      // Answering before disk has answered — their action must win.
      revived.read(onboardingProvider.notifier).selectGender(Gender.man);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final state = revived.read(onboardingProvider);
      expect(state.resumable, isNull, reason: 'no card over live answers');
      expect(state.gender, Gender.man);
      expect(state.step, ObStep.welcome);
    });

    test('the Frame Map never writes a draft', () async {
      final c = container(restore: false);
      final vm = c.read(onboardingProvider.notifier)
        ..previewStep(ObStep.reveal);
      // And nothing after the jump leaks either — suppression is sticky.
      vm.selectPace(21);

      expect(await OnboardingDraftPersistence.load(now: now), isNull);
    });

    test('the age gate erases the draft and it stays erased', () async {
      // The easily-missed half: the `state = copyWith(step: under18)` right
      // after the erase runs through the persisting setter, and without
      // suppression would immediately write it back.
      final c = container();
      final vm = c.read(onboardingProvider.notifier);
      vm.state = vm.state.copyWith(step: ObStep.birthYear);
      for (final ch in '${now.year - 15}'.split('')) {
        vm.typeBirthDigit(int.parse(ch));
      }
      vm.next();

      expect(c.read(onboardingProvider).step, ObStep.under18);
      expect(await OnboardingDraftPersistence.load(now: now), isNull);
      expect(
        (await SharedPreferences.getInstance()).getString(key),
        isNull,
        reason: 'the under-18 mutation rewrote the draft we just erased',
      );
    });

    test('a failed startJourney leaves the draft on disk to retry', () async {
      // The paywall's retry contract: the throw happens before the clear, so
      // nothing is lost in memory or on disk.
      final c = ProviderContainer(
        overrides: [
          ...fastBackendOverrides(online: false, now: now),
          onboardingProvider.overrideWith(OnboardingViewModel.new),
        ],
      );
      addTearDown(c.dispose);
      filled(c);

      await expectLater(
        c.read(onboardingProvider.notifier).completeWithTier(
          SubscriptionTier.free,
        ),
        throwsA(anything),
      );

      expect(c.read(onboardingProvider).puffsInput, '200');
      expect(await OnboardingDraftPersistence.load(now: now), isNotNull);
    });

    test('a completed funnel clears the draft', () async {
      final c = container();
      filled(c);
      await c
          .read(onboardingProvider.notifier)
          .completeWithTier(SubscriptionTier.free);

      expect(await OnboardingDraftPersistence.load(now: now), isNull);
    });
  });
}
