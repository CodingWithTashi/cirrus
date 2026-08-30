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
import '../../core/utils/lp_haptics.dart';
import '../../core/utils/lp_pricing.dart';
import '../../core/widgets/lp_buttons.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_error.dart';
import '../../core/widgets/lp_misc.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/providers.dart';
import '../../domain/analytics/lp_events.dart';
import '../../domain/models/models.dart';
import '../onboarding/onboarding_view_model.dart';

enum _Tier { yearly, monthly, weekly }

/// D5 — hard-converting layout, honest mechanics: reminder toggle ships ON,
/// the Free path is visible, never hidden (docs/02 §4).
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  _Tier _selected = _Tier.yearly;
  bool _busy = false;

  bool get _fromOnboarding => ref.read(quitStoreProvider) == null;

  @override
  void initState() {
    super.initState();
    // `variant` is the A/B slot docs/06 §3's paywall tests read. There is one
    // layout today, so it is named rather than left blank — an empty string
    // would make the first test's data indistinguishable from history.
    ref.read(analyticsProvider).paywallViewed('d5_default');
  }

  void _leave(GoRouter router) => leavePaywall(router);

  Future<void> _startTrial() async {
    unawaited(LpHaptics.celebrate());
    // Reported at the moment of intent, before the (currently non-existent)
    // billing round-trip, so trial-start rate stays comparable once
    // RevenueCat lands and the call can fail.
    ref.read(analyticsProvider).trialStarted(_selected.name);
    if (_fromOnboarding) {
      setState(() => _busy = true);
      try {
        await ref
            .read(onboardingProvider.notifier)
            .completeWithTier(SubscriptionTier.trial);
      } on Exception catch (error) {
        // Onboarding draft survives a failed start — retry loses nothing.
        if (!mounted) return;
        setState(() => _busy = false);
        await showLpErrorDialog(context, error: error, onRetry: _startTrial);
        return;
      }
      if (!mounted) return;
      context.go(Routes.day1);
    } else {
      // Leave FIRST, then change the tier. See `leavePaywall`.
      _leave(GoRouter.of(context));
      ref.read(quitStoreProvider.notifier).setTier(SubscriptionTier.premium);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final settings = ref.watch(settingsStoreProvider);

    Widget feature(String label) => Row(
      children: [
        Text('✓', style: LpType.body13(lp.voltText, weight: FontWeight.w700)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: LpType.caption(lp.textBody),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    Widget planCard({
      required _Tier tier,
      required String name,
      required String price,
      String? sub,
      Color? subColor,
      bool best = false,
    }) {
      final selected = _selected == tier;
      return PressScale(
        onTap: () => setState(() => _selected = tier),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: LpMotion.fast,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: lp.surface,
                borderRadius: BorderRadius.circular(LpDimens.rCard),
                border: Border.all(
                  color: selected ? lp.voltFocus : lp.border,
                  width: selected ? 2 : 1.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: lp.volt.withValues(alpha: 0.2),
                          blurRadius: 26,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: LpType.heading(lp.textPrimary, size: 16),
                        ),
                        if (sub != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            sub,
                            style: LpType.caption(
                              subColor ?? lp.voltText,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(price, style: LpType.number(lp.textPrimary, size: 20)),
                  const SizedBox(width: 10),
                  AnimatedContainer(
                    duration: LpMotion.fast,
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? lp.volt : Colors.transparent,
                      border: selected
                          ? null
                          : Border.all(color: lp.border, width: 1.5),
                    ),
                    child: selected
                        ? Text(
                            '✓',
                            style: TextStyle(
                              color: lp.onVolt,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            if (best)
              Positioned(
                top: -10,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: lp.volt,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    l10n.paywallYearlyBadge,
                    style: LpType.micro(
                      lp.onVolt,
                      weight: FontWeight.w700,
                    ).copyWith(letterSpacing: 1),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.paywallTitle,
                style: LpType.title(lp.textPrimary, size: 26),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.paywallSubtitle,
                style: LpType.body13(lp.textSecondary),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: feature(l10n.paywallFeatCoach)),
                  const SizedBox(width: 12),
                  Expanded(child: feature(l10n.paywallFeatPanic)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: feature(l10n.paywallFeatPlan)),
                  const SizedBox(width: 12),
                  Expanded(child: feature(l10n.paywallFeatForecasts)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: feature(l10n.paywallFeatCommunity)),
                  const SizedBox(width: 12),
                  Expanded(child: feature(l10n.paywallFeatReports)),
                ],
              ),
              const SizedBox(height: 16),
              planCard(
                tier: _Tier.yearly,
                name: l10n.paywallYearly,
                price: LpPricing.yearly,
                sub: l10n.paywallYearlySub,
                best: true,
              ),
              const SizedBox(height: 9),
              planCard(
                tier: _Tier.monthly,
                name: l10n.paywallMonthly,
                price: LpPricing.monthly,
              ),
              const SizedBox(height: 9),
              planCard(
                tier: _Tier.weekly,
                name: l10n.paywallWeekly,
                price: LpPricing.weekly,
                sub: l10n.paywallWeeklySub,
                subColor: lp.emberText,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: lp.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: lp.border, width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.paywallTrialReminder,
                        style: LpType.caption(lp.textBody),
                      ),
                    ),
                    Switch(
                      value: settings.trialReminderOn,
                      onChanged: (v) => ref
                          .read(settingsStoreProvider.notifier)
                          .setTrialReminder(v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '${l10n.paywallCancelAnytime} · ${l10n.paywallAnchor}',
                  style: LpType.caption11(lp.textSecondary),
                ),
              ),
              const Spacer(),
              LpButton(
                l10n.paywallCta,
                height: 54,
                busy: _busy,
                onTap: _startTrial,
              ),
              const SizedBox(height: 6),
              LpTextButton(
                l10n.paywallFreeLink,
                size: 12,
                onTap: () => context.push(Routes.paywallFree),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// D5b — pure positive framing of Free. No guilt copy anywhere.
class FreePlanScreen extends ConsumerStatefulWidget {
  const FreePlanScreen({super.key});

  @override
  ConsumerState<FreePlanScreen> createState() => _FreePlanScreenState();
}

class _FreePlanScreenState extends ConsumerState<FreePlanScreen> {
  bool _busy = false;

  Future<void> _continueFree() async {
    ref.read(analyticsProvider).freeContinued();
    final fromOnboarding = ref.read(quitStoreProvider) == null;
    if (fromOnboarding) {
      setState(() => _busy = true);
      try {
        await ref
            .read(onboardingProvider.notifier)
            .completeWithTier(SubscriptionTier.free);
      } on Exception catch (error) {
        if (!mounted) return;
        setState(() => _busy = false);
        await showLpErrorDialog(context, error: error, onRetry: _continueFree);
        return;
      }
      if (!mounted) return;
      context.go(Routes.day1);
    } else {
      ref.read(quitStoreProvider.notifier).setTier(SubscriptionTier.free);
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;

    Widget item(String label) => Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: LpCard(
        radius: LpDimens.rInput,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Text(
              '✓',
              style: LpType.body15(lp.voltText, weight: FontWeight.w700),
            ),
            const SizedBox(width: 12),
            Text(label, style: LpType.body14(lp.textPrimary)),
          ],
        ),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.freePlanTitle, style: LpType.title(lp.textPrimary)),
              const SizedBox(height: 8),
              Text(
                l10n.freePlanSubtitle,
                style: LpType.body14(lp.textSecondary),
              ),
              const SizedBox(height: 26),
              item(l10n.freePlanFeat1),
              item(l10n.freePlanFeat2),
              item(l10n.freePlanFeat3),
              item(l10n.freePlanFeat4),
              item(l10n.freePlanFeat5),
              const Spacer(),
              LpNoteCard(l10n.freePlanUpgradeNote),
              const SizedBox(height: 14),
              LpButton(l10n.freePlanCta, busy: _busy, onTap: _continueFree),
            ],
          ),
        ),
      ),
    );
  }
}

/// D5c — one-time founding offer, and the copy says so: opening it burns it.
class WinbackScreen extends ConsumerStatefulWidget {
  const WinbackScreen({super.key});

  @override
  ConsumerState<WinbackScreen> createState() => _WinbackScreenState();
}

class _WinbackScreenState extends ConsumerState<WinbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsStoreProvider.notifier).markWinbackShown();
      ref.read(analyticsProvider).winbackShown();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: lp.emberSoft,
                    borderRadius: BorderRadius.circular(LpDimens.rChip),
                    border: Border.all(
                      color: lp.ember.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    l10n.winbackBadge,
                    style: LpType.caption11(
                      lp.emberText,
                      weight: FontWeight.w700,
                    ).copyWith(letterSpacing: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.winbackTitle,
                style: LpType.title(lp.textPrimary, size: 32),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.winbackSubtitle,
                style: LpType.body14(lp.textSecondary),
              ),
              const SizedBox(height: 26),
              LpCard(
                radius: LpDimens.rBento,
                borderColor: lp.ember,
                glowColor: lp.ember,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: LpPricing.monthly,
                            style: LpType.body14(
                              lp.textSecondary,
                            ).copyWith(decoration: TextDecoration.lineThrough),
                          ),
                          TextSpan(
                            text: ' ${l10n.winbackFirstMonth}',
                            style: LpType.body14(lp.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      LpPricing.foundingMonth,
                      style: LpType.numberHero(lp.emberText, size: 56).copyWith(
                        shadows: [
                          Shadow(
                            color: lp.ember.withValues(alpha: 0.4),
                            blurRadius: 32,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.winbackNote(
                        LpFormat.money(
                          LpPricing.monthlyUsd,
                          context.localeTag,
                          cents: true,
                        ),
                      ),
                      textAlign: TextAlign.center,
                      style: LpType.body13(lp.textSecondary),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              LpButton(
                l10n.winbackCta,
                onTap: () {
                  ref
                      .read(quitStoreProvider.notifier)
                      .setTier(SubscriptionTier.premium);
                  ref.read(analyticsProvider).winbackConverted();
                  LpHaptics.celebrate();
                  context.go(Routes.home);
                },
              ),
              const SizedBox(height: 6),
              LpTextButton(l10n.winbackDecline, onTap: () => context.pop()),
            ],
          ),
        ),
      ),
    );
  }
}

/// D5d — honest trial-ending reminder with the user's own 3-day wins.
class TrialEndingScreen extends ConsumerWidget {
  const TrialEndingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final snap = ref.watch(todayProvider);

    Widget stat(String value, String label) => Column(
      children: [
        Text(value, style: LpType.number(lp.voltText, size: 24)),
        const SizedBox(height: 2),
        Text(label, style: LpType.caption11(lp.textSecondary)),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: BackChevron(onTap: () => context.pop()),
              ),
              const SizedBox(height: 10),
              PushPreviewCard(
                time: l10n.trialEndingPushTime,
                body: l10n.trialEndingPush,
              ),
              const SizedBox(height: 24),
              Text(l10n.trialEndingTitle, style: LpType.title(lp.textPrimary)),
              const SizedBox(height: 10),
              Text(
                l10n.trialEndingBody,
                style: LpType.body14(lp.textSecondary),
              ),
              const SizedBox(height: 22),
              LpCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel(
                      l10n.trialEndingStatsLabel,
                      color: lp.voltText,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        stat(
                          LpFormat.signedPercent(snap?.vsDay1Percent ?? 0),
                          l10n.trialEndingVsDay1,
                        ),
                        stat(
                          '${snap?.cravingsSurvivedTotal ?? 0}',
                          l10n.trialEndingCravings,
                        ),
                        stat(
                          LpFormat.money(snap?.savedLifetime ?? 0, locale),
                          l10n.trialEndingSaved,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              LpButton(
                l10n.trialEndingKeep(LpPricing.yearly),
                onTap: () {
                  leavePaywall(GoRouter.of(context));
                  ref
                      .read(quitStoreProvider.notifier)
                      .setTier(SubscriptionTier.premium);
                  ref.read(analyticsProvider).trialStarted(_Tier.yearly.name);
                },
              ),
              const SizedBox(height: 6),
              LpTextButton(
                l10n.trialEndingSwitchFree,
                onTap: () {
                  leavePaywall(GoRouter.of(context));
                  ref
                      .read(quitStoreProvider.notifier)
                      .setTier(SubscriptionTier.free);
                  ref.read(analyticsProvider).freeContinued();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Closes a paywall. Call this BEFORE changing the tier, never after.
///
/// Changing the tier bumps the router's `refreshListenable`, and Riverpod
/// delivers that notification asynchronously — so a pop performed first was
/// undone a microtask later when the refresh rebuilt the match list and
/// restored the imperatively pushed entry. The user was left staring at the
/// paywall they had just paid past, with `canPop()` reporting true and the pop
/// visibly doing nothing.
///
/// Leaving first means the refresh recomputes from the destination instead.
void leavePaywall(GoRouter router) {
  // A paywall reached by a deep link has nothing beneath it.
  if (router.canPop()) {
    router.pop();
  } else {
    router.go(Routes.home);
  }
}
