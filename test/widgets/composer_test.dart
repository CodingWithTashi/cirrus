import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/allowances.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// The composer after the Sep 1 field test (docs/09 issue 6).
///
/// Three things it got wrong on a phone: the keyboard stayed up over the tag
/// row, a rule-breaking post was refused only after it had been sent, and on
/// an account's first post the screen stayed put with the post already made.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  /// `flutter test` substitutes a square-glyph fallback font; overflow here
  /// says nothing about the device (see `screen_layout_test`).
  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  /// The app on the Community tab with the composer pushed over it, the way
  /// the feed's FAB does it — so `pop` has somewhere to go.
  Future<ProviderContainer> openComposer(WidgetTester tester) async {
    ignoreFontWidthOverflow();
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
    final router = container.read(routerProvider);
    router.go(Routes.community);
    await tester.pumpAndSettle();
    unawaited(router.push(Routes.compose));
    await tester.pumpAndSettle();
    expect(find.text(l10n.communityComposerTitle), findsOneWidget);
    return container;
  }

  testWidgets('picking a tag puts the keyboard away', (tester) async {
    await openComposer(tester);

    final field = find.byType(TextField);
    await tester.tap(field);
    await tester.pump();
    final editable = find.byType(EditableText);
    expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);

    await tester.tap(find.text(l10n.communityTagVent));
    await tester.pumpAndSettle();

    expect(
      tester.widget<EditableText>(editable).focusNode.hasFocus,
      isFalse,
      reason: 'choosing a tag should release the keyboard',
    );
  });

  testWidgets('posting leaves the composer — even the first post, which earns '
      'a badge', (tester) async {
    final container = await openComposer(tester);
    // The seeded journey has never posted, so this post awards `firstPost`.
    // That mutates the journey and rebuilds the router right after the tap,
    // which used to undo the pop and leave the composer on screen with the
    // post already created (docs/09 issue 6c).
    expect(
      container.read(quitStoreProvider)!.earnedBadges,
      isNot(contains('firstPost')),
    );

    await tester.enterText(find.byType(TextField), 'day one, terrified');
    await tester.pump();
    await tester.tap(find.text(l10n.communityTagVent));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.communityComposerPost));
    await tester.pumpAndSettle();

    expect(find.text(l10n.communityComposerTitle), findsNothing);
    expect(
      container.read(routerProvider).state.uri.path,
      isNot(Routes.compose),
    );
    expect(
      container
          .read(communityStoreProvider)
          .posts
          .any((p) => p.text == 'day one, terrified'),
      isTrue,
    );
    expect(
      container.read(quitStoreProvider)!.earnedBadges,
      contains('firstPost'),
    );
    // Let the "Posted." snack and its fallback timer run out (showLpSnack
    // force-closes at duration + 250ms), or the harness reports it pending.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a slur is refused under the text, and nothing is sent', (
    tester,
  ) async {
    final container = await openComposer(tester);
    await tester.enterText(
      find.byType(TextField),
      'quit? not with these faggots cheering',
    );
    await tester.pump();
    await tester.tap(find.text(l10n.communityTagVent));
    await tester.pumpAndSettle();

    expect(find.text(l10n.communityRuleSlur), findsOneWidget);
    await tester.tap(find.text(l10n.communityComposerPost));
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.communityComposerTitle),
      findsOneWidget,
      reason: 'Post is off while the text breaks a rule',
    );
    expect(
      container
          .read(communityStoreProvider)
          .posts
          .any((p) => (p.text ?? '').contains('faggots')),
      isFalse,
    );

    // Fix the words and the line goes away.
    await tester.enterText(
      find.byType(TextField),
      'quit? yes, with all of you cheering',
    );
    await tester.pump();
    expect(find.text(l10n.communityRuleSlur), findsNothing);
  });

  testWidgets('where-to-buy talk is refused; naming the brand you quit is not', (
    tester,
  ) async {
    await openComposer(tester);
    await tester.enterText(
      find.byType(TextField),
      'anyone know where to buy 50mg pods',
    );
    await tester.pump();
    expect(find.text(l10n.communityRuleSourcing), findsOneWidget);

    // Tone is the model's call; the composer must not refuse the most
    // ordinary sentence in a quit community.
    await tester.enterText(
      find.byType(TextField),
      'threw my juul in the bin. day 1.',
    );
    await tester.pump();
    expect(find.text(l10n.communityRuleSourcing), findsNothing);
  });

  testWidgets('a subscriber past their posts is refused before typing', (
    tester,
  ) async {
    // `openComposer` runs the paying demo persona, so the allowance is three.
    final container = await openComposer(tester);
    final store = container.read(communityStoreProvider.notifier);
    for (var i = 0; i < LpAllowances.premiumPosts; i++) {
      store.addPost(text: 'venting post number $i', tag: PostTag.vent);
    }
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.communityDailyCapReached(LpAllowances.premiumPosts)),
      findsOneWidget,
    );
    // Nothing to sell someone who already subscribed.
    expect(find.text(l10n.premiumLockCta), findsNothing);
  });

  testWidgets('a spent ordinary allowance still leaves the SOS open', (
    tester,
  ) async {
    // The rule this protects: using your ordinary posts must never grey out
    // the one control somebody in trouble needs. The server keeps a separate
    // counter for exactly this, and the composer has to agree with it.
    final container = await openComposer(tester);
    final store = container.read(communityStoreProvider.notifier);
    for (var i = 0; i < LpAllowances.premiumPosts; i++) {
      store.addPost(text: 'venting post number $i', tag: PostTag.vent);
    }
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.communityDailyCapReached(LpAllowances.premiumPosts)),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.communityTagSos));
    await tester.pumpAndSettle();

    // The blocker is gone the moment the tag says SOS.
    expect(
      find.text(l10n.communityDailyCapReached(LpAllowances.premiumPosts)),
      findsNothing,
    );
    await tester.enterText(find.byType(TextField), 'please talk to me');
    await tester.pumpAndSettle();
    final before = container.read(communityStoreProvider).posts.length;
    await tester.tap(find.text(l10n.communityComposerPost));
    await tester.pumpAndSettle();
    expect(container.read(communityStoreProvider).posts.length, before + 1);
    // Let the "Posted." snack and its fallback timer run out (showLpSnack
    // force-closes at duration + 250ms), or the harness reports it pending.
    await tester.pump(const Duration(seconds: 5));
  });
}
