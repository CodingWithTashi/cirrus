import '../../domain/models/models.dart';

/// Decode-only: testimonials are authored server-side and never travel back.
///
/// Not part of `JourneyCodec`, so the five-way codec rule does not apply — this
/// is not a field on `journeys/{uid}` and there is no `journeyCodec.ts`
/// counterpart to keep in step.
abstract final class TestimonialCodec {
  /// Skips any row missing an id or text rather than throwing: a malformed row
  /// should cost one quote, not the screen.
  static List<Testimonial> decodeList(Object? raw) {
    if (raw is! List) return const [];
    final out = <Testimonial>[];
    for (final row in raw) {
      if (row is! Map) continue;
      final id = row['id'];
      final text = row['text'];
      if (id is! String || text is! String) continue;
      if (id.isEmpty || text.trim().isEmpty) continue;
      out.add(Testimonial(id: id, text: text.trim()));
    }
    return out;
  }
}
