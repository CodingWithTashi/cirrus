import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_palette.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/features/panic/breath_pacer.dart';
import 'package:last_puff/features/panic/breath_ring.dart';
import 'package:last_puff/features/panic/panic_screens.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// Panic step 1 as the founder saw it on Sep 1 (docs/09 §7): "a big teal
/// circle with In… and a small 3 — it looks like a button someone is holding
/// down. Nothing tells me to breathe, and I cannot see it moving."
///
/// These pin the three fixes: the instruction and the verb are on screen
/// from the first frame, the orb has visibly grown one second in, and the
/// labels and haptics turn over on the 4-7-8 beat.
void main() {
  /// Records every haptic the platform channel is asked for.
  List<String> recordHaptics(WidgetTester tester) {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return calls;
  }

  /// The scope lives in the tree, so it outlives the flow's `dispose` (which
  /// reports the abandoned craving through a provider).
  Future<void> mountFlow(WidgetTester tester, {ThemeData? theme}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: fastBackendOverrides(),
        child: MaterialApp(
          theme: theme ?? LpTheme.midnight(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PanicFlow(),
        ),
      ),
    );
  }

  BreathRingPainter painterOf(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(BreathRing),
        matching: find.byType(CustomPaint),
      ),
    );
    return paint.painter! as BreathRingPainter;
  }

  testWidgets('frame one tells the user what to do', (tester) async {
    await mountFlow(tester);

    // No time has passed: this is what the screen shows the instant it
    // appears, before any animation has had a frame to run.
    expect(find.text('Breathe with the circle.'), findsOneWidget);
    expect(find.text('Breathe in'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('In 4 · Hold 7 · Out 8'), findsOneWidget);
    expect(find.text('Skip to my why →'), findsOneWidget);

    final m = painterOf(tester).moment;
    expect(m.phase, BreathPhase.inhale);
    expect(m.scale, const BreathPacer().minScale);
  });

  testWidgets('the orb is visibly growing one second in', (tester) async {
    await mountFlow(tester);
    final rest = painterOf(tester).moment.scale;

    await tester.pump(const Duration(seconds: 1));

    final grown = painterOf(tester).moment.scale;
    expect(grown / rest, greaterThan(1.2));
    // Still the inhale, and the count has moved.
    expect(find.text('Breathe in'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('labels and countdown turn over on the 4-7-8 beat', (
    tester,
  ) async {
    await mountFlow(tester);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Hold'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(painterOf(tester).moment.scale, 1);

    await tester.pump(const Duration(seconds: 7));
    expect(find.text('Breathe out'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);

    await tester.pump(const Duration(seconds: 8));
    expect(find.text('Breathe in'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(painterOf(tester).moment.scale, const BreathPacer().minScale);
  });

  testWidgets('haptics tick with the breath and go silent through the hold', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    await mountFlow(tester);
    // The ticker's first frame is the one after mount; it marks the first
    // inhale.
    await tester.pump();
    expect(haptics, ['HapticFeedbackType.lightImpact']);

    // Through the inhale: a selection tick on each new second.
    haptics.clear();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    // 3, 2, 1 ticked; the fourth second is the phase change into the hold.
    expect(
      haptics.where((h) => h == 'HapticFeedbackType.selectionClick').length,
      3,
    );
    expect(haptics.last, 'HapticFeedbackType.lightImpact');

    // Through the hold: nothing at all, until the exhale starts.
    haptics.clear();
    for (var i = 0; i < 13; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(haptics, isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    expect(haptics, ['HapticFeedbackType.lightImpact']);
  });

  // One test per palette and mode rather than one test that mounts them all:
  // stacking six `mountFlow`s in a single `testWidgets` overflows on the last
  // one whichever palette is last, so it measures mount count, not colour.
  for (final entry in LpPaletteCatalog.entries) {
    for (final mode in const [Brightness.dark, Brightness.light]) {
      final theme = mode == Brightness.dark
          ? LpTheme.dark(entry.id)
          : LpTheme.light(entry.id);
      testWidgets(
        'the ring lays out on a small phone (${entry.id.name}, ${mode.name})',
        (tester) async {
          tester.view.physicalSize = const Size(360, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await mountFlow(tester, theme: theme);
          await tester.pump(const Duration(seconds: 2));
          final ring = tester.getSize(find.byType(BreathRing));
          // Shrunk to fit; the orb carries no text, so it may go small. The
          // overflow check is real here: the fallback font is WIDER than
          // Inter, so a layout that fits under `flutter test` fits on any
          // device.
          expect(ring.width, inInclusiveRange(160, 272));
          expect(ring.width, ring.height);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
