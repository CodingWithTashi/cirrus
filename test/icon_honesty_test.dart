import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chrome is drawn, not typed.
///
/// An emoji renders as the PLATFORM's own full-colour artwork: a different
/// picture on every OS version, at a weight and colour nothing in the app
/// shares, sitting beside Material glyphs that the app does control. In a
/// settings list or a header it reads as clip art dropped into a designed
/// interface, and that is exactly how it looked.
///
/// Emoji are still right in two places, and both are content rather than
/// chrome: a person's chosen avatar (`EmojiAvatar`), and the reactions and tag
/// marks in the community feed, which are the user's own vocabulary.
void main() {
  /// Files that draw app chrome — navigation, list rows, headers, empty
  /// states. Content surfaces are deliberately absent.
  const chrome = <String>[
    'lib/features/settings/settings_screens.dart',
    'lib/features/profile/profile_screen.dart',
    'lib/features/notifications/notifications_screen.dart',
    'lib/core/widgets/lp_error.dart',
  ];

  /// Ranges that cover the pictographic blocks. Deliberately not every emoji
  /// codepoint — this is a tripwire, not a linter.
  bool isPictograph(int rune) =>
      (rune >= 0x1F300 && rune <= 0x1FAFF) || // symbols, pictographs, emoji
      (rune >= 0x2600 && rune <= 0x27BF); // misc symbols, dingbats

  for (final path in chrome) {
    test('no emoji in the chrome of $path', () {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path moved or was deleted');

      final offenders = <String>[];
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Doc comments explain the rule and may name the glyphs they replaced.
        if (line.trimLeft().startsWith('//')) continue;
        // Content, declared as such at the site. An exemption has to be
        // written down next to the thing it exempts — so it is visible in
        // review rather than buried in this test's allow-list. The marker
        // may sit on the line or in the doc comment just above it, which is
        // where a reason naturally goes.
        final nearby = [
          line,
          if (i > 0) lines[i - 1],
          if (i > 1) lines[i - 2],
        ];
        if (nearby.any((l) => l.contains('emoji-ok:'))) continue;
        for (final rune in line.runes) {
          if (isPictograph(rune)) {
            offenders.add('${i + 1}: ${line.trim()}');
            break;
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Use an `IconData` from `Icons.*`, as every other row here does. '
            'Offending lines:\n${offenders.join('\n')}',
      );
    });
  }

  test('the notification icon exists at every density', () {
    // Android builds a status-bar icon from the ALPHA CHANNEL alone, so the
    // full-colour launcher icon it falls back to becomes a solid white square.
    // A missing density silently falls back to the nearest one and looks
    // soft, which is the failure this catches.
    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      final asset = File(
        'android/app/src/main/res/drawable-$density/ic_stat_cirrus.png',
      );
      expect(asset.existsSync(), isTrue, reason: 'missing for $density');
      expect(asset.lengthSync(), greaterThan(0));
    }
  });

  test('the manifest names that icon, and a colour to tint it', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      manifest,
      contains('com.google.firebase.messaging.default_notification_icon'),
      reason: 'without it Firebase falls back to the launcher icon, which '
          'Android renders as a white blob in the status bar',
    );
    expect(manifest, contains('@drawable/ic_stat_cirrus'));
    expect(
      manifest,
      contains('com.google.firebase.messaging.default_notification_color'),
    );
    expect(
      File('android/app/src/main/res/values/colors.xml').readAsStringSync(),
      contains('notification_accent'),
    );
  });

  test('scheduled reminders use the same icon as server pushes', () {
    // Both halves land in the same status bar; only one of them used to use
    // an icon shaped for it.
    expect(
      File(
        'lib/data/api/firebase/reminder_scheduler.dart',
      ).readAsStringSync(),
      contains("AndroidInitializationSettings('@drawable/ic_stat_cirrus')"),
    );
  });
}
