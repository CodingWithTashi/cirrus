import 'package:in_app_review/in_app_review.dart';

/// The native store review sheet, wrapped the way [LpHaptics] wraps haptics:
/// one place, never throws, and honest about what it cannot know.
///
/// ## Two things about this API that shape every caller
///
/// **Neither platform reports whether the sheet appeared, or what the user
/// did with it.** Play's In-App Review has an undocumented per-user quota and
/// simply shows nothing when it is spent; iOS caps at three prompts a year.
/// So nothing downstream may render a "Thanks for rating!" or log a
/// `rating_completed` — a control that only shows a success snack is worse
/// than a missing one, and here we would not even know if we were lying.
///
/// **Review gating is prohibited.** Apple Guideline 1.1.7 forbids asking for a
/// rating ahead of the system prompt or routing by sentiment, and Google Play
/// forbids asking the user's opinion at all before presenting the rating card
/// — including a star picker that routes every value identically. So there is
/// no way to pass a rating into this, and there must not be.
abstract final class LpReview {
  /// Whether the platform will actually show something.
  ///
  /// False on desktop, in `flutter test`, and on a sideloaded Android build
  /// (which is every `./tool/device.ps1` install), so the CTA can be hidden
  /// rather than shipped as a button that does nothing.
  static Future<bool> isAvailable() async {
    try {
      return await InAppReview.instance.isAvailable();
    } on Object {
      // A missing plugin is not worth failing a funnel step over.
      return false;
    }
  }

  /// Asks the OS to show its sheet. Silence is a normal outcome.
  static Future<void> request() async {
    try {
      await InAppReview.instance.requestReview();
    } on Object {
      // Nothing to tell the user: we could not have confirmed success either.
    }
  }
}
