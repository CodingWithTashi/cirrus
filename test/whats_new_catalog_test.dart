import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/core/utils/whats_new_copy.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

/// What's New is bundled, so a release without an entry would show nobody
/// anything — silently (docs/10 §55). This is the gate that makes "every
/// release has its notes" a rule rather than a habit.
void main() {
  /// `version: 1.0.32+32` → `1.0.32`.
  String pubspecVersion() {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    return line.substring('version:'.length).trim().split('+').first;
  }

  test('the version in pubspec.yaml has What\'s New notes', () {
    final version = pubspecVersion();
    expect(
      WhatsNewCatalog.has(version),
      isTrue,
      reason:
          'pubspec.yaml is $version and WhatsNewCatalog has no entry for it. '
          'Add whatsNew<version>Item1..3 to all six ARBs and an entry in '
          'lib/core/utils/whats_new_copy.dart before releasing.',
    );
  });

  test('every entry is one to three bullets of at most 80 characters, in '
      'every locale', () async {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      for (final version in WhatsNewCatalog.versions) {
        final notes = WhatsNewCatalog.notesFor(version, l10n);
        expect(notes.length, inInclusiveRange(1, 3), reason: '$locale $version');
        for (final note in notes) {
          expect(note.trim(), isNotEmpty, reason: '$locale $version');
          expect(
            note.characters.length,
            lessThanOrEqualTo(80),
            reason: '$locale $version: "$note"',
          );
        }
      }
    }
  });

  test('a build number does not hide the entry, an unknown version has none',
      () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final version = pubspecVersion();
    expect(WhatsNewCatalog.notesFor('$version+99', l10n), isNotEmpty);
    expect(WhatsNewCatalog.has('0.0.1'), isFalse);
    expect(WhatsNewCatalog.notesFor(null, l10n), isEmpty);
  });
}
