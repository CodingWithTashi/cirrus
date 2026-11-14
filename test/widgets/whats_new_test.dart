import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3 moved `Override` out of the main library.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/utils/lp_review.dart';
import 'package:last_puff/data/api/firebase/push_service.dart';
import 'package:last_puff/data/repositories/fake_remote_flags_repository.dart';
import 'package:last_puff/data/stores/day1_tour_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/data/stores/settings_store.dart';
import 'package:last_puff/data/stores/update_check_store.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';

import '../helpers.dart';

class _Iphone extends UpgraderOS {
  @override
  UpgraderOSType get currentOSType => UpgraderOSType.ios;

  @override
  String get current => 'ios';

  @override
  bool get isIOS => true;

  @override
  bool get isAndroid => false;
}

/// Settings as they are before the preferences have answered.
class _Unread extends SettingsStore {
  _Unread() : super(restore: false);

  @override
  SettingsState build() => const SettingsState(hydrated: false);
}

class _Permissions implements PushPermissions {
  @override
  Future<PushPermission> status() async => PushPermission.notAsked;

  @override
  Future<bool> request() async => true;
}

const _bundleId = 'com.quitvape.lastPuff';
const _installed = '1.0.32';

http.Client _appStore({String version = '1.0.33', Completer<void>? hold}) =>
    MockClient((_) async {
      if (hold != null) await hold.future;
      return http.Response(
        jsonEncode({
          'resultCount': 1,
          'results': [
            {'version': version, 'bundleId': _bundleId, 'releaseNotes': ''},
          ],
        }),
        200,
      );
    });

