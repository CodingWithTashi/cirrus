import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/core/widgets/lp_misc.dart';
import 'package:last_puff/features/onboarding/onboarding_flow.dart';
import 'package:last_puff/features/onboarding/onboarding_view_model.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// iPhone 15, TestFlight, Sep 2 2026: "during onboarding there is no going
/// back at all — each screen is forward only."
///
/// The header chevron was shown only on the twelve quiz steps, because the
/// condition was "has a progress bar". On Android nobody noticed: the system
/// back gesture reaches `PopScope` and calls `vm.back()` from any step. iOS
/// has no system back — no hardware key, and no edge swipe either, since the
/// whole funnel is one route whose steps swap in place — so on an iPhone the
/// chevron IS back, and six screens (reveal, coach name, why-words, commit,
/// rating, notifications) had none.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<ProviderContainer> pump(WidgetTester tester, ObStep step) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(container.dispose);
    container.read(onboardingProvider.notifier).previewStep(step);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LpTheme.midnight(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const OnboardingFlow(),
        ),
      ),
    );
    // Fixed pumps throughout: several steps carry looping animations
    // (the welcome shimmer, the blinking caret) that never settle.
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  ObStep stepOf(ProviderContainer c) => c.read(onboardingProvider).step;

  group('every Phase D screen can go back', () {
    const pairs = [
      (ObStep.reveal, ObStep.pace),
      (ObStep.coachName, ObStep.reveal),
      (ObStep.whyWords, ObStep.coachName),
      (ObStep.commit, ObStep.whyWords),
      (ObStep.rating, ObStep.commit),
      (ObStep.notifications, ObStep.rating),
    ];
    for (final (step, previous) in pairs) {
      testWidgets('${step.name} → ${previous.name}', (tester) async {
        final container = await pump(tester, step);

        expect(
          find.byType(BackChevron),
          findsOneWidget,
          reason: '${step.name} has no way back on an iPhone',
        );
        await tester.tap(find.byType(BackChevron));
        await tester.pump(const Duration(milliseconds: 400));

        expect(stepOf(container), previous);
      });
    }
  });

  testWidgets('a quiz step keeps its progress beside the chevron', (
    tester,
  ) async {
    final container = await pump(tester, ObStep.spend);

    expect(find.byType(BackChevron), findsOneWidget);
    expect(find.text(l10n.obProgressOf(7, 12)), findsOneWidget);

    await tester.tap(find.byType(BackChevron));
    await tester.pump(const Duration(milliseconds: 400));
    expect(stepOf(container), ObStep.strength);
  });

  testWidgets('the entry screen offers no back', (tester) async {
    // Leaving welcome means leaving the funnel, which is the sign-in
    // screen's business, not a chevron's.
    await pump(tester, ObStep.welcome);
    expect(find.byType(BackChevron), findsNothing);
    expect(find.byType(GlowProgressBar), findsNothing);
  });

  testWidgets('the age-gate screen offers no back', (tester) async {
    // It carries its own "let me fix that", which is the honest way out.
    await pump(tester, ObStep.under18);
    expect(find.byType(BackChevron), findsNothing);
  });

  testWidgets('the building animation offers no back, and ignores one', (
    tester,
  ) async {
    // It advances itself a few seconds in. A back that landed on `pace`
    // would be overtaken by that timer, so `back()` is a no-op here — from
    // the Android gesture as much as from a chevron that is not shown.
    final container = await pump(tester, ObStep.building);
    expect(find.byType(BackChevron), findsNothing);

    expect(container.read(onboardingProvider.notifier).back(), isTrue);
    expect(stepOf(container), ObStep.building);

    // Let the animation run out so it advances on its own, not into a step
    // the user had left.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(stepOf(container), ObStep.reveal);
  });

  testWidgets('going back during the commit celebration is not undone', (
    tester,
  ) async {
    // The commit step advances itself 1.4 s after the hold completes. That
    // timer used to call `next()` unconditionally; a chevron tap in that
    // window then had the timer advance the screen they went back to.
    final container = await pump(tester, ObStep.commit);
    final vm = container.read(onboardingProvider.notifier);

    // The commit itself, via the store — the hold gesture is covered by
    // commit_step_test; this is about the timer that follows it.
    vm.markCommitted();
    await tester.tap(find.byType(BackChevron));
    await tester.pump(const Duration(milliseconds: 400));
    expect(stepOf(container), ObStep.whyWords);

    await tester.pump(const Duration(seconds: 2));
    expect(
      stepOf(container),
      ObStep.whyWords,
      reason: 'the commit timer advanced a screen the user had gone back to',
    );
  });
}
