import '../../core/utils/lp_format.dart';
import '../../domain/date_key.dart';
import '../../domain/logic/day_window.dart';
import '../../domain/logic/week_trend.dart';
import '../../domain/models/journey_state.dart';

/// The strings the widget renders, resolved from ARB while a `Localizations`
/// scope is still in reach.
///
/// Four of them are **native format templates** carrying a literal `%1$d`
/// rather than an ARB `{placeholder}`. That is deliberate: the count and the
/// day number are the two values the widget changes on its own — a `+` tap
/// while the app is dead, or a midnight rollover — so they have to be
/// formatted on the other side of the process boundary, by Kotlin's
/// `String.format`. Word order stays per-locale, which a "number in its own
/// TextView" layout could not do (German wants "noch 46 übrig").
class WidgetCopy {
  const WidgetCopy({
    required this.day,
    required this.dayFreedom,
    required this.dayPastOne,
    required this.dayPastOther,
    required this.leftAhead,
    required this.leftTight,
    required this.overLimit,
    required this.emptyTitle,
    required this.emptyBody,
    required this.watchOpenPhone,
    required this.weekTitle,
    required this.vsLast,
    required this.savedLabel,
    required this.cravingsLabel,
    required this.breatheIn,
    required this.breatheHold,
    required this.breatheOut,
    required this.breathePattern,
    required this.cravingTimer,
    required this.cravingTimerLate,
  });

  /// `day %1$d`
  final String day;

  /// The last plan day, said the way Home says it (`Freedom Day 🏆`) — the
  /// widget used to keep counting past it, reading "day 31" of a 30-day plan
  /// on the launcher while Home said "1 day past Freedom Day".
  final String dayFreedom;

  /// `%1$d day past Freedom Day` / `%1$d days past Freedom Day`. Two
  /// templates because `String.format` has no plural forms; one and other
  /// cover all five locales.
  final String dayPastOne;
  final String dayPastOther;

  /// `%1$d left · ahead of your curve`
  final String leftAhead;

  /// `%1$d left · tight, you've got this`
  final String leftTight;

  /// No count in this one — over is over.
  final String overLimit;

  final String emptyTitle;
  final String emptyBody;

  /// The body of the watch app's empty card.
  ///
  /// Separate from [emptyBody] because that one says "Tap to open Cirrus",
  /// which is true on a home screen and false on a wrist: watchOS cannot launch
  /// its companion iPhone app. A control that tells you to do something
  /// impossible is the same failure as one that claims to have done something
  /// it did not.
  final String watchOpenPhone;

  // --- The wrist's second and third screens -------------------------------
  //
  // Watch-only, and every one of them is a string the app already ships in
  // five languages — the week card is Stats' own copy and the breathing
  // screen is the panic flow's. Nothing new was written for the wrist, which
  // is why no ARB key was added.

  /// `PUFFS THIS WEEK`. Stats' own section label, not the mock's shorter
  /// "THIS WEEK" — a new key to save four characters would cost five
  /// translations to say less.
  final String weekTitle;

  /// `%1$@ vs last`. A **native template**, like [leftAhead], but carrying a
  /// STRING rather than a `%1$d`: the percent arrives pre-signed in
  /// `weekVsLastLabel` because `LpFormat.signedPercent` renders a flat week as
  /// `0%` and never `+0%`, and re-deriving that in Swift would disagree at
  /// exactly the value the card most wants to get right.
  final String vsLast;

  final String savedLabel;
  final String cravingsLabel;

  /// The three verbs of the paced breath, and the pattern under the orb.
  final String breatheIn;
  final String breatheHold;
  final String breatheOut;
  final String breathePattern;

  /// `craving timer · %1$@ · peaks ~15 min`, and its past-the-spike twin.
  ///
  /// Native templates again, because the wrist owns this clock: the craving is
  /// timed where it is being felt, and the phone's `panicProvider` is not
  /// involved. Counting UP with an approximate window is the honest shape —
  /// nothing on either device can know when a particular craving peaks.
  final String cravingTimer;
  final String cravingTimerLate;

