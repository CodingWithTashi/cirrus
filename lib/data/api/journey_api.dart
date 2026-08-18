/// Wire-level journey endpoints. JSON in/out.
abstract interface class JourneyApi {
  /// The server creates the initial journey from onboarding output (day-0 log
  /// at the curve limit, onboarding goal, buddy assignment) and returns it.
  Future<Map<String, dynamic>> createJourney({
    required Map<String, dynamic> profile,
    required Map<String, dynamic> plan,
  });

  /// Write-behind upsert of the whole journey document (Firestore-style).
  Future<void> saveJourney(Map<String, dynamic> journey);

  Future<void> deleteJourney();
}
