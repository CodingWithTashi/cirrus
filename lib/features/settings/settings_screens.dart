import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_format.dart';
import '../../core/widgets/lp_buttons.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_error.dart';
import '../../core/widgets/lp_misc.dart';
import '../../core/widgets/lp_selectables.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/providers.dart';
import '../../domain/models/models.dart';
import 'danger_hours_sheet.dart';

/// Frame 50 — settings: account, subscription, notifications with the
/// danger-hours editor inline, privacy (export/delete one tap deep),
/// appearance, language. Delete is the only destructive red on the screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final settings = ref.watch(settingsStoreProvider);
    final journey = ref.watch(quitStoreProvider);
    final tier = journey?.profile.tier ?? SubscriptionTier.free;

    String appearanceValue() => switch (settings.themeMode) {
      ThemeMode.system => l10n.settingsAppearanceSystem,
      ThemeMode.dark => l10n.settingsAppearanceMidnight,
      ThemeMode.light => l10n.settingsAppearanceDaylight,
    };

    String languageValue() => settings.locale == null
        ? l10n.settingsLanguageSystem
        : _languageName(settings.locale!.languageCode);

    Widget row({
      required String emoji,
      required String label,
      String? value,
      Widget? trailing,
      VoidCallback? onTap,
      Widget? below,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: PressScale(
          onTap: onTap,
          child: LpCard(
            radius: LpDimens.rInput,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: LpType.body14(
                          lp.textPrimary,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (value != null)
                      Text('$value ›', style: LpType.caption(lp.textSecondary)),
                    ?trailing,
                  ],
                ),
                if (below != null) ...[const SizedBox(height: 10), below],
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackChevron(onTap: () => context.pop()),
        title: Text(l10n.settingsTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            row(
              emoji: '👤',
              label: l10n.settingsAccount,
              value: journey?.profile.email ?? journey?.profile.alias ?? '',
            ),
            row(
              emoji: '💳',
              label: l10n.settingsSubscription,
              value: tier == SubscriptionTier.free
                  ? l10n.settingsSubscriptionFree
                  : l10n.settingsSubscriptionValue,
              // Free tier sees the founding offer exactly once (frame 22);
              // after that, the regular paywall.
              onTap: () => context.push(
                tier != SubscriptionTier.free
                    ? Routes.trialEnding
                    : settings.winbackShown
                    ? Routes.paywall
                    : Routes.winback,
              ),
            ),
            row(
              emoji: '🔔',
              label: l10n.settingsNotifications,
              trailing: Switch(
                value: settings.notificationsOn,
                onChanged: (v) => ref
                    .read(settingsStoreProvider.notifier)
                    .setNotifications(v),
              ),
              below: PressScale(
                onTap: () => showDangerHoursSheet(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: lp.surfaceInset,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: lp.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.settingsDangerHours,
                        style: LpType.caption(lp.textSecondary),
                      ),
                      Text(
                        l10n.settingsDangerHoursEdit(
                          '${LpFormat.hour(settings.dangerStartHour, locale)} – ${LpFormat.hour(settings.dangerEndHour % 24, locale)}',
                        ),
                        style: LpType.caption(
                          lp.emberText,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LpCard(
                radius: LpDimens.rInput,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🔒', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 12),
                        Text(
                          l10n.settingsPrivacy,
                          style: LpType.body14(
                            lp.textPrimary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.settingsPrivacyNote,
                      style: LpType.caption(lp.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        PressScale(
                          onTap: () =>
                              showLpSnack(context, l10n.settingsExported),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: lp.surfaceInset,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: lp.border),
                            ),
                            child: Text(
                              l10n.settingsExportData,
                              style: LpType.caption11(
                                lp.textBody,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PressScale(
                          onTap: () => _confirmDelete(context, ref),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: lp.surfaceInset,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: lp.danger.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              l10n.settingsDeleteEverything,
                              style: LpType.caption11(
                                lp.dangerText,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            row(
              emoji: '🎨',
              label: l10n.settingsAppearance,
              value: appearanceValue(),
              onTap: () => _showAppearanceSheet(context, ref),
            ),
            row(
              emoji: '🌐',
              label: l10n.settingsLanguage,
              value: languageValue(),
              onTap: () => _showLanguageSheet(context, ref),
            ),
            row(
              emoji: '🗺️',
              label: l10n.frameMapTitle,
              value: '',
              onTap: () => context.push(Routes.frames),
            ),
            row(
              emoji: '💬',
              label: l10n.settingsSupport,
              value: '',
              onTap: () => showLpSnack(context, l10n.commonComingSoon),
            ),
            row(
              emoji: '↺',
              label: l10n.settingsRestorePurchases,
              value: '',
              onTap: () => showLpSnack(context, l10n.settingsRestored),
            ),
            const SizedBox(height: 10),
            Center(
              child: LpTextButton(
                l10n.settingsSignOut,
                size: 14,
                onTap: () => _confirmSignOut(context, ref),
              ),
            ),
            Center(
              child: Text(
                l10n.appVersionFooter('1.0.0'),
                style: LpType.caption11(lp.textFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Endonyms — the one list the value row and the picker sheet both use.
  static const _languages = {
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'pt': 'Português',
  };

  static String _languageName(String code) => _languages[code] ?? code;

  void _showAppearanceSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        final current = ref.read(settingsStoreProvider).themeMode;
        Widget option(ThemeMode mode, String label, String emoji) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OptionCard(
            selected: current == mode,
            onTap: () {
              ref.read(settingsStoreProvider.notifier).setThemeMode(mode);
              Navigator.of(sheetContext).pop();
            },
            title: '$emoji  $label',
          ),
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.settingsAppearance,
                  style: LpType.titleSm(sheetContext.lp.textPrimary),
                ),
                const SizedBox(height: 16),
                option(ThemeMode.system, l10n.settingsAppearanceSystem, '⚙️'),
                option(ThemeMode.dark, l10n.settingsAppearanceMidnight, '🌑'),
                option(ThemeMode.light, l10n.settingsAppearanceDaylight, '☀️'),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLanguageSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        final current = ref.read(settingsStoreProvider).locale;
        Widget option(Locale? locale, String label) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OptionCard(
            selected:
                current?.languageCode == locale?.languageCode &&
                (current == null) == (locale == null),
            onTap: () {
              ref.read(settingsStoreProvider.notifier).setLocale(locale);
              Navigator.of(sheetContext).pop();
            },
            title: label,
          ),
        );
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.settingsLanguage,
                  style: LpType.titleSm(sheetContext.lp.textPrimary),
                ),
                const SizedBox(height: 16),
                option(null, l10n.settingsLanguageSystem),
                for (final entry in _languages.entries)
                  option(Locale(entry.key), entry.value),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Drops the local session and lands back on auth. Shared by sign-out and
  /// the tail of a confirmed deletion so the two can't drift apart.
  static void _leaveJourney(BuildContext context, WidgetRef ref) {
    ref.invalidate(coachStoreProvider);
    ref.invalidate(communityStoreProvider);
    context.go(Routes.auth);
  }

  /// Deletion is the one destructive action here, and the only lifecycle CTA
  /// that awaits its backend ack. Sign-out can be optimistic — worst case the
  /// session lingers server-side for a moment. Erasure cannot: telling
  /// someone their data is gone and navigating away, while the request failed
  /// offline, is a lie the UI would never correct.
  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      // The request must survive a stray tap outside the sheet.
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountDialog(),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lp = context.lp;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsSignOutConfirmTitle),
        content: Text(l10n.settingsSignOutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              l10n.commonCancel,
              style: LpType.body14(lp.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(quitStoreProvider.notifier).signOut();
              _leaveJourney(context, ref);
            },
            child: Text(
              l10n.settingsSignOut,
              style: LpType.body14(lp.textPrimary, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// The delete-account confirmation, with a busy state, because deletion is
/// the one action here that waits on the network.
///
/// It runs `deleteUserData` server-side: the journey, the server-owned user
/// tree (entitlement, coach transcript, cravings, insights) and the uid↔post
/// mapping all go, and community posts are anonymized rather than removed so
/// the threads other quitters are reading don't develop holes (docs/03 §11).
class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  bool _busy = false;

  Future<void> _delete() async {
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      await ref.read(quitStoreProvider.notifier).deleteAccount();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      navigator.pop();
      // The account still exists and the user is still signed in — the
      // standard offline/generic copy is exactly right here, and the retry
      // is simply tapping Delete again.
      unawaited(showLpErrorDialog(context, error: error));
      return;
    }
    if (!mounted) return;
    navigator.pop();
    SettingsScreen._leaveJourney(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lp = context.lp;
    return AlertDialog(
      title: Text(l10n.settingsDeleteConfirmTitle),
      content: Text(l10n.settingsDeleteConfirmBody),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(
            l10n.commonCancel,
            style: LpType.body14(lp.textSecondary),
          ),
        ),
        TextButton(
          onPressed: _busy ? null : _delete,
          child: _busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: lp.dangerText,
                  ),
                )
              : Text(
                  l10n.settingsDeleteConfirmCta,
                  style: LpType.body14(lp.dangerText, weight: FontWeight.w600),
                ),
        ),
      ],
    );
  }
}
