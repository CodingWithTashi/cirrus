import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/api/fake/fake_auth_api.dart';
import 'package:last_puff/data/api/fake/fake_journey_api.dart';
import 'package:last_puff/data/api/fake/fake_server.dart';
import 'package:last_puff/data/dto/journey_codec.dart';
import 'package:last_puff/domain/repositories/repositories.dart';

void main() {
  late FakeServer server;
  late FakeAuthApi auth;

  setUp(() {
    server = FakeServer(latency: Duration.zero);
    auth = FakeAuthApi(server);
  });

  test('a short password throws InvalidCredentialsException', () {
    expect(
      () => auth.signInWithEmail(email: 'maya@quitmail.com', password: '123'),
      throwsA(isA<InvalidCredentialsException>()),
    );
  });

  test('any email + a valid password signs into the demo journey', () async {
    final json = await auth.signInWithEmail(
      email: 'someone@else.com',
      password: 'hunter22',
    );
    final journey = JourneyCodec.decode(json);
    expect(journey.profile.alias, '@quietfox');
    expect(journey.plan.baselinePuffsPerDay, 200);
    expect(journey.plan.dayNumber(DateTime.now()), 12);
  });

  test('registering the demo email throws EmailAlreadyInUseException', () {
    expect(
      () => auth.register(email: FakeServer.demoEmail, password: 'secret1'),
      throwsA(isA<EmailAlreadyInUseException>()),
    );
  });

  test('a registered account rejects any other password', () async {
    await auth.register(email: 'new@user.com', password: 'goodpass');
    await auth.signOut();
    expect(
      () => auth.signInWithEmail(email: 'new@user.com', password: 'wrongpass'),
      throwsA(isA<InvalidCredentialsException>()),
    );
  });

  test('register opens a session with no journey yet', () async {
    await auth.register(email: 'new@user.com', password: 'goodpass');
    expect(await auth.restoreSession(), isNull);
  });

  test('restoreSession returns the signed-in journey', () async {
    await auth.signInWithEmail(email: 'maya@quitmail.com', password: 'secret1');
    expect(await auth.restoreSession(), isNotNull);
    await auth.signOut();
    expect(await auth.restoreSession(), isNull);
  });

  test('Apple sign-in onboards first, restores its journey after', () async {
    expect(await auth.signInWithApple(), isNull);

    // Onboarding completes → the backend creates the journey.
    final journeys = FakeJourneyApi(server);
    final demo = JourneyCodec.decode(
      await FakeAuthApi(
        FakeServer(latency: Duration.zero),
      ).signInWithEmail(email: FakeServer.demoEmail, password: 'secret1'),
    );
    await journeys.createJourney(
      profile: JourneyCodec.encodeProfile(demo.profile),
      plan: JourneyCodec.encodePlan(demo.plan),
    );

    await auth.signOut();
    expect(await auth.signInWithApple(), isNotNull);
  });

  test('deleteAccount removes the journey', () async {
    await auth.signInWithEmail(email: 'maya@quitmail.com', password: 'secret1');
    await auth.deleteAccount();
    expect(await auth.restoreSession(), isNull);
    // Even after signing back in, a deleted account starts from seed again —
    // the fake re-seeds unknown accounts (demo shim).
    expect(server.hasSession, isFalse);
  });
}
