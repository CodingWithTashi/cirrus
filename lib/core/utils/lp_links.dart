import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// The app's outbound links, in one place.
///
/// Terms and Privacy are store requirements — Play will not accept a listing
/// without them — and they were rendered as plain, non-tappable text for as
/// long as the pages did not exist. That was the right call at the time: a
/// link to a 404 is worse than a label, because it looks like the document is
/// there. The pages are published now, so they are links.
abstract final class LpLinks {
  /// The brand site. One host for everything the app links out to, so the
  /// policy a user reads is the one the marketing site publishes.
  ///
  /// These used to point at `alastpuff.web.app`, which served a byte-identical
  /// copy of both documents — two live originals that were free to drift apart.
  /// The Firebase copies now 301 here (see the `hosting.redirects` block in
  /// `firebase.json`), which is why the redirect must outlive the files: every
  /// build ever installed still asks for the old URL.
  static const host = 'https://cirrusquit.com';

  static final website = Uri.parse(host);
  static final privacy = Uri.parse('$host/privacy');
  static final terms = Uri.parse('$host/terms');

  /// The address both legal pages already publish, so this discloses nothing
  /// new. Rendered as visible text wherever it is tappable: if no mail app
  /// handles it, the reader can still see who to write to.
  static const supportEmail = 'support@cirrusquit.com';
  static final support = Uri.parse('mailto:$supportEmail');

  /// Opens [url] in the browser. Returns whether anything handled it.
  ///
  /// Never throws: a device with no browser is an odd device, not a reason to
  /// crash the sign-in screen.
  static Future<bool> open(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } on Object catch (error) {
      debugPrint('links: could not open $url — $error');
      return false;
    }
  }
}
