/// Backend contracts (DIP seam). Stores — the view-model layer — depend on
/// these interfaces only; today they're implemented over a fake JSON API
/// (`data/api/fake`), later over Firebase or a REST client without touching a
/// single store or view (docs/05 architecture).
library;

import '../models/journey_state.dart';
import '../models/models.dart';

/// Session lifecycle. Every method is a real (fake-backed) API round-trip.
abstract interface class AuthRepository {
  /// The signed-in account's journey, or null (no session / not onboarded).
  Future<JourneyState?> restoreSession();

  /// The account's journey, or null for an account that registered but never
  /// onboarded (route to onboarding). Throws [InvalidCredentialsException] on
  /// a wrong password.
  Future<JourneyState?> signInWithEmail({
    required String email,
    required String password,
  });

  /// The account's journey when it already has one; null → onboarding.
  Future<JourneyState?> signInWithApple();

  /// The account's journey when it already has one; null → onboarding.
  Future<JourneyState?> signInWithGoogle();

  /// Creates the account and opens a session (journey comes later, from
  /// onboarding). Throws [EmailAlreadyInUseException].
  Future<void> register({required String email, required String password});

  Future<void> requestPasswordReset(String email);

  Future<void> signOut();

  Future<void> deleteAccount();

  /// The signed-in account's stable id, or null when there is no session — or
  /// no id safe to use as one.
  ///
  /// Exists for analytics identity: without it a returning user's funnel is a
  /// fresh device every reinstall, and signing out on a shared phone leaves
  /// the next person's events attributed to the previous one. It is NOT a
  /// permission check — nothing is authorized by this value.
  Future<String?> currentUserId();
}

/// Persistence of the quit journey itself.
abstract interface class JourneyRepository {
  /// The backend creates the initial journey from onboarding output.
  Future<JourneyState> create({
    required UserProfile profile,
    required QuitPlan plan,
  });

  /// Write-behind upsert after every local mutation.
  Future<void> save(JourneyState journey);

  Future<void> delete();
}

/// Anonymous community feed.
abstract interface class CommunityRepository {
  Future<List<Post>> fetchPosts();

  Future<void> addPost(Post post);

  Future<void> setReaction(String postId, String emoji, {required bool on});

  Future<void> addReply(String postId, Reply reply);

  Future<void> reportPost(String postId);

  /// Flags a reply for review.
  ///
  /// Separate from [reportPost] because the rules deny every client write to a
  /// reply — a reader has to be able to raise a count without being able to
  /// touch the text, the author or the status — so this goes through a
  /// callable rather than an increment.
  Future<void> reportReply({required String postId, required String replyId});

  Future<void> blockAuthor(String alias);

}

/// Craving sessions (docs/03 §7).
///
/// The 3-step script itself is entirely on-device — a craving cannot wait on
/// a network round-trip — so this exists only for the two facts the client
/// must not own: the session count that feeds the guardrail metric, and the
/// tier read that decides whether the AI layer is offered.
abstract interface class PanicRepository {
  /// Opens a session. Counted server-side; the answer only ever *enables* the
  /// AI option, so a failure degrades to [PanicAvailability.unknown] rather
  /// than to a blocked screen.
  Future<PanicAvailability> begin();

  /// The craving passed. Fire-and-forget: the session is already counted, and
  /// a lost outcome costs one data point, never the user anything.
  Future<void> survived({required int intensity});
}

/// Ember — the backend decides *what* to say ([CoachReply]); views localize.
abstract interface class CoachRepository {
  /// Ember's turn, streamed.
  ///
  /// A stream rather than a future because the answer exists progressively and
  /// waiting for the last token before showing the first is a choice, not a
  /// constraint. Implementations that cannot stream emit one [CoachChunk] and
  /// then [CoachDone]; the store handles both without knowing which it got.
  ///
  /// [panicIntensity] (1–10) is set only from the panic flow. The server
  /// switches to its short, directive PANIC MODE voice when it is present —
  /// mid-craving is no time for Ember to ask an open question.
  Stream<CoachEvent> streamReply({
    String? text,
    CoachChip? chip,
    required bool capped,
    int? panicIntensity,
  });

  /// Everything already said in this thread, oldest first.
  ///
  /// The server has always kept the transcript — it feeds the model the last
  /// turns of context — but the client never read it back, so closing the app
  /// wiped the visible conversation while Ember carried on remembering it.
  /// A coach that recalls what you said last week, in a thread that forgets
  /// what you said five minutes ago, reads as broken rather than personal.
  Future<List<CoachMessage>> history();

  /// Everything Ember remembers about this user, newest first.
  ///
  /// The coach stores what people tell it so it can be personal weeks later.
  /// A store like that has to be legible and revocable, or it is something to
  /// be uneasy about rather than the reason to keep coming back.
  Future<List<CoachMemory>> memories();

  /// Turns the one free-text onboarding answer into Ember's first memory.
  ///
  /// Called once, right after the journey is created. The server reads the
  /// sentence from the stored journey rather than from this call — nothing
  /// crosses the wire here — so a client cannot write itself a memory, and a
  /// memory goes straight into a system prompt.
  ///
  /// Fire-and-forget: a failure costs one remembered sentence, never the
  /// account, and the server leaves it retryable.
  Future<void> seedMemories();

  /// Forgets one memory, permanently. The user's call, never ours.
  Future<void> forgetMemory(String id);
}

