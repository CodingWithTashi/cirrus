import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_palette.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../domain/analytics/lp_events.dart';
import '../../domain/logic/billing_catalog.dart';
import '../../core/utils/lp_links.dart';
import '../../core/utils/lp_format.dart';
import '../../core/utils/lp_haptics.dart';
import '../../core/widgets/lp_buttons.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_error.dart';
import '../../core/widgets/lp_misc.dart';
import '../../core/widgets/lp_selectables.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/providers.dart';
import '../../domain/models/models.dart';
import 'danger_hours_sheet.dart';
import '../../domain/logic/coach_name.dart';

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
    final entitlement = ref.watch(entitlementProvider);

    // Mode only. The family used to be named here ("Midnight"/"Daylight"),
    // which stopped being true the moment a family other than Ember existed.
    String appearanceValue() => switch (settings.themeMode) {
      ThemeMode.system => l10n.settingsAppearanceSystem,
      ThemeMode.dark => l10n.settingsAppearanceDark,
      ThemeMode.light => l10n.settingsAppearanceLight,
    };

    // The family the app is actually WEARING, not the one on disk: a lapsed
    // subscriber sees Ember here, because Ember is what they are looking at.
    String themeValue() => _paletteName(
      l10n,
      LpPaletteCatalog.resolveFor(
        settings.palette,
        premium: ref.watch(isPremiumProvider),
      ).id,
    );

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
            // Sits with the privacy controls, not with the coach: the reason
            // to open it is "what does this thing know about me", and the
            // answer belongs beside Export and Delete.
            // Renaming lives here rather than in the chat header: that header
            // is one mis-tap from a rename in the middle of a craving.
            row(
              emoji: '🔥',
              label: l10n.settingsCoachName,
              value: ref.watch(coachNameProvider) ?? l10n.coachName,
              onTap: () => _showRenameCoachSheet(context, ref),
            ),
            row(
              emoji: '🧠',
              label: l10n.settingsMemories(
                ref.watch(coachNameProvider) ?? l10n.coachName,
              ),
              value: '',
              onTap: () => context.push(Routes.memories),
            ),
            row(
              emoji: '👤',
              label: l10n.settingsAccount,
              value: journey?.profile.email ?? journey?.profile.alias ?? '',
            ),
            row(
              emoji: '💳',
              label: l10n.settingsSubscription,
              value: _subscriptionValue(l10n, entitlement, locale),
              // Free → the paywall (the founding offer, once, when it is
              // enabled — frame 22). Trial → the trial-ending screen. Paid →
              // the store's own manage page: cancelling and switching plans
              // happen there and nowhere else, which is also what both stores
              // require an app to offer.
              onTap: () {
                if (!entitlement.isActive) {
                  context.push(
                    BillingCatalog.foundingOfferEnabled && !settings.winbackShown
                        ? Routes.winback
                        : Routes.paywallFrom('settings'),
                  );
                } else if (entitlement.isTrial) {
                  context.push(Routes.trialEnding);
                } else {
                  _manageSubscription(context, entitlement);
                }
              },
            ),
            // Restore is a store requirement the day subscriptions ship
            // (S1-7): a reinstall or a new phone must be able to find a
            // subscription the store account already owns.
            if (!entitlement.isActive)
              row(
                emoji: '↩️',
                label: l10n.paywallRestore,
                value: '',
                onTap: () => _restorePurchases(context, ref),
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
                        // The hour they chose. The end hour used to show
                        // here too, but nothing reads it — the nudge is one
                        // push before the start (docs/09 issue 5).
                        l10n.settingsDangerHoursEdit(
                          LpFormat.hour(settings.dangerStartHour % 24, locale),
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
                    // Only Delete here. There was an "Export my data"
                    // button beside it that showed a success snack and
                    // exported nothing — a privacy control that lies is worse
                    // than one that is missing. It comes back when it writes a
                    // real file (docs/08 S5).
                    Row(
                      children: [
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
              emoji: '🌈',
              label: l10n.settingsTheme,
              value: themeValue(),
              onTap: () => _showThemeSheet(context, ref),
            ),
            row(
              emoji: '🌐',
              label: l10n.settingsLanguage,
              value: languageValue(),
              onTap: () => _showLanguageSheet(context, ref),
            ),
            // Founder-only. `isModeratorProvider` reads the signed token's
            // `admin` claim, so a non-admin never sees this row and a client
            // that forced the route would still be refused by the callables.
            if (ref.watch(isModeratorProvider).valueOrNull ?? false)
              row(
                emoji: '🛡️',
                label: l10n.moderationTitle,
                value: '',
                onTap: () => context.push(Routes.moderation),
              ),
            // The app used to be an island: no way to reach the site, the
            // policy, the terms or a person from anywhere inside it. Support
            // used to sit here and only show a snack, so it was deleted — this
            // one opens a real mail app AND prints the address underneath, so a
            // device with no mail client still leaves the reader somewhere to
            // write. A row that can only fail silently is worse than no row.
            row(
              emoji: '🌐',
              label: l10n.settingsWebsite,
              value: '',
              onTap: () => LpLinks.open(LpLinks.website).ignore(),
            ),
            row(
              emoji: '🔒',
              label: l10n.settingsPrivacyPolicy,
              value: '',
              onTap: () => LpLinks.open(LpLinks.privacy).ignore(),
            ),
            row(
              emoji: '📄',
              label: l10n.settingsTermsOfUse,
              value: '',
              onTap: () => LpLinks.open(LpLinks.terms).ignore(),
            ),
            row(
              emoji: '✉️',
              label: l10n.settingsSupport,
              value: '',
              onTap: () => LpLinks.open(LpLinks.support).ignore(),
              below: SizedBox(
                width: double.infinity,
                child: Text(
                  LpLinks.supportEmail,
                  style: LpType.caption(lp.textSecondary),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: LpTextButton(
                l10n.settingsSignOut,
                size: 14,
                onTap: () => _confirmSignOut(context, ref),
              ),
            ),
            if (ref.watch(appVersionProvider).valueOrNull case final version?)
              Center(
                child: Text(
                  l10n.appVersionFooter(version),
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
                option(ThemeMode.dark, l10n.settingsAppearanceDark, '🌑'),
                option(ThemeMode.light, l10n.settingsAppearanceLight, '☀️'),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _paletteName(AppLocalizations l10n, LpPalette id) =>
      switch (id) {
        LpPalette.ember => l10n.settingsThemeEmber,
        LpPalette.hearth => l10n.settingsThemeHearth,
        LpPalette.tide => l10n.settingsThemeTide,
      };

  static String _paletteBlurb(AppLocalizations l10n, LpPalette id) =>
      switch (id) {
        LpPalette.ember => l10n.settingsThemeEmberSub,
        LpPalette.hearth => l10n.settingsThemeHearthSub,
        LpPalette.tide => l10n.settingsThemeTideSub,
      };

  /// The palette-family picker.
  ///
  /// A `ConsumerStatefulWidget` rather than the flat builder the appearance
  /// sheet uses, because this one has to WATCH the tier: a purchase made
  /// through the lock card must unlock the cards underneath it without the
  /// reader reopening the sheet.
  void _showThemeSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ThemeSheet(),
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

/// The palette-family picker.
///
/// Locked families stay visible and stay tappable, which is the same call the
/// panic arena's `GameSwitcher` made and for the same reason: hiding them
/// would make the cleanest sheet and sell nothing, because nobody upgrades
/// for a feature they have never seen exist. Disabling them would answer the
/// tap with silence. So the tap is answered with the lock card.
///
/// Each card shows the family's REAL colours — ground, primary, streak, calm,
/// straight off `LpColors`. That is a truthful preview rather than a mock-up,
/// which is what lets a locked card carry its own argument.
class _ThemeSheet extends ConsumerStatefulWidget {
  const _ThemeSheet();

  @override
  ConsumerState<_ThemeSheet> createState() => _ThemeSheetState();
}

class _ThemeSheetState extends ConsumerState<_ThemeSheet> {
  /// The locked family whose card is open, if any. Cleared by a purchase.
  LpPalette? _locked;
  bool _reported = false;

  /// Where this reader is in their own quit — a dimension on the gate events.
  /// Read, never watched: watching would rebuild the sheet on every puff tap.
  int? get _planDay {
    final journey = ref.read(quitStoreProvider);
    if (journey == null) return null;
    return journey.plan.dayNumber(ref.read(nowProvider)());
  }

  void _tap(PaletteEntry entry, bool premium) {
    // A locked family answers with the card, not with silence and not by
    // being worn for a second. Nothing is committed: they never had it, and a
    // stored choice they were never entitled to would surface the day they
    // subscribed for something else entirely.
    if (entry.premium && !premium) {
      // No second `gateShown` here. The impression was counted when the sheet
      // opened; counting the tap as another one would cap
      // `gate_tapped/gate_shown` at 50% for this door no matter how well it
      // converts, and that ratio is the only thing the event is for.
      LpHaptics.light();
      setState(() => _locked = entry.id);
      return;
    }
    ref.read(settingsStoreProvider.notifier).setPalette(entry.id);
    Navigator.of(context).pop();
  }

  void _openPaywall() {
    const source = 'theme';
    ref.read(analyticsProvider).gateTapped(source);
    // Pop first, push second. `showModalBottomSheet` pushes an imperative
    // `ModalBottomSheetRoute` onto the same navigator go_router drives, so a
    // `context.push` under a live sheet is asking two route stacks to
    // interleave — the arena can unlock in place because it is a screen, not
    // a sheet. Returning from the paywall lands on Settings, where the Theme
    // row is one tap away and already reads the new tier.
    Navigator.of(context).pop();
    context.push(Routes.paywallFrom(source));
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    // Watched, not read: an entitlement can arrive while this sheet is open
    // without anyone touching it — a restore, the `rcWebhook` mirror landing,
    // a purchase made on another device — and a lock card still sitting over
    // a family they now own would be a lie.
    final premium = ref.watch(isPremiumProvider);
    final current = LpPaletteCatalog.resolveFor(
      ref.watch(settingsStoreProvider).palette,
      premium: premium,
    ).id;
    if (premium && _locked != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _locked = null);
      });
    }
    if (!_reported) {
      _reported = true;
      // Fires whether or not a locked card is opened, so the sheet's own
      // view-to-tap rate is readable. Deferred a frame: `build` must stay
      // free of side effects and a sink can reach a platform channel.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !premium) {
          ref.read(analyticsProvider).gateShown('theme', planDay: _planDay);
        }
      });
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.settingsTheme, style: LpType.titleSm(lp.textPrimary)),
            const SizedBox(height: 16),
            for (final entry in LpPaletteCatalog.entries) ...[
              _PaletteCard(
                entry: entry,
                selected: current == entry.id,
                locked: entry.premium && !premium,
                onTap: () => _tap(entry, premium),
              ),
              const SizedBox(height: 10),
            ],
            if (_locked != null) ...[
              const SizedBox(height: 2),
              LpNoteCard(l10n.settingsThemeLocked),
              const SizedBox(height: 12),
              LpButton(l10n.premiumLockCta, glow: false, onTap: _openPaywall),
            ],
          ],
        ),
      ),
    );
  }
}

