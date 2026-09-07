import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../data/stores/providers.dart';
import '../../domain/date_key.dart';
import '../../domain/logic/launch_paywall_policy.dart';

/// Frame 25 — the Cirrus mark sealing into a zero over a breathing Volt glow,
/// wordmark fades up, auto-advances ~1.5s.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  /// The animated mark, so the widget test can find it without reaching into
  /// a private class. Nothing under `assets/images` is bundled any more: the
  /// mark is drawn, and everything in that folder is launcher-icon or
  /// store-listing source art read only by the generator in pubspec.yaml.
  static const markKey = ValueKey<String>('splashMark');

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  /// The C-to-zero seal. It runs ONCE and holds closed. The splash normally
  /// lives only the 1.5s `_advance()` waits out, but a cold `restoreSession()`
  /// can stretch that — and a mark that re-opened on a loop would read as a
  /// spinner, i.e. as waiting rather than as the brand resolving. It settles,
  /// then sits there while the glow keeps breathing.
  late final AnimationController _seal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

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
    // A tapped notification is waiting for this navigation to happen so it
    // can land on top. Showing the paywall would spend one of its
    // lifetime-capped slots on an impression the push immediately covers.
    final pushPending = ref.read(pushPendingProvider);
    final show = !pushPending && LaunchPaywallPolicy.shouldShow(
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
    _seal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    // The Scaffold hands its body LOOSE constraints, and a Stack under loose
    // constraints sizes itself to its largest non-positioned child. So a bare
    // `Stack(alignment: center)` here was a 340dp square parked in the
    // top-left corner of the screen, with the wordmark centred only within
    // *it*. Align fills the body first, then places the group — a touch above
    // the middle, where a lone mark reads as centred.
    return Scaffold(
      body: Align(
        alignment: const Alignment(0, -0.1),
        child: TweenAnimationBuilder<double>(
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
              _AppIcon(breath: _breath, seal: _seal),
              const SizedBox(height: 20),
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
              const SizedBox(height: 12),
              Text(
                context.l10n.appTagline,
                textAlign: TextAlign.center,
                style: LpType.body15(lp.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The mark over the breathing glow.
///
/// The glow is centred on the MARK, not on the group. It is far larger than
/// the mark, so it overflows the mark's box through an [OverflowBox]: the
/// Column measures only the mark and the wordmark sits at its natural
/// distance below, while the glow spills out behind everything.
class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.breath, required this.seal});

  final Animation<double> breath;
  final Animation<double> seal;

  static const double size = 98;
  static const double glowSize = 340;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return SizedBox(
      width: size,
      height: size * _MarkPainter.aspect,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: breath,
            builder: (context, _) => OverflowBox(
              maxWidth: glowSize,
              maxHeight: glowSize,
              child: Container(
                width: glowSize,
                height: glowSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      lp.volt.withValues(alpha: 0.10 + 0.07 * breath.value),
                      lp.volt.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Both glows breathe off the SAME controller value, uncurved, so
          // they stay locked in phase and in shape. Easing one and not the
          // other makes the two beat against each other at the turnaround.
          AnimatedBuilder(
            animation: Listenable.merge([breath, seal]),
            builder: (context, _) => CustomPaint(
              key: SplashScreen.markKey,
              size: const Size(size, size * _MarkPainter.aspect),
              painter: _MarkPainter(
                seal: seal.value,
                breath: breath.value,
                color: lp.volt,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Cirrus mark: the open ring that seals into a zero.
///
/// Transcribed from the design export (`cirrus-logo.svg`, viewBox
/// `200 240 600 640`): an ellipse at (484,560), rx 200 / ry 245, stroked 92
/// with round caps, tilted -8°, drawn over 84% of its circumference with the
/// gap at 3 o'clock — which is what makes it read as a C rather than as a
/// ring somebody forgot to finish. Sealing that gap is the whole animation.
///
/// It is painted rather than exported because the mark is [LpColors.volt] —
/// a ROLE, not a hue. The three palette families paint it lime, amber and
/// teal, and any baked asset (SVG, Lottie, Rive) would have to ship six
/// times to say the same thing.
class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.seal,
    required this.breath,
    required this.color,
  });

  /// Raw controller value; [_close] shapes it into 0 = open C, 1 = sealed.
  final double seal;

  /// Raw controller value, 0..1 and back.
  final double breath;

  /// The primary accent of the live palette.
  final Color color;

  /// The export's viewBox, verbatim.
  static const double _vbX = 200, _vbY = 240, _vbW = 600, _vbH = 640;
  static const double aspect = _vbH / _vbW;

  /// Hold the C long enough to be read, then close it. Against the 1400ms
  /// controller that is ~630ms open, ~560ms sealing and ~210ms settled — all
  /// of it inside the 1.5s branding beat `_advance()` waits out, so the seal
  /// is never cut off by the navigation.
  static const Interval _close = Interval(
    0.45,
    0.85,
    curve: Curves.easeInOutCubic,
  );

  /// The drawn fraction of the circumference: `stroke-dasharray="84 100"`
  /// against `pathLength="100"`.
  static const double _openSweep = 0.84;

  /// `stroke-dashoffset="4.9"` — what puts the gap at 3 o'clock.
  static const double _startAt = 0.049;

  /// A sealed ring stops a thousandth of a turn SHORT of the full circle,
  /// and must. Skia's `addArc` takes `sweep mod 360` unless the start angle
  /// is near a multiple of 90°, so a sweep of exactly one turn appends
  /// nothing — the mark disappeared outright on the frame it sealed, glow and
  /// all, while every frame before it drew correctly. The 46-unit round caps
  /// overlap far past the 1.4 units of arc this leaves open.
  static const double _sealedSweep = 0.999;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _vbW;

    canvas.save();
    // Translate in DEVICE px for the viewBox origin, then scale — after which
    // every number below is a viewBox unit and matches the export directly.
    canvas.translate(-_vbX * s, -_vbY * s);
    canvas.scale(s);
    canvas.translate(484, 560);
    canvas.rotate(-8 * math.pi / 180);

    final arc = cirrusMarkArc(seal);
    final path = Path()
      ..addArc(
        Rect.fromCenter(center: Offset.zero, width: 400, height: 490),
        arc.startTurns * 2 * math.pi,
        arc.sweepTurns * 2 * math.pi,
      );

    // The 300px-wide export blurs the glow 18→44px, and 300px covers 600
    // viewBox units — so the sigma is 36→88 HERE, and scales with the widget
    // instead of washing the mark out at small sizes.
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.40 + 0.45 * breath)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 92
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 36 + 52 * breath),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 92
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.seal != seal || old.breath != breath || old.color != color;
}

/// The arc the mark draws at [seal], in turns.
///
/// The gap closes from BOTH tips: the sweep grows by the whole gap while the
/// start winds back by half of it, so the two ends meet in the middle instead
/// of one end chasing the other around the ring.
@visibleForTesting
({double startTurns, double sweepTurns}) cirrusMarkArc(double seal) {
  final closed = _MarkPainter._close.transform(seal.clamp(0.0, 1.0));
  final grow = (_MarkPainter._sealedSweep - _MarkPainter._openSweep) * closed;
  return (
    startTurns: _MarkPainter._startAt - grow / 2,
    sweepTurns: _MarkPainter._openSweep + grow,
  );
}
