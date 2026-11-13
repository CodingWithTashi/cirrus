import '../date_key.dart';
import '../models/journey_state.dart';
import '../models/models.dart';

/// The daily quit program (docs/15 stage B): one message a day from seven days
/// before the quit date to 56 days after, the way the trialled text program ran
/// (Graham 2020/2021). This file is the whole of its logic and none of its
/// words — pure Dart, no Flutter — so the schedule can be armed days ahead on
/// the device and re-based the moment the date moves.
///
/// **The anchor is the app's own "your date"**: `plan.freedomDate` for a taper,
/// the last day of its runway, and `plan.startDate` for cold turkey, which is
/// already vape-free on day one. Always from the CURRENT plan, so a plan started
/// again, an Adjust and a slip's added days all re-base the program at once and
/// nothing is remembered; a message can repeat or be skipped when the date
/// moves, and that is accepted. (The plan's own phrase, "the first zero day",
/// is a different day for a low baseline, whose curve reaches zero earlier;
/// those zero-line days fall inside the pre-week as negative program days.)
///
/// Every day count is calendar arithmetic through [LpDate]: a count taken with
/// `Duration(days:)` is an hour off across a clock change.
abstract final class QuitProgram {
  static const firstDay = -7;
  static const lastDay = 56;

  /// The day the program counts from.
  static DateTime quitDate(QuitPlan plan) =>
      plan.method == QuitMethod.coldTurkey ? plan.startDate : plan.freedomDate;

  /// Calendar days from the quit date to [date]; negative before it. Not
  /// bounded — check-ups run past the end of the program.
  static int daysFromQuit(QuitPlan plan, DateTime date) =>
      LpDate.daysBetween(quitDate(plan), LpDate.dayStart(date));

  /// The program day for [date]: −7 … 56, or null outside the program.
  static int? dayOf(QuitPlan plan, DateTime date) {
    final d = daysFromQuit(plan, date);
    return d < firstDay || d > lastDay ? null : d;
  }

  static final Map<(int, ProgramSlot), ProgramMessage> _index = {
    for (final m in ProgramMessage.values) (m.programDay, m.slot): m,
  };

  /// The message for [slot] on [date], or null when the program has none.
  static ProgramMessage? messageFor(
    QuitPlan plan,
    DateTime date,
    ProgramSlot slot,
  ) {
    final d = dayOf(plan, date);
    return d == null ? null : _index[(d, slot)];
  }

  /// Everything the program says on [date], morning first.
  static List<ProgramMessage> messagesOn(QuitPlan plan, DateTime date) => [
    for (final slot in ProgramSlot.values)
      ?messageFor(plan, date, slot),
  ];

  /// The message the daily card shows at [now]: on a day with a morning and an
  /// evening message, the morning one until [checkinHour] and the evening one
  /// from then on; on a day with one, that one all day; on a day with none,
  /// null. [checkinHour] is the person's own (Settings), the hour the evening
  /// message is armed for, so the card changes over when the notification does.
  static ProgramMessage? messageToShow(
    QuitPlan plan,
    DateTime now, {
    required int checkinHour,
  }) {
    final today = messagesOn(plan, now);
    if (today.isEmpty) return null;
    if (today.length == 1) return today.single;
    return now.hour < checkinHour ? today.first : today.last;
  }

  /// Whether the person has slipped lately: puffs on a day whose line was zero,
  /// on [date] or either of the two days before it.
  ///
  /// Read from each day's STORED `DayLog.limit`, never a recomputed curve — the
  /// stored number is the one the streak engine and Home use, and a plan
  /// started again holds a day's line on the log. Going over a line that is not
  /// zero is the taper's business (the slip screen), not this program's: it
  /// speaks about the zero line it is counting towards.
  static ProgramTrack trackOn(JourneyState journey, DateTime date) {
    final day = LpDate.dayStart(date);
    for (var back = 0; back < 3; back++) {
      final log = journey.logFor(LpDate.addDays(day, -back));
      if (log != null && log.limit == 0 && log.puffs > 0) {
        return ProgramTrack.slipped;
      }
    }
    return ProgramTrack.onTrack;
  }

