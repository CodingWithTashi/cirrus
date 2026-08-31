import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/core/utils/lp_format.dart';

void main() {
  group('compactAgo', () {
    test('buckets minutes, hours, then days', () {
      expect(LpFormat.compactAgo(const Duration(minutes: 38)), '38m');
      expect(LpFormat.compactAgo(const Duration(hours: 14)), '14h');
      // A three-day-old post used to read "72h", which nobody says.
      expect(LpFormat.compactAgo(const Duration(days: 3)), '3d');
    });

    test('truncates instead of rounding up at each boundary', () {
      expect(LpFormat.compactAgo(const Duration(minutes: 59)), '59m');
      expect(LpFormat.compactAgo(const Duration(hours: 23, minutes: 59)), '23h');
      expect(LpFormat.compactAgo(const Duration(hours: 24)), '1d');
    });

    test('keeps hours past 24 when the day bucket is off (Health timeline)', () {
      // 24h/48h/72h milestones: "71h" says one hour to the node; "2d" hides it.
      expect(
        LpFormat.compactAgo(const Duration(hours: 71), dayBucket: false),
        '71h',
      );
    });
  });
}
