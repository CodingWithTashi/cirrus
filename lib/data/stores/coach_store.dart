import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/journey_state.dart';
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

/// Scripted, stat-aware Ember (docs/04). Picks a protocol from the user's
/// words, injects their real numbers, and never repeats the same celebration
/// twice in a row — the same contract the Gemini flow will honor server-side.
class CoachStore extends Notifier<CoachState> implements CoachRepository {
  static const int freeDailyCap = 5;

  final _random = Random();
  int _idCounter = 0;
  CoachTemplate? _lastTemplate;

  @override
  CoachState build() => const CoachState();

  @override
  List<CoachMessage> get messages => state.messages;

  @override
  bool get isTyping => state.isTyping;

  @override
  int get freeMessagesLeftToday {
    final premium = ref.read(quitStoreProvider)?.profile.isPremium ?? true;
    if (premium) return 1 << 20;
    final left = freeDailyCap - state.freeUsedToday;
    return left < 0 ? 0 : left;
  }

  @override
  void seedGreetingIfEmpty() {
    if (state.messages.isNotEmpty) return;
    final snap = _snapshot();
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
            'freedomYmd': _ymd(snap?.freedomDate),
          },
        ),
      ],
    );
  }

  @override
  Future<void> send(String text) =>
      _handle(userText: text, template: _pick(text));

  @override
  Future<void> sendChip(CoachChip chip) {
    final template = switch (chip) {
      CoachChip.craving => _rotate([
        CoachTemplate.craving1,
        CoachTemplate.craving2,
        CoachTemplate.craving3,
      ]),
      CoachChip.roughDay => _rotate([
        CoachTemplate.rough1,
        CoachTemplate.rough2,
      ]),
      CoachChip.slipped => _rotate([CoachTemplate.slip1, CoachTemplate.slip2]),
      CoachChip.progress => _rotate([
        CoachTemplate.progress1,
        CoachTemplate.progress2,
      ]),
    };
    return _handle(chip: chip, template: template);
  }

  Future<void> _handle({
    String? userText,
    CoachChip? chip,
    required CoachTemplate template,
  }) async {
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

    await Future<void>.delayed(
      Duration(milliseconds: 700 + _random.nextInt(700)),
    );

    final effective = capped ? CoachTemplate.capReached : template;
    _lastTemplate = effective;
    state = state.copyWith(
      isTyping: false,
      messages: [
        ...state.messages,
        CoachMessage.ember(
          id: _nextId(),
          template: effective,
          args: _argsFor(effective),
          showWeekCard:
              effective == CoachTemplate.progress1 ||
              effective == CoachTemplate.progress2,
        ),
      ],
    );
  }

  /// Keyword protocol routing (docs/04 §4) — swapped for the model later.
  CoachTemplate _pick(String text) {
    final t = text.toLowerCase();
    bool hasAny(List<String> words) => words.any(t.contains);
    if (hasAny(['crav', 'want one', 'need a hit', 'urge', 'dying for'])) {
      return _rotate([
        CoachTemplate.craving1,
        CoachTemplate.craving2,
        CoachTemplate.craving3,
      ]);
    }
    if (hasAny(['slip', 'caved', 'messed up', 'relapse', 'hit my friend'])) {
      return _rotate([CoachTemplate.slip1, CoachTemplate.slip2]);
    }
    if (hasAny([
      'party',
      'bar tonight',
      'drinks',
      'friends vape',
      'everyone vapes',
    ])) {
      return CoachTemplate.party;
    }
    if (hasAny(['progress', 'how am i doing', 'stats', 'numbers'])) {
      return _rotate([CoachTemplate.progress1, CoachTemplate.progress2]);
    }
    if (hasAny(['rough', 'stress', 'work is', 'bad day', 'tired', 'insane'])) {
      return _rotate([CoachTemplate.rough1, CoachTemplate.rough2]);
    }
    return _rotate([
      CoachTemplate.generic1,
      CoachTemplate.generic2,
      CoachTemplate.generic3,
      CoachTemplate.generic4,
    ]);
  }

  /// Variable reward: never the same line twice in a row (docs/03 §7).
  CoachTemplate _rotate(List<CoachTemplate> options) {
    final pool = options
        .where((o) => o != _lastTemplate)
        .toList(growable: false);
    return pool[_random.nextInt(pool.length)];
  }

  Map<String, Object> _argsFor(CoachTemplate template) {
    final snap = _snapshot();
    if (snap == null) return const {};
    return {
      'day': snap.dayNumber,
      'today': snap.puffs,
      'limit': snap.limit,
      'count': snap.cravingsSurvivedTotal,
      'saved': snap.savedLifetime,
      'percent': -snap.vsDay1Percent,
      'streak': snap.streak,
    };
  }

  TodaySnapshot? _snapshot() {
    final j = ref.read(quitStoreProvider);
    return j == null ? null : TodaySnapshot.of(j, DateTime.now());
  }

  static int _ymd(DateTime? d) =>
      d == null ? 20260101 : d.year * 10000 + d.month * 100 + d.day;

  String _nextId() => 'm${_idCounter++}';
}
