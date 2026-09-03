import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
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
import '../../core/utils/lp_links.dart';
import '../../core/utils/lp_pricing.dart';
import '../../core/widgets/lp_buttons.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_error.dart';
import '../../core/widgets/lp_misc.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/providers.dart';
import '../../domain/analytics/analytics.dart';
import '../../domain/analytics/lp_events.dart';
import '../../core/widgets/lp_charts.dart';
import '../../domain/logic/plan_reveal.dart';
import '../../domain/logic/billing_catalog.dart';
import '../../domain/logic/pricing_math.dart';
import '../../domain/models/models.dart';
import '../onboarding/onboarding_view_model.dart';

/// D5 — hard-converting layout, honest mechanics: reminder toggle ships ON,
/// the Free path is visible, never hidden (docs/02 §4).
///
/// Every price on this screen is the store's (`offeringsProvider`), and the
/// CTA opens the store's own payment sheet through `EntitlementStore`. The
/// founder-locked figures in `LpPricing` appear only when the store cannot be
/// reached, under a caption that says so.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, this.source = 'direct'});

  /// The door this paywall was reached through (`Routes.paywallFrom`).
  /// Analytics only; nothing on the screen changes with it.
  final String source;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

/// What the paywall actually rendered. Not an A/B arm — an arm adds values
/// here — but three genuinely different offers a person can be shown.
const String _variantLive = 'd5_default';
const String _variantFallback = 'd5_fallback';
const String _variantLoading = 'd5_loading';

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  PlanPeriod _selected = PlanPeriod.yearly;
  bool _busy = false;
  bool _restoring = false;

  /// The variant to report, set on the first build that knows whether the
  /// store answered. Null means it never did.
  String? _pendingVariant;

  /// Whether `paywall_viewed` has actually gone out. Distinct from
  /// [_pendingVariant] on purpose: the send is deferred a frame, and a pop
  /// inside that frame would otherwise leave the view scheduled, unsent, and
  /// silently skipped by both paths.
  bool _viewSent = false;

  /// A purchase completed, or the free path was taken on purpose. Either way
  /// this screen did its job and leaving is not a dismissal.
  bool _resolved = false;

  /// Captured in [initState]: Riverpod forbids `ref` in `dispose`, and both
  /// of this screen's closing events fire from there.
  late final AnalyticsSink _analytics;

  /// Where this reader was in their own quit when the paywall opened. Read
  /// once, for the same reason — and it cannot meaningfully change while a
  /// paywall is on screen. Null before a journey exists (the D5 paywall).
  int? _planDay;

  bool get _fromOnboarding => ref.read(quitStoreProvider) == null;

  @override
  void initState() {
    super.initState();
    _analytics = ref.read(analyticsProvider);
    final journey = ref.read(quitStoreProvider);
    _planDay = journey?.plan.dayNumber(ref.read(nowProvider)());
  }

  /// `paywall_viewed`, once, with what was actually on screen.
  ///
  /// Held back until the offering has resolved, because the variant is a fact
  /// about the rendered page: a paywall showing the typed fallback prices
  /// under their "prices unavailable" caption is a different offer from one
  /// showing live store prices, it happens in production, and it converts
  /// differently. The dimension used to be the constant `d5_default`, so every
  /// chart cut by it had exactly one bucket.
  ///
  /// Fired from a post-frame callback, never from `build` itself: a sink can
  /// reach a platform channel, and `build` has to stay free of side effects —
  /// the same rule `LpPremiumGate` follows for `gate_shown`.
  void _reportView({required bool live, required bool loading}) {
    if (_pendingVariant != null || loading) return;
    _pendingVariant = live ? _variantLive : _variantFallback;
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendView());
  }

  /// Sends the view exactly once, from whichever path gets there first.
  ///
  /// Touches no `ref`: [dispose] calls this too, and Riverpod forbids `ref`
  /// there. Everything it needs was captured in [initState].
  void _sendView() {
    if (_viewSent) return;
    _viewSent = true;
    _analytics.paywallViewed(
      // Never resolved means the store never answered — its own variant, not
      // one of the other two.
      _pendingVariant ?? _variantLoading,
      source: widget.source,
      planDay: _planDay,
    );
  }

  @override
  void dispose() {
    // A paywall closed before the store ever answered is still a paywall
    // somebody saw, and losing it would understate every door's denominator.
    // `d5_loading` gets its own variant rather than being folded into either
    // of the others: a spike in it means the store is slow, which is a
    // conversion problem with a completely different fix.
    //
    // This also covers the narrow race the deferral opens: a pop inside the
    // frame the send was queued for. `_sendView` is idempotent, so whichever
    // of the two arrives first wins and the other is a no-op.
    _sendView();
    // Left without buying and without choosing Free. `purchase_cancelled`
    // only ever fired once the STORE sheet had opened, so backing out of the
    // paywall itself was invisible — and for the launch paywall, which nobody
    // asked for, this is the number that says whether it is a door or a nag.
    if (!_resolved) {
      _analytics.paywallDismissed(
        source: widget.source,
        plan: _selected.name,
      );
    }
    super.dispose();
  }

  /// The entitlement arrived while the paywall was up — a pending payment
  /// the store just settled, a restore made on another device, a renewal.
  /// Nothing left to sell: close the door the way a purchase would have.
  void _onEntitlementArrived() {
    // Not while this screen is itself completing a purchase or a restore —
    // those paths leave on their own, and a second leave pops whatever is
    // under the paywall (Settings, a gated screen). And not while a dialog or
    // the Free screen sits on top: `leavePaywall` pops the top-most route.
    if (!mounted || _busy || _restoring) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final router = GoRouter.of(context);
    // A restore, a renewal, a pending payment that settled: nothing left to
    // sell, so this close is not an abandonment either.
    _resolved = true;
    showLpSnack(context, context.l10n.paywallRestored);
    if (_fromOnboarding) {
      setState(() => _busy = true);
      unawaited(_finishOnboarding());
    } else {
      leavePaywall(router);
    }
  }

  /// Purchase first, journey second. A cancelled sheet leaves a guest on the
  /// paywall with the plan cards, the Free path and the onboarding draft all
  /// intact — no orphaned free journey, no `trial_started` followed by an
  /// unexplained free account.
  Future<void> _startTrial() {
    unawaited(LpHaptics.celebrate());
    // Reported at the moment of intent, before the store sheet, so the
    // trial-start rate stays comparable with the pre-billing funnel. What the
    // sheet did is the `purchase_*` family, fired by the store. Once per tap:
    // a retry after a store failure re-runs the purchase, not the intent.
    //
    // Deliberately NOT `_resolved`: opening the sheet and backing out and then
    // leaving IS a dismissal, and the pair (`purchase_cancelled` then
    // `paywall_dismissed`) is what separates "tried and thought better of it"
    // from "never engaged at all".
    ref.read(analyticsProvider).trialStarted(_selected.name);
    return _purchaseSelected();
  }

  Future<void> _purchaseSelected() async {
    // Captured before any await: the router must not be looked up through a
    // context that may be gone (paywall_test pins this).
    final router = GoRouter.of(context);
    final fromOnboarding = _fromOnboarding;
    final l10n = context.l10n;
    setState(() => _busy = true);
    final PurchaseOutcome outcome;
    try {
      outcome = await ref
          .read(entitlementProvider.notifier)
          .purchase(BillingCatalog.packageOf(_selected));
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      await showLpErrorDialog(
        context,
        error: error,
        onRetry: _purchaseSelected,
      );
      return;
    }
    if (!mounted) return;
    switch (outcome) {
      case PurchaseCancelled():
        // They closed the sheet. Stay put; nothing to say.
        setState(() => _busy = false);
      case PurchasePending():
        // The store accepted the order but has not settled it. Access arrives
        // through the entitlement stream when it does; claiming it now would
        // be a lie the next screen has to walk back.
        setState(() => _busy = false);
        showLpSnack(context, l10n.paywallPurchasePending);
      case PurchaseCompleted():
        // Bought. Leaving now is the screen finishing, not a dismissal.
        _resolved = true;
        if (fromOnboarding) {
          await _finishOnboarding();
        } else {
          // Leave FIRST. See `leavePaywall`.
          leavePaywall(router);
        }
    }
  }

  /// The journey, once the store has said yes. Retried on its own: a journey
  /// that failed to create must never re-open the sheet — the entitlement is
  /// already held, and `EntitlementStore.purchase` answers it without a sheet
  /// on the next tap anyway.
  Future<void> _finishOnboarding() async {
    // Busy for the whole of it, including a retry from the dialog: a live
    // CTA here would answer the held entitlement without a sheet and run a
    // second `complete()` alongside this one.
    if (!_busy) setState(() => _busy = true);
    try {
      await ref.read(onboardingProvider.notifier).complete();
    } on Exception catch (error) {
      // Onboarding draft survives a failed start — retry loses nothing.
      if (!mounted) return;
      setState(() => _busy = false);
      await showLpErrorDialog(
        context,
        error: error,
        onRetry: _finishOnboarding,
      );
      return;
    }
    if (!mounted) return;
    context.go(Routes.day1);
  }

  Future<void> _restore() async {
    if (_restoring) return;
    final router = GoRouter.of(context);
    final fromOnboarding = _fromOnboarding;
    final l10n = context.l10n;
    setState(() => _restoring = true);
    try {
      final restored = await ref.read(entitlementProvider.notifier).restore();
      if (!mounted) return;
      if (!restored.isActive) {
        // A normal answer, said out loud — never a silent no-op.
        showLpSnack(context, l10n.paywallRestoreNothing);
        return;
      }
      showLpSnack(context, l10n.paywallRestored);
      if (fromOnboarding) {
        await _finishOnboarding();
      } else {
        leavePaywall(router);
      }
    } on Exception catch (error) {
      if (!mounted) return;
      await showLpErrorDialog(context, error: error);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final settings = ref.watch(settingsStoreProvider);
    // What the coordinator will actually schedule: the trial toggle AND the
    // master notifications switch (`ReminderCoordinator.sync`).
    final reminderOn = settings.trialReminderOn && settings.notificationsOn;
    ref.listen<Entitlement>(entitlementProvider, (previous, next) {
      if (next.isActive && !(previous?.isActive ?? false)) {
        _onEntitlementArrived();
      }
    });
    final offeringAsync = ref.watch(offeringsProvider);
    final offering = offeringAsync.valueOrNull;
    // An offering with no plans is not a live price list — it is the store
    // having nothing to sell, and the typed fallbacks with their caption say
    // so more honestly than an empty card list under a live disclosure.
    final live = offering != null && offering.plans.isNotEmpty;
    final loading = offeringAsync.isLoading && !live;
    _reportView(live: live, loading: loading);

    BillingPlan? plan(PlanPeriod period) => offering?[period];
    // Only the plans the store actually offers get a card. A period missing
    // from a LIVE offering (a store config gap, a storefront without it) must
    // not fall back to a typed price — that is an invented number next to
    // real ones — and the selection can never point at a plan with no card.
    final periods = live
        ? [
            for (final period in PlanPeriod.values)
              if (plan(period) != null) period,
          ]
        : PlanPeriod.values;
    if (live && periods.isNotEmpty && !periods.contains(_selected)) {
      _selected = periods.first;
    }
    String fallbackPrice(PlanPeriod period) => switch (period) {
      PlanPeriod.yearly => LpPricing.yearly,
      PlanPeriod.monthly => LpPricing.monthly,
      PlanPeriod.weekly => LpPricing.weekly,
    };
    double fallbackAmount(PlanPeriod period) => switch (period) {
      PlanPeriod.yearly => LpPricing.yearlyUsd,
      PlanPeriod.monthly => LpPricing.monthlyUsd,
      PlanPeriod.weekly => LpPricing.weeklyUsd,
    };
    String priceOf(PlanPeriod period) =>
        plan(period)?.price ?? fallbackPrice(period);
    double amountOf(PlanPeriod period) =>
        plan(period)?.priceAmount ?? fallbackAmount(period);
    String? currencyOf(PlanPeriod period) =>
        live ? plan(period)?.currencyCode : 'USD';

    // The trial length is the store's, per plan and per user — someone who
    // already used an intro offer is offered none. Only the fixed-copy
    // fallback assumes the configured length.
    final int? trialDays = live
        ? plan(_selected)?.trialDays
        : LpPricing.trialDays;
    final periodWord = switch (_selected) {
      PlanPeriod.yearly => l10n.paywallPeriodYear,
      PlanPeriod.monthly => l10n.paywallPeriodMonth,
      PlanPeriod.weekly => l10n.paywallPeriodWeek,
    };
    final storeName = switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => l10n.paywallStoreApple,
      _ => l10n.paywallStoreGoogle,
    };
    // What the timeline's last beat quotes: the selected plan's price with
    // its period.
    final chargePrice = switch (_selected) {
      PlanPeriod.yearly => l10n.paywallPerYear(priceOf(PlanPeriod.yearly)),
      PlanPeriod.monthly => l10n.paywallPerMonth(priceOf(PlanPeriod.monthly)),
      PlanPeriod.weekly => l10n.paywallPerWeek(priceOf(PlanPeriod.weekly)),
    };

    // The yearly card's sub-line is derived from the amounts on screen —
    // never typed in. The store formats the per-week figure for a live plan
    // when it can; otherwise it is divided out of the store's own amount, in
    // the store's own currency. The fallback is USD.
    final yearlyPlan = plan(PlanPeriod.yearly);
    final String? perWeek = loading
        ? null
        : yearlyPlan != null
        ? yearlyPlan.pricePerWeek ??
              LpFormat.moneyIn(
                PricingMath.perWeek(yearlyPlan.priceAmount),
                locale,
                yearlyPlan.currencyCode,
              )
        : LpFormat.money(
            PricingMath.perWeek(LpPricing.yearlyUsd),
            locale,
            cents: true,
          );
    final savings = loading
        ? null
        : PricingMath.yearlySavingsPercent(
            yearly: amountOf(PlanPeriod.yearly),
            weekly: amountOf(PlanPeriod.weekly),
            yearlyCurrency: currencyOf(PlanPeriod.yearly),
            weeklyCurrency: currencyOf(PlanPeriod.weekly),
          );
    final yearlySub = perWeek == null
        ? null
        : savings == null
        ? l10n.paywallYearlySubPerWeek(perWeek)
        : l10n.paywallYearlySubLive(perWeek, savings);

    final ctaLabel = switch (trialDays) {
      null => l10n.paywallCtaSubscribe,
      // "Start my free week" for the configured length; the plural key
      // covers every other length an A/B variant might set.
      7 => l10n.paywallCta,
      final days => l10n.paywallCtaTrial(days),
    };
    final subtitle = trialDays == null
        ? l10n.paywallSubtitleNoTrial
        : l10n.paywallSubtitleTrial(trialDays);
    final disclosure = trialDays == null
        ? l10n.paywallDisclosure(priceOf(_selected), periodWord, storeName)
        : l10n.paywallDisclosureTrial(
            priceOf(_selected),
            periodWord,
            trialDays,
            storeName,
          );

    // Sep 1 field test (docs/09 issue 4): the eye landed on $39.99 before it
    // landed on what it buys. The features are the hero now — full-width
    // rows, benefit first, nothing truncated — and the plans are slim rows
    // below a trial timeline. The page scrolls; the CTA is pinned.
    Widget feature(IconData icon, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: lp.voltSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: lp.voltText),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: LpType.body14(lp.textPrimary))),
        ],
      ),
    );

    Widget planCard({
      required PlanPeriod period,
      required String name,
      String? sub,
      Color? subColor,
      bool best = false,
    }) {
      final selected = _selected == period;
      return PressScale(
        onTap: () {
          if (_selected == period) return;
          setState(() => _selected = period);
          // What people CONSIDER, as opposed to what they buy — the gap
          // between the two is the whole question behind the price ladder,
          // and `trial_started` only ever reported the winner.
          ref
              .read(analyticsProvider)
              .planSelected(period.name, source: widget.source);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: LpMotion.fast,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
                          style: LpType.heading(lp.textPrimary, size: 15),
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
                  // No number until the store has answered: a USD figure
                  // flashing before a EUR one is a wrong price, briefly.
                  Text(
                    loading ? '' : priceOf(period),
                    style: LpType.number(lp.textPrimary, size: 18),
                  ),
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

    // Caption-sized text with a finger-sized target: reviewers look for
    // Restore specifically, and a 12px hit area fails the tap the first time.
    Widget restoreLink() => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _restoring ? null : _restore,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Text(
          l10n.paywallRestore,
          style: LpType.caption(
            _restoring ? lp.textFaint : lp.textSecondary,
          ).copyWith(decoration: TextDecoration.underline),
        ),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // "Your plan is ready" is the end of onboarding; a
                    // returning free user (launch, a gate, Settings) gets the
                    // upgrade framing instead.
                    Text(
                      _fromOnboarding
                          ? l10n.paywallTitle
                          : l10n.paywallTitleUpgrade,
                      style: LpType.title(lp.textPrimary, size: 26),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: LpType.body13(lp.textSecondary)),
                    const SizedBox(height: 18),
                    // Their own plan, above the generic list. This runs WITH
                    // the Sep 1 decision that features out-rank pricing
                    // (docs/09 #4), not against it: the order is now their
                    // numbers, then what Premium adds, then the price.
                    const _PlanRevealCard(),
                    feature(Icons.auto_awesome, l10n.paywallFeatCoach),
                    feature(Icons.bolt, l10n.paywallFeatPanic),
                    feature(Icons.forum_outlined, l10n.paywallFeatCommunity),
                    feature(Icons.trending_down, l10n.paywallFeatPlan),
                    feature(Icons.schedule, l10n.paywallFeatForecasts),
                    feature(Icons.bar_chart, l10n.paywallFeatReports),
                    const SizedBox(height: 8),
                    if (trialDays != null && !loading)
                      _TrialTimeline(
                        chargePrice: chargePrice,
                        trialDays: trialDays,
                        remind: reminderOn,
                      ),
                    const SizedBox(height: 18),
                    for (final (i, period) in periods.indexed) ...[
                      if (i > 0) const SizedBox(height: 9),
                      switch (period) {
                        PlanPeriod.yearly => planCard(
                          period: period,
                          name: l10n.paywallYearly,
                          sub: yearlySub,
                          best: true,
                        ),
                        PlanPeriod.monthly => planCard(
                          period: period,
                          name: l10n.paywallMonthly,
                        ),
                        // "Founding price — locked forever" is a promise the
                        // founding offer makes; without that offer it is an
                        // invented claim, so it renders only with it.
                        PlanPeriod.weekly => planCard(
                          period: period,
                          name: l10n.paywallWeekly,
                          sub: BillingCatalog.foundingOfferEnabled
                              ? l10n.paywallWeeklySub
                              : null,
                          subColor: lp.emberText,
                        ),
                      },
                    ],
                    // "We'll remind you before your trial ends" is a promise
                    // about a trial; when the store offers none to this user
                    // (used up, or a product without one) there is nothing to
                    // remind about, and the row would be a small lie.
                    if (trialDays != null && !loading) ...[
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
                              value: reminderOn,
                              onChanged: (v) {
                                final store = ref.read(
                                  settingsStoreProvider.notifier,
                                );
                                // Asking for this reminder is asking for
                                // notifications; the master switch off would
                                // otherwise leave the row ON and the alarm
                                // never set.
                                if (v) store.setNotifications(true);
                                store.setTrialReminder(v);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    // The disclosure both stores require on the surface that
                    // holds the purchase button: price, period, auto-renewal,
                    // how to cancel, and the legal links — plus Restore.
                    const SizedBox(height: 12),
                    if (!loading)
                      Text(
                        disclosure,
                        style: LpType.caption11(lp.textSecondary),
                      ),
                    if (!live && !loading) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.paywallPricesUnavailable,
                        style: LpType.caption11(lp.textFaint),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        LpLegalLink(label: l10n.authTerms, url: LpLinks.terms),
                        LpLegalLink(
                          label: l10n.authPrivacy,
                          url: LpLinks.privacy,
                        ),
                        restoreLink(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Pinned: the offer and the way out are visible at every scroll
            // position, on every phone height.
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      '${l10n.paywallCancelAnytime} · ${l10n.paywallAnchor}',
                      style: LpType.caption11(lp.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  LpButton(
                    ctaLabel,
                    height: 54,
                    // Busy while the prices load too: a disabled-looking
                    // button that still sinks on press reads as broken.
                    busy: _busy || loading,
                    onTap: loading ? null : _startTrial,
                  ),
                  const SizedBox(height: 6),
                  LpTextButton(
                    l10n.paywallFreeLink,
                    size: 12,
                    onTap: () {
                      // Choosing Free on purpose is an answer, not an
                      // abandonment; `free_continued` is its event.
                      _resolved = true;
                      context.push(Routes.paywallFree);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The trial as three beats — today, the reminder, the first charge — so the
/// reminder toggle explains itself and "cancel before, pay nothing" is said
/// where the price is.
///
/// Copy about the offer, on the same footing as the CTA. The reminder beat is
/// the day before the charge: that is when the on-device reminder fires, and
/// its own copy says "ends tomorrow". The charge is the store's.
/// The user's own plan, on the screen that asks them for money.
///
/// Onboarding step 16 computes a Freedom Day, a projected saving, the puffs a
/// taper removes and the shape of the curve — then the paywall four screens
/// later opened with six generic feature rows and a price, and none of it
/// followed. This is the strongest thing the funnel knows about a person, and
/// it was being dropped immediately before the ask.
///
/// Every figure comes from [PlanReveal], the same source `RevealStep` reads, so
/// the two screens cannot quote different numbers at the same person.
class _PlanRevealCard extends ConsumerWidget {
  const _PlanRevealCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;

    // A returning free user has a real journey. During onboarding the journey
    // does not exist yet — it is created by `complete()` on this very screen —
    // so the draft is the only source there is. The `??` is lazy, so a signed-in
    // user never touches the onboarding provider at all.
    final journey = ref.watch(quitStoreProvider);
    final plan =
        journey?.plan ?? ref.read(onboardingProvider.notifier).draftPlan();
    final reveal = PlanReveal.of(plan, now: ref.read(nowProvider)());

    // Nothing honest to show: the launch paywall can open before any journey
    // or any answers exist. An empty state beats a Freedom Day derived from a
    // baseline of zero, which would be inventing the user's own data.
    if (reveal == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: LpCard(
        radius: LpDimens.rCardLg,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.paywallRevealLabel,
              style: LpType.caption11(
                lp.voltText,
                weight: FontWeight.w600,
              ).copyWith(letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            // Static, unlike the reveal screen's. The curve already drew itself
            // once; replaying it here would read as decoration rather than as
            // the plan they just committed to.
            TaperCurveChart(samples: reveal.curve, height: 54, animate: false),
            const SizedBox(height: 10),
            Text(
              l10n.obRevealMilestoneFreedom(
                LpFormat.shortDate(reveal.freedomDate, locale),
              ),
              style: LpType.caption(lp.textPrimary, weight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // Spend is a required onboarding answer, so this is present on
                // every real path — but "$0 saved" is honest and useless, so
                // the tile simply goes away rather than showing a zero.
                if (reveal.hasSaving) ...[
                  Expanded(
                    child: _stat(
                      context,
                      LpFormat.money(reveal.projectedSaved, locale),
                      l10n.obRevealSavedLabel,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: _stat(
                    context,
                    LpFormat.integer(reveal.puffsAvoided, locale),
                    l10n.obRevealPuffsLabel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final lp = context.lp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: LpType.number(lp.voltText, size: 22)),
        const SizedBox(height: 2),
        Text(
          label,
          style: LpType.caption11(lp.textSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _TrialTimeline extends StatelessWidget {
  const _TrialTimeline({
    required this.chargePrice,
    required this.trialDays,
    required this.remind,
  });

  /// Already carries its period ("$39.99/yr"), for the plan selected above.
  final String chargePrice;

  /// The store's trial length for the selected plan.
  final int trialDays;

  /// Whether a reminder will actually be scheduled. The middle beat promises
  /// one only when it is true; otherwise it names the last free day to cancel.
  final bool remind;

  static const double _dot = 12;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final remindDay = math.max(1, trialDays - 1);
    final steps = [
      (l10n.paywallTimelineToday, l10n.paywallTimelineTodayBody, true),
      (
        l10n.paywallTimelineDay(remindDay),
        remind
            ? l10n.paywallTimelineRemindBody
            : l10n.paywallTimelineNoRemindBody,
        false,
      ),
      (
        l10n.paywallTimelineDay(trialDays),
        l10n.paywallTimelineChargeBody(chargePrice),
        false,
      ),
    ];
    return LpCard(
      subtle: true,
      radius: LpDimens.rCard,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      child: Column(
        children: [
          // The track runs between the first and last dot centres. Positioned
          // children are excluded from intrinsic sizing, so this is safe
          // under any ancestor that measures (see the IntrinsicHeight gotcha).
          LayoutBuilder(
            builder: (context, constraints) {
              final sixth = constraints.maxWidth / 6;
              return SizedBox(
                height: _dot,
                child: Stack(
                  children: [
                    Positioned(
                      left: sixth,
                      right: sixth,
                      top: _dot / 2 - 1,
                      child: Container(height: 2, color: lp.border),
                    ),
                    Row(
                      children: [
                        for (final (_, _, now) in steps)
                          Expanded(
                            child: Center(
                              child: Container(
                                width: _dot,
                                height: _dot,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: now ? lp.volt : lp.surface,
                                  border: Border.all(
                                    color: now ? lp.volt : lp.voltText,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, body, _) in steps)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: LpType.caption(
                          lp.textPrimary,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: LpType.caption11(lp.textSecondary),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
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
        await ref.read(onboardingProvider.notifier).complete();
      } on Exception catch (error) {
        if (!mounted) return;
        setState(() => _busy = false);
        await showLpErrorDialog(context, error: error, onRetry: _continueFree);
        return;
      }
      if (!mounted) return;
      context.go(Routes.day1);
    } else {
      // Nothing to write: "free" is the absence of an entitlement, and the
      // entitlement is the store's to grant.
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
///
/// Gated off behind [BillingCatalog.foundingOfferEnabled] until the $3.99
/// first month exists as a store offer (tracker S4-7): until then the sheet
/// would charge the full monthly price under a card that promises less, and
/// a control that claims what it does not do is worse than none.
class WinbackScreen extends ConsumerStatefulWidget {
  const WinbackScreen({super.key});

  @override
  ConsumerState<WinbackScreen> createState() => _WinbackScreenState();
}

class _WinbackScreenState extends ConsumerState<WinbackScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsStoreProvider.notifier).markWinbackShown();
      ref.read(analyticsProvider).winbackShown();
    });
  }

  Future<void> _claim() async {
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    try {
      final outcome = await ref
          .read(entitlementProvider.notifier)
          .purchase(BillingCatalog.monthlyPackage);
      if (!mounted) return;
      if (outcome is PurchaseCompleted) {
        ref.read(analyticsProvider).winbackConverted();
        unawaited(LpHaptics.celebrate());
        router.go(Routes.home);
        return;
      }
      setState(() => _busy = false);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      await showLpErrorDialog(context, error: error);
    }
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
              LpButton(l10n.winbackCta, busy: _busy, onTap: _claim),
              const SizedBox(height: 6),
              LpTextButton(l10n.winbackDecline, onTap: () => context.pop()),
            ],
          ),
        ),
      ),
    );
  }
}

/// D5d — honest trial-ending reminder with the user's own first-week wins.
///
/// Reached from Settings while the entitlement is a trial. Keeping Premium
/// needs no action (the trial renews on its own), so "Keep" simply leaves;
/// switching to Free IS cancelling, which only the store can do, so that
/// button opens the store's manage page.
class TrialEndingScreen extends ConsumerWidget {
  const TrialEndingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final snap = ref.watch(todayProvider);
    final entitlement = ref.watch(entitlementProvider);
    final ends = entitlement.expiresAt;

    Widget stat(String value, String label) => Column(
      children: [
        Text(value, style: LpType.number(lp.voltText, size: 24)),
        const SizedBox(height: 2),
        Text(label, style: LpType.caption11(lp.textSecondary)),
      ],
    );

    void switchToFree() {
      final url = entitlement.managementUrl;
      if (url == null) {
        showLpSnack(context, l10n.settingsManageUnavailable);
        return;
      }
      LpLinks.open(url).ignore();
    }

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
              Text(
                ends == null
                    ? l10n.trialEndingTitle
                    : l10n.trialEndsOn(LpFormat.mediumDate(ends, locale)),
                style: LpType.title(lp.textPrimary),
              ),
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
                l10n.trialEndingKeep,
                onTap: () => leavePaywall(GoRouter.of(context)),
              ),
              const SizedBox(height: 6),
              LpTextButton(l10n.trialEndingSwitchFree, onTap: switchToFree),
            ],
          ),
        ),
      ),
    );
  }
}

/// Closes a paywall. Call this BEFORE anything that bumps the router's
/// `refreshListenable`, never after.
///
/// Changing journey state bumps that listenable, and Riverpod delivers the
/// notification asynchronously — so a pop performed first was undone a
/// microtask later when the refresh rebuilt the match list and restored the
/// imperatively pushed entry. The user was left staring at the paywall they
/// had just paid past, with `canPop()` reporting true and the pop visibly
/// doing nothing.
///
/// The entitlement itself is deliberately NOT wired into that listenable
/// (`EntitlementStore`), so a purchase can complete and this can run in
/// either order; the rule stands for the journey writes around it.
void leavePaywall(GoRouter router) {
  // A paywall reached by a deep link has nothing beneath it.
  if (router.canPop()) {
    router.pop();
  } else {
    router.go(Routes.home);
  }
}
