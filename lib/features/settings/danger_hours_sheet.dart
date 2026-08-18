import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_format.dart';
import '../../core/utils/lp_haptics.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/providers.dart';

/// Danger-hours editor sheet — reachable from Settings AND by tapping the
/// Stats trigger-hours heatmap (frame 38 note: "Heatmap taps into
/// danger-hours editor").
void showDangerHoursSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      var start = ref.read(settingsStoreProvider).dangerStartHour;
      var span = (ref.read(settingsStoreProvider).dangerEndHour - start).clamp(
        1,
        6,
      );
      return StatefulBuilder(
        builder: (context, setState) {
          final lp = context.lp;
          final l10n = context.l10n;
          final locale = context.localeTag;
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
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
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    '${LpFormat.hour(start, locale)} – ${LpFormat.hour((start + span) % 24, locale)}',
                    style: LpType.number(lp.emberText, size: 28),
                  ),
                ),
                Slider(
                  value: start.toDouble(),
                  min: 12,
                  max: 26,
                  divisions: 14,
                  activeColor: lp.ember,
                  thumbColor: lp.ember,
                  onChanged: (v) {
                    LpHaptics.tick();
                    setState(() => start = v.round());
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.settingsQuietHours(
                    '${LpFormat.hour(23, locale)} – ${LpFormat.hour(8, locale)}',
                  ),
                  textAlign: TextAlign.center,
                  style: LpType.caption11(lp.textFaint),
                ),
                const SizedBox(height: 16),
                PressScale(
                  onTap: () {
                    ref
                        .read(settingsStoreProvider.notifier)
                        .setDangerWindow(
                          start % 24,
                          (start + span) % 24 == 0 ? 24 : start + span,
                        );
                    Navigator.of(sheetContext).pop();
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
          );
        },
      );
    },
  );
}
