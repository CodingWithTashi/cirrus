import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/whats_new_copy.dart';
import '../data/stores/day1_tour_store.dart';
import '../data/stores/providers.dart';
import '../data/stores/update_check_store.dart';
import '../domain/logic/update_prompt_policy.dart';
import '../features/update/update_views.dart';
import 'router/app_router.dart';

/// Opens the optional update prompt, then What's New, over the signed-in Home
/// and nowhere else (docs/10 §55).
///
/// Mounted around [HomeScreen] by the router, so it exists only where the
/// prompt may appear: never over the splash, the quiz, sign-in, the Day-1
/// tour, a paywall, a craving or an error page. The forced screen is not this
/// widget's business — the router stands it in front of everything.
///
/// The `flutter-upgrader` skill's `UpdatePrompt` wraps upgrader's stock
/// `UpgradeAlert`; this one is Cirrus's own, deliberately (docs/10 §55): the
/// force comes from Remote Config rather than a tag in the store listing, and
/// the dialog is ours. What stays the skill's: upgrader's store lookup, Update
/// and Later only (no Ignore), checked at start and not on resume, and the
/// three-day quiet after Later.
///
/// Order, one a visit (`AppModal`): forced > this prompt > What's New > the
/// notification ask > the rating ask. What's New waits while the store check
/// is still out, so it can never open a moment before the prompt that
/// outranks it; skipped, it is not marked seen and shows on a later visit.
class UpdatePrompt extends ConsumerStatefulWidget {
  const UpdatePrompt({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdatePrompt> createState() => _UpdatePromptState();
}

class _UpdatePromptState extends ConsumerState<UpdatePrompt> {
  late final AppLifecycleListener _lifecycle;

  /// A sheet is open (or opening) from here.
  bool _open = false;

  /// A post-frame look is already queued.
  bool _queued = false;

  @override
  void initState() {
    super.initState();
    // A visit starts when the app comes back; Home may already be on top.
    _lifecycle = AppLifecycleListener(onResume: _queue);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _queue() {
    if (_queued || !mounted) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      _maybeOpen();
    });
  }

  /// Whether Home is what the person is looking at, with nothing over it.
  bool _onTop() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return false;
    }
    // Off when another tab is showing, or a pushed route covers the shell.
    if (!TickerMode.valuesOf(context).enabled) return false;
    final router = ref.read(routerProvider);
    if (router.routerDelegate.currentConfiguration.uri.path != Routes.home) {
      return false;
    }
    // A sheet or dialog of somebody else's, on either navigator.
    if (lpRootNavigatorKey.currentState?.canPop() ?? false) return false;
    if (Navigator.maybeOf(context)?.canPop() ?? false) return false;
    return true;
  }

  Future<void> _maybeOpen() async {
    if (!mounted || _open) return;
    final check = ref.read(updateCheckProvider);
    final allowed = UpdatePromptPolicy.promptMayShow(
      surface: UpdateSurface.home,
      onTop: _onTop(),
      tourRunning:
          ref.read(day1TourProvider).running ||
          ref.read(day1TourLockedProvider),
    );
    if (!allowed || check.forced) return;
    final visit = ref.read(visitModalsProvider.notifier);

    if (check.kind == UpdateKind.optional &&
        !check.offered &&
        visit.mayOpen(AppModal.updatePrompt)) {
      _open = true;
      try {
        await showUpdateSheet(context, ref);
      } finally {
        _open = false;
      }
      return _queue();
    }

    final settings = ref.read(settingsStoreProvider);
    final installed = ref.read(installedVersionProvider).value;
    final due = UpdatePromptPolicy.whatsNewDue(
      installedVersion: installed,
      lastSeenVersion: settings.whatsNewSeenVersion,
      hasNotes: WhatsNewCatalog.has(installed),
      hydrated: settings.hydrated,
    );
    if (!due || installed == null) return;
    if (!visit.mayOpen(
      AppModal.whatsNew,
      waiting: {if (check.promptWaiting) AppModal.updatePrompt},
    )) {
      return;
    }
    _open = true;
    try {
      await showWhatsNewSheet(context, ref, installed);
    } finally {
      _open = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Every input to the decision, so a change to any of them looks again:
    // the verdict landing, the preferences answering, the version resolving,
    // the tour ending, a new visit — and the tab or route changing, through
    // the TickerMode dependency `_onTop` takes.
    ref.watch(updateCheckProvider);
    ref.watch(
      settingsStoreProvider.select(
        (s) => (s.hydrated, s.whatsNewSeenVersion),
      ),
    );
    ref.watch(installedVersionProvider);
    ref.watch(day1TourProvider);
    ref.watch(day1TourLockedProvider);
    ref.watch(visitModalsProvider);
    TickerMode.valuesOf(context);
    _queue();
    return widget.child;
  }
}
