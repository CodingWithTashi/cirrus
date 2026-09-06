import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

/// The key-value store the home-screen widget and the app both reach.
///
/// On Android this is the `HomeWidgetPreferences` SharedPreferences file; on
/// iOS it is the App Group `UserDefaults`. Either way it is the ONLY channel
/// between the two processes: the widget never touches Firebase, and the app
/// never renders the widget. One side writes what the other reads.
///
/// It is an interface for one reason — everything above it must be unit
/// testable. `HomeWidget`'s methods are platform channels, and a channel that
/// is not there throws `MissingPluginException`, so a test that exercised the
/// real implementation would be testing the absence of a plugin. The drain
/// logic is the most safety-critical code in this feature and it gets tested
/// against [MemoryWidgetStore] instead.
abstract interface class WidgetStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  /// Tells the OS to re-render every placed instance of the widget.
  Future<void> refresh();

  /// Pushes the mirror to a paired Apple Watch, if there is one.
  ///
  /// Separate from [refresh] because it crosses a device boundary, not a
  /// process one: an App Group is per-device, so the watch cannot read the
  /// store this interface describes at all. The native side reads the mirror it
  /// has just been handed here and sends it over WatchConnectivity
  /// (`ios/Runner/CirrusWatchLink.swift`). No payload travels through this
  /// call — the container is the single source of truth on both sides of it.
  ///
  /// A no-op everywhere but iOS.
  Future<void> syncWatch();

  /// Arms a repaint at each of [times].
  ///
  /// This is what makes the day number turn over at midnight for a widget
  /// whose app is closed. Without it the only repaint is the 30-minute
  /// `updatePeriodMillis` floor, so a phone left alone overnight shows
  /// yesterday's day and yesterday's count until the system gets round to it.
  Future<void> scheduleRepaints(List<DateTime> times);
}

/// The real store, over `home_widget`.
class HomeWidgetStore implements WidgetStore {
  const HomeWidgetStore();

  /// Must match the App Group registered for BOTH iOS app ids. Ignored on
  /// Android, which scopes the store to the application id already.
  static const String appGroupId = 'group.com.quitvape.lastPuff';

  /// The Kotlin `AppWidgetProvider`, fully qualified, and on iOS the
  /// WidgetKit `kind` string.
  ///
  /// Both are silent when wrong: `updateWidget` addresses the provider by
  /// name, so a stale one refreshes nothing at all and the widget simply keeps
  /// showing whatever it last drew. `test/android_widget_test.dart` pins this
  /// against the receiver the manifest declares, and the iOS name against
  /// `CirrusKeys.kind`.
  static const String androidProvider =
      'com.quitvape.last_puff.widget.CirrusWidgetProvider';
  static const String iOSName = 'CirrusWidget';

  /// The one channel to `CirrusWatchLink`. Pinned against the Swift by
  /// `test/ios_watch_test.dart` — a renamed channel throws
  /// `MissingPluginException` into the catch below and the wrist silently stops
  /// updating, which is the same silence a wrong `androidProvider` buys.
  static const String watchChannel = 'cirrus/watch';
  static const String watchSyncMethod = 'sync';

  /// Declares the shared container, once per process.
  ///
  /// Ignored on Android, which scopes the store to the application id, and
  /// load-bearing on iOS: `home_widget` keeps the group id in a static, and
  /// anything written before it is set lands in `UserDefaults.standard` — the
  /// app's own container, which a widget extension cannot see. The widget then
  /// shows its empty state for ever with nothing in any log to say why. So it
  /// is awaited on every call rather than left to a caller to remember.
  static Future<void>? _group;

  static Future<void> _ensureGroup() =>
      _group ??= HomeWidget.setAppGroupId(appGroupId).catchError((_) => null);

  @override
  Future<String?> read(String key) async {
    try {
      await _ensureGroup();
      return await HomeWidget.getWidgetData<String>(key);
    } on Object {
      // A store that will not open reads as empty. Nothing here is worth
      // failing a launch over.
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _ensureGroup();
      await HomeWidget.saveWidgetData<String>(key, value);
    } on Object {
      // Write-behind, like every other optimistic save in the app.
    }
  }

  @override
  Future<void> scheduleRepaints(List<DateTime> times) async {
    try {
      await _ensureGroup();
      // Inexact by construction: `HomeWidgetScheduler` calls
      // `canScheduleExactAlarms()` and falls back to `setAndAllowWhileIdle`
      // when it is false, which it always is here — Cirrus declares neither
      // exact-alarm permission and never will (founder decision Sep 2 2026,
      // after Play rejected the build for USE_EXACT_ALARM). A repaint that
      // lands a few minutes late is a cosmetic lag; the numbers are recomputed
      // at render time and are never wrong.
      await HomeWidget.scheduleWidgetUpdates(
        times,
        qualifiedAndroidName: androidProvider,
      );
    } on Object {
      // A device that will not schedule is a widget that refreshes on its own
      // 30-minute floor instead. Not worth failing anything over.
    }
  }

  @override
  Future<void> syncWatch() async {
    if (!Platform.isIOS) return;
    try {
      await const MethodChannel(watchChannel).invokeMethod<void>(watchSyncMethod);
    } on Object {
      // No watch paired, no session yet, or an older build of the app shell.
      // The native side re-pushes on every foreground, so a missed sync heals
      // itself; there is nothing here worth surfacing to anyone.
    }
  }

  @override
  Future<void> refresh() async {
    try {
      await _ensureGroup();
      // `qualifiedAndroidName`, NOT `androidName`. The plugin resolves the
      // latter as `"$packageName.$androidName"`, so a fully-qualified value
      // there becomes
      // `com.quitvape.last_puff.com.quitvape.last_puff.widget.CirrusWidgetProvider`
      // — ClassNotFoundException, an error returned across the channel, and
      // the catch below swallowing it. The mirror still updates and the widget
      // simply never repaints: it only refreshes on its own taps and on the
      // 30-minute `updatePeriodMillis`, which reads exactly like "the widget
      // is laggy" rather than like a bug.
      await HomeWidget.updateWidget(
        qualifiedAndroidName: androidProvider,
        iOSName: iOSName,
      );
    } on Object {
      // A widget nobody has placed has nothing to refresh.
    }
  }
}

/// In-memory store for tests, desktop and the fake backend.
///
/// Also what makes the outbox tests possible: they drive the same code the
/// device runs, with the platform channel swapped out rather than stubbed.
class MemoryWidgetStore implements WidgetStore {
  final Map<String, String> values = {};
  int refreshes = 0;
  int watchSyncs = 0;
  List<DateTime> scheduled = const [];

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> refresh() async => refreshes++;

  @override
  Future<void> syncWatch() async => watchSyncs++;

  @override
  Future<void> scheduleRepaints(List<DateTime> times) async =>
      scheduled = times;
}
