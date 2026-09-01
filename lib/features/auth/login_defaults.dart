import '../../data/api/fake/fake_server.dart';
import '../../data/backend_mode.dart';

/// What the sign-in forms start with.
///
/// The demo identity (`maya@quitmail.com`, the seeded day-12 journey) is a
/// convenience of the fake backend and belongs to it alone. It shipped
/// pre-filled in the production build's login form (QA L3, Aug 31 2026) —
/// a fixture's email in front of every real user, on the one screen that
/// asks for theirs.
abstract final class LoginDefaults {
  static String email(BackendMode backend) => switch (backend) {
    BackendMode.fake => FakeServer.demoEmail,
    BackendMode.firebase => '',
  };
}
