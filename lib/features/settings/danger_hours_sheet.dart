import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_format.dart';
import '../../core/utils/lp_haptics.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_selectables.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/day1_tour_store.dart';
import '../../data/stores/providers.dart';
import '../../domain/logic/reminder_planner.dart';
import '../day1/day1_spotlight.dart';
import 'quiet_hours_band.dart';

/// Danger-hours editor sheet — reachable from Settings AND by tapping the
/// Stats trigger-hours heatmap (frame 38 note: "Heatmap taps into
/// danger-hours editor").
///
/// One question, one answer, one promise. The Sep 1 field test (docs/09
/// issue 5) put the previous version in front of a user and got back "9 PM –
/// 12 AM — how many notifications, and when?": a slider with no labels, a
/// range whose end hour nothing reads, and a note about "max 3 pushes" that
/// described a different mode. What the feature actually does is simple —
/// ONE local push, ten minutes before the hour they choose, every day, never
/// inside quiet hours — so the sheet now says exactly that, live, for the
/// hour under their thumb.
///
/// Why chips and not a slider: the choice is discrete (an hour), and a slider
/// hides the option set and asks for a drag to land on a value; a row of
/// labelled chips shows every option at once and takes one tap. Why only
/// some hours: the list comes from [ReminderPlanner.eligibleStartHours], the
/// same quiet-hours rule the scheduler applies, so nothing here can be saved
/// and then silently never fire. Why the exact time is printed: a concrete
/// "at 8:50 PM" is an implementation intention — a cue tied to a moment —
/// which is the form of plan people actually follow through on, and stating
/// "one, at this time" is what stops a reminder reading as spam before it has
/// fired once.
///
/// Quiet hours live here too, since Sep 6 2026 (docs/10 §28): the rail under
/// the chips is the window nothing lands in, dragged by its ends or slid by
/// its middle. The chips are re-derived from the window under the finger —
/// an hour whose nudge would fall inside it leaves the grid, and a selection
/// that stops qualifying steps to the nearest hour that still fires — and the
/// promise card re-prints both times on every move, so the two settings can
/// never be saved in disagreement. Save writes both; a swipe-away saves
/// neither. The trial reminder and the milestone celebration read the same
/// window from the same setting, so they move with it.
void showDangerHoursSheet(BuildContext context, WidgetRef ref) {
  // Locked shut while the Day-1 walkthrough is on this step: the sheet IS
  // the lesson, and swiping it away unsaved would leave the step unfinished
  // with nothing on screen explaining why.
  final duringTour = ref.read(day1TourStepProvider) == Day1TourStep.dangerHours;
  // The spotlight has done its job — the user tapped the real control. Down
  // it comes, or the sheet (pushed under the showcase's root-overlay entry)
  // opens behind the barrier.
  if (duringTour) Day1Spotlight.dismissOverlay();
  showModalBottomSheet<void>(
    context: context,
    isDismissible: !duringTour,
    enableDrag: !duringTour,
    // Sized to content rather than capped at the default fraction of the
    // screen, so the chip rows never get clipped on a short phone.
    isScrollControlled: true,
    builder: (sheetContext) {
      final settings = ref.read(settingsStoreProvider);
      var quiet = QuietTrack.fromHours(
        settings.quietStartHour,
        settings.quietEndHour,
      );
      // A start saved by the old slider can sit inside quiet hours (midnight
      // to 2am). Land on the nearest hour that works rather than opening with
      // nothing selected.
      var start = _nearestOf(_eligible(quiet), settings.dangerStartHour % 24);
      // The chip the selection last stepped onto by itself, so it pops once
      // and the eye follows it; a fresh key per step re-runs the pop.
      int? steppedTo;
      var steps = 0;
      return StatefulBuilder(
        builder: (context, setState) {
          final lp = context.lp;
          final l10n = context.l10n;
          final locale = context.localeTag;
          final hours = _eligible(quiet);
          // The window moved under the selection: step to the nearest hour
          // that still fires, visibly, rather than promising a nudge the
          // planner would refuse.
          if (!hours.contains(start)) {
            start = _nearestOf(hours, start);
            steppedTo = start;
            steps++;
          }
          final fire = ReminderPlanner.fireTimeFor(start);
          final nudgeAt = LpFormat.clockTime(
            DateTime(2026, 1, 1, fire.$1, fire.$2),
            locale,
          );
          final quietRange =
              '${LpFormat.hour(quiet.startHour, locale)} – '
              '${LpFormat.hour(quiet.endHour, locale)}';
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.settingsDangerHoursTitle,
                      style: LpType.titleSm(lp.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.settingsDangerHoursNote,
                      style: LpType.caption(lp.textSecondary),
                    ),
                    const SizedBox(height: 18),
                    // The grid re-derives itself from the window below; the
                    // size animates so a row appearing or leaving never jumps.
                    AnimatedSize(
                      duration: LpMotion.fast,
                      curve: LpMotion.ease,
                      alignment: Alignment.topCenter,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final hour in hours)
                            _Pop(
                              key: ValueKey(
                                hour == steppedTo ? 'step$steps' : 'hour$hour',
                              ),
                              animate: hour == steppedTo,
                              child: LpChip(
                                label: LpFormat.hour(hour, locale),
                                selected: hour == start,
                                selectedColor: lp.ember,
                                fontSize: 13,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 9,
                                ),
                                onTap: () {
                                  LpHaptics.tick();
                                  setState(() {
                                    start = hour;
                                    steppedTo = null;
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        SectionLabel(
                          l10n.settingsQuietHoursLabel,
                          padding: EdgeInsets.zero,
                        ),
                        Text(
                          '$quietRange · '
                          '${l10n.settingsQuietHoursLength(quiet.length)}',
                          style: LpType.body13(
                            lp.textPrimary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    // Room for the hour pill that rides above the knob.
                    const SizedBox(height: 26),
                    QuietHoursBand(
                      track: quiet,
                      onChanged: (next) => setState(() => quiet = next),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.settingsQuietHoursHint,
                      style: LpType.caption11(lp.textFaint),
                    ),
                    const SizedBox(height: 16),
                    // The promise, live: exactly what will happen for the
                    // hour selected above, and the one window it never will.
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: lp.surfaceInset,
                        borderRadius: BorderRadius.circular(LpDimens.rInput),
                        border: Border.all(color: lp.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('🔔', style: TextStyle(fontSize: 15)),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  settings.notificationsOn
                                      ? l10n.settingsDangerHoursNudge(nudgeAt)
                                      : l10n.settingsDangerHoursNotifOff,
                                  style: LpType.body14(
                                    lp.textPrimary,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 29),
                            child: Text(
                              l10n.settingsQuietHours(quietRange),
                              style: LpType.caption11(lp.textFaint),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    PressScale(
                      onTap: () {
                        // Both choices, one Save. The quiet window first: the
                        // start below was chosen against it, and the
                        // coordinator re-plans on each commit.
                        ref
                            .read(settingsStoreProvider.notifier)
                            .setQuietHours(quiet.startHour, quiet.endHour);
                        // The end hour is kept for the model's sake only —
                        // nothing schedules or shows it — so it follows the
                        // start by the span the default always had.
                        ref
                            .read(settingsStoreProvider.notifier)
                            .setDangerWindow(start, start + _spanHours);
                        Navigator.of(sheetContext).pop();
                        // The real move, and the only thing that ticks the
                        // box: an hour actually saved. `dangerHoursCustom`
                        // flipping true is what separates a chosen window
                        // from the shipped default, and tapping "Save" is
                        // where that happens.
                        if (duringTour) {
                          ref
                              .read(day1TourProvider.notifier)
                              .complete(Day1TourStep.dangerHours);
                        }
                      },
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: lp.volt,
                          borderRadius: BorderRadius.circular(LpDimens.rButton),
                        ),
                        child: Text(
                          l10n.commonSave,
                          style: LpType.button(lp.onVolt, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// The window length the shipped default (21 → 24) always had. Only the
/// start hour is chosen or used; see the Save handler.
const int _spanHours = 3;

/// The start hours whose nudge clears [quiet] — the scheduler's own rule.
List<int> _eligible(QuietTrack quiet) => ReminderPlanner.eligibleStartHours(
  quietStartHour: quiet.startHour,
  quietEndHour: quiet.endHour,
);

/// [hour] itself when it is offered, else the offered hour closest to it on
/// the clock face (so 1am lands on 11pm, not 9am).
int _nearestOf(List<int> hours, int hour) {
  if (hours.contains(hour)) return hour;
  int distance(int a, int b) {
    final d = (a - b).abs();
    return d < 24 - d ? d : 24 - d;
  }

  var best = hours.first;
  for (final candidate in hours) {
    if (distance(candidate, hour) < distance(best, hour)) best = candidate;
  }
  return best;
}

/// A one-time scale pop for the chip the selection stepped onto by itself.
/// Explicit `begin`, or the first build never animates (the RollingNumber
/// lesson); no-op when [animate] is false so every other chip is plain.
class _Pop extends StatelessWidget {
  const _Pop({super.key, required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!animate) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.86, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: LpMotion.spring,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}
