import 'package:amplitude_flutter/amplitude.dart';
import 'package:amplitude_flutter/autocapture/autocapture.dart';
import 'package:amplitude_flutter/configuration.dart';
import 'package:amplitude_flutter/events/base_event.dart';
import 'package:amplitude_flutter/observers/amplitude_navigator_observer.dart';
import 'package:amplitude_flutter/tracking_options.dart';
import 'package:flutter/foundation.dart';

import '../../domain/analytics/analytics.dart';
import 'analytics_options.dart';

/// Amplitude — the product-analytics half of docs/05's analytics row, filling
/// the slot that spec reserved for Mixpanel.
///
/// **The only file in the app that imports `package:amplitude_flutter`.** That
/// is the whole point of the seam: replacing this vendor is deleting this file
/// and writing one more [AnalyticsSink], with no event, call site or view
/// model touched.
///
/// Autocapture carries the half of "engagement" that explicit events cannot:
/// sessions and app lifecycle are what make DAU/WAU, session length and
/// retention curves computable at all. Screen views are NOT autocaptured by
/// the native SDKs — a Flutter app is one native surface, so route changes are
/// invisible to them — so they arrive through `app/router/analytics_observer.dart`
/// and are re-emitted here under Amplitude's own native event type, which is
/// what makes them show up in its built-in screen-view charts.
final class AmplitudeAnalytics implements AnalyticsSink {
  AmplitudeAnalytics([Amplitude? amplitude])
    : _amplitude =
          amplitude ??
          Amplitude(
            Configuration(
              apiKey: AnalyticsOptions.amplitudeApiKey,
              autocapture: const AutocaptureOptions(
                sessions: true,
                appLifecycles: true,
                screenViews: true,
              ),
              // Android's location listener is on by default. Nothing in this
              // app reads a coordinate, and "we never sell your data" starts
              // with not collecting it.
              locationListening: false,
              // `TrackingOptions.adid` defaults to TRUE, so the Android SDK
              // attaches an advertising ID to every event it sends — and it
              // can, because firebase_analytics drags
              // play-services-ads-identifier onto the classpath whether we
              // want it or not. That is the "verify if any third-party SDK
              // uses advertising ID" half of Play's console question, and it
              // is the half a manifest cannot answer: the AD_ID permission is
              // removed in AndroidManifest.xml, but an SDK asking for an
              // identifier we told Play we do not use is the wrong shape even
              // when the platform hands it back zeroed. One decision, two
              // files; android_manifest_test.dart pins both ends.
              trackingOptions: TrackingOptions(adid: false),
            ),
          );

  final Amplitude _amplitude;

  /// Every call is chained onto init, and that is not optional.
  ///
  /// `Amplitude(...)` kicks off a MethodChannel `init` and returns straight
  /// away; the Android plugin answers any `track` arriving before that
  /// finishes with `IllegalArgumentException: Amplitude instance ... not
  /// found`. Since a sink may never throw at its caller, the event would be
  /// swallowed by [_guard] and lost — and the events at risk are exactly the
  /// earliest ones: the first screen view fires on the same frame that builds
  /// this object. `isBuilt` never completes with an error (the SDK catches
  /// its own init failure and resolves `false`), and `.then` callbacks on one
  /// future run in registration order, so this both waits and preserves the
  /// order events were fired in.
  void _guard(String label, Future<void> Function() send) {
    _amplitude.isBuilt
        .then((built) => built ? send() : _log(label, 'init failed'))
        .catchError((Object error) => _log(label, error));
  }

  // Analytics must never break a user flow.
  void _log(String label, Object error) =>
      debugPrint('analytics/amplitude: $label failed — $error');

  @override
  void track(AnalyticsEvent event) => _guard(
    event.name,
    () => _amplitude.track(
      BaseEvent(
        event.name,
        eventProperties: event.props.isEmpty ? null : event.props,
      ),
    ),
  );

  @override
  void screenViewed(String name) => _guard(
    'screen_view',
    () => _amplitude.track(
      BaseEvent(
        screenViewedEventType,
        eventProperties: {screenNameProperty: name},
      ),
    ),
  );

  @override
  void identify(String userId) =>
      _guard('identify', () => _amplitude.setUserId(userId));

  @override
  void reset() => _guard('reset', () => _amplitude.reset());
}
