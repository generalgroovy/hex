param([ValidatePattern('^[a-z0-9-]+$')][string]$RunId = ('art-' + (Get-Date -Format 'yyyyMMdd-HHmmss')))
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$artRoot=Get-FluxRepoRoot
if ((& git -C $artRoot remote get-url origin).Trim() -ne 'https://github.com/generalgroovy/hex.git') {throw 'Wrong checkout'}
$artOutput=Join-Path $artRoot ".godot/fullbody-game/$RunId"
if(Test-Path -LiteralPath $artOutput){throw 'Fresh RunId required'}
New-Item -ItemType Directory -Path $artOutput | Out-Null
$artLease=Enter-FluxEngineRun 'fullbody-live-game-capture'
$artSavedData=$env:APPDATA
try {
 $env:APPDATA=Join-Path $artOutput 'isolated-roaming'
 New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
 $artCases=@(
  @{id='oh-tipi';args=@('--champion=oh_tipi','--capture-movement=walk','--capture-direction=south_east')},
  @{id='jan-slide';args=@('--champion=jan_wicked','--capture-movement=slide','--capture-direction=south')},
  @{id='fluup-dodge';args=@('--champion=fluup','--capture-movement=air_chain','--capture-direction=east')},
  @{id='gallery';args=@('--champion=wa_bidi','--capture-expanded-station=champion-loom')}
 )
 foreach($artCase in $artCases){
  $artFolder=Join-Path $artOutput $artCase.id
  New-Item -ItemType Directory -Path $artFolder | Out-Null
  $artArgs=@('--path',$artRoot,'--windowed','--resolution','1280x720','--write-movie',(Join-Path $artFolder 'frame.png'),'--quit-after','64','--fixed-fps','120','--','--fullbody-art','--no-lan-discovery','--camera-zoom=100')+$artCase.args
  Invoke-FluxGodotChecked (Get-FluxGodot) $artArgs (Join-Path $artFolder 'capture.log') -TimeoutSeconds 180 -RejectWarnings | Out-Null
 }
 Write-Output "PASS: four actual bootstrap scene captures,64 frames each. $artOutput"
} finally {$env:APPDATA=$artSavedData;Exit-FluxEngineRun $artLease}
