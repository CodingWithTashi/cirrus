import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';
import 'package:last_puff/features/moderation/moderation_screen.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// The founder's review queue (App Store Guideline 1.2, docs/03 §9).
///
/// `moderationQueue` and `resolveModeration` were deployed and tested with no
/// client at all, so a flagged post could be written but never seen. The two
/// behaviours worth pinning here are the ones that would silently break the
/// 24-hour review commitment: a failed load must not look like an empty
/// queue, and a refused decision must not look like an applied one.
void main() {
  const flagged = ModerationItem(
    flagId: 'p1',
    postId: 'p1',
    action: 'flag',
    reason: 'possible self-harm',
    kind: 'post',
    text: 'I do not think I can do this any more',
    status: 'pending',
    alias: 'SteadyFalcon42',
  );

  late _StubModeration repo;

  setUp(() => repo = _StubModeration());

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        moderationRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LpTheme.midnight(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ModerationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('a flagged post reaches the founder with its reason', (
    tester,
  ) async {
    repo.items = [flagged];
    await pump(tester);

    expect(find.text(flagged.text!), findsOneWidget);
    expect(find.textContaining(flagged.reason), findsOneWidget);
  });

  testWidgets('a failed load says so instead of showing an empty queue', (
    tester,
  ) async {
    repo.failure = const NoConnectionException();
    await pump(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.moderationFailed), findsOneWidget);
    // "Nothing to review" and "we could not look" are the same picture and
    // very different facts — the empty copy must not appear here.
    expect(find.text(l10n.moderationEmpty), findsNothing);
  });

  testWidgets('blocking a post removes the row once the server accepts', (
    tester,
  ) async {
    repo.items = [flagged];
    final c = await pump(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.moderationBlock));
    await tester.pumpAndSettle();
    // PressScale's release bounce leaves a timer behind when its row is
    // removed mid-animation; drain it so the binding's timer check passes.
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.resolved, [('p1', ModerationResolution.block)]);
    expect(c.read(moderationStoreProvider).items, isEmpty);
    expect(find.text(flagged.text!), findsNothing);
  });

  testWidgets('a refused decision leaves the row in the queue', (tester) async {
    repo.items = [flagged];
    final c = await pump(tester);
    repo.failure = const NoConnectionException();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.moderationBlock));
    await tester.pumpAndSettle();

    // The post is still live server-side, so it must still be in front of the
    // founder. Dropping it here is how a report gets silently lost.
    expect(c.read(moderationStoreProvider).items, hasLength(1));
    expect(find.text(flagged.text!), findsOneWidget);
    expect(find.text(l10n.moderationResolveFailed), findsOneWidget);
    // Let the snack (and its force-close fallback timer) run out.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('a flag whose post is gone still shows, and is resolvable', (
    tester,
  ) async {
    repo.items = const [
      // A reply flag: its own id, with the parent post as a field. Resolving
      // this used to write to `moderation/p2` — the parent's document — so the
      // reply's flag was never marked reviewed and came back tomorrow.
      ModerationItem(
        flagId: 'r9',
        postId: 'p2',
        replyId: 'r9',
        action: 'block',
        reason: 'harassment',
        kind: 'reply',
      ),
    ];
    final c = await pump(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.moderationSubjectGone), findsOneWidget);

    await tester.tap(find.text(l10n.moderationDismiss));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    // The FLAG's id, not the parent post's. Resolving by postId wrote to
    // `moderation/p2` — a different document — so this reply's flag stayed
    // unreviewed and returned to the queue every day, while p2's status was
    // flipped in its place.
    expect(repo.resolved, [('r9', null)]);
    expect(c.read(moderationStoreProvider).items, isEmpty);
  });
}

class _StubModeration implements ModerationRepository {
  List<ModerationItem> items = const [];
  final resolved = <(String, ModerationResolution?)>[];
  Object? failure;

  @override
  Future<bool> isModerator() async => true;

  @override
  Future<List<ModerationItem>> queue({bool includeReviewed = false}) async {
    if (failure != null) throw failure!;
    return items;
  }

  @override
  Future<void> resolve(String postId, {ModerationResolution? action}) async {
    if (failure != null) throw failure!;
    resolved.add((postId, action));
  }
}
