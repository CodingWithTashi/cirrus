/// Repository contracts (DIP seam). The UI depends on these interfaces only;
/// today they're backed by in-memory stores, later by Firestore + Functions
/// without touching a single view (docs/05 architecture).
library;

import '../models/journey_state.dart';
import '../models/models.dart';

/// Commands + state for the quit journey itself.
abstract interface class QuitRepository {
  JourneyState? get journey;

  /// Starts a brand-new journey from onboarding output.
  void startJourney({required UserProfile profile, required QuitPlan plan});

  /// Loads the returning-user account (demo seed in the in-memory build).
  void loadExistingJourney();

  void endJourney();

  void logPuff({DateTime? at});
  void undoLastPuff();
  void confirmVapeFreeDay();
  void recordCravingSurvived();
  void recordSlipTrigger(SlipTrigger trigger);
  void applySlipRecovery();
  void dismissSlipRecovery();
  void editPastDay(DateTime date, int puffs);
  void checkInMood(Mood mood, {String? note});
  void addGoal(SavingsGoal goal);
  void adjustPlan({QuitMethod? method, int? paceDays});
  void completeDay1Task(int index);
  void updateAlias(String alias, String avatarEmoji);
  void setTier(SubscriptionTier tier);
}

/// Anonymous community feed.
abstract interface class CommunityRepository {
  List<Post> get posts;

  void addPost({required String text, required PostTag tag});
  void toggleReaction(String postId, String emoji);
  void addReply(String postId, String text);
  void reportPost(String postId);
  void blockAuthor(String postId);
  void nudgeBuddy();
}

/// Ember — scripted in-memory stand-in for the server-side coach
/// (docs/04; the real Gemini flow slots in behind this interface).
abstract interface class CoachRepository {
  List<CoachMessage> get messages;
  bool get isTyping;
  int get freeMessagesLeftToday;

  Future<void> send(String text);
  Future<void> sendChip(CoachChip chip);
  void seedGreetingIfEmpty();
}

enum CoachChip { craving, roughDay, slipped, progress }
