import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/date_key.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import 'providers.dart';

class CoachState {
  const CoachState({
    this.messages = const [],
    this.isTyping = false,
    this.freeUsedToday = 0,
    this.isRestoring = false,
    this.messagesLeft,
    this.isFreeTier,
  });

  final List<CoachMessage> messages;

  /// Ember has been asked and has not started speaking yet. Once the first
  /// chunk lands this drops and the bubble itself carries the progress.
  final bool isTyping;
  final int freeUsedToday;

  /// The stored transcript is being fetched. Distinct from [isTyping]: one is
  /// "Ember is thinking", the other is "we are finding what you already said".
  final bool isRestoring;

  /// The allowance as last reported by the side that enforces it. Null until
  /// the backend has said, and the counter stays hidden while it is.
  final int? messagesLeft;

  /// Whether that allowance is a capped free one worth putting on screen.
  final bool? isFreeTier;

  CoachState copyWith({
    List<CoachMessage>? messages,
    bool? isTyping,
    int? freeUsedToday,
    bool? isRestoring,
    int? messagesLeft,
    bool? isFreeTier,
  }) => CoachState(
    messages: messages ?? this.messages,
    isTyping: isTyping ?? this.isTyping,
    freeUsedToday: freeUsedToday ?? this.freeUsedToday,
    isRestoring: isRestoring ?? this.isRestoring,
    messagesLeft: messagesLeft ?? this.messagesLeft,
    isFreeTier: isFreeTier ?? this.isFreeTier,
  );
}

/// View model of Ember's thread. The reply decision lives behind
/// [CoachRepository] (scripted fake today, Gemini later — docs/04); this store
/// only manages the thread, the typing beat, and the free-tier counter.
class CoachStore extends Notifier<CoachState> {
  static const int freeDailyCap = 5;

  int _idCounter = 0;
  bool Function() _alive = () => false;

  @override
  CoachState build() {
    var alive = true;
    ref.onDispose(() => alive = false);
    _alive = () => alive;
    return const CoachState();
  }

  CoachRepository get _repo => ref.read(coachRepositoryProvider);

  /// What the composer uses to decide whether the user is out of messages.
  ///
  /// Prefers the server's own number. The local count is only a first guess for
  /// the very first message of a session: it lives in memory, resets on
  /// launch, never rolls over at midnight, and is derived from a tier the
  /// client wrote into its own document — so it is wrong in both directions
  /// and is replaced by the truth as soon as one reply lands.
  int get freeMessagesLeftToday {
    final reported = state.messagesLeft;
    if (reported != null) return reported;
    final premium = ref.read(isPremiumProvider);
    if (premium) return 1 << 20;
    final left = freeDailyCap - state.freeUsedToday;
    return left < 0 ? 0 : left;
  }

  /// Whether to show a remaining-messages count at all. Only when the backend
  /// has told us it is enforcing a capped free allowance.
  bool get showsAllowance =>
      state.isFreeTier == true && state.messagesLeft != null;

  /// Local + synchronous on purpose: an async greeting would flash an empty
  /// thread every time the coach tab opens.
  void seedGreetingIfEmpty() {
    if (state.messages.isNotEmpty) return;
    final j = ref.read(quitStoreProvider);
    state = state.copyWith(
      messages: [
        CoachMessage.ember(
          id: _nextId(),
          template: CoachTemplate.greeting,
          args: {
            'puffs': j?.plan.baselinePuffsPerDay ?? 0,
            'method': j?.plan.method.name ?? 'taper',
            // Local y/m/d packed as an int — epoch-day math shifts the date
            // across timezones.
            'freedomYmd': _ymd(j?.plan.freedomDate),
          },
          sentAt: DateTime.now(),
        ),
      ],
    );
  }

  /// Pulls the stored transcript in, so reopening the app continues the
  /// conversation instead of starting a new one.
  ///
  /// Falls back to the greeting when there is nothing stored, and on failure —
  /// a thread that will not load is not worth an error dialog, and the
  /// greeting is a perfectly good place to start.
  Future<void> restoreHistory() async {
    if (state.messages.isNotEmpty || state.isRestoring) return;
    state = state.copyWith(isRestoring: true);
    List<CoachMessage> stored;
    try {
      stored = await _repo.history();
    } on Exception {
      stored = const [];
    }
    if (!_alive()) return;
    state = state.copyWith(isRestoring: false, messages: stored);
    if (stored.isEmpty) seedGreetingIfEmpty();
  }

  Future<void> send(String text, {int? panicIntensity}) =>
      _handle(userText: text, panicIntensity: panicIntensity);

  Future<void> sendChip(CoachChip chip, {int? panicIntensity}) =>
      _handle(chip: chip, panicIntensity: panicIntensity);

  /// One of the two lines the client writes for a reply that never came.
  static bool isFailure(CoachMessage m) =>
      m.role == CoachRole.ember &&
      (m.template == CoachTemplate.connectionLost ||
          m.template == CoachTemplate.backendRejected);

