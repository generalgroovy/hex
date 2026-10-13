param(
    [ValidatePattern('^[a-z0-9-]{1,16}$')][string]$RunSuffix = 'a',
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{64}$')][string]$ExpectedDriverSha256
)
$ErrorActionPreference = 'Stop'
. ./scripts/flux2-common.ps1
$hexRoot = [IO.Path]::GetFullPath("$PWD")
$hexDriver = '.godot/iteration-20261013/terminal-audio/probe-terminal-audio.gd'
if ((Get-FileHash -LiteralPath $hexDriver).Hash.ToLowerInvariant() -cne $ExpectedDriverSha256) { throw 'Reviewed audio driver differs' }
$hexBase = ".godot/iteration-20261013/terminal-audio/runs/probe-$RunSuffix"
foreach ($hexFresh in @($hexBase, "$hexBase.log", "$hexBase.log.err", "$hexBase-parse.log", "$hexBase-parse.log.err", "$hexBase-roaming")) {
    if (Test-Path -LiteralPath $hexFresh) { throw "Fresh output required: $hexFresh" }
}
$hexSavedRoaming = $env:APPDATA
$hexHadRoaming = Test-Path Env:APPDATA
$hexLease = Enter-FluxEngineRun 'terminal-audio-reproduction'
try {
    New-Item -ItemType Directory -Path (Split-Path -Parent $hexBase) -Force | Out-Null
    $env:APPDATA = Join-Path $hexRoot "$hexBase-roaming"
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    Invoke-FluxGodotChecked (Get-FluxGodot) @('--headless','--path',$hexRoot,'--check-only','--script',"res://$hexDriver") (Join-Path $hexRoot "$hexBase-parse.log") -RejectWarnings -TimeoutSeconds 180 | Out-Null
    Invoke-FluxGodotChecked (Get-FluxGodot) @('--headless','--path',$hexRoot,'--audio-driver','Dummy','--script',"res://$hexDriver",'--','--no-lan-discovery',"--output=res://$hexBase") (Join-Path $hexRoot "$hexBase.log") -RejectWarnings -TimeoutSeconds 600 | Out-Null
    $hexReceipt = Get-Content -LiteralPath "$hexBase/receipt.json" -Raw | ConvertFrom-Json
    if ($hexReceipt.integrity_passed -ne $true -or $hexReceipt.failures.Count -ne 0 -or $hexReceipt.checks -lt 1) { throw 'Audio reproduction integrity failed' }
    if (@($hexReceipt.sources.PSObject.Properties).Count -lt 3) { throw 'Source pin inventory missing' }
    foreach ($hexProperty in $hexReceipt.sources.PSObject.Properties) {
        $hexPath = [IO.Path]::GetFullPath((Join-Path $hexRoot ($hexProperty.Name -replace '^res://','')))
        if (-not $hexPath.StartsWith($hexRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Source pin escapes checkout' }
        if ((Get-FileHash -LiteralPath $hexPath).Hash.ToLowerInvariant() -cne $hexProperty.Value) { throw "Source pin changed: $hexPath" }
    }
    Write-Output "PASS audio integrity: $($hexReceipt.checks) checks; reproduced=$($hexReceipt.reproduced)."
    Get-FileHash -LiteralPath "$hexBase/receipt.json" -Algorithm SHA256
} finally {
    if ($hexHadRoaming) { $env:APPDATA = $hexSavedRoaming } else { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue }
    Exit-FluxEngineRun $hexLease
    if ((Get-FileHash -LiteralPath $hexDriver).Hash.ToLowerInvariant() -cne $ExpectedDriverSha256) { throw 'Audio driver changed during execution' }
}
