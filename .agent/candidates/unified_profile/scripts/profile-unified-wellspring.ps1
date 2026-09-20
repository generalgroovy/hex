param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9-]{2,60}$')][string]$RunId,
    [ValidateSet(720,7200)][int]$Ticks = 720
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')

$lease = Enter-FluxEngineRun 'profile-unified-wellspring'
$hadProfileAppData = Test-Path Env:APPDATA
$savedProfileAppData = $env:APPDATA
$repo = Get-FluxRepoRoot
$output = Join-Path $repo ".godot/unified-wellspring-profile-$RunId.json"
$logs = Join-Path $repo ".godot/unified-wellspring-profile-$RunId-logs"
$personalProfilePath = $null
$personalProfileBefore = 'appdata-unavailable'
$runFailure = $null

try {
    if ($Ticks -eq 7200) {
        throw 'The 7200-tick soak is blocked until it is split into bounded invocations; flux2-common.ps1 permits at most a 300-second engine watchdog.'
    }
    if ((Test-Path -LiteralPath $output) -or (Test-Path -LiteralPath $logs)) {
        throw 'Choose a fresh RunId; retained unified Wellspring profile paths are immutable.'
    }
    New-Item -ItemType Directory -Path $logs | Out-Null
    if ($hadProfileAppData) {
        $personalProfilePath = Join-Path $savedProfileAppData 'Godot/app_userdata/FLUX 2/player_preferences_v1.json'
        $personalProfileBefore = if (Test-Path -LiteralPath $personalProfilePath) { (Get-FileHash -LiteralPath $personalProfilePath).Hash } else { 'absent' }
    }
    $env:APPDATA = Join-Path $logs 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null

    & (Join-Path $PSScriptRoot 'runtime-build-identity.ps1') -Mode Check -Json |
        Set-Content -LiteralPath (Join-Path $logs 'identity-check.json')
    & (Join-Path $PSScriptRoot 'check-script-class-cache.ps1') -Json |
        Set-Content -LiteralPath (Join-Path $logs 'class-cache.json')
    [ordered]@{
        captured_utc = [DateTime]::UtcNow.ToString('o')
        run_id = $RunId
        sample_ticks = $Ticks
        computer = @(Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model, TotalPhysicalMemory)
        processor = @(Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed)
        operating_system = @(Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber)
        video = @(Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, AdapterRAM)
        power_plan = (powercfg /getactivescheme 2>&1 | Out-String).Trim()
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $logs 'hardware.json')

    $timeout = 300
    Invoke-FluxGodotChecked (Get-FluxGodot) @(
        '--headless',
        '--path', $repo,
        '--script', 'res://tests/performance/profile_unified_wellspring.gd',
        '--',
        "--ticks=$Ticks",
        "--output=res://.godot/unified-wellspring-profile-$RunId.json"
    ) (Join-Path $logs 'profile.log') -RejectWarnings -TimeoutSeconds $timeout

    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
        throw 'Unified Wellspring profiler exited without its scoped JSON receipt.'
    }
    $receipt = Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
    if ([int]$receipt.schema_version -ne 1 -or $receipt.workload_version -cne 'unified-wellspring-profile-v1') {
        throw 'Unified Wellspring profile receipt has an unexpected schema or workload version.'
    }
    if ([int]$receipt.failures -ne 0 -or [int]$receipt.sample_ticks -ne $Ticks -or [int]$receipt.repetitions_per_case -ne 2) {
        throw 'Unified Wellspring profile receipt failed its bounded workload contract.'
    }
    if (@($receipt.cases).Count -ne 2 -or @($receipt.runs).Count -ne 4) {
        throw 'Unified Wellspring profile receipt is missing one case or matched repeat.'
    }
    if ($receipt.performance_acceptance -notmatch '^NOT_ESTABLISHED;') {
        throw 'Unified Wellspring profile receipt must retain its diagnostic-only evidence boundary.'
    }
}
catch {
    $runFailure = $_
    if (Test-Path -LiteralPath $logs -PathType Container) {
        [ordered]@{
            failed_utc = [DateTime]::UtcNow.ToString('o')
            type = $_.Exception.GetType().FullName
            message = $_.Exception.Message
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logs 'failure.json')
    }
}
finally {
    try {
        if ($hadProfileAppData) {
            $env:APPDATA = $savedProfileAppData
        }
        else {
            Remove-Item Env:APPDATA -ErrorAction SilentlyContinue
        }
        $personalProfileAfter = if ($personalProfilePath -and (Test-Path -LiteralPath $personalProfilePath)) { (Get-FileHash -LiteralPath $personalProfilePath).Hash } elseif ($personalProfilePath) { 'absent' } else { 'appdata-unavailable' }
        if (Test-Path -LiteralPath $logs -PathType Container) {
            [ordered]@{
                before = $personalProfileBefore
                after = $personalProfileAfter
                unchanged = ($personalProfileBefore -ceq $personalProfileAfter)
                appdata_restored = ((Test-Path Env:APPDATA) -eq $hadProfileAppData) -and (-not $hadProfileAppData -or $env:APPDATA -ceq $savedProfileAppData)
            } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logs 'profile-guard.json')
        }
        if ($personalProfileBefore -cne $personalProfileAfter -and -not $runFailure) {
            $runFailure = [System.InvalidOperationException]::new('Personal profile changed; quarantine this measurement and inspect profile-guard.json.')
        }
    }
    finally {
        Exit-FluxEngineRun $lease
    }
}

if ($runFailure) {
    throw $runFailure
}

Write-Output "PASS: diagnostic unified Wellspring profile completed; receipt=$output; performance_acceptance=NOT_ESTABLISHED"
