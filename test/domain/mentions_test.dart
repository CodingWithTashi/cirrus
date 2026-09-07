import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/mentions.dart';
import 'package:last_puff/domain/models/models.dart';

/// The client's copy of @-mention grammar, and the caret arithmetic the
/// picker runs on.
///
/// Two implementations of one rule drift, and this pair drifts in a
/// particularly quiet way: the client decides what to OFFER and the server
/// decides who to NOTIFY, so a loose client offers a tag that reaches nobody
/// and a strict one hides somebody who could have been reached. Neither shows
/// up as an error anywhere.
void main() {
  Reply reply(String alias, {String emoji = '🐝'}) =>
      Reply(id: alias, alias: alias, avatarEmoji: emoji, text: 'here');

  Post thread({
    String alias = '@quietfox42',
    List<Reply> replies = const [],
  }) => Post(
    id: 'p1',
    alias: alias,
    avatarEmoji: '🦊',
    dayN: 3,
    tag: PostTag.win,
    text: 'day three and white-knuckling',
    createdAt: DateTime(2026, 9, 7),
    replies: replies,
  );

  group('parse', () {
    test('finds an alias in ordinary prose', () {
      expect(LpMentions.parse('@quietfox42 that line got me'), [
        '@quietfox42',
      ]);
    });

    test('dedupes case-insensitively, keeping the first spelling', () {
      expect(LpMentions.parse('@QuietFox42 hey @quietfox42'), ['@QuietFox42']);
    });

    test('ignores text that is not alias-shaped', () {
      expect(LpMentions.parse('email me@example.com or @x or @nodigits'), []);
    });

    test('caps how many it will honour', () {
      final many = [
        for (var i = 0; i < 12; i++) '@aliasname$i',
      ].join(' ');
      expect(LpMentions.parse(many), hasLength(LpMentions.maxMentions));
    });
  });

  group('strip', () {
    test('leaves the message and takes the addresses', () {
      expect(LpMentions.strip('@quietfox42 that line got me').trim(), 'that '
          'line got me');
    });

    test('is uncapped, unlike parse', () {
      // Different questions. The cap is "how many will we honour"; this is
      // "what is left once the addresses come out", and a sixth address is
      // still an address.
      final many = [for (var i = 0; i < 8; i++) '@aliasname$i'].join(' ');
      expect(LpMentions.parse(many), hasLength(LpMentions.maxMentions));
      expect(LpMentions.strip(many).trim(), isEmpty);
    });

    test('leaves an email address alone', () {
      expect(LpMentions.strip('email me@example.com'), 'email me@example.com');
    });
  });

  group('isMentionable', () {
    test('accepts what _randomAlias mints', () {
      // 8 adjectives × 8 animals × 9..98 — every alias a real account has.
      for (final alias in [
        '@quietfox42',
        '@calmotter9',
        '@brightmoth17',
        '@STEADYFALCON98',
      ]) {
        expect(LpMentions.isMentionable(alias), isTrue, reason: alias);
      }
    });

    test('refuses what somebody could rename themselves to', () {
      // A hand-edited alias is storable but not mentionable — the profile
      // sheet enforces only the leading `@`. The picker must not offer one,
      // because a tag on it would notify nobody at all.
      for (final alias in [
        '@bob',
        '@quietfox',
        'quietfox42',
        '@quietfox4242',
        '[departed quitter]',
        '',
      ]) {
        expect(LpMentions.isMentionable(alias), isFalse, reason: alias);
      }
    });
  });

  group('targetsIn', () {
    test('offers the author first, then the voices in order', () {
      final targets = LpMentions.targetsIn(
        thread(
          replies: [reply('@brightmoth17'), reply('@calmotter9')],
        ),
      );
      expect(targets.map((t) => t.alias), [
        '@quietfox42',
        '@brightmoth17',
        '@calmotter9',
      ]);
    });

    test('never offers the reader themselves', () {
      // Mentioning yourself is not a notification — `resolveMentions` drops
      // it server-side, so offering it would be a control that does nothing.
      final targets = LpMentions.targetsIn(
        thread(replies: [reply('@brightmoth17')]),
        myAlias: '@BrightMoth17',
      );
      expect(targets.map((t) => t.alias), ['@quietfox42']);
    });

    test('gives a duplicated alias to whoever used it FIRST', () {
      // The squatting attack, from the picker's side: somebody replies under
      // the author's alias. The incumbent wins here exactly as they win in
      // `resolveMentions`, so the strip cannot offer the impostor's avatar
      // against the author's name.
      final targets = LpMentions.targetsIn(
        thread(replies: [reply('@quietfox42', emoji: '🐺')]),
      );
      expect(targets, hasLength(1));
      expect(targets.single.avatarEmoji, '🦊');
    });

    test('drops blocked and muted voices', () {
      final targets = LpMentions.targetsIn(
        thread(replies: [reply('@brightmoth17'), reply('@calmotter9')]),
        hidden: {'@calmotter9'},
      );
      expect(targets.map((t) => t.alias), ['@quietfox42', '@brightmoth17']);
    });

    test('drops anybody the server could not resolve a tag to', () {
      final targets = LpMentions.targetsIn(
        thread(alias: '@quietfox', replies: [reply('@brightmoth17')]),
      );
      expect(targets.map((t) => t.alias), ['@brightmoth17']);
    });
  });

  group('resolveIn', () {
    test('keeps only the names belonging to somebody in the thread', () {
      expect(
        LpMentions.resolveIn(
          ['@quietfox42', '@brightmoth17'],
          '@BRIGHTMOTH17 and @ghostwolf88, thanks',
        ),
        {'@brightmoth17'},
      );
    });

    test('is unbothered by an alias that would be a bad regex', () {
      // An alias is untrusted input and must never BECOME a pattern: `(a+)+$`
      // compiled into one is a denial of service, and `a` used with a
      // substring match hits nearly every reply ever written.
      expect(LpMentions.resolveIn([r'(a+)+$', 'a'], 'a perfectly ordinary '
          'sentence'), isEmpty);
    });
  });

  group('MentionQuery.at', () {
    test('opens on a bare @ at the start', () {
      final query = MentionQuery.at('@', 1);
      expect(query, isNotNull);
      expect(query!.start, 0);
      expect(query.query, '@');
    });

    test('opens after whitespace and carries what has been typed', () {
      final query = MentionQuery.at('thanks @nig', 11);
      expect(query!.start, 7);
      expect(query.query, '@nig');
      expect(query.matches('@nightbee14'), isTrue);
      expect(query.matches('@owlish7'), isFalse);
    });

    test('never opens inside an email address', () {
      expect(MentionQuery.at('me@example', 10), isNull);
    });

    test('closes once the token holds something an alias cannot', () {
      // Offering against `@qui.` would be offering against a prefix the
      // server's own pattern could never parse.
      expect(MentionQuery.at('@qui.', 5), isNull);
    });

    test('closes on the space the picker itself inserts', () {
      expect(MentionQuery.at('@nightbee14 ', 12), isNull);
    });

    test('reads the token the caret is in, not the last one in the text', () {
      // Tapping back into the middle of a written sentence.
      final query = MentionQuery.at('@nig and @owlish7 too', 4);
      expect(query!.query, '@nig');
    });

    test('answers null for a field that has never been focused', () {
      // `TextEditingController.selection.baseOffset` is -1 until then.
      expect(MentionQuery.at('', -1), isNull);
    });
  });

  test('the grammar is the one the server parses with', () {
    // Two copies of one rule drift. The client decides what to OFFER and the
    // server decides who to NOTIFY, so a drift here is silent in both
    // directions — a tag that reaches nobody, or a person who cannot be
    // reached. Same discipline as `post_quality_test.dart`, which reads the
    // TypeScript prefilter to pin the posting floor.
    final mentions = File(
      'functions/src/domain/mentions.ts',
    ).readAsStringSync();

    final pattern = RegExp(r'const MENTION = /(.*?)/g;').firstMatch(mentions);
    expect(pattern, isNotNull, reason: 'MENTION not found in mentions.ts');
    expect(LpMentions.patternSource, pattern!.group(1));

    final cap = RegExp(
      r'export const MAX_MENTIONS = (\d+);',
    ).firstMatch(mentions);
    expect(cap, isNotNull, reason: 'MAX_MENTIONS not found in mentions.ts');
    expect(LpMentions.maxMentions, int.parse(cap!.group(1)!));

    // Narrower than what `sanitizeAlias` will STORE, and deliberately so —
    // storage stays permissive for `[departed quitter]`, while mention
    // matching is a lookup key and wants the tightest shape it can get.
    final guards = File('functions/src/lib/guards.ts').readAsStringSync();
    final mentionable = RegExp(
      r'const MENTIONABLE_ALIAS = /(.*?)/i;',
    ).firstMatch(guards);
    expect(mentionable, isNotNull, reason: 'MENTIONABLE_ALIAS not in guards.ts');
    expect(LpMentions.mentionableSource, mentionable!.group(1));
  });
}
