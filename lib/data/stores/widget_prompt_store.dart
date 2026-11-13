import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/analytics/lp_events.dart';
import '../../domain/logic/widget_prompt_policy.dart';
import 'providers.dart';

/// What the one-time home-screen widget card needs that the pure
/// [WidgetPromptPolicy] cannot know (docs/15 QP-C2).
class WidgetPromptState {
  const WidgetPromptState({
    this.way,
    this.installed,
    this.visible = false,
    this.requested = false,
    this.baseline = 0,
  });

  /// How this device adds a widget, or null when it has no way — and until the
  /// launcher has answered, which reads the same: no card before the answer.
  final WidgetAddWay? way;

  /// How many Cirrus widgets the last read found. Null is "could not be read",
  /// never zero.
  final int? installed;

  /// Whether the card is up this visit. The shown-once flag is written the
  /// moment it first renders, which makes the policy false from the next frame
  /// on — so the card is held up by this latch, not by the policy, exactly as
  /// the smoking rule on Home is held up by its own State.
  final bool visible;

  /// The person took the card's offer and the app is waiting to see whether a
  /// widget appears. In memory only: if the process dies in the launcher's
  /// dialog the `widget_installed` event is simply not sent.
  final bool requested;

  /// [installed] when the offer was taken: a later count above it is the widget
  /// that was asked for.
  final int baseline;

  WidgetPromptState copyWith({
    WidgetAddWay? way,
    int? installed,
    bool? visible,
    bool? requested,
    int? baseline,
  }) => WidgetPromptState(
    way: way ?? this.way,
    installed: installed ?? this.installed,
    visible: visible ?? this.visible,
    requested: requested ?? this.requested,
    baseline: baseline ?? this.baseline,
  );
}

/// The one-time widget offer: what the device can do, whether the card is up,
/// and whether a request is waiting to be confirmed.
///
/// **The system dialog has no callback**, so "was it added" is only ever learned
/// by asking the launcher again — [resume] does, and Home calls it when the app
/// comes back from the dialog.
///
/// Reset on sign-out and on account deletion (`ref.invalidate` at both call
/// sites in `JourneyStore`): left latched, the card would reach the next
/// person's Home without the policy ever being asked.
class WidgetPromptStore extends Notifier<WidgetPromptState> {
  /// Which build of this store a call belongs to. A launcher answer that lands
  /// after the store was rebuilt (sign-out invalidates it) or disposed must not
  /// write into the state that replaced it.
  ///
  /// A counter rather than a flag: `invalidate` re-runs [build] on this same
  /// instance and a plain bool would be true again by the time the stale call
  /// resumed, letting the old account's answer into the next account's state.
  /// Bumped on dispose as well as on build, so a call that was in flight when
  /// either happened sees a different number.
  int _generation = 0;

  @override
  WidgetPromptState build() {
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    // First read of the provider starts the one launcher question this needs.
    // Handed its generation: a container disposed before the microtask runs
    // must not reach `ref`, which throws once it is gone.
    Future.microtask(() => probe(generation: generation));
    return const WidgetPromptState();
  }

  /// Reads what the device can do and how many widgets are placed.
  Future<void> probe({int? generation}) async {
    final mine = generation ?? _generation;
    if (mine != _generation) return;
    final store = ref.read(widgetStoreProvider);
    final pin = await store.canPin();
    final count = await store.installedCount();
    if (mine != _generation) return;
    final apple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    state = WidgetPromptState(
      way: WidgetPromptPolicy.wayFor(pinSupported: pin, isApple: apple),
      installed: count,
      visible: state.visible,
      requested: state.requested,
      baseline: state.baseline,
    );
  }

  /// Puts the card up and marks it shown. Idempotent: Home asks on every
  /// rebuild until the flag lands.
  ///
  /// Held until settings have hydrated, like every automatic writer of them: on
  /// the defaults, "never shown" is a guess, and the write would persist the
  /// guess over what the device stored.
  void show() {
    final way = state.way;
    if (state.visible || way == null) return;
    final settings = ref.read(settingsStoreProvider);
    if (!settings.hydrated) return;
    state = state.copyWith(visible: true);
    ref.read(settingsStoreProvider.notifier).markWidgetPromptShown();
    ref.read(analyticsProvider).widgetPromptShown(way);
  }

  /// The card's button: the system dialog on Android, "got it" after the three
  /// steps on an iPhone. The card comes down either way; whether a widget then
  /// appears is for [resume] to find out.
  Future<void> accept() async {
    final way = state.way;
    // Only a card that is up can be accepted, and the first tap takes it down
    // before anything is awaited: the button is on screen until then, so a
    // double tap would otherwise ask the launcher for two dialogs and report
    // two acceptances.
    if (way == null || !state.visible) return;
    final mine = _generation;
    state = state.copyWith(visible: false);
    if (way == WidgetAddWay.pinDialog) {
      final asked = await ref.read(widgetStoreProvider).requestPin();
      // A launcher that refused opened no dialog — the card is already gone,
      // which beats a dead button — and a store rebuilt in the meantime belongs
      // to somebody else.
      if (mine != _generation || !asked) return;
    }
    ref.read(analyticsProvider).widgetPromptAccepted(way);
    state = state.copyWith(requested: true, baseline: state.installed ?? 0);
  }

  /// "Not now". Nothing is reported and nothing is waited for.
  void decline() => state = state.copyWith(visible: false);

  /// The app is back in the foreground: ask the launcher again.
  ///
  /// A widget above the count the offer was taken at is the one that was asked
  /// for, reported once. A widget that appears without an accepted offer (the
  /// launcher's own picker) is counted as present and credited to nobody — and
  /// takes a card that is still up back down.
  Future<void> resume() async {
    // Only worth a platform call while the answer can still matter: the card is
    // up, a request is waiting, or the offer has yet to be made and a stale
    // zero would put it in front of somebody who already has the widget. After
    // that it would be one launcher query per foreground for ever.
    if (state.way == null) return;
    if (!state.visible &&
        !state.requested &&
        ref.read(settingsStoreProvider).widgetPromptShown) {
      return;
    }
    final mine = _generation;
    final count = await ref.read(widgetStoreProvider).installedCount();
    if (mine != _generation || count == null) return;
    final landed = state.requested && count > state.baseline;
    if (landed) ref.read(analyticsProvider).widgetInstalled();
    state = state.copyWith(
      installed: count,
      requested: landed ? false : state.requested,
      visible: count > 0 ? false : state.visible,
    );
  }
}

final widgetPromptProvider =
    NotifierProvider<WidgetPromptStore, WidgetPromptState>(
      WidgetPromptStore.new,
    );
