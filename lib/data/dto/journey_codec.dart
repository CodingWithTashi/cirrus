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
  };

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
  );

  static Map<String, dynamic> encodeProfile(UserProfile p) => {
    'alias': p.alias,
    'avatarEmoji': p.avatarEmoji,
    'tier': p.tier.name,
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
  };

  static UserProfile decodeProfile(Map<String, dynamic> json) => UserProfile(
    alias: json['alias'] as String,
    avatarEmoji: json['avatarEmoji'] as String,
    tier: enumByName(
      SubscriptionTier.values,
      json['tier'],
      SubscriptionTier.free,
    ),
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
  );

  static Map<String, dynamic> encodePlan(QuitPlan p) => {
    'method': p.method.name,
    'paceDays': p.paceDays,
    'startDate': encodeDayKey(p.startDate),
    'baselinePuffsPerDay': p.baselinePuffsPerDay,
    'weeklySpend': p.weeklySpend,
    'strength': p.strength.name,
    'stretchDays': p.stretchDays,
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
