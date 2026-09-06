import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_haptics.dart';
import '../../core/widgets/lp_card.dart';
import '../../data/api/firebase/push_service.dart';
import '../../data/stores/providers.dart';

/// What the SERVER is allowed to send, one switch per kind.
///
/// Separate from the danger-hours sheet beside it because the two settle
/// genuinely different questions. Danger hours are scheduled on the device,
/// work offline, and cost nothing; everything here is decided in a Cloud
/// Function and reaches the phone from outside. That distinction is not
/// cosmetic — a preference kept only on the device can silence the first kind
/// and is powerless over the second, which is exactly the bug the master
/// switch used to have.
///
/// So every toggle writes locally for an instant UI and rides
/// `syncUserContext` to `users/{uid}.pushPrefs`, which is what the send path
/// actually reads.
///
/// Quiet hours are deliberately NOT repeated here. They are one window, they
/// already live on the danger-hours sheet where they are drawn as a rail, and
/// a second editor for one setting is how two screens end up disagreeing.
void showPushCategoriesSheet(BuildContext context, WidgetRef ref) {
  LpHaptics.light();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _PushCategoriesSheet(),
  );
}

class _PushCategoriesSheet extends ConsumerStatefulWidget {
  const _PushCategoriesSheet();

  @override
  ConsumerState<_PushCategoriesSheet> createState() =>
      _PushCategoriesSheetState();
}

class _PushCategoriesSheetState extends ConsumerState<_PushCategoriesSheet> {
  /// Whether the OS will let anything through at all.
  ///
  /// Read rather than assumed: every switch on this sheet is a lie while the
  /// system permission is refused, and telling somebody their replies are on
  /// when the OS is dropping them is the kind of dishonesty this app's own
  /// rules single out.
  PushPermission? _permission;

  @override
  void initState() {
    super.initState();
    PushService.permissionStatus().then((value) {
      if (mounted) setState(() => _permission = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final settings = ref.watch(settingsStoreProvider);
    final store = ref.read(settingsStoreProvider.notifier);
    // The master switch already turns everything off; showing the categories
    // as live controls underneath it would misdescribe what happens next.
    final enabled = settings.notificationsOn;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: LpCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.settingsPushTitle,
                style: LpType.title(lp.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.settingsPushSubtitle,
                style: LpType.body13(lp.textSecondary),
              ),
              if (_permission == PushPermission.denied) ...[
                const SizedBox(height: 12),
                // Android auto-denies a second `requestPermission()` without
                // showing anything, so there is no button we could offer that
                // would work. Saying where the switch actually lives is the
                // only honest thing left.
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: lp.caution.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(LpDimens.rInput),
                  ),
                  child: Text(
                    l10n.settingsPushBlocked,
                    style: LpType.caption(lp.cautionText),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _Toggle(
                label: l10n.settingsPushReplies,
                note: l10n.settingsPushRepliesNote,
                value: settings.pushRepliesOn,
                enabled: enabled,
                onChanged: store.setPushReplies,
              ),
              _Toggle(
                label: l10n.settingsPushMentions,
                note: l10n.settingsPushMentionsNote,
                value: settings.pushMentionsOn,
                enabled: enabled,
                onChanged: store.setPushMentions,
              ),
              _Toggle(
                label: l10n.settingsPushWeekly,
                note: l10n.settingsPushWeeklyNote,
                value: settings.pushWeeklyOn,
                enabled: enabled,
                onChanged: store.setPushWeekly,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.note,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String note;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: LpType.body14(
                    enabled ? lp.textPrimary : lp.textSecondary,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(note, style: LpType.caption(lp.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: enabled && value,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
