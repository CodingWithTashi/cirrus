import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../domain/logic/exercises/exercise.dart';
import '../../../domain/models/coach_ui.dart';
import 'coach_catalog.dart';

/// The cards under Ember's newest reply.
///
/// This is the whole of the app's side of `a2ui_flutter`, and the package
/// stops here: this file's public names carry none of its types, so the
/// coach screen holds a controller and a view and never learns what draws
/// them. The package is pre-1.0 and has broken on every minor release;
/// upgrading it is a change to this folder and its test.
///
/// One controller per thread, and it shows ONE reply's cards at a time: a
/// reply's cards are an answer to that reply, like its follow-up chips, so
/// nothing stale stays in the scrollback.
///
/// The rule it exists to keep: the cards are extra. A surface the package
/// will not take, or one that fails while it is drawn, is taken down whole
/// and reported once; it draws no error, and it never touches the words it
/// would have sat under.
class CoachSurfaceController {
  CoachSurfaceController({
    required void Function(int launchers) onShown,
    required void Function() onDropped,
  }) : _onShown = onShown,
       _onDropped = onDropped;

  final void Function(int launchers) _onShown;
  final void Function() _onDropped;

  /// What the view draws: the live surface, or null for nothing at all.
  final ValueNotifier<SurfaceModel<ComponentImplementation>?> _surface =
      ValueNotifier(null);

  /// Made on the first reply that carries a card, and kept for the thread.
  /// Most accounts never get one, so most threads never build it.
  MessageProcessor<ComponentImplementation>? _processor;

  Subscription? _errors;

  /// The message whose cards are up (or were asked for and refused), and the
  /// cards themselves. Both, because Ember's bubble exists before its
  /// envelope does: the words stream into a message that has no cards yet,
  /// and the finished message keeps that id.
  String? _messageId;
  List<CoachBlock> _blocks = const [];

  /// The messages already reported, each way. A retry takes two bubbles
  /// down, which makes an older reply the newest one for a moment: its cards
  /// come back, and it is not counted a second time.
  String? _countedShown;
  String? _countedDropped;

  /// Bumped on every change, so a report from a surface that has since been
  /// replaced (they arrive a microtask late) cannot take down its successor.
  int _generation = 0;
  int _surfaces = 0;
  bool _disposed = false;

  /// Shows [blocks] as the cards of the message [messageId], in place of
  /// whatever was showing. The same message with the same cards is a no-op.
  /// No blocks is nothing at all: no surface, no size, no report.
  void show(String messageId, List<CoachBlock> blocks) {
    if (_disposed) return;
    if (messageId == _messageId && listEquals(blocks, _blocks)) return;
    _take(messageId, blocks);
    if (blocks.isEmpty) return;
    final surfaceId = 'coach${_surfaces++}';
    _present(
      messageId,
      surfaceId: surfaceId,
      payload: coachUiMessages(surfaceId, blocks),
      launchers: blocks.length,
    );
  }

  /// [show] for a payload written by hand: what a test needs to hand the
  /// package something [coachUiMessages] can never produce.
  @visibleForTesting
  void showRaw(
    String messageId, {
    required String surfaceId,
    required Object? payload,
    int launchers = 1,
  }) {
    if (_disposed) return;
    _take(messageId, const []);
    _present(
      messageId,
      surfaceId: surfaceId,
      payload: payload,
      launchers: launchers,
    );
  }

  /// Takes the cards down. What has been reported stays reported.
  void clear() {
    if (_disposed) return;
    _take(null, const []);
  }

  void dispose() {
    if (_disposed) return;
    _take(null, const []);
    _disposed = true;
    try {
      _processor?.dispose();
    } catch (_) {
      // Nothing to tell anybody: the screen is going away.
    }
    _processor = null;
    _surface.dispose();
  }

  /// Removes what is up and records what is wanted next.
  void _take(String? messageId, List<CoachBlock> blocks) {
    _generation++;
    _messageId = messageId;
    _blocks = blocks;
    _errors?.unsubscribe();
    _errors = null;
    final current = _surface.value;
    if (current == null) return;
    // The view first, the surface second: the package asks that its widget
    // is not left drawing a surface that has been deleted.
    _surface.value = null;
    try {
      _processor?.processMessages(coachUiDelete(current.id));
    } catch (_) {
      // A surface that will not go quietly is still gone from the screen,
      // and its processor is disposed with the thread.
    }
  }

  void _present(
    String messageId, {
    required String surfaceId,
    required Object? payload,
    required int launchers,
  }) {
    final generation = _generation;
    try {
      final processor = _processor ??=
          MessageProcessor<ComponentImplementation>(
            catalogs: [coachCatalog()],
            // Strict: an unknown component, an undeclared property, a value
            // outside an enum, a child that is not there. Each refuses the
            // whole surface, which is what lets a card carry an id and
            // nothing else.
            validationConfig: ValidationConfig.strict,
          );
      processor.processMessages(payload);
      final surface = processor.model.getSurface(surfaceId);
      if (surface == null) {
        // Taken without complaint, and nothing to show for it.
        _drop(messageId, generation);
        return;
      }
      // What the package finds while it DRAWS arrives here, a microtask
      // after the build that found it.
      _errors = surface.onError.subscribe((_) => _drop(messageId, generation));
      _surface.value = surface;
    } on A2uiError {
      // The package's own refusal: the payload did not pass its catalog.
      _drop(messageId, generation);
      return;
    } catch (_) {
      // Anything else a pre-1.0 package throws on the way (a cast, a state
      // error). Same outcome: the reply stands without its cards.
      _drop(messageId, generation);
      return;
    }
    if (_countedShown != messageId) {
      _countedShown = messageId;
      _onShown(launchers);
    }
  }

  /// The cards of [messageId] are not going to be drawn. Reported once per
  /// message, and only while that message is still the one wanted.
  void _drop(String messageId, int generation) {
    if (_disposed || generation != _generation) return;
    _take(messageId, _blocks);
    if (_countedDropped == messageId) return;
    _countedDropped = messageId;
    _onDropped();
  }
}

/// Draws what [controller] is showing: the cards, in a column as wide as the
/// week card beside them in the thread, or nothing at all (zero size, so an
/// empty one costs the thread no gap).
///
/// No intrinsic-size widget above the surface and no layout callback inside
/// it: either one fails layout outright on the first frame.
class CoachSurfaceView extends StatelessWidget {
  const CoachSurfaceView({
    super.key,
    required this.controller,
    required this.source,
    this.padding = EdgeInsets.zero,
  });

  final CoachSurfaceController controller;

  /// Where a card tapped here was opened from.
  final ExerciseSource source;

  /// Space around the cards, when there are cards.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller._surface,
      builder: (context, surface, _) {
        if (surface == null) return const SizedBox.shrink();
        return Padding(
          padding: padding,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width * 0.82,
              child: CoachSurfaceScope(
                source: source,
                child: A2uiSurface(surface: surface),
              ),
            ),
          ),
        );
      },
    );
  }
}
