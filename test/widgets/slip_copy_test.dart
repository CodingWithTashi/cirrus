import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// QA L2 (Aug 31 2026, production): picked "Stress" in the slip flow, and
/// the adjustment screen said "Party nights get a pre-armed nudge + game
/// shortcut". The note was one fixed string regardless of the chip — it
/// named a trigger the user never chose, which is an invented fact about
/// them. The note follows the trigger now, and never promises a feature
/// the app does not have.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<ProviderContainer> openSlip(WidgetTester tester) async {
    final container = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    final store = container.read(quitStoreProvider.notifier);
    store.seedDemoJourney();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    // Arm the flow the way an over-limit day does.
    final journey = container.read(quitStoreProvider)!;
    final today = JourneyState.dateKey(DateTime.now());
    store.replaceForTest(
      journey.copyWith(
        pendingSlipCleanDays: () => 11,
        days: {
          ...journey.days,
          today: journey.days[today]!.copyWith(
            puffs: journey.days[today]!.limit + 5,
          ),
        },
      ),
    );
    container.read(routerProvider).go(Routes.slip);
    await tester.pumpAndSettle();
    expect(find.text(l10n.slipTitle), findsOneWidget);
    return container;
  }

  Future<void> pickAndAdjust(WidgetTester tester, String chip) async {
    await tester.tap(find.text(chip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.slipAdjustCta));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  testWidgets('Stress gets the stress note, never the party one', (
    tester,
  ) async {
    final container = await openSlip(tester);

    await pickAndAdjust(tester, l10n.slipTriggerStress);

    expect(
      container.read(quitStoreProvider)!.logFor(DateTime.now())?.slipTrigger,
      SlipTrigger.stress,
    );
    expect(find.text(l10n.slipCurveNoteStress), findsOneWidget);
    expect(find.text(l10n.slipCurveNoteParty), findsNothing);
  });

  testWidgets('Party gets the party note', (tester) async {
    await openSlip(tester);

    await pickAndAdjust(tester, l10n.slipTriggerParty);

    expect(find.text(l10n.slipCurveNoteParty), findsOneWidget);
  });

  testWidgets('"Just happened" gets a note that names no trigger', (
    tester,
  ) async {
    await openSlip(tester);

    await pickAndAdjust(tester, l10n.slipTriggerJustHappened);

    expect(find.text(l10n.slipCurveNoteJustHappened), findsOneWidget);
    expect(find.textContaining('Party'), findsNothing);
  });
}
