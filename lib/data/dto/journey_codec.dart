import '../../domain/date_key.dart';
import '../../domain/logic/games/game_id.dart';
import '../../domain/models/journey_state.dart';
import '../../domain/models/models.dart';
import 'codec_helpers.dart';

/// JSON mapping for the quit journey aggregate. This is the wire format the
/// fake backend serves today and a REST API or Firestore document would serve
/// later — any new model field must be added here AND to the round-trip test.
abstract final class JourneyCodec {
  static Map<String, dynamic> encode(JourneyState s) => {
    'profile': encodeProfile(s.profile),
    'plan': encodePlan(s.plan),
    'days': {
      for (final e in s.days.entries)
        encodeDayKey(e.key): _encodeDayLog(e.value),
    },
    'cravingsSurvivedTotal': s.cravingsSurvivedTotal,
    'repairTokens': s.repairTokens,
    'longestStreak': s.longestStreak,
    'goals': [for (final g in s.goals) _encodeGoal(g)],
    'earnedBadges': s.earnedBadges.toList(),
    'lastPuffAt': s.lastPuffAt == null ? null : encodeTimestamp(s.lastPuffAt!),
    'day1TasksDone': s.day1TasksDone.toList(),
    'day1TourSkipped': s.day1TourSkipped,
    'pendingSlipCleanDays': s.pendingSlipCleanDays,
    'moodCheckIns': s.moodCheckIns,
    'planAdvice': s.planAdvice == null ? null : _encodeAdvice(s.planAdvice!),
    'gameBests': {for (final e in s.gameBests.entries) e.key.name: e.value},
    'lastGame': s.lastGame?.name,
    // Written only once there is an answer, so a journey nobody asked stays
    // byte-for-byte the document it always was (docs/15 QP-B7).
    if (s.checkups.isNotEmpty) 'checkups': _encodeCheckups(s.checkups),
  };

  static Map<String, dynamic> _encodeCheckups(
    Map<DateTime, Map<CheckupKind, CheckupAnswer>> checkups,
  ) => {
    for (final e in checkups.entries)
      encodeDayKey(e.key): {
        for (final a in e.value.entries) a.key.name: a.value.name,
      },
  };

  /// The program's check-up answers, keyed by the day they were given. Decoded
  /// defensively because it is client-written and a newer build may write what
  /// this one does not know: an unknown question, an unknown answer, an answer
  /// that belongs to a different question, a bad day key and a value that is
  /// not a map are all DROPPED, and a day left with nothing disappears. A
  /// decode that threw on any of them would take the account down at launch.
  static Map<DateTime, Map<CheckupKind, CheckupAnswer>> _decodeCheckups(
    Object? raw,
  ) {
    if (raw is! Map) return const {};
    final out = <DateTime, Map<CheckupKind, CheckupAnswer>>{};
    for (final day in raw.entries) {
      final key = day.key;
      final answers = day.value;
      if (key is! String || !LpDate.isDayKey(key) || answers is! Map) continue;
      final kept = <CheckupKind, CheckupAnswer>{};
      for (final a in answers.entries) {
        final kind = enumByNameOrNull(CheckupKind.values, a.key);
        final answer = enumByNameOrNull(CheckupAnswer.values, a.value);
        if (kind != null && answer != null && kind.answers.contains(answer)) {
          kept[kind] = answer;
        }
      }
      if (kept.isNotEmpty) out[decodeDayKey(key)] = kept;
    }
    return out;
  }