/// The founder's moderation queue (docs/03 §9, App Store Guideline 1.2).
///
/// Guideline 1.2 requires a means of acting on reported content, and docs/03
/// promises review inside 24 hours. Both were unmeetable: `moderation/*` is
/// server-only by rule, and until now nothing on any client could open it.
///
/// Access is a custom claim on the signed auth token. [isModerator] reads
/// that claim so the entry point can stay hidden for everyone else — it is a
/// UI convenience, NOT the access check. The callables re-verify the claim
/// themselves, and answer non-admins with `not-found` rather than confirming
/// the queue exists at all.
abstract interface class ModerationRepository {
  Future<bool> isModerator();

  Future<List<ModerationItem>> queue({bool includeReviewed = false});

  /// Marks the flag reviewed. A null [action] records "looked, it stands".
  ///
  /// Takes the FLAG's id, not the post's — see [ModerationItem.flagId].
  Future<void> resolve(String flagId, {ModerationResolution? action});
}

/// The read side of the server-owned `users/{uid}` document.
///
/// Everything here is computed where the client cannot be trusted or cannot
/// reach: the nightly taper advice (`taperRecalc`), the Sunday report
/// (`weeklyInsight`), and — next — the RevenueCat entitlement mirror, which
/// is the whole reason the ownership split exists. The client reads this
/// tree and never writes it; `firestore.rules` enforces that, not politeness.
///
/// Every method answers null rather than throwing on "nothing there yet",
/// because "no report this week" and "cron hasn't run for you" are ordinary
/// states, not failures. Wire failures still throw, so the caller can tell a
/// missing report from a dead connection.
abstract interface class ServerStateRepository {
  /// The nightly adaptive taper verdict, or null before the first cron run
  /// (and for anyone past Freedom Day, where there is no limit to bend).
  Future<PlanAdvice?> planAdvice();

  /// The most recent weekly report, or null when none has been generated —
  /// free tier, a short week, or a model outage the cron skipped silently.
  Future<WeeklyInsight?> latestInsight();
}

sealed class AuthException implements Exception {
  const AuthException();
}

final class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException();
}

final class EmailAlreadyInUseException extends AuthException {
  const EmailAlreadyInUseException();
}

/// The user dismissed a native sign-in sheet (Google/Apple). Not a failure:
/// views reset their busy flag and stay put — never a dialog.
final class SignInCancelledException extends AuthException {
  const SignInCancelledException();
}

/// The device can't reach the backend (airplane mode, dead wifi, tunnel…).
/// Thrown by every repository operation that needs the wire; views map it to
/// the friendly offline surfaces, never to a generic failure.
final class NoConnectionException implements Exception {
  const NoConnectionException();
}

/// The backend reached us fine and refused the *app* — App Check attestation
/// failed, or the caller lacks permission for the resource.
///
/// This exists because it used to be indistinguishable from being offline, and
/// that cost days. A rotated App Check debug secret made every callable answer
/// `unauthenticated`; the client mapped it onto the offline surfaces, so the
/// coach said "say that again once you're back online" to users who were
/// online, the panic and community writes died silently, and the one true
/// cause — a token the backend had never seen — was never once named on
/// screen. An outage the user can fix by walking outside and a rejection only
/// we can fix must never share a surface again.
final class BackendRejectedException implements Exception {
  const BackendRejectedException();
}

/// Pushes the device facts the server cannot infer into the server-owned
/// `users/{uid}` document: timezone, locale, and the push token.
///
/// This is the reason the nightly crons have anything to page over — they
/// query `users` by the UTC hour matching the user's local 01:00, and that
/// row only exists once this has run at least once.
abstract interface class UserContextRepository {
  /// Fire-and-forget by design: a failed sync costs a cron cycle, never a
  /// session. Callers ignore the future.
  Future<void> sync({String? fcmToken});

  /// Releases this device from the push registry, on sign-out.
  ///
  /// Without it a token stayed registered to the account that left, so the
  /// next person to sign in on a shared phone received the previous user's
  /// pushes. Two halves, and the order matters: the local token is deleted
  /// (which alone guarantees silence, and needs no network), and the server
  /// row is released (which is best effort, and needs the caller to still be
  /// signed in — so this must complete before the credential goes).
  ///
  /// Never throws, and is bounded in time: someone who tapped "sign out" is
  /// not left signed in because a backend was slow.
  Future<void> unregister();
}

/// The two quotes shown on the D3 rating ask, chosen for what this person just
/// told us they are afraid of.
///
/// The answers travel in the request rather than being read from the journey,
/// because at step 18 of 19 the journey document does not exist yet — it is
/// created after the paywall. That is safe for the same reason timezone and
/// locale are: none of them is a privilege, so a lying client only gets itself
/// a less relevant quote.
abstract interface class TestimonialsRepository {
  /// Empty when nothing fits, when the backend is unreachable, or when the
  /// pool is too small to fill both cards — the view keeps its bundled quotes
  /// in every one of those cases rather than showing a half-filled screen.
  Future<List<Testimonial>> matched({
    required Set<WhyChip> whys,
    required Set<WorryChip> worries,
    QuitAttempts? attempts,
    Gender? gender,
    required DependenceLevel dependence,
  });
}

/// The server-owned copy of what the user calls their coach.
///
/// Two copies exist on purpose. `journeys/{uid}.profile.coachName` is
/// client-owned and drives the UI; this one is written only through a
/// validated callable and is the ONLY version the model is told about —
/// because the journey document is written wholesale by the app, so a name
/// taken from it would be unvalidated client text going into a system prompt.
abstract interface class CoachNameRepository {
  /// True when the server accepted it. False is a definite refusal.
  ///
  /// Anything else — offline, a timeout, a backend that will not answer —
  /// THROWS, and the caller accepts the name locally: this is the user's own
  /// private word, and losing the funnel to a moderation round-trip is the
  /// worse failure.
  Future<bool> reserve(String name);
}
