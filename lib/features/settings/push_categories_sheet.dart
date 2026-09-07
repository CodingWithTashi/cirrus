import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_haptics.dart';
import '../../core/widgets/lp_buttons.dart';
import '../../core/widgets/lp_card.dart';
import '../../data/api/firebase/push_service.dart';
import '../../data/stores/providers.dart';
import '../../domain/analytics/lp_events.dart';

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

  /// An OS prompt already in flight. The button is awaited twice over
  /// (`requestPermission`, then `permissionStatus`) and stays tappable
  /// throughout without this — two taps on a slow cold start would race two
  /// requests and, worse, file two `notifPrompt` events for ONE decision,
  /// which is a funnel this app reads its launch gates off.
  bool _asking = false;

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
              if (_permission == PushPermission.notAsked && enabled) ...[
                const SizedBox(height: 12),
                // The opposite of the branch above, and the hole it left.
                //
                // The OS prompt only ever fires from onboarding's D4 step and
                // from the sheet after a community post. Somebody who signed
                // in on a NEW device never sees either — their journey is
                // restored, so onboarding is skipped — and every switch below
                // was live while the OS had never been asked and no FCM token
                // could be minted. The screen said notifications were on, the
                // registry had no device, and nothing could arrive. That is
                // the exact state a reinstall leaves, so it is the state a
                // founder testing on a real phone hits every single time.
                //
                // Here it is a working button rather than a signpost, because
                // `notAsked` is the one status where the OS dialog still opens.
                //
                // Gated on `enabled` — the master switch — for a reason that
                // is easy to miss: turning notifications off calls
                // `PushService.deleteToken()`, which is the half that actually
                // guarantees this device goes quiet. Granting here would mint
                // a fresh token and re-register the device, undoing that,
                // while every switch below stayed visibly disabled. The button
                // would have appeared to do nothing and silently done the one
                // thing the user had just asked us not to.
                LpButton(
                  l10n.pushAskCta,
                  busy: _asking,
                  onTap: _asking
                      ? null
                      : () async {
                          setState(() => _asking = true);
                          final granted = await PushService.requestPermission();
                          if (!mounted) return;
                          ref
                              .read(analyticsProvider)
                              .notifPrompt(granted: granted);
                          // Register the freshly minted token now; the
                          // alternative is the next resume or cold start, and
                          // somebody who came here deliberately should not
                          // have to relaunch. Through the registrar because
                          // on iOS the token is usually not available yet at
                          // the instant the sheet returns — see the same CTA
                          // in onboarding.
                          if (granted) {
                            ref
                                .read(pushTokenRegistrarProvider)
                                .onPermissionGranted();
                          }
                          final next = await PushService.permissionStatus();
                          if (!mounted) return;
                          setState(() {
                            _permission = next;
                            _asking = false;
                          });
                        },
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
