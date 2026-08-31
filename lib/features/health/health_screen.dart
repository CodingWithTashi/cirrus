import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_format.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_misc.dart';
import '../../data/stores/providers.dart';

/// Frame 39 — health recovery timeline, honestly anchored to the last
/// logged puff (rolling anchor, docs/03 §6).
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final snap = ref.watch(todayProvider);
    if (snap == null) return const SizedBox.shrink();
    final sinceLastPuff = snap.lastPuffAt == null
        ? Duration.zero
        : DateTime.now().difference(snap.lastPuffAt!);

    final milestones = <(Duration, String, String, bool)>[
      (
        const Duration(minutes: 20),
        l10n.healthM20min,
        l10n.healthM20minBody,
        false,
      ),
      (const Duration(hours: 8), l10n.healthM8h, l10n.healthM8hBody, false),
      (const Duration(hours: 12), l10n.healthM12h, l10n.healthM12hBody, false),
      (const Duration(hours: 24), l10n.healthM24h, l10n.healthM24hBody, false),
      (const Duration(hours: 48), l10n.healthM48h, l10n.healthM48hBody, false),
      (const Duration(hours: 72), l10n.healthM72h, l10n.healthM72hBody, false),
      (const Duration(days: 7), l10n.healthM1w, l10n.healthM1wBody, false),
      (const Duration(days: 14), l10n.healthM2w, l10n.healthM2wBody, false),
      (const Duration(days: 30), l10n.healthM1m, l10n.healthM1mBody, false),
      (const Duration(days: 90), l10n.healthM3m, l10n.healthM3mBody, false),
      (const Duration(days: 180), l10n.healthM6m, l10n.healthM6mBody, false),
      (const Duration(days: 365), l10n.healthM1y, l10n.healthM1yBody, true),
    ];

    // Index of the next milestone to unlock — the "you are here" node.
    var hereIndex = milestones.indexWhere(
      (milestone) => sinceLastPuff < milestone.$1,
    );
    if (hereIndex == -1) hereIndex = milestones.length;

    return Scaffold(
      appBar: AppBar(
        leading: BackChevron(onTap: () => context.pop()),
        title: Text(l10n.healthTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(
              // Hours past 24 on purpose: the timeline below is denominated
              // in 24h/48h/72h milestones, and "71h" says how close the next
              // node is where "2d" would hide it.
              l10n.healthAnchor(
                LpFormat.compactAgo(sinceLastPuff, dayBucket: false),
              ),
              style: LpType.body13(lp.textSecondary),
            ),
            const SizedBox(height: 22),
            for (final (i, milestone) in milestones.indexed)
              _TimelineNode(
                title: i == hereIndex
                    ? l10n.healthYouAreHere(milestone.$2)
                    : milestone.$2,
                body: milestone.$3,
                state: i < hereIndex
                    ? _NodeState.done
                    : i == hereIndex
                    ? _NodeState.current
                    : _NodeState.locked,
                trophy: milestone.$4,
                isLast: i == milestones.length - 1,
              ),
            const SizedBox(height: 8),
            LpNoteCard(l10n.healthUnlockNote),
            const SizedBox(height: 8),
            Center(
              child: Text(
                l10n.healthSourceNote,
                textAlign: TextAlign.center,
                style: LpType.micro(lp.textFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _NodeState { done, current, locked }

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.title,
    required this.body,
    required this.state,
    required this.isLast,
    this.trophy = false,
  });

  final String title;
  final String body;
  final _NodeState state;
  final bool isLast;
  final bool trophy;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final done = state == _NodeState.done;
    final current = state == _NodeState.current;

    final node = Container(
      width: _nodeSize,
      height: _nodeSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? lp.volt : lp.surface,
        border: done
            ? null
            : Border.all(
                color: current ? lp.voltStrong : lp.border,
                width: current ? 2 : 1.5,
              ),
        boxShadow: done || current
            ? [BoxShadow(color: lp.volt.withValues(alpha: 0.5), blurRadius: 14)]
            : null,
      ),
      child: done
          ? Text(
              '✓',
              style: TextStyle(
                color: lp.onVolt,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            )
          : trophy
          ? const Text('🏆', style: TextStyle(fontSize: 13))
          : current
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: lp.voltStrong,
              ),
            )
          : null,
    );

    final content = current
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: lp.surface,
              borderRadius: BorderRadius.circular(LpDimens.rInput),
              border: Border.all(color: lp.voltFocus, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: lp.volt.withValues(alpha: 0.12),
                  blurRadius: 18,
                ),
              ],
            ),
            child: _text(context),
          )
        : _text(context);

    // Stack, not IntrinsicHeight.
    //
    // The obvious layout — IntrinsicHeight > Row(stretch) > Column with an
    // Expanded connector — crashed the whole screen. IntrinsicHeight asks its
    // child for a max intrinsic height, that walk reaches the connector's
    // `FractionallySizedBox`, and its intrinsic height is
    // `child intrinsic / heightFactor`. The reveal tween starts at 0, so on
    // the FIRST frame that divides by zero and the row is laid out with an
    // infinite height. Every non-last completed milestone did it, so opening
    // Health threw before it ever painted.
    //
    // Positioned children are excluded from a Stack's intrinsic sizing and
    // get bounded constraints from top+bottom, so the same growing line is
    // safe here — and nothing has to be measured twice.
    return Stack(
      children: [
        if (!isLast)
          Positioned(
            top: _nodeSize,
            bottom: 0,
            left: _nodeSize / 2 - 1,
            width: 2,
            // Frame 39: the Volt line grows down to "you are here".
            child: done
                ? TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: LpMotion.reveal,
                    curve: LpMotion.ease,
                    builder: (context, t, _) => Align(
                      alignment: Alignment.topCenter,
                      child: FractionallySizedBox(
                        heightFactor: t,
                        child: Container(color: lp.voltStrong),
                      ),
                    ),
                  )
                : Container(color: lp.border),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: _nodeSize, child: node),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
                child: content,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The node circle is a fixed square, which is what lets the connector be
  /// positioned rather than stretched.
  static const double _nodeSize = 28;

  Widget _text(BuildContext context) {
    final lp = context.lp;
    final done = state == _NodeState.done;
    final current = state == _NodeState.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: LpType.body14(
            done
                ? lp.voltText
                : current
                ? lp.textPrimary
                : lp.textSecondary,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          body,
          style: LpType.caption(
            done || current ? lp.textSecondary : lp.textFaint,
          ),
        ),
      ],
    );
  }
}
