import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/core/widgets/lp_error.dart';
import 'package:last_puff/data/api/firebase/functions_client.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// A backend that refuses the *app* must never wear the offline costume.
///
/// This is the regression net for the failure that made the whole product look
/// dead: a rotated App Check debug secret meant every callable answered
/// `unauthenticated`, the client filed that under "you're offline", and the
/// coach told users who were demonstrably online to try again once they
/// reconnected. Coach, panic, community and user-sync all died at the same
/// gate, and nothing on screen or in the taxonomy ever said the real cause.
///
/// Every case here fails against the pre-fix mapping.
class _Fx extends FirebaseFunctionsException {
  _Fx(String code, {super.message = 'test'}) : super(code: code);
}

class _RejectingCoach implements CoachRepository {
  @override
  Stream<CoachEvent> streamReply({
    String? text,
    CoachChip? chip,
    required bool capped,
    int? panicIntensity,
  }) async* {
    throw const BackendRejectedException();
  }

  @override
  Future<List<CoachMessage>> history() async => const [];

  @override
  Future<List<CoachMemory>> memories() async => const [];

  @override
  Future<void> seedMemories() async {}

  @override
  Future<void> forgetMemory(String id) async {}
}

void main() {
  group('callable error mapping', () {
    test('a signed-in caller refused with `unauthenticated` is App Check', () {
      // The gen-2 callable answers a failed App Check with the same code it
      // uses for a missing user, so being signed in is the only thing that
      // separates them.
      expect(
        mapCallableError(_Fx('unauthenticated'), signedIn: true),
        isA<BackendRejectedException>(),
      );
    });

    test('a signed-out caller refused the same way is a credentials problem', () {
      expect(
        mapCallableError(_Fx('unauthenticated'), signedIn: false),
        isA<InvalidCredentialsException>(),
      );
    });

    test('permission-denied is a rejection, never an outage', () {
      expect(
        mapCallableError(_Fx('permission-denied'), signedIn: true),
        isA<BackendRejectedException>(),
      );
    });

    test('genuinely offline codes still map to offline', () {
      expect(
        mapCallableError(_Fx('unavailable'), signedIn: true),
        isA<NoConnectionException>(),
      );
      expect(
        mapCallableError(_Fx('deadline-exceeded'), signedIn: false),
        isA<NoConnectionException>(),
      );
    });

    test('an unrecognised code is passed through, not guessed at', () {
      expect(
        mapCallableError(_Fx('resource-exhausted'), signedIn: true),
        isA<FirebaseFunctionsException>(),
      );
    });

    group('a streamed failure that lost its code', () {
      // iPhone 15 simulator, Sep 2 2026: an unregistered App Check debug
      // token. `syncUserContext` (plain call) said "this build got bounced";
      // the coach (streaming call) said "signal dropped" for the SAME
      // refusal, because the plugin's Apple stream handler emits every error
      // as `unknown` with only the SDK's localizedDescription attached.
      test('"Unauthenticated" in the words is App Check when signed in', () {
        for (final message in ['Unauthenticated', 'UNAUTHENTICATED']) {
          expect(
            mapCallableError(_Fx('unknown', message: message), signedIn: true),
            isA<BackendRejectedException>(),
            reason: message,
          );
          expect(
            mapCallableError(_Fx('unknown', message: message), signedIn: false),
            isA<InvalidCredentialsException>(),
            reason: message,
          );
        }
      });

      test('a permission refusal is a rejection', () {
        expect(
          mapCallableError(
            _Fx('unknown', message: 'PERMISSION_DENIED'),
            signedIn: true,
          ),
          isA<BackendRejectedException>(),
        );
      });

      test('a dead link described in words is still offline', () {
        for (final message in [
          'The Internet connection appears to be offline.',
          'The network connection was lost.',
          'The request timed out.',
          'UNAVAILABLE',
        ]) {
          expect(
            mapCallableError(_Fx('unknown', message: message), signedIn: true),
            isA<NoConnectionException>(),
            reason: message,
          );
        }
      });

      test('words that name nothing stay unknown', () {
        expect(
          mapCallableError(_Fx('unknown', message: 'INTERNAL'), signedIn: true),
          isA<FirebaseFunctionsException>(),
        );
      });

      test('a real code is never second-guessed by its words', () {
        // The message says "unauthenticated" but the code is authoritative.
        expect(
          mapCallableError(
            _Fx('resource-exhausted', message: 'unauthenticated?'),
            signedIn: true,
          ),
          isA<FirebaseFunctionsException>(),
        );
      });
    });
  });

  testWidgets('a refused build does not read as "check your wifi"', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final rejected = lpErrorCopy(ctx, const BackendRejectedException());
    final offline = lpErrorCopy(ctx, const NoConnectionException());
    final generic = lpErrorCopy(ctx, StateError('boom'));

    // Its own voice: not the offline copy, and not the anonymous generic one.
    expect(rejected.title, isNot(offline.title));
    expect(rejected.title, isNot(generic.title));
    // And it must not send the user to fix a connection that is already fine.
    expect(rejected.body.toLowerCase(), isNot(contains('offline')));
  });

  test('Ember says the truth when the backend refuses the build', () async {
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        coachRepositoryProvider.overrideWithValue(_RejectingCoach()),
      ],
    );
    addTearDown(container.dispose);
    container.read(quitStoreProvider.notifier).seedDemoJourney();

    await container.read(coachStoreProvider.notifier).send('craving hard');

    final coach = container.read(coachStoreProvider);
    expect(coach.isTyping, isFalse);
    // Still refunded — the user's message never reached a model.
    expect(coach.freeUsedToday, 0);
    expect(coach.messages.last.template, CoachTemplate.backendRejected);
    expect(
      coach.messages.last.template,
      isNot(CoachTemplate.connectionLost),
      reason: 'a refused build is not a lost signal',
    );
  });
}
