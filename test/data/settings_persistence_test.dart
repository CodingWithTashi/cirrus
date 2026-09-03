import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/settings_persistence.dart';
import 'package:last_puff/data/stores/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings used to live in memory only, so every restart silently reset the
/// user's theme, language, notification choice and danger hours — and re-armed
/// the win-back offer that is supposed to fire exactly once.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a fresh install loads the documented defaults', () async {
    const defaults = SettingsState();
    final loaded = await SettingsPersistence.load();

    expect(loaded.themeMode, defaults.themeMode);
    expect(loaded.locale, isNull);
    expect(loaded.notificationsOn, defaults.notificationsOn);
    expect(loaded.dangerStartHour, defaults.dangerStartHour);
    expect(loaded.winbackShown, isFalse);
  });

  test('every field survives a save and reload', () async {
    const saved = SettingsState(
      themeMode: ThemeMode.dark,
      locale: Locale('fr'),
      notificationsOn: false,
      dangerStartHour: 19,
      dangerEndHour: 23,
      trialReminderOn: false,
      winbackShown: true,
      launchPaywallShownDay: '2026-09-02',
      launchPaywallShownCount: 3,
    );

    await SettingsPersistence.save(saved);
    final loaded = await SettingsPersistence.load();
    expect(loaded.launchPaywallShownDay, '2026-09-02');

    expect(loaded.themeMode, ThemeMode.dark);
    expect(loaded.locale?.languageCode, 'fr');
    expect(loaded.notificationsOn, isFalse);
    expect(loaded.dangerStartHour, 19);
    expect(loaded.dangerEndHour, 23);
    expect(loaded.trialReminderOn, isFalse);
    expect(loaded.winbackShown, isTrue);
    // A lifetime counter that resets on every launch would hand out an
    // unlimited number of "four times, ever" paywalls.
    expect(loaded.launchPaywallShownCount, 3);
  });

  // B8, restated: this store persists the WHOLE state object precisely so a
  // field cannot be saved on write and forgotten on read. Adding one to
  // `SettingsState` without adding it here would leave that hole open again.
  test('every settable field is in the round trip above', () {
    final source = File(
      'lib/data/stores/settings_store.dart',
    ).readAsStringSync();
    // The state class only — `SettingsStore` below it has private fields of
    // its own that are not state at all.
    final body = source.substring(
      source.indexOf('class SettingsState {'),
      source.indexOf('class SettingsStore'),
    );
    final declared = RegExp(r'^  final [\w<>?, ]+ (\w+);', multiLine: true)
        .allMatches(body)
        .map((m) => m.group(1)!)
        .toSet();

    // Fixed by docs/03 §8 and settable by nobody: they have defaults, no
    // `copyWith` parameter, and no setter, so there is no user choice to
    // persist. Asserted rather than assumed — the moment one becomes
    // settable it must also become persisted.
    const fixed = {'quietStartHour', 'quietEndHour'};
    for (final name in fixed) {
      expect(
        body.contains('    int? $name,'),
        isFalse,
        reason: '$name is settable now, so it must be persisted too',
      );
    }

    expect(declared.difference(fixed), {
      'themeMode',
      'locale',
      'notificationsOn',
      'dangerStartHour',
      'dangerEndHour',
      'dangerHoursCustom',
      'trialReminderOn',
      'winbackShown',
      'launchPaywallShownDay',
      'launchPaywallShownCount',
    }, reason: 'a new SettingsState field must be added to the save/reload '
        'round trip above, and to this list');
  });

  // "Follow the system language" has to be storable as a real choice, not
  // just as the absence of one — otherwise switching back to system after
  // picking French would be indistinguishable from never having chosen.
  test('clearing the locale round-trips as follow-the-system', () async {
    await SettingsPersistence.save(const SettingsState(locale: Locale('de')));
    expect((await SettingsPersistence.load()).locale?.languageCode, 'de');

    await SettingsPersistence.save(const SettingsState());
    expect((await SettingsPersistence.load()).locale, isNull);
  });

  // The founding offer fires once and never again (Run 1 frame 22). An
  // in-memory flag meant a restart handed it out repeatedly.
  test('the one-time win-back flag stays burned across a reload', () async {
    await SettingsPersistence.save(const SettingsState(winbackShown: true));
    expect((await SettingsPersistence.load()).winbackShown, isTrue);
  });

  test('a corrupt stored theme falls back rather than throwing', () async {
    SharedPreferences.setMockInitialValues({
      'settings.themeMode': 'ultraviolet',
    });

    expect((await SettingsPersistence.load()).themeMode, ThemeMode.system);
  });
}
