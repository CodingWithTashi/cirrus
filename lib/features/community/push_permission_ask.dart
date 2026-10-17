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

/// Why this ask is happening — which decides the words on the sheet.
///
/// [community]: they just posted or replied, and want to hear back.
/// [dayOne]: they just finished the Day-1 checklist, and the evening
/// check-in is tonight. [survived]: they just beat a craving, and the next
/// one is coming.
enum PushAskReason { community, dayOne, survived }

/// Asks for notification permission at the moments it obviously pays.
///
/// Somebody has just put something into the community, finished their first
/// day's setup, or beaten a craving — and is, right now, the most likely they
/// will ever be to want what notifications bring. Onboarding's D4 screen asks
/// earlier and keeps asking earlier — this is the second chance for the people
/// who tapped "Maybe later" there, which never opened the OS dialog at all.
/// 11 of 20 real people declined at D4 in the Oct 5 2026 read, and until
/// Oct 16 the community was the only second chance, so somebody who never
/// posted never got one (docs/03 §8's re-ask after a survived craving was
/// documented and not built).
///
/// Three rules, and each one exists because breaking it makes things worse:
///
/// * **Only when the status is `notAsked`.** Android auto-denies a second
///   `requestPermission()` after two dismissals without showing anything, so
///   asking a refused user is a button that visibly does nothing. Their route
///   back is system settings, which the notifications sheet says.
/// * **Only once, ever** — across every [PushAskReason]: whichever moment
///   comes first is the one. Tracked in `SettingsState`, so it survives a
///   restart. A prompt that returns after every post is how an app teaches
///   people to refuse it.
/// * **After the content is away.** The post is already published and the
///   screen already left; this is a card on top of what happened, never
///   something standing between a person and posting.
Future<void> maybeAskPushPermission(
  BuildContext context,
  WidgetRef ref, {
  PushAskReason reason = PushAskReason.community,
}) async {
  final settings = ref.read(settingsStoreProvider);
  // Nothing to gain from asking somebody who has switched notifications off
  // in our own settings — they have already answered this question.
  if (settings.pushPromptShown || !settings.notificationsOn) return;
  // No OS to ask: the fake backend, desktop and web.
  final permissions = ref.read(pushPermissionsProvider);
  if (permissions == null) return;
  if (await permissions.status() != PushPermission.notAsked) return;
  if (!context.mounted) return;

  ref.read(settingsStoreProvider.notifier).markPushPromptShown();
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    // Its own height, not the default 9/16 of the screen: the Day-1 and
    // Survived copy run longer than the community line did, and on a small
    // phone the capped sheet pushed "Maybe later" off the bottom.
    isScrollControlled: true,
    builder: (_) => _AskSheet(reason),
  );
  if (accepted != true) {
    ref.read(analyticsProvider).notifPrompt(granted: false);
    return;
  }

  final granted = await permissions.request();
  ref.read(analyticsProvider).notifPrompt(granted: granted);
  // Register the freshly minted token now: the alternative is waiting for the
  // next resume or cold start, which loses the first day of replies — exactly
  // the day the post they just wrote is being answered.
  if (granted) ref.read(pushTokenRegistrarProvider).onPermissionGranted();
}

class _AskSheet extends StatelessWidget {
  const _AskSheet(this.reason);

  final PushAskReason reason;

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
              Text(
                switch (reason) {
                  PushAskReason.community => l10n.pushAskTitle,
                  PushAskReason.dayOne => l10n.pushAskDayOneTitle,
                  PushAskReason.survived => l10n.pushAskSurvivedTitle,
                },
                style: LpType.title(lp.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                switch (reason) {
                  PushAskReason.community => l10n.pushAskBody,
                  PushAskReason.dayOne => l10n.pushAskDayOneBody,
                  PushAskReason.survived => l10n.pushAskSurvivedBody,
                },
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
