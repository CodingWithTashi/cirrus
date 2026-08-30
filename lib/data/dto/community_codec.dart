import '../../domain/models/models.dart';
import 'codec_helpers.dart';

/// JSON mapping for community posts. `isMine`/`myReactions` travel on the
/// wire verbatim — a fake-backend simplification; a real backend derives them
/// per viewer from the requesting account.
abstract final class PostCodec {
  static Map<String, dynamic> encode(Post p) => {
    'id': p.id,
    'alias': p.alias,
    'avatarEmoji': p.avatarEmoji,
    'dayN': p.dayN,
    'tag': p.tag.name,
    'text': p.text,
    'seedTextId': p.seedTextId,
    'createdAt': encodeTimestamp(p.createdAt),
    'reactions': p.reactions,
    'myReactions': p.myReactions.toList(),
    'replies': [for (final r in p.replies) encodeReply(r)],
    'isMine': p.isMine,
    'hidden': p.hidden,
  };

  static Post decode(Map<String, dynamic> json) => Post(
    id: json['id'] as String,
    alias: json['alias'] as String,
    avatarEmoji: json['avatarEmoji'] as String,
    dayN: json['dayN'] as int,
    tag: enumByName(PostTag.values, json['tag'], PostTag.win),
    text: json['text'] as String?,
    seedTextId: json['seedTextId'] as String?,
    createdAt: decodeTimestamp(json['createdAt'] as String),
    reactions: {
      for (final e
          in (json['reactions'] as Map<String, dynamic>? ?? const {}).entries)
        e.key: (e.value as num).toInt(),
    },
    myReactions: (json['myReactions'] as List? ?? const [])
        .cast<String>()
        .toSet(),
    replies: [
      for (final r in json['replies'] as List? ?? const [])
        decodeReply(r as Map<String, dynamic>),
    ],
    isMine: json['isMine'] as bool? ?? false,
    hidden: json['hidden'] as bool? ?? false,
  );

  static Map<String, dynamic> encodeReply(Reply r) => {
    'id': r.id,
    'alias': r.alias,
    'avatarEmoji': r.avatarEmoji,
    'text': r.text,
    'seedTextId': r.seedTextId,
    'isOp': r.isOp,
    'isMine': r.isMine,
  };

  static Reply decodeReply(Map<String, dynamic> json) => Reply(
    id: json['id'] as String? ?? '',
    alias: json['alias'] as String,
    avatarEmoji: json['avatarEmoji'] as String,
    text: json['text'] as String?,
    seedTextId: json['seedTextId'] as String?,
    isOp: json['isOp'] as bool? ?? false,
    isMine: json['isMine'] as bool? ?? false,
  );
}
