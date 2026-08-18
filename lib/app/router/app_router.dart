import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/stores/providers.dart';
import '../../features/auth/auth_screens.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/buddy/buddy_screen.dart';
import '../../features/coach/coach_screen.dart';
import '../../features/community/community_screens.dart';
import '../../features/day1/day1_screen.dart';
import '../../features/frame_map/frame_map_screen.dart';
import '../../features/health/health_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/insight/insight_screen.dart';
import '../../features/milestones/milestones_screen.dart';
import '../../features/money/money_screen.dart';
import '../../features/onboarding/onboarding_flow.dart';
import '../../features/panic/panic_screens.dart';
import '../../features/paywall/paywall_screens.dart';
import '../../features/plan/plan_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/settings_screens.dart';
import '../../features/shell/app_shell.dart';
import '../../features/slip/slip_screen.dart';
import '../../features/stats/stats_screen.dart';

abstract final class Routes {
  static const splash = '/';
  static const auth = '/auth';
  static const register = '/auth/register';
  static const login = '/auth/login';
  static const forgot = '/auth/forgot';
  static const onboarding = '/onboarding';
  static const paywall = '/paywall';
  static const paywallFree = '/paywall/free';
  static const winback = '/paywall/winback';
  static const trialEnding = '/paywall/trial-ending';
  static const day1 = '/day1';
  static const home = '/home';
  static const stats = '/stats';
  static const community = '/community';
  static const coach = '/coach';
  static const compose = '/community/compose';
  static const panic = '/panic';
  static const game = '/panic/game';
  static const survived = '/panic/survived';
  static const plan = '/plan';
  static const money = '/money';
  static const health = '/health';
  static const milestones = '/milestones';
  static const insight = '/insight';
  static const buddy = '/buddy';
  static const profile = '/profile';
  static const settings = '/settings';
  static const slip = '/slip';
  static const frames = '/frames';
  static const framesEdge = '/frames/edge';
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.onDispose(refresh.dispose);
  ref.listen(quitStoreProvider, (_, _) => refresh.value++);

  bool hasJourney() => ref.read(quitStoreProvider) != null;

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      final path = state.uri.path;
      final authed = hasJourney();
      final needsJourney =
          path.startsWith(Routes.home) ||
          path.startsWith(Routes.stats) ||
          path.startsWith(Routes.community) ||
          path.startsWith(Routes.coach) ||
          path.startsWith(Routes.panic) ||
          path.startsWith(Routes.plan) ||
          path.startsWith(Routes.money) ||
          path.startsWith(Routes.health) ||
          path.startsWith(Routes.milestones) ||
          path.startsWith(Routes.insight) ||
          path.startsWith(Routes.buddy) ||
          path.startsWith(Routes.profile) ||
          path.startsWith(Routes.settings) ||
          path.startsWith(Routes.slip) ||
          path.startsWith(Routes.day1);
      if (!authed && needsJourney) return Routes.auth;
      // Signed-in visits to auth/onboarding are allowed on purpose: the
      // Frame Map previews every screen regardless of session state.
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.auth, builder: (_, _) => const SignInScreen()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: Routes.forgot,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => const OnboardingFlow(),
      ),
      GoRoute(path: Routes.paywall, builder: (_, _) => const PaywallScreen()),
      GoRoute(
        path: Routes.paywallFree,
        builder: (_, _) => const FreePlanScreen(),
      ),
      GoRoute(path: Routes.winback, builder: (_, _) => const WinbackScreen()),
      GoRoute(
        path: Routes.trialEnding,
        builder: (_, _) => const TrialEndingScreen(),
      ),
      GoRoute(path: Routes.day1, builder: (_, _) => const Day1Screen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.stats,
                builder: (_, _) => const StatsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.community,
                builder: (_, _) => const CommunityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.coach,
                builder: (_, _) => const CoachScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: Routes.compose, builder: (_, _) => const ComposerScreen()),
      GoRoute(
        path: '/community/post/:id',
        builder: (_, state) =>
            PostDetailScreen(postId: state.pathParameters['id']!),
      ),
      // Panic takeover: fast fade-in, no slide (≤400ms, docs/03 §7).
      GoRoute(
        path: Routes.panic,
        pageBuilder: (_, _) => CustomTransitionPage(
          child: const PanicFlow(),
          transitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(path: Routes.game, builder: (_, _) => const TapGameScreen()),
      GoRoute(
        path: Routes.survived,
        pageBuilder: (_, _) => CustomTransitionPage(
          child: const SurvivedScreen(),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(path: Routes.plan, builder: (_, _) => const PlanScreen()),
      GoRoute(path: Routes.money, builder: (_, _) => const MoneyScreen()),
      GoRoute(path: Routes.health, builder: (_, _) => const HealthScreen()),
      GoRoute(
        path: Routes.milestones,
        builder: (_, _) => const MilestonesScreen(),
      ),
      GoRoute(path: Routes.insight, builder: (_, _) => const InsightScreen()),
      GoRoute(path: Routes.buddy, builder: (_, _) => const BuddyScreen()),
      GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
      GoRoute(path: Routes.slip, builder: (_, _) => const SlipFlow()),
      GoRoute(path: Routes.frames, builder: (_, _) => const FrameMapScreen()),
      GoRoute(
        path: Routes.framesEdge,
        builder: (_, _) => const EdgeStatesPreviewScreen(),
      ),
    ],
  );
});
