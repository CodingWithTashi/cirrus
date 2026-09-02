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
