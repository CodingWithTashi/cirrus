import '../../domain/logic/update_prompt_policy.dart';
import '../../l10n/gen/app_localizations.dart';

/// What's New, bundled with the build it describes (docs/10 §55).
///
/// One entry per released version, as ARB keys in all six locales, so the
/// sheet a person sees after updating is in their language and was reviewed
/// with the release — unlike the update prompt's notes, which an OLD build
/// cannot carry and so come from Remote Config.
///
/// **Every release adds an entry.** `test/whats_new_catalog_test.dart` reads
/// the version in `pubspec.yaml` and fails when it has none here, so no build
/// ships without its notes. One to three bullets, each at most 80 characters,
/// plain language, never a health or quitting claim (`copy_honesty_test`
/// holds the `whatsNew` keys to the medical-claims bar).
abstract final class WhatsNewCatalog {
  static final Map<String, List<String> Function(AppLocalizations)> _entries = {
    '1.0.32': (l10n) => [
      l10n.whatsNew1032Item1,
      l10n.whatsNew1032Item2,
      l10n.whatsNew1032Item3,
    ],
    // 1.0.32 was never released on its own — the stores still carry 1.0.28 —
    // so somebody updating from 1.0.28 meets only THIS sheet, and the three
    // changes they have not seen are the same three. The text is copied, not
    // shared, so the next release can diverge without touching this one.
    '1.0.34': (l10n) => [
      l10n.whatsNew1034Item1,
      l10n.whatsNew1034Item2,
      l10n.whatsNew1034Item3,
    ],
    // The stores still carry 1.0.28, so this sheet is again the first one an
    // updating person meets, and the same three changes are still the ones
    // they have not seen. Copied for the same reason as 1.0.34 above.
    '1.0.36': (l10n) => [
      l10n.whatsNew1036Item1,
      l10n.whatsNew1036Item2,
      l10n.whatsNew1036Item3,
    ],
    // 1.0.36 IS in both stores (Android ~Nov 15, iOS Nov 17 2026 — docs/10
    // §58.4), so the copying stops here: somebody updating to 1.0.38 has
    // already seen the three bullets above. These are only what changed
    // since — the plan's first mornings and the morning titles (docs/10 §59).
    '1.0.38': (l10n) => [
      l10n.whatsNew1038Item1,
      l10n.whatsNew1038Item2,
    ],
    // 1.0.38 was never released (founder, Nov 26 2026), so an update from
    // 1.0.36 meets only THIS sheet, and the two changes it has not seen are
    // the two above. Copied for the same reason as 1.0.34. Coach cards are
    // left out on purpose: they reach subscribers and trials only, and only
    // once the functions are deployed, so a bullet would be false for every
    // free reader (docs/10 §60.13).
    '1.0.40': (l10n) => [
      l10n.whatsNew1040Item1,
      l10n.whatsNew1040Item2,
    ],
  };

  /// The versions with notes, for the catalog test.
  static Iterable<String> get versions => _entries.keys;

  /// Whether [version] (`x.y.z`, a build suffix ignored) has notes.
  static bool has(String? version) => _keyFor(version) != null;

  /// The bullets for [version], or none.
  static List<String> notesFor(String? version, AppLocalizations l10n) {
    final key = _keyFor(version);
    return key == null ? const [] : _entries[key]!(l10n);
  }

  static String? _keyFor(String? version) {
    for (final key in _entries.keys) {
      if (AppVersion.compare(key, version) == 0) return key;
    }
    return null;
  }
}
