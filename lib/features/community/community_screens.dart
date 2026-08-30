import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/enum_labels.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/widgets/lp_states.dart';
import '../../core/utils/lp_format.dart';
import '../../core/utils/lp_haptics.dart';
import '../../core/widgets/lp_buttons.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_error.dart';
import '../../core/widgets/lp_misc.dart';
import '../../core/widgets/lp_selectables.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/community_store.dart' show CommunityStore, FeedStatus;
import '../../data/stores/providers.dart';
import '../../domain/models/models.dart';

/// Resolves seeded demo content to localized copy; user posts are raw text.
String postText(BuildContext context, Post post) {
  final l10n = context.l10n;
  if (post.text != null) return post.text!;
  return switch (post.seedTextId) {
    'win30' => l10n.seedPostWin30,
    'sosGasStation' => l10n.seedPostSos,
    'day1Lake' => l10n.seedPostDay1,
    'ventCoworker' => l10n.seedPostVent,
    'milestoneStairs' => l10n.seedPostMilestone,
    'winParty' => l10n.seedPostWinParty,
    _ => '',
  };
}

String replyText(BuildContext context, Reply reply) {
  final l10n = context.l10n;
  if (reply.text != null) return reply.text!;
  return switch (reply.seedTextId) {
    'sosReplyWalk' => l10n.seedReplyWalk,
    'sosReplyScience' => l10n.seedReplyScience,
    'sosReplyGatorade' => l10n.seedReplyGatorade,
    'sosReplyUpdate' => l10n.seedReplyUpdate,
    _ => '',
  };
}

Color tagColor(BuildContext context, PostTag tag) => switch (tag) {
  PostTag.win || PostTag.milestone => context.lp.ember,
  PostTag.sos => context.lp.oxygen,
  _ => context.lp.textSecondary,
};

/// Frame 43 — anonymous feed. SOS floats to the top with the Oxygen ring.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  PostTag? _filter;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final community = ref.watch(communityStoreProvider);
    final journey = ref.watch(quitStoreProvider);
    final posts = community
        .visible(DateTime.now())
        .where((p) => _filter == null || p.tag == _filter)
        .toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.communityTitle,
                    style: LpType.titleSm(lp.textPrimary),
                  ),
                  Text(
                    l10n.communityYouAre(journey?.profile.alias ?? ''),
                    style: LpType.caption(lp.textSecondary),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _filterChip(null, l10n.communityFilterAll),
                  for (final tag in PostTag.values)
                    _filterChip(tag, tag.label(context)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              // Post-shaped skeletons rather than a spinner: the feed keeps
              // its layout, so nothing jumps when the real posts land.
              child: posts.isEmpty && community.status == FeedStatus.loading
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      children: const [
                        _FeedSkeleton(),
                        SizedBox(height: 14),
                        _FeedSkeleton(),
                        SizedBox(height: 14),
                        _FeedSkeleton(),
                      ],
                    )
                  : posts.isEmpty && community.status == FeedStatus.failed
                  ? LpErrorState(
                      emoji: '📡',
                      title: l10n.errorFeedTitle,
                      body: l10n.errorFeedBody,
                      retryLabel: l10n.errorRetry,
                      onRetry: () =>
                          ref.read(communityStoreProvider.notifier).retryFeed(),
                    )
                  : posts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.communityEmptyTitle,
                              style: LpType.emphasis(lp.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.communityEmptyBody,
                              textAlign: TextAlign.center,
                              style: LpType.body13(lp.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                      itemCount: posts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => PostCard(
                        post: posts[i],
                        onOpen: () =>
                            context.push('/community/post/${posts[i].id}'),
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: PressScale(
        onTap: () => context.push(Routes.compose),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: lp.volt,
            boxShadow: lp.voltGlow(blur: 24, opacity: 0.35),
          ),
          child: Icon(Icons.edit_rounded, color: lp.onVolt, size: 22),
        ),
      ),
    );
  }

  Widget _filterChip(PostTag? tag, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: LpChip(
        label: label,
        selected: _filter == tag,
        onTap: () => setState(() => _filter = tag),
        fontSize: 12,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      ),
    );
  }
}

