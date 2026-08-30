/// The analytics port (DIP seam), the write-only sibling of
/// `domain/repositories/repositories.dart`.
///
/// It is called a *sink* rather than a repository because nothing is ever read
/// back: events go out, and no caller waits for or inspects an answer.
///
/// The split this file exists to create: **what the product measures** lives in
/// `lp_events.dart` as one vocabulary, and **who it is sent to** lives in
/// `data/analytics/` as one class per vendor. Before the split the two were the
/// same class, so adding a second vendor meant editing all sixteen events.
library;

/// One event, named exactly as docs/02 §7 names it.
///
/// snake_case because Firebase Analytics will not accept anything else, and
/// because both vendors' dashboards then read the same word for the same thing.
final class AnalyticsEvent {
  const AnalyticsEvent(this.name, [this.props = const {}]);

  final String name;

  /// Enum names and numbers only — never free text, an alias, or a message
  /// body. See the privacy note on the `LpEvents` extension.
  final Map<String, Object> props;

  @override
  String toString() => props.isEmpty ? name : '$name $props';
}

/// Somewhere events go. One implementation per vendor, plus the two
/// vendor-free ones in `data/analytics/analytics_sinks.dart`.
///
/// Every method returns `void`, not `Future<void>`. Analytics is
/// fire-and-forget by definition, and a void return makes it structurally
/// impossible to stall a tap handler on a network sink — the same reasoning
/// that makes `LpHaptics.light()` void. Implementations swallow their own
/// failures: analytics must never break a user flow.
abstract interface class AnalyticsSink {
  void track(AnalyticsEvent event);

  /// A screen was shown. Separate from [track] because both vendors model
  /// screen views natively and their built-in charts only see the native
  /// shape. [name] is a route path pattern, never a filled URL.
  void screenViewed(String name);

  /// Binds subsequent events to a known account. Called from the one place a
  /// session is established, never from a view.
  void identify(String userId);

  /// Unbinds the identity on sign-out and deletion. Without it, the next
  /// person to use the phone inherits the last one's user id.
  void reset();
}
