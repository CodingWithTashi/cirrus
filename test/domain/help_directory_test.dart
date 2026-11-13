import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/help_directory.dart';

/// docs/15 QP-A7. A phone number in a health app is a promise that somebody
/// answers it, so every entry carries the official page it was checked
/// against, and none was written from memory.
void main() {
  List<HelpEntry> all() => [
    for (final code in HelpDirectory.countries) ...HelpDirectory.forCountry(code),
  ];

  /// The only hosts an entry may be sourced from. Adding a country means
  /// adding its official host here on purpose, in a diff somebody reads — a
  /// blog or a directory site is not a source for a number people will dial
  /// at their worst moment.
  const officialHosts = {
    'smokefree.gov',
    'www.nhs.uk',
    'www.canada.ca',
    'www.quit.org.au',
  };

  test('covers the countries the site traffic shows, and no others yet', () {
    // Search Console, Aug 29 – Sep 16 2026 (docs/10 §43): US 265, UK 79,
    // Canada 28, India 13, Australia 13. India is deliberately absent until a
    // number is checked against its health ministry's own page.
    expect(HelpDirectory.countries, {'US', 'GB', 'CA', 'AU'});
  });

  test('every entry names an official https source', () {
    expect(all(), isNotEmpty);
    for (final e in all()) {
      final source = Uri.parse(e.sourceUrl);
      expect(source.scheme, 'https', reason: e.id);
      expect(
        officialHosts,
        contains(source.host),
        reason: '${e.id} is sourced from ${source.host}',
      );
    }
  });

  test('every entry can be reached: a number to call or a page to open', () {
    for (final e in all()) {
      expect(
        e.phone != null || e.url != null,
        isTrue,
        reason: '${e.id} has no way to reach it',
      );
      if (e.url != null) {
        expect(Uri.parse(e.url!).scheme, 'https', reason: e.id);
      }
    }
  });

  test('a dialled number is the displayed number, digits only', () {
    for (final e in all().where((e) => e.phone != null)) {
      expect(e.dial, isNotNull, reason: '${e.id} shows a number it cannot dial');
      expect(e.dial, matches(RegExp(r'^[0-9]+$')), reason: e.id);
      final shown = e.phone!.replaceAll(RegExp(r'[^0-9]'), '');
      expect(e.dial, shown, reason: '${e.id}: display and dial disagree');
    }
  });

  test('ids are unique, because analytics and keys lean on them', () {
    final ids = [for (final e in all()) e.id];
    expect(ids.toSet().length, ids.length);
  });

  group('the numbers, as the official pages print them', () {
    HelpEntry entry(String country, String id) =>
        HelpDirectory.forCountry(country).firstWhere((e) => e.id == id);

    test('United States: 1-800-QUIT-NOW', () {
      final e = entry('US', 'us_quitline');
      expect(e.name, '1-800-QUIT-NOW');
      expect(e.phone, '1-800-784-8669');
      expect(e.dial, '18007848669');
      expect(e.sourceUrl, contains('smokefree.gov'));
    });

    test('United Kingdom: the three national helplines and the finder', () {
      expect(entry('GB', 'gb_england').phone, '0300 123 1044');
      expect(entry('GB', 'gb_scotland').phone, '0800 84 84 84');
      expect(entry('GB', 'gb_wales').phone, '0800 085 2219');
      // Northern Ireland prints no number on the page, only a finder, so the
      // finder is the entry for all four nations.
      expect(entry('GB', 'gb_services').url, isNotNull);
      expect(entry('GB', 'gb_services').phone, isNull);
    });

    test('Canada: the national quit coach line', () {
      expect(entry('CA', 'ca_quit_coach').phone, '1-866-366-3667');
    });

    test('Australia: Quitline', () {
      final e = entry('AU', 'au_quitline');
      expect(e.phone, '13 7848');
      expect(e.dial, '137848');
    });
  });

  group('which country', () {
    test('is read case- and space-insensitively', () {
      final us = HelpDirectory.forCountry('US');
      expect(HelpDirectory.forCountry('us'), us);
      expect(HelpDirectory.forCountry(' Us '), us);
    });

    test('an unknown, empty or missing region lists nobody', () {
      // The screen turns an empty list into "ask a doctor or pharmacist". The
      // directory never invents a service for a country it was not checked
      // for, and never guesses one from the language.
      for (final code in ['ZZ', 'IN', '', '  ', null]) {
        expect(HelpDirectory.forCountry(code), isEmpty, reason: '$code');
      }
    });

    test('the UK is GB, which is what a device reports', () {
      expect(HelpDirectory.forCountry('UK'), isEmpty);
      expect(HelpDirectory.forCountry('GB'), isNotEmpty);
    });
  });
}
