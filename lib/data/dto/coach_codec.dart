import '../../domain/models/models.dart';
import 'codec_helpers.dart';

/// JSON mapping for the coach reply envelope — the only coach payload that
/// crosses the wire (docs/04). Args values are JSON scalars (int/double/String).
abstract final class CoachReplyCodec {
  static Map<String, dynamic> encode(CoachReply reply) => {
    'template': reply.template.name,
    'args': reply.args,
    'showWeekCard': reply.showWeekCard,
    if (reply.text != null) 'text': reply.text,
    if (reply.messagesLeft != null) 'messagesLeft': reply.messagesLeft,
    if (reply.isFreeTier != null) 'tier': reply.isFreeTier! ? 'free' : 'premium',
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
  );
}
