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
    this.dangerHoursCustom = false,
    this.quietStartHour = 23,
    this.quietEndHour = 8,
    this.trialReminderOn = true,
    this.winbackShown = false,
    this.launchPaywallShownDay,
  });

  final ThemeMode themeMode;

  /// null = follow system.
  final Locale? locale;
  final bool notificationsOn;
  final int dangerStartHour;
  final int dangerEndHour;

  /// Whether [dangerStartHour] is the user's own choice rather than the
  /// shipped default. Needed because the default is a real hour: without this
  /// flag there is no way to tell "9pm, because they said so" from "9pm,
  /// because nobody has said anything", and the detected hours would never win.
  final bool dangerHoursCustom;
  final int quietStartHour;
  final int quietEndHour;
  final bool trialReminderOn;

  /// The founding offer fires once, then never again (Run 1 frame 22).
  final bool winbackShown;

  /// Local day key (`yyyy-MM-dd`) of the last launch on which a free user was
  /// shown the paywall. Docs/02 §5 allows one upgrade prompt a day and never
  /// an interstitial beyond that; this is how "one a day" is counted.
  final String? launchPaywallShownDay;

  SettingsState copyWith({
    ThemeMode? themeMode,
    Locale? Function()? locale,
    bool? notificationsOn,
    int? dangerStartHour,
    int? dangerEndHour,
    bool? dangerHoursCustom,
    bool? trialReminderOn,
    bool? winbackShown,
    String? launchPaywallShownDay,
  }) => SettingsState(
    themeMode: themeMode ?? this.themeMode,
    locale: locale != null ? locale() : this.locale,
    notificationsOn: notificationsOn ?? this.notificationsOn,
    dangerStartHour: dangerStartHour ?? this.dangerStartHour,
    dangerEndHour: dangerEndHour ?? this.dangerEndHour,
    dangerHoursCustom: dangerHoursCustom ?? this.dangerHoursCustom,
    quietStartHour: quietStartHour,
    quietEndHour: quietEndHour,
    trialReminderOn: trialReminderOn ?? this.trialReminderOn,
    winbackShown: winbackShown ?? this.winbackShown,
    launchPaywallShownDay: launchPaywallShownDay ?? this.launchPaywallShownDay,
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
    state.copyWith(
      dangerStartHour: startHour,
      dangerEndHour: endHour,
      dangerHoursCustom: true,
    ),
  );

  void setTrialReminder(bool on) =>
      _commit(state.copyWith(trialReminderOn: on));

  void markWinbackShown() => _commit(state.copyWith(winbackShown: true));

  /// Records that today's launch paywall was shown, so it is not shown again
  /// before the next local day.
  void markLaunchPaywallShown(String dayKey) =>
      _commit(state.copyWith(launchPaywallShownDay: dayKey));
}
