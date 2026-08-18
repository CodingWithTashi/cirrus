import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import 'providers.dart';

class CoachState {
  const CoachState({
    this.messages = const [],
    this.isTyping = false,
    this.freeUsedToday = 0,
  });

  final List<CoachMessage> messages;
  final bool isTyping;
  final int freeUsedToday;

  CoachState copyWith({
    List<CoachMessage>? messages,
    bool? isTyping,
    int? freeUsedToday,
  }) => CoachState(
    messages: messages ?? this.messages,
    isTyping: isTyping ?? this.isTyping,
    freeUsedToday: freeUsedToday ?? this.freeUsedToday,
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

  int get freeMessagesLeftToday {
    final premium = ref.read(quitStoreProvider)?.profile.isPremium ?? true;
    if (premium) return 1 << 20;
    final left = freeDailyCap - state.freeUsedToday;
    return left < 0 ? 0 : left;
  }

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
        ),
      ],
    );
  }

  Future<void> send(String text) => _handle(userText: text);

  Future<void> sendChip(CoachChip chip) => _handle(chip: chip);

  Future<void> _handle({String? userText, CoachChip? chip}) async {
    if (userText != null && userText.trim().isEmpty) return;
    final capped = freeMessagesLeftToday <= 0;

    state = state.copyWith(
      messages: [
        ...state.messages,
        if (userText != null) CoachMessage.user(id: _nextId(), text: userText),
        if (chip != null)
          CoachMessage.chip(id: _nextId(), chipEcho: chip.index),
      ],
      isTyping: true,
      freeUsedToday: state.freeUsedToday + 1,
    );

    CoachReply reply;
    try {
      reply = await _repo.requestReply(
        text: userText,
        chip: chip,
        capped: capped,
      );
    } on Exception {
      // Offline or backend hiccup: Ember owns the miss in-thread, and the
      // attempt doesn't burn a free message.
      if (!_alive()) return;
      state = state.copyWith(
        isTyping: false,
        freeUsedToday: (state.freeUsedToday - 1).clamp(0, 1 << 20),
        messages: [
          ...state.messages,
          CoachMessage.ember(
            id: _nextId(),
            template: CoachTemplate.connectionLost,
          ),
        ],
      );
      return;
    }

    // Sign-out invalidates this store while Ember is "typing".
    if (!_alive()) return;
    state = state.copyWith(
      isTyping: false,
      messages: [
        ...state.messages,
        CoachMessage.ember(
          id: _nextId(),
          template: reply.template,
          args: reply.args,
          showWeekCard: reply.showWeekCard,
        ),
      ],
    );
  }

  static int _ymd(DateTime? d) =>
      d == null ? 20260101 : d.year * 10000 + d.month * 100 + d.day;

  String _nextId() => 'm${_idCounter++}';
}
