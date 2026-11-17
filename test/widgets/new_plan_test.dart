import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/utils/lp_format.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/core/widgets/lp_misc.dart';
import 'package:last_puff/core/widgets/lp_selectables.dart';
import 'package:last_puff/core/widgets/rolling_number.dart';
import 'package:last_puff/data/repositories/firebase_server_state_repository.dart';
import 'package:last_puff/features/home/home_screen.dart';
import 'package:last_puff/features/plan/new_plan_screen.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// "Start a new plan": two steps, reached from where people were getting
/// stuck — the plan, then what happens to the history (kept by default, or
/// erased from scratch).
///
/// The doors are the places the people who signed out and started over had
/// been standing (Nov 11 2026): the Plan screen, Home after the plan had
/// ended while they were still logging puffs, and the sign-out dialog itself.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final now = DateTime(2026, 11, 12, 15, 30);
  final today = LpDate.dayStart(now);

  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  /// A finished 30-day, 200-a-day taper, five days past its end. [lately] is
  /// the puffs on the days before today, newest first.
  JourneyState finished({List<int> lately = const [78, 80, 82, 84, 86, 0, 82]}) {
    final j = journeyOnDay(36, now: now, baseline: 200, weeklySpend: 60);
    final days = {...j.days};
    for (var back = 1; back <= lately.length; back++) {
      final date = LpDate.addDays(today, -back);
      final puffs = lately[back - 1];
      days[date] = DayLog(
        date: date,
        puffs: puffs,
        limit: 0,
        hourBuckets: puffs == 0 ? const {} : {21: puffs},
        vapeFreeConfirmed: puffs == 0,
      );
    }
    return j.copyWith(days: days);
  }

  Future<(ProviderContainer, RecordingAnalytics)> open(
    WidgetTester tester,
    JourneyState journey, {
    String route = Routes.home,
    bool online = true,
    List<Override> extra = const [],
  }) async {
    ignoreFontWidthOverflow();
    final analytics = RecordingAnalytics();
    final container = ProviderContainer(
      overrides: fastBackendOverrides(
        now: now,
        analytics: analytics,
        online: online,
        extra: extra,
      ),
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
    container.read(routerProvider).go(Routes.home);
    await tester.pumpAndSettle();
    if (route != Routes.home) {
      unawaited(container.read(routerProvider).push(route));
      await tester.pumpAndSettle();
    }
    return (container, analytics);
  }

  String path(ProviderContainer c) => c.read(routerProvider).state.uri.path;

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Step one's button: on to the history.
  Future<void> next(WidgetTester tester) =>
      tapVisible(tester, find.text(l10n.commonContinue));

  /// Step two, and the step-two button that keeps everything.
  Future<void> startKeeping(WidgetTester tester) async {
    await next(tester);
    await tapVisible(tester, find.text(l10n.newPlanCta));
  }

  group('step one: the plan', () {
    testWidgets('opens on the level they have really been at', (tester) async {
      await open(tester, finished(), route: Routes.planNew);

      expect(find.byType(NewPlanScreen), findsOneWidget);
      expect(find.text(l10n.obProgressOf(1, 2)), findsOneWidget);
      expect(find.text(l10n.newPlanTitle), findsOneWidget);
      expect(find.widgetWithText(TextField, '82'), findsOneWidget);
      expect(find.text(l10n.newPlanLevelHint(82)), findsOneWidget);
    });

    testWidgets('promises nothing about the history: that is step two', (
      tester,
    ) async {
      await open(tester, finished(), route: Routes.planNew);

      expect(find.text(l10n.newPlanHistoryTitle), findsNothing);
      expect(find.text(l10n.newPlanKeepTitle), findsNothing);
      expect(find.textContaining('Nothing resets'), findsNothing);
    });

    testWidgets('asks, and guesses nothing, when there is nothing to go on', (
      tester,
    ) async {
      await open(tester, finished(lately: const []), route: Routes.planNew);

      expect(find.text(l10n.newPlanLevelNoHint), findsOneWidget);
      expect(find.textContaining('averaged'), findsNothing);
      // Nothing typed, nothing to start a taper from: Continue goes nowhere.
      await next(tester);
      expect(find.text(l10n.obProgressOf(1, 2)), findsOneWidget);
      expect(find.text(l10n.newPlanHistoryTitle), findsNothing);
    });

    testWidgets('shows the line and the date the choices lead to, live', (
      tester,
    ) async {
      await open(tester, finished(), route: Routes.planNew);

      // The default runway is the one the old plan used: 30 days from 82.
      expect(find.text(l10n.newPlanToday(78)), findsOneWidget);
      expect(
        find.text(
          l10n.newPlanFreedom(
            LpFormat.shortDate(LpDate.addDays(today, 29), 'en'),
          ),
        ),
        findsOneWidget,
      );

      await tapVisible(tester, find.text('21'));
      expect(find.text(l10n.newPlanToday(76)), findsOneWidget);
      expect(
        find.text(
          l10n.newPlanFreedom(
            LpFormat.shortDate(LpDate.addDays(today, 20), 'en'),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('starting it lands on Home on day one, with nothing lost', (
      tester,
    ) async {
      final (c, analytics) = await open(
        tester,
        finished(),
        route: Routes.planNew,
      );
      final before = c.read(todayProvider)!;

      await tapVisible(tester, find.text('21'));
      await startKeeping(tester);

      expect(path(c), Routes.home);
      expect(find.byType(HomeScreen), findsOneWidget);
      final after = c.read(todayProvider)!;
      expect(after.dayNumber, 1);
      expect(after.totalDays, 21);
      expect(after.limit, 76);
      expect(after.streak, before.streak);
      expect(after.savedLifetime, before.savedLifetime);
      expect(after.cravingsSurvivedTotal, before.cravingsSurvivedTotal);
      expect(
        find.text(
          l10n.homeGreetingDate(LpFormat.weekdayDate(now, 'en'), 1, 21),
        ),
        findsOneWidget,
      );
      expect(analytics.names, contains('plan_restarted'));
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('a new day one is not sent back to the setup checklist', (
      tester,
    ) async {
      // Somebody who skipped setup on their first plan. Day one of plan two
      // must not be read as the first day of the app.
      final (c, _) = await open(
        tester,
        finished().copyWith(day1TasksDone: const {}, day1TourSkipped: false),
        route: Routes.planNew,
      );

      await startKeeping(tester);

      expect(path(c), Routes.home);
      expect(find.textContaining('Finish setup'), findsNothing);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  });

  group('the steps', () {
    testWidgets('Continue opens step two of two, keeping everything by '
        'default', (tester) async {
      final (c, _) = await open(tester, finished(), route: Routes.planNew);

      await next(tester);

      expect(path(c), Routes.planNew);
      expect(find.text(l10n.obProgressOf(2, 2)), findsOneWidget);
      expect(find.text(l10n.newPlanHistoryTitle), findsOneWidget);
      expect(find.text(l10n.newPlanCta), findsOneWidget);
      expect(find.text(l10n.newPlanFreshCta), findsNothing);
    });

    testWidgets('the back chevron on step two is a step back, with every '
        'answer still there', (tester) async {
      final (c, _) = await open(tester, finished(), route: Routes.planNew);
      await tester.enterText(find.byType(TextField), '100');
      await tester.pump();
      await tapVisible(tester, find.text('21'));
      // Whatever 100 a day over 21 days draws, it must be drawn again.
      final drawn =
          (tester.widget(find.textContaining("Today's line")) as Text).data!;
      expect(drawn, isNot(l10n.newPlanToday(76)), reason: 'fixture: not 82');
      final line = find.text(drawn);
      await next(tester);

      await tapVisible(tester, find.byType(BackChevron));

      expect(path(c), Routes.planNew);
      expect(find.text(l10n.obProgressOf(1, 2)), findsOneWidget);
      expect(find.widgetWithText(TextField, '100'), findsOneWidget);
      expect(line, findsOneWidget);
    });

    testWidgets('Back on step two is a step back too, and Android is told '
        'the app handles it', (tester) async {
      // Since Android 14 the OS hands Back to Flutter only while the
      // framework says it can handle one, and that is reported only once the
      // app has a lifecycle state — which `flutter test` starts without.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final handles = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
            handles.add(call.arguments);
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
      final (c, _) = await open(tester, finished(), route: Routes.planNew);
      await next(tester);
      expect(handles, isNotEmpty);
      expect(handles.last, isTrue, reason: 'Android would leave the screen');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(path(c), Routes.planNew);
      expect(find.text(l10n.obProgressOf(1, 2)), findsOneWidget);

      // And on step one, Back leaves the screen as it always did.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(NewPlanScreen), findsNothing);
    });
  });

  group('the choices', () {
    /// How far [label]'s painted glyphs sit from the centre of their chip.
    ///
    /// The glyphs, not the `Text`: a chip stretched by `Expanded` hands its
    /// label a tight width, so the text's own box is always the chip's width
    /// and always centred — wherever inside it the letters are drawn.
    double offCentre(WidgetTester tester, String label) {
      final text = find.text(label);
      final chip = find.ancestor(of: text, matching: find.byType(LpChip));
      final paragraph = tester.renderObject<RenderParagraph>(text);
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: label.length),
      );
      final ink = boxes
          .map((b) => b.toRect())
          .reduce((a, b) => a.expandToInclude(b));
      final inkCentre = paragraph.localToGlobal(ink.center).dx;
      return (inkCentre - tester.getCenter(chip).dx).abs();
    }

    testWidgets('method and pace chips centre their labels', (tester) async {
      await open(tester, finished(), route: Routes.planNew);

      // Stretched to a quarter or a half of the row each, the labels used to
      // sit flush against the left border.
      expect(offCentre(tester, '14'), lessThan(1));
      expect(offCentre(tester, '42'), lessThan(1));
      expect(offCentre(tester, l10n.obMethodCold), lessThan(1));
    });
  });

  group('step two: starting from scratch', () {
    /// [finished] with a record in every corner a scratch start erases.
    JourneyState lived() => finished().copyWith(
      cravingsSurvivedTotal: 9,
      earnedBadges: const {'spark', 'firstLog'},
      longestStreak: 18,
    );

    /// What the four numbers above the choice say, left to right.
    List<String> numbers(WidgetTester tester) => [
      for (final e
          in find
              .descendant(
                of: find.byType(RollingNumber),
                matching: find.byType(Text),
              )
              .evaluate())
        (e.widget as Text).data!,
    ];

    Future<void> chooseScratch(WidgetTester tester) async {
      await next(tester);
      await tapVisible(tester, find.text(l10n.newPlanFreshTitle));
    }

    Future<void> openDialog(WidgetTester tester) =>
        tapVisible(tester, find.text(l10n.newPlanFreshCta));

    testWidgets('their own numbers sit above the choice', (tester) async {
      final (c, _) = await open(tester, lived(), route: Routes.planNew);
      await next(tester);
      final snap = c.read(todayProvider)!;

      expect(numbers(tester), [
        '${snap.streak}',
        LpFormat.money(snap.savedLifetime, 'en'),
        '2',
        '9',
      ]);
      expect(snap.savedLifetime, greaterThan(0), reason: 'fixture');
    });

    testWidgets('choosing it rolls every one of them to zero, and names '
        'everything it erases, the coach included', (tester) async {
      await open(tester, lived(), route: Routes.planNew);

      await chooseScratch(tester);

      expect(numbers(tester), ['0', LpFormat.money(0, 'en'), '0', '0']);
      expect(find.text(l10n.newPlanFreshBody('Ember')), findsOneWidget);
      expect(find.text(l10n.newPlanCta), findsNothing);
      expect(find.text(l10n.newPlanFreshCta), findsOneWidget);
      // One choice, all of it: nothing to switch off.
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('going back to keeping brings the numbers and the button '
        'back', (tester) async {
      final (c, _) = await open(tester, lived(), route: Routes.planNew);
      await chooseScratch(tester);

      await tapVisible(tester, find.text(l10n.newPlanKeepTitle));

      expect(numbers(tester).last, '9');
      expect(find.text(l10n.newPlanCta), findsOneWidget);
      expect(find.text(l10n.newPlanFreshCta), findsNothing);
      expect(c.read(quitStoreProvider)!.cravingsSurvivedTotal, 9);
    });

    testWidgets('nothing is erased until the confirmation is accepted', (
      tester,
    ) async {
      final (c, analytics) = await open(tester, lived(), route: Routes.planNew);
      await chooseScratch(tester);

      await openDialog(tester);
      expect(find.text(l10n.newPlanFreshDialogTitle), findsOneWidget);
      expect(find.text(l10n.newPlanFreshGoesLog), findsOneWidget);
      expect(find.text(l10n.newPlanFreshGoesStreak), findsOneWidget);
      expect(find.text(l10n.newPlanFreshGoesCoach('Ember')), findsOneWidget);
      expect(find.text(l10n.newPlanFreshStays), findsOneWidget);
      expect(find.text(l10n.newPlanFreshNoUndo), findsOneWidget);

      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      expect(find.text(l10n.newPlanFreshDialogTitle), findsNothing);
      expect(path(c), Routes.planNew);
      expect(c.read(quitStoreProvider)!.cravingsSurvivedTotal, 9);
      expect(analytics.names, isNot(contains('plan_restarted')));
    });

    testWidgets('a tap outside the confirmation does not dismiss it', (
      tester,
    ) async {
      await open(tester, lived(), route: Routes.planNew);
      await chooseScratch(tester);
      await openDialog(tester);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(find.text(l10n.newPlanFreshDialogTitle), findsOneWidget);
    });

    testWidgets('confirming erases it all and lands on Home on day one', (
      tester,
    ) async {
      final (c, analytics) = await open(tester, lived(), route: Routes.planNew);
      await chooseScratch(tester);
      await openDialog(tester);

      await tester.tap(find.text(l10n.newPlanFreshConfirm));
      await tester.pumpAndSettle();

      expect(path(c), Routes.home);
      expect(find.byType(HomeScreen), findsOneWidget);
      final after = c.read(todayProvider)!;
      expect(after.dayNumber, 1);
      expect(after.streak, 0);
      expect(after.savedLifetime, 0);
      expect(after.cravingsSurvivedTotal, 0);
      final journey = c.read(quitStoreProvider)!;
      expect(journey.days.keys, [today]);
      expect(journey.earnedBadges, isEmpty);
      expect(journey.longestStreak, 0);
      expect(
        analytics.propsOf('plan_restarted'),
        containsPair('kept_history', 'false'),
      );
      expect(
        analytics.names.where((n) => n == 'plan_restarted'),
        hasLength(1),
        reason: 'committed once, by the screen, after it left',
      );
      final freedom = journey.plan.freedomDate;
      expect(
        find.text(l10n.newPlanFreshStarted(LpFormat.shortDate(freedom, 'en'))),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('offline, the erase fails, says why, and changes nothing', (
      tester,
    ) async {
      final (c, analytics) = await open(
        tester,
        lived(),
        route: Routes.planNew,
        online: false,
      );
      await chooseScratch(tester);
      await openDialog(tester);

      await tester.tap(find.text(l10n.newPlanFreshConfirm));
      await tester.pumpAndSettle();

      expect(find.text(l10n.newPlanFreshDialogTitle), findsNothing);
      expect(find.text(l10n.errorOfflineTitle), findsOneWidget);
      expect(path(c), Routes.planNew);
      expect(c.read(quitStoreProvider)!.cravingsSurvivedTotal, 9);
      expect(c.read(quitStoreProvider)!.days.length, greaterThan(1));
      expect(analytics.names, isNot(contains('plan_restarted')));
    });

    testWidgets('a reminder tapped mid-erase takes the screen away, and the '
        'journey still follows the server', (tester) async {
      final slow = _SlowErase();
      final (c, analytics) = await open(
        tester,
        lived(),
        route: Routes.planNew,
        extra: [serverStateRepositoryProvider.overrideWithValue(slow)],
      );
      await chooseScratch(tester);
      await openDialog(tester);
      await tester.tap(find.text(l10n.newPlanFreshConfirm));
      await tester.pump();

      // What a tapped reminder does (`_ReminderSync`): the screen and its
      // dialog are gone while the server is still erasing.
      c.read(routerProvider).go(Routes.home);
      await tester.pumpAndSettle();
      expect(find.byType(NewPlanScreen), findsNothing);
      expect(
        c.read(quitStoreProvider)!.cravingsSurvivedTotal,
        9,
        reason: 'nothing changes before the server has answered',
      );

      slow.gate.complete();
      await tester.pumpAndSettle();

      final journey = c.read(quitStoreProvider)!;
      expect(journey.days.keys, [today]);
      expect(journey.cravingsSurvivedTotal, 0);
      expect(journey.plan.planNumber, 2);
      expect(path(c), Routes.home);
      expect(analytics.names.where((n) => n == 'plan_restarted'), hasLength(1));
    });
  });

  group('after a new plan has started', () {
    /// Restarted today, on top of [before].
    Future<ProviderContainer> restarted(
      WidgetTester tester,
      JourneyState before, {
      String route = Routes.home,
    }) async {
      final (c, _) = await open(tester, before);
      c
          .read(quitStoreProvider.notifier)
          .startNewPlan(method: QuitMethod.taper, paceDays: 21, level: 82);
      await tester.pumpAndSettle();
      if (route != Routes.home) {
        unawaited(c.read(routerProvider).push(route));
        await tester.pumpAndSettle();
      }
      return c;
    }

    testWidgets('an unanswered yesterday is still asked about', (
      tester,
    ) async {
      // Yesterday has no log at all. It came before the new plan's day one,
      // and the card was bounded by the plan — so it vanished and the chain
      // stayed broken with nothing to say why.
      final j = finished();
      final yesterday = LpDate.addDays(today, -1);
      final c = await restarted(
        tester,
        j.copyWith(days: {...j.days}..remove(yesterday)),
      );
      expect(c.read(quitStoreProvider)!.days[yesterday], isNull);

      expect(
        find.text(l10n.homeYesterdayTitle, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('Money and Profile still date things from the beginning', (
      tester,
    ) async {
      final before = finished();
      final began = LpFormat.shortDate(before.historyStart, 'en');
      final restartDay = LpFormat.shortDate(today, 'en');
      expect(began, isNot(restartDay), reason: 'fixture');

      await restarted(tester, before, route: Routes.money);
      expect(find.textContaining('saved since $began'), findsOneWidget);
      expect(find.textContaining('saved since $restartDay'), findsNothing);
    });

    testWidgets('Profile says how long they have really been at it', (
      tester,
    ) async {
      final before = finished();
      final began = LpFormat.shortDate(before.historyStart, 'en');

      await restarted(tester, before, route: Routes.profile);
      expect(find.textContaining('quitting since $began'), findsOneWidget);
    });
  });

  group('the doors', () {
    testWidgets('Home, once the plan has ended and puffs are still being '
        'logged', (tester) async {
      final (c, _) = await open(tester, finished());

      await tapVisible(
        tester,
        find.text(l10n.homePlanEndedTitle, skipOffstage: false),
      );

      expect(path(c), Routes.planNew);
    });

    testWidgets('but not for somebody who has stopped', (tester) async {
      // Past Freedom Day with clean days behind them: they are done, and
      // suggesting another plan would be telling them they are not.
      await open(tester, finished(lately: const [0, 0, 0]));

      expect(
        find.text(l10n.homePlanEndedTitle, skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('nor in the middle of a plan', (tester) async {
      await open(tester, journeyOnDay(12, now: now));

      expect(
        find.text(l10n.homePlanEndedTitle, skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('the Plan screen, where a finished plan offers the next one '
        'in place of an adjustment', (tester) async {
      final (c, _) = await open(tester, finished(), route: Routes.plan);

      expect(find.text(l10n.planAdjustCta), findsNothing);
      await tapVisible(tester, find.text(l10n.planNewCta));

      expect(path(c), Routes.planNew);
    });

    testWidgets('and a running one offers both', (tester) async {
      await open(tester, journeyOnDay(12, now: now), route: Routes.plan);

      expect(find.text(l10n.planAdjustCta), findsOneWidget);
      expect(find.text(l10n.planNewCta), findsOneWidget);
    });

    testWidgets('the sign-out dialog, which is where they were giving up', (
      tester,
    ) async {
      final (c, _) = await open(tester, finished(), route: Routes.settings);
      final signOut = find.text(l10n.settingsSignOut, skipOffstage: false);
      await tester.scrollUntilVisible(
        signOut,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(signOut);
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.settingsSignOutNewPlan));
      await tester.pumpAndSettle();

      expect(path(c), Routes.planNew);
      expect(c.read(quitStoreProvider), isNotNull, reason: 'still signed in');
    });
  });
}

/// An erase that answers when the test says so.
class _SlowErase extends NoopServerStateRepository {
  _SlowErase();

  final gate = Completer<void>();

  @override
  Future<void> eraseHistory() => gate.future;
}
