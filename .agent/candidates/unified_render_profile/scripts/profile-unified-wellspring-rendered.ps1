param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9-]{2,60}$')][string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')

$lease = Enter-FluxEngineRun 'profile-unified-wellspring-rendered'
$hadProfileAppData = Test-Path Env:APPDATA
$savedProfileAppData = $env:APPDATA
$repo = Get-FluxRepoRoot
$output = Join-Path $repo ".godot/unified-wellspring-render-profile-$RunId.json"
$logs = Join-Path $repo ".godot/unified-wellspring-render-profile-$RunId-logs"
$personalProfilePath = $null
$personalProfileBefore = 'appdata-unavailable'
$runFailure = $null

try {
    if ((Test-Path -LiteralPath $output) -or (Test-Path -LiteralPath $logs)) {
        throw 'Choose a fresh RunId; retained unified Wellspring render-profile paths are immutable.'
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
        workload = 'unified-wellspring-render-profile-v1'
        sample_ticks_per_run = 720
        presentation = 'native window, 1280x720, fixed 60 Hz, two 120 Hz simulation ticks per frame'
        computer = @(Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model, TotalPhysicalMemory)
        processor = @(Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed)
        operating_system = @(Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber)
        video = @(Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, AdapterRAM, CurrentHorizontalResolution, CurrentVerticalResolution, CurrentRefreshRate)
        power_plan = (powercfg /getactivescheme 2>&1 | Out-String).Trim()
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $logs 'hardware.json')

    # Deliberately native: --headless would invalidate the rendered evidence.
    Invoke-FluxGodotChecked (Get-FluxGodot) @(
        '--path', $repo,
        '--windowed',
        '--resolution', '1280x720',
        '--fixed-fps', '60',
        '--script', 'res://tests/performance/profile_unified_wellspring_rendered.gd',
        '--',
        "--output=res://.godot/unified-wellspring-render-profile-$RunId.json"
    ) (Join-Path $logs 'profile.log') -RejectWarnings -TimeoutSeconds 300

    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
        throw 'Unified Wellspring rendered profiler exited without its scoped JSON receipt.'
    }
    $receipt = Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
    if ([int]$receipt.schema_version -ne 1 -or $receipt.workload_version -cne 'unified-wellspring-render-profile-v1') {
        throw 'Unified Wellspring render-profile receipt has an unexpected schema or workload version.'
    }
    if ([int]$receipt.failures -ne 0 -or [int]$receipt.sample_ticks -ne 720 -or [int]$receipt.ticks_per_present_frame -ne 2) {
        throw 'Unified Wellspring render-profile receipt failed its bounded workload contract.'
    }
    if ($receipt.display_server -ceq 'headless' -or @($receipt.cases).Count -ne 2 -or @($receipt.modes).Count -ne 2 -or @($receipt.runs).Count -ne 4) {
        throw 'Unified Wellspring render-profile receipt is missing native matched case/mode runs.'
    }
    foreach ($caseName in @('sustained-distributed', 'dense-crucible')) {
        $caseRuns = @($receipt.runs | Where-Object { $_.case -ceq $caseName })
        $caseModes = @($caseRuns | ForEach-Object { [string]$_.visual_mode } | Sort-Object)
        if ($caseRuns.Count -ne 2 -or ($caseModes -join ',') -cne 'normal,reduced') {
            throw "Rendered receipt lacks the matched normal/reduced pair for $caseName."
        }
    }
    foreach ($run in @($receipt.runs)) {
        if ([int]$run.sample_ticks -ne 720 -or [int]$run.present_frames -ne 360 -or
            [int]$run.draw_authority_checks -ne 7 -or [int]$run.draw_authority_mutations -ne 0) {
            throw 'A rendered run violated the matched 720-tick/360-frame authority contract.'
        }
        if ([int]$run.present_frame_elapsed_us.samples -ne 360 -or [int]$run.two_tick_sim_us.samples -ne 360 -or
            [int]$run.bootstrap_draw_submission_us.samples -ne 360 -or [int]$run.render_monitors.draw_calls_per_frame.samples -ne 360 -or
            [int]$run.render_monitors.primitives_per_frame.samples -ne 360) {
            throw 'A rendered run lacks its complete timing or production render-counter samples.'
        }
        if ([int]$run.workload_totals.requested_pressed -le 0 -or [int]$run.workload_totals.requested_held_ticks -le 0 -or
            [int]$run.workload_totals.admitted -le 0 -or [int]$run.workload_totals.active_cell_instance_ticks -le 0 -or
            [int]$run.alive_work.mean_alive_actors -ne 8) {
            throw 'A rendered run silently lowered or lost the legal eight-champion paid workload.'
        }
    }
    if ($receipt.performance_acceptance -notmatch '^NOT_ESTABLISHED;') {
        throw 'Unified Wellspring render-profile receipt must retain its diagnostic-only evidence boundary.'
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

Write-Output "PASS: native diagnostic unified Wellspring render profile completed; receipt=$output; performance_acceptance=NOT_ESTABLISHED"
