import 'dart:async';

import 'package:amplitude_flutter/amplitude.dart';
import 'package:amplitude_flutter/configuration.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/analytics/amplitude_analytics.dart';
import 'package:last_puff/data/analytics/analytics_options.dart';
import 'package:last_puff/data/analytics/analytics_sinks.dart';
import 'package:last_puff/data/backend_mode.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/analytics/analytics.dart';
import 'package:last_puff/domain/analytics/lp_events.dart';
import 'package:last_puff/domain/logic/games/game_id.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/onboarding/onboarding_view_model.dart';

import 'helpers.dart';

/// The analytics seam: one vocabulary, many vendors, and a guarantee that a
/// vendor failing is invisible to the user.
///
/// The static class this replaced could not be tested at all — it called
/// `FirebaseAnalytics.instance` directly, so every assertion here is coverage
/// that did not previously exist.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the vocabulary', () {
    // The dashboard reads these strings. A rename in Dart that is not also a
    // rename in Amplitude and Firebase silently orphans a chart, and the
    // >15% drop-off alert docs/02 §7 asks for stops firing rather than
    // reporting zero. So the names are pinned, in order, against the spec.
    test('every event fires under its docs/02 §7 name', () {
      final a = RecordingAnalytics()
        ..onboardingStart()
        ..screenCompleted('welcome', 1200)
        ..ageGateBlocked()
        ..ageEntryAdopted()
        ..puffsEntered(200, 'heavy')
        ..spendEntered(45, 2340)
        ..methodChosen('taper')
        ..paceChosen(30)
        ..planRevealed()
        ..commitHeld()
        ..notifPrompt(granted: true)
        ..paywallViewed('d5_default', source: 'onboarding', planDay: 12)
        ..planSelected('yearly', source: 'onboarding')
        ..paywallDismissed(source: 'launch', plan: 'weekly')
        ..trialStarted('yearly')
        ..freeContinued()
        ..winbackShown()
        ..winbackConverted()
        ..gateShown('insight', planDay: 3)
        ..gateTapped('insight')
        ..limitReached(LpLimit.coach, premium: false, used: 5, limit: 5)
        ..day1Viewed()
        ..day1TaskDone('log_puff')
        ..day1Completed()
        ..day1Skipped(1)
        ..purchaseCompleted('yearly', trial: true)
        ..purchaseCancelled('monthly')
        ..purchaseFailed('offline')
        ..restoreCompleted(found: false)
        ..entitlementChanged('trial')
        ..puffLogged()
        ..cravingSurvived(survived: true)
        ..gameFinished(
          game: GameId.tiles,
          round: 1,
          score: 112,
          bestCombo: 40,
          misses: 3,
        )
        ..gameSwitched(from: GameId.tiles, to: GameId.blocks);

      expect(a.names, [
        'onboarding_start',
        'screen_completed',
        'age_gate_blocked',
        'age_entry_adopted',
        'puffs_entered',
        'spend_entered',
        'method_chosen',
        'pace_chosen',
        'plan_revealed',
        'commit_held',
        'notif_prompt',
        'paywall_viewed',
        // What people CONSIDER vs what they buy, and leaving the paywall
        // itself — `purchase_cancelled` only ever saw the store sheet.
        'plan_selected',
        'paywall_dismissed',
        'trial_started',
        'free_continued',
        'winback_shown',
        'winback_converted',
        // The eleven gates only ever reported the doors that were tapped, so
        // a gate nobody opened read the same as a gate nobody saw.
        'gate_shown',
        'gate_tapped',
        // A gate is a door we chose to show; a limit is a wall somebody hit.
        // Every server-enforced wall used to be silent, so "ran out of coach
        // messages" read exactly like "never opened the coach".
        'limit_reached',
        // The Day-1 checklist gates every new account and emitted nothing at
        // all, which left activation — the biggest drop-off in the app —
        // entirely unmeasured.
        'day1_viewed',
        'day1_task_done',
        'day1_completed',
        'day1_skipped',
        'purchase_completed',
        'purchase_cancelled',
        'purchase_failed',
        'restore_completed',
        'entitlement_changed',
        'puff_logged',
        'craving_outcome',
        'game_finished',
        'game_switched',
      ]);
      expect(a.propsOf('purchase_completed'), {
        'plan': 'yearly',
        'trial': 'true',
      });
      expect(a.propsOf('restore_completed'), {'found': 'false'});
      expect(a.propsOf('gate_shown'), {'source': 'insight', 'plan_day': 3});
      expect(a.propsOf('paywall_viewed'), {
        'variant': 'd5_default',
        'source': 'onboarding',
        'plan_day': 12,
      });
      expect(a.propsOf('plan_selected'), {
        'period': 'yearly',
        'source': 'onboarding',
      });
      expect(a.propsOf('paywall_dismissed'), {
        'source': 'launch',
        'plan': 'weekly',
      });
      expect(a.propsOf('gate_tapped'), {'source': 'insight'});
      expect(a.propsOf('limit_reached'), {
        'capability': 'coach',
        'tier': 'free',
        'used': 5,
        'limit': 5,
      });
      // The task name is a wire value spelled out in JourneyStore, not
      // `Day1TourStep.name` — renaming that enum must not reclassify history.
      expect(a.propsOf('day1_task_done'), {'task': 'log_puff'});
      expect(a.propsOf('day1_skipped'), {'done': 1});

      // Property keys are read by the same dashboards.
      expect(a.propsOf('screen_completed'), {'screen_id': 'welcome', 'ms': 1200});
      expect(a.propsOf('game_finished'), {
        'game': 'tiles',
        'round': 1,
        'score': 112,
        'best_combo': 40,
        'misses': 3,
      });
      expect(a.propsOf('game_switched'), {'from': 'tiles', 'to': 'blocks'});
      expect(a.propsOf('puffs_entered'), {'value': 200, 'badge': 'heavy'});
      expect(a.propsOf('spend_entered'), {'weekly': 45, 'yearly_shown': 2340});
      expect(a.propsOf('pace_chosen'), {'pace_days': 30});
      expect(a.propsOf('craving_outcome'), {
        'survived': 'true',
        'game': 'none',
        'rounds': 0,
      });
    });

    // Firebase Analytics rejects anything else outright, and a rejected event
    // is dropped without an error anyone sees.
    test('names and keys are snake_case and within Firebase limits', () {
      final a = RecordingAnalytics()
        ..onboardingStart()
        ..screenCompleted('welcome', 1)
        ..puffsEntered(1, 'light')
        ..spendEntered(1, 1)
        ..methodChosen('taper')
        ..paceChosen(1)
        ..notifPrompt(granted: false)
        ..paywallViewed('v', source: 's', planDay: 1)
        ..planSelected('weekly', source: 's')
        ..paywallDismissed(source: 's', plan: 'yearly')
        ..trialStarted('t')
        // Every capability's wire value goes through the snake_case check —
        // three of the four are multi-word, and `.name` would have shipped
        // camelCase into a snake_case vocabulary.
        ..limitReached(LpLimit.coach, premium: true)
        ..limitReached(LpLimit.communityPost, premium: false)
        ..limitReached(LpLimit.communityCap, premium: true, used: 3)
        ..limitReached(LpLimit.panicAi, premium: false, used: 2)
        ..cravingSurvived(survived: false);

      final snake = RegExp(r'^[a-z][a-z0-9_]*$');
      for (final event in a.events) {
        expect(event.name, matches(snake), reason: event.name);
        expect(event.name.length, lessThanOrEqualTo(40), reason: event.name);
        for (final key in event.props.keys) {
          expect(key, matches(snake), reason: '${event.name}.$key');
          expect(key.length, lessThanOrEqualTo(40), reason: '${event.name}.$key');
        }
      }
      // Not just the keys: a capability lands in the dashboard as a VALUE,
      // and a camelCase one there is as unreadable as a camelCase key.
      for (final capability in LpLimit.values) {
        expect(capability.wire, matches(snake), reason: capability.name);
      }
      expect(
        {for (final c in LpLimit.values) c.wire},
        hasLength(LpLimit.values.length),
        reason: 'two capabilities sharing a wire value would merge in the chart',
      );
    });

    // `used`/`limit` are omitted, never zero-filled: a client guess sitting in
    // the same column as the server's fact is worse than an absent number.
    test('an unreported count is absent rather than invented', () {
      final a = RecordingAnalytics()
        ..limitReached(LpLimit.communityPost, premium: false);
      expect(a.propsOf('limit_reached'), {
        'capability': 'community_post',
        'tier': 'free',
      });
    });

    // A trial is on the premium allowance, so it must not read as a free user
    // hitting a free wall — that would understate paid-tier friction.
    test('tier reports the allowance in force, not the entitlement', () {
      final a = RecordingAnalytics()
        ..limitReached(LpLimit.coach, premium: true, used: 100, limit: 100);
      expect(a.propsOf('limit_reached'), containsPair('tier', 'premium'));
    });
  });

  group('FanOutAnalytics', () {
    test('delivers every call to every sink', () {
      final a = RecordingAnalytics();
      final b = RecordingAnalytics();
      FanOutAnalytics([a, b])
        ..puffLogged()
        ..screenViewed('/home')
        ..identify('uid-1')
        ..reset();

      for (final sink in [a, b]) {
        expect(sink.names, ['puff_logged']);
        expect(sink.screens, ['/home']);
        expect(sink.identified, ['uid-1']);
        expect(sink.resets, 1);
      }
    });

    // One vendor being down must not cost the other vendor its data, and must
    // never reach the tap handler that fired the event.
    test('a throwing sink neither blocks the others nor escapes', () {
      final healthy = RecordingAnalytics();
      final fanOut = FanOutAnalytics([_ThrowingAnalytics(), healthy]);

      expect(() => fanOut.puffLogged(), returnsNormally);
      expect(() => fanOut.screenViewed('/home'), returnsNormally);
      expect(() => fanOut.identify('uid-1'), returnsNormally);
      expect(() => fanOut.reset(), returnsNormally);

      expect(healthy.names, ['puff_logged']);
      expect(healthy.screens, ['/home']);
      expect(healthy.identified, ['uid-1']);
      expect(healthy.resets, 1);
    });
  });

  test('NoopAnalytics swallows everything without throwing', () {
    const noop = NoopAnalytics();
    expect(() {
      noop
        ..puffLogged()
        ..screenViewed('/home')
        ..identify('uid-1')
        ..reset();
    }, returnsNormally);
  });

  group('only the release app reports', () {
    test('the fake backend never reports', () {
      final c = ProviderContainer(overrides: fastBackendOverrides());
      addTearDown(c.dispose);
      // Not just "no events": constructing a vendor SDK under `flutter test`
      // would reach a MethodChannel that does not exist.
      expect(c.read(analyticsProvider), isA<NoopAnalytics>());
    });

    // The one that matters for funnel hygiene. `flutter test` and every
    // `./tool/device.ps1` run are debug builds, and a dev walking the
    // 19 steps must not land in the funnel the >15% drop-off alert reads.
    // This asserts the BUILD gate, not the backend one: the backend here is
    // the real Firebase.
    test('a non-release build never reports, even on the real backend', () {
      expect(analyticsEnabled(BackendMode.firebase), isFalse);
      expect(analyticsEnabled(BackendMode.fake), isFalse);

      final c = ProviderContainer(
        overrides: [
          ...fastBackendOverrides(),
          backendModeProvider.overrideWithValue(BackendMode.firebase),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(analyticsProvider), isA<NoopAnalytics>());
    });
  });

  // `Amplitude(...)` returns before its native `init` lands, and the Android
  // plugin answers an early `track` with "instance not found". A sink may
  // never throw at its caller, so such an event would be swallowed and lost —
  // and the first screen view fires on the very frame the sink is built.
  test('an event fired before init completes is not lost', () async {
    const channel = MethodChannel('amplitude_flutter_test');
    final calls = <String>[];
    final initReleased = Completer<void>();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'init') await initReleased.future;
          calls.add(call.method);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    AmplitudeAnalytics(Amplitude(Configuration(apiKey: 'k'), channel))
      ..puffLogged()
      ..screenViewed('/home');
    await pumpEventQueue();
    expect(calls, isEmpty, reason: 'nothing may be sent before init lands');

    initReleased.complete();
    await pumpEventQueue();
    // Both survived, in the order they were fired.
    expect(calls, ['init', 'track', 'track']);
  });

  // The whole reason the event is emitted from the view model rather than
  // from 19 widgets: the funnel cannot have a hole in it.
  test('every onboarding step reports its own screen_completed', () {
    final analytics = RecordingAnalytics();
    final c = ProviderContainer(
      overrides: fastBackendOverrides(analytics: analytics),
    );
    addTearDown(c.dispose);

    // `next()` refuses to leave an unanswered step, so every answer goes in
    // first — the same fixture shape as test/data/onboarding_test.dart.
    final vm = c.read(onboardingProvider.notifier)
      ..selectGender(Gender.woman)
      ..selectAttempts(QuitAttempts.twoToFive)
      ..selectFrequency(VapeFrequency.always)
      ..selectStrength(NicStrength.mg50)
      ..selectFirstPuff(FirstPuffWindow.withinFive)
      ..toggleWhy(WhyChip.health)
      ..toggleWorry(WorryChip.cravings)
      ..selectMethod(QuitMethod.taper)
      ..selectPace(30);
    for (final d in [1, 9, 9, 5]) {
      vm.typeBirthDigit(d);
    }
    for (final d in [2, 0, 0]) {
      vm.typePuffDigit(d);
    }
    for (final d in [4, 5]) {
      vm.typeSpendDigit(d);
    }
    for (var i = 0; i < 6; i++) {
      vm.next();
    }

    final completed = analytics.events
        .where((e) => e.name == 'screen_completed')
        .toList();
    expect(completed, hasLength(6));
    // Six screens left, six distinct screen ids — a step that reported under
    // its neighbour's name would read as a healthy screen and a dead one.
    expect({for (final e in completed) e.props['screen_id']}, hasLength(6));
    // The first step left is welcome, and leaving it is the funnel's
    // denominator.
    expect(completed.first.props['screen_id'], ObStep.welcome.name);
    expect(analytics.names, contains('onboarding_start'));
    for (final e in completed) {
      expect(e.props['ms'], isA<int>());
    }
  });
}

/// A vendor that is having a bad day.
class _ThrowingAnalytics implements AnalyticsSink {
  @override
  void track(AnalyticsEvent event) => throw StateError('down');

  @override
  void screenViewed(String name) => throw StateError('down');

  @override
  void identify(String userId) => throw StateError('down');

  @override
  void reset() => throw StateError('down');
}
