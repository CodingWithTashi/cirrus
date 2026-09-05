import '../../domain/date_key.dart';
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
    required this.leftAhead,
    required this.leftTight,
    required this.overLimit,
    required this.emptyTitle,
    required this.emptyBody,
  });

  /// `day %1$d`
  final String day;

  /// `%1$d left · ahead of your curve`
  final String leftAhead;

  /// `%1$d left · tight, you've got this`
  final String leftTight;

  /// No count in this one — over is over.
  final String overLimit;

  final String emptyTitle;
  final String emptyBody;

  Map<String, dynamic> toJson() => {
    'day': day,
    'leftAhead': leftAhead,
    'leftTight': leftTight,
    'overLimit': overLimit,
    'emptyTitle': emptyTitle,
    'emptyBody': emptyBody,
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
}) {
  if (journey == null || snapshot == null) {
    return {
      'v': WidgetMirror.schemaVersion,
      'hasJourney': false,
      'copy': copy.toJson(),
    };
  }

  final today = LpDate.dayStart(now);
  return {
    'v': WidgetMirror.schemaVersion,
    'hasJourney': true,
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
