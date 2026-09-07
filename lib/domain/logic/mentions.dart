/// The client half of @-mention grammar (docs/10 §30.4).
///
/// A twin of `functions/src/domain/mentions.ts`, which is the source of truth
/// and carries the reasoning at length. The short version: `_randomAlias()`
/// mints aliases ON THE CLIENT from 8 adjectives × 8 animals × 90 numbers —
/// 5,760 possibilities, a plain `Random()`, no uniqueness check anywhere — so
/// an alias does not identify a PERSON. What it identifies, reliably, is a
/// voice in one conversation. There is no global alias→uid index and there
/// cannot be one, which is why [targetsIn] resolves against the thread
/// already in memory and never asks the backend anything.
///
/// Why the client needs a copy at all when the server is the one that
/// notifies: the picker must not offer a tag that would notify nobody. An
/// alias outside [mentionableSource] — a hand-edited one, `[departed
/// quitter]`, an older fixture — is storable but not mentionable, and
/// offering it would be a control that silently does nothing.
///
/// `test/domain/mentions_test.dart` reads `functions/src/domain/mentions.ts`
/// and `functions/src/lib/guards.ts` and fails if the pattern, the cap or the
/// mentionable shape drift — the same discipline `post_quality_test.dart`
/// applies to the posting floor.
library;

import '../models/models.dart';

/// Somebody a reply can be addressed to: what the picker draws.
class MentionTarget {
  const MentionTarget({required this.alias, required this.avatarEmoji});

  /// Includes the leading `@` — aliases are stored that way.
  final String alias;
  final String avatarEmoji;
}

abstract final class LpMentions {
  /// Mentions honoured per reply. Mirrors `MAX_MENTIONS`.
  ///
  /// A cap because each one costs the server a lookup, and because a reply
  /// naming fifteen people is not a conversation.
  static const int maxMentions = 5;

  /// `@quietfox42`, the shape `_randomAlias()` produces. Mirrors `MENTION`.
  ///
  /// Held as source text rather than only as a compiled pattern so the parity
  /// test can compare it character for character against the TypeScript.
  static const String patternSource = r'@[A-Za-z]{3,24}\d{1,3}';

  /// The anchored shape an alias must have to be the target of a mention.
  /// Mirrors `MENTIONABLE_ALIAS` in `guards.ts`, which is deliberately
  /// narrower than what `sanitizeAlias` will STORE.
  static const String mentionableSource = r'^@[a-z]{3,24}\d{1,3}$';

  /// Aliases named in [text], deduped case-insensitively and capped.
  ///
  /// Dart `RegExp` carries no `lastIndex`, so unlike the TypeScript this
  /// needs no fresh-pattern dance — but the dedupe and the cap must match it
  /// exactly, because this is what decides whether the picker still opens.
  static List<String> parse(String text) {
    final seen = <String>{};
    final found = <String>[];
    for (final match in _mention.allMatches(text)) {
      final alias = match[0]!;
      if (!seen.add(alias.toLowerCase())) continue;
      found.add(alias);
      if (found.length == maxMentions) break;
    }
    return found;
  }

  /// [text] with every mention-shaped token replaced by a space.
  ///
  /// **Uncapped, unlike [parse].** This answers "what is left once the
  /// addresses are removed", which the reply floor asks in order to refuse a
  /// reply that is only tags — so a sixth tag has to come out too, even
  /// though the server would never have honoured it.
  static String strip(String text) => text.replaceAll(_mention, ' ');

  /// Whether [alias] can be the target of a mention at all.
  static bool isMentionable(String alias) => _mentionable.hasMatch(alias);

  /// The people [post] can address, in the order they first spoke.
  ///
  /// The post's author precedes every reply, and replies arrive oldest-first
  /// — that ordering is the whole of the first-claimant rule, so a latecomer
  /// replying under somebody's alias cannot displace them in this list any
  /// more than they can on the server.
  ///
  /// [myAlias] drops the reader (mentioning yourself is not a notification);
  /// [hidden] drops whoever they have blocked or muted.
  static List<MentionTarget> targetsIn(
    Post post, {
    String? myAlias,
    Set<String> hidden = const <String>{},
  }) {
    final mine = myAlias?.toLowerCase();
    final skip = {for (final alias in hidden) alias.toLowerCase()};
    final seen = <String>{};
    final targets = <MentionTarget>[];
    void offer(String alias, String emoji) {
      final key = alias.toLowerCase();
      // First claimant wins, exactly as `resolveMentions` does it.
      if (!seen.add(key)) return;
      if (key == mine || skip.contains(key)) return;
      if (!isMentionable(alias)) return;
      targets.add(MentionTarget(alias: alias, avatarEmoji: emoji));
    }

    offer(post.alias, post.avatarEmoji);
    for (final reply in post.replies) {
      offer(reply.alias, reply.avatarEmoji);
    }
    return targets;
  }

  /// The aliases [text] names that belong to somebody in [participants],
  /// lowercased.
  ///
  /// `resolveMentions` stopping one step short: the client has no uid map and
  /// never will. Matched by exact equality against a pre-tokenised set — an
  /// alias must never BECOME a pattern, for the reasons `mentions.ts` gives.
  static Set<String> resolveIn(Iterable<String> participants, String text) {
    final known = {for (final alias in participants) alias.toLowerCase()};
    return {
      for (final alias in parse(text))
        if (known.contains(alias.toLowerCase())) alias.toLowerCase(),
    };
  }

  static final RegExp _mention = RegExp(patternSource);
  static final RegExp _mentionable = RegExp(
    mentionableSource,
    caseSensitive: false,
  );
}

/// The `@token` the caret is currently sitting inside, if any.
///
/// Pure caret arithmetic, kept out of the widget so it can be tested without
/// pumping anything: every interesting case here is an off-by-one.
class MentionQuery {
  const MentionQuery({
    required this.start,
    required this.end,
    required this.query,
  });

  /// Index of the `@`.
  final int start;

  /// The caret, one past the last typed character.
  final int end;

  /// The token as typed, `@` included — `@`, `@ni`, `@nightbee1`.
  final String query;

  /// The active token in [text] at [caret], or null when there is none.
  ///
  /// A token only opens at the start of the text or after whitespace, so
  /// `me@example.com` never offers a picker. It closes on the first character
  /// an alias cannot contain, so `@qui.` offers nothing rather than offering
  /// against a prefix the server could not parse.
  static MentionQuery? at(String text, int caret) {
    if (caret < 0 || caret > text.length) return null;
    for (var i = caret - 1; i >= 0; i--) {
      final char = text[i];
      if (char == '@') {
        if (i > 0 && !_space.hasMatch(text[i - 1])) return null;
        return MentionQuery(
          start: i,
          end: caret,
          query: text.substring(i, caret),
        );
      }
      if (!_aliasBody.hasMatch(char)) return null;
    }
    return null;
  }

  /// Whether [alias] is still a candidate for what has been typed so far.
  bool matches(String alias) =>
      alias.toLowerCase().startsWith(query.toLowerCase());

  static final RegExp _space = RegExp(r'\s');
  static final RegExp _aliasBody = RegExp(r'[A-Za-z0-9]');
}
