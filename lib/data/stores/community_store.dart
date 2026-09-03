import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/analytics/lp_events.dart';
import '../../domain/logic/community_rules.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import 'community_prefs.dart';
import 'providers.dart';

/// Lifecycle of the feed's initial fetch. Mutations after `ready` stay
/// optimistic and never regress the status.
enum FeedStatus { loading, ready, failed }

class CommunityState {
  const CommunityState({
    required this.posts,
    this.status = FeedStatus.loading,
    this.blocked = const {},
    this.muted = const {},
  });

  final List<Post> posts;
  final FeedStatus status;
  final Set<String> blocked;

  /// Muted authors: their posts hide for you, without mutual invisibility.
  final Set<String> muted;


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
    FeedStatus? status,
    Set<String>? blocked,
    Set<String>? muted,
  }) => CommunityState(
    posts: posts ?? this.posts,
    status: status ?? this.status,
    blocked: blocked ?? this.blocked,
    muted: muted ?? this.muted,
  );
}

/// View model of the community feed: fetched async from the backend, mutated
/// optimistically with write-behind sync (the feed never blocks on the wire).
class CommunityStore extends Notifier<CommunityState> {
  /// Reports this session, **per post**.
  ///
  /// Was a single counter across the whole feed, which meant reporting three
  /// DIFFERENT posts hid the third one: each had a single report, and the
  /// threshold is supposed to be three reports on the same post. Found by the
  /// on-device suite.
  final Map<String, int> _reportsByPost = {};

  /// Live moderation-state subscriptions for posts written this session.
  final Map<String, StreamSubscription<PostStatus>> _statusSubs = {};

  /// Posts the server refused at the door this session. They read as
  /// blocked, but `createPost` throws before it claims a cap slot, so the
  /// composer's cap check must not count them.
  final Set<String> _refusedAtDoor = {};

  bool Function() _alive = () => false;

  @override
  CommunityState build() {
    // Riverpod 2.x Notifiers have no `ref.mounted`; guard the async load
    // against provider invalidation (sign-out) mid-fetch.
    var alive = true;
    ref.onDispose(() {
      alive = false;
      for (final sub in _statusSubs.values) {
        unawaited(sub.cancel());
      }
      _statusSubs.clear();
    });
    _alive = () => alive;
    unawaited(_load());
    unawaited(_restorePrefs());
    return const CommunityState(posts: []);
  }

  CommunityRepository get _repo => ref.read(communityRepositoryProvider);

  /// Brings back who this reader has blocked and muted.
  ///
  /// Merged into whatever is already in state rather than assigned over it: a
  /// user who blocks somebody in the first second after launch must not have
  /// that undone by a restore landing a moment later.
  Future<void> _restorePrefs() async {
    final stored = await CommunityPrefs.restore();
    if (!_alive()) return;
    if (stored.blocked.isEmpty && stored.muted.isEmpty) return;
    state = state.copyWith(
      blocked: {...stored.blocked, ...state.blocked},
      muted: {...stored.muted, ...state.muted},
    );
  }

  Future<void> _load() async {
    try {
      final posts = await _repo.fetchPosts();
      if (_alive()) {
        state = state.copyWith(posts: posts, status: FeedStatus.ready);
        _watchUnsettled(posts);
      }
    } on Exception {
      // Offline or backend hiccup — the screen offers "run it back".
      if (_alive() && state.status == FeedStatus.loading) {
        state = state.copyWith(status: FeedStatus.failed);
      }
    }
  }

  /// Retry CTA on the feed's error state.
  Future<void> retryFeed() async {
    if (state.status == FeedStatus.loading) return;
    state = state.copyWith(status: FeedStatus.loading);
    await _load();
  }

  List<Post> get posts => state.posts;

  /// The router gates every community path behind a live journey, so these
  /// fallbacks are unreachable. They are neutral rather than the seeded demo
  /// identity ('@quietfox'/🦊) on purpose: if that gate ever slips, a post
  /// should be obviously unattributed, not silently signed with a fixture's
  /// name.
  String get _myAlias =>
      ref.read(quitStoreProvider)?.profile.alias ?? '@quitter';

  String get _myAvatar =>
      ref.read(quitStoreProvider)?.profile.avatarEmoji ?? '🔥';

