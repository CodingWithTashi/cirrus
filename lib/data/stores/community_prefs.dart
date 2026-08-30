import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Disk for the reader-side moderation choices: blocked and muted authors.
///
/// These were an in-memory `Set` that a cold start emptied, which means the
/// app quietly un-blocked people. Blocking is an App Store Guideline 1.2
/// requirement and, more to the point, it is a promise: someone who blocks an
/// author after a bad exchange should not meet them again on the next launch
/// because we only remembered it until the process died.
///
/// Local rather than server-side on purpose. Aliases are per-account and there
/// is no relationship to store; sending a block list to the backend would
/// create exactly the link between two accounts that keeps this feed
/// anonymous. The moderation queue is what handles content that should be gone
/// for everybody.
abstract final class CommunityPrefs {
  static const _blocked = 'community.blockedAliases';
  static const _muted = 'community.mutedAliases';

  /// Restored sets, or empty ones when nothing is stored or the platform is
  /// unavailable. Never throws — a reader who cannot load their block list
  /// still gets a working feed, and the alternative is a broken screen.
  static Future<({Set<String> blocked, Set<String> muted})> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (
        blocked: (prefs.getStringList(_blocked) ?? const []).toSet(),
        muted: (prefs.getStringList(_muted) ?? const []).toSet(),
      );
    } on Object catch (error) {
      debugPrint('community prefs: restore failed — $error');
      return (blocked: <String>{}, muted: <String>{});
    }
  }

  /// Writes both sets. Called after every block or mute; write-behind, so a
  /// failure costs the persistence, never the interaction.
  static Future<void> save({
    required Set<String> blocked,
    required Set<String> muted,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_blocked, blocked.toList());
      await prefs.setStringList(_muted, muted.toList());
    } on Object catch (error) {
      debugPrint('community prefs: save failed — $error');
    }
  }
}
