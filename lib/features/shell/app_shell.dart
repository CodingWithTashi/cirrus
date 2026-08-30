import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_haptics.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/providers.dart';
import '../home/widgets/log_feedback.dart';

/// Tab scaffold: Home · Stats · [ + quick log ] · Community · Coach.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;

    // Warm the community feed while the user is still on Home, so the tab
    // never opens onto its empty state during the fetch. (listen, not watch:
    // the shell must not rebuild on feed changes.)
    ref.listen(communityStoreProvider, (_, _) {});

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
                  color: selected ? lp.voltText : lp.textFaint,
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

    return Scaffold(
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
                tab(branch: 3, icon: Icons.auto_awesome, label: l10n.navCoach),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
