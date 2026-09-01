/// The client-side half of the community policy (docs/03 §9): brand praise
/// and sourcing are held before they leave the device.
///
/// Lives in the domain so the fake backend can apply the same rule the store
/// does — the real backend classifies server-side (`moderatePost`), and a
/// demo backend that published what production would hold taught the wrong
/// lesson about what "Posted." means.
abstract final class CommunityRules {
  static const _banned = [
    'elfbar',
    'elf bar',
    'geekbar',
    'geek bar',
    'juul',
    'vuse',
    'lostmary',
    'lost mary',
    'where to buy',
    'for sale',
    'plug for',
    'best flavor to buy',
  ];

  static bool violates(String text) {
    final t = text.toLowerCase();
    return _banned.any(t.contains);
  }
}
