import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/widgets/lp_states.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_error.dart';
import '../../core/widgets/lp_misc.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/moderation_store.dart';
import '../../data/stores/providers.dart';
import '../../domain/models/models.dart';

/// The founder's review queue (docs/03 §9, App Store Guideline 1.2).
///
/// Guideline 1.2 requires a means of acting on reported content, and docs/03
/// commits to review inside 24 hours. `moderatePost` has been writing flags
/// since the backend was written and `moderationQueue`/`resolveModeration`
/// have been deployed; this screen is the thing that made either promise
/// keepable, because `moderation/*` is server-only and nothing could open it.
///
/// Deliberately plain. It is a daily chore for one person, not a product
/// surface, and every minute spent styling it is a minute not spent on the
/// screens users actually see. What it does owe them is honesty: no decision
/// appears applied until the server says it was.
class ModerationScreen extends ConsumerWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final state = ref.watch(moderationStoreProvider);
    final store = ref.read(moderationStoreProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: BackChevron(onTap: () => context.pop()),
        title: Text(l10n.moderationTitle),
        actions: [
          if (state.status == ModerationStatus.ready)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Center(
                child: Text(
                  l10n.moderationPendingCount(state.items.length),
                  style: LpType.caption(lp.textSecondary),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (state.status) {
          ModerationStatus.loading => LpLoadingState(
            label: l10n.moderationLoading,
          ),
          // A failed load must never render as an empty queue: "nothing to
          // review" and "we could not look" are the same picture and very
          // different facts.
          ModerationStatus.failed => LpErrorState(
            emoji: '🛡️',
            title: l10n.moderationFailed,
            body: l10n.errorGenericBody,
            retryLabel: l10n.moderationRetry,
            onRetry: store.load,
          ),
          ModerationStatus.ready => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _ReviewedToggle(
                value: state.includeReviewed,
                onChanged: (v) => store.setIncludeReviewed(value: v),
              ),
              const SizedBox(height: 12),
              if (state.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Text(
                    l10n.moderationEmpty,
                    textAlign: TextAlign.center,
                    style: LpType.body14(lp.textSecondary),
                  ),
                ),
              for (final item in state.items) ...[
                _FlagCard(
                  item: item,
                  busy: state.resolving.contains(item.flagId),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        },
      ),
    );
  }
}

class _ReviewedToggle extends StatelessWidget {
  const _ReviewedToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          context.l10n.moderationShowReviewed,
          style: LpType.caption(lp.textSecondary),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _FlagCard extends ConsumerWidget {
  const _FlagCard({required this.item, required this.busy});

  final ModerationItem item;
  final bool busy;

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref,
    ModerationResolution? action,
  ) async {
    final l10n = context.l10n;
    final ok = await ref
        .read(moderationStoreProvider.notifier)
        .resolve(item.flagId, action: action);
    if (!context.mounted || ok) return;
    // The row stays put on failure — a decision that did not land must not
    // look like one that did.
    showLpSnack(context, l10n.moderationResolveFailed);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    // 'block' is the classifier's own hard call; those rows read Ember.
    final blocked = item.action == 'block';

    return LpCard(
      radius: LpDimens.rInput,
      borderColor: blocked ? lp.ember.withValues(alpha: 0.45) : lp.border,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  // Verbatim, unlocalized: this is the record of what the
                  // classifier decided, and translating it would restate it.
                  l10n.moderationFlaggedAs(item.action, item.reason),
                  style: LpType.caption11(
                    blocked ? lp.emberText : lp.textSecondary,
                    weight: FontWeight.w700,
                  ).copyWith(letterSpacing: 0.6),
                ),
              ),
              Text(
                '${item.kind} · ${item.status ?? '—'}',
                style: LpType.caption11(lp.textFaint),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (item.subjectMissing)
            Text(
              l10n.moderationSubjectGone,
              style: LpType.body13(lp.textFaint),
            )
          else ...[
            Text(item.text ?? '', style: LpType.body14(lp.textBody)),
            if (item.alias != null) ...[
              const SizedBox(height: 6),
              Text(item.alias!, style: LpType.caption11(lp.textFaint)),
            ],
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _Action(
                label: l10n.moderationDismiss,
                tint: lp.textSecondary,
                busy: busy,
                onTap: () => _resolve(context, ref, null),
              ),
              const SizedBox(width: 8),
              _Action(
                label: l10n.moderationAllow,
                tint: lp.voltText,
                busy: busy,
                onTap: () =>
                    _resolve(context, ref, ModerationResolution.allow),
              ),
              const SizedBox(width: 8),
              _Action(
                label: l10n.moderationBlock,
                tint: lp.dangerText,
                busy: busy,
                onTap: () =>
                    _resolve(context, ref, ModerationResolution.block),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.tint,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final Color tint;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Expanded(
      child: PressScale(
        onTap: busy ? null : onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: lp.surfaceInset,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: lp.border),
          ),
          child: Text(
            label,
            style: LpType.caption(
              busy ? lp.textFaint : tint,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
