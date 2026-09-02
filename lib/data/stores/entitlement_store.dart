import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/analytics/lp_events.dart';
import '../../domain/logic/billing_catalog.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../network/connectivity.dart';
import 'providers.dart';

/// View model of what this account is entitled to.
///
/// The client's tier lives HERE and nowhere else — not on the journey, which
/// the app writes wholesale into its own Firestore document and which the
/// server therefore never believes. Reads are synchronous (`isPremiumProvider`
/// is a bool, never a loading state), the value starts from the billing SDK's
/// on-disk cache so a returning subscriber is Premium on the first frame, and
/// every later change — a renewal, an expiry, a purchase on another device —
/// arrives through [BillingRepository.changes].
///
/// **Never wire this provider into `routerProvider`'s refresh listener.**
/// Nothing in `redirect` depends on tier, and that independence is what lets
/// a paywall call `leavePaywall()` across an async purchase without the
/// pushed route coming back (see `paywall_screens.dart`).
///
/// Sessions come and go under this store on one phone. Every answer from the
/// billing backend is stamped with the session generation it was asked for,
/// and an answer for a session that has since been unbound is dropped — the
/// sign-out → sign-in race used to let the previous person's slow `logOut`
/// wipe the next person's Premium, or leave the previous person's Premium on
/// a signed-out phone.
class EntitlementStore extends Notifier<Entitlement> {
  /// Tests seed a tier the way `SettingsStore(restore: false)` pins defaults.
  EntitlementStore({Entitlement? initial}) : _initial = initial;

  final Entitlement? _initial;

  /// The identity the backend has answered for (null until it has).
  String? _boundUid;

  /// The identity of the current session, whether or not the bind succeeded.
  /// Retries target this.
  String? _requestedUid;
  bool _bindRequested = false;
  bool _bindInFlight = false;
  Future<void>? _binding;

  /// The reset the last unbind started. A bind waits for it: the backend's
  /// log-out answer — and the "nobody" it publishes on the change stream —
  /// must land BEFORE the next identity is asked for, or it could land after
  /// that identity's answer and erase it.
  Future<void>? _resetting;

  /// Bumped on every unbind. An identify that started under an older
  /// generation belongs to a session that is over; its answer is discarded.
  int _generation = 0;

  /// Purchases and restores in flight. Their changes reach [_apply] both as
  /// the awaited result and, on a device, as the SDK's own listener push —
  /// which can arrive first. Neither is a "remote" change worth announcing.
  int _selfChanges = 0;

  /// True once the billing backend has answered for the bound session —
  /// the moment "free" stops meaning "unknown". Gates that would put a
  /// screen in someone's way (the once-a-day launch paywall) wait for this;
  /// gates that merely lock a feature read the value as it stands.
  bool get isSettled => _settled;
  bool _settled = false;

  /// Completes when the current session's first bind attempt has settled,
  /// one way or the other. Never errors: a failed bind settles too — with the
  /// cached value. Replaced on unbind, so the next session waits for its own.
  Future<void> get settled => _settledCompleter.future;
  Completer<void> _settledCompleter = Completer<void>();

  @override
  Entitlement build() {
    final repo = ref.watch(billingRepositoryProvider);
    final sub = repo.changes().listen(_onChanged);
    ref.onDispose(sub.cancel);
    // A bind that failed for want of a network is retried the moment the
    // network is back. Without this a sign-in on a dead connection left the
    // gates locked until the next cold start — the SDK's listener never fires
    // for an identity it was never told about.
    ref.listen<bool>(connectivityProvider, (_, online) {
      if (online && _bindRequested && !_settled && !_bindInFlight) {
        unawaited(bindSession(_requestedUid));
      }
    });
    return _initial ?? repo.cached ?? const Entitlement.none();
  }

  /// Binds the billing identity to the session. Called from the one place a
  /// session is established (`JourneyStore._onSessionEstablished`), never
  /// from a view. Never throws: offline at launch simply leaves the cached
  /// value standing, which is the right answer.
  Future<void> bindSession(String? uid) {
    final repo = ref.read(billingRepositoryProvider);
    final generation = _generation;
    _bindRequested = true;
    _requestedUid = uid;
    _bindInFlight = true;
    return _binding = () async {
      try {
        final resetting = _resetting;
        if (resetting != null) await resetting;
        final answer = await repo.identify(uid);
        if (generation != _generation) return;
        _apply(answer);
        _boundUid = uid;
        _settled = true;
      } on Exception {
        // Cached entitlement stands until the wire is back. Deliberately NOT
        // settled: an offline launch must not be read as "known free".
      } finally {
        _bindInFlight = false;
        if (generation == _generation && !_settledCompleter.isCompleted) {
          _settledCompleter.complete();
        }
      }
    }();
  }