/// What's New, once per version, and the one-modal-a-visit order it sits in
/// (docs/10 §55): forced > update prompt > What's New > the notification ask
/// > the rating ask.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Cirrus',
      packageName: _bundleId,
      version: _installed,
      buildNumber: '32',
      buildSignature: '',
    );
  });

  Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
    for (var turn = 0; !done(); turn++) {
      if (turn == 200) fail('Still waiting after $turn turns');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<ProviderContainer> boot(
    WidgetTester tester, {
    String? installedVersion = _installed,
    http.Client? store,
    JourneyState? journey,
    RecordingAnalytics? analytics,
    List<Override> extra = const [],
    void Function(ProviderContainer)? before,
    bool settle = true,
  }) async {
    Upgrader? upgrader;
    if (store != null) {
      upgrader = Upgrader(
        client: store,
        upgraderOS: _Iphone(),
        checkOnResume: false,
      );
      addTearDown(upgrader.dispose);
    }
    final container = ProviderContainer(
      overrides: fastBackendOverrides(
        analytics: analytics,
        upgrader: upgrader,
        remoteFlags: FakeRemoteFlagsRepository(),
        installedVersion: installedVersion,
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
    final quit = container.read(quitStoreProvider.notifier);
    journey == null ? quit.seedDemoJourney() : quit.replaceForTest(journey);
    // Still on the splash: Home has not been built yet.
    before?.call(container);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    if (settle) {
      await pumpUntil(
        tester,
        () => container.read(updateCheckProvider).settled,
      );
      await tester.pumpAndSettle();
    }
    return container;
  }

  void newVisit(WidgetTester tester) {
    for (final state in [
      AppLifecycleState.resumed,
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  Finder whatsNew() => find.text(l10n.whatsNewTitle);

  group("What's New", () {
    testWidgets('on the first Home visit of a version: its notes, one button, '
        'then never again for that version', (tester) async {
      final analytics = RecordingAnalytics();
      final c = await boot(tester, analytics: analytics);

      expect(whatsNew(), findsOneWidget);
      expect(find.text(_installed), findsOneWidget, reason: 'the chip');
      expect(find.text(l10n.whatsNew1032Item1), findsOneWidget);
      expect(find.text(l10n.whatsNew1032Item2), findsOneWidget);
      expect(find.text(l10n.whatsNew1032Item3), findsOneWidget);
      expect(find.text(l10n.whatsNewDone), findsOneWidget);
      expect(find.text(l10n.commonNotNow), findsNothing);
      expect(analytics.propsOfAll('whats_new_shown'), [
        {'version': _installed},
      ]);
      expect(c.read(settingsStoreProvider).whatsNewSeenVersion, _installed);

      await tester.tap(find.text(l10n.whatsNewDone));
      await tester.pumpAndSettle();
      expect(whatsNew(), findsNothing);
      expect(find.text(l10n.homeLogPuff), findsOneWidget);

      newVisit(tester);
      await tester.pumpAndSettle();
      expect(whatsNew(), findsNothing);
      expect(analytics.propsOfAll('whats_new_shown'), hasLength(1));
    });

    testWidgets('after an update from an older version', (tester) async {
      await boot(
        tester,
        before: (c) =>
            c.read(settingsStoreProvider.notifier).markWhatsNewSeen('1.0.31'),
      );
      expect(whatsNew(), findsOneWidget);
    });

    testWidgets('a version already seen shows nothing', (tester) async {
      final analytics = RecordingAnalytics();
      await boot(
        tester,
        analytics: analytics,
        before: (c) =>
            c.read(settingsStoreProvider.notifier).markWhatsNewSeen(_installed),
      );
      expect(whatsNew(), findsNothing);
      expect(analytics.names, isNot(contains('whats_new_shown')));
    });

    testWidgets('a version with no notes shows nothing', (tester) async {
      await boot(tester, installedVersion: '1.0.99');
      expect(whatsNew(), findsNothing);
    });

    testWidgets('waits for the settings to be read', (tester) async {
      await boot(
        tester,
        extra: [settingsStoreProvider.overrideWith(_Unread.new)],
      );
      expect(whatsNew(), findsNothing);
    });

    testWidgets('never during the Day-1 tour', (tester) async {
      final c = await boot(
        tester,
        journey: journeyOnDay(
          3,
          now: DateTime.now(),
        ).copyWith(day1TasksDone: const {}),
        // Started from the checklist before Home is first built.
        before: (c) =>
            c.read(day1TourProvider.notifier).start(Day1TourStep.logPuff),
      );
      expect(c.read(day1TourLockedProvider), isTrue);
      expect(c.read(routerProvider).state.uri.path, Routes.home);
      expect(whatsNew(), findsNothing);
      expect(c.read(settingsStoreProvider).whatsNewSeenVersion, isNull);
    });
  });

  group('one modal a visit', () {
    testWidgets('the update prompt goes first; What\'s New waits for the next '
        'visit, unmarked', (tester) async {
      final c = await boot(tester, store: _appStore());
      expect(find.text(l10n.updateTitle), findsOneWidget);
      expect(whatsNew(), findsNothing);

      await tester.tap(find.text(l10n.commonNotNow));
      await tester.pumpAndSettle();
      expect(whatsNew(), findsNothing);
      expect(c.read(settingsStoreProvider).whatsNewSeenVersion, isNull);

      newVisit(tester);
      await tester.pumpAndSettle();
      expect(whatsNew(), findsOneWidget);
    });

    testWidgets("What's New waits while the store check is still out", (
      tester,
    ) async {
      final hold = Completer<void>();
      final c = await boot(
        tester,
        store: _appStore(version: _installed, hold: hold),
        settle: false,
      );
      await tester.pumpAndSettle();
      expect(whatsNew(), findsNothing);

      hold.complete();
      await pumpUntil(tester, () => c.read(updateCheckProvider).settled);
      await tester.pumpAndSettle();
      expect(whatsNew(), findsOneWidget);
    });

    testWidgets("after What's New, the notification ask waits — and is not "
        'spent', (tester) async {
      final c = await boot(
        tester,
        extra: [pushPermissionsProvider.overrideWithValue(_Permissions())],
      );
      await tester.tap(find.text(l10n.whatsNewDone));
      await tester.pumpAndSettle();

      Future<void> finishDay1() async {
        c.read(routerProvider).go(Routes.day1);
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.day1CtaHome));
        await tester.pumpAndSettle();
      }

      await finishDay1();
      expect(find.text(l10n.pushAskDayOneTitle), findsNothing);
      expect(c.read(settingsStoreProvider).pushAsksShown, isEmpty);

      newVisit(tester);
      await finishDay1();
      expect(find.text(l10n.pushAskDayOneTitle), findsOneWidget);
    });

    testWidgets("after What's New, no rating card on the Survived screen", (
      tester,
    ) async {
      final c = await boot(
        tester,
        extra: [
          reviewRouteProvider.overrideWith((_) async => ReviewRoute.sheet),
        ],
      );
      await tester.tap(find.text(l10n.whatsNewDone));
      await tester.pumpAndSettle();

      unawaited(c.read(routerProvider).push(Routes.survived));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(l10n.reviewAskTitle, skipOffstage: false), findsNothing);
    });

    testWidgets("a rating card on screen spends the visit: What's New comes "
        'on the next', (tester) async {
      final hold = Completer<void>();
      final c = await boot(
        tester,
        store: _appStore(version: _installed, hold: hold),
        extra: [
          reviewRouteProvider.overrideWith((_) async => ReviewRoute.sheet),
        ],
        settle: false,
      );
      // On Home, with What's New held back by the store check still out.
      await tester.pumpAndSettle();
      expect(whatsNew(), findsNothing);
      // The seeded day-12 account has beaten enough cravings for the card.
      unawaited(c.read(routerProvider).push(Routes.survived));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        find.text(l10n.reviewAskTitle, skipOffstage: false),
        findsOneWidget,
      );

      hold.complete();
      await pumpUntil(tester, () => c.read(updateCheckProvider).settled);
      c.read(routerProvider).go(Routes.home);
      await tester.pumpAndSettle();
      expect(whatsNew(), findsNothing);
      expect(c.read(settingsStoreProvider).whatsNewSeenVersion, isNull);

      newVisit(tester);
      await tester.pumpAndSettle();
      expect(whatsNew(), findsOneWidget);
    });
  });
}