  static JourneyState decode(Map<String, dynamic> json) => JourneyState(
    profile: decodeProfile(json['profile'] as Map<String, dynamic>),
    plan: decodePlan(json['plan'] as Map<String, dynamic>),
    days: {
      for (final e in (json['days'] as Map<String, dynamic>).entries)
        decodeDayKey(e.key): _decodeDayLog(
          e.key,
          e.value as Map<String, dynamic>,
        ),
    },
    cravingsSurvivedTotal: json['cravingsSurvivedTotal'] as int,
    repairTokens: json['repairTokens'] as int,
    longestStreak: json['longestStreak'] as int,
    goals: [
      for (final g in json['goals'] as List)
        _decodeGoal(g as Map<String, dynamic>),
    ],
    earnedBadges: (json['earnedBadges'] as List).cast<String>().toSet(),
    lastPuffAt: json['lastPuffAt'] == null
        ? null
        : decodeTimestamp(json['lastPuffAt'] as String),
    // Both defaulted: a journey written before the checklist (or the tour)
    // existed is missing these keys, and a decode that threw on one would
    // take the whole account down on the next launch.
    day1TasksDone:
        (json['day1TasksDone'] as List? ?? const []).cast<int>().toSet(),
    day1TourSkipped: json['day1TourSkipped'] as bool? ?? false,
    pendingSlipCleanDays: json['pendingSlipCleanDays'] as int?,
    moodCheckIns: json['moodCheckIns'] as int,
    planAdvice: json['planAdvice'] == null
        ? null
        : decodeAdvice(json['planAdvice'] as Map<String, dynamic>),
    gameBests: _decodeGameBests(json),
    lastGame: enumByNameOrNull(GameId.values, json['lastGame']),
    checkups: _decodeCheckups(json['checkups']),
  );

  /// Per-game bests keyed by `GameId.name`; missing means never played. The
  /// single-game `bestGameScore` is read once as the tiles best, never
  /// written again; an unknown id is dropped, not a crash.
  static Map<GameId, int> _decodeGameBests(Map<String, dynamic> json) {
    final raw = json['gameBests'];
    if (raw is Map) {
      return {
        for (final e in raw.entries)
          if (enumByNameOrNull(GameId.values, e.key) case final id?)
            if (e.value case final int score) id: score,
      };
    }
    final legacy = json['bestGameScore'];
    return legacy is int ? {GameId.tiles: legacy} : const {};
  }

  static Map<String, dynamic> encodeProfile(UserProfile p) => {
    'alias': p.alias,
    'avatarEmoji': p.avatarEmoji,
    'email': p.email,
    'gender': p.gender?.name,
    'birthYear': p.birthYear,
    'whys': [for (final w in p.whys) w.name],
    'worries': [for (final w in p.worries) w.name],
    'attempts': p.attempts?.name,
    'frequency': p.frequency?.name,
    'firstPuff': p.firstPuff?.name,
    'coachName': p.coachName,
    'whyWords': p.whyWords,
    // Written only once answered, so a journey nobody asked stays
    // byte-for-byte the document it always was.
    if (p.smoking != null) 'smoking': p.smoking!.name,
  };

  static UserProfile decodeProfile(Map<String, dynamic> json) => UserProfile(
    alias: json['alias'] as String,
    avatarEmoji: json['avatarEmoji'] as String,
    email: json['email'] as String?,
    gender: enumByNameOrNull(Gender.values, json['gender']),
    birthYear: json['birthYear'] as int?,
    whys: {
      for (final w in (json['whys'] as List? ?? const []))
        ?enumByNameOrNull(WhyChip.values, w),
    },
    worries: {
      for (final w in (json['worries'] as List? ?? const []))
        ?enumByNameOrNull(WorryChip.values, w),
    },
    attempts: enumByNameOrNull(QuitAttempts.values, json['attempts']),
    frequency: enumByNameOrNull(VapeFrequency.values, json['frequency']),
    firstPuff: enumByNameOrNull(FirstPuffWindow.values, json['firstPuff']),
    coachName: json['coachName'] as String?,
    // Every journey written before the question existed is missing this key,
    // so it decodes as "never asked" rather than throwing.
    whyWords: json['whyWords'] as String?,
    // Missing, or a name a newer build wrote, both read as "never asked".
    smoking: enumByNameOrNull(SmokingHistory.values, json['smoking']),
  );

  static Map<String, dynamic> encodePlan(QuitPlan p) => {
    'method': p.method.name,
    'paceDays': p.paceDays,
    'startDate': encodeDayKey(p.startDate),
    'baselinePuffsPerDay': p.baselinePuffsPerDay,
    'weeklySpend': p.weeklySpend,
    'strength': p.strength.name,
    'stretchDays': p.stretchDays,
    // A plan started again (`PlanRestart`). Written only then, so a first
    // plan stays byte-for-byte the document it always was.
    if (p.taperFrom != null) 'taperFrom': p.taperFrom,
    if (p.planNumber > 1) 'planNumber': p.planNumber,
  };

