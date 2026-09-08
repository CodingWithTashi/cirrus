import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/features/panic/panic_screens.dart';

import '../helpers.dart';

/// The intensity control on the panic flow's why-step is a `CupertinoSlider`,
/// and the Material `Slider` must not come back.
///
/// With `Slider` there, iOS reported every accessibility frame on the step —
/// and on the Survived screen after it — at 1/devicePixelRatio once the flow
/// switched out of the breathing step, and a drag on the slider then emptied
/// the accessibility tree until the app restarted. The pixels were never
/// wrong; VoiceOver's picture of the screen was. Bisected on Sep 8 2026 to
/// the Material slider itself (docs/10 §35). No widget test can see the
/// frames — `.maestro/flows/06_panic.yaml` does that on a simulator — so this
/// pins the one thing a widget test can: which widget is there.
void main() {
  testWidgets('the why-step uses a CupertinoSlider, never a Material Slider', (
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
    await tester.pump(const Duration(seconds: 2)); // splash beat
    await tester.pumpAndSettle();

    // Fixed pumps, not pumpAndSettle: the breathing ring on step 1 animates
    // for as long as it is on screen.
    container.read(routerProvider).go(Routes.panic);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // The takeover opens its craving after its first frame; step 2 is the
    // why-step, the one with the intensity control.
    container.read(panicProvider.notifier).previewStep(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CupertinoSlider), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
  });
}
