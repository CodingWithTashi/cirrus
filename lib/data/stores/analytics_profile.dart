import '../../domain/analytics/analytics.dart';

/// The person's standing facts on the analytics user (docs/10 §58.5), sent
/// only when one of them changes.
///
/// Callers report what they know as often as they like — every launch, every
/// resume — and only a changed value reaches the vendors, so a resume costs
/// nothing when nothing moved. [forget] is for a change of person: a sign-out
/// resets the vendor identity, so every value the last account already had is
/// news to the next one.
final class AnalyticsProfile {
  AnalyticsProfile(this._sink);

  final AnalyticsSink _sink;
  final Map<String, Object> _sent = {};

  void report(Map<String, Object> values) {
    final changed = {
      for (final MapEntry(:key, :value) in values.entries)
        if (_sent[key] != value) key: value,
    };
    if (changed.isEmpty) return;
    _sent.addAll(changed);
    _sink.setUserProperties(changed);
  }

  void forget() => _sent.clear();
}