  static const _hard = [
    ProgramReply.breathe,
    ProgramReply.waitTen,
    ProgramReply.changeRoom,
    ProgramReply.tellSomeone,
  ];
  static const _okay = [
    ProgramReply.okayHold,
    ProgramReply.okayOne,
    ProgramReply.okayShort,
  ];
  static const _praise = [
    ProgramReply.praiseWhy1,
    ProgramReply.praiseWhy2,
    ProgramReply.praise3,
    ProgramReply.praise4,
  ];
  static const _praiseNoWhy = [ProgramReply.praise3, ProgramReply.praise4];
  static const _slip = [
    ProgramReply.slipData,
    ProgramReply.slipToday,
    ProgramReply.slipPlan,
  ];

  /// The written answer to a mood check-in (docs/15 §4.2). Not an AI reply:
  /// safer, free, and identical in tests. [seed] picks among the variants
  /// deterministically — the plan day, so a person does not see the same line
  /// every day and a test can name the one it expects. A reply that needs the
  /// person's own words is never chosen when they gave none ([hasWhy]).
  static ProgramReply replyFor(
    Mood mood,
    ProgramTrack track, {
    int seed = 0,
    bool hasWhy = true,
  }) {
    final pool = switch (track) {
      ProgramTrack.slipped => _slip,
      ProgramTrack.onTrack => switch (mood) {
        Mood.rough || Mood.meh => _hard,
        Mood.okay => _okay,
        Mood.good || Mood.great => hasWhy ? _praise : _praiseNoWhy,
      },
    };
    return pool[seed % pool.length];
  }

  /// A tip of [kind] for the Stress, Slipped and More buttons.
  static ProgramTip tipFor(ProgramTipKind kind, int seed) {
    final of = _tips[kind]!;
    return of[seed % of.length];
  }

  static final Map<ProgramTipKind, List<ProgramTip>> _tips = {
    for (final k in ProgramTipKind.values)
      k: [
        for (final t in ProgramTip.values)
          if (t.kind == k) t,
      ],
  };

  /// The check-up due on [date], or null. Asked once per window: an answer
  /// recorded on any day inside the question's window closes it. The windows
  /// never overlap, so what is returned is never a choice.
  static CheckupKind? checkupDue(JourneyState journey, DateTime date) {
    final day = daysFromQuit(journey.plan, date);
    for (final kind in CheckupKind.values) {
      if (!kind.windowContains(day)) continue;
      // Answered when an answer to this question was recorded in the SAME
      // window. "Same window" and not "any window": the nicotine question is
      // four separate single days, and an answer on day 7 must not close day 14.
      final window = kind.windowStart(day);
      final answered = journey.checkups.entries.any(
        (e) =>
            e.value.containsKey(kind) &&
            kind.windowStart(daysFromQuit(journey.plan, e.key)) == window,
      );
      if (!answered) return kind;
    }
    return null;
  }
}

/// When a check-up is asked, in program days from the quit date.
extension CheckupKindProgram on CheckupKind {
  /// Whether [day] (program days; unbounded) is inside this question's window.
  bool windowContains(int day) => switch (this) {
    // "Any other nicotine this week?" — a single day each time.
    CheckupKind.nicotine => const {7, 14, 28, 56}.contains(day),
    // "Have you vaped in the last 30 days?" — open from day 30 to 44.
    CheckupKind.vaped30 => day >= 30 && day <= 44,
    // The same question at 90 days, after the program has ended.
    CheckupKind.vaped90 => day >= 90 && day <= 104,
  };

  /// The first day of the window [day] falls in, or null when it is in none.
  /// Two days with the same start are in the same asking.
  int? windowStart(int day) => !windowContains(day)
      ? null
      : switch (this) {
          CheckupKind.nicotine => day,
          CheckupKind.vaped30 => 30,
          CheckupKind.vaped90 => 90,
        };

  /// Whether the question sits inside the daily card. The 90-day one has its
  /// own small Home card, because the program is over by then.
  bool get inProgramCard => this != CheckupKind.vaped90;
}

enum ProgramSlot { morning, evening }

