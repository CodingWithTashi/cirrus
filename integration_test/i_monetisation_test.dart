import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/widgets/lp_premium_gate.dart';
import 'package:last_puff/core/utils/lp_pricing.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/allowances.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/panic/panic_screens.dart';

import 'harness.dart';

/// The free/premium surfaces (docs/12), on a real tree.
///
/// The widget suite pins each of these on its own. What only a device can show
/// is the combination: the gates sit inside a `StatefulShellRoute` that keeps
/// every tab alive, the paywall is a pushed route whose `dispose` now fires an
/// event, and the panic flow animates forever — three things that have each
/// already broken a green widget test in this repo.
///
/// The rule under test throughout: **a free account is never stuck.** Every
/// door opens onto a real paywall and closes back onto the screen it came
/// from, and the panic flow never reaches one at all.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Signs in as the demo persona and then makes the account **free**.
  ///
  /// The seeded day-12 journey has always been a subscriber's — `signIn`
  /// mints the demo entitlement with it — so the free tier, which is what all
  /// of this is about, has to be asked for. The row goes on the fake server
  /// and the store is re-bound, which is exactly the path a real expiry takes.
  Future<E2E> freeAccount(WidgetTester tester) async {
    final e2e = await E2E.boot(tester);
    await e2e.waitFor(const Duration(seconds: 2));
    await e2e.tapText(e2e.l10n.authContinueWithEmail);
    await e2e.tapSpan(e2e.l10n.authLogIn);
    await e2e.enterField(e2e.l10n.authEmailLabel, 'maya@quitmail.com');
    await e2e.enterField(e2e.l10n.authPasswordLabel, 'secret1');
    await e2e.tapText(e2e.l10n.authLogIn);
    await e2e.waitFor(const Duration(seconds: 3));
    expect(
      e2e.container.read(quitStoreProvider),
      isNotNull,
      reason: 'sign-in failed; on screen: ${e2e.texts()}',
    );

    final fake = e2e.container.read(fakeServerProvider)
      ..putEntitlement({
        'tier': 'free',
        'productId': 'yearly_3999',
        'expiresAt': DateTime.now()
            .subtract(const Duration(days: 1))
            .toUtc()
            .toIso8601String(),
      });
    await e2e.container
        .read(entitlementProvider.notifier)
        .bindSession(fake.ensureSessionId());
    await e2e.settle();
    expect(
      e2e.container.read(isPremiumProvider),
      isFalse,
      reason: 'the account should read as free after the row expired',
    );
    return e2e;
  }

  /// The paywall is open, through the door named [source].
  void expectPaywallFrom(E2E e2e, String source) {
    final uri = e2e.container.read(routerProvider).state.uri;
    expect(
      uri.path,
      Routes.paywall,
      reason: 'expected the paywall; on screen: ${e2e.texts()}',
    );
    expect(uri.queryParameters['source'], source);
  }

  testWidgets('Home offers the free account a door where it used to offer '
      'nothing, and closes back onto Home', (tester) async {
    final e2e = await freeAccount(tester);
    // Home picks ONE card from a priority chain and the mood prompt outranks
    // the nudge after 6pm, so a device run at 7pm would otherwise pass or
    // fail on the clock. Checking a mood in puts the chain on the branch this
    // test is about — the same fixture trick the widget suite uses.
    e2e.container.read(quitStoreProvider.notifier).checkInMood(Mood.okay);
    await e2e.settle();

    final window = e2e.container.read(todayProvider)!.dangerWindow;
    expect(
      window,
      isNotNull,
      reason: 'no danger hour in the fixture, so there is no nudge to gate',
    );
    expect(
      find.byType(LpPremiumGate).evaluate(),
      isNotEmpty,
      reason: 'no gate on Home; on screen: ${e2e.texts()}',
    );

    await e2e.tapText(e2e.l10n.premiumLockCta);
    await e2e.waitFor(const Duration(seconds: 1));
    expectPaywallFrom(e2e, 'nudge');

    // And back. A door that does not close is a trap, and the paywall is a
    // pushed route whose dispose now does work.
    e2e.container.read(routerProvider).pop();
    await e2e.settle();
    expect(e2e.container.read(routerProvider).state.uri.path, Routes.home);
  });

  testWidgets('Stats tells a free account its real window and sells the month',
      (tester) async {
    final e2e = await freeAccount(tester);
    await e2e.tapText(e2e.l10n.navStats);
    await e2e.settle();

    expect(
      e2e.visible(
        e2e.l10n.premiumFreeHistoryNote(LpAllowances.freeHistoryDays),
      ),
      isTrue,
      reason: 'no history note; on screen: ${e2e.texts()}',
    );

    await e2e.tapText(e2e.l10n.statsRangeMonth);
    await e2e.waitFor(const Duration(seconds: 1));
    expectPaywallFrom(e2e, 'history');
  });

  testWidgets('the community gives a free account its post, then the door', (
    tester,
  ) async {
    final e2e = await freeAccount(tester);
    await e2e.tapText(e2e.l10n.navCommunity);
    await e2e.waitFor(const Duration(seconds: 3));

    // docs/12 §4.1: posting is an allowance now, not a wall. The first one
    // goes through — the thing that used to be impossible for a free account.
    final store = e2e.container.read(communityStoreProvider.notifier);
    final before = e2e.container.read(communityStoreProvider).posts.length;
    store.addPost(text: 'day 12 and still here', tag: PostTag.win);
    await e2e.waitFor(const Duration(seconds: 2));
    final posts = e2e.container.read(communityStoreProvider).posts;
    expect(posts.length, before + 1);
    expect(
      posts.first.status,
      PostStatus.live,
      reason: 'the free post was refused; status ${posts.first.status}',
    );

    // The second meets the allowance, in the composer, before the send.
    unawaited(e2e.container.read(routerProvider).push(Routes.compose));
    await e2e.waitFor(const Duration(seconds: 2));
    expect(
      e2e.showing(e2e.l10n.premiumPitchCompose(LpAllowances.premiumPosts)),
      isTrue,
      reason: 'no allowance blocker; on screen: ${e2e.texts()}',
    );

    await e2e.tapText(e2e.l10n.premiumLockCta);
    await e2e.waitFor(const Duration(seconds: 1));
    expectPaywallFrom(e2e, 'compose');
  });

  testWidgets('an SOS is still open with the ordinary allowance spent', (
    tester,
  ) async {
    // The rule that matters most in this file: nobody is told they are out of
    // posts while asking for help. The server keeps a separate counter for
    // exactly this, and the composer has to agree with it on a real tree.
    final e2e = await freeAccount(tester);
    await e2e.tapText(e2e.l10n.navCommunity);
    await e2e.waitFor(const Duration(seconds: 3));
    e2e.container
        .read(communityStoreProvider.notifier)
        .addPost(text: 'the one I get', tag: PostTag.win);
    await e2e.waitFor(const Duration(seconds: 2));

    unawaited(e2e.container.read(routerProvider).push(Routes.compose));
    await e2e.waitFor(const Duration(seconds: 2));
    expect(
      e2e.showing(e2e.l10n.premiumPitchCompose(LpAllowances.premiumPosts)),
      isTrue,
    );

    await e2e.tapText(e2e.l10n.communityTagSos);
    await e2e.settle();
    expect(
      e2e.showing(e2e.l10n.premiumPitchCompose(LpAllowances.premiumPosts)),
      isFalse,
      reason: 'choosing SOS must clear the blocker; on screen: ${e2e.texts()}',
    );
  });

  testWidgets('the panic flow never reaches a paywall', (tester) async {
    // The door that used to sit here put a purchase decision in front of
    // somebody at 9/10 craving intensity. On a device because the panic flow
    // animates forever and disposes a route-scoped notifier on the way out —
    // the exact combination that has broken this screen before.
    final e2e = await freeAccount(tester);
    unawaited(e2e.container.read(routerProvider).push(Routes.panic));
    await e2e.waitFor(const Duration(seconds: 2));

    // Straight to the option list. `previewStep` builds a fresh session, so
    // the intensity goes on after it, not before.
    e2e.container.read(panicProvider.notifier)
      ..previewStep(3)
      ..setIntensity(9);
    await e2e.settle();

    expect(
      e2e.showing(e2e.l10n.panicLoopCoach),
      isTrue,
      reason: 'no AI option on the loop screen; on screen: ${e2e.texts()}',
    );
    await e2e.tapText(e2e.l10n.panicLoopCoach);
    await e2e.waitFor(const Duration(seconds: 2));

    final uri = e2e.container.read(routerProvider).state.uri;
    expect(
      uri.path,
      isNot(Routes.paywall),
      reason: 'the AI option opened a paywall mid-craving',
    );
    expect(uri.path, Routes.coach);
    // The craving rides along, so Ember answers in its PANIC MODE voice.
    expect(uri.queryParameters['panic'], '9');
  });

  testWidgets('the arena opens playable for a free account, and the lock is '
      'something they have to go and tap', (tester) async {
    // The rule the whole design turns on: a free account must never LAND on a
    // lock mid-craving. On a device because the arena owns a Ticker, a frame
    // clock and an AnimatedSwitcher — the lock card takes the field's slot in
    // it, and nothing in a widget test disposes a real one.
    final e2e = await freeAccount(tester);
    unawaited(e2e.container.read(routerProvider).push(Routes.game));
    await e2e.waitFor(const Duration(seconds: 2));

    expect(
      e2e.showing(e2e.l10n.gameNameOrbs),
      isTrue,
      reason: 'no game switcher; on screen: ${e2e.texts()}',
    );
    // Orbs is the only field a free account should be looking at, and it is
    // playing — no lock, no offer, no round it cannot finish.
    expect(
      e2e.showing(e2e.l10n.gameLockedTitle(e2e.l10n.gameNameTiles)),
      isFalse,
      reason: 'a free account LANDED on a lock; on screen: ${e2e.texts()}',
    );

    // The lock is met only by asking for it.
    await e2e.tapText(e2e.l10n.gameNameTiles);
    await e2e.waitFor(const Duration(seconds: 1));
    expect(
      e2e.showing(e2e.l10n.gameLockedTitle(e2e.l10n.gameNameTiles)),
      isTrue,
      reason: 'no lock card after tapping Tiles; on screen: ${e2e.texts()}',
    );

    // …and "Play Orbs" leads, because somebody mid-craving came for a board.
    await e2e.tapText(e2e.l10n.gameLockedPlayFree(e2e.l10n.gameNameOrbs));
    await e2e.waitFor(const Duration(seconds: 1));
    expect(
      e2e.showing(e2e.l10n.gameLockedTitle(e2e.l10n.gameNameTiles)),
      isFalse,
      reason: 'the card did not clear; on screen: ${e2e.texts()}',
    );

    // The door exists, is tagged, and closes back onto the arena.
    await e2e.tapText(e2e.l10n.gameNameBlocks);
    await e2e.waitFor(const Duration(seconds: 1));
    await e2e.tapText(e2e.l10n.premiumLockCta);
    await e2e.waitFor(const Duration(seconds: 2));
    expectPaywallFrom(e2e, 'panic_game');

    e2e.container.read(routerProvider).pop();
    await e2e.waitFor(const Duration(seconds: 1));
    expect(e2e.container.read(routerProvider).state.uri.path, Routes.game);
  });

  testWidgets('a subscriber plays all three', (tester) async {
    // The other side of the same gate, and the reason `resolveFor` reads the
    // tier rather than hiding the pills: a payer sees no padlock anywhere.
    final e2e = await E2E.boot(tester);
    await e2e.waitFor(const Duration(seconds: 2));
    await e2e.tapText(e2e.l10n.authContinueWithEmail);
    await e2e.tapSpan(e2e.l10n.authLogIn);
    await e2e.enterField(e2e.l10n.authEmailLabel, 'maya@quitmail.com');
    await e2e.enterField(e2e.l10n.authPasswordLabel, 'secret1');
    await e2e.tapText(e2e.l10n.authLogIn);
    await e2e.waitFor(const Duration(seconds: 3));
    expect(e2e.container.read(isPremiumProvider), isTrue);

    unawaited(e2e.container.read(routerProvider).push(Routes.game));
    await e2e.waitFor(const Duration(seconds: 2));
    await e2e.tapText(e2e.l10n.gameNameTiles);
    await e2e.waitFor(const Duration(seconds: 1));
    expect(
      e2e.showing(e2e.l10n.gameLockedTitle(e2e.l10n.gameNameTiles)),
      isFalse,
      reason: 'a subscriber met a lock; on screen: ${e2e.texts()}',
    );
  });

  testWidgets('the SOS composer refuses a one-tap non-post, with a real '
      'keyboard', (tester) async {
    // `"a"` used to publish from here — and because a live SOS pins to the top
    // of the feed for an hour, it pinned. On a device because this is the one
    // harness with a real IME: the composer autofocuses, the keyboard eats the
    // viewport, and the blocker has to stay visible under the text box.
    final e2e = await freeAccount(tester);
    unawaited(
      e2e.container
          .read(routerProvider)
          .push('${Routes.compose}?tag=${PostTag.sos.name}'),
    );
    await e2e.waitFor(const Duration(seconds: 2));

    await tester.enterText(find.byType(TextField), 'a');
    await e2e.settle();
    expect(
      e2e.showing(e2e.l10n.communityTooShort),
      isTrue,
      reason: 'a one-character SOS was postable; on screen: ${e2e.texts()}',
    );

    await tester.enterText(find.byType(TextField), 'help help help help');
    await e2e.settle();
    expect(
      e2e.showing(e2e.l10n.communityTooRepetitive),
      isTrue,
      reason: 'one word repeated was postable; on screen: ${e2e.texts()}',
    );

    // And the bar stays low enough for somebody with shaking hands.
    await tester.enterText(find.byType(TextField), 'help me please');
    await e2e.settle();
    expect(
      e2e.showing(e2e.l10n.communityTooShort) ||
          e2e.showing(e2e.l10n.communityTooRepetitive),
      isFalse,
      reason: 'a real cry for help was refused; on screen: ${e2e.texts()}',
    );

    final before = e2e.container.read(communityStoreProvider).posts.length;
    await e2e.tapText(e2e.l10n.communityComposerPost);
    await e2e.waitFor(const Duration(seconds: 2));
    expect(
      e2e.container.read(communityStoreProvider).posts.length,
      before + 1,
      reason: 'the valid SOS did not post',
    );

    // One live SOS at a time: the second is refused while the first is pinned.
    unawaited(
      e2e.container
          .read(routerProvider)
          .push('${Routes.compose}?tag=${PostTag.sos.name}'),
    );
    await e2e.waitFor(const Duration(seconds: 2));
    expect(
      e2e.showing(e2e.l10n.communitySosStillUp),
      isTrue,
      reason: 'a second SOS was offered; on screen: ${e2e.texts()}',
    );
  });

  testWidgets('a reply too thin to publish never leaves the composer', (
    tester,
  ) async {
    // The one that shipped broken. `createReply` gained a quality floor
    // server-side with no client counterpart, and `addReply` does
    // `.ignore()` on the failure — so "ok" on somebody's SOS went into the
    // author's own thread, awarded them the helpedSos badge, was rejected by
    // the callable, and was seen by nobody. A silent drop is the worst shape
    // a refusal can take, and only a real tree shows the thread.
    final e2e = await freeAccount(tester);
    await e2e.tapText(e2e.l10n.navCommunity);
    await e2e.waitFor(const Duration(seconds: 3));

    // Somebody else's post, so replying is a normal reply.
    final target = e2e.container
        .read(communityStoreProvider)
        .posts
        .firstWhere((p) => !p.isMine);
    unawaited(
      e2e.container.read(routerProvider).push('/community/post/${target.id}'),
    );
    await e2e.waitFor(const Duration(seconds: 2));

    final field = find.byType(TextField);
    expect(field, findsWidgets, reason: 'no reply box; on: ${e2e.texts()}');

    int repliesNow() => e2e.container
        .read(communityStoreProvider)
        .posts
        .firstWhere((p) => p.id == target.id)
        .replies
        .length;
    final before = repliesNow();

    // Refused, and refused BEFORE it is shown as sent — the whole point.
    await tester.enterText(field.last, 'ok');
    await e2e.settle();
    await e2e.tap(
      find.byIcon(Icons.arrow_upward_rounded).last,
      why: 'send a two-letter reply',
    );
    await e2e.waitFor(const Duration(seconds: 2));
    expect(
      repliesNow(),
      before,
      reason: '"ok" was accepted locally and would be dropped by the server',
    );

    // …and the bar stays low enough that a nod still counts.
    await tester.enterText(field.last, 'thanks');
    await e2e.settle();
    await e2e.tap(find.byIcon(Icons.arrow_upward_rounded).last, why: 'send');
    await e2e.waitFor(const Duration(seconds: 2));
    expect(
      repliesNow(),
      before + 1,
      reason: '"thanks" is a real reply and must post',
    );
  });

  testWidgets('the Free screen shows both columns and Pro is the button', (
    tester,
  ) async {
    // Ten rows plus two headings do not fit a 360x640 viewport, and the screen
    // used to be a fixed Column with a Spacer. Only a device renders it at the
    // real size with the real text scale.
    final e2e = await freeAccount(tester);
    unawaited(e2e.container.read(routerProvider).push(Routes.paywall));
    await e2e.waitFor(const Duration(seconds: 2));
    await e2e.tapText(e2e.l10n.paywallFreeLink);
    await e2e.waitFor(const Duration(seconds: 2));

    expect(
      e2e.showing(e2e.l10n.freePlanColPro),
      isTrue,
      reason: 'no Pro column; on screen: ${e2e.texts()}',
    );
    // The numbers are the ones the app enforces, not typed copy.
    expect(
      e2e.showing(
        e2e.l10n.freeComparePerDay(LpAllowances.premiumCoachMessages),
      ),
      isTrue,
      reason: "Pro's coach allowance is missing; on screen: ${e2e.texts()}",
    );
    expect(
      e2e.showing(e2e.l10n.freeCompareDays(LpAllowances.freeHistoryDays)),
      isTrue,
    );
    // Free is demoted but never hidden (Apple 3.1.2).
    expect(e2e.showing(e2e.l10n.freePlanCta), isTrue);

    // Pro pops back onto the paywall underneath rather than stacking a second.
    await e2e.tapText(e2e.l10n.freePlanProCta(LpPricing.trialDays));
    await e2e.waitFor(const Duration(seconds: 2));
    expect(
      e2e.container.read(routerProvider).state.uri.path,
      Routes.paywall,
      reason: 'Try Pro did not land on the paywall; on: ${e2e.texts()}',
    );
    expect(e2e.showing(e2e.l10n.freePlanColPro), isFalse);
  });
}
