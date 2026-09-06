import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/widgets/lp_buttons.dart';
import '../../core/widgets/lp_card.dart';
import '../../data/api/firebase/push_service.dart';
import '../../data/stores/providers.dart';
import '../../domain/analytics/lp_events.dart';

/// Asks for notification permission at the one moment it obviously pays.
///
/// Somebody has just put something into the community and is, right now, the
/// most likely they will ever be to want to hear back about it. Onboarding's
/// D4 screen asks earlier and keeps asking earlier — this is the second
/// chance for the people who tapped "Maybe later" there, which never opened
/// the OS dialog at all.
///
/// Three rules, and each one exists because breaking it makes things worse:
///
/// * **Only when the status is `notAsked`.** Android auto-denies a second
///   `requestPermission()` after two dismissals without showing anything, so
///   asking a refused user is a button that visibly does nothing. Their route
///   back is system settings, which the notifications sheet says.
/// * **Only once, ever.** Tracked in `SettingsState`, so it survives a
///   restart. A prompt that returns after every post is how an app teaches
///   people to refuse it.
/// * **After the content is away.** The post is already published and the
///   screen already left; this is a card on top of what happened, never
///   something standing between a person and posting.
Future<void> maybeAskPushPermission(
  BuildContext context,
  WidgetRef ref,
) async {
  final settings = ref.read(settingsStoreProvider);
  // Nothing to gain from asking somebody who has switched notifications off
  // in our own settings — they have already answered this question.
  if (settings.pushPromptShown || !settings.notificationsOn) return;
  if (await PushService.permissionStatus() != PushPermission.notAsked) return;
  if (!context.mounted) return;

  ref.read(settingsStoreProvider.notifier).markPushPromptShown();
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AskSheet(),
  );
  if (accepted != true) {
    ref.read(analyticsProvider).notifPrompt(granted: false);
    return;
  }

  final granted = await PushService.requestPermission();
  ref.read(analyticsProvider).notifPrompt(granted: granted);
  // Register the freshly minted token now: the alternative is waiting for the
  // next resume or cold start, which loses the first day of replies — exactly
  // the day the post they just wrote is being answered.
  if (granted) ref.read(userContextRepositoryProvider).sync().ignore();
}

class _AskSheet extends StatelessWidget {
  const _AskSheet();

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LpCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.pushAskTitle, style: LpType.title(lp.textPrimary)),
              const SizedBox(height: 8),
              Text(
                l10n.pushAskBody,
                style: LpType.body14(lp.textSecondary),
              ),
              const SizedBox(height: 18),
              LpButton(
                l10n.pushAskCta,
                onTap: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 4),
              LpTextButton(
                l10n.commonMaybeLater,
                onTap: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
