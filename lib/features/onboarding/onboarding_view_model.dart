import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/stores/providers.dart';
import '../../domain/models/models.dart';

/// Ordered steps of the first-session flow (docs/02 §2).
enum ObStep {
  welcome,
  gender,
  birthYear,
  under18,
  tried,
  frequency,
  puffs,
  strength,
  spend,
  firstPuff,
  why,
  worries,
  method,
  pace,
  building,
  reveal,
  commit,
  rating,
  notifications,
}

/// Quiz questions counted by the progress bar (1/12 … 12/12).
const _progressSteps = [
  ObStep.gender,
  ObStep.birthYear,
  ObStep.tried,
  ObStep.frequency,
  ObStep.puffs,
  ObStep.strength,
  ObStep.spend,
  ObStep.firstPuff,
  ObStep.why,
  ObStep.worries,
  ObStep.method,
  ObStep.pace,
];

class OnboardingState {
  const OnboardingState({
    this.step = ObStep.welcome,
    this.email,
    this.gender,
    this.birthYearInput = '',
    this.attempts,
    this.frequency,
    this.puffsInput = '',
    this.strength,
    this.spendInput = '',
    this.firstPuff,
    this.whys = const {},
    this.worries = const {},
    this.method = QuitMethod.taper,
    this.paceDays = 30,
    this.committed = false,
  });

  final ObStep step;
  final String? email;
  final Gender? gender;
  final String birthYearInput;
  final QuitAttempts? attempts;
  final VapeFrequency? frequency;
  final String puffsInput;
  final NicStrength? strength;
  final String spendInput;
  final FirstPuffWindow? firstPuff;
  final Set<WhyChip> whys;
  final Set<WorryChip> worries;
  final QuitMethod method;
  final int paceDays;
  final bool committed;

  int? get birthYear =>
      birthYearInput.length == 4 ? int.tryParse(birthYearInput) : null;

  int get puffsPerDay => int.tryParse(puffsInput) ?? 0;

  double get weeklySpend => double.tryParse(spendInput) ?? 0;

  double get yearlySpend => weeklySpend * 52;

  DependenceLevel get dependence => DependenceLevel.forPuffs(puffsPerDay);

  /// Progress bar position, or null on non-quiz steps.
  (int, int)? get progress {
    final i = _progressSteps.indexOf(step);
    return i == -1 ? null : (i + 1, _progressSteps.length);
  }

  bool get canContinue => switch (step) {
    ObStep.gender => gender != null,
    ObStep.birthYear => birthYear != null,
    ObStep.tried => attempts != null,
    ObStep.frequency => frequency != null,
    ObStep.puffs => puffsPerDay > 0,
    ObStep.strength => strength != null,
    ObStep.spend => weeklySpend > 0,
    ObStep.firstPuff => firstPuff != null,
    ObStep.why => whys.isNotEmpty,
    ObStep.worries => worries.isNotEmpty,
    _ => true,
  };

  OnboardingState copyWith({
    ObStep? step,
    String? email,
    Gender? gender,
    String? birthYearInput,
    QuitAttempts? attempts,
    VapeFrequency? frequency,
    String? puffsInput,
    NicStrength? strength,
    String? spendInput,
    FirstPuffWindow? firstPuff,
    Set<WhyChip>? whys,
    Set<WorryChip>? worries,
    QuitMethod? method,
    int? paceDays,
    bool? committed,
  }) => OnboardingState(
    step: step ?? this.step,
    email: email ?? this.email,
    gender: gender ?? this.gender,
    birthYearInput: birthYearInput ?? this.birthYearInput,
    attempts: attempts ?? this.attempts,
    frequency: frequency ?? this.frequency,
    puffsInput: puffsInput ?? this.puffsInput,
    strength: strength ?? this.strength,
    spendInput: spendInput ?? this.spendInput,
    firstPuff: firstPuff ?? this.firstPuff,
    whys: whys ?? this.whys,
    worries: worries ?? this.worries,
    method: method ?? this.method,
    paceDays: paceDays ?? this.paceDays,
    committed: committed ?? this.committed,
  );
}

class OnboardingViewModel extends Notifier<OnboardingState> {
  static const int minAge = 18;

  @override
  OnboardingState build() => const OnboardingState();

  void setEmail(String email) => state = state.copyWith(email: email);

  void selectGender(Gender g) => state = state.copyWith(gender: g);

  void typeBirthDigit(int d) {
    if (state.birthYearInput.length >= 4) return;
    state = state.copyWith(birthYearInput: state.birthYearInput + d.toString());
  }

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

  void markCommitted() => state = state.copyWith(committed: true);

  /// Frame-map preview: seed the draft with the demo answers every design
  /// frame depicts (200/day, $25/wk, 30-day taper) and jump straight to [step].
  void previewStep(ObStep step) {
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

  void next() {
    final order = ObStep.values;
    var i = order.indexOf(state.step) + 1;
    // Age gate: under-18 goes to the resource screen, everyone else skips it.
    if (state.step == ObStep.birthYear) {
      final age = DateTime.now().year - (state.birthYear ?? 0);
      state = state.copyWith(
        step: age < minAge ? ObStep.under18 : ObStep.tried,
      );
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
    );
    final plan = draftPlan();
    await ref
        .read(quitStoreProvider.notifier)
        .startJourney(profile: profile, plan: plan);
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
