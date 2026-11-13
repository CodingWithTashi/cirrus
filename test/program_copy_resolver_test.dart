import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/core/utils/program_copy.dart';
import 'package:last_puff/domain/logic/quit_program.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

/// The program's ids resolve to their own words. A 43-way switch is exactly
/// where `d3 => d4` hides, and nothing else would notice: both strings exist,
/// both read fine, and a person on day three is told day four's line.
void main() {
  const locales = ['en', 'de', 'es', 'fr', 'it', 'pt'];
  String cap(String s) => s[0].toUpperCase() + s.substring(1);

  for (final code in locales) {
    group(code, () {
      late AppLocalizations l10n;
      late Map<String, dynamic> arb;
      setUpAll(() async {
        l10n = await AppLocalizations.delegate.load(Locale(code));
        arb = jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
            as Map<String, dynamic>;
      });

      test('every message', () {
        for (final m in ProgramMessage.values) {
          expect(
            m.text(l10n),
            arb['programMsg${cap(m.name)}'],
            reason: m.name,
          );
        }
      });

      test('every reply, with the reason filled in only where it is asked for', () {
        const why = 'being there for my daughter';
        for (final r in ProgramReply.values) {
          final raw = arb['programReply${cap(r.name)}'] as String;
          expect(
            r.text(l10n, why: why),
            raw.replaceAll('{why}', why),
            reason: r.name,
          );
          if (!r.needsWhy) {
            expect(r.text(l10n), raw, reason: '${r.name} takes no reason');
          }
        }
      });

      test('every tip', () {
        for (final t in ProgramTip.values) {
          expect(t.text(l10n), arb['programTip${cap(t.name)}'], reason: t.name);
        }
      });
    });
  }
}
