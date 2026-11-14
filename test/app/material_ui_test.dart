import 'dart:async';

// The library the app's unmigrated dependencies (showcaseview, which draws
// the Day-1 tour) still import. The last test stands where they stand.
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as legacy;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';

/// Material left the Flutter SDK for `package:material_ui` (Flutter 3.47,
/// deprecated in the SDK from 3.50), and the copy still under
/// `package:flutter/material.dart` is a SECOND set of classes, not a
/// re-export. Everything that finds its Material by type therefore has to be
/// looking for the same one. Three places were not, and none of them is a
/// compile error (docs/10 §56.7):
///
/// - go_router 18 asks for its own `MaterialApp` before it picks a page type.
/// - A `material_ui` widget asks for `material_ui`'s `MaterialLocalizations`,
///   which gen-l10n's `AppLocalizations.localizationsDelegates` does not carry.
/// - A dependency still on the old library asks for the old `Theme`.
void main() {
  Future<ProviderContainer> open(WidgetTester tester) async {
    final container = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    return container;
  }

  /// A context on a real screen, below the navigator.
  BuildContext screen(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first);

  testWidgets('a plain builder route is pushed as a Material page, with its '
      'transition', (tester) async {
    // On the SDK's MaterialApp go_router found no Material app at all, fell
    // back to its "WidgetsApp configuration", and built every route declared
    // with `builder:` as a NoTransitionPage: no push animation and no
    // back-swipe on Settings, Plan, Money, Health and every auth screen.
    final container = await open(tester);
    expect(find.byType(MaterialApp), findsOneWidget);

    for (final path in [Routes.settings, Routes.plan, Routes.money]) {
      unawaited(container.read(routerProvider).push(path));
      await tester.pumpAndSettle();
      final page = tester
          .widget<Navigator>(find.byType(Navigator).first)
          .pages
          .last;
      expect(page, isA<MaterialPage<void>>(), reason: path);
      expect(page, isNot(isA<NoTransitionPage<void>>()), reason: path);
      container.read(routerProvider).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('every supported locale has Material strings', (tester) async {
    // English is covered by a default built into MaterialApp, so an app that
    // forgets the delegates works for the developer and for nobody reading
    // one of the other five languages: "No MaterialLocalizations found" on
    // the first back button, dialog or text field.
    final container = await open(tester);
    final english = MaterialLocalizations.of(screen(tester)).backButtonTooltip;

    for (final locale in AppLocalizations.supportedLocales) {
      container.read(settingsStoreProvider.notifier).setLocale(locale);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$locale');

      final strings = Localizations.of<MaterialLocalizations>(
        screen(tester),
        MaterialLocalizations,
      );
      expect(strings, isNotNull, reason: '$locale');
      if (locale.languageCode != 'en') {
        expect(strings!.backButtonTooltip, isNot(english), reason: '$locale');
      }
    }
  });

  testWidgets('a dependency still on the old Material library finds the '
      "app's theme and strings", (tester) async {
    // What showcaseview does inside the Day-1 tour: `Theme.of(context)` and
    // `MaterialLocalizations.of(context)` from package:flutter/material.dart.
    // Without MaterialUiCompatibilityBridge the first is Flutter's fallback
    // theme and the second is not there.
    await open(tester);
    final context = screen(tester);

    expect(
      legacy.Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.primary,
    );
    expect(
      legacy.Theme.of(context).colorScheme.surface,
      Theme.of(context).colorScheme.surface,
    );
    expect(
      legacy.Localizations.of<legacy.MaterialLocalizations>(
        context,
        legacy.MaterialLocalizations,
      ),
      isNotNull,
    );
  });
}
