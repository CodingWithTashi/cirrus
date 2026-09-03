import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/lp_error.dart';
import '../core/widgets/lp_misc.dart';
import '../data/api/firebase/push_service.dart';
import '../data/backend_mode.dart';
import '../data/stores/providers.dart';
import '../domain/logic/reminder_planner.dart';
import '../domain/models/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/lp_theme.dart';

class LastPuffApp extends ConsumerWidget {
  const LastPuffApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsStoreProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: LpTheme.daylight(),
      darkTheme: LpTheme.midnight(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // App-level chrome: the offline strip floats above every screen.
      builder: (context, child) => Stack(
        children: [
          // Wraps the tree so it sits under a Localizations scope — the
          // reminder copy has to be in the user's language.
          _ServerStateSync(
            child: _PushSync(
              child: _ReminderSync(child: child ?? const SizedBox.shrink()),
            ),
          ),
          const Align(alignment: Alignment.topCenter, child: OfflineBanner()),
        ],
      ),
    );
  }
}

/// Keeps the device notification schedule in step with the journey and the
/// user's settings.
///
/// Renders nothing. It exists because the schedule depends on three things
/// that live in different places — the journey, the settings, and the
/// localized copy — and something has to sit where all three are in scope.
///
/// Syncing happens after the frame so a rebuild triggered by logging a puff
/// never blocks on a platform channel; [ReminderCoordinator] then drops the
/// call entirely when the plan has not actually changed.
class _ReminderSync extends ConsumerStatefulWidget {
  const _ReminderSync({required this.child});

  final Widget child;

  @override
  ConsumerState<_ReminderSync> createState() => _ReminderSyncState();
}

class _ReminderSyncState extends ConsumerState<_ReminderSync> {
  StreamSubscription<ReminderKind>? _taps;
  late final GoRouter _router;

  /// A tap that arrived while the splash still owned the first screen. The
  /// splash ends with a `go` that replaces the stack, so anything pushed
  /// before it is gone; the tap waits for the splash to decide, then lands.
  ReminderKind? _pending;

  @override
  void initState() {
    super.initState();
    _router = ref.read(routerProvider)..routerDelegate.addListener(_flush);
    _taps = ref.read(reminderCoordinatorProvider)?.opened.listen((kind) {
      _pending = kind;
      _flush();
    });
  }

  void _flush() {
    final kind = _pending;
    if (kind == null) return;
    final path = _router.state.uri.path;
    if (path == Routes.splash) return;
    _pending = null;
    // A signed-out phone (the splash landed on sign-in): nothing to land on,
    // and a push here would stack a second sign-in under the redirect.
    if (ref.read(quitStoreProvider) == null) return;
    switch (kind) {
      case ReminderKind.trial:
        // The reminder is about the trial: land where it says when the trial
        // ends and where to manage it. Already converted or lapsed by the
        // time of the tap → Settings shows the plan as it now stands.
        final tier = ref.read(entitlementProvider).tier;
        final target = tier == SubscriptionTier.trial
            ? Routes.trialEnding
            : Routes.settings;
        if (path != target) _router.push(target);
      case ReminderKind.danger:
        // The nudge is about the hour ahead; Home is where it is lived. The
        // redirect still sends a signed-out phone to sign-in.
        _router.go(Routes.home);
    }
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_flush);
    _taps?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final coordinator = ref.watch(reminderCoordinatorProvider);
    if (coordinator != null) {
      final journey = ref.watch(quitStoreProvider);
      final settings = ref.watch(settingsStoreProvider);
      // The trial-ending reminder follows the entitlement: scheduled the
      // moment a trial starts, withdrawn the moment it converts or ends.
      final entitlement = ref.watch(entitlementProvider);
      final now = ref.read(nowProvider);
      final l10n = AppLocalizations.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        coordinator
            .sync(
              journey: journey,
              settings: settings,
              title: l10n.dangerReminderTitle,
              body: l10n.dangerReminderBody,
              entitlement: entitlement,
              trialTitle: l10n.trialEndingNotifTitle,
              trialBody: l10n.trialEndingPush,
              now: now,
            )
            .ignore();
      });
    }
    return child;
  }
}

/// Re-reads the server-owned nightly advice when the app comes back to the
/// foreground.
///
/// `taperRecalc` writes just after the user's local midnight. Sessions are
/// long-lived — a phone left open overnight never re-runs the sign-in path —
/// so without this the advice would only ever be picked up on a cold start,
/// and the user would spend the day on yesterday's curve.
///
/// Renders nothing, and is a no-op on the fake backend, where the repository
/// answers null.
class _ServerStateSync extends ConsumerStatefulWidget {
  const _ServerStateSync({required this.child});

  final Widget child;

  @override
  ConsumerState<_ServerStateSync> createState() => _ServerStateSyncState();
}

class _ServerStateSyncState extends ConsumerState<_ServerStateSync> {
  AppLifecycleListener? _listener;

