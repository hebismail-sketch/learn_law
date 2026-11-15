# Verifies a built release AAB without printing any secret.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_aab.ps1
$ErrorActionPreference = 'Stop'

$aab = Join-Path $PSScriptRoot '..\build\app\outputs\bundle\release\app-release.aab'
$aab = [System.IO.Path]::GetFullPath($aab)
if (-not (Test-Path $aab)) { throw "Missing $aab" }


$jarsigner = $null
if ($env:JAVA_HOME) { $jarsigner = Join-Path $env:JAVA_HOME 'bin\jarsigner.exe' }
foreach ($candidate in @($jarsigner, 'C:\Program Files\Java\jdk-17\bin\jarsigner.exe')) {
  if ($candidate -and (Test-Path $candidate)) { $jarsigner = $candidate; break }
}
if (-not $jarsigner -or -not (Test-Path $jarsigner)) {
  $jarsigner = (Get-Command jarsigner -ErrorAction SilentlyContinue).Source
}
if (-not $jarsigner) { throw 'jarsigner not found' }

Write-Output "== Signature =="
& $jarsigner -verify -verbose:summary $aab | Select-String -Pattern 'jar verified|CN=|SHA-256 digest|warning' | Select-Object -First 12

Write-Output "== Signing certificate =="
& $jarsigner -verify -certs -verbose $aab 2>&1 |
  Select-String -Pattern 'CN=.*,$|Signature algorithm|X.509, CN' | Select-Object -First 6

Write-Output "== Bundle contents (key files) =="
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($aab)
try {
  $zip.Entries | Where-Object {
    $_.FullName -match '^(AndroidManifest\.xml|META-INF/.*\.(RSA|SF|MF)|base/manifest/AndroidManifest\.xml|BundleConfig\.pb|base/lib/)' -or
    $_.FullName -match 'files/arm64_v8a|files/armeabi|files/x86_64'
  } | Select-Object -First 40 | ForEach-Object { '{0,12} {1}' -f $_.Length, $_.FullName }
  Write-Output ("total entries: {0}" -f $zip.Entries.Count)
  Write-Output ("native libs: " + (($zip.Entries | Where-Object { $_.FullName -like 'base/lib/*/*.so' }).Count))
} finally { $zip.Dispose() }

Write-Output "== Size =="
'{0:N1} MB' -f ((Get-Item $aab).Length / 1MB)