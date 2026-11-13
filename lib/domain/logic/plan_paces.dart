/// The plan lengths a person can choose (docs/15 QP-A8).
///
/// A taper is at most six weeks. Three screens used to carry their own copy of
/// `[14, 21, 30, 60, 90]`; they read this now, so a length cannot be on offer
/// in one place and gone in another.
///
/// **Why six weeks.** A quit date that is far off is a quit date that slips:
/// each week of delay to the quit date raised the chance of lapsing by 19%
/// (Hughes 2010), and NICE guidance for smoking advises a quit date within six
/// weeks (NG209). Tapers ran to 90 days before this.
///
/// **What it does not touch.** Plans already running keep their length: this
/// governs what is *offered*, never what a stored `QuitPlan.paceDays` is. The
/// stores still accept any length, because 60- and 90-day plans exist.
abstract final class PlanPaces {
  /// The lengths on offer, shortest first.
  static const options = [14, 21, 30, 42];

  /// The length chosen when nothing else says — and the one marked "most
  /// chosen". Always one of [options].
  static const defaultDays = 30;

  /// A length arriving from somewhere that predates [options] — a saved
  /// onboarding draft, a link — brought onto the menu.
  ///
  /// - on offer: kept;
  /// - past the ceiling (the retired 60 and 90): the longest on offer, because
  ///   it was a "slower" choice and the nearest honest equivalent is the
  ///   slowest one available;
  /// - missing, non-positive or between two choices: [defaultDays]. Guessing
  ///   "the nearest" for an in-between length would put somebody on a length
  ///   they never picked.
  static int clamp(int? days) {
    if (days == null || days <= 0) return defaultDays;
    if (options.contains(days)) return days;
    if (days > options.last) return options.last;
    return defaultDays;
  }
}
