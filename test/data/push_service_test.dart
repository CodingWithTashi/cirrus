import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/api/firebase/push_service.dart';

/// `PushService.routeFor` — the one piece of untrusted-input parsing on the
/// client side of push.
///
/// A route in a payload is an instruction, and an instruction taken from a
/// payload should only ever be one we chose to accept. Today the sender is
/// ours; this pins the allow-list for the day it is not, and against the
/// quieter failure of a typo'd route silently opening nothing.
void main() {
  const allowed = {'/community', '/insight', '/coach', '/home'};

  RemoteMessage msg(Object? route) =>
      RemoteMessage(data: {'route': ?route});

  test('an allow-listed route passes through verbatim', () {
    expect(PushService.routeFor(msg('/community'), allowed), '/community');
    expect(PushService.routeFor(msg('/insight'), allowed), '/insight');
  });

  test('a subpath of an allowed route passes', () {
    expect(
      PushService.routeFor(msg('/community/abc123'), allowed),
      '/community/abc123',
    );
  });

  test('a prefix that is not a path boundary does not pass', () {
    // startsWith on the raw string would accept this; the '$a/' form is why
    // it must not.
    expect(PushService.routeFor(msg('/communityevil'), allowed), isNull);
  });

  test('an unlisted route is refused', () {
    expect(PushService.routeFor(msg('/settings'), allowed), isNull);
    expect(PushService.routeFor(msg('/moderation'), allowed), isNull);
  });

  test('no route, an empty route, and a non-string route are refused', () {
    expect(PushService.routeFor(msg(null), allowed), isNull);
    expect(PushService.routeFor(msg(''), allowed), isNull);
    expect(PushService.routeFor(msg(42), allowed), isNull);
  });

  test('garbage that does not parse as a URI is refused', () {
    expect(PushService.routeFor(msg('::not a uri::'), allowed), isNull);
  });
}
