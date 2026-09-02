import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../data/stores/providers.dart';
import '../utils/l10n_ext.dart';
import 'lp_buttons.dart';
import 'press_scale.dart';

/// The one way a Premium-only surface is gated on screen.
///
/// Premium (or trial): [child], untouched. Free: [child] still renders — its
/// real content, dimmed and blurred, never a mock-up — under a lock card that
/// says in one line what Premium adds *here* ([pitch]) and offers one door to
/// the paywall, tagged with [source] so the conversion of each door can be
/// read apart. That is docs/02 §5 ("every cap screen shows exactly what
/// Premium adds at that moment") and docs/04's honest tease for the weekly
/// report (headline visible, body blurred).
///
/// The tier is `isPremiumProvider`, so a purchase, a restore, an expiry or a
/// renewal re-renders every gate in the app on its own.
///
/// Layout note: a `Stack` with a positioned overlay, never `IntrinsicHeight`
/// around a blurred child — positioned children are excluded from intrinsic
/// sizing and get bounded constraints (see the Health screen gotcha).
class LpPremiumGate extends ConsumerWidget {
  const LpPremiumGate({
    super.key,
    required this.source,
    required this.pitch,
    this.child,
    this.blurSigma = 6,
    this.compact = false,
    this.lockAlignment = Alignment.center,
  });

  /// `Routes.paywallFrom(source)` — the analytics door.
  final String source;

  /// What Premium adds on this surface. One sentence, an ARB string.
  final String pitch;

  /// The gated surface. Null when there is genuinely nothing to show behind
  /// the gate (the server computes nothing for a free account): then only
  /// the lock card renders, inline — never a mocked-up preview.
  final Widget? child;

  /// How hard the free view is blurred. 0 keeps it readable and only dims.
  final double blurSigma;

  /// A tighter lock card for small surfaces (a chip row, a stat tile).
  final bool compact;

  /// Where the lock card sits over [child]. Centre for a card-sized surface;
  /// `topCenter` for a tall one (a timeline), so the door is on screen the
  /// moment the gated region scrolls into view rather than a page below it.
  final Alignment lockAlignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gated = child;
    if (ref.watch(isPremiumProvider)) return gated ?? const SizedBox.shrink();
    final lock = _LockCard(source: source, pitch: pitch, compact: compact);
    if (gated == null) return lock;
    // Both children are non-positioned on purpose: the Stack then sizes to
    // the taller of the two, so a lock card over a short surface (the
    // trigger-hours heatmap) grows the region instead of overflowing it.
    return Stack(
      alignment: lockAlignment,
      children: [
        // The real thing, out of reach but not out of sight. Absorbing taps
        // here is what keeps a blurred button from being a working button.
        AbsorbPointer(
          child: Opacity(
            opacity: 0.55,
            child: blurSigma > 0
                ? ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                    ),
                    child: gated,
                  )
                : gated,
          ),
        ),
        lock,
      ],
    );
  }
}

class _LockCard extends StatelessWidget {
  const _LockCard({
    required this.source,
    required this.pitch,
    required this.compact,
  });

  final String source;
  final String pitch;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    return PressScale(
      onTap: () => context.push(Routes.paywallFrom(source)),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 18,
          vertical: compact ? 12 : 16,
        ),
        decoration: BoxDecoration(
          color: lp.surface,
          borderRadius: BorderRadius.circular(LpDimens.rCard),
          border: Border.all(color: lp.voltFocus, width: 1.5),
          boxShadow: [
            BoxShadow(color: lp.volt.withValues(alpha: 0.18), blurRadius: 24),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 15, color: lp.voltText),
                const SizedBox(width: 6),
                Text(
                  l10n.premiumLockTitle,
                  style: LpType.caption(
                    lp.voltText,
                    weight: FontWeight.w700,
                  ).copyWith(letterSpacing: 1),
                ),
              ],
            ),
            SizedBox(height: compact ? 6 : 8),
            Text(
              pitch,
              textAlign: TextAlign.center,
              style: compact
                  ? LpType.caption(lp.textPrimary)
                  : LpType.body14(lp.textPrimary),
            ),
            SizedBox(height: compact ? 10 : 14),
            LpButton(
              l10n.premiumLockCta,
              height: compact ? 40 : 46,
              fontSize: compact ? 14 : 15,
              glow: false,
              onTap: () => context.push(Routes.paywallFrom(source)),
            ),
          ],
        ),
      ),
    );
  }
}
