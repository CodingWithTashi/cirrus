import '../../domain/logic/exercises/exercise.dart';
import '../../domain/models/coach_ui.dart';
import '../../domain/models/models.dart';
import 'codec_helpers.dart';

/// JSON mapping for the coach reply envelope — the only coach payload that
/// crosses the wire (docs/04). Args values are JSON scalars (int/double/String).
abstract final class CoachReplyCodec {
  /// The most cards one reply may carry (K3). The server sends at most
  /// three today; the cap is what bounds a reply this build did not write.
  static const int maxBlocks = 4;

  static Map<String, dynamic> encode(CoachReply reply) => {
    'template': reply.template.name,
    'args': reply.args,
    'showWeekCard': reply.showWeekCard,
    if (reply.text != null) 'text': reply.text,
    if (reply.messagesLeft != null) 'messagesLeft': reply.messagesLeft,
    if (reply.isFreeTier != null) 'tier': reply.isFreeTier! ? 'free' : 'premium',
    if (reply.followUps.isNotEmpty) 'followUps': reply.followUps,
    if (reply.blocks.isNotEmpty)
      'ui': {
        'v': CoachUiCaps.version,
        'blocks': [for (final block in reply.blocks) _encodeBlock(block)],
      },
  };

  static CoachReply decode(Map<String, dynamic> json) => CoachReply(
    template: enumByName(
      CoachTemplate.values,
      json['template'],
      CoachTemplate.generic1,
    ),
    args: Map<String, Object>.from(json['args'] as Map? ?? const {}),
    showWeekCard: json['showWeekCard'] as bool? ?? false,
    // Blank is treated as absent so a stray empty string can never render as
    // an empty bubble; the template takes over instead.
    text: switch ((json['text'] as String?)?.trim()) {
      final String t when t.isNotEmpty => t,
      _ => null,
    },
    messagesLeft: (json['messagesLeft'] as num?)?.toInt(),
    // Absent tier means an older backend; leaving it null hides the counter
    // rather than guessing at an allowance.
    isFreeTier: switch (json['tier'] as String?) {
      'free' => true,
      null => null,
      _ => false,
    },
    // Absent, empty, or full of things that are not strings all decode the
    // same way — an empty list, which the chip row reads as "show the four
    // static chips". That is the state a client built before this field
    // existed is permanently in, and the state every restored transcript is
    // in, so it has to be the quiet default rather than an error.
    //
    // Blank entries are dropped like `text` is, for the same reason: a chip
    // with nothing written on it is worse than one chip fewer.
    followUps: [
      for (final item in json['followUps'] as List<dynamic>? ?? const [])
        if (item is String && item.trim().isNotEmpty) item.trim(),
    ],
    blocks: _decodeBlocks(json['ui']),
  );

  static Map<String, dynamic> _encodeBlock(CoachBlock block) => switch (block) {
    CoachLauncherBlock(:final exercise) => {
      't': 'launcher',
      'exercise': exercise.name,
    },
  };

  /// Tolerant on purpose, and per card rather than per reply. A newer
  /// server may send a block type or an exercise this build does not know;
  /// that costs the one card, never the cards beside it and never the
  /// reply. Anything that is not the expected shape — no `ui`, a string, a
  /// list, `blocks` that is not a list — is no cards, which is exactly
  /// today's thread. `v` is not checked: a later version that still sends a
  /// readable list is still read.
  static List<CoachBlock> _decodeBlocks(Object? ui) {
    if (ui is! Map) return const [];
    final raw = ui['blocks'];
    if (raw is! List) return const [];
    final blocks = <CoachBlock>[];
    for (final item in raw) {
      if (blocks.length == maxBlocks) break;
      final block = item is Map ? _decodeBlock(item) : null;
      if (block != null) blocks.add(block);
    }
    return blocks;
  }

  static CoachBlock? _decodeBlock(Map<dynamic, dynamic> json) {
    switch (json['t']) {
      case 'launcher':
        final exercise = Exercises.parse(json['exercise']);
        return exercise == null ? null : CoachLauncherBlock(exercise);
      default:
        return null;
    }
  }
}