class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onOpen,
    this.expanded = false,
  });

  final Post post;
  final VoidCallback? onOpen;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final isSos = post.tag == PostTag.sos;
    final accent = tagColor(context, post.tag);
    final age = DateTime.now().difference(post.createdAt);

    return PressScale(
      onTap: onOpen,
      child: LpCard(
        borderColor: isSos ? lp.oxygen.withValues(alpha: 0.4) : lp.border,
        glowColor: isSos ? lp.oxygen : null,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                EmojiAvatar(post.avatarEmoji, tint: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: post.alias,
                      style: LpType.body13(
                        lp.textPrimary,
                        weight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(
                          text:
                              ' · ${l10n.communityDayTag(post.dayN)} · ${LpFormat.compactAgo(age)}',
                          style: LpType.caption11(lp.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    post.tag.label(context).toUpperCase(),
                    style: LpType.micro(
                      post.tag == PostTag.win || post.tag == PostTag.milestone
                          ? lp.emberText
                          : isSos
                          ? lp.oxygenText
                          : lp.textSecondary,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!post.isMine) ...[
                  const SizedBox(width: 6),
                  _PostMenu(post: post),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(postText(context, post), style: LpType.body14(lp.textPrimary)),
            const SizedBox(height: 12),
            if (isSos)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: lp.oxygenSoft,
                      borderRadius: BorderRadius.circular(LpDimens.rChip),
                      border: Border.all(
                        color: lp.oxygen.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      l10n.communityIGotYou,
                      style: LpType.caption(
                        lp.oxygenText,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (post.replies.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    // The real count. `replyingNow` used to live here: a
                    // fabricated 3 on your own SOS post and 12 in the demo
                    // fixtures, and nothing on the real backend could ever
                    // compute it — live presence needs a backend we do not
                    // have. A number that is only ever invented is worse than
                    // no number, especially one claiming people are with you.
                    Text(
                      l10n.communityRepliedCount(post.replies.length),
                      style: LpType.caption11(lp.textSecondary),
                    ),
                  ],
                ],
              )
            else
              Row(
                children: [
                  for (final entry in post.reactions.entries) ...[
                    _ReactionPill(post: post, emoji: entry.key),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ReactionPill extends ConsumerWidget {
  const _ReactionPill({required this.post, required this.emoji});

  final Post post;
  final String emoji;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final mine = post.myReactions.contains(emoji);
    final count = post.reactions[emoji] ?? 0;
    return PressScale(
      onTap: () {
        LpHaptics.light();
        ref
            .read(communityStoreProvider.notifier)
            .toggleReaction(post.id, emoji);
      },
      haptic: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: lp.surfaceInset,
          borderRadius: BorderRadius.circular(LpDimens.rChip),
          border: Border.all(
            color: mine ? lp.voltFocus : lp.border,
            width: mine ? 1.5 : 1,
          ),
        ),
        child: Text(
          '$emoji $count',
          style: LpType.caption(
            mine ? lp.voltText : lp.textSecondary,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PostMenu extends ConsumerWidget {
  const _PostMenu({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    return PressScale(
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          builder: (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.flag_outlined, color: lp.textSecondary),
                  title: Text(
                    l10n.communityReport,
                    style: LpType.body14(lp.textPrimary),
                  ),
                  onTap: () {
                    ref
                        .read(communityStoreProvider.notifier)
                        .reportPost(post.id);
                    Navigator.of(sheetContext).pop();
                    showLpSnack(context, l10n.communityReported);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.visibility_off_outlined,
                    color: lp.textSecondary,
                  ),
                  title: Text(
                    l10n.communityMute,
                    style: LpType.body14(lp.textPrimary),
                  ),
                  onTap: () {
                    ref
                        .read(communityStoreProvider.notifier)
                        .muteAuthor(post.id);
                    Navigator.of(sheetContext).pop();
                    showLpSnack(context, l10n.communityMuted);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.block_rounded, color: lp.dangerText),
                  title: Text(
                    l10n.communityBlock,
                    style: LpType.body14(lp.dangerText),
                  ),
                  onTap: () {
                    ref
                        .read(communityStoreProvider.notifier)
                        .blockAuthor(post.id);
                    Navigator.of(sheetContext).pop();
                    showLpSnack(context, l10n.communityBlocked);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
      child: Icon(Icons.more_horiz_rounded, color: lp.textFaint, size: 18),
    );
  }
}

/// Frame 44 — composer: tag required, kindness line persistent, always
/// anonymous, day count auto-attached.
class ComposerScreen extends ConsumerStatefulWidget {
  const ComposerScreen({super.key, this.initialTag});

  /// Pre-selects a tag. The panic flow opens this pre-tagged `sos` so that
  /// reaching for people mid-craving is one tap and not a form.
  final PostTag? initialTag;

  @override
  ConsumerState<ComposerScreen> createState() => _ComposerScreenState();
}

class _ComposerScreenState extends ConsumerState<ComposerScreen> {
  final _text = TextEditingController();
  late PostTag? _tag = widget.initialTag;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final journey = ref.watch(quitStoreProvider);
    final canPost = _text.text.trim().isNotEmpty && _tag != null;
    final isSos = _tag == PostTag.sos;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          // Scrolls when the keyboard eats the viewport; the kindness note
          // stays pinned to the bottom whenever there's room (Spacer).
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          LpTextButton(
                            l10n.commonCancel,
                            onTap: () => context.pop(),
                          ),
                          Text(
                            l10n.communityComposerTitle,
                            style: LpType.heading(lp.textPrimary),
                          ),
                          PressScale(
                            onTap: canPost
                                ? () {
                                    final text = _text.text.trim();
                                    ref
                                        .read(communityStoreProvider.notifier)
                                        .addPost(text: text, tag: _tag!);
                                    LpHaptics.medium();
                                    context.pop();
                                    // Brand/sourcing talk gets held, and says so.
                                    showLpSnack(
                                      context,
                                      CommunityStore.violatesCommunityRules(
                                            text,
                                          )
                                          ? l10n.communityAutoFlagged
                                          : l10n.communityPosted,
                                    );
                                  }
                                : null,
                            child: Opacity(
                              opacity: canPost ? 1 : 0.5,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSos ? lp.oxygen : lp.volt,
                                  borderRadius: BorderRadius.circular(
                                    LpDimens.rChip,
                                  ),
                                ),
                                child: Text(
                                  l10n.communityComposerPost,
                                  style: LpType.displaySmall(
                                    lp.onVolt,
                                    size: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      LpCard(
                        subtle: true,
                        radius: 12,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            EmojiAvatar(
                              journey?.profile.avatarEmoji ?? '🦊',
                              size: 30,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.communityPostingAs(
                                  journey?.profile.alias ?? '',
                                  journey?.plan.dayNumber(DateTime.now()) ?? 1,
                                ),
                                style: LpType.caption(lp.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        constraints: const BoxConstraints(minHeight: 150),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: lp.surface,
                          borderRadius: BorderRadius.circular(LpDimens.rCard),
                          border: Border.all(color: lp.voltFocus, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: lp.volt.withValues(alpha: 0.1),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _text,
                          maxLines: null,
                          maxLength: 500,
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                          style: LpType.body15(lp.textPrimary),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            counterText: '',
                            hintText: l10n.communityComposerHint,
                            hintStyle: LpType.body15(lp.textFaint),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SectionLabel(l10n.communityTagIt),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in PostTag.values)
                            LpChip(
                              label: tag.label(context),
                              selected: _tag == tag,
                              selectedColor: tag == PostTag.sos
                                  ? lp.oxygen
                                  : tag == PostTag.win ||
                                        tag == PostTag.milestone
                                  ? lp.ember
                                  : null,
                              onTap: () => setState(() => _tag = tag),
                              fontSize: 13,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 9,
                              ),
                            ),
                        ],
                      ),
                      if (_tag == null) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.communityTagRequired,
                          style: LpType.caption11(lp.textFaint),
                        ),
                      ],
                      const Spacer(),
                      LpNoteCard(l10n.communityKindnessNote),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How many people actually showed up for an SOS post.
///
/// Replies plus reactions: two things a real person did, both already stored.
/// This used to be `17 + replies.length` — a constant floor invented so the
/// banner would look busy, on a screen whose entire value is that someone
/// really is there. Zero means zero, and the banner does not render.
int _backupCount(Post post) =>
    post.replies.length +
    post.reactions.values.fold(0, (sum, n) => sum + n);

/// Frame 45 — SOS rally: live backup banner, replies, poster's update.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _reply = TextEditingController();

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final community = ref.watch(communityStoreProvider);
    final post = community.posts
        .where((p) => p.id == widget.postId)
        .firstOrNull;
    if (post == null) return const Scaffold(body: SizedBox.shrink());
    final isSos = post.tag == PostTag.sos;

    return Scaffold(
      appBar: AppBar(
        leading: BackChevron(onTap: () => context.pop()),
        title: Text(post.tag.label(context)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  // Only once somebody has actually shown up. An empty rally
                  // banner promising backup is the loneliest thing this screen
                  // could show the person who just asked for help.
                  if (isSos && _backupCount(post) > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: lp.oxygenSoft,
                        borderRadius: BorderRadius.circular(LpDimens.rInput),
                        border: Border.all(
                          color: lp.oxygen.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: lp.oxygen.withValues(alpha: 0.1),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Text('🛡️', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.communitySosBanner(_backupCount(post)),
                              style: LpType.body13(
                                lp.oxygenText,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  PostCard(post: post, expanded: true),
                  const SizedBox(height: 14),
                  for (final reply in post.replies) ...[
                    _ReplyBubble(reply: reply, postId: post.id),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
                decoration: BoxDecoration(
                  color: lp.surface,
                  borderRadius: BorderRadius.circular(LpDimens.rChip),
                  border: Border.all(color: lp.border, width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _reply,
                        style: LpType.body14(lp.textPrimary),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(post),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: l10n.communityAddVoice,
                          hintStyle: LpType.body14(lp.textFaint),
                        ),
                      ),
                    ),
                    PressScale(
                      onTap: () => _send(post),
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSos ? lp.oxygen : lp.volt,
                        ),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          size: 18,
                          color: lp.onVolt,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _send(Post post) {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    _reply.clear();
    LpHaptics.light();
    ref.read(communityStoreProvider.notifier).addReply(post.id, text);
  }
}

class _ReplyBubble extends ConsumerWidget {
  const _ReplyBubble({required this.reply, required this.postId});

  final Reply reply;
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmojiAvatar(
          reply.avatarEmoji,
          size: 30,
          tint: reply.isOp ? lp.oxygen : lp.volt,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: reply.isOp ? lp.oxygenSoft : lp.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: reply.isOp
                    ? lp.oxygen.withValues(alpha: 0.35)
                    : lp.border,
                width: 1.5,
              ),
            ),
            child: Text(
              replyText(context, reply),
              style: LpType.body13(lp.textPrimary),
            ),
          ),
        ),
        // Only a reply the server knows about can be reported, so a local
        // optimistic one has no flag until the feed reloads with its real id.
        if (!reply.isMine && reply.id.isNotEmpty) ...[
          const SizedBox(width: 6),
          // Frame 45: flagging a reply is one tap. It used to be a snackbar
          // and nothing else — the app said the report was filed and filed
          // nothing, on the one surface Guideline 1.2 is actually about.
          PressScale(
            onTap: () {
              LpHaptics.light();
              ref
                  .read(communityStoreProvider.notifier)
                  .reportReply(postId: postId, replyId: reply.id);
              showLpSnack(context, context.l10n.communityReported);
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Icon(Icons.flag_outlined, size: 14, color: lp.textFaint),
            ),
          ),
        ],
      ],
    );
  }
}

/// A post-shaped placeholder for the feed's first load.
class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) => LpCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Row(
          children: [
            LpSkeleton(height: 34, width: 34, radius: 17),
            SizedBox(width: 10),
            LpSkeleton(height: 12, width: 96, radius: 6),
          ],
        ),
        SizedBox(height: 14),
        LpSkeletonLines(count: 2),
      ],
    ),
  );
}
