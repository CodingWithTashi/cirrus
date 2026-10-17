import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_format.dart';
import '../../core/utils/lp_haptics.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_selectables.dart';
import '../../data/stores/providers.dart';
import '../../domain/logic/reminder_planner.dart';

/// The evening check-in: on or off, and at which hour (docs/10 §51).
///
/// Its own sheet rather than a row on the push-categories one, for the reason
/// that sheet gives: what is there is decided by the SERVER, and this is
/// scheduled on the device — like danger hours, it works offline and nothing
/// outside the phone has to be told.
void showCheckinSheet(BuildContext context, WidgetRef ref) {
  LpHaptics.light();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _CheckinSheet(),
  );
}

class _CheckinSheet extends ConsumerWidget {
  const _CheckinSheet();

  /// The evening hours on offer. Only those quiet hours leave open — the
  /// planner refuses a quiet hour anyway, and a chip that saves and then
  /// does nothing is the "what does this even do?" of the old danger-hours
  /// slider (docs/09 issue 5).
  static List<int> hoursFor(int quietStart, int quietEnd, int current) => {
    for (var hour = 17; hour <= 22; hour++)
      if (!ReminderPlanner.isQuiet(hour, quietStart, quietEnd)) hour,
    if (!ReminderPlanner.isQuiet(current, quietStart, quietEnd)) current,
  }.toList()..sort();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final settings = ref.watch(settingsStoreProvider);
    final store = ref.read(settingsStoreProvider.notifier);
    // The master switch already silences everything; a live control under
    // it would misdescribe what happens next.
    final enabled = settings.notificationsOn;
    final on = enabled && settings.checkinReminderOn;
    final hours = hoursFor(
      settings.quietStartHour,
      settings.quietEndHour,
      settings.checkinHour,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LpCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.settingsCheckin, style: LpType.title(lp.textPrimary)),
              const SizedBox(height: 6),
              Text(
                l10n.settingsCheckinBody,
                style: LpType.body13(lp.textSecondary),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.settingsCheckinToggle,
                      style: LpType.body14(
                        enabled ? lp.textPrimary : lp.textSecondary,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Switch(
                    value: on,
                    onChanged: enabled ? store.setCheckinReminder : null,
                  ),
                ],
              ),
              if (on && hours.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.settingsCheckinTime,
                  style: LpType.caption(lp.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final hour in hours)
                      LpChip(
                        label: LpFormat.hour(hour, locale),
                        selected: hour == settings.checkinHour,
                        fontSize: 14,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        onTap: () => store.setCheckinHour(hour),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
