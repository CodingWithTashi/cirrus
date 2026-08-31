import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/lp_review.dart';
import '../../data/stores/onboarding_draft_persistence.dart';
import '../../data/stores/providers.dart';
import '../../domain/analytics/lp_events.dart';
import '../../domain/logic/coach_name.dart';
import '../../domain/logic/why_words.dart';
import '../../domain/models/models.dart';
import '../../domain/models/onboarding_draft.dart';

/// Re-exported so the ten files importing this one keep their imports.
export '../../domain/models/onboarding_draft.dart';

class OnboardingViewModel extends Notifier<OnboardingState> {
  /// Restore is skipped when false — tests want deterministic defaults, not
  /// whatever the host machine's preferences last held. Mirrors
  /// `SettingsStore({bool restore})`.
  OnboardingViewModel({bool restore = true}) : _restore = restore;

  static const int minAge = 18;

  final bool _restore;

  /// The user has touched the funnel, so a draft landing late from disk must
  /// not overwrite what they are doing. Same role as `SettingsStore._dirty`.
  bool _touched = false;

  /// Set while writing state that must not be persisted — the Frame Map's
  /// preview seeding, restoring a draft (which would re-stamp `savedAt` and
  /// silently renew the TTL of something the user never touched), and the
  /// age-gate erasure.
  bool _persistSuppressed = false;

  /// A draft read from disk, held until the user accepts or rejects it.
  OnboardingDraft? _pending;

  /// Riverpod 2's `Ref` has no `mounted`, and both of the async warm-ups here
  /// outlive a fast user: a draft read and a testimonial fetch can both land
  /// after the notifier is gone (`completeWithTier` invalidates it), and
  /// writing state then throws.
  bool _disposed = false;

