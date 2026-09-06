import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_colors.dart';
import 'package:last_puff/app/theme/lp_palette.dart';
import 'package:last_puff/app/theme/lp_theme.dart';

/// WCAG 2.1 relative luminance. Colours are opaque in every pair checked
/// below, so no compositing against the ground is needed.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('LpPalette', () {
    // The name is the wire value: `SettingsPersistence` stores
    // `state.palette.name`, so renaming one silently resets everyone who had
    // chosen it back to the default on their next launch.
    test('the persisted names are frozen', () {
      expect(LpPalette.values.map((p) => p.name).toList(), [
        'ember',
        'hearth',
        'tide',
      ]);
    });

    test('the catalogue covers every enum value exactly once', () {
      expect(
        LpPaletteCatalog.entries.map((e) => e.id).toList(),
        LpPalette.values,
      );
    });

    test('the first entry is free, and it is the only free one', () {
      expect(
        LpPaletteCatalog.entries.first.premium,
        isFalse,
        reason: 'resolveFor falls back to entries.first — it must be wearable',
      );
      expect(LpPaletteCatalog.freeCount, 1);
      expect(LpPaletteCatalog.entries.length, 3);
    });

    test('a mode carries the brightness it claims', () {
      for (final entry in LpPaletteCatalog.entries) {
        expect(entry.dark.brightness, Brightness.dark, reason: entry.id.name);
        expect(entry.light.brightness, Brightness.light, reason: entry.id.name);
        expect(entry.dark.isDark, isTrue, reason: entry.id.name);
        expect(entry.light.isDark, isFalse, reason: entry.id.name);
      }
    });
  });

  group('resolveFor clamps', () {
    test('a free reader is clamped to the free family', () {
      for (final entry in LpPaletteCatalog.entries) {
        expect(
          LpPaletteCatalog.resolveFor(entry.id, premium: false).id,
          LpPalette.ember,
          reason: '${entry.id.name} must not render for a free account',
        );
      }
    });

    test('a paying reader gets what they chose', () {
      for (final entry in LpPaletteCatalog.entries) {
        expect(
          LpPaletteCatalog.resolveFor(entry.id, premium: true).id,
          entry.id,
        );
      }
    });

    test('a null choice is the free family, whatever the tier', () {
      expect(LpPaletteCatalog.resolveFor(null, premium: false).id, LpPalette.ember);
      expect(LpPaletteCatalog.resolveFor(null, premium: true).id, LpPalette.ember);
    });
  });

  group('token integrity', () {
    // `LpChip` (lp_selectables.dart) picks its text token by COLOUR EQUALITY:
    // `accent == lp.ember ? lp.emberText : accent == lp.oxygen ? ... : volt`.
    // Two accents sharing a value in one palette would silently route a chip
    // to the wrong text token — in that palette only, with nothing to see in
    // the diff and no compiler complaint.
    test('volt, ember and oxygen are three distinct colours', () {
      for (final entry in LpPaletteCatalog.entries) {
        for (final MapEntry(key: mode, value: lp) in {
          'dark': entry.dark,
          'light': entry.light,
        }.entries) {
          final accents = {lp.volt, lp.ember, lp.oxygen};
          expect(
            accents.length,
            3,
            reason:
                '${entry.id.name} $mode: LpChip dispatches on colour equality, '
                'so two equal accents route to the wrong text token',
          );
        }
      }
    });

    // The compiler already forces all 29 constructor arguments, but `lerp`
    // takes no such oath: a field added later and forgotten here would
    // hard-snap mid-crossfade instead of animating, silently.
    test('lerp interpolates every colour field', () {
      final source = File('lib/app/theme/lp_colors.dart').readAsStringSync();
      final fields = RegExp(r'^  final Color (\w+);', multiLine: true)
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toSet();
      final body = source.substring(source.indexOf('LpColors lerp('));
      final lerped = RegExp(r'(\w+): c\(')
          .allMatches(body)
          .map((m) => m.group(1)!)
          .toSet();

      expect(fields, isNotEmpty);
      expect(
        fields.difference(lerped),
        isEmpty,
        reason: 'every Color field must appear in lerp() or it will snap',
      );
    });
  });

  group('contrast', () {
    // Floors are set by what ALREADY SHIPS, not by an aspiration: Daylight
    // Ember's voltText is 4.47 and its emberText is 3.46, both below AA for
    // body text. So these guard against regression rather than pretending the
    // brand clears AA everywhere. The two new families are above every floor
    // here — Hearth Day clears AA on all eight pairs.
    for (final entry in LpPaletteCatalog.entries) {
      for (final MapEntry(key: mode, value: lp) in {
        'dark': entry.dark,
        'light': entry.light,
      }.entries) {
        test('${entry.id.name} $mode is readable', () {
          void atLeast(String what, Color fg, Color bg, double floor) {
            expect(
              _contrast(fg, bg),
              greaterThanOrEqualTo(floor),
              reason: '${entry.id.name} $mode: $what',
            );
          }

          // Body-critical: real prose is set in these.
          atLeast('textPrimary on background', lp.textPrimary, lp.background, 7);
          atLeast(
            'textSecondary on background',
            lp.textSecondary,
            lp.background,
            4.5,
          );
          atLeast('voltText on background', lp.voltText, lp.background, 4.4);
          atLeast('onVolt on volt', lp.onVolt, lp.volt, 4.5);

          // Accent text: short labels, badges and chips — AA Large / UI.
          atLeast('emberText on background', lp.emberText, lp.background, 3);
          atLeast('oxygenText on background', lp.oxygenText, lp.background, 3);
          atLeast('cautionText on background', lp.cautionText, lp.background, 3);
          atLeast('dangerText on background', lp.dangerText, lp.background, 3);
        });
      }
    }
  });

  group('the free family is frozen', () {
    // Ember ships today and the founder signed off on it as-is. Tuning the
    // two new families must not drift the default by a single byte.
    test('Midnight Ember keeps its hexes', () {
      const lp = LpColors.midnight();
      expect(lp.background, const Color(0xFF0A0C10));
      expect(lp.surface, const Color(0xFF161A22));
      expect(lp.border, const Color(0xFF232A36));
      expect(lp.volt, const Color(0xFFC8F542));
      expect(lp.ember, const Color(0xFFFF8A00));
      expect(lp.oxygen, const Color(0xFF6EE7FF));
      expect(lp.caution, const Color(0xFFE8C547));
      expect(lp.danger, const Color(0xFFFF5C5C));
      expect(lp.navBar, const Color(0xF210131A));
    });

    test('Daylight Ember keeps its hexes', () {
      const lp = LpColors.daylight();
      expect(lp.background, const Color(0xFFF6F8F4));
      expect(lp.surface, const Color(0xFFFFFFFF));
      expect(lp.voltText, const Color(0xFF587E00));
      expect(lp.emberText, const Color(0xFFCE6A00));
      expect(lp.oxygenText, const Color(0xFF0787B4));
      expect(lp.danger, const Color(0xFFFF5C5C));
      expect(lp.navBar, const Color(0xF7FFFFFF));
    });

    // An alert must not change meaning when the reader changes their theme.
    test('danger is the same red in every family', () {
      for (final entry in LpPaletteCatalog.entries) {
        expect(entry.dark.danger, const Color(0xFFFF5C5C), reason: entry.id.name);
        expect(entry.light.danger, const Color(0xFFFF5C5C), reason: entry.id.name);
      }
    });
  });

  group('LpTheme', () {
    test('builds the palette it was asked for', () {
      for (final entry in LpPaletteCatalog.entries) {
        expect(
          LpTheme.dark(entry.id).extension<LpColors>(),
          same(entry.dark),
          reason: '${entry.id.name} dark',
        );
        expect(
          LpTheme.light(entry.id).extension<LpColors>(),
          same(entry.light),
          reason: '${entry.id.name} light',
        );
        expect(
          LpTheme.dark(entry.id).scaffoldBackgroundColor,
          entry.dark.background,
        );
      }
    });

    // MaterialApp rebuilds on every settings change; _build is pure, so the
    // six ThemeData objects are built once.
    test('the same palette hands back the same ThemeData', () {
      expect(LpTheme.dark(LpPalette.tide), same(LpTheme.dark(LpPalette.tide)));
      expect(
        LpTheme.midnight(),
        same(LpTheme.dark(LpPalette.ember)),
        reason: 'the shorthand and the catalogue must be one canonical const',
      );
      expect(LpTheme.daylight(), same(LpTheme.light(LpPalette.ember)));
    });

    test('the status bar follows the mode, in every family', () {
      for (final entry in LpPaletteCatalog.entries) {
        expect(LpTheme.overlayStyle(entry.dark).statusBarBrightness, isNot(
          LpTheme.overlayStyle(entry.light).statusBarBrightness,
        ));
      }
    });
  });
}
