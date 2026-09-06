import 'dart:math' as math;

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
import '../../core/widgets/confetti_burst.dart';
import '../../core/widgets/lp_buttons.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/providers.dart';
import '../../domain/logic/games/game_id.dart';

/// The beat between the store sheet closing and wherever the person was
/// going: Premium is theirs, here is what that means, and every line is a
/// door into it (docs/10 §28).
///
/// Shown for every COMPLETED purchase — the paywall's CTA, the win-back
/// card, an onboarding purchase, and a pending payment that settles while
/// the paywall is still up — and never for `PurchasePending`, whose honest
/// "payment is pending" snack stays. A restore keeps its "welcome back" snack:
/// nothing new was bought, and a fanfare would be wrong.
///
/// Reached with `pushReplacement` over the paywall, so back can never land
/// on a paywall the person has just paid past; its CTA pops to whatever was
/// under that paywall, or goes Home when nothing was.
///
/// Every word on it already exists: the seven `paywallFeat*` lines, the
/// charge date from `entitlement.expiresAt` (the same instant the trial
/// reminder is planned from), and the reminder sentence only when that
/// toggle — and the master switch — are on. No new numbers.
class PremiumWelcomeScreen extends ConsumerStatefulWidget {
  const PremiumWelcomeScreen({super.key, this.onboarding = false});

  /// Reached on the way out of onboarding: the Day-1 checklist is next, and
  /// the rows are not doors — the router sends the shell tabs back to the
  /// checklist until it is done, so a door here would open onto the wrong
  /// screen.
  final bool onboarding;

  @override
  ConsumerState<PremiumWelcomeScreen> createState() =>
      _PremiumWelcomeScreenState();
}

class _PremiumWelcomeScreenState extends ConsumerState<PremiumWelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const _lead = Duration(milliseconds: 250);
  static const _stagger = Duration(milliseconds: 80);
  static const _rowDuration = Duration(milliseconds: 500);

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: _lead + _stagger * (_Unlock.values.length - 1) + _rowDuration,
  );
  bool _revealStarted = false;

  @override
  void initState() {
    super.initState();
    LpHaptics.celebrate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_revealStarted) return;
    _revealStarted = true;
    // Rows tick in one after another — or are simply there, under reduced
    // motion, and for anyone who reads faster than they animate.
    if (MediaQuery.disableAnimationsOf(context)) {
      _reveal.value = 1;
    } else {
      _reveal.forward();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  /// One curve per row, built once: a rebuild (the entitlement or a setting
  /// changing under the screen) must not attach seven fresh listeners.
  late final List<Animation<double>> _rows = [
    for (var i = 0; i < _Unlock.values.length; i++) _row(i),
  ];

  Animation<double> _row(int index) {
    final total = _reveal.duration!.inMilliseconds;
    final from = _lead.inMilliseconds + index * _stagger.inMilliseconds;
    return CurvedAnimation(
      parent: _reveal,
      curve: Interval(
        from / total,
        (from + _rowDuration.inMilliseconds) / total,
        curve: LpMotion.ease,
      ),
    );
  }

  void _leave() {
    if (widget.onboarding) {
      context.go(Routes.day1);
      return;
    }
    final router = GoRouter.of(context);
    // Same fallback as `leavePaywall`: a paywall reached by a deep link had
    // nothing beneath it, and neither does its welcome.
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(Routes.home);
    }
  }

  /// Days left on the trial, from the store's own end. The entitlement
  /// carries no length, and the catalogue's is only the fallback for a store
  /// that did not say.
  static int _trialDays(DateTime? ends, DateTime now) {
    if (ends == null) return LpPricing.trialDays;
    final minutes = ends.difference(now).inMinutes;
    return math.max(1, (minutes / Duration.minutesPerDay).round());
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final entitlement = ref.watch(entitlementProvider);
    final settings = ref.watch(settingsStoreProvider);
    final now = ref.read(nowProvider)();
    final trial = entitlement.isTrial;
    final ends = entitlement.expiresAt;
    // What the coordinator will actually schedule: the trial toggle AND the
    // master notifications switch.
    final reminderOn = settings.trialReminderOn && settings.notificationsOn;
    final days = trial ? _trialDays(ends, now) : null;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          Center(child: _Eyebrow(l10n.premiumWelcomeEyebrow)),
                          const SizedBox(height: 16),
                          Text(
                            l10n.premiumWelcomeTitle,
                            textAlign: TextAlign.center,
                            style: LpType.title(lp.textPrimary, size: 36),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            days != null
                                ? l10n.premiumWelcomeTrialBody(days)
                                : l10n.premiumWelcomeBody,
                            textAlign: TextAlign.center,
                            style: LpType.body15(lp.textSecondary),
                          ),
                          const SizedBox(height: 22),
                          LpCard(
                            radius: LpDimens.rCardLg,
                            padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SectionLabel(
                                  l10n.premiumWelcomeUnlocks,
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    0,
                                    10,
                                    6,
                                  ),
                                ),
                                for (final (i, unlock)
                                    in _Unlock.values.indexed)
                                  _UnlockRow(
                                    unlock: unlock,
                                    label: unlock.label(l10n),
                                    animation: _rows[i],
                                    door: widget.onboarding
                                        ? null
                                        : () => unlock.open(context),
                                  ),
                              ],
                            ),
                          ),
                          if (trial && ends != null) ...[
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '🔔',
                                  style: TextStyle(fontSize: 15),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: l10n.premiumWelcomeCharge(
                                            LpFormat.shortDate(ends, locale),
                                          ),
                                          style: LpType.body13(
                                            lp.textPrimary,
                                            weight: FontWeight.w600,
                                          ),
                                        ),
                                        if (reminderOn)
                                          TextSpan(
                                            text:
                                                ' ${l10n.premiumWelcomeReminder}',
                                            style: LpType.body13(
                                              lp.textSecondary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LpButton(
                    widget.onboarding
                        ? l10n.premiumWelcomeCtaDay1
                        : l10n.premiumWelcomeCta,
                    onTap: _leave,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.paywallCancelAnytime,
                    textAlign: TextAlign.center,
                    style: LpType.caption11(lp.textFaint),
                  ),
                ],
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(child: ConfettiBurst()),
          ),
        ],
      ),
    );
  }
}

