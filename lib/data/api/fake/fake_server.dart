import 'dart:convert';

import '../../../domain/logic/community_rules.dart';
import '../../../domain/repositories/repositories.dart';
import 'fake_fixtures.dart';

/// The in-memory "backend database" behind the fake APIs. Everything resets
/// on app restart — the same demo model the app has always had, now speaking
/// JSON over an API-shaped seam.
///
/// INVARIANT: every operation mutates the store **synchronously**; only the
/// acknowledgement is delayed ([respond]). This is what keeps write-behind
/// clients and server-computed coach replies consistent — do not introduce
/// ops that mutate after the delay.
class FakeServer {
  FakeServer({this.latency = const Duration(milliseconds: 350), this.isOnline});

  /// Simulated network round-trip. Widget tests override this to zero.
  final Duration latency;

  /// Synchronous read of device connectivity (wired to the connectivity
  /// store). null = always reachable. When it reports offline, every call
  /// fails like a real backend would — after a short "tried and gave up"
  /// beat — without applying anything.
  final bool Function()? isOnline;

  bool get reachable => isOnline?.call() ?? true;

  static const demoEmail = 'maya@quitmail.com';
  static const _appleAccountId = 'apple-user';
  static const _googleAccountId = 'google-user';
  static const _guestAccountId = 'guest';

  /// email → password. The demo account exists implicitly (see [signIn]).
  final Map<String, String> _accounts = {};

  /// account id → journey JSON. Mutations survive sign-out (same session),
  /// so logging back in restores the mutated journey, not pristine seed data.
  final Map<String, Map<String, dynamic>> _journeys = {};

  /// Lazily seeded on first fetch so fixture timestamps are relative to then.
  List<Map<String, dynamic>>? _posts;

  /// post id → the account that wrote it. The fake's `postAuthors`: kept
  /// OFF the post, exactly like production, so "is this mine" is answered
  /// per session by the backend and never by a flag riding on the wire —
  /// which is how every reader of the store used to be its author (QA H3).
  final Map<String, String> _postAuthors = {};

  final Map<String, int> _reportCounts = {};

  String? _sessionAccountId;

  /// Applies [op] synchronously, delays only the ack. Offline devices get a
  /// [NoConnectionException] instead — checked BEFORE the op so nothing is
  /// half-applied.
  Future<T> respond<T>(T Function() op) {
    if (!reachable) {
      return Future<T>.delayed(
        latency,
        () => throw const NoConnectionException(),
      );
    }
    final T result;
    try {
      result = op();
    } on ContentRefusedException catch (refusal) {
      // A refusal is an answer, so it arrives with the ack's latency like any
      // other — and nothing was applied, exactly as `createPost` throws
      // before it writes.
      return Future<T>.delayed(latency, () => throw refusal);
    }
    return Future<T>.delayed(latency, () => result);
  }

  // ---- session / accounts ---------------------------------------------------

  bool get hasSession => _sessionAccountId != null;

  bool isRegistered(String email) =>
      email == demoEmail || _accounts.containsKey(email);

  /// The stored password for accounts created via register; null for the
  /// implicit demo account (which accepts any well-formed password).
  String? registeredPassword(String email) => _accounts[email];

  /// Demo shim: any email signs into an account; unknown accounts get the
  /// seeded day-12 journey on first sign-in. Password rules are enforced by
  /// [FakeAuthApi] before this is called.
  void signIn(String email) {
    _sessionAccountId = email;
    _journeys.putIfAbsent(
      email,
      () => FakeFixtures.journeyJson(DateTime.now()),
    );
  }

  /// Apple accounts onboard like fresh registrations: no journey until
  /// createJourney. Returns the account's journey if one already exists.
  void signInApple() => _sessionAccountId = _appleAccountId;

  /// Same model as [signInApple], for the Google button.
  void signInGoogle() => _sessionAccountId = _googleAccountId;

