# Verifies the upload keystore without printing any password.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_upload_keystore.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_upload_keystore.ps1 `
#     -Keystore C:\restore\android\upload-keystore.jks -KeyProperties C:\restore\android\key.properties
#
# Checks:
#   * the keystore opens with the password in key.properties
#   * the configured alias exists
#   * the private key is readable (i.e. the key password is correct)
#   * the certificate SHA-256 fingerprint, printed for comparison
#   * the files are ignored by git
param(
  [string]$Keystore,
  [string]$KeyProperties,
  # Fingerprint of android/app/upload-keystore.jks, alias `upload`, as measured
  # from the file in this repository on 2026-11-15. Compare it with the
  # "Upload key certificate" shown in Play Console → Setup → App signing before
  # the first upload: it must be the same certificate.
  [string]$ExpectedSha256 = 'D5:25:D1:D1:A8:88:06:4E:E3:1B:57:1C:17:C2:D7:A0:BD:F6:0B:5F:87:8F:FB:72:03:31:2D:32:53:DB:12:3C'
)

$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $KeyProperties) { $KeyProperties = Join-Path $root 'android\key.properties' }
if (-not (Test-Path $KeyProperties)) { throw "Missing $KeyProperties" }

$props = @{}
Get-Content $KeyProperties | ForEach-Object {
  if ($_ -match '^\s*([^#=]+?)\s*=\s*(.*)$') { $props[$matches[1]] = $matches[2].Trim() }
}
foreach ($key in @('storePassword', 'keyAlias', 'keyPassword')) {
  if (-not $props.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($props[$key])) {
    throw "key.properties is missing a non-empty $key"
  }
}

# Gradle resolves storeFile relative to android\app, so the same rule is used
# here unless the caller passes an explicit path.
if (-not $Keystore) {
  $storeFile = if ($props.ContainsKey('storeFile')) { $props['storeFile'] } else { 'upload-keystore.jks' }
  $Keystore = if ([System.IO.Path]::IsPathRooted($storeFile)) { $storeFile } else { Join-Path $root (Join-Path 'android\app' $storeFile) }
}
if (-not (Test-Path $Keystore)) { throw "Missing keystore: $Keystore" }

$keytool = $null
if ($env:JAVA_HOME) { $keytool = Join-Path $env:JAVA_HOME 'bin\keytool.exe' }
foreach ($candidate in @($keytool, 'C:\Program Files\Java\jdk-17\bin\keytool.exe', 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe')) {
  if ($candidate -and (Test-Path $candidate)) { $keytool = $candidate; break }
}
if (-not $keytool) {
  $cmd = Get-Command keytool -ErrorAction SilentlyContinue
  if ($cmd) { $keytool = $cmd.Source }
}
if (-not $keytool) { throw 'keytool not found (install a JDK or set JAVA_HOME).' }

# keytool prints its banner on stderr. With $ErrorActionPreference = 'Stop',
# redirecting 2>&1 into the pipeline would turn that banner into a terminating
# error, so the plain-text scratch file is used instead.
$scratch = $env:TEMP
$listingFile = Join-Path $scratch ("learnlaw-list-" + [guid]::NewGuid() + '.txt')
$errorsFile = Join-Path $scratch ("learnlaw-list-err-" + [guid]::NewGuid() + '.txt')
try {
  # Native stderr is relaxed for this call only: keytool's banner would
  # otherwise be promoted to a terminating error by the outer policy.
  $ErrorActionPreference = 'Continue'
  & $keytool -list -v -keystore $Keystore -alias $props['keyAlias'] `
    -storepass $props['storePassword'] 1> $listingFile 2> $errorsFile
  $exit = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  $listing = if (Test-Path $listingFile) { Get-Content $listingFile -Raw } else { '' }
  $toolErrors = if (Test-Path $errorsFile) { Get-Content $errorsFile -Raw } else { '' }
} finally {
  Remove-Item $listingFile, $errorsFile -Force -ErrorAction SilentlyContinue
}
if ($exit -ne 0) {
  # Never echo the password; keytool never prints it, but be explicit.
  if ($toolErrors) { Write-Output 'keytool reported an error opening the keystore.' }
  throw 'The keystore did not open with the configured password/alias.'
}

$sha = ($listing -split "`n" | Select-String 'SHA256:' | Select-Object -First 1).Line
if (-not $sha) { throw 'No SHA256 fingerprint in keytool output.' }
$actual = ($sha -split 'SHA256:\s*', 2)[1].Trim()

Write-Output "Alias:    $($props['keyAlias'])"
Write-Output "SHA-256:  $actual"
if ($ExpectedSha256 -and $actual -ne $ExpectedSha256) {
  Write-Output "EXPECTED: $ExpectedSha256"
  throw 'Fingerprint does not match the expected certificate. Do not publish with this key.'
}
Write-Output 'Fingerprint matches the expected upload certificate.'

# The private key password has to be correct as well; -certreq exercises it
# without writing anything.
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("learnlaw-${pid}.csr")
try {
  $ErrorActionPreference = 'Continue'
  & $keytool -certreq -keystore $Keystore -alias $props['keyAlias'] `
    -storepass $props['storePassword'] -keypass $props['keyPassword'] -file $tmp `
    1> $null 2> $null
  $certReqExit = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  if ($certReqExit -ne 0) { throw 'The key password in key.properties does not open the private key.' }
  Write-Output 'Private key opens with the configured key password.'
}
finally {
  Remove-Item $tmp -Force -ErrorAction SilentlyContinue
}

Push-Location $root
try {
  foreach ($path in @('android/key.properties', 'android/app/upload-keystore.jks', 'android/upload-keystore.jks')) {
    $tracked = git ls-files -- $path
    if ($tracked) { throw "Tracked by git and must be removed from the index: $tracked" }
  }
  Write-Output 'Neither the keystore nor key.properties is tracked by git.'
}
finally { Pop-Location }
