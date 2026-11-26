import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../../../domain/logic/exercises/exercise.dart';
import '../../../domain/models/coach_ui.dart';
import '../../exercises/exercise_launcher_card.dart';

/// The coach catalog: everything a card under an Ember reply can be made of.
///
/// Two components, both the app's own. The package ships a catalog of its
/// own as well (text, buttons, images, a video player); this folder never
/// names it, for two reasons that are both pinned by tests. A surface built
/// from it could say anything, where one built from this can only choose
/// among exercises this build knows how to open. And it is written against
/// the SDK's Material, a separate set of classes from the `material_ui` the
/// app is on, so one reference links a second copy of Material into the
/// binary (`test/app/a2ui_seam_test.dart`).
///
/// The id is a name, not an address: nothing is ever fetched from it.
const String coachCatalogId =
    'https://cirrusquit.com/a2ui/coach/v1/catalog.json';

const String _stack = 'CoachStack';
const String _launcher = 'ExerciseLauncher';

/// A new one per call: a catalog caches what it derives from its schemas, and
/// the one processor a thread keeps is the only thing that needs it.
CatalogImplementation coachCatalog() => CatalogImplementation(
  id: coachCatalogId,
  protocolVersion: A2uiProtocolVersion.v1_0,
  components: [
    // The cards, top to bottom. A static list of ids and nothing else: no
    // template, no alignment, no weights.
    ComponentImplementation(
      name: _stack,
      schema: Schema.object(
        properties: {
          // Marked as component ids, which is how the processor knows these
          // are references: a child that is not on the surface is refused.
          'children': Schema.list(items: CommonSchemas.componentId),
        },
        required: ['children'],
        additionalProperties: false,
      ),
      builder: _buildStack,
    ),
    // One card. The whole payload is an exercise id, and the ids are the
    // registry's, so a new exercise is drawable the moment it has a row.
    ComponentImplementation(
      name: _launcher,
      schema: Schema.object(
        properties: {
          'exercise': Schema.string(
            enumValues: [for (final id in ExerciseId.values) id.name],
          ),
        },
        required: ['exercise'],
        additionalProperties: false,
      ),
      builder: _buildLauncher,
    ),
  ],
);

/// A plain [Column], on purpose. The package's own column measures itself
/// with a layout callback, and a widget that does cannot answer an
/// intrinsic-height walk at all: it throws, and it takes down whatever
/// screen put the walk above it (the Health screen was lost that way once).
Widget _buildStack(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  spacing: 8,
  children: [
    // A child that has not resolved draws nothing; leaving it out as well
    // keeps it from being given a gap.
    for (final child in props.children('children'))
      if (!child.isPlaceholder) buildChild(child),
  ],
);

Widget _buildLauncher(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  // The schema's enum already refused anything else. Parsed all the same, so
  // a value that somehow got past it draws nothing rather than throwing
  // inside a build.
  final id = Exercises.parse(props.string('exercise'));
  if (id == null) return const SizedBox.shrink();
  return ExerciseLauncherCard(id: id, source: CoachSurfaceScope.of(context));
}

/// Where the cards below were offered from. It comes from the view, never
/// from the surface: a block carries an id and nothing else, so the source
/// cannot ride on it.
class CoachSurfaceScope extends InheritedWidget {
  const CoachSurfaceScope({
    super.key,
    required this.source,
    required super.child,
  });

  final ExerciseSource source;

  static ExerciseSource of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CoachSurfaceScope>()?.source ??
      ExerciseSource.coach;

  @override
  bool updateShouldNotify(CoachSurfaceScope oldWidget) =>
      oldWidget.source != source;
}

/// [blocks] as A2UI v1.0: ONE `createSurface` that carries its components,
/// rooted at a stack whose children are `c0…cN`.
///
/// Built here, on the device, from typed blocks. A2UI is not what the server
/// sends: every installed build keeps its own strict validator for ever, and
/// strict validation drops a whole surface for one unknown value where a
/// block list drops one card.
List<Map<String, Object?>> coachUiMessages(
  String surfaceId,
  List<CoachBlock> blocks,
) => [
  {
    'version': A2uiProtocolVersion.v1_0.jsonValue,
    'createSurface': {
      'surfaceId': surfaceId,
      'catalogId': coachCatalogId,
      'components': [
        {
          'id': 'root',
          'component': _stack,
          'children': [for (var i = 0; i < blocks.length; i++) 'c$i'],
        },
        for (final (i, block) in blocks.indexed)
          switch (block) {
            CoachLauncherBlock(:final exercise) => {
              'id': 'c$i',
              'component': _launcher,
              'exercise': exercise.name,
            },
          },
      ],
    },
  },
];

/// The message that takes a surface down again.
Map<String, Object?> coachUiDelete(String surfaceId) => {
  'version': A2uiProtocolVersion.v1_0.jsonValue,
  'deleteSurface': {'surfaceId': surfaceId},
};
