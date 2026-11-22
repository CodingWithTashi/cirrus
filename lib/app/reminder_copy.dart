import '../core/utils/program_copy.dart';
import '../domain/logic/quit_program.dart';
import '../domain/logic/reminder_planner.dart';
import '../l10n/gen/app_localizations.dart';

// The words a check-in notification carries, resolved under the
// `Localizations` scope and handed to the scheduler as plain strings: it has no
// `BuildContext`, and a notification in the wrong language is worse than none.
// Public so the tests and the device suite assert on the production words
// rather than on a copy of them.

/// A plain check-in's words: the evening's, or a plan's first-days morning
/// (plan days 2 and 3). The two bodies differ by slot because they ask for
/// different things — the evening asks how the day went, the morning names the
/// line and the one action, logging. On a zero line the morning never says
/// log: there is nothing to log, and it points at the craving flow instead.
({String title, String body}) checkinCopy(
  AppLocalizations l10n,
  CheckinReminder checkin,
) => (
  title: _dayTitle(l10n, checkin),
  body: switch (checkin.slot) {
    ProgramSlot.morning =>
      checkin.limit == 0
          ? l10n.morningNotifBodyZero
          : l10n.morningNotifBody(checkin.limit),
    ProgramSlot.evening =>
      checkin.limit == 0
          ? l10n.checkinNotifBodyZero
          : l10n.checkinNotifBody(checkin.limit),
  },
);

/// The daily program's words for one message (docs/15 stage B): the title of
/// the slot it fills, and the message itself as the body.
({String title, String body}) programCopy(
  AppLocalizations l10n,
  CheckinReminder checkin,
) => (title: _dayTitle(l10n, checkin), body: checkin.message!.text(l10n));

/// The plan day, worn by the slot. `checkinNotifTitle` reads as an evening in
/// fr, de and it ("le point du soir"), so every morning — plain or program —
/// takes the morning title. Past Freedom Day both drop the number: Home stops
/// counting "Day N" there, and a notification that disagreed with it would be
/// a second count of the same thing.
String _dayTitle(AppLocalizations l10n, CheckinReminder checkin) {
  final past = checkin.planDay > checkin.totalDays;
  return switch (checkin.slot) {
    ProgramSlot.morning =>
      past
          ? l10n.morningNotifTitlePast
          : l10n.morningNotifTitle(checkin.planDay),
    ProgramSlot.evening =>
      past
          ? l10n.checkinNotifTitlePast
          : l10n.checkinNotifTitle(checkin.planDay),
  };
}
