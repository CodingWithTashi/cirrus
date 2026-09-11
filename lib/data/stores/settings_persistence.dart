import 'dart:ui';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/lp_palette.dart';
import 'settings_store.dart';

/// Disk for [SettingsState].
///
/// Every one of these values was previously in-memory only, so a restart
/// silently reset the user's theme, language, notification choice and danger
/// hours — and re-armed the one-time win-back offer that is supposed to fire
/// exactly once.
///
/// Deliberately NOT a general key-value store: it reads and writes the one
/// state object, so a field can never be persisted on write and forgotten on
/// read. Unknown or corrupt values fall back to the default rather than
/// throwing — settings are a convenience, and none of them is worth failing a
/// launch over.
abstract final class SettingsPersistence {
  static const _themeMode = 'settings.themeMode';
  static const _palette = 'settings.palette';
  static const _locale = 'settings.locale';
  static const _notificationsOn = 'settings.notificationsOn';
  static const _dangerStart = 'settings.dangerStartHour';
  static const _dangerEnd = 'settings.dangerEndHour';
  static const _dangerCustom = 'settings.dangerHoursCustom';
  static const _quietStart = 'settings.quietStartHour';
  static const _quietEnd = 'settings.quietEndHour';
  static const _trialReminderOn = 'settings.trialReminderOn';
  static const _pushReplies = 'settings.pushRepliesOn';
  static const _pushMentions = 'settings.pushMentionsOn';
  static const _pushWeekly = 'settings.pushWeeklyOn';
  static const _pushPrompt = 'settings.pushPromptShown';
  static const _winbackShown = 'settings.winbackShown';
  static const _launchPaywallDay = 'settings.launchPaywallShownDay';
  static const _launchPaywallCount = 'settings.launchPaywallShownCount';
  static const _celebrated = 'settings.celebratedMilestones';
  static const _armedMilestone = 'settings.armedMilestone';
  static const _armedMilestoneAt = 'settings.armedMilestoneAt';
  static const _milestonesAdopted = 'settings.milestonesAdopted';
  static const _reviewAskedAt = 'settings.reviewAskedAt';
  static const _reviewAskedCount = 'settings.reviewAskedCount';

  /// Sentinel for "follow the system language". An absent key means the same
  /// thing, so a fresh install and an explicit reset behave identically.
  static const _systemLocale = '';

