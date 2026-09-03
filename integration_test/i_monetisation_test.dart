import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/widgets/lp_premium_gate.dart';
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
}