  /// Unbinds on sign-out and deletion, so the next person on this phone does
  /// not inherit the last one's Premium.
  ///
  /// The phone forgets first, synchronously; the backend is told after. A
  /// sign-in that lands while the SDK is still logging the old identity out
  /// must not be overwritten when that log-out completes.
  Future<void> unbind() async {
    _generation++;
    _boundUid = null;
    _requestedUid = null;
    _bindRequested = false;
    _bindInFlight = false;
    _binding = null;
    _settled = false;
    _settledCompleter = Completer<void>();
    state = const Entitlement.none();
    final generation = _generation;
    final resetting = ref.read(billingRepositoryProvider).reset();
    _resetting = resetting;
    try {
      await resetting;
    } finally {
      if (identical(_resetting, resetting)) _resetting = null;
      // Whatever the stream said meanwhile, a signed-out phone holds nothing
      // — unless a newer session has already bound past this one.
      if (generation == _generation) state = const Entitlement.none();
    }
  }

  /// Opens the store sheet for [planId] — after making sure there is an
  /// identity to file the purchase under. Guest onboarding reaches the
  /// paywall before any session exists; buying first and identifying later
  /// would file the receipt under an id nobody can read back.
  ///
  /// Already-active accounts never see a sheet: a retry after a paid purchase
  /// whose journey creation failed, or a subscriber who tapped the CTA from
  /// an in-app upsell, gets the entitlement they already hold. That check
  /// runs AFTER the identity is bound, so it is the store's answer for this
  /// account — never a value left over from a previous session.
  Future<PurchaseOutcome> purchase(String planId) async {
    final repo = ref.read(billingRepositoryProvider);
    final analytics = ref.read(analyticsProvider);
    final plan = BillingCatalog.periodOfPackage(planId)?.name ?? planId;
    _selfChanges++;
    try {
      await _ensureBound(repo);
      if (state.isActive) return PurchaseCompleted(state);
      final outcome = await repo.purchase(planId);
      switch (outcome) {
        case PurchaseCompleted(:final entitlement):
          _apply(entitlement, announce: false);
          analytics.purchaseCompleted(plan, trial: entitlement.isTrial);
        case PurchaseCancelled():
          analytics.purchaseCancelled(plan);
        case PurchasePending():
          break;
      }
      return outcome;
    } on Exception catch (error) {
      analytics.purchaseFailed(_failureCode(error));
      rethrow;
    } finally {
      _selfChanges--;
    }
  }

  /// Asks the store what this store account owns. `isActive == false` on
  /// the answer is "nothing to restore" — a normal result the caller says
  /// out loud.
  Future<Entitlement> restore() async {
    final repo = ref.read(billingRepositoryProvider);
    final analytics = ref.read(analyticsProvider);
    _selfChanges++;
    try {
      await _ensureBound(repo);
      final e = await repo.restore();
      _apply(e, announce: false);
      analytics.restoreCompleted(found: e.isActive);
      return e;
    } finally {
      _selfChanges--;
    }
  }

  /// Makes sure the backend has answered for the session's identity, minting
  /// a guest identity when there is none yet. Throws the wire failure, which
  /// the caller surfaces — a purchase cannot proceed on an unknown identity.
  Future<void> _ensureBound(BillingRepository repo) async {
    final pending = _binding;
    if (pending != null) await pending;
    final resetting = _resetting;
    if (resetting != null) await resetting;
    final uid = await ref.read(authRepositoryProvider).ensureSessionId();
    if (_boundUid == uid) return;
    final generation = _generation;
    final answer = await repo.identify(uid);
    if (generation != _generation) return;
    _apply(answer);
    _boundUid = uid;
    _requestedUid = uid;
    _bindRequested = true;
    _binding = Future.value();
    _settled = true;
    if (!_settledCompleter.isCompleted) _settledCompleter.complete();
  }

  /// While a reset is in flight the stream is in flux — the purchase echo of
  /// the identity being logged out, the SDK's "nobody" for the anonymous
  /// user that replaces it. None of it is this phone's tier; the reset's own
  /// completion is. Events after the reset (the next sign-in's) apply.
  void _onChanged(Entitlement next) {
    if (_resetting != null) return;
    _apply(next);
  }

  /// [announce] is false for changes this store caused itself (a purchase, a
  /// restore), which already have their own event; while one is in flight,
  /// the SDK's own push of the same change is not announced either.
  void _apply(Entitlement next, {bool announce = true}) {
    if (next == state) return;
    state = next;
    if (announce && _selfChanges == 0) {
      ref.read(analyticsProvider).entitlementChanged(next.tier.name);
    }
  }

  static String _failureCode(Object error) => switch (error) {
    NoConnectionException() => 'offline',
    PurchaseNotAllowedException() => 'not_allowed',
    ReceiptOwnedElsewhereException() => 'receipt_owned',
    StoreUnavailableException() => 'store',
    _ => 'other',
  };
}
