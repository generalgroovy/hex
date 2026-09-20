# One synchronous engine workflow per checkout. The OS owns mutex lifetime;
# the journal only detects surviving children after interrupted ownership.
function Get-FluxEngineJournalPath {
    return Join-Path (Get-FluxRepoRoot) '.godot/engine-run.json'
}

function Write-FluxEngineJournal($Record) {
    $journal = Get-FluxEngineJournalPath
    $temporary = $journal + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($temporary, ($Record | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
        if (Test-Path -LiteralPath $journal) { [IO.File]::Replace($temporary, $journal, [NullString]::Value) }
        else { [IO.File]::Move($temporary, $journal) }
    } finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary } }
}

function Test-FluxRecordedProcess($Record) {
    $candidate = Get-Process -Id ([int]$Record.pid) -ErrorAction SilentlyContinue
    if ($null -eq $candidate) { return $false }
    try { return $candidate.StartTime.ToUniversalTime().Ticks.ToString() -eq $Record.started -and $candidate.Path -eq $Record.executable }
    catch { throw "Cannot establish engine ownership for PID $($Record.pid); close or inspect it before retrying." }
}

function Enter-FluxEngineRun([string]$Purpose) {
    $root = (Get-FluxRepoRoot).TrimEnd('\', '/').ToLowerInvariant()
    $ancestor = $root
    while ($ancestor) {
        if (((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'Engine workflows require the physical checkout path, without junction or symlink ancestors.'
        }
        $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }
    $digest = [Security.Cryptography.SHA256]::Create()
    try { $key = [BitConverter]::ToString($digest.ComputeHash([Text.Encoding]::UTF8.GetBytes($root))).Replace('-', '') }
    finally { $digest.Dispose() }
    $mutex = [Threading.Mutex]::new($false, "Local\FLUX-engine-$key")
    $held = $false
    try {
        try { $held = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $held = $true }
        if (-not $held) { throw "Another engine workflow owns this checkout. Retry after it finishes; see $(Get-FluxEngineJournalPath)." }
        $self = Get-Process -Id $PID
        $started = $self.StartTime.ToUniversalTime().Ticks.ToString()
        $journalPath = Get-FluxEngineJournalPath
        New-Item -ItemType Directory -Path (Split-Path $journalPath) -Force | Out-Null
        $previous = if (Test-Path -LiteralPath $journalPath) { Get-Content -LiteralPath $journalPath -Raw | ConvertFrom-Json } else { $null }
        # A synchronous nested .ps1 invocation reacquires the same OS mutex.
        if ($null -ne $previous -and $previous.owner_pid -eq $PID -and $previous.owner_started -eq $started) {
            return [pscustomobject]@{mutex = $mutex; outer = $false}
        }
        if ($null -ne $previous) {
            foreach ($child in @($previous.children)) {
                if (Test-FluxRecordedProcess $child) { throw "Previous engine child PID $($child.pid) is still alive. No lock was stolen and no process was stopped." }
            }
        }
        # Also cover an interruption between Start-Process and journal registration,
        # and an engine launched outside these wrappers against this checkout.
        foreach ($candidate in Get-CimInstance Win32_Process) {
            $command = ([string]$candidate.CommandLine).Replace('\', '/').ToLowerInvariant()
            $executable = [string]$candidate.ExecutablePath
            $sameCheckout = $candidate.Name -match '^(Godot.*|flux2)\.exe$' -and $command.Contains($root.Replace('\', '/'))
            $pendingLaunch = $null -ne $previous -and $null -ne $previous.pending_executable -and $executable -eq $previous.pending_executable
            if ($sameCheckout -or $pendingLaunch) { throw "Engine process PID $($candidate.ProcessId) may still use this checkout. Inspect it before retrying; no process was stopped." }
        }
        Write-FluxEngineJournal ([ordered]@{owner_pid=$PID; owner_started=$started; purpose=$Purpose; children=@(); pending_executable=$null})
        return [pscustomobject]@{mutex = $mutex; outer = $true}
    }
    catch {
        if ($held) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
        throw
    }
}

function Exit-FluxEngineRun($Lease) {
    if ($null -eq $Lease) { return }
    try {
        if ($Lease.outer) {
            $record = Get-Content -LiteralPath (Get-FluxEngineJournalPath) -Raw | ConvertFrom-Json
            $record.owner_pid = 0
            $record.owner_started = ''
            # Preserve child identities even on cancellation; the next owner
            # proves they exited before clearing this journal.
            Write-FluxEngineJournal $record
        }
    }
    finally { $Lease.mutex.ReleaseMutex(); $Lease.mutex.Dispose() }
}

function Start-FluxOwnedProcess([hashtable]$StartParameters, [Diagnostics.Process]$Process = $null) {
    $path = Get-FluxEngineJournalPath
    $record = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($record.owner_pid -ne $PID) { throw 'An engine workflow lease is required before launching a child.' }
    $executable = if ($null -ne $Process) { $Process.StartInfo.FileName } else { $StartParameters.FilePath }
    $record.pending_executable = [IO.Path]::GetFullPath($executable)
    Write-FluxEngineJournal $record
    $child = $null
    $launched = $false
    try {
        if ($null -ne $Process) { $child = $Process; [void]$child.Start() }
        else { $child = Start-Process @StartParameters -PassThru }
        $launched = $true
        $record.children = @($record.children | Where-Object { Test-FluxRecordedProcess $_ }) + @([ordered]@{
            pid=$child.Id; started=$child.StartTime.ToUniversalTime().Ticks.ToString(); executable=$record.pending_executable
        })
        $record.pending_executable = $null
        Write-FluxEngineJournal $record
        return $child
    }
    catch {
        if ($launched -and -not $child.HasExited) { $child.Kill(); $child.WaitForExit() }
        $record.pending_executable = $null
        Write-FluxEngineJournal $record
        throw
    }
}
