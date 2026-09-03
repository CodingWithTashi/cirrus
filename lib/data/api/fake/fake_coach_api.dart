import 'dart:math';

import '../../../domain/logic/allowances.dart';
import '../../../domain/models/journey_state.dart';
import '../../../domain/models/models.dart';
import '../../../domain/repositories/repositories.dart';
import '../../dto/coach_codec.dart';
import '../../dto/codec_helpers.dart';
import '../../dto/journey_codec.dart';
import '../coach_api.dart';
import 'fake_server.dart';

/// Scripted, stat-aware Ember backend (docs/04). Picks a protocol from the
/// user's words, injects their real numbers (computed from the journey the
/// write-behind sync keeps on the server), and never repeats the same
/// celebration twice in a row — the same contract the Gemini flow will honor.
class FakeCoachApi implements CoachApi {
  FakeCoachApi(this._server);

  final FakeServer _server;
  final _random = Random();
  CoachTemplate? _lastTemplate;

  @override
  Future<Map<String, dynamic>> requestReply(Map<String, dynamic> request) {
    // "Model thinking" latency — the typing indicator's beat. Zeroed with the
    // rest of the network when tests zero the server latency.
    final thinking = _server.latency == Duration.zero
        ? Duration.zero
        : Duration(milliseconds: 700 + _random.nextInt(700));

    if (!_server.reachable) {
      return Future.delayed(
        thinking,
        () => throw const NoConnectionException(),
      );
    }

    final chip = enumByNameOrNull(CoachChip.values, request['chip']);
    final capped = request['capped'] as bool? ?? false;
    final template = capped
        ? CoachTemplate.capReached
        : chip != null
        ? _forChip(chip)
        : _pick(request['text'] as String? ?? '');
    _lastTemplate = template;

    // `aiCoachChat` answers a cap with `args: {limit}` and NOTHING else — the
    // allowance it just enforced. The generic card must not be used here: its
    // `limit` is the day's PUFF allowance, a different number entirely, and
    // sending it would make the cap bubble quote the taper curve at someone
    // who ran out of messages.
    final reply = capped
        ? CoachReply(
            template: template,
            args: {'limit': LpAllowances.freeCoachMessages},
            messagesLeft: 0,
            isFreeTier: true,
          )
        : CoachReply(
            template: template,
            args: _args(),
            showWeekCard:
                template == CoachTemplate.progress1 ||
                template == CoachTemplate.progress2,
          );
    return Future.delayed(thinking, () => CoachReplyCodec.encode(reply));
  }

  CoachTemplate _forChip(CoachChip chip) => switch (chip) {
    CoachChip.craving => _rotate([
      CoachTemplate.craving1,
      CoachTemplate.craving2,
      CoachTemplate.craving3,
    ]),
    CoachChip.roughDay => _rotate([CoachTemplate.rough1, CoachTemplate.rough2]),
    CoachChip.slipped => _rotate([CoachTemplate.slip1, CoachTemplate.slip2]),
    CoachChip.progress => _rotate([
      CoachTemplate.progress1,
      CoachTemplate.progress2,
    ]),
  };

  /// Keyword protocol routing (docs/04 §4) — swapped for the model later.
  CoachTemplate _pick(String text) {
    final t = text.toLowerCase();
    bool hasAny(List<String> words) => words.any(t.contains);
    if (hasAny(['crav', 'want one', 'need a hit', 'urge', 'dying for'])) {
      return _rotate([
        CoachTemplate.craving1,
        CoachTemplate.craving2,
        CoachTemplate.craving3,
      ]);
    }
    if (hasAny(['slip', 'caved', 'messed up', 'relapse', 'hit my friend'])) {
      return _rotate([CoachTemplate.slip1, CoachTemplate.slip2]);
    }
    if (hasAny([
      'party',
      'bar tonight',
      'drinks',
      'friends vape',
      'everyone vapes',
    ])) {
      return CoachTemplate.party;
    }
    if (hasAny(['progress', 'how am i doing', 'stats', 'numbers'])) {
      return _rotate([CoachTemplate.progress1, CoachTemplate.progress2]);
    }
    if (hasAny(['rough', 'stress', 'work is', 'bad day', 'tired', 'insane'])) {
      return _rotate([CoachTemplate.rough1, CoachTemplate.rough2]);
    }
    return _rotate([
      CoachTemplate.generic1,
      CoachTemplate.generic2,
      CoachTemplate.generic3,
      CoachTemplate.generic4,
    ]);
  }

  /// Variable reward: never the same line twice in a row (docs/03 §7).
  CoachTemplate _rotate(List<CoachTemplate> options) {
    final pool = options
        .where((o) => o != _lastTemplate)
        .toList(growable: false);
    return pool[_random.nextInt(pool.length)];
  }

  /// The user's real numbers, derived from the journey the client last synced.
  Map<String, Object> _args() {
    final json = _server.journeyJsonForCurrentSession();
    if (json == null) return const {};
    final snap = TodaySnapshot.of(JourneyCodec.decode(json), DateTime.now());
    return {
      'day': snap.dayNumber,
      'today': snap.puffs,
      'limit': snap.limit,
      'count': snap.cravingsSurvivedTotal,
      'saved': snap.savedLifetime,
      'percent': -snap.vsDay1Percent,
      'streak': snap.streak,
    };
  }
}
