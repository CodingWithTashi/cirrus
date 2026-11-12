import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';

import '../helpers.dart';

/// The coach's name has to reach the server once there is an account for it
/// to belong to.
///
/// Since the quiz moved in front of the account (Oct 5 2026) the coach-name
/// step runs with nobody signed in. `setCoachName` answered "Sign in to
/// continue" to 73 of 87 calls, the failure was swallowed as designed, and
/// **nothing sent the name again** — so 101 of 127 accounts had no server
/// copy, and the model, which may only read the server's, called itself Ember
/// on every screen that showed the name the person had chosen (Nov 11 2026).
///
/// The fix has one home: a session being established with a journey that
/// carries a name. That is the first moment both halves exist, and it is the
/// same moment on a new account and on the next launch of an old one.
void main() {
  final now = DateTime(2026, 11, 12, 10, 30);

  // Plain tests on purpose: these await the fake backend, whose ack is a
  // zero-length timer that only a real event loop fires. Under the widget
  // binding's fake clock the same await never returns.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 5));

  ProviderContainer container(CoachNameRepository guard) {
    final c = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(now: now),
        coachNameRepositoryProvider.overrideWithValue(guard),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  ({UserProfile profile, QuitPlan plan}) fresh({String? coachName}) {
    final seed = journeyOnDay(1, now: now);
    return (
      profile: UserProfile(
        alias: seed.profile.alias,
        avatarEmoji: seed.profile.avatarEmoji,
        coachName: coachName,
      ),
      plan: seed.plan,
    );
  }

  test('a journey created at the end of onboarding sends its name', () async {
    final guard = _Recording();
    final c = container(guard);
    final draft = fresh(coachName: 'Pip');

    await c
        .read(quitStoreProvider.notifier)
        .startJourney(profile: draft.profile, plan: draft.plan);
    await settle();

    expect(guard.names, ['Pip']);
    expect(c.read(quitStoreProvider)!.profile.coachName, 'Pip');
  });

  test('an account that never chose a name sends nothing', () async {
    final guard = _Recording();
    final c = container(guard);
    final draft = fresh();

    await c
        .read(quitStoreProvider.notifier)
        .startJourney(profile: draft.profile, plan: draft.plan);
    await settle();

    expect(guard.names, isEmpty);
  });

  test('an account from before the fix is caught up on its next '
      'sign-in', () async {
    final guard = _Recording();
    final c = container(guard);
    final store = c.read(quitStoreProvider.notifier);
    // The demo account, renamed in an earlier session.
    await store.logIn(email: 'maya@quitmail.com', password: 'hunter22');
    await store.reserveCoachName('Pip');
    await settle();
    store.signOut();
    await settle();
    guard.names.clear();

    await store.logIn(email: 'maya@quitmail.com', password: 'hunter22');
    await settle();

    expect(c.read(quitStoreProvider)!.profile.coachName, 'Pip');
    expect(guard.names, ['Pip']);
  });

  test('a name the server refuses goes back to the default, so the '
      'screens and the coach agree', () async {
    // The refusal cannot be shown at the step any more — nobody was signed in
    // there to ask. Keeping the name would leave every screen saying one
    // thing and the model another, for good.
    final guard = _Recording(accept: false);
    final c = container(guard);
    final draft = fresh(coachName: 'Pip');

    await c
        .read(quitStoreProvider.notifier)
        .startJourney(profile: draft.profile, plan: draft.plan);
    await settle();

    expect(guard.names, ['Pip']);
    expect(c.read(quitStoreProvider)!.profile.coachName, isNull);
  });

  test('a server that cannot answer keeps the name for next time', () async {
    final guard = _Recording(fail: true);
    final c = container(guard);
    final draft = fresh(coachName: 'Pip');

    await c
        .read(quitStoreProvider.notifier)
        .startJourney(profile: draft.profile, plan: draft.plan);
    await settle();

    expect(c.read(quitStoreProvider)!.profile.coachName, 'Pip');
  });
}

class _Recording implements CoachNameRepository {
  _Recording({this.accept = true, this.fail = false});

  final bool accept;
  final bool fail;
  final List<String> names = [];

  @override
  Future<bool> reserve(String name) async {
    names.add(name);
    if (fail) throw const NoConnectionException();
    return accept;
  }
}
