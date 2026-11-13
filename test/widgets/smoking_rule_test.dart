import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/help/smoking_rule_card.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// docs/15 QP-A4: the one rule above the others for anyone who has smoked.
/// Every guideline puts "do not go back to smoking" first, and 19% of British
/// method-users quit vaping by smoking (ASH 2026).
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<void> pumpCard(
    WidgetTester tester,
    SmokingHistory answer, {
    VoidCallback? onDone,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: fastBackendOverrides(),
        child: MaterialApp(
          theme: LpTheme.midnight(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SmokingRuleCard(answer: answer, source: 'home', onDone: onDone),
          ),
        ),
      ),
    );
  }

  testWidgets('a former smoker gets the rule and a way to More help', (
    tester,
  ) async {
    await pumpCard(tester, SmokingHistory.former);

    expect(find.text(l10n.smokingRuleBody), findsOneWidget);
    expect(find.text(l10n.smokingRuleCurrent), findsNothing);
    expect(find.text(l10n.helpTitle), findsOneWidget);
  });

  testWidgets('someone who still smokes also hears that stopping that comes first', (
    tester,
  ) async {
    await pumpCard(tester, SmokingHistory.current);

    expect(find.text(l10n.smokingRuleBody), findsOneWidget);
    expect(find.text(l10n.smokingRuleCurrent), findsOneWidget);
  });

  testWidgets('someone who never smoked is told nothing', (tester) async {
    // A rule about cigarettes shown to a person who never touched one is noise
    // at best and a nudge at worst.
    await pumpCard(tester, SmokingHistory.never);

    expect(find.text(l10n.smokingRuleBody), findsNothing);
    expect(find.text(l10n.helpTitle), findsNothing);
  });

  testWidgets('Done is offered only where the card can be dismissed', (
    tester,
  ) async {
    await pumpCard(tester, SmokingHistory.former);
    expect(find.text(l10n.commonDone), findsNothing);

    var done = 0;
    await pumpCard(tester, SmokingHistory.former, onDone: () => done++);
    await tester.tap(find.text(l10n.commonDone));
    // `PressScale` schedules a 120ms `Future.delayed` after each tap.
    await tester.pump(const Duration(milliseconds: 150));
    expect(done, 1);
  });

  test('the rule never calls a vape harmless or tells anyone to start one', () {
    // It says the vape is the SAFER choice between two, not that it is safe,
    // and it is only ever shown to someone already vaping.
    final text = '${l10n.smokingRuleBody} ${l10n.smokingRuleCurrent}'.toLowerCase();
    expect(text, contains('safer'));
    expect(text, isNot(contains('harmless')));
    expect(text, isNot(contains('start vaping')));
  });
}
