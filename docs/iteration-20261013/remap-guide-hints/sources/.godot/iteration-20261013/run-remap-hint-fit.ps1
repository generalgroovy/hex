param(
    [ValidatePattern('^[a-z0-9-]{1,16}$')][string]$RunSuffix = 'a',
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{64}$')][string]$ExpectedDriverSha256
)
$ErrorActionPreference = 'Stop'
. ./scripts/flux2-common.ps1
$hexRoot = [IO.Path]::GetFullPath("$PWD")
$hexDriver = '.godot/iteration-20261013/remap-guide-hints/capture-remap-hint-fit.gd'
if ((Get-FileHash -LiteralPath $hexDriver).Hash.ToLowerInvariant() -cne $ExpectedDriverSha256) { throw 'Reviewed remap fit driver differs' }
$hexBase = ".godot/iteration-20261013/remap-guide-hints/runs/fit-$RunSuffix"
foreach ($hexFresh in @($hexBase, "$hexBase.log", "$hexBase.log.err", "$hexBase-parse.log", "$hexBase-parse.log.err", "$hexBase-roaming")) {
    if (Test-Path -LiteralPath $hexFresh) { throw "Fresh output required: $hexFresh" }
}
$hexSavedRoaming = $env:APPDATA
$hexHadRoaming = Test-Path Env:APPDATA
$hexLease = Enter-FluxEngineRun 'remapped-shortcut-native-fit'
try {
    New-Item -ItemType Directory -Path (Split-Path -Parent $hexBase) -Force | Out-Null
    $env:APPDATA = Join-Path $hexRoot "$hexBase-roaming"
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    Invoke-FluxGodotChecked (Get-FluxGodot) @('--headless','--path',$hexRoot,'--check-only','--script',"res://$hexDriver") (Join-Path $hexRoot "$hexBase-parse.log") -RejectWarnings -TimeoutSeconds 180 | Out-Null
    Invoke-FluxGodotChecked (Get-FluxGodot) @('--path',$hexRoot,'--audio-driver','Dummy','--script',"res://$hexDriver",'--','--no-lan-discovery',"--output=res://$hexBase") (Join-Path $hexRoot "$hexBase.log") -RejectWarnings -TimeoutSeconds 180 | Out-Null
    $hexReceipt = Get-Content -LiteralPath "$hexBase/receipt.json" -Raw | ConvertFrom-Json
    if ($hexReceipt.passed -ne $true -or $hexReceipt.errors.Count -ne 0 -or $hexReceipt.cases.Count -ne 12) { throw 'Native remap fit receipt failed' }
    foreach ($hexProperty in $hexReceipt.source_hashes.PSObject.Properties) {
        $hexPath = [IO.Path]::GetFullPath((Join-Path $hexRoot ($hexProperty.Name -replace '^res://','')))
        if (-not $hexPath.StartsWith($hexRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Source pin escapes checkout' }
        if ((Get-FileHash -LiteralPath $hexPath).Hash.ToLowerInvariant() -cne $hexProperty.Value) { throw "Source pin changed: $hexPath" }
    }
    Write-Output "PASS native remap fit: $($hexReceipt.checks) checks; $($hexReceipt.cases.Count) cases."
    Get-FileHash -LiteralPath "$hexBase/receipt.json" -Algorithm SHA256
} finally {
    if ($hexHadRoaming) { $env:APPDATA = $hexSavedRoaming } else { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue }
    Exit-FluxEngineRun $hexLease
    if ((Get-FileHash -LiteralPath $hexDriver).Hash.ToLowerInvariant() -cne $ExpectedDriverSha256) { throw 'Remap fit driver changed during execution' }
}
