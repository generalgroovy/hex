param([Parameter(Mandatory)][string]$ExpectedBuildId)
$ErrorActionPreference='Stop'
$hexRoot='C:/Users/sende/Projects/hex'
$hexPackage=Join-Path $hexRoot 'exports/hex-refinement-20261005'
$hexLogs=Join-Path $hexRoot '.godot/refinement-network-20261005-v1'
$hexReceiptPath=Join-Path $hexLogs 'receipt.json'
$hexIdentity=Get-Content -LiteralPath (Join-Path $hexPackage 'windows/SOURCE-IDENTITY.json') -Raw | ConvertFrom-Json
if($hexIdentity.build_id -ne $ExpectedBuildId){throw 'Expected refinement package identity required'}
if(Test-Path -LiteralPath $hexLogs){throw 'Fresh network log directory required'}
New-Item -ItemType Directory -Path $hexLogs | Out-Null
$hexSavedRoaming=$env:APPDATA
$hexClock=[Diagnostics.Stopwatch]::StartNew()
$hexFailure=$null
try {
 $env:APPDATA=Join-Path $hexLogs 'isolated-roaming'
 New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
 & (Join-Path $hexRoot 'scripts/smoke-farflow.ps1') -Executable (Join-Path $hexPackage 'windows/hex.exe') -Port 29951 -TickRate 120 -TimeoutSeconds 120 -LogDirectory $hexLogs
} catch { $hexFailure=$_.Exception.Message }
finally {
 $hexClock.Stop()
 $env:APPDATA=$hexSavedRoaming
 $hexErrors=[ordered]@{}
 foreach($hexName in @('host','guest','late-guest')) {
  $hexPath=Join-Path $hexLogs "$hexName.log.err"
  $hexErrors[$hexName]=$(if(Test-Path -LiteralPath $hexPath){(Get-Item -LiteralPath $hexPath).Length}else{-1})
 }
 if(-not $hexFailure -and @($hexErrors.Values | Where-Object {$_ -ne 0}).Count -gt 0) {
  $hexFailure='Network stderr is missing or nonempty'
 }
 $hexResult=[ordered]@{
  status=$(if($hexFailure){'failed'}else{'passed'})
  build_id=$hexIdentity.build_id
  executable='exports/hex-refinement-20261005/windows/hex.exe'
  script='scripts/smoke-farflow.ps1';port=29951;configured_tick_rate=120;timeout_seconds=120
  elapsed_seconds=$hexClock.Elapsed.TotalSeconds
  scope='Three-process same-export localhost lifecycle; not physical internet, sustained load or timing-budget acceptance'
  asserted_scenarios=@('host/join','shared HELLO','movement reconciliation','Hearth-to-Court round','late spectator and Hearth handoff','exact-actor return','rematch','reason-bearing host stewardship')
  stderr_bytes=$hexErrors
  isolated_appdata='.godot/refinement-network-20261005-v1/isolated-roaming'
  original_logs='.godot/refinement-network-20261005-v1'
  error=$hexFailure
 }
 [IO.File]::WriteAllText($hexReceiptPath,($hexResult | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
 $hexResult | ConvertTo-Json -Depth 8
}
if($hexFailure){throw $hexFailure}
if(@($hexErrors.Values | Where-Object {$_ -ne 0}).Count -gt 0){throw 'Network stderr missing or nonempty'}
