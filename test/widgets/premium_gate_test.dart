import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/utils/lp_format.dart';
import 'package:last_puff/core/widgets/lp_premium_gate.dart';
import 'package:last_puff/data/api/fake/fake_server.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/allowances.dart';
import 'package:last_puff/domain/logic/launch_paywall_policy.dart';
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
    RecordingAnalytics? analytics,
    List<Override> overrides = const [],
  }) async {
    ignoreFontWidthOverflow();
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(premium: premium, analytics: analytics),
        ...overrides,
      ],
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
      expect(find.text(l10n.premiumPitchHealth(l10n.healthM48h)), findsOneWidget);
    });
  });

  group('what the funnel can see', () {
    testWidgets('a gate reports one impression per mount, then its tap', (
      tester,
    ) async {
      // Before this, `paywall_viewed` fired only on a tap, so a door nobody
      // opened was indistinguishable from a door nobody was ever shown — and
      // those have opposite fixes (bad copy vs bad placement). The impression
      // is the denominator that tells them apart.
      final analytics = RecordingAnalytics();
      final container = await open(
        tester,
        Routes.insight,
        analytics: analytics,
      );

      expect(
        analytics
            .propsOfAll('gate_shown')
            .where((p) => p['source'] == 'insight')
            .length,
        1,
        reason: 'one mount is one impression, however many rebuilds follow',
      );
      // Counted by source, not in total: the shell keeps Home alive behind
      // this route, so whichever door Home is showing today is also in the
      // tree. Counting every `gate_shown` would make this assertion depend on
      // the seeded fixture's danger hours and on the wall clock.
      expect(analytics.names, isNot(contains('gate_tapped')));

      await reveal(tester, find.text(l10n.premiumLockCta));
      await tester.tap(find.text(l10n.premiumLockCta));
      await tester.pumpAndSettle();

      // The pair the conversion of this door is computed from, both carrying
      // the same source as the paywall they opened.
      //
      // `lastWhere`, not `propsOf`: a free account has already been shown the
      // once-a-day launch paywall on the splash, so the first `paywall_viewed`
      // of the session is `launch` and has nothing to do with this gate.
      expect(analytics.propsOf('gate_tapped'), {'source': 'insight'});
      expect(
        analytics.events.lastWhere((e) => e.name == 'paywall_viewed').props['source'],
        'insight',
      );
      expectPaywallFrom(container, 'insight');
    });

    testWidgets('a paying account is never counted as having seen a gate', (
      tester,
    ) async {
      final analytics = RecordingAnalytics();
      await open(
        tester,
        Routes.insight,
        premium: true,
        analytics: analytics,
      );
      expect(analytics.names, isNot(contains('gate_shown')));
    });
  });

  group('per surface', () {
    testWidgets('Health: the first day is open, the year behind it is gated', (
      tester,
    ) async {
      final container = await open(tester, Routes.health);
      expect(find.text(l10n.premiumPitchHealth(l10n.healthM48h)), findsOneWidget);
      await reveal(tester, find.text(l10n.premiumLockCta));
      await tester.tap(find.text(l10n.premiumLockCta));
      await tester.pumpAndSettle();
      expectPaywallFrom(container, 'health');
    });

    testWidgets('Health: premium sees the whole timeline, no gate', (
      tester,
    ) async {
      await open(tester, Routes.health, premium: true);
      expect(find.text(l10n.premiumPitchHealth(l10n.healthM48h)), findsNothing);
    });

    testWidgets('Stats: free is told its window, and Month is the door', (
      tester,
    ) async {
      final container = await open(tester, Routes.stats);
      expect(
        find.text(l10n.premiumFreeHistoryNote(LpAllowances.freeHistoryDays)),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.statsRangeMonth));
      await tester.pumpAndSettle();
      expectPaywallFrom(container, 'history');
    });

    testWidgets('Stats: premium switches to Month in place', (tester) async {
      final container = await open(tester, Routes.stats, premium: true);
      expect(
        find.text(l10n.premiumFreeHistoryNote(LpAllowances.freeHistoryDays)),
        findsNothing,
      );
      await tester.tap(find.text(l10n.statsRangeMonth));
      await tester.pumpAndSettle();
      expect(container.read(routerProvider).state.uri.path, Routes.stats);
    });

    testWidgets('Stats: the free window really is a week of days', (
      tester,
    ) async {
      // The note is copy; this is the clamp, and the clamp has to bite or the
      // note is a lie. It was 30 for a few hours on Sep 3 2026 — long enough
      // to hold the whole taper program — and was cut back to 7 the same day
      // (docs/12 §5c): Stats is where the product's central question gets
      // answered, and a free tier that answers it in full has nothing left to
      // sell.
      //
      // Asserted against the constant rather than a literal, so the screen
      // and the allowance can never disagree about what "your last N days"
      // means.
      final container = await open(tester, Routes.stats);
      final journey = container.read(quitStoreProvider)!;
      final now = container.read(todayProvider)!.now;
      final floor = LpDate.addDays(
        LpDate.dayStart(now),
        -(LpAllowances.freeHistoryDays - 1),
      );
      // The day-12 fixture is longer than the window, which is the whole
      // reason there is something behind the Month pill.
      expect(
        journey.days.values.where((d) => d.date.isBefore(floor)),
        isNotEmpty,
        reason: 'a window that drops nothing is not a window',
      );
      expect(
        journey.days.values.where((d) => !d.date.isBefore(floor)).length,
        lessThanOrEqualTo(LpAllowances.freeHistoryDays),
      );
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

    /// Home on the nudge branch of its card chain.
    ///
    /// Home picks ONE card — slip, then mood prompt, then the nudge — and
    /// `showMoodPrompt` is `mood == null && now.hour >= 18` against the real
    /// wall clock. The seeded day-12 fixture logs no mood for today, so from
    /// 6pm local the mood prompt wins and the nudge never renders: this used
    /// to fail every evening and pass every morning. Checking a mood in first
    /// puts the chain on the branch these tests are actually about.
    Future<ProviderContainer> openNudge(
      WidgetTester tester, {
      required bool premium,
    }) async {
      final container = await open(tester, Routes.home, premium: premium);
      container.read(quitStoreProvider.notifier).checkInMood(Mood.okay);
      await tester.pumpAndSettle();
      // The premise. Without a real danger window there is no nudge of either
      // kind, and every assertion below would pass by rendering nothing.
      expect(
        container.read(todayProvider)!.dangerWindow,
        isNotNull,
        reason: 'the seeded fixture must have a danger hour to nudge about',
      );
      return container;
    }

    testWidgets('Home: premium gets the nudge itself', (tester) async {
      await openNudge(tester, premium: true);
      expect(find.byType(LpPremiumGate), findsNothing);
      expect(find.byType(Dismissible), findsOneWidget);
    });

    testWidgets('Home: free gets a door where it used to get nothing', (
      tester,
    ) async {
      // The nudge IS the craving forecast, so it stays Premium — but a free
      // account used to render an empty slot on the app's most-visited
      // screen, at the one moment we can name their own risky hour back to
      // them. That was the best contextual door in the app going unused.
      final container = await openNudge(tester, premium: false);

      expect(find.byType(LpPremiumGate), findsOneWidget);
      // Still dismissible: docs/02 §5's "never interstitial spam" means a
      // door the user can wave off.
      expect(find.byType(Dismissible), findsOneWidget);

      await tester.tap(find.text(l10n.premiumLockCta));
      await tester.pumpAndSettle();
      expectPaywallFrom(container, 'nudge');
    });

    testWidgets('Home: the free nudge pitch names their own hour and never '
        'the reminder', (tester) async {
      final container = await openNudge(tester, premium: false);
      final hour = LpFormat.hour(
        container.read(todayProvider)!.dangerWindow!.$1,
        'en',
      );

      // Their number, from their own logs — the honest half is on screen, not
      // blurred behind the lock.
      expect(find.text(l10n.premiumPitchNudge(hour)), findsOneWidget);
      // And the pitch must not sell the danger-hour reminder: `ReminderPlanner`
      // has no tier check, so free accounts already get those. Selling a
      // reader something they already have is the one thing this door cannot
      // do and still be honest.
      final pitch = l10n.premiumPitchNudge(hour).toLowerCase();
      for (final claim in ['remind', 'notif', 'text you', 'push']) {
        expect(pitch, isNot(contains(claim)), reason: claim);
      }
    });

    testWidgets('Home: the door is reported like every other gate', (
      tester,
    ) async {
      final analytics = RecordingAnalytics();
      final container = await open(
        tester,
        Routes.home,
        analytics: analytics,
      );
      container.read(quitStoreProvider.notifier).checkInMood(Mood.okay);
      await tester.pumpAndSettle();

      expect(
        analytics.propsOfAll('gate_shown').where((p) => p['source'] == 'nudge'),
        hasLength(1),
      );
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

    // A function, not a `final`: group bodies run at collection time, before
    // `setUpAll` has initialized `l10n`.
    String composePitch() =>
        l10n.premiumPitchCompose(LpAllowances.premiumPosts);

    testWidgets('free: the first post of the day goes through, no door', (
      tester,
    ) async {
      // docs/12 §4.1. Posting used to be refused outright for a free account,
      // which left the feature we call our moat read-only for exactly the
      // people a subscriber pays to read — while replying stayed free, so the
      // line was arbitrary as well as costly.
      final container = await openComposer(tester);
      await tester.enterText(find.byType(TextField), 'day 12, still here');
      await tester.tap(find.text(l10n.communityTagWin));
      await tester.pumpAndSettle();

      expect(find.text(composePitch()), findsNothing);
      final before = container.read(communityStoreProvider).posts.length;
      await tester.tap(find.text(l10n.communityComposerPost));
      await tester.pumpAndSettle();
      expect(container.read(communityStoreProvider).posts.length, before + 1);
      expect(
        container.read(communityStoreProvider).posts.first.status,
        PostStatus.live,
      );
      // Drain the "Posted." snack and its fallback timer (showLpSnack
      // force-closes at duration + 250ms), or the harness reports it pending.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('free: the SECOND post is where the door appears', (
      tester,
    ) async {
      final container = await openComposer(tester);
      container.read(communityStoreProvider.notifier).addPost(
        text: 'the one I get',
        tag: PostTag.win,
      );
      await tester.pumpAndSettle();

      // On open, before a word is typed: they learn it now rather than after
      // writing a post that cannot be sent.
      expect(find.text(composePitch()), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'one more thought');
      await tester.tap(find.text(l10n.communityTagWin));
      await tester.pumpAndSettle();
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

    testWidgets('free: an SOS is never paywalled, even out of posts', (
      tester,
    ) async {
      final container = await openComposer(tester);
      container.read(communityStoreProvider.notifier).addPost(
        text: 'the one I get',
        tag: PostTag.win,
      );
      await tester.pumpAndSettle();
      expect(find.text(composePitch()), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'need a hand right now');
      await tester.tap(find.text(l10n.communityTagSos));
      await tester.pumpAndSettle();

      // Picking SOS clears it: that allowance is a different one, and nobody
      // is told they are out of posts while asking for help.
      expect(find.text(composePitch()), findsNothing);
      expect(find.text(l10n.premiumLockCta), findsNothing);
      final before = container.read(communityStoreProvider).posts.length;
      await tester.tap(find.text(l10n.communityComposerPost));
      await tester.pumpAndSettle();
      expect(container.read(communityStoreProvider).posts.length, before + 1);
      // Drain the "Posted." snack and its fallback timer (showLpSnack
      // force-closes at duration + 250ms), or the harness reports it pending.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('premium: three posts, then a cap with nothing to sell', (
      tester,
    ) async {
      final container = await openComposer(tester, premium: true);
      final store = container.read(communityStoreProvider.notifier);
      for (var i = 0; i < LpAllowances.premiumPosts; i++) {
        store.addPost(text: 'winning post number $i', tag: PostTag.win);
      }
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.communityDailyCapReached(LpAllowances.premiumPosts)),
        findsOneWidget,
      );
      // A subscriber has already bought the only thing that would help.
      expect(find.text(composePitch()), findsNothing);
      expect(find.text(l10n.premiumLockCta), findsNothing);
    });

    testWidgets('the backend refuses what a skipped gate sends', (
      tester,
    ) async {
      // A client that bypasses the composer's check meets the same allowance
      // on the server (`createPost` → permission-denied once the free post is
      // spent); the fake enforces it too, and the store files the post as not
      // published.
      final container = await open(tester, Routes.community);
      final store = container.read(communityStoreProvider.notifier);
      final before = container.read(communityStoreProvider).posts.length;
      store.addPost(text: 'the one I get', tag: PostTag.win);
      await tester.pumpAndSettle();
      expect(
        container.read(communityStoreProvider).posts.first.status,
        PostStatus.live,
      );

      store.addPost(text: 'sneaking a second one in', tag: PostTag.win);
      await tester.pumpAndSettle();
      final posts = container.read(communityStoreProvider).posts;
      expect(posts.length, before + 2);
      expect(posts.first.status, PostStatus.blocked);

      // And an SOS still lands, from its own untouched allowance.
      store.addPost(text: 'someone please help', tag: PostTag.sos);
      await tester.pumpAndSettle();
      expect(
        container.read(communityStoreProvider).posts.first.status,
        PostStatus.live,
      );
    });
  });

  group('the launch paywall', () {
    // The seeded fixture is a day-12 journey and 12 is not a milestone day,
    // so the clock seam moves the account onto one. Two days on is day 14.
    //
    // `LpDate.addDays`, never `add(Duration(days: 2))`: the second is 48
    // ABSOLUTE hours, and across a DST change it lands on the neighbouring
    // date — day 13, not a milestone, and this suite would go red twice a
    // year. That is the exact arithmetic that used to zero the Freedom Streak.
    final milestone = LpDate.addDays(DateTime.now(), 2);
    final today = LpDate.dayKey(milestone);

    /// Cold start from the splash with a signed-in account whose journey the
    /// backend restores — the real first frame of a returning user's day.
    Future<ProviderContainer> launch(
      WidgetTester tester, {
      required Map<String, dynamic>? entitlement,
      String? shownDay,
      DateTime? now,
    }) async {
      ignoreFontWidthOverflow();
      final container = ProviderContainer(
        overrides: fastBackendOverrides(premium: false, now: now ?? milestone),
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

    testWidgets('a known-free user sees it on a milestone day, over Home, '
        'and it is remembered', (tester) async {
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

    testWidgets('nothing on an ordinary day', (tester) async {
      // This is the change. It used to fire on EVERY launch-day of a free
      // account's life — the interstitial docs/02 §5 forbids in its own words.
      final container = await launch(
        tester,
        entitlement: null,
        now: LpDate.addDays(DateTime.now(), 3), // plan day 15
      );
      expect(container.read(routerProvider).state.uri.path, Routes.home);
      expect(
        container.read(settingsStoreProvider).launchPaywallShownDay,
        isNull,
      );
    });

    testWidgets('four times and never again', (tester) async {
      final container = await launch(
        tester,
        entitlement: null,
        shownDay: '1999-01-01',
        now: LpDate.addDays(DateTime.now(), 2),
      );
      // A plan restart brings the milestone days round again; the lifetime
      // counter is what stops a fifth.
      container.read(settingsStoreProvider.notifier)
        ..markLaunchPaywallShown('1999-01-01')
        ..markLaunchPaywallShown('1999-01-02')
        ..markLaunchPaywallShown('1999-01-03')
        ..markLaunchPaywallShown('1999-01-04');
      expect(
        container.read(settingsStoreProvider).launchPaywallShownCount,
        greaterThanOrEqualTo(LaunchPaywallPolicy.lifetimeCap),
      );
      expect(
        LaunchPaywallPolicy.shouldShow(
          hasJourney: true,
          planDay: 3,
          settled: true,
          isPremium: false,
          lastShownDay: null,
          today: today,
          shownCount:
              container.read(settingsStoreProvider).launchPaywallShownCount,
        ),
        isFalse,
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
