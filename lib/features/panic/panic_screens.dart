import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../core/widgets/confetti_burst.dart';
import '../../core/widgets/lp_buttons.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_misc.dart';
import '../../core/widgets/lp_selectables.dart';
import '../../core/widgets/press_scale.dart';
import '../../core/widgets/rolling_number.dart';
import '../../data/stores/providers.dart';
import '../../domain/analytics/lp_events.dart';
import '../../domain/models/models.dart';
import 'breath_pacer.dart';
import 'breath_ring.dart';

/// Session state shared by the three panic steps (feature-local VM).
class PanicSession {
  const PanicSession({
    this.step = 0,
    this.intensity = 7,
    this.startedAt,
    this.availability = PanicAvailability.unknown,
  });

  final int step;
  final int intensity;
  final DateTime? startedAt;

  /// What the server said when this session opened. Starts optimistic and is
  /// only ever narrowed by a reply that actually arrived.
  final PanicAvailability availability;

  PanicSession copyWith({
    int? step,
    int? intensity,
    DateTime? startedAt,
    PanicAvailability? availability,
  }) => PanicSession(
    step: step ?? this.step,
    intensity: intensity ?? this.intensity,
    startedAt: startedAt ?? this.startedAt,
    availability: availability ?? this.availability,
  );
}

class PanicViewModel extends Notifier<PanicSession> {
  @override
  PanicSession build() {
    ref.onDispose(() => _disposed = true);
    _openSession();
    return PanicSession(startedAt: DateTime.now());
  }

  /// True once the session reached a recorded outcome, so an abandoned flow
  /// can be told apart from a survived one.
  bool _resolved = false;

  /// The flow can close (or `survive()` can invalidate this notifier) while
  /// the availability call is still in flight; writing `state` after that
  /// throws.
  bool _disposed = false;

  /// Tells the server a craving started, and folds the answer in when it
  /// arrives. Deliberately not awaited anywhere: the breathing screen is
  /// already on screen before this resolves, which is the point — a craving
  /// does not wait on a round-trip (docs/04 §7).
  void _openSession() {
    ref.read(panicRepositoryProvider).begin().then((availability) {
      // The notifier may already be gone (flow closed mid-flight).
      if (!_disposed) state = state.copyWith(availability: availability);
    }).ignore();
  }

  void next() => state = state.copyWith(step: state.step + 1);

  void skipToWhy() => state = state.copyWith(step: 1);

  /// Frame-map preview: open the takeover at a specific step.
  void previewStep(int step) =>
      state = PanicSession(startedAt: DateTime.now(), step: step);

  void setIntensity(int value) => state = state.copyWith(intensity: value);

  Duration get elapsed => DateTime.now().difference(state.startedAt!);

  /// Craving survived → celebrate, then reset for the next session.
  void survive() {
    _resolved = true;
    ref.read(analyticsProvider).cravingSurvived(survived: true);
    ref
        .read(panicRepositoryProvider)
        .survived(intensity: state.intensity)
        .ignore();
    ref.read(quitStoreProvider.notifier).recordCravingSurvived();
    ref.invalidateSelf();
  }

  /// The takeover closed without "it passed" being tapped.
  ///
  /// Reported to analytics only, never to the server: leaving the flow is not
  /// the same claim as slipping, and `panicSession` records outcomes people
  /// actually stated. The guardrail rate (docs/06 §1, craving-survived ≥ 70%)
  /// reads sessions-opened as its denominator either way.
  void abandon() {
    if (_resolved) return;
    _resolved = true;
    ref.read(analyticsProvider).cravingSurvived(survived: false);
  }
}

final panicProvider = NotifierProvider<PanicViewModel, PanicSession>(
  PanicViewModel.new,
);

/// Frames 32–34 — the full-screen craving takeover on the Oxygen ground.
class PanicFlow extends ConsumerStatefulWidget {
  const PanicFlow({super.key});

  @override
  ConsumerState<PanicFlow> createState() => _PanicFlowState();
}

class _PanicFlowState extends ConsumerState<PanicFlow> {
  /// Captured in [initState], not read in [dispose].
  ///
  /// Riverpod throws "Cannot use ref after the widget was disposed" for a
  /// `ref.read` inside `dispose`, so the reference has to be taken while the
  /// element is still alive. Holding the instance is also what makes the
  /// resolved check correct: `survive()` invalidates the provider, so a later
  /// read would hand back a FRESH notifier with `_resolved == false` and every
  /// survived craving would be reported abandoned as well.
  late final PanicViewModel _session = ref.read(panicProvider.notifier);

