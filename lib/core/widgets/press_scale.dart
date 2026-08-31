import 'package:flutter/material.dart';

import '../../app/theme/lp_dimens.dart';
import '../utils/lp_haptics.dart';

/// "Every tap gets a reaction" (docs/02 §1): scales to 0.97 on press,
/// springs back on release, fires a light haptic on tap.
///
/// [onHoldStart]/[onHoldEnd] turn a press-and-hold into a mode: start fires
/// once the long-press threshold passes (the control stays visually sunk for
/// the whole hold), end fires on release or cancel. The quick-log buttons use
/// this pair for hold-to-repeat.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onHoldStart,
    this.onHoldEnd,
    this.haptic = true,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldEnd;
  final bool haptic;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  // Press sinks to 0.97, release overshoots to 1.02 before settling — the
  // "1.02 bounce" every design note references.
  double _scale = 1;

  void _release() {
    if (!mounted) return;
    setState(() => _scale = 1.02);
    Future<void>.delayed(LpMotion.tap, () {
      if (mounted) setState(() => _scale = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final holds = widget.onHoldStart != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapCancel: () => setState(() => _scale = 1),
      onTapUp: (_) => _release(),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) LpHaptics.light();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      onLongPressStart: !holds
          ? null
          : (_) {
              // The long press won the arena, which cancelled the tap and its
              // scale reset — sink again so the hold reads as held.
              setState(() => _scale = 0.97);
              widget.onHoldStart!();
            },
      onLongPressEnd: !holds
          ? null
          : (_) {
              _release();
              widget.onHoldEnd?.call();
            },
      onLongPressCancel: !holds ? null : () => widget.onHoldEnd?.call(),
      child: AnimatedScale(
        scale: _scale,
        duration: LpMotion.tap,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