  Map<String, dynamic> toJson() => {
    'day': day,
    'dayFreedom': dayFreedom,
    'dayPastOne': dayPastOne,
    'dayPastOther': dayPastOther,
    'leftAhead': leftAhead,
    'leftTight': leftTight,
    'overLimit': overLimit,
    'emptyTitle': emptyTitle,
    'emptyBody': emptyBody,
    'watchOpenPhone': watchOpenPhone,
    'weekTitle': weekTitle,
    'vsLast': vsLast,
    'savedLabel': savedLabel,
    'cravingsLabel': cravingsLabel,
    'breatheIn': breatheIn,
    'breatheHold': breatheHold,
    'breatheOut': breatheOut,
    'breathePattern': breathePattern,
    'cravingTimer': cravingTimer,
    'cravingTimerLate': cravingTimerLate,
  };
}

/// How many days of taper limits travel with the mirror.
///
/// The widget can survive a day rollover without the app only if it already
/// knows the next day's line. A week is the honest ceiling: past that the
/// nightly `taperRecalc` advice would have moved the number, and a widget
/// quoting a stale limit is exactly the invented figure this app refuses to
/// show. Beyond the window it falls back to showing the count alone.
const int kMirrorLimitDays = 7;

/// How many nightly repaints are armed at a time. Matches the limit window:
/// past it the widget has no line to draw anyway, and the app will have run
/// again long before then.
const int kMirrorRepaintDays = kMirrorLimitDays;

