[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PackDirectory,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [ValidateSet('hearth', 'garden-entry', 'paid-fire-bolt', 'paid-all-six-mantle')]
    [string[]]$Cases = @('hearth', 'garden-entry', 'paid-fire-bolt', 'paid-all-six-mantle'),
    [ValidateRange(1, 36000)][int]$Frames = 900,
    [switch]$VisibleWindow,
    [ValidateRange(1, 1800)][int]$TimeoutSeconds = 180
)

# Measures the named release executable, never the editor or checkout project.
# A finite diagnostic sequence is not sustained casting. Engine FPS lines are
# one-second observations including cold startup, not presentation timestamps.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')

function Get-PortableProperty($Object, [string]$Name, $Default = $null) {
    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    return $property.Value
}

function Get-PortableAvailableMemory {
    try {
        $memory = Get-CimInstance -ClassName Win32_OperatingSystem -Property FreePhysicalMemory -ErrorAction Stop
        return [ordered]@{ observed_utc = [DateTime]::UtcNow.ToString('o'); available_mb = [Math]::Round([double]$memory.FreePhysicalMemory / 1024.0, 2); error = $null }
    } catch {
        return [ordered]@{ observed_utc = [DateTime]::UtcNow.ToString('o'); available_mb = $null; error = $_.Exception.Message }
    }
}

function Write-PortableJson([string]$Path, $Value) {
    if (Test-Path -LiteralPath $Path) { throw "Evidence already exists: $Path" }
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 32) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
}

function Read-PortableObservations([string]$Path) {
    $fps = [Collections.Generic.List[object]]::new()
    $chemistry = [Collections.Generic.List[object]]::new()
    $casts = [Collections.Generic.List[object]]::new()
    $identities = [Collections.Generic.List[object]]::new()
    $parseErrors = [Collections.Generic.List[string]]::new()
    $lineNumber = 0
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        foreach ($line in Get-Content -LiteralPath $Path) {
            $lineNumber++
            if ($line -match '^Project FPS:\s*(?<fps>[0-9]+(?:\.[0-9]+)?)\s*\((?<ms>[0-9]+(?:\.[0-9]+)?)\s+mspf\)\s*$') {
                $fps.Add([ordered]@{ line_number = $lineNumber; fps = [double]::Parse($Matches.fps, [Globalization.CultureInfo]::InvariantCulture); reported_mspf = [double]::Parse($Matches.ms, [Globalization.CultureInfo]::InvariantCulture); raw = $line })
            } elseif ($line -match '^Project FPS:') { $parseErrors.Add("Unparsed FPS line $lineNumber`: $line") }
            if ($line -match '^FLUX2 runtime build:\s*(?<id>p[0-9]+-[0-9a-f]{12})\s*\|\s*(?<hash>[0-9a-f]{64})\s*$') {
                $identities.Add([ordered]@{ line_number = $lineNumber; build_id = $Matches.id; runtime_source_sha256 = $Matches.hash })
            }
            if ($line -match '^FLUX2 paid chemistry capture: tick (?<tick>[0-9]+) (?<json>.+)$') {
                $eventTick = [long]$Matches.tick
                $json = $Matches.json
                try { $chemistry.Add([ordered]@{ line_number = $lineNumber; simulation_tick = $eventTick; event = ($json | ConvertFrom-Json -ErrorAction Stop); raw = $line }) }
                catch { $parseErrors.Add("Invalid chemistry JSON at line $lineNumber`: $($_.Exception.Message)") }
            }
            if ($line -match '^FLUX2 spell capture: tick (?<tick>[0-9]+) pending (?<wire>[0-9]+)/(?<ticks>[0-9]+) projectiles (?<shots>[0-9]+) fields (?<fields>[0-9]+) events (?<json>.+)$') {
                $captureRow = [ordered]@{ line_number = $lineNumber; simulation_tick = [long]$Matches.tick; pending_wire_id = [int]$Matches.wire; pending_ticks = [int]$Matches.ticks; projectile_count = [int]$Matches.shots; field_count = [int]$Matches.fields; events = @(); raw = $line }
                $json = $Matches.json
                try { $captureRow.events = @($json | ConvertFrom-Json -ErrorAction Stop); $casts.Add($captureRow) }
                catch { $parseErrors.Add("Invalid combat JSON at line $lineNumber`: $($_.Exception.Message)") }
            }
        }
    }
    $summary = [ordered]@{ sample_count = $fps.Count; mean_reported_fps = $null; minimum_reported_fps = $null; maximum_reported_fps = $null }
    if ($fps.Count -gt 0) {
        $values = @($fps | ForEach-Object { $_.fps })
        $statistics = $values | Measure-Object -Average -Minimum -Maximum
        $summary.mean_reported_fps = $statistics.Average
        $summary.minimum_reported_fps = $statistics.Minimum
        $summary.maximum_reported_fps = $statistics.Maximum
    }
    return [ordered]@{ fps_summary = $summary; fps_samples = $fps.ToArray(); chemistry_observations = $chemistry.ToArray(); combat_observations = $casts.ToArray(); runtime_identities = $identities.ToArray(); parse_errors = $parseErrors.ToArray() }
}

