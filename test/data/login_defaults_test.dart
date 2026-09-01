import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/backend_mode.dart';
import 'package:last_puff/features/auth/login_defaults.dart';

/// QA L3 (Aug 31 2026, production): the login form arrived pre-filled with
/// `maya@quitmail.com` — the fake backend's demo identity — in the
/// production build. The prefill is a demo convenience and belongs to the
/// demo backend only.
void main() {
  test('the demo email prefills only on the fake backend', () {
    expect(LoginDefaults.email(BackendMode.fake), 'maya@quitmail.com');
    expect(LoginDefaults.email(BackendMode.firebase), '');
  });
}
