import 'package:flutter/foundation.dart';

import '../../domain/analytics/analytics.dart';

/// Analytics is off: the fake backend, debug builds, tests, and any build
/// without an API key. Matches `NoopUserContextRepository` and friends — the
/// seam always resolves to something, so no caller ever null-checks.
final class NoopAnalytics implements AnalyticsSink {
  const NoopAnalytics();

  @override
  void track(AnalyticsEvent event) {}

  @override
  void screenViewed(String name) {}

  @override
  void identify(String userId) {}

  @override
  void reset() {}
}

/// One event, every vendor.
///
/// This is the whole "swap the vendor later" story: a new provider is a new
/// class implementing [AnalyticsSink] and one more entry in this list — no
/// event name, no call site and no view model changes.
///
/// Each forward is guarded separately. A vendor that throws must not swallow
/// the other vendors' copy of the same event, and none of them may reach the
/// caller: this is a tap handler's worth of latency budget, not a code path
/// anyone is allowed to fail in.
final class FanOutAnalytics implements AnalyticsSink {
  const FanOutAnalytics(this.sinks);

  final List<AnalyticsSink> sinks;

  void _each(String label, void Function(AnalyticsSink) send) {
    for (final sink in sinks) {
      try {
        send(sink);
      } on Object catch (error) {
        debugPrint('analytics: $label failed on ${sink.runtimeType} — $error');
      }
    }
  }

  @override
  void track(AnalyticsEvent event) => _each(event.name, (s) => s.track(event));

  @override
  void screenViewed(String name) =>
      _each('screen_viewed', (s) => s.screenViewed(name));

  @override
  void identify(String userId) => _each('identify', (s) => s.identify(userId));

  @override
  void reset() => _each('reset', (s) => s.reset());
}
