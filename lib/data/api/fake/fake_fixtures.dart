import '../../../domain/models/models.dart';
import '../../dto/community_codec.dart';
import '../../dto/journey_codec.dart';
import '../../seed/seed_data.dart';

/// Canned backend content, expressed as JSON the way a real API would return
/// it. Built from typed models and pushed through the codecs so every fixture
/// exercises the same round-trip production responses take.
abstract final class FakeFixtures {
  /// The demo account's day-12 journey (SeedData is the single source).
  static Map<String, dynamic> journeyJson(DateTime now) =>
      JourneyCodec.encode(SeedData.journey(now));

  /// The seeded community feed, timestamps relative to [now].
  static List<Map<String, dynamic>> communityJson(DateTime now) => [
    for (final p in _posts(now)) PostCodec.encode(p),
  ];

  static List<Post> _posts(DateTime now) => [
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
