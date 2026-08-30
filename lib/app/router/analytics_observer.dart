import 'package:flutter/widgets.dart';

import '../../domain/analytics/analytics.dart';

/// Turns route changes into screen views.
///
/// Takes an [AnalyticsSink], not an `Amplitude` — the router stays vendor-free,
/// and Firebase Analytics gets the same screen views for its audiences.
///
/// **What arrives as [RouteSettings.name] is the path *pattern*, not the URL.**
/// go_router builds pages with `name: state.name ?? state.path`, and no route
/// in `app_router.dart` declares a `name:`, so this receives `/panic` and
/// `/community/:id` rather than `/community/abc123`. That is what keeps the
/// screen dimension low-cardinality and structurally incapable of carrying a
/// user's own text — the same rule the event vocabulary follows.
///
/// One gap it cannot close: `StatefulShellRoute.indexedStack` switches tabs
/// without pushing a route, so no observer sees it. `AppShell` reports those
/// four itself.
final class LpAnalyticsObserver extends NavigatorObserver {
  LpAnalyticsObserver(this.analytics);

  final AnalyticsSink analytics;

  // Dialogs, sheets and the panic takeover's popups are not screens.
  void _report(Route<dynamic>? route) {
    if (route is! PageRoute) return;
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;
    analytics.screenViewed(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _report(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _report(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _report(newRoute);
}
