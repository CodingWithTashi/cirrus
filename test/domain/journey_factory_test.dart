import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/journey_factory.dart';
import 'package:last_puff/domain/logic/taper_engine.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';

/// `InitialJourney.build` — the day-1 journey both backends mint.
///
/// A day-1 journey contains exactly what the user gave us and nothing else.
/// It once invented a savings goal and a buddy; and until Sep 5 2026 its
/// unconfirmed 0-puff log was credited as a whole baseline day saved.
void main() {
  const profile = UserProfile(alias: '@newfox', avatarEmoji: '🦊');
  QuitPlan plan(DateTime start) => QuitPlan(
    method: QuitMethod.taper,
    paceDays: 30,
    startDate: start,
    baselinePuffsPerDay: 100,
    weeklySpend: 30,
    strength: NicStrength.mg50,
  );

  test('mints today as plan day 1 at the curve\'s day-1 line', () {
    final now = DateTime(2026, 9, 4, 15, 40);
    final s = InitialJourney.build(profile: profile, plan: plan(DateTime(2026, 9, 4)), now: now);
    final today = s.days[DateTime(2026, 9, 4)];
    expect(today, isNotNull, reason: 'keyed by local midnight');
    expect(today!.puffs, 0);
    expect(today.limit, TaperEngine.limitFor(s.plan, 1));
    expect(today.limit, 95);
    expect(today.isConfirmed, isFalse, reason: 'nobody has said vape-free');
    expect(s.plan.dayNumber(now), 1);
  });

  test('invents nothing', () {
    final s = InitialJourney.build(
      profile: profile,
      plan: plan(DateTime(2026, 9, 4)),
      now: DateTime(2026, 9, 4, 15),
    );
    expect(s.goals, isEmpty);
    expect(s.earnedBadges, isEmpty);
    expect(s.lastPuffAt, isNull);
    expect(s.cravingsSurvivedTotal, 0);
    expect(s.repairTokens, 0);
    expect(s.longestStreak, 0);
    expect(s.days, hasLength(1));
  });

  test('a fresh journey has saved nothing yet', () {
    // The unconfirmed factory log must not read as a clean day: Home said
    // "$4 saved so far · 100 puffs not taken" before the first tap.
    final now = DateTime(2026, 9, 4, 15);
    final s = InitialJourney.build(profile: profile, plan: plan(DateTime(2026, 9, 4)), now: now);
    final snap = TodaySnapshot.of(s, now);
    expect(snap.savedLifetime, 0);
    expect(snap.puffsNotTaken, 0);
    expect(snap.streak, 0);
  });

  test('built after Freedom Day it starts in maintenance with a zero line', () {
    // A plan whose start date is already 35 days back (a restored draft, a
    // clock jump): the journey exists, and the line is what the plan says
    // for that day — nothing.
    final now = DateTime(2026, 9, 4, 15);
    final s = InitialJourney.build(profile: profile, plan: plan(DateTime(2026, 8, 1)), now: now);
    expect(s.days[DateTime(2026, 9, 4)]!.limit, 0);
    final snap = TodaySnapshot.of(s, now);
    expect(snap.isMaintenance, isTrue);
    expect(snap.dayNumber, 35);
  });

  test('on the last day of the plan the line is zero too', () {
    final now = DateTime(2026, 9, 4, 15);
    final s = InitialJourney.build(profile: profile, plan: plan(DateTime(2026, 8, 6)), now: now);
    expect(s.plan.dayNumber(now), 30);
    expect(s.days[DateTime(2026, 9, 4)]!.limit, 0);
    expect(TodaySnapshot.of(s, now).isFreedomDay, isTrue);
  });
}