  @override
  void initState() {
    super.initState();
    // Constructed here rather than as a field initializer: the listener
    // registers itself with the binding on construction, so it must not be
    // built lazily on first access.
    _listener = AppLifecycleListener(
      onResume: () {
        ref.read(quitStoreProvider.notifier).pullPlanAdvice();
        // `syncUserContext`'s own docstring asks for sign-in, resume and any
        // timezone change — and only the first of those was wired. Someone
        // who granted notifications later from OS Settings, or who flew
        // somewhere, was not re-registered until their next cold session.
        // Fire-and-forget: a miss costs one cron cycle. Only with a session
        // to sync FOR: signed out, this call would mint a fresh FCM token
        // and burn a refused callable on every single resume.
        if (ref.read(quitStoreProvider) != null) {
          ref.read(userContextRepositoryProvider).sync().ignore();
        }
        // The same problem this widget already solves for plan advice: a
        // process Android froze overnight comes back on yesterday's date, and
        // its timers may never have fired.
        ref.read(dayClockProvider.notifier).refresh();
      },
    );
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Makes a push do something after it lands.
///
/// Everything here was missing, which meant push was dead end to end in a way
/// that reads as "we just don't send any": a token was collected on every
/// sign-in and written to Firestore, and there was no `onMessage`, no
/// `onMessageOpenedApp`, no `getInitialMessage`, and — despite the getter
/// existing — no subscriber to `onTokenRefresh`, so every reinstall silently
/// orphaned the device.
///
/// Renders nothing, and does nothing at all on the fake backend, where there
/// is no FCM to listen to.
class _PushSync extends ConsumerStatefulWidget {
  const _PushSync({required this.child});

  final Widget child;

  @override
  ConsumerState<_PushSync> createState() => _PushSyncState();
}

class _PushSyncState extends ConsumerState<_PushSync> {
  final _subs = <StreamSubscription<Object?>>[];

  /// Destinations a push is allowed to ask for. See [PushService.routeFor].
  ///
  /// `Routes.paywall` here is the app's TWELFTH paywall door and the only
  /// untagged one: it arrived bare, so the route builder's `'direct'` default
  /// applied and a push-driven paywall was indistinguishable in the funnel
  /// from the debug frame map's. [taggedPushRoute] fixes that at the door.
  static const _allowedRoutes = {
    Routes.community,
    Routes.insight,
    Routes.coach,
    Routes.home,
    Routes.paywall,
  };

  @override
  void initState() {
    super.initState();
    // The PROVIDER, never `resolveBackendMode()` directly: the test platform
    // reports android, so reading the platform here would reach for
    // FirebaseMessaging in every widget test that pumps the app. This is the
    // same trap `fastBackendOverrides()` exists to close for the repositories.
    if (ref.read(backendModeProvider) != BackendMode.firebase) return;

    // The Android channel the manifest routes background pushes into has to
    // actually exist; see PushService.ensureAndroidChannel.
    PushService.ensureAndroidChannel().ignore();

    // A rotated token is a device we can no longer reach. Re-register it —
    // through the store, which skips it when nobody is signed in (QA L6).
    _subs.add(
      PushService.onTokenRefresh.listen(
        (token) =>
            ref.read(quitStoreProvider.notifier).onPushTokenRefreshed(token),
      ),
    );

    // Tapped from the background.
    _subs.add(PushService.onOpened.listen(_openFrom));

    // Foreground: Android draws nothing itself, so without this the message
    // arrives and the user never learns it did.
    _subs.add(
      PushService.onForeground.listen((message) {
        final body = message.notification?.body;
        if (body == null || body.isEmpty || !mounted) return;
        showLpSnack(context, body);
      }),
    );

    // Tapped while the app was not running at all.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initial = await PushService.initialMessage();
      if (initial != null) _openFrom(initial);
    });
  }

  void _openFrom(RemoteMessage message) {
    final route = PushService.routeFor(message, _allowedRoutes);
    // No route, or one we do not accept: opening the app is still the right
    // outcome, so this is deliberately silent rather than an error.
    if (route == null || !mounted) return;
    ref.read(routerProvider).go(taggedPushRoute(route));
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Stamps `source=push` on a paywall a notification opened.
///
/// `paywall_viewed` reads `?source=`, and the route builder defaults a missing
/// one to `direct` — which is also what the debug frame map reports, so a
/// push-driven paywall could not be told apart from it. `lp_events.dart` has
/// documented a `push` source all along; nothing ever passed one.
///
/// A source the SERVER already put on the route wins: the payload is how a
/// campaign names itself, and this must not overwrite that.
String taggedPushRoute(String route) {
  final uri = Uri.tryParse(route);
  if (uri == null) return route;
  if (uri.path != Routes.paywall) return route;
  if ((uri.queryParameters['source'] ?? '').isNotEmpty) return route;
  return Routes.paywallFrom('push');
}
