import 'package:flutter/material.dart';

import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_typography.dart';

/// Shared step body: horizontal padding + optional title/subtitle header.
class StepBody extends StatelessWidget {
  const StepBody({
    super.key,
    this.title,
    this.subtitle,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 24),
  });

  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return StepScrollView(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(title!, style: LpType.title(lp.textPrimary)),
              SizedBox(height: subtitle != null ? 10 : 26),
            ],
            if (subtitle != null) ...[
              Text(subtitle!, style: LpType.body14(lp.textSecondary)),
              const SizedBox(height: 26),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Lets a step scroll when the viewport is shorter than its content, without
/// breaking the `Spacer()`s that push a CTA to the bottom.
///
/// Same idiom as the auth forms' `_AuthScrollView`, and it exists for the same
/// reason. The onboarding steps were bare Columns, so the moment the viewport
/// shrank they overflowed. The path that does it in production: registering
/// opens the keyboard, `context.go(Routes.onboarding)` runs before the IME is
/// dismissed, and the welcome screen renders into what is left — a
/// yellow-and-black overflow stripe on step one of the funnel every
/// acquisition number in docs/08 §2 divides through.
///
/// Found on device. No widget test can see it: the test font has different
/// metrics and nothing in that harness raises a keyboard.
///
/// `minHeight` keeps the column full-height when there IS room, so `Spacer`
/// still has a bounded box to divide.
class StepScrollView extends StatelessWidget {
  const StepScrollView({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: IntrinsicHeight(child: child),
      ),
    ),
  );
}
