import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_dimens.dart';
import '../../../app/theme/lp_typography.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/lp_haptics.dart';
import '../../../core/widgets/lp_buttons.dart';
import '../../../core/widgets/lp_card.dart';
import '../../../core/widgets/lp_misc.dart';
import '../../../core/widgets/press_scale.dart';
import '../../../data/stores/providers.dart';
import '../../../domain/models/models.dart';

/// Frame 41 — mood check-in as a sheet: 5 emoji, optional note, unlock meter.
Future<void> showMoodSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => const _MoodSheet(),
  );
}

class _MoodSheet extends ConsumerStatefulWidget {
  const _MoodSheet();

  @override
  ConsumerState<_MoodSheet> createState() => _MoodSheetState();
}

class _MoodSheetState extends ConsumerState<_MoodSheet> {
  Mood? _selected;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  static const _emoji = {
    Mood.rough: '😖',
    Mood.meh: '😕',
    Mood.okay: '🙂',
    Mood.good: '😄',
    Mood.great: '🤩',
  };

  String _label(Mood m) => switch (m) {
    Mood.rough => context.l10n.moodRough,
    Mood.meh => context.l10n.moodMeh,
    Mood.okay => context.l10n.moodOkay,
    Mood.good => context.l10n.moodGood,
    Mood.great => context.l10n.moodGreat,
  };

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final checkIns = (ref.watch(quitStoreProvider)?.moodCheckIns ?? 0).clamp(
      0,
      7,
    );

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.moodTitle, style: LpType.title(lp.textPrimary, size: 28)),
          const SizedBox(height: 8),
          Text(l10n.moodSubtitle, style: LpType.body14(lp.textSecondary)),
          const SizedBox(height: 24),
          Row(
            children: [
              for (final mood in Mood.values) ...[
                if (mood != Mood.values.first) const SizedBox(width: 10),
                Expanded(
                  child: PressScale(
                    onTap: () => setState(() => _selected = mood),
                    child: AnimatedContainer(
                      duration: LpMotion.fast,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _selected == mood ? lp.voltSoft : lp.surface,
                        borderRadius: BorderRadius.circular(LpDimens.rCard),
                        border: Border.all(
                          color: _selected == mood ? lp.voltFocus : lp.border,
                          width: 1.5,
                        ),
                        boxShadow: _selected == mood
                            ? [
                                BoxShadow(
                                  color: lp.volt.withValues(alpha: 0.2),
                                  blurRadius: 16,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        children: [
                          Text(
                            _emoji[mood]!,
                            style: const TextStyle(fontSize: 26),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _label(mood),
                            style: LpType.micro(
                              _selected == mood
                                  ? lp.voltText
                                  : lp.textSecondary,
                              weight: _selected == mood
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          LpCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: TextField(
              controller: _note,
              style: LpType.body14(lp.textPrimary),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: l10n.moodNoteHint,
                hintStyle: LpType.body14(lp.textFaint),
              ),
            ),
          ),
          const SizedBox(height: 16),
          LpCard(
            subtle: true,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.moodUnlockTitle,
                      style: LpType.body13(
                        lp.textPrimary,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      l10n.moodUnlockProgress(checkIns, 7),
                      style: LpType.caption11(lp.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = 0; i < 7; i++) ...[
                      if (i > 0) const SizedBox(width: 5),
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: i < checkIns ? lp.volt : lp.border,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.moodUnlockNote((7 - checkIns).clamp(0, 7)),
                  style: LpType.caption11(lp.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          LpButton(
            l10n.moodCta,
            onTap: _selected == null
                ? null
                : () {
                    LpHaptics.medium();
                    ref
                        .read(quitStoreProvider.notifier)
                        .checkInMood(
                          _selected!,
                          note: _note.text.trim().isEmpty
                              ? null
                              : _note.text.trim(),
                        );
                    Navigator.of(context).pop();
                    showLpSnack(context, l10n.moodSaved);
                  },
          ),
        ],
      ),
    );
  }
}
