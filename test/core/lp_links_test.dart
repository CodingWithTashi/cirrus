import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/core/utils/lp_links.dart';

/// The app's outbound links, pinned.
///
/// These are store-facing: Play will not accept a listing whose privacy policy
/// 404s, and a reviewer opens both. They also used to point at a second live
/// copy of the same legal text on `alastpuff.web.app`, which meant two originals
/// free to drift apart — the Firebase copies now 301 to the apex instead.
void main() {
  group('LpLinks', () {
    test('point at the published pages on the brand domain', () {
      expect(LpLinks.website.toString(), 'https://cirrusquit.com');
      expect(LpLinks.privacy.toString(), 'https://cirrusquit.com/privacy');
      expect(LpLinks.terms.toString(), 'https://cirrusquit.com/terms');
    });

    test('support is a mailto for the address the legal pages publish', () {
      expect(LpLinks.support.scheme, 'mailto');
      expect(LpLinks.support.path, LpLinks.supportEmail);
    });

    test('every link is https, or a mailto — never cleartext', () {
      for (final url in [LpLinks.website, LpLinks.privacy, LpLinks.terms]) {
        expect(url.scheme, 'https', reason: '$url');
      }
    });
  });

  /// The repoint is only done if the old host is gone everywhere, not just in
  /// the one file that was edited. A stray `alastpuff.web.app` would still
  /// resolve — the redirect keeps it working — so nothing would fail loudly;
  /// it would just quietly send users to a URL we intend to stop maintaining.
  test('no source file still links the retired Firebase host', () {
    const retired = 'alastpuff.web.app';
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      // Comment lines are skipped so the history above can name the old host
      // without tripping this. Note the stripping has to be line-leading only:
      // a naive "cut everything after //" would eat the `//` in `https://` and
      // hide the very thing this looks for.
      //
      // The generated localizations are rebuilt from the ARBs; if a URL ever
      // lands in one it is the ARB that needs fixing, and this still catches it.
      final offending = entity
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('//'))
          .any((line) => line.contains(retired));

      if (offending) offenders.add(entity.path);
    }

    expect(
      offenders,
      isEmpty,
      reason: 'still pointing at the retired host: ${offenders.join(', ')}',
    );
  });
}
