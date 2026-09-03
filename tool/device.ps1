# Build, install and launch a debug build wired to the real backend.
#
# Exists because the App Check debug secret is a credential and therefore lives
# outside git (`.appcheck_token`), which means every device command needs the
# same --dart-define and forgetting it silently reverts to a rotating token —
# the exact failure this whole setup is here to end.
#
#   ./tool/device.ps1                       # build + install + launch
#   ./tool/device.ps1 -Backend fake         # demo backend instead
#   ./tool/device.ps1 -Test                 # run the on-device E2E suites
#   ./tool/device.ps1 -Analytics            # ...with the analytics funnel live
#   ./tool/device.ps1 -ReRegister           # console entry deleted; register again
#
# Equivalent by hand, if you ever need it. The defines file is written by this
# script and is what the Android Studio run configuration points at, so the
# green Run button and this script build the same thing:
#
#   flutter run -d <device> --dart-define-from-file=.dart_defines.json
#
# ============================================================================
# A SIDELOADED RELEASE APK CANNOT PASS APP CHECK. Not with any combination of
# defines. This has cost more than one session, so it is written out in full:
#
#   flutter build apk --release --dart-define-from-file=.dart_defines.json
#
# ...looks correct and is not. `kDebugMode` is false in a release build, so
# the pinned token is read into a constant nothing consults and the app
# attests with PLAY INTEGRITY instead. Play Integrity cannot vouch for an APK
# Google has never seen, so no token is minted, and the backend rejects EVERY
# callable with `Decoding App Check token failed` - the coach, panic,
# community, testimonials and user sync all break at once and none of it looks
# like App Check. `activateAppCheck()` now says so out loud at launch.
#
# The two things that DO work:
#
#   * this script, for anything you would sideload for;
#   * the Play internal testing track, for a genuine release build - install it
#     from Play, with the Play app-signing SHA-256 registered in Firebase.
#
# Analytics is not a reason to build release: `LP_ANALYTICS=on` overrides the
# `kReleaseMode` check in any build mode, which is what -Analytics passes.
# ============================================================================
#
#   flutter build appbundle --release       # Play Store (no defines needed)
#
param(
  [string]$Device  = '',
  [ValidateSet('firebase', 'fake')]
  [string]$Backend = 'firebase',
  [switch]$Test,
  # Re-register the App Check token even if this checkout already did. Use it
  # when the console entry has been deleted.
  [switch]$ReRegister,
  # Send analytics from this debug build. `analyticsEnabled()` is
  # `kReleaseMode`-only by default so a dev build never appears in the launch
  # funnel as a user; this is the sanctioned override for verifying the
  # integration. It exists so that wanting analytics on device is never a
  # reason to build release - which is what breaks App Check.
  [switch]$Analytics
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$appId = '1:826701239342:android:6f8f39f49c52ee24e4bbbf'
$project = 'alastpuff'

function Invoke-Firebase {
  param([string[]]$FbArgs)
  if (Get-Command firebase -ErrorAction SilentlyContinue) { & firebase @FbArgs }
  else { & npx --yes firebase-tools @FbArgs }
}

# The token file, and - the part that was missing - proof that the token in it
# has actually been registered.
#
# Checking only that the FILE exists is what cost hours: a token that was never
# registered, or that was deleted from the console afterwards, leaves a file
# sitting there looking correct while every callable comes back 403. App Check
# rejects at the SERVER, so the client sails on and the symptom is an app where
# nothing writes to Firestore and nothing says why.
#
# It cannot be verified by asking. `debugtokens:list` returns resource ids, NOT
# token values - the values are secrets and are never echoed back - so there is
# no query that answers "is this token registered". The only reliable move is
# to register it, which `--force` makes idempotent: it replaces the entry with
# the same display name rather than adding one.
#
# A local marker records what has been registered from this checkout, so the
# round trip happens when the token CHANGES rather than on every launch. Delete
# the marker (or pass -ReRegister) to force it, which is what you want if the
# console entry was removed.
$tokenFile = Join-Path $root '.appcheck_token'
if (-not (Test-Path $tokenFile)) {
  Write-Host 'No .appcheck_token - minting one.' -ForegroundColor Yellow
  [guid]::NewGuid().ToString() | Set-Content -NoNewline $tokenFile
}
$token = (Get-Content $tokenFile -Raw).Trim()

# Written for the IDE. Android Studio's green Run button passes whatever is in
# its run configuration and nothing else, so a config with no args produces a
# build with no App Check token - a fresh rotating secret, unregistered by
# construction, and every callable 403s. Pointing the config at this file
# instead of hardcoding the token keeps the secret out of .idea and keeps one
# source of truth: this script.
$definesFile = Join-Path $root '.dart_defines.json'
@{ LP_APPCHECK_DEBUG_TOKEN = $token } | ConvertTo-Json | Set-Content $definesFile

$markerFile = Join-Path $root '.appcheck_token.registered'
$marker = if (Test-Path $markerFile) { (Get-Content $markerFile -Raw).Trim() } else { '' }

if ($ReRegister -or $marker -ne $token) {
  Write-Host "Registering App Check debug token $token" -ForegroundColor Yellow
  Invoke-Firebase @(
    'appcheck:debugtokens:create', $token,
    '--project', $project, '--app', $appId, '--force'
  )
  # The client backs off after repeated rejections ("Too many attempts") and
  # that backoff outlives a hot restart, so a token registered while the app is
  # already installed does not take effect until a fresh install.
  Write-Host 'Uninstalling so the client drops its App Check backoff.' -ForegroundColor Yellow
  adb uninstall com.quitvape.last_puff 2>&1 | Out-Null
  Set-Content -NoNewline $markerFile $token
}

if (-not $Device) {
  # First attached device that is not the loopback line.
  $Device = (adb devices | Select-Object -Skip 1 |
             Where-Object { $_ -match '\sdevice$' } |
             ForEach-Object { ($_ -split '\s+')[0] } |
             Select-Object -First 1)
  if (-not $Device) { Write-Error 'No adb device attached.' }
}

$defines = @(
  "--dart-define=LP_BACKEND=$Backend",
  "--dart-define-from-file=$definesFile"
)
if ($Analytics) { $defines += '--dart-define=LP_ANALYTICS=on' }

$analyticsLabel = if ($Analytics) { 'on' } else { 'off (pass -Analytics)' }
Write-Host "device=$Device backend=$Backend analytics=$analyticsLabel" -ForegroundColor Cyan

if ($Test) {
  # Note: `flutter test integration_test` uninstalls the app when it finishes.
  # That used to destroy the App Check secret; with a pinned token it no longer
  # matters, which is the whole point of the pin.
  flutter test integration_test -d $Device @defines
} else {
  flutter run -d $Device @defines
}
