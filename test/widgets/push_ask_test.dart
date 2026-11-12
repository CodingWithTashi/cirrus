import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/utils/lp_review.dart';
import 'package:last_puff/data/api/firebase/push_service.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// The second notification ask, at the moments it pays (docs/10 §51).
///
/// 11 of 20 real people declined at onboarding's D4 screen in the Oct 5 2026
/// read, and "Maybe later" there never opens the OS dialog. Until Oct 16 the
/// only second chance was after a community post, so somebody who never
/// posted never got one — and docs/03 §8's re-ask after a survived craving was
/// documented and not built. Now: when the Day-1 checklist is finished, and
/// on the way out of the Survived screen. Still once, ever, and only while the
/// OS has never been asked.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<(ProviderContainer, _Permissions)> pumpApp(
    WidgetTester tester, {
    PushPermission status = PushPermission.notAsked,
    ReviewRoute? reviewRoute,
    DateTime Function()? clock,
  }) async {
    final permissions = _Permissions(status);
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        // A clock a test can move: the asks are rationed by calendar day.
        if (clock != null) nowProvider.overrideWithValue(clock),
        pushPermissionsProvider.overrideWithValue(permissions),
        // `flutter test` has no store, so the rating card never renders
        // unless a test says a tap on it would go somewhere.
        if (reviewRoute != null)
          reviewRouteProvider.overrideWith((_) async => reviewRoute),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    // The seeded day-12 journey, all three Day-1 tasks done.
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    return (container, permissions);
  }

  String path(ProviderContainer c) => c.read(routerProvider).state.uri.path;

  group('finishing the Day-1 checklist', () {
    Future<(ProviderContainer, _Permissions)> openDay1(
      WidgetTester tester, {
      PushPermission status = PushPermission.notAsked,
    }) async {
      final (container, permissions) = await pumpApp(tester, status: status);
      container.read(routerProvider).go(Routes.day1);
      await tester.pumpAndSettle();
      return (container, permissions);
    }

    testWidgets('asks once, with words about tonight, then goes Home', (
      tester,
    ) async {
      final (container, permissions) = await openDay1(tester);

      await tester.tap(find.text(l10n.day1CtaHome));
      await tester.pumpAndSettle();
      expect(find.text(l10n.pushAskDayOneTitle), findsOneWidget);
      // Leaving is not held hostage to the sheet's answer.
      await tester.tap(find.text(l10n.commonMaybeLater));
      await tester.pumpAndSettle();

      expect(path(container), Routes.home);
      expect(permissions.requests, 0);
      expect(container.read(settingsStoreProvider).pushPromptShown, isTrue);

      // Once, ever: the next finish goes straight Home.
      container.read(routerProvider).go(Routes.day1);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.day1CtaHome));
      await tester.pumpAndSettle();
      expect(find.text(l10n.pushAskDayOneTitle), findsNothing);
      expect(path(container), Routes.home);
    });

    testWidgets('a yes opens the OS prompt', (tester) async {
      final (container, permissions) = await openDay1(tester);

      await tester.tap(find.text(l10n.day1CtaHome));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.pushAskCta));
      await tester.pumpAndSettle();

      expect(permissions.requests, 1);
      expect(path(container), Routes.home);
    });

    testWidgets('never once the OS has answered', (tester) async {
      final (container, _) = await openDay1(
        tester,
        status: PushPermission.granted,
      );

      await tester.tap(find.text(l10n.day1CtaHome));
      await tester.pumpAndSettle();
      expect(find.text(l10n.pushAskDayOneTitle), findsNothing);
      expect(path(container), Routes.home);
    });
  });

  group('more than one second chance', () {
    // 41 of the 117 people who reached the permission step declined or
    // skipped it (Nov 11 2026), and "Maybe later" never opens the OS dialog —
    // so all of them were still askable. One ask, ever, across three moments
    // meant whichever came first spent it, usually within minutes of
    // onboarding. Each moment now has its own, a day apart at the least.
    var today = DateTime(2026, 11, 12, 15);
    setUp(() => today = DateTime(2026, 11, 12, 15));

    Future<void> finishDay1(WidgetTester tester, ProviderContainer c) async {
      c.read(routerProvider).go(Routes.day1);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.day1CtaHome));
      await tester.pumpAndSettle();
    }

    Future<void> surviveAndLeave(
      WidgetTester tester,
      ProviderContainer c,
    ) async {
      // The rating card is not due: it was answered today.
      c.read(settingsStoreProvider.notifier).markReviewAsked(today);
      unawaited(c.read(routerProvider).push(Routes.survived));
      await tester.pump(const Duration(seconds: 2));
      final back = find.text(l10n.survivedBack, skipOffstage: false);
      await tester.ensureVisible(back);
      await tester.pump();
      await tester.tap(find.text(l10n.survivedBack));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('a different moment on a later day asks again', (tester) async {
      final (container, _) = await pumpApp(tester, clock: () => today);
      await finishDay1(tester, container);
      expect(find.text(l10n.pushAskDayOneTitle), findsOneWidget);
      await tester.tap(find.text(l10n.commonMaybeLater));
      await tester.pumpAndSettle();

      today = DateTime(2026, 11, 13, 21);
      await surviveAndLeave(tester, container);

      expect(find.text(l10n.pushAskSurvivedTitle), findsOneWidget);
    });

    testWidgets('never two asks on the same day', (tester) async {
      final (container, _) = await pumpApp(tester, clock: () => today);
      await finishDay1(tester, container);
      await tester.tap(find.text(l10n.commonMaybeLater));
      await tester.pumpAndSettle();

      await surviveAndLeave(tester, container);

      expect(find.text(l10n.pushAskSurvivedTitle), findsNothing);
      expect(path(container), Routes.home);
    });

    testWidgets('the same moment never asks twice, however long after', (
      tester,
    ) async {
      final (container, _) = await pumpApp(tester, clock: () => today);
      await finishDay1(tester, container);
      await tester.tap(find.text(l10n.commonMaybeLater));
      await tester.pumpAndSettle();

      today = DateTime(2026, 11, 20, 9);
      await finishDay1(tester, container);

      expect(find.text(l10n.pushAskDayOneTitle), findsNothing);
      expect(path(container), Routes.home);
    });

    testWidgets('skipping setup is still a chance to be asked', (tester) async {
      // 14 people tapped "Skip setup for now" and went straight to Home; the
      // ask lived only on the button they did not press.
      final (container, _) = await pumpApp(tester, clock: () => today);
      container
          .read(quitStoreProvider.notifier)
          // A first day with nothing ticked — the fixture's default is a
          // finished checklist, which has no skip to tap.
          .replaceForTest(
            journeyOnDay(1, now: today).copyWith(day1TasksDone: const {}),
          );
      container.read(routerProvider).go(Routes.day1);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.text(l10n.day1Skip, skipOffstage: false),
      );
      await tester.pump();
      await tester.tap(find.text(l10n.day1Skip));
      await tester.pumpAndSettle();

      expect(find.text(l10n.pushAskDayOneTitle), findsOneWidget);
      await tester.tap(find.text(l10n.commonMaybeLater));
      await tester.pumpAndSettle();
      expect(path(container), Routes.home);
    });
  });

  group('the Survived screen', () {
    // Below the fold under the fallback test font, which is wider than the
    // device's.
    Future<void> leaveSurvived(WidgetTester tester) async {
      final back = find.text(l10n.survivedBack, skipOffstage: false);
      await tester.ensureVisible(back);
      await tester.pump();
      await tester.tap(find.text(l10n.survivedBack));
    }

    testWidgets('asks on the way out, with words about the next craving', (
      tester,
    ) async {
      final (container, _) = await pumpApp(tester);
      // The rating card is not due: it was answered today.
      container
          .read(settingsStoreProvider.notifier)
          .markReviewAsked(DateTime.now());
      // Pushed over the shell, as the panic flow does.
      unawaited(container.read(routerProvider).push(Routes.survived));
      await tester.pump(const Duration(seconds: 2));

      await leaveSurvived(tester);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(l10n.pushAskSurvivedTitle), findsOneWidget);
      await tester.tap(find.text(l10n.commonMaybeLater));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(path(container), Routes.home);
    });

    testWidgets('yields to the rating card: one ask per craving', (
      tester,
    ) async {
      // The seeded day-12 account has beaten enough cravings for the rating
      // card to be due, and has never been asked for one.
      final (container, _) = await pumpApp(
        tester,
        reviewRoute: ReviewRoute.sheet,
      );
      // Pushed over the shell, as the panic flow does.
      unawaited(container.read(routerProvider).push(Routes.survived));
      await tester.pump(const Duration(seconds: 2));
      // One more frame: the store route arrives a microtask after the push.
      await tester.pump();
      expect(
        find.text(l10n.reviewAskTitle, skipOffstage: false),
        findsOneWidget,
      );

      await leaveSurvived(tester);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(l10n.pushAskSurvivedTitle), findsNothing);
      expect(path(container), Routes.home);
    });

    testWidgets('a rating card that cannot show does not swallow the ask', (
      tester,
    ) async {
      // Due by policy, but a tap on it would go nowhere on this device (no
      // store, no sheet), so the card is not drawn. Yielding to a card that
      // is not there left the person asked nothing at all.
      final (container, _) = await pumpApp(
        tester,
        reviewRoute: ReviewRoute.none,
      );
      unawaited(container.read(routerProvider).push(Routes.survived));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text(l10n.reviewAskTitle, skipOffstage: false), findsNothing);

      await leaveSurvived(tester);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(l10n.pushAskSurvivedTitle), findsOneWidget);
    });
  });
}

class _Permissions implements PushPermissions {
  _Permissions(this._status);

  final PushPermission _status;
  int requests = 0;

  @override
  Future<PushPermission> status() async => _status;

  @override
  Future<bool> request() async {
    requests++;
    return true;
  }
}
