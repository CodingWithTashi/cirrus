import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/utils/lp_links.dart';
import 'package:last_puff/data/repositories/fake_remote_flags_repository.dart';
import 'package:last_puff/data/stores/day1_tour_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/data/stores/update_check_store.dart';
import 'package:last_puff/domain/logic/update_prompt_policy.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/repositories/repositories.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';

import '../helpers.dart';

/// An iPhone, so upgrader asks the App Store: the test platform reports
/// android, and Google Play answers with a whole HTML page.
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

const _bundleId = 'com.quitvape.lastPuff';
const _installed = '1.0.32';
const _storeNotes = 'Faster Home.\nA fix for the widget.';

/// The App Store's answer for Cirrus: [version], with [notes] as its "What's
/// New". With [hold], the answer waits until the test completes it — which is
/// how a test puts the person somewhere particular when the verdict lands.
http.Client _appStore({
  String version = '1.0.33',
  String notes = _storeNotes,
  Completer<void>? hold,
}) => MockClient((_) async {
  if (hold != null) await hold.future;
  return http.Response(
    jsonEncode({
      'resultCount': 1,
      'results': [
        {
          'version': version,
          'bundleId': _bundleId,
          'releaseNotes': notes,
          'trackViewUrl': 'https://apps.apple.com/app/id${LpLinks.appStoreId}',
          'description': 'Cirrus',
        },
      ],
    }),
    200,
  );
});

/// A store that answers with an error page: unreadable, so nothing is known.
http.Client _brokenStore() =>
    MockClient((_) async => http.Response('<html>try later</html>', 503));

/// A store that never answers at all.
http.Client _silentStore() =>
    MockClient((_) => Completer<http.Response>().future);