  static QuitPlan decodePlan(Map<String, dynamic> json) => QuitPlan(
    method: enumByName(QuitMethod.values, json['method'], QuitMethod.taper),
    paceDays: json['paceDays'] as int,
    startDate: decodeDayKey(json['startDate'] as String),
    baselinePuffsPerDay: json['baselinePuffsPerDay'] as int,
    weeklySpend: (json['weeklySpend'] as num).toDouble(),
    strength: enumByName(
      NicStrength.values,
      json['strength'],
      NicStrength.notSure,
    ),
    stretchDays: json['stretchDays'] as int? ?? 0,
    // Absent on every journey written before Nov 2026, and anything that is
    // not a positive whole number reads as absent: a first plan.
    taperFrom: switch (json['taperFrom']) {
      final int level when level > 0 => level,
      _ => null,
    },
    planNumber: switch (json['planNumber']) {
      final int n when n >= 1 => n,
      _ => 1,
    },
  );

  // `date` is re-derived from the map key on decode — one source of truth.
  static Map<String, dynamic> _encodeDayLog(DayLog l) => {
    'puffs': l.puffs,
    'limit': l.limit,
    'hourBuckets': {
      for (final e in l.hourBuckets.entries) e.key.toString(): e.value,
    },
    'cravingsSurvived': l.cravingsSurvived,
    'mood': l.mood?.name,
    'moodNote': l.moodNote,
    'vapeFreeConfirmed': l.vapeFreeConfirmed,
    'slipTrigger': l.slipTrigger?.name,
    'repairTokenUsed': l.repairTokenUsed,
  };

  static DayLog _decodeDayLog(String dayKey, Map<String, dynamic> json) =>
      DayLog(
        date: decodeDayKey(dayKey),
        puffs: json['puffs'] as int,
        limit: json['limit'] as int,
        hourBuckets: {
          for (final e in (json['hourBuckets'] as Map<String, dynamic>).entries)
            int.parse(e.key): e.value as int,
        },
        cravingsSurvived: json['cravingsSurvived'] as int? ?? 0,
        mood: enumByNameOrNull(Mood.values, json['mood']),
        moodNote: json['moodNote'] as String?,
        vapeFreeConfirmed: json['vapeFreeConfirmed'] as bool? ?? false,
        slipTrigger: enumByNameOrNull(SlipTrigger.values, json['slipTrigger']),
        repairTokenUsed: json['repairTokenUsed'] as bool? ?? false,
      );

  static Map<String, dynamic> _encodeAdvice(PlanAdvice a) => {
    'forDay': encodeDayKey(a.forDay),
    'limit': a.limit,
    'adherence': a.adherence.name,
    'stretchDelta': a.stretchDelta,
  };

  /// Public because the same shape arrives from two places: this journey
  /// document (the client's accepted copy) and the server-owned `users/{uid}`
  /// document `taperRecalc` writes. One decoder means they cannot drift.
  static PlanAdvice decodeAdvice(Map<String, dynamic> json) => PlanAdvice(
    forDay: decodeDayKey(json['forDay'] as String),
    limit: json['limit'] as int,
    adherence: enumByName(
      PlanAdherence.values,
      json['adherence'],
      PlanAdherence.onTrack,
    ),
    stretchDelta: json['stretchDelta'] as int? ?? 0,
  );

  static Map<String, dynamic> _encodeGoal(SavingsGoal g) => {
    'id': g.id,
    'emoji': g.emoji,
    'name': g.name,
    'price': g.price,
    'fromOnboarding': g.fromOnboarding,
  };

  static SavingsGoal _decodeGoal(Map<String, dynamic> json) => SavingsGoal(
    id: json['id'] as String,
    emoji: json['emoji'] as String,
    name: json['name'] as String,
    price: (json['price'] as num).toDouble(),
    fromOnboarding: json['fromOnboarding'] as bool? ?? false,
  );

}
