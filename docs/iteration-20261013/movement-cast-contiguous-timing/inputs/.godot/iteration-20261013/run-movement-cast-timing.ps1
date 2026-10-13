param(
    [ValidateSet('functional','forward','reverse')][string]$Mode = 'functional',
    [Parameter(Mandatory)][ValidateSet('garden_idle','fire_close','bootstrap_roster_mantle')][string]$Case,
    [ValidatePattern('^[a-z0-9-]{1,16}$')][string]$RunSuffix = 'a',
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{64}$')][string]$ExpectedDriverSha256,
    [string]$FunctionalReceipt = '',
    [string]$ExpectedFunctionalSha256 = ''
)
$ErrorActionPreference = 'Stop'
. ./scripts/flux2-common.ps1
$hexRoot = [IO.Path]::GetFullPath("$PWD")
$hexDriver = '.godot/iteration-20261013/movement-cast-timing/compare-movement-cast-timing.gd'
if ((Get-FileHash -LiteralPath $hexDriver).Hash.ToLowerInvariant() -cne $ExpectedDriverSha256) { throw 'Reviewed timing driver differs' }
$hexFunctionalPath = ''
if ($Mode -eq 'functional') {
    if ($Case -cne 'bootstrap_roster_mantle' -or $FunctionalReceipt -or $ExpectedFunctionalSha256) { throw 'Only new roster functional qualification is allowed without a prior receipt' }
} else {
    if (-not $FunctionalReceipt -or $ExpectedFunctionalSha256 -cnotmatch '^[a-f0-9]{64}$') { throw 'Exact functional receipt and hash required for timing' }
    $hexFunctionalPath = [IO.Path]::GetFullPath((Join-Path $hexRoot ($FunctionalReceipt -replace '^res://','')))
    if (-not $hexFunctionalPath.StartsWith($hexRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Functional receipt escapes checkout' }
    if ((Get-FileHash -LiteralPath $hexFunctionalPath).Hash.ToLowerInvariant() -cne $ExpectedFunctionalSha256) { throw 'Qualified functional receipt differs' }
}
$hexRuns = '.godot/iteration-20261013/movement-cast-timing/runs'
$hexBase = "$hexRuns/probe-$Mode-$Case-$RunSuffix"
foreach ($hexFresh in @($hexBase, "$hexBase.log", "$hexBase.log.err", "$hexBase-parse.log", "$hexBase-parse.log.err", "$hexBase-roaming")) {
    if (Test-Path -LiteralPath $hexFresh) { throw "Fresh output required: $hexFresh" }
}
$hexSavedRoaming = $env:APPDATA
$hexHadRoaming = Test-Path Env:APPDATA
$hexLease = Enter-FluxEngineRun 'movement-cast-timing'
try {
    New-Item -ItemType Directory -Path $hexRuns -Force | Out-Null
    $env:APPDATA = Join-Path $hexRoot "$hexBase-roaming"
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    Invoke-FluxGodotChecked (Get-FluxGodot) @('--headless','--path',$hexRoot,'--check-only','--script',"res://$hexDriver") (Join-Path $hexRoot "$hexBase-parse.log") -RejectWarnings -TimeoutSeconds 180 | Out-Null
    $hexArguments = @('--path',$hexRoot,'--audio-driver','Dummy','--script',"res://$hexDriver",'--','--no-lan-discovery',"--output=res://$hexBase","--case=$Case")
    if ($Mode -eq 'functional') {
        $hexArguments = @('--headless') + $hexArguments + @('--functional-only')
    } else {
        $hexRelativeFunctional = $hexFunctionalPath.Substring($hexRoot.Length + 1).Replace('\','/')
        $hexArguments += @("--functional-receipt=res://$hexRelativeFunctional", "--functional-sha256=$ExpectedFunctionalSha256")
    }
    if ($Mode -eq 'reverse') { $hexArguments += '--reverse-order' }
    Invoke-FluxGodotChecked (Get-FluxGodot) $hexArguments (Join-Path $hexRoot "$hexBase.log") -RejectWarnings -TimeoutSeconds 600 | Out-Null
    $hexReceipt = Get-Content -LiteralPath "$hexBase/receipt.json" -Raw | ConvertFrom-Json
    $hexExpectedMode = if ($Mode -eq 'functional') { 'functional' } else { 'timing' }
    if ($hexReceipt.schema -cne 'hex-movement-cast-contiguous-timing-v1' -or $hexReceipt.passed -ne $true -or $hexReceipt.errors.Count -ne 0 -or $hexReceipt.checks -lt 1 -or $hexReceipt.mode -cne $hexExpectedMode) { throw "Timing companion receipt failed: $Mode" }
    if ($hexReceipt.selected_case -cne $Case -or $hexReceipt.cases.Count -ne 1 -or $hexReceipt.cases[0].label -cne $Case) { throw 'Selected case differs from executed case' }
    if ($hexReceipt.cleanup.ended_worlds -ne 2 -or $hexReceipt.cleanup.remaining_worlds -ne 0 -or $hexReceipt.cleanup.factory_owned -cne $false) { throw 'Timing companion ownership did not close' }
    $hexExpectedQualification = if ($Mode -eq 'functional') { '' } else { "res://$hexRelativeFunctional" }
    if ($hexReceipt.qualification.path -cne $hexExpectedQualification -or $hexReceipt.qualification.sha256 -cne $ExpectedFunctionalSha256) { throw 'Timing qualification linkage differs' }
    if ($hexReceipt.reverse_initial_order -cne ($Mode -eq 'reverse')) { throw 'Timing invocation order differs' }
    if (@($hexReceipt.source_hashes.PSObject.Properties).Count -lt 3) { throw 'Source pin inventory missing' }
    foreach ($hexProperty in $hexReceipt.source_hashes.PSObject.Properties) {
        $hexPath = [IO.Path]::GetFullPath((Join-Path $hexRoot ($hexProperty.Name -replace '^res://','')))
        if (-not $hexPath.StartsWith($hexRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Source pin escapes checkout' }
        if ((Get-FileHash -LiteralPath $hexPath).Hash.ToLowerInvariant() -cne $hexProperty.Value) { throw "Source pin changed: $hexPath" }
    }
    Write-Output "PASS timing companion $Mode/$Case : $($hexReceipt.checks) checks."
    Get-FileHash -LiteralPath "$hexBase/receipt.json" -Algorithm SHA256
} finally {
    if ($hexHadRoaming) { $env:APPDATA = $hexSavedRoaming } else { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue }
    Exit-FluxEngineRun $hexLease
    if ((Get-FileHash -LiteralPath $hexDriver).Hash.ToLowerInvariant() -cne $ExpectedDriverSha256) { throw 'Timing driver changed during execution' }
    if ($hexFunctionalPath -and (Get-FileHash -LiteralPath $hexFunctionalPath).Hash.ToLowerInvariant() -cne $ExpectedFunctionalSha256) { throw 'Functional receipt changed during execution' }
}
