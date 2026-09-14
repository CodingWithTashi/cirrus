import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/core/widgets/press_scale.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/community_rules.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/community/community_screens.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// Reactions on your own post (docs/10 §40).
///
/// The card drew the whole palette under every post, the author's own
/// included: a brand-new post showed its writer "💪 0 🔥 0 💬 0", and a tap
/// counted — publicly — as a reaction to themselves. The author now sees
/// nothing until somebody else reacts, and then only the counts, with nothing
/// to press.
void main() {
  Post post({required bool mine, Map<String, int> reactions = const {}}) =>
      Post(
        id: mine ? 'mine-1' : 'theirs-1',
        alias: mine ? '@matrixfox' : '@wildowl78',
        avatarEmoji: '🦊',
        dayN: 3,
        tag: PostTag.win,
        createdAt: DateTime(2026, 9, 13, 9),
        text: 'Three days in and the evenings are finally quieter.',
        reactions: reactions,
        isMine: mine,
      );

  Future<void> pumpCard(WidgetTester tester, Post p) async {
    final c = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: LpTheme.midnight(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView(children: [PostCard(post: p)]),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Tap targets between a piece of text and the screen: the card itself is
  /// one (it opens the thread), a reaction you can press is a second.
  Finder pressables(String text) =>
      find.ancestor(of: find.text(text), matching: find.byType(PressScale));

  testWidgets('your own post with no reactions has no reaction row', (
    tester,
  ) async {
    await pumpCard(tester, post(mine: true));
    for (final emoji in CommunityReactions.palette) {
      expect(find.textContaining(emoji), findsNothing, reason: emoji);
    }
  });

  testWidgets('once others react, the author sees only the counts', (
    tester,
  ) async {
    await pumpCard(
      tester,
      post(mine: true, reactions: const {'💪': 2, '🔥': 0, '💬': 1}),
    );
    expect(find.text('💪 2'), findsOneWidget);
    expect(find.text('💬 1'), findsOneWidget);
    expect(
      find.textContaining('🔥'),
      findsNothing,
      reason: 'a count of zero is not a reaction',
    );
    expect(
      pressables('💪 2'),
      findsOneWidget,
      reason: 'only the card itself — the count is not a button',
    );
  });

  testWidgets('your own SOS never offers you "I got you"', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpCard(
      tester,
      Post(
        id: 'sos-mine',
        alias: '@matrixfox',
        avatarEmoji: '🦊',
        dayN: 3,
        tag: PostTag.sos,
        createdAt: DateTime(2026, 9, 13, 9),
        text: 'Craving hard at the gas station right now',
        isMine: true,
        replyCount: 2,
      ),
    );
    expect(find.text(l10n.communityIGotYou), findsNothing);
    expect(find.text(l10n.communityRepliedCount(2)), findsOneWidget);
  });

  testWidgets('an SOS from someone else still says "I got you"', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpCard(
      tester,
      Post(
        id: 'sos-theirs',
        alias: '@wildowl78',
        avatarEmoji: '🦉',
        dayN: 3,
        tag: PostTag.sos,
        createdAt: DateTime(2026, 9, 13, 9),
        text: 'Craving hard at the gas station right now',
        replyCount: 0,
      ),
    );
    expect(find.text(l10n.communityIGotYou), findsOneWidget);
  });

  testWidgets("someone else's post still offers every reaction", (
    tester,
  ) async {
    await pumpCard(tester, post(mine: false));
    for (final emoji in CommunityReactions.palette) {
      expect(find.text('$emoji 0'), findsOneWidget);
      expect(pressables('$emoji 0'), findsNWidgets(2));
    }
  });

  test('the store refuses a reaction to your own post', () async {
    final c = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(c.dispose);
    c.read(fakeServerProvider).signIn('author@test');
    c.read(quitStoreProvider.notifier).seedDemoJourney();
    final store = c.read(communityStoreProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    store.addPost(
      text: 'Day one done. Cravings were loud but I held on.',
      tag: PostTag.win,
    );
    final mine = c
        .read(communityStoreProvider)
        .posts
        .firstWhere((p) => p.isMine);

    store.toggleReaction(mine.id, '🔥');

    final after = c
        .read(communityStoreProvider)
        .posts
        .firstWhere((p) => p.id == mine.id);
    expect(after.reactions, isEmpty);
    expect(after.myReactions, isEmpty);
  });
}
