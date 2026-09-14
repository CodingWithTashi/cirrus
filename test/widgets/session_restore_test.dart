import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/network/connectivity.dart';
import 'package:last_puff/data/repositories/api_auth_repository.dart';
import 'package:last_puff/data/repositories/api_journey_repository.dart';
import 'package:last_puff/data/stores/journey_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/features/auth/auth_screens.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// Reopening the app while signed in (docs/10 §40).
///
/// Launch read the journey with a hard five-second budget and treated every
/// failure — a timeout on a waking radio included — as "signed out", so a
/// returning user was sent to the sign-in screen for an account they were
/// still signed into. A slow read now uses the copy the device keeps (the
/// Firebase repository does that part), and with no copy either the splash
/// offers a retry. Sign-in is for nobody being signed in, and nothing else.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  String path(ProviderContainer c) => c.read(routerProvider).state.uri.path;

  Future<ProviderContainer> launch(
    WidgetTester tester, {
    required bool online,
    required bool signedIn,
  }) async {
    final container = ProviderContainer(
      overrides: fastBackendOverrides(online: online),
    );
    addTearDown(container.dispose);
    if (signedIn) container.read(fakeServerProvider).signIn('back@test');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    return container;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  group('the launch', () {
    testWidgets('signed in, journey out of reach: a retry, never sign-in', (
      tester,
    ) async {
      final container = await launch(tester, online: false, signedIn: true);

      expect(find.byType(SignInScreen), findsNothing);
      expect(path(container), Routes.splash);
      expect(find.text(l10n.splashJourneyUnavailableTitle), findsOneWidget);
      expect(find.text(l10n.errorRetry), findsOneWidget);
    });

    testWidgets('Retry that still cannot reach it stays a retry', (
      tester,
    ) async {
      final container = await launch(tester, online: false, signedIn: true);

      await tester.tap(find.text(l10n.errorRetry));
      await settle(tester);

      expect(find.byType(SignInScreen), findsNothing);
      expect(path(container), Routes.splash);
      expect(find.text(l10n.splashJourneyUnavailableTitle), findsOneWidget);
    });

    testWidgets('the connection coming back retries by itself', (tester) async {
      final container = await launch(tester, online: false, signedIn: true);

      (container.read(connectivityProvider.notifier) as ToggleConnectivity).set(
        true,
      );
      await settle(tester);

      expect(container.read(quitStoreProvider), isNotNull);
      expect(path(container), Routes.home);
    });

    testWidgets('nobody signed in and offline: sign-in, as before', (
      tester,
    ) async {
      final container = await launch(tester, online: false, signedIn: false);
      expect(path(container), Routes.auth);
    });

    testWidgets('signed in and online: straight to Home', (tester) async {
      final container = await launch(tester, online: true, signedIn: true);
      expect(path(container), Routes.home);
    });
  });

  group('the copy a slow launch restored', () {
    final now = DateTime(2026, 9, 13, 10);

    /// Launch answered with the device's copy; the server holds [server] and
    /// hands it over when the returned gate opens.
    (ProviderContainer, Completer<void>) wire(
      JourneyState deviceCopy,
      JourneyState server,
    ) {
      final gate = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          ...fastBackendOverrides(now: now),
          authRepositoryProvider.overrideWith(
            (ref) => _RestoresCopy(ref.watch(authApiProvider), deviceCopy),
          ),
          journeyRepositoryProvider.overrideWith(
            (ref) => _ServerHolds(ref.watch(journeyApiProvider), server, gate),
          ),
        ],
      );
      addTearDown(container.dispose);
      return (container, gate);
    }

    Future<void> drain() async {
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test(
      'gives way to a newer server copy when nothing changed here',
      () async {
        final device = journeyOnDay(5, now: now);
        final server = device.copyWith(cravingsSurvivedTotal: 3);
        final (c, gate) = wire(device, server);

        final outcome = await c
            .read(quitStoreProvider.notifier)
            .restoreSession();
        expect(outcome, SessionRestore.restored);
        expect(c.read(quitStoreProvider)!.cravingsSurvivedTotal, 0);

        gate.complete();
        await drain();
        expect(c.read(quitStoreProvider)!.cravingsSurvivedTotal, 3);
      },
    );

    test('keeps a change made here before the server answered', () async {
      final device = journeyOnDay(5, now: now);
      final server = device.copyWith(cravingsSurvivedTotal: 3);
      final (c, gate) = wire(device, server);
      final store = c.read(quitStoreProvider.notifier);

      await store.restoreSession();
      store.logPuff();
      gate.complete();
      await drain();

      final journey = c.read(quitStoreProvider)!;
      expect(journey.logFor(now)?.puffs, 1, reason: 'the tap is not undone');
      expect(journey.cravingsSurvivedTotal, 0);
    });

    test('an identical server copy changes nothing', () async {
      final device = journeyOnDay(5, now: now);
      final (c, gate) = wire(device, device);

      await c.read(quitStoreProvider.notifier).restoreSession();
      final restored = c.read(quitStoreProvider);
      gate.complete();
      await drain();

      expect(identical(c.read(quitStoreProvider), restored), isTrue);
    });
  });
}

class _RestoresCopy extends ApiAuthRepository {
  _RestoresCopy(super.api, this.copy);

  final JourneyState copy;

  @override
  Future<JourneyState?> restoreSession() async => copy;
}

class _ServerHolds extends ApiJourneyRepository {
  _ServerHolds(super.api, this.server, this.gate);

  final JourneyState server;
  final Completer<void> gate;

  @override
  Future<JourneyState?> fetchLatest() async {
    await gate.future;
    return server;
  }
}
