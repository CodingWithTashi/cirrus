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
              l10n.healthAnchor(LpFormat.compactAgo(sinceLastPuff)),
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
      width: 28,
      height: 28,
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

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              node,
              if (!isLast)
                Expanded(
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
                              child: Container(width: 2, color: lp.voltStrong),
                            ),
                          ),
                        )
                      : Container(width: 2, color: lp.border),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: content,
            ),
          ),
        ],
      ),
    );
  }

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
