import 'dart:convert';

import '../../../domain/logic/allowances.dart';
import '../../../domain/logic/community_rules.dart';
import '../../../domain/logic/lp_pricing.dart';
import '../../../domain/models/billing.dart';
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

  /// account id → entitlement JSON (`EntitlementCodec`). Survives sign-out
  /// the way journeys do — logging back in restores the subscription — and
  /// dies with the account.
  final Map<String, Map<String, dynamic>> _entitlements = {};

  /// Test knob: how the next store sheet "ends". Consumed by the purchase
  /// that reads it and reset to [FakePurchaseScript.completed], so a
  /// scripted cancel cannot leak into the next test.
  FakePurchaseScript nextPurchase = FakePurchaseScript.completed;

  /// Which plans the fake store offers. Tests drop one to stand in for a
  /// storefront or a store config that lacks it (the Test Store has no
  /// weekly product, for one).
  Set<PlanPeriod> offeringPeriods = Set.of(PlanPeriod.values);

  /// The trial the fake store offers on every plan; null is a store (or a
  /// user) with no introductory offer left.
  int? offeringTrialDays = LpPricing.trialDays;

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
    // The seeded day-12 journey has always been a paying user's; the
    // subscription behind it is a row here now rather than a field on the
    // journey — and it comes WITH the seeded journey, never to an account
    // that onboarded on its own and chose Free. Apple/Google/guest accounts
    // start free, like a fresh install.
    if (!_journeys.containsKey(email)) {
      _journeys[email] = FakeFixtures.journeyJson(DateTime.now());
      _entitlements.putIfAbsent(
        email,
        () => demoEntitlementJson(DateTime.now()),
      );
    }
  }

  /// The demo account's standing subscription: premium, yearly, renewing.
  static Map<String, dynamic> demoEntitlementJson(DateTime now) => {
    'tier': 'premium',
    'productId': 'yearly_3999',
    'plan': 'yearly',
    'expiresAt': now.add(const Duration(days: 300)).toUtc().toIso8601String(),
    'willRenew': true,
    'store': 'other',
    'isSandbox': true,
  };

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
      _entitlements.remove(id);
    }
    _sessionAccountId = null;
  }

  // ---- billing --------------------------------------------------------------

  /// The account a purchase would be filed under — the session, or the guest
  /// account a pre-auth flow runs on. The fake's stand-in for "mint an
  /// anonymous uid".
  String ensureSessionId() => _sessionOrGuest();

  Map<String, dynamic>? entitlementForSession() =>
      _copy(_entitlements[_sessionOrGuest()]);

  void putEntitlement(Map<String, dynamic> json) =>
      _entitlements[_sessionOrGuest()] = _copy(json)!;

  /// The guest account's row, written without opening a session — the test
  /// helper's way of seeding the demo persona before anyone has signed in.
  void seedGuestEntitlement(Map<String, dynamic> json) =>
      _entitlements[_guestAccountId] = _copy(json)!;

  // ---- journey --------------------------------------------------------------

  /// A guest session lets pre-auth flows (frame-map previews, onboarding
  /// straight from the sign-in screen) persist a journey without an account.
  String _sessionOrGuest() => _sessionAccountId ??= _guestAccountId;

  /// Who a read should attribute to, WITHOUT opening a guest session.
  ///
  /// [_sessionOrGuest] binds one as a side effect (`??=`), which is right for
  /// a write — a guest posting needs an account — and wrong for a count: a
  /// read must not change who this server thinks is signed in.
  String get _readerId => _sessionAccountId ?? _guestAccountId;

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
    final stored = _copy(post)!..remove('isMine');
    final id = stored['id'] as String;
    // Idempotent on the client's id, as `createPost` is on `clientId`: a
    // retry of a send that did land does not mint a second post — and,
    // because this is checked FIRST exactly as the callable does, it does not
    // spend a second allowance either.
    if (posts.any((p) => p['id'] == id)) return id;

    // Refused at the door, as `createPost` does with the same list: a slur
    // never lands and never claims a slot (docs/09 issue 6). Ahead of the
    // allowance, so the answer to a slur costs nobody a post.
    if (CommunityRules.check(post['text'] as String? ?? '') ==
        CommunityRuleViolation.slur) {
      throw const ContentRefusedException(ContentRefusal.rules);
    }

    // "Was anything said?" — the floor `createPost` puts under the composer's
    // own check, in the same place and ahead of the allowance, so the demo
    // backend refuses `"a"` exactly as production does.
    if (PostQuality.checkPost(
          post['text'] as String? ?? '',
          sos: post['tag'] == 'sos',
        ) !=
        null) {
      throw const ContentRefusedException(ContentRefusal.rules);
    }

    // Posting is an ALLOWANCE, not a wall (docs/12 §4.1) — the same rule
    // `createPost` enforces through `tierFor` and `claimDailyPost`, read here
    // from the fake's own entitlement row and its own posts.
    //
    // An SOS spends a SEPARATE allowance: nobody is refused a call for help
    // because they used their ordinary posts, and a post that pins to the top
    // of the feed for an hour still cannot be spammed without limit.
    final sos = post['tag'] == 'sos';
    final tier = entitlementForSession()?['tier'];
    final entitled = tier == 'premium' || tier == 'trial';
    final limit = LpAllowances.postsForKind(premium: entitled, sos: sos);
    if (_myPostsToday(sos: sos) >= limit) {
      // The same two codes the callable answers with, and for the same
      // reason: only a refusal a subscription would have prevented gets the
      // upgrade-shaped one the app turns into a door.
      throw ContentRefusedException(
        !sos && !entitled ? ContentRefusal.premium : ContentRefusal.dailyCap,
      );
    }
    // One live SOS at a time, mirroring `createPost`'s SOS_COOLDOWN_MS. The
    // window matches the feed's own pin, so the refusal is true rather than
    // arbitrary: yours is still up there.
    if (sos && _lastSosAt() != null) {
      throw const ContentRefusedException(ContentRefusal.sosCooldown);
    }
    // `held`, not `pending`: this is the verdict, not the wait for one. The
    // real mirror says the same (MIRROR_STATUS in moderatePost.ts).
    stored['status'] = CommunityRules.violates(stored['text'] as String? ?? '')
        ? 'held'
        : 'live';
    _postAuthors[id] = _sessionOrGuest();
    posts.insert(0, stored);
    return id;
  }

  /// When the caller's own SOS last landed, if it is still pinned.
  ///
  /// The fake's counterpart to the `sosUsage.lastAtMs` timestamp
  /// `claimDailyPost` writes — read off the stored posts, because the fake's
  /// whole contract is that a read reflects what was written.
  DateTime? _lastSosAt() {
    final me = _readerId;
    final now = DateTime.now();
    for (final p in posts) {
      if (_postAuthors[p['id']] != me || p['tag'] != 'sos') continue;
      final raw = p['createdAt'];
      final at = raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
      if (at != null && now.difference(at) < LpAllowances.sosPinWindow) {
        return at;
      }
    }
    return null;
  }

  /// The caller's own posts stored today in one allowance bucket.
  ///
  /// Counted off the stored posts rather than a separate counter, because the
  /// fake's whole contract is that a read reflects what was written. A post
  /// refused at the door never landed, so it never counts — which is the same
  /// guarantee `claimDailyPost` gives by only incrementing on success.
  int _myPostsToday({required bool sos}) {
    final me = _readerId;
    final now = DateTime.now();
    var count = 0;
    for (final p in posts) {
      if (_postAuthors[p['id']] != me) continue;
      if ((p['tag'] == 'sos') != sos) continue;
      final raw = p['createdAt'];
      final at = raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
      // Local calendar day, never a 24h window — the same rollover
      // `dayKeyIn` gives the server.
      if (at == null ||
          at.year != now.year ||
          at.month != now.month ||
          at.day != now.day) {
        continue;
      }
      count++;
    }
    return count;
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

/// How the fake's store sheet "ends" — see [FakeServer.nextPurchase]. One
/// value per branch the paywall has to handle, so each is one line in a test.
enum FakePurchaseScript { completed, cancelled, pending, alreadyOwned, notAllowed }
