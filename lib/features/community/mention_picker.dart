import 'package:flutter/material.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/press_scale.dart';
import '../../domain/logic/mentions.dart';
import '../../domain/models/models.dart';

/// How many people the strip will show at once.
///
/// A cap because a busy thread has many voices, not because the server has a
/// limit — [LpMentions.maxMentions] is a different number answering a
/// different question (how many tags one reply may carry).
const int _visibleLimit = 8;

/// The strip's own height.
const double kMentionStripHeight = 44;

/// The shortest thread viewport that will still seat the strip.
///
/// The strip is a convenience; the composer is not. In a viewport too short
/// for both, the strip is what gives way — otherwise the `Column` it sits in
/// paints an overflow stripe across the composer, which is the failure this
/// repo already knows as "a bare `Column` overflows the moment the viewport
/// shrinks".
///
/// It takes a genuinely tiny viewport to reach: about 175dp of body, a third
/// of the shortest phone `screen_layout_test` covers, and the app is
/// portrait-locked so a phone cannot get there at all. Split-screen on a
/// tablet can. The number is the strip plus the composer (roughly 74dp with
/// its padding) plus a sliver of thread left visible.
const double kMentionStripMinRoom = kMentionStripHeight + 74 + 60;

/// What the strip should offer for the composer's current state, or null when
/// it must not open at all.
///
/// Everything it needs is already in memory: the thread's own participants.
/// **No backend call, no query, no index** — there is no global alias→uid
/// table and `functions/src/domain/mentions.ts` explains at length why there
/// must never be one.
List<MentionTarget>? mentionSuggestions({
  required Post post,
  required String text,
  required int caret,
  String? myAlias,
  Set<String> hidden = const <String>{},
}) {
  final query = MentionQuery.at(text, caret);
  if (query == null) return null;

  // Once the reply already names as many people as the server will honour, a
  // sixth tag is parsed and silently dropped. Offering one would be a control
  // that does nothing, which is the shape of bug this app refuses to ship.
  if (LpMentions.parse(text).length >= LpMentions.maxMentions) return null;

  final matches = <MentionTarget>[];
  for (final target in LpMentions.targetsIn(
    post,
    myAlias: myAlias,
    hidden: hidden,
  )) {
    if (!query.matches(target.alias)) continue;
    matches.add(target);
    if (matches.length == _visibleLimit) break;
  }
  // An empty strip is worse than no strip: it takes height from the thread to
  // say nothing. Typing `@zzz` simply closes it.
  return matches.isEmpty ? null : matches;
}

/// The @-mention suggestions, sitting directly above the reply composer.
///
/// A horizontal strip rather than an anchored popup, which is deliberate on
/// two counts. It is the shape the coach screen already uses for its
/// suggestion chips, so the app gains no new overlay machinery — there is no
/// `OverlayEntry`, `LayerLink` or `RawAutocomplete` anywhere in `lib/`. And
/// as a plain sibling of the composer inside the `Scaffold`'s resized
/// `Column`, it rides above the keyboard with no `viewInsets` arithmetic at
/// all.
///
/// The avatar is the point: two aliases from the same eight animals are told
/// apart by their mark far faster than by their digits.
class MentionStrip extends StatelessWidget {
  const MentionStrip({
    super.key,
    required this.targets,
    required this.onSelected,
  });

  final List<MentionTarget> targets;
  final ValueChanged<MentionTarget> onSelected;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    return SizedBox(
      height: kMentionStripHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final target in targets)
            Semantics(
              button: true,
              label: l10n.communityMentionTag(target.alias),
              child: PressScale(
                // Deliberately does NOT unfocus, unlike the tag row on the
                // post composer: the person is mid-sentence and the keyboard
                // has to stay.
                onTap: () => onSelected(target),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.fromLTRB(6, 4, 14, 4),
                  decoration: BoxDecoration(
                    color: lp.surface,
                    borderRadius: BorderRadius.circular(LpDimens.rChip),
                    border: Border.all(color: lp.border, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EmojiAvatar(target.avatarEmoji, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        target.alias,
                        style: LpType.body13(
                          lp.textPrimary,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
