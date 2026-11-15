# Creates an encrypted backup of the Android upload keystore and key.properties,
# outside the repository.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\backup_upload_keystore.ps1 -OutDir D:\backup
#
# The archive is protected with a passphrase. Interactive runs ask for it with
# a masked prompt; scripted runs read LEARNLAW_BACKUP_PASSPHRASE. Neither
# method writes the passphrase to disk, to the console or to any log, and the
# keystore password only ever travels inside the encrypted file.
#
# Output in -OutDir:
#   learnlaw-upload-key-<date>.enc          AES-256 encrypted payload
#   learnlaw-upload-key-<date>.enc.sha256   checksum of that file
#   RESTORE.md                               restore instructions
#
# Run it twice: one copy on this machine, one on removable media kept
# elsewhere. A backup stored next to the original is not a backup.
param(
  [Parameter(Mandatory = $true)][string]$OutDir
)

$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$keyProperties = Join-Path $root 'android\key.properties'
if (-not (Test-Path $keyProperties)) { throw "Missing $keyProperties" }

$props = @{}
Get-Content $keyProperties | ForEach-Object {
  if ($_ -match '^\s*([^#=]+?)\s*=\s*(.*)$') { $props[$matches[1]] = $matches[2].Trim() }
}

# Gradle resolves storeFile relative to android\app. Older checkouts kept the
# key one level up, so both locations are tried.
$storeFile = if ($props.ContainsKey('storeFile')) { $props['storeFile'] } else { 'upload-keystore.jks' }
$candidates = if ([System.IO.Path]::IsPathRooted($storeFile)) {
  @($storeFile)
} else {
  @(
    (Join-Path $root (Join-Path 'android\app' $storeFile)),
    (Join-Path $root (Join-Path 'android' $storeFile))
  )
}
$keystore = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $keystore) { throw "Missing keystore ($storeFile); refusing to create an empty backup." }

$secure = $null
if ($env:LEARNLAW_BACKUP_PASSPHRASE) {
  $secure = ConvertTo-SecureString $env:LEARNLAW_BACKUP_PASSPHRASE -AsPlainText -Force
} elseif ([Environment]::UserInteractive -and $Host.UI.RawUI) {
  $secure = Read-Host -AsSecureString 'Backup passphrase (typed once, never stored)'
}
if (-not $secure -or $secure.Length -lt 12) {
  throw 'No passphrase supplied (or shorter than 12 characters); nothing was written.'
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$encrypted = Join-Path $OutDir "learnlaw-upload-key-$stamp.enc"
$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("learnlaw-key-" + [guid]::NewGuid())
$payload = Join-Path ([System.IO.Path]::GetTempPath()) ("learnlaw-payload-" + [guid]::NewGuid() + '.zip')

try {
  New-Item -ItemType Directory -Force -Path (Join-Path $stage 'android') | Out-Null
  Copy-Item $keystore (Join-Path $stage 'android\upload-keystore.jks')
  Copy-Item $keyProperties (Join-Path $stage 'android\key.properties')

  # The payload keeps the relative layout Gradle expects, so restoring means
  # copying two files back into android\.
  Compress-Archive -Path (Join-Path $stage 'android') -DestinationPath $payload -CompressionLevel Optimal -Force

  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    $passphrase = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    $plain = [System.IO.File]::ReadAllBytes($payload)

    $salt = New-Object byte[] 16
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($salt)

    $kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes(
      $passphrase, $salt, 210000, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    try {
      $aes = [System.Security.Cryptography.Aes]::Create()
      try {
        $aes.KeySize = 256
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Key = $kdf.GetBytes(32)
        $aes.GenerateIV()
        $encryptor = $aes.CreateEncryptor()
        $cipher = $encryptor.TransformFinalBlock($plain, 0, $plain.Length)

        # Header: magic, salt, IV, SHA-256 of the plaintext (tamper check).
        $out = New-Object System.Collections.Generic.List[byte]
        $out.AddRange([byte[]][System.Text.Encoding]::ASCII.GetBytes('LLK1'))
        $out.AddRange($salt)
        $out.AddRange($aes.IV)
        $out.AddRange([System.Security.Cryptography.SHA256]::Create().ComputeHash($plain))
        $out.AddRange($cipher)
        [System.IO.File]::WriteAllBytes($encrypted, $out.ToArray())
      } finally { $aes.Dispose() }
    } finally { $kdf.Dispose() }
  } finally {
    if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    $passphrase = $null
    $plain = $null
    $secure.Dispose()
  }

  $hash = (Get-FileHash -Algorithm SHA256 $encrypted).Hash
  Set-Content -Path "$encrypted.sha256" -Value "$hash  $(Split-Path $encrypted -Leaf)" -Encoding ASCII
  Copy-Item (Join-Path $root 'docs\keystore-restore.md') (Join-Path $OutDir 'RESTORE.md') -Force

  Write-Output "Encrypted backup: $encrypted"
  Write-Output "SHA-256: $hash"
  Write-Output "Restore instructions: $(Join-Path $OutDir 'RESTORE.md')"
  Write-Output ''
  Write-Output 'Next steps (manual, important):'
  Write-Output '  1. Copy the .enc and .sha256 files to a second, separate location.'
  Write-Output '  2. Store the passphrase in a password manager, not next to the files.'
} finally {
  Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item $payload -Force -ErrorAction SilentlyContinue
}
