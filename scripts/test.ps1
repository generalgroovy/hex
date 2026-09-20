param(
    [ValidateSet('Focused', 'Fast', 'Full', 'Release')][string]$Tier = 'Full',
    [switch]$SkipFullSuite,
    [string[]]$Suite = @(),
    [switch]$ListSuites,
    [string]$ReceiptPath = ''
)
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$workflowLease = Enter-FluxEngineRun 'test'
try {

if ($SkipFullSuite) {
    $Tier = 'Fast'
}
if ($Tier -eq 'Focused' -and $Suite.Count -eq 0 -and -not $ListSuites) {
    throw 'Focused validation requires at least one stable suite ID via -Suite.'
}
if ($Tier -ne 'Focused' -and $Suite.Count -gt 0) {
    throw '-Suite is valid only with -Tier Focused so Full can never silently become partial.'
}

$repoRoot = Get-FluxRepoRoot
$logRoot = Join-Path $repoRoot ('.godot\windows-tests\' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$importLog = Join-Path $logRoot 'import.log'
$suiteLog = Join-Path $logRoot 'suite.log'
$bootLog = Join-Path $logRoot 'boot-120.log'
$executedLogs = [System.Collections.Generic.List[string]]::new()
$runImport = $Tier -in @('Fast', 'Full', 'Release')
$runSuites = $Tier -in @('Focused', 'Full', 'Release')
$runBoot = $Tier -in @('Fast', 'Full', 'Release')
$runAssetAudit = $Tier -in @('Full', 'Release')
# The growing unfiltered suite needs more supervision time than an individual
# import/capture/Focused run. The unified paid/geometry suite exceeded300s in
# u5-full-prefinal-v1; preserve its full workload with900s supervision.
# This is a watchdog, not the simulation budget.
$suiteTimeoutSeconds = if ($Tier -eq 'Full') { 900 } else { 180 }
if ($ListSuites) {
    $runImport = $false
    $runSuites = $false
    $runBoot = $false
    $runAssetAudit = $false
}
if ($runImport) { $executedLogs.Add($importLog) }
if ($runBoot) { $executedLogs.Add($bootLog) }
if ($runSuites -or $ListSuites) { $executedLogs.Add($suiteLog) }
foreach ($logPath in $executedLogs) {
    foreach ($generatedPath in @($logPath, "$logPath.err")) {
        if (Test-Path -LiteralPath $generatedPath -PathType Leaf) { Remove-Item -LiteralPath $generatedPath -Force }
    }
}
$hadSelectionEnvironment = Test-Path Env:FLUX2_TEST_SUITES
$previousSelectionEnvironment = $env:FLUX2_TEST_SUITES
$hadModeEnvironment = Test-Path Env:FLUX2_TEST_MODE
$previousModeEnvironment = $env:FLUX2_TEST_MODE
$hadRoamingEnvironment = Test-Path Env:APPDATA
$previousRoamingEnvironment = $env:APPDATA
$isolatedRoamingPath = Join-Path $logRoot 'isolated-roaming'
$caughtError = $null
$didCurrentStateCheck = $false
$didAssetAudit = $false
$freshCurrentState = $false
$freshAssetAudit = $false
$didDoctor = $false
$didImport = $false
$didSuites = $false
$didBoot = $false
$didPackageAndInstaller = $false
$clock = [System.Diagnostics.Stopwatch]::StartNew()
try {
    # A parent shell must never turn Full into a filtered run or a listing.
    Remove-Item Env:FLUX2_TEST_SUITES -ErrorAction SilentlyContinue
    Remove-Item Env:FLUX2_TEST_MODE -ErrorAction SilentlyContinue
    $godotBin = Get-FluxGodot
    $didCurrentStateCheck = $true
    & (Join-Path $PSScriptRoot 'current-state.ps1') -Check -Quiet
    $freshCurrentState = $true
    if ($runAssetAudit) {
        $didAssetAudit = $true
        & (Join-Path $PSScriptRoot 'asset-inventory.ps1') -Check -Quiet
        $freshAssetAudit = $true
    }
    $didDoctor = $true
    & (Join-Path $PSScriptRoot 'doctor.ps1') -RequireExportTemplates:($Tier -eq 'Release') -ExportTarget Windows
    # Engine discovery and template checks use the installed environment. All
    # test/import/boot user data then belongs to this disposable validation run.
    New-Item -ItemType Directory -Path $isolatedRoamingPath -Force | Out-Null
    $env:APPDATA = $isolatedRoamingPath
    if ($ListSuites) {
        $env:FLUX2_TEST_MODE = 'list'
        Invoke-FluxGodotChecked $godotBin @('--headless', '--path', $repoRoot, '--script', 'res://tests/run_all.gd') $suiteLog -RejectWarnings
        return
    }
    if ($runImport) {
        $didImport = $true
        Invoke-FluxGodotChecked $godotBin @('--headless', '--editor', '--path', $repoRoot, '--quit') $importLog -RejectWarnings
    }
    & (Join-Path $PSScriptRoot 'check-script-class-cache.ps1') -Json | Set-Content -LiteralPath (Join-Path $logRoot 'script-class-cache.json')
    if ($runSuites) {
        if ($Suite.Count -gt 0) { $env:FLUX2_TEST_SUITES = $Suite -join ',' }
        $didSuites = $true
        Invoke-FluxGodotChecked $godotBin @('--headless', '--path', $repoRoot, '--script', 'res://tests/run_all.gd') $suiteLog -RejectWarnings -TimeoutSeconds $suiteTimeoutSeconds
    }
    if ($runBoot) {
        $didBoot = $true
        Invoke-FluxGodotChecked $godotBin @('--headless', '--path', $repoRoot, '--quit-after', '3', '--fixed-fps', '120', '--', '--tick-rate=120', '--no-lan-discovery') $bootLog -RejectWarnings
    }
    if ($Tier -eq 'Release') {
        if ($hadRoamingEnvironment) { $env:APPDATA = $previousRoamingEnvironment } else { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue }
        $didPackageAndInstaller = $true
        & (Join-Path $PSScriptRoot 'package.ps1') -Target Windows
        & (Join-Path $PSScriptRoot 'test-windows-bootstrap.ps1')
    }
}
catch {
    $caughtError = $_
}
finally {
    $clock.Stop()
    if ($hadRoamingEnvironment) { $env:APPDATA = $previousRoamingEnvironment } else { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue }
    if ($hadSelectionEnvironment) { $env:FLUX2_TEST_SUITES = $previousSelectionEnvironment } else { Remove-Item Env:FLUX2_TEST_SUITES -ErrorAction SilentlyContinue }
    if ($hadModeEnvironment) { $env:FLUX2_TEST_MODE = $previousModeEnvironment } else { Remove-Item Env:FLUX2_TEST_MODE -ErrorAction SilentlyContinue }
}
$stderrBytes = 0
foreach ($logPath in $executedLogs) {
    $errorPath = "$logPath.err"
    if (Test-Path -LiteralPath $errorPath -PathType Leaf) {
        $stderrBytes += (Get-Item -LiteralPath $errorPath).Length
    }
}
$suiteResults = @()
if ($didSuites -and (Test-Path -LiteralPath $suiteLog -PathType Leaf)) {
    foreach ($line in Get-Content -LiteralPath $suiteLog) {
        if ($line -match '^([^:]+): ([0-9]+) assertions, ([0-9]+) failures$') {
            $suiteResults += [ordered]@{
                id = $Matches[1]
                assertions = [int]$Matches[2]
                failures = [int]$Matches[3]
            }
        }
    }
}
$statePath = Join-Path $logRoot 'current-state.json'
$assetReportPath = Join-Path $logRoot 'asset-inventory.json'
if ($freshCurrentState -and (Test-Path -LiteralPath (Join-Path $repoRoot '.godot/reports/current-state.json'))) {
    Copy-Item -LiteralPath (Join-Path $repoRoot '.godot/reports/current-state.json') -Destination $statePath
}
if ($freshAssetAudit -and (Test-Path -LiteralPath (Join-Path $repoRoot '.godot/reports/asset-inventory.json'))) {
    Copy-Item -LiteralPath (Join-Path $repoRoot '.godot/reports/asset-inventory.json') -Destination $assetReportPath
}
$state = if (Test-Path -LiteralPath $statePath -PathType Leaf) { Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json } else { $null }
$assertionCount = 0
foreach ($suiteResult in $suiteResults) { $assertionCount += [int]$suiteResult['assertions'] }
if (-not $ReceiptPath) {
    $ReceiptPath = Join-Path $repoRoot ('.godot\receipts\latest-{0}.json' -f $Tier.ToLowerInvariant())
} elseif (-not [System.IO.Path]::IsPathRooted($ReceiptPath)) {
    $ReceiptPath = Join-Path $repoRoot $ReceiptPath
}
$ReceiptPath = [System.IO.Path]::GetFullPath($ReceiptPath)
$logRecords = @()
foreach ($logPath in $executedLogs) {
    if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) { continue }
    $relativeLog = $logPath.Substring($repoRoot.Length).TrimStart('\').Replace('\', '/')
    $errorPath = "$logPath.err"
    $logRecords += [ordered]@{
        path = $relativeLog
        sha256 = Get-FluxFileSha256 $logPath
        stderr_bytes = if (Test-Path -LiteralPath $errorPath -PathType Leaf) { (Get-Item -LiteralPath $errorPath).Length } else { 0 }
    }
}
$receipt = [ordered]@{
    schema_version = 1
    completed_at_utc = [DateTime]::UtcNow.ToString('o')
    tier = $Tier.ToLowerInvariant()
    result = if ($null -eq $caughtError) { 'passed' } else { 'failed' }
    failure = if ($null -eq $caughtError) { $null } else { $caughtError.Exception.Message }
    source = [ordered]@{
        current_state_path = if ($freshCurrentState) { $statePath.Substring($repoRoot.Length + 1).Replace('\', '/') } else { $null }
        asset_inventory_path = if ($freshAssetAudit) { $assetReportPath.Substring($repoRoot.Length + 1).Replace('\', '/') } else { $null }
        head = if ($null -ne $state) { $state.git.head } else { $null }
        branch = if ($null -ne $state) { $state.git.current_branch } else { $null }
        dirty = if ($null -ne $state) { $state.git.dirty } else { $null }
        current_state_sha256 = if (Test-Path -LiteralPath $statePath -PathType Leaf) { Get-FluxFileSha256 $statePath } else { $null }
        asset_inventory_sha256 = if ($didAssetAudit -and (Test-Path -LiteralPath $assetReportPath -PathType Leaf)) { Get-FluxFileSha256 $assetReportPath } else { $null }
    }
    requested_suite_ids = @($Suite)
    supervision = [ordered]@{ default_engine_timeout_seconds = 180; suite_timeout_seconds = $suiteTimeoutSeconds }
    isolation = [ordered]@{
        appdata_path = $isolatedRoamingPath.Substring($repoRoot.Length + 1).Replace('\', '/')
        scope = 'Godot import, suite and boot user data; packaging retains its own isolation policy'
        caller_appdata_restored = ($env:APPDATA -eq $previousRoamingEnvironment)
    }
    executed = [ordered]@{
        current_state_check = $didCurrentStateCheck
        asset_inventory = $didAssetAudit
        doctor = $didDoctor
        import = $didImport
        deterministic_suite_runner = $didSuites
        suite_count = $suiteResults.Count
        assertion_count = $assertionCount
        suites = $suiteResults
        boot_120_hz = $didBoot
        package_and_installer = $didPackageAndInstaller
    }
    duration_ms = $clock.ElapsedMilliseconds
    stderr_bytes = $stderrBytes
    logs = $logRecords
}
$receiptDirectory = Split-Path -Parent $ReceiptPath
New-Item -ItemType Directory -Path $receiptDirectory -Force | Out-Null
$receiptJson = $receipt | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($ReceiptPath, $receiptJson + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText((Join-Path $logRoot 'receipt.json'), $receiptJson + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
if ($null -ne $caughtError) { throw $caughtError }
Write-Output ("PASS: Windows {0} gate completed in {1} ms; {2} suite(s), {3} assertions, stderr {4} bytes." -f $Tier.ToLowerInvariant(), $clock.ElapsedMilliseconds, $suiteResults.Count, $receipt.executed.assertion_count, $stderrBytes)
Write-Output "Receipt: $ReceiptPath"

} finally { Exit-FluxEngineRun $workflowLease }
