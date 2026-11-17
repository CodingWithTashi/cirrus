import 'dart:async';

import 'package:material_ui/material_ui.dart';
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
import '../../core/widgets/lp_error.dart';
import '../../core/widgets/lp_misc.dart';
import '../../core/widgets/lp_selectables.dart';
import '../../core/widgets/rolling_number.dart';
import '../../data/stores/providers.dart';
import '../../domain/logic/plan_paces.dart';
import '../../domain/logic/plan_restart.dart';
import '../../domain/logic/taper_engine.dart';
import '../../domain/models/journey_state.dart';
import '../../domain/models/models.dart';

/// Start a new plan — on this account, from where the person is now.
///
/// Two steps, in onboarding's own header (back, the glowing bar, "1/2"),
/// rather than a second onboarding: the four-minute quiz was about who
/// somebody is, and none of that has changed; asking it again is what a new
/// account cost the people who used to make one to get here (five of the
/// seven who signed out before Nov 2026).
///
/// 1. **The plan** — how much now, which way, how long, and a live picture of
///    the line they lead to.
/// 2. **The history** — keep it (the default; `PlanRestart.apply`), or start
///    from scratch (`PlanRestart.fresh`), which erases ALL of it: every puff,
///    the stats, streak, badges, money saved, cravings beaten and the chat
///    with the coach. One choice, no sub-switches — the streak, the money and
///    the stats are all read off the same day log, so "some of it" was never
///    a real option. The person's own numbers sit above the choice and roll
///    to zero when scratch is picked, so what "everything" means is on
///    screen before any dialog says it; the CTA then opens a confirmation
///    that lists it, and nothing is erased until the server has confirmed
///    its half (`_FreshStartDialog`).
///
/// What a new plan changes and what it must not are `PlanRestart`'s rules,
/// not this screen's.
class NewPlanScreen extends ConsumerStatefulWidget {
  const NewPlanScreen({super.key});

  @override
  ConsumerState<NewPlanScreen> createState() => _NewPlanScreenState();
}

class _NewPlanScreenState extends ConsumerState<NewPlanScreen> {
  static const _paces = PlanPaces.options;
  static const _steps = 2;

  /// What the last week says they have been vaping, read once on the way in.
  /// Null when there is too little logged to say — then the field starts
  /// empty and the screen asks instead of guessing.
  late final int? _suggested;
  late final TextEditingController _level;
  late QuitMethod _method;
  late int _pace;

  /// 0: the plan. 1: what happens to the history. Every answer lives here,
  /// on the screen, so going back a step loses nothing typed.
  int _step = 0;

  /// Keep everything (the default) or start from scratch.
  bool _keepHistory = true;

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
    _pace = _paces.contains(last) ? last! : PlanPaces.defaultDays;
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

