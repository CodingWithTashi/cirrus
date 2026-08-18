import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/data/stores/providers.dart';

import 'helpers.dart';

void main() {
  // Instant fake network + no connectivity polling — pumpAndSettle must
  // never wait out simulated latency or hit real DNS.
  final overrides = fastBackendOverrides();

  testWidgets('boots to splash and lands on sign-in when signed out', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: const LastPuffApp()),
    );
    expect(find.text('LastPuff'), findsWidgets);

    // Splash auto-advances after 1.5s.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Sign in with Apple'), findsOneWidget);
  });

  testWidgets('signed-in demo journey lands on Today with live numbers', (
    tester,
  ) async {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    container.read(quitStoreProvider.notifier).seedDemoJourney();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('LOG PUFF'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);

    // Day 12 of the seeded 30-day taper, with the full streak intact —
    // every seeded day must hold its own curve limit.
    final journey = container.read(quitStoreProvider)!;
    expect(journey.plan.dayNumber(DateTime.now()), 12);
    expect(container.read(todayProvider)!.streak, 12);
  });

  testWidgets('Daylight Ember theme renders Home on the light ground', (
    tester,
  ) async {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    container
        .read(settingsStoreProvider.notifier)
        .setThemeMode(ThemeMode.light);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    final homeContext = tester.element(find.text('Today'));
    expect(
      Theme.of(homeContext).scaffoldBackgroundColor,
      const Color(0xFFF6F8F4),
      reason: 'Daylight Ember ground (Run 2 Light) must back every screen',
    );
    // And the dark ground when flipped to Midnight.
    container.read(settingsStoreProvider.notifier).setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    final darkContext = tester.element(find.text('Today'));
    expect(
      Theme.of(darkContext).scaffoldBackgroundColor,
      const Color(0xFF0A0C10),
      reason: 'Midnight Ember ground must back every screen',
    );
  });
}
