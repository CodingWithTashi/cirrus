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
    this.launchPaywallShownCount = 0,
    this.celebratedMilestones = const {},
    this.armedMilestone,
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

  /// How many launch paywalls this account has ever been shown
  /// (`LaunchPaywallPolicy.lifetimeCap`). Counted, not derived from the day
  /// key: a Comeback restarts the plan and would bring the milestone days
  /// round again.
  final int launchPaywallShownCount;

  /// Badge ids whose celebration has already been SCHEDULED.
  ///
  /// Marked at scheduling time, not at firing time: nothing observes a
  /// notification going off, so an unmarked badge would re-schedule on every
  /// resume for ever. Device-scoped rather than part of the journey on
  /// purpose — the notification is a device's, and `journeys/{uid}` is
  /// rewritten wholesale on every puff tap, which is where a server-shaped
  /// field goes to die.
  final Set<String> celebratedMilestones;

  /// The badge whose celebration is currently on the device clock, if any.
  ///
  /// Tracked separately because [celebratedMilestones] means "settled", and
  /// the two part company exactly once: switching notifications off cancels
  /// every scheduled id, so the armed one has to become owed again or it is
  /// lost for good — the badge stays earned, the planner sees it as settled,
  /// and nothing ever re-arms it.
  final String? armedMilestone;

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
    int? launchPaywallShownCount,
    Set<String>? celebratedMilestones,
    String? Function()? armedMilestone,
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
    launchPaywallShownCount:
        launchPaywallShownCount ?? this.launchPaywallShownCount,
    celebratedMilestones: celebratedMilestones ?? this.celebratedMilestones,
    armedMilestone: armedMilestone != null
        ? armedMilestone()
        : this.armedMilestone,
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

  /// Records that [armed]'s celebration is on the clock and that every badge
  /// in [covers] is settled.
  ///
  /// One write, not one per badge: a restored journey can settle four at once
  /// and each `_commit` re-triggers the sync that called this.
  void markMilestonesCelebrated(String armed, Set<String> covers) {
    final next = {...state.celebratedMilestones, ...covers};
    if (next.length == state.celebratedMilestones.length &&
        state.armedMilestone == armed) {
      return;
    }
    _commit(
      state.copyWith(
        celebratedMilestones: next,
        armedMilestone: () => armed,
      ),
    );
  }

  /// Hands the armed celebration back to the planner, because the device no
  /// longer holds it — notifications were switched off, which cancels every
  /// scheduled id. Without this the badge stays "settled" for ever and the
  /// promise is silently dropped when they are switched back on.
  void releaseArmedMilestone() {
    final armed = state.armedMilestone;
    if (armed == null) return;
    _commit(
      state.copyWith(
        celebratedMilestones: {...state.celebratedMilestones}..remove(armed),
        armedMilestone: () => null,
      ),
    );
  }

  /// Records that today's launch paywall was shown, so it is not shown again
  /// before the next local day.
  void markLaunchPaywallShown(String dayKey) => _commit(
    state.copyWith(
      launchPaywallShownDay: dayKey,
      launchPaywallShownCount: state.launchPaywallShownCount + 1,
    ),
  );
}
