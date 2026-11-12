import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/enum_labels.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_format.dart';
import '../../core/utils/lp_haptics.dart';
import '../../core/widgets/lp_buttons.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_charts.dart';
import '../../core/widgets/lp_misc.dart';
import '../../core/widgets/lp_selectables.dart';
import '../../data/stores/providers.dart';
import '../../domain/logic/plan_restart.dart';
import '../../domain/logic/taper_engine.dart';
import '../../domain/models/models.dart';

/// Start a new plan — on this account, from where the person is now.
///
/// One page rather than a second onboarding: three answers (how much now,
/// which way, how long) and a live picture of the line they lead to. The
/// four-minute quiz was about who somebody is, and none of that has changed;
/// asking it again is what a new account cost the people who used to make
/// one to get here (five of the seven who signed out before Nov 2026).
///
/// What it changes and what it must not are `PlanRestart`'s rules, not this
/// screen's. The screen's own promise is the first line on it: nothing
/// resets.
class NewPlanScreen extends ConsumerStatefulWidget {
  const NewPlanScreen({super.key});

  @override
  ConsumerState<NewPlanScreen> createState() => _NewPlanScreenState();
}

class _NewPlanScreenState extends ConsumerState<NewPlanScreen> {
  static const _paces = [14, 21, 30, 60, 90];

  /// What the last week says they have been vaping, read once on the way in.
  /// Null when there is too little logged to say — then the field starts
  /// empty and the screen asks instead of guessing.
  late final int? _suggested;
  late final TextEditingController _level;
  late QuitMethod _method;
  late int _pace;

  @override
  void initState() {
    super.initState();
    final journey = ref.read(quitStoreProvider);
    final now = ref.read(nowProvider)();
    _suggested = journey == null
        ? null
        : PlanRestart.suggestedLevel(journey, now);
    _level = TextEditingController(text: _suggested?.toString() ?? '');
    _method = journey?.plan.method ?? QuitMethod.taper;
    // The runway they chose last time, when it is one of the choices here —
    // a stretched or reflowed plan is not, and falls back to thirty.
    final last = journey?.plan.paceDays;
    _pace = _paces.contains(last) ? last! : 30;
  }

  @override
  void dispose() {
    _level.dispose();
    super.dispose();
  }

  /// The level typed, when it is a level: a whole number of at least one.
  int? get _typed {
    final value = int.tryParse(_level.text.trim());
    return value != null && value >= 1 ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final journey = ref.watch(quitStoreProvider);
    if (journey == null) return const SizedBox.shrink();
    final now = ref.watch(nowProvider)();

    // Cold turkey needs no level to draw its line — it is zero — so it can
    // start on an empty field; a taper cannot start from nothing.
    final level = _typed;
    final canStart = level != null || _method == QuitMethod.coldTurkey;
    final preview = canStart
        ? PlanRestart.apply(
            journey,
            now: now,
            method: _method,
            paceDays: _pace,
            level: level ?? _suggested ?? journey.plan.curveStart,
          ).plan
        : null;

    void start() {
      final plan = preview;
      if (plan == null) return;
      LpHaptics.medium();
      showLpSnack(
        context,
        l10n.newPlanStarted(LpFormat.shortDate(plan.freedomDate, locale)),
      );
      final store = ref.read(quitStoreProvider.notifier);
      // Leave first, then mutate: the journey change refreshes the router,
      // and a refresh delivered after a navigation undoes it.
      context.go(Routes.home);
      store.startNewPlan(
        method: plan.method,
        paceDays: plan.paceDays,
        level: plan.curveStart,
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackChevron(onTap: () => context.pop()),
        title: Text(l10n.newPlanTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LpNoteCard(l10n.newPlanLead),
              const SizedBox(height: 18),
              LpField(
                label: l10n.newPlanLevelLabel,
                controller: _level,
                keyboardType: TextInputType.number,
                maxLength: 4,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Text(
                switch (_suggested) {
                  final avg? => l10n.newPlanLevelHint(avg),
                  null => l10n.newPlanLevelNoHint,
                },
                style: LpType.caption(lp.textSecondary),
              ),
              const SizedBox(height: 20),
              SectionLabel(
                l10n.obMethodTitle,
                padding: const EdgeInsets.only(left: 4, bottom: 10),
              ),
              Row(
                children: [
                  for (final m in QuitMethod.values) ...[
                    if (m != QuitMethod.values.first) const SizedBox(width: 10),
                    Expanded(
                      child: LpChip(
                        label: m.label(context),
                        selected: _method == m,
                        onTap: () => setState(() => _method = m),
                        fontSize: 14,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              SectionLabel(
                l10n.obPaceTitle,
                padding: const EdgeInsets.only(left: 4, bottom: 10),
              ),
              Row(
                children: [
                  for (final p in _paces) ...[
                    if (p != _paces.first) const SizedBox(width: 8),
                    Expanded(
                      child: LpChip(
                        label: '$p',
                        selected: _pace == p,
                        onTap: () => setState(() => _pace = p),
                        fontSize: 14,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              if (preview != null)
                LpCard(
                  radius: LpDimens.rCardLg,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TaperCurveChart(
                        samples: TaperEngine.normalizedCurve(preview),
                        height: 90,
                        todayFraction: 0,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.newPlanToday(TaperEngine.limitFor(preview, 1)),
                        style: LpType.body14(
                          lp.voltText,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n.newPlanFreedom(
                          LpFormat.shortDate(preview.freedomDate, locale),
                        ),
                        style: LpType.caption(lp.emberText),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              LpButton(l10n.newPlanCta, onTap: canStart ? start : null),
            ],
          ),
        ),
      ),
    );
  }
}
