import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_palette.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/core/utils/whats_new_copy.dart';
import 'package:last_puff/data/stores/update_check_store.dart';
import 'package:last_puff/domain/logic/update_prompt_policy.dart';
import 'package:last_puff/features/update/update_views.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// A verdict that is already in, so a view can be drawn on its own.
class _Answered extends UpdateCheckStore {
  _Answered(this.answer);

  final UpdateCheckState answer;

  @override
  UpdateCheckState build() => answer;
}

/// Opens a sheet once the first frame is up, as `UpdatePrompt` does.
class _Opener extends ConsumerStatefulWidget {
  const _Opener(this.open);

  final Future<void> Function(BuildContext, WidgetRef) open;

  @override
  ConsumerState<_Opener> createState() => _OpenerState();
}

class _OpenerState extends ConsumerState<_Opener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.open(context, ref),
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}

/// The three views, in every language and every palette, on the smallest
/// phone at twice the text size (docs/10 §55). Fails on ANY layout error —
/// overflow included, unlike `screen_layout_test`: these views are short and
/// scroll, so even the test font's wide glyphs must fit.
void main() {
  const version = '1.0.33';
  final answer = UpdateCheckState(
    settled: true,
    kind: UpdateKind.optional,
    storeVersion: version,
    storeNotes:
        'A quicker way to log a puff from the home screen.\n'
        'Calmer reminders around your quit date.\n'
        'Fixes for the Stats week view.',
  );

  // Six locales, six themes: each language on a different family and mode,
  // so the sweep covers every palette without multiplying the runs.
  final themes = [
    for (final entry in LpPaletteCatalog.entries) ...[
      LpTheme.dark(entry.id),
      LpTheme.light(entry.id),
    ],
  ];

  final views = <String, Widget Function()>{
    'forced': () => const ForcedUpdateScreen(),
    'update sheet': () => _Opener(showUpdateSheet),
    "What's New": () => _Opener(
      (context, ref) => showWhatsNewSheet(
        context,
        ref,
        WhatsNewCatalog.versions.first,
      ),
    ),
  };

  String titleOf(String view, AppLocalizations l10n) => switch (view) {
    'forced' => l10n.updateRequiredTitle,
    'update sheet' => l10n.updateTitle,
    _ => l10n.whatsNewTitle,
  };

  for (final (index, locale) in AppLocalizations.supportedLocales.indexed) {
    for (final view in views.keys) {
      for (final (label, size, scale) in [
        ('320pt, text 200%', const Size(320, 568), 2.0),
        ('390pt, text 100%', const Size(390, 844), 1.0),
      ]) {
        testWidgets('$view renders in ${locale.languageCode} ($label)', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          final l10n = await AppLocalizations.delegate.load(locale);
          final errors = <FlutterErrorDetails>[];
          final prior = FlutterError.onError;
          FlutterError.onError = errors.add;
          addTearDown(() => FlutterError.onError = prior);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                ...fastBackendOverrides(),
                updateCheckProvider.overrideWith(() => _Answered(answer)),
              ],
              child: MaterialApp(
                theme: themes[index % themes.length],
                locale: locale,
                localizationsDelegates:
                    AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: views[view]!(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          FlutterError.onError = prior;

          expect(
            errors.map((e) => e.exceptionAsString().split('\n').first),
            isEmpty,
            reason: '$view in ${locale.languageCode} at $label',
          );
          expect(find.text(titleOf(view, l10n)), findsOneWidget);
          final primary = view == "What's New"
              ? l10n.whatsNewDone
              : l10n.updateCta;
          // Reachable: scrolled to if the text size pushed it down.
          await tester.ensureVisible(find.text(primary));
          await tester.pumpAndSettle();
          expect(find.text(primary).hitTestable(), findsOneWidget);
          expect(
            tester.getSize(find.text(primary)).height,
            greaterThan(0),
          );
        });
      }
    }
  }

  testWidgets('every button is at least 48dp tall and announced as a button',
      (tester) async {
    final handle = tester.ensureSemantics();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...fastBackendOverrides(),
          updateCheckProvider.overrideWith(() => _Answered(answer)),
        ],
        child: MaterialApp(
          theme: themes.first,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _Opener(showUpdateSheet),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in [l10n.updateCta, l10n.commonNotNow]) {
      expect(
        tester.getSemantics(find.text(label)),
        matchesSemantics(
          label: label,
          isButton: true,
          hasTapAction: true,
        ),
        reason: label,
      );
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    expect(find.bySemanticsLabel(l10n.updateVersionLabel(version)),
        findsOneWidget);
    handle.dispose();
  });
}