$portableRoot = Get-FluxRepoRoot
if (-not [IO.Path]::IsPathRooted($PackDirectory)) { $PackDirectory = Join-Path $portableRoot $PackDirectory }
if (-not [IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory = Join-Path $portableRoot $OutputDirectory }
$PackDirectory = [IO.Path]::GetFullPath($PackDirectory)
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Choose a fresh output directory; prior measurements are preserved.' }
if ($OutputDirectory.StartsWith($PackDirectory.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Measurement output must be outside the portable directory.' }
if ($Cases.Count -eq 0 -or @($Cases | Select-Object -Unique).Count -ne $Cases.Count) { throw 'Select at least one case, without duplicates.' }
$portableExe = Join-Path $PackDirectory 'hex.exe'
$portablePack = Join-Path $PackDirectory 'hex.pck'
$portableBuildPath = Join-Path $PackDirectory 'BUILD-STATE.json'
foreach ($path in @($portableExe, $portablePack, $portableBuildPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing exact portable payload file: $path" }
}
$portableBefore = [ordered]@{ exe_sha256 = Get-FluxFileSha256 $portableExe; pack_sha256 = Get-FluxFileSha256 $portablePack; build_state_sha256 = Get-FluxFileSha256 $portableBuildPath }
$portableBuild = Get-Content -Raw -LiteralPath $portableBuildPath | ConvertFrom-Json -ErrorAction Stop
$portableIdentity = Get-PortableProperty (Get-PortableProperty (Get-PortableProperty $portableBuild 'state') 'runtime') 'build_identity'
$portableBuildId = [string](Get-PortableProperty $portableIdentity 'build_id' '')
$portableSourceHash = [string](Get-PortableProperty $portableIdentity 'runtime_source_sha256' '')
if ((Get-PortableProperty $portableBuild 'source_kind' '') -cne 'exported_pack' -or (Get-PortableProperty $portableBuild 'pack_sha256' '') -cne $portableBefore.pack_sha256 -or $portableBuildId -cnotmatch '^p[0-9]+-[0-9a-f]{12}$' -or $portableSourceHash -cnotmatch '^[0-9a-f]{64}$') { throw 'BUILD-STATE must identify this exact exported PCK and a valid release identity.' }

$portableCaseRows = @{
    'hearth' = @{ Wire = 0; Spawn = @(1536, 880); Extra = @('--capture-spawn=1536,880') }
    'garden-entry' = @{ Wire = 0; Spawn = @(4880, 720); Extra = @('--capture-spawn=4880,720') }
    'paid-fire-bolt' = @{ Wire = 145; Spawn = @(1536, 880); Extra = @('--capture-spawn=1536,880', '--capture-pointer=1736,880', '--capture-spell-wires=145', '--capture-cast-slot=1', '--capture-spell-sequence=1,1,1,1,1,1,1,1,1,1,1,1') }
    'paid-all-six-mantle' = @{ Wire = 1319; Spawn = @(1536, 880); Extra = @('--capture-spawn=1536,880', '--capture-pointer=1736,880', '--capture-spell-wires=1319', '--capture-cast-slot=1', '--capture-spell-sequence=1,1,1,1,1,1,1,1,1,1,1,1') }
}
$portableScope = 'Actual named release EXE/PCK; engine one-second FPS observations include cold startup and output logging. Not a frame-present trace, input-latency measurement, GPU timer, or sustained casting certification. Twelve finite slot-1 attempts use ordinary cooldown/Flux rules; refusals and idle after sequence/expiry remain in the sample. No resource refill, app closure, or current-source engine is used. Requested --quit-after iterations are not seconds or verified displayed-frame counts. Win32 foreground ownership and main-window visibility/minimization are sampled roughly every500ms after process launch; unavailable handles are null, not proof of a hidden window. Visibility does not prove unobscured presentation.'
$portableLease = Enter-FluxEngineRun 'measure-actual-portable'
$portableHadAppData = Test-Path Env:APPDATA
$portableSavedAppData = $env:APPDATA
$portableResults = [Collections.Generic.List[object]]::new()
$portableError = $null
$portableAfter = $null
$portableMemoryBefore = Get-PortableAvailableMemory
try {
    New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    Copy-Item -LiteralPath $portableBuildPath -Destination (Join-Path $OutputDirectory 'BUILD-STATE.input.json')
    foreach ($caseName in $Cases) {
        $definition = $portableCaseRows[$caseName]
        $caseDirectory = Join-Path $OutputDirectory $caseName
        New-Item -ItemType Directory -Path $caseDirectory | Out-Null
        $env:APPDATA = Join-Path $caseDirectory 'isolated-roaming'
        New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
        $arguments = @('--print-fps', '--windowed', '--resolution', '1280x720', '--quit-after', [string]$Frames, '--', '--fullbody-art', '--pixel-cast', '--no-lan-discovery') + $definition.Extra
        $logPath = Join-Path $caseDirectory 'engine.log'
        $caseError = $null
        $windowObservations = [Collections.Generic.List[object]]::new()
        $memoryBefore = Get-PortableAvailableMemory
        $startedUtc = [DateTime]::UtcNow.ToString('o')
        $watch = [Diagnostics.Stopwatch]::StartNew()
        Push-Location -LiteralPath $PackDirectory
        try { Invoke-FluxGodotChecked $portableExe $arguments $logPath -RejectWarnings -TimeoutSeconds $TimeoutSeconds -VisibleWindow:$VisibleWindow -WindowObservations $windowObservations | Out-Null }
        catch { $caseError = $_.Exception.Message }
        finally { Pop-Location; $watch.Stop() }
        $memoryAfter = Get-PortableAvailableMemory
        $observations = Read-PortableObservations $logPath
        $validation = [Collections.Generic.List[string]]::new()
        if ($null -ne $caseError) { $validation.Add($caseError) }
        foreach ($message in $observations.parse_errors) { $validation.Add($message) }
        if ($observations.fps_summary.sample_count -eq 0) { $validation.Add('No engine FPS observation was emitted; this is not a completed FPS measurement.') }
        if ($observations.runtime_identities.Count -ne 1 -or $observations.runtime_identities[0].build_id -cne $portableBuildId -or $observations.runtime_identities[0].runtime_source_sha256 -cne $portableSourceHash) { $validation.Add('Runtime log did not prove exactly the BUILD-STATE identity.') }
        $accepted = 0
        $refused = 0
        foreach ($combat in $observations.combat_observations) {
            foreach ($event in $combat.events) {
                if ([int](Get-PortableProperty $event 'wire_id' 0) -ne [int]$definition.Wire) { continue }
                $kind = Get-PortableProperty $event 'type' ''
                if ($kind -ceq 'cast_started') { $accepted++ }
                if ($kind -ceq 'cast_refused') { $refused++ }
            }
        }
        if ($definition.Wire -gt 0 -and $accepted -eq 0) { $validation.Add('Finite cast case did not prove any admitted cast of its requested wire.') }
        $stderrBytes = if (Test-Path -LiteralPath "$logPath.err") { (Get-Item -LiteralPath "$logPath.err").Length } else { 0 }
        if ($stderrBytes -ne 0) { $validation.Add('Release process emitted stderr; retain and inspect the exact log.') }
        $row = [ordered]@{ case = $caseName; status = if ($validation.Count -eq 0) { 'measured' } else { 'incomplete_or_failed' }; started_utc = $startedUtc; process_wall_seconds = $watch.Elapsed.TotalSeconds; engine_iterations_requested = $Frames; watchdog_seconds = $TimeoutSeconds; arguments = $arguments; requested_spawn_px = $definition.Spawn; requested_wire_id = $definition.Wire; finite_sequence_attempts_requested = if ($definition.Wire -gt 0) { 12 } else { 0 }; admitted_cast_events = $accepted; refused_cast_events = $refused; memory_before = $memoryBefore; memory_after = $memoryAfter; stderr_bytes = $stderrBytes; validation_errors = $validation.ToArray(); observations = $observations; scope = $portableScope }
        $row['requested_window_style'] = if ($VisibleWindow) { 'Normal' } else { 'Hidden' }
        $row['window_observations'] = $windowObservations.ToArray()
        Write-PortableJson (Join-Path $caseDirectory 'measurement.json') $row
        $portableResults.Add($row)
        Write-Output ("Portable {0}: {1}, {2} FPS observations, mean reported FPS {3}" -f $caseName, $row.status, $observations.fps_summary.sample_count, $observations.fps_summary.mean_reported_fps)
        if ((Get-FluxFileSha256 $portableExe) -cne $portableBefore.exe_sha256 -or (Get-FluxFileSha256 $portablePack) -cne $portableBefore.pack_sha256) { throw 'Portable executable or PCK changed; no further cases will run.' }
    }
} catch { $portableError = $_.Exception.Message }
finally {
    if ($portableHadAppData) { $env:APPDATA = $portableSavedAppData } else { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue }
    Exit-FluxEngineRun $portableLease
}
$portableMemoryAfter = Get-PortableAvailableMemory
$portableAfter = [ordered]@{ exe_sha256 = Get-FluxFileSha256 $portableExe; pack_sha256 = Get-FluxFileSha256 $portablePack; build_state_sha256 = Get-FluxFileSha256 $portableBuildPath }
$portableUnchanged = $portableBefore.exe_sha256 -ceq $portableAfter.exe_sha256 -and $portableBefore.pack_sha256 -ceq $portableAfter.pack_sha256 -and $portableBefore.build_state_sha256 -ceq $portableAfter.build_state_sha256
$portableComplete = $null -eq $portableError -and $portableUnchanged -and $portableResults.Count -eq $Cases.Count -and @($portableResults | Where-Object { $_.status -cne 'measured' }).Count -eq 0
$portableReport = [ordered]@{ schema_version = 1; status = if ($portableComplete) { 'measured' } else { 'incomplete_or_failed' }; scope = $portableScope; pack_directory = $PackDirectory; output_directory = $OutputDirectory; wrapper_sha256 = Get-FluxFileSha256 $PSCommandPath; expected_release_identity = $portableIdentity; payload_before = $portableBefore; payload_after = $portableAfter; payload_unchanged = $portableUnchanged; available_memory_before = $portableMemoryBefore; available_memory_after = $portableMemoryAfter; requested_cases = $Cases; cases = $portableResults.ToArray(); error = $portableError }
if (Test-Path -LiteralPath $OutputDirectory -PathType Container) { Write-PortableJson (Join-Path $OutputDirectory 'measurement.json') $portableReport }
if (-not $portableComplete) { throw "Portable measurement was incomplete or failed; inspect $OutputDirectory" }
Write-Output "MEASURED: exact portable retained; raw observations and scoped evidence saved to $OutputDirectory"