/// The seven lines the paywall sells, in the order a new subscriber can act
/// on them: the coach first, then the two things visible without opening
/// anything (a theme, a game), then the ones that fill in with data.
enum _Unlock {
  coach('✨'),
  themes('🎨'),
  games('🎮'),
  forecasts('🔮'),
  plan('🔁'),
  report('📊'),
  community('🆘');

  const _Unlock(this.emoji);

  final String emoji;

  String label(AppLocalizations l10n) => switch (this) {
    coach => l10n.paywallFeatCoach,
    themes => l10n.paywallFeatThemes,
    games => l10n.paywallFeatPanic,
    forecasts => l10n.paywallFeatForecasts,
    plan => l10n.paywallFeatPlan,
    report => l10n.paywallFeatReports,
    community => l10n.paywallFeatCommunity,
  };

  /// Where the row leads. The shell tabs are `go`ne to — pushing one would
  /// stack a second shell — so the welcome is over when they open; the rest
  /// are pushed, so back returns here.
  void open(BuildContext context) {
    switch (this) {
      case coach:
        context.go(Routes.coach);
      case themes:
        context.push(Routes.settings);
      case games:
        context.push(Routes.gameFor(GameId.blocks));
      case forecasts:
        context.go(Routes.stats);
      case plan:
        context.push(Routes.plan);
      case report:
        context.push(Routes.insight);
      case community:
        context.go(Routes.community);
    }
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: lp.voltSoft,
        borderRadius: BorderRadius.circular(LpDimens.rChip),
        border: Border.all(color: lp.volt.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 12, color: lp.voltText),
          const SizedBox(width: 6),
          Text(text.toUpperCase(), style: LpType.label(lp.voltText)),
        ],
      ),
    );
  }
}

class _UnlockRow extends StatelessWidget {
  const _UnlockRow({
    required this.unlock,
    required this.label,
    required this.animation,
    this.door,
  });

  final _Unlock unlock;
  final String label;
  final Animation<double> animation;
  final VoidCallback? door;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: lp.voltSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(unlock.emoji, style: const TextStyle(fontSize: 17)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: LpType.body13(lp.textBody, weight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: lp.volt, shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, size: 12, color: lp.onVolt),
          ),
          if (door != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 20, color: lp.textFaint),
          ],
        ],
      ),
    );
    final animated = FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(animation),
        child: row,
      ),
    );
    final onTap = door;
    return onTap == null
        ? animated
        : PressScale(onTap: onTap, child: animated);
  }
}
