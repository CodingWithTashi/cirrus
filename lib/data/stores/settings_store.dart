import 'dart:ui';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsState {
  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.locale,
    this.notificationsOn = true,
    this.dangerStartHour = 21,
    this.dangerEndHour = 24,
    this.quietStartHour = 23,
    this.quietEndHour = 8,
    this.trialReminderOn = true,
    this.winbackShown = false,
  });

  final ThemeMode themeMode;

  /// null = follow system.
  final Locale? locale;
  final bool notificationsOn;
  final int dangerStartHour;
  final int dangerEndHour;
  final int quietStartHour;
  final int quietEndHour;
  final bool trialReminderOn;

  /// The founding offer fires once, then never again (Run 1 frame 22).
  final bool winbackShown;

  SettingsState copyWith({
    ThemeMode? themeMode,
    Locale? Function()? locale,
    bool? notificationsOn,
    int? dangerStartHour,
    int? dangerEndHour,
    bool? trialReminderOn,
    bool? winbackShown,
  }) => SettingsState(
    themeMode: themeMode ?? this.themeMode,
    locale: locale != null ? locale() : this.locale,
    notificationsOn: notificationsOn ?? this.notificationsOn,
    dangerStartHour: dangerStartHour ?? this.dangerStartHour,
    dangerEndHour: dangerEndHour ?? this.dangerEndHour,
    quietStartHour: quietStartHour,
    quietEndHour: quietEndHour,
    trialReminderOn: trialReminderOn ?? this.trialReminderOn,
    winbackShown: winbackShown ?? this.winbackShown,
  );
}

class SettingsStore extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  void setThemeMode(ThemeMode mode) => state = state.copyWith(themeMode: mode);

  void setLocale(Locale? locale) =>
      state = state.copyWith(locale: () => locale);

  void setNotifications(bool on) => state = state.copyWith(notificationsOn: on);

  void setDangerWindow(int startHour, int endHour) => state = state.copyWith(
    dangerStartHour: startHour,
    dangerEndHour: endHour,
  );

  void setTrialReminder(bool on) => state = state.copyWith(trialReminderOn: on);

  void markWinbackShown() => state = state.copyWith(winbackShown: true);
}
