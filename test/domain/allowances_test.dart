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
    expect(LpAllowances.sosPosts, 3);
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

  test('the free history window is a week, and that is a decision', () {
    // It was 30, raised there on the morning of Sep 3 2026 so a free account
    // could see its own taper working (`P=30`), and cut back to 7 the same
    // day (docs/12 §5c). The argument for 30 was never refuted — it was
    // traded: Stats is where the product's central question gets answered,
    // and a free tier that answers it in full leaves nothing to sell.
    //
    // Pinned exactly rather than as a bound, because both directions are
    // wrong by accident: longer gives the answer away, shorter cannot show a
    // week.
    expect(LpAllowances.freeHistoryDays, 7);
  });

  test('the SOS pin window is the one the feed and the server use', () {
    // `CommunityState.visible` pins by it, the composer refuses by it, and
    // `createPost`'s SOS_COOLDOWN_MS is the same hour in milliseconds. Three
    // copies of one number, and the refusal only says something true —
    // "yours is still up there" — while they agree.
    expect(LpAllowances.sosPinWindow, const Duration(hours: 1));
    expect(LpAllowances.sosPinWindow.inMilliseconds, 60 * 60 * 1000);
  });

  test('the health gate is a floor, low enough to leave an arc to sell', () {
    // `health_screen.dart` takes `max(freeHealthNodes, hereIndex + 1)`, so
    // this can never lock a node the reader has already reached — it only
    // ever hides the future. Four is the first 24 hours.
    expect(LpAllowances.freeHealthNodes, 4);
  });
}
