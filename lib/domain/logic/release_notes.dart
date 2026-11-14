import 'dart:convert';

import 'update_prompt_policy.dart';

/// The notes for a version the installed app has never seen, from Remote
/// Config's `update_release_notes` (docs/10 §55).
///
/// An old build cannot carry a newer build's notes, so they are written in
/// the console as a JSON string:
///
/// ```json
/// {"version":"1.0.33","en":["…"],"de":["…"],"es":["…"],"fr":["…"],"it":["…"],"pt":["…"]}
/// ```
///
/// The console default is `{}`. Parsing never throws: a typo in the console
/// costs the list, never the prompt.
class RemoteReleaseNotes {
  const RemoteReleaseNotes._(this.version, this._byLanguage);

  static const RemoteReleaseNotes empty = RemoteReleaseNotes._(null, {});

  /// The most bullets shown, and the longest one kept. A bullet over the
  /// limit is dropped, never cut mid-word: a clipped sentence reads as a bug.
  static const int maxItems = 3;
  static const int maxLength = 80;

  /// The version these notes describe, or null when there is none.
  final String? version;
  final Map<String, List<String>> _byLanguage;

  static RemoteReleaseNotes parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return empty;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return empty;
    }
    if (decoded is! Map<String, dynamic>) return empty;
    final version = decoded['version'];
    if (version is! String || version.trim().isEmpty) return empty;
    final byLanguage = <String, List<String>>{};
    for (final entry in decoded.entries) {
      if (entry.key == 'version') continue;
      final items = entry.value;
      if (items is! List) continue;
      byLanguage[entry.key] = [
        for (final item in items)
          if (item is String &&
              item.trim().isNotEmpty &&
              item.trim().length <= maxLength)
            item.trim(),
      ].take(maxItems).toList();
    }
    return RemoteReleaseNotes._(version.trim(), byLanguage);
  }

  /// The bullets written for [languageCode] (`en`, `de`, …), or none.
  List<String> forLanguage(String languageCode) =>
      _byLanguage[languageCode] ?? const [];
}

/// Which bullets the update prompt shows.
abstract final class UpdateNotes {
  /// - Remote Config's notes, when they describe [storeVersion] — the
  ///   reader's language, then English from the same notes;
  /// - otherwise the store's own release notes ([storeNotes], from upgrader),
  ///   cleaned into at most three lines;
  /// - otherwise nothing, and the prompt shows no list. Never invented.
  static List<String> resolve({
    required RemoteReleaseNotes remote,
    required String? storeVersion,
    required String? storeNotes,
    required String languageCode,
  }) {
    if (remote.version != null &&
        AppVersion.compare(remote.version, storeVersion) == 0) {
      final own = remote.forLanguage(languageCode);
      if (own.isNotEmpty) return own;
      final english = remote.forLanguage('en');
      if (english.isNotEmpty) return english;
    }
    return _storeLines(storeNotes);
  }

  static final _tag = RegExp(r'<[^>]*>');
  static final _bullet = RegExp(r'^[•\-*·–—]+\s*');

  /// Store notes are free text: iTunes sends plain lines, Google Play's
  /// page is HTML that upgrader turns into lines at each `<br>`. Tags and the
  /// common entities go, list markers go, blank lines go, three are kept.
  static List<String> _storeLines(String? notes) {
    if (notes == null) return const [];
    return [
      for (final raw in notes.split('\n'))
        if (_clean(raw).isNotEmpty) _clean(raw),
    ].take(RemoteReleaseNotes.maxItems).toList();
  }

  static String _clean(String line) => line
      .replaceAll(_tag, '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim()
      .replaceFirst(_bullet, '')
      .trim();
}
