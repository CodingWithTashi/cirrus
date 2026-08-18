/// Immutable domain entities. Pure Dart — no Flutter imports.
library;

import 'enums.dart';

export 'enums.dart';

class UserProfile {
  const UserProfile({
    required this.alias,
    required this.avatarEmoji,
    required this.tier,
    this.email,
    this.gender,
    this.birthYear,
    this.whys = const {},
    this.worries = const {},
    this.attempts,
    this.frequency,
    this.firstPuff,
  });

  final String alias;
  final String avatarEmoji;
  final SubscriptionTier tier;
  final String? email;
  final Gender? gender;
  final int? birthYear;
  final Set<WhyChip> whys;
  final Set<WorryChip> worries;
  final QuitAttempts? attempts;
  final VapeFrequency? frequency;
  final FirstPuffWindow? firstPuff;

  bool get isPremium => tier != SubscriptionTier.free;

  UserProfile copyWith({
    String? alias,
    String? avatarEmoji,
    SubscriptionTier? tier,
    String? email,
    Set<WhyChip>? whys,
    Set<WorryChip>? worries,
  }) => UserProfile(
    alias: alias ?? this.alias,
    avatarEmoji: avatarEmoji ?? this.avatarEmoji,
    tier: tier ?? this.tier,
    email: email ?? this.email,
    gender: gender,
    birthYear: birthYear,
    whys: whys ?? this.whys,
    worries: worries ?? this.worries,
    attempts: attempts,
    frequency: frequency,
    firstPuff: firstPuff,
  );
}

class QuitPlan {
  const QuitPlan({
    required this.method,
    required this.paceDays,
    required this.startDate,
    required this.baselinePuffsPerDay,
    required this.weeklySpend,
    required this.strength,
    this.stretchDays = 0,
  });

  final QuitMethod method;
  final int paceDays;

  /// Local date (y/m/d) of day 1.
  final DateTime startDate;
  final int baselinePuffsPerDay;
  final double weeklySpend;
  final NicStrength strength;

  /// Extra days added by slip recovery (docs/03 §3.3, cap +50% of pace).
  final int stretchDays;

  int get totalDays => paceDays + stretchDays;

  DateTime get freedomDate => startDate.add(Duration(days: totalDays - 1));

  /// 1-based day index for [date]; values above [totalDays] mean maintenance.
  int dayNumber(DateTime date) =>
      _dateOnly(date).difference(startDate).inDays + 1;

  double get costPerPuff =>
      baselinePuffsPerDay == 0 ? 0 : weeklySpend / (7 * baselinePuffsPerDay);

  QuitPlan copyWith({
    QuitMethod? method,
    int? paceDays,
    DateTime? startDate,
    int? baselinePuffsPerDay,
    double? weeklySpend,
    NicStrength? strength,
    int? stretchDays,
  }) => QuitPlan(
    method: method ?? this.method,
    paceDays: paceDays ?? this.paceDays,
    startDate: startDate ?? this.startDate,
    baselinePuffsPerDay: baselinePuffsPerDay ?? this.baselinePuffsPerDay,
    weeklySpend: weeklySpend ?? this.weeklySpend,
    strength: strength ?? this.strength,
    stretchDays: stretchDays ?? this.stretchDays,
  );

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

class DayLog {
  const DayLog({
    required this.date,
    required this.puffs,
    required this.limit,
    this.hourBuckets = const {},
    this.cravingsSurvived = 0,
    this.mood,
    this.moodNote,
    this.vapeFreeConfirmed = false,
    this.slipTrigger,
    this.repairTokenUsed = false,
  });

  final DateTime date;
  final int puffs;
  final int limit;

  /// Puffs logged per hour 0–23; fuels the danger-hour engine.
  final Map<int, int> hourBuckets;
  final int cravingsSurvived;
  final Mood? mood;
  final String? moodNote;
  final bool vapeFreeConfirmed;
  final SlipTrigger? slipTrigger;
  final bool repairTokenUsed;

  bool get isOverLimit => puffs > limit;

  bool get isConfirmed => puffs > 0 || vapeFreeConfirmed;

  DayLog copyWith({
    int? puffs,
    int? limit,
    Map<int, int>? hourBuckets,
    int? cravingsSurvived,
    Mood? mood,
    String? moodNote,
    bool? vapeFreeConfirmed,
    SlipTrigger? slipTrigger,
    bool? repairTokenUsed,
  }) => DayLog(
    date: date,
    puffs: puffs ?? this.puffs,
    limit: limit ?? this.limit,
    hourBuckets: hourBuckets ?? this.hourBuckets,
    cravingsSurvived: cravingsSurvived ?? this.cravingsSurvived,
    mood: mood ?? this.mood,
    moodNote: moodNote ?? this.moodNote,
    vapeFreeConfirmed: vapeFreeConfirmed ?? this.vapeFreeConfirmed,
    slipTrigger: slipTrigger ?? this.slipTrigger,
    repairTokenUsed: repairTokenUsed ?? this.repairTokenUsed,
  );
}

class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.emoji,
    required this.name,
    required this.price,
    this.fromOnboarding = false,
  });

  final String id;
  final String emoji;
  final String name;
  final double price;
  final bool fromOnboarding;
}

