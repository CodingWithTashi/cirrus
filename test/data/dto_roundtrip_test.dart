import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/api/fake/fake_fixtures.dart';
import 'package:last_puff/data/dto/coach_codec.dart';
import 'package:last_puff/data/dto/community_codec.dart';
import 'package:last_puff/data/dto/journey_codec.dart';
import 'package:last_puff/data/seed/seed_data.dart';
import 'package:last_puff/domain/models/models.dart';

/// Every model field must survive encode → real JSON string → decode →
/// re-encode unchanged. The seeded journey is the densest instance we have
/// (moods, notes, hour buckets, badges, goals, lastPuffAt). Models have no
/// `==`, so fidelity is asserted on the re-encoded JSON.
void main() {
  group('JourneyCodec', () {
    final now = DateTime(2026, 8, 18, 14, 37, 5);
    final journey = SeedData.journey(now);

    test('seed journey survives a full JSON round-trip', () {
      final wire = jsonEncode(JourneyCodec.encode(journey));
      final decoded = JourneyCodec.decode(
        jsonDecode(wire) as Map<String, dynamic>,
      );
      expect(jsonEncode(JourneyCodec.encode(decoded)), wire);
    });

    test('decoded fields are structurally intact', () {
      final decoded = JourneyCodec.decode(
        jsonDecode(jsonEncode(JourneyCodec.encode(journey)))
            as Map<String, dynamic>,
      );
      expect(decoded.days.length, 12);
      expect(decoded.profile.alias, '@quietfox');
      expect(decoded.profile.whys, journey.profile.whys);
      expect(decoded.plan.baselinePuffsPerDay, 200);
      expect(decoded.plan.strength, NicStrength.mg50);
      expect(decoded.lastPuffAt, journey.lastPuffAt);
      expect(decoded.day1TasksDone, {0, 1, 2});

      // Day-map keys stay local-midnight dates and each log's `date` matches
      // its key (the codec derives one from the other).
      for (final e in decoded.days.entries) {
        expect(e.key, DateTime(e.key.year, e.key.month, e.key.day));
        expect(e.value.date, e.key);
      }
      // The hard-but-held Thursday (day 7: 133 puffs) with its hour buckets.
      final day7 =
          decoded.days[journey.plan.startDate.add(const Duration(days: 6))]!;
      expect(day7.puffs, 133);
      expect(day7.hourBuckets, isNotEmpty);
      expect(day7.moodNote, 'work party tonight, nervous');
    });

    test('planAdvice round-trips, and its absence stays absent', () {
      // The seed journey carries no advice — the nightly cron has never run
      // for it — so the null case is the one the demo backend exercises daily.
      expect(journey.planAdvice, isNull);
      expect(
        JourneyCodec.encode(journey)['planAdvice'],
        isNull,
        reason: 'a journey with no advice must not invent one',
      );

      final advised = journey.copyWith(
        planAdvice: () => PlanAdvice(
          forDay: DateTime(2026, 8, 18),
          limit: 91,
          adherence: PlanAdherence.struggling,
          stretchDelta: 1,
        ),
      );
      final wire = jsonEncode(JourneyCodec.encode(advised));
      final decoded = JourneyCodec.decode(
        jsonDecode(wire) as Map<String, dynamic>,
      );
      expect(jsonEncode(JourneyCodec.encode(decoded)), wire);
      expect(decoded.planAdvice!.limit, 91);
      expect(decoded.planAdvice!.adherence, PlanAdherence.struggling);
      expect(decoded.planAdvice!.stretchDelta, 1);
      // Local midnight, never an epoch shift.
      expect(decoded.planAdvice!.forDay, DateTime(2026, 8, 18));
    });

    test('an unknown adherence decodes to onTrack, never a crash', () {
      final advice = JourneyCodec.decodeAdvice(const {
        'forDay': '2026-08-18',
        'limit': 40,
        'adherence': 'sandbagging',
        'stretchDelta': 0,
      });
      expect(advice.adherence, PlanAdherence.onTrack);
    });
  });

  group('PostCodec', () {
    test('community fixtures survive a full JSON round-trip', () {
      final wire = FakeFixtures.communityJson(DateTime(2026, 8, 18, 9));
      expect(wire, hasLength(6));
      for (final json in wire) {
        final decoded = PostCodec.decode(
          jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
        );
        expect(jsonEncode(PostCodec.encode(decoded)), jsonEncode(json));
      }
    });

    test('a user-authored post round-trips reactions and replies', () {
      final post = Post(
        id: 'p1',
        alias: '@quietfox',
        avatarEmoji: '🦊',
        dayN: 12,
        tag: PostTag.sos,
        text: 'craving hard right now',
        createdAt: DateTime(2026, 8, 18, 21, 4),
        reactions: const {'💪': 3},
        myReactions: const {'💪'},
        replies: const [
          Reply(alias: '@nightbee', avatarEmoji: '🐝', text: 'hold the line'),
        ],
        replyingNow: 2,
        isMine: true,
      );
      final wire = jsonEncode(PostCodec.encode(post));
      final decoded = PostCodec.decode(
        jsonDecode(wire) as Map<String, dynamic>,
      );
      expect(jsonEncode(PostCodec.encode(decoded)), wire);
      expect(decoded.replies.single.text, 'hold the line');
      expect(decoded.myReactions, {'💪'});
    });
  });

  group('CoachReplyCodec', () {
    // Ember's actual words travel in `text`. The server always sends a
    // sensible `template` alongside so a client built before the field
    // existed still renders something — but a client that DROPS text shows
    // the canned template instead of what the model actually said, which is
    // worse than either alone.
    test('carries the model reply text across the wire', () {
      const reply = CoachReply(
        template: CoachTemplate.generic1,
        args: {'day': 12},
        showWeekCard: true,
        text: 'That 10pm wave is brutal. Fifteen minutes and it breaks.',
      );

      final decoded = CoachReplyCodec.decode(
        jsonDecode(jsonEncode(CoachReplyCodec.encode(reply)))
            as Map<String, dynamic>,
      );

      expect(decoded.text, reply.text);
      expect(decoded.template, CoachTemplate.generic1);
      expect(decoded.args['day'], 12);
      expect(decoded.showWeekCard, isTrue);
    });

    // The deterministic templates (capReached, connectionLost) carry no text.
    test('a template-only reply decodes with a null text', () {
      final decoded = CoachReplyCodec.decode({
        'template': 'capReached',
        'args': {'limit': 5},
        'showWeekCard': false,
      });

      expect(decoded.text, isNull);
      expect(decoded.template, CoachTemplate.capReached);
    });

    test('an empty text is treated as absent, not as an empty bubble', () {
      final decoded = CoachReplyCodec.decode({
        'template': 'generic1',
        'args': <String, Object>{},
        'showWeekCard': false,
        'text': '   ',
      });

      expect(decoded.text, isNull);
    });
  });
}
