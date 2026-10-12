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
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool IsIconic(IntPtr window);
    [DllImport("user32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool GetClientRect(IntPtr window, out RECT rect);
    [DllImport("user32.dll", SetLastError = true)] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr window);
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool SetForegroundWindow(IntPtr window);
}
'@
}

function Get-FluxWindowObservation([Diagnostics.Process]$Process, [long]$ElapsedMilliseconds) {
    $sample = [ordered]@{
        elapsed_ms = $ElapsedMilliseconds; observed_utc = [DateTime]::UtcNow.ToString('o'); process_id = $Process.Id
        foreground_process_matches = $null; foreground_window_matches = $null; foreground_process_id = $null
        main_window_available = $null; main_window_visible = $null; main_window_minimized = $null
        main_window_handle = $null; main_window_process_id = $null; main_window_process_matches = $null
        client_width = $null; client_height = $null; client_size_scope = $null; window_dpi = $null
        process_private_bytes = $null; process_working_set_bytes = $null; process_memory_error = $null
        availability_reason = 'query_failed'; error = $null
    }
    try {
        $Process.Refresh()
        if ($Process.HasExited) { $sample.main_window_available = $false; $sample.availability_reason = 'process_exited'; return $sample }
        try { $sample.process_private_bytes = $Process.PrivateMemorySize64; $sample.process_working_set_bytes = $Process.WorkingSet64 }
        catch { $sample.process_memory_error = $_.Exception.Message }
        $foreground = [FluxWindowObservationNative]::GetForegroundWindow()
        if ($foreground -ne [IntPtr]::Zero) {
            [uint32]$foregroundProcessId = 0
            $threadId = [FluxWindowObservationNative]::GetWindowThreadProcessId($foreground, [ref]$foregroundProcessId)
            if ($threadId -ne 0) { $sample.foreground_process_id = $foregroundProcessId; $sample.foreground_process_matches = $foregroundProcessId -eq $Process.Id }
        }
        $mainWindow = $Process.MainWindowHandle
        $sample.main_window_available = $mainWindow -ne [IntPtr]::Zero
        $sample.availability_reason = if ($sample.main_window_available) { 'available' } else { 'window_unavailable' }
        if ($mainWindow -ne [IntPtr]::Zero) {
            $sample.main_window_handle = $mainWindow.ToInt64().ToString('X')
            $sample.foreground_window_matches = $foreground -eq $mainWindow
            [uint32]$ownerProcessId = 0
            if ([FluxWindowObservationNative]::GetWindowThreadProcessId($mainWindow, [ref]$ownerProcessId) -eq 0) { throw 'Could not resolve the owned main-window process.' }
            $sample.main_window_process_id = $ownerProcessId
            $sample.main_window_process_matches = $ownerProcessId -eq $Process.Id
            if (-not $sample.main_window_process_matches) { throw 'Observed HWND no longer belongs to the launched process.' }
            $sample.main_window_visible = [FluxWindowObservationNative]::IsWindowVisible($mainWindow)
            $sample.main_window_minimized = [FluxWindowObservationNative]::IsIconic($mainWindow)
            # Thread-local query context only; restore even on error. Do not
            # alter the game process or system DPI settings. GetClientRect's
            # right/bottom are exclusive client bounds, never outer decoration.
            # https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-getclientrect
            $oldDpiContext = [FluxWindowObservationNative]::SetThreadDpiAwarenessContext([IntPtr]::new(-4))
            if ($oldDpiContext -eq [IntPtr]::Zero) { throw 'Could not establish physical-pixel DPI context for client-size observation.' }
            try {
                $rect = [FluxWindowObservationNative+RECT]::new()
                if (-not [FluxWindowObservationNative]::GetClientRect($mainWindow, [ref]$rect)) { throw 'GetClientRect failed for the owned window.' }
                $sample.client_width = $rect.Right - $rect.Left
                $sample.client_height = $rect.Bottom - $rect.Top
                $sample.client_size_scope = 'physical_pixels_per_monitor_v2'
                $sample.window_dpi = [FluxWindowObservationNative]::GetDpiForWindow($mainWindow)
            } finally {
                if ([FluxWindowObservationNative]::SetThreadDpiAwarenessContext($oldDpiContext) -eq [IntPtr]::Zero) { $sample.error = 'Could not restore observer thread DPI context.' }
            }
            [uint32]$ownerAfter = 0
            if ([FluxWindowObservationNative]::GetWindowThreadProcessId($mainWindow, [ref]$ownerAfter) -eq 0 -or $ownerAfter -ne $ownerProcessId) { throw 'Owned-window identity changed while querying client size.' }
        }
    } catch { $sample.error = $_.Exception.Message }
    return $sample
}

