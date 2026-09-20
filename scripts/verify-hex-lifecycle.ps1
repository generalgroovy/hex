param([Parameter(Mandatory)][string]$RunId, [int]$Port=24942, [string]$Executable='')
$ErrorActionPreference='Stop'
$hexRoot=Split-Path -Parent $PSScriptRoot
$hexEvidence=Join-Path $hexRoot 'docs/evidence/hex-integration-20260920'
$hexLogs=Join-Path $hexRoot ".godot/hex-network-$RunId"
if(Test-Path -LiteralPath $hexLogs){throw 'Fresh RunId required'}
New-Item -ItemType Directory -Path $hexLogs | Out-Null
$hexSavedAppData=$env:APPDATA
$env:APPDATA=Join-Path $hexLogs 'isolated-roaming'
New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
$hexClock=[Diagnostics.Stopwatch]::StartNew()
$hexFailure=$null
try { & (Join-Path $PSScriptRoot 'smoke-farflow.ps1') -TimeoutSeconds 300 -Port $Port -LogDirectory $hexLogs -Executable $Executable }
catch { $hexFailure=$_.Exception.Message }
finally {
 $env:APPDATA=$hexSavedAppData
 $hexClock.Stop()
 $hexIdentity=Get-Content (Join-Path $hexRoot 'content/runtime/runtime_build_identity_v1.json') -Raw | ConvertFrom-Json
 [ordered]@{status=$(if($hexFailure){'failed'}else{'passed'});failure=$hexFailure;build_id=$hexIdentity.build_id;runtime_sha=$hexIdentity.runtime_source_sha256;duration_ms=$hexClock.ElapsedMilliseconds;logs=$hexLogs;target=$(if($Executable){$Executable}else{'source'});timeout_seconds=300} | ConvertTo-Json | Set-Content (Join-Path $hexEvidence "network-$RunId.json") -Encoding utf8
}
if($hexFailure){throw $hexFailure}
