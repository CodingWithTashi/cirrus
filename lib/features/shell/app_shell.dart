import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_haptics.dart';
import '../../core/widgets/press_scale.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../data/stores/day1_tour_store.dart';
import '../../data/stores/providers.dart';
import '../home/widgets/log_feedback.dart';

/// Tab scaffold: Home · Stats · [ + quick log ] · Community · Coach.
///
/// Also the one place the Day-1 walkthrough's showcase controller is
/// registered. It is a controller rather than a widget ancestor, so it is
/// registered once for the whole shell and every branch screen can reach it —
/// which is what lets three spotlights on three different tabs work without a
/// wrapper around each.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    try {
      ShowcaseView.register(
        // A stray tap must not end a lesson that has not been learned yet.
        disableBarrierInteraction: true,
        // The highlight's default "moving" animation never stops, so the tree
        // never reaches a steady state: every `pumpAndSettle` in a test that
        // opens the walkthrough times out, and on a device it is a pulsing
        // ring under a tooltip nobody asked to be hypnotised by.
        disableMovingAnimation: true,
        // Step three's target is a card in the Stats ListView: on a small
        // screen it can sit below the fold, and a highlight drawn around an
        // off-screen rect is a dark screen with a tooltip pointing at
        // nothing.
        enableAutoScroll: true,
      );
    } on Object {
      // A stale scope from a shell still animating out. The walkthrough is a
      // courtesy; it must never take the tab scaffold down with it.
    }
  }

  @override
  void dispose() {
    try {
      ShowcaseView.get().unregister();
    } on Object {
      // Already unregistered — nothing to tear down.
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    final lp = context.lp;
    final l10n = context.l10n;

    // Warm the community feed while the user is still on Home, so the tab
    // never opens onto its empty state during the fetch. (listen, not watch:
    // the shell must not rebuild on feed changes.)
    ref.listen(communityStoreProvider, (_, _) {});

    // The Day-1 walkthrough holds the app closed until the three moves are
    // made. The tab bar is why this has to be handled HERE: it lives outside
    // whichever branch screen owns the showcase, so no overlay barrier can
    // cover it, and a user one tap from Community learns nothing.
    final locked = ref.watch(day1TourLockedProvider);

    void quickLog() {
      LpHaptics.light();
      ref.read(quitStoreProvider.notifier).logPuff();
      showLogUndoSnack(context, ref);
    }

    Widget tab({
      required int branch,
      required IconData icon,
      required String label,
    }) {
      final selected = shell.currentIndex == branch;
      return Expanded(
        child: PressScale(
          enabled: !locked,
          onTap: () {
            // `goBranch` swaps the IndexedStack branch without pushing a
            // route, so LpAnalyticsObserver never sees a tab change — these
            // four are the only screens it cannot report for itself. The path
            // is read back off the branch rather than listed here, so a
            // reordered tab bar cannot start mislabelling screen views.
            final path = shell.route.branches[branch].defaultRoute?.path;
            if (path != null) ref.read(analyticsProvider).screenViewed(path);
            shell.goBranch(branch, initialLocation: selected);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: locked
                      ? lp.textFaint.withValues(alpha: 0.4)
                      : (selected ? lp.voltText : lp.textFaint),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: LpType.micro(
                    selected ? lp.voltText : lp.textSecondary,
                    weight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      // The barrier absorbs stray taps; it does nothing about the system back
      // gesture, which on a branch root would drop the user straight out of
      // the app mid-lesson. Same reason `onboarding_flow.dart` carries one.
      canPop: !locked,
      // Swallowing the gesture outright made the tour a hostage situation:
      // an offline user on the coach step had no move left at all. Back now
      // means what it means everywhere — leave this screen — and lands on
      // the checklist, ticking nothing.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ref.read(day1TourProvider.notifier).pause();
      },
      child: Scaffold(
        body: shell,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: lp.navBar,
            border: Border(top: BorderSide(color: lp.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  tab(branch: 0, icon: Icons.circle, label: l10n.navHome),
                  tab(
                    branch: 1,
                    icon: Icons.bar_chart_rounded,
                    label: l10n.navStats,
                  ),
                  PressScale(
                    // The second, unmarked way to log a puff. During the
                    // walkthrough it has to be shut too: step one teaches the
                    // Home button, and a user who found this instead would tick
                    // the box without meeting the control being taught.
                    enabled: !locked,
                    onTap: quickLog,
                    haptic: false,
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: lp.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: lp.border, width: 1.5),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: lp.voltText,
                        size: 24,
                      ),
                    ),
                  ),
                  tab(
                    branch: 2,
                    icon: Icons.diamond_outlined,
                    label: l10n.navCommunity,
                  ),
                  tab(
                    branch: 3,
                    icon: Icons.auto_awesome,
                    label: l10n.navCoach,
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
