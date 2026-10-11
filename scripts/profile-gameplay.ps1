[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [ValidateSet('low', 'standard')][string[]]$Profiles = @('low', 'standard'),
    [ValidateSet('hearth_idle', 'garden_entry', 'garden_middle', 'paid_fire_bolt', 'paid_all_six_mantle', 'movement_boundary', 'range_paid_fire', 'paid_fire_bolt_close')]
    [string[]]$Cases = @('hearth_idle', 'garden_entry', 'garden_middle', 'paid_fire_bolt', 'paid_all_six_mantle', 'movement_boundary', 'range_paid_fire'),
    [ValidateRange(1, 600)][double]$SecondsPerCase = 10,
    [ValidateRange(0, 3600)][double]$SoakSeconds = 0,
    [ValidateSet(0, 60, 120)][int]$FrameLimit = 60,
    [ValidateRange(960, 2560)][int]$Width = 1280,
    [ValidateRange(540, 1440)][int]$Height = 720,
    [switch]$LightObserver,
    [switch]$Screenshots,
    [ValidateRange(1, 1800)][int]$TimeoutSeconds = 900
)

# Native source diagnostic only. This wrapper never imports, changes a runtime
# identity, promotes a build, or runs a packaged release executable.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')

function Get-GameplayProfileValue($Object, [string]$Name, $Default = $null) {
    if ($null -eq $Object) { return $Default }
    if ($Object -is [Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $Default
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    return $property.Value
}

function Get-GameplayProfileMemory {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -Property Caption, Version, FreePhysicalMemory, TotalVisibleMemorySize -ErrorAction Stop
        return [ordered]@{ observed_utc = [DateTime]::UtcNow.ToString('o'); os = $os.Caption; os_version = $os.Version; available_mb = [Math]::Round([double]$os.FreePhysicalMemory / 1024.0, 2); total_visible_mb = [Math]::Round([double]$os.TotalVisibleMemorySize / 1024.0, 2); error = $null }
    } catch {
        return [ordered]@{ observed_utc = [DateTime]::UtcNow.ToString('o'); available_mb = $null; error = $_.Exception.Message }
    }
}

function Write-GameplayProfileReceipt([string]$Path, $Value) {
    $text = ($Value | ConvertTo-Json -Depth 64) + [Environment]::NewLine
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($text)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
    if ([IO.File]::ReadAllText($Path) -cne $text) { throw "Receipt read-back differs: $Path" }
}

function Get-GameplayProfileExpectedRows([string[]]$SelectedProfiles, [string[]]$SelectedCases, [double]$SelectedSoak) {
    [pscustomobject]@{ label = 'startup_arrival'; quality = $SelectedProfiles[0]; temperature = 'cold_process_cache' }
    foreach ($quality in $SelectedProfiles) {
        foreach ($label in $SelectedCases) {
            if ($label -in @('garden_entry', 'garden_middle')) {
                [pscustomobject]@{ label = $label + '_arrival'; quality = $quality; temperature = 'travel_process_cache_state_recorded' }
            }
            [pscustomobject]@{ label = $label; quality = $quality; temperature = 'warm' }
        }
        if ($SelectedSoak -gt 0) {
            [pscustomobject]@{ label = 'garden_middle_arrival'; quality = $quality; temperature = 'travel_process_cache_state_recorded' }
            [pscustomobject]@{ label = 'garden_soak'; quality = $quality; temperature = 'warm' }
        }
    }
}

function Get-GameplayProfileReportErrors($Report, $Expected) {
    $errors = [Collections.Generic.List[string]]::new()
    if ((Get-GameplayProfileValue $Report 'schema' '') -cne 'hex-gameplay-profile-v1' -or (Get-GameplayProfileValue $Report 'complete' $false) -cne $true) { $errors.Add('Benchmark receipt is absent, incompatible, or incomplete.') }
    if (Get-GameplayProfileValue $Report 'error' '') { $errors.Add('Benchmark receipt records an error.') }
    foreach ($key in @('observed_source_before', 'observed_source_after')) {
        $snapshot = Get-GameplayProfileValue $Report $key
        if ((Get-GameplayProfileValue $snapshot 'ok' $false) -cne $true -or (Get-GameplayProfileValue $snapshot 'sha256' '') -cnotmatch '^[0-9a-f]{64}$') { $errors.Add("Missing valid independent source snapshot: $key") }
    }
    $before = Get-GameplayProfileValue $Report 'observed_source_before'
    $after = Get-GameplayProfileValue $Report 'observed_source_after'
    if ((Get-GameplayProfileValue $Report 'observed_source_unchanged' $false) -cne $true -or (Get-GameplayProfileValue $before 'sha256' '') -cne (Get-GameplayProfileValue $after 'sha256' '')) { $errors.Add('Benchmark source changed during the run.') }
    if ((Get-GameplayProfileValue $Report 'profile_script_sha256' '') -cne $Expected.script_sha256) { $errors.Add('Benchmark script identity differs from the launched source.') }
    $manifest = Get-GameplayProfileValue $Report 'manifest'
    foreach ($key in @('build_id', 'runtime_source_sha256', 'engine_identity', 'protocol_version', 'snapshot_schema', 'record_count')) {
        if ((Get-GameplayProfileValue $manifest $key) -cne (Get-GameplayProfileValue $Expected.identity $key)) { $errors.Add("Runtime manifest mismatch: $key") }
    }
    if (([string](Get-GameplayProfileValue $Report 'user_data' '')).Replace('\', '/').TrimEnd('/') -ine $Expected.user_data.Replace('\', '/').TrimEnd('/')) { $errors.Add('Runtime user-data directory is not the exact isolated profile.') }
    if (([string](Get-GameplayProfileValue $Report 'executable' '')).Replace('\', '/') -ine $Expected.engine.Replace('\', '/')) { $errors.Add('Runtime executable differs from the selected Godot binary.') }
    $engine = Get-GameplayProfileValue $Report 'engine'
    $enginePrefix = (@('major', 'minor', 'patch', 'status', 'build') | ForEach-Object { [string](Get-GameplayProfileValue $engine $_ '') }) -join '.'
    $engineHash = [string](Get-GameplayProfileValue $engine 'hash' '')
    $expectedEngineHash = ([string]$Expected.identity.engine_identity).Split('.')[-1]
    if ($Expected.identity.engine_identity -cne ($enginePrefix + '.' + $expectedEngineHash) -or $engineHash -cnotmatch '^[0-9a-f]{40}$' -or -not $engineHash.StartsWith($expectedEngineHash, [StringComparison]::Ordinal)) { $errors.Add('Runtime engine version differs from the canonical identity.') }
    if ((Get-GameplayProfileValue $Report 'display_server' '') -in @('', 'headless')) { $errors.Add('A native display is required.') }
    foreach ($entry in @(@('frame_limit', $Expected.frame_limit), @('case_seconds', $Expected.seconds), @('soak_seconds', $Expected.soak), @('observer_mode', $Expected.observer), @('tick_rate', 120), @('protocol', $Expected.identity.protocol_version))) {
        if ((Get-GameplayProfileValue $Report $entry[0]) -cne $entry[1]) { $errors.Add("Runtime setting mismatch: $($entry[0])") }
    }
    if ((@(Get-GameplayProfileValue $Report 'profiles' @()) -join ',') -cne ($Expected.profiles -join ',')) { $errors.Add('Runtime quality profile order differs from the request.') }
    if ((@(Get-GameplayProfileValue $Report 'window_size' @()) -join ',') -cne (@($Expected.width, $Expected.height) -join ',')) { $errors.Add('Actual native window size differs from the requested bounds.') }
    $expectedRows = @(Get-GameplayProfileExpectedRows $Expected.profiles $Expected.cases $Expected.soak)
    $rows = @(Get-GameplayProfileValue $Report 'results' @())
    if ($rows.Count -ne $expectedRows.Count) { $errors.Add("Expected $($expectedRows.Count) exact startup/travel/warm rows, received $($rows.Count).") }
    for ($index = 0; $index -lt [Math]::Min($rows.Count, $expectedRows.Count); $index++) {
        $row = $rows[$index]
        $wanted = $expectedRows[$index]
        foreach ($key in @('label', 'quality', 'temperature')) {
            if ((Get-GameplayProfileValue $row $key '') -cne $wanted.$key) { $errors.Add("Result $index has the wrong $key.") }
        }
        if ((Get-GameplayProfileValue $row 'ready' $false) -cne $true) { $errors.Add("Result $index did not reach actual terrain readiness.") }
        if ($wanted.temperature -cne 'warm') { continue }
        $samples = Get-GameplayProfileValue $row 'frame_interval_ms'
        if ((Get-GameplayProfileValue $samples 'count' 0) -lt 1 -or (Get-GameplayProfileValue $row 'ticks_advanced' 0) -lt 1) { $errors.Add("Warm result $index has no frame interval or simulation progress.") }
        if ($wanted.label -in @('paid_fire_bolt', 'paid_all_six_mantle', 'range_paid_fire', 'paid_fire_bolt_close')) {
            if ((Get-GameplayProfileValue $row 'cast_attempts' 0) -lt 1 -or (Get-GameplayProfileValue $row 'matter_paid_delta' 0) -lt 1) { $errors.Add("Paid result $index has no actual payment witness.") }
        }
        if ($wanted.label -ceq 'paid_fire_bolt_close') {
            $fixture = Get-GameplayProfileValue $row 'fixture'
            foreach ($entry in @(@('cast_attempts', 12), @('admitted_casts_delta', 12), @('refused_casts_delta', 0), @('matter_paid_delta', 7200))) {
                if ((Get-GameplayProfileValue $row $entry[0] -1) -ne $entry[1]) { $errors.Add("Close Fire result $index lacks the complete finite paid witness: $($entry[0]).") }
            }
            if ((Get-GameplayProfileValue $fixture 'finite_attempt_limit' 0) -ne 12 -or (Get-GameplayProfileValue $fixture 'spell_wire' 0) -ne 145 -or (Get-GameplayProfileValue $fixture 'target_distance_px' 0) -ne 200 -or (Get-GameplayProfileValue $fixture 'resource_refill' $true) -cne $false -or (@(Get-GameplayProfileValue $fixture 'target_world_px' @()) -join ',') -cne '1736,880' -or (@(Get-GameplayProfileValue $row 'position_before' @()) -join ',') -cne '1536,880') { $errors.Add("Close Fire result $index does not describe the actual near-target, unrefilled fixture.") }
            $attemptTicks = @(Get-GameplayProfileValue $row 'cast_attempt_ticks' @())
            if ($attemptTicks.Count -ne 12) { $errors.Add("Close Fire result $index lacks all twelve raw command ticks.") }
            for ($attempt = 1; $attempt -lt $attemptTicks.Count; $attempt++) {
                if ([long]$attemptTicks[$attempt] -le [long]$attemptTicks[$attempt - 1]) { $errors.Add("Close Fire result $index has unordered or duplicate command ticks.") }
            }
            if ($Expected.observer -ceq 'full') {
                $components = Get-GameplayProfileValue $row 'main_court_components_total_us'
                $observation = Get-GameplayProfileValue $row 'close_fire_observation'
                if ((Get-GameplayProfileValue $row 'max_paid_cells' 0) -lt 1 -or (Get-GameplayProfileValue $components 'bundle' 0) -le 0 -or (Get-GameplayProfileValue $components 'surface' 0) -le 0 -or (Get-GameplayProfileValue $observation 'accepted_prepared_regions' 0) -lt 1) { $errors.Add("Close Fire result $index never witnessed actual prepared visible paid material.") }
            }
        }
        if (Get-GameplayProfileValue $Expected 'screenshots' $false) {
            $shotPath = [string](Get-GameplayProfileValue $row 'screenshot' '')
            $wantedShot = Join-Path ([IO.Path]::GetDirectoryName($Expected.metrics_path)) ([IO.Path]::GetFileNameWithoutExtension($Expected.metrics_path) + '-' + $wanted.quality + '-' + $wanted.label + '.png')
            if ($shotPath.Replace('\', '/') -ine $wantedShot.Replace('\', '/') -or -not (Test-Path -LiteralPath $wantedShot -PathType Leaf) -or (Get-Item -LiteralPath $wantedShot).Length -le 8) { $errors.Add("Requested screenshot is absent or failed for warm result $index.") }
        }
    }
    return $errors.ToArray()
}

function Get-GameplayProfileCompactReport($Report) {
    if ($null -eq $Report) { return $null }
    $compact = [ordered]@{}
    foreach ($property in $Report.PSObject.Properties) {
        if ($property.Name -eq 'results') {
            $rows = [Collections.Generic.List[object]]::new()
            foreach ($row in $property.Value) {
                $small = [ordered]@{}
                foreach ($field in $row.PSObject.Properties) { if ($field.Name -cne 'raw') { $small[$field.Name] = $field.Value } }
                $rows.Add($small)
            }
            $compact[$property.Name] = $rows.ToArray()
        } elseif ($property.Name -in @('observed_source_before', 'observed_source_after')) {
            $snapshot = [ordered]@{}
            foreach ($field in $property.Value.PSObject.Properties) { if ($field.Name -cne 'files') { $snapshot[$field.Name] = $field.Value } }
            $compact[$property.Name] = $snapshot
        } else { $compact[$property.Name] = $property.Value }
    }
    return $compact
}

$profileRoot = Get-FluxRepoRoot
# PowerShell ValidateSet is case-insensitive; the GDScript CLI is not.
$Profiles = @($Profiles | ForEach-Object { $_.ToLowerInvariant() })
$Cases = @($Cases | ForEach-Object { $_.ToLowerInvariant() })
if (-not [IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory = Join-Path $profileRoot $OutputDirectory }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Choose a fresh benchmark output directory; existing evidence is never overwritten.' }
if ($Profiles.Count -eq 0 -or @($Profiles | Select-Object -Unique).Count -ne $Profiles.Count -or $Cases.Count -eq 0 -or @($Cases | Select-Object -Unique).Count -ne $Cases.Count) { throw 'Select nonempty profiles and cases without duplicates.' }
if (-not [double]::IsFinite($SecondsPerCase) -or -not [double]::IsFinite($SoakSeconds)) { throw 'Diagnostic durations must be finite.' }
$minimumSeconds = $Profiles.Count * ($Cases.Count * ($SecondsPerCase + 1) + $(if ($SoakSeconds -gt 0) { $SoakSeconds + 1 } else { 0 }))
if ($minimumSeconds -ge $TimeoutSeconds) { throw "Requested case/soak durations and one-second warmups need at least $minimumSeconds seconds, before extra startup/preparation; choose a smaller matrix or larger watchdog (maximum1800)." }
$profileScript = Join-Path $profileRoot 'scripts/profile-gameplay.gd'
$profileIdentityScript = Join-Path $profileRoot 'scripts/runtime-build-identity.ps1'
$profileManifestPath = Join-Path $profileRoot 'content/runtime/runtime_build_identity_v1.json'
$profileProject = Get-Content -Raw -LiteralPath (Join-Path $profileRoot 'project.godot')
if ($profileProject -notmatch '(?m)^config/use_custom_user_dir=true\s*$' -or $profileProject -notmatch '(?m)^config/custom_user_dir_name="Godot/app_userdata/FLUX 2"\s*$') { throw 'Review the exact engine user-data contract before running this benchmark.' }
$profileEngine = Get-FluxGodot
$profileLease = Enter-FluxEngineRun 'profile-native-gameplay'
$profileHadAppData = Test-Path Env:APPDATA
$profileSavedAppData = $env:APPDATA
$profileErrors = [Collections.Generic.List[string]]::new()
$profileReport = $null
$profileIdentityBefore = $null
$profileIdentityAfter = $null
$profileBefore = [ordered]@{}
$profileAfter = [ordered]@{}
$profileMemoryBefore = Get-GameplayProfileMemory
$profileWatch = [Diagnostics.Stopwatch]::StartNew()
$profileArguments = @()
$profileMetricsPath = Join-Path $OutputDirectory 'metrics.json'
$profileLogPath = Join-Path $OutputDirectory 'engine.log'
try {
    New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    $profileIdentityBefore = (& $profileIdentityScript -Mode Check -Json | Out-String) | ConvertFrom-Json -ErrorAction Stop
    foreach ($path in @($profileScript, $PSCommandPath, $profileIdentityScript, (Join-Path $PSScriptRoot 'flux2-common.ps1'), (Join-Path $PSScriptRoot 'engine-guard.ps1'), $profileManifestPath)) { $profileBefore[$path] = Get-FluxFileSha256 $path }
    Copy-Item -LiteralPath $profileManifestPath -Destination (Join-Path $OutputDirectory 'runtime-identity.input.json')
    $env:APPDATA = Join-Path $OutputDirectory 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    $profileExpectedUserData = Join-Path $env:APPDATA 'Godot/app_userdata/FLUX 2'
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $profileArguments = @('--path', $profileRoot, '--script', 'res://scripts/profile-gameplay.gd', '--windowed', '--resolution', "${Width}x${Height}", '--', '--no-lan-discovery', '--fullbody-art', '--pixel-cast', "--profile-output=$profileMetricsPath", "--profile-user-data=$profileExpectedUserData", ('--profile-seconds=' + $SecondsPerCase.ToString('R', $culture)), ('--profile-soak-seconds=' + $SoakSeconds.ToString('R', $culture)), ('--profile-profiles=' + ($Profiles -join ',')), ('--profile-cases=' + ($Cases -join ',')), "--profile-frame-limit=$FrameLimit", "--profile-width=$Width", "--profile-height=$Height")
    if ($LightObserver) { $profileArguments += '--profile-light-observer' }
    if ($Screenshots) { $profileArguments += '--profile-screenshots' }
    Push-Location -LiteralPath $profileRoot
    try { Invoke-FluxGodotChecked $profileEngine $profileArguments $profileLogPath -RejectWarnings -TimeoutSeconds $TimeoutSeconds | Out-Null }
    catch { $profileErrors.Add($_.Exception.Message) }
    finally { Pop-Location }
    if (-not (Test-Path -LiteralPath $profileMetricsPath -PathType Leaf)) { $profileErrors.Add('Complete metrics.json is missing; any partial report remains unqualified evidence.') }
    else {
        $profileReport = Get-Content -Raw -LiteralPath $profileMetricsPath | ConvertFrom-Json -ErrorAction Stop
        $expected = @{ profiles = $Profiles; cases = $Cases; seconds = $SecondsPerCase; soak = $SoakSeconds; frame_limit = $FrameLimit; width = $Width; height = $Height; observer = $(if ($LightObserver) { 'light' } else { 'full' }); identity = $profileIdentityBefore; engine = $profileEngine; user_data = $profileExpectedUserData; script_sha256 = $profileBefore[$profileScript]; screenshots = [bool]$Screenshots; metrics_path = $profileMetricsPath }
        foreach ($message in @(Get-GameplayProfileReportErrors $profileReport $expected)) { $profileErrors.Add($message) }
    }
    $completeLines = @(if (Test-Path -LiteralPath $profileLogPath) { Get-Content -LiteralPath $profileLogPath | Where-Object { $_ -ceq "HEX_GAMEPLAY_PROFILE_COMPLETE $profileMetricsPath" -or $_ -ceq ('HEX_GAMEPLAY_PROFILE_COMPLETE ' + $profileMetricsPath.Replace('\', '/')) } })
    if ($completeLines.Count -ne 1) { $profileErrors.Add('Expected exactly one matching complete-report marker in the native log.') }
    $stderrPath = "$profileLogPath.err"
    if (-not (Test-Path -LiteralPath $stderrPath) -or (Get-Item -LiteralPath $stderrPath).Length -ne 0) { $profileErrors.Add('Native stderr is missing or nonempty; inspect the preserved log.') }
    $profileIdentityAfter = (& $profileIdentityScript -Mode Check -Json | Out-String) | ConvertFrom-Json -ErrorAction Stop
    if ($profileIdentityBefore.runtime_source_sha256 -cne $profileIdentityAfter.runtime_source_sha256 -or $profileIdentityBefore.build_id -cne $profileIdentityAfter.build_id) { $profileErrors.Add('Canonical runtime identity changed during the benchmark.') }
} catch { $profileErrors.Add($_.Exception.Message) }
finally {
    $profileWatch.Stop()
    if ($profileHadAppData) { $env:APPDATA = $profileSavedAppData } else { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue }
    foreach ($path in $profileBefore.Keys) {
        try {
            $profileAfter[$path] = Get-FluxFileSha256 $path
            if ($profileAfter[$path] -cne $profileBefore[$path]) { $profileErrors.Add("Qualification input changed: $path") }
        } catch { $profileErrors.Add($_.Exception.Message) }
    }
    Exit-FluxEngineRun $profileLease
}
$profileMemoryAfter = Get-GameplayProfileMemory
$profileAppDataRestored = (Test-Path Env:APPDATA) -eq $profileHadAppData -and (-not $profileHadAppData -or $env:APPDATA -ceq $profileSavedAppData)
if (-not $profileAppDataRestored) { $profileErrors.Add('APPDATA restoration did not match its exact initial existence/value.') }
$profileSummary = [ordered]@{
    schema = 'hex-native-profile-wrapper-v1'; status = $(if ($profileErrors.Count -eq 0) { 'measured' } else { 'incomplete_or_failed' })
    scope = 'Instrumented native source runtime, not portable-release FPS acceptance or physical presentation/input latency. Cold rows mean this process cache, not a flushed OS cache; warm and travel rows stay separate. No source/package/promotion edits; engine preferences live only in the isolated profile. The shared checked-engine runner validates process results, but does not expose a numeric exit code when Windows leaves it unavailable.'
    numeric_process_exit_code = $null; exit_code_scope = 'Not exposed by the shared checked-engine runner; clean launcher return, exact completion marker, complete receipt and empty stderr are required.'
    appdata_restored = $profileAppDataRestored
    requested = [ordered]@{ profiles = $Profiles; cases = $Cases; seconds_per_case = $SecondsPerCase; soak_seconds = $SoakSeconds; frame_limit = $FrameLimit; width = $Width; height = $Height; observer_mode = $(if ($LightObserver) { 'light' } else { 'full' }); screenshots = [bool]$Screenshots; timeout_seconds = $TimeoutSeconds }
    output_directory = $OutputDirectory; engine = $profileEngine; arguments = $profileArguments; wall_seconds = $profileWatch.Elapsed.TotalSeconds
    available_memory_before = $profileMemoryBefore; available_memory_after = $profileMemoryAfter
    runtime_identity_before = $profileIdentityBefore; runtime_identity_after = $profileIdentityAfter; input_hashes_before = $profileBefore; input_hashes_after = $profileAfter
    raw_metrics_path = $profileMetricsPath; native_log_path = $profileLogPath; metrics_sha256 = $(if (Test-Path -LiteralPath $profileMetricsPath -PathType Leaf) { Get-FluxFileSha256 $profileMetricsPath } else { $null })
    validation_errors = $profileErrors.ToArray(); benchmark = Get-GameplayProfileCompactReport $profileReport
}
if (Test-Path -LiteralPath $OutputDirectory -PathType Container) { Write-GameplayProfileReceipt (Join-Path $OutputDirectory 'summary.json') $profileSummary }
if ($profileErrors.Count -gt 0) { throw "Native profile is incomplete or failed; inspect $OutputDirectory" }
Write-Output "MEASURED: native diagnostic and compact summary retained at $OutputDirectory"
