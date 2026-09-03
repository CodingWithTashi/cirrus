import 'package:flutter/material.dart';

import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_typography.dart';

/// How much vertical room a step has, and therefore how tall it may draw.
///
/// The keypad steps pin a keypad and a CTA at the bottom under a hero number
/// and its supporting cards. On a 6.1" iPhone the spend step's full-size
/// layout ran about 120 logical pixels past the bottom: the step gets ~707 of
/// the iPhone 15's 852 once the status bar, the home indicator and the
/// progress header have taken theirs, while a Pixel 8 leaves it 800+. So the
/// CTA sat below the fold and every change to the amount meant a scroll to
/// reach Continue — on the one screen of the funnel whose whole job is to
/// make a number land.
///
/// A step reads its density once from its own constraints and draws every
/// fixed size from it. Nothing is removed at [compact]; the same elements
/// draw shorter. The regular sizes are the design frames' and stay untouched
/// on every phone tall enough for them.
enum StepDensity {
  regular,
  compact;

  /// Step heights below this get the compact drawing. Set from the spend
  /// step, the tallest of the keypad screens: its regular layout needs ~780
  /// and this leaves a little air above the keypad on anything that qualifies
  /// as regular.
  static const double compactBelow = 800;

  static StepDensity of(BoxConstraints constraints) =>
      constraints.maxHeight < compactBelow ? compact : regular;

  bool get isCompact => this == compact;

  /// [regular] when there is room, else [compact] — the one-liner every
  /// per-size decision in a step reads as.
  T pick<T>(T regular, T compact) => isCompact ? compact : regular;
}

/// Shared step body: horizontal padding + optional title/subtitle header.
class StepBody extends StatelessWidget {
  const StepBody({
    super.key,
    this.title,
    this.subtitle,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 24),
    this.titleGap = 26,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  /// Space under a title that has no subtitle. A compact step tightens it.
  final double titleGap;

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
              SizedBox(height: subtitle != null ? 10 : titleGap),
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
