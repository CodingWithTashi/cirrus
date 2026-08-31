import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/coach_name.dart';

void main() {
  group('CoachName.validate', () {
    test('accepts the names people will actually pick', () {
      for (final name in [
        'Ember', 'Pip', 'Fin', 'Koda', 'Wren',
        'Élodie', "O'Brien", 'Mary-Jane', 'Sam 2',
        'Ünal', 'Zoë', 'Ana Maria', 'さくら', 'Мира',
      ]) {
        expect(CoachName.validate(name), isNull, reason: name);
      }
    });

    test('refuses an empty or whitespace-only answer', () {
      for (final name in ['', '   ', '\t\n']) {
        expect(CoachName.validate(name), CoachNameError.empty, reason: name);
      }
    });

    test('counts length the way a person does, not the way UTF-16 does', () {
      expect(CoachName.validate('W' * 20), isNull);
      expect(CoachName.validate('W' * 21), CoachNameError.tooLong);
      // Accented characters must not cost double.
      expect(CoachName.validate('é' * 20), isNull);
    });

    test('refuses emoji, which the chat header cannot lay out', () {
      expect(CoachName.validate('🔥'), CoachNameError.badCharacters);
      expect(CoachName.validate('Ember 🔥'), CoachNameError.badCharacters);
    });

    test('refuses invisible characters', () {
      // A right-to-left override can make a stored name render as something
      // else entirely in a support ticket.
      expect(
        CoachName.validate('Wren${String.fromCharCode(0x202E)}'),
        CoachNameError.badCharacters,
      );
      expect(
        CoachName.validate('Wr${String.fromCharCode(0x200D)}en'),
        CoachNameError.badCharacters,
      );
    });

    test('refuses something with no letter or digit in it', () {
      for (final name in ['---', "'''", '- -']) {
        expect(
          CoachName.validate(name),
          CoachNameError.badCharacters,
          reason: name,
        );
      }
    });

    test('normalize trims and collapses so one name has one spelling', () {
      expect(CoachName.normalize('  Wren  '), 'Wren');
      expect(CoachName.normalize('Ana   Maria'), 'Ana Maria');
    });

    test('normalize capitalizes the first letter, and only the first', () {
      // The name heads the chat screen and signs every message; "john" up
      // there reads as a bug. The REST stays as typed — "AJ" and "McCoy" are
      // spellings, not mistakes.
      expect(CoachName.normalize('john'), 'John');
      expect(CoachName.normalize('  john smith '), 'John smith');
      expect(CoachName.normalize('élodie'), 'Élodie');
      expect(CoachName.normalize('AJ'), 'AJ');
      expect(CoachName.normalize('mcCoy'), 'McCoy');
      // Scripts with no case pass through untouched.
      expect(CoachName.normalize('さくら'), 'さくら');
      expect(CoachName.normalize('мира'), 'Мира');
    });
  });
}