  int get _myDay {
    final j = ref.read(quitStoreProvider);
    return j == null ? 1 : j.plan.dayNumber(DateTime.now()).clamp(1, 9999);
  }

  /// Client-side guard mirroring the moderation policy (docs/03 §9): slurs
  /// and sourcing are refused in the composer, before the send. The server
  /// runs the same prefilter at the door, and the model behind it.
  static bool violatesCommunityRules(String text) =>
      CommunityRules.violates(text);

  /// The caller's own posts dated today (local calendar day) in one allowance
  /// bucket, counting only those that claimed a server slot: not a failed
  /// send, not a cap refusal, and not a post the door refused —
  /// `createPost` throws before it claims.
  ///
  /// [sos] picks the bucket, because the server keeps two (docs/12 §4.1):
  /// spending your ordinary posts must never refuse a call for help, so a
  /// composer that counted them together would grey out the one control
  /// somebody in trouble needs. The allowance itself is [LpAllowances].
  int myPostsToday({required bool sos}) {
    final now = DateTime.now();
    return state.posts
        .where(
          (p) =>
              p.isMine &&
              (p.tag == PostTag.sos) == sos &&
              p.status != PostStatus.failed &&
              p.status != PostStatus.capped &&
              !_refusedAtDoor.contains(p.id) &&
              p.createdAt.year == now.year &&
              p.createdAt.month == now.month &&
              p.createdAt.day == now.day,
        )
        .length;
  }

