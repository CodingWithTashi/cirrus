import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/models/onboarding_draft.dart';

/// Where the store-rating ask is allowed to live.
///
/// App Store review rejected build 1.0.16 on Sep 11 2026 under Guideline
/// 5.6.3: "The app requests users to rate the app on first launch or during
/// onboarding, before they've had enough time to gain a clear understanding
/// of the app's value." The ask was onboarding step D3 — a spec placement
/// (docs/02 §3) that the guideline forbids outright. It is on the Survived
/// screen now, behind `ReviewAskPolicy`, and Settings carries a row the person
/// taps themselves.
///
/// This test reads the sources so the step cannot quietly come back: not as
/// an `ObStep`, not as an import, and not as a `requestReview` call anywhere
/// under the onboarding or auth folders.
void main() {
  test('onboarding has no rating step', () {
    expect(ObStep.values.map((s) => s.name), isNot(contains('rating')));
  });

  test('nothing in onboarding, auth or day 1 reaches the review API', () {
    final offenders = <String>[];
    for (final folder in [
      'lib/features/onboarding',
      'lib/features/auth',
      'lib/features/day1',
    ]) {
      final dir = Directory(folder);
      if (!dir.existsSync()) continue;
      for (final file in dir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        if (source.contains('lp_review.dart') ||
            source.contains('in_app_review') ||
            source.contains('InAppReview') ||
            source.contains('reviewRouteProvider') ||
            source.contains('requestReview')) {
          offenders.add(file.path);
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'a rating ask on first launch or during onboarding is an App Store '
          'rejection (Guideline 5.6.3, Sep 11 2026). The ask lives on the '
          'Survived screen behind ReviewAskPolicy.',
    );
  });

  test('the only unprompted ask is the Survived screen, behind the policy', () {
    final callers = <String>[];
    for (final file in Directory(
      'lib/features',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      if (file.readAsStringSync().contains('LpReview.request(')) {
        callers.add(file.path.replaceAll(r'\', '/'));
      }
    }
    expect(callers, ['lib/features/panic/panic_screens.dart']);
    expect(
      File('lib/features/panic/panic_screens.dart').readAsStringSync(),
      contains('ReviewAskPolicy.shouldAsk('),
    );
  });
}
