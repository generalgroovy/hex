# Pure stdout/phase regressions. Does not launch the portable or write fixtures.
$ErrorActionPreference = 'Stop'
$portableTestTokens = $null
$portableTestErrors = $null
$portableTestAst = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'measure-portable.ps1'), [ref]$portableTestTokens, [ref]$portableTestErrors)
if ($portableTestErrors.Count -gt 0) { throw ($portableTestErrors | Out-String) }
foreach ($name in @('Get-PortableProperty', 'Read-PortableObservations', 'Get-PortableWorkloadPhases')) {
    $definitions = @($portableTestAst.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $true))
    if ($definitions.Count -ne 1) { throw "Expected one portable observation function $name" }
    Invoke-Expression $definitions[0].Extent.Text
}
$portableTestAssertions = 0
function Check-PortableObservation([bool]$Condition, [string]$Message) {
    $script:portableTestAssertions++
    if (-not $Condition) { throw "FAIL: $Message" }
}
$log = @(
    ('FLUX2 runtime build: p60-aaaaaaaaaaaa | ' + ('a' * 64)),
    'Project FPS: 60 (16.7 mspf)',
    'FLUX2 spell capture: tick 2 pending 145/4 projectiles 0 fields 0 events [{"type":"cast_started","wire_id":145}]',
    'Project FPS: 40 (25 mspf)',
    'FLUX2 spell capture: tick 30 pending 0/0 projectiles 1 fields 2 events [{"type":"cast_refused","wire_id":145}]',
    'Project FPS: 59 (16.9 mspf)',
    'FLUX2 paid chemistry capture: tick 31 {"type":"hex_pressure"}'
)
$read = Read-PortableObservations -Lines $log
$phases = Get-PortableWorkloadPhases $read 145
Check-PortableObservation ($read.parse_errors.Count -eq 0 -and $read.fps_samples.Count -eq 3 -and $read.combat_observations.Count -eq 2 -and $read.chemistry_observations.Count -eq 1) 'Valid independent FPS, combat and chemistry lines remain separate raw observations.'
Check-PortableObservation (($read.fps_samples | ForEach-Object { $_.log_order_phase }) -join ',' -ceq 'before_first_attempt,between_attempt_log_anchors,after_last_attempt_effect_lifetime_unknown') 'Coarse log ordering never calls post-attempt time idle or exact active-frame time.'
Check-PortableObservation ($phases.first_attempt.simulation_tick -eq 2 -and $phases.last_attempt.simulation_tick -eq 30 -and $phases.attempt_log_anchors.Count -eq 2) 'Both ordinary admission and refusal are workload anchors.'
Check-PortableObservation ($read.fps_samples[1].raw -ceq $log[3] -and $read.combat_observations[0].raw -ceq $log[2]) 'Original emitted lines survive phase annotation.'
$other = Get-PortableWorkloadPhases (Read-PortableObservations -Lines $log) 1319
Check-PortableObservation ($other.attempt_log_anchors.Count -eq 0) 'A different spell cannot supply the requested workload witness.'
$bad = Read-PortableObservations -Lines @('Project FPS: nonsense', 'FLUX2 spell capture: tick 2 pending 145/4 projectiles 0 fields 0 events broken')
Check-PortableObservation ($bad.parse_errors.Count -eq 2) 'Malformed observations fail explicitly rather than disappearing from admission.'
$many = @(for ($i = 0; $i -lt 8193; $i++) { 'Project FPS: 60 (16.7 mspf)' })
$limited = Read-PortableObservations -Lines $many
Check-PortableObservation ($limited.storage_limit_exceeded -and $limited.fps_samples.Count -eq 8192 -and $limited.parse_errors.Count -eq 1) 'Record-budget overflow retains a bounded failed prefix and an explicit error.'
$wide = Read-PortableObservations -Lines @('FLUX2 paid chemistry capture: tick 31 ' + ('x' * 262145))
Check-PortableObservation ($wide.parse_errors.Count -eq 1 -and $wide.chemistry_observations.Count -eq 0) 'Oversized recognized data never enters JSON parsing or evidence arrays.'
Write-Output "portable-measurement: $portableTestAssertions assertions passed"
