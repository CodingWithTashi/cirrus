/// Wire-level coach endpoint. The request carries the user's words
/// (`{'text': …}` or `{'chip': name}`) plus `{'capped': bool}`; the response
/// is a reply envelope (`template`, `args`, `showWeekCard`). The fake backend
/// scripts the decision; the Gemini flow (docs/04) answers the same contract.
abstract interface class CoachApi {
  Future<Map<String, dynamic>> requestReply(Map<String, dynamic> request);
}
