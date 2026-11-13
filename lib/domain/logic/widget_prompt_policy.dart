import '../models/journey_state.dart';

/// How a person adds the home-screen widget on this device.
enum WidgetAddWay {
  /// The system's own "add this widget" dialog, one tap from the card
  /// (Android 8+ on a launcher that supports pinning).
  pinDialog,

  /// Three steps shown on the card, because no app can add a widget to an
  /// iPhone's home screen — the person does it from edit mode.
  walkthrough,
}

/// When Home offers the home-screen widget (docs/15 QP-C2).
///
/// The offer is one small convenience: logging a puff in one tap instead of
/// opening the app. It is made once, to somebody already logging by hand, and
/// the copy says that and nothing larger — the only evidence on widgets is that
/// they raised how many days a diary was filled in (22 people); nothing links
/// one to quitting, so nothing here may claim it does.
///
/// Pure, so each rule is a one-line test. What is NOT here is structural: the
/// shown-once flag is device-scoped in `SettingsStore`, and whether the device
/// can add a widget is read from `WidgetStore` — both arrive as arguments.
abstract final class WidgetPromptPolicy {
  /// Puffs logged, in total, before the offer is worth making.
  static const int minPuffs = 5;

  /// Distinct days those puffs must span. One heavy sitting is not a habit of
  /// opening the app to log.
  static const int minDays = 2;

  /// Which way this device adds a widget, or null when it has none.
  ///
  /// iOS is the walkthrough whatever the plugin says about pinning: `canPin` is
  /// false there and the walkthrough must not hang on it. On Android a launcher
  /// that cannot pin gets **no card**: one tap is the promise, and a button that
  /// does nothing is worse than no button.
  static WidgetAddWay? wayFor({
    required bool pinSupported,
    required bool isApple,
  }) {
    if (isApple) return WidgetAddWay.walkthrough;
    return pinSupported ? WidgetAddWay.pinDialog : null;
  }

  /// Whether Home shows the card right now.
  ///
  /// - A taper user only: [JourneyState.limitOn] above zero today. On a zero
  ///   line (cold turkey, the taper's tail, every day after Freedom Day) zero
  ///   puffs IS the goal and "log faster" is the wrong thing to be offered.
  /// - Not while a slip waits to be resolved: that card owns the slot.
  /// - [minPuffs] puffs over [minDays] days. **The journey does not store a
  ///   puff's source** (`puff_logged{source}` is analytics only), so the day map
  ///   is the proxy for "logged in the app" — sound only because a placed
  ///   widget is a separate rule below.
  /// - [installed] is exactly zero. Null is "could not be read" and is refused:
  ///   reading a failed call as zero would hand the card to the people who
  ///   already have the widget.
  /// - Never shown before ([alreadyShown]), and not while the Day-1 tour runs.
  /// - [way] is non-null: the device has some way to add one.
  static bool shouldShow({
    required JourneyState journey,
    required DateTime now,
    required int? installed,
    required bool alreadyShown,
    required bool tourRunning,
    required WidgetAddWay? way,
  }) {
    if (alreadyShown || tourRunning || way == null) return false;
    if (installed != 0) return false;
    if (journey.pendingSlipCleanDays != null) return false;
    if (journey.limitOn(now) <= 0) return false;

    var puffs = 0;
    var days = 0;
    for (final log in journey.days.values) {
      if (log.puffs <= 0) continue;
      puffs += log.puffs;
      days++;
    }
    return puffs >= minPuffs && days >= minDays;
  }
}
