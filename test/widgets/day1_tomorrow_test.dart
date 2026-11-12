import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/api/firebase/push_service.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// Day one ends by pointing at day two.
///
/// The checklist was finished about eighty seconds after onboarding, and its
/// last screen said only "Go to Today". People who used the app on one day
/// and never again left a median of five minutes after onboarding (Nov 11
/// 2026): setup done, and nothing said what tomorrow was for. A finished
/// list now names tomorrow's number, from the engine, and tonight's check-in
/// when — and only when — one is really going to arrive.
///
/// And a list somebody skipped stays reachable from Home for the first three
/// days, instead of being gone for good at the first tap of "Skip".
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final afternoon = DateTime(2026, 11, 12, 15, 30);

  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  JourneyState journey(
    DateTime now, {
    int day = 1,
    QuitMethod method = QuitMethod.taper,
    Set<int> done = const {0, 1, 2},
    bool skipped = false,
  }) {
    final j = journeyOnDay(day, now: now);
    return j.copyWith(
      plan: j.plan.copyWith(method: method),
      day1TasksDone: done,
      day1TourSkipped: skipped,
    );
  }

  Future<ProviderContainer> open(
    WidgetTester tester,
    JourneyState j, {
    required DateTime now,
    required String route,
    PushPermission permission = PushPermission.granted,
  }) async {
    ignoreFontWidthOverflow();
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(now: now),
        pushPermissionsProvider.overrideWithValue(_Permissions(permission)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).replaceForTest(j);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    container.read(routerProvider).go(route);
    await tester.pumpAndSettle();
    return container;
  }

  group('a finished checklist', () {
    testWidgets('names tomorrow\'s line, from the engine', (tester) async {
      final j = journey(afternoon);
      await open(tester, j, now: afternoon, route: Routes.day1);

      final tomorrow = j.limitOn(LpDate.addDays(LpDate.dayStart(afternoon), 1));
      expect(tomorrow, greaterThan(0), reason: 'fixture');
      expect(find.text(l10n.day1NextTaper(tomorrow)), findsOneWidget);
    });

    testWidgets('and tonight\'s check-in, when one is going to arrive', (
      tester,
    ) async {
      await open(tester, journey(afternoon), now: afternoon, route: Routes.day1);

      expect(find.text(l10n.day1NextCheckin('8 PM')), findsOneWidget);
    });

    testWidgets('but promises no check-in without the permission for one', (
      tester,
    ) async {
      await open(
        tester,
        journey(afternoon),
        now: afternoon,
        route: Routes.day1,
        permission: PushPermission.notAsked,
      );

      expect(find.textContaining('first check-in'), findsNothing);
      // Tomorrow's line needs no permission to be true.
      expect(find.textContaining("Tomorrow's line"), findsOneWidget);
    });

    testWidgets('nor once tonight\'s has already gone', (tester) async {
      final late = DateTime(2026, 11, 12, 21, 10);
      await open(tester, journey(late), now: late, route: Routes.day1);

      expect(find.textContaining('first check-in'), findsNothing);
    });

    testWidgets('on a zero line, tomorrow is day two vape-free', (
      tester,
    ) async {
      await open(
        tester,
        journey(afternoon, method: QuitMethod.coldTurkey),
        now: afternoon,
        route: Routes.day1,
      );

      expect(find.text(l10n.day1NextZero), findsOneWidget);
      expect(find.textContaining("Tomorrow's line"), findsNothing);
    });

    testWidgets('an unfinished one says nothing about tomorrow yet', (
      tester,
    ) async {
      await open(
        tester,
        journey(afternoon, done: const {0}),
        now: afternoon,
        route: Routes.day1,
      );

      expect(find.textContaining("Tomorrow's line"), findsNothing);
      expect(find.textContaining('first check-in'), findsNothing);
    });
  });

  group('setup somebody skipped', () {
    testWidgets('is a card on Home that reopens the checklist', (
      tester,
    ) async {
      final c = await open(
        tester,
        journey(afternoon, done: const {}, skipped: true),
        now: afternoon,
        route: Routes.home,
      );

      expect(find.text(l10n.homeFinishSetup(0)), findsOneWidget);
      await tester.tap(find.text(l10n.homeFinishSetup(0)));
      await tester.pumpAndSettle();

      expect(c.read(routerProvider).state.uri.path, Routes.day1);
    });

    testWidgets('and the checklist it reopens can be left again', (
      tester,
    ) async {
      // "Skip setup for now" is hidden once it has been used, the screen has
      // no back control, and every other button starts a tour step that
      // returns here. Opened from Home, that was a room with no door: on an
      // iPhone the only ways out were finishing all three tasks — one needs
      // a network — or killing the app.
      final c = await open(
        tester,
        journey(afternoon, done: const {}, skipped: true),
        now: afternoon,
        route: Routes.day1,
      );
      expect(find.text(l10n.day1Skip), findsNothing);

      final back = find.text(l10n.day1CtaHome, skipOffstage: false);
      await tester.ensureVisible(back);
      await tester.pump();
      await tester.tap(back);
      await tester.pumpAndSettle();

      expect(c.read(routerProvider).state.uri.path, Routes.home);
      expect(
        c.read(quitStoreProvider)!.day1TasksDone,
        isEmpty,
        reason: 'leaving ticks nothing',
      );
    });

    testWidgets('counts what is already done, on day two as well', (
      tester,
    ) async {
      await open(
        tester,
        journey(afternoon, day: 2, done: const {0}),
        now: afternoon,
        route: Routes.home,
      );

      expect(find.text(l10n.homeFinishSetup(1)), findsOneWidget);
    });

    testWidgets('stops asking after the third day', (tester) async {
      await open(
        tester,
        journey(afternoon, day: 4, done: const {0}),
        now: afternoon,
        route: Routes.home,
      );

      expect(find.textContaining('Finish setup'), findsNothing);
    });

    testWidgets('and is never there once setup is finished', (tester) async {
      await open(
        tester,
        journey(afternoon, day: 2),
        now: afternoon,
        route: Routes.home,
      );

      expect(find.textContaining('Finish setup'), findsNothing);
    });
  });
}

class _Permissions implements PushPermissions {
  _Permissions(this._status);

  final PushPermission _status;

  @override
  Future<PushPermission> status() async => _status;

  @override
  Future<bool> request() async => _status == PushPermission.granted;
}
