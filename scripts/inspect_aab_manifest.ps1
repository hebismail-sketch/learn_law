# Prints the parts of the merged release manifest that matter for Google Play
# and for app security: package, SDK levels, permissions, exported components,
# backup flags, AdMob app id. No secret is printed.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\inspect_aab_manifest.ps1
$ErrorActionPreference = 'Stop'

$repo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$aapt2 = Get-ChildItem 'C:\Users\*\AppData\Local\Android\sdk\build-tools\*\aapt2.exe' -ErrorAction SilentlyContinue |
  Sort-Object FullName -Descending | Select-Object -First 1
if (-not $aapt2) { throw 'aapt2.exe not found in the Android SDK build-tools.' }

$merged = Join-Path $repo 'build\app\intermediates\merged_manifest\release\processReleaseMainManifest\AndroidManifest.xml'
if (-not (Test-Path $merged)) {
  $merged = Join-Path $repo 'build\app\intermediates\merged_manifest\release\AndroidManifest.xml'
}
if (-not (Test-Path $merged)) { throw 'Merged release manifest not found; run flutter build appbundle --release first.' }

# Native tools write their banner to stderr; keep it from aborting the script.
$ErrorActionPreference = 'Continue'

Write-Output '== Badging =='
& $aapt2.FullName dump badging $merged |
  Select-String -Pattern "^package:|sdkVersion|targetSdkVersion|application-label|uses-permission|uses-feature" |
  ForEach-Object { $_.Line }

Write-Output ''
Write-Output '== Components that could expose the app =='
& $aapt2.FullName dump xmltree --file AndroidManifest.xml $merged |
  Select-String -Pattern 'E: (activity|service|receiver|provider)|A: android:exported|A: android:permission|A: android:allowBackup|A: android:debuggable|A: android:usesCleartextTraffic|A: android:dataExtractionRules|A: android:fullBackupContent|APPLICATION_ID' |
  ForEach-Object { $_.Line.Trim() }
