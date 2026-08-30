/// Interprets the birth-year keypad buffer. Pure Dart — no Flutter imports.
///
/// The screen asks for a year and a great many people type their age. Before
/// this existed, "28" simply left Continue grey with nothing on screen to say
/// why, and a four-digit typo like "2812" computed an age of −786, which is
/// less than 18, so it routed the user into the under-18 resource screen —
/// whose only exit is closing the app. This classifies the buffer instead, so
/// every state has an answer and the legal gate keys off a real under-18
/// answer rather than off arithmetic that can go negative.
library;

enum BirthEntryKind {
  /// Nothing typed yet.
  empty,

  /// A valid prefix of some year in range, not resolvable yet.
  typing,

  /// Reads as an age, but could still become a year ("19" → 1998?). Offered,
  /// never adopted — we only assert when we cannot be wrong.
  ageOffer,

  /// Reads as an age and cannot become any year in range ("28").
  ageOnly,

  /// Four digits resolving to an adult.
  year,

  /// A genuine under-18 answer, from either a year or an unambiguous age.
  underAge,

  /// A year that has not happened yet.
  future,

  /// Older than any verified human.
  tooOld,

  /// Neither a year prefix nor a plausible age.
  impossible,
}

class BirthEntry {
  const BirthEntry(this.kind, {this.year, this.age});

  final BirthEntryKind kind;

  /// The resolved birth year, or null when the buffer does not yet name one.
  /// `canContinue` reads exactly this, so a state with no year cannot advance.
  final int? year;

  /// Age in whole years at [year], for the copy and for the gate.
  final int? age;
}

abstract final class AgeEntryEngine {
  /// docs/02 §1.6 — the App Store gate and the ethical one.
  static const int minAge = 18;

  /// The oldest verified human lifespan (Jeanne Calment, 122). A birth year
  /// implying more than this is a typo, not a user.
  static const int maxAge = 122;

  /// Below this a two-digit entry reads as a slip rather than an age. Set low
  /// on purpose: an under-18 answer belongs at the resource screen, and that
  /// screen is confirm-gated, so erring toward the gate costs a mistyping
  /// adult one tap while erring away from it fails someone we are legally and
  /// ethically required to redirect.
  static const int minPlausibleAge = 10;

  static BirthEntry interpret(String digits, {required int currentYear}) {
    if (digits.isEmpty) return const BirthEntry(BirthEntryKind.empty);
    final n = int.tryParse(digits);
    if (n == null) return const BirthEntry(BirthEntryKind.impossible);

    if (digits.length >= 4) {
      if (n > currentYear) return const BirthEntry(BirthEntryKind.future);
      final age = currentYear - n;
      if (age > maxAge) return const BirthEntry(BirthEntryKind.tooOld);
      return BirthEntry(
        age < minAge ? BirthEntryKind.underAge : BirthEntryKind.year,
        year: n,
        age: age,
      );
    }

    final couldPrefixYear = _couldPrefixYear(digits, currentYear);
    final readsAsAge =
        digits.length >= 2 && n >= minPlausibleAge && n <= maxAge;

    if (!readsAsAge) {
      return couldPrefixYear
          ? const BirthEntry(BirthEntryKind.typing)
          : const BirthEntry(BirthEntryKind.impossible);
    }

    final year = currentYear - n;
    // Ambiguous: "19" is an age AND the first half of 1998. Offer the
    // substitution, never adopt it — the two commonest birth decades in this
    // audience both start with digits that are also plausible ages.
    if (couldPrefixYear) {
      return BirthEntry(BirthEntryKind.ageOffer, year: year, age: n);
    }
    // Unambiguously an age. An under-18 one routes to the gate exactly as a
    // four-digit under-18 year does — the gate must not be dodgeable by
    // answering in a different unit.
    return BirthEntry(
      n < minAge ? BirthEntryKind.underAge : BirthEntryKind.ageOnly,
      year: year,
      age: n,
    );
  }

  /// Whether [digits] could still grow into a year someone alive could be born
  /// in. 123 iterations, and obviously correct at a glance — which matters
  /// more here than being clever.
  static bool _couldPrefixYear(String digits, int currentYear) {
    for (var y = currentYear - maxAge; y <= currentYear; y++) {
      if (y.toString().startsWith(digits)) return true;
    }
    return false;
  }
}
