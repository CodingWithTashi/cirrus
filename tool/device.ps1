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
#
param(
  [string]$Device  = '',
  [ValidateSet('firebase', 'fake')]
  [string]$Backend = 'firebase',
  [switch]$Test
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$tokenFile = Join-Path $root '.appcheck_token'
if (-not (Test-Path $tokenFile)) {
  Write-Error @"
No .appcheck_token found.

Create one and register it once (any UUID works):
  [guid]::NewGuid().ToString() | Set-Content -NoNewline .appcheck_token
  firebase appcheck:debugtokens:create (Get-Content .appcheck_token) ``
    --project alastpuff ``
    --app 1:826701239342:android:6f8f39f49c52ee24e4bbbf --force
"@
}
$token = (Get-Content $tokenFile -Raw).Trim()

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
  "--dart-define=LP_APPCHECK_DEBUG_TOKEN=$token"
)

Write-Host "device=$Device backend=$Backend" -ForegroundColor Cyan

if ($Test) {
  # Note: `flutter test integration_test` uninstalls the app when it finishes.
  # That used to destroy the App Check secret; with a pinned token it no longer
  # matters, which is the whole point of the pin.
  flutter test integration_test -d $Device @defines
} else {
  flutter run -d $Device @defines
}
