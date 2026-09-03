import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/core/utils/lp_links.dart';

/// The Android manifest is a shippability gate, so it gets a test.
///
/// Google Play rejected the Sep 2026 submission with: "Your app uses the
/// USE_EXACT_ALARM permission. If your app's core functionality is not
/// 'calendar' or 'alarm clock', you're not eligible to use this permission and
/// must remove it from your app, across all tracks."
///
/// It was never needed. Both reminder paths schedule with
/// `AndroidScheduleMode.inexactAllowWhileIdle`, which the plugin routes to
/// `AlarmManagerCompat.setAndAllowWhileIdle` — no exact-alarm permission is
/// consulted on that branch. The two `uses-permission` lines were pure
/// declaration: they bought nothing at runtime and cost the release.
///
/// The same console asks a second question, about a permission that arrives
/// the other way round: `com.google.android.gms.permission.AD_ID` is in the
/// merged manifest because `firebase_analytics` merges it in, not because
/// this app asked for one. It is removed rather than declared, in the
/// manifest AND in the Amplitude SDK that would otherwise send it.
///
/// The other half is the mirror image — a manifest entry that IS load-bearing
/// and was missing. Since v16 the plugin declares only `POST_NOTIFICATIONS`
/// and `VIBRATE` in its own manifest, so the two receivers `AlarmManager`
/// delivers to belong to the host app. Without them every `zonedSchedule()`
/// armed an alarm that fired into an undeclared component: no notification,
/// no error, planner and coordinator both correct. Exactly the shape of the
/// `periodicallyShow` bug this feature already survived once.
void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  /// The `uses-permission` entries only. Matching on the raw string would
  /// let the comment that explains WHY the exact-alarm permissions are gone
  /// fail the test for naming them.
  ///
  /// A `tools:node="remove"` entry is the opposite of a declaration — it is
  /// how the app strips a permission a *library* merged in — so the two are
  /// kept apart. Folding them together would let the AD_ID removal read as an
  /// AD_ID declaration, which is the exact claim this file exists to deny.
  final tags = RegExp(
    r'<uses-permission([^>]*)>',
  ).allMatches(manifest).map((m) => m.group(1)!).toList();

  String nameOf(String tag) =>
      RegExp(r'android:name="([^"]+)"').firstMatch(tag)!.group(1)!;

  bool isRemoval(String tag) => tag.contains('tools:node="remove"');

  final declared = tags.where((t) => !isRemoval(t)).map(nameOf).toSet();
  final removed = tags.where(isRemoval).map(nameOf).toSet();

  bool declaresPermission(String name) =>
      declared.contains('android.permission.$name');

  final receivers = RegExp(r'<receiver[^>]*android:name="([^"]+)"', dotAll: true)
      .allMatches(manifest)
      .map((m) => m.group(1)!)
      .toSet();

  bool declaresReceiver(String name) =>
      receivers.contains('com.dexterous.flutterlocalnotifications.$name');

  group('AndroidManifest', () {
    test('declares no restricted exact-alarm permission', () {
      // Play restricts USE_EXACT_ALARM to calendar and alarm-clock apps, and
      // gates SCHEDULE_EXACT_ALARM behind the same policy question. Cirrus is
      // neither, and its reminders are inexact by design — so neither may
      // appear here, in a plugin we add, or in a `tools:` merge rule.
      expect(declaresPermission('USE_EXACT_ALARM'), isFalse);
      expect(declaresPermission('SCHEDULE_EXACT_ALARM'), isFalse);
    });

    test('schedules inexactly, matching the permissions it declares', () {
      final scheduler = File(
        'lib/data/api/firebase/reminder_scheduler.dart',
      ).readAsStringSync();
      // The manifest and the schedule mode are one decision in two files. An
      // `exact` mode here throws `ExactAlarmPermissionException` on every
      // Android 14 device, because the permission it needs is gone for good.
      expect(scheduler.contains('AndroidScheduleMode.exact'), isFalse);
      expect(scheduler.contains('AndroidScheduleMode.alarmClock'), isFalse);
      expect(
        'AndroidScheduleMode.inexactAllowWhileIdle'.allMatches(scheduler).length,
        2,
        reason: 'both zonedSchedule calls must stay inexact',
      );
    });

    test('declares the receivers scheduled notifications are delivered to', () {
      expect(declaresReceiver('ScheduledNotificationReceiver'), isTrue);
      expect(declaresReceiver('ScheduledNotificationBootReceiver'), isTrue);
      // The boot receiver is inert without it, and pending reminders would be
      // dropped by every restart.
      expect(declaresPermission('RECEIVE_BOOT_COMPLETED'), isTrue);
    });

    test('still asks for the runtime notification grant', () {
      expect(declaresPermission('POST_NOTIFICATIONS'), isTrue);
    });

    /// App Links fail silently in both directions: claim too little and the
    /// link opens a browser with no error anywhere, claim too much and the app
    /// starts swallowing URLs meant for the website. Both are pinned.
    group('App Links', () {
      final filter = RegExp(
        r'<intent-filter android:autoVerify="true">(.*?)</intent-filter>',
        dotAll: true,
      ).firstMatch(manifest)?.group(1);

      Set<String> attr(String name) => RegExp('android:$name="([^"]+)"')
          .allMatches(filter ?? '')
          .map((m) => m.group(1)!)
          .toSet();

      test('declares a verified filter at all', () {
        expect(
          filter,
          isNotNull,
          reason: 'without autoVerify, cirrusquit.com links open a browser',
        );
        expect(attr('scheme'), {'https'});
      });

      test('claims the apex host, and only the apex host', () {
        // Digital Asset Links does NOT follow redirects, and www.cirrusquit.com
        // 301s to the apex — so declaring www fails verification for the whole
        // set, not just for www.
        expect(attr('host'), {'cirrusquit.com'});
      });

      test('claims only paths that something actually serves', () {
        // Every claimed prefix must have a real destination on BOTH sides: a
        // page on the site for anyone without the app, and a route inside it
        // for anyone with. `/go/` was claimed here before either existed —
        // a door with nothing behind it, exactly like the store links that
        // sat dead in a published blog post. It returns with LpDeepLinks.
        expect(attr('pathPrefix'), {'/download'});
        expect(
          filter!.contains('pathPattern'),
          isFalse,
          reason: 'a wildcard pattern is how an unscoped claim sneaks back in',
        );
      });

      test('never claims a path the app itself opens in a browser', () {
        // LpLinks hands these to the OS *expecting a browser*. If a prefix
        // ever covered one, tapping "Privacy policy" in Settings would
        // relaunch the app instead of showing the policy — an unescapable
        // loop, on the screen a Play reviewer opens first.
        final prefixes = attr('pathPrefix');
        final hosts = attr('host');

        for (final uri in [LpLinks.website, LpLinks.privacy, LpLinks.terms]) {
          if (!hosts.contains(uri.host)) continue;
          final path = uri.path.isEmpty ? '/' : uri.path;
          for (final prefix in prefixes) {
            expect(
              path.startsWith(prefix),
              isFalse,
              reason: '$uri is claimed by pathPrefix "$prefix"',
            );
          }
        }
      });

      test("leaves Flutter's own deep-link handling off, inside the activity", () {
        // Presence is not enough, and this is the trap: Flutter reads the flag
        // with getActivityInfo(GET_META_DATA), so a <meta-data> sitting in
        // <application> is silently ignored — and since Flutter 3.24 deep
        // linking defaults to ON whenever an autoVerify filter exists, which
        // it now does. The engine would then hand go_router the raw web path,
        // so cirrusquit.com/download becomes a lookup for "/download" that no
        // route declares, landing on RouteNotFoundScreen, and skipping the
        // redirect guards on the way. So assert the SCOPE, not the string.
        final activity = RegExp(
          r'<activity[^>]*android:name="\.MainActivity".*?</activity>',
          dotAll: true,
        ).firstMatch(manifest)?.group(0);

        expect(activity, isNotNull, reason: 'MainActivity not found');
        expect(
          RegExp(
            r'android:name="flutter_deeplinking_enabled"\s*\n?\s*android:value="false"',
          ).hasMatch(activity!),
          isTrue,
          reason: 'the flag must be inside <activity>, or it does nothing',
        );
      });
    });

    test('removes the advertising ID instead of declaring it', () {
      // Play's console asks: "Your manifest file includes the AD_ID
      // permission ... answer 'yes' or remove this permission." Nothing in
      // this app reads an advertising ID; firebase_analytics merges the
      // permission in transitively via play-services-measurement-api. Founder
      // decision Sep 2 2026: remove it, so the Data Safety form for an app
      // about quitting nicotine carries no advertising identifier.
      //
      // These must be REMOVALS, never declarations — the distinction the
      // `declared`/`removed` split above exists to keep.
      expect(removed, contains('com.google.android.gms.permission.AD_ID'));
      expect(removed, contains('android.permission.ACCESS_ADSERVICES_AD_ID'));
      expect(declared, isNot(contains('com.google.android.gms.permission.AD_ID')));
      expect(
        declared,
        isNot(contains('android.permission.ACCESS_ADSERVICES_AD_ID')),
      );
      // `tools:node` is inert without the namespace, and its absence fails
      // silently: the merger keeps the library's permission and the console
      // asks again on the next upload.
      expect(manifest.contains('xmlns:tools="http://schemas.android.com/tools"'), isTrue);
    });

    test('no SDK asks for the advertising ID the manifest removes', () {
      // The other half of the same decision, and the half a manifest cannot
      // reach. Amplitude's `TrackingOptions.adid` defaults to TRUE, so the
      // Android SDK attaches an advertising ID to every event unless it is
      // turned off here — and the ads-identifier library firebase_analytics
      // drags in is what would let it succeed. Play's warning names this case
      // explicitly ("verify if any third-party SDK code in your app uses
      // advertising ID").
      final sink = File(
        'lib/data/analytics/amplitude_analytics.dart',
      ).readAsStringSync();
      expect(sink.contains('TrackingOptions(adid: false)'), isTrue);
    });
  });
}
