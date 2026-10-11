param(
    [Parameter(Mandatory)][string]$PreviousInstaller,
    [Parameter(Mandatory)][string]$Installer,
    [Parameter(Mandatory)][ValidatePattern('^p[0-9]+-[0-9a-f]{12}$')][string]$ExpectedPreviousBuildId,
    [Parameter(Mandatory)][ValidatePattern('^p[0-9]+-[0-9a-f]{12}$')][string]$ExpectedBuildId,
    [string]$TestRoot = '',
    [string]$ResumeFailedTestRoot = '',
    [ValidateRange(10, 300)][int]$TimeoutSeconds = 120
)

# Real payload installation/selection acceptance only. Never starts the game,
# creates shortcuts, touches the normal profile, or deletes retained evidence.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
$testParent = [IO.Path]::GetFullPath((Join-Path $repoRoot 'exports\hex-installer-tests'))

function Get-PhysicalPath([string]$Path) {
    if ($Path -notmatch '^[A-Za-z]:[\\/]') { throw 'An absolute local Windows path is required.' }
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    $ancestor = $full
    while ($ancestor) {
        $item = Get-Item -LiteralPath $ancestor -Force -ErrorAction SilentlyContinue
        if ($null -ne $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Reparse-point path refused: $ancestor"
        }
        $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }
    return $full
}

