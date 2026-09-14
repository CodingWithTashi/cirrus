import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/features/community/community_screens.dart';

import '../helpers.dart';

/// A reply you send is scrolled into view, the way the coach follows its chat.
///
/// Replies are oldest-first, so a new one is always the last thing in the
/// thread — and the list used to stay exactly where it was. The box cleared,
/// the reply went in below the fold, and nothing on screen said it had arrived
/// until the reader scrolled down to look (reproduced on a Pixel 8 in a test
/// thread, Sep 13 2026).
void main() {
  /// The fallback font overflows where the device does not — same rule as
  /// `screen_layout_test`.
  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  const sos = 'seed-sos';

  /// The seeded SOS thread, on a Pixel 8's 411 × 914 logical screen.
  Future<ProviderContainer> openThread(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    // The one-time notification ask opens a sheet over the thread after the
    // first reply. It has its own tests; here it would only stand in front of
    // the reply being measured.
    container.read(settingsStoreProvider.notifier).markPushPromptShown();
    container.read(routerProvider).go(Routes.communityPost(sos));
    await tester.pumpAndSettle();
    return container;
  }

  Finder inThread(Finder matching) => find.descendant(
    of: find.byType(PostDetailScreen),
    matching: matching,
    skipOffstage: false,
  );

  /// The thread's own list — not the reply box, which scrolls sideways.
  Finder thread() => find
      .descendant(
        of: inThread(find.byType(RefreshIndicator)),
        matching: find.byType(Scrollable),
      )
      .first;

  ScrollPosition position(WidgetTester tester) =>
      tester.state<ScrollableState>(thread()).position;

  /// Whether [text] sits wholly inside the thread's viewport. A reply the list
  /// has not even laid out yet is, by definition, not on screen.
  bool onScreen(WidgetTester tester, String text) {
    final reply = inThread(find.text(text, skipOffstage: false));
    if (reply.evaluate().isEmpty) return false;
    final rect = tester.getRect(reply);
    final viewport = tester.getRect(thread());
    return rect.top >= viewport.top && rect.bottom <= viewport.bottom;
  }

  Future<void> typeReply(WidgetTester tester, String text) async {
    await tester.enterText(inThread(find.byType(TextField)), text);
    await tester.pump();
  }

  Future<void> tapSend(WidgetTester tester) async {
    await tester.tap(inThread(find.byIcon(Icons.arrow_upward_rounded)));
    await tester.pumpAndSettle();
  }

  /// What the phone's keyboard does to the screen: the bottom 300dp are gone.
  Future<void> raiseKeyboard(WidgetTester tester) async {
    tester.view.viewInsets = FakeViewPadding(bottom: 300 * 2.625);
    await tester.pumpAndSettle();
  }

  testWidgets('every reply sent is on screen, however far the thread grows', (
    tester,
  ) async {
    ignoreFontWidthOverflow();
    await openThread(tester);

    for (var i = 1; i <= 6; i++) {
      final text = 'still here, reply number $i';
      await typeReply(tester, text);
      await tapSend(tester);
      expect(onScreen(tester, text), isTrue, reason: 'reply $i sent off screen');
    }
    // The thread really did outgrow the screen: this was not a short list
    // that happened to show everything.
    expect(position(tester).pixels, greaterThan(0));
  });

  testWidgets('with the keyboard up, the reply lands just above the box', (
    tester,
  ) async {
    ignoreFontWidthOverflow();
    await openThread(tester);
    await raiseKeyboard(tester);

    const text = 'the keyboard is up and this still shows';
    await typeReply(tester, text);
    await tapSend(tester);

    expect(onScreen(tester, text), isTrue);
  });

  testWidgets("the keyboard's own send key follows the reply as well", (
    tester,
  ) async {
    ignoreFontWidthOverflow();
    await openThread(tester);
    await raiseKeyboard(tester);

    const text = 'sent from the keyboard key, not the arrow';
    await typeReply(tester, text);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(onScreen(tester, text), isTrue);
  });

  testWidgets('a tail of long replies still ends on the reply, sent from the top', (
    tester,
  ) async {
    // The list lays replies out lazily and only ESTIMATES the height of the
    // ones below the fold. Long replies under a screenful of short ones make
    // that estimate come up short, and a single glide stops above the reply
    // it was going to.
    ignoreFontWidthOverflow();
    final container = await openThread(tester);
    final store = container.read(communityStoreProvider.notifier);
    for (var i = 1; i <= 12; i++) {
      unawaited(store.addReply(sos, 'short one $i'));
    }
    for (var i = 0; i < 6; i++) {
      unawaited(store.addReply(sos, _longReply));
    }
    await tester.pumpAndSettle();
    position(tester).jumpTo(0);
    await tester.pumpAndSettle();

    const text = 'this one has to end up on screen';
    await typeReply(tester, text);
    await tapSend(tester);

    expect(onScreen(tester, text), isTrue);
  });

  testWidgets('reporting a reply, or a reply this screen did not send, moves nothing', (
    tester,
  ) async {
    // Only a SEND moves the thread. Following every change to the store — the
    // coach's way — would drag a reader who flags a reply mid-thread, or
    // reacts to the post at the top, down to the last reply.
    ignoreFontWidthOverflow();
    final container = await openThread(tester);
    final store = container.read(communityStoreProvider.notifier);
    for (var i = 1; i <= 6; i++) {
      unawaited(store.addReply(sos, 'already in the thread $i'));
    }
    await tester.pumpAndSettle();
    position(tester).jumpTo(40);
    await tester.pumpAndSettle();

    store.reportReply(postId: sos, replyId: 'seed-sosReplyScience');
    await tester.pumpAndSettle();
    expect(position(tester).pixels, 40);

    // What a refresh does to the list: a reply lands that nobody sent from
    // this screen.
    unawaited(store.addReply(sos, 'somebody else got here first'));
    await tester.pumpAndSettle();
    expect(position(tester).pixels, 40);
  });
}

const _longReply =
    'Day nine and the evenings are still the hardest part of it. I have been '
    'walking the long way home so I do not pass the shop, and it helps more '
    'than I expected. Some nights the wave is small and some nights it is '
    'not, but it has passed every single time so far.';
