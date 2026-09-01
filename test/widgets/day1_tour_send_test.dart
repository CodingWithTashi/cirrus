import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/day1_tour_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// QA L4 (Aug 31 2026, production): on Day-1 tour step two the composer's
/// in-app send arrow was dead — two taps swallowed — while the keyboard's
/// IME send worked. A user whose keyboard has no send key was stuck on the
/// one step that requires a real send.
///
/// Why: the spotlight measures its target rect ONCE, when the step starts.
/// Tapping the field opens the keyboard, the composer slides up above it,
/// and the send arrow now sits outside the hole the barrier left — so the
/// barrier eats the tap. The IME key never touches the screen, which is why
/// it worked. The existing tour test sent through the IME too, so it never
/// saw this.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the send arrow works after the keyboard moves the composer', (
    tester,
  ) async {
    final container = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    final store = container.read(quitStoreProvider.notifier);
    store.replaceForTest(
      container.read(quitStoreProvider)!.copyWith(day1TasksDone: const {0}),
    );
    container.read(routerProvider).go(Routes.day1);
    await tester.pumpAndSettle();

    // Step two, the way a user reaches it.
    await tester.tap(find.text(l10n.day1Task2).first);
    await tester.pumpAndSettle();
    expect(container.read(day1TourStepProvider), Day1TourStep.meetCoach);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Tap the field: the keyboard comes up and the whole composer moves.
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hi ember');
    await tester.pumpAndSettle();

    // The in-app arrow, not the IME key.
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    final messages = container.read(coachStoreProvider).messages;
    expect(
      messages.any((m) => m.role == CoachRole.user && m.text == 'hi ember'),
      isTrue,
      reason: 'the arrow tap was swallowed by the spotlight barrier',
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
