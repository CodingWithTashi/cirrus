import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/core/widgets/lp_misc.dart';
import 'package:last_puff/features/auth/auth_screens.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

void main() {
  testWidgets('register screen scrolls under the keyboard, never overflows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    // A raised keyboard (~305dp) — the layout that used to overflow by 36px.
    tester.view.viewInsets = const FakeViewPadding(bottom: 840);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: LpTheme.midnight(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const RegisterScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('an action snack bar still expires under accessible navigation', (
    tester,
  ) async {
    // With accessible navigation on, the framework deliberately never times
    // out snack bars that carry an action — showLpSnack bounds the lifetime
    // itself so an "Undo" snack can't sit on screen forever.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showLpSnack(
                  context,
                  'logged one',
                  actionLabel: 'Undo',
                  onAction: () {},
                  duration: const Duration(seconds: 5),
                ),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('logged one'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('logged one'), findsNothing);
  });
}
