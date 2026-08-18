import '../../domain/models/models.dart';
import 'codec_helpers.dart';

/// JSON mapping for the coach reply envelope — the only coach payload that
/// crosses the wire (docs/04). Args values are JSON scalars (int/double/String).
abstract final class CoachReplyCodec {
  static Map<String, dynamic> encode(CoachReply reply) => {
    'template': reply.template.name,
    'args': reply.args,
    'showWeekCard': reply.showWeekCard,
  };

  static CoachReply decode(Map<String, dynamic> json) => CoachReply(
    template: enumByName(
      CoachTemplate.values,
      json['template'],
      CoachTemplate.generic1,
    ),
    args: Map<String, Object>.from(json['args'] as Map? ?? const {}),
    showWeekCard: json['showWeekCard'] as bool? ?? false,
  );
}
