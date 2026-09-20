param(
    [string]$Executable = '',
    [ValidateRange(1024, 65535)][int]$Port = 24892,
    [ValidateSet(60, 120)][int]$TickRate = 120,
    [ValidateSet('open_commons', 'sparring_circle', 'duel_knot')][string]$Charter = 'open_commons',
    [ValidatePattern('^[a-z_]+$')][string]$HostChampion = 'oh_tipi',
    [ValidatePattern('^[a-z_]+$')][string]$GuestChampion = 's_wayne',
    # Unified authority currently misses its frame budget. A longer explicit
    # lifecycle watchdog can diagnose completion; it never grants performance acceptance.
    [ValidateRange(5, 300)][int]$TimeoutSeconds = 30,
    [string]$LogDirectory = ''
)
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$workflowLease = Enter-FluxEngineRun 'smoke-farflow'
try {

$repoRoot = Get-FluxRepoRoot
$logRoot = if ($LogDirectory) { [System.IO.Path]::GetFullPath($LogDirectory) } else { Join-Path $repoRoot ('.godot\farflow-smoke\' + [guid]::NewGuid().ToString('N')) }
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$hostLog = Join-Path $logRoot 'host.log'
$guestLog = Join-Path $logRoot 'guest.log'
$lateLog = Join-Path $logRoot 'late-guest.log'
$hostError = "$hostLog.err"
$guestError = "$guestLog.err"
$lateError = "$lateLog.err"
foreach ($path in @($hostLog, $guestLog, $lateLog, $hostError, $guestError, $lateError)) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
}

if ($Executable) {
    $program = [System.IO.Path]::GetFullPath($Executable)
    if (-not (Test-Path -LiteralPath $program -PathType Leaf)) { throw "Packaged executable is missing: $program" }
    $baseArguments = @('--headless', '--fixed-fps', "$TickRate", '--')
    Write-Output "Farflow acceptance target: package $program"
} else {
    & (Join-Path $PSScriptRoot 'doctor.ps1')
    $program = Get-FluxGodot
    $baseArguments = @('--headless', '--path', $repoRoot, '--fixed-fps', "$TickRate", '--')
    Write-Output "Farflow acceptance target: source via $program"
}

function Start-FluxSmokeProcess([string[]]$Arguments, [string]$Output, [string]$ErrorOutput) {
    $quoted = $Arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }
    return Start-FluxOwnedProcess @{FilePath=$program; ArgumentList=$quoted; RedirectStandardOutput=$Output; RedirectStandardError=$ErrorOutput; WindowStyle='Hidden'}
}

function Read-FluxSmokeLog([string]$Output, [string]$ErrorOutput) {
    $parts = @()
    if (Test-Path -LiteralPath $Output) { $parts += Get-Content -LiteralPath $Output -Raw }
    if (Test-Path -LiteralPath $ErrorOutput) { $parts += Get-Content -LiteralPath $ErrorOutput -Raw }
    return $parts -join "`n"
}

function Wait-FluxSmokePattern([System.Diagnostics.Process]$Process, [string]$Output, [string]$ErrorOutput, [string[]]$Patterns, [datetime]$Deadline) {
    while ([datetime]::UtcNow -lt $Deadline) {
        $content = Read-FluxSmokeLog $Output $ErrorOutput
        $complete = $true
        foreach ($pattern in $Patterns) {
            if ($content -notmatch [regex]::Escape($pattern)) { $complete = $false; break }
        }
        if ($complete) { return }
        if ($Process.HasExited) { throw "Farflow process exited before '$($Patterns -join "', '")'. See $Output" }
        Start-Sleep -Milliseconds 100
    }
    throw "Farflow smoke timed out before '$($Patterns -join "', '")'. See $Output"
}

$hostProcess = $null
$guestProcess = $null
$lateProcess = $null
try {
    $spectatorEnabled = $Charter -ne 'duel_knot'
    $charterDisplay = @{
        open_commons = 'OPEN COMMONS'
        sparring_circle = 'SPARRING CIRCLE'
        duel_knot = 'DUEL KNOT'
    }[$Charter]
    $hostArguments = $baseArguments + @("--tick-rate=$TickRate", '--farflow=host', "--session-port=$Port", "--session-charter=$Charter", '--player-name=Lantern Host', '--farflow-smoke-hearth', '--farflow-smoke-round', '--farflow-smoke-rematch', '--farflow-smoke-steward')
    $hostArguments += "--champion=$HostChampion"
    $hostProcess = Start-FluxSmokeProcess $hostArguments $hostLog $hostError
    $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
    Wait-FluxSmokePattern $hostProcess $hostLog $hostError @("FLUX2 farflow host: listening on UDP $Port", $charterDisplay) $deadline

    $guestArguments = $baseArguments + @("--tick-rate=$TickRate", '--farflow=join', '--join-address=127.0.0.1', "--session-port=$Port", '--player-name=River Guest', '--farflow-smoke-emote', '--farflow-smoke-prediction', '--farflow-smoke-hearth', '--farflow-smoke-round', '--farflow-smoke-rematch', '--farflow-smoke-reconnect', '--farflow-smoke-steward')
    $guestArguments += "--champion=$GuestChampion"
    $guestProcess = Start-FluxSmokeProcess $guestArguments $guestLog $guestError
    Wait-FluxSmokePattern $hostProcess $hostLog $hostError @(
        'FLUX2 farflow hearth: Proving Court round started'
    ) $deadline

    if ($spectatorEnabled) {
        $lateArguments = $baseArguments + @("--tick-rate=$TickRate", '--farflow=join', '--join-address=127.0.0.1', "--session-port=$Port", '--player-name=Late Lantern', '--farflow-smoke-spectator')
        $lateProcess = Start-FluxSmokeProcess $lateArguments $lateLog $lateError
        Wait-FluxSmokePattern $lateProcess $lateLog $lateError @(
            'FLUX2 farflow replica: local entity 3',
            'FLUX2 farflow spectator smoke: late guest following entity 1',
            'FLUX2 farflow spectator smoke: Hearth handoff ready for entity 3',
            'FLUX2 farflow spectator smoke: joined Proving Court serial 2 as entity 3'
        ) $deadline
    }
    Wait-FluxSmokePattern $guestProcess $guestLog $guestError @(
        'FLUX2 farflow replica: local entity 2',
        'FLUX2 farflow social: guest emote request sent',
        'FLUX2 farflow prediction smoke: authoritative movement confirmed',
        'FLUX2 farflow hearth smoke: guest readiness sent',
        'FLUX2 farflow hearth smoke: guest received shared practice start',
        'FLUX2 farflow round smoke: guest active in Proving Court serial 1',
        'FLUX2 farflow reconnect smoke: left entity 2',
        'FLUX2 farflow reconnect smoke: returned entity 2',
        'FLUX2 farflow rematch smoke: guest gathered and ready for round 2',
        'FLUX2 farflow rematch smoke: guest active in Proving Court serial 2',
        'FLUX2 farflow steward smoke: guest received release reason and return revoked'
    ) $deadline
    $hostPatterns = @(
        'FLUX2 farflow host: joined entity 2 (River Guest)',
        'FLUX2 farflow social: shared emote entity 2',
        'FLUX2 farflow hearth smoke: roster gathered and host ready',
        'FLUX2 farflow hearth smoke: all ready; countdown started',
        'FLUX2 farflow hearth: Proving Court round started',
        'FLUX2 farflow host: return reserved for entity 2 (River Guest)',
        'FLUX2 farflow host: returned entity 2 (River Guest)',
        'FLUX2 farflow rematch smoke: host gathered and ready for round 2',
        'FLUX2 farflow steward smoke: confirmed release sent for entity 2',
        'FLUX2 farflow steward smoke: guest removed without reservation'
    )
    if ($spectatorEnabled) { $hostPatterns += 'FLUX2 farflow host: joined entity 3 (Late Lantern)' }
    Wait-FluxSmokePattern $hostProcess $hostLog $hostError $hostPatterns $deadline
    $spectatorResult = if ($spectatorEnabled) { ', late-join spectating/Hearth handoff' } else { '' }
    Write-Output "PASS: Farflow host/join, shared HELLO, movement reconciliation, Hearth-to-Court round$spectatorResult, exact-actor return, rematch and reason-bearing host stewardship passed at $TickRate Hz on UDP $Port."
    Write-Output "Logs: $logRoot"
} finally {
    foreach ($process in @($lateProcess, $guestProcess, $hostProcess)) {
        if ($null -ne $process -and -not $process.HasExited) {
            Stop-Process -Id $process.Id -Force
            $process.WaitForExit()
        }
    }
}

} finally { Exit-FluxEngineRun $workflowLease }