  @override
  void initState() {
    super.initState();
    _session; // resolve now, while ref is still usable
    // The takeover owns the whole screen — a lingering "Logged 1 puff"
    // undo snack must never cover the step controls.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
    });
  }

  @override
  void dispose() {
    // `survive()` marks the session resolved before this runs, so a survived
    // craving is never double-counted as an abandoned one.
    _session.abandon();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final session = ref.watch(panicProvider);
    return Scaffold(
      backgroundColor: lp.panicBackground,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: LpMotion.normal,
          child: KeyedSubtree(
            key: ValueKey(session.step),
            child: switch (session.step) {
              0 => const _BreatheStep(),
              1 => const _WhyStep(),
              _ => const _BreakLoopStep(),
            },
          ),
        ),
      ),
    );
  }
}

/// Live mm:ss craving timer pill ("peaks ~15 min").
class _CravingTimer extends ConsumerStatefulWidget {
  const _CravingTimer({this.late = false});

  final bool late;

  @override
  ConsumerState<_CravingTimer> createState() => _CravingTimerState();
}

class _CravingTimerState extends ConsumerState<_CravingTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final elapsed = ref.read(panicProvider.notifier).elapsed;
    final label = widget.late || elapsed.inMinutes >= 5
        ? l10n.panicCravingTimerLate(LpFormat.timer(elapsed))
        : l10n.panicCravingTimer(LpFormat.timer(elapsed));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: lp.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(LpDimens.rChip),
        border: Border.all(color: lp.border, width: 1.5),
      ),
      child: Text(label, style: LpType.body13(lp.textSecondary)),
    );
  }
}

/// Step 1 — 4-7-8 breathing ring with matching haptic rhythm.
///
/// QA Sep 1 (docs/09 §7): the ring read as a pressed button. The orb at rest
/// was 80% of full, the label was a single word and nothing told the user to
/// breathe. Now the instruction is on screen from the first frame, the verb
/// says what to do, the orb rests at 40% so the first second of inhale is a
/// quarter of its size, and a pointer laps the track so the hold still moves.
class _BreatheStep extends ConsumerStatefulWidget {
  const _BreatheStep();

  @override
  ConsumerState<_BreatheStep> createState() => _BreatheStepState();
}

