import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/features/panic/panic_screens.dart';
import 'package:last_puff/domain/models/models.dart';

import 'harness.dart';

/// Community and Coach — the two tabs that talk to other people and to a
/// model, and the two most likely to fail quietly.
///
/// The community is the stated moat and a Guideline 1.2 surface, so the paths
/// that matter here are the moderation-adjacent ones: a post that reaches the
/// feed, a report that is accepted once, and a blocked author who genuinely
/// disappears rather than merely being scrolled past.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<E2E> signedIn(WidgetTester tester, {bool online = true}) async {
    final e2e = await E2E.boot(tester, online: online);
    await e2e.waitFor(const Duration(seconds: 2));
    await e2e.tapText(e2e.l10n.authContinueWithEmail);
    await e2e.tapSpan(e2e.l10n.authLogIn);
    await e2e.enterField(e2e.l10n.authEmailLabel, 'maya@quitmail.com');
    await e2e.enterField(e2e.l10n.authPasswordLabel, 'secret1');
    await e2e.tapText(e2e.l10n.authLogIn);
    await e2e.waitFor(const Duration(seconds: 3));
    expect(e2e.container.read(quitStoreProvider), isNotNull,
        reason: 'sign-in failed; on screen: ${e2e.texts()}');
    return e2e;
  }

  Future<void> openCommunity(E2E e2e) async {
    await e2e.tapText(e2e.l10n.navCommunity);
    await e2e.waitFor(const Duration(seconds: 3));
  }

  testWidgets('the feed loads and SOS posts pin above the rest', (
    tester,
  ) async {
    final e2e = await signedIn(tester);
    await openCommunity(e2e);

    final state = e2e.container.read(communityStoreProvider);
    expect(state.status.name, 'ready',
        reason: 'feed never loaded; on screen: ${e2e.texts()}');
    expect(state.posts, isNotEmpty);

    // docs/03 §9: a live SOS is pinned for its first hour. Whatever the
    // fixture holds, the visible order must satisfy that rule.
    final now = DateTime.now();
    final visible = state.visible(now);
    final firstNonSos = visible.indexWhere(
      (p) => !(p.tag == PostTag.sos && now.difference(p.createdAt).inMinutes < 60),
    );
    if (firstNonSos > 0) {
      final tail = visible.skip(firstNonSos);
      expect(
        tail.any(
          (p) => p.tag == PostTag.sos && now.difference(p.createdAt).inMinutes < 60,
        ),
        isFalse,
        reason: 'a live SOS sorted below a non-SOS post',
      );
    }
  });

  testWidgets('a composed post reaches the feed under my own alias', (
    tester,
  ) async {
    final e2e = await signedIn(tester);
    await openCommunity(e2e);
    final alias = e2e.container.read(quitStoreProvider)!.profile.alias;
    final before = e2e.container.read(communityStoreProvider).posts.length;

    // The composer is a FAB with an icon, not a label.
    await e2e.tap(find.byIcon(Icons.edit_rounded), why: 'composer FAB');
    await e2e.waitFor(const Duration(seconds: 1));

    const body = 'e2e: day twelve and the 9pm wave just broke on its own';
    await tester.enterText(find.byType(TextField).first, body);
    await e2e.settle();

    // A tag is mandatory — the composer refuses to post without one.
    await e2e.tapText(e2e.l10n.communityTagWin);
    await e2e.tapText(e2e.l10n.communityComposerPost);
    await e2e.waitFor(const Duration(seconds: 3));

    final after = e2e.container.read(communityStoreProvider).posts;
    expect(after.length, before + 1, reason: 'on screen: ${e2e.texts()}');
    expect(after.first.text, body);
    expect(after.first.alias, alias);
  });

  testWidgets('three reports hide the post that was reported three times', (
    tester,
  ) async {
    final e2e = await signedIn(tester);
    await openCommunity(e2e);
    final store = e2e.container.read(communityStoreProvider.notifier);
    final target = e2e.container.read(communityStoreProvider).posts.first;

    store.reportPost(target.id);
    store.reportPost(target.id);
    store.reportPost(target.id);
    await e2e.settle();

    // Three reports auto-hide pending review (the UGC requirement).
    final after = e2e.container
        .read(communityStoreProvider)
        .posts
        .firstWhere((p) => p.id == target.id);
    expect(after.hidden, isTrue, reason: 'on screen: ${e2e.texts()}');
  });

  testWidgets('reporting three DIFFERENT posts hides none of them', (
    tester,
  ) async {
    final e2e = await signedIn(tester);
    await openCommunity(e2e);
    final store = e2e.container.read(communityStoreProvider.notifier);
    final posts = e2e.container.read(communityStoreProvider).posts;
    expect(posts.length, greaterThanOrEqualTo(3));

    // One report each on three separate posts. Each has a single report, so
    // the auto-hide threshold has not been met by ANY of them.
    store.reportPost(posts[0].id);
    store.reportPost(posts[1].id);
    store.reportPost(posts[2].id);
    await e2e.settle();

    final after = e2e.container.read(communityStoreProvider).posts;
    for (final p in posts.take(3)) {
      expect(
        after.firstWhere((q) => q.id == p.id).hidden,
        isFalse,
        reason: 'post ${p.id} was hidden on one report — the auto-hide '
            'counter is not per-post',
      );
    }
  });

  testWidgets('a blocked author disappears from the feed entirely', (
    tester,
  ) async {
    final e2e = await signedIn(tester);
    await openCommunity(e2e);
    final store = e2e.container.read(communityStoreProvider.notifier);
    final mine = e2e.container.read(quitStoreProvider)!.profile.alias;
    final victim = e2e.container
        .read(communityStoreProvider)
        .posts
        .firstWhere((p) => p.alias != mine);

    // Takes the POST id, not the alias — it resolves the author itself.
    store.blockAuthor(victim.id);
    await e2e.settle();

    final visible = e2e.container
        .read(communityStoreProvider)
        .visible(DateTime.now());
    expect(
      visible.any((p) => p.alias == victim.alias),
      isFalse,
      reason: 'a blocked author was still readable — a Guideline 1.2 failure',
    );
  });

  testWidgets('a failed feed shows the retry state, never an empty feed', (
    tester,
  ) async {
    // Sign in first: a session has to exist before the feed can fail to load,
    // and signing in offline fails at the earlier step instead.
    final e2e = await signedIn(tester);
    await e2e.setOnline(false);
    e2e.container.invalidate(communityStoreProvider);
    await openCommunity(e2e);

    expect(e2e.container.read(communityStoreProvider).status.name, 'failed',
        reason: 'on screen: ${e2e.texts()}');
    // "Nothing here yet" and "we could not load" are the same picture and
    // very different facts.
    expect(e2e.visible(e2e.l10n.communityEmptyTitle), isFalse);
  });

  testWidgets('the panic flow reaches real people, pre-tagged SOS', (
    tester,
  ) async {
    // The social loop-breaker used to "ping your buddy" and ping nobody. It
    // now opens the composer pre-tagged SOS, which live-pins to the feed for
    // an hour — the same stage of the hook, actually implemented.
    final e2e = await signedIn(tester);
    await e2e.tapText(e2e.l10n.homeSos);
    await e2e.waitFor(const Duration(seconds: 2));
    e2e.container.read(panicProvider.notifier).previewStep(2);
    await e2e.settle();

    await e2e.tapText(e2e.l10n.panicLoopSos);
    await e2e.waitFor(const Duration(seconds: 2));

    // Landed in the composer with the tag already chosen, so reaching for
    // people mid-craving is one tap rather than a form.
    expect(e2e.showing(e2e.l10n.communityComposerTitle), isTrue,
        reason: 'on screen: ${e2e.texts()}');
    const body = 'e2e: sos from the panic flow';
    await tester.enterText(find.byType(TextField).first, body);
    await e2e.settle();
    await e2e.tapText(e2e.l10n.communityComposerPost);
    await e2e.waitFor(const Duration(seconds: 3));

    final posted = e2e.container.read(communityStoreProvider).posts.first;
    expect(posted.text, body);
    expect(posted.tag, PostTag.sos, reason: 'the SOS tag was not pre-selected');
  });

  testWidgets('Ember answers, and the answer renders as a message', (
    tester,
  ) async {
    final e2e = await signedIn(tester);
    await e2e.tapText(e2e.l10n.navCoach);
    await e2e.waitFor(const Duration(seconds: 3));

    final before = e2e.container.read(coachStoreProvider).messages.length;
    // A chip prefills the composer; sending is a separate, deliberate tap.
    await e2e.tapText(e2e.l10n.coachChipCraving);
    await e2e.tap(find.byIcon(Icons.arrow_upward_rounded), why: 'send');
    await e2e.waitFor(const Duration(seconds: 4));

    final messages = e2e.container.read(coachStoreProvider).messages;
    expect(messages.length, greaterThan(before + 1),
        reason: 'no reply arrived; on screen: ${e2e.texts()}');
    expect(messages.last.role, CoachRole.ember);
  });

  testWidgets('a lost connection is owned in-thread and refunds the message', (
    tester,
  ) async {
    final e2e = await signedIn(tester);
    await e2e.tapText(e2e.l10n.navCoach);
    await e2e.waitFor(const Duration(seconds: 3));

    final coach = e2e.container.read(coachStoreProvider.notifier);
    final leftBefore = coach.freeMessagesLeftToday;
    await e2e.setOnline(false);
    await e2e.tapText(e2e.l10n.coachChipRoughDay);
    await e2e.tap(find.byIcon(Icons.arrow_upward_rounded), why: 'send');
    await e2e.waitFor(const Duration(seconds: 5));

    // docs/04: the coach never raises a dialog — it says so in the thread, and
    // a message that never got an answer must not be charged for.
    expect(e2e.visible(e2e.l10n.errorOfflineTitle), isFalse,
        reason: 'the coach must not raise the offline dialog');
    expect(
      coach.freeMessagesLeftToday,
      leftBefore,
      reason: 'a failed message was still charged against the free allowance',
    );
  });
}
