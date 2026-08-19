import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/logic/journey_factory.dart';
import '../../domain/models/journey_state.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../dto/journey_codec.dart';
import 'firebase_common.dart';

/// [JourneyRepository] over the journeys collection, keyed by the signed-in
/// Firebase uid.
class FirebaseJourneyRepository implements JourneyRepository {
  FirebaseJourneyRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  @override
  Future<JourneyState> create({
    required UserProfile profile,
    required QuitPlan plan,
  }) => guardAuth(() async {
    // Pre-auth onboarding (Frame Map, onboarding straight from sign-in)
    // gets an anonymous account — the Firebase analogue of the fake's guest
    // session; linking it to a real account at register is a follow-up.
    final user = _auth.currentUser ?? (await _auth.signInAnonymously()).user!;
    final journey = InitialJourney.build(
      profile: profile,
      plan: plan,
      now: DateTime.now(),
    );
    await journeyDoc(_db, user.uid).set(JourneyCodec.encode(journey));
    return journey;
  });

  @override
  Future<void> save(JourneyState journey) async {
    final user = _auth.currentUser;
    // Signed-out writes (seedDemoJourney on device) fail quietly into the
    // store's write-behind `.ignore()`.
    if (user == null) throw StateError('no signed-in account');
    await journeyDoc(_db, user.uid).set(JourneyCodec.encode(journey));
  }

  @override
  Future<void> delete() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await journeyDoc(_db, user.uid).delete();
  }
}
