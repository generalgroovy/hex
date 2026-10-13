param([ValidatePattern('^[a-z0-9-]{1,16}$')][string]$RunSuffix='a')
$ErrorActionPreference='Stop'
. ./scripts/flux2-common.ps1
$hexBase=".godot/iteration-20261013/coach-terminal/runs/probe-$RunSuffix"
foreach ($hexPath in @($hexBase,"$hexBase-parse.log","$hexBase.log","$hexBase-roaming")) {
    if (Test-Path -LiteralPath $hexPath) { throw "Fresh output required: $hexPath" }
}
New-Item -ItemType Directory -Path (Split-Path -Parent $hexBase) -Force | Out-Null
$hexSavedRoaming=$env:APPDATA
try {
    $env:APPDATA=Join-Path $PWD "$hexBase-roaming"
    $hexScript='res://.godot/iteration-20261013/coach-terminal/probe-coach-terminal.gd'
    Invoke-FluxGodotChecked -GodotBin (Get-FluxGodot) -Arguments @('--headless','--path',"$PWD",'--check-only','--script',$hexScript) -LogPath (Join-Path $PWD "$hexBase-parse.log") -TimeoutSeconds 120 -RejectWarnings
    Invoke-FluxGodotChecked -GodotBin (Get-FluxGodot) -Arguments @('--headless','--path',"$PWD",'--script',$hexScript,'--',"--output=res://$hexBase") -LogPath (Join-Path $PWD "$hexBase.log") -TimeoutSeconds 300 -RejectWarnings
    $hexReceipt=Get-Content -LiteralPath "$hexBase/receipt.json" -Raw | ConvertFrom-Json
    $hexReceipt | Select-Object integrity_passed,reproduced,checks,failures | ConvertTo-Json -Depth 4
    if (-not $hexReceipt.integrity_passed -or $hexReceipt.failures.Count -gt 0) { throw 'Coach diagnostic integrity failed' }
    foreach ($hexProperty in $hexReceipt.sources.PSObject.Properties) {
        $hexPath=Join-Path $PWD ($hexProperty.Name -replace '^res://','')
        if ((Get-FileHash -LiteralPath $hexPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $hexProperty.Value) { throw "Source drift: $hexPath" }
    }
    Get-FileHash -LiteralPath "$hexBase/receipt.json" -Algorithm SHA256
} finally { $env:APPDATA=$hexSavedRoaming }
