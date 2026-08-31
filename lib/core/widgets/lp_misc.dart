import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../utils/l10n_ext.dart';
import 'press_scale.dart';

/// The glowing Volt dot of the wordmark.
class VoltDot extends StatelessWidget {
  const VoltDot({super.key, this.size = 10});

  final double size;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: lp.volt,
        boxShadow: [
          BoxShadow(
            color: lp.volt.withValues(alpha: 0.8),
            blurRadius: size * 1.2,
          ),
        ],
      ),
    );
  }
}

/// Wordmark row: glowing dot + "LastPuff".
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.fontSize = 18, this.center = false});

  final double fontSize;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: center
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        VoltDot(size: fontSize * 0.55),
        const SizedBox(width: 8),
        Text(
          context.l10n.appName,
          style: TextStyle(
            fontFamily: LpType.display,
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
            letterSpacing: -0.5,
            color: lp.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// 🔥 streak chip (Ember family).
class StreakChip extends StatelessWidget {
  const StreakChip({
    super.key,
    required this.days,
    this.dimmed = false,
    this.onTap,
  });

  final int days;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return PressScale(
      onTap: onTap,
      child: Opacity(
        opacity: dimmed ? 0.68 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: lp.emberSoft,
            borderRadius: BorderRadius.circular(LpDimens.rChip),
            border: Border.all(
              color: lp.ember.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: Text(
            context.l10n.homeStreakChip(days),
            style: LpType.displaySmall(lp.emberText, size: 14),
          ),
        ),
      ),
    );
  }
}

/// Minimal back chevron used across onboarding/auth.
class BackChevron extends StatelessWidget {
  const BackChevron({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return PressScale(
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: lp.textSecondary,
        ),
      ),
    );
  }
}

/// Themed floating snackbar with optional action (undo pattern).
///
/// [margin] repositions the snack away from its default bottom-edge spot —
/// the log-puff snack passes one so it never covers the control that was just
/// tapped (a toast squatting on the button it confirms blocks the next tap
/// for its whole lifetime).
void showLpSnack(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
  EdgeInsetsGeometry? margin,
}) {
  final messenger = ScaffoldMessenger.of(context);
  // Replace, never queue — rapid logging must not stack minutes of snacks.
  messenger.clearSnackBars();
  final controller = messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      margin: margin,
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ),
  );
  // The framework skips its auto-timeout for action snack bars whenever the
  // platform reports accessible navigation — which some environments report
  // spuriously, leaving "Undo" snacks up forever. The design wants a bounded
  // lifetime regardless (docs/03 §5: a 5s undo window), so close whatever is
  // still showing ourselves. Cancelled as soon as the snack closes by any
  // other path (timeout, swipe, replacement), so it never double-fires.
  final timer = Timer(duration + const Duration(milliseconds: 250), () {
    // Guarded because this is a backstop, not a control path. If the tree
    // that owns the messenger was torn down while the snack was up — a
    // crash screen replacing the app, the host disposing it — `close()`
    // asserts on a disposed AnimationController, and a *backstop* taking the
    // app down is strictly worse than a snack that outlives its window.
    // `controller.closed` never completes in that case, so the cancel below
    // never runs and this timer is the one thing left holding the reference.
    try {
      controller.close();
    } on Object {
      // Nothing to do: the snack is already gone with its messenger.
    }
  });
  unawaited(controller.closed.whenComplete(timer.cancel));
}

/// Slim animated progress bar (onboarding header, day-1 checklist, goals).
/// Fills from 0 on entry, animates forward — and **snaps** on decrease
/// (Run 1 frame 2: the bar "never jumps back visually").
class GlowProgressBar extends StatefulWidget {
  const GlowProgressBar({
    super.key,
    required this.value,
    this.height = 4,
    this.curve = LpMotion.ease,
  });

  final double value;
  final double height;
  final Curve curve;

  @override
  State<GlowProgressBar> createState() => _GlowProgressBarState();
}

class _GlowProgressBarState extends State<GlowProgressBar> {
  late double _previous = 0;

  @override
  void didUpdateWidget(GlowProgressBar old) {
    super.didUpdateWidget(old);
    _previous = old.value;
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final target = widget.value.clamp(0, 1).toDouble();
    final backwards = target < _previous;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.height / 2),
      child: Container(
        height: widget.height,
        color: lp.border,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: target),
          duration: backwards ? Duration.zero : LpMotion.normal,
          curve: widget.curve,
          builder: (context, t, _) => FractionallySizedBox(
            widthFactor: t,
            child: Container(
              decoration: BoxDecoration(
                color: lp.volt,
                borderRadius: BorderRadius.circular(widget.height / 2),
                boxShadow: [
                  BoxShadow(
                    color: lp.volt.withValues(alpha: 0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal error shake (Run 2 frame 28: "wrong password shakes the field
/// 2px"). Trigger via a GlobalKey: `_shakeKey.currentState?.shake()`.
class ShakeIt extends StatefulWidget {
  const ShakeIt({super.key, required this.child});

  final Widget child;

  @override
  State<ShakeIt> createState() => ShakeItState();
}

class ShakeItState extends State<ShakeIt> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  void shake() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Three decaying ±2px swings.
        final dx = math.sin(t * math.pi * 6) * 2 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

/// OS-style notification bubble used by every push preview (onboarding D4,
/// trial ending): Volt app icon, app name, time, one-line body.
class PushPreviewCard extends StatelessWidget {
  const PushPreviewCard({super.key, required this.time, required this.body});

  final String time;
  final String body;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: lp.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(LpDimens.rBento),
        border: Border.all(color: lp.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: lp.isDark ? 0.5 : 0.08),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: lp.volt,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: lp.onVolt,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.appName,
                      style: LpType.body14(
                        lp.textPrimary,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Text(time, style: LpType.caption11(lp.textSecondary)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(body, style: LpType.body13(lp.textBody)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Auth-style labeled input container matching the design's field cards.
class LpField extends StatelessWidget {
  const LpField({
    super.key,
    required this.label,
    required this.controller,
    this.focusNode,
    this.obscure = false,
    this.trailing,
    this.keyboardType,
    this.autofocus = false,
    this.hint,
    this.onChanged,
    this.maxLines = 1,
    this.maxLength,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool obscure;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final bool autofocus;
  final String? hint;
  final ValueChanged<String>? onChanged;

  /// Above 1 the field grows into a small prose box. Every existing caller is
  /// a single-line credential or a name, so the default keeps them unchanged.
  final int maxLines;

  /// Shows the counter and stops accepting characters past the limit. A field
  /// that silently refuses input reads as a broken keyboard, which is why the
  /// counter comes with it rather than a bare cap.
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, ?focusNode]),
      builder: (context, _) {
        final focused = focusNode?.hasFocus ?? false;
        return AnimatedContainer(
          duration: LpMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: lp.surface,
            borderRadius: BorderRadius.circular(LpDimens.rInput),
            border: Border.all(
              color: focused ? lp.voltFocus : lp.border,
              width: 1.5,
            ),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: lp.volt.withValues(alpha: 0.12),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: LpType.caption11(
                  focused ? lp.voltText : lp.textSecondary,
                  weight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      obscureText: obscure,
                      autofocus: autofocus,
                      keyboardType: keyboardType,
                      onChanged: onChanged,
                      maxLines: maxLines,
                      minLines: 1,
                      maxLength: maxLength,
                      style: LpType.body15(lp.textPrimary),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: hint,
                        hintStyle: LpType.body15(lp.textFaint),
                        contentPadding: const EdgeInsets.only(top: 4),
                        counterStyle: LpType.caption11(lp.textFaint),
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
