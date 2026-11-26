import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Where the A2UI packages are allowed to live, and at which versions.
///
/// `a2ui_flutter` draws Ember's coach cards. It is pre-1.0 (every minor
/// release from 0.1 to 0.5 was breaking) and it is built on
/// `package:flutter/material.dart`, which is a separate set of classes from
/// the `material_ui` the app is on (see `material_ui_test.dart`). So it is
/// kept behind one seam: one folder may import it, and a version moves only
/// when somebody changes the pin on purpose.
///
/// This test reads the sources, like `review_ask_placement_test.dart`: an
/// import from anywhere else, or a caret in `pubspec.yaml`, fails here.
void main() {
  const surface = 'lib/features/coach/surface/';

  /// The exact versions. `json_schema_builder` is named although `a2ui_core`
  /// already brings it in: a catalog component declares its schema with that
  /// package's `Schema` type, so a catalog of our own imports it directly.
  const pins = {
    'a2ui_flutter': '0.5.0',
    'a2ui_core': '0.9.0',
    'json_schema_builder': '0.1.7',
  };

  test('a2ui stays in one folder', () {
    final offenders = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      if (!source.contains('package:a2ui_') &&
          !source.contains('package:json_schema_builder')) {
        continue;
      }
      final path = file.path.replaceAll(r'\', '/');
      if (!path.startsWith(surface)) offenders.add(path);
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'only $surface may import a2ui_flutter, a2ui_core or '
          'json_schema_builder. Everything else talks to the coach surface '
          'through its own widgets, so a breaking release of the package is '
          'a change to one folder.',
    );
  });

  test("the package's basic catalog is never referenced", () {
    // The size the dependency was accepted at (about +1.3 MB on the APK)
    // holds only while the app draws from a catalog of its OWN widgets. The
    // package's built-in catalog is written against
    // `package:flutter/material.dart`, so one reference to it links a second
    // copy of Material in beside `material_ui`: a probe measured +3.2 MB
    // (docs/superpowers/evidence/2026-11-25-coach-cards/README.md). Nothing
    // about that shows up as a compile error or a failing widget test, so it
    // is read off the sources here, comments included: the names simply do
    // not appear under lib/.
    const banned = [
      'basicCatalog', // a2ui_flutter's catalog function
      'BasicComponents', // its built-in component implementations
      'basic_catalog', // either package's library of that name
      'BasicCatalog', // a2ui_core's schemas and functions for the same thing
    ];
    final offenders = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final name in banned) {
        if (source.contains(name)) {
          offenders.add('${file.path.replaceAll(r'\', '/')}: $name');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          "the coach surface draws only from its own catalog. Naming the "
          "package's basic catalog or one of its built-in components links "
          'a second copy of Material into the app. If a surface cannot be '
          'built without it, that is a size decision for the founder, not '
          'a line to delete here.',
    );
  });

  test('the a2ui packages are pinned exactly', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    // Runtime dependencies only: Flutter's Gradle plugin strips a
    // dev-dependency plugin from release builds, and a2ui_flutter brings a
    // native one (video_player).
    final start = pubspec.indexOf('\ndependencies:\n');
    final end = pubspec.indexOf('\ndev_dependencies:\n');
    expect(start, isNot(-1), reason: 'pubspec.yaml has no dependencies block');
    expect(end, greaterThan(start));
    final dependencies = pubspec.substring(start, end);

    for (final pin in pins.entries) {
      final line = RegExp(
        '^  ${pin.key}: ${RegExp.escape(pin.value)}[ \\t]*\$',
        multiLine: true,
      );
      expect(
        line.hasMatch(dependencies),
        isTrue,
        reason:
            '${pin.key} must be pinned to exactly ${pin.value} under '
            'dependencies, with no caret and no range. Every a2ui_flutter '
            'minor from 0.1 to 0.5 was breaking.',
      );
    }
  });
}