  void register(String email, String password) {
    _accounts[email] = password;
    _sessionAccountId = email;
  }

  void signOut() => _sessionAccountId = null;

  void deleteAccount() {
    final id = _sessionAccountId;
    if (id != null) {
      _accounts.remove(id);
      _journeys.remove(id);
    }
    _sessionAccountId = null;
  }

  // ---- journey --------------------------------------------------------------

  /// A guest session lets pre-auth flows (frame-map previews, onboarding
  /// straight from the sign-in screen) persist a journey without an account.
  String _sessionOrGuest() => _sessionAccountId ??= _guestAccountId;

  Map<String, dynamic>? journeyJsonForCurrentSession() {
    final id = _sessionAccountId;
    return id == null ? null : _copy(_journeys[id]);
  }

  void putJourney(Map<String, dynamic> journey) =>
      _journeys[_sessionOrGuest()] = _copy(journey)!;

  void deleteJourney() {
    final id = _sessionAccountId;
    if (id != null) _journeys.remove(id);
  }

  // ---- community ------------------------------------------------------------

  List<Map<String, dynamic>> get posts =>
      _posts ??= FakeFixtures.communityJson(DateTime.now());

  /// The feed as THIS session sees it: other people's posts only when live,
  /// the caller's own posts in every state, `isMine` decided here.
  List<Map<String, dynamic>> postsForSession() => [
    for (final p in posts)
      if (_postAuthors[p['id']] == _sessionAccountId ||
          (p['status'] ?? 'live') == 'live')
        {
          ..._copy(p)!,
          'isMine':
              _sessionAccountId != null &&
              _postAuthors[p['id']] == _sessionAccountId,
        },
  ];

  /// Stores the post without its `isMine`, records who wrote it, and
  /// "moderates" it the way production does — synchronously, so the status
  /// a client reads back is the verdict, never the optimistic guess.
  String insertPost(Map<String, dynamic> post) {
    // Refused at the door, as `createPost` does with the same list: a slur
    // never lands and never claims a slot (docs/09 issue 6).
    if (CommunityRules.check(post['text'] as String? ?? '') ==
        CommunityRuleViolation.slur) {
      throw const ContentRefusedException(ContentRefusal.rules);
    }
    final stored = _copy(post)!..remove('isMine');
    final id = stored['id'] as String;
    // Idempotent on the client's id, as `createPost` is on `clientId`: a
    // retry of a send that did land does not mint a second post.
    if (posts.any((p) => p['id'] == id)) return id;
    // `held`, not `pending`: this is the verdict, not the wait for one. The
    // real mirror says the same (MIRROR_STATUS in moderatePost.ts).
    stored['status'] = CommunityRules.violates(stored['text'] as String? ?? '')
        ? 'held'
        : 'live';
    _postAuthors[id] = _sessionOrGuest();
    posts.insert(0, stored);
    return id;
  }

  /// `posts/{id}.status` as the backend has it, null when unknown.
  String? postStatus(String postId) {
    for (final p in posts) {
      if (p['id'] == postId) return (p['status'] ?? 'live') as String;
    }
    return null;
  }

  void updatePost(String postId, void Function(Map<String, dynamic>) mutate) {
    for (final p in posts) {
      if (p['id'] == postId) {
        mutate(p);
        return;
      }
    }
  }

  void reportPost(String postId) {
    final count = (_reportCounts[postId] = (_reportCounts[postId] ?? 0) + 1);
    // 3 reports auto-hide pending review (App Store UGC requirement).
    if (count >= 3) updatePost(postId, (p) => p['hidden'] = true);
  }

  /// Deep-copies JSON so client and "server" never alias the same maps.
  static Map<String, dynamic>? _copy(Map<String, dynamic>? json) => json == null
      ? null
      : jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

  static List<Map<String, dynamic>> copyList(List<Map<String, dynamic>> list) =>
      (jsonDecode(jsonEncode(list)) as List).cast<Map<String, dynamic>>();
}