  /// The plan the answers lead to, or null while a taper has nothing to
  /// start from. Cold turkey needs no level to draw its line — it is zero —
  /// so it can start on an empty field.
  QuitPlan? _preview(JourneyState journey, DateTime now) {
    final level = _typed;
    if (level == null && _method != QuitMethod.coldTurkey) return null;
    return PlanRestart.apply(
      journey,
      now: now,
      method: _method,
      paceDays: _pace,
      level: level ?? _suggested ?? journey.plan.curveStart,
    ).plan;
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step = 0);
    } else if (context.canPop()) {
      context.pop();
    } else {
      // Reached by `go` (a link, a test): nothing beneath to pop, and
      // `GoRouter.pop()` throws on an empty stack rather than doing nothing.
      context.go(Routes.home);
    }
  }

  void _next() {
    LpHaptics.tick();
    // The keyboard from the level field would otherwise sit over step two's
    // button.
    FocusScope.of(context).unfocus();
    setState(() => _step = 1);
  }

  void _choose({required bool keep}) {
    if (keep == _keepHistory) return;
    LpHaptics.tick();
    setState(() => _keepHistory = keep);
  }

  void _start(QuitPlan plan, {bool fresh = false}) {
    LpHaptics.medium();
    final l10n = context.l10n;
    final date = LpFormat.shortDate(plan.freedomDate, context.localeTag);
    showLpSnack(
      context,
      fresh ? l10n.newPlanFreshStarted(date) : l10n.newPlanStarted(date),
    );
    final store = ref.read(quitStoreProvider.notifier);
    // Leave first, then mutate: the journey change refreshes the router,
    // and a refresh delivered after a navigation undoes it.
    context.go(Routes.home);
    store.startNewPlan(
      method: plan.method,
      paceDays: plan.paceDays,
      level: plan.curveStart,
      keepHistory: !fresh,
    );
  }

  Future<void> _confirmFresh(QuitPlan plan) async {
    LpHaptics.tick();
    final store = ref.read(quitStoreProvider.notifier);
    // The erase and the commit are one unit, chained on the request rather
    // than on this screen: a tapped reminder can `go` Home while the spinner
    // is up, tearing down the dialog and the screen together. Once the server
    // has erased, the journey must follow, screen or no screen — otherwise
    // the coach thread is gone and every puff is still there.
    Future<void> erase() async {
      await store.eraseServerHistory();
      if (mounted) return; // [_start] commits, after leaving.
      store.startNewPlan(
        method: plan.method,
        paceDays: plan.paceDays,
        level: plan.curveStart,
        keepHistory: false,
      );
    }

    final erased = await showDialog<bool>(
      context: context,
      // A stray tap outside must not cancel an erase already in flight.
      barrierDismissible: false,
      builder: (_) => _FreshStartDialog(erase: erase),
    );
    if (erased != true || !mounted) return;
    _start(plan, fresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final journey = ref.watch(quitStoreProvider);
    if (journey == null) return const SizedBox.shrink();
    final now = ref.watch(nowProvider)();
    final preview = _preview(journey, now);

    final Widget cta = switch ((_step, preview)) {
      (0, _) => AnimatedOpacity(
        key: const ValueKey('next'),
        duration: LpMotion.fast,
        // Nothing typed, nothing to start a taper from: the button says so
        // rather than looking ready and doing nothing.
        opacity: preview == null ? 0.4 : 1,
        child: LpButton(
          l10n.commonContinue,
          onTap: preview == null ? null : _next,
        ),
      ),
      (_, null) => const SizedBox.shrink(),
      (_, final plan?) when _keepHistory => LpButton(
        l10n.newPlanCta,
        key: const ValueKey('keep'),
        onTap: () => _start(plan),
      ),
      (_, final plan?) => LpButton(
        l10n.newPlanFreshCta,
        key: const ValueKey('fresh'),
        style: LpButtonStyle.danger,
        onTap: () => _confirmFresh(plan),
      ),
    };

    return PopScope(
      // Back on step two is a step back, never out of the screen.
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 20, 8),
                child: Row(
                  children: [
                    BackChevron(onTap: _back),
                    const SizedBox(width: 4),
                    Expanded(
                      child: GlowProgressBar(value: (_step + 1) / _steps),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.obProgressOf(_step + 1, _steps),
                      style: LpType.displaySmall(lp.textSecondary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: LpMotion.normal,
                  switchInCurve: LpMotion.ease,
                  switchOutCurve: Curves.easeIn,
                  // Top-aligned and full-size: the default centres a short
                  // step in the middle of the screen.
                  layoutBuilder: (current, previous) => Stack(
                    fit: StackFit.expand,
                    children: [...previous, ?current],
                  ),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: SingleChildScrollView(
                    key: ValueKey(_step),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: _step == 0
                        ? _planStep(context, preview)
                        : _historyStep(context),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: AnimatedSwitcher(duration: LpMotion.fast, child: cta),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Step one: the three answers and the line they lead to.
  Widget _planStep(BuildContext context, QuitPlan? preview) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepTitle(
          title: l10n.newPlanTitle,
          subtitle: l10n.newPlanPlanSubtitle,
        ),
        LpField(
          label: l10n.newPlanLevelLabel,
          controller: _level,
          keyboardType: TextInputType.number,
          maxLength: 4,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Text(switch (_suggested) {
          final avg? => l10n.newPlanLevelHint(avg),
          null => l10n.newPlanLevelNoHint,
        }, style: LpType.caption(lp.textSecondary)),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 11,
                  ),
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
                  style: LpType.body14(lp.voltText, weight: FontWeight.w600),
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
      ],
    );
  }

  /// Step two: their numbers, and what happens to them.
  Widget _historyStep(BuildContext context) {
    final l10n = context.l10n;
    final snap = ref.watch(todayProvider);
    final journey = ref.watch(quitStoreProvider);
    final coachName = ref.watch(coachNameProvider) ?? l10n.coachName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepTitle(
          title: l10n.newPlanHistoryTitle,
          subtitle: l10n.newPlanHistorySubtitle,
        ),
        _HistoryNumbers(
          erased: !_keepHistory,
          streak: snap?.streak ?? 0,
          saved: snap?.savedLifetime ?? 0,
          badges: journey?.earnedBadges.length ?? 0,
          cravings: snap?.cravingsSurvivedTotal ?? 0,
        ),
        const SizedBox(height: 16),
        OptionCard(
          selected: _keepHistory,
          onTap: () => _choose(keep: true),
          title: l10n.newPlanKeepTitle,
          subtitle: l10n.newPlanKeepBody,
        ),
        const SizedBox(height: 10),
        OptionCard(
          selected: !_keepHistory,
          destructive: true,
          onTap: () => _choose(keep: false),
          title: l10n.newPlanFreshTitle,
          subtitle: l10n.newPlanFreshBody(coachName),
        ),
      ],
    );
  }
}

/// A step's title and subtitle, in onboarding's type and spacing
/// (`StepBody`), without its intrinsic-height scroll view: the curve preview
/// animates, and an animating box under `IntrinsicHeight` is what took the
/// Health screen down.
class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: LpType.title(lp.textPrimary)),
          const SizedBox(height: 10),
          Text(subtitle, style: LpType.body14(lp.textSecondary)),
        ],
      ),
    );
  }
}

