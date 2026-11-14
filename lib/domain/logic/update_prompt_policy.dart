/// What the launch-time store check found, once the force rule is applied.
enum UpdateKind {
  /// Nothing to say: the store has nothing newer, it could not be read, or
  /// the person said "Not now" less than three days ago.
  none,

  /// A newer version is in the store. Offered once, over Home, with Update
  /// and Not now.
  optional,

  /// Remote Config's `force_update_app` is on AND the store has a newer
  /// version. One button, no way past it.
  forced,
}

/// Where the app is when a prompt might open — the router's path, reduced to
/// what the rules below care about. The mapping lives beside the routes
/// (`updateSurfaceOf` in `app_router.dart`); this stays free of route strings.
///
/// There is no "error screen" value: go_router's error page has no path of its
/// own to classify, so it reads as [other] — where the forced screen may stand
/// and the optional prompt, which only ever opens over [home], never does.
enum UpdateSurface {
  splash,
  onboarding,
  auth,
  dayOne,
  home,
  paywall,
  panic,
  survived,
  other,
}

/// The modals that open without a tap, in priority order: the earlier wins.
///
/// **The declaration order IS the rule** (`mayOpen` compares indices), and
/// `test/domain/update_prompt_policy_test.dart` pins it: forced update >
/// update prompt > What's New > the notification ask > the rating ask.
enum AppModal { forcedUpdate, updatePrompt, whatsNew, pushAsk, ratingAsk }

/// Store version strings, compared by number.
///
/// Its own few lines rather than `package:version`: the domain imports no
/// package, and the only versions it ever sees are this app's `x.y.z`.
abstract final class AppVersion {
  /// `1.0.32` → [1, 0, 32]; a build suffix (`+32`) is dropped, a missing part
  /// reads as 0. Null for anything that is not dotted numbers — Google Play
  /// answers "Varies with device" for some listings, and that must never be
  /// read as a version older than ours.
  static List<int>? parse(String? raw) {
    if (raw == null) return null;
    final core = raw.trim().split('+').first;
    if (core.isEmpty) return null;
    final parts = <int>[];
    for (final part in core.split('.')) {
      final n = int.tryParse(part);
      if (n == null || n < 0) return null;
      parts.add(n);
    }
    return parts;
  }

  /// Negative, zero or positive like `compareTo`; null when either side
  /// cannot be read.
  static int? compare(String? a, String? b) {
    final x = parse(a);
    final y = parse(b);
    if (x == null || y == null) return null;
    final length = x.length > y.length ? x.length : y.length;
    for (var i = 0; i < length; i++) {
      final l = i < x.length ? x[i] : 0;
      final r = i < y.length ? y[i] : 0;
      if (l != r) return l - r;
    }
    return 0;
  }

  /// Whether [candidate] is a later version than [than]. False when either
  /// cannot be read: an unknown is never "newer".
  static bool isNewer(String? candidate, String? than) =>
      (compare(candidate, than) ?? 0) > 0;
}

/// When the update prompt, the forced update screen and What's New may
/// appear (docs/10 §55).
///
/// Pure, so every rule is a one-line test. Two deliberate deviations from
/// the shared `flutter-upgrader` skill live here:
///
/// 1. **Force comes from Remote Config, never from the store listing.** The
///    skill forces through a `[:mav: x.y.z]` tag in the listing's description;
///    upgrader still parses that tag (`blocked()`), and nothing here reads it.
///    One switch, flipped in the console without a release.
/// 2. The dialog is Cirrus's own design, not the stock Cupertino/Material
///    one — that half is in `features/update/`.
abstract final class UpdatePromptPolicy {
  /// The verdict, from what the store and Remote Config said at launch.
  ///
  /// - [forceFlag] is Remote Config's `force_update_app`, and the repository
  ///   already answers false when it could not fetch this launch — fail open.
  /// - Forced needs the flag AND a store version newer than [installedVersion].
  ///   The flag left on after everyone has updated shows nothing.
  /// - A store that could not be read ([storeVersion] null or not a version)
  ///   never forces and never offers.
  /// - [tooSoon] is upgrader's three-day "Not now" clock. It quiets the
  ///   optional prompt only; a forced update is not optional.
  /// - [debugOptional] is `--dart-define=UPGRADER_DEBUG=true` (once per
  ///   launch, whatever the store says); [debugForce] is
  ///   `--dart-define=UPDATE_FORCE_DEBUG=true`, which the caller passes only
  ///   from a non-release build.
  static UpdateKind decide({
    required String? installedVersion,
    required String? storeVersion,
    required bool forceFlag,
    required bool tooSoon,
    bool debugOptional = false,
    bool debugForce = false,
  }) {
    if (debugForce) return UpdateKind.forced;
    final newer = AppVersion.isNewer(storeVersion, installedVersion);
    if (newer && forceFlag) return UpdateKind.forced;
    if (debugOptional) return UpdateKind.optional;
    if (newer && !tooSoon) return UpdateKind.optional;
    return UpdateKind.none;
  }

  /// Whether the forced screen may take over on [surface].
  ///
  /// It may appear before sign-in — an unsupported build is unsupported for
  /// everyone — but only once the splash has decided the first screen, and
  /// never in the middle of a craving, on the Survived screen after one, or
  /// over a store sheet that is taking somebody's money. Those wait until
  /// they close; the router re-asks on the next navigation.
  static bool forcedMayShow({
    required UpdateSurface surface,
    required bool storeSheetOpen,
  }) {
    if (storeSheetOpen) return false;
    return switch (surface) {
      UpdateSurface.splash ||
      UpdateSurface.panic ||
      UpdateSurface.survived => false,
      _ => true,
    };
  }

  /// Whether the optional update sheet or What's New may open now: only over
  /// the signed-in Home, only when Home is the thing on screen ([onTop]: its
  /// tab, nothing pushed or sheeted over it), and never during the Day-1
  /// tour.
  static bool promptMayShow({
    required UpdateSurface surface,
    required bool onTop,
    required bool tourRunning,
  }) => surface == UpdateSurface.home && onTop && !tourRunning;

  /// Whether [modal] may open, given what this visit has already shown and
  /// which higher modals are still [waiting] to be decided.
  ///
  /// One modal a visit: a second one waits for the next visit rather than
  /// stacking on the first. A visit is one stretch in the foreground (the
  /// latch is cleared when the app is hidden). The forced screen is exempt —
  /// it is not a choice the person can postpone.
  static bool mayOpen(
    AppModal modal, {
    required Set<AppModal> shownThisVisit,
    Set<AppModal> waiting = const {},
  }) {
    if (modal == AppModal.forcedUpdate) return true;
    if (shownThisVisit.isNotEmpty) return false;
    return !waiting.any((other) => other.index < modal.index);
  }

  /// Whether What's New is owed on this device: the installed version has
  /// notes in the bundled catalog and this device has not shown them.
  ///
  /// [hydrated] is `SettingsState.hydrated`: until disk answers, the default
  /// "never seen" would show the sheet to everybody who already saw it.
  static bool whatsNewDue({
    required String? installedVersion,
    required String? lastSeenVersion,
    required bool hasNotes,
    required bool hydrated,
  }) {
    if (!hydrated || installedVersion == null || !hasNotes) return false;
    return AppVersion.compare(installedVersion, lastSeenVersion) != 0;
  }
}
