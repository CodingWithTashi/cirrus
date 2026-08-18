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
  Timer? _advance;

  @override
  void initState() {
    super.initState();
    _advance = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final hasJourney = ref.read(quitStoreProvider) != null;
      context.go(hasJourney ? Routes.home : Routes.auth);
    });
  }

  @override
  void dispose() {
    _advance?.cancel();
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
