import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/utils/program_copy.dart';
import 'package:last_puff/data/stores/day1_tour_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/quit_program.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/home/home_screen.dart';
import 'package:last_puff/features/home/widgets/program_card.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// docs/15 QP-B4: the daily program's card on Home, under the ring.
///
/// A cold-turkey account's plan day N is program day N − 1 (its date is day
/// one), which is the easiest way to stand on a given program day: plan day 3
/// is program day 2, with a morning and an evening message.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final morning = DateTime(2026, 11, 12, 10, 15);
  final evening = DateTime(2026, 11, 12, 21, 5);

  /// A cold-turkey account on plan day [day], setup finished, cigarettes
  /// answered (so no other card competes for the slot).
  JourneyState coldOn(
    int day, {
    DateTime? at,
    SmokingHistory smoking = SmokingHistory.never,
    Map<DateTime, DayLog> extraDays = const {},
    String? whyWords,
  }) {
    final when = at ?? morning;
    final base = journeyOnDay(day, now: when);
    return base.copyWith(
      plan: base.plan.copyWith(method: QuitMethod.coldTurkey),
      profile: UserProfile(
        alias: base.profile.alias,
        avatarEmoji: base.profile.avatarEmoji,
        smoking: smoking,
        whyWords: whyWords,
      ),
      days: {...base.days, ...extraDays},
    );
  }

  Future<(ProviderContainer, RecordingAnalytics)> pumpHome(
    WidgetTester tester,
    JourneyState journey, {
    DateTime? at,
  }) async {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
    tester.view.physicalSize = const Size(393, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final analytics = RecordingAnalytics();
    final container = ProviderContainer(
      overrides: fastBackendOverrides(now: at ?? morning, analytics: analytics),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).replaceForTest(journey);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    return (container, analytics);
  }

  /// Past `PressScale`'s 120ms release timer, then settled.
  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).first);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  /// A finder confined to the card. Home has quick links of its own ("Money
  /// back", "Your body, healing"), so an unscoped `find.text` would happily tap
  /// those and pass for the wrong reason.
  Finder inCard(String text) =>
      find.descendant(of: find.byType(ProgramCard), matching: find.text(text));

  Future<void> tapInCard(WidgetTester tester, String label) async {
    expect(inCard(label), findsOneWidget, reason: '"$label" in the card');
    await tester.tap(inCard(label));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  String cold(int day, {DateTime? at, ProgramSlot? slot}) {
    final when = at ?? morning;
    final j = coldOn(day, at: when);
    final m = QuitProgram.messageToShow(j.plan, when, checkinHour: 20)!;
    return m.text(l10n);
  }

  group('when it shows', () {
    testWidgets('on a day with a message: the day in the title, the message, '
        'the question and the four buttons', (tester) async {
      await pumpHome(tester, coldOn(3));

      expect(find.text(l10n.programCardTitle(3)), findsOneWidget);
      expect(find.text(cold(3)), findsOneWidget);
      expect(find.text(l10n.programQuestion), findsOneWidget);
      for (final label in [
        l10n.programBtnCraving,
        l10n.programBtnStress,
        l10n.programBtnSlipped,
        l10n.programBtnMore,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('not on a day with no message and no check-up', (tester) async {
      // Plan day 16 is program day 15, which has neither.
      await pumpHome(tester, coldOn(16));
      expect(find.byType(ProgramCard), findsNothing);
    });

    testWidgets('not for an account far from its date', (tester) async {
      final far = journeyOnDay(4, now: morning); // a taper, weeks from its date
      await pumpHome(tester, far);
      expect(find.byType(ProgramCard), findsNothing);
    });

    testWidgets('the morning message until the check-in hour, then the evening '
        'one', (tester) async {
      await pumpHome(tester, coldOn(3));
      expect(find.text(cold(3)), findsOneWidget);
      expect(find.text(cold(3, at: evening)), findsNothing);
    });

    testWidgets('and the evening one after it', (tester) async {
      await pumpHome(tester, coldOn(3, at: evening), at: evening);
      expect(find.text(cold(3, at: evening)), findsOneWidget);
      expect(find.text(cold(3)), findsNothing);
    });

    testWidgets('past Freedom Day the title drops the number, as Home does', (
      tester,
    ) async {
      // Plan day 40 of 30 is program day 39 (the community message).
      await pumpHome(tester, coldOn(40));
      expect(find.text(l10n.programCardTitlePast), findsOneWidget);
      expect(find.textContaining('DAY 40'), findsNothing);
    });

    testWidgets('it is not dismissible: it has no answer that hides it', (
      tester,
    ) async {
      await pumpHome(tester, coldOn(3));
      expect(
        find.descendant(
          of: find.byType(ProgramCard),
          matching: find.byType(Dismissible),
        ),
        findsNothing,
      );
    });

    testWidgets('not while the Day-1 tour is running', (tester) async {
      // Plan day 3, one setup task done: Home is not redirected to the
      // checklist, and a tour can still be started.
      final j = coldOn(3).copyWith(day1TasksDone: const {0});
      final (container, _) = await pumpHome(tester, j);
      expect(find.byType(ProgramCard), findsOneWidget, reason: 'premise');
      container.read(day1TourProvider.notifier).start(Day1TourStep.logPuff);
      await tester.pumpAndSettle();
      expect(find.byType(ProgramCard), findsNothing);
    });

    testWidgets('and with no journey there is nothing to show', (tester) async {
      final container = ProviderContainer(overrides: fastBackendOverrides());
      addTearDown(container.dispose);
      expect(container.read(quitStoreProvider), isNull);
    });
  });

  group('the evening mood prompt gives way to the card', () {
    testWidgets('on a card day after 18:00 there is one check-in, not two', (
      tester,
    ) async {
      await pumpHome(tester, coldOn(3, at: evening), at: evening);
      expect(find.byType(ProgramCard), findsOneWidget);
      expect(find.text(l10n.moodTitle), findsNothing);
    });

    testWidgets('on a day with no card it still appears', (tester) async {
      await pumpHome(tester, coldOn(16, at: evening), at: evening);
      expect(find.byType(ProgramCard), findsNothing);
      expect(find.text(l10n.moodTitle), findsOneWidget);
    });
  });

  group('the check-in and its written reply', () {
    testWidgets('a mood stores itself and brings the reply the engine picks', (
      tester,
    ) async {
      final (container, _) = await pumpHome(tester, coldOn(3));
      await tap(tester, l10n.moodRough);

      final j = container.read(quitStoreProvider)!;
      expect(j.logFor(morning)!.mood, Mood.rough);
      final expected = QuitProgram.replyFor(
        Mood.rough,
        ProgramTrack.onTrack,
        seed: j.plan.dayNumber(morning),
        hasWhy: false,
      ).text(l10n);
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('a slip in the last three days gets a slip reply, whatever the '
        'mood', (tester) async {
      final yesterday = LpDate.addDays(LpDate.dayStart(morning), -1);
      final j = coldOn(
        3,
        extraDays: {yesterday: DayLog(date: yesterday, puffs: 4, limit: 0)},
      );
      await pumpHome(tester, j);
      await tap(tester, l10n.moodGreat);

      final expected = QuitProgram.replyFor(
        Mood.great,
        ProgramTrack.slipped,
        seed: j.plan.dayNumber(morning),
      ).text(l10n);
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('a good day quotes their own reason, when they gave one', (
      tester,
    ) async {
      // Seeds walk the variants, so find the plan day whose praise uses {why}.
      for (final day in [3, 4, 5, 6]) {
        final j = coldOn(day, whyWords: 'being there for my daughter');
        final reply = QuitProgram.replyFor(
          Mood.good,
          ProgramTrack.onTrack,
          seed: j.plan.dayNumber(morning),
        );
        if (!reply.needsWhy) continue;
        await pumpHome(tester, j);
        await tap(tester, l10n.moodGood);
        expect(
          find.text(reply.text(l10n, why: 'being there for my daughter')),
          findsOneWidget,
        );
        return;
      }
      fail('no plan day in 3..6 picked a reply that uses the reason');
    });

    testWidgets('changing the answer changes the reply and counts nothing', (
      tester,
    ) async {
      final (container, _) = await pumpHome(tester, coldOn(3));
      await tap(tester, l10n.moodRough);
      await tap(tester, l10n.moodGreat);
      final j = container.read(quitStoreProvider)!;
      expect(j.logFor(morning)!.mood, Mood.great);
      expect(j.moodCheckIns, 1);
    });
  });

  group('the four buttons', () {
    testWidgets('Craving opens the craving flow', (tester) async {
      final (container, analytics) = await pumpHome(tester, coldOn(3));
      await tester.tap(find.text(l10n.programBtnCraving));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        container.read(routerProvider).state.uri.path,
        Routes.panic,
      );
      expect(analytics.propsOfAll('program_help'), [
        {'kind': 'craving'},
      ]);
    });

    testWidgets('Stress opens a minute to breathe and one tip', (tester) async {
      final (container, analytics) = await pumpHome(tester, coldOn(3));
      await tester.tap(find.text(l10n.programBtnStress));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(l10n.programStressTitle), findsOneWidget);
      final tip = QuitProgram.tipFor(
        ProgramTipKind.stress,
        container.read(quitStoreProvider)!.plan.dayNumber(morning),
      ).text(l10n);
      expect(find.text(tip), findsOneWidget);
      expect(analytics.propsOfAll('program_help'), [
        {'kind': 'stress'},
      ]);
      // The breathing ring is the panic flow's own widget.
      expect(find.text(l10n.programStressBody), findsOneWidget);
    });

    testWidgets('Slipped offers a new plan, the coach and More help — and no '
        'plan change of its own', (tester) async {
      final (container, analytics) = await pumpHome(tester, coldOn(3));
      final before = container.read(quitStoreProvider)!.plan;
      await tap(tester, l10n.programBtnSlipped);

      expect(find.text(l10n.programSlippedTitle), findsOneWidget);
      expect(find.text(l10n.planNewCta), findsOneWidget);
      expect(find.text(l10n.programSlippedCoach), findsOneWidget);
      expect(find.text(l10n.helpTitle), findsOneWidget);
      expect(
        identical(container.read(quitStoreProvider)!.plan, before),
        isTrue,
        reason: 'opening it must not move anything',
      );
      expect(analytics.propsOfAll('program_help'), [
        {'kind': 'slipped'},
      ]);
    });

    testWidgets('Slipped shows the one rule to someone who has smoked', (
      tester,
    ) async {
      await pumpHome(tester, coldOn(3, smoking: SmokingHistory.former));
      await tap(tester, l10n.programBtnSlipped);
      expect(find.text(l10n.smokingRuleBody), findsOneWidget);
    });

    testWidgets('and that rule card is the only More help on the sheet (a '
        'Pixel 8 showed the door twice, docs/15 QP-B8)', (tester) async {
      await pumpHome(tester, coldOn(3, smoking: SmokingHistory.former));
      await tap(tester, l10n.programBtnSlipped);
      expect(find.text(l10n.helpTitle), findsOneWidget);
    });

    testWidgets('and not to someone who has not', (tester) async {
      await pumpHome(tester, coldOn(3));
      await tap(tester, l10n.programBtnSlipped);
      expect(find.text(l10n.smokingRuleBody), findsNothing);
    });

    testWidgets('Slipped → Start a new plan goes to it', (tester) async {
      final (container, _) = await pumpHome(tester, coldOn(3));
      await tap(tester, l10n.programBtnSlipped);
      await tap(tester, l10n.planNewCta);
      expect(
        container.read(routerProvider).state.uri.path,
        Routes.planNew,
      );
    });

    testWidgets('More shows another idea and a way to More help', (tester) async {
      final (container, analytics) = await pumpHome(tester, coldOn(3));
      await tap(tester, l10n.programBtnMore);

      expect(find.text(l10n.programMoreTitle), findsOneWidget);
      final tip = QuitProgram.tipFor(
        ProgramTipKind.more,
        container.read(quitStoreProvider)!.plan.dayNumber(morning),
      ).text(l10n);
      expect(find.text(tip), findsOneWidget);
      expect(find.text(l10n.helpTitle), findsOneWidget);
      expect(analytics.propsOfAll('program_help'), [
        {'kind': 'more'},
      ]);
    });
  });

  group('a message that points somewhere', () {
    testWidgets('the evening of day two points to More help', (tester) async {
      final (container, analytics) = await pumpHome(
        tester,
        coldOn(3, at: evening),
        at: evening,
      );
      // d2pm carries the help link, shown as a chip under the message.
      await tapInCard(tester, l10n.helpTitle);
      expect(container.read(routerProvider).state.uri.path, Routes.help);
      expect(analytics.propsOfAll('help_viewed'), [
        {'source': 'program'},
      ]);
    });

    testWidgets('the money message opens Money', (tester) async {
      // Program day 12 is plan day 13 for cold turkey.
      final (container, _) = await pumpHome(tester, coldOn(13));
      await tapInCard(tester, l10n.moneyTitle);
      expect(container.read(routerProvider).state.uri.path, Routes.money);
    });

    testWidgets('the body message opens Health', (tester) async {
      final (container, _) = await pumpHome(tester, coldOn(36));
      await tapInCard(tester, l10n.healthTitle);
      expect(container.read(routerProvider).state.uri.path, Routes.health);
    });

    testWidgets('the community message opens Community', (tester) async {
      final (container, _) = await pumpHome(tester, coldOn(40));
      await tapInCard(tester, l10n.navCommunity);
      expect(
        container.read(routerProvider).state.uri.path,
        Routes.community,
      );
    });

    testWidgets('a message with no pointer shows no link', (tester) async {
      await pumpHome(tester, coldOn(4)); // program day 3
      expect(inCard(l10n.moneyTitle), findsNothing);
      expect(inCard(l10n.healthTitle), findsNothing);
      expect(inCard(l10n.helpTitle), findsNothing);
    });
  });

  group('what is reported', () {
    testWidgets('one program_shown per day and slot, with the program day', (
      tester,
    ) async {
      final (container, analytics) = await pumpHome(tester, coldOn(3));
      await tester.pump(const Duration(seconds: 1));
      expect(analytics.propsOfAll('program_shown'), [
        {'day': 2, 'slot': 'morning'},
      ]);
      // A rebuild (a mood answer) must not report it again.
      await tap(tester, l10n.moodOkay);
      expect(analytics.propsOfAll('program_shown'), hasLength(1));
      expect(container.read(quitStoreProvider), isNotNull);
    });

    testWidgets('the reply is reported with the mood and the track, once', (
      tester,
    ) async {
      final (_, analytics) = await pumpHome(tester, coldOn(3));
      await tap(tester, l10n.moodRough);
      expect(analytics.propsOfAll('program_reply'), [
        {'mood': 'rough', 'track': 'onTrack'},
      ]);
    });
  });

  group('the check-ups', () {
    testWidgets('are not asked before the mood is in: the question comes after '
        'the reply', (tester) async {
      // Plan day 8 is program day 7: "any other nicotine this week?".
      await pumpHome(tester, coldOn(8));
      expect(find.text(l10n.programCheckupNicotineQ), findsNothing);
      await tap(tester, l10n.moodOkay);
      expect(find.text(l10n.programCheckupNicotineQ), findsOneWidget);
    });

    testWidgets('the nicotine question files an answer', (tester) async {
      final (container, analytics) = await pumpHome(tester, coldOn(8));
      await tap(tester, l10n.moodOkay);
      await tap(tester, l10n.programCheckupPouches);

      final today = LpDate.dayStart(morning);
      expect(
        container.read(quitStoreProvider)!.checkups[today],
        {CheckupKind.nicotine: CheckupAnswer.pouches},
      );
      expect(find.text(l10n.programCheckupThanks), findsOneWidget);
      expect(analytics.propsOfAll('checkup_answered'), [
        {'kind': 'nicotine', 'answer': 'pouches'},
      ]);
    });

    testWidgets('cigarettes brings up the one rule and More help', (
      tester,
    ) async {
      await pumpHome(tester, coldOn(8));
      await tap(tester, l10n.moodOkay);
      await tap(tester, l10n.programCheckupCigarettes);
      expect(find.text(l10n.smokingRuleBody), findsOneWidget);
    });

    testWidgets('patch or gum gets a line about using it well', (tester) async {
      await pumpHome(tester, coldOn(8));
      await tap(tester, l10n.moodOkay);
      await tap(tester, l10n.programCheckupPatchGum);
      expect(find.text(l10n.programCheckupPatchNote), findsOneWidget);
    });

    testWidgets('no answer asks for medicine by name or gives a dose', (
      tester,
    ) async {
      await pumpHome(tester, coldOn(8));
      await tap(tester, l10n.moodOkay);
      await tap(tester, l10n.programCheckupPatchGum);
      // The patch line is a pointer to a pharmacist and nothing more.
      expect(l10n.programCheckupPatchNote.toLowerCase(), contains('pharmacist'));
      expect(l10n.programCheckupPatchNote, isNot(matches(RegExp(r'\d'))));
    });

    testWidgets('day thirty asks about the last thirty days, and the answer is '
        'reported as a quit status', (tester) async {
      // Plan day 31 is program day 30; the card has a message there too.
      final (container, analytics) = await pumpHome(tester, coldOn(31));
      await tap(tester, l10n.moodOkay);
      expect(find.text(l10n.programCheckupVapedQ), findsOneWidget);
      await tap(tester, l10n.programCheckupNone);

      final today = LpDate.dayStart(morning);
      expect(
        container.read(quitStoreProvider)!.checkups[today],
        {CheckupKind.vaped30: CheckupAnswer.notVaped},
      );
      expect(analytics.propsOfAll('quit_status_reported'), [
        {'at': 30, 'vape_free': 'true'},
      ]);
    });

    testWidgets('a day inside the thirty-day window with no message still '
        'carries the question', (tester) async {
      // Program day 31 has no message; the window is open until day 44.
      await pumpHome(tester, coldOn(32));
      expect(find.byType(ProgramCard), findsOneWidget);
      await tap(tester, l10n.moodGood);
      expect(find.text(l10n.programCheckupVapedQ), findsOneWidget);
    });

    testWidgets('an answered question is not asked again that window', (
      tester,
    ) async {
      // Plan day 33 is program day 32, which has a message, so the card shows.
      final j = coldOn(33);
      final answered = j.copyWith(
        checkups: {
          LpDate.addDays(QuitProgram.quitDate(j.plan), 30): {
            CheckupKind.vaped30: CheckupAnswer.notVaped,
          },
        },
      );
      await pumpHome(tester, answered);
      await tap(tester, l10n.moodGood);
      expect(find.text(l10n.programCheckupVapedQ), findsNothing);
    });

    testWidgets('the ninety-day question has its own small card', (
      tester,
    ) async {
      // Plan day 92 is program day 91, past the end of the program.
      final (container, analytics) = await pumpHome(tester, coldOn(92));
      expect(find.byType(ProgramCard), findsNothing);
      expect(find.byType(Program90Card), findsOneWidget);
      expect(find.text(l10n.programCheckup90Title), findsOneWidget);
      expect(find.text(l10n.programCheckupVapedQ), findsOneWidget);

      await tap(tester, l10n.programCheckupYes);
      expect(
        container
            .read(quitStoreProvider)!
            .checkups[LpDate.dayStart(morning)],
        {CheckupKind.vaped90: CheckupAnswer.vaped},
      );
      expect(analytics.propsOfAll('quit_status_reported'), [
        {'at': 90, 'vape_free': 'false'},
      ]);
      expect(find.text(l10n.programCheckupThanks), findsOneWidget);
    });

    testWidgets('and is gone once the window has closed', (tester) async {
      await pumpHome(tester, coldOn(110));
      expect(find.byType(Program90Card), findsNothing);
    });
  });

  test('every link a message carries resolves to a screen the router has', () {
    for (final m in ProgramMessage.values) {
      final route = programLinkRoute(m.link);
      switch (m.link) {
        case ProgramLink.none || ProgramLink.stress:
          expect(route, isNull, reason: m.name);
        case ProgramLink.money:
          expect(route, Routes.money);
        case ProgramLink.health:
          expect(route, Routes.health);
        case ProgramLink.help:
          expect(route, startsWith(Routes.help));
        case ProgramLink.community:
          expect(route, Routes.community);
      }
    }
  });
}
