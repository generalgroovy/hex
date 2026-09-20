param(
    [Parameter(Mandatory = $true)][ValidatePattern('^[a-z0-9][a-z0-9-]{0,47}$')][string]$Name,
    [ValidateSet('1280x720', '1920x1080')][string]$Resolution = '1280x720',
    [ValidateSet(120)][int]$TickRate = 120,
    [ValidateRange(2, 120)][int]$Frames = 4,
    [switch]$FarflowPair,
    [ValidateRange(1024, 65535)][int]$Port = 24920,
    [string[]]$FarflowGuestArguments = @(),
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$GameArguments
)

. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$workflowLease = Enter-FluxEngineRun 'capture-visual'
try {

$repoRoot = Get-FluxRepoRoot
$godotBin = Get-FluxGodot
Assert-FluxGodotVersion $godotBin | Out-Null
$parts = $Resolution.Split('x')
$width = [int]$parts[0]
$height = [int]$parts[1]
$outputRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot ".godot\visual-captures\$Name"))
$allowedOutputRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot '.godot\visual-captures'))
if (-not $outputRoot.StartsWith($allowedOutputRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Capture output escaped the ignored visual-capture root.'
}
if (Test-Path -LiteralPath $outputRoot) {
    throw "Capture already exists; choose a new name: $outputRoot"
}
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null

$temporaryRoot = [System.IO.Path]::GetFullPath((Join-Path ([System.IO.Path]::GetTempPath()) ("flux2-visual-capture-" + [guid]::NewGuid().ToString('N'))))
$systemTemporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
if (-not $temporaryRoot.StartsWith($systemTemporaryRoot, [System.StringComparison]::OrdinalIgnoreCase) -or -not ([System.IO.Path]::GetFileName($temporaryRoot)).StartsWith('flux2-visual-capture-')) {
    throw 'Temporary capture project did not resolve below the system temporary directory.'
}
$farflowPeerProcess = $null
$movieProcess = $null

if ($FarflowPair) {
    if ($Frames -lt 60) { throw 'A paired Farflow capture requires at least 60 frames so the real join and shared greeting can settle.' }
    foreach ($argument in $GameArguments) {
        if ($argument -like '--farflow=*' -or $argument -like '--session-port=*' -or $argument -like '--player-name=*') {
            throw 'Paired Farflow capture owns farflow mode, port and diagnostic player names.'
        }
    }
    foreach ($argument in $FarflowGuestArguments) {
        if ($argument -like '--farflow=*' -or $argument -like '--session-port=*' -or $argument -like '--player-name=*') {
            throw 'Paired Farflow guest arguments cannot override farflow mode, port or diagnostic player name.'
        }
    }
}

try {
    New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null
    & robocopy.exe $repoRoot $temporaryRoot /E /NFL /NDL /NJH /NJS /NP /XD .git .godot dist node_modules /XF firewall.ps1 | Out-Null
    if ($LASTEXITCODE -gt 7) { throw "Temporary project copy failed with robocopy code $LASTEXITCODE" }
    $sourceGodotCache = Join-Path $repoRoot '.godot'
    $temporaryGodotCache = Join-Path $temporaryRoot '.godot'
    New-Item -ItemType Directory -Path $temporaryGodotCache -Force | Out-Null
    foreach ($cacheFileName in @('global_script_class_cache.cfg', 'uid_cache.bin')) {
        $sourceCacheFile = Join-Path $sourceGodotCache $cacheFileName
        if (Test-Path -LiteralPath $sourceCacheFile -PathType Leaf) {
            Copy-Item -LiteralPath $sourceCacheFile -Destination (Join-Path $temporaryGodotCache $cacheFileName)
        }
    }
    $sourceImportedCache = Join-Path $sourceGodotCache 'imported'
    if (Test-Path -LiteralPath $sourceImportedCache -PathType Container) {
        & robocopy.exe $sourceImportedCache (Join-Path $temporaryGodotCache 'imported') /E /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -gt 7) { throw "Temporary Godot import-cache copy failed with robocopy code $LASTEXITCODE" }
    }

    $temporaryProject = Join-Path $temporaryRoot 'project.godot'
    $projectText = [System.IO.File]::ReadAllText($temporaryProject)
    $projectText = [regex]::Replace($projectText, 'window/size/viewport_width=\d+', "window/size/viewport_width=$width")
    $projectText = [regex]::Replace($projectText, 'window/size/viewport_height=\d+', "window/size/viewport_height=$height")
    $projectText = [regex]::Replace($projectText, 'window/size/window_width_override=\d+', "window/size/window_width_override=$width")
    $projectText = [regex]::Replace($projectText, 'window/size/window_height_override=\d+', "window/size/window_height_override=$height")
    [System.IO.File]::WriteAllText($temporaryProject, $projectText, [System.Text.UTF8Encoding]::new($false))

    $importLogPath = Join-Path $outputRoot 'import.log'
    Invoke-FluxGodotChecked $godotBin @('--headless', '--editor', '--path', $temporaryRoot, '--quit') $importLogPath | Out-Null

    $effectiveGameArguments = @($GameArguments)
    if ($FarflowPair) {
        $effectiveGameArguments += @(
            '--farflow=host', "--session-port=$Port", '--session-charter=open_commons',
            '--player-name=Lantern Host', '--capture-spawn=300,720'
        )
    }

    $moviePath = Join-Path $outputRoot 'frame.png'
    $logPath = Join-Path $outputRoot 'capture.log'
    $arguments = @(
        '--path', $temporaryRoot,
        '--windowed', '--resolution', $Resolution,
        '--write-movie', $moviePath,
        '--quit-after', "$Frames", '--fixed-fps', "$TickRate",
        '--', "--tick-rate=$TickRate"
    ) + $effectiveGameArguments
    if ($FarflowPair) {
        $movieErrorPath = "$logPath.err"
        $quotedMovieArguments = $arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }
        $movieProcess = Start-FluxOwnedProcess @{FilePath=$godotBin; ArgumentList=$quotedMovieArguments; RedirectStandardOutput=$logPath; RedirectStandardError=$movieErrorPath; WindowStyle='Hidden'}
        $hostDeadline = [datetime]::UtcNow.AddSeconds(20)
        $hostReady = $false
        while ([datetime]::UtcNow -lt $hostDeadline) {
            if (Test-Path -LiteralPath $logPath) {
                $hostText = Get-Content -LiteralPath $logPath -Raw
                if ($hostText -match [regex]::Escape("FLUX2 farflow host: listening on UDP $Port")) {
                    $hostReady = $true
                    break
                }
            }
            if ($movieProcess.HasExited) { break }
            Start-Sleep -Milliseconds 100
        }
        if (-not $hostReady) { throw "Visual Farflow host did not become ready on UDP $Port; see $logPath" }

        $peerLogPath = Join-Path $outputRoot 'farflow-guest.log'
        $peerErrorPath = Join-Path $outputRoot 'farflow-guest.err.log'
        $peerArguments = @(
            '--headless', '--path', $temporaryRoot, '--fixed-fps', "$TickRate", '--',
            "--tick-rate=$TickRate", '--farflow=join', '--join-address=127.0.0.1',
            "--session-port=$Port", '--player-name=River Guest', '--farflow-smoke-emote'
        ) + @($FarflowGuestArguments)
        $quotedPeerArguments = $peerArguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }
        $farflowPeerProcess = Start-FluxOwnedProcess @{FilePath=$godotBin; ArgumentList=$quotedPeerArguments; RedirectStandardOutput=$peerLogPath; RedirectStandardError=$peerErrorPath; WindowStyle='Hidden'}
        if (-not $movieProcess.WaitForExit(120000)) { throw 'Visual Farflow host did not complete its bounded movie capture.' }
        $movieProcess.WaitForExit()
        $movieProcess.Refresh()
        $movieExitCode = $movieProcess.ExitCode
        if ($null -ne $movieExitCode -and [int]$movieExitCode -ne 0) { throw "Visual Farflow host exited with code $movieExitCode." }
        $combinedMovieLog = @()
        if (Test-Path -LiteralPath $logPath) { $combinedMovieLog += Get-Content -LiteralPath $logPath }
        if (Test-Path -LiteralPath $movieErrorPath) { $combinedMovieLog += Get-Content -LiteralPath $movieErrorPath }
        if ($combinedMovieLog | Select-String -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|Invalid call') {
            throw 'Visual Farflow host emitted a script/import/runtime error.'
        }
        $movieText = $combinedMovieLog -join "`n"
        if ($movieText -notmatch [regex]::Escape('Done recording movie at path:')) {
            throw 'Visual Farflow host exited without completing its movie capture.'
        }
        foreach ($requiredPattern in @('FLUX2 farflow host: joined entity 2 (River Guest)', 'FLUX2 farflow social: shared emote entity 2')) {
            if ($movieText -notmatch [regex]::Escape($requiredPattern)) {
                throw "Paired Farflow capture missed '$requiredPattern'."
            }
        }
    }
    else {
        Invoke-FluxGodotChecked $godotBin $arguments $logPath | Out-Null
    }

    $frameFiles = @(Get-ChildItem -LiteralPath $outputRoot -Filter 'frame*.png' -File)
    if ($frameFiles.Count -ne $Frames) { throw "Expected $Frames movie frames, found $($frameFiles.Count)." }
    Add-Type -AssemblyName System.Drawing
    foreach ($frame in $frameFiles) {
        $image = [System.Drawing.Image]::FromFile($frame.FullName)
        try {
            if ($image.Width -ne $width -or $image.Height -ne $height) {
                throw "Capture $($frame.Name) is $($image.Width)x$($image.Height), expected $Resolution."
            }
        }
        finally { $image.Dispose() }
    }
    $pairLabel = if ($FarflowPair) { ' with a real two-process Farflow pair' } else { '' }
    Write-Output "PASS: $($frameFiles.Count) truthful $Resolution frames$pairLabel at $outputRoot"
}
finally {
    foreach ($process in @($farflowPeerProcess, $movieProcess)) {
        if ($null -ne $process -and -not $process.HasExited) {
            Stop-Process -Id $process.Id -Force
            $process.WaitForExit()
        }
    }
    if (Test-Path -LiteralPath $temporaryRoot) {
        $resolvedTemporaryRoot = [System.IO.Path]::GetFullPath($temporaryRoot)
        if ($resolvedTemporaryRoot.StartsWith($systemTemporaryRoot, [System.StringComparison]::OrdinalIgnoreCase) -and ([System.IO.Path]::GetFileName($resolvedTemporaryRoot)).StartsWith('flux2-visual-capture-')) {
            Remove-Item -LiteralPath $resolvedTemporaryRoot -Recurse -Force
        }
    }
}

} finally { Exit-FluxEngineRun $workflowLease }
