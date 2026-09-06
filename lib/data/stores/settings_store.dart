import 'dart:ui';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/lp_palette.dart';
import '../api/firebase/push_service.dart';
import 'providers.dart';
import 'settings_persistence.dart';

class SettingsState {
  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.palette = LpPalette.ember,
    this.locale,
    this.notificationsOn = true,
    this.dangerStartHour = 21,
    this.dangerEndHour = 24,
    this.dangerHoursCustom = false,
    this.quietStartHour = 23,
    this.quietEndHour = 8,
    this.trialReminderOn = true,
    this.pushRepliesOn = true,
    this.pushMentionsOn = true,
    this.pushWeeklyOn = true,
    this.pushPromptShown = false,
    this.winbackShown = false,
    this.launchPaywallShownDay,
    this.launchPaywallShownCount = 0,
    this.celebratedMilestones = const {},
    this.armedMilestone,
    this.armedMilestoneAt,
    this.milestonesAdopted = false,
    this.hydrated = true,
  });

  final ThemeMode themeMode;

  /// The chosen palette family — orthogonal to [themeMode], which still picks
  /// light/dark/system within it.
  ///
  /// Device-scoped like [themeMode] rather than part of the journey: a look is
  /// a phone's, and `journeys/{uid}` is rewritten wholesale on every puff tap.
  ///
  /// Stored even when the reader is not entitled to it. `LpPaletteCatalog
  /// .resolveFor` clamps at render, so a lapsed subscriber sees the free
  /// family without this being overwritten — and gets their own back the
  /// moment they resubscribe.
  final LpPalette palette;

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

  /// The window no notification lands in — the danger-hour nudge, the trial
  /// reminder and the milestone celebration all read it. Wraps midnight when
  /// start > end; the shipped 23 → 8 is docs/03 §8. The user's own since
  /// Sep 6 2026, dragged on the rail in the danger-hours sheet.
  final int quietStartHour;
  final int quietEndHour;
  final bool trialReminderOn;

  /// Server-decided notifications, one flag per category.
  ///
  /// These are the only settings on this screen the SERVER has to know about,
  /// because the server is what sends them — so every change here rides
  /// `syncUserContext` as well as being stored locally. A push preference
  /// kept only on the device silences nothing at all.
  ///
  /// They are also account-shaped state in a device-scoped store: like
  /// `celebratedMilestones`, `SharedPreferences` has no uid in the key, so
  /// they have to be forgotten on sign-out or the next person on a shared
  /// phone inherits them and the screen lies about what the server will do.
  final bool pushRepliesOn;
  final bool pushMentionsOn;
  final bool pushWeeklyOn;

  /// Whether the contextual permission ask has been shown, once, ever.
  ///
  /// Account-shaped like the flags above, and forgotten with them: a fresh
  /// person on a shared phone deserves the ask their predecessor declined.
  final bool pushPromptShown;

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

  /// When [armedMilestone]'s notification is due. Nothing observes it firing,
  /// so this is how "handed back" is told apart from "already delivered":
  /// switching notifications off after the moment has passed must not
  /// un-settle a celebration the user has already received, or it arrives a
  /// second time the moment they are switched back on.
  final DateTime? armedMilestoneAt;

  /// Whether [celebratedMilestones] has been initialised for the account now
  /// signed in.
  ///
  /// False means "this device has never watched this account earn anything",
  /// which is true in three places and needs the same answer in all of them: a
  /// fresh install, the first launch after the build that introduced the
  /// ledger, and a new account signing in on a phone whose ledger was just
  /// reset. In each, whatever is already in `earnedBadges` was earned before
  /// this device was watching, so it is ADOPTED as celebrated rather than
  /// treated as owed — otherwise the first sync fires "Two weeks. TWO WEEKS."
  /// at somebody who did that a month ago.
  ///
  /// Needed as a flag rather than inferred from an empty ledger, because an
  /// empty ledger is also the honest state of a user about to earn their very
  /// first badge — and suppressing that one is the bug in the other direction.
  final bool milestonesAdopted;

  /// Whether this state is the one on disk (or a change made on top of it),
  /// as opposed to the defaults the store shows while disk is still answering.
  ///
  /// NOT persisted — it describes the store, not a choice. It exists so that
  /// nothing automatic acts on the defaults: `ReminderCoordinator.sync` used
  /// to run the instant a journey landed, and on a cold start where Firestore
  /// answered before SharedPreferences it adopted the milestone ledger on the
  /// default state and committed it — persisting fourteen default values over
  /// the user's stored ones, and cancelling an armed celebration against a
  /// ledger that did not know it was armed.
  final bool hydrated;

  SettingsState copyWith({
    ThemeMode? themeMode,
    LpPalette? palette,
    Locale? Function()? locale,
    bool? notificationsOn,
    int? dangerStartHour,
    int? dangerEndHour,
    bool? dangerHoursCustom,
    int? quietStartHour,
    int? quietEndHour,
    bool? trialReminderOn,
    bool? pushRepliesOn,
    bool? pushMentionsOn,
    bool? pushWeeklyOn,
    bool? pushPromptShown,
    bool? winbackShown,
    String? launchPaywallShownDay,
    int? launchPaywallShownCount,
    Set<String>? celebratedMilestones,
    String? Function()? armedMilestone,
    DateTime? Function()? armedMilestoneAt,
    bool? milestonesAdopted,
    bool? hydrated,
  }) => SettingsState(
    themeMode: themeMode ?? this.themeMode,
    palette: palette ?? this.palette,
    locale: locale != null ? locale() : this.locale,
    notificationsOn: notificationsOn ?? this.notificationsOn,
    dangerStartHour: dangerStartHour ?? this.dangerStartHour,
    dangerEndHour: dangerEndHour ?? this.dangerEndHour,
    dangerHoursCustom: dangerHoursCustom ?? this.dangerHoursCustom,
    quietStartHour: quietStartHour ?? this.quietStartHour,
    quietEndHour: quietEndHour ?? this.quietEndHour,
    trialReminderOn: trialReminderOn ?? this.trialReminderOn,
    pushRepliesOn: pushRepliesOn ?? this.pushRepliesOn,
    pushMentionsOn: pushMentionsOn ?? this.pushMentionsOn,
    pushWeeklyOn: pushWeeklyOn ?? this.pushWeeklyOn,
    pushPromptShown: pushPromptShown ?? this.pushPromptShown,
    winbackShown: winbackShown ?? this.winbackShown,
    launchPaywallShownDay: launchPaywallShownDay ?? this.launchPaywallShownDay,
    launchPaywallShownCount:
        launchPaywallShownCount ?? this.launchPaywallShownCount,
    celebratedMilestones: celebratedMilestones ?? this.celebratedMilestones,
    armedMilestone: armedMilestone != null
        ? armedMilestone()
        : this.armedMilestone,
    armedMilestoneAt: armedMilestoneAt != null
        ? armedMilestoneAt()
        : this.armedMilestoneAt,
    milestonesAdopted: milestonesAdopted ?? this.milestonesAdopted,
    hydrated: hydrated ?? this.hydrated,
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
    if (_restore) {
      _hydrate();
      // The defaults, and SAID to be the defaults: automatic writers
      // (`ReminderCoordinator`) wait for `hydrated` rather than act on them.
      return const SettingsState(hydrated: false);
    }
    return const SettingsState();
  }

  Future<void> _hydrate() async {
    final stored = await SettingsPersistence.load();
    // The user may have changed something while disk was answering; their
    // action wins over the older stored value — but disk HAS answered now,
    // and the automatic writers waiting on that must be let through.
    if (_dirty) {
      state = state.copyWith(hydrated: true);
      return;
    }
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

  /// Wears [palette]. Callers gate on entitlement themselves — a locked family
  /// must never reach here, because a stored choice the reader was never
  /// entitled to would come back the day they subscribe for something else.
  void setPalette(LpPalette palette) =>
      _commit(state.copyWith(palette: palette));

  void setLocale(Locale? locale) =>
      _commit(state.copyWith(locale: () => locale));

  /// The master switch, on both sides of the seam.
  ///
  /// Turning it off used to cancel the locally scheduled reminders and stop
  /// there — so every SERVER push kept arriving, on an app the user had just
  /// told to be quiet. Two things close that now, and they fail in opposite
  /// directions on purpose:
  ///
  /// * the token is deleted locally, which needs no network and no session
  ///   and is what actually guarantees this device hears nothing;
  /// * the preference is mirrored to `users/{uid}`, which is best effort and
  ///   is what stops us pushing again after the next sign-in mints a token.
  void setNotifications(bool on) {
    _commit(state.copyWith(notificationsOn: on));
    if (!on) PushService.deleteToken().ignore();
    _syncPushPrefs();
  }

  void setPushReplies(bool on) {
    _commit(state.copyWith(pushRepliesOn: on));
    _syncPushPrefs();
  }

  void setPushMentions(bool on) {
    _commit(state.copyWith(pushMentionsOn: on));
    _syncPushPrefs();
  }

  /// Burns the one contextual permission ask.
  ///
  /// Marked BEFORE the sheet opens, not after: a swipe-away is an answer, and
  /// a prompt that only counts itself once accepted comes back on every post
  /// until somebody says yes.
  void markPushPromptShown() =>
      _commit(state.copyWith(pushPromptShown: true));

  void setPushWeekly(bool on) {
    _commit(state.copyWith(pushWeeklyOn: on));
    _syncPushPrefs();
  }

  /// Tells the server what it may send.
  ///
  /// Write-behind and deliberately unobserved, like every other optimistic
  /// mutation in this app: the switch has already moved, and a dialog about
  /// a failed background save is the wrong response to a toggle.
  void _syncPushPrefs() {
    ref
        .read(userContextRepositoryProvider)
        .sync(
          pushPrefs: {
            'all': state.notificationsOn,
            'communityReply': state.pushRepliesOn,
            'communityMention': state.pushMentionsOn,
            'insightReady': state.pushWeeklyOn,
            'quietStart': state.quietStartHour,
            'quietEnd': state.quietEndHour,
          },
        )
        .ignore();
  }

  void setDangerWindow(int startHour, int endHour) => _commit(
    state.copyWith(
      dangerStartHour: startHour,
      dangerEndHour: endHour,
      dangerHoursCustom: true,
    ),
  );

  /// The window no notification lands in. Hours 0–23; start > end wraps
  /// midnight (23 → 8). Start == end would mean "no quiet hours" to the
  /// planner and cannot be drawn on the rail, so it is refused rather than
  /// stored — the sheet's track never produces it, and nothing else writes.
  void setQuietHours(int startHour, int endHour) {
    final start = startHour % 24;
    final end = endHour % 24;
    if (start == end) return;
    _commit(state.copyWith(quietStartHour: start, quietEndHour: end));
  }

  void setTrialReminder(bool on) =>
      _commit(state.copyWith(trialReminderOn: on));

  void markWinbackShown() => _commit(state.copyWith(winbackShown: true));

  /// Records that [armed]'s celebration is on the clock for [at] and that
  /// every badge in [covers] is settled.
  ///
  /// One write, not one per badge: a restored journey can settle four at once
  /// and each `_commit` re-triggers the sync that called this.
  void markMilestonesCelebrated(String armed, Set<String> covers, DateTime at) {
    final next = {...state.celebratedMilestones, ...covers};
    if (next.length == state.celebratedMilestones.length &&
        state.armedMilestone == armed &&
        state.armedMilestoneAt == at) {
      return;
    }
    _commit(
      state.copyWith(
        celebratedMilestones: next,
        armedMilestone: () => armed,
        armedMilestoneAt: () => at,
      ),
    );
  }

  /// Hands the armed celebration back to the planner, because the device no
  /// longer holds it — notifications were switched off, which cancels every
  /// scheduled id. Without this the badge stays "settled" for ever and the
  /// promise is silently dropped when they are switched back on.
  ///
  /// Unless it has already fired: a celebration due before [now] was
  /// delivered, and handing it back would deliver it again the moment
  /// notifications are switched on. Nothing observes the notification going
  /// off, so the due time is the only evidence there is.
  void releaseArmedMilestone(DateTime now) {
    final armed = state.armedMilestone;
    if (armed == null) return;
    final due = state.armedMilestoneAt;
    final delivered = due != null && !due.isAfter(now);
    _commit(
      state.copyWith(
        celebratedMilestones: delivered
            ? state.celebratedMilestones
            : ({...state.celebratedMilestones}..remove(armed)),
        armedMilestone: () => null,
        armedMilestoneAt: () => null,
      ),
    );
  }

  /// Adopts [earned] as already celebrated, without arming anything.
  ///
  /// Called once per account, the first time the schedule is synced with a
  /// journey in hand. See [SettingsState.milestonesAdopted] for why an empty
  /// ledger is not enough to infer this.
  void adoptMilestones(Set<String> earned) {
    if (state.milestonesAdopted) return;
    _commit(
      state.copyWith(
        celebratedMilestones: {...earned},
        armedMilestone: () => null,
        armedMilestoneAt: () => null,
        milestonesAdopted: true,
      ),
    );
  }

  /// Forgets the milestone ledger, because it belonged to the account that has
  /// just left.
  ///
  /// The ledger is device-scoped SharedPreferences with no uid in the key, so
  /// without this a shared phone hands the next person the last person's
  /// settled badges — and since a settled badge makes the planner answer null,
  /// they would never get a single celebration. Same per-account rule as
  /// `analytics.reset()`, `EntitlementStore.unbind()` and
  /// `WidgetCoordinator.discardQueued()` beside it.
  ///
  /// The push preferences go with them, for exactly the same reason. They are
  /// account-shaped too, stored under keys with no uid in them, and leaving
  /// them behind means the next person on a shared phone inherits the last
  /// one's choices — and, worse, sees a screen that disagrees with what the
  /// server will actually send them, since the server's copy is per account.
  void resetMilestoneLedger() => _commit(
    state.copyWith(
      celebratedMilestones: const {},
      armedMilestone: () => null,
      armedMilestoneAt: () => null,
      milestonesAdopted: false,
      pushRepliesOn: true,
      pushMentionsOn: true,
      pushWeeklyOn: true,
      pushPromptShown: false,
    ),
  );

  /// Records that today's launch paywall was shown, so it is not shown again
  /// before the next local day.
  void markLaunchPaywallShown(String dayKey) => _commit(
    state.copyWith(
      launchPaywallShownDay: dayKey,
      launchPaywallShownCount: state.launchPaywallShownCount + 1,
    ),
  );
}
