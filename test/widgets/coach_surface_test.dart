import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/core/utils/l10n_ext.dart';
import 'package:last_puff/data/dto/coach_codec.dart';
import 'package:last_puff/domain/logic/exercises/exercise.dart';
import 'package:last_puff/domain/models/coach_ui.dart';
import 'package:last_puff/features/coach/surface/coach_catalog.dart';
import 'package:last_puff/features/coach/surface/coach_surface.dart';
import 'package:last_puff/features/exercises/exercise_launcher_card.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';

/// The coach surface: typed blocks in, the app's own cards out, drawn by
/// `a2ui_flutter` against a catalog of two components.
///
/// What this suite is for is the two ways it can go wrong without anybody
/// noticing. One: the server sends a card this renderer refuses, and the
/// reply it belongs to is damaged with it (Review Focus 7: the words stand,
/// nothing else renders, no error bubble, one `coach_ui_dropped`). Two: the
/// app and the server drift, which is why every fixture the server's policy
/// is pinned to is drawn here through the real processor.
void main() {
  const launcherBreathing = CoachLauncherBlock(ExerciseId.breathing);
  const launcherOrbs = CoachLauncherBlock(ExerciseId.orbs);
  const launcherSos = CoachLauncherBlock(ExerciseId.sos);

  final fixtures = Directory('functions/test/fixtures/coach_ui');

  /// Every `*.json` fixture, by name, as the blocks the codec makes of it:
  /// the same path a reply's `ui` takes in production.
  Map<String, List<CoachBlock>> fixtureBlocks() => {
    for (final file
        in fixtures
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      file.uri.pathSegments.last.replaceAll(
        '.json',
        '',
      ): CoachReplyCodec.decode({
        'template': 'generic1',
        'ui': {
          'v': 1,
          'blocks':
              (jsonDecode(file.readAsStringSync())
                  as Map<String, dynamic>)['blocks'],
        },
      }).blocks,
  };

  Finder cards() => find.byType(ExerciseLauncherCard);

  List<ExerciseId> shownIds(WidgetTester tester) => [
    for (final card in tester.widgetList<ExerciseLauncherCard>(cards()))
      card.id,
  ];

  /// A hand-written v1.0 surface, for what `coachUiMessages` can never
  /// produce: the payloads the package must refuse.
  List<Map<String, Object?>> rawSurface(
    String surfaceId,
    List<Map<String, Object?>> components,
  ) => [
    {
      'version': '1.0',
      'createSurface': {
        'surfaceId': surfaceId,
        'catalogId': coachCatalogId,
        'components': components,
      },
    },
  ];

  /// The view on a page of its own: a `material_ui` app with the app's
  /// theme, strings and compatibility bridge, as `LastPuffApp` builds them.
  /// The card under it reads `isPremiumProvider`, hence the scope.
  Future<_Harness> pump(
    WidgetTester tester, {
    ExerciseSource source = ExerciseSource.coach,
    bool underIntrinsicHeight = false,
  }) async {
    final harness = _Harness();
    final view = CoachSurfaceView(
      controller: harness.controller,
      source: source,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: fastBackendOverrides(),
        child: MaterialApp(
          theme: LpTheme.midnight(),
          localizationsDelegates: lpLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // ignore: deprecated_member_use
          builder: (context, child) => MaterialUiCompatibilityBridge(
            child: child ?? const SizedBox.shrink(),
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (underIntrinsicHeight)
                    IntrinsicHeight(child: view)
                  else
                    view,
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return harness;
  }

  testWidgets('every fixture the server can send draws its cards', (
    tester,
  ) async {
    final harness = await pump(tester);
    final all = fixtureBlocks();
    // Fourteen files, nine of which carry cards (K6). Counted, so a folder
    // that could not be read cannot pass by drawing nothing.
    expect(all, hasLength(14));
    expect(all.values.where((b) => b.isNotEmpty), hasLength(9));

    final width = tester.getSize(find.byType(Scaffold)).width;
    for (final MapEntry(key: name, value: blocks) in all.entries) {
      harness.shown.clear();
      harness.controller.show(name, blocks);
      await tester.pump();

      expect(tester.takeException(), isNull, reason: name);
      // One card per block, the ones that were asked for, top to bottom.
      expect(shownIds(tester), [
        for (final b in blocks) (b as CoachLauncherBlock).exercise,
      ], reason: name);
      final tops = [
        for (final card in cards().evaluate())
          tester.getTopLeft(find.byWidget(card.widget)).dy,
      ];
      expect(tops, [...tops]..sort(), reason: '$name: cards out of order');
      expect(harness.dropped, 0, reason: name);
      if (blocks.isEmpty) {
        expect(harness.shown, isEmpty, reason: name);
      } else {
        expect(harness.shown, [blocks.length], reason: name);
        // 82% of the screen, like the week card beside it in the thread.
        expect(
          tester.getSize(cards().first).width,
          moreOrLessEquals(width * 0.82, epsilon: 0.01),
          reason: name,
        );
      }
    }
  });

  testWidgets('the same message is shown once', (tester) async {
    final harness = await pump(tester);

    harness.controller.show('m1', const [launcherBreathing, launcherOrbs]);
    await tester.pump();
    final before = cards().evaluate().toList();

    // The store emits a state for every chunk and every flag: the screen
    // asks again, with a list that is equal and not the same object.
    harness.controller.show('m1', [launcherBreathing, launcherOrbs].toList());
    await tester.pump();

    expect(harness.shown, [2]);
    expect(cards(), findsNWidgets(2));
    // The same cards, not two new ones built in their place: nothing was
    // torn down, so a press in progress is not lost to a rebuild.
    final after = cards().evaluate().toList();
    expect(identical(after[0], before[0]), isTrue);
    expect(identical(after[1], before[1]), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets("a newer reply replaces the older one's cards", (tester) async {
    final harness = await pump(tester);

    harness.controller.show('m1', const [launcherBreathing]);
    await tester.pump();
    expect(shownIds(tester), [ExerciseId.breathing]);

    harness.controller.show('m2', const [launcherOrbs]);
    await tester.pump();

    expect(shownIds(tester), [ExerciseId.orbs]);
    expect(harness.shown, [1, 1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no blocks is nothing at all', (tester) async {
    final harness = await pump(tester);

    harness.controller.show('m3', const []);
    await tester.pump();

    expect(cards(), findsNothing);
    expect(tester.getSize(find.byType(CoachSurfaceView)), Size.zero);
    expect(harness.shown, isEmpty);
    expect(harness.dropped, 0);

    // And it takes away what was there: a reply with no cards after one
    // that had some leaves an empty thread, not the old menu.
    harness.controller.show('m4', const [launcherSos]);
    await tester.pump();
    expect(cards(), findsOneWidget);
    harness.controller.show('m5', const []);
    await tester.pump();
    expect(cards(), findsNothing);
    expect(tester.getSize(find.byType(CoachSurfaceView)), Size.zero);
    expect(harness.shown, [1]);
  });

  testWidgets('a reply that streamed first still gets its cards', (
    tester,
  ) async {
    // On the real backend Ember's bubble exists before its envelope does:
    // the words stream into a message that has no cards yet, and the final
    // message keeps THAT id. "The same id is a no-op" would therefore show a
    // card on the fake backend (one event, a fresh id) and never on Firebase.
    final harness = await pump(tester);

    harness.controller.show('m1', const []);
    await tester.pump();
    harness.controller.show('m1', const [launcherOrbs]);
    await tester.pump();

    expect(shownIds(tester), [ExerciseId.orbs]);
    expect(harness.shown, [1]);
  });

  testWidgets('cards cleared and shown again are counted once', (tester) async {
    // A retry takes two bubbles down, which makes an older reply the newest
    // one for an instant. Its cards coming back is right; a second
    // `coach_ui_shown` for the same message is not.
    final harness = await pump(tester);

    harness.controller.show('m1', const [launcherBreathing]);
    await tester.pump();
    harness.controller.clear();
    await tester.pump();
    expect(cards(), findsNothing);
    expect(tester.getSize(find.byType(CoachSurfaceView)), Size.zero);

    harness.controller.show('m1', const [launcherBreathing]);
    await tester.pump();

    expect(shownIds(tester), [ExerciseId.breathing]);
    expect(harness.shown, [1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a surface the package refuses leaves nothing behind', (
    tester,
  ) async {
    final harness = await pump(tester);
    // Something good first, so "nothing behind" includes the last reply's.
    harness.controller.show('m0', const [launcherBreathing]);
    await tester.pump();
    expect(cards(), findsOneWidget);
    harness.shown.clear();

    harness.controller.showRaw(
      'm1',
      surfaceId: 'bad',
      payload: rawSurface('bad', [
        {
          'id': 'root',
          'component': 'CoachStack',
          'children': ['c0'],
        },
        {'id': 'c0', 'component': 'ExerciseLauncher', 'exercise': 'teleport'},
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(cards(), findsNothing);
    expect(tester.getSize(find.byType(CoachSurfaceView)), Size.zero);
    expect(tester.takeException(), isNull);
    expect(harness.dropped, 1);
    expect(harness.shown, isEmpty);
    // No error bubble: the view draws no words of its own, ever.
    expect(
      find.descendant(
        of: find.byType(CoachSurfaceView),
        matching: find.byType(Text),
      ),
      findsNothing,
    );

    // Asked again for the same message: still nothing, and not counted twice.
    harness.controller.showRaw(
      'm1',
      surfaceId: 'bad',
      payload: rawSurface('bad', [
        {
          'id': 'root',
          'component': 'CoachStack',
          'children': ['c0'],
        },
        {'id': 'c0', 'component': 'ExerciseLauncher', 'exercise': 'teleport'},
      ]),
    );
    await tester.pump();
    expect(harness.dropped, 1);

    // And the next good reply draws: one refusal does not poison the thread.
    harness.controller.show('m2', const [launcherOrbs]);
    await tester.pump();
    expect(shownIds(tester), [ExerciseId.orbs]);
    expect(harness.shown, [1]);
    expect(harness.dropped, 1);
  });

  testWidgets('every kind of refusal ends the same way', (tester) async {
    // Strict validation is the whole reason a card can carry "an id and
    // nothing else": each of these is a way for a surface to carry more.
    final refused = <String, Object?>{
      'a property the catalog does not declare': rawSurface('s', [
        {
          'id': 'root',
          'component': 'CoachStack',
          'children': ['c0'],
        },
        {
          'id': 'c0',
          'component': 'ExerciseLauncher',
          'exercise': 'orbs',
          'route': '/paywall',
        },
      ]),
      "a component from the package's own catalog": rawSurface('s', [
        {'id': 'root', 'component': 'Text', 'text': 'Upgrade now'},
      ]),
      'a child that is not there': rawSurface('s', [
        {
          'id': 'root',
          'component': 'CoachStack',
          'children': ['c0', 'c1'],
        },
        {'id': 'c0', 'component': 'ExerciseLauncher', 'exercise': 'orbs'},
      ]),
      'a card with no exercise': rawSurface('s', [
        {
          'id': 'root',
          'component': 'CoachStack',
          'children': ['c0'],
        },
        {'id': 'c0', 'component': 'ExerciseLauncher'},
      ]),
      'an exercise that is not a name': rawSurface('s', [
        {
          'id': 'root',
          'component': 'CoachStack',
          'children': ['c0'],
        },
        {
          'id': 'c0',
          'component': 'ExerciseLauncher',
          'exercise': {'@path': '/exercise'},
        },
      ]),
      'no root': rawSurface('s', [
        {'id': 'c0', 'component': 'ExerciseLauncher', 'exercise': 'orbs'},
      ]),
      'a catalog this app does not hold': [
        {
          'version': '1.0',
          'createSurface': {
            'surfaceId': 's',
            'catalogId':
                'https://a2ui.org/specification/v1_0/catalogs/basic/catalog.json',
            'components': [
              {'id': 'root', 'component': 'Text', 'text': 'hi'},
            ],
          },
        },
      ],
      'an older protocol': [
        {
          'version': 'v0.9',
          'createSurface': {'surfaceId': 's', 'catalogId': coachCatalogId},
        },
      ],
      'not a message at all': 42,
      'a list of things that are not messages': [7, null],
    };

    final harness = await pump(tester);
    var n = 0;
    for (final MapEntry(key: what, value: payload) in refused.entries) {
      n++;
      harness.controller.showRaw('bad$n', surfaceId: 's', payload: payload);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull, reason: what);
      expect(cards(), findsNothing, reason: what);
      expect(
        tester.getSize(find.byType(CoachSurfaceView)),
        Size.zero,
        reason: what,
      );
      expect(harness.dropped, n, reason: what);
      expect(harness.shown, isEmpty, reason: what);
    }
  });

  testWidgets('cards sit under an intrinsic-height parent without throwing', (
    tester,
  ) async {
    // Auth forms and onboarding steps scroll under an IntrinsicHeight, and
    // that walk reaches everything below it. A LayoutBuilder cannot answer
    // it at all, which is why the stack is a plain Column.
    //
    // Collected one by one, as `screen_layout_test.dart` does, because
    // overflow is not what this is about: the test font is a square em box,
    // and the view is a fixed 82% of the SCREEN, so the height it reports
    // for the width it is asked about can be a text line short of the height
    // it lays out at. What is fatal on every device and font is the other
    // class: a box that cannot answer the question at all.
    final errors = <Object>[];
    final asked = <double>[];
    final priorHandler = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exception);
    try {
      final harness = await pump(tester, underIntrinsicHeight: true);
      harness.controller.show('m1', const [
        launcherBreathing,
        launcherOrbs,
        launcherSos,
      ]);
      await tester.pump();
      // The question an intrinsic-height parent asks, put directly.
      final box = tester.renderObject<RenderBox>(find.byType(CoachSurfaceView));
      asked.addAll([
        box.getMaxIntrinsicHeight(box.size.width),
        box.getMinIntrinsicHeight(box.size.width),
        box.getMaxIntrinsicWidth(double.infinity),
      ]);
    } catch (error) {
      // Kept as a finding rather than thrown: an exception leaving the body
      // while the handler is swapped out hangs the whole file.
      errors.add(error);
    } finally {
      FlutterError.onError = priorHandler;
    }

    final real = [
      for (final error in errors)
        if (!error.toString().contains('overflowed'))
          error.toString().split('\n').first,
    ];
    expect(real, isEmpty);
    expect(cards(), findsNWidgets(3));
    expect(tester.getSize(cards().first).height, greaterThan(0));
    expect(asked, hasLength(3));
    expect(asked, everyElement(allOf(isPositive, lessThan(double.infinity))));
  });

  testWidgets('disposing leaves no timers', (tester) async {
    final harness = await pump(tester);
    harness.controller.show('m1', const [launcherBreathing, launcherOrbs]);
    await tester.pump();
    expect(cards(), findsNWidgets(2));

    // Inside the body: flutter_test looks for pending timers before any
    // tearDown runs.
    harness.controller.dispose();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(cards(), findsNothing);
    // A reply that lands after the screen has gone asks a dead controller.
    harness.controller.show('m2', const [launcherSos]);
    harness.controller.clear();
    harness.controller.dispose();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(cards(), findsNothing);
    expect(harness.shown, [2]);
    expect(harness.dropped, 0);
  });

  testWidgets('a controller nobody showed anything disposes clean', (
    tester,
  ) async {
    // Every free account, every visit: the screen makes a controller and no
    // reply ever carries a card.
    final harness = await pump(tester);
    harness.controller.clear();
    harness.controller.dispose();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(harness.shown, isEmpty);
    expect(harness.dropped, 0);
  });

  testWidgets('a card is still one button to a screen reader', (tester) async {
    // The renderer wraps every component it draws in semantics widgets of
    // its own. They must add nothing and hide nothing: the card already
    // merges itself into one button that reads its own two lines, and that
    // is the only thing in the view with anything to say.
    final handle = tester.ensureSemantics();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final harness = await pump(tester);
    harness.controller.show('m1', const [launcherOrbs]);
    await tester.pump();

    expect(
      tester.getSemantics(cards()),
      isSemantics(
        label: '${l10n.gameNameOrbs}\n${l10n.exerciseGameSub(60)}',
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(
      find.descendant(
        of: find.byType(CoachSurfaceView),
        matching: find.bySemanticsLabel(RegExp('.+')),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a card opens as what the view was given', (tester) async {
    // The source is the view's, never the surface's: a block carries an id
    // and nothing else, so where it was opened from cannot ride on it.
    final harness = await pump(tester, source: ExerciseSource.plan);
    harness.controller.show('m1', const [launcherOrbs]);
    await tester.pump();

    expect(
      tester.widget<ExerciseLauncherCard>(cards()).source,
      ExerciseSource.plan,
    );
  });

  test('the catalog is small and ours', () {
    final json = coachCatalog().toJson();

    expect(json['catalogId'], coachCatalogId);
    expect(coachCatalogId, 'https://cirrusquit.com/a2ui/coach/v1/catalog.json');
    expect(json['protocolVersion'], '1.0');
    final components = json['components'] as Map<String, Object?>;
    expect(components.keys, ['CoachStack', 'ExerciseLauncher']);
    // Nothing to call, nothing to style: two components and no more.
    expect(json.containsKey('functions'), isFalse);
    expect(json.containsKey('theme'), isFalse);
    expect(jsonEncode(json).length, lessThan(3000));

    // Closed, both of them: a property nobody declared is a refusal.
    for (final MapEntry(key: name, value: schema) in components.entries) {
      expect(
        (schema! as Map<String, Object?>)['additionalProperties'],
        isFalse,
        reason: name,
      );
    }
    // The launcher takes an exercise id and nothing else, and the ids are
    // the registry's: a new exercise is drawable the moment it has a row.
    final launcher = components['ExerciseLauncher']! as Map<String, Object?>;
    final properties = launcher['properties']! as Map<String, Object?>;
    expect(properties.keys, ['exercise']);
    expect((properties['exercise']! as Map<String, Object?>)['enum'], [
      for (final id in ExerciseId.values) id.name,
    ]);
    expect(launcher['required'], ['exercise']);
    final stack = components['CoachStack']! as Map<String, Object?>;
    expect((stack['properties']! as Map<String, Object?>).keys, ['children']);
  });

  test('blocks become one v1.0 createSurface, an id per card', () {
    expect(coachUiMessages('s7', const [launcherOrbs, launcherSos]), [
      {
        'version': '1.0',
        'createSurface': {
          'surfaceId': 's7',
          'catalogId': coachCatalogId,
          'components': [
            {
              'id': 'root',
              'component': 'CoachStack',
              'children': ['c0', 'c1'],
            },
            {'id': 'c0', 'component': 'ExerciseLauncher', 'exercise': 'orbs'},
            {'id': 'c1', 'component': 'ExerciseLauncher', 'exercise': 'sos'},
          ],
        },
      },
    ]);
  });

  test("the surface folder sells nothing and names no package widget", () {
    // The plan's rule for this folder, read off its sources: no paywall
    // door from a card, and none of the package's own components.
    final sources = [
      for (final file in Directory(
        'lib/features/coach/surface',
      ).listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart')) file,
    ];
    expect(sources, isNotEmpty);
    for (final file in sources) {
      final source = file.readAsStringSync();
      expect(source.contains('paywall'), isFalse, reason: file.path);
      expect(source.contains('LayoutBuilder('), isFalse, reason: file.path);
      expect(
        source.contains('package:flutter/material.dart'),
        isFalse,
        reason: file.path,
      );
    }
  });
}

class _Harness {
  final List<int> shown = [];
  int dropped = 0;

  late final CoachSurfaceController controller = CoachSurfaceController(
    onShown: shown.add,
    onDropped: () => dropped++,
  );
}
