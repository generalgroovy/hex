Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'engine-guard.ps1')

function Get-FluxRepoRoot {
    return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}

function Get-FluxFileSha256([string]$Path) {
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Cannot hash missing file: $fullPath"
    }
    $stream = [System.IO.File]::OpenRead($fullPath)
    try {
        $algorithm = [System.Security.Cryptography.SHA256]::Create()
        try {
            $bytes = $algorithm.ComputeHash($stream)
            return ([System.BitConverter]::ToString($bytes)).Replace('-', '').ToLowerInvariant()
        }
        finally {
            $algorithm.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Get-FluxGodot {
    if ($env:FLUX2_GODOT_BIN) {
        $candidate = [System.IO.Path]::GetFullPath($env:FLUX2_GODOT_BIN)
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
        throw "FLUX2_GODOT_BIN does not name a file: $candidate"
    }
    $bundled = Join-Path $env:LOCALAPPDATA 'FLUX-dev\godot-4.7.1\Godot_v4.7.1-stable_win64.exe'
    if (Test-Path -LiteralPath $bundled -PathType Leaf) { return $bundled }
    foreach ($commandName in @('godot4', 'godot')) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
    }
    throw 'Godot 4.7.1 is missing. Set FLUX2_GODOT_BIN or install the pinned engine.'
}

function Assert-FluxGodotVersion([string]$GodotBin) {
    $actual = (& $GodotBin --version | Select-Object -First 1).Trim()
    $expected = '4.7.1.stable.official.a13da4feb'
    if ($actual -ne $expected) { throw "Expected Godot $expected, found $actual" }
    return $actual
}

function Initialize-FluxWindowObservation {
    if ('FluxWindowObservationNative' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class FluxWindowObservationNative {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool IsIconic(IntPtr window);
}
'@
}

function Get-FluxWindowObservation([Diagnostics.Process]$Process, [long]$ElapsedMilliseconds) {
    $sample = [ordered]@{ elapsed_ms = $ElapsedMilliseconds; foreground_process_matches = $null; main_window_available = $null; main_window_visible = $null; main_window_minimized = $null; error = $null }
    try {
        $Process.Refresh()
        if ($Process.HasExited) { $sample.error = 'Process exited before this observation.'; return $sample }
        $foreground = [FluxWindowObservationNative]::GetForegroundWindow()
        if ($foreground -ne [IntPtr]::Zero) {
            [uint32]$foregroundProcessId = 0
            $threadId = [FluxWindowObservationNative]::GetWindowThreadProcessId($foreground, [ref]$foregroundProcessId)
            if ($threadId -ne 0) { $sample.foreground_process_matches = $foregroundProcessId -eq $Process.Id }
        }
        $mainWindow = $Process.MainWindowHandle
        $sample.main_window_available = $mainWindow -ne [IntPtr]::Zero
        if ($mainWindow -ne [IntPtr]::Zero) {
            $sample.main_window_visible = [FluxWindowObservationNative]::IsWindowVisible($mainWindow)
            $sample.main_window_minimized = [FluxWindowObservationNative]::IsIconic($mainWindow)
        }
    } catch { $sample.error = $_.Exception.Message }
    return $sample
}

function Invoke-FluxGodotChecked {
    param(
        [string]$GodotBin,
        [string[]]$Arguments,
        [string]$LogPath,
        [switch]$RejectWarnings,
        [ValidateRange(1, 1800)][int]$TimeoutSeconds = 180,
        [switch]$VisibleWindow,
        [Collections.Generic.List[object]]$WindowObservations = $null
    )
    $lease = Enter-FluxEngineRun 'checked-engine'
    $process = $null
    try {
    if ($null -ne $WindowObservations) { Initialize-FluxWindowObservation }
    $errorPath = "$LogPath.err"
    foreach ($path in @($LogPath, $errorPath)) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
    # Start-Process joins ArgumentList values into one command line on Windows.
    # Quote every value so clones living below a path with spaces remain valid.
    $quotedArguments = $Arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }
    $process = Start-FluxOwnedProcess @{FilePath=$GodotBin; ArgumentList=$quotedArguments; RedirectStandardOutput=$LogPath; RedirectStandardError=$errorPath; WindowStyle=$(if ($VisibleWindow) { 'Normal' } else { 'Hidden' })}
    $observationWatch = if ($null -ne $WindowObservations) { [Diagnostics.Stopwatch]::StartNew() } else { $null }
    $nextObservationMs = 0L
    # Failed test scripts may never exit their own loops. Bound this owned child.
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while (-not $process.WaitForExit(250) -and [DateTime]::UtcNow -lt $deadline) {
        if ($null -ne $WindowObservations -and $observationWatch.ElapsedMilliseconds -ge $nextObservationMs) {
            $WindowObservations.Add((Get-FluxWindowObservation $process $observationWatch.ElapsedMilliseconds))
            $nextObservationMs = $observationWatch.ElapsedMilliseconds + 500L
        }
    }
    if (-not $process.HasExited) {
        $process.Kill()
        $process.WaitForExit()
        throw "Godot check timed out after $TimeoutSeconds seconds; inspect $LogPath and $errorPath"
    }
    # The timed overload can return before redirected stream bookkeeping has
    # populated ExitCode on some Windows/.NET combinations. Drain once and
    # refresh so a successful check can never be reported as a blank failure.
    $process.WaitForExit()
    $process.Refresh()
    $combined = @()
    if (Test-Path -LiteralPath $LogPath) { $combined += Get-Content -LiteralPath $LogPath -Tail 2000 }
    if (Test-Path -LiteralPath $errorPath) { $combined += Get-Content -LiteralPath $errorPath -Tail 2000 }
    $combined | Write-Output
    $existingLogs = @($LogPath, $errorPath) | Where-Object { Test-Path -LiteralPath $_ }
    $bad = Select-String -LiteralPath $existingLogs -Pattern '^(FAIL:|ERROR:)|SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|Invalid call' -Quiet
    if ($true -in @($bad)) { throw 'Godot emitted a script/import/runtime error.' }
    # Some Godot/Windows combinations leave ExitCode unset despite HasExited;
    # clean non-empty logs are still inspectable, while an absent log is never
    # accepted. A populated non-zero code remains authoritative.
    if ($null -ne $process.ExitCode -and [int]$process.ExitCode -ne 0) { throw "Godot exited with code $($process.ExitCode)" }
    if ($null -eq $process.ExitCode -and $combined.Count -eq 0) { throw 'Godot exited without an inspectable result.' }
    if ($RejectWarnings) {
        $warnings = Select-String -LiteralPath $existingLogs -Pattern '^(WARNING|ERROR):' -Quiet
        if ($true -in @($warnings)) { throw 'Godot emitted an unexpected warning/error; inspect the complete logs.' }
    }
    }
    finally {
        try { if ($null -ne $process -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() } }
        finally { Exit-FluxEngineRun $lease }
    }
}

function Get-FluxTickRate([int]$Requested) {
    if ($Requested -ne 120) { throw 'TickRate must be 120.' }
    return $Requested
}

function Get-FluxExportTemplateRoot {
    if ($env:GODOT_EXPORT_TEMPLATE_ROOT) {
        return [System.IO.Path]::GetFullPath($env:GODOT_EXPORT_TEMPLATE_ROOT)
    }
    return Join-Path $env:APPDATA 'Godot\export_templates\4.7.1.stable'
}

function Assert-FluxExportTemplates([string]$Target) {
    $templateRoot = Get-FluxExportTemplateRoot
    $required = @()
    if ($Target -in @('Windows', 'All')) { $required += 'windows_release_x86_64.exe' }
    if ($Target -in @('Linux', 'All')) { $required += 'linux_release.x86_64' }
    $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $templateRoot $_) -PathType Leaf) })
    if ($missing.Count -gt 0) {
        throw "Godot 4.7.1 $Target release templates are missing at $templateRoot ($($missing -join ', ')). Open the pinned editor, choose Editor > Manage Export Templates, install 4.7.1.stable once, then rerun."
    }
    return $templateRoot
}
