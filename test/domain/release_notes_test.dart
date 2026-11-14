import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/release_notes.dart';

/// What the update prompt says is in the new version (docs/10 §55).
///
/// An installed app cannot contain a newer version's notes, so they come from
/// Remote Config — and only when they are about the version the store is
/// actually offering. Otherwise the store's own notes, otherwise nothing.
/// Never an invented line.
void main() {
  const json = '''
{"version":"1.0.33",
 "en":["Faster logging","A calmer Home"],
 "de":["Schneller loggen"],
 "it":[]}''';

  group('parse', () {
    test('reads the version and every locale list', () {
      final notes = RemoteReleaseNotes.parse(json);
      expect(notes.version, '1.0.33');
      expect(notes.forLanguage('en'), ['Faster logging', 'A calmer Home']);
      expect(notes.forLanguage('de'), ['Schneller loggen']);
      expect(notes.forLanguage('fr'), isEmpty);
    });

    test('the console default, junk and a non-object all read as no notes', () {
      for (final raw in ['{}', '', 'not json', '[1,2]', '{"version":3}', null]) {
        final notes = RemoteReleaseNotes.parse(raw);
        expect(notes.version, isNull, reason: '$raw');
        expect(notes.forLanguage('en'), isEmpty, reason: '$raw');
      }
    });

    test('at most three bullets; blanks, non-strings and over-long ones drop', () {
      final long = 'x' * (RemoteReleaseNotes.maxLength + 1);
      final notes = RemoteReleaseNotes.parse(
        '{"version":"1.0.33","en":["one","  ",7,"$long","two","three","four"]}',
      );
      expect(notes.forLanguage('en'), ['one', 'two', 'three']);
    });

    test('a bullet of exactly the limit is kept, trimmed', () {
      final edge = 'y' * RemoteReleaseNotes.maxLength;
      final notes = RemoteReleaseNotes.parse(
        '{"version":"1.0.33","en":["  $edge  "]}',
      );
      expect(notes.forLanguage('en'), [edge]);
    });
  });

  group('resolve', () {
    final remote = RemoteReleaseNotes.parse(json);

    List<String> resolve({
      String? storeVersion = '1.0.33',
      String? storeNotes = 'Bug fixes.',
      String language = 'en',
      RemoteReleaseNotes? notes,
    }) => UpdateNotes.resolve(
      remote: notes ?? remote,
      storeVersion: storeVersion,
      storeNotes: storeNotes,
      languageCode: language,
    );

    test('the reader\'s language first, when the notes match the store', () {
      expect(resolve(language: 'de'), ['Schneller loggen']);
    });

    test('then English from the same notes', () {
      expect(resolve(language: 'fr'), ['Faster logging', 'A calmer Home']);
      // An empty list for the language is the same as a missing one.
      expect(resolve(language: 'it'), ['Faster logging', 'A calmer Home']);
    });

    test('notes for another version fall back to the store\'s own notes', () {
      expect(resolve(storeVersion: '1.0.34'), ['Bug fixes.']);
      expect(resolve(storeVersion: null), ['Bug fixes.']);
    });

    test('no matching notes and no store notes: no list, never an invented one', () {
      expect(resolve(storeVersion: '1.0.34', storeNotes: null), isEmpty);
      expect(resolve(storeVersion: '1.0.34', storeNotes: '  \n '), isEmpty);
      expect(
        resolve(notes: RemoteReleaseNotes.parse('{}'), storeNotes: null),
        isEmpty,
      );
    });

    test('store notes become at most three clean lines', () {
      expect(
        resolve(
          storeVersion: '1.0.34',
          storeNotes:
              '• New widget\n- Calmer Home &amp; Stats\n\n* <b>Fixes</b>\nMore',
        ),
        ['New widget', 'Calmer Home & Stats', 'Fixes'],
      );
    });
  });
}
