param(
    [ValidateSet('functional','forward','reverse')][string[]]$Modes = @('functional'),
    [ValidatePattern('^[a-z0-9-]{1,16}$')][string]$RunSuffix = 'a',
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{64}$')][string]$ExpectedDriverSha256
)
$ErrorActionPreference = 'Stop'
. ./scripts/flux2-common.ps1
$hexRoot = [IO.Path]::GetFullPath("$PWD")
$hexDriver = '.godot/iteration-20261013/movement-cast-attribution/compare-movement-cast.gd'
if ((Get-FileHash -LiteralPath $hexDriver).Hash.ToLowerInvariant() -cne $ExpectedDriverSha256) { throw 'Reviewed driver differs' }
if (@($Modes | Select-Object -Unique).Count -ne $Modes.Count) { throw 'Duplicate requested mode' }
$hexSavedRoaming = $env:APPDATA
$hexHadRoaming = Test-Path Env:APPDATA
$hexLease = Enter-FluxEngineRun 'movement-cast-attribution'
try {
    $hexRuns = '.godot/iteration-20261013/movement-cast-attribution/runs'
    New-Item -ItemType Directory -Path $hexRuns -Force | Out-Null
    foreach ($hexMode in $Modes) {
        $hexBase = "$hexRuns/$hexMode-$RunSuffix"
        foreach ($hexFresh in @($hexBase, "$hexBase.log", "$hexBase.log.err", "$hexBase-parse.log", "$hexBase-parse.log.err", "$hexBase-roaming")) {
            if (Test-Path -LiteralPath $hexFresh) { throw "Fresh output required: $hexFresh" }
        }
        $env:APPDATA = Join-Path $hexRoot "$hexBase-roaming"
        New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
        Invoke-FluxGodotChecked (Get-FluxGodot) @('--headless','--path',$hexRoot,'--check-only','--script',"res://$hexDriver") (Join-Path $hexRoot "$hexBase-parse.log") -RejectWarnings -TimeoutSeconds 180 | Out-Null
        $hexArguments = @('--path',$hexRoot,'--audio-driver','Dummy','--script',"res://$hexDriver",'--','--no-lan-discovery',"--output=res://$hexBase")
        if ($hexMode -eq 'functional') { $hexArguments = @('--headless') + $hexArguments + @('--functional-only') }
        if ($hexMode -eq 'reverse') { $hexArguments += '--reverse-order' }
        Invoke-FluxGodotChecked (Get-FluxGodot) $hexArguments (Join-Path $hexRoot "$hexBase.log") -RejectWarnings -TimeoutSeconds 600 | Out-Null
        $hexReceipt = Get-Content -LiteralPath "$hexBase/receipt.json" -Raw | ConvertFrom-Json
        $hexExpectedMode = if ($hexMode -eq 'functional') { 'functional' } else { 'timing' }
        if ($hexReceipt.passed -ne $true -or $hexReceipt.errors.Count -ne 0 -or $hexReceipt.checks -lt 1 -or $hexReceipt.mode -cne $hexExpectedMode) { throw "Attribution receipt failed: $hexMode" }
        if (@($hexReceipt.source_hashes.PSObject.Properties).Count -lt 3) { throw 'Source pin inventory is missing' }
        foreach ($hexProperty in $hexReceipt.source_hashes.PSObject.Properties) {
            $hexPath = [IO.Path]::GetFullPath((Join-Path $hexRoot ($hexProperty.Name -replace '^res://','')))
            if (-not $hexPath.StartsWith($hexRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Source pin escapes checkout' }
            if ((Get-FileHash -LiteralPath $hexPath).Hash.ToLowerInvariant() -cne $hexProperty.Value) { throw "Source pin changed: $hexPath" }
        }
        if ((Get-FileHash -LiteralPath $hexDriver).Hash.ToLowerInvariant() -cne $ExpectedDriverSha256) { throw 'Driver changed during execution' }
        Write-Output "PASS attribution $hexMode : $($hexReceipt.checks) checks; $($hexReceipt.cases.Count) cases."
        Get-FileHash -LiteralPath "$hexBase/receipt.json" -Algorithm SHA256
    }
} finally {
    if ($hexHadRoaming) { $env:APPDATA = $hexSavedRoaming } else { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue }
    Exit-FluxEngineRun $hexLease
}
