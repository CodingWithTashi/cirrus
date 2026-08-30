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
import '../../data/stores/providers.dart';
import '../../domain/models/models.dart';

/// What Ember remembers, and the button that takes it back.
///
/// The coach stores what people tell it so it can be personal weeks later.
/// That is the feature — and a store like that is only trustworthy if the
/// person can see it and empty it. An AI quietly accumulating disclosures with
/// no way to look is a thing to be uneasy about, which is the opposite of what
/// makes someone keep opening the app.
///
/// It also keeps a promise the app already makes out loud: "we never sell your
/// data" (PRD §6) is worth less if we cannot show what we hold.
class CoachMemoriesScreen extends ConsumerWidget {
  const CoachMemoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final memories = ref.watch(coachMemoriesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: BackChevron(onTap: () => context.pop()),
        title: Text(l10n.memoriesTitle),
      ),
      body: SafeArea(
        child: memories.when(
          loading: () => LpLoadingState(label: l10n.memoriesLoading),
          // A failed load must not read as "Ember remembers nothing" — that is
          // a reassuring answer to an unanswered question.
          error: (_, _) => LpErrorState(
            emoji: '🧠',
            title: l10n.memoriesFailed,
            body: l10n.errorGenericBody,
            retryLabel: l10n.moderationRetry,
            onRetry: () => ref.invalidate(coachMemoriesProvider),
          ),
          data: (items) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(l10n.memoriesIntro, style: LpType.body13(lp.textSecondary)),
              const SizedBox(height: 18),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(
                    l10n.memoriesEmpty,
                    textAlign: TextAlign.center,
                    style: LpType.body14(lp.textSecondary),
                  ),
                ),
              for (final memory in items) ...[
                _MemoryCard(memory: memory),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoryCard extends ConsumerStatefulWidget {
  const _MemoryCard({required this.memory});

  final CoachMemory memory;

  @override
  ConsumerState<_MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends ConsumerState<_MemoryCard> {
  bool _busy = false;

  Future<void> _forget() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await ref
          .read(coachRepositoryProvider)
          .forgetMemory(widget.memory.id);
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      // Never optimistic. Telling someone a disclosure is gone while it is
      // still stored is the one failure this screen exists to prevent.
      showLpSnack(context, l10n.memoriesForgetFailed);
      return;
    }
    if (!mounted) return;
    showLpSnack(context, l10n.memoriesForgotten);
    ref.invalidate(coachMemoriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    return LpCard(
      radius: LpDimens.rInput,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _kindLabel(l10n, widget.memory.kind).toUpperCase(),
            style: LpType.caption11(
              lp.emberText,
              weight: FontWeight.w700,
            ).copyWith(letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          Text(widget.memory.text, style: LpType.body14(lp.textBody)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: PressScale(
              onTap: _busy ? null : _forget,
              child: Text(
                l10n.memoriesForget,
                style: LpType.caption(
                  _busy ? lp.textFaint : lp.dangerText,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The kind, as a phrase a person would use. Exhaustive on purpose: a new
/// [MemoryKind] should not compile until it has copy in every locale.
String _kindLabel(AppLocalizations l10n, MemoryKind kind) => switch (kind) {
  MemoryKind.person => l10n.memoriesKindPerson,
  MemoryKind.trigger => l10n.memoriesKindTrigger,
  MemoryKind.motivation => l10n.memoriesKindMotivation,
  MemoryKind.milestone => l10n.memoriesKindMilestone,
  MemoryKind.preference => l10n.memoriesKindPreference,
  MemoryKind.context => l10n.memoriesKindContext,
};
