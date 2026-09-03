import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/network/connectivity.dart';
import 'package:last_puff/data/stores/coach_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// A dropped coach reply gets a button, not just an apology.
///
/// Ember already owned the miss in-thread ("signal dropped mid-thought…"),
/// but the only way to try again was to retype the message. On the Day-1
/// walkthrough — where that reply is the one thing the step waits for — an
/// iPhone user with a flaky connection read it as the app breaking.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  /// The app on the coach tab, offline from the first frame.
  Future<ProviderContainer> pumpOfflineCoach(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: fastBackendOverrides(online: false),
    );
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
    container.read(routerProvider).go(Routes.coach);
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
  }

  void goOnline(ProviderContainer c) =>
      (c.read(connectivityProvider.notifier) as ToggleConnectivity).set(true);

  testWidgets('a dropped reply offers "run it back", and it re-asks once', (
    tester,
  ) async {
    final container = await pumpOfflineCoach(tester);
    await send(tester, 'hi ember');

    var coach = container.read(coachStoreProvider);
    expect(coach.messages.last.template, CoachTemplate.connectionLost);
    expect(find.text(l10n.errorRetry), findsOneWidget);

    goOnline(container);
    await tester.tap(find.text(l10n.errorRetry));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    coach = container.read(coachStoreProvider);
    final asked = coach.messages.where(
      (m) => m.role == CoachRole.user && m.text == 'hi ember',
    );
    expect(asked.length, 1, reason: 'the question must not appear twice');
    expect(CoachStore.isFailure(coach.messages.last), isFalse);
    expect(coach.messages.last.role, CoachRole.ember);
    expect(
      coach.messages.any(CoachStore.isFailure),
      isFalse,
      reason: 'the failure line comes down when the retry lands',
    );
    expect(find.text(l10n.errorRetry), findsNothing);
  });

  testWidgets('the button only ever answers the LAST line', (tester) async {
    // A failure earlier in the thread is history, not an open offer — the
    // store re-sends only when the thread ends in that exact pair.
    final container = await pumpOfflineCoach(tester);
    await send(tester, 'first');
    goOnline(container);
    await send(tester, 'second');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text(l10n.errorRetry), findsNothing);
    final before = container.read(coachStoreProvider).messages.length;
    await container.read(coachStoreProvider.notifier).retryLast();
    expect(container.read(coachStoreProvider).messages.length, before);
  });

  testWidgets('a refused build is not offered a retry', (tester) async {
    // That failure repeats identically until the build is fixed; a button
    // there would promise what it cannot deliver. The line says "we're on
    // it", and that is the whole of what can honestly be said.
    final container = await pumpOfflineCoach(tester);
    await send(tester, 'hello');
    final store = container.read(coachStoreProvider.notifier);
    final msgs = container.read(coachStoreProvider).messages;
    // Swap the wire failure for the refusal, in place.
    store.state = container.read(coachStoreProvider).copyWith(
      messages: [
        ...msgs.sublist(0, msgs.length - 1),
        CoachMessage.ember(
          id: 'refused',
          template: CoachTemplate.backendRejected,
          sentAt: DateTime.now(),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.coachBackendRejected), findsOneWidget);
    expect(find.text(l10n.errorRetry), findsNothing);
  });
}
