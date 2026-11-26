/// The demo backend's coach cards: two of the server's own answers, copied.
///
/// The real decision is `planBlocks` in `functions/src/ai/coachUi.ts`, pinned
/// to the fixture files in `functions/test/fixtures/coach_ui/`. This is not a
/// second policy. It holds the `blocks` of two of those files as const data,
/// and `test/data/fake_coach_ui_test.dart` reads the files to keep them
/// copies, and checks the function below against every fixture it can
/// answer.
///
/// What it leaves out, because the fake has nothing to read them from: the
/// craving history (the server leads with the tool somebody used last) and
/// the audience param (the server can widen cards to free accounts). So the
/// fake always behaves like a first craving on the default audience.
library;

/// Fixture name → that fixture's `blocks`, as they travel on the wire.
const Map<String, List<Map<String, String>>> fakeCoachUi = {
  // In a craving: one next step.
  'panic_default': [
    {'t': 'launcher', 'exercise': 'breathing'},
  ],
  // The craving chip, from outside one: the menu, one of each kind.
  'craving_chip': [
    {'t': 'launcher', 'exercise': 'breathing'},
    {'t': 'launcher', 'exercise': 'orbs'},
    {'t': 'launcher', 'exercise': 'sos'},
  ],
};

/// The cards the demo backend puts under its reply to [request], for an
/// account on [tier] (the fake's own entitlement row, never the client's
/// word for it).
///
/// Nothing unless the app said what it can draw (`request['ui']`: an older
/// build and the Day-1 walkthrough's coach step say nothing) and the account
/// pays (`premium` or `trial`). One card in a craving (`panicIntensity` set,
/// or `ui.craving`); the menu for the craving chip; nothing otherwise. And
/// never a card the app did not advertise.
List<Map<String, String>> fakeBlocksFor({
  required Map<String, dynamic> request,
  required String? tier,
}) {
  final ui = request['ui'];
  if (ui is! Map) return const [];
  if (tier != 'premium' && tier != 'trial') return const [];
  final advertised = ui['exercises'];
  if (advertised is! List) return const [];

  final inCraving = request['panicIntensity'] != null || ui['craving'] == true;
  final blocks = inCraving
      ? fakeCoachUi['panic_default']!
      : request['chip'] == 'craving'
      ? fakeCoachUi['craving_chip']!
      : const <Map<String, String>>[];
  return [
    for (final block in blocks)
      if (advertised.contains(block['exercise'])) block,
  ];
}
