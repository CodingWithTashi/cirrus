import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/providers.dart';
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
  });

  final List<String> chunks;
  final CoachReply reply;
  final List<CoachMessage> stored;

  /// Throw once this many chunks have been emitted, to model a stream that
  /// dies halfway through a sentence.
  final int? failAfterChunks;
  final bool endWithoutDone;

  /// What the last call was told about the craving in progress.
  int? lastPanicIntensity;
  int historyCalls = 0;

  @override
  Stream<CoachEvent> streamReply({
    String? text,
    CoachChip? chip,
    required bool capped,
    int? panicIntensity,
  }) async* {
    lastPanicIntensity = panicIntensity;
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

class _FailingHistoryCoach extends _ScriptedCoach {
  @override
  Future<List<CoachMessage>> history() async =>
      throw const NoConnectionException();
}
