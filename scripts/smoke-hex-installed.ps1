param(
    [Parameter(Mandatory)][string]$InstalledRoot,
    [Parameter(Mandatory)][string]$ExpectedBuildId,
    [Parameter(Mandatory)][string]$LogDirectory
)

# Run with PowerShell 7.4+. This launches only an existing isolated installation;
# it does not install into the profile, create shortcuts, or force-stop a game.
. (Join-Path $PSScriptRoot 'flux2-common.ps1')

function Get-HexSmokeFullPath([string]$Path) {
    if ($Path -notmatch '^[A-Za-z]:[\\/]') { throw 'Smoke paths must be absolute local Windows paths.' }
    return [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
}

function Test-HexSmokeDescendant([string]$Path, [string]$Parent) {
    return $Path.StartsWith($Parent.TrimEnd('\', '/') + '\', [StringComparison]::OrdinalIgnoreCase)
}

function Assert-HexSmokePhysicalPath([string]$Path) {
    $ancestor = $Path
    while ($ancestor) {
        if (Test-Path -LiteralPath $ancestor) {
            if (((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Reparse-point path refused: $ancestor"
            }
        }
        $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }
}

function ConvertTo-HexSmokeArgument([AllowEmptyString()][string]$Value) {
    $builder = [Text.StringBuilder]::new()
    [void]$builder.Append('"')
    $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') { $slashes++; continue }
        if ($character -eq '"') { [void]$builder.Append('\', 2 * $slashes + 1) }
        else { [void]$builder.Append('\', $slashes) }
        $slashes = 0
        [void]$builder.Append($character)
    }
    [void]$builder.Append('\', 2 * $slashes)
    [void]$builder.Append('"')
    return $builder.ToString()
}

$repoRoot = Get-FluxRepoRoot
$testBase = Join-Path $repoRoot 'exports\hex-installer-tests'
$logs = Get-HexSmokeFullPath $LogDirectory
$installed = Get-HexSmokeFullPath $InstalledRoot
if (-not ((Test-HexSmokeDescendant $logs $testBase) -or
          (Test-HexSmokeDescendant $logs (Join-Path $repoRoot '.godot')))) {
    throw 'LogDirectory must be a fresh child of .godot or exports/hex-installer-tests.'
}
if ($logs -eq $installed -or (Test-HexSmokeDescendant $logs $installed) -or
    (Test-HexSmokeDescendant $installed $logs)) {
    throw 'Evidence and installation paths must not overlap.'
}
Assert-HexSmokePhysicalPath $logs
if (Test-Path -LiteralPath $logs) { throw 'LogDirectory already exists; previous evidence is preserved.' }
New-Item -ItemType Directory -Path $logs | Out-Null

# Invalid or occupied evidence destinations are refused before writes. Once this
# fresh destination exists, every normal success/failure produces a receipt.
$receiptPath = Join-Path $logs 'receipt.json'
$receipt = [ordered]@{
    schema_version = 1
    status = 'failed'
    scope = 'Installed launcher, rendered startup, art admission and safe close; not human play/performance acceptance.'
    expected_build_id = $ExpectedBuildId
    installed_root = $installed
    log_directory = $logs
    started_utc = [DateTime]::UtcNow.ToString('o')
    finished_utc = $null
    timeout_seconds = 120
    launcher_pid = $null
    launcher_started_ticks = $null
    launcher_exit = $null
    game_pid = $null
    game_started_ticks = $null
    game_executable = $null
    game_exit = $null
    game_arguments = @()
    checked_markers = @()
    stderr_bytes = $null
    rendered_requested = $true
    rendered_startup_verified = $false
    isolated_appdata = Join-Path $logs 'isolated-roaming'
    isolated_localappdata = Join-Path $logs 'isolated-local'
    shortcuts_requested = $false
    parent_environment_changed = $false
    forced_stop = $false
    error = ''
}
$lease = $null
$launcher = $null
$game = $null
try {
    if (-not (Get-Command Start-Process).Parameters.ContainsKey('Environment')) {
        throw 'PowerShell 7.4+ is required for child-only environment overrides.'
    }
    if ($ExpectedBuildId -notmatch '^p[0-9]+-[0-9a-f]{12}$') { throw 'ExpectedBuildId must be an exact runtime build ID.' }
    if (-not (Test-HexSmokeDescendant $installed $testBase)) {
        throw 'InstalledRoot must be an existing isolated installation beneath exports/hex-installer-tests.'
    }
    Assert-HexSmokePhysicalPath $installed
    if ((Get-Content -LiteralPath (Join-Path $installed '.hex-install-root') -Raw).Trim() -ne 'HEX-INSTALL-ROOT-V1') {
        throw 'Missing or incorrect isolated-install ownership marker.'
    }

    Add-Type -AssemblyName System.Security
    $selectionPath = Join-Path $installed 'selection.dat'
    Assert-HexSmokePhysicalPath $selectionPath
    if ((Get-Item -LiteralPath $selectionPath).Length -gt 16384) { throw 'Protected selection is oversized.' }
    $plaintext = [Security.Cryptography.ProtectedData]::Unprotect(
        [IO.File]::ReadAllBytes($selectionPath), [Text.Encoding]::UTF8.GetBytes('HEX-SELECTION-V1'),
        [Security.Cryptography.DataProtectionScope]::CurrentUser)
    $lines = [Text.Encoding]::UTF8.GetString($plaintext).Split("`n")
    if ($lines.Count -ne 3 -or $lines[0] -ne 'HEX-SELECTION-V1') { throw 'Malformed protected selection.' }
    $selected = $lines[1].Split('|')
    if ($selected.Count -ne 3 -or $selected[0] -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,159}$' -or
        $selected[1] -notmatch '^[0-9a-f]{64}$') { throw 'Malformed selected version.' }
    $presentationArgs = @()
    if ($selected[2]) { $presentationArgs = @($selected[2].Split(',')) }
    foreach ($argument in $presentationArgs) {
        if ($argument -notin @('--fullbody-art', '--pixel-cast', '--pixel-body-pilot')) {
            throw "Unexpected protected presentation argument: $argument"
        }
    }
    if ('--pixel-cast' -notin $presentationArgs -or '--pixel-body-pilot' -in $presentationArgs) {
        throw 'The selected installation must enable the complete 30-character pixel cast.'
    }

    $versionDir = Join-Path (Join-Path $installed 'versions') $selected[0]
    $gameExe = Join-Path $versionDir 'hex.exe'
    $launcherExe = Join-Path $installed 'HEX.exe'
    $identityPath = Join-Path $versionDir 'SOURCE-IDENTITY.json'
    foreach ($path in @($launcherExe, $gameExe, $identityPath)) {
        Assert-HexSmokePhysicalPath $path
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing installed file: $path" }
    }
    $identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
    if ($identity.build_id -ne $ExpectedBuildId) { throw "Unexpected selected build: $($identity.build_id)" }
    $receipt.game_executable = $gameExe
    New-Item -ItemType Directory -Path $receipt.isolated_appdata, $receipt.isolated_localappdata | Out-Null
    $stdinFile = Join-Path $logs 'stdin-empty.txt'
    New-Item -ItemType File -Path $stdinFile | Out-Null
    $stdoutFile = Join-Path $logs 'launcher-and-game.stdout.log'
    $stderrFile = Join-Path $logs 'launcher-and-game.stderr.log'
    $gameLog = Join-Path $logs 'godot.log'

    # First separator belongs to HEX; the second belongs to Godot. File-backed
    # stdio avoids waiting on launcher pipes inherited by its asynchronous game.
    $arguments = @('--quiet', '--no-shortcuts', "--install-root=$installed", '--engine-args', '--',
        '--windowed', '--resolution', '1280x720', '--fixed-fps', '120', '--log-file', $gameLog, '--') +
        $presentationArgs + @('--tick-rate=120', '--no-lan-discovery', '--safe-quit-smoke')
    $receipt.game_arguments = $arguments
    $quotedArguments = ($arguments | ForEach-Object { ConvertTo-HexSmokeArgument $_ }) -join ' '
    $lease = Enter-FluxEngineRun 'isolated installed HEX rendered safe-quit smoke'
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $launchTime = [DateTime]::UtcNow
    $launcher = Start-FluxOwnedProcess @{
        FilePath = $launcherExe
        ArgumentList = $quotedArguments
        WorkingDirectory = $logs
        WindowStyle = 'Hidden'
        RedirectStandardInput = $stdinFile
        RedirectStandardOutput = $stdoutFile
        RedirectStandardError = $stderrFile
        Environment = @{APPDATA = $receipt.isolated_appdata; LOCALAPPDATA = $receipt.isolated_localappdata}
    }
    $null = $launcher.Handle
    $receipt.launcher_pid = $launcher.Id
    $receipt.launcher_started_ticks = $launcher.StartTime.ToUniversalTime().Ticks.ToString()
    $journal = Get-Content -LiteralPath (Get-FluxEngineJournalPath) -Raw | ConvertFrom-Json
    $journal.pending_executable = $gameExe
    Write-FluxEngineJournal $journal

    while ($null -eq $game -and $clock.Elapsed.TotalSeconds -lt 120) {
        foreach ($candidate in @(Get-Process -Name hex -ErrorAction SilentlyContinue)) {
            try {
                if ($candidate.Path -eq $gameExe -and $candidate.StartTime.ToUniversalTime() -ge $launchTime) {
                    $null = $candidate.Handle
                    $receipt.game_started_ticks = $candidate.StartTime.ToUniversalTime().Ticks.ToString()
                    $game = $candidate
                    break
                }
            } catch { } # An exited/unrelated candidate never establishes ownership.
            finally { if ($candidate -ne $game) { $candidate.Dispose() } }
        }
        if ($launcher.HasExited -and $null -ne $launcher.ExitCode -and $launcher.ExitCode -ne 0) {
            throw "Installed launcher failed with exit $($launcher.ExitCode)."
        }
        if ($null -eq $game) { Start-Sleep -Milliseconds 10 }
    }
    if ($null -eq $game) { throw 'No exact installed-game handle captured within 120 seconds.' }
    $receipt.game_pid = $game.Id
    $journal = Get-Content -LiteralPath (Get-FluxEngineJournalPath) -Raw | ConvertFrom-Json
    $journal.children = @($journal.children) + @([ordered]@{
        pid = $game.Id; started = $receipt.game_started_ticks; executable = $gameExe
    })
    $journal.pending_executable = $null
    Write-FluxEngineJournal $journal

    while (-not $game.WaitForExit(250)) {
        if ($clock.Elapsed.TotalSeconds -ge 120) { throw "Game PID $($game.Id) did not safely exit within 120 seconds; it was not killed." }
    }
    if (-not $launcher.WaitForExit(1000)) { throw "Game exited, but launcher PID $($launcher.Id) remains alive." }
    $launcher.Refresh()
    $game.Refresh()
    $receipt.launcher_exit = $launcher.ExitCode
    $receipt.game_exit = $game.ExitCode
    if ($null -eq $receipt.launcher_exit -or $null -eq $receipt.game_exit -or
        $receipt.launcher_exit -ne 0 -or $receipt.game_exit -ne 0) {
        throw "Exact zero exits were not established: launcher=$($receipt.launcher_exit), game=$($receipt.game_exit)."
    }

    $logText = Get-Content -LiteralPath $gameLog -Raw
    $stdoutText = Get-Content -LiteralPath $stdoutFile -Raw
    $receipt.stderr_bytes = (Get-Item -LiteralPath $stderrFile).Length
    if ($receipt.stderr_bytes -ne 0) { throw 'Launcher or game wrote to stderr.' }
    if (($logText + "`n" + $stdoutText) -match '(?im)^\s*(WARNING|ERROR|SCRIPT ERROR|USER ERROR|FAIL):|Parse Error|Compile Error|Failed to load script|Invalid call') {
        throw 'Launcher or game emitted a warning or runtime/import error.'
    }
    foreach ($marker in @(
        "FLUX2 runtime build: $ExpectedBuildId |",
        'FLUX2 match initialized at 120 Hz',
        'H.E.X. fullbody art candidate: 30 identity skins',
        'H.E.X. fixed-pixel cast: 30 identities',
        'H.E.X. fixed-pixel action keys: 30 identities',
        'FLUX2 safe quit: smoke requested; notified 0 guest(s)',
        'FLUX2 safe quit: local state flushed and network peer closed'
    )) {
        if (-not $logText.Contains($marker)) { throw "Missing required game-log marker: $marker" }
        $receipt.checked_markers += $marker
    }
    $receipt.rendered_startup_verified = $true
    $receipt.status = 'passed'
} catch {
    $receipt.error = $_.Exception.Message
    throw
} finally {
    # Keep survivor identities/pending executable in the engine journal. No
    # forced stop can be mistaken for successful safe close, even on failure.
    try {
        try {
            if ($null -ne $game) {
                try { if ($game.HasExited) { $receipt.game_exit = $game.ExitCode } }
                finally { $game.Dispose() }
            }
            if ($null -ne $launcher) {
                try { if ($launcher.HasExited) { $receipt.launcher_exit = $launcher.ExitCode } }
                finally { $launcher.Dispose() }
            }
        } finally {
            Exit-FluxEngineRun $lease
        }
    } catch {
        $receipt.status = 'failed'
        $receipt.error += ' Cleanup: ' + $_.Exception.Message
        throw
    } finally {
        $receipt.finished_utc = [DateTime]::UtcNow.ToString('o')
        [IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
        Write-Output "HEX_INSTALLED_SMOKE_RECEIPT=$receiptPath"
    }
}
