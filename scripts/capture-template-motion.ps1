param([Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$RunId)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$lease=Enter-FluxEngineRun 'capture-template-motion'
$savedTemplateRoaming=$env:APPDATA
$repo=Get-FluxRepoRoot
$logs=Join-Path $repo ".godot/template-motion-$RunId-logs"
try {
    if(Test-Path $logs){throw 'Fresh capture RunId required'}
    New-Item -ItemType Directory $logs | Out-Null
    $env:APPDATA=Join-Path $logs 'isolated-roaming'
    New-Item -ItemType Directory $env:APPDATA | Out-Null
    & (Join-Path $PSScriptRoot 'runtime-build-identity.ps1') -Mode Check -Json | Set-Content (Join-Path $logs 'identity.json')
    Invoke-FluxGodotChecked (Get-FluxGodot) @('--path',$repo,'--script','res://tests/visual/capture_template_motion.gd','--',"--output=res://.godot/template-motion-$RunId") (Join-Path $logs 'capture.log') -RejectWarnings
} finally {
    $env:APPDATA=$savedTemplateRoaming
    Exit-FluxEngineRun $lease
}
