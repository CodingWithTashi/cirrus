import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';
import 'package:last_puff/features/panic/panic_screens.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// The panic flow's server hop (`panicSession`, docs/03 §7 + docs/04 §7).
///
/// The rule these protect is the one docs/04 §7 states outright: never
/// hard-block someone mid-crisis. The server's answer may take the AI layer
/// away; it may not take the flow away, and it may not make the screen wait
/// for a round-trip.
void main() {
  late _StubPanic panic;

  setUp(() => panic = _StubPanic());

  /// Mounts just enough app to own a ProviderScope. The panic view model is
  /// route-scoped, so reading the notifier is exactly what a route push does.
  Future<ProviderContainer> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...fastBackendOverrides(),
          panicRepositoryProvider.overrideWithValue(panic),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox.shrink(),
        ),
      ),
    );
    return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  }

  testWidgets('opening the flow tells the server a craving started', (
    tester,
  ) async {
    final c = await mount(tester);
    c.read(panicProvider);
    await tester.pumpAndSettle();

    expect(panic.begins, 1);
    // And the first step is already on screen — nothing awaited the call.
    expect(c.read(panicProvider).step, 0);
  });

  testWidgets('a survived craving is reported with its intensity', (
    tester,
  ) async {
    final c = await mount(tester);
    c.read(quitStoreProvider.notifier).seedDemoJourney();
    final before = c.read(quitStoreProvider)!.cravingsSurvivedTotal;

    c.read(panicProvider.notifier).setIntensity(9);
    c.read(panicProvider.notifier).survive();
    await tester.pumpAndSettle();

    expect(panic.survivedIntensities, [9]);
    // The user's own count still moves locally — the report is telemetry, not
    // the source of truth for the number on their screen.
    expect(c.read(quitStoreProvider)!.cravingsSurvivedTotal, before + 1);
  });

  testWidgets('an unreachable server leaves the AI option offered', (
    tester,
  ) async {
    panic.failure = const NoConnectionException();
    final c = await mount(tester);
    c.read(panicProvider);
    await tester.pumpAndSettle();

    // Optimistic on purpose: withholding help because wifi dropped is the one
    // outcome worse than an over-quota model call.
    expect(c.read(panicProvider).availability.aiAvailable, isTrue);
  });

  testWidgets('a spent free allowance narrows the AI layer, not the flow', (
    tester,
  ) async {
    panic.result = const PanicAvailability(
      aiAvailable: false,
      sessionsToday: 2,
    );
    final c = await mount(tester);
    c.read(panicProvider);
    await tester.pumpAndSettle();

    expect(c.read(panicProvider).availability.aiAvailable, isFalse);
    // The session itself is untouched: breathing, the why card and the tap
    // game are all still where they were.
    expect(c.read(panicProvider).step, 0);
  });
}

class _StubPanic implements PanicRepository {
  int begins = 0;
  final survivedIntensities = <int>[];
  PanicAvailability result = PanicAvailability.unknown;
  Object? failure;

  @override
  Future<PanicAvailability> begin() async {
    begins++;
    if (failure != null) throw failure!;
    return result;
  }

  @override
  Future<void> survived({required int intensity}) async {
    survivedIntensities.add(intensity);
    if (failure != null) throw failure!;
  }
}