class _BreatheStepState extends ConsumerState<_BreatheStep>
    with SingleTickerProviderStateMixin {
  static const _pacer = BreathPacer();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _pacer.cycle,
  )..repeat();

  /// Null until the first tick, so entering the screen gets the phase haptic
  /// that marks the start of the first inhale.
  BreathPhase? _phase;
  int _remaining = _pacer.inhale;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTick);
  }

  void _onTick() {
    final m = _pacer.at(_controller.value);
    if (m.phase != _phase) {
      _phase = m.phase;
      _remaining = m.remaining;
      LpHaptics.light();
      setState(() {});
    } else if (m.remaining != _remaining) {
      _remaining = m.remaining;
      // Frame 32: the haptics breathe with the ring — a soft tick each
      // second while inhaling/exhaling, silence through the hold.
      if (m.phase != BreathPhase.hold) LpHaptics.tick();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final vm = ref.read(panicProvider.notifier);
    final label = switch (_phase ?? BreathPhase.inhale) {
      BreathPhase.inhale => l10n.panicBreatheIn,
      BreathPhase.hold => l10n.panicBreatheHold,
      BreathPhase.exhale => l10n.panicBreatheOut,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 40),
      child: Column(
        children: [
          Text(
            l10n.panicStepLabel(1),
            style: LpType.body13(
              lp.oxygenText,
              weight: FontWeight.w600,
            ).copyWith(letterSpacing: 2),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.panicBreatheNote,
            textAlign: TextAlign.center,
            style: LpType.body13(lp.textSecondary),
          ),
          // The middle takes whatever the header and footer leave, and the
          // ring sizes itself to it — a 5" phone gets a smaller ring, never
          // an overflow. Bounded boxes only: no IntrinsicHeight around an
          // animated size.
          //
          // The orb is EMPTY and the verb + count caption it from below
          // (Apple Watch Breathe, Headspace). A circle with a label in it is
          // a button by convention, and a resting orb is narrower than any
          // 28-px verb — the rim cut straight through "Breathe out".
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final ring = (constraints.maxHeight - 168).clamp(160.0, 272.0);
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.panicBreatheInstruction,
                        textAlign: TextAlign.center,
                        style: LpType.body15(
                          lp.textPrimary,
                          weight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      BreathRing(
                        animation: _controller,
                        pacer: _pacer,
                        size: ring,
                      ),
                      const SizedBox(height: 16),
                      // The verb crossfades on the same beat as the haptic
                      // instead of snapping.
                      AnimatedSwitcher(
                        duration: LpMotion.fast,
                        child: Text(
                          label,
                          key: ValueKey(label),
                          textAlign: TextAlign.center,
                          style: LpType.heading(lp.oxygenText, size: 28),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_remaining',
                        style: LpType.number(lp.textPrimary, size: 34),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Text(
            l10n.panicBreathePattern,
            style: LpType.body14(lp.textSecondary),
          ),
          const SizedBox(height: 22),
          const _CravingTimer(),
          const SizedBox(height: 18),
          PressScale(
            onTap: vm.next,
            child: Text(
              l10n.panicSkipToWhy,
              style: LpType.body13(lp.oxygenText, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Step 2 — the user's own whys + live intensity slider.
class _WhyStep extends ConsumerWidget {
  const _WhyStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final session = ref.watch(panicProvider);
    final vm = ref.read(panicProvider.notifier);
    final journey = ref.watch(quitStoreProvider);
    if (journey == null) return const SizedBox.shrink();
    final whys = journey.profile.whys;
    final firstWhy = whys.isEmpty
        ? l10n.obWhyHealth.toLowerCase()
        : whys.first.label(context).toLowerCase();
    final yearly = LpFormat.money(journey.plan.weeklySpend * 52, locale);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              l10n.panicStepLabel(2),
              style: LpType.body13(
                lp.oxygenText,
                weight: FontWeight.w600,
              ).copyWith(letterSpacing: 2),
            ),
          ),
          const SizedBox(height: 28),
          Text(l10n.panicWhyTitle, style: LpType.title(lp.textPrimary)),
          const SizedBox(height: 22),
          LpCard(
            radius: LpDimens.rCardLg,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(l10n.panicYouSaid),
                Text(
                  l10n.panicWhyLine(firstWhy, yearly),
                  style: LpType.body15(lp.textPrimary).copyWith(height: 1.6),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final why in whys)
                      StaticChip(why.label(context), small: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LpCard(
            radius: LpDimens.rCardLg,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.panicIntensityQuestion,
                      style: LpType.body13(lp.textSecondary),
                    ),
                    Text(
                      '${session.intensity}/10',
                      style: LpType.displaySmall(lp.oxygenText, size: 15),
                    ),
                  ],
                ),
                Slider(
                  value: session.intensity.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  onChanged: (v) {
                    LpHaptics.tick();
                    vm.setIntensity(v.round());
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.panicIntensityLow,
                      style: LpType.caption11(lp.textSecondary),
                    ),
                    Text(
                      l10n.panicIntensityHigh,
                      style: LpType.caption11(lp.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          LpButton(
            l10n.panicStillCraving,
            style: LpButtonStyle.oxygen,
            onTap: vm.next,
          ),
          const SizedBox(height: 6),
          LpTextButton(
            l10n.panicItPassed,
            onTap: () {
              vm.survive();
              context.pushReplacement(Routes.survived);
            },
          ),
        ],
      ),
    );
  }
}

/// Step 3 — break the loop: game / buddy / coach. Every path can end at 35.
class _BreakLoopStep extends ConsumerWidget {
  const _BreakLoopStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final danger = ref.watch(todayProvider)?.dangerWindow;
    final hourLabel = LpFormat.hour(danger?.$1 ?? 22, context.localeTag);
    // docs/04 §7: past the free allowance the AI layer drops away — the
    // option stays on screen and routes to the paywall instead of
    // disappearing, because a door that vanishes mid-craving reads as the app
    // giving up on you.
    final session = ref.watch(panicProvider);
    final aiAvailable = session.availability.aiAvailable;

    Widget option({
      required Widget icon,
      required Color tint,
      required String title,
      required String sub,
      required VoidCallback onTap,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PressScale(
        onTap: onTap,
        child: LpCard(
          radius: LpDimens.rCardLg,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: tint.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: icon,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: LpType.emphasis(lp.textPrimary)),
                    const SizedBox(height: 3),
                    Text(sub, style: LpType.caption(lp.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: lp.textSecondary),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              l10n.panicStepLabel(3),
              style: LpType.body13(
                lp.oxygenText,
                weight: FontWeight.w600,
              ).copyWith(letterSpacing: 2),
            ),
          ),
          const SizedBox(height: 28),
          Text(l10n.panicLoopTitle, style: LpType.title(lp.textPrimary)),
          const SizedBox(height: 8),
          Text(l10n.panicLoopSubtitle, style: LpType.body14(lp.textSecondary)),
          const SizedBox(height: 26),
          // The four loop-breakers scroll; the timer and the "it passed" CTA
          // below stay pinned where a craving needs to find them.
          //
          // Found on a real device: a 26px overflow stripe on the third panic
          // step. Four options with subtitles do not fit every viewport, and
          // they grew when the buddy option became the longer SOS one.
          //
          // Deliberately NOT the `StepScrollView` idiom the auth forms use.
          // That is min-height + `IntrinsicHeight`, and an intrinsic walk over
          // the animating `_CravingTimer` below is the exact combination that
          // took the Health screen down — it crashed this screen outright when
          // tried here. `Expanded` takes the slack instead, so there is no
          // intrinsic pass at all.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  option(
                    icon: const Text('🎮', style: TextStyle(fontSize: 22)),
                    tint: lp.volt,
                    title: l10n.panicLoopGame,
                    sub: l10n.panicLoopGameSub,
                    onTap: () => context.push(Routes.game),
                  ),
                  // The social loop-breaker (docs/03 §7). This used to be "ping your
                  // buddy", which pinged nobody: Quit Buddies was descoped in Aug 2026
                  // and the buddy it named was invented by the app. The stage it
                  // occupies in the hook — someone else pulling you out — is real and
                  // worth keeping, so it now opens the composer pre-tagged SOS. Live
                  // SOS posts pin to the top of the feed for an hour and real quitters
                  // answer them, which is what the fake ping was pretending to do.
                  option(
                    icon: const Text('🆘', style: TextStyle(fontSize: 22)),
                    tint: lp.ember,
                    title: l10n.panicLoopSos,
                    sub: l10n.panicLoopSosSub,
                    onTap: () {
                      LpHaptics.medium();
                      context.push('${Routes.compose}?tag=${PostTag.sos.name}');
                    },
                  ),
                  option(
                    icon: Text(
                      'AI',
                      style: LpType.displaySmall(lp.oxygenText, size: 16),
                    ),
                    tint: lp.oxygen,
                    title: l10n.panicLoopCoach,
                    sub: aiAvailable
                        ? l10n.panicLoopCoachSub(hourLabel)
                        : l10n.panicLoopCoachLocked,
                    // The intensity rides along: `aiCoachChat` switches to its short,
                    // directive PANIC MODE voice when it is present, and until now no
                    // client ever sent it — so Ember answered a 9/10 craving in the
                    // same open-question register it uses for a quiet Tuesday.
                    onTap: () => aiAvailable
                        ? context.go(
                            '${Routes.coach}?panic=${session.intensity}',
                          )
                        : context.push(Routes.paywall),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: _CravingTimer(late: true)),
          const SizedBox(height: 14),
          LpTextButton(
            l10n.panicItPassed,
            onTap: () {
              ref.read(panicProvider.notifier).survive();
              context.pushReplacement(Routes.survived);
            },
          ),
        ],
      ),
    );
  }
}

/// The 60-second tap game — sparks appear, thumbs stay busy.
class TapGameScreen extends ConsumerStatefulWidget {
  const TapGameScreen({super.key});

  @override
  ConsumerState<TapGameScreen> createState() => _TapGameScreenState();
}

class _TapGameScreenState extends ConsumerState<TapGameScreen> {
  static const _gameLength = 60;
  final _random = math.Random();
  Timer? _tick;
  int _secondsLeft = _gameLength;
  int _score = 0;
  Offset _sparkAlign = const Offset(0, -0.2);
  double _sparkSize = 64;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        ref.read(panicProvider.notifier).survive();
        context.pushReplacement(Routes.survived);
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _catchSpark() {
    LpHaptics.light();
    setState(() {
      _score++;
      _sparkAlign = Offset(
        _random.nextDouble() * 1.6 - 0.8,
        _random.nextDouble() * 1.2 - 0.5,
      );
      _sparkSize = 48 + _random.nextDouble() * 32;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: lp.panicBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BackChevron(onTap: () => context.pop()),
                  Text(
                    l10n.gameTimeLeft(_secondsLeft),
                    style: LpType.number(lp.oxygenText, size: 24),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '$_score ✦',
                      textAlign: TextAlign.right,
                      style: LpType.displaySmall(lp.voltText, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(l10n.gameTitle, style: LpType.titleSm(lp.textPrimary)),
              Text(l10n.gameSubtitle, style: LpType.caption(lp.textSecondary)),
              Expanded(
                child: Stack(
                  children: [
                    AnimatedAlign(
                      duration: LpMotion.fast,
                      curve: LpMotion.spring,
                      alignment: Alignment(_sparkAlign.dx, _sparkAlign.dy),
                      child: PressScale(
                        onTap: _catchSpark,
                        haptic: false,
                        child: Container(
                          width: _sparkSize,
                          height: _sparkSize,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: lp.volt,
                            boxShadow: lp.voltGlow(blur: 28, opacity: 0.5),
                          ),
                          child: Text(
                            '✦',
                            style: TextStyle(
                              fontSize: _sparkSize * 0.4,
                              color: lp.onVolt,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Frame 35 — craving survived. Confetti, rolling counter, share the W.
class SurvivedScreen extends ConsumerStatefulWidget {
  const SurvivedScreen({super.key});

  @override
  ConsumerState<SurvivedScreen> createState() => _SurvivedScreenState();
}

class _SurvivedScreenState extends ConsumerState<SurvivedScreen> {
  late final int _lineIndex;

  @override
  void initState() {
    super.initState();
    // Variable reward: rotate through celebration lines (docs/03 §7).
    _lineIndex = math.Random().nextInt(8);
    LpHaptics.celebrate();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final total = ref.watch(todayProvider)?.cravingsSurvivedTotal ?? 0;
    final line = [
      l10n.survivedLine1,
      l10n.survivedLine2,
      l10n.survivedLine3,
      l10n.survivedLine4,
      l10n.survivedLine5,
      l10n.survivedLine6,
      l10n.survivedLine7,
      l10n.survivedLine8,
    ][_lineIndex];

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  const Center(
                    child: Text('🎉', style: TextStyle(fontSize: 60)),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      l10n.survivedPlusOne,
                      style: LpType.title(lp.textPrimary, size: 36),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(line, style: LpType.body15(lp.textSecondary)),
                  ),
                  const SizedBox(height: 34),
                  Center(
                    child: LpCard(
                      radius: LpDimens.rCardLg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 20,
                      ),
                      child: Column(
                        children: [
                          // Frame 35: the counter rolls 22 → 23.
                          RollingNumber(
                            total,
                            from: total > 0 ? total - 1 : 0,
                            style: LpType.numberHero(lp.voltText, size: 52)
                                .copyWith(
                                  shadows: [
                                    Shadow(
                                      color: lp.volt.withValues(alpha: 0.45),
                                      blurRadius: 36,
                                    ),
                                  ],
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.survivedTotalLabel,
                            style: LpType.body13(lp.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Center(
                    child: PressScale(
                      onTap: () async {
                        // Anonymous stat card as text — no personal data.
                        await Clipboard.setData(
                          ClipboardData(
                            text:
                                '🎉 ${l10n.survivedPlusOne} · $total ${l10n.survivedTotalLabel} · ${l10n.appName}',
                          ),
                        );
                        if (context.mounted) {
                          showLpSnack(context, l10n.survivedShareCopied);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: lp.surface,
                          borderRadius: BorderRadius.circular(LpDimens.rChip),
                          border: Border.all(color: lp.border, width: 1.5),
                        ),
                        child: Text(
                          l10n.survivedShare,
                          style: LpType.body13(
                            lp.textPrimary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  LpButton(
                    l10n.survivedBack,
                    onTap: () => context.go(Routes.home),
                  ),
                ],
              ),
            ),
          ),
          const Positioned.fill(child: ConfettiBurst()),
        ],
      ),
    );
  }
}
