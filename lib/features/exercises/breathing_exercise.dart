import 'package:material_ui/material_ui.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_haptics.dart';
import '../panic/breath_pacer.dart';
import '../panic/breath_ring.dart';

/// 4-7-8 breathing as an exercise of its own: the takeover's ring, verb and
/// countdown, without the takeover around them.
///
/// The body of the `breathing` exercise, hosted by `ExerciseScaffold`. It
/// reads no provider and knows nothing about cravings: it is a ring on a
/// repeating controller, captioned from below (the orb stays empty, because
/// a circle with a word in it reads as a button), with the same haptic
/// rhythm as the takeover's first step. Whatever replaces it later replaces
/// this file and nothing else.
class BreathingExercise extends StatefulWidget {
  const BreathingExercise({super.key});

  @override
  State<BreathingExercise> createState() => _BreathingExerciseState();
}

class _BreathingExerciseState extends State<BreathingExercise>
    with SingleTickerProviderStateMixin {
  static const _pacer = BreathPacer();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _pacer.cycle,
  )..repeat();

  /// Null until the first tick, so opening the screen gets the phase haptic
  /// that marks the start of the first inhale.
  BreathPhase? _phase;
  int _remaining = _pacer.inhale;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTick);
  }

  void _onTick() {
    final moment = _pacer.at(_controller.value);
    if (moment.phase != _phase) {
      _phase = moment.phase;
      _remaining = moment.remaining;
      LpHaptics.light();
      setState(() {});
    } else if (moment.remaining != _remaining) {
      _remaining = moment.remaining;
      // The haptics breathe with the ring: a soft tick each second while
      // inhaling and exhaling, silence through the hold.
      if (moment.phase != BreathPhase.hold) LpHaptics.tick();
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
    final label = switch (_phase ?? BreathPhase.inhale) {
      BreathPhase.inhale => l10n.panicBreatheIn,
      BreathPhase.hold => l10n.panicBreatheHold,
      BreathPhase.exhale => l10n.panicBreatheOut,
    };
    // The ring sizes itself to the room it is given: a short phone gets a
    // smaller ring, and one too short even for that scrolls. Bounded boxes
    // only, no IntrinsicHeight around an animated size.
    return LayoutBuilder(
      builder: (context, constraints) {
        final ring = (constraints.maxHeight - 196).clamp(160.0, 272.0);
        return Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.panicBreatheInstruction,
                  textAlign: TextAlign.center,
                  style: LpType.body15(lp.textPrimary, weight: FontWeight.w500),
                ),
                const SizedBox(height: 20),
                BreathRing(animation: _controller, pacer: _pacer, size: ring),
                const SizedBox(height: 16),
                // The verb crossfades on the same beat as the haptic.
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
                const SizedBox(height: 8),
                Text(
                  l10n.panicBreathePattern,
                  textAlign: TextAlign.center,
                  style: LpType.body14(lp.textSecondary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
