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

class Reply {
  const Reply({
    required this.id,
    required this.alias,
    required this.avatarEmoji,
    this.text,
    this.seedTextId,
    this.isOp = false,
    this.isMine = false,
  }) : assert(text != null || seedTextId != null);

  /// The reply's own document id.
  ///
  /// Firestore has always had one and the client threw it away, so a reply
  /// could be rendered but never addressed — which is why reporting one could
  /// only ever have been a snackbar.
  final String id;

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
  final bool isMine;

  /// Hidden by report threshold or block (moderation UX).
  final bool hidden;

  Post copyWith({
    Map<String, int>? reactions,
    Set<String>? myReactions,
    List<Reply>? replies,
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

  /// Client-side fallback when the coach backend is unreachable.
  connectionLost,

  /// Client-side fallback when the backend answered and refused this build
  /// (App Check). Separate from [connectionLost] because they need opposite
  /// advice: one resolves itself when the signal returns, the other never
  /// does, and telling someone to reconnect while they are online is how this
  /// failure hid for days.
  backendRejected,
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
    this.text,
  }) : role = CoachRole.ember,
       chipEcho = null;

  final String id;
  final CoachRole role;

  /// Raw text: what the user typed, or — for an Ember message — the model's
  /// own words. When set on an Ember message it replaces the template.
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
    this.text,
    this.messagesLeft,
    this.isFreeTier,
  });

  final CoachTemplate template;

  /// Numeric/string args captured server-side at reply time.
  final Map<String, Object> args;

  final bool showWeekCard;

  /// Ember's actual words, when the reply came from the model rather than a
  /// deterministic template. Null for `capReached`/`connectionLost`, which the
  /// server owns and the views localize. When present this WINS over
  /// [template] — the template is only a fallback for clients built before
  /// this field existed.
  final String? text;

  /// Messages left today, straight from the side that enforces the cap.
  ///
  /// The client used to count this itself — an in-memory int with no midnight
  /// rollover, derived from a tier the client wrote into its own journey doc.
  /// It could grey the composer while the server would happily answer, or
  /// promise messages the server would refuse. Null when the backend did not
  /// say, in which case the counter is simply not shown: no number beats a
  /// number nobody stands behind.
  final int? messagesLeft;

  /// Whether [messagesLeft] describes a capped free allowance worth showing.
  final bool? isFreeTier;
}

/// One step of Ember answering.
///
/// The coach used to be a form submission: a spinner, a pause, a finished
/// paragraph. The model has always produced its answer a token at a time and
/// the server has always been able to stream it — the client simply asked for
/// it all at once, so the most alive thing in the product arrived dead.
sealed class CoachEvent {
  const CoachEvent();
}

/// More of Ember's sentence. Append it to what is already on screen.
final class CoachChunk extends CoachEvent {
  const CoachChunk(this.text);

  final String text;
}

/// The turn is finished. Carries the authoritative envelope — a stream that
/// ends without one never really answered.
final class CoachDone extends CoachEvent {
  const CoachDone(this.reply);

  final CoachReply reply;
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

/// What the server says about a craving session that just opened
/// (docs/03 §7, docs/04 §7).
///
/// It gates the AI layer and NOTHING else. The breathing screen, the reframe
/// card and the tap game always run, whatever this says — we do not paywall
/// someone mid-crisis, and a craving must never wait on a round-trip.
class PanicAvailability {
  const PanicAvailability({
    required this.aiAvailable,
    required this.sessionsToday,
  });

  /// The optimistic local answer, used before the server replies and whenever
  /// it can't be reached. Assuming "available" is deliberate: the worst case
  /// is one over-quota model call, versus withholding help from someone
  /// mid-craving because their wifi dropped.
  static const unknown = PanicAvailability(aiAvailable: true, sessionsToday: 0);

  final bool aiAvailable;