  /// Re-asks the question a trailing failure line answered.
  ///
  /// Both bubbles come down first, so the thread reads as the question asked
  /// once and Ember answering it — not as the same words twice with an
  /// apology between them. The refund the failure path already made stands;
  /// this is a fresh attempt at the same message, not a second one.
  ///
  /// A no-op unless the thread ends in exactly that pair: nothing here can
  /// re-send a message that was answered.
  Future<void> retryLast() async {
    final messages = state.messages;
    if (state.isTyping || messages.length < 2) return;
    final failure = messages.last;
    final asked = messages[messages.length - 2];
    if (!isFailure(failure) || asked.role != CoachRole.user) return;
    state = state.copyWith(messages: messages.sublist(0, messages.length - 2));
    final chip = asked.chipEcho;
    await _handle(
      userText: chip == null ? asked.text : null,
      chip: chip == null ? null : CoachChip.values[chip],
    );
  }

  Future<void> _handle({
    String? userText,
    CoachChip? chip,
    int? panicIntensity,
  }) async {
    if (userText != null && userText.trim().isEmpty) return;
    final capped = freeMessagesLeftToday <= 0;

    final sentAt = DateTime.now();
    state = state.copyWith(
      messages: [
        ...state.messages,
        if (userText != null)
          CoachMessage.user(id: _nextId(), text: userText, sentAt: sentAt),
        if (chip != null)
          CoachMessage.chip(id: _nextId(), chipEcho: chip.index, sentAt: sentAt),
      ],
      isTyping: true,
      freeUsedToday: state.freeUsedToday + 1,
    );

    // The bubble Ember writes into. It is added on the first chunk rather than
    // up front, so a reply that never starts leaves no empty bubble behind.
    final streamId = _nextId();
    var streamed = '';
    CoachReply? reply;

    try {
      await for (final event in _repo.streamReply(
        text: userText,
        chip: chip,
        capped: capped,
        panicIntensity: panicIntensity,
      )) {
        if (!_alive()) return;
        switch (event) {
          case CoachChunk(:final text):
            streamed += text;
            state = state.copyWith(
              isTyping: false,
              messages: _withStreamed(streamId, streamed),
            );
          case CoachDone(reply: final done):
            reply = done;
        }
      }
    } on Exception catch (error) {
      // Offline or backend hiccup: Ember owns the miss in-thread, and the
      // attempt doesn't burn a free message.
      //
      // A refused build gets its own line. "Say that again once you're back
      // online" is actively misleading when the connection is fine and the
      // backend simply would not accept us — it sends the user to check a
      // router over something only we can fix.
      if (!_alive()) return;
      state = state.copyWith(
        isTyping: false,
        freeUsedToday: (state.freeUsedToday - 1).clamp(0, 1 << 20),
        messages: [
          // Drop the half-written bubble. A sentence that stopped mid-word is
          // worse than no sentence: it reads as Ember losing its train of
          // thought rather than as a failure that was nobody's fault.
          ...state.messages.where((m) => m.id != streamId),
          CoachMessage.ember(
            id: _nextId(),
            template: error is BackendRejectedException
                ? CoachTemplate.backendRejected
                : CoachTemplate.connectionLost,
            // Stamped like every live message: an un-stamped bubble
            // mid-thread makes the NEXT message render a spurious time pill.
            sentAt: DateTime.now(),
          ),
        ],
      );
      return;
    }

    // Sign-out invalidates this store while Ember is "typing".
    if (!_alive()) return;
    final done = reply;
    if (done == null) {
      // Every implementation ends with CoachDone; reaching here means the
      // stream closed without answering, which is a lost connection wearing a
      // success costume.
      state = state.copyWith(
        isTyping: false,
        freeUsedToday: (state.freeUsedToday - 1).clamp(0, 1 << 20),
        messages: [
          ...state.messages.where((m) => m.id != streamId),
          CoachMessage.ember(
            id: _nextId(),
            template: CoachTemplate.connectionLost,
            sentAt: DateTime.now(),
          ),
        ],
      );
      return;
    }

    // The envelope is authoritative — it carries the args, the week card, the
    // final text, and the allowance. Replacing the streamed bubble rather than
    // appending keeps one message per turn however the words arrived.
    state = state.copyWith(
      isTyping: false,
      messagesLeft: done.messagesLeft,
      isFreeTier: done.isFreeTier,
      messages: [
        ...state.messages.where((m) => m.id != streamId),
        CoachMessage.ember(
          id: streamed.isEmpty ? _nextId() : streamId,
          template: done.template,
          args: done.args,
          showWeekCard: done.showWeekCard,
          // Ember's own words when the model answered; null keeps the
          // template path for the deterministic replies. Prefer what actually
          // streamed when the envelope omits it.
          text: done.text ?? (streamed.isEmpty ? null : streamed),
          sentAt: DateTime.now(),
        ),
      ],
    );
  }

  /// The thread with Ember's in-progress bubble carrying [text].
  List<CoachMessage> _withStreamed(String id, String text) {
    final bubble = CoachMessage.ember(
      id: id,
      // Never rendered: `text` wins over the template whenever it is set.
      template: CoachTemplate.generic1,
      text: text,
    );
    final existing = state.messages.indexWhere((m) => m.id == id);
    if (existing < 0) return [...state.messages, bubble];
    final next = [...state.messages];
    next[existing] = bubble;
    return next;
  }

  static int _ymd(DateTime? d) => d == null ? 20260101 : LpDate.toYmdInt(d);

  String _nextId() => 'm${_idCounter++}';
}
