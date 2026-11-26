/// Wire-level coach endpoint. The request carries the user's words
/// (`{'text': …}` or `{'chip': name}`) plus `{'capped': bool}`, and when they
/// apply `panicIntensity`, `ui` (what this build can draw, and whether the
/// message is sent from inside a craving) and `justDid` (the exercise they
/// just finished). The response is a reply envelope (`template`, `args`,
/// `showWeekCard`, and `ui` when the reply carries cards). The fake backend
/// scripts the decision; the Gemini flow (docs/04) answers the same contract.
abstract interface class CoachApi {
  Future<Map<String, dynamic>> requestReply(Map<String, dynamic> request);
}
