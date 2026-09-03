/// The onboarding draft: the ordered steps, and every answer given so far.
///
/// Pure Dart, and in `domain/` rather than beside the view model for one
/// concrete reason: `OnboardingDraftPersistence` lives in `data/stores/` with
/// the app's other two preference files, and nothing in `data/` or `domain/`
/// may import `features/`. The view model re-exports this file, so every
/// existing import of `onboarding_view_model.dart` keeps working untouched.
library;

import '../logic/age_entry_engine.dart';
import 'models.dart';

export '../logic/age_entry_engine.dart' show BirthEntry, BirthEntryKind;

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
  coachName,
  whyWords,
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

/// A draft waiting to be resumed: when it was written, and how far it got.
typedef ResumableDraft = ({DateTime savedAt, int answered, int total});

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
    this.coachNameInput = '',
    this.whyWordsInput = '',
    this.committed = false,
    this.resumable,
    this.testimonials = const [],
    this.reviewAvailable = false,
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

  /// What they typed on the "name your coach" screen. Empty means they kept
  /// the default, which stays null on the profile rather than becoming the
  /// literal word — see [UserProfile.coachName].
  final String coachNameInput;

  /// Why they are doing this, in their own words — the one free-text answer
  /// in the funnel, and the only one that can seed Ember's vector memory.
  /// Empty means they skipped, which is a valid answer.
  final String whyWordsInput;

  final bool committed;

  /// A draft found on disk that is waiting for the user's yes or no.
  ///
  /// TRANSIENT — never encoded. It describes the draft on disk, not this
  /// state, which is why it carries the draft's own answer count.
  final ResumableDraft? resumable;

  /// Tailored quotes for D3, fetched four screens early so the swap lands
  /// off-screen. TRANSIENT — never encoded; empty means "use the bundled two".
  final List<Testimonial> testimonials;

  /// Whether the OS will actually show its review sheet. TRANSIENT.
  ///
  /// False on desktop, in tests, and on any sideloaded Android build, so the
  /// CTA is hidden rather than shipped as a button that does nothing.
  final bool reviewAvailable;

  /// How many of the twelve quiz questions carry an answer. Drives the
  /// "you were 8 of 12 in" line on the resume card.
  int get answeredCount => _progressSteps
      .where((step) => copyWith(step: step).canContinue)
      .length;

  /// How the keypad buffer reads right now — a year, an age, a typo, or
  /// nothing yet. The screen's caption and its CTA both switch on this.
  ///
  /// Reads the wall-clock year on every rebuild, which is also what keeps the
  /// resolved age correct if the year ticks over while the app is open. The
  /// engine itself takes `currentYear` as a parameter and is tested that way.
  BirthEntry get birthEntry =>
      AgeEntryEngine.interpret(birthYearInput, currentYear: DateTime.now().year);

  /// The resolved birth year, or null when the buffer does not name one.
  /// A future year resolves to null, which is what keeps a typo out of the
  /// under-18 gate.
  int? get birthYear => birthEntry.year;

  /// Whether the buffer is an answer we are willing to act on.
  ///
  /// Deliberately narrower than `birthYear != null`: an [BirthEntryKind.ageOffer]
  /// like "19" resolves a year, but it is also the first half of 1998, so
  /// advancing on it would silently record a birth year the user never meant.
  /// They confirm with "That's me" or keep typing.
  bool get birthAnswered => switch (birthEntry.kind) {
    BirthEntryKind.year ||
    BirthEntryKind.ageOnly ||
    BirthEntryKind.underAge => true,
    _ => false,
  };

  int get puffsPerDay => int.tryParse(puffsInput) ?? 0;

  double get weeklySpend => double.tryParse(spendInput) ?? 0;

  double get yearlySpend => weeklySpend * 52;

  DependenceLevel get dependence => DependenceLevel.forPuffs(puffsPerDay);

  /// Progress bar position, or null on non-quiz steps.
  (int, int)? get progress {
    final i = _progressSteps.indexOf(step);
    return i == -1 ? null : (i + 1, _progressSteps.length);
  }

  /// Whether this step offers a way to the previous one.
  ///
  /// iOS has no system back: no hardware key, and no edge swipe either, since
  /// the whole funnel is one route whose steps swap in place. On an iPhone the
  /// on-screen chevron IS back, so it has to exist on every step that has a
  /// previous one — not only on the twelve that carry a progress bar, which is
  /// what left the Phase D screens (reveal, coach name, why-words, commit,
  /// rating, notifications) forward-only on every iPhone.
  ///
  /// The three exceptions each have a reason: welcome is the entry (leaving it
  /// means leaving the funnel, which is the sign-in screen's business),
  /// under-18 carries its own "let me fix that", and building is an animation
  /// that advances itself — a back pressed under it would be undone a second
  /// later.
  bool get canGoBack => switch (step) {
    ObStep.welcome || ObStep.under18 || ObStep.building => false,
    _ => true,
  };

  bool get canContinue => switch (step) {
    ObStep.gender => gender != null,
    ObStep.birthYear => birthAnswered,
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
    String? coachNameInput,
    String? whyWordsInput,
    bool? committed,
    ResumableDraft? resumable,
    bool clearResumable = false,
    List<Testimonial>? testimonials,
    bool? reviewAvailable,
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
    coachNameInput: coachNameInput ?? this.coachNameInput,
    whyWordsInput: whyWordsInput ?? this.whyWordsInput,
    committed: committed ?? this.committed,
    resumable: clearResumable ? null : (resumable ?? this.resumable),
    testimonials: testimonials ?? this.testimonials,
    reviewAvailable: reviewAvailable ?? this.reviewAvailable,
  );
}
