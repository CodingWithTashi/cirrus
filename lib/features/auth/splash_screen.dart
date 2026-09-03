import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/widgets/lp_misc.dart';
import '../../data/stores/providers.dart';
import '../../domain/date_key.dart';
import '../../domain/logic/launch_paywall_policy.dart';

/// Frame 25 — Volt glow breathes, wordmark fades up, auto-advances ~1.5s.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    unawaited(_advance());
  }

  /// Restores the backend session while the wordmark breathes — but never
  /// under the branding beat of 1.5s.
  Future<void> _advance() async {
    await Future.wait([
      Future<void>.delayed(const Duration(milliseconds: 1500)),
      ref.read(quitStoreProvider.notifier).restoreSession(),
    ]);
    if (!mounted) return;
    final journey = ref.read(quitStoreProvider);
    if (journey == null) {
      context.go(Routes.auth);
      return;
    }
    // The once-a-day launch paywall for free users (LaunchPaywallPolicy).
    // The billing backend gets a short, bounded wait to answer for this
    // session; if it has not, the policy treats the tier as unknown and shows
    // nothing — a paying user must never see a paywall for their own plan.
    final entitlements = ref.read(entitlementProvider.notifier);
    await entitlements.settled.timeout(
      const Duration(milliseconds: 2500),
      onTimeout: () {},
    );
    if (!mounted) return;
    final now = ref.read(nowProvider)();
    final today = LpDate.dayKey(now);
    final show = LaunchPaywallPolicy.shouldShow(
      hasJourney: true,
      planDay: journey.plan.dayNumber(now),
      settled: entitlements.isSettled,
      isPremium: ref.read(isPremiumProvider),
      lastShownDay: ref.read(settingsStoreProvider).launchPaywallShownDay,
      shownCount: ref.read(settingsStoreProvider).launchPaywallShownCount,
      today: today,
    );
    context.go(Routes.home);
    if (show) {
      ref.read(settingsStoreProvider.notifier).markLaunchPaywallShown(today);
      unawaited(context.push(Routes.paywallFrom('launch')));
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _breath,
            builder: (context, _) => Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    lp.volt.withValues(alpha: 0.10 + 0.07 * _breath.value),
                    lp.volt.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 400),
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - t)),
                child: child,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const VoltDot(size: 20),
                const SizedBox(height: 22),
                Text(
                  context.l10n.appName,
                  style: TextStyle(
                    fontFamily: LpType.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 44,
                    letterSpacing: -1.5,
                    color: lp.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  context.l10n.appTagline,
                  textAlign: TextAlign.center,
                  style: LpType.body15(lp.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
