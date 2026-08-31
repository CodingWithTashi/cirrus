import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../data/stores/day1_tour_store.dart';

/// Highlights one real control while the Day-1 walkthrough is on that step.
///
/// The three steps live on three different routes, and
/// `ShowCaseWidget.startShowCase([keys])` sequences within ONE widget tree —
/// so nothing here hands showcaseview a list. Each screen owns its own
/// single-key showcase and starts it when [day1TourStepProvider] says it is
/// that screen's turn. The sequencing lives in the store, where the state
/// already is.
///
/// `disableDefaultTargetGestures: true` is the load-bearing flag: without it
/// showcaseview swallows the tap on the highlighted widget and calls its own
/// callback, which would mean the tour advanced without the user ever
/// operating the control it was pointing at. That is the failure this whole
/// change exists to remove.
///
/// When the step is not active this renders the bare child — no `Showcase`,
/// so a screen outside a [ShowCaseWidget] ancestor is unaffected.
class Day1Spotlight extends ConsumerStatefulWidget {
  const Day1Spotlight({
    super.key,
    required this.step,
    required this.title,
    required this.description,
    required this.child,
  });

  /// Takes the highlight down NOW, keeping the tour's locks in place.
  ///
  /// For the moment the lesson's real action begins: the showcase overlay is
  /// inserted into the ROOT overlay above the navigator's existing routes, so
  /// anything pushed after it — the danger-hours sheet, and visually even the
  /// coach transcript behind the barrier — sits under an 88%-opacity sheet of
  /// background color. A user who did exactly what the tooltip asked then
  /// watches the result happen behind a dark pane, which reads as the app
  /// breaking mid-lesson.
  static void dismissOverlay() {
    try {
      ShowcaseView.get().dismiss();
    } on Object {
      // No scope registered — nothing is showing.
    }
  }

  final Day1TourStep step;
  final String title;
  final String description;
  final Widget child;

  @override
  ConsumerState<Day1Spotlight> createState() => _Day1SpotlightState();
}

class _Day1SpotlightState extends ConsumerState<Day1Spotlight> {
  /// Stable for the life of this element — `Showcase` requires a `GlobalKey`
  /// and rebuilding one every frame would restart the highlight.
  final GlobalKey _key = GlobalKey();
  bool _started = false;

  bool get _active => ref.read(day1TourStepProvider) == widget.step;

  /// Starts after the frame — showcaseview measures the target's render box,
  /// which does not exist until this subtree has been laid out once — and
  /// after the route transition, because the rect is measured ONCE, and a
  /// rect measured mid-slide highlights where the control was passing
  /// through, not where it landed.
  void _startWhenReady() {
    if (_started || !_active) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _startNow());
  }

  void _startNow() {
    if (!mounted || !_active) {
      // Reset the latch on every bail-out. Leaving it set here is how a
      // re-entered step ends up locked with no highlight and no explanation.
      _started = false;
      return;
    }
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    if (animation != null && animation.status == AnimationStatus.forward) {
      late final AnimationStatusListener listener;
      listener = (status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          animation.removeStatusListener(listener);
          WidgetsBinding.instance.addPostFrameCallback((_) => _startNow());
        }
      };
      animation.addStatusListener(listener);
      return;
    }
    try {
      ShowcaseView.get().startShowCase([_key]);
    } on Object {
      // No registered scope (a spotlight rendered outside the shell, or a
      // torn-down tree). A missing highlight must never crash the screen the
      // control lives on.
      _started = false;
    }
  }

  /// Ends the run this spotlight started. Nothing else ever dismisses it —
  /// `Showcase.dispose` only removes its controller, and whether the stale
  /// barrier then disappears depends on an overlay rebuild that is not
  /// guaranteed to come.
  void _dismiss() {
    try {
      ShowcaseView.get().dismiss();
    } on Object {
      // Scope already unregistered — the shell is gone and its overlay with it.
    }
  }

  @override
  void dispose() {
    if (_started) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          ShowcaseView.get().dismiss();
        } on Object {
          // Already torn down with the shell.
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final active = ref.watch(day1TourStepProvider) == widget.step;
    if (!active) {
      // Reset so re-entering the step (an interrupted tour, a resumed
      // session) highlights again rather than silently doing nothing — and
      // take the overlay down with us if we were the ones showing it.
      if (_started) {
        _started = false;
        WidgetsBinding.instance.addPostFrameCallback((_) => _dismiss());
      }
      return widget.child;
    }
    _startWhenReady();

    return Showcase(
      key: _key,
      title: widget.title,
      description: widget.description,
      // The user operates the real control. See the class comment.
      disableDefaultTargetGestures: true,
      tooltipBackgroundColor: lp.surface,
      textColor: lp.textPrimary,
      titleTextStyle: LpType.heading(lp.textPrimary, size: 16),
      descTextStyle: LpType.body14(lp.textSecondary),
      overlayColor: lp.background,
      overlayOpacity: 0.88,
      targetBorderRadius: BorderRadius.circular(18),
      targetPadding: const EdgeInsets.all(6),
      // The escape hatch, on the tooltip itself. It ticks NOTHING — it puts
      // the user back on the checklist, where the step stays listed and the
      // skip link stays offered. A step whose real move cannot happen (the
      // coach needs a network) must never be a wall.
      tooltipActions: [
        TooltipActionButton(
          type: TooltipDefaultActionType.skip,
          name: context.l10n.commonMaybeLater,
          backgroundColor: Colors.transparent,
          textStyle: LpType.body13(lp.textSecondary),
          onTap: () => ref.read(day1TourProvider.notifier).pause(),
        ),
      ],
      tooltipActionConfig: const TooltipActionConfig(
        alignment: MainAxisAlignment.end,
        gapBetweenContentAndAction: 6,
      ),
      child: widget.child,
    );
  }
}
