import 'lp_colors.dart';

/// The palette families the app ships.
///
/// Orthogonal to `ThemeMode`: this picks the FAMILY, `ThemeMode` still picks
/// light / dark / system within it. That split is not cosmetic — `ThemeMode`
/// has exactly three values and `MaterialApp` takes exactly two `ThemeData`s,
/// so folding six palettes into one list would have cost "Match system"
/// entirely. A Premium reader keeps it.
///
/// **Persisted by `.name`** (`settings.palette` in `SharedPreferences`), so a
/// value here is a wire value: renaming one silently resets everybody who had
/// chosen it. `test/app/lp_palette_test.dart` pins the names.
///
/// Note this is the fifth thing in the repo called "ember" — the palette
/// token [LpColors.ember], the `CoachRole.ember` wire value, one of the eight
/// `_randomAlias` adjectives, the mascot, and now this. A repo-wide
/// find-and-replace takes all of them.
enum LpPalette { ember, hearth, tide }

/// One family as the app sees it: an id, a tier, and its two modes.
class PaletteEntry {
  const PaletteEntry({
    required this.id,
    required this.dark,
    required this.light,
    this.premium = false,
  });

  final LpPalette id;
  final LpColors dark;
  final LpColors light;

  /// Whether a subscription is needed to wear it. Ember is free forever and
  /// is [LpPaletteCatalog.entries]`.first`, so a free account always has a
  /// palette it is entitled to.
  final bool premium;
}

/// The palette families, in picker order.
///
/// **Ember is first, and that is load-bearing.** [resolveFor] falls back to
/// the first FREE entry, so the palette actually rendered — for a new user,
/// and for anyone whose subscription has lapsed — is always one they own.
///
/// Shaped on `GameCatalog` deliberately: this is the same problem the panic
/// arena solved. A locked option stays visible and stays tappable (hiding the
/// two Premium families would make the cleanest Settings screen and sell
/// nothing), but it can never be the state the app *lands* in.
abstract final class LpPaletteCatalog {
  static const List<PaletteEntry> entries = [
    PaletteEntry(
      id: LpPalette.ember,
      dark: LpColors.midnight(),
      light: LpColors.daylight(),
    ),
    PaletteEntry(
      id: LpPalette.hearth,
      dark: LpColors.hearthNight(),
      light: LpColors.hearthDay(),
      premium: true,
    ),
    PaletteEntry(
      id: LpPalette.tide,
      dark: LpColors.deepTide(),
      light: LpColors.arcticTide(),
      premium: true,
    ),
  ];

  static PaletteEntry? of(LpPalette id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// The entry for [id], or the first family when unknown or null.
  static PaletteEntry resolve(LpPalette? id) =>
      (id == null ? null : of(id)) ?? entries.first;

  /// The family to RENDER for a reader of this tier.
  ///
  /// Clamps to a free family whenever [premium] is false, which is what makes
  /// an expiry safe: the app re-themes itself back to Ember the moment the
  /// entitlement goes, with no migration and no stuck state. Clamping happens
  /// on render rather than on selection on purpose — the stored choice is
  /// never overwritten, so resubscribing brings their palette straight back.
  static PaletteEntry resolveFor(LpPalette? id, {required bool premium}) {
    final entry = resolve(id);
    if (premium || !entry.premium) return entry;
    return entries.firstWhere((e) => !e.premium);
  }

  /// How many families a free account can wear. Read by the paywall's
  /// comparison table so it quotes what the app enforces rather than a typed
  /// number that goes stale the first time this list moves.
  static int get freeCount => entries.where((e) => !e.premium).length;
}
