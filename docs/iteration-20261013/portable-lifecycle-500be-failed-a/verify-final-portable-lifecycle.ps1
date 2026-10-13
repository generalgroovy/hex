param([Parameter(Mandatory)][string]$BuildDir,[Parameter(Mandatory)][string]$OutputDirectory,[Parameter(Mandatory)][string]$ExpectedBuildId)
$ErrorActionPreference='Stop'
$BuildDir=[IO.Path]::GetFullPath($BuildDir)
$OutputDirectory=[IO.Path]::GetFullPath($OutputDirectory)
$hexRepo='C:\Users\sende\Projects\hex'
. (Join-Path $hexRepo 'scripts/flux2-common.ps1')
$hexPayload=Join-Path $BuildDir 'windows'
$hexExe=Join-Path $hexPayload 'hex.exe'
$hexPackage=Get-Content -LiteralPath (Join-Path $BuildDir 'receipt.json') -Raw | ConvertFrom-Json
if($hexPackage.status -ne 'passed' -or $hexPackage.build_id -ne $ExpectedBuildId){throw 'Expected passed final package'}
if(Test-Path -LiteralPath $OutputDirectory){throw 'Fresh lifecycle output required'}
$hexBefore=@{}
foreach($hexName in @('hex.exe','hex.pck','BUILD-STATE.json','SOURCE-IDENTITY.json')){$hexBefore[$hexName]=(Get-FileHash -LiteralPath (Join-Path $hexPayload $hexName)).Hash.ToLowerInvariant()}
$hexCases=@(
 @{name='hearth';seconds=20;wire=0;extra=@('--capture-spawn=1536,880')},
 @{name='garden';seconds=25;wire=0;extra=@('--capture-spawn=4880,720')},
 @{name='paid-fire';seconds=45;wire=145;extra=@('--capture-spawn=1536,880','--capture-pointer=1736,880','--capture-spell-wires=145','--capture-cast-slot=1','--capture-spell-sequence=1,1,1,1,1,1,1,1,1,1,1,1')},
 @{name='paid-all-six-mantle';seconds=45;wire=1319;extra=@('--capture-spawn=1536,880','--capture-pointer=1736,880','--capture-spell-wires=1319','--capture-cast-slot=1','--capture-spell-sequence=1,1,1,1,1,1,1,1,1,1,1,1')},
 @{name='reopen';seconds=20;wire=0;extra=@('--capture-spawn=1536,880')}
)
$hexSavedAppData=$env:APPDATA
$hexLease=Enter-FluxEngineRun 'final-portable-lifecycle'
$hexRows=[Collections.Generic.List[object]]::new()
$hexFailure=$null
try{
 New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
 $env:APPDATA=Join-Path $OutputDirectory 'isolated-roaming'
 New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
 foreach($hexCase in $hexCases){
  $hexLog=Join-Path $OutputDirectory ($hexCase.name+'.log')
  $hexArgs=@('--windowed','--resolution','1280x720','--','--fullbody-art','--pixel-cast','--no-lan-discovery')+$hexCase.extra
  $hexStarted=[DateTime]::UtcNow.ToString('o')
  Push-Location -LiteralPath $hexPayload
  try{Invoke-FluxGodotChecked $hexExe $hexArgs $hexLog -RejectWarnings -TimeoutSeconds 120 -CloseAfterSeconds $hexCase.seconds -VisibleWindow | Out-Null}finally{Pop-Location}
  $hexLogText=[IO.File]::ReadAllText($hexLog)
  if(-not $hexLogText.Contains('FLUX2 runtime build: '+$hexPackage.build_id+' | '+$hexPackage.runtime_source_sha256)){throw 'Unexpected runtime identity'}
  if(-not $hexLogText.Contains('safe quit: local state flushed and network peer closed')){throw 'Missing safe-close marker'}
  if((Get-Item -LiteralPath ($hexLog+'.err')).Length -ne 0){throw 'Nonempty stderr'}
  $hexCastStarts=0;$hexCastRefusals=0
  foreach($hexLine in [IO.File]::ReadLines($hexLog)){
   if($hexLine -match '^FLUX2 spell capture: tick [0-9]+ pending [0-9]+/[0-9]+ projectiles [0-9]+ fields [0-9]+ events (.+)$'){
    foreach($hexEvent in @($Matches[1] | ConvertFrom-Json)){
     if($hexEvent.type -notin @('cast_started','cast_refused')){continue}
     if($null -eq $hexEvent.PSObject.Properties['wire_id']){throw 'Cast outcome is missing its spell wire'}
     if($hexEvent.wire_id -eq $hexCase.wire){if($hexEvent.type -eq 'cast_started'){$hexCastStarts++};if($hexEvent.type -eq 'cast_refused'){$hexCastRefusals++}}
    }
   }
  }
  if($hexCase.wire -gt 0 -and ($hexCastStarts+$hexCastRefusals -ne 12 -or $hexCastStarts -lt 1)){throw 'Finite paid workload incomplete'}
  $hexProfileRoot=Join-Path $env:APPDATA 'Godot/app_userdata/FLUX 2'
  $hexPreferences=Join-Path $hexProfileRoot 'player_preferences_v1.json'
  if(-not (Test-Path -LiteralPath $hexPreferences -PathType Leaf) -or (Get-Item -LiteralPath $hexPreferences).Length -eq 0){throw 'Missing isolated persisted preferences'}
  $hexPreferenceData=Get-Content -LiteralPath $hexPreferences -Raw | ConvertFrom-Json
  if($null -eq $hexPreferenceData -or $hexPreferenceData.schema_version -ne 11){throw 'Invalid isolated preferences document'}
  $hexProfiles=@()
  if(Test-Path -LiteralPath $hexProfileRoot){
   $hexProfiles=@(Get-ChildItem -LiteralPath $hexProfileRoot -File | Where-Object {$_.Name -match '\.(json|bak)$'} | Sort-Object Name | ForEach-Object {[ordered]@{name=$_.Name;bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()}})
  }
  $hexRows.Add([ordered]@{case=$hexCase.name;started_utc=$hexStarted;status='passed';scheduled_close_seconds=$hexCase.seconds;exit_mode='owned-process-normal-window-close';safe_close_marker=$true;stderr_bytes=0;accepted_casts=$hexCastStarts;refused_casts=$hexCastRefusals;paid_wire=$hexCase.wire;profile_files=$hexProfiles;log=$hexLog;log_sha256=(Get-FileHash -LiteralPath $hexLog).Hash.ToLowerInvariant()})
  Write-Output ('PASS lifecycle: '+$hexCase.name+'; accepted='+$hexCastStarts+' refused='+$hexCastRefusals)
 }
 foreach($hexName in $hexBefore.Keys){if((Get-FileHash -LiteralPath (Join-Path $hexPayload $hexName)).Hash.ToLowerInvariant() -ne $hexBefore[$hexName]){throw 'Package bytes changed'}}
}catch{$hexFailure=$_.Exception.Message}
finally{
 $env:APPDATA=$hexSavedAppData
 Exit-FluxEngineRun $hexLease
 if(Test-Path -LiteralPath $OutputDirectory){
  $hexResult=[ordered]@{schema='hex-portable-lifecycle-v1';status=$(if($hexFailure){'failed'}else{'passed'});failure=$hexFailure;build_id=$hexPackage.build_id;runtime_source_sha256=$hexPackage.runtime_source_sha256;completed_utc=[DateTime]::UtcNow.ToString('o');package_hashes_before=$hexBefore;cases=$hexRows.ToArray();shared_isolated_profile_verified=$hexRows.Count -eq $hexCases.Count;caller_appdata_restored=$env:APPDATA -eq $hexSavedAppData;script_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant();scope='Actual release executable: shared fresh isolated profile, five sequential normal-close/reopen cases and twelve finite ordinary paid attempts in each casting case; accepted/refused counts remain explicit. Visible launch requested for normal window-close delivery; no foreground, timing, FPS, physical input, earned progression, damaged-save recovery or replay export acceptance.'}
  [IO.File]::WriteAllText((Join-Path $OutputDirectory 'receipt.json'),($hexResult | ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
 }
}
if($hexFailure){throw $hexFailure}
