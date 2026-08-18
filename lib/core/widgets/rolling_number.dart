import 'package:flutter/material.dart';

import '../../app/theme/lp_dimens.dart';
import '../utils/lp_haptics.dart';

/// Odometer-style counter: animates between values, formatting via [format].
/// Used for money tickers, puff counts, streaks — every number that rewards.
class RollingNumber extends StatelessWidget {
  const RollingNumber(
    this.value, {
    super.key,
    required this.style,
    this.format,
    this.from = 0,
    this.duration = LpMotion.reveal,
    this.curve = LpMotion.emphasized,
    this.hapticOnLand = false,
  });

  final num value;
  final TextStyle style;
  final String Function(num value)? format;

  /// Where the first roll starts. Defaults to 0 so counters roll up on
  /// entry (a begin-less Tween never animates its first build); pass e.g.
  /// `total - 1` for the survived screen's 22→23 roll.
  final num from;
  final Duration duration;

  /// Pass an [Interval] to stagger multiple counters (Run 1 frame 16:
  /// "stat counters roll up staggered").
  final Curve curve;

  /// Medium haptic when the roll-up lands (Run 1 frame 9: the yearly shock
  /// counter thuds as it settles).
  final bool hapticOnLand;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: from.toDouble(), end: value.toDouble()),
      duration: duration,
      curve: curve,
      onEnd: hapticOnLand && value != 0 ? LpHaptics.medium : null,
      builder: (context, animated, _) {
        final display = format?.call(animated) ?? animated.round().toString();
        return Text(display, style: style);
      },
    );
  }
}