  @override
  OnboardingState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    if (_restore) _hydrate();
    // Returned directly rather than through the setter, so constructing this
    // notifier never writes anything.
    return const OnboardingState();
  }

  /// Every mutation funnels through here — including a bare `state = ...` in
  /// some future mutator nobody remembered to wire up. That is the entire
  /// point of overriding it rather than calling save from each of the twenty
  /// commands below.
  @override
  set state(OnboardingState next) {
    super.state = next;
    _touched = true;
    if (_persistSuppressed) return;
    OnboardingDraftPersistence.save(
      next,
      now: ref.read(nowProvider)(),
    ).ignore();
  }

  Future<void> _hydrate() async {
    final draft = await OnboardingDraftPersistence.load(
      now: ref.read(nowProvider)(),
    );
    if (_disposed || draft == null) return;
    // They started answering while disk was working. Their action wins.
    if (_touched || state.step != ObStep.welcome) return;
    _pending = draft;
    _persistSuppressed = true;
    super.state = state.copyWith(
      resumable: (
        savedAt: draft.savedAt,
        answered: draft.state.answeredCount,
        total: 12,
      ),
    );
    _persistSuppressed = false;
  }

  /// Adopts the draft the resume card is offering.
  void resumeDraft() {
    final draft = _pending;
    if (draft == null) return;
    _pending = null;
    // Restart the dwell clock, or the first `screen_completed` after a resume
    // reports however long the app was closed.
    _stepEnteredAt = ref.read(nowProvider)();
    // `onboardingStart` deliberately does not re-fire: it fired on the first
    // run, and the funnel's denominator must not count one person twice.
    _persistSuppressed = true;
    super.state = draft.state;
    _persistSuppressed = false;
  }

  /// "Start fresh" — the only way to clear a draft without finishing the
  /// funnel, which is half of why the card is explicit rather than automatic.
  void discardDraft() {
    _pending = null;
    OnboardingDraftPersistence.clear().ignore();
    _persistSuppressed = true;
    super.state = const OnboardingState();
    _persistSuppressed = false;
  }

  void setEmail(String email) => state = state.copyWith(email: email);

  void selectGender(Gender g) => state = state.copyWith(gender: g);

  void typeBirthDigit(int d) {
    if (state.birthYearInput.length >= 4) return;
    state = state.copyWith(birthYearInput: state.birthYearInput + d.toString());
  }

  /// Takes the offered age→year substitution ("28" → "1998"). The odometer
  /// replays, so the user watches us understand them.
  void adoptAgeEntry() {
    final entry = state.birthEntry;
    final year = entry.year;
    if (year == null) return;
    if (entry.kind != BirthEntryKind.ageOffer &&
        entry.kind != BirthEntryKind.ageOnly) {
      return;
    }
    ref.read(analyticsProvider).ageEntryAdopted();
    state = state.copyWith(birthYearInput: year.toString());
  }

  /// "Let me fix that" — the way back out of the under-18 confirmation, so a
  /// mistyped digit never costs someone the app.
  void clearBirthYear() => state = state.copyWith(birthYearInput: '');

  void backspaceBirth() {
    final s = state.birthYearInput;
    if (s.isEmpty) return;
    state = state.copyWith(birthYearInput: s.substring(0, s.length - 1));
  }

  void selectAttempts(QuitAttempts a) => state = state.copyWith(attempts: a);

  void selectFrequency(VapeFrequency f) => state = state.copyWith(frequency: f);

  void typePuffDigit(int d) {
    if (state.puffsInput.length >= 4) return;
    state = state.copyWith(puffsInput: state.puffsInput + d.toString());
  }

  void backspacePuffs() {
    final s = state.puffsInput;
    if (s.isEmpty) return;
    state = state.copyWith(puffsInput: s.substring(0, s.length - 1));
  }

  void setPuffsEstimate(int puffs) =>
      state = state.copyWith(puffsInput: puffs.toString());

  void selectStrength(NicStrength s) => state = state.copyWith(strength: s);

  void typeSpendDigit(int d) {
    if (state.spendInput.length >= 4) return;
    state = state.copyWith(spendInput: state.spendInput + d.toString());
  }

  void backspaceSpend() {
    final s = state.spendInput;
    if (s.isEmpty) return;
    state = state.copyWith(spendInput: s.substring(0, s.length - 1));
  }

  void toggleWhy(WhyChip chip) {
    final whys = {...state.whys};
    whys.contains(chip) ? whys.remove(chip) : whys.add(chip);
    state = state.copyWith(whys: whys);
  }

  void toggleWorry(WorryChip chip) {
    final worries = {...state.worries};
    worries.contains(chip) ? worries.remove(chip) : worries.add(chip);
    state = state.copyWith(worries: worries);
  }

  void selectFirstPuff(FirstPuffWindow w) =>
      state = state.copyWith(firstPuff: w);

  void selectMethod(QuitMethod m) => state = state.copyWith(method: m);

  void selectPace(int days) => state = state.copyWith(paceDays: days);

  /// The coach's new name, or null when they kept the default.
  ///
  /// Null rather than the literal word: the default is an ARB string, so
  /// nothing here hardcodes a brand name and an untouched profile stays
  /// indistinguishable from every existing one.
  String? get chosenCoachName {
    final name = CoachName.normalize(state.coachNameInput);
    return name.isEmpty ? null : name;
  }

  void typeCoachName(String raw) =>
      state = state.copyWith(coachNameInput: raw);

  /// Why they are doing this, in their own words, or null when they skipped.
  ///
  /// Null rather than an empty string for the same reason [chosenCoachName]
  /// is: the two mean different things, and an empty string would print a
  /// blank line into Ember's user card as though something had been said.
  String? get chosenWhyWords => WhyWords.stored(state.whyWordsInput);

  void typeWhyWords(String raw) =>
      state = state.copyWith(whyWordsInput: raw);

  void markCommitted() {
    // The hold gesture itself, not the screen advance — someone can complete
    // the commit screen without ever holding, and the two are different
    // numbers (docs/02 §7).
    ref.read(analyticsProvider).commitHeld();
    state = state.copyWith(committed: true);
  }

  /// Frame-map preview: seed the draft with the demo answers every design
  /// frame depicts (200/day, $25/wk, 30-day taper) and jump straight to [step].
  void previewStep(ObStep step) {
    // Sticky for the life of this notifier, not scoped to the assignment: a
    // session that has jumped into a Frame Map frame is a design session, not
    // a funnel, and every tap after this one would otherwise be written out as
    // if it were somebody's real answers.
    _persistSuppressed = true;
    state = OnboardingState(
      step: step,
      gender: Gender.woman,
      birthYearInput: '2003',
      attempts: QuitAttempts.twoToFive,
      frequency: VapeFrequency.always,
      puffsInput: '200',
      strength: NicStrength.mg50,
      spendInput: '25',
      firstPuff: FirstPuffWindow.withinFive,
      whys: const {WhyChip.health, WhyChip.money, WhyChip.fitness},
      worries: const {WorryChip.cravings, WorryChip.stress, WorryChip.failing},
    );
  }

  // ---- navigation -----------------------------------------------------------

  /// When the current screen was reached, for the dwell time in
  /// `screen_completed`. Set on every advance so the funnel alert in
  /// docs/02 §7 (>15% drop-off on any screen) has something to alert on.
  DateTime _stepEnteredAt = DateTime.now();

  /// Emits `screen_completed` for the screen being left, plus that screen's
  /// own docs/02 §7 event, and restarts the clock.
  ///
  /// Central on purpose: 19 widgets each remembering to log is 19 chances to
  /// miss one, and a hole in the funnel looks like a healthy step. The switch
  /// is exhaustive over the steps that carry an answer worth reporting —
  /// adding a step therefore forces a decision here rather than silently
  /// shipping an unmeasured screen.
  void _completeStep() {
    final step = state.step;
    final analytics = ref.read(analyticsProvider);
    analytics.screenCompleted(
      step.name,
      DateTime.now().difference(_stepEnteredAt).inMilliseconds,
    );
    switch (step) {
      // The funnel's denominator. Fired on leaving welcome rather than on
      // mount so the Frame Map's `previewStep` jumps — which never pass
      // through welcome — cannot inflate it.
      case ObStep.welcome:
        analytics.onboardingStart();
      case ObStep.puffs:
        analytics.puffsEntered(state.puffsPerDay, state.dependence.name);
      case ObStep.spend:
        analytics.spendEntered(
          state.weeklySpend.round(),
          state.yearlySpend.round(),
        );
      case ObStep.method:
        analytics.methodChosen(state.method.name);
      case ObStep.pace:
        analytics.paceChosen(state.paceDays);
      case ObStep.reveal:
        analytics.planRevealed();
      // `commit_held` rides the hold gesture (markCommitted) and `notif_prompt`
      // needs the OS answer, so both fire from where that fact exists.
      case ObStep.gender:
      case ObStep.birthYear:
      case ObStep.under18:
      case ObStep.tried:
      case ObStep.frequency:
      case ObStep.strength:
      case ObStep.firstPuff:
      // Leaving the worries screen is the first moment every tag exists, and
      // it is four screens before D3 — so the tailored quotes almost always
      // land while the user is somewhere else, and the card never blinks.
      case ObStep.worries:
        _prefetchRatingStep();
      case ObStep.why:
      case ObStep.building:
      case ObStep.coachName:
      case ObStep.whyWords:
      case ObStep.commit:
      case ObStep.rating:
      case ObStep.notifications:
        break;
    }
    _stepEnteredAt = DateTime.now();
  }

  /// Warms D3: the tailored quotes, and whether the OS will show its sheet.
  ///
  /// Both are best-effort and both fail to the same place — bundled quotes and
  /// a hidden CTA — so neither is awaited and neither can block the funnel.
  Future<void> _prefetchRatingStep() async {
    final answers = state;
    final available = await LpReview.isAvailable();
    var quotes = const <Testimonial>[];
    try {
      quotes = await ref
          .read(testimonialsRepositoryProvider)
          .matched(
            whys: answers.whys,
            worries: answers.worries,
            attempts: answers.attempts,
            gender: answers.gender,
            dependence: answers.dependence,
          );
    } on Object {
      // Offline, or a backend that refused. The bundled quotes are honest and
      // already on screen, so there is nothing to report and nothing to retry.
      quotes = const [];
    }
    if (_disposed) return;
    // All-or-nothing: one tailored quote beside one generic one reads as a
    // bug rather than as social proof.
    _persistSuppressed = true;
    super.state = state.copyWith(
      testimonials: quotes.length >= 2 ? quotes : const [],
      reviewAvailable: available,
    );
    _persistSuppressed = false;
  }

  void next() {
    // Nothing advances on an unanswered step. Belt-and-braces with the
    // disabled CTA: `birthYear` is null for a future or impossible entry, so
    // this is also the second of the two locks on the age gate.
    if (!state.canContinue) return;
    _completeStep();
    final order = ObStep.values;
    var i = order.indexOf(state.step) + 1;
    // Age gate: under-18 goes to the resource screen, everyone else skips it.
    if (state.step == ObStep.birthYear) {
      // Keyed off the engine's classification, never off subtraction. The old
      // `now.year - birthYear < minAge` sent 2812 (age -786) to the resource
      // screen, and that screen's only exit is closing the app.
      final blocked = state.birthEntry.kind == BirthEntryKind.underAge;
      if (blocked) {
        ref.read(analyticsProvider).ageGateBlocked();
        // docs/02 §3 A3: "No data stored." This is the only moment we learn
        // the draft must not exist. Suppression is NOT optional — the
        // `state = ...` two lines down runs through the persisting setter and
        // would immediately rewrite what we just erased.
        _persistSuppressed = true;
        OnboardingDraftPersistence.clear().ignore();
      }
      state = state.copyWith(step: blocked ? ObStep.under18 : ObStep.tried);
      return;
    }
    if (i < order.length) state = state.copyWith(step: order[i]);
  }

  /// Returns false when already at the first step (caller pops the route).
  bool back() {
    final order = ObStep.values;
    var i = order.indexOf(state.step) - 1;
    if (state.step == ObStep.tried) i = order.indexOf(ObStep.birthYear);
    if (i < 0) return false;
    state = state.copyWith(step: order[i]);
    return true;
  }

  /// The taper plan implied by the current answers (for reveal/pace preview).
  QuitPlan draftPlan() {
    final now = DateTime.now();
    return QuitPlan(
      method: state.method,
      paceDays: state.paceDays,
      startDate: DateTime(now.year, now.month, now.day),
      baselinePuffsPerDay: state.puffsPerDay,
      weeklySpend: state.weeklySpend,
      strength: state.strength ?? NicStrength.notSure,
    );
  }

  /// Ends onboarding: the backend creates the journey with [tier], then the
  /// draft clears. Profile and plan are captured BEFORE the await — nothing
  /// may touch `state`/`ref` after [Ref.invalidateSelf], which must stay the
  /// final statement.
  Future<void> completeWithTier(SubscriptionTier tier) async {
    final (alias, emoji) = _randomAlias();
    final profile = UserProfile(
      alias: alias,
      avatarEmoji: emoji,
      tier: tier,
      email: state.email,
      gender: state.gender,
      birthYear: state.birthYear,
      whys: state.whys,
      worries: state.worries,
      attempts: state.attempts,
      frequency: state.frequency,
      firstPuff: state.firstPuff,
      coachName: chosenCoachName,
      whyWords: chosenWhyWords,
    );
    final plan = draftPlan();
    await ref
        .read(quitStoreProvider.notifier)
        .startJourney(profile: profile, plan: plan);
    // Ember's first memory, from the one thing they wrote in their own words.
    // After `startJourney` because the server reads the sentence out of the
    // journey document this just created — and fire-and-forget because a
    // model outage must cost a remembered sentence, never the last screen of
    // onboarding. `ref` is safe here: `invalidateSelf` has not run yet.
    ref.read(coachRepositoryProvider).seedMemories().ignore();
    // The server has it now, so the local copy is the thing that must not
    // outlive it. Awaited, unlike every other write-behind here: `clear()` is
    // total and never throws, so awaiting adds no failure mode, and it closes
    // the race where `invalidateSelf` rebuilds this notifier and `_hydrate`
    // reads the draft mid-delete.
    //
    // Placed AFTER the await on purpose: if `startJourney` throws, neither
    // this nor the invalidation runs, so the draft survives in memory and on
    // disk and the paywall's retry path still has something to retry with.
    await OnboardingDraftPersistence.clear();
    ref.invalidateSelf();
  }

  static (String, String) _randomAlias() {
    const adjectives = [
      'quiet',
      'swift',
      'steady',
      'brave',
      'lunar',
      'ember',
      'wild',
      'calm',
    ];
    const animals = [
      ('fox', '🦊'),
      ('otter', '🦦'),
      ('falcon', '🦅'),
      ('wolf', '🐺'),
      ('turtle', '🐢'),
      ('bee', '🐝'),
      ('owl', '🦉'),
      ('moth', '🦋'),
    ];
    final r = Random();
    final (animal, emoji) = animals[r.nextInt(animals.length)];
    final n = r.nextInt(90) + 9;
    return ('@${adjectives[r.nextInt(adjectives.length)]}$animal$n', emoji);
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingViewModel, OnboardingState>(
      OnboardingViewModel.new,
    );
