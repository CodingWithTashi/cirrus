import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/features/auth/auth_screens.dart';
import 'package:last_puff/features/coach/coach_screen.dart';
import 'package:last_puff/features/coach/memories_screen.dart';
import 'package:last_puff/features/community/community_screens.dart';
import 'package:last_puff/features/frame_map/frame_map_screen.dart';
import 'package:last_puff/features/health/health_screen.dart';
import 'package:last_puff/features/day1/day1_screen.dart';
import 'package:last_puff/features/home/home_screen.dart';
import 'package:last_puff/features/insight/insight_screen.dart';
import 'package:last_puff/features/milestones/milestones_screen.dart';
import 'package:last_puff/features/moderation/moderation_screen.dart';
import 'package:last_puff/features/money/money_screen.dart';
import 'package:last_puff/features/onboarding/onboarding_flow.dart';
import 'package:last_puff/domain/logic/games/game_id.dart';
import 'package:last_puff/features/panic/game_arena_screen.dart';
import 'package:last_puff/features/panic/panic_screens.dart';
import 'package:last_puff/features/paywall/paywall_screens.dart';
import 'package:last_puff/features/plan/plan_screen.dart';
import 'package:last_puff/features/profile/profile_screen.dart';
import 'package:last_puff/features/settings/settings_screens.dart';
import 'package:last_puff/features/slip/slip_screen.dart';
import 'package:last_puff/features/stats/stats_screen.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';
import 'package:last_puff/features/onboarding/onboarding_view_model.dart';

/// Every screen, laid out, in both themes and at two sizes.
///
/// The bug this exists for: `HealthScreen` threw
/// "BoxConstraints forces an infinite height" on its FIRST frame for every
/// completed milestone — `IntrinsicHeight` asked for a max intrinsic height,
/// the walk reached a `FractionallySizedBox` whose reveal tween starts at 0,
/// and the division by zero produced an infinite constraint. The screen never
/// painted. It shipped that way because nothing had ever built it in a test,
/// and the on-device sweep is what finally opened it.
///
/// A layout assertion is invisible until someone opens the screen, so the
/// cheapest possible guard is to open all of them.
void main() {
  final screens = <String, Widget>{
    'SignIn': const SignInScreen(),
    'Register': const RegisterScreen(),
    'Login': const LoginScreen(),
    'ForgotPassword': const ForgotPasswordScreen(),
    'Home': const HomeScreen(),
    'Stats': const StatsScreen(),
    'Community': const CommunityScreen(),
    'Composer': const ComposerScreen(),
    'Coach': const CoachScreen(),
    'Plan': const PlanScreen(),
    'Money': const MoneyScreen(),
    'Health': const HealthScreen(),
    'Milestones': const MilestonesScreen(),
    'Insight': const InsightScreen(),
    'Profile': const ProfileScreen(),
    'Settings': const SettingsScreen(),
    'Slip': const SlipFlow(),
    'Panic': const PanicFlow(),
    'GameArena': const GameArenaScreen(),
    'GameArenaBlocks': const GameArenaScreen(initial: GameId.blocks),
    'GameArenaOrbs': const GameArenaScreen(initial: GameId.orbs),
    'Survived': const SurvivedScreen(),
    'Paywall': const PaywallScreen(),
    'FreePlan': const FreePlanScreen(),
    'Winback': const WinbackScreen(),
    'TrialEnding': const TrialEndingScreen(),
    'Onboarding': const OnboardingFlow(),
    for (final name in [
      'ObBirthYear',
      'ObSpend',
      'ObWorries',
      'ObReveal',
      'ObCoachName',
      'ObWhyWords',
      'ObCommit',
      'ObRating',
    ])
      name: const OnboardingFlow(),
    'FrameMap': const FrameMapScreen(),
    'EdgeStates': const EdgeStatesPreviewScreen(),
    'Moderation': const ModerationScreen(),
    'CoachMemories': const CoachMemoriesScreen(),
    // The screen every new account lands on straight out of the paywall, and
    // it was the one screen this sweep never opened.
    'Day1': const Day1Screen(),
  };

  /// Onboarding steps worth a layout pass of their own.
  ///
  /// `'Onboarding'` above only ever renders the welcome screen. These are the
  /// screens this change added copy to, and the ones whose new cards sit
  /// inside `StepScrollView`'s `IntrinsicHeight` — the walk that took the
  /// Health screen down when something below it reported an infinite height.
  const previewed = {
    'ObBirthYear': ObStep.birthYear,
    'ObSpend': ObStep.spend,
    'ObWorries': ObStep.worries,
    'ObReveal': ObStep.reveal,
    'ObCoachName': ObStep.coachName,
    'ObWhyWords': ObStep.whyWords,
    'ObCommit': ObStep.commit,
    'ObRating': ObStep.rating,
  };

  /// A small phone and a large one, both logical pixels at dpr 1.
  const sizes = {'small': Size(360, 640), 'tall': Size(430, 932)};

  /// Overflow is deliberately NOT a failure here.
  ///
  /// `flutter test` substitutes a fallback font whose every glyph is a square
  /// em box, so text is far wider than Space Grotesk or Inter ever renders it
  /// — and a sweep that failed on overflow would report twenty screens broken
  /// that the on-device run lays out cleanly. Real overflow is caught by the
  /// device suite and by looking at the app.
  ///
  /// What IS caught here is the font-independent class: a constraint that is
  /// infinite or unsatisfiable, or a box that never got laid out. That is what
  /// took the Health screen down, and it is fatal on every device and font.
  bool isFontWidthArtifact(Object error) =>
      error.toString().contains('overflowed');

  String firstLineOf(Object error) =>
      error.toString().split(RegExp(r'\r?\n')).first;

  for (final theme in {'midnight': LpTheme.midnight(), 'daylight': LpTheme.daylight()}.entries) {
    for (final size in sizes.entries) {
      for (final screen in screens.entries) {
        testWidgets('${screen.key} lays out (${theme.key}, ${size.key})', (
          tester,
        ) async {
          tester.view.physicalSize = size.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final container = ProviderContainer(overrides: fastBackendOverrides());
          addTearDown(container.dispose);
          // A live day-12 journey: the state most screens are written for, and
          // the one that has completed milestones, goals, streaks and history.
          container.read(quitStoreProvider.notifier).seedDemoJourney();
          final step = previewed[screen.key];
          if (step != null) {
            container.read(onboardingProvider.notifier).previewStep(step);
          }

          // Collected individually: `takeException` folds several errors into
          // one "Multiple exceptions" wrapper, which would make the overflow
          // exclusion above impossible to apply.
          final errors = <Object>[];
          final priorHandler = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(details.exception);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: theme.value,
                localizationsDelegates:
                    AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: screen.value,
              ),
            ),
          );
          // Two pumps rather than pumpAndSettle: several screens animate
          // forever by design, and the first frame is where layout throws.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          FlutterError.onError = priorHandler;

          final real = errors.where((e) => !isFontWidthArtifact(e)).toList();
          expect(
            real,
            isEmpty,
            reason: '${screen.key} threw while laying out: '
                '${real.map(firstLineOf).toList()}',
          );
        });
      }
    }
  }
}