function Request-FluxOwnedWindowForeground([Diagnostics.Process]$Process, [long]$ElapsedMilliseconds) {
    # One explicitly opted-in request, separate from the read-only observer.
    # Windows may refuse foreground activation. Never retry, change its policy,
    # attach input threads, synthesize input, or target an unrelated HWND.
    $request = [ordered]@{ elapsed_ms = $ElapsedMilliseconds; process_id = $Process.Id; window_handle = $null; window_process_id = $null; requested = $false; native_returned_success = $null; error = $null }
    try {
        $Process.Refresh()
        if ($Process.HasExited) { throw 'Owned process exited before its foreground request.' }
        $window = $Process.MainWindowHandle
        if ($window -eq [IntPtr]::Zero) { throw 'Owned main window disappeared before its foreground request.' }
        [uint32]$windowProcessId = 0
        if ([FluxWindowObservationNative]::GetWindowThreadProcessId($window, [ref]$windowProcessId) -eq 0 -or $windowProcessId -ne $Process.Id) { throw 'Foreground request refused because HWND ownership could not be proved.' }
        $request.window_handle = $window.ToInt64().ToString('X')
        $request.window_process_id = $windowProcessId
        $request.requested = $true
        $request.native_returned_success = [FluxWindowObservationNative]::SetForegroundWindow($window)
    } catch { $request.error = $_.Exception.Message }
    return $request
}

function Get-FluxEngineLogPreview([string]$Path) {
    # PowerShell's reverse Tail reader can take minutes on a single large JSON
    # assertion. Stream complete lines instead; keep full evidence on disk and
    # leave validation below scanning the original, unabridged log.
    $lines = [Collections.Generic.Queue[string]]::new()
    $stream = [IO.File]::Open([IO.Path]::GetFullPath($Path), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $reader = [IO.StreamReader]::new($stream)
    try {
        while ($null -ne ($line = $reader.ReadLine())) {
            $preview = if ($line.Length -gt 4000) { $line.Substring(0, 4000) + ' ... [preview truncated; see full log]' } else { $line }
            $lines.Enqueue($preview)
            if ($lines.Count -gt 2000) { $null = $lines.Dequeue() }
        }
    } finally {
        $reader.Dispose()
    }
    return $lines.ToArray()
}

function Invoke-FluxGodotChecked {
    param(
        [string]$GodotBin,
        [string[]]$Arguments,
        [string]$LogPath,
        [switch]$RejectWarnings,
        [ValidateRange(1, 3600)][int]$TimeoutSeconds = 180,
        [ValidateRange(0, 1799)][int]$CloseAfterSeconds = 0,
        [switch]$VisibleWindow,
        [Collections.Generic.List[object]]$WindowObservations = $null,
        [switch]$RequestForegroundOnce,
        [Collections.Generic.List[object]]$WindowActivationRequests = $null
    )
    $lease = Enter-FluxEngineRun 'checked-engine'
    $process = $null
    try {
    if ($CloseAfterSeconds -ge $TimeoutSeconds) { throw 'Scheduled window close must precede the engine watchdog.' }
    if ($RequestForegroundOnce -and -not $VisibleWindow) { throw 'Foreground request requires explicit VisibleWindow.' }
    if ($null -ne $WindowObservations -or $RequestForegroundOnce) { Initialize-FluxWindowObservation }
    $errorPath = "$LogPath.err"
    foreach ($path in @($LogPath, $errorPath)) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
    # Start-Process joins ArgumentList values into one command line on Windows.
    # Quote every value so clones living below a path with spaces remain valid.
    $quotedArguments = $Arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }
    $process = Start-FluxOwnedProcess @{FilePath=$GodotBin; ArgumentList=$quotedArguments; RedirectStandardOutput=$LogPath; RedirectStandardError=$errorPath; WindowStyle=$(if ($VisibleWindow) { 'Normal' } else { 'Hidden' })}
    $closeWatch = if ($CloseAfterSeconds -gt 0) { [Diagnostics.Stopwatch]::StartNew() } else { $null }
    $windowCloseRequested = $false
    $observationWatch = if ($null -ne $WindowObservations -or $RequestForegroundOnce) { [Diagnostics.Stopwatch]::StartNew() } else { $null }
    $foregroundAttempted = $false
    $nextObservationMs = 0L
    # Failed test scripts may never exit their own loops. Bound this owned child.
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while (-not $process.WaitForExit(250) -and [DateTime]::UtcNow -lt $deadline) {
        if ($RequestForegroundOnce -and -not $foregroundAttempted) {
            $process.Refresh()
            if (-not $process.HasExited -and $process.MainWindowHandle -ne [IntPtr]::Zero) {
                $foregroundAttempted = $true
                $activation = Request-FluxOwnedWindowForeground $process $observationWatch.ElapsedMilliseconds
                if ($null -ne $WindowActivationRequests) { $WindowActivationRequests.Add($activation) }
            }
        }
        if ($CloseAfterSeconds -gt 0 -and -not $windowCloseRequested -and $closeWatch.Elapsed.TotalSeconds -ge $CloseAfterSeconds) {
            $process.Refresh()
            if ($process.HasExited) { break }
            if (-not $process.CloseMainWindow()) { throw 'The owned engine process did not accept a normal window-close request.' }
            $windowCloseRequested = $true
        }
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
    if ($CloseAfterSeconds -gt 0 -and -not $windowCloseRequested) { throw 'Engine exited before its scheduled normal window-close request.' }
    $combined = @()
    if (Test-Path -LiteralPath $LogPath) { $combined += Get-FluxEngineLogPreview $LogPath }
    if (Test-Path -LiteralPath $errorPath) { $combined += Get-FluxEngineLogPreview $errorPath }
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
