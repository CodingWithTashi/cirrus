import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../api/firebase/functions_client.dart';
import '../dto/testimonial_codec.dart';

/// Calls `matchedTestimonials`. Like every other callable, only through
/// [LpFunctions] — it injects the locale the server picks the language from.
class FirebaseTestimonialsRepository implements TestimonialsRepository {
  FirebaseTestimonialsRepository({LpFunctions? functions})
    : _functions = functions ?? LpFunctions();

  final LpFunctions _functions;

  @override
  Future<List<Testimonial>> matched({
    required Set<WhyChip> whys,
    required Set<WorryChip> worries,
    QuitAttempts? attempts,
    Gender? gender,
    required DependenceLevel dependence,
  }) async {
    final result = await _functions.call('matchedTestimonials', {
      'whys': whys.map((w) => w.name).toList(),
      'worries': worries.map((w) => w.name).toList(),
      'attempts': ?attempts?.name,
      'gender': ?gender?.name,
      'dependence': dependence.name,
    });
    return TestimonialCodec.decodeList(result['testimonials']);
  }
}

/// The fake backend has no testimonial store, so the view keeps the bundled
/// quotes — which is also exactly what a real user sees offline.
class NoopTestimonialsRepository implements TestimonialsRepository {
  const NoopTestimonialsRepository();

  @override
  Future<List<Testimonial>> matched({
    required Set<WhyChip> whys,
    required Set<WorryChip> worries,
    QuitAttempts? attempts,
    Gender? gender,
    required DependenceLevel dependence,
  }) async => const [];
}
