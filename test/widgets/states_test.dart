import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/core/widgets/lp_states.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

/// The three states a screen can be in now read as one system.
///
/// Failure had a widget from the start; loading was six bare spinners with no
/// words anywhere in the app, and empty had no widget at all, so every empty
/// state was hand-rolled and they drifted. These are cheap tests, but they
/// pin the thing that actually regressed: a wait with nothing to read.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: LpTheme.midnight(),
      home: Scaffold(body: child),
    ),
  );

  testWidgets('a wait says what it is waiting for', (tester) async {
    await pump(tester, const LpLoadingState(label: 'Pulling in the feed…'));
    expect(find.text('Pulling in the feed…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('an empty state offers a way out of it', (tester) async {
    var tapped = 0;
    await pump(
      tester,
      LpEmptyState(
        emoji: '📈',
        title: 'Charts show up tomorrow.',
        body: 'One day of logs = one dot.',
        actionLabel: 'Log a puff',
        onAction: () => tapped++,
      ),
    );

    expect(find.text('Charts show up tomorrow.'), findsOneWidget);
    await tester.tap(find.text('Log a puff'));
    expect(tapped, 1);
  });

  testWidgets('an empty state without an action renders no button', (
    tester,
  ) async {
    await pump(
      tester,
      const LpEmptyState(emoji: '🌱', title: 'Nothing yet', body: 'Soon.'),
    );
    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets('skeleton lines end short, the way a paragraph does', (
    tester,
  ) async {
    // A stack of identical bars reads as a progress bar rather than as text,
    // which is the whole reason to prefer a skeleton over a spinner.
    await pump(tester, const LpSkeletonLines(count: 3));

    final factors = tester
        .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .map((b) => b.widthFactor)
        .toList();
    expect(factors, [1.0, 1.0, 0.55]);
  });

  testWidgets('a skeleton animates rather than sitting still', (tester) async {
    await pump(tester, const LpSkeleton(height: 20));
    Color? colorNow() => (tester
                .widget<Container>(find.byType(Container).first)
                .decoration
            as BoxDecoration?)
        ?.color;

    final first = colorNow();
    await tester.pump(const Duration(milliseconds: 550));
    expect(colorNow(), isNot(first));

    // Leave the repeating controller settled so the binding does not complain.
    await tester.pumpWidget(const SizedBox());
  });
}
