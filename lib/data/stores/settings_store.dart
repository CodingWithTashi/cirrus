import 'dart:ui';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_persistence.dart';

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
  /// Starts at the defaults and adopts the stored values as soon as disk
  /// answers. `build()` cannot be async, and blocking the first frame on a
  /// preferences read to avoid a one-frame theme flicker is a bad trade.
  ///
  /// Restore is skipped when [restore] is false — tests want deterministic
  /// defaults, not whatever the host machine last wrote.
  SettingsStore({bool restore = true}) : _restore = restore;

  final bool _restore;

  @override
  SettingsState build() {
    if (_restore) _hydrate();
    return const SettingsState();
  }

  Future<void> _hydrate() async {
    final stored = await SettingsPersistence.load();
    // The user may have changed something while disk was answering; their
    // action wins over the older stored value.
    if (_dirty) return;
    state = stored;
  }

  bool _dirty = false;

  /// Sets state and persists write-behind, mirroring `JourneyStore._commit`:
  /// the change is already on screen, so a failed write is not worth a dialog.
  void _commit(SettingsState next) {
    _dirty = true;
    state = next;
    SettingsPersistence.save(next).ignore();
  }

  void setThemeMode(ThemeMode mode) => _commit(state.copyWith(themeMode: mode));

  void setLocale(Locale? locale) =>
      _commit(state.copyWith(locale: () => locale));

  void setNotifications(bool on) =>
      _commit(state.copyWith(notificationsOn: on));

  void setDangerWindow(int startHour, int endHour) => _commit(
    state.copyWith(dangerStartHour: startHour, dangerEndHour: endHour),
  );

  void setTrialReminder(bool on) =>
      _commit(state.copyWith(trialReminderOn: on));

  void markWinbackShown() => _commit(state.copyWith(winbackShown: true));
}