/// The person's own record, above the choice of what happens to it — so
/// "start from scratch" shows what it means before any dialog says it: pick
/// it and every number rolls to zero in the danger colour; pick "keep" and
/// they roll back.
///
/// Engine numbers only (`TodaySnapshot`, the badge set), never a figure
/// written for the screen.
class _HistoryNumbers extends StatelessWidget {
  const _HistoryNumbers({
    required this.erased,
    required this.streak,
    required this.saved,
    required this.badges,
    required this.cravings,
  });

  final bool erased;
  final int streak;
  final double saved;
  final int badges;
  final int cravings;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final ink = erased ? lp.dangerText : lp.textPrimary;

    Widget tile(num value, String label, {String Function(num)? format}) =>
        Expanded(
          child: Column(
            children: [
              RollingNumber(
                erased ? 0 : value,
                style: LpType.number(ink, size: 22),
                format: format,
                duration: LpMotion.normal,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: LpType.caption(lp.textSecondary),
              ),
            ],
          ),
        );

    return AnimatedContainer(
      duration: LpMotion.fast,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      decoration: BoxDecoration(
        color: erased ? lp.dangerSoft : lp.surface,
        borderRadius: BorderRadius.circular(LpDimens.rCard),
        border: Border.all(
          color: erased ? lp.danger.withValues(alpha: 0.45) : lp.border,
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tile(streak, l10n.newPlanStatStreak(erased ? 0 : streak)),
          tile(
            saved,
            l10n.homeSavedSoFar,
            format: (v) => LpFormat.money(v, locale),
          ),
          tile(badges, l10n.profileBadgesEarned),
          tile(cravings, l10n.homeCravingsBeaten),
        ],
      ),
    );
  }
}

/// The confirmation a scratch start has to pass, and the place it happens.
///
/// Modelled on account deletion, the other erase in the app: not dismissible
/// by a stray tap, the destructive action in the danger colour, and the
/// server's half AWAITED inside the dialog (`eraseServerHistory`) with a
/// spinner on the button. It pops `true` only once that has landed; the
/// screen then leaves and erases the journey. A failure closes the dialog and
/// shows the standard offline/generic copy with nothing changed — the account
/// is exactly as it was, so trying again is simply the same tap.
///
/// It lists what goes in plain words, the coach included, and what stays —
/// the subscription above all, because somebody paying must not read "erase"
/// as "cancel".
class _FreshStartDialog extends ConsumerStatefulWidget {
  const _FreshStartDialog({required this.erase});

  /// The server erase, and the commit when nobody is left to make it.
  final Future<void> Function() erase;

  @override
  ConsumerState<_FreshStartDialog> createState() => _FreshStartDialogState();
}

class _FreshStartDialogState extends ConsumerState<_FreshStartDialog> {
  bool _busy = false;

  Future<void> _erase() async {
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      await widget.erase();
    } on Object catch (error) {
      if (!mounted) return;
      navigator.pop(false);
      // Offline, nothing was erased on either side. A request that reached
      // the server and lost its answer may have erased some of it — the
      // erase is idempotent, so either way trying again is the same tap and
      // the standard offline/generic copy is right. Shown from this context
      // the way account deletion does: the route is still in the tree for
      // its exit animation.
      unawaited(showLpErrorDialog(context, error: error));
      return;
    }
    if (!mounted) return;
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lp = context.lp;
    final coachName = ref.watch(coachNameProvider) ?? l10n.coachName;
    final goes = [
      l10n.newPlanFreshGoesLog,
      l10n.newPlanFreshGoesStreak,
      l10n.newPlanFreshGoesCravings,
      l10n.newPlanFreshGoesGoals,
      l10n.newPlanFreshGoesCoach(coachName),
    ];
    return PopScope(
      // The system Back gesture is a stray tap too, while the erase is out.
      canPop: !_busy,
      child: AlertDialog(
        title: Text(l10n.newPlanFreshDialogTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.newPlanFreshDialogIntro),
              const SizedBox(height: 10),
              for (final line in goes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.remove_circle_outline,
                          size: 16,
                          color: lp.dangerText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(line, style: LpType.body14(lp.textPrimary)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                l10n.newPlanFreshStays,
                style: LpType.body13(lp.textSecondary),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.newPlanFreshNoUndo,
                style: LpType.body14(lp.dangerText, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: Text(
              l10n.commonCancel,
              style: LpType.body14(lp.textSecondary),
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _erase,
            child: _busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: lp.dangerText,
                    ),
                  )
                : Text(
                    l10n.newPlanFreshConfirm,
                    style: LpType.body14(
                      lp.dangerText,
                      weight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
