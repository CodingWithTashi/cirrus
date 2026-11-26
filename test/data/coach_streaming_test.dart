import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/api/coach_api.dart';
import 'package:last_puff/data/api/firebase/functions_client.dart';
import 'package:last_puff/data/repositories/api_coach_repository.dart';
import 'package:last_puff/data/repositories/firebase_coach_repository.dart';
import 'package:last_puff/data/stores/day1_tour_store.dart';
import 'package:last_puff/data/stores/exercise_runs.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/exercises/exercise.dart';
import 'package:last_puff/domain/models/coach_ui.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';

import '../helpers.dart';

/// Ember answering out loud, and remembering the conversation it is in.
///
/// Two failures are pinned here, both of which made a working backend read as
/// a dead one:
///
///  * the reply arrived all at once, because the client called the callable
///    unary while the server's streaming branch sat there as dead code;
///  * the visible thread was wiped on every cold start while the server kept
///    feeding the model the last ten turns — so Ember recalled a fact from
///    last week in a thread that had forgotten the last five minutes.
class _ScriptedCoach implements CoachRepository {
  _ScriptedCoach({
    this.chunks = const [],
    this.reply = const CoachReply(template: CoachTemplate.generic1),
    this.stored = const [],
    this.failAfterChunks,
    this.endWithoutDone = false,
    this.failFirstCalls = 0,
  });

  final List<String> chunks;
  final CoachReply reply;
  final List<CoachMessage> stored;

  /// Throw once this many chunks have been emitted, to model a stream that
  /// dies halfway through a sentence.
  final int? failAfterChunks;
  final bool endWithoutDone;

  /// Fail this many calls outright before answering, to model a reply that
  /// is lost and then asked for again.
  final int failFirstCalls;

  /// What the last call was told about the craving in progress.
  int? lastPanicIntensity;
  int historyCalls = 0;

  /// What every call carried beyond its words, in order.
  final List<CoachTurnExtras?> extras = [];

  @override
  Stream<CoachEvent> streamReply({
    String? text,
    CoachChip? chip,
    required bool capped,
    int? panicIntensity,
    CoachTurnExtras? extras,
  }) async* {
    lastPanicIntensity = panicIntensity;
    this.extras.add(extras);
    if (this.extras.length <= failFirstCalls) {
      throw const NoConnectionException();
    }
    var sent = 0;
    for (final chunk in chunks) {
      if (failAfterChunks != null && sent >= failAfterChunks!) {
        throw const NoConnectionException();
      }
      sent++;
      yield CoachChunk(chunk);
    }
    if (!endWithoutDone) yield CoachDone(reply);
  }

  @override
  Future<List<CoachMessage>> history() async {
    historyCalls++;
    return stored;
  }

  @override
  Future<List<CoachMemory>> memories() async => const [];

  @override
  Future<void> seedMemories() async {}

  @override
  Future<void> forgetMemory(String id) async {}
}

