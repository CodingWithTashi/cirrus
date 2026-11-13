/// Official stop-smoking and quit lines, by country (docs/15 QP-A7).
///
/// Pure Dart. A phone number in a health app is a promise that somebody
/// answers it, so **every entry carries [HelpEntry.sourceUrl], the official
/// page it was read from, and none was written from memory**. Numbers were
/// read off those pages on Nov 12 2026; `test/domain/help_directory_test.dart`
/// pins the numbers and fails if an entry is sourced from anywhere outside the
/// official hosts it lists.
///
/// Four countries, chosen from the only country data the repo holds — Search
/// Console, Aug 29 – Sep 16 2026 (docs/10 §43): US 265 impressions, UK 79,
/// Canada 28, India 13, Australia 13. India is absent on purpose until a number
/// is checked against its health ministry's own page. Every other country gets
/// an empty list, which the screen renders as "ask a doctor or pharmacist" —
/// the directory never invents a service for a country it was not checked for,
/// and never guesses a country from the language.
///
/// Adding a country: read the number off the official page, add its host to
/// the test's allow-list, and add the entry here with the page as its source.
library;

/// One service a person can call or open.
class HelpEntry {
  const HelpEntry({
    required this.id,
    required this.name,
    required this.sourceUrl,
    this.phone,
    this.dial,
    this.url,
  });

  /// Stable and unique, for keys. Never shown.
  final String id;

  /// The service's own name. A proper noun, so it is not translated.
  final String name;

  /// The number as the official page prints it, for display.
  final String? phone;

  /// [phone] as digits only, for the dialler. Kept beside it rather than
  /// derived so a vanity number ("1-800-QUIT-NOW") dials what it spells.
  final String? dial;

  /// A page to open, when the service has one worth sending somebody to.
  final String? url;

  /// The official page this entry was checked against.
  final String sourceUrl;
}

abstract final class HelpDirectory {
  static const _us = [
    HelpEntry(
      id: 'us_quitline',
      name: '1-800-QUIT-NOW',
      phone: '1-800-784-8669',
      dial: '18007848669',
      // Connects to the caller's own state quitline.
      sourceUrl: 'https://smokefree.gov/tools-tips/get-extra-help/speak-to-an-expert',
    ),
  ];

  static const _nhsServices =
      'https://www.nhs.uk/live-well/quit-smoking/nhs-stop-smoking-services-help-you-quit/';

  /// A device reports GB for the whole United Kingdom, and the NHS page prints
  /// one helpline per nation, so all three are listed with the finder that
  /// covers Northern Ireland (which prints no number).
  static const _gb = [
    HelpEntry(
      id: 'gb_services',
      name: 'NHS stop smoking services',
      url: _nhsServices,
      sourceUrl: _nhsServices,
    ),
    HelpEntry(
      id: 'gb_england',
      name: 'Smokefree National Helpline (England)',
      phone: '0300 123 1044',
      dial: '03001231044',
      sourceUrl: _nhsServices,
    ),
    HelpEntry(
      id: 'gb_scotland',
      name: 'Quit Your Way Scotland',
      phone: '0800 84 84 84',
      dial: '0800848484',
      sourceUrl: _nhsServices,
    ),
    HelpEntry(
      id: 'gb_wales',
      name: 'Help Me Quit (Wales)',
      phone: '0800 085 2219',
      dial: '08000852219',
      sourceUrl: _nhsServices,
    ),
  ];

  static const _ca = [
    HelpEntry(
      id: 'ca_quit_coach',
      name: 'Quit coach line (Canada)',
      phone: '1-866-366-3667',
      dial: '18663663667',
      sourceUrl:
          'https://www.canada.ca/en/health-canada/services/smoking-tobacco/quit-smoking/provincial-territorial-services.html',
    ),
  ];

  static const _au = [
    HelpEntry(
      id: 'au_quitline',
      name: 'Quitline',
      phone: '13 7848',
      dial: '137848',
      sourceUrl: 'https://www.quit.org.au/',
    ),
  ];

  static const _byCountry = <String, List<HelpEntry>>{
    'US': _us,
    'GB': _gb,
    'CA': _ca,
    'AU': _au,
  };

  /// The ISO 3166-1 alpha-2 codes with a checked entry.
  static Set<String> get countries => _byCountry.keys.toSet();

  /// The services for a device-reported [code], or an empty list.
  ///
  /// Case- and space-insensitive. Empty for a null, blank or unlisted code —
  /// including `UK`, which is not an ISO code and is never what a device
  /// reports (it says `GB`).
  static List<HelpEntry> forCountry(String? code) {
    final key = code?.trim().toUpperCase();
    if (key == null || key.isEmpty) return const [];
    return _byCountry[key] ?? const [];
  }
}
