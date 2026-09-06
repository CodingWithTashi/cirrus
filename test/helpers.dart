import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:last_puff/data/api/fake/fake_server.dart';
import 'package:last_puff/data/backend_mode.dart';
import 'package:last_puff/data/dto/entitlement_codec.dart';
import 'package:last_puff/data/network/connectivity.dart';
import 'package:last_puff/data/stores/entitlement_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/analytics/analytics.dart';
import 'package:last_puff/data/stores/settings_store.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/taper_engine.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/onboarding/onboarding_view_model.dart';

/// Standard test overrides for anything that pumps the app or wires the fake
/// backend: pinned to the fake backend (the test platform reports android,
/// which would otherwise select Firebase), instant fake network + no
/// connectivity polling (no pending timers, no real DNS lookups). Pass
/// `online: false` to simulate airplane mode — every backend call then
/// throws [NoConnectionException].
///
/// Settings restore is off: tests assert against the documented defaults, not
/// against whatever the host machine's shared_preferences last held.
///
/// Pass [analytics] to capture the events a flow emits; without it the pinned
/// fake backend already resolves the seam to `NoopAnalytics`, so no vendor SDK
/// is ever constructed under `flutter test`.
///
/// [premium] (default) is the demo persona: the seeded day-12 journey has
/// always been a paying user's, and the fake's guest account — the one
/// `seedDemoJourney()` runs on — starts with no subscription row. It is said
/// on BOTH sides of the seam: the fake server (what `createPost` would refuse)
/// and the store (what every gate reads). `premium: false` is the free
/// account the gates exist for.
List<Override> fastBackendOverrides({
  bool online = true,
  DateTime? now,
  AnalyticsSink? analytics,
  bool premium = true,
}) => [
  if (analytics != null) analyticsProvider.overrideWithValue(analytics),
  backendModeProvider.overrideWithValue(BackendMode.fake),
  apiLatencyProvider.overrideWithValue(Duration.zero),
  connectivityPollIntervalProvider.overrideWithValue(null),
  settingsStoreProvider.overrideWith(() => SettingsStore(restore: false)),
  // Same reason as settings: assert against the documented defaults, not
  // against whatever draft the host machine's shared_preferences last held.
  onboardingProvider.overrideWith(() => OnboardingViewModel(restore: false)),
  // Without these every widget test fails on a pending timer.
  dayClockProvider.overrideWith(() => DayClock(tick: false)),
  minuteClockProvider.overrideWith(() => MinuteClock(tick: false)),
  if (now != null) nowProvider.overrideWithValue(() => now),
  if (!online) connectivityProvider.overrideWith(ToggleConnectivity.new),
  if (premium) ...demoSubscriptionOverrides(),
];

/// The demo persona's subscription on both sides of the seam, from ONE row —
/// so the first `identify()` answers exactly the store's initial value and no
/// spurious `entitlement_changed` is recorded — and seeded on the guest
/// account without opening a session (`hasSession` stays false until a
/// sign-in, as on a fresh install).
List<Override> demoSubscriptionOverrides() {
  final row = FakeServer.demoEntitlementJson(DateTime.now());
  return [
    fakeServerProvider.overrideWith(
      (ref) => FakeServer(
        latency: ref.watch(apiLatencyProvider),
        isOnline: () => ref.read(connectivityProvider),
        now: ref.watch(nowProvider),
      )..seedGuestEntitlement(row),
    ),
    entitlementProvider.overrideWith(
      () => EntitlementStore(initial: EntitlementCodec.decode(row)),
    ),
  ];
}

/// A journey on plan day [day] of a [totalDays]-day taper, as of [now].
///
/// Every day before today is logged at the curve's own limit (confirmed, at
/// the line, so the chain holds) with all of its puffs at 10 AM; [puffsByDay]
/// overrides any of them (day number → puffs, 0 = a confirmed vape-free day).
/// Today is UNLOGGED — the state a real account is in before its first tap —
/// so `streak` reads `day - 1` and money counts only the completed days.
///
/// The defaults are the Sep 5 2026 screenshot's plan (100 puffs/day, $30 a
/// week): `journeyOnDay(2, now: DateTime(2026, 9, 5, 14, 12), puffsByDay:
/// {1: 36})` is the journey Home rendered as "Day 2 of 30 · $3 saved · 🔥 1
/// day", and its twin lives in `functions/test/memoryCard.test.ts`.
JourneyState journeyOnDay(
  int day, {
  required DateTime now,
  int baseline = 100,
  double weeklySpend = 30,
  int totalDays = 30,
  Map<int, int> puffsByDay = const {},
  DateTime? lastPuffAt,
  String alias = '@matrixfox',
}) {
  assert(day >= 1, 'plan days are 1-based');
  final start = LpDate.addDays(LpDate.dayStart(now), -(day - 1));
  final plan = QuitPlan(
    method: QuitMethod.taper,
    paceDays: totalDays,
    startDate: start,
    baselinePuffsPerDay: baseline,
    weeklySpend: weeklySpend,
    strength: NicStrength.mg50,
  );
  final days = <DateTime, DayLog>{};
  for (var d = 1; d < day; d++) {
    final date = LpDate.addDays(start, d - 1);
    final limit = d <= totalDays ? TaperEngine.limitFor(plan, d) : 0;
    final puffs = puffsByDay[d] ?? limit;
    days[date] = DayLog(
      date: date,
      puffs: puffs,
      limit: limit,
      hourBuckets: puffs == 0 ? const {} : {10: puffs},
      vapeFreeConfirmed: puffs == 0,
    );
  }
  return JourneyState(
    profile: UserProfile(alias: alias, avatarEmoji: '🦊'),
    plan: plan,
    days: days,
    cravingsSurvivedTotal: 0,
    repairTokens: 0,
    longestStreak: 0,
    goals: const [],
    earnedBadges: const {},
    lastPuffAt: lastPuffAt,
    day1TasksDone: const {0, 1, 2},
  );
}

/// Starts offline; tests flip it with `set(true)` to simulate the connection
/// coming back (retry-path coverage).
class ToggleConnectivity extends ConnectivityStore {
  @override
  bool build() => false;

  // ignore: use_setters_to_change_properties
  void set(bool online) => state = online;
}

/// An [AnalyticsSink] that sends nothing and remembers everything, so a test
/// can assert on the funnel a flow actually emits. The static class this seam
/// replaced could not be observed at all.
class RecordingAnalytics implements AnalyticsSink {
  final List<AnalyticsEvent> events = [];
  final List<String> screens = [];
  final List<String> identified = [];
  int resets = 0;

  /// Event names in order — what most assertions actually want.
  List<String> get names => [for (final e in events) e.name];

  Map<String, Object>? propsOf(String name) {
    for (final e in events) {
      if (e.name == name) return e.props;
    }
    return null;
  }

  /// Every occurrence, in order. [propsOf] answers the first, which silently
  /// hides a call site firing twice — and "did this fire exactly once" is the
  /// assertion an event with a per-wall meaning actually needs.
  List<Map<String, Object>> propsOfAll(String name) => [
    for (final e in events)
      if (e.name == name) e.props,
  ];

  @override
  void track(AnalyticsEvent event) => events.add(event);

  @override
  void screenViewed(String name) => screens.add(name);

  @override
  void identify(String userId) => identified.add(userId);

  @override
  void reset() => resets++;
}
