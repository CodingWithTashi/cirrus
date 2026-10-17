import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
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
  }) async {
    final permissions = _Permissions(status);
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        pushPermissionsProvider.overrideWithValue(permissions),
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
      final (container, _) = await pumpApp(tester);
      // Pushed over the shell, as the panic flow does.
      unawaited(container.read(routerProvider).push(Routes.survived));
      await tester.pump(const Duration(seconds: 2));

      await leaveSurvived(tester);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(l10n.pushAskSurvivedTitle), findsNothing);
      expect(path(container), Routes.home);
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
