/// Which of Home's optional cards may be on screen right now.
///
/// Home is the screen people open most and the one they leave when it asks too
/// much of them. What stacks below the numbers is of two kinds:
///
/// * **Needs the person today** — a slip to resolve, the evening mood,
///   yesterday's missing answer, the day's vape-free confirmation, the daily
///   program, the cigarette rule, the over-limit actions. Those keep their
///   place; they are [actionUp].
/// * **Can wait** — finishing setup, the cigarettes question, the widget offer,
///   the coach nudge. On a day-3 evening all four used to stack with the mood
///   prompt and the day-3 offer, nine things under two numbers.
///
/// The optional ones now take turns: **at most one, and none while something
/// needs the person**, so the extras surface in the calm moments instead of on
/// top of the day's real work. A card that is held back is not spent — it comes
/// back the next time Home is calm — which is why each of them decides its own
/// "due" and this decides only whether it gets the slot.
///
/// The offer is the one thing that never gives way ([offerUp]): the splash
/// counts it the moment it decides one (`LaunchPaywallPolicy`), so hiding it
/// behind another card would burn a lifetime offer nobody saw. Everything
/// optional yields to it instead.
///
/// Pure Dart: the view computes the inputs, this decides.
class HomeCardPlan {
  const HomeCardPlan({
    this.setup = false,
    this.smoking = false,
    this.widget = false,
    this.nudge = false,
  });

  /// "Finish setup" (the first three days, Day-1 tasks left).
  final bool setup;

  /// The cigarettes question for accounts that were never asked.
  final bool smoking;

  /// The one-time home-screen widget offer.
  final bool widget;

  /// The coach nudge (or its Premium lock card).
  final bool nudge;

  /// Setup first (activation, and the people who skip it come back at half the
  /// rate), then the safety question, then the convenience, then the nudge.
  static HomeCardPlan decide({
    required bool actionUp,
    required bool offerUp,
    required bool setupDue,
    required bool smokingDue,
    required bool widgetUp,
    required bool nudgeDue,
  }) {
    if (actionUp || offerUp) return const HomeCardPlan();
    if (setupDue) return const HomeCardPlan(setup: true);
    if (smokingDue) return const HomeCardPlan(smoking: true);
    if (widgetUp) return const HomeCardPlan(widget: true);
    if (nudgeDue) return const HomeCardPlan(nudge: true);
    return const HomeCardPlan();
  }
}