/// What a person on 1.0.32 sees once the store has something newer
/// (docs/10 §55): an optional prompt over Home with Update and Not now; with
/// Remote Config's `force_update_app` on, a screen with Update and nothing
/// else. Both fail open, and neither interrupts a craving.
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

  Upgrader upgraderFor(http.Client store) {
    final upgrader = Upgrader(
      client: store,
      upgraderOS: _Iphone(),
      checkOnResume: false,
    );
    addTearDown(upgrader.dispose);
    return upgrader;
  }

  /// Pumps until [done]: part of the store's answer comes on the real clock,
  /// which a widget test's fake clock never moves.
  Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
    for (var turn = 0; !done(); turn++) {
      if (turn == 200) fail('Still waiting after $turn turns');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> verdict(WidgetTester tester, ProviderContainer c) =>
      pumpUntil(tester, () => c.read(updateCheckProvider).settled);

  /// The real app on the fake backend, with the store and the flags this
  /// test wants. Signed in, it lands on the seeded day-12 Home.
  Future<ProviderContainer> boot(
    WidgetTester tester, {
    http.Client? store,
    RemoteFlags flags = RemoteFlags.none,
    bool flagsFail = false,
    String? installedVersion,
    bool signedIn = true,
    JourneyState? journey,
    bool waitForVerdict = true,
    RecordingAnalytics? analytics,
    List<Uri>? opened,
    Key? launch,
  }) async {
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(
          analytics: analytics,
          upgrader: store == null ? null : upgraderFor(store),
          remoteFlags: FakeRemoteFlagsRepository(
            flags: flags,
            fails: flagsFail,
          ),
          installedVersion: installedVersion,
        ),
        linkOpenerProvider.overrideWithValue((uri) async {
          opened?.add(uri);
          return true;
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        key: launch,
        container: container,
        child: const LastPuffApp(),
      ),
    );
    if (!signedIn) {
      await parkOnSignIn(tester);
    } else if (journey != null) {
      container.read(quitStoreProvider.notifier).replaceForTest(journey);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
    } else {
      container.read(quitStoreProvider.notifier).seedDemoJourney();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
    }
    if (waitForVerdict) {
      await verdict(tester, container);
      await tester.pumpAndSettle();
    }
    return container;
  }

  String path(ProviderContainer c) =>
      c.read(routerProvider).routerDelegate.currentConfiguration.uri.path;

  Finder sheetTitle() => find.text(l10n.updateTitle);
  Finder forcedTitle() => find.text(l10n.updateRequiredTitle);

  /// The app leaves the screen and comes back: a new visit.
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

  group('the optional prompt', () {
    testWidgets('offers Update and Not now over Home, and nothing else', (
      tester,
    ) async {
      final analytics = RecordingAnalytics();
      final c = await boot(tester, store: _appStore(), analytics: analytics);

      expect(path(c), Routes.home);
      expect(sheetTitle(), findsOneWidget);
      expect(find.text(l10n.updateReason), findsOneWidget);
      expect(find.text('1.0.33'), findsOneWidget, reason: 'the version chip');
      expect(find.text(l10n.updateCta), findsOneWidget);
      expect(find.text(l10n.commonNotNow), findsOneWidget);
      // No Ignore, under any of upgrader's spellings.
      expect(find.textContaining(RegExp('ignore', caseSensitive: false)),
          findsNothing);
      expect(analytics.propsOfAll('update_prompt_shown'), [
        {'forced': 'false'},
      ]);

      await tester.tap(find.text(l10n.commonNotNow));
      await tester.pumpAndSettle();
      expect(sheetTitle(), findsNothing);
      expect(find.text(l10n.homeLogPuff), findsOneWidget);
      expect(analytics.names, contains('update_prompt_later'));
      expect(analytics.names, isNot(contains('update_prompt_update')));
    });

    testWidgets('Update opens the store listing', (tester) async {
      final analytics = RecordingAnalytics();
      final opened = <Uri>[];
      await boot(
        tester,
        store: _appStore(),
        analytics: analytics,
        opened: opened,
      );

      await tester.tap(find.text(l10n.updateCta));
      await tester.pumpAndSettle();
      expect(opened, [LpLinks.storeListing(defaultTargetPlatform)]);
      expect(analytics.names, contains('update_prompt_update'));
      expect(analytics.names, isNot(contains('update_prompt_later')));
    });

    testWidgets('nothing newer in the store, nothing offered', (tester) async {
      await boot(tester, store: _appStore(version: _installed));
      expect(sheetTitle(), findsNothing);
      expect(forcedTitle(), findsNothing);
    });

    testWidgets('after Not now it stays away for three days, across a new '
        'launch — unless the store has moved on again', (tester) async {
      await boot(tester, store: _appStore());
      await tester.tap(find.text(l10n.commonNotNow));
      await tester.pumpAndSettle();

      // A new launch the same day: quiet.
      await boot(tester, store: _appStore(), launch: UniqueKey());
      expect(sheetTitle(), findsNothing);

      // A newer version than the one it asked about: asked again.
      await boot(tester, store: _appStore(version: '1.0.34'),
          launch: UniqueKey());
      expect(sheetTitle(), findsOneWidget);
      await tester.tap(find.text(l10n.commonNotNow));
      await tester.pumpAndSettle();

      // Four days on, the same version is offered again.
      await tester.runAsync(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'lastTimeAlerted',
          DateTime.now().subtract(const Duration(days: 4)).toString(),
        );
      });
      await boot(tester, store: _appStore(version: '1.0.34'),
          launch: UniqueKey());
      expect(sheetTitle(), findsOneWidget);
    });

    testWidgets('offered once a launch, not again on the next visit', (
      tester,
    ) async {
      await boot(tester, store: _appStore());
      await tester.tap(find.text(l10n.commonNotNow));
      await tester.pumpAndSettle();
      newVisit(tester);
      await tester.pumpAndSettle();
      expect(sheetTitle(), findsNothing);
    });

    testWidgets('never over sign-in or the quiz', (tester) async {
      final c = await boot(tester, store: _appStore(), signedIn: false);
      expect(path(c), Routes.auth);
      expect(c.read(updateCheckProvider).kind, UpdateKind.optional);
      expect(sheetTitle(), findsNothing);

      c.read(routerProvider).go(Routes.onboarding);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(sheetTitle(), findsNothing);
    });

    testWidgets('never over a craving: it waits for Home', (tester) async {
      final hold = Completer<void>();
      final c = await boot(
        tester,
        store: _appStore(hold: hold),
        waitForVerdict: false,
      );
      c.read(routerProvider).go(Routes.panic);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      hold.complete();
      await verdict(tester, c);
      await tester.pump(const Duration(milliseconds: 500));
      expect(path(c), Routes.panic);
      expect(sheetTitle(), findsNothing);

      c.read(routerProvider).go(Routes.home);
      await tester.pumpAndSettle();
      expect(sheetTitle(), findsOneWidget);
    });

    testWidgets('never over another tab, or a route pushed over Home', (
      tester,
    ) async {
      final hold = Completer<void>();
      final c = await boot(
        tester,
        store: _appStore(hold: hold),
        waitForVerdict: false,
      );
      await tester.pumpAndSettle();
      c.read(routerProvider).go(Routes.stats);
      await tester.pumpAndSettle();
      hold.complete();
      await verdict(tester, c);
      await tester.pumpAndSettle();
      expect(sheetTitle(), findsNothing);

      c.read(routerProvider).go(Routes.home);
      await tester.pumpAndSettle();
      expect(sheetTitle(), findsOneWidget);
    });

    testWidgets('never over a sheet that is already open', (tester) async {
      final hold = Completer<void>();
      final c = await boot(
        tester,
        store: _appStore(hold: hold),
        waitForVerdict: false,
      );
      await tester.pumpAndSettle();
      unawaited(
        showModalBottomSheet<void>(
          context: lpRootNavigatorKey.currentContext!,
          builder: (_) => const SizedBox(height: 120, child: Text('mine')),
        ),
      );
      await tester.pumpAndSettle();
      hold.complete();
      await verdict(tester, c);
      await tester.pumpAndSettle();
      expect(find.text('mine'), findsOneWidget);
      expect(sheetTitle(), findsNothing);
    });

    testWidgets('never during the Day-1 tour', (tester) async {
      final hold = Completer<void>();
      // Past day one, with the setup still to do: the tour can be started
      // from the checklist, and walks them through Home.
      final c = await boot(
        tester,
        store: _appStore(hold: hold),
        journey: journeyOnDay(
          3,
          now: DateTime.now(),
        ).copyWith(day1TasksDone: const {}),
        waitForVerdict: false,
      );
      await tester.pumpAndSettle();
      c.read(day1TourProvider.notifier).start(Day1TourStep.logPuff);
      await tester.pump();
      expect(c.read(day1TourLockedProvider), isTrue);
      hold.complete();
      await verdict(tester, c);
      await tester.pump(const Duration(milliseconds: 500));
      expect(path(c), Routes.home);
      expect(sheetTitle(), findsNothing);
    });
  });

  group('the notes', () {
    String notesJson(String version) => jsonEncode({
      'version': version,
      'en': ['Log a puff from the widget', 'A calmer Home'],
      'de': ['Zug vom Widget eintragen'],
    });

    testWidgets('Remote Config notes for the store\'s version win', (
      tester,
    ) async {
      await boot(
        tester,
        store: _appStore(),
        flags: RemoteFlags(releaseNotes: notesJson('1.0.33')),
      );
      expect(find.text('Log a puff from the widget'), findsOneWidget);
      expect(find.text('A calmer Home'), findsOneWidget);
      expect(find.text('Faster Home.'), findsNothing);
    });

    testWidgets('notes written for another version fall back to the store\'s',
        (tester) async {
      await boot(
        tester,
        store: _appStore(),
        flags: RemoteFlags(releaseNotes: notesJson('1.0.31')),
      );
      expect(find.text('Log a puff from the widget'), findsNothing);
      expect(find.text('Faster Home.'), findsOneWidget);
      expect(find.text('A fix for the widget.'), findsOneWidget);
    });

    testWidgets('no notes anywhere: no list, never an invented one', (
      tester,
    ) async {
      await boot(tester, store: _appStore(notes: ''));
      expect(sheetTitle(), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    });
  });

  group('the forced screen', () {
    testWidgets('Update only — no Not now, Back does nothing, and no route '
        'gets past it', (tester) async {
      final analytics = RecordingAnalytics();
      final opened = <Uri>[];
      final c = await boot(
        tester,
        store: _appStore(),
        flags: const RemoteFlags(forceUpdate: true),
        analytics: analytics,
        opened: opened,
      );

      expect(path(c), Routes.updateRequired);
      expect(forcedTitle(), findsOneWidget);
      expect(find.text(l10n.updateRequiredBody), findsOneWidget);
      expect(find.text(l10n.updateCta), findsOneWidget);
      expect(find.text(l10n.commonNotNow), findsNothing);
      expect(sheetTitle(), findsNothing, reason: 'not the optional sheet too');
      expect(find.text(l10n.homeLogPuff), findsNothing);
      expect(analytics.propsOfAll('update_prompt_shown'), [
        {'forced': 'true'},
      ]);

      // Back: handled, and nothing — not even closing the app.
      final platformCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          platformCalls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        platformCalls.where((call) => call.method == 'SystemNavigator.pop'),
        isEmpty,
        reason: 'Back must not close the app either',
      );
      expect(forcedTitle(), findsOneWidget);

      // A notification tap or any other `go` lands back here.
      c.read(routerProvider).go(Routes.settings);
      await tester.pumpAndSettle();
      expect(path(c), Routes.updateRequired);

      await tester.tap(find.text(l10n.updateCta));
      await tester.pumpAndSettle();
      expect(opened, [LpLinks.storeListing(defaultTargetPlatform)]);
      expect(analytics.names, contains('update_prompt_update'));
      expect(forcedTitle(), findsOneWidget, reason: 'it stays until updated');
    });

    testWidgets('tells Android it handles Back, so the system never closes '
        'the app from it', (tester) async {
      // On Android 14+ the OS hands Back to Flutter only while the framework
      // has said it can handle one (`SystemNavigator.setFrameworkHandlesBack`);
      // otherwise the OS acts alone and the app leaves. `handlePopRoute` in
      // the test above never reaches that hand-off, and it only happens at
      // all once the app is resumed — `flutter test` starts with no lifecycle.
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
      final c = await boot(
        tester,
        store: _appStore(),
        flags: const RemoteFlags(forceUpdate: true),
        signedIn: false,
      );
      await tester.pumpAndSettle();
      expect(path(c), Routes.updateRequired);
      expect(handles, isNotEmpty);
      expect(handles.last, isTrue, reason: 'Android would close the app');
    });

    testWidgets('stands in front of sign-in too', (tester) async {
      final c = await boot(
        tester,
        store: _appStore(),
        flags: const RemoteFlags(forceUpdate: true),
        signedIn: false,
      );
      await tester.pumpAndSettle();
      expect(path(c), Routes.updateRequired);
      expect(forcedTitle(), findsOneWidget);
    });

    testWidgets('never during a craving or the Survived screen — it waits for '
        'them to finish', (tester) async {
      final hold = Completer<void>();
      final c = await boot(
        tester,
        store: _appStore(hold: hold),
        flags: const RemoteFlags(forceUpdate: true),
        waitForVerdict: false,
      );
      final router = c.read(routerProvider);
      router.go(Routes.panic);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      hold.complete();
      await verdict(tester, c);
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.read(updateCheckProvider).forced, isTrue);
      expect(path(c), Routes.panic);
      expect(forcedTitle(), findsNothing);

      router.go(Routes.survived);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(path(c), Routes.survived);
      expect(forcedTitle(), findsNothing);

      router.go(Routes.home);
      await tester.pumpAndSettle();
      expect(path(c), Routes.updateRequired);

      // The splash this test left behind is still inside its 2.5s wait for the
      // billing backend: `seedDemoJourney` opens no session, so the entitlement
      // never settles and the wait always runs to its end. The test used to
      // finish just after that timer fired, by a few `pumpUntil` turns; let it
      // run out on purpose rather than depend on how fast the verdict came.
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('never over a store sheet — it waits for the sheet to close', (
      tester,
    ) async {
      final hold = Completer<void>();
      final c = await boot(
        tester,
        store: _appStore(hold: hold),
        flags: const RemoteFlags(forceUpdate: true),
        waitForVerdict: false,
      );
      await tester.pumpAndSettle();
      c.read(storeSheetsOpenProvider.notifier).state++;
      hold.complete();
      await verdict(tester, c);
      await tester.pumpAndSettle();
      expect(path(c), Routes.home);
      // A purchase leaves the paywall before its sheet's count comes down
      // ("navigate before you mutate"): that `go` must not land here either.
      c.read(routerProvider).go(Routes.home);
      await tester.pumpAndSettle();
      expect(path(c), Routes.home);

      c.read(storeSheetsOpenProvider.notifier).state--;
      await tester.pumpAndSettle();
      expect(path(c), Routes.updateRequired);
    });

    testWidgets('a visit to its route with nothing forced goes back to the '
        'splash', (tester) async {
      final c = await boot(tester, store: _appStore(version: _installed));
      c.read(routerProvider).go(Routes.updateRequired);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(path(c), isNot(Routes.updateRequired));
      expect(forcedTitle(), findsNothing);
    });
  });

  group('fails open', () {
    testWidgets('the flag is on but nothing newer is in the store', (
      tester,
    ) async {
      await boot(
        tester,
        store: _appStore(version: _installed),
        flags: const RemoteFlags(forceUpdate: true),
      );
      expect(forcedTitle(), findsNothing);
      expect(sheetTitle(), findsNothing);
      expect(find.text(l10n.homeLogPuff), findsOneWidget);
    });

    testWidgets('Remote Config cannot be fetched: never forced, still offered',
        (tester) async {
      await boot(
        tester,
        store: _appStore(),
        // Its last fetch said force; this one failed.
        flags: const RemoteFlags(forceUpdate: true),
        flagsFail: true,
      );
      expect(forcedTitle(), findsNothing);
      expect(sheetTitle(), findsOneWidget);
      expect(find.text(l10n.commonNotNow), findsOneWidget);
    });

    testWidgets('the store answers with an error page: nothing at all', (
      tester,
    ) async {
      final c = await boot(
        tester,
        store: _brokenStore(),
        flags: const RemoteFlags(forceUpdate: true),
      );
      expect(c.read(updateCheckProvider).kind, UpdateKind.none);
      expect(forcedTitle(), findsNothing);
      expect(sheetTitle(), findsNothing);
      expect(find.text(l10n.homeLogPuff), findsOneWidget);
    });

    testWidgets('the store never answers: Home is not held, and the check '
        'gives up', (tester) async {
      final c = await boot(
        tester,
        store: _silentStore(),
        flags: const RemoteFlags(forceUpdate: true),
        waitForVerdict: false,
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.homeLogPuff), findsOneWidget);
      expect(c.read(updateCheckProvider).settled, isFalse);

      await tester.pump(UpdateCheckStore.storeTimeout);
      await verdict(tester, c);
      await tester.pumpAndSettle();
      expect(c.read(updateCheckProvider).kind, UpdateKind.none);
      expect(forcedTitle(), findsNothing);
    });
  });
}
