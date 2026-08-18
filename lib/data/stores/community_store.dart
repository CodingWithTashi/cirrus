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

class CommunityStore extends Notifier<CommunityState>
    implements CommunityRepository {
  int _reportCounts = 0;

  @override
  CommunityState build() => CommunityState(posts: _seed(DateTime.now()));

  @override
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

  @override
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
    ref.read(quitStoreProvider.notifier).awardBadge('firstPost');
  }

  @override
  void toggleReaction(String postId, String emoji) {
    state = state.copyWith(
      posts: [
        for (final p in state.posts)
          if (p.id != postId)
            p
          else if (p.myReactions.contains(emoji))
            p.copyWith(
              reactions: {...p.reactions, emoji: (p.reactions[emoji] ?? 1) - 1},
              myReactions: {...p.myReactions}..remove(emoji),
            )
          else
            p.copyWith(
              reactions: {...p.reactions, emoji: (p.reactions[emoji] ?? 0) + 1},
              myReactions: {...p.myReactions, emoji},
            ),
      ],
    );
  }

  @override
  void addReply(String postId, String text) {
    state = state.copyWith(
      posts: [
        for (final p in state.posts)
          if (p.id != postId)
            p
          else
            p.copyWith(
              replies: [
                ...p.replies,
                Reply(
                  alias: _myAlias,
                  avatarEmoji: _myAvatar,
                  text: text,
                  isMine: true,
                ),
              ],
            ),
      ],
    );
    final post = state.posts.firstWhere((p) => p.id == postId);
    if (post.tag == PostTag.sos && !post.isMine) {
      ref.read(quitStoreProvider.notifier).awardBadge('helpedSos');
    }
  }

  @override
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
  }

  @override
  void blockAuthor(String postId) {
    final post = state.posts.firstWhere((p) => p.id == postId);
    state = state.copyWith(blocked: {...state.blocked, post.alias});
  }

  void muteAuthor(String postId) {
    final post = state.posts.firstWhere((p) => p.id == postId);
    state = state.copyWith(muted: {...state.muted, post.alias});
  }

  static const int nudgeDailyCap = 2;

  int get nudgesLeftToday =>
      (nudgeDailyCap - state.nudgesToday).clamp(0, nudgeDailyCap);

  @override
  void nudgeBuddy() {
    if (nudgesLeftToday == 0) return;
    state = state.copyWith(nudgesToday: state.nudgesToday + 1);
    ref.read(quitStoreProvider.notifier).awardBadge('buddyBond');
  }

  static List<Post> _seed(DateTime now) => [
    Post(
      id: 'seed-win',
      alias: '@embermaus',
      avatarEmoji: '🐭',
      dayN: 30,
      tag: PostTag.win,
      seedTextId: 'win30',
      createdAt: now.subtract(const Duration(hours: 2)),
      reactions: const {'💪': 214, '🔥': 89, '💬': 31},
    ),
    Post(
      id: 'seed-sos',
      alias: '@slowturtle',
      avatarEmoji: '🐢',
      dayN: 4,
      tag: PostTag.sos,
      seedTextId: 'sosGasStation',
      createdAt: now.subtract(const Duration(minutes: 22)),
      replyingNow: 12,
      replies: const [
        Reply(
          alias: '@quietfox',
          avatarEmoji: '🦊',
          seedTextId: 'sosReplyWalk',
          isMine: true,
        ),
        Reply(
          alias: '@nightbee',
          avatarEmoji: '🐝',
          seedTextId: 'sosReplyScience',
        ),
        Reply(
          alias: '@owlish',
          avatarEmoji: '🦉',
          seedTextId: 'sosReplyGatorade',
        ),
        Reply(
          alias: '@slowturtle',
          avatarEmoji: '🐢',
          seedTextId: 'sosReplyUpdate',
          isOp: true,
        ),
      ],
    ),
    Post(
      id: 'seed-day1',
      alias: '@cactusjuice',
      avatarEmoji: '🌵',
      dayN: 1,
      tag: PostTag.day1,
      seedTextId: 'day1Lake',
      createdAt: now.subtract(const Duration(hours: 1)),
      reactions: const {'💪': 47, '🔥': 12},
    ),
    Post(
      id: 'seed-vent',
      alias: '@moonmoth',
      avatarEmoji: '🦋',
      dayN: 9,
      tag: PostTag.vent,
      seedTextId: 'ventCoworker',
      createdAt: now.subtract(const Duration(hours: 5)),
      reactions: const {'💪': 33, '💬': 8},
    ),
    Post(
      id: 'seed-milestone',
      alias: '@ironlung',
      avatarEmoji: '🐺',
      dayN: 14,
      tag: PostTag.milestone,
      seedTextId: 'milestoneStairs',
      createdAt: now.subtract(const Duration(hours: 8)),
      reactions: const {'💪': 96, '🔥': 41},
    ),
    Post(
      id: 'seed-win2',
      alias: '@quietfox',
      avatarEmoji: '🦊',
      dayN: 12,
      tag: PostTag.win,
      seedTextId: 'winParty',
      createdAt: now.subtract(const Duration(hours: 26)),
      reactions: const {'💪': 58, '🔥': 21},
      isMine: true,
    ),
  ];
}
