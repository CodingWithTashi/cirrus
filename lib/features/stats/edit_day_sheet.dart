import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_format.dart';
import '../../core/utils/lp_haptics.dart';
import '../../core/widgets/lp_buttons.dart';
import '../../data/stores/providers.dart';
import '../../domain/models/journey_state.dart';
import '../../domain/models/models.dart';

/// Stepper sheet for one day's puff count — long-press a Stats bar for any
/// day, or tap the Home ring card for today (the "I logged too many and the
/// undo snack is gone" path). Tap steps by 1; hold a stepper to run.
///
/// Today saves through [JourneyStore.adjustToday] (hour buckets stay honest,
/// over-limit rules apply); past days through [JourneyStore.editPastDay].
void showEditDaySheet(BuildContext context, WidgetRef ref, DayLog log) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      var value = log.puffs;
      return StatefulBuilder(
        builder: (context, setState) {
          final lp = context.lp;
          final l10n = context.l10n;
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.statsEditDayTitle(
                    LpFormat.mediumDate(log.date, context.localeTag),
                  ),
                  style: LpType.titleSm(lp.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.statsEditDayNote,
                  style: LpType.caption(lp.textSecondary),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PressScaleIcon(
                      icon: Icons.remove_rounded,
                      color: lp.textPrimary,
                      repeatOnHold: true,
                      onTap: () {
                        if (value > 0) setState(() => value -= 1);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        '$value',
                        style: LpType.number(lp.textPrimary, size: 44),
                      ),
                    ),
                    PressScaleIcon(
                      icon: Icons.add_rounded,
                      color: lp.textPrimary,
                      repeatOnHold: true,
                      onTap: () => setState(() => value += 1),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                LpButton(
                  l10n.commonSave,
                  onTap: () {
                    final store = ref.read(quitStoreProvider.notifier);
                    final isToday =
                        JourneyState.dateKey(log.date) ==
                        JourneyState.dateKey(DateTime.now());
                    if (isToday) {
                      store.adjustToday(value);
                    } else {
                      store.editPastDay(log.date, value);
                    }
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Small circular stepper button. With [repeatOnHold] a press-and-hold fires
/// [onTap] on a self-accelerating clock, so ±1 steps stay precise for small
/// corrections and a big edit is one hold instead of a hundred taps.
class PressScaleIcon extends StatefulWidget {
  const PressScaleIcon({
    super.key,
    required this.icon,
    required this.onTap,
    required this.color,
    this.repeatOnHold = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final bool repeatOnHold;

  @override
  State<PressScaleIcon> createState() => _PressScaleIconState();
}

class _PressScaleIconState extends State<PressScaleIcon> {
  Timer? _timer;
  int _ticks = 0;

  void _tick() {
    LpHaptics.tick();
    widget.onTap();
    _ticks++;
    // Deliberate at first (readable single steps), then runs.
    final interval = _ticks < 12
        ? const Duration(milliseconds: 120)
        : const Duration(milliseconds: 45);
    _timer = Timer(interval, _tick);
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _ticks = 0;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return GestureDetector(
      onTap: () {
        LpHaptics.tick();
        widget.onTap();
      },
      onLongPressStart: widget.repeatOnHold ? (_) => _tick() : null,
      onLongPressEnd: widget.repeatOnHold ? (_) => _stop() : null,
      onLongPressCancel: widget.repeatOnHold ? _stop : null,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: lp.surface,
          border: Border.all(color: lp.border, width: 1.5),
        ),
        child: Icon(widget.icon, color: widget.color),
      ),
    );
  }
}