/// One family's card: its name, its blurb, and four real swatches.
class _PaletteCard extends StatelessWidget {
  const _PaletteCard({
    required this.entry,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final PaletteEntry entry;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    // Swatches come from the mode the reader is actually looking at, so the
    // preview matches what tapping would produce rather than always showing
    // the dark half of a family.
    final preview = lp.isDark ? entry.dark : entry.light;
    return OptionCard(
      selected: selected,
      onTap: onTap,
      title: SettingsScreen._paletteName(l10n, entry.id),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      SettingsScreen._paletteName(l10n, entry.id),
                      style: LpType.emphasis(
                        selected ? lp.voltText : lp.textPrimary,
                        size: 16,
                      ),
                    ),
                    if (locked) ...[
                      const SizedBox(width: 7),
                      Icon(Icons.lock_outline, size: 14, color: lp.textFaint),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  SettingsScreen._paletteBlurb(l10n, entry.id),
                  style: LpType.body13(lp.textSecondary),
                ),
                const SizedBox(height: 10),
                _Swatches(preview: preview),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SelectCheck(selected: selected),
        ],
      ),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.preview});

  final LpColors preview;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    Widget dot(Color c, {double width = 22}) => Container(
      width: width,
      height: 22,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: lp.border),
      ),
    );
    return Row(
      children: [
        dot(preview.background, width: 34),
        const SizedBox(width: 5),
        dot(preview.surface),
        const SizedBox(width: 5),
        dot(preview.volt),
        const SizedBox(width: 5),
        dot(preview.ember),
        const SizedBox(width: 5),
        dot(preview.oxygen),
      ],
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

/// Renaming the coach after onboarding.
///
/// Memories and stored transcripts are deliberately NOT rewritten. Memories
/// are third-person facts about the user, and rewriting stored model output
/// would falsify a transcript — it *was* called that then. The greeting
/// re-renders for free (it is template-resolved at render time) and the next
/// model turn uses the new name immediately, so the only thing that looks back
/// is the history, which is the one thing that should.
void _showRenameCoachSheet(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  final current = ref.read(coachNameProvider);
  final field = TextEditingController(text: current ?? '');
  var busy = false;
  var rejected = false;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        final lp = context.lp;
        final typed = field.text;
        final error = switch (CoachName.validate(typed)) {
          CoachNameError.empty => typed.trim().isEmpty ? '' : '',
          CoachNameError.tooLong => l10n.obCoachNameErrorLong,
          CoachNameError.badCharacters => l10n.obCoachNameErrorChars,
          null => rejected ? l10n.obCoachNameErrorRejected : '',
        };
        final blocked = typed.trim().isEmpty || error.isNotEmpty;

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                l10n.settingsCoachName,
                style: LpType.titleSm(lp.textPrimary),
              ),
              const SizedBox(height: 16),
              LpField(
                label: l10n.obCoachNameFieldLabel,
                controller: field,
                hint: l10n.coachName,
                onChanged: (_) => setSheetState(() => rejected = false),
              ),
              SizedBox(
                height: 22,
                child: error.isEmpty
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          error,
                          style: LpType.caption(lp.cautionText),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              LpButton(
                l10n.commonSave,
                busy: busy,
                onTap: blocked
                    ? null
                    : () async {
                        setSheetState(() => busy = true);
                        final name = CoachName.normalize(field.text);
                        final ok = await ref
                            .read(quitStoreProvider.notifier)
                            .reserveCoachName(name);
                        if (!context.mounted) return;
                        if (!ok) {
                          setSheetState(() {
                            busy = false;
                            rejected = true;
                          });
                          return;
                        }
                        Navigator.of(context).pop();
                        // A snack, not a coach bubble: this is the app
                        // acknowledging a settings change, and a synthetic
                        // message in the thread would not survive a restore —
                        // a small lie about what was actually said.
                        showLpSnack(context, l10n.coachRenamed(name));
                      },
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// The subscription row's value, from the entitlement alone — never from a
/// plan name the app wrote down for itself.
String _subscriptionValue(
  AppLocalizations l10n,
  Entitlement entitlement,
  String locale,
) {
  if (!entitlement.isActive) return l10n.settingsSubscriptionFree;
  final ends = entitlement.expiresAt;
  if (entitlement.isTrial) {
    return ends == null
        ? l10n.settingsSubscriptionPremium
        : l10n.settingsSubscriptionTrial(LpFormat.mediumDate(ends, locale));
  }
  if (!entitlement.willRenew && ends != null) {
    return l10n.settingsSubscriptionEnds(LpFormat.mediumDate(ends, locale));
  }
  return switch (entitlement.period) {
    PlanPeriod.yearly => l10n.settingsSubscriptionYearly,
    PlanPeriod.monthly => l10n.settingsSubscriptionMonthly,
    PlanPeriod.weekly => l10n.settingsSubscriptionWeekly,
    null => l10n.settingsSubscriptionPremium,
  };
}

/// Opens the store's manage-subscription page. Null when the store gave us
/// none — a family-shared or promotional grant — and the honest answer then
/// is to say where it can be managed, not to fake a page.
void _manageSubscription(BuildContext context, Entitlement entitlement) {
  final url = entitlement.managementUrl;
  if (url == null) {
    showLpSnack(context, context.l10n.settingsManageUnavailable);
    return;
  }
  LpLinks.open(url).ignore();
}

/// One restore at a time: two quick taps must not run two.
bool _restoreInFlight = false;

Future<void> _restorePurchases(BuildContext context, WidgetRef ref) async {
  if (_restoreInFlight) return;
  _restoreInFlight = true;
  final l10n = context.l10n;
  try {
    final restored = await ref.read(entitlementProvider.notifier).restore();
    if (!context.mounted) return;
    showLpSnack(
      context,
      restored.isActive ? l10n.paywallRestored : l10n.paywallRestoreNothing,
    );
  } on Exception catch (error) {
    if (!context.mounted) return;
    await showLpErrorDialog(context, error: error);
  }
}
