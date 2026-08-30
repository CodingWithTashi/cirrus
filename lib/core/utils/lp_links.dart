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
  static final privacy = Uri.parse('https://alastpuff.web.app/privacy');
  static final terms = Uri.parse('https://alastpuff.web.app/terms');

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
