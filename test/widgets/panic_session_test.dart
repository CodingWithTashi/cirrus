import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
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

  /// Mounts the real PanicFlow against a container the TEST owns, so
  /// replacing the tree (what popping the route does) disposes the widget
  /// without disposing the providers underneath it.
  Future<ProviderContainer> mountFlow(WidgetTester tester) async {
    final c = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        panicRepositoryProvider.overrideWithValue(panic),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: LpTheme.midnight(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PanicFlow(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    return c;
  }

  Future<void> unmountFlow(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: LpTheme.midnight(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('closing the takeover does not throw', (tester) async {
    // Found by the on-device run: `dispose()` read `ref`, which Riverpod
    // forbids once the element is gone, so EVERY close of the panic flow threw
    // "Cannot use ref after the widget was disposed". The widget suite missed
    // it because nothing here had ever unmounted PanicFlow.
    final c = await mountFlow(tester);
    await unmountFlow(tester, c);

    expect(tester.takeException(), isNull);
  });

  testWidgets('closing without surviving reports the craving abandoned', (
    tester,
  ) async {
    final c = await mountFlow(tester);
    await unmountFlow(tester, c);

    expect(panic.survivedIntensities, isEmpty);
    expect(c.read(panicProvider).step, 0);
  });

  testWidgets('a survived craving is not also counted as abandoned', (
    tester,
  ) async {
    final c = await mountFlow(tester);
    c.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(milliseconds: 400));
    final before = c.read(quitStoreProvider)!.cravingsSurvivedTotal;

    c.read(panicProvider.notifier).survive();
    await tester.pump(const Duration(milliseconds: 400));
    await unmountFlow(tester, c);

    // survive() invalidates the notifier, so a `ref.read` in dispose would
    // hand back a FRESH, unresolved session and count this same craving twice.
    expect(tester.takeException(), isNull);
    expect(panic.survivedIntensities, hasLength(1));
    expect(c.read(quitStoreProvider)!.cravingsSurvivedTotal, before + 1);
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