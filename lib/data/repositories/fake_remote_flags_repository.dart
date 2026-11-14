import '../../domain/repositories/repositories.dart';

/// Remote Config for the fake backend and for tests.
///
/// The fake backend answers [RemoteFlags.none] — nothing forced, no notes —
/// which is also what a real device answers whenever Remote Config cannot be
/// reached. A test sets [flags] to the console it wants, or [fails] to watch
/// the app fail open.
class FakeRemoteFlagsRepository implements RemoteFlagsRepository {
  FakeRemoteFlagsRepository({
    this.flags = RemoteFlags.none,
    this.fails = false,
  });

  RemoteFlags flags;

  /// Simulates an unreachable Remote Config. Answers what the Firebase
  /// repository answers then: no force, whatever notes were cached.
  bool fails;

  int fetches = 0;

  @override
  Future<RemoteFlags> fetch() async {
    fetches++;
    if (fails) return RemoteFlags(releaseNotes: flags.releaseNotes);
    return flags;
  }
}