  static Future<SettingsState> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const defaults = SettingsState();
      final tag = prefs.getString(_locale);
      return SettingsState(
        themeMode: _themeFromName(prefs.getString(_themeMode)),
        palette: _paletteFromName(prefs.getString(_palette)),
        locale: tag == null || tag == _systemLocale ? null : Locale(tag),
        notificationsOn:
            prefs.getBool(_notificationsOn) ?? defaults.notificationsOn,
        dangerStartHour: prefs.getInt(_dangerStart) ?? defaults.dangerStartHour,
        dangerEndHour: prefs.getInt(_dangerEnd) ?? defaults.dangerEndHour,
        dangerHoursCustom:
            prefs.getBool(_dangerCustom) ?? defaults.dangerHoursCustom,
        quietStartHour: prefs.getInt(_quietStart) ?? defaults.quietStartHour,
        quietEndHour: prefs.getInt(_quietEnd) ?? defaults.quietEndHour,
        pushRepliesOn: prefs.getBool(_pushReplies) ?? defaults.pushRepliesOn,
        pushMentionsOn: prefs.getBool(_pushMentions) ?? defaults.pushMentionsOn,
        pushWeeklyOn: prefs.getBool(_pushWeekly) ?? defaults.pushWeeklyOn,
        pushPromptShown: prefs.getBool(_pushPrompt) ?? defaults.pushPromptShown,
        trialReminderOn:
            prefs.getBool(_trialReminderOn) ?? defaults.trialReminderOn,
        winbackShown: prefs.getBool(_winbackShown) ?? defaults.winbackShown,
        launchPaywallShownDay: prefs.getString(_launchPaywallDay),
        launchPaywallShownCount:
            prefs.getInt(_launchPaywallCount) ??
            defaults.launchPaywallShownCount,
        celebratedMilestones:
            prefs.getStringList(_celebrated)?.toSet() ??
            defaults.celebratedMilestones,
        armedMilestone: prefs.getString(_armedMilestone),
        armedMilestoneAt: DateTime.tryParse(
          prefs.getString(_armedMilestoneAt) ?? '',
        ),
        milestonesAdopted:
            prefs.getBool(_milestonesAdopted) ?? defaults.milestonesAdopted,
        reviewAskedAt: DateTime.tryParse(prefs.getString(_reviewAskedAt) ?? ''),
        reviewAskedCount:
            prefs.getInt(_reviewAskedCount) ?? defaults.reviewAskedCount,
      );
    } on Object {
      // A broken preferences store must not stop the app booting.
      return const SettingsState();
    }
  }

  static Future<void> save(SettingsState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeMode, state.themeMode.name);
      await prefs.setString(_palette, state.palette.name);
      await prefs.setString(
        _locale,
        state.locale?.languageCode ?? _systemLocale,
      );
      await prefs.setBool(_notificationsOn, state.notificationsOn);
      await prefs.setInt(_dangerStart, state.dangerStartHour);
      await prefs.setInt(_dangerEnd, state.dangerEndHour);
      await prefs.setBool(_dangerCustom, state.dangerHoursCustom);
      await prefs.setInt(_quietStart, state.quietStartHour);
      await prefs.setInt(_quietEnd, state.quietEndHour);
      await prefs.setBool(_pushReplies, state.pushRepliesOn);
      await prefs.setBool(_pushMentions, state.pushMentionsOn);
      await prefs.setBool(_pushWeekly, state.pushWeeklyOn);
      await prefs.setBool(_pushPrompt, state.pushPromptShown);
      await prefs.setBool(_trialReminderOn, state.trialReminderOn);
      await prefs.setBool(_winbackShown, state.winbackShown);
      await prefs.setBool(_milestonesAdopted, state.milestonesAdopted);
      await prefs.setInt(_launchPaywallCount, state.launchPaywallShownCount);
      await prefs.setStringList(
        _celebrated,
        state.celebratedMilestones.toList(),
      );
      final armed = state.armedMilestone;
      if (armed == null) {
        await prefs.remove(_armedMilestone);
      } else {
        await prefs.setString(_armedMilestone, armed);
      }
      final armedAt = state.armedMilestoneAt;
      if (armedAt == null) {
        await prefs.remove(_armedMilestoneAt);
      } else {
        await prefs.setString(_armedMilestoneAt, armedAt.toIso8601String());
      }
      final day = state.launchPaywallShownDay;
      if (day == null) {
        await prefs.remove(_launchPaywallDay);
      } else {
        await prefs.setString(_launchPaywallDay, day);
      }
      await prefs.setInt(_reviewAskedCount, state.reviewAskedCount);
      final askedAt = state.reviewAskedAt;
      if (askedAt == null) {
        await prefs.remove(_reviewAskedAt);
      } else {
        await prefs.setString(_reviewAskedAt, askedAt.toIso8601String());
      }
    } on Object {
      // Write-behind, like every other optimistic save in the app: the user
      // already saw the change take effect.
    }
  }

  static ThemeMode _themeFromName(String? name) => switch (name) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  /// A palette written by a NEWER build (or a corrupt value) falls back to the
  /// free family rather than throwing — same contract as [_themeFromName].
  /// Deliberately not `LpPalette.values.byName`, which throws on an unknown.
  static LpPalette _paletteFromName(String? name) {
    for (final p in LpPalette.values) {
      if (p.name == name) return p;
    }
    return LpPalette.ember;
  }
}
