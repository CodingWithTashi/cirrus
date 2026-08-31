/// D2, the hold-to-commit gate — the one screen in the funnel nobody can skip,
/// and until now the one with no widget test at all.
///
/// Two things were wrong with it and both are the same mistake: the screen was
/// laid out for a picture rather than for a thumb.
///
/// * The ring sat at ~28% of screen height with the bottom 45% empty, so the
///   only control on the screen was in the worst reach zone on a large phone.
/// * The hold ran on `GestureDetector.onTapDown`/`onTapUp`, and a tap
///   recognizer rejects once the pointer drifts past `kTouchSlop`. A thumb
///   that shifted 20 logical pixels at 2.8 seconds of a 3-second hold lost the
///   whole hold, with nothing on screen to say why.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/core/widgets/progress_ring.dart';
import 'package:last_puff/features/onboarding/onboarding_view_model.dart';
import 'package:last_puff/features/onboarding/steps/payoff_steps.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

void main() {
  /// A 6.7" phone in logical pixels — the size the reach problem shows at.
  const size = Size(430, 932);

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(container.dispose);
    container.read(onboardingProvider.notifier).previewStep(ObStep.commit);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LpTheme.midnight(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CommitStep(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    return container;
  }

  bool committed(ProviderContainer c) => c.read(onboardingProvider).committed;

  /// Drains the celebration: a 1.4s advance timer and a 1.6s confetti burst.
  Future<void> settleCelebration(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  testWidgets('the hold target sits in the bottom half of the screen', (
    tester,
  ) async {
    await pump(tester);

    final centre = tester.getCenter(find.byType(ProgressRing));

    // Not a pixel-perfect assertion — a design tweak should not fail this.
    // What it pins is the thing that was actually wrong: the only control on
    // the screen must not be stranded in the top third.
    expect(
      centre.dy,
      greaterThan(size.height * 0.6),
      reason: 'hold ring is at ${(centre.dy / size.height * 100).round()}% of '
          'screen height — out of thumb reach on a large phone',
    );
  });

  testWidgets('the payoff card stays above the control that earns it', (
    tester,
  ) async {
    // Reordering for reach must not reorder the story: read the date, then
    // commit to it.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await pump(tester);

    final card = tester.getCenter(find.text(l10n.obCommitFreedomLabel));
    final ring = tester.getCenter(find.byType(ProgressRing));
    expect(card.dy, lessThan(ring.dy));
  });

  testWidgets('a thumb that drifts mid-hold still commits', (tester) async {
    final container = await pump(tester);
    final ring = find.byType(ProgressRing);

    final gesture = await tester.startGesture(tester.getCenter(ring));
    await tester.pump(const Duration(milliseconds: 300));
    // Well past kTouchSlop (18), well inside the ring: this is a thumb
    // settling, not a swipe away. A tap recognizer cancels here; a raw
    // pointer listener does not.
    await gesture.moveBy(const Offset(0, 30));
    expect(
      kTouchSlop,
      lessThan(30),
      reason: 'the drift has to actually exceed slop for this to test anything',
    );

    await tester.pump(const Duration(seconds: 3));
    expect(committed(container), isTrue);

    await gesture.up();
    await settleCelebration(tester);
  });

  testWidgets('the hold lands between one and two seconds', (tester) async {
    // Pins the 1.8s duration behaviorally, from both sides. Every other hold
    // test pumps three seconds, so a silent regression back to the original
    // 3s hold — the one that made a drifting thumb lose the whole commit at
    // 2.8s — would pass all of them.
    final container = await pump(tester);
    final ring = find.byType(ProgressRing);

    var gesture = await tester.startGesture(tester.getCenter(ring));
    // The empty pump is the ticker's first frame — it establishes the epoch
    // the next pump's elapsed time is measured from.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    expect(
      committed(container),
      isFalse,
      reason: 'a one-second press must not read as commitment',
    );
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    gesture = await tester.startGesture(tester.getCenter(ring));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2000));
    expect(
      committed(container),
      isTrue,
      reason: 'two full seconds of holding must be enough',
    );
    await gesture.up();
    await settleCelebration(tester);
  });

  testWidgets('letting go early commits nothing', (tester) async {
    final container = await pump(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ProgressRing)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));

    expect(committed(container), isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('a pointer that leaves the screen mid-hold commits nothing', (
    tester,
  ) async {
    final container = await pump(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ProgressRing)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.cancel();
    await tester.pump(const Duration(seconds: 3));

    expect(committed(container), isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('the commit is reachable without holding anything', (
    tester,
  ) async {
    // This is the one gate in onboarding with no way past it, so a hold-only
    // gesture would lock out switch access and anyone who cannot sustain a
    // press. The semantic action is the door.
    final handle = tester.ensureSemantics();
    final container = await pump(tester);

    // Two halves: the action reaches assistive tech at all, and it does the
    // thing when taken.
    final node = tester.getSemantics(find.byType(ProgressRing));
    expect(
      node.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
      reason: 'the hold ring exposes no semantic action',
    );

    final semantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.onTap != null,
        description: 'a Semantics carrying a tap action',
      ),
    );
    semantics.properties.onTap!();
    await tester.pump();

    expect(committed(container), isTrue);
    await settleCelebration(tester);
    handle.dispose();
  });
}
