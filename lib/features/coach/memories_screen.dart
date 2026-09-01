import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/enum_labels.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_format.dart';
import '../../core/widgets/lp_states.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_error.dart';
import '../../core/widgets/lp_misc.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/providers.dart';
import '../../domain/models/journey_state.dart';
import '../../domain/models/models.dart';

/// What Ember knows and remembers, and the button that takes the latter back.
///
/// Two kinds of knowledge, deliberately separated on screen. "What it always
/// knows" is the user's own data — onboarding answers and the live engine
/// numbers, the same facts the coach's USER CARD carries — shown because a
/// day-1 tester read the old all-empty screen as "the AI remembers nothing"
/// (founder decision Aug 31 2026: memory is not only chat). "Things you've
/// told it" is the chat-extracted store, and only that part is forgettable,
/// because only that part is a disclosure rather than app data.
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
    final coach = ref.watch(coachNameProvider) ?? l10n.coachName;
    final journey = ref.watch(quitStoreProvider);
    final snap = ref.watch(todayProvider);
    final locale = context.localeTag;

    return Scaffold(
      appBar: AppBar(
        leading: BackChevron(onTap: () => context.pop()),
        title: Text(l10n.memoriesTitle(coach)),
      ),
      body: SafeArea(
        child: memories.when(
          loading: () => LpLoadingState(label: l10n.memoriesLoading(coach)),
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
              Text(l10n.memoriesIntro(coach), style: LpType.body13(lp.textSecondary)),
              const SizedBox(height: 18),
              if (journey != null) ...[
                _SectionHeader(label: l10n.memoriesSectionKnows(coach)),
                const SizedBox(height: 10),
                _FactsCard(facts: _facts(context, journey, snap, locale)),
                const SizedBox(height: 24),
              ],
              _SectionHeader(label: l10n.memoriesSectionTold(coach)),
              const SizedBox(height: 10),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    l10n.memoriesEmpty(coach),
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

  /// The deterministic facts, engine-computed from the journey — the same
  /// sources the server's USER CARD reads, so this list can never claim
  /// something the coach does not actually know. Rows without data simply
  /// don't render; nothing here is ever invented.
  List<(String, String)> _facts(
    BuildContext context,
    JourneyState journey,
    TodaySnapshot? snap,
    String locale,
  ) {
    final l10n = context.l10n;
    final plan = journey.plan;
    final profile = journey.profile;
    final whyWords = profile.whyWords;
    return [
      (
        l10n.memoriesFactPlan,
        l10n.memoriesFactPlanValue(plan.method.label(context), plan.totalDays),
      ),
      (l10n.memoriesFactStarted, LpFormat.mediumDate(plan.startDate, locale)),
      (
        l10n.memoriesFactBaseline,
        l10n.memoriesFactBaselineValue(plan.baselinePuffsPerDay),
      ),
      if (profile.whys.isNotEmpty)
        (
          l10n.memoriesFactWhy,
          profile.whys.map((w) => w.label(context)).join(', '),
        ),
      if (whyWords != null) (l10n.memoriesFactWhyWords, whyWords),
      if (profile.worries.isNotEmpty)
        (
          l10n.memoriesFactWorries,
          profile.worries.map((w) => w.label(context)).join(', '),
        ),
      if (profile.firstPuff != null)
        (
          l10n.memoriesFactFirstPuff,
          switch (profile.firstPuff!) {
            FirstPuffWindow.withinFive => l10n.obFirstPuffWithin5,
            FirstPuffWindow.fiveToThirty => l10n.obFirstPuff5to30,
            FirstPuffWindow.thirtyToSixty => l10n.obFirstPuff30to60,
            FirstPuffWindow.hourPlus => l10n.obFirstPuffHourPlus,
          },
        ),
      if (profile.frequency != null)
        (
          l10n.memoriesFactFrequency,
          switch (profile.frequency!) {
            VapeFrequency.daily => l10n.obFreqDaily,
            VapeFrequency.often => l10n.obFreqOften,
            VapeFrequency.always => l10n.obFreqAlways,
          },
        ),
      if (snap != null) ...[
        (
          l10n.memoriesFactDay,
          snap.isMaintenance
              ? l10n.memoriesFactDayMaintenance(snap.daysPastPlan)
              : l10n.memoriesFactDayValue(snap.dayNumber, snap.totalDays),
        ),
        (
          l10n.memoriesFactToday,
          l10n.memoriesFactTodayValue(snap.puffs, snap.limit),
        ),
        (l10n.memoriesFactStreak, l10n.homeStreakChip(snap.streak)),
        (l10n.memoriesFactSaved, LpFormat.money(snap.savedLifetime, locale)),
        (
          l10n.homeCravingsBeaten,
          LpFormat.integer(snap.cravingsSurvivedTotal, locale),
        ),
        if (snap.dangerWindow != null)
          (
            l10n.statsTriggerHours,
            '${LpFormat.hour(snap.dangerWindow!.$1, locale)} – '
                '${LpFormat.hour(snap.dangerWindow!.$2, locale)}',
          ),
      ],
    ];
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Text(
      label,
      style: LpType.body13(lp.textPrimary, weight: FontWeight.w700),
    );
  }
}

/// One card of LABEL/value rows for everything the coach derives from the
/// journey itself. No forget affordance: this is the app's own data, visible
/// here for honesty, deletable only by deleting the account.
class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.facts});

  final List<(String, String)> facts;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return LpCard(
      radius: LpDimens.rInput,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, fact) in facts.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            Text(
              fact.$1.toUpperCase(),
              style: LpType.caption11(
                lp.textFaint,
                weight: FontWeight.w700,
              ).copyWith(letterSpacing: 0.8),
            ),
            const SizedBox(height: 3),
            Text(fact.$2, style: LpType.body14(lp.textBody)),
          ],
        ],
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
    showLpSnack(
      context,
      l10n.memoriesForgotten(
        ref.read(coachNameProvider) ?? l10n.coachName,
      ),
    );
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
