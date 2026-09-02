import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/reminder_planner.dart';
import 'package:last_puff/domain/models/models.dart';

/// The honest trial-ending reminder (docs/02 §4): one day before the charge,
/// never inside quiet hours, never after the fact, never for anyone who is
/// not on a trial.
void main() {
  final now = DateTime(2026, 9, 2, 12);

  Entitlement trial(DateTime ends) => Entitlement(
    tier: SubscriptionTier.trial,
    period: PlanPeriod.yearly,
    expiresAt: ends,
    willRenew: true,
  );

  OneShotReminder? plan(
    Entitlement e, {
    bool enabled = true,
    int quietStart = 23,
    int quietEnd = 8,
  }) => TrialReminderPlanner.plan(
    entitlement: e,
    now: now,
    quietStartHour: quietStart,
    quietEndHour: quietEnd,
    enabled: enabled,
  );

  test('fires one day before the trial ends, with the reserved id', () {
    final r = plan(trial(DateTime(2026, 9, 9, 15)));
    expect(r, isNotNull);
    expect(r!.id, 2000);
    expect(r.at, DateTime(2026, 9, 8, 15));
  });

  test('a fire time inside quiet hours moves to the nearest edge on the same '
      'day — the copy says "tomorrow"', () {
    // 03:00 is in the post-midnight band: forward to 08:00, still the day
    // before the charge (the old rule pulled it to 23:00 two days before).
    expect(plan(trial(DateTime(2026, 9, 9, 3)))!.at, DateTime(2026, 9, 8, 8));
    // 23:30 is in the evening band: back to 23:00 the same evening.
    expect(
      plan(trial(DateTime(2026, 9, 9, 23, 30)))!.at,
      DateTime(2026, 9, 8, 23),
    );
    // 07:59 is still inside; 08:00 is not.
    expect(
      plan(trial(DateTime(2026, 9, 9, 7, 59)))!.at,
      DateTime(2026, 9, 8, 8),
    );
    expect(plan(trial(DateTime(2026, 9, 9, 8)))!.at, DateTime(2026, 9, 8, 8));
  });

  test('a user who turned the reminder off gets none', () {
    expect(plan(trial(DateTime(2026, 9, 9, 15)), enabled: false), isNull);
  });

  test('only a trial gets one — a paid plan, free, or an unknown end do not', () {
    expect(
      plan(
        Entitlement(
          tier: SubscriptionTier.premium,
          expiresAt: DateTime(2026, 9, 9, 15),
        ),
      ),
      isNull,
    );
    expect(plan(const Entitlement.none()), isNull);
    expect(plan(const Entitlement(tier: SubscriptionTier.trial)), isNull);
  });

  test('a trial with less than a day left has nothing honest to schedule', () {
    expect(plan(trial(DateTime(2026, 9, 3, 11))), isNull);
    expect(plan(trial(DateTime(2026, 9, 3, 12))), isNull);
    expect(plan(trial(DateTime(2026, 9, 3, 12, 1))), isNotNull);
  });

  test('quiet hours that do not wrap midnight work the same way', () {
    // 12→14 quiet; a 13:00 fire is pulled back to 12:00 the same day.
    expect(
      plan(trial(DateTime(2026, 9, 9, 13)), quietStart: 12, quietEnd: 14)!.at,
      DateTime(2026, 9, 8, 12),
    );
  });
}