/// Whether the person has slipped lately — see [QuitProgram.trackOn].
enum ProgramTrack { onTrack, slipped }

/// Where a message points. The words say "Look at Money" and this is what makes
/// the pointer a tap; `stress` is the daily card's own Stress button, so it has
/// no route.
enum ProgramLink { none, money, health, help, community, stress }

/// The 43 messages (docs/15 §4.1), named for their day and slot. The copy for
/// each is one l10n string, resolved in the view the way `CoachTemplate` is, so
/// adding a message is a compile error until its copy exists.
///
/// `programDay` is days from the quit date, not the plan day: for a taper the
/// quit date is its last day, and for cold turkey it is day one.
enum ProgramMessage {
  pre7(-7),
  pre6(-6),
  pre5(-5),
  pre4(-4),
  pre3(-3),
  pre2(-2),
  pre1(-1),
  q0am(0, ProgramSlot.morning),
  q0pm(0),
  d1am(1, ProgramSlot.morning),
  d1pm(1),
  d2am(2, ProgramSlot.morning),
  d2pm(2, ProgramSlot.evening, ProgramLink.help),
  d3(3),
  d4(4),
  d5(5, ProgramSlot.evening, ProgramLink.stress),
  d6(6),
  d7(7),
  d8(8),
  d9(9),
  d10(10),
  d11(11),
  d12(12, ProgramSlot.evening, ProgramLink.money),
  d13(13),
  d14(14),
  d16(16),
  d18(18),
  d21(21),
  d23(23),
  d25(25),
  d28(28),
  d30(30),
  d32(32),
  d35(35, ProgramSlot.evening, ProgramLink.health),
  d37(37),
  d39(39, ProgramSlot.evening, ProgramLink.community),
  d42(42),
  d44(44),
  d46(46),
  d49(49),
  d51(51),
  d53(53),
  d56(56);

  const ProgramMessage(
    this.programDay, [
    this.slot = ProgramSlot.evening,
    this.link = ProgramLink.none,
  ]);

  final int programDay;
  final ProgramSlot slot;
  final ProgramLink link;
}

/// The written answers to a mood check-in (docs/15 §4.2): fourteen.
enum ProgramReply {
  // Rough or meh, on track: one concrete step each.
  breathe,
  waitTen,
  changeRoom,
  tellSomeone,
  // Okay, on track: steadying and short.
  okayHold,
  okayOne,
  okayShort,
  // Good or great, on track: specific praise. Two use the person's own reason.
  praiseWhy1(needsWhy: true),
  praiseWhy2(needsWhy: true),
  praise3,
  praise4,
  // A slip, any mood: no shame, "a slip is data", and the next step.
  slipData,
  slipToday,
  slipPlan;

  const ProgramReply({this.needsWhy = false});

  /// Whether the line interpolates what the person wrote as their reason.
  final bool needsWhy;
}

enum ProgramTipKind { stress, slipped, more }

/// Twenty-one tips: five for Stress, four for a slip, twelve for More. Drawn
/// from acceptance-style skills (notice the urge and let it pass, delay,
/// replace the action, plan the trigger — Bricker 2020).
enum ProgramTip {
  stress1(ProgramTipKind.stress),
  stress2(ProgramTipKind.stress),
  stress3(ProgramTipKind.stress),
  stress4(ProgramTipKind.stress),
  stress5(ProgramTipKind.stress),
  slip1(ProgramTipKind.slipped),
  slip2(ProgramTipKind.slipped),
  slip3(ProgramTipKind.slipped),
  slip4(ProgramTipKind.slipped),
  more1(ProgramTipKind.more),
  more2(ProgramTipKind.more),
  more3(ProgramTipKind.more),
  more4(ProgramTipKind.more),
  more5(ProgramTipKind.more),
  more6(ProgramTipKind.more),
  more7(ProgramTipKind.more),
  more8(ProgramTipKind.more),
  more9(ProgramTipKind.more),
  more10(ProgramTipKind.more),
  more11(ProgramTipKind.more),
  more12(ProgramTipKind.more);

  const ProgramTip(this.kind);

  final ProgramTipKind kind;
}