  /// Optimistic: the post is in the author's feed at once, marked `pending`
  /// — every post is born pending on the backend and only the server flips
  /// it live. Once the backend acknowledges, the local copy is rebound to
  /// the server's id and its moderation state is followed, so a held post
  /// says "in review" instead of showing "Posted." and then vanishing on
  /// the next launch (QA M5).
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
      status: PostStatus.pending,
    );
    state = state.copyWith(posts: [post, ...state.posts]);
    unawaited(_syncPost(post));
    ref.read(quitStoreProvider.notifier).awardBadge('firstPost');
  }

  Future<void> _syncPost(Post local) async {
    final String? serverId;
    try {
      serverId = await _repo.addPost(local);
    } on ContentRefusedException catch (refusal) {
      // The server refused the content itself. Final either way, so no
      // retry is offered — but the three reasons read differently, and two of
      // them are allowances rather than content judgements.
      switch (refusal.reason) {
        case ContentRefusal.rules:
          // Not a limit: nothing about this post would be allowed at any tier,
          // so it belongs to moderation, not the funnel.
          _refusedAtDoor.add(local.id);
          _setStatus(local.id, PostStatus.blocked);
        case ContentRefusal.dailyCap:
          _reportLimit(LpLimit.communityCap);
          _setStatus(local.id, PostStatus.capped);
        case ContentRefusal.premium:
          // The composer gates this before the send; reaching here means a
          // client that skipped the gate, and "not published" is the honest
          // row for it.
          _reportLimit(LpLimit.communityPost);
          _refusedAtDoor.add(local.id);
          _setStatus(local.id, PostStatus.blocked);
      }
      return;
    } on Exception {
      // Offline or the app refused: it never reached anyone, and the row
      // says so with the retry on it — instead of "Posting…" for good,
      // which is what the Sep 1 field test saw as a stuck screen (docs/09
      // issue 6c).
      _setStatus(local.id, PostStatus.failed);
      return;
    }
    if (!_alive()) return;
    final id = serverId ?? local.id;
    if (id != local.id) {
      state = state.copyWith(
        posts: [
          for (final p in state.posts)
            if (p.id == local.id) p.copyWith(id: id) else p,
        ],
      );
    }
    _watch(id);
  }

  /// One wall met, reported once.
  ///
  /// Neither refusal carries a count on the wire — the cap is a server
  /// constant and the tier refusal has nothing to count — so `used`/`limit`
  /// are deliberately omitted rather than filled with the client's guess.
  void _reportLimit(LpLimit capability) => ref
      .read(analyticsProvider)
      .limitReached(capability, premium: ref.read(isPremiumProvider));

  /// Follows the author's mirror row until it settles. `pending` AND `held`
  /// are open: a held post is what `remoderateHeld` or the founder later
  /// flips live, and the author should see that land without a restart.
  void _watch(String id) {
    final stale = _statusSubs.remove(id);
    if (stale != null) unawaited(stale.cancel());
    _statusSubs[id] = _repo.watchPostStatus(id).listen(
      (status) => _setStatus(id, status),
      onError: (Object _) {},
    );
  }

  /// The author's own posts that came back from the feed still open — held
  /// for a human, or not yet classified — keep a watch too, so a verdict
  /// that lands while the app is open shows up without a reload.
  void _watchUnsettled(List<Post> posts) {
    for (final post in posts) {
      if (!post.isMine || _statusSubs.containsKey(post.id)) continue;
      if (post.status != PostStatus.pending && post.status != PostStatus.held) {
        continue;
      }
      _watch(post.id);
    }
  }

  /// Sends a post the network never carried. Only a `failed` post: a pending
  /// one is already on its way, and a held one is the server's call.
  void retryPost(String postId) {
    final post = state.posts.where((p) => p.id == postId).firstOrNull;
    if (post == null || post.status != PostStatus.failed) return;
    _setStatus(postId, PostStatus.pending);
    unawaited(_syncPost(post.copyWith(status: PostStatus.pending)));
  }

  void _setStatus(String postId, PostStatus status) {
    if (!_alive()) return;
    state = state.copyWith(
      posts: [
        for (final p in state.posts)
          if (p.id == postId && p.status != status)
            p.copyWith(status: status)
          else
            p,
      ],
    );
    // Only a settled status closes the watch; `held` stays open (see _watch).
    if (status != PostStatus.pending && status != PostStatus.held) {
      final done = _statusSubs.remove(postId);
      if (done != null) unawaited(done.cancel());
    }
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
    _repo.setReaction(postId, emoji, on: on).ignore();
  }

  void addReply(String postId, String text) {
    final reply = Reply(
      // Local id until the feed reloads with the server's. Distinct enough to
      // key a list and to be recognised as not-yet-server-side.
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
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
    _repo.addReply(postId, reply).ignore();
    final post = state.posts.firstWhere((p) => p.id == postId);
    if (post.tag == PostTag.sos && !post.isMine) {
      ref.read(quitStoreProvider.notifier).awardBadge('helpedSos');
    }
  }

  /// 3 reports on the SAME post auto-hide it pending review (the App Store
  /// UGC requirement). The count is local to this session and to this reader;
  /// the authoritative tally is `posts/{id}.reportCount` server-side.
  void reportPost(String postId) {
    final count = (_reportsByPost[postId] ?? 0) + 1;
    _reportsByPost[postId] = count;
    if (count >= autoHideReports) {
      state = state.copyWith(
        posts: [
          for (final p in state.posts)
            if (p.id == postId) p.copyWith(hidden: true) else p,
        ],
      );
    }
    _repo.reportPost(postId).ignore();
  }

  /// Reports on one post before it hides for the reporter.
  static const int autoHideReports = 3;

  void blockAuthor(String postId) {
    final post = state.posts.firstWhere((p) => p.id == postId);
    state = state.copyWith(blocked: {...state.blocked, post.alias});
    _repo.blockAuthor(post.alias).ignore();
    _persist();
  }

  void muteAuthor(String postId) {
    final post = state.posts.firstWhere((p) => p.id == postId);
    state = state.copyWith(muted: {...state.muted, post.alias});
    _persist();
  }

  /// Flags one reply, and hides it for this reader immediately.
  ///
  /// The button used to be `showLpSnack(context, 'Reported')` and nothing
  /// else: the app said the report was filed and filed nothing. The hide is
  /// local and immediate because the reader should not have to keep looking at
  /// what they just reported while moderation catches up.
  void reportReply({required String postId, required String replyId}) {
    state = state.copyWith(
      posts: [
        for (final p in state.posts)
          if (p.id == postId)
            p.copyWith(
              replies: p.replies.where((r) => r.id != replyId).toList(),
            )
          else
            p,
      ],
    );
    _repo.reportReply(postId: postId, replyId: replyId).ignore();
  }

  void _persist() {
    unawaited(
      CommunityPrefs.save(blocked: state.blocked, muted: state.muted),
    );
  }
}
