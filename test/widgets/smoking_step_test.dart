import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/onboarding/onboarding_flow.dart';
import 'package:last_puff/features/onboarding/onboarding_view_model.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// docs/15 QP-A2: "Have you ever smoked cigarettes?" — three one-tap answers
/// between the first-puff question and the why.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(container.dispose);
    // `previewStep` fills every answer in, which would hide the empty state
    // this test is about; start from a draft that has reached the step cold.
    container.read(onboardingProvider.notifier).state = const OnboardingState(
      step: ObStep.smoking,
    );

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
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  testWidgets('asks the question and offers the three answers', (tester) async {
    await pump(tester);

    expect(find.text(l10n.obSmokingTitle), findsOneWidget);
    expect(find.text(l10n.obSmokingNever), findsOneWidget);
    expect(find.text(l10n.obSmokingFormer), findsOneWidget);
    expect(find.text(l10n.obSmokingCurrent), findsOneWidget);
    // Position 9 of 13: after the first-puff question.
    expect(find.text(l10n.obProgressOf(9, 13)), findsOneWidget);
  });

  testWidgets('Continue waits for an answer, then moves on to the why', (
    tester,
  ) async {
    final container = await pump(tester);
    ObStep step() => container.read(onboardingProvider).step;

    await tester.tap(find.text(l10n.commonContinue));
    await tester.pump(const Duration(milliseconds: 400));
    expect(step(), ObStep.smoking, reason: 'no answer yet, so no way forward');

    await tester.tap(find.text(l10n.obSmokingFormer));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      container.read(onboardingProvider).smoking,
      SmokingHistory.former,
    );

    await tester.tap(find.text(l10n.commonContinue));
    await tester.pump(const Duration(milliseconds: 400));
    expect(step(), ObStep.why);
  });

  testWidgets('shows the one rule under an answer that needs it, and only then', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text(l10n.smokingRuleBody), findsNothing);

    await tester.tap(find.text(l10n.obSmokingFormer));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text(l10n.smokingRuleBody), findsOneWidget);
    expect(find.text(l10n.smokingRuleCurrent), findsNothing);

    await tester.tap(find.text(l10n.obSmokingCurrent));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text(l10n.smokingRuleBody), findsOneWidget);
    expect(find.text(l10n.smokingRuleCurrent), findsOneWidget);

    // Changing their mind takes it away again.
    await tester.tap(find.text(l10n.obSmokingNever));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text(l10n.smokingRuleBody), findsNothing);
  });

  testWidgets('each answer is recorded as itself', (tester) async {
    final container = await pump(tester);

    for (final (label, answer) in [
      (l10n.obSmokingCurrent, SmokingHistory.current),
      (l10n.obSmokingNever, SmokingHistory.never),
      (l10n.obSmokingFormer, SmokingHistory.former),
    ]) {
      await tester.tap(find.text(label));
      expect(container.read(onboardingProvider).smoking, answer, reason: label);
    }
    // `PressScale` schedules a 120ms `Future.delayed` after each tap; the
    // harness fails a test that ends with it still pending.
    await tester.pump(const Duration(milliseconds: 400));
  });
}
