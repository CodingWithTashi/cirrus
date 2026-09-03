import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/allowances.dart';

/// The client's copy of the server's allowances, and the parity that keeps it
/// honest.
///
/// The same literals are asserted in `functions/test/allowance.test.ts`. Two
/// implementations of one number drift, and this repo has the scars:
/// `streakEngine.ts` once omitted the repair-token clause `streak_engine.dart`
/// applied, so the coach quoted numbers the Home screen contradicted. A
/// mismatch here shows up as a composer that greys out a post the server would
/// have accepted, or a cap bubble quoting a limit nobody enforces.
void main() {
  test('the documented allowances match functions/src/config.ts', () {
    // Change these ONLY together with `ALLOWANCE_DEFAULTS` and the
    // `.env.alastpuff` values, or the app and the backend disagree about what
    // a person is allowed to do.
    expect(LpAllowances.freeCoachMessages, 5);
    expect(LpAllowances.premiumCoachMessages, 100);
    expect(LpAllowances.freePosts, 1);
    expect(LpAllowances.premiumPosts, 3);
    expect(LpAllowances.sosPosts, 5);
  });

  test('a free account is never given more than a subscriber', () {
    // `createPost` decides which refusal code to send by comparing the two.
    // Inverted, a free user would be offered a door to a smaller allowance.
    expect(LpAllowances.freePosts, lessThan(LpAllowances.premiumPosts));
    expect(
      LpAllowances.freeCoachMessages,
      lessThan(LpAllowances.premiumCoachMessages),
    );
  });

  test('every allowance is a usable count', () {
    for (final value in [
      LpAllowances.freeCoachMessages,
      LpAllowances.premiumCoachMessages,
      LpAllowances.freePosts,
      LpAllowances.premiumPosts,
      LpAllowances.sosPosts,
      LpAllowances.freeHistoryDays,
    ]) {
      expect(value, greaterThan(0));
    }
  });

  group('postsForKind', () {
    test('follows the tier for an ordinary post', () {
      expect(
        LpAllowances.postsForKind(premium: false, sos: false),
        LpAllowances.freePosts,
      );
      expect(
        LpAllowances.postsForKind(premium: true, sos: false),
        LpAllowances.premiumPosts,
      );
    });

    test('ignores the tier entirely for an SOS', () {
      // The rule the separate counter exists for: nobody is refused a call for
      // help because of what they can afford, or because they used their
      // ordinary posts earlier.
      for (final premium in [true, false]) {
        expect(
          LpAllowances.postsForKind(premium: premium, sos: true),
          LpAllowances.sosPosts,
        );
      }
    });

    test('an SOS is never the scarcer of the two for a free account', () {
      expect(
        LpAllowances.postsForKind(premium: false, sos: true),
        greaterThanOrEqualTo(
          LpAllowances.postsForKind(premium: false, sos: false),
        ),
      );
    });
  });

  test('the free history window outlasts the taper program', () {
    // The taper runs 30 days (`P=30`). A shorter window means a free account
    // cannot see whether its own plan is working — on data already sitting in
    // its own journey document.
    expect(LpAllowances.freeHistoryDays, greaterThanOrEqualTo(30));
  });
}
