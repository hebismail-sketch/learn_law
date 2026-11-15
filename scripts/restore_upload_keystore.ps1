# Decrypts a backup produced by scripts\backup_upload_keystore.ps1 and writes
# android\upload-keystore.jks together with android\key.properties into -OutDir.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\restore_upload_keystore.ps1 `
#     -Archive D:\backup\learnlaw-upload-key-20261115-1010.enc -OutDir C:\restore
#
# The passphrase is read interactively and never printed. The plaintext is
# written only to -OutDir; delete that folder when you are done.
param(
  [Parameter(Mandatory = $true)][string]$Archive,
  [Parameter(Mandatory = $true)][string]$OutDir
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Archive)) { throw "Missing $Archive" }

$bytes = [System.IO.File]::ReadAllBytes($Archive)
if ($bytes.Length -lt 84) { throw 'File is too short to be a Learn Law key backup.' }
if ([System.Text.Encoding]::ASCII.GetString($bytes, 0, 4) -ne 'LLK1') {
  throw 'Unknown backup format (expected LLK1 header).'
}

$salt = $bytes[4..19]
$iv = $bytes[20..35]
$expectedHash = $bytes[36..67]
$cipher = $bytes[68..($bytes.Length - 1)]

# Masked prompt on an interactive host; LEARNLAW_BACKUP_PASSPHRASE when a
# script or test drives the restore.
$secure = $null
if ($env:LEARNLAW_BACKUP_PASSPHRASE) {
  $secure = ConvertTo-SecureString $env:LEARNLAW_BACKUP_PASSPHRASE -AsPlainText -Force
} elseif ([Environment]::UserInteractive -and $Host.UI.RawUI) {
  $secure = Read-Host -AsSecureString 'Backup passphrase'
}
if (-not $secure) { throw 'No passphrase supplied; nothing was restored.' }

$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
  $passphrase = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)

  $kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes(
    $passphrase, $salt, 210000, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
  try {
    $aes = [System.Security.Cryptography.Aes]::Create()
    try {
      $aes.KeySize = 256
      $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
      $aes.Key = $kdf.GetBytes(32)
      $aes.IV = $iv
      $decryptor = $aes.CreateDecryptor()
      try {
        $plain = $decryptor.TransformFinalBlock($cipher, 0, $cipher.Length)
      }
      catch {
        throw 'Wrong passphrase or damaged file (padding check failed).'
      }
    }
    finally { $aes.Dispose() }
  }
  finally { $kdf.Dispose() }

  $actualHash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($plain)
  for ($i = 0; $i -lt 32; $i++) {
    if ($actualHash[$i] -ne $expectedHash[$i]) {
      throw 'Integrity check failed: the decrypted payload does not match its stored hash.'
    }
  }

  $tmpZip = Join-Path ([System.IO.Path]::GetTempPath()) ("learnlaw-restore-" + [guid]::NewGuid() + '.zip')
  [System.IO.File]::WriteAllBytes($tmpZip, $plain)
  try {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    Expand-Archive -Path $tmpZip -DestinationPath $OutDir -Force
  }
  finally {
    Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
  }
}
finally {
  if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
  $passphrase = $null
  $plain = $null
}

Write-Output "Restored to: $OutDir"
Write-Output 'Next: verify the SHA-256 fingerprint with scripts\verify_upload_keystore.ps1,'
Write-Output 'then delete this folder — it holds an unencrypted private key.'
