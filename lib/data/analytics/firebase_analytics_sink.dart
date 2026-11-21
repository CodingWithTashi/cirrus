import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../../domain/analytics/analytics.dart';

/// Firebase Analytics — the free backbone docs/05 keeps alongside the product
/// analytics tool. Crashlytics audiences and Remote Config targeting read from
/// here, so it stays wired even though Amplitude answers the funnel questions.
final class FirebaseAnalyticsSink implements AnalyticsSink {
  FirebaseAnalyticsSink([FirebaseAnalytics? analytics])
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  void _guard(String label, Future<void> Function() send) {
    try {
      send().catchError((Object error) => _log(label, error));
    } on Object catch (error) {
      _log(label, error);
    }
  }

  // Analytics must never break a user flow.
  void _log(String label, Object error) =>
      debugPrint('analytics/firebase: $label failed — $error');

  @override
  void track(AnalyticsEvent event) => _guard(
    event.name,
    () => _analytics.logEvent(
      name: event.name,
      parameters: event.props.isEmpty ? null : event.props,
    ),
  );

  @override
  void screenViewed(String name) =>
      _guard('screen_view', () => _analytics.logScreenView(screenName: name));

  @override
  void identify(String userId) =>
      _guard('identify', () => _analytics.setUserId(id: userId));

  // Firebase takes one string per call; `setUserProperty` throws on a bad
  // name, which `_guard` keeps from reaching the caller.
  @override
  void setUserProperties(Map<String, Object> properties) =>
      _guard('user_properties', () async {
        for (final MapEntry(:key, :value) in properties.entries) {
          await _analytics.setUserProperty(name: key, value: '$value');
        }
      });

  @override
  void reset() => _guard('reset', () async {
    await _analytics.setUserId(id: null);
    await _analytics.resetAnalyticsData();
  });
}
