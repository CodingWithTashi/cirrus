import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// App Check is the single point that breaks *everything* at once, and its
/// failure never looks like itself.
///
/// The shape, every time: a build cannot obtain a token, the client sails on
/// because App Check rejects at the SERVER, and every callable comes back
/// `unauthenticated` — coach, panic, community, testimonials, user sync — each
/// wearing an error that reads like the network. Nothing on screen says "App
/// Check". The only thing that ever shortens the hunt is a line at launch.
///
/// Two ways that line has gone missing, both of which cost a session:
///
/// 1. `logAppCheckStatus()` opened with `if (!kDebugMode) return;`, so the one
///    diagnostic written for this was switched off in the build that fails
///    most confusingly. A release APK built locally and sideloaded cannot get
///    a token at all, and said nothing about it.
/// 2. Passing `--dart-define-from-file=.dart_defines.json` to a `--release`
///    build LOOKS right — it is the same file `./tool/device.ps1` writes — but
///    `kDebugMode` is false there, so the pinned token is read into a constant
///    nothing consults and the app attests with Play Integrity, which cannot
///    vouch for an APK Google has never seen.
///
/// Source inspection rather than behaviour, for the same reason
/// `android_manifest_test.dart` reads the manifest: the failure is a build
/// mode, and a widget test always runs in exactly one of them.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/data/api/firebase/app_check_setup.dart').readAsStringSync();
  });

  test('the token diagnostic is not gated to debug builds', () {
    final body = source.substring(source.indexOf('Future<void> logAppCheckStatus'));
    expect(
      body.contains('if (!kDebugMode) return;'),
      isFalse,
      reason:
          'logAppCheckStatus() must run in EVERY build mode. Gating it to '
          'debug switches the diagnostic off in the build that needs it most: '
          'a sideloaded release APK cannot obtain a token, and without this '
          'line it fails every callable in total silence.',
    );
  });

  test('a debug token handed to a non-debug build says so out loud', () {
    expect(
      source.contains('if (!kDebugMode && token.isNotEmpty)'),
      isTrue,
      reason:
          'The command `flutter build apk --release '
          '--dart-define-from-file=.dart_defines.json` looks correct and is '
          'not: the token is ignored and Play Integrity takes over. That has '
          'to be announced, or it is rediscovered from first principles every '
          'time.',
    );
    // Naming the way out matters as much as naming the fault — the whole
    // point is that the reader should not have to work out what to do next.
    expect(source, contains('./tool/device.ps1'));
    expect(source, contains('Play internal testing'));
  });

  test('the debug provider is still confined to debug builds', () {
    // The fix for the above must never become "let release use the debug
    // token". A registered debug token bypasses attestation project-wide, so
    // it is a credential; shipping one in a release binary hands anyone who
    // unzips the APK a free pass to every callable.
    expect(source, contains('providerAndroid: kDebugMode'));
    expect(source, contains('providerApple: kDebugMode'));
    expect(source, contains('AndroidPlayIntegrityProvider()'));
    expect(source, contains('AppleAppAttestProvider()'));
  });

  test('the device launcher offers analytics, so release is never the reason', () {
    // `analyticsEnabled()` is `kReleaseMode`-only by default, which is why
    // wanting the funnel on device used to send people to `--release` — and
    // that is what breaks App Check. `-Analytics` is the sanctioned override.
    final script = File('tool/device.ps1').readAsStringSync();
    expect(script, contains(r'[switch]$Analytics'));
    expect(script, contains('LP_ANALYTICS=on'));
  });
}