void main() {
  ProviderContainer withCoach(_ScriptedCoach coach) {
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        coachRepositoryProvider.overrideWithValue(coach),
      ],
    );
    addTearDown(container.dispose);
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    return container;
  }

  test('the reply builds up as it arrives, as one message', () async {
    final coach = _ScriptedCoach(
      chunks: const ['That wave ', 'is brutal, ', 'I know.'],
      reply: const CoachReply(
        template: CoachTemplate.generic1,
        text: 'That wave is brutal, I know.',
      ),
    );
    final container = withCoach(coach);
    final store = container.read(coachStoreProvider.notifier);

    await store.send('craving hard');
    final messages = container.read(coachStoreProvider).messages;

    // One user message, one Ember message — the growing bubble is replaced,
    // never appended alongside the finished one.
    final ember = messages.where((m) => m.role == CoachRole.ember).toList();
    expect(ember, hasLength(1));
    expect(ember.single.text, 'That wave is brutal, I know.');
  });

  test('typing stops the moment the first word lands', () async {
    // `isTyping` is the "Ember is thinking" beat. Once words are arriving the
    // bubble itself is the progress indicator, and showing both reads as two
    // replies in flight.
    final coach = _ScriptedCoach(
      chunks: const ['Okay.'],
      reply: const CoachReply(template: CoachTemplate.generic1, text: 'Okay.'),
    );
    final container = withCoach(coach);
    await container.read(coachStoreProvider.notifier).send('hi');
    expect(container.read(coachStoreProvider).isTyping, isFalse);
  });

  test('the envelope wins over the streamed text', () async {
    // The stream is prose; the envelope carries args and the week card. A turn
    // that kept only the chunks would drop the "YOUR WEEK" card entirely.
    final coach = _ScriptedCoach(
      chunks: const ['partial'],
      reply: const CoachReply(
        template: CoachTemplate.generic1,
        text: 'the whole considered answer',
        showWeekCard: true,
      ),
    );
    final container = withCoach(coach);
    await container.read(coachStoreProvider.notifier).send('how am I doing');

    final last = container.read(coachStoreProvider).messages.last;
    expect(last.text, 'the whole considered answer');
    expect(last.showWeekCard, isTrue);
  });

  test('a stream that dies mid-sentence leaves no half-written bubble', () async {
    final coach = _ScriptedCoach(
      chunks: const ['That wave ', 'is brut'],
      failAfterChunks: 1,
    );
    final container = withCoach(coach);
    await container.read(coachStoreProvider.notifier).send('craving hard');

    final messages = container.read(coachStoreProvider).messages;
    final ember = messages.where((m) => m.role == CoachRole.ember).toList();
    expect(ember, hasLength(1));
    expect(ember.single.template, CoachTemplate.connectionLost);
    // The truncated words are gone, not left on screen as Ember trailing off.
    expect(ember.single.text, isNull);
    expect(container.read(coachStoreProvider).freeUsedToday, 0);
  });

  test('a stream that ends without answering is a failure, not a reply', () async {
    final coach = _ScriptedCoach(
      chunks: const ['hello'],
      endWithoutDone: true,
    );
    final container = withCoach(coach);
    await container.read(coachStoreProvider.notifier).send('hi');

    final last = container.read(coachStoreProvider).messages.last;
    expect(last.template, CoachTemplate.connectionLost);
    expect(container.read(coachStoreProvider).freeUsedToday, 0);
  });

  test('a craving in progress reaches the server', () async {
    // Without this the PANIC_MODE addendum is unreachable code, and Ember
    // answers a 9/10 craving in its ordinary open-question register.
    final coach = _ScriptedCoach(chunks: const ['breathe']);
    final container = withCoach(coach);
    await container
        .read(coachStoreProvider.notifier)
        .send('I am about to cave', panicIntensity: 9);

    expect(coach.lastPanicIntensity, 9);
  });

  test('the intensity does not stick to later messages', () async {
    final coach = _ScriptedCoach(chunks: const ['ok']);
    final container = withCoach(coach);
    final store = container.read(coachStoreProvider.notifier);
    await store.send('help', panicIntensity: 8);
    await store.send('thanks');
    expect(coach.lastPanicIntensity, isNull);
  });

  group('coach cards', () {
    const everyExercise = ['breathing', 'orbs', 'tiles', 'blocks', 'sos'];
    const twoCards = [
      CoachLauncherBlock(ExerciseId.orbs),
      CoachLauncherBlock(ExerciseId.sos),
    ];

    /// The walkthrough on its coach step, the way the Day-1 screen puts it
    /// there: one task done, the second asked for.
    void startCoachStep(ProviderContainer container) {
      final quit = container.read(quitStoreProvider.notifier);
      quit.replaceForTest(
        container.read(quitStoreProvider)!.copyWith(day1TasksDone: const {0}),
      );
      container.read(day1TourProvider.notifier).start(Day1TourStep.meetCoach);
      expect(container.read(day1TourStepProvider), Day1TourStep.meetCoach);
    }

    test('the app says which exercises it can open', () async {
      // Capability negotiation is a list: the server offers only what this
      // build said it can draw, so the list is the registry's, in its order.
      final coach = _ScriptedCoach(chunks: const ['ok']);
      final container = withCoach(coach);
      final store = container.read(coachStoreProvider.notifier);

      await store.send('hello');
      await store.sendChip(CoachChip.craving);

      for (final extras in coach.extras) {
        expect(extras!.ui!.exercises, everyExercise);
        expect(extras.ui!.exercises, [
          for (final spec in Exercises.all) spec.id.name,
        ]);
        expect(extras.ui!.craving, isFalse);
        // Nothing was just done, so nothing is said about it.
        expect(extras.justDid, isNull);
      }
      expect(coach.extras, hasLength(2));
    });

    test('a message sent inside a craving says so', () async {
      final coach = _ScriptedCoach(chunks: const ['ok']);
      final container = withCoach(coach);
      final store = container.read(coachStoreProvider.notifier);

      await store.send('still here', craving: true);
      await store.sendChip(CoachChip.roughDay, craving: true);
      await store.send('better now');

      expect([for (final e in coach.extras) e!.ui!.craving], [
        true,
        true,
        false,
      ]);
    });

    test('no cards are asked for during the Day-1 coach step', () async {
      // The walkthrough leaves for the checklist 2.5 s after the reply. A
      // card under it would be on screen for exactly as long as it takes to
      // start reading it. Saying nothing about what this build can draw is
      // how an older build looks to the server: no cards.
      final coach = _ScriptedCoach(chunks: const ['ok']);
      final container = withCoach(coach);
      startCoachStep(container);

      await container.read(coachStoreProvider.notifier).send('hi ember');

      expect(coach.extras.single!.ui, isNull);
      expect(coach.extras.single!.toJson(), isEmpty);
    });

    test("a reply's cards land on its message", () async {
      final coach = _ScriptedCoach(
        reply: const CoachReply(
          template: CoachTemplate.craving1,
          blocks: twoCards,
        ),
      );
      final container = withCoach(coach);
      await container
          .read(coachStoreProvider.notifier)
          .sendChip(CoachChip.craving);

      final messages = container.read(coachStoreProvider).messages;
      expect(messages.last.role, CoachRole.ember);
      expect(messages.last.blocks, twoCards);
      // And on nothing else in the thread.
      for (final m in messages.take(messages.length - 1)) {
        expect(m.blocks, isEmpty);
      }
    });

    test('a reply that streamed keeps its cards and its one bubble', () async {
      // The real backend: the words arrive first, into a bubble that has no
      // cards yet, and the envelope that carries them replaces it in place.
      final coach = _ScriptedCoach(
        chunks: const ['Fifteen minutes ', 'and it breaks.'],
        reply: const CoachReply(
          template: CoachTemplate.generic1,
          text: 'Fifteen minutes and it breaks.',
          blocks: twoCards,
        ),
      );
      final container = withCoach(coach);
      final seen = <List<CoachBlock>>[];
      final ids = <String>{};
      container.listen(coachStoreProvider, (_, next) {
        final last = next.messages.lastOrNull;
        if (last == null || last.role != CoachRole.ember) return;
        seen.add(last.blocks);
        ids.add(last.id);
      });

      await container.read(coachStoreProvider.notifier).send('craving hard');

      // Empty while it streamed, the cards once it was whole, one message id.
      expect(seen.first, isEmpty);
      expect(seen.last, twoCards);
      expect(ids, hasLength(1));
      final ember = container
          .read(coachStoreProvider)
          .messages
          .where((m) => m.role == CoachRole.ember);
      expect(ember, hasLength(1));
    });

    test('a card that arrives during the Day-1 coach step is not kept', () async {
      // The other half of not asking: a server that sends one anyway (a
      // policy change, a bug) still cannot put a card under that reply.
      final coach = _ScriptedCoach(
        reply: const CoachReply(
          template: CoachTemplate.generic1,
          text: 'Good to meet you.',
          blocks: twoCards,
        ),
      );
      final container = withCoach(coach);
      startCoachStep(container);

      await container.read(coachStoreProvider.notifier).send('hi ember');

      final last = container.read(coachStoreProvider).messages.last;
      expect(last.text, 'Good to meet you.');
      expect(last.blocks, isEmpty);
    });

    test('a retry asks the way the first attempt did', () async {
      // "Run it back" is the same message asked again, so it is asked from
      // inside the same craving: one next step, not the menu.
      final coach = _ScriptedCoach(chunks: const ['ok'], failFirstCalls: 1);
      final container = withCoach(coach);
      final store = container.read(coachStoreProvider.notifier);

      await store.send('it is getting worse', craving: true);
      expect(
        container.read(coachStoreProvider).messages.last.template,
        CoachTemplate.connectionLost,
      );
      await store.retryLast();

      expect(coach.extras, hasLength(2));
      expect(coach.extras.last!.ui!.craving, isTrue);
      expect(coach.extras.last!.ui!.exercises, everyExercise);
    });

    test('the wire carries the extras', () async {
      // `aiCoachChat` reads `ui` off the request it is handed; the store
      // building it is no use if the repository drops it on the way out.
      final functions = _RecordingFunctions();
      final repository = FirebaseCoachRepository(functions: functions);
      const extras = CoachTurnExtras(
        ui: CoachUiCaps(exercises: everyExercise, craving: true),
      );

      await repository
          .streamReply(
            text: 'it is back',
            capped: false,
            panicIntensity: 8,
            extras: extras,
          )
          .drain<void>();

      const expected = {
        'text': 'it is back',
        'panicIntensity': 8,
        'ui': {'v': 1, 'exercises': everyExercise, 'craving': true},
      };
      // The stream, and the plain call that re-asks when a stream ends
      // before a word (Android answers every failure that way).
      expect(functions.names, ['stream aiCoachChat', 'call aiCoachChat']);
      expect(functions.streamed, [expected]);
      expect(functions.called, [expected]);
    });

    test('a turn with no extras is the request an older build makes', () async {
      // Every addition is optional. With nothing to add, the payload is
      // byte for byte what it was before cards existed.
      final functions = _RecordingFunctions();
      final repository = FirebaseCoachRepository(functions: functions);

      await repository
          .streamReply(chip: CoachChip.progress, capped: true)
          .drain<void>();
      await repository
          .streamReply(
            text: 'hi',
            capped: false,
            extras: const CoachTurnExtras(),
          )
          .drain<void>();

      expect(functions.streamed, [
        {'chip': 'progress'},
        {'text': 'hi'},
      ]);
      expect(functions.called, functions.streamed);
    });

    test('the fake wire carries them too, and the strength', () async {
      // The demo backend used to drop `panicIntensity` on the floor, which
      // made a craving handed to the coach indistinguishable from a hello.
      final api = _RecordingCoachApi();
      const extras = CoachTurnExtras(
        ui: CoachUiCaps(exercises: everyExercise),
      );

      await ApiCoachRepository(api)
          .streamReply(
            chip: CoachChip.craving,
            capped: false,
            panicIntensity: 7,
            extras: extras,
          )
          .drain<void>();
      await ApiCoachRepository(api)
          .streamReply(text: 'hello', capped: false)
          .drain<void>();

      expect(api.requests, [
        {
          'chip': 'craving',
          'capped': false,
          'panicIntensity': 7,
          'ui': {'v': 1, 'exercises': everyExercise, 'craving': false},
        },
        {'text': 'hello', 'capped': false},
      ]);
    });
  });

  group('what they just did', () {
    const afterOrbs = ExerciseRun(
      id: ExerciseId.orbs,
      source: ExerciseSource.coach,
      seconds: 61,
      completed: true,
      passed: false,
    );

    /// A container on a clock the test moves: a run is news for one craving.
    (ProviderContainer, _Clock) withCoachAt(_ScriptedCoach coach) {
      final clock = _Clock(DateTime(2026, 9, 5, 14));
      final container = ProviderContainer(
        overrides: fastBackendOverrides(
          extra: [
            coachRepositoryProvider.overrideWithValue(coach),
            nowProvider.overrideWithValue(clock.read),
          ],
        ),
      );
      addTearDown(container.dispose);
      container.read(quitStoreProvider.notifier).seedDemoJourney();
      return (container, clock);
    }

    test('the next message carries what they just did, once', () async {
      final coach = _ScriptedCoach(chunks: const ['ok']);
      final (container, _) = withCoachAt(coach);
      final store = container.read(coachStoreProvider.notifier);
      container.read(exerciseRunsProvider.notifier).report(afterOrbs);

      await store.send('that helped a bit');
      await store.send('thanks');

      expect(coach.extras.first!.justDid, same(afterOrbs));
      expect(coach.extras.first!.toJson()['justDid'], {
        'exercise': 'orbs',
        'seconds': 61,
        'completed': true,
        'passed': false,
      });
      // Told once. The second message is not about the exercise.
      expect(coach.extras.last!.justDid, isNull);
      expect(coach.extras.last!.toJson().containsKey('justDid'), isFalse);
      expect(container.read(exerciseRunsProvider), isNull);
      // And it still says what this build can draw.
      expect(coach.extras.first!.ui, isNotNull);
    });

    test("a run from the panic flow is not the chat's to report", () async {
      // The takeover reports its own cravings. The chat tells Ember only
      // about an exercise the chat offered.
      final coach = _ScriptedCoach(chunks: const ['ok']);
      final (container, _) = withCoachAt(coach);
      const fromPanic = ExerciseRun(
        id: ExerciseId.orbs,
        source: ExerciseSource.panic,
        seconds: 61,
        completed: true,
        passed: true,
      );
      container.read(exerciseRunsProvider.notifier).report(fromPanic);

      await container.read(coachStoreProvider.notifier).send('hello');

      expect(coach.extras.single!.justDid, isNull);
      // Left where it was: it was never this store's to take.
      expect(container.read(exerciseRunsProvider), same(fromPanic));
    });

    test('a run older than a craving is not news', () async {
      final coach = _ScriptedCoach(chunks: const ['ok']);
      final (container, clock) = withCoachAt(coach);
      container.read(exerciseRunsProvider.notifier).report(afterOrbs);

      clock.now = clock.now.add(const Duration(minutes: 20));
      await container.read(coachStoreProvider.notifier).send('morning');

      expect(coach.extras.single!.justDid, isNull);
    });

    test('a craving counted from the chat is reported as passed', () async {
      // "It passed" said with the chat's chip counts the craving, so the
      // person's total has already gone up. A run still marked "not passed"
      // would have the server leave out its "already counted" note, which is
      // the condition under which Ember quoted a total one higher than the
      // one on the card. The store sends its own copy, marked passed; the
      // filed run is not reported a second time.
      final analytics = RecordingAnalytics();
      final coach = _ScriptedCoach(chunks: const ['ok']);
      final container = ProviderContainer(
        overrides: fastBackendOverrides(
          analytics: analytics,
          extra: [coachRepositoryProvider.overrideWithValue(coach)],
        ),
      );
      addTearDown(container.dispose);
      container.read(quitStoreProvider.notifier).seedDemoJourney();
      final store = container.read(coachStoreProvider.notifier);
      container.read(exerciseRunsProvider.notifier).report(afterOrbs);
      expect(store.runHasPassed(afterOrbs), isFalse);

      store.markRunPassed(afterOrbs);
      expect(store.runHasPassed(afterOrbs), isTrue);
      await store.send('it passed');
      await store.send('thanks');

      expect(coach.extras.first!.toJson()['justDid'], {
        'exercise': 'orbs',
        'seconds': 61,
        'completed': true,
        'passed': true,
      });
      expect(coach.extras.first!.justDid!.source, ExerciseSource.coach);
      // Told once, and the run is gone with it.
      expect(coach.extras.last!.justDid, isNull);
      expect(container.read(exerciseRunsProvider), isNull);
      // One exercise, one `exercise_finished`: as it was filed.
      expect(analytics.propsOfAll('exercise_finished'), [
        {
          'exercise': 'orbs',
          'source': 'coach',
          'completed': 'true',
          'passed': 'false',
          'seconds': 61,
        },
      ]);
    });

    test('only the run that was counted is reported as passed', () async {
      final coach = _ScriptedCoach(chunks: const ['ok']);
      final (container, _) = withCoachAt(coach);
      final store = container.read(coachStoreProvider.notifier);
      // An earlier run was counted from the chat; a later one replaced it.
      store.markRunPassed(afterOrbs);
      const later = ExerciseRun(
        id: ExerciseId.breathing,
        source: ExerciseSource.coach,
        seconds: 20,
        completed: false,
        passed: false,
      );
      container.read(exerciseRunsProvider.notifier).report(later);

      expect(store.runHasPassed(later), isFalse);
      await store.send('not yet');

      expect(coach.extras.single!.justDid, same(later));
      expect(coach.extras.single!.justDid!.passed, isFalse);
    });

    for (final (what, envelope) in const [
      (
        'the cap',
        CoachReply(
          template: CoachTemplate.capReached,
          args: {'limit': 5},
          messagesLeft: 0,
          isFreeTier: true,
        ),
      ),
      (
        'an outage the server reports',
        CoachReply(template: CoachTemplate.connectionLost),
      ),
    ]) {
      test('$what is not a reply: what they just did waits for one', () async {
        // Both come back as an ordinary envelope, so "a reply came back" is
        // not the test. Ember said nothing about the exercise either way,
        // and a run taken here takes the two chips with it: after that the
        // craving behind it could not be counted from the chat at all.
        final coach = _ScriptedCoach(reply: envelope);
        final (container, _) = withCoachAt(coach);
        final store = container.read(coachStoreProvider.notifier);
        container.read(exerciseRunsProvider.notifier).report(afterOrbs);

        await store.send('that helped');

        expect(
          container.read(coachStoreProvider).messages.last.template,
          envelope.template,
        );
        expect(coach.extras.single!.justDid, same(afterOrbs));
        expect(container.read(exerciseRunsProvider), same(afterOrbs));

        // Whatever is tried next carries it again.
        if (envelope.template == CoachTemplate.connectionLost) {
          await store.retryLast();
        } else {
          await store.send('hello?');
        }
        expect(coach.extras.last!.justDid, same(afterOrbs));
        expect(container.read(exerciseRunsProvider), same(afterOrbs));
      });
    }

    test('a reply that was lost does not lose what they just did', () async {
      // The run is handed over when the message is sent. If that send never
      // got an answer, "run it back" is the same message and carries it
      // again; otherwise Ember is simply never told.
      final coach = _ScriptedCoach(chunks: const ['ok'], failFirstCalls: 1);
      final (container, _) = withCoachAt(coach);
      final store = container.read(coachStoreProvider.notifier);
      container.read(exerciseRunsProvider.notifier).report(afterOrbs);

      await store.send('that helped');
      expect(coach.extras.single!.justDid, same(afterOrbs));
      await store.retryLast();
      await store.send('thanks');

      expect([for (final e in coach.extras) e!.justDid], [
        same(afterOrbs),
        same(afterOrbs),
        isNull,
      ]);
    });
  });

  group('the message counter', () {
    test('stays hidden until the server says what it is enforcing', () async {
      final container = withCoach(_ScriptedCoach(chunks: const ['hi']));
      final store = container.read(coachStoreProvider.notifier);
      expect(store.showsAllowance, isFalse);
    });

    test('shows the server number, not the local guess', () async {
      // The local count starts at 5 and decrements; the server is the only
      // side that knows about midnight, other devices, or the real tier.
      final coach = _ScriptedCoach(
        chunks: const ['ok'],
        reply: const CoachReply(
          template: CoachTemplate.generic1,
          text: 'ok',
          messagesLeft: 3,
          isFreeTier: true,
        ),
      );
      final container = withCoach(coach);
      final store = container.read(coachStoreProvider.notifier);
      await store.send('hi');

      expect(store.showsAllowance, isTrue);
      expect(store.freeMessagesLeftToday, 3);
    });

    test('a premium allowance is never put on screen', () async {
      final coach = _ScriptedCoach(
        chunks: const ['ok'],
        reply: const CoachReply(
          template: CoachTemplate.generic1,
          text: 'ok',
          messagesLeft: 97,
          isFreeTier: false,
        ),
      );
      final container = withCoach(coach);
      final store = container.read(coachStoreProvider.notifier);
      await store.send('hi');

      expect(store.showsAllowance, isFalse);
    });
  });

  group('restoring the thread', () {
    test('a stored conversation comes back instead of a greeting', () async {
      final coach = _ScriptedCoach(
        stored: const [
          CoachMessage.user(id: 'h_1', text: 'work party tonight'),
          CoachMessage.ember(
            id: 'h_2',
            template: CoachTemplate.generic1,
            text: 'Hold a cold drink all night.',
          ),
        ],
      );
      final container = withCoach(coach);
      await container.read(coachStoreProvider.notifier).restoreHistory();

      final messages = container.read(coachStoreProvider).messages;
      expect(messages, hasLength(2));
      expect(messages.first.text, 'work party tonight');
      expect(
        messages.any((m) => m.template == CoachTemplate.greeting),
        isFalse,
        reason: 'a continued conversation must not restart with hello',
      );
    });

    test('an empty history still greets', () async {
      final container = withCoach(_ScriptedCoach());
      await container.read(coachStoreProvider.notifier).restoreHistory();

      final messages = container.read(coachStoreProvider).messages;
      expect(messages, hasLength(1));
      expect(messages.single.template, CoachTemplate.greeting);
    });

    test('a failed restore greets rather than showing an error', () async {
      // The thread is not worth a dialog: the greeting is a perfectly good
      // place to start, and the user has a craving to deal with.
      final container = withCoach(_FailingHistoryCoach());
      await container.read(coachStoreProvider.notifier).restoreHistory();

      final messages = container.read(coachStoreProvider).messages;
      expect(messages.single.template, CoachTemplate.greeting);
    });

    test('reopening does not refetch or duplicate', () async {
      final coach = _ScriptedCoach(
        stored: const [CoachMessage.user(id: 'h_1', text: 'hi')],
      );
      final container = withCoach(coach);
      final store = container.read(coachStoreProvider.notifier);
      await store.restoreHistory();
      await store.restoreHistory();

      expect(coach.historyCalls, 1);
      expect(container.read(coachStoreProvider).messages, hasLength(1));
    });
  });
}

/// The app's own door to Cloud Functions, recording what it is handed. Not a
/// Firebase mock: nothing below this seam is constructed.
class _RecordingFunctions implements LpFunctions {
  final names = <String>[];
  final streamed = <Map<String, Object?>>[];
  final called = <Map<String, Object?>>[];

  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, Object?> data = const {},
    Duration? timeout,
  ]) async {
    names.add('call $name');
    called.add(data);
    return const {'template': 'generic1'};
  }

  /// Ends before a word, as the Android plugin does on any failure, so the
  /// repository goes on to ask again over [call].
  @override
  Stream<({String? chunk, Map<String, dynamic>? result})> stream(
    String name, [
    Map<String, Object?> data = const {},
  ]) {
    names.add('stream $name');
    streamed.add(data);
    return const Stream.empty();
  }
}

class _RecordingCoachApi implements CoachApi {
  final requests = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> requestReply(
    Map<String, dynamic> request,
  ) async {
    requests.add(request);
    return const {'template': 'generic1'};
  }
}

class _Clock {
  _Clock(this.now);

  DateTime now;

  DateTime read() => now;
}

class _FailingHistoryCoach extends _ScriptedCoach {
  @override
  Future<List<CoachMessage>> history() async =>
      throw const NoConnectionException();
}
