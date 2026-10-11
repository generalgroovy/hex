param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Executable,
    [ValidateSet('duos', 'trios')][string]$Charter = 'duos',
    [ValidateRange(1024, 65535)][int]$Port = 24926,
    [ValidateRange(120, 300)][int]$TimeoutSeconds = 240,
    [string]$LogDirectory = ''
)
. (Join-Path $PSScriptRoot 'flux2-common.ps1')

# Same-export localhost lifecycle evidence only. The owned children are stopped
# after their markers; this is not graceful-close, FPS, balance or Internet QA.
function Assert-HexTeamPhysicalPath([string]$Path) {
    $ancestor = [IO.Path]::GetFullPath($Path)
    while ($ancestor) {
        if ((Test-Path -LiteralPath $ancestor) -and
            (((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
            throw "Team smoke paths cannot contain junction or symlink ancestors: $ancestor"
        }
        $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }
}

function Read-HexTeamText([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    return [string](Get-Content -LiteralPath $Path -Raw)
}

function Get-HexTeamLogState([string]$Text, [string]$Mode, [int]$Count, [string]$Role, $Identity) {
    if ($Text -match '(?m)^(?:ERROR:|SCRIPT ERROR:|FAIL:)|Parse Error|Compile Error|Failed to load script|Invalid call') {
        throw "$Role emitted a runtime/script error."
    }
    $identityMatches = [regex]::Matches($Text, '(?m)^FLUX2 runtime build: (p[1-9][0-9]*-[a-f0-9]{12}) \| ([a-f0-9]{64})\r?$')
    foreach ($match in $identityMatches) {
        if ($match.Groups[1].Value -cne [string]$Identity.build_id -or $match.Groups[2].Value -cne [string]$Identity.runtime_source_sha256) {
            throw "$Role loaded a different runtime identity from the pinned export."
        }
    }
    $activeMatches = [regex]::Matches($Text, '(?m)^HEX team smoke: active mode=([a-z]+) participants=([0-9]+) serial=([0-9]+)\r?$')
    foreach ($match in $activeMatches) {
        if ($match.Groups[1].Value -cne $Mode -or [int]$match.Groups[2].Value -ne $Count) {
            throw "$Role received the wrong team mode or participant count."
        }
    }
    $result = [ordered]@{ identity = ($identityMatches.Count -gt 0); active_1 = $false; local_1 = $false; result_1 = $false; hearth_return = $false; active_2 = $false; local_2 = $false; entity_id = 0; team_id = 0; complete = $false }
    $cursor = -1
    $localMarkers = [regex]::Matches($Text, '(?m)^HEX team smoke: local entity=([1-8]) team=([12])(?: serial=([12]))?\r?$')
    if ($localMarkers.Count -gt 0) {
        foreach ($match in $localMarkers) {
            if ($match.Groups[1].Value -cne $localMarkers[0].Groups[1].Value -or $match.Groups[2].Value -cne $localMarkers[0].Groups[2].Value) {
                throw "$Role emitted contradictory local identity/team metadata in an unchanged-roster run."
            }
        }
    }
    foreach ($serial in @(1, 2)) {
        $active = @($activeMatches | Where-Object { [int]$_.Groups[3].Value -eq $serial -and $_.Index -gt $cursor } | Select-Object -First 1)
        if ($active.Count -eq 0) { return [pscustomobject]$result }
        $result["active_$serial"] = $true
        $cursor = $active[0].Index + $active[0].Length
        $local = @($localMarkers | Where-Object { $_.Index -ge $cursor -and (-not $_.Groups[3].Success -or [int]$_.Groups[3].Value -eq $serial) } | Select-Object -First 1)
        if ($local.Count -eq 0) { return [pscustomobject]$result }
        # A future-round marker cannot be borrowed as first-round team proof.
        $boundary = [regex]::Match($Text.Substring($cursor), '(?m)^HEX team smoke: (?:active |result )')
        if ($boundary.Success -and $local[0].Index -ge $cursor + $boundary.Index) {
            throw "$Role omitted current-round local team metadata before its next phase."
        }
        $entityId = [int]$local[0].Groups[1].Value
        $teamId = [int]$local[0].Groups[2].Value
        if ($serial -eq 2 -and ($entityId -ne $result.entity_id -or $teamId -ne $result.team_id)) {
            throw "$Role changed its participant identity or team across this unchanged-roster rematch."
        }
        $result.entity_id = $entityId
        $result.team_id = $teamId
        $result["local_$serial"] = $true
        $cursor = $local[0].Index + $local[0].Length
        if ($serial -eq 1) {
            $finished = [regex]::Match($Text.Substring($cursor), '(?m)^HEX team smoke: result serial=1\r?$')
            if (-not $finished.Success) { return [pscustomobject]$result }
            $result.result_1 = $true
            $cursor += $finished.Index + $finished.Length
            $readyRole = if ($Role -eq 'host') { 'host' } else { 'guest' }
            $returnPattern = '(?m)^(?:HEX team smoke: hearth after_serial=1|FLUX2 farflow rematch smoke: ' + $readyRole + ' gathered and ready for round 2)\r?$'
            $returned = [regex]::Match($Text.Substring($cursor), $returnPattern)
            if (-not $returned.Success) { return [pscustomobject]$result }
            $result.hearth_return = $true
            $cursor += $returned.Index + $returned.Length
        }
    }
    $result.complete = $result.identity -and $result.local_2
    return [pscustomobject]$result
}

function Stop-HexTeamOwnedChild($Child) {
    $Child.process.Refresh()
    if ($Child.process.HasExited) { $Child.receipt.termination = 'exited_before_cleanup'; return }
    if (-not (Test-FluxRecordedProcess $Child.identity)) {
        throw "Refusing cleanup because owned process identity no longer matches PID $($Child.identity.pid)."
    }
    $Child.process.Kill()
    if (-not $Child.process.WaitForExit(5000)) { throw "Owned child PID $($Child.identity.pid) did not exit after cleanup." }
    $Child.process.Refresh()
    $Child.receipt.termination = 'owned_forced_cleanup'
}

$teamRepo = Get-FluxRepoRoot
$program = [IO.Path]::GetFullPath($Executable)
if (-not (Test-Path -LiteralPath $program -PathType Leaf) -or [IO.Path]::GetExtension($program) -ine '.exe') { throw "Explicit packaged Windows executable is missing: $program" }
Assert-HexTeamPhysicalPath $program
$packageDirectory = Split-Path -Parent $program
$packStem = [IO.Path]::GetFileNameWithoutExtension($program) -replace '\.console$', ''
$packPath = Join-Path $packageDirectory ($packStem + '.pck')
$identityPath = Join-Path $packageDirectory 'SOURCE-IDENTITY.json'
foreach ($path in @($packPath, $identityPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Same-export smoke requires the package sidecar: $path" }
    Assert-HexTeamPhysicalPath $path
}
$expectedIdentity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
if ([string]$expectedIdentity.runtime_source_sha256 -cnotmatch '^[a-f0-9]{64}$' -or
    [string]$expectedIdentity.build_id -cnotmatch '^p[1-9][0-9]*-[a-f0-9]{12}$' -or
    [string]$expectedIdentity.build_id -cne "p$($expectedIdentity.protocol_version)-$(([string]$expectedIdentity.runtime_source_sha256).Substring(0, 12))") {
    throw 'Export identity sidecar does not contain a valid derived build/source identity.'
}
$expectedExeHash = Get-FluxFileSha256 $program
$expectedPackHash = Get-FluxFileSha256 $packPath
$expectedIdentityHash = Get-FluxFileSha256 $identityPath
$participantCount = if ($Charter -eq 'duos') { 4 } else { 6 }
$teamGodotRoot = [IO.Path]::GetFullPath((Join-Path $teamRepo '.godot')).TrimEnd('\', '/')
if ($LogDirectory -and -not [IO.Path]::IsPathRooted($LogDirectory)) { throw 'LogDirectory must be an absolute fresh directory beneath this checkout .godot.' }
$logRoot = if ($LogDirectory) { [IO.Path]::GetFullPath($LogDirectory) } else { Join-Path $teamGodotRoot ('hex-team-smoke-' + $Charter + '-' + [guid]::NewGuid().ToString('N')) }
if (-not $logRoot.StartsWith($teamGodotRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'LogDirectory must be strictly beneath this checkout .godot, never the workspace or .godot root.' }
Assert-HexTeamPhysicalPath $logRoot
if (Test-Path -LiteralPath $logRoot) { throw "LogDirectory already exists; previous evidence will not be overwritten: $logRoot" }
New-Item -ItemType Directory -Path $logRoot | Out-Null
$receiptPath = Join-Path $logRoot 'receipt.json'
$clock = [Diagnostics.Stopwatch]::StartNew()
$receipt = [ordered]@{
    schema_version = 1; status = 'failed'; charter = $Charter; participants = $participantCount; tick_rate = 120; port = $Port
    started_utc = [DateTime]::UtcNow.ToString('o'); finished_utc = ''; duration_ms = 0; timeout_seconds = $TimeoutSeconds
    executable = $program; executable_sha256 = $expectedExeHash; pack = $packPath; pack_sha256 = $expectedPackHash
    build_id = [string]$expectedIdentity.build_id; runtime_source_sha256 = [string]$expectedIdentity.runtime_source_sha256
    identity_sidecar = $identityPath; identity_sidecar_sha256 = $expectedIdentityHash; package_unchanged = $false
    lifecycle = 'exact roster ACTIVE serial 1 -> RESULT serial 1 -> HEARTH -> ACTIVE serial 2, including local team metadata in every process'
    scope = 'Same-export localhost deterministic lifecycle and runtime identity; not graceful shutdown, competitive balance, rendered FPS, sustained 120Hz or physical Internet acceptance.'
    timing_scope = 'Wall-clock process/marker observation only; not engine tick throughput or network latency.'
    user_data_isolation = 'Every participant uses a fresh APPDATA directory beneath this run log directory; caller APPDATA is restored after each spawn, including failures.'
    process_count = 0; all_stderr_empty = $false; lifecycle_complete = $false; processes = @(); errors = @()
}
$lease = $null
$children = [Collections.Generic.List[object]]::new()
$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)

function Start-HexTeamChild([int]$Ordinal) {
    $role = if ($Ordinal -eq 1) { 'host' } else { "guest-$Ordinal" }
    $playerName = if ($Ordinal -eq 1) { 'TeamHost' } else { "TeamGuest$Ordinal" }
    $stdoutPath = Join-Path $logRoot ($role + '.log')
    $stderrPath = Join-Path $logRoot ($role + '.err')
    $isolatedAppDataPath = [IO.Path]::GetFullPath((Join-Path $logRoot ($role + '-appdata')))
    if (-not $isolatedAppDataPath.StartsWith($logRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Participant APPDATA must remain beneath the fresh run log directory.' }
    Assert-HexTeamPhysicalPath $isolatedAppDataPath
    if (Test-Path -LiteralPath $isolatedAppDataPath) { throw "Participant APPDATA already exists; previous user data will not be reused: $isolatedAppDataPath" }
    New-Item -ItemType Directory -Path $isolatedAppDataPath | Out-Null
    $arguments = @('--headless', '--fixed-fps', '120', '--', '--tick-rate=120', "--session-port=$Port", "--session-charter=$Charter", "--player-name=$playerName", '--farflow-smoke-hearth', '--farflow-smoke-round', '--farflow-smoke-rematch', '--farflow-smoke-team')
    if ($Ordinal -eq 1) { $arguments += '--farflow=host' } else { $arguments += @('--farflow=join', '--join-address=127.0.0.1') }
    $exeHash = Get-FluxFileSha256 $program
    $packHash = Get-FluxFileSha256 $packPath
    if ($exeHash -cne $expectedExeHash -or $packHash -cne $expectedPackHash) { throw 'Pinned export changed while launching its team participants.' }
    $quoted = $arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }
    $teamHadAppData = Test-Path Env:APPDATA
    $teamCallerAppData = $env:APPDATA
    try {
        $env:APPDATA = $isolatedAppDataPath
        $process = Start-FluxOwnedProcess @{ FilePath = $program; ArgumentList = $quoted; WorkingDirectory = $packageDirectory; RedirectStandardOutput = $stdoutPath; RedirectStandardError = $stderrPath; WindowStyle = 'Hidden' }
    } finally {
        if ($teamHadAppData) { $env:APPDATA = $teamCallerAppData }
        else { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue }
    }
    $identity = [pscustomobject]@{ pid = $process.Id; started = $process.StartTime.ToUniversalTime().Ticks.ToString(); executable = $program }
    $processReceipt = [ordered]@{
        role = $role; player_name = $playerName; pid = $process.Id; started_ticks = $identity.started; started_utc = $process.StartTime.ToUniversalTime().ToString('o')
        executable = $program; executable_sha256 = $exeHash; pack_sha256 = $packHash; arguments = $arguments
        isolated_appdata = $isolatedAppDataPath
        stdout = $stdoutPath; stderr = $stderrPath; stdout_sha256 = ''; stderr_sha256 = ''; stderr_bytes = -1
        observed_entity_id = 0; observed_team_id = 0; observed_build_id = ''; observed_runtime_source_sha256 = ''
        milestones_ms = [ordered]@{}; complete = $false
        elapsed_ms = 0; termination = 'running'; exit_code = $null
    }
    $child = [pscustomobject]@{ process = $process; identity = $identity; receipt = $processReceipt; started_ms = $clock.ElapsedMilliseconds; state = $null }
    $children.Add($child)
    $receipt.processes += $processReceipt
    $receipt.process_count = $children.Count
    return $child
}

try {
    $lease = Enter-FluxEngineRun ('smoke-hex-teams-' + $Charter)
    $teamHost = Start-HexTeamChild 1
    $listenPattern = '(?m)^FLUX2 farflow host: listening on UDP ' + $Port + ' \| ' + $(if ($Charter -eq 'duos') { 'DUOS 2v2' } else { 'TRIOS 3v3' }) + ' \| ' + $participantCount + ' places\r?$'
    while ([DateTime]::UtcNow -lt $deadline) {
        $hostText = Read-HexTeamText $teamHost.receipt.stdout
        $hostState = Get-HexTeamLogState $hostText $Charter $participantCount 'host' $expectedIdentity
        if ((Test-Path -LiteralPath $teamHost.receipt.stderr) -and (Get-Item -LiteralPath $teamHost.receipt.stderr).Length -ne 0) { throw 'Host wrote stderr before all guests launched.' }
        if ($hostText -match $listenPattern -and $hostState.identity) { break }
        if ($teamHost.process.HasExited) { throw 'Host exited before its pinned identity and exact-capacity listen marker.' }
        Start-Sleep -Milliseconds 100
    }
    if ([DateTime]::UtcNow -ge $deadline) { throw 'Host startup exceeded the team smoke watchdog.' }
    for ($ordinal = 2; $ordinal -le $participantCount; $ordinal++) { $null = Start-HexTeamChild $ordinal }
    $allComplete = $false
    while ([DateTime]::UtcNow -lt $deadline) {
        $allComplete = $true
        foreach ($child in $children) {
            if ($child.process.HasExited) { throw "$($child.receipt.role) exited before completion of the all-process lifecycle gate." }
            if ((Test-Path -LiteralPath $child.receipt.stderr) -and (Get-Item -LiteralPath $child.receipt.stderr).Length -ne 0) { throw "$($child.receipt.role) wrote stderr." }
            $text = Read-HexTeamText $child.receipt.stdout
            $child.state = Get-HexTeamLogState $text $Charter $participantCount $child.receipt.role $expectedIdentity
            foreach ($stage in @('identity', 'active_1', 'local_1', 'result_1', 'hearth_return', 'active_2', 'local_2')) {
                if ($child.state.$stage -and -not $child.receipt.milestones_ms.Contains($stage)) { $child.receipt.milestones_ms[$stage] = $clock.ElapsedMilliseconds }
            }
            $child.receipt.observed_entity_id = $child.state.entity_id
            $child.receipt.observed_team_id = $child.state.team_id
            if ($child.state.identity) {
                $child.receipt.observed_build_id = [string]$expectedIdentity.build_id
                $child.receipt.observed_runtime_source_sha256 = [string]$expectedIdentity.runtime_source_sha256
            }
            $child.receipt.complete = $child.state.complete
            if (-not $child.state.complete) { $allComplete = $false }
        }
        if ($allComplete) { break }
        Start-Sleep -Milliseconds 100
    }
    if (-not $allComplete) { throw 'Team smoke watchdog expired before every participant proved both rounds and its team.' }
    $orderedIds = @($children | ForEach-Object { $_.state.entity_id } | Sort-Object)
    if (@($orderedIds | Select-Object -Unique).Count -ne $participantCount -or $teamHost.state.entity_id -ne 1) { throw 'Participant metadata duplicates an actor or lacks the authoritative host identity.' }
    $hostText = Read-HexTeamText $teamHost.receipt.stdout
    foreach ($child in $children) {
        $position = [Array]::IndexOf($orderedIds, $child.state.entity_id)
        if ($child.state.team_id -ne 1 + ($position % 2)) { throw "$($child.receipt.role) disagrees with the sorted locked-roster assignment." }
        if ($child.receipt.role -ne 'host') {
            $joined = 'FLUX2 farflow host: joined entity ' + $child.state.entity_id + ' (' + $child.receipt.player_name + ')'
            if ($hostText -notmatch ('(?m)^' + [regex]::Escape($joined) + '\r?$')) { throw 'Host did not authenticate the observed guest identity/name mapping.' }
            $replica = '(?m)^FLUX2 farflow replica: local entity ' + $child.state.entity_id + ', snapshot tick [0-9]+, travellers [0-9]+\r?$'
            if ((Read-HexTeamText $child.receipt.stdout) -notmatch $replica) { throw 'Guest never proved receipt of its admitted authoritative replica.' }
        }
    }
    $receipt.lifecycle_complete = $true
} catch {
    $receipt.errors += $_.Exception.Message
} finally {
    for ($index = $children.Count - 1; $index -ge 0; $index--) {
        $child = $children[$index]
        try { Stop-HexTeamOwnedChild $child } catch { $receipt.errors += ('Cleanup: ' + $_.Exception.Message) }
        $child.receipt.elapsed_ms = $clock.ElapsedMilliseconds - $child.started_ms
        try {
            if ($child.process.HasExited) { $child.process.Refresh(); $child.receipt.exit_code = $child.process.ExitCode }
            foreach ($kind in @('stdout', 'stderr')) {
                $path = [string]$child.receipt[$kind]
                if (Test-Path -LiteralPath $path -PathType Leaf) { $child.receipt[$kind + '_sha256'] = Get-FluxFileSha256 $path }
            }
            if (Test-Path -LiteralPath $child.receipt.stderr -PathType Leaf) { $child.receipt.stderr_bytes = (Get-Item -LiteralPath $child.receipt.stderr).Length }
        } catch { $receipt.errors += ('Child evidence: ' + $_.Exception.Message) }
    }
    try {
        $receipt.package_unchanged = (Get-FluxFileSha256 $program) -ceq $expectedExeHash -and (Get-FluxFileSha256 $packPath) -ceq $expectedPackHash -and (Get-FluxFileSha256 $identityPath) -ceq $expectedIdentityHash
        if (-not $receipt.package_unchanged) { $receipt.errors += 'Pinned export or identity sidecar changed during the run.' }
        $receipt.all_stderr_empty = $children.Count -eq $participantCount -and @($children | Where-Object { $_.receipt.stderr_bytes -ne 0 }).Count -eq 0
        if (-not $receipt.all_stderr_empty) { $receipt.errors += 'Exactly all expected processes with zero-byte stderr were not established.' }
        foreach ($child in $children) {
            $finalState = Get-HexTeamLogState (Read-HexTeamText $child.receipt.stdout) $Charter $participantCount $child.receipt.role $expectedIdentity
            if ($receipt.lifecycle_complete -and -not $finalState.complete) { throw 'Final preserved log no longer proves the observed lifecycle.' }
        }
    } catch { $receipt.errors += ('Final evidence check: ' + $_.Exception.Message) }
    try { Exit-FluxEngineRun $lease } catch { $receipt.errors += ('Engine lease release: ' + $_.Exception.Message) }
    $clock.Stop()
    $receipt.duration_ms = $clock.ElapsedMilliseconds
    $receipt.finished_utc = [DateTime]::UtcNow.ToString('o')
    if ($receipt.lifecycle_complete -and $receipt.all_stderr_empty -and $receipt.package_unchanged -and $receipt.errors.Count -eq 0) { $receipt.status = 'passed' }
    $receiptStream = [IO.File]::Open($receiptPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    try {
        $receiptBytes = [Text.UTF8Encoding]::new($false).GetBytes(($receipt | ConvertTo-Json -Depth 10))
        $receiptStream.Write($receiptBytes, 0, $receiptBytes.Length)
    } finally { $receiptStream.Dispose() }
    Write-Output "HEX_TEAM_SMOKE_RECEIPT=$receiptPath"
}
if ($receipt.status -ne 'passed') { throw ('Team smoke failed: ' + ($receipt.errors -join ' | ')) }
Write-Output "PASS: $Charter same-export localhost $participantCount-process lifecycle, two active rounds, result/Hearth return, exact teams and runtime identity. No FPS, balance, safe-close or physical-network claim."
