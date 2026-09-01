import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/journey_state.dart';

import 'harness.dart';

/// The hook loop itself (docs/03 §1): log a puff, undo it, cross the line,
/// burn a repair token, and land in the recovery flow.
///
/// These are the paths that run hundreds of times a day per user, and the
/// edge cases are where the streak silently breaks — a token spent twice, an
/// undo that removes the wrong hour, an over-limit day that zeroes a streak it
/// should only dim.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<E2E> signedIn(WidgetTester tester) async {
    final e2e = await E2E.boot(tester);
    await e2e.waitFor(const Duration(seconds: 2));
    await e2e.tapText(e2e.l10n.authContinueWithEmail);
    await e2e.tapSpan(e2e.l10n.authLogIn);
    await e2e.enterField(e2e.l10n.authEmailLabel, 'maya@quitmail.com');
    await e2e.enterField(e2e.l10n.authPasswordLabel, 'secret1');
    await e2e.tapText(e2e.l10n.authLogIn);
    await e2e.waitFor(const Duration(seconds: 3));
    expect(e2e.container.read(quitStoreProvider), isNotNull,
        reason: 'sign-in failed; on screen: ${e2e.texts()}');
    return e2e;
  }

  int puffsToday(E2E e2e) =>
      e2e.container.read(todayProvider)?.puffs ?? -1;

  testWidgets('logging a puff moves the ring and the undo snack appears', (
    tester,
  ) async {
    final e2e = await signedIn(tester);
    final before = puffsToday(e2e);

    await e2e.tapText(e2e.l10n.homeLogPuff);

    expect(puffsToday(e2e), before + 1);
    // The undo affordance is the whole reason a mis-tap is not a lost day.
    expect(await e2e.waitForText(e2e.l10n.commonUndo), isTrue,
        reason: 'no undo snack; on screen: ${e2e.texts()}');
  });

  testWidgets('undo removes exactly the puff just logged', (tester) async {
    final e2e = await signedIn(tester);
    final before = puffsToday(e2e);

    await e2e.tapText(e2e.l10n.homeLogPuff);
    expect(puffsToday(e2e), before + 1);
    expect(await e2e.waitForText(e2e.l10n.commonUndo), isTrue);
    await e2e.tapText(e2e.l10n.commonUndo);

    expect(puffsToday(e2e), before,
        reason: 'undo did not restore the count');
  });

  testWidgets('crossing the line burns one repair token, and only one', (
    tester,
  ) async {
    final e2e = await signedIn(tester);
    final store = e2e.container.read(quitStoreProvider.notifier);
    final journey = e2e.container.read(quitStoreProvider)!;
    final today = JourneyState.dateKey(DateTime.now());
    final limit = e2e.container.read(todayProvider)!.limit;

    // Park exactly on the line, so the very next tap is the one that crosses
    // it. The wallet is DERIVED from history (docs/03 §5, one token per seven
    // completed holding days — QA H2 found the stored one re-minted itself),
    // and the seeded demo's eleven clean days fund exactly one token.
    store.replaceForTest(
      journey.copyWith(
        days: {
          ...journey.days,
          today: journey.days[today]!.copyWith(
            puffs: limit,
            repairTokenUsed: false,
          ),
        },
      ),
    );
    await e2e.settle();

    await e2e.tapText(e2e.l10n.homeLogPuff);
    final afterFirst = e2e.container.read(quitStoreProvider)!;
    expect(afterFirst.days[today]!.repairTokenUsed, isTrue,
        reason: 'the one token the eleven-day chain earned was not spent');
    expect(afterFirst.repairTokens, 0, reason: 'token not deducted');
    expect(afterFirst.pendingSlipCleanDays, isNull,
        reason: 'the token absorbed the slip; recovery must not arm');
    // docs/03 §5: the token is spent silently and the flame dims rather than
    // dying — the user is told, once.
    expect(await e2e.waitForText(e2e.l10n.homeTokenUsedNote), isTrue,
        reason: 'on screen: ${e2e.texts()}');

    // Every further puff the same day is already over the line; a second
    // token must not be spent for the same slip, and recovery must not arm.
    await e2e.tapText(e2e.l10n.homeLogPuff);
    await e2e.tapText(e2e.l10n.homeLogPuff);
    final afterMore = e2e.container.read(quitStoreProvider)!;
    expect(afterMore.repairTokens, 0);
    expect(afterMore.pendingSlipCleanDays, isNull,
        reason: 'a second crossing was counted on the same over-limit day');
  });

  testWidgets('with no token left, crossing the line arms slip recovery', (
    tester,
  ) async {
    final e2e = await signedIn(tester);
    final store = e2e.container.read(quitStoreProvider.notifier);
    final journey = e2e.container.read(quitStoreProvider)!;
    final today = JourneyState.dateKey(DateTime.now());
    final limit = e2e.container.read(todayProvider)!.limit;

    // Only the last three completed days survive, so the derived wallet has
    // never earned a token (seven holding days mint one).
    final recent = journey.days.keys.toList()..sort();
    final kept = recent.sublist(recent.length - 4);
    store.replaceForTest(
      journey.copyWith(
        days: {
          for (final d in kept)
            d: d == today
                ? journey.days[today]!.copyWith(puffs: limit)
                : journey.days[d]!,
        },
      ),
    );
    await e2e.settle();

    await e2e.tapText(e2e.l10n.homeLogPuff);
    expect(e2e.container.read(quitStoreProvider)!.pendingSlipCleanDays,
        isNotNull,
        reason: 'recovery never armed; on screen: ${e2e.texts()}');
  });

  testWidgets('slip recovery stretches Freedom Day, and dismiss does not', (
    tester,
  ) async {
    final e2e = await signedIn(tester);
    final store = e2e.container.read(quitStoreProvider.notifier);
    final before = e2e.container.read(quitStoreProvider)!.plan.freedomDate;

    store.dismissSlipRecovery();
    await e2e.settle(frames: 10);
    expect(e2e.container.read(quitStoreProvider)!.plan.freedomDate, before,
        reason: 'dismissing must not move the plan');

    store.applySlipRecovery();
    await e2e.settle(frames: 10);
    expect(
      e2e.container.read(quitStoreProvider)!.plan.freedomDate.isAfter(before),
      isTrue,
      reason: 'recovery did not stretch the runway',
    );
  });

  testWidgets('a craving survived through the real panic flow is counted', (
    tester,
  ) async {
    final e2e = await signedIn(tester);
    final before =
        e2e.container.read(quitStoreProvider)!.cravingsSurvivedTotal;

    // Enter the takeover the way the Home screen does.
    await e2e.tapText(e2e.l10n.homeSos);
    await e2e.waitFor(const Duration(seconds: 2));

    // Step 1 is the breathing pacer; skip straight to the why card, which is
    // the documented escape hatch.
    if (e2e.showing(e2e.l10n.panicSkipToWhy)) {
      await e2e.tapText(e2e.l10n.panicSkipToWhy);
    }
    await e2e.waitFor(const Duration(seconds: 1));
    if (e2e.showing(e2e.l10n.panicStillCraving)) {
      await e2e.tapText(e2e.l10n.panicStillCraving);
    }
    await e2e.waitFor(const Duration(seconds: 1));

    expect(e2e.showing(e2e.l10n.panicItPassed), isTrue,
        reason: 'never reached the loop breakers; on screen: ${e2e.texts()}');
    await e2e.tapText(e2e.l10n.panicItPassed);
    await e2e.waitFor(const Duration(seconds: 2));

    expect(e2e.container.read(quitStoreProvider)!.cravingsSurvivedTotal,
        before + 1);
  });

  testWidgets('logging stays optimistic offline — no dialog, no lost tap', (
    tester,
  ) async {
    final e2e = await E2E.boot(tester);
    await e2e.waitFor(const Duration(seconds: 2));
    await e2e.tapText(e2e.l10n.authContinueWithEmail);
    await e2e.tapSpan(e2e.l10n.authLogIn);
    await e2e.enterField(e2e.l10n.authEmailLabel, 'maya@quitmail.com');
    await e2e.enterField(e2e.l10n.authPasswordLabel, 'secret1');
    await e2e.tapText(e2e.l10n.authLogIn);
    await e2e.waitFor(const Duration(seconds: 3));

    // Drop the connection AFTER the session exists — the local-first stance
    // says the tap still counts and the banner carries the whole story.
    await e2e.setOnline(false);

    final before = puffsToday(e2e);
    await e2e.tapText(e2e.l10n.homeLogPuff);

    expect(puffsToday(e2e), before + 1, reason: 'an offline tap was lost');
    expect(e2e.visible(e2e.l10n.errorGenericTitle), isFalse,
        reason: 'a background save failure must never raise a dialog');
  });
}
