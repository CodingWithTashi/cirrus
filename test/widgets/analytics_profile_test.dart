import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/data/api/firebase/push_service.dart';
import 'package:last_puff/data/api/firebase/reminder_scheduler.dart';
import 'package:last_puff/data/stores/analytics_profile.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/data/stores/reminder_coordinator.dart';
import 'package:last_puff/domain/analytics/lp_events.dart';
import 'package:last_puff/domain/logic/reminder_planner.dart';
import 'package:last_puff/domain/logic/reminder_tap.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

class _Permissions implements PushPermissions {
  _Permissions(this.answer);

  PushPermission answer;

  @override
  Future<PushPermission> status() async => answer;

  @override
  Future<bool> request() async => true;
}

/// A scheduler that takes everything it is handed and remembers the ids.
class _ArmingSink implements ReminderSink {
  final List<int> armed = [];

  @override
  Stream<ReminderTap> get opened => const Stream.empty();

  @override
  Future<void> apply(
    List<ReminderSlot> slots, {
    required String title,
    required String body,
  }) async {}

  @override
  Future<bool> scheduleOnce(
    OneShotReminder reminder, {
    required ReminderTap tap,
    required String title,
    required String body,
  }) async {
    armed.add(reminder.id);
    return true;
  }

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}

/// Who the person is, as the dashboard sees it (docs/10 §58.5).
///
/// The Nov 21 read had to rebuild "taper vs cold turkey" and "notifications
/// on vs off" by hand from onboarding events for every retention split,
/// because nothing was set on the user. These are the two splits that
/// separated who came back.
void main() {
  group('AnalyticsProfile', () {
    test('sends a value once, and again only when it changes', () {
      final sink = RecordingAnalytics();
      final profile = AnalyticsProfile(sink);

      profile.report({LpUserProps.quitMethod: 'taper'});
      profile.report({LpUserProps.quitMethod: 'taper'});
      profile.report({
        LpUserProps.quitMethod: 'taper',
        LpUserProps.pushPermission: 'granted',
      });
      profile.report({LpUserProps.quitMethod: 'coldTurkey'});

      expect(sink.userProperties, [
        {LpUserProps.quitMethod: 'taper'},
        {LpUserProps.pushPermission: 'granted'},
        {LpUserProps.quitMethod: 'coldTurkey'},
      ]);
    });

    test('after forget, the next person gets every value sent again', () {
      // A sign-out resets the vendor identity, so a value the last account
      // already had is news to the next one.
      final sink = RecordingAnalytics();
      final profile = AnalyticsProfile(sink);

      profile.report({LpUserProps.quitMethod: 'taper'});
      profile.forget();
      profile.report({LpUserProps.quitMethod: 'taper'});

      expect(sink.userProperties, hasLength(2));
    });

    test('names fit Firebase: snake_case, at most 24 characters', () {
      final snake = RegExp(r'^[a-z][a-z0-9_]*$');
      expect(LpUserProps.all, contains(LpUserProps.day2Morning));
      for (final name in LpUserProps.all) {
        expect(name, matches(snake));
        expect(name.length, lessThanOrEqualTo(24), reason: name);
        expect(name.startsWith('firebase_'), isFalse, reason: name);
      }
    });
  });

  group('the app reports them', () {
    Future<(ProviderContainer, RecordingAnalytics)> boot(
      WidgetTester tester,
      _Permissions permissions,
    ) async {
      final analytics = RecordingAnalytics();
      final c = ProviderContainer(
        overrides: fastBackendOverrides(
          analytics: analytics,
          extra: [pushPermissionsProvider.overrideWithValue(permissions)],
        ),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: c, child: const LastPuffApp()),
      );
      c.read(quitStoreProvider.notifier).seedDemoJourney();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      return (c, analytics);
    }

    Map<String, Object> merged(RecordingAnalytics a) => {
      for (final p in a.userProperties) ...p,
    };

    testWidgets('the method and the notification permission', (tester) async {
      final (_, analytics) = await boot(
        tester,
        _Permissions(PushPermission.granted),
      );

      expect(merged(analytics), {
        LpUserProps.quitMethod: QuitMethod.taper.name,
        LpUserProps.pushPermission: PushPermission.granted.name,
      });
    });

    testWidgets('a permission changed in system settings shows on resume', (
      tester,
    ) async {
      // The app is never told when somebody turns notifications off in
      // Settings; a resume is the first moment it can notice.
      final permissions = _Permissions(PushPermission.granted);
      final (_, analytics) = await boot(tester, permissions);

      permissions.answer = PushPermission.denied;
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();

      expect(
        merged(analytics)[LpUserProps.pushPermission],
        PushPermission.denied.name,
      );
    });

    testWidgets('the day-2 morning is reported once it is armed', (
      tester,
    ) async {
      // Whether the morning reminder exists on the phone is the one thing the
      // funnel cannot read from a tap: nobody taps one that was never armed.
      final analytics = RecordingAnalytics();
      final sink = _ArmingSink();
      final now = DateTime(2026, 9, 14, 19);
      final c = ProviderContainer(
        overrides: fastBackendOverrides(
          now: now,
          analytics: analytics,
          extra: [
            pushPermissionsProvider.overrideWithValue(
              _Permissions(PushPermission.granted),
            ),
            reminderCoordinatorProvider.overrideWithValue(
              ReminderCoordinator(sink),
            ),
          ],
        ),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: c, child: const LastPuffApp()),
      );
      c
          .read(quitStoreProvider.notifier)
          .replaceForTest(journeyOnDay(1, now: now));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(sink.armed, contains(5102));
      expect(merged(analytics)[LpUserProps.day2Morning], 'armed');
    });

    testWidgets('the next account on the phone gets its own values', (
      tester,
    ) async {
      final (c, analytics) = await boot(
        tester,
        _Permissions(PushPermission.granted),
      );
      final before = analytics.userProperties.length;

      c.read(quitStoreProvider.notifier).signOut();
      await tester.pumpAndSettle();
      final j = journeyOnDay(3, now: DateTime.now());
      c
          .read(quitStoreProvider.notifier)
          .replaceForTest(
            j.copyWith(plan: j.plan.copyWith(method: QuitMethod.coldTurkey)),
          );
      await tester.pumpAndSettle();

      final after = {
        for (final p in analytics.userProperties.skip(before)) ...p,
      };
      expect(after, {
        LpUserProps.quitMethod: QuitMethod.coldTurkey.name,
        LpUserProps.pushPermission: PushPermission.granted.name,
      });
    });
  });
}
