import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/widgets/lp_misc.dart';
import 'package:last_puff/core/widgets/press_scale.dart';
import 'package:last_puff/data/stores/day1_tour_store.dart';
import 'package:last_puff/data/stores/exercise_runs.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/allowances.dart';
import 'package:last_puff/domain/logic/exercises/exercise.dart';
import 'package:last_puff/domain/models/coach_ui.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';
import 'package:last_puff/features/coach/coach_screen.dart';
import 'package:last_puff/features/coach/surface/coach_catalog.dart';
import 'package:last_puff/features/coach/surface/coach_surface.dart';
import 'package:last_puff/features/exercises/exercise_launcher_card.dart';
import 'package:last_puff/features/panic/breath_ring.dart';
import 'package:last_puff/features/panic/panic_screens.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';

/// Ember's cards in the real thread, on the real router: a reply carries
/// them, the newest reply shows them, a tap opens the exercise and back
/// returns to the chat.
///
/// And what the app tells the server so that the right cards come back: what
/// this build can draw, and whether the message was sent from inside a
/// craving (one next step, never the menu again).
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  const breathing = CoachLauncherBlock(ExerciseId.breathing);
  const orbs = CoachLauncherBlock(ExerciseId.orbs);
  const sos = CoachLauncherBlock(ExerciseId.sos);

  const menuWords = 'Pick one. I am right here.';
  const menu = CoachReply(
    template: CoachTemplate.craving1,
    text: menuWords,
    blocks: [breathing, orbs, sos],
  );

  late RecordingAnalytics analytics;
  late _CardCoach coach;
  late _Clock clock;

  setUp(() {
    analytics = RecordingAnalytics();
    coach = _CardCoach();
    clock = _Clock(DateTime(2026, 9, 5, 14));
  });

  /// The whole app, signed in on the seeded day-12 journey, at [location].
  Future<ProviderContainer> boot(
    WidgetTester tester, {
    bool premium = true,
    String? location = Routes.coach,
    // Tall enough for a reply and three cards to be on screen together. The
    // test font is a square em box, so on the default 600 px surface the
    // thread is about 320 px and three cards more than fill it. The suites
    // about what the cards ARE run where everything fits; the group about
    // where the thread rests picks its own sizes.
    Size size = const Size(800, 1100),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = ProviderContainer(
      overrides: fastBackendOverrides(
        analytics: analytics,
        premium: premium,
        extra: [
          coachRepositoryProvider.overrideWithValue(coach),
          nowProvider.overrideWithValue(clock.read),
        ],
      ),
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const LastPuffApp()),
    );
    c.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    if (location != null) {
      c.read(routerProvider).go(location);
      await tester.pumpAndSettle();
    }
    return c;
  }

  /// Types [text] and sends it, the way a person does.
  Future<void> say(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
  }

  /// Taps a quick chip (it prefills) and sends it unedited.
  Future<void> sayChip(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
  }

  /// Fixed pumps, never `pumpAndSettle`: an exercise animates for as long as
  /// it is on screen.
  Future<void> beat(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Moves the app's clock and lets the minute clock notice, as its own
  /// timer would.
  Future<void> advance(
    WidgetTester tester,
    ProviderContainer c,
    Duration by,
  ) async {
    clock.now = clock.now.add(by);
    c.invalidate(minuteClockProvider);
    await tester.pumpAndSettle();
  }

  Finder cards() => find.byType(ExerciseLauncherCard);
  List<ExerciseId> shownIds(WidgetTester tester) => [
    for (final card in tester.widgetList<ExerciseLauncherCard>(cards()))
      card.id,
  ];
  String path(ProviderContainer c) => c.read(routerProvider).state.uri.path;
  int planDay(ProviderContainer c) => c.read(todayProvider)!.dayNumber;

  testWidgets(
    'a card under the reply opens the exercise, and back returns to the chat',
    (tester) async {
      coach.queue.add(menu);
      final c = await boot(tester);

      await sayChip(tester, l10n.coachChipCraving);

      // Three cards, the ones the reply carried, under its words.
      expect(shownIds(tester), [
        ExerciseId.breathing,
        ExerciseId.orbs,
        ExerciseId.sos,
      ]);
      expect(find.text(menuWords), findsOneWidget);
      expect(
        tester.getTopLeft(cards().first).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.text(menuWords)).dy),
      );
      expect(tester.takeException(), isNull);
      // Counted once, as a menu offered from outside a craving, on the day
      // it happened.
      expect(planDay(c), 12);
      expect(analytics.propsOfAll('coach_ui_shown'), [
        {'launchers': 3, 'panic': 'false', 'plan_day': 12},
      ]);

      final card = find.widgetWithText(
        ExerciseLauncherCard,
        l10n.exerciseBreathingTitle,
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await beat(tester);

      expect(find.byType(BreathRing), findsOneWidget);
      expect(path(c), '/panic/exercise/breathing');
      expect(analytics.propsOfAll('exercise_opened'), [
        {'exercise': 'breathing', 'source': 'coach'},
      ]);

      await tester.tap(find.byType(BackChevron));
      await beat(tester);
      await beat(tester);

      // The thread, and its cards, as they were left.
      expect(find.byType(BreathRing), findsNothing);
      expect(path(c), Routes.coach);
      expect(find.text(menuWords), findsOneWidget);
      expect(shownIds(tester), [
        ExerciseId.breathing,
        ExerciseId.orbs,
        ExerciseId.sos,
      ]);
      expect(analytics.propsOfAll('coach_ui_shown'), hasLength(1));
      expect(analytics.names, isNot(contains('coach_ui_dropped')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('only the newest reply keeps its cards', (tester) async {
    coach.queue
      ..add(menu)
      ..add(
        const CoachReply(
          template: CoachTemplate.generic1,
          text: 'Glad it eased.',
        ),
      );
    await boot(tester);
    await sayChip(tester, l10n.coachChipCraving);
    expect(cards(), findsNWidgets(3));

    await say(tester, 'it eased a little');

    // Both replies are still in the thread. The cards belonged to the older
    // one, and are gone with it being the newest.
    expect(find.text(menuWords), findsOneWidget);
    expect(find.text('Glad it eased.'), findsOneWidget);
    expect(cards(), findsNothing);
    expect(analytics.propsOfAll('coach_ui_shown'), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets("a reply with no cards is today's thread", (tester) async {
    // An older server, a free account, any turn the policy has no card for.
    coach.queue.add(
      const CoachReply(template: CoachTemplate.generic1, text: 'Just words.'),
    );
    await boot(tester);

    await say(tester, 'hello');

    expect(find.text('Just words.'), findsOneWidget);
    expect(cards(), findsNothing);
    // The place a surface would be takes no room at all.
    expect(tester.getSize(find.byType(CoachSurfaceView)).height, 0);
    for (final label in [
      l10n.coachChipCraving,
      l10n.coachChipRoughDay,
      l10n.coachChipSlipped,
      l10n.coachChipProgress,
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(analytics.names, isNot(contains('coach_ui_shown')));
    expect(analytics.names, isNot(contains('coach_ui_dropped')));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'after the craving chip, the next message says it is still a craving',
    (tester) async {
      final c = await boot(tester);

      // The chip's own turn is the one that gets the menu, so it is sent
      // from outside a craving.
      await sayChip(tester, l10n.coachChipCraving);
      expect(coach.chips.single, CoachChip.craving);
      expect(coach.extras.single!.ui!.craving, isFalse);

      // The second and the third message of that chat: one next step each
      // time, never the three-card menu again.
      await say(tester, 'it is not passing');
      await say(tester, 'still here');
      expect(coach.extras[1]!.ui!.craving, isTrue);
      expect(coach.extras[2]!.ui!.craving, isTrue);

      await advance(tester, c, const Duration(minutes: 19));
      await say(tester, 'nearly');
      expect(coach.extras[3]!.ui!.craving, isTrue);

      // Twenty-one minutes after the chip: the app's own model of a craving
      // says it has passed, and this is an ordinary message again.
      await advance(tester, c, const Duration(minutes: 2));
      await say(tester, 'what about tomorrow');
      expect(coach.extras[4]!.ui!.craving, isFalse);
      // Every turn said what this build can draw.
      for (final extras in coach.extras) {
        expect(extras!.ui!.exercises, [
          for (final spec in Exercises.all) spec.id.name,
        ]);
      }
    },
  );

  testWidgets('arriving from the panic flow says so from the first message', (
    tester,
  ) async {
    coach.queue.add(
      const CoachReply(
        template: CoachTemplate.generic1,
        text: 'Breathe with me.',
        blocks: [breathing],
      ),
    );
    final c = await boot(tester, location: '${Routes.coach}?panic=8');

    await say(tester, 'I am about to cave');

    expect(coach.panics.single, 8);
    expect(coach.extras.single!.ui!.craving, isTrue);
    // One next step, and it is counted as offered inside a craving.
    expect(shownIds(tester), [ExerciseId.breathing]);
    expect(analytics.propsOfAll('coach_ui_shown'), [
      {'launchers': 1, 'panic': 'true', 'plan_day': planDay(c)},
    ]);

    // The strength rides on the first message only; the craving outlasts it.
    await say(tester, 'still bad');
    expect(coach.panics.last, isNull);
    expect(coach.extras.last!.ui!.craving, isTrue);
  });

  testWidgets('a restored thread has no cards', (tester) async {
    // Nothing about cards is stored or restored: a transcript is words.
    coach = _CardCoach(
      stored: const [
        CoachMessage.user(id: 'h_1', text: 'craving hard'),
        CoachMessage.ember(
          id: 'h_2',
          template: CoachTemplate.generic1,
          text: 'Pick one. I am right here.',
        ),
      ],
    );
    await boot(tester);

    expect(find.text('craving hard'), findsOneWidget);
    expect(find.text('Pick one. I am right here.'), findsOneWidget);
    expect(cards(), findsNothing);
    expect(tester.getSize(find.byType(CoachSurfaceView)).height, 0);
    expect(analytics.names, isNot(contains('coach_ui_shown')));
  });

  testWidgets('the Day-1 coach step draws no card even if one arrives', (
    tester,
  ) async {
    // The walkthrough leaves for the checklist 2.5 s after the reply. No
    // card is asked for, and one that comes anyway is not drawn.
    coach.queue.add(
      const CoachReply(
        template: CoachTemplate.generic1,
        text: 'Good to meet you.',
        blocks: [breathing, orbs, sos],
      ),
    );
    final c = await boot(tester, location: null);
    c
        .read(quitStoreProvider.notifier)
        .replaceForTest(
          c.read(quitStoreProvider)!.copyWith(day1TasksDone: const {0}),
        );
    c.read(routerProvider).go(Routes.day1);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.day1Task2).first);
    await tester.pumpAndSettle();
    expect(c.read(day1TourStepProvider), Day1TourStep.meetCoach);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hi ember');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    // Inside the 2.5 s the reply is given on screen.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Good to meet you.'), findsOneWidget);
    expect(coach.extras.single!.ui, isNull);
    expect(cards(), findsNothing);

    // The step completes and the checklist is back.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(path(c), Routes.day1);

    // And the card does not turn up later, under the same reply: the
    // walkthrough is over, the chat is open by choice, the reply is there.
    c.read(day1TourProvider.notifier).skip();
    c.read(routerProvider).go(Routes.coach);
    await tester.pumpAndSettle();
    expect(c.read(day1TourStepProvider), isNull);
    expect(path(c), Routes.coach);
    expect(find.text('Good to meet you.'), findsOneWidget);
    expect(c.read(coachStoreProvider).messages.last.text, 'Good to meet you.');
    expect(cards(), findsNothing);
    expect(analytics.names, isNot(contains('coach_ui_shown')));
    expect(analytics.names, isNot(contains('coach_ui_dropped')));
  });

  testWidgets('cards come back when the chat is built again', (tester) async {
    // The thread outlives the screen: leaving the tab bar altogether takes
    // the screen down, and the newest reply is still the newest reply.
    coach.queue.add(menu);
    final c = await boot(tester);
    await sayChip(tester, l10n.coachChipCraving);
    expect(cards(), findsNWidgets(3));

    c.read(routerProvider).go(Routes.settings);
    await tester.pumpAndSettle();
    expect(find.byType(CoachScreen), findsNothing);

    c.read(routerProvider).go(Routes.coach);
    await tester.pumpAndSettle();

    expect(find.text(menuWords), findsOneWidget);
    expect(shownIds(tester), [
      ExerciseId.breathing,
      ExerciseId.orbs,
      ExerciseId.sos,
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a reply whose cards are refused is still a reply', (
    tester,
  ) async {
    // Review Focus 7, in the thread: the words stand, nothing else renders,
    // there is no error bubble, and it is counted once. Typed blocks cannot
    // carry anything the catalog refuses, so the refusal is handed to the
    // screen's own controller, under the id of the reply it belongs to.
    coach.queue.add(
      const CoachReply(template: CoachTemplate.generic1, text: 'Just words.'),
    );
    final c = await boot(tester);
    await say(tester, 'hello');
    final before = c.read(coachStoreProvider).messages;
    final texts = find.byType(Text).evaluate().length;

    final controller = tester
        .widget<CoachSurfaceView>(find.byType(CoachSurfaceView))
        .controller;
    for (var i = 0; i < 2; i++) {
      controller.showRaw(
        before.last.id,
        surfaceId: 'refused',
        payload: [
          {
            'version': '1.0',
            'createSurface': {
              'surfaceId': 'refused',
              'catalogId': coachCatalogId,
              'components': [
                {'id': 'root', 'component': 'Text', 'text': 'Upgrade'},
              ],
            },
          },
        ],
      );
      await tester.pumpAndSettle();
    }

    expect(tester.takeException(), isNull);
    expect(find.text('Just words.'), findsOneWidget);
    expect(cards(), findsNothing);
    expect(tester.getSize(find.byType(CoachSurfaceView)).height, 0);
    // Not one more piece of text anywhere, and not one more message.
    expect(find.byType(Text).evaluate().length, texts);
    expect(c.read(coachStoreProvider).messages, before);
    expect(analytics.propsOfAll('coach_ui_dropped'), [<String, Object>{}]);
    expect(analytics.names, isNot(contains('coach_ui_shown')));
  });

  group('where the thread rests', () {
    // A chat scrolls to its end when something is said. Cards are the one
    // thing that arrives all at once and is tall: on a small phone three of
    // them are taller than the thread, and scrolling to their end carried
    // the words they answer off the top of the screen (360x640: thread 321
    // pt, cards 335 pt, the reply entirely above it). So a reply that lands
    // WITH cards rests with its first line in view, as far toward the end as
    // that allows.
    const small = Size(360, 640);
    const phone = Size(390, 844);

    const longWords =
        'That pull you are feeling right now is real and it is loud, and it '
        'is also on a clock. Most cravings crest and fall inside fifteen to '
        'twenty minutes whether or not you feed them. You have already come '
        'through this exact moment before on this plan, more than once, and '
        'the wave broke each time. Pick whichever of these looks least '
        'annoying, give it one honest minute, and come straight back here '
        'and tell me what the craving did.';

    /// The chat's own list, not the Home tab's behind it.
    Finder thread() => find.descendant(
      of: find.byType(CoachScreen),
      matching: find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.vertical,
      ),
    );
    ScrollPosition position(WidgetTester tester) =>
        tester.widget<ListView>(thread()).controller!.position;
    Rect viewport(WidgetTester tester) => tester.getRect(thread());

    // Built is enough for these two. A finder that skips what is scrolled
    // out of view cannot say WHERE the reply went, which is the question.
    Finder words(String text) => find.text(text, skipOffstage: false);
    Finder cardFor(String title) =>
        find.widgetWithText(ExerciseLauncherCard, title, skipOffstage: false);

    /// The first line of the reply [text] is inside the thread, and a
    /// finger can land on it.
    void expectFirstLineInView(WidgetTester tester, String text) {
      expect(words(text), findsOneWidget, reason: 'the reply is not built');
      final reply = tester.getRect(words(text));
      final view = viewport(tester);
      final where =
          'reply text ${reply.top.round()}..${reply.bottom.round()}, '
          'thread ${view.top.round()}..${view.bottom.round()}';
      expect(reply.top, greaterThanOrEqualTo(view.top - 0.5), reason: where);
      expect(
        reply.top + 14,
        lessThanOrEqualTo(view.bottom + 0.5),
        reason: where,
      );
      expect(
        find.text(text).hitTestable(at: Alignment.topLeft),
        findsOneWidget,
        reason: where,
      );
    }

    /// Runs [body] with overflow reports set aside. The test font is a
    /// square em box, so at a phone's width half the app's rows are a few
    /// pixels too wide; that is not what this group is about, and
    /// `screen_layout_test.dart` sets the same class aside. Anything else
    /// that is reported fails the test.
    Future<void> atPhoneWidth(Future<void> Function() body) async {
      final reported = <Object>[];
      final prior = FlutterError.onError;
      FlutterError.onError = (details) => reported.add(details.exception);
      try {
        await body();
      } finally {
        // Always, or the rest of the file hangs on a handler nobody owns.
        FlutterError.onError = prior;
      }
      expect([
        for (final error in reported)
          if (!error.toString().contains('overflowed'))
            error.toString().split('\n').first,
      ], isEmpty);
    }

    testWidgets(
      'on a small phone the reply stays in view and the cards run below it',
      (tester) async {
        await atPhoneWidth(() async {
          coach.queue.add(menu);
          final c = await boot(tester, size: small);

          await sayChip(tester, l10n.coachChipCraving);

          // The first line of what Ember said, and at least the start of
          // the first card under it.
          expectFirstLineInView(tester, menuWords);
          final view = viewport(tester);
          final first = tester.getRect(cardFor(l10n.exerciseBreathingTitle));
          expect(first.top, lessThan(view.bottom));
          expect(first.bottom, greaterThan(view.top));
          // It did not fit, which is the case this is about: the thread is
          // resting short of its end.
          expect(
            position(tester).pixels,
            lessThan(position(tester).maxScrollExtent),
          );

          // The rest is an ordinary scroll away, and a card reached that
          // way opens what it names.
          final third = find.widgetWithText(
            ExerciseLauncherCard,
            l10n.panicLoopSos,
          );
          await tester.dragUntilVisible(
            third,
            thread(),
            const Offset(0, -60),
          );
          await tester.pumpAndSettle();
          await tester.tap(third);
          await beat(tester);
          expect(analytics.propsOfAll('exercise_opened'), [
            {'exercise': 'sos', 'source': 'coach'},
          ]);
          expect(path(c), Routes.compose);
        });
      },
    );

    testWidgets('what they say next still goes to the end', (tester) async {
      await atPhoneWidth(() async {
        coach.queue
          ..add(menu)
          ..add(
            const CoachReply(
              template: CoachTemplate.generic1,
              text: 'Glad it eased.',
            ),
          );
        await boot(tester, size: small);
        await sayChip(tester, l10n.coachChipCraving);
        expect(
          position(tester).pixels,
          lessThan(position(tester).maxScrollExtent),
        );

        await say(tester, 'it eased a little');

        // Their own message, and a reply with no cards: the end of the
        // thread, as a chat does.
        expect(position(tester).pixels, position(tester).maxScrollExtent);
        expect(find.text('Glad it eased.').hitTestable(), findsOneWidget);
      });
    });

    testWidgets('when everything fits, the thread ends where it always did', (
      tester,
    ) async {
      coach.queue.add(menu);
      await boot(tester);

      await sayChip(tester, l10n.coachChipCraving);

      final view = viewport(tester);
      expect(position(tester).pixels, position(tester).maxScrollExtent);
      expectFirstLineInView(tester, menuWords);
      for (final title in [
        l10n.exerciseBreathingTitle,
        l10n.gameNameOrbs,
        l10n.panicLoopSos,
      ]) {
        final rect = tester.getRect(cardFor(title));
        expect(rect.top, greaterThanOrEqualTo(view.top), reason: title);
        expect(rect.bottom, lessThanOrEqualTo(view.bottom), reason: title);
      }
    });

    testWidgets('a long reply keeps its first line on screen', (tester) async {
      // Production replies run to eighty words where the demo's run to
      // thirty: on any phone that is a reply taller than the space three
      // cards leave it.
      await atPhoneWidth(() async {
        expect(longWords.split(' ').length, inInclusiveRange(75, 90));
        coach.queue.add(
          const CoachReply(
            template: CoachTemplate.craving1,
            text: longWords,
            blocks: [breathing, orbs, sos],
          ),
        );
        await boot(tester, size: phone);

        await sayChip(tester, l10n.coachChipCraving);

        expectFirstLineInView(tester, longWords);
        expect(shownIds(tester), isNotEmpty);
      });
    });

    testWidgets('while the words are still arriving the thread follows them', (
      tester,
    ) async {
      // The real backend's order: the words stream into a bubble first, and
      // the envelope with the cards lands frames later. Until it does this
      // is any other reply, read at its end as it grows; the rule applies
      // when the cards appear.
      await atPhoneWidth(() async {
        coach
          ..hold = Completer<void>()
          ..queue.add(
            const CoachReply(
              template: CoachTemplate.craving1,
              text: longWords,
              blocks: [breathing, orbs, sos],
            ),
          );
        await boot(tester, size: small);

        await sayChip(tester, l10n.coachChipCraving);

        // Streaming: no cards yet, and the end of what has arrived in view.
        expect(
          find.byType(ExerciseLauncherCard, skipOffstage: false),
          findsNothing,
        );
        var reply = tester.getRect(words(longWords));
        expect(reply.top, lessThan(viewport(tester).top));
        expect(reply.bottom, lessThanOrEqualTo(viewport(tester).bottom));
        expect(reply.bottom, greaterThan(viewport(tester).top));

        coach.hold!.complete();
        await tester.pumpAndSettle();

        // The cards are on the thread, and it has come back up to the first
        // line of the reply they belong to.
        expect(
          find.byType(ExerciseLauncherCard, skipOffstage: false),
          findsNWidgets(3),
        );
        expectFirstLineInView(tester, longWords);
        reply = tester.getRect(words(longWords));
        expect(reply.bottom, greaterThan(viewport(tester).bottom));
      });
    });

    testWidgets('a reply with no cards still ends at the end of the thread', (
      tester,
    ) async {
      await atPhoneWidth(() async {
        coach.queue.add(
          const CoachReply(template: CoachTemplate.generic1, text: longWords),
        );
        await boot(tester, size: small);

        await say(tester, 'tell me everything');

        // As before cards existed: the end of what was said is in view, even
        // though this reply is taller than the thread and starts above it.
        // The rule is about cards, not about long replies.
        expect(position(tester).maxScrollExtent, greaterThan(0));
        expect(
          position(tester).pixels,
          greaterThanOrEqualTo(position(tester).maxScrollExtent),
        );
        final reply = tester.getRect(words(longWords));
        expect(reply.top, lessThan(viewport(tester).top));
        expect(reply.bottom, lessThanOrEqualTo(viewport(tester).bottom));
        expect(reply.bottom, greaterThan(viewport(tester).top));
      });
    });

    testWidgets('and rests flush with it, not past it', (tester) async {
      // Before each message was one list child, the list's length was an
      // estimate at the moment the scroll was aimed (the end of a tall
      // reply had not been laid out), and the thread came to rest past its
      // real end: 754.8 against 712 here, a strip of nothing under the
      // reply. A reply is laid out whole now, so the end is the end.
      await atPhoneWidth(() async {
        coach.queue.add(
          const CoachReply(template: CoachTemplate.generic1, text: longWords),
        );
        await boot(tester, size: small);

        await say(tester, 'tell me everything');

        expect(position(tester).pixels, position(tester).maxScrollExtent);
        expect(position(tester).outOfRange, isFalse);
      });
    });

    testWidgets('with the keyboard up, a craving reply stays above its card', (
      tester,
    ) async {
      // The other way the thread gets short. One card, which fits a phone
      // easily, and still pushed its reply out once the keyboard had taken
      // the bottom third of the screen.
      const said =
          'Okay. You came here instead of reaching for it, and that is the '
          'hard part done. Breathe with me for one minute and tell me what '
          'it does.';
      await atPhoneWidth(() async {
        coach.queue.add(
          const CoachReply(
            template: CoachTemplate.generic1,
            text: said,
            blocks: [breathing],
          ),
        );
        await boot(tester, size: phone, location: '${Routes.coach}?panic=8');
        final open = viewport(tester).height;

        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 336);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        expect(viewport(tester).height, lessThan(open - 200));

        await say(tester, 'I am about to cave');

        expect(cardFor(l10n.exerciseBreathingTitle), findsOneWidget);
        expectFirstLineInView(tester, said);
        // The keyboard is why: with it down the same reply and card fit.
        expect(
          position(tester).pixels,
          lessThan(position(tester).maxScrollExtent),
        );
      });
    });

    testWidgets('a chat built again on a thread that ends in cards opens on '
        'that reply', (tester) async {
      await atPhoneWidth(() async {
        coach.queue.add(menu);
        final c = await boot(tester, size: small);
        await sayChip(tester, l10n.coachChipCraving);

        c.read(routerProvider).go(Routes.settings);
        await tester.pumpAndSettle();
        expect(find.byType(CoachScreen), findsNothing);
        c.read(routerProvider).go(Routes.coach);
        await tester.pumpAndSettle();

        expectFirstLineInView(tester, menuWords);
        final view = viewport(tester);
        final first = tester.getRect(cardFor(l10n.exerciseBreathingTitle));
        expect(first.top, lessThan(view.bottom));
        expect(first.bottom, greaterThan(view.top));
      });
    });

    testWidgets('a chat built again on a thread with no cards opens where it '
        'always has', (tester) async {
      // Left exactly alone: a screen built on an existing thread opens at
      // the top of it, as it did before cards existed. Only cards move it.
      await atPhoneWidth(() async {
        coach.queue.add(
          const CoachReply(template: CoachTemplate.generic1, text: longWords),
        );
        final c = await boot(tester, size: small);
        await say(tester, 'tell me everything');
        expect(position(tester).maxScrollExtent, greaterThan(0));

        c.read(routerProvider).go(Routes.settings);
        await tester.pumpAndSettle();
        c.read(routerProvider).go(Routes.coach);
        await tester.pumpAndSettle();

        expect(position(tester).pixels, 0);
      });
    });

    testWidgets('however long the thread above that reply is', (tester) async {
      // A screen built on an existing thread opens at its top, and a lazy
      // list has built nothing near its end: neither the newest reply nor
      // its cards exist to be measured. It has to go and find them.
      coach = _CardCoach(
        stored: [
          for (var i = 0; i < 12; i++) ...[
            CoachMessage.user(id: 'h_u$i', text: 'earlier question $i'),
            CoachMessage.ember(
              id: 'h_e$i',
              template: CoachTemplate.generic1,
              text: 'Earlier answer $i. $longWords',
            ),
          ],
        ],
      );
      await atPhoneWidth(() async {
        coach.queue.add(menu);
        final c = await boot(tester, size: small);
        await sayChip(tester, l10n.coachChipCraving);
        expectFirstLineInView(tester, menuWords);

        c.read(routerProvider).go(Routes.settings);
        await tester.pumpAndSettle();
        expect(find.byType(CoachScreen), findsNothing);
        c.read(routerProvider).go(Routes.coach);
        await tester.pumpAndSettle();

        // Far from the top it opened at, and on the reply.
        expect(position(tester).pixels, greaterThan(2000));
        expectFirstLineInView(tester, menuWords);
        final view = viewport(tester);
        final first = tester.getRect(cardFor(l10n.exerciseBreathingTitle));
        expect(first.top, lessThan(view.bottom));
        expect(first.bottom, greaterThan(view.top));
        expect(position(tester).outOfRange, isFalse);
      });
    });
  });

  group('back from an exercise', () {
    const backedOut = ExerciseRun(
      id: ExerciseId.orbs,
      source: ExerciseSource.coach,
      seconds: 40,
      completed: false,
      passed: false,
    );

    /// A quick chip, by its words. Not `find.text`: once a chip has
    /// prefilled the composer the same words are in the text field too.
    Finder chip(String label) => find.descendant(
      of: find.byType(PressScale),
      matching: find.text(label),
    );
    String composer(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text;
    int survived(ProviderContainer c) =>
        c.read(quitStoreProvider)!.cravingsSurvivedTotal;
    List<Map<String, Object>> outcomes() =>
        analytics.propsOfAll('craving_outcome');

    testWidgets('two replies lead the chips', (tester) async {
      final c = await boot(tester);
      expect(chip(l10n.panicItPassed), findsNothing);
      expect(chip(l10n.coachAfterStill), findsNothing);

      c.read(exerciseRunsProvider.notifier).report(backedOut);
      await tester.pumpAndSettle();

      // First and second in the row, ahead of the four openers.
      final passed = tester.getTopLeft(chip(l10n.panicItPassed)).dx;
      final still = tester.getTopLeft(chip(l10n.coachAfterStill)).dx;
      final opener = tester.getTopLeft(chip(l10n.coachChipCraving)).dx;
      expect(passed, lessThan(still));
      expect(still, lessThan(opener));
      // The openers are all still in the row, further along it.
      final row = find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.horizontal,
      );
      for (final label in [
        l10n.coachChipRoughDay,
        l10n.coachChipSlipped,
        l10n.coachChipProgress,
      ]) {
        await tester.dragUntilVisible(chip(label), row, const Offset(-150, 0));
        expect(chip(label), findsOneWidget);
      }
      await tester.dragUntilVisible(
        chip(l10n.coachAfterStill),
        row,
        const Offset(150, 0),
      );
      await tester.pumpAndSettle();

      // Tapping one fills the composer and sends nothing.
      final thread = c.read(coachStoreProvider).messages;
      await tester.tap(chip(l10n.coachAfterStill));
      await tester.pumpAndSettle();
      expect(composer(tester), l10n.coachAfterStill);
      expect(coach.extras, isEmpty);
      expect(c.read(coachStoreProvider).messages, thread);
      expect(outcomes(), isEmpty);

      // Sent, it is an ordinary message that says what they just did, and
      // the two replies have done their job.
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();
      expect(coach.chips.single, isNull);
      expect(coach.extras.single!.justDid, same(backedOut));
      expect(chip(l10n.panicItPassed), findsNothing);
      expect(chip(l10n.coachAfterStill), findsNothing);
    });

    testWidgets('they go when the craving they were about has passed', (
      tester,
    ) async {
      final c = await boot(tester);
      c.read(exerciseRunsProvider.notifier).report(backedOut);
      await tester.pumpAndSettle();
      expect(chip(l10n.coachAfterStill), findsOneWidget);

      await advance(tester, c, const Duration(minutes: 21));

      expect(chip(l10n.panicItPassed), findsNothing);
      expect(chip(l10n.coachAfterStill), findsNothing);
      expect(chip(l10n.coachChipCraving), findsOneWidget);
    });

    testWidgets('a craving already marked passed asks nothing more', (
      tester,
    ) async {
      // "It passed" was said on the exercise's own screen: the craving is
      // counted and there is nothing left to ask.
      const passedThere = ExerciseRun(
        id: ExerciseId.breathing,
        source: ExerciseSource.coach,
        seconds: 75,
        completed: true,
        passed: true,
      );
      final c = await boot(tester);
      c.read(exerciseRunsProvider.notifier).report(passedThere);
      await tester.pumpAndSettle();

      expect(chip(l10n.panicItPassed), findsNothing);
      expect(chip(l10n.coachAfterStill), findsNothing);
      expect(chip(l10n.coachChipCraving), findsOneWidget);

      // Ember is still told.
      await say(tester, 'that was good');
      expect(coach.extras.single!.justDid, same(passedThere));
    });

    testWidgets('saying it passed in the chat counts the craving, once', (
      tester,
    ) async {
      // The whole loop, the way a person walks it: the menu, a card, the
      // exercise, back without "It passed", and then saying so here.
      coach.queue.add(menu);
      final c = await boot(tester);
      await sayChip(tester, l10n.coachChipCraving);
      final card = find.widgetWithText(
        ExerciseLauncherCard,
        l10n.exerciseBreathingTitle,
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await beat(tester);
      expect(find.byType(BreathRing), findsOneWidget);
      await tester.tap(find.byType(BackChevron));
      await beat(tester);
      await beat(tester);
      await tester.pumpAndSettle();

      // Back in the chat, nothing counted, the two replies leading.
      final before = survived(c);
      expect(outcomes(), isEmpty);
      expect(chip(l10n.panicItPassed), findsOneWidget);
      final sent = coach.extras.length;
      final thread = c.read(coachStoreProvider).messages;

      await tester.tap(chip(l10n.panicItPassed));
      await tester.pumpAndSettle();

      // Counted exactly as the button on the exercise would have counted
      // it, and nothing was sent on their behalf.
      expect(survived(c), before + 1);
      expect(outcomes(), hasLength(1));
      expect(outcomes().single['survived'], 'true');
      expect(outcomes().single['exercise'], 'breathing');
      expect(outcomes().single['source'], 'coach');
      expect(composer(tester), l10n.panicItPassed);
      expect(coach.extras, hasLength(sent));
      expect(c.read(coachStoreProvider).messages, thread);
      expect(path(c), Routes.coach);

      // The question has been answered, so the two replies are gone, as
      // they are after "It passed" on the exercise's own screen. There is
      // nothing left to tap twice.
      expect(chip(l10n.panicItPassed), findsNothing);
      expect(chip(l10n.coachAfterStill), findsNothing);
      expect(chip(l10n.coachChipCraving), findsOneWidget);

      // Sending it tells Ember what they did, once, and that it passed: the
      // craving is already in their total, and the server has to know that
      // to say so beside it.
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();
      expect(coach.extras, hasLength(sent + 1));
      final justDid = coach.extras.last!.justDid!;
      expect(justDid.id, ExerciseId.breathing);
      expect(justDid.source, ExerciseSource.coach);
      expect(justDid.passed, isTrue);
      expect(survived(c), before + 1);
      expect(outcomes(), hasLength(1));
      // The exercise is reported finished once, as it ended: backed out of.
      expect(analytics.propsOfAll('exercise_finished'), hasLength(1));
      expect(
        analytics.propsOfAll('exercise_finished').single['passed'],
        'false',
      );
      await say(tester, 'thanks');
      expect(coach.extras.last!.justDid, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with no craving open, saying it passed only fills the box', (
      tester,
    ) async {
      // A run with nothing parked behind it (the craving was already closed
      // some other way): the words still go in the box, and nothing is
      // counted that did not happen.
      final c = await boot(tester);
      c.read(exerciseRunsProvider.notifier).report(backedOut);
      await tester.pumpAndSettle();
      final before = survived(c);

      await tester.tap(chip(l10n.panicItPassed));
      await tester.pumpAndSettle();

      expect(composer(tester), l10n.panicItPassed);
      expect(survived(c), before);
      expect(outcomes(), isEmpty);
      expect(coach.extras, isEmpty);
      // Nothing was counted, so nothing is claimed: the question stays open
      // and the run goes out as it was filed.
      expect(chip(l10n.panicItPassed), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();
      expect(coach.extras.single!.justDid, same(backedOut));
      expect(coach.extras.single!.justDid!.passed, isFalse);
    });

    testWidgets('a turn the cap answered leaves the two replies where they '
        'were', (tester) async {
      // The cap is an envelope like any other, and it says nothing about
      // the exercise. The question it would have closed is still open.
      coach.queue.add(
        const CoachReply(
          template: CoachTemplate.capReached,
          args: {'limit': LpAllowances.freeCoachMessages},
          messagesLeft: 0,
          isFreeTier: true,
        ),
      );
      final c = await boot(tester, premium: false);
      c.read(exerciseRunsProvider.notifier).report(backedOut);
      await tester.pumpAndSettle();

      await say(tester, 'that helped a bit');

      expect(
        c.read(coachStoreProvider).messages.last.template,
        CoachTemplate.capReached,
      );
      expect(coach.extras.single!.justDid, same(backedOut));
      expect(chip(l10n.panicItPassed), findsOneWidget);
      expect(chip(l10n.coachAfterStill), findsOneWidget);
      expect(c.read(exerciseRunsProvider), same(backedOut));
    });

    testWidgets('still strong counts nothing', (tester) async {
      coach.queue.add(menu);
      final c = await boot(tester);
      await sayChip(tester, l10n.coachChipCraving);
      final card = find.widgetWithText(
        ExerciseLauncherCard,
        l10n.exerciseBreathingTitle,
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await beat(tester);
      await tester.tap(find.byType(BackChevron));
      await beat(tester);
      await beat(tester);
      await tester.pumpAndSettle();
      final before = survived(c);

      await tester.tap(chip(l10n.coachAfterStill));
      await tester.pumpAndSettle();

      expect(composer(tester), l10n.coachAfterStill);
      expect(survived(c), before);
      expect(outcomes(), isEmpty);
    });
  });

  group('once the craving has passed', () {
    // The chat is told a craving is in progress two ways: the panic flow
    // sends its strength with the person, and the craving chip opens a
    // twenty-minute window. Neither used to end when the craving did. Having
    // said "It passed", the next thing typed still went out as a message
    // from inside it: in PANIC MODE if the strength had never been sent
    // (and a panic turn is told nothing about what they just did), with one
    // more card under "thanks" otherwise.
    const card = CoachReply(
      template: CoachTemplate.generic1,
      text: 'Breathe with me.',
      blocks: [breathing],
    );

    /// The breathing card, the exercise, "It passed" on its own screen, and
    /// "Back to the chat".
    Future<void> breatheAndPass(
      WidgetTester tester,
      ProviderContainer c,
    ) async {
      final launcher = find.widgetWithText(
        ExerciseLauncherCard,
        l10n.exerciseBreathingTitle,
      );
      await tester.ensureVisible(launcher);
      await tester.pumpAndSettle();
      await tester.tap(launcher);
      await beat(tester);
      expect(find.byType(BreathRing), findsOneWidget);
      await tester.tap(find.text(l10n.panicItPassed));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SurvivedScreen), findsOneWidget);
      await tester.ensureVisible(
        find.text(l10n.survivedBackChat, skipOffstage: false),
      );
      await tester.pump();
      await tester.tap(find.text(l10n.survivedBackChat));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(path(c), Routes.coach);
      expect(find.byType(SurvivedScreen), findsNothing);
    }

    int survived(ProviderContainer c) =>
        c.read(quitStoreProvider)!.cravingsSurvivedTotal;

    testWidgets('a strength nobody sent does not ride on what they say next', (
      tester,
    ) async {
      // An earlier turn left its cards under the newest reply.
      coach.queue.add(menu);
      final c = await boot(tester);
      await sayChip(tester, l10n.coachChipCraving);
      // Later the panic flow sends them here at 8/10. Before typing a word
      // they take the card that is already there.
      c.read(routerProvider).go('${Routes.coach}?panic=8');
      await tester.pumpAndSettle();
      final before = survived(c);

      await breatheAndPass(tester, c);
      expect(survived(c), before + 1);
      final sent = coach.extras.length;
      await say(tester, 'thanks');

      // An ordinary message: no strength, not from inside a craving, and so
      // Ember is told what they just did.
      expect(coach.extras, hasLength(sent + 1));
      expect(coach.panics.last, isNull);
      expect(coach.extras.last!.ui!.craving, isFalse);
      expect(coach.extras.last!.justDid!.id, ExerciseId.breathing);
      expect(coach.extras.last!.justDid!.passed, isTrue);
    });

    testWidgets('nor does the craving, once its strength has been sent', (
      tester,
    ) async {
      coach.queue
        ..add(card)
        ..add(card);
      final c = await boot(tester, location: '${Routes.coach}?panic=8');
      await say(tester, 'I am about to cave');
      expect(coach.panics.single, 8);
      expect(coach.extras.single!.ui!.craving, isTrue);
      expect(analytics.propsOfAll('coach_ui_shown').single['panic'], 'true');

      await breatheAndPass(tester, c);
      await say(tester, 'thanks');

      expect(coach.panics.last, isNull);
      expect(coach.extras.last!.ui!.craving, isFalse);
      // The card this reply happens to carry is not one offered mid-craving.
      expect(analytics.propsOfAll('coach_ui_shown'), hasLength(2));
      expect(analytics.propsOfAll('coach_ui_shown').last['panic'], 'false');
    });

    testWidgets('saying it passed with the chip ends it too', (tester) async {
      coach.queue.add(menu);
      final c = await boot(tester);
      await sayChip(tester, l10n.coachChipCraving);
      final launcher = find.widgetWithText(
        ExerciseLauncherCard,
        l10n.exerciseBreathingTitle,
      );
      await tester.ensureVisible(launcher);
      await tester.pumpAndSettle();
      await tester.tap(launcher);
      await beat(tester);
      await tester.tap(find.byType(BackChevron));
      await beat(tester);
      await beat(tester);
      await tester.pumpAndSettle();
      final before = survived(c);

      await tester.tap(
        find.descendant(
          of: find.byType(PressScale),
          matching: find.text(l10n.panicItPassed),
        ),
      );
      await tester.pumpAndSettle();
      expect(survived(c), before + 1);
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      expect(coach.extras.last!.ui!.craving, isFalse);
      expect(coach.extras.last!.justDid!.passed, isTrue);
    });

    testWidgets('a new craving afterwards is a new craving', (tester) async {
      coach.queue.add(card);
      final c = await boot(tester, location: '${Routes.coach}?panic=8');
      await say(tester, 'I am about to cave');
      await breatheAndPass(tester, c);
      await say(tester, 'thanks');
      expect(coach.extras.last!.ui!.craving, isFalse);

      // The chip again: its own turn gets the menu, what follows is inside.
      await sayChip(tester, l10n.coachChipCraving);
      expect(coach.chips.last, CoachChip.craving);
      expect(coach.extras.last!.ui!.craving, isFalse);
      await say(tester, 'it is back');
      expect(coach.extras.last!.ui!.craving, isTrue);

      // And the panic flow again, with its own strength.
      c.read(routerProvider).go('${Routes.coach}?panic=6');
      await tester.pumpAndSettle();
      await say(tester, 'worse now');
      expect(coach.panics.last, 6);
      expect(coach.extras.last!.ui!.craving, isTrue);
    });

    testWidgets('and the cap keeps its tongue until its own window closes', (
      tester,
    ) async {
      // A3 is a different clock. Surviving the craving ends what the chat
      // tells the server; it does not reopen the shop a minute later.
      coach.queue.add(
        const CoachReply(
          template: CoachTemplate.capReached,
          args: {'limit': LpAllowances.freeCoachMessages},
          messagesLeft: 0,
          isFreeTier: true,
        ),
      );
      final c = await boot(
        tester,
        premium: false,
        location: '${Routes.coach}?panic=9',
      );
      await say(tester, 'help');
      expect(find.text(l10n.premiumLockCta), findsNothing);

      // The craving the flow parked on its way here is counted.
      final panic = c.read(panicProvider.notifier)
        ..ensureStarted()
        ..park();
      expect(panic.surviveParked(), isTrue);
      await tester.pumpAndSettle();
      await advance(tester, c, const Duration(minutes: 5));

      expect(find.text(l10n.premiumLockCta), findsNothing);
      await say(tester, 'that was close');
      expect(coach.panics.last, isNull);
      expect(coach.extras.last!.ui!.craving, isFalse);

      await advance(tester, c, const Duration(minutes: 16));
      expect(find.text(l10n.premiumLockCta), findsWidgets);
    });
  });

  group('coming back from a survived craving', () {
    /// A free account whose messages are spent: the cap bubble, which carries
    /// an upgrade button except to somebody who walked in from a craving.
    const cap = CoachReply(
      template: CoachTemplate.capReached,
      args: {'limit': LpAllowances.freeCoachMessages},
      messagesLeft: 0,
      isFreeTier: true,
    );

    testWidgets('does not reopen the shop', (tester) async {
      coach.queue.add(cap);
      final arrived = clock.now;
      final c = await boot(
        tester,
        premium: false,
        location: '${Routes.coach}?panic=9',
      );
      await say(tester, 'help');
      expect(
        find.text(l10n.coachCapReached(LpAllowances.freeCoachMessages)),
        findsOneWidget,
      );
      expect(find.text(l10n.premiumLockCta), findsNothing);

      // Ten minutes on they are back from an exercise. "Back to the chat"
      // lands on the coach with no strength on the route.
      await advance(tester, c, const Duration(minutes: 10));
      c.read(routerProvider).go(Routes.coach);
      await tester.pumpAndSettle();
      expect(c.read(routerProvider).state.uri.queryParameters, isEmpty);
      expect(
        find.text(l10n.premiumLockCta),
        findsNothing,
        reason: 'the craving that sent them here has not passed',
      );

      // Still inside the window that was already running.
      await advance(tester, c, const Duration(minutes: 9));
      expect(find.text(l10n.premiumLockCta), findsNothing);

      // Twenty-one minutes after they ARRIVED, not after they came back: the
      // return did not start the window again.
      await advance(tester, c, const Duration(minutes: 2));
      expect(clock.now.difference(arrived), const Duration(minutes: 21));
      expect(find.text(l10n.premiumLockCta), findsOneWidget);
    });

    testWidgets('and a second craving starts its own window', (tester) async {
      coach.queue.add(cap);
      final c = await boot(
        tester,
        premium: false,
        location: '${Routes.coach}?panic=9',
      );
      await say(tester, 'help');

      // Back in the chat, then sent here again by a new craving.
      await advance(tester, c, const Duration(minutes: 5));
      c.read(routerProvider).go(Routes.coach);
      await tester.pumpAndSettle();
      await advance(tester, c, const Duration(minutes: 10));
      c.read(routerProvider).go('${Routes.coach}?panic=7');
      await tester.pumpAndSettle();

      // Twenty-one minutes after the first one, six after the second.
      await advance(tester, c, const Duration(minutes: 6));
      expect(find.text(l10n.premiumLockCta), findsNothing);
      await advance(tester, c, const Duration(minutes: 15));
      expect(find.text(l10n.premiumLockCta), findsOneWidget);
    });
  });
}

class _Clock {
  _Clock(this.now);

  DateTime now;

  DateTime read() => now;
}

/// A coach backend that answers the replies it was given, in order, and
/// remembers what each turn carried. The words stream first and the envelope
/// follows, as on the real backend, so a reply's cards arrive on a bubble
/// that already exists.
class _CardCoach implements CoachRepository {
  _CardCoach({this.stored = const []});

  final List<CoachMessage> stored;
  final List<CoachReply> queue = [];

  final List<CoachTurnExtras?> extras = [];
  final List<CoachChip?> chips = [];
  final List<int?> panics = [];

  /// When set, the envelope waits for it: the words are on screen and the
  /// cards have not arrived, for as many frames as the test likes.
  Completer<void>? hold;

  @override
  Stream<CoachEvent> streamReply({
    String? text,
    CoachChip? chip,
    required bool capped,
    int? panicIntensity,
    CoachTurnExtras? extras,
  }) async* {
    this.extras.add(extras);
    chips.add(chip);
    panics.add(panicIntensity);
    final reply = queue.isEmpty
        ? const CoachReply(template: CoachTemplate.generic1, text: 'Okay.')
        : queue.removeAt(0);
    final words = reply.text;
    if (words != null) yield CoachChunk(words);
    await hold?.future;
    yield CoachDone(reply);
  }

  @override
  Future<List<CoachMessage>> history() async => stored;

  @override
  Future<List<CoachMemory>> memories() async => const [];

  @override
  Future<void> seedMemories() async {}

  @override
  Future<void> forgetMemory(String id) async {}
}
