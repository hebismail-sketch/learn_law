# One command to repeat the release checks before every upload.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\release_preflight.ps1
#
# Fails fast. Never prints a secret. It does NOT build by itself: run
# `flutter build appbundle --release` first (or pass -Build).
param([switch]$Build)

$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location $root
try {
  Write-Output '== 1/6  Secrets are not in git ================================'
  $bad = @()
  foreach ($pattern in @('android/key.properties', 'android/*.jks', 'android/app/*.jks',
                         'key.properties', '*.jks', '*.keystore', '.env', '.env.*')) {
    $tracked = git ls-files -- $pattern
    if ($tracked) { $bad += $tracked }
  }
  if ($bad.Count -gt 0) { throw "Tracked secret files: $($bad -join ', ')" }
  Write-Output 'OK - no keystore, key.properties or .env is tracked.'

  Write-Output ''
  Write-Output '== 2/6  Upload keystore ======================================='
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'verify_upload_keystore.ps1')

  Write-Output ''
  Write-Output '== 3/6  Static analysis ======================================='
  $analysis = flutter analyze 2>&1 | Out-String
  $analysis | Select-Object -Last 2
  if ($analysis -notmatch 'No issues found') { throw 'flutter analyze reported issues.' }

  Write-Output ''
  Write-Output '== 4/6  Tests ================================================'
  $tests = flutter test 2>&1 | Out-String
  ($tests -split "`n" | Select-Object -Last 2) -join ''
  if ($tests -notmatch 'All tests passed') { throw 'flutter test failed.' }

  if ($Build) {
    Write-Output ''
    Write-Output '== 5/6  Release bundle ======================================='
    flutter build appbundle --release
  } else {
    Write-Output ''
    Write-Output '== 5/6  Release bundle (skipped, pass -Build) ================='
  }

  Write-Output ''
  Write-Output '== 6/6  Bundle verification =================================='
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'verify_aab.ps1')

  Write-Output ''
  Write-Output 'Preflight passed.'
  Write-Output 'Remaining manual steps: Play Console upload, Data Safety form,'
  Write-Output 'App Access credentials, content rating. See docs/play-console-checklist.md.'
} finally {
  Pop-Location
}
