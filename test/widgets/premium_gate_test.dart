import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/api/fake/fake_server.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

/// Every place Free meets Premium (docs/01 §10), and the one door out of each.
///
/// The contract under test: a free account sees the real surface — dimmed,
/// never mocked — with one lock card that names what Premium adds *here* and
/// opens the paywall tagged with that surface's `source`; a paying account
/// sees no gate anywhere; and the launch paywall shows a known-free user once
/// a day, never a paying one, never anyone whose tier is unknown.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Same rule as `screen_layout_test`: the fallback font overflows where the
  /// device does not.
  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  /// The app on [route] with the seeded day-12 journey, as a free account
  /// unless [premium] — `fastBackendOverrides` then seeds the demo
  /// subscription on both the fake server and the store.
  Future<ProviderContainer> open(
    WidgetTester tester,
    String route, {
    bool premium = false,
    List<Override> overrides = const [],
  }) async {
    ignoreFontWidthOverflow();
    final container = ProviderContainer(
      overrides: [...fastBackendOverrides(premium: premium), ...overrides],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    // The frame-map seed is a bare commit, not a session: bind the billing
    // identity the way `_onSessionEstablished` does after a real sign-in.
    unawaited(
      container
          .read(entitlementProvider.notifier)
          .bindSession(container.read(fakeServerProvider).ensureSessionId()),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(container.read(isPremiumProvider), premium);
    container.read(routerProvider).go(route);
    await tester.pumpAndSettle();
    return container;
  }

  /// Scrolls [finder] into the viewport through its own nearest Scrollable —
  /// `ensureVisible` alone leaves a card inside a Stack overlay a page below
  /// the fold of a ListView.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    final scrollables = find.ancestor(
      of: finder,
      matching: find.byType(Scrollable),
    );
    // A card that is not inside a scroll view (the Insight report area) is
    // on screen already.
    if (scrollables.evaluate().isEmpty) return;
    await tester.scrollUntilVisible(finder, 120, scrollable: scrollables.first);
    await tester.pumpAndSettle();
  }

  /// The paywall is open and knows which door it came through.
  void expectPaywallFrom(ProviderContainer container, String source) {
    final uri = container.read(routerProvider).state.uri;
    expect(uri.path, Routes.paywall);
    expect(uri.queryParameters['source'], source);
  }

  group('the lock card', () {
    testWidgets('names Premium, pitches this surface, and opens the paywall '
        'tagged with it', (tester) async {
      final container = await open(tester, Routes.insight);
      expect(find.text(l10n.premiumLockTitle), findsOneWidget);
      expect(find.text(l10n.premiumPitchInsight), findsOneWidget);

      await reveal(tester, find.text(l10n.premiumLockCta));
      await tester.tap(find.text(l10n.premiumLockCta));
      await tester.pumpAndSettle();
      expectPaywallFrom(container, 'insight');
    });

    testWidgets('is absent for a paying account', (tester) async {
      await open(tester, Routes.insight, premium: true);
      expect(find.text(l10n.premiumLockTitle), findsNothing);
      expect(find.text(l10n.premiumLockCta), findsNothing);
    });

    testWidgets('the gated surface underneath does not take taps', (
      tester,
    ) async {
      // A blurred button must not be a working button.
      await open(tester, Routes.health);
      expect(find.byType(AbsorbPointer), findsWidgets);
      expect(find.text(l10n.premiumPitchHealth), findsOneWidget);
    });
  });

  group('per surface', () {
    testWidgets('Health: the first week is open, the year behind it is gated', (
      tester,
    ) async {
      final container = await open(tester, Routes.health);
      expect(find.text(l10n.premiumPitchHealth), findsOneWidget);
      await reveal(tester, find.text(l10n.premiumLockCta));
      await tester.tap(find.text(l10n.premiumLockCta));
      await tester.pumpAndSettle();
      expectPaywallFrom(container, 'health');
    });

    testWidgets('Health: premium sees the whole timeline, no gate', (
      tester,
    ) async {
      await open(tester, Routes.health, premium: true);
      expect(find.text(l10n.premiumPitchHealth), findsNothing);
    });

    testWidgets('Stats: free is told it sees 7 days, and Month is the door', (
      tester,
    ) async {
      final container = await open(tester, Routes.stats);
      expect(find.text(l10n.premiumFreeHistoryNote), findsOneWidget);

      await tester.tap(find.text(l10n.statsRangeMonth));
      await tester.pumpAndSettle();
      expectPaywallFrom(container, 'history');
    });

    testWidgets('Stats: premium switches to Month in place', (tester) async {
      final container = await open(tester, Routes.stats, premium: true);
      expect(find.text(l10n.premiumFreeHistoryNote), findsNothing);
      await tester.tap(find.text(l10n.statsRangeMonth));
      await tester.pumpAndSettle();
      expect(container.read(routerProvider).state.uri.path, Routes.stats);
    });

    testWidgets('Plan: free sees the adaptive door where the advice would be', (
      tester,
    ) async {
      final container = await open(tester, Routes.plan);
      expect(find.text(l10n.premiumPitchPlan), findsOneWidget);
      await reveal(tester, find.text(l10n.premiumLockCta));
      await tester.tap(find.text(l10n.premiumLockCta));
      await tester.pumpAndSettle();
      expectPaywallFrom(container, 'plan');
    });

    testWidgets('Plan: premium sees no door', (tester) async {
      await open(tester, Routes.plan, premium: true);
      expect(find.text(l10n.premiumPitchPlan), findsNothing);
    });

    testWidgets('Home: the craving-forecast nudge is a Premium card', (
      tester,
    ) async {
      // The nudge IS the forecast. Counted rather than matched on copy: its
      // title and body are interpolated, and Home has other dismissibles.
      await open(tester, Routes.home, premium: true);
      final withPremium = find.byType(Dismissible).evaluate().length;
      await open(tester, Routes.home);
      final withFree = find.byType(Dismissible).evaluate().length;
      expect(withPremium - withFree, 1);
    });

    testWidgets('Coach: the cap message carries the door to Premium', (
      tester,
    ) async {
      final container = await open(
        tester,
        Routes.coach,
        overrides: [
          coachRepositoryProvider.overrideWithValue(
            const _CappedCoach(),
          ),
        ],
      );
      expect(find.text(l10n.premiumLockCta), findsNothing);

      await container.read(coachStoreProvider.notifier).send('one more');
      await tester.pumpAndSettle();
      expect(
        container.read(coachStoreProvider).messages.last.template,
        CoachTemplate.capReached,
      );
      expect(find.text(l10n.premiumLockCta), findsOneWidget);

      await reveal(tester, find.text(l10n.premiumLockCta));
      await tester.tap(find.text(l10n.premiumLockCta));
      await tester.pumpAndSettle();
      expectPaywallFrom(container, 'coach_cap');
    });
  });

  group('the composer', () {
    Future<ProviderContainer> openComposer(
      WidgetTester tester, {
      bool premium = false,
    }) async {
      final container = await open(tester, Routes.community, premium: premium);
      unawaited(container.read(routerProvider).push(Routes.compose));
      await tester.pumpAndSettle();
      expect(find.text(l10n.communityComposerTitle), findsOneWidget);
      return container;
    }

    testWidgets('free: a tagged post is Premium, and the door is beside it', (
      tester,
    ) async {
      final container = await openComposer(tester);
      await tester.enterText(find.byType(TextField), 'day 12, still here');
      await tester.tap(find.text(l10n.communityTagWin));
      await tester.pumpAndSettle();

      expect(find.text(l10n.premiumPitchCompose), findsOneWidget);
      // Sending does nothing while blocked: no post is added.
      final before = container.read(communityStoreProvider).posts.length;
      await tester.tap(find.text(l10n.communityComposerPost));
      await tester.pumpAndSettle();
      expect(container.read(communityStoreProvider).posts.length, before);
      expect(container.read(routerProvider).state.uri.path, Routes.compose);

      await reveal(tester, find.text(l10n.premiumLockCta));
      await tester.tap(find.text(l10n.premiumLockCta));
      await tester.pumpAndSettle();
      expectPaywallFrom(container, 'compose');
    });

    testWidgets('free: an SOS is never paywalled', (tester) async {
      await openComposer(tester);
      await tester.enterText(find.byType(TextField), 'need a hand right now');
      await tester.tap(find.text(l10n.communityTagSos));
      await tester.pumpAndSettle();
      expect(find.text(l10n.premiumPitchCompose), findsNothing);
      expect(find.text(l10n.premiumLockCta), findsNothing);
    });

    testWidgets('premium: no blocker on any tag', (tester) async {
      await openComposer(tester, premium: true);
      await tester.enterText(find.byType(TextField), 'day 12, still here');
      await tester.tap(find.text(l10n.communityTagWin));
      await tester.pumpAndSettle();
      expect(find.text(l10n.premiumPitchCompose), findsNothing);
    });

    testWidgets('the backend refuses what a skipped gate sends', (
      tester,
    ) async {
      // A client that bypasses the composer's check meets the same rule on
      // the server (`createPost` → permission-denied); the fake enforces it
      // too, and the store files the post as not published.
      final container = await open(tester, Routes.community);
      final store = container.read(communityStoreProvider.notifier);
      final before = container.read(communityStoreProvider).posts.length;
      store.addPost(text: 'sneaky', tag: PostTag.win);
      await tester.pumpAndSettle();
      final posts = container.read(communityStoreProvider).posts;
      expect(posts.length, before + 1);
      expect(posts.first.status, PostStatus.blocked);

      store.addPost(text: 'help', tag: PostTag.sos);
      await tester.pumpAndSettle();
      expect(
        container.read(communityStoreProvider).posts.first.status,
        PostStatus.live,
      );
    });
  });

  group('the launch paywall', () {
    /// Cold start from the splash with a signed-in account whose journey the
    /// backend restores — the real first frame of a returning user's day.
    Future<ProviderContainer> launch(
      WidgetTester tester, {
      required Map<String, dynamic>? entitlement,
      String? shownDay,
    }) async {
      ignoreFontWidthOverflow();
      final container = ProviderContainer(
        overrides: fastBackendOverrides(premium: false),
      );
      addTearDown(container.dispose);
      final fake = container.read(fakeServerProvider)..signIn('launch@test');
      if (entitlement == null) {
        // The row the demo sign-in seeds is premium; a free account is one
        // whose subscription has run out.
        fake.putEntitlement({
          'tier': 'free',
          'productId': 'yearly_3999',
          'expiresAt': DateTime.now()
              .subtract(const Duration(days: 1))
              .toUtc()
              .toIso8601String(),
        });
      } else {
        fake.putEntitlement(entitlement);
      }
      if (shownDay != null) {
        container
            .read(settingsStoreProvider.notifier)
            .markLaunchPaywallShown(shownDay);
      }
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LastPuffApp(),
        ),
      );
      // The splash's branding beat, then whatever the backend needed.
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
      return container;
    }

    final today = LpDate.dayKey(DateTime.now());

    testWidgets('a known-free user sees it once, over Home, and it is '
        'remembered for the day', (tester) async {
      final container = await launch(tester, entitlement: null);
      expectPaywallFrom(container, 'launch');
      expect(
        container.read(settingsStoreProvider).launchPaywallShownDay,
        today,
      );

      // Home is underneath: closing the paywall lands there, not on splash.
      container.read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(container.read(routerProvider).state.uri.path, Routes.home);
    });

    testWidgets('not twice in one day', (tester) async {
      final container = await launch(
        tester,
        entitlement: null,
        shownDay: today,
      );
      expect(container.read(routerProvider).state.uri.path, Routes.home);
    });

    testWidgets('never for a paying account', (tester) async {
      final container = await launch(
        tester,
        entitlement: FakeServer.demoEntitlementJson(DateTime.now()),
      );
      expect(container.read(isPremiumProvider), isTrue);
      expect(container.read(routerProvider).state.uri.path, Routes.home);
      expect(
        container.read(settingsStoreProvider).launchPaywallShownDay,
        isNull,
      );
    });

    testWidgets('never for a trial', (tester) async {
      final container = await launch(
        tester,
        entitlement: {
          'tier': 'trial',
          'productId': 'yearly_3999',
          'expiresAt': DateTime.now()
              .add(const Duration(days: 5))
              .toUtc()
              .toIso8601String(),
          'willRenew': true,
        },
      );
      expect(container.read(routerProvider).state.uri.path, Routes.home);
    });
  });
}

/// A coach whose next answer is the daily cap — the server's decision,
/// arriving as the template-only envelope it really sends.
class _CappedCoach implements CoachRepository {
  const _CappedCoach();

  @override
  Stream<CoachEvent> streamReply({
    String? text,
    CoachChip? chip,
    required bool capped,
    int? panicIntensity,
  }) async* {
    yield const CoachDone(CoachReply(template: CoachTemplate.capReached));
  }

  @override
  Future<List<CoachMessage>> history() async => const [];

  @override
  Future<List<CoachMemory>> memories() async => const [];

  @override
  Future<void> seedMemories() async {}

  @override
  Future<void> forgetMemory(String id) async {}
}
