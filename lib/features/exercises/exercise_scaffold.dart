import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/widgets/lp_buttons.dart';
import '../../core/widgets/lp_misc.dart';
import '../../data/stores/exercise_runs.dart';
import '../../data/stores/providers.dart';
import '../../domain/logic/exercises/exercise.dart';
import '../panic/games/intensity_row.dart';
import '../panic/panic_screens.dart';
import 'exercise_catalog.dart';
import 'exercise_run_filing.dart';

/// The frame around an exercise that runs on a screen of its own: the way
/// back, its name, the exercise itself ([body]), the "how strong is it now?"
/// row and "It passed".
///
/// An exercise brings its [body] and nothing else. Everything that makes it
/// part of a craving is here, once, and is the arena's contract exactly:
///
/// - **It is a craving's screen.** Opened from a coach card inside the
///   craving window it joins the craving the takeover parked (same clock,
///   same strength, same server session); opened cold it starts one. If it
///   owns the craving it parks it again on the way out (`PanicViewModel`).
/// - **Two exits.** "It passed" lands on the Survived screen and counts the
///   craving, once, through `PanicViewModel.survive`, the path every craving
///   takes. Back counts nothing.
/// - **Either way the run is filed** (`exerciseRunsProvider`), which is also
///   what reports `exercise_finished`.
class ExerciseScaffold extends ConsumerStatefulWidget {
  const ExerciseScaffold({
    super.key,
    required this.id,
    required this.source,
    required this.body,
    this.completedAfter = const Duration(seconds: 57),
  });

  final ExerciseId id;

  /// Where it was opened from; it decides where "It passed" leads back to.
  final ExerciseSource source;

  /// The exercise. It gets all the room the frame does not use.
  final Widget body;

  /// How long on this screen counts as having done the exercise. The default
  /// is three 4-7-8 breaths (19 seconds each).
  final Duration completedAfter;

  @override
  ConsumerState<ExerciseScaffold> createState() => _ExerciseScaffoldState();
}

class _ExerciseScaffoldState extends ConsumerState<ExerciseScaffold> {
  /// Captured in [initState]: both exits use them after the element may be
  /// on its way out, and Riverpod forbids `ref` there.
  late final PanicViewModel _session = ref.read(panicProvider.notifier);
  late final ExerciseRuns _runs = ref.read(exerciseRunsProvider.notifier);
  late final void Function(ExerciseRun run) _fileLater = ref.read(
    fileRunLaterProvider,
  );
  late final DateTime Function() _clock = ref.read(nowProvider);
  late final DateTime _openedAt = _clock();

  /// Whether this screen owns the craving (`PanicViewModel.ensureStarted`)
  /// and so parks it when it is left.
  bool _owns = false;

  /// Their answer to "how strong is it now?", if any.
  int? _intensityAfter;

  /// True once the run has been filed, so the screen "It passed" replaces
  /// does not file a second one from its dispose.
  bool _filed = false;

  @override
  void initState() {
    super.initState();
    _session; // resolve them now, while ref is still usable
    _runs;
    _fileLater;
    _openedAt;
    // After the frame, never during the build that pushed us: opening a
    // craving writes a provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _owns = _session.ensureStarted();
    });
  }

  @override
  void dispose() {
    // Left without "it passed": the craving is not over, so it is parked for
    // the next exercise to join. Plain fields only inside `park`.
    if (_owns) _session.park();
    // And the visit still happened. Filed after this frame, because a
    // provider write from `dispose` throws.
    if (!_filed) _fileLater(_run(passed: false));
    super.dispose();
  }

  ExerciseRun _run({required bool passed}) {
    final elapsed = _clock().difference(_openedAt);
    return ExerciseRun(
      id: widget.id,
      source: widget.source,
      seconds: elapsed.inSeconds,
      completed: elapsed >= widget.completedAfter,
      passed: passed,
    );
  }

  void _itPassed() {
    final run = _run(passed: true);
    _filed = true;
    // Leave first, then mutate: `survive` commits a journey change, and a
    // router refresh delivered after an imperative navigation undoes it.
    context.pushReplacement('${Routes.survived}?src=${widget.source.name}');
    _session.survive(
      intensityAfter: _intensityAfter,
      exercise: widget.id,
      source: widget.source,
    );
    _runs.report(run);
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: lp.panicBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            children: [
              Row(
                children: [
                  BackChevron(onTap: () => context.pop()),
                  Expanded(
                    child: Text(
                      ExerciseCatalog.of(widget.id).title(l10n),
                      textAlign: TextAlign.center,
                      style: LpType.titleSm(lp.textPrimary),
                    ),
                  ),
                  // The chevron's width again, so the title sits centred.
                  const SizedBox(width: 40),
                ],
              ),
              // Bounded by Expanded, never under an IntrinsicHeight an
              // animating body would choke.
              Expanded(child: widget.body),
              const SizedBox(height: 12),
              // Ten circles are 320 wide and a 360-wide phone leaves 312
              // inside this padding: scale the row down rather than let it
              // overflow.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: IntensityRow(
                  label: l10n.gameIntensityNow,
                  value: _intensityAfter,
                  onChanged: (value) => setState(() => _intensityAfter = value),
                ),
              ),
              const SizedBox(height: 10),
              LpTextButton(l10n.panicItPassed, onTap: _itPassed),
            ],
          ),
        ),
      ),
    );
  }
}
