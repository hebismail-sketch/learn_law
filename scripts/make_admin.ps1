# Learn Law - grant (or revoke) the admin role on a Supabase project.
#
# The app only opens the editor for an account whose server-managed
# app_metadata carries an admin claim, because the RLS policies read the same
# claim from the JWT. This script writes that claim with the *service role* key
# from your machine; the key is never part of the app or this repository.
#
# Usage (PowerShell, from the project root):
#
#   $env:SUPABASE_URL = 'https://ptsfjeersiesgjtvcjkh.supabase.co'
#   $env:SUPABASE_SERVICE_ROLE_KEY = '<service role key from Dashboard > Project Settings > API>'
#   .\scripts\make_admin.ps1 -Email 'you@example.com'
#
# Options:
#   -Revoke   remove both admin claims instead of adding them
#   -DryRun   show what would be sent, change nothing
#
# After a successful run the account must sign in again (or wait for the token
# refresh, at most one hour): the claim reaches the phone with the next JWT.

param(
  [Parameter(Mandatory = $true)][string]$Email,
  [switch]$Revoke,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$url = $env:SUPABASE_URL
$serviceKey = $env:SUPABASE_SERVICE_ROLE_KEY

if ([string]::IsNullOrWhiteSpace($url)) {
  throw 'Set $env:SUPABASE_URL first (Project Settings > API > Project URL).'
}
if ([string]::IsNullOrWhiteSpace($serviceKey)) {
  throw 'Set $env:SUPABASE_SERVICE_ROLE_KEY first (Project Settings > API > service_role key).'
}
if ($serviceKey.StartsWith('sb_publishable_')) {
  throw 'That is the publishable key. Use the service_role key (never ship it in the app).'
}

$base = $url.TrimEnd('/') + '/auth/v1'
$headers = @{
  apikey         = $serviceKey
  Authorization  = "Bearer $serviceKey"
  'Content-Type' = 'application/json'
}

# GoTrue reports failures in the response body (e.g. "invalid JWT"); this reads
# the body out of the exception so the real reason is never hidden behind the
# generic "remote server returned an error".
function Get-ResponseBody {
  param($ErrorRecord)
  $details = $ErrorRecord.ErrorDetails
  if ($details -and -not [string]::IsNullOrWhiteSpace($details.Message)) {
    return $details.Message
  }
  $response = $ErrorRecord.Exception.Response
  if ($null -eq $response) { return $ErrorRecord.Exception.Message }
  try {
    $stream = $response.GetResponseStream()
    if ($null -eq $stream) { return $ErrorRecord.Exception.Message }
    return (New-Object System.IO.StreamReader($stream)).ReadToEnd()
  } catch {
    return $ErrorRecord.Exception.Message
  }
}

function Invoke-GoTrue {
  param([string]$Path, [string]$Method = 'GET', [string]$Body = $null)
  if ($DryRun) {
    Write-Host "[dry-run] $Method $base$Path $Body"
    return $null
  }
  $params = @{
    Uri             = "$base$Path"
    Method          = $Method
    Headers         = $headers
    UseBasicParsing = $true
    TimeoutSec      = 30
  }
  if ($Body) { $params.Body = [System.Text.Encoding]::UTF8.GetBytes($Body) }
  try {
    $content = (Invoke-WebRequest @params).Content
  } catch {
    throw "Auth admin API failed: $(Get-ResponseBody $_)"
  }
  if ([string]::IsNullOrWhiteSpace($content)) { return $null }
  return $content | ConvertFrom-Json
}

# Paginate the user list until the email shows up. /auth/v1/admin/users is the
# only endpoint that exposes raw_app_meta_data for every account.
$page = 1
$user = $null
while ($true) {
  $response = Invoke-GoTrue -Path "/admin/users?page=$page&per_page=200"
  if ($null -eq $response) { break }
  $match = $response.users | Where-Object { $_.email -eq $Email } | Select-Object -First 1
  if ($match) { $user = $match; break }
  if ($response.users.Count -lt 200) { break }
  $page++
}

if ($DryRun) {
  Write-Host 'Dry run finished; no account was listed.'
  exit 0
}

if (-not $user) {
  throw "No account with email '$Email' exists on $url. Create it in Authentication > Users first (email must be confirmed)."
}

$current = $user.app_metadata
if ($null -eq $current) { $current = [pscustomobject]@{} }

# app_metadata is replaced as a whole by the admin API, so the existing keys
# (provider, providers, ...) are carried over untouched.
$meta = @{}
foreach ($prop in $current.PSObject.Properties) { $meta[$prop.Name] = $prop.Value }

if ($Revoke) {
  $meta.Remove('role')
  $meta.Remove('learn_law_role')
}
else {
  $meta['learn_law_role'] = 'admin'
  $meta['role'] = 'admin'
}

$payload = @{ app_metadata = $meta } | ConvertTo-Json -Depth 10 -Compress
$updated = Invoke-GoTrue -Path "/admin/users/$($user.id)" -Method 'PUT' -Body $payload

$verify = $updated.app_metadata
if ($Revoke) {
  if ($verify.role -eq 'admin' -or $verify.learn_law_role -eq 'admin') {
    throw 'Revoke did not take effect; check the response above.'
  }
  Write-Host "Removed the admin claim from $Email ($($user.id))."
}
else {
  if ($verify.role -ne 'admin' -and $verify.learn_law_role -ne 'admin') {
    throw 'The claim was sent but is not present in the response; check the API logs.'
  }
  Write-Host "Granted admin to $Email ($($user.id)) on $url."
  Write-Host 'Sign that account out and back in in the app so the new JWT carries the claim.'
}
