import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

/// The store name is Cirrus (founder decision, Aug 29 2026). "LastPuff" was
/// the working title and survives only as internal identifiers — the Dart
/// package name, `LastPuffApp`, and the `docs/design/LastPuff Run *` bundle
/// filenames, none of which a user ever sees.
///
/// These tests exist because a rename is exactly the kind of change that
/// lands in English and quietly misses four other locales.
void main() {
  const brand = 'Cirrus';
  const retired = 'LastPuff';

  test('every locale ships the current brand name', () async {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(
        l10n.appName,
        brand,
        reason: 'appName drifted in ${locale.languageCode}',
      );
    }
  });

  test('no ARB file still carries the retired working title', () {
    final arbs = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.arb'));

    expect(arbs, isNotEmpty, reason: 'ARB files not found — wrong cwd?');

    for (final file in arbs) {
      expect(
        file.readAsStringSync(),
        isNot(contains(retired)),
        reason: '${file.path} still says $retired',
      );
    }
  });

  test('the native app labels match the brand', () {
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:label="$brand"'),
    );
    // CFBundleDisplayName is the springboard label. Line endings are
    // normalized because the repo checks out CRLF on Windows.
    final plist = File(
      'ios/Runner/Info.plist',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    expect(
      plist,
      contains('<key>CFBundleDisplayName</key>\n\t<string>$brand</string>'),
    );
  });
}
