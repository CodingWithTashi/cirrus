import 'package:flutter/material.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';

/// The two states a screen spends most of its life in and nothing here had a
/// widget for: waiting, and empty.
///
/// Failure has had `LpErrorState` since the beginning, so a screen that broke
/// looked considered while a screen that was merely loading showed a bare
/// spinner with no words at all — six of them, app-wide, and not one with a
/// line of copy. Empty was worse: there was no widget at all, so every empty
/// state was hand-rolled inline and they drifted apart.
///
/// All three now read as one system.

/// A shimmering placeholder in the shape of the thing being loaded.
///
/// A skeleton beats a spinner because it says what is coming, not merely that
/// something is: the screen keeps its layout, so nothing jumps when the real
/// content lands. Prefer this anywhere the shape is known in advance.
class LpSkeleton extends StatefulWidget {
  const LpSkeleton({
    super.key,
    required this.height,
    this.width,
    this.radius = 10,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<LpSkeleton> createState() => _LpSkeletonState();
}

class _LpSkeletonState extends State<LpSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          // A gentle pulse rather than a sweeping highlight: this sits behind
          // real content for a second or two, and anything more energetic
          // reads as a loading screen in its own right.
          color: Color.lerp(lp.surface, lp.surfaceInset, _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A block of stacked skeleton lines, for text-shaped content.
class LpSkeletonLines extends StatelessWidget {
  const LpSkeletonLines({
    super.key,
    this.count = 3,
    this.height = 13,
    this.gap = 10,
  });

  final int count;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < count; i++) ...[
        if (i > 0) SizedBox(height: gap),
        // The last line is short, the way a real paragraph ends. A stack of
        // identical bars reads as a progress bar, not as text.
        FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: i == count - 1 ? 0.55 : 1,
          child: LpSkeleton(height: height, radius: 6),
        ),
      ],
    ],
  );
}

/// A screen that worked and has nothing to show yet.
///
/// Deliberately the same shape as [LpErrorState] — emoji, title, body,
/// optional action — because to a user these are neighbours, and the app
/// should not change its voice between "this broke" and "there is nothing here
/// yet". The difference is tone, and that belongs in the copy.
class LpEmptyState extends StatelessWidget {
  const LpEmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String emoji;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: LpType.emphasis(lp.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: LpType.body13(lp.textSecondary),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: lp.surfaceInset,
                    borderRadius: BorderRadius.circular(LpDimens.rChip),
                    border: Border.all(color: lp.border, width: 1.5),
                  ),
                  child: Text(
                    actionLabel!,
                    style: LpType.body13(
                      lp.textPrimary,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A spinner that says what it is waiting for.
///
/// Every loading state in the app was a bare `CircularProgressIndicator` with
/// no words — which is fine for 200ms and reads as a hang at two seconds, and
/// two seconds is what a cold-started callable actually costs. Use a skeleton
/// where the shape is known; use this where it is not.
class LpLoadingState extends StatelessWidget {
  const LpLoadingState({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: lp.volt),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            textAlign: TextAlign.center,
            style: LpType.body13(lp.textSecondary),
          ),
        ],
      ),
    );
  }
}