/// The mirror document the home-screen widget renders from.
///
/// Everything here is engine-computed on the Flutter side — the widget owns no
/// arithmetic except adding one to a counter and picking today's row out of
/// [kMirrorLimitDays]. That is the whole point: "no invented numbers" has to
/// hold on the home screen too, and a second implementation of the taper curve
/// in Kotlin would drift the way the client and server streak engines already
/// did once (B12).
///
/// No theme travels with it. The widget follows the SYSTEM theme through
/// `values-night/`, not the app's own Appearance setting — a deliberate
/// deviation, because the launcher inflates the layout in its own process and
/// a card on the home screen should match the screen it sits on.
Map<String, dynamic> buildMirror({
  required JourneyState? journey,
  required TodaySnapshot? snapshot,
  required WidgetCopy copy,
  required DateTime now,
  required String? sid,
  required String locale,
}) {
  if (journey == null || snapshot == null) {
    return {
      'v': WidgetMirror.schemaVersion,
      'hasJourney': false,
      'copy': copy.toJson(),
    };
  }

  final today = LpDate.dayStart(now);
  // The wrist's week card. Seven CALENDAR days ending today — never "the last
  // seven logged", which slid the chart into last week and hid the day that
  // most needed fixing (QA M1). The verdicts are the same two the Stats bars
  // and the coach's card read, from the one engine.
  final week = DayWindow.trailing(journey, now, kMirrorLimitDays);
  final weekPuffs = [for (final log in week) log.puffs];
  final vsLast = WeekTrend.vsPrevious(
    week,
    DayWindow.previous(journey, now, kMirrorLimitDays),
  );
  return {
    'v': WidgetMirror.schemaVersion,
    'hasJourney': true,
    // Which account these numbers belong to. Read by the WATCH only, and only
    // to answer "are these still the same person's?" — see
    // `WatchWire.applyContext`. The home-screen widget lives in the same
    // container as the app, so sign-out forgets its queue synchronously and it
    // has never needed to ask.
    //
    // Absent, not empty, when the id has not resolved yet: an empty sid would
    // be indistinguishable from a different one, and the watch would throw away
    // a good mirror and a queue of real taps on every cold launch.
    if (sid != null && sid.isNotEmpty) 'sid': sid,
    'dayKey': LpDate.dayKey(today),
    // Plan day 1, so the widget can recompute the day number across a midnight
    // it slept through. Mirrors `QuitPlan.dayNumber`: whole calendar days,
    // never 24-hour arithmetic.
    //
    // A DAY KEY, not an epoch day. It was an epoch day, derived as
    // `dayStart(...).millisecondsSinceEpoch ~/ millisecondsPerDay` — which
    // floors the UTC *instant* of local midnight, not the local calendar day.
    // East of Greenwich local midnight falls on the previous UTC date, so the
    // quotient came out one low, and the native side (which computes today
    // with `LocalDate.now().toEpochDay()`, a true local day) read one day too
    // high. Every user at a positive UTC offset would have seen the widget say
    // "day 13" while Home said "day 12", for ever. The whole class of bug goes
    // away by shipping the same `yyyy-MM-dd` the day map is already keyed by.
    'planStartDayKey': LpDate.dayKey(LpDate.dayStart(journey.plan.startDate)),
    'dayNumber': snapshot.dayNumber,
    'totalDays': snapshot.totalDays,
    'puffs': snapshot.puffs,
    'limit': snapshot.limit,
    'puffsLeft': snapshot.puffsLeft,
    'streak': snapshot.streak,
    'flame': snapshot.flameDimmed ? '🌑' : '🔥',
    'isOverLimit': snapshot.isOverLimit,
    // --- The week card, for the wrist -------------------------------------
    //
    // Raw counts and the phone's own denominator, never pre-computed bar
    // heights: a height is layout, and the wrist is the side that knows how
    // wide it is. What the wrist must NOT do is decide which day was hard or
    // which was best — those are `WeekTrend` verdicts with real rules (a day
    // with no puffs is not the hard day; today is never the best day, because
    // one puff at 08:10 would paint a day that ends at fifty as the week's
    // win) and they arrive already decided.
    //
    // Shipping `weekMax` is what keeps the denominator engine-side. The watch
    // renormalizes against it after folding in taps the phone has not drained
    // yet, so the week chart and the day card on the same wrist can never
    // disagree about today.
    'weekPuffs': weekPuffs,
    'weekMax': weekPuffs.fold<int>(1, (m, p) => p > m ? p : m),
    'weekHardest': WeekTrend.hardestIndex(week),
    'weekBest': WeekTrend.bestIndex(week, now),
    // ABSENT, not zero. `0` already means "flat", which the card paints volt
    // as good news — so a sentinel here would claim an improvement on an
    // account that has not earned one. Four ways to have no honest answer;
    // see `WeekTrend.vsPrevious`. Both keys travel together or not at all.
    if (vsLast != null) ...{
      'weekVsLast': vsLast,
      'weekVsLastLabel': LpFormat.signedPercent(vsLast),
    },
    // Formatted here, because the rule that produced it is a domain rule: an
    // unconfirmed day is unknown, never a saving (`MoneyEngine.savedOn`). The
    // raw double deliberately does NOT travel — shipping it would invite a
    // second implementation of that filter on the wrist.
    'savedText': LpFormat.money(snapshot.savedLifetime, locale),
    'cravingsBeaten': snapshot.cravingsSurvivedTotal,
    // dayKey -> limit, so a rollover without the app still draws a real line.
    'limits': {
      for (var i = 0; i < kMirrorLimitDays; i++)
        LpDate.dayKey(LpDate.addDays(today, i)): journey.limitOn(
          LpDate.addDays(today, i),
        ),
    },
    'copy': copy.toJson(),
  };
}

/// Where the mirror lives and what shape it is.
///
/// Constants only — `WidgetCoordinator` owns the writing, because the write
/// and the repaint have to be ordered against the outbox cursor and that
/// ordering is the coordinator's job.
abstract final class WidgetMirror {
  /// Read by the Kotlin `CirrusWidgetProvider` and the Swift `CirrusMirror`.
  /// Change it in all three.
  static const String key = 'lp.mirror';

  static const int schemaVersion = 1;
}
