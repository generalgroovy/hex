param(
    [Parameter(Mandatory)][ValidateSet('sheet','world','panel','architecture','canonical')][string]$Mode,
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$RunId
)
$ErrorActionPreference = 'Stop'
$hexRoot = 'C:\Users\sende\Projects\hex'
. (Join-Path $hexRoot 'scripts/flux2-common.ps1')
$hexEvidenceFolder = if ($Mode -in @('architecture','canonical')) { 'architecture-prototype' } else { 'environment-depth' }
$hexCaptureScript = if ($Mode -eq 'canonical') { 'capture-canonical-architecture.gd' } elseif ($Mode -eq 'architecture') { 'capture-architecture.gd' } else { 'capture-environment-depth.gd' }
$hexEvidenceRoot = Join-Path $hexRoot ('.godot/iteration-20261013/' + $hexEvidenceFolder)
$hexRunFolder = if ($Mode -eq 'canonical') { 'parity-runs' } else { 'runs' }
$hexOutput = Join-Path $hexEvidenceRoot ($hexRunFolder + '/' + $RunId)
$hexLogRoot = Join-Path $hexEvidenceRoot ('logs/' + $RunId)
if ((Test-Path -LiteralPath $hexOutput) -or (Test-Path -LiteralPath $hexLogRoot)) { throw 'Fresh native evidence paths required.' }
$hexNativeLease = Enter-FluxEngineRun 'environment-depth-native'
$hexHadAppData = Test-Path Env:APPDATA
$hexSavedAppData = $env:APPDATA
try {
    New-Item -ItemType Directory -Path $hexLogRoot | Out-Null
    $env:APPDATA = Join-Path $hexLogRoot 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    $hexLog = Join-Path $hexLogRoot 'native.log'
    Invoke-FluxGodotChecked (Get-FluxGodot) @('--path',$hexRoot,'--windowed','--resolution','1280x720','--script',('res://.godot/iteration-20261013/'+$hexEvidenceFolder+'/'+$hexCaptureScript),'--',('--mode='+$Mode),('--output=res://.godot/iteration-20261013/'+$hexEvidenceFolder+'/'+$hexRunFolder+'/'+$RunId)) $hexLog -RejectWarnings -TimeoutSeconds 240
    if ((Get-Item -LiteralPath ($hexLog+'.err')).Length -ne 0) { throw 'Native fixture emitted stderr.' }
    $hexReceipt = Get-Content -LiteralPath (Join-Path $hexOutput 'receipt.json') -Raw | ConvertFrom-Json
    if ($hexReceipt.passed -ne $true -or ($Mode -notin @('architecture','canonical') -and $hexReceipt.mode -cne $Mode) -or $hexReceipt.errors.Count -ne 0 -or $hexReceipt.cleanup.created -ne $hexReceipt.cleanup.freed) { throw 'Native fixture receipt did not pass.' }
    [ordered]@{ mode=$Mode; checks=$hexReceipt.checks; captures=$hexReceipt.captures.Count; receipt=(Join-Path $hexOutput 'receipt.json'); stderr_bytes=0; scope='Prepared native fixture; not a player or performance session.' } | ConvertTo-Json
} finally {
    if ($hexHadAppData) { $env:APPDATA=$hexSavedAppData } else { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue }
    Exit-FluxEngineRun $hexNativeLease
}
