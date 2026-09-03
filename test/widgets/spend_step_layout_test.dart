import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/app/theme/lp_typography.dart';
import 'package:last_puff/features/onboarding/onboarding_flow.dart';
import 'package:last_puff/features/onboarding/onboarding_view_model.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// iPhone 15, TestFlight, Sep 2 2026: on the spend step, Continue sat below
/// the fold and every change to the amount meant a scroll to reach it. Fine
/// on a Pixel 8.
///
/// The step's content is fixed-size — a hero number, a yearly card, three
/// chips, a keypad and a CTA — and at the design frames' sizes it needs ~780
/// logical pixels. A Pixel 8 gives the step 800+; an iPhone 15 gives it ~707
/// once the status bar, the home indicator and the progress header have
/// taken theirs. The step now reads its density from its own height and
/// draws the same elements shorter when it has to (`StepDensity`).
///
/// Rendered with the bundled brand fonts, not the test font. The test font
/// draws every glyph as a square, so a 30 px title wraps to three lines where
/// the device shows two — the reason `screen_layout_test` cannot assert on
/// overflow. Here the assertion IS the fit, so the metrics have to be real.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final file in files) {
        final bytes = File('assets/fonts/$file.ttf').readAsBytesSync();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
    }

    await load(LpType.display, ['SpaceGrotesk-Medium', 'SpaceGrotesk-Bold']);
    await load(LpType.body, [
      'Inter-Regular',
      'Inter-Medium',
      'Inter-SemiBold',
      'Inter-Bold',
    ]);
  });

  /// Logical screen size and the OS's own insets, with `devicePixelRatio`
  /// pinned to 1 so the padding reads in the same unit.
  const phones = <String, (Size, FakeViewPadding)>{
    // The report. 6.1" — the most common iPhone in the field.
    'iPhone 15': (Size(393, 852), FakeViewPadding(top: 59, bottom: 34)),
    'iPhone 15 Pro Max': (Size(430, 932), FakeViewPadding(top: 59, bottom: 34)),
    // Where it always fit. Gesture navigation, then the taller 3-button bar.
    'Pixel 8': (Size(411, 914), FakeViewPadding(top: 30, bottom: 24)),
    'Pixel 8, 3-button nav': (
      Size(411, 914),
      FakeViewPadding(top: 30, bottom: 48),
    ),
  };

  Future<void> pumpSpend(
    WidgetTester tester,
    Size size,
    FakeViewPadding padding,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = padding;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(container.dispose);
    // $25 a week — the demo answer every design frame depicts, which also
    // shows the yearly card, the kicker line and all three chips.
    container.read(onboardingProvider.notifier).previewStep(ObStep.spend);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LpTheme.midnight(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const OnboardingFlow(),
        ),
      ),
    );
    // The yearly counter rolls up for a second; the caret blinks forever.
    await tester.pump(const Duration(milliseconds: 1500));
  }

  /// The hero amount — the one text on the screen in the hero style.
  Finder hero() => find.byWidgetPredicate(
    (w) =>
        w is Text &&
        w.style?.fontFamily == LpType.display &&
        w.style?.letterSpacing == -2,
  );

  for (final MapEntry(key: name, value: (size, padding)) in phones.entries) {
    testWidgets('$name: Continue is on screen without scrolling', (
      tester,
    ) async {
      await pumpSpend(tester, size, padding);
      final l10n = AppLocalizations.of(tester.element(hero()));

      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        scrollable.position.maxScrollExtent,
        0,
        reason:
            'the step needs ${scrollable.position.maxScrollExtent.round()}'
            ' px more than $name has — Continue is below the fold',
      );

      final cta = tester.getRect(find.text(l10n.commonContinue));
      expect(cta.bottom, lessThanOrEqualTo(size.height - padding.bottom));
      // And the whole keypad above it, including its last row.
      expect(tester.getRect(find.text('0')).bottom, lessThan(cta.top));
    });
  }

  testWidgets('a 6.1" iPhone draws the compact hero; a Pixel keeps the frame', (
    tester,
  ) async {
    // The mechanism, so a future size tweak that quietly stops triggering
    // compact on the phone that needed it fails here rather than in the field.
    final (size, padding) = phones['iPhone 15']!;
    await pumpSpend(tester, size, padding);
    expect(tester.widget<Text>(hero()).style!.fontSize, 60);

    final (pixelSize, pixelPadding) = phones['Pixel 8']!;
    await pumpSpend(tester, pixelSize, pixelPadding);
    expect(tester.widget<Text>(hero()).style!.fontSize, 72);
  });
}