class Buddy {
  const Buddy({
    required this.alias,
    required this.avatarEmoji,
    required this.name,
    required this.streakDays,
  });

  final String alias;
  final String avatarEmoji;
  final String name;
  final int streakDays;
}

class Reply {
  const Reply({
    required this.alias,
    required this.avatarEmoji,
    this.text,
    this.seedTextId,
    this.isOp = false,
    this.isMine = false,
  }) : assert(text != null || seedTextId != null);

  final String alias;
  final String avatarEmoji;

  /// Raw text for user-authored replies.
  final String? text;

  /// Localization id for seeded demo replies (resolved in the view).
  final String? seedTextId;

  /// Reply written by the original poster (highlighted in SOS rallies).
  final bool isOp;
  final bool isMine;
}

class Post {
  const Post({
    required this.id,
    required this.alias,
    required this.avatarEmoji,
    required this.dayN,
    required this.tag,
    required this.createdAt,
    this.text,
    this.seedTextId,
    this.reactions = const {},
    this.myReactions = const {},
    this.replies = const [],
    this.replyingNow = 0,
    this.isMine = false,
    this.hidden = false,
  }) : assert(text != null || seedTextId != null);

  final String id;
  final String alias;
  final String avatarEmoji;
  final int dayN;
  final PostTag tag;

  /// Raw text for the user's own posts.
  final String? text;

  /// Localization id for seeded demo posts (resolved in the view).
  final String? seedTextId;
  final DateTime createdAt;

  /// emoji → count ("💪" → 214).
  final Map<String, int> reactions;
  final Set<String> myReactions;
  final List<Reply> replies;
  final int replyingNow;
  final bool isMine;

  /// Hidden by report threshold or block (moderation UX).
  final bool hidden;

  Post copyWith({
    Map<String, int>? reactions,
    Set<String>? myReactions,
    List<Reply>? replies,
    int? replyingNow,
    bool? hidden,
  }) => Post(
    id: id,
    alias: alias,
    avatarEmoji: avatarEmoji,
    dayN: dayN,
    tag: tag,
    text: text,
    seedTextId: seedTextId,
    createdAt: createdAt,
    reactions: reactions ?? this.reactions,
    myReactions: myReactions ?? this.myReactions,
    replies: replies ?? this.replies,
    replyingNow: replyingNow ?? this.replyingNow,
    isMine: isMine,
    hidden: hidden ?? this.hidden,
  );
}

enum CoachRole { ember, user }

/// Ember's reply repertoire. Views resolve a template + args into localized
/// copy; the store only decides *what* to say, never in which language.
enum CoachTemplate {
  greeting,
  craving1,
  craving2,
  craving3,
  rough1,
  rough2,
  slip1,
  slip2,
  progress1,
  progress2,
  generic1,
  generic2,
  generic3,
  generic4,
  party,
  capReached,
}

class CoachMessage {
  const CoachMessage.user({required this.id, required String this.text})
    : role = CoachRole.user,
      template = null,
      chipEcho = null,
      args = const {},
      showWeekCard = false;

  /// A quick-chip tap echoed into the thread as the user's message.
  const CoachMessage.chip({required this.id, required int this.chipEcho})
    : role = CoachRole.user,
      template = null,
      text = null,
      args = const {},
      showWeekCard = false;

  const CoachMessage.ember({
    required this.id,
    required CoachTemplate this.template,
    this.args = const {},
    this.showWeekCard = false,
  }) : role = CoachRole.ember,
       text = null,
       chipEcho = null;

  final String id;
  final CoachRole role;

  /// Raw text (user messages only).
  final String? text;

  /// Index of the tapped quick chip (localized in the view).
  final int? chipEcho;

  /// Localized template (Ember messages only).
  final CoachTemplate? template;

  /// Numeric/string args captured at send time (day, saved, counts…).
  final Map<String, Object> args;

  /// Renders the inline "YOUR WEEK" stat card under this message.
  final bool showWeekCard;
}

/// The coach backend's reply envelope: *what* Ember says (template + the
/// user's real numbers), never in which language — views localize it. This is
/// the only coach payload that crosses the wire (docs/04; the Gemini flow
/// returns the same shape).
class CoachReply {
  const CoachReply({
    required this.template,
    this.args = const {},
    this.showWeekCard = false,
  });

  final CoachTemplate template;

  /// Numeric/string args captured server-side at reply time.
  final Map<String, Object> args;

  final bool showWeekCard;
}

/// A milestone badge definition + earned state.
class QuitBadge {
  const QuitBadge({
    required this.id,
    required this.emoji,
    required this.earned,
    this.ember = false,
  });

  /// Stable id — the UI maps it to a localized name.
  final String id;
  final String emoji;
  final bool earned;

  /// Streak-family badges glow Ember instead of Volt.
  final bool ember;
}