function Get-Hash([string]$Path) {
    $physical = Get-PhysicalPath $Path
    if (-not (Test-Path -LiteralPath $physical -PathType Leaf)) { throw "Missing file: $physical" }
    return (Get-FileHash -LiteralPath $physical -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-InstallerPin([string]$Path, [string]$BuildId) {
    $physical = Get-PhysicalPath $Path
    if ([IO.Path]::GetExtension($physical) -ine '.exe') { throw 'Expected a trusted local HEX-Setup executable.' }
    $hash = Get-Hash $physical
    # Read literal metadata only; never invoke a method from the supplied assembly.
    $assembly = [Reflection.Assembly]::LoadFile($physical)
    $program = $assembly.GetType('Hex.Bootstrap.Program', $true)
    $constants = @{}
    foreach ($name in @('PayloadVersion', 'ManifestSha256')) {
        $field = $program.GetField($name, [Reflection.BindingFlags]'NonPublic,Static')
        if ($null -eq $field -or -not $field.IsLiteral) { throw "Missing installer constant: $name" }
        $constants[$name] = [string]$field.GetRawConstantValue()
    }
    if ($constants.ManifestSha256 -cnotmatch '^[0-9a-f]{64}$' -or
        $constants.PayloadVersion -cnotmatch ('^' + [regex]::Escape($BuildId) + '-[0-9a-f]{10}$')) {
        throw "Installer does not embed the expected build identity: $BuildId"
    }
    return [pscustomobject]@{ Path=$physical; Sha256=$hash; BuildId=$BuildId;
        Version=$constants.PayloadVersion; ManifestHash=$constants.ManifestSha256 }
}

function Quote-Argument([AllowEmptyString()][string]$Value) {
    $builder = [Text.StringBuilder]::new()
    [void]$builder.Append('"'); $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') { $slashes++; continue }
        if ($character -eq '"') { [void]$builder.Append('\', 2 * $slashes + 1) }
        else { [void]$builder.Append('\', $slashes) }
        $slashes = 0; [void]$builder.Append($character)
    }
    [void]$builder.Append('\', 2 * $slashes); [void]$builder.Append('"')
    return $builder.ToString()
}

function Invoke-Install([string]$Stage, [string]$Path, [string]$ExpectedHash, [switch]$Previous) {
    if ((Get-Hash $Path) -cne $ExpectedHash) { throw "Executable changed before $Stage." }
    $arguments = @('--quiet', '--install-only', '--no-shortcuts', "--install-root=$installRoot")
    if ($Previous) { $arguments += '--previous' }
    $entry = [ordered]@{ stage=$Stage; executable=$Path; executable_sha256=$ExpectedHash;
        arguments=$arguments; pid=$null; exit_code=$null; forced_stop_requested=$false; forced_stop=$false; error='' }
    $processes.Add($entry)
    Write-Output "REAL_UPDATE_STAGE=$Stage"
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $Path
    $info.Arguments = ($arguments | ForEach-Object { Quote-Argument $_ }) -join ' '
    $info.WorkingDirectory = $TestRoot
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true
    $info.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    $info.EnvironmentVariables['APPDATA'] = $roaming
    $info.EnvironmentVariables['LOCALAPPDATA'] = $local
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    $started = $false; $stdout = $null; $stderr = $null
    try {
        $started = $process.Start()
        if (-not $started) { throw 'Windows did not start the isolated installer.' }
        $entry.pid = $process.Id
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $clock = [Diagnostics.Stopwatch]::StartNew()
        while (-not $process.WaitForExit(250)) {
            if ($clock.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                $entry.forced_stop_requested = $true
                $process.Kill() # Exact process handle created above; never discover/kill other processes.
                $entry.forced_stop = $process.WaitForExit(5000)
                throw "Isolated installer exceeded $TimeoutSeconds seconds; acceptance failed."
            }
        }
        $entry.exit_code = $process.ExitCode
        if (-not $stdout.Wait(2000) -or -not $stderr.Wait(2000)) { throw 'Installer output did not close.' }
        if ($process.ExitCode -ne 0 -or $stderr.Result.Length -ne 0) {
            throw "Installer failed: exit=$($process.ExitCode), stderr=$($stderr.Result)"
        }
        if ((Get-Hash $Path) -cne $ExpectedHash) { throw "Executable changed during $Stage." }
    } catch { $entry.error = $_.Exception.Message; throw }
    finally {
        if ($started -and $process.HasExited) { $entry.exit_code = $process.ExitCode }
        foreach ($stream in @(@('stdout', $stdout), @('stderr', $stderr))) {
            $content = if ($null -ne $stream[1] -and $stream[1].Status -eq 'RanToCompletion') { $stream[1].Result } else { '[Output unavailable or incomplete]' }
            $logPath = Get-PhysicalPath (Join-Path $TestRoot "$Stage.$($stream[0]).log")
            [IO.File]::WriteAllText($logPath, $content)
        }
        $process.Dispose()
    }
}

function Read-Selection([string]$Value) {
    if (-not $Value) { return $null }
    $parts = $Value.Split('|')
    if ($parts.Count -ne 3 -or $parts[0] -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,159}$' -or
        $parts[1] -cnotmatch '^[0-9a-f]{64}$') { throw 'Malformed protected selection.' }
    $arguments = if ($parts[2]) { @($parts[2].Split(',')) } else { @() }
    foreach ($argument in $arguments) {
        if ($argument -cnotin @('--fullbody-art', '--pixel-cast', '--pixel-body-pilot')) { throw 'Unexpected presentation argument.' }
    }
    return [pscustomobject]@{ Version=$parts[0]; ManifestHash=$parts[1]; Arguments=@($arguments); Encoded=$Value }
}

function Verify-Payload($Selection, $Pin) {
    if ($null -eq $Selection -or $Selection.Version -cne $Pin.Version -or
        $Selection.ManifestHash -cne $Pin.ManifestHash) { throw 'Selected build does not match the installer-pinned identity/manifest.' }
    $directory = Get-PhysicalPath (Join-Path (Join-Path $installRoot 'versions') $Selection.Version)
    $manifest = Join-Path $directory 'SHA256SUMS.txt'
    [void](Get-PhysicalPath $manifest)
    if ((Get-Item -LiteralPath $manifest).Length -gt 1MB -or (Get-Hash $manifest) -cne $Pin.ManifestHash) {
        throw 'Installed checksum manifest is not the installer-pinned manifest.'
    }
    $seen = @{}
    foreach ($line in [IO.File]::ReadAllLines($manifest)) {
        if (-not $line.Trim()) { continue }
        if ($line -cnotmatch '^([0-9a-fA-F]{64})  ([A-Za-z0-9_.-]+)$') { throw 'Expected flat safe package checksum records.' }
        $hash = $Matches[1]; $name = $Matches[2]
        if ($name -in @('.', '..', 'SHA256SUMS.txt') -or $name.EndsWith('.') -or $seen.ContainsKey($name)) {
            throw 'Duplicate or ambiguous manifest entry.'
        }
        if ((Get-Hash (Join-Path $directory $name)) -ine $hash) { throw "Installed file hash mismatch: $name" }
        $seen[$name] = $hash.ToLowerInvariant()
    }
    foreach ($required in @('hex.exe', 'hex.pck', 'BUILD-STATE.json', 'SOURCE-IDENTITY.json', 'PLAY-HEX.cmd')) {
        if (-not $seen.ContainsKey($required)) { throw "Unauthenticated required file: $required" }
    }
    foreach ($item in Get-ChildItem -LiteralPath $directory -Force) {
        [void](Get-PhysicalPath $item.FullName)
        if ($item.PSIsContainer -or ($item.Name -ne 'SHA256SUMS.txt' -and -not $seen.ContainsKey($item.Name))) {
            throw "Unexpected package content: $($item.Name)"
        }
    }
    $identity = Get-Content -LiteralPath (Join-Path $directory 'SOURCE-IDENTITY.json') -Raw | ConvertFrom-Json
    $build = Get-Content -LiteralPath (Join-Path $directory 'BUILD-STATE.json') -Raw | ConvertFrom-Json
    $runtime = $build.state.runtime.build_identity
    if ($identity.build_id -cne $Pin.BuildId -or $runtime.build_id -cne $Pin.BuildId -or
        $identity.runtime_source_sha256 -cne $runtime.runtime_source_sha256 -or
        $build.pack_sha256 -cne $seen['hex.pck']) { throw 'Installed source/build/PCK identities disagree.' }
    return $directory
}

function Assert-State([string]$Stage, $CurrentPin, $PreviousPin, [string]$ExpectedCurrent = '', [string]$ExpectedPrevious = '') {
    $marker = Get-PhysicalPath (Join-Path $installRoot '.hex-install-root')
    if ([IO.File]::ReadAllText($marker).Trim() -cne 'HEX-INSTALL-ROOT-V1') { throw 'Missing install ownership marker.' }
    $statePath = Get-PhysicalPath (Join-Path $installRoot 'selection.dat')
    if ((Get-Item -LiteralPath $statePath).Length -gt 16384) { throw 'Oversized protected selection.' }
    $bytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($statePath),
        [Text.Encoding]::UTF8.GetBytes('HEX-SELECTION-V1'), [Security.Cryptography.DataProtectionScope]::CurrentUser)
    $lines = [Text.Encoding]::UTF8.GetString($bytes).Split("`n")
    if ($lines.Count -ne 3 -or $lines[0] -cne 'HEX-SELECTION-V1') { throw 'Malformed protected state.' }
    $current = Read-Selection $lines[1]
    $previous = Read-Selection $lines[2]
    $directory = Verify-Payload $current $CurrentPin
    if ($null -eq $PreviousPin) {
        if ($null -ne $previous) { throw 'Clean installation unexpectedly retained a previous selection.' }
    } else { [void](Verify-Payload $previous $PreviousPin) }
    if (($ExpectedCurrent -and $current.Encoded -cne $ExpectedCurrent) -or
        ($ExpectedPrevious -and ($null -eq $previous -or $previous.Encoded -cne $ExpectedPrevious))) {
        throw 'Rollback/forward changed a retained selection or its presentation arguments.'
    }
    if ((Get-Hash $sentinel) -cne $sentinelHash) { throw 'Saved-profile sentinel was modified or removed.' }
    $checks.Add([ordered]@{ stage=$Stage; current=$current.Encoded; previous=$lines[2];
        selected_directory=$directory; all_payload_hashes_verified=$true; saved_profile_sentinel_preserved=$true })
    Write-Host "PASS: $Stage; selected $($CurrentPin.BuildId); retained files and saved-profile sentinel verified."
    return $current.Encoded
}

function Assert-NoResumeProcesses([string]$Root) {
    $names = @('hex', [IO.Path]::GetFileNameWithoutExtension($oldPin.Path), [IO.Path]::GetFileNameWithoutExtension($newPin.Path))
    foreach ($process in @(Get-Process -Name $names -ErrorAction SilentlyContinue)) {
        try {
            if ($process.HasExited) { continue }
            try { $path = $process.Path }
            catch { throw "Cannot establish whether process $($process.Id) belongs to the fixture." }
            if (-not $path -or $path.StartsWith($Root + '\', [StringComparison]::OrdinalIgnoreCase) -or
                $path -ieq $oldPin.Path -or $path -ieq $newPin.Path) {
                throw "A possible fixture game/installer is still running: PID $($process.Id)."
            }
        } finally { $process.Dispose() }
    }
}

function Read-ResumeFixture([string]$Root) {
    $rootPath = Get-PhysicalPath $Root
    if ((Split-Path -Parent $rootPath) -ine $testParent -or (Split-Path -Parent $TestRoot) -ine $testParent -or
        -not (Test-Path -LiteralPath $rootPath -PathType Container) -or
        $TestRoot -ieq $rootPath -or $TestRoot.StartsWith($rootPath + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'ResumeFailedTestRoot must be an existing direct fixture child, separate from fresh TestRoot.'
    }
    # Inspect each physical directory before descending; never follow a link.
    $pending = [Collections.Generic.Stack[string]]::new()
    $pending.Push($rootPath)
    while ($pending.Count) {
        foreach ($item in Get-ChildItem -LiteralPath $pending.Pop() -Force) {
            [void](Get-PhysicalPath $item.FullName)
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
    $priorPath = Get-PhysicalPath (Join-Path $rootPath 'receipt.json')
    if ((Get-Item -LiteralPath $priorPath).Length -gt 1MB) { throw 'Oversized prior receipt.' }
    $prior = Get-Content -LiteralPath $priorPath -Raw | ConvertFrom-Json
    if ($prior.schema_version -ne 1 -or $prior.passed -isnot [bool] -or $prior.passed -or
        $prior.test_root -ine $rootPath -or @($prior.checks).Count -ne 1 -or @($prior.processes).Count -ne 2) {
        throw 'Resume requires one failed fixture with only old-install success and new-update failure.'
    }
    foreach ($flag in @('godot_run', 'user_profile_install', 'shortcuts_created', 'remote_updates_tested')) {
        if ($prior.$flag -isnot [bool] -or $prior.$flag) { throw "Unexpected prior fixture scope: $flag" }
    }
    $rootInstall = Get-PhysicalPath (Join-Path $rootPath 'real payload install')
    $rootRoaming = Get-PhysicalPath (Join-Path $rootPath 'isolated-roaming')
    $rootLocal = Get-PhysicalPath (Join-Path $rootPath 'isolated-local')
    $rootSentinel = Get-PhysicalPath (Join-Path $rootRoaming 'Godot\app_userdata\FLUX 2\installer-preservation-sentinel.txt')
    if ($prior.installed_root -ine $rootInstall -or $prior.saved_profile_sentinel -ine $rootSentinel -or
        $prior.sentinel_sha256 -cnotmatch '^[0-9a-f]{64}$') { throw 'Prior receipt paths or sentinel identity disagree.' }
    foreach ($path in @($rootInstall, $rootRoaming, $rootLocal)) {
        if (-not (Test-Path -LiteralPath $path -PathType Container)) { throw "Missing isolated fixture directory: $path" }
    }
    $pins = @($oldPin, $newPin)
    $recordedPins = @($prior.previous_installer, $prior.installer)
    $expectedArguments = @('--quiet', '--install-only', '--no-shortcuts', "--install-root=$rootInstall")
    for ($index = 0; $index -lt 2; $index++) {
        $pin = $pins[$index]; $recorded = $recordedPins[$index]; $process = $prior.processes[$index]
        if ((Get-PhysicalPath $recorded.Path) -ine $pin.Path) { throw 'Resume installer path mismatch.' }
        foreach ($field in @('Sha256', 'BuildId', 'Version', 'ManifestHash')) {
            if ($recorded.$field -cne $pin.$field) { throw "Resume installer $field mismatch." }
        }
        $expectedStage = if ($index -eq 0) { '01-old-install' } else { '02-new-update' }
        if ($process.stage -cne $expectedStage -or $process.exit_code -ne $index -or
            $process.executable -ine $pin.Path -or $process.executable_sha256 -cne $pin.Sha256 -or
            $process.forced_stop_requested -isnot [bool] -or $process.forced_stop_requested -or
            $process.forced_stop -isnot [bool] -or $process.forced_stop -or
            (($process.arguments | ConvertTo-Json -Compress) -cne ($expectedArguments | ConvertTo-Json -Compress))) {
            throw 'Prior process evidence does not match the required isolated old/new sequence.'
        }
    }
    $oldCheck = $prior.checks[0]
    $oldDirectory = Join-Path (Join-Path $rootInstall 'versions') $oldPin.Version
    if ($oldCheck.stage -cne '01-old-install' -or -not $oldCheck.current -or $oldCheck.previous -cne '' -or
        $oldCheck.selected_directory -ine $oldDirectory -or -not $oldCheck.all_payload_hashes_verified -or
        -not $oldCheck.saved_profile_sentinel_preserved -or $prior.processes[0].error -cne '' -or
        -not $prior.processes[1].error -or -not $prior.failure) { throw 'Prior old-state verification is incomplete.' }
    foreach ($item in Get-ChildItem -LiteralPath $rootInstall -Force) {
        if ($item.Name -cnotin @('versions', 'HEX.exe', 'selection.dat', '.hex-install-root', 'bootstrap.log')) {
            throw "Resume refuses staged or unexpected install content: $($item.Name)"
        }
    }
    $versions = @(Get-ChildItem -LiteralPath (Join-Path $rootInstall 'versions') -Force)
    if ($versions.Count -ne 1 -or -not $versions[0].PSIsContainer -or $versions[0].Name -cne $oldPin.Version) {
        throw 'Resume requires exactly the intact old version, with no staged/new versions.'
    }
    Assert-NoResumeProcesses $rootInstall
    $evidence = @()
    foreach ($name in @('receipt.json', '01-old-install.stdout.log', '01-old-install.stderr.log', '02-new-update.stdout.log', '02-new-update.stderr.log')) {
        $path = Join-Path $rootPath $name
        $evidence += [pscustomobject]@{ path=$path; sha256=(Get-Hash $path) }
    }
    $bootstrapLog = Join-Path $rootInstall 'bootstrap.log'
    return [pscustomobject]@{ Root=$rootPath; ReceiptPath=$priorPath; Receipt=$prior; InstallRoot=$rootInstall;
        Roaming=$rootRoaming; Local=$rootLocal; Sentinel=$rootSentinel; Evidence=$evidence;
        BootstrapLog=$bootstrapLog; BootstrapHash=(Get-Hash $bootstrapLog) }
}

if ($ExpectedPreviousBuildId -ceq $ExpectedBuildId) { throw 'Distinct old and new build IDs are required.' }
if (-not $TestRoot) { $TestRoot = Join-Path $testParent ('real-update-' + [guid]::NewGuid().ToString('N')) }
$TestRoot = Get-PhysicalPath $TestRoot
if (-not $TestRoot.StartsWith($testParent + '\', [StringComparison]::OrdinalIgnoreCase) -or
    (Test-Path -LiteralPath $TestRoot)) { throw 'TestRoot must be a fresh child of exports/hex-installer-tests.' }
$oldPin = Get-InstallerPin $PreviousInstaller $ExpectedPreviousBuildId
$newPin = Get-InstallerPin $Installer $ExpectedBuildId
if ($oldPin.Sha256 -ceq $newPin.Sha256 -or $oldPin.ManifestHash -ceq $newPin.ManifestHash) { throw 'Distinct installer payloads are required.' }
$installRoot = Join-Path $TestRoot 'real payload install'
$roaming = Join-Path $TestRoot 'isolated-roaming'
$local = Join-Path $TestRoot 'isolated-local'
$sentinel = Join-Path $roaming 'Godot\app_userdata\FLUX 2\installer-preservation-sentinel.txt'
$processes = [Collections.Generic.List[object]]::new()
$checks = [Collections.Generic.List[object]]::new()
$resume = $null
if ($ResumeFailedTestRoot) {
    $resume = Read-ResumeFixture $ResumeFailedTestRoot
    $installRoot = $resume.InstallRoot; $roaming = $resume.Roaming; $local = $resume.Local
    $sentinel = $resume.Sentinel; $sentinelHash = $resume.Receipt.sentinel_sha256
    Add-Type -AssemblyName System.Security
    $oldSelection = Assert-State '01-resumed-old-state' $oldPin $null $resume.Receipt.checks[0].current
    if ((Get-Hash (Join-Path $installRoot 'HEX.exe')) -cne $oldPin.Sha256) { throw 'Resume stored launcher does not match the old setup.' }
}
New-Item -ItemType Directory -Path $TestRoot | Out-Null
$receipt = [ordered]@{ schema_version=1; passed=$false;
    scope='Real offline payload update/rollback/forward and save-file preservation; no gameplay or save compatibility certification.';
    test_root=$TestRoot; installed_root=$installRoot; previous_installer=$oldPin; installer=$newPin;
    godot_run=$false; user_profile_install=$false; shortcuts_created=$false; remote_updates_tested=$false;
    saved_profile_sentinel=$sentinel; sentinel_sha256=$null; checks=@(); processes=@(); failure='' }
try {
    if ($null -ne $resume) {
        $receipt.sentinel_sha256 = $sentinelHash
        $snapshot = Get-PhysicalPath (Join-Path $TestRoot '00-pre-resume-bootstrap.log')
        $receipt.resume = [ordered]@{ original_test_root=$resume.Root; original_receipt=$resume.ReceiptPath;
            original_evidence=$resume.Evidence; original_evidence_unchanged=$false; old_setup_rerun=$false;
            installed_bootstrap_log=$resume.BootstrapLog; bootstrap_before_sha256=$resume.BootstrapHash;
            bootstrap_before_snapshot=$snapshot; bootstrap_after_sha256=$null;
            note='Original receipt and stage logs stay immutable. Installed bootstrap.log may append normally; its prior bytes are preserved.' }
        Copy-Item -LiteralPath $resume.BootstrapLog -Destination $snapshot
        if ((Get-Hash $snapshot) -cne $resume.BootstrapHash) { throw 'Pre-resume runtime log snapshot changed.' }
        Assert-NoResumeProcesses $installRoot
    } else {
        New-Item -ItemType Directory -Path (Split-Path -Parent $sentinel), $local | Out-Null
        [IO.File]::WriteAllText($sentinel, 'Isolated saved-profile preservation fixture: ' + [guid]::NewGuid().ToString('N'))
        $sentinelHash = Get-Hash $sentinel
        $receipt.sentinel_sha256 = $sentinelHash
        Add-Type -AssemblyName System.Security
        Invoke-Install '01-old-install' $oldPin.Path $oldPin.Sha256
        $oldSelection = Assert-State '01-old-install' $oldPin $null
    }
    $stored = Join-Path $installRoot 'HEX.exe'
    if ((Get-Hash $stored) -cne $oldPin.Sha256) { throw 'Old stored launcher does not match its setup.' }
    Invoke-Install '02-new-update' $newPin.Path $newPin.Sha256
    $newSelection = Assert-State '02-new-update' $newPin $oldPin '' $oldSelection
    if ((Get-Hash $stored) -cne $newPin.Sha256) { throw 'Updated stored launcher does not match its setup.' }
    Invoke-Install '03-rollback' $stored $newPin.Sha256 -Previous
    [void](Assert-State '03-rollback' $oldPin $newPin $oldSelection $newSelection)
    Invoke-Install '04-forward' $stored $newPin.Sha256 -Previous
    [void](Assert-State '04-forward' $newPin $oldPin $newSelection $oldSelection)
    $receipt.passed = $true
    Write-Output "HEX_REAL_UPDATE_INSTALLED_ROOT=$installRoot"
} catch { $receipt.failure = $_.Exception.ToString(); throw }
finally {
    $evidenceFailure = ''
    if ($null -ne $resume -and $receipt.Contains('resume')) {
        try {
            foreach ($item in $resume.Evidence) {
                if ((Get-Hash $item.path) -cne $item.sha256) { throw "Original fixture evidence changed: $($item.path)" }
            }
            $receipt.resume.original_evidence_unchanged = $true
            $receipt.resume.bootstrap_after_sha256 = Get-Hash $resume.BootstrapLog
        } catch {
            $receipt.passed = $false
            $evidenceFailure = $_.Exception.Message
            $receipt.failure += " Original evidence verification: $evidenceFailure"
        }
    }
    $receipt.checks = @($checks.ToArray())
    $receipt.processes = @($processes.ToArray())
    $receiptPath = Get-PhysicalPath (Join-Path $TestRoot 'receipt.json')
    [IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    Write-Output "HEX_REAL_UPDATE_RECEIPT=$receiptPath"
    if ($evidenceFailure) { throw $evidenceFailure }
}