  /// Sessions counted today, this one included. Server-owned — the client
  /// can't be trusted with the free-tier allowance.
  final int sessionsToday;
}

/// How the trailing days compare to the curve (docs/03 §3.3). Server-derived.
enum PlanAdherence { crushing, onTrack, struggling }

/// The nightly adaptive layer's verdict, computed by `taperRecalc` just after
/// the user's local midnight and read from the server-owned `users/{uid}`.
///
/// The advice is *bent* curve, never a new curve: the server has the trailing
/// three days the client also has, but it is the only side that can be
/// trusted to apply them (docs/03 §3.3), and it can do it while the phone is
/// asleep. Once the client accepts a day's advice it stores the accepted copy
/// in its own journey document — which is why this type is client-persisted
/// even though the server owns the original. Writing back into `users/{uid}`
/// is not possible and not wanted.
class PlanAdvice {
  const PlanAdvice({
    required this.forDay,
    required this.limit,
    required this.adherence,
    required this.stretchDelta,
  });

  /// Local midnight of the day [limit] applies to.
  final DateTime forDay;

  /// The limit to show instead of the raw curve value for [forDay].
  final int limit;
  final PlanAdherence adherence;

  /// Days the runway grows by, already capped server-side at +50% of pace.
  /// Applied exactly once per [forDay] — see `JourneyStore.applyPlanAdvice`.
  final int stretchDelta;

  bool appliesTo(DateTime day) =>
      forDay.year == day.year &&
      forDay.month == day.month &&
      forDay.day == day.day;
}

/// The Sunday AI report `weeklyInsight` generates (docs/04 §5).
///
/// Unlike coach replies, these five strings are NOT localizable ids: they are
/// the model's own prose about this user's own week, generated in the locale
/// `syncUserContext` recorded. Nothing here can be resolved through the ARB
/// files, and nothing here should be — a translated summary of numbers the
/// model never saw would be a different claim.
class WeeklyInsight {
  const WeeklyInsight({
    required this.weekId,
    required this.headline,
    required this.pattern,
    required this.win,
    required this.watchout,
    required this.move,
  });

  /// The user's local Sunday, `yyyy-MM-dd`. One report per week.
  final String weekId;
  final String headline;

  /// What the week's data showed.
  final String pattern;
  final String win;
  final String watchout;

  /// The single concrete thing to do next week.
  final String move;
}

/// What a moderator can decide about a flagged item (`resolveModeration`).
/// Resolving with no action means "I looked, it stands" — the common case.
enum ModerationResolution { allow, block }

/// One row of the founder's review queue (docs/03 §9, Guideline 1.2).
///
/// The flag outlives its subject: a post can be deleted while its flag
/// remains, which is why [text], [status] and [alias] are all nullable. A
/// queue that silently dropped those rows would leave reports looking handled
/// when nobody ever saw them.
class ModerationItem {
  const ModerationItem({
    required this.flagId,
    required this.postId,
    required this.action,
    required this.reason,
    required this.kind,
    this.replyId,
    this.text,
    this.status,
    this.alias,
  });

  /// The moderation document's own id — what [ModerationRepository.resolve]
  /// must be given.
  ///
  /// Resolving by [postId] silently addressed the wrong document for a reply
  /// flag, which is stored under its own id with the parent as a field: the
  /// reply's flag was never marked reviewed and reappeared in the queue every
  /// day, while the parent post's status was flipped instead.
  final String flagId;

  final String postId;

  /// Set only for reply flags.
  final String? replyId;

  /// What the classifier did — `flag` or `block`.
  final String action;

  /// The classifier's stated reason, verbatim. Not localized: it is evidence
  /// of a decision, and translating it would change what was decided.
  final String reason;

  /// `post` or `reply`.
  final String kind;
  final String? text;
  final String? status;
  final String? alias;

  /// True when the subject is gone and only the flag is left.
  bool get subjectMissing => text == null && status == null;
}

/// What kind of thing Ember remembered. Shown as a label so the list reads as
/// a person's notes rather than a database dump.
enum MemoryKind { person, trigger, motivation, milestone, preference, context }

/// One thing Ember remembers, as the user can see it.
///
/// The embedding never crosses the wire — the phone has nothing to do with 768
/// floats, and a memory the user cannot read is not one they can meaningfully
/// consent to.
class CoachMemory {
  const CoachMemory({
    required this.id,
    required this.text,
    required this.kind,
  });

  final String id;

  /// One sentence, in the third person, as the extraction wrote it.
  final String text;
  final MemoryKind kind;
}
