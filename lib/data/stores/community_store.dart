import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import 'providers.dart';

class CommunityState {
  const CommunityState({
    required this.posts,
    this.blocked = const {},
    this.muted = const {},
    this.nudgesToday = 0,
  });

  final List<Post> posts;
  final Set<String> blocked;

  /// Muted authors: their posts hide for you, without mutual invisibility.
  final Set<String> muted;

  /// Buddy nudges sent today — capped at 2/day (Run 3 frame 46).
  final int nudgesToday;

  /// Feed order: live SOS posts pinned first, then reverse-chron (docs/03 §9).
  List<Post> visible(DateTime now) {
    final list =
        posts
            .where(
              (p) =>
                  !p.hidden &&
                  !blocked.contains(p.alias) &&
                  !muted.contains(p.alias),
            )
            .toList()
          ..sort((a, b) {
            final aSos =
                a.tag == PostTag.sos &&
                now.difference(a.createdAt).inMinutes < 60;
            final bSos =
                b.tag == PostTag.sos &&
                now.difference(b.createdAt).inMinutes < 60;
            if (aSos != bSos) return aSos ? -1 : 1;
            return b.createdAt.compareTo(a.createdAt);
          });
    return list;
  }

  CommunityState copyWith({
    List<Post>? posts,
    Set<String>? blocked,
    Set<String>? muted,
    int? nudgesToday,
  }) => CommunityState(
    posts: posts ?? this.posts,
    blocked: blocked ?? this.blocked,
    muted: muted ?? this.muted,
    nudgesToday: nudgesToday ?? this.nudgesToday,
  );
}

/// View model of the community feed: fetched async from the backend, mutated
/// optimistically with write-behind sync (the feed never blocks on the wire).
class CommunityStore extends Notifier<CommunityState> {
  int _reportCounts = 0;

  @override
  CommunityState build() {
    // Riverpod 2.x Notifiers have no `ref.mounted`; guard the async load
    // against provider invalidation (sign-out) mid-fetch.
    var alive = true;
    ref.onDispose(() => alive = false);
    unawaited(_load(() => alive));
    return const CommunityState(posts: []);
  }

  CommunityRepository get _repo => ref.read(communityRepositoryProvider);

  Future<void> _load(bool Function() alive) async {
    final posts = await _repo.fetchPosts();
    if (alive()) state = state.copyWith(posts: posts);
  }

  List<Post> get posts => state.posts;

  String get _myAlias =>
      ref.read(quitStoreProvider)?.profile.alias ?? '@quietfox';

  String get _myAvatar =>
      ref.read(quitStoreProvider)?.profile.avatarEmoji ?? '🦊';

  int get _myDay {
    final j = ref.read(quitStoreProvider);
    return j == null ? 1 : j.plan.dayNumber(DateTime.now()).clamp(1, 9999);
  }

  /// Client-side guard mirroring the moderation policy (docs/03 §9): brand
  /// praise and sourcing get held. The real Gemini pass is server-side later.
  static bool violatesCommunityRules(String text) {
    final t = text.toLowerCase();
    const banned = [
      'elfbar',
      'elf bar',
      'geekbar',
      'geek bar',
      'juul',
      'vuse',
      'lostmary',
      'lost mary',
      'where to buy',
      'for sale',
      'plug for',
      'best flavor to buy',
    ];
    return banned.any(t.contains);
  }

  void addPost({required String text, required PostTag tag}) {
    final post = Post(
      id: 'p${DateTime.now().microsecondsSinceEpoch}',
      alias: _myAlias,
      avatarEmoji: _myAvatar,
      dayN: _myDay,
      tag: tag,
      text: text,
      createdAt: DateTime.now(),
      isMine: true,
      replyingNow: tag == PostTag.sos ? 3 : 0,
      hidden: violatesCommunityRules(text),
    );
    state = state.copyWith(posts: [post, ...state.posts]);
    unawaited(_repo.addPost(post));
    ref.read(quitStoreProvider.notifier).awardBadge('firstPost');
  }

  void toggleReaction(String postId, String emoji) {
    final post = state.posts.where((p) => p.id == postId).firstOrNull;
    if (post == null) return;
    final on = !post.myReactions.contains(emoji);
    state = state.copyWith(
      posts: [
        for (final p in state.posts)
          if (p.id != postId)
            p
          else if (on)
            p.copyWith(
              reactions: {...p.reactions, emoji: (p.reactions[emoji] ?? 0) + 1},
              myReactions: {...p.myReactions, emoji},
            )
          else
            p.copyWith(
              reactions: {...p.reactions, emoji: (p.reactions[emoji] ?? 1) - 1},
              myReactions: {...p.myReactions}..remove(emoji),
            ),
      ],
    );
    unawaited(_repo.setReaction(postId, emoji, on: on));
  }

  void addReply(String postId, String text) {
    final reply = Reply(
      alias: _myAlias,
      avatarEmoji: _myAvatar,
      text: text,
      isMine: true,
    );
    state = state.copyWith(
      posts: [
        for (final p in state.posts)
          if (p.id != postId) p else p.copyWith(replies: [...p.replies, reply]),
      ],
    );
    unawaited(_repo.addReply(postId, reply));
    final post = state.posts.firstWhere((p) => p.id == postId);
    if (post.tag == PostTag.sos && !post.isMine) {
      ref.read(quitStoreProvider.notifier).awardBadge('helpedSos');
    }
  }

  void reportPost(String postId) {
    // 3 reports auto-hide pending review (App Store UGC requirement).
    _reportCounts++;
    if (_reportCounts % 3 == 0) {
      state = state.copyWith(
        posts: [
          for (final p in state.posts)
            if (p.id == postId) p.copyWith(hidden: true) else p,
        ],
      );
    }
    unawaited(_repo.reportPost(postId));
  }

  void blockAuthor(String postId) {
    final post = state.posts.firstWhere((p) => p.id == postId);
    state = state.copyWith(blocked: {...state.blocked, post.alias});
    unawaited(_repo.blockAuthor(post.alias));
  }

  void muteAuthor(String postId) {
    final post = state.posts.firstWhere((p) => p.id == postId);
    state = state.copyWith(muted: {...state.muted, post.alias});
  }

  static const int nudgeDailyCap = 2;

  int get nudgesLeftToday =>
      (nudgeDailyCap - state.nudgesToday).clamp(0, nudgeDailyCap);

  void nudgeBuddy() {
    if (nudgesLeftToday == 0) return;
    state = state.copyWith(nudgesToday: state.nudgesToday + 1);
    unawaited(_repo.nudgeBuddy());
    ref.read(quitStoreProvider.notifier).awardBadge('buddyBond');
  }
}
