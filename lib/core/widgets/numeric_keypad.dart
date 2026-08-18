import 'package:flutter/material.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_typography.dart';
import '../utils/lp_haptics.dart';
import 'press_scale.dart';

/// The onboarding number pad (birth year, puffs, spend). Soft tick haptics.
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;

    Widget key({
      String? label,
      Widget? child,
      VoidCallback? onTap,
      bool filled = true,
    }) {
      return Expanded(
        child: PressScale(
          onTap: onTap == null
              ? null
              : () {
                  LpHaptics.tick();
                  onTap();
                },
          haptic: false,
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: filled
                ? BoxDecoration(
                    color: lp.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: lp.borderSubtle),
                  )
                : null,
            child:
                child ??
                Text(
                  label ?? '',
                  style: TextStyle(
                    fontFamily: LpType.display,
                    fontWeight: FontWeight.w500,
                    fontSize: 22,
                    color: lp.textPrimary,
                  ),
                ),
          ),
        ),
      );
    }

    Widget row(List<Widget> keys) => Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          keys[i],
        ],
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final digits in const [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ]) ...[
          row([
            for (final d in digits) key(label: '$d', onTap: () => onDigit(d)),
          ]),
          const SizedBox(height: 8),
        ],
        row([
          key(filled: false),
          key(label: '0', onTap: () => onDigit(0)),
          key(
            filled: false,
            onTap: onBackspace,
            child: Icon(
              Icons.backspace_outlined,
              size: 20,
              color: lp.textSecondary,
            ),
          ),
        ]),
      ],
    );
  }
}

/// Blinking Volt caret next to big numeric entry.
class BlinkingCaret extends StatefulWidget {
  const BlinkingCaret({super.key, this.height = 52, this.width = 3});

  final double height;
  final double width;

  @override
  State<BlinkingCaret> createState() => _BlinkingCaretState();
}

class _BlinkingCaretState extends State<BlinkingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return FadeTransition(
      opacity: TweenSequence<double>([
        TweenSequenceItem(tween: ConstantTween(1), weight: 55),
        TweenSequenceItem(tween: ConstantTween(0), weight: 45),
      ]).animate(_controller),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: lp.volt,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
