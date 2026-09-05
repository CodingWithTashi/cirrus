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
import '../data/stores/widget_mirror.dart';
import '../domain/logic/reminder_planner.dart';
import '../domain/models/journey_state.dart';
import '../domain/models/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/lp_palette.dart';
import 'theme/lp_theme.dart';

class LastPuffApp extends ConsumerWidget {
  const LastPuffApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsStoreProvider);
    final router = ref.watch(routerProvider);
    // Clamped on RENDER, not on selection: an expiry re-themes the app back
    // to the free family on its own, and the stored choice survives untouched
    // so resubscribing brings their palette straight back.
    //
    // Watching `isPremiumProvider` here is fine and is not the thing
    // `EntitlementStore`'s header forbids — that prohibition is specifically
    // about `routerProvider`'s refresh listener. This is a `Provider<bool>`,
    // so `MaterialApp` rebuilds only when the tier actually flips.
    final palette = LpPaletteCatalog.resolveFor(
      settings.palette,
      premium: ref.watch(isPremiumProvider),
    ).id;
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: LpTheme.light(palette),
      darkTheme: LpTheme.dark(palette),
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
              child: _ReminderSync(
                child: _WidgetSync(child: child ?? const SizedBox.shrink()),
              ),
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
      case ReminderKind.milestone:
        // The badge it is about lives on the milestones grid, which is a
        // pushed detail screen with a back chevron — so `push`, not `go`,
        // or it would land there with nothing to go back to.
        if (path != Routes.milestones) _router.push(Routes.milestones);
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
              milestoneTitle: l10n.milestoneNotifTitle,
              milestoneBody: (badgeId) => _milestoneBody(l10n, badgeId),
              // Marked when the celebration is SCHEDULED, not when it fires:
              // nothing observes a notification going off, so an unmarked
              // badge would re-arm on every resume for ever.
              onMilestoneScheduled: ref
                  .read(settingsStoreProvider.notifier)
                  .markMilestonesCelebrated,
              onMilestonesWithdrawn: ref
                  .read(settingsStoreProvider.notifier)
                  .releaseArmedMilestone,
              // First sync for this account on this device: adopt what is
              // already earned instead of celebrating it late.
              onMilestonesAdopted: ref
                  .read(settingsStoreProvider.notifier)
                  .adoptMilestones,
              now: now,
            )
            .ignore();
      });
    }
    return child;
  }
}

/// The celebration copy for one badge.
///
/// Resolved here, under the `Localizations` scope, and passed down as a plain
/// String — the scheduler has no `BuildContext` and a notification fired in the
/// wrong language is worse than none. The ids are
/// `MilestoneReminderPlanner.celebrated`; anything else falls back to the
/// title's own line rather than an empty bubble.
String _milestoneBody(AppLocalizations l10n, String badgeId) => switch (badgeId) {
  'spark' => l10n.milestoneNotifSpark,
  'weekFlame' => l10n.milestoneNotifWeekFlame,
  'twoWeekFlame' => l10n.milestoneNotifTwoWeekFlame,
  'inferno' => l10n.milestoneNotifInferno,
  'freedomDay' => l10n.milestoneNotifFreedomDay,
  _ => l10n.milestoneNotifTitle,
};

/// Keeps the home-screen widget in step with the journey, and picks up the
/// puffs it logged while the app was closed.
///
/// Renders nothing. Sits inside [_ReminderSync] so it is under a
/// `Localizations` scope: the widget draws localized copy, and pushing it from
/// here is what lets the native layout ship with no `res/values-*/strings.xml`
/// of its own — ARB stays the single source, and a language change in Settings
/// repaints the widget on the next push for free.
///
/// Does nothing on the fake backend, where [widgetCoordinatorProvider] is null
/// and there is no home screen to talk to.
class _WidgetSync extends ConsumerStatefulWidget {
  const _WidgetSync({required this.child});

  final Widget child;

  @override
  ConsumerState<_WidgetSync> createState() => _WidgetSyncState();
}

class _WidgetSyncState extends ConsumerState<_WidgetSync> {
  AppLifecycleListener? _listener;
  ProviderSubscription<JourneyState?>? _session;

  @override
  void initState() {
    super.initState();
    final coordinator = ref.read(widgetCoordinatorProvider);
    if (coordinator == null) return;

    // Constructed here rather than lazily: the listener registers itself with
    // the binding on construction.
    _listener = AppLifecycleListener(onResume: _drain);

    // Cold launch. `restoreSession` resolves inside the splash, roughly a
    // second and a half in, and every other session-establishing path
    // (email, Apple, Google, a brand-new journey) lands on the same
    // transition — so this one hook covers all of them without polling, and
    // without firing before there is a day map to apply anything to.
    _session = ref.listenManual<JourneyState?>(quitStoreProvider, (
      previous,
      next,
    ) {
      if (previous == null && next != null) {
        _drain();
      } else if (previous != null && next == null) {
        // Signed out or deleted. Whatever the widget queued belonged to that
        // account, and on a shared phone the next person to sign in must not
        // inherit it.
        unawaited(coordinator.discardQueued());
      }
    });
  }

  void _drain() {
    final coordinator = ref.read(widgetCoordinatorProvider);
    if (coordinator == null) return;
    // Every foreground re-pushes the mirror even if nothing changed. `push`
    // skips identical content, so a repaint that failed for any reason would
    // otherwise never be retried and the widget would sit there stale; one
    // trip through the app now puts it right whatever went wrong.
    coordinator.invalidate();
    // After the day clock has been refreshed by _ServerStateSync's own resume
    // handler, so a queue that spans midnight is folded in against the right
    // today. Fire-and-forget: nothing on screen waits for it.
    unawaited(
      coordinator.drain(
        ref.read(quitStoreProvider.notifier),
        now: ref.read(nowProvider)(),
      ),
    );
  }

  @override
  void dispose() {
    _session?.close();
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.watch(widgetCoordinatorProvider);
    if (coordinator == null) return widget.child;

    final journey = ref.watch(quitStoreProvider);
    // Watched for the dependency as much as the value: it recomputes when the
    // day turns, which is what refreshes the widget's day number at midnight
    // without a single line of scheduling.
    final snapshot = ref.watch(todayProvider);
    final l10n = AppLocalizations.of(context);

    final mirror = buildMirror(
      journey: journey,
      snapshot: snapshot,
      copy: WidgetCopy(
        day: l10n.widgetDay,
        leftAhead: l10n.widgetLeftAhead,
        leftTight: l10n.widgetLeftTight,
        overLimit: l10n.widgetOverLimit,
        emptyTitle: l10n.widgetEmptyTitle,
        emptyBody: l10n.widgetEmptyBody,
      ),
      now: ref.read(nowProvider)(),
    );

    // After the frame, so logging a puff never blocks its own rebuild on a
    // platform channel — the same reason _ReminderSync defers its sync.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Guarded: `ref.read` on a disposed ConsumerState throws, and this
      // callback outlives the frame it was registered in — a tree replacement,
      // a hot restart or a test teardown in that window would put a StateError
      // into the frame callback rather than anywhere it could be handled.
      if (!mounted) return;
      coordinator.push(mirror, now: ref.read(nowProvider)()).ignore();
    });

    return widget.child;
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
