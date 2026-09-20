param(
    [string]$Installer = '',
    [string]$BaselineInstaller = '',
    [switch]$KeepArtifacts,
    [ValidateRange(10, 120)][int]$TimeoutSeconds = 45,
    [int]$ExpectedProtocol = 47,
    [int]$ExpectedChampions = 30
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$workflowLease = Enter-FluxEngineRun 'test-windows-bootstrap'
try {
$repoRoot = Get-FluxRepoRoot
if (-not $Installer) { $Installer = Join-Path $repoRoot 'exports\release\FLUX.exe' }
$Installer = [IO.Path]::GetFullPath($Installer)
if (-not (Test-Path -LiteralPath $Installer -PathType Leaf)) { throw "Missing installer: $Installer" }
if ($BaselineInstaller) {
    $BaselineInstaller = [IO.Path]::GetFullPath($BaselineInstaller)
    if (-not (Test-Path -LiteralPath $BaselineInstaller -PathType Leaf)) { throw "Missing baseline: $BaselineInstaller" }
    if ((Get-FluxFileSha256 $Installer) -eq (Get-FluxFileSha256 $BaselineInstaller)) { throw 'Update acceptance requires distinct hardened installers; never supply the old pre-quiet launcher.' }
}
foreach ($relative in @('packaging\PLAY-FLUX.cmd', 'packaging\README-FIRST.txt', 'packaging\windows-bootstrap\FluxBootstrap.cs')) {
    if ([IO.File]::ReadAllBytes((Join-Path $repoRoot $relative)) | Where-Object { $_ -gt 127 } | Select-Object -First 1) { throw "Windows launcher text must remain ASCII-only: $relative" }
}

# Every mutation is confined to a unique owned child. Failures always retain evidence.
$testParent = [IO.Path]::GetFullPath((Join-Path $repoRoot '.godot\bootstrap-test'))
$runId = [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $testParent ("run $runId")
$installRoot = Join-Path $testRoot 'install with spaces'
$logsRoot = Join-Path $testRoot 'logs'
$receiptPath = Join-Path $testParent ("receipt-$runId.json")
$stages = New-Object 'System.Collections.Generic.List[object]'
$succeeded = $false
$failure = ''
$probeArguments = @('', 'two words', 'quote"inside', 'C:\ending path\', 'one\"two', '--literal=value')

function Assert-ChildPath([string]$Path, [string]$Parent) {
    $resolved = [IO.Path]::GetFullPath($Path)
    $prefix = [IO.Path]::GetFullPath($Parent).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe test path: $Path" }
    return $resolved
}

# Start-Process joins arrays without preserving Windows argv boundaries.
function ConvertTo-WindowsArgument([AllowEmptyString()][string]$Value) {
    $builder = New-Object Text.StringBuilder
    [void]$builder.Append('"')
    $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') { $slashes++; continue }
        if ($character -eq '"') { [void]$builder.Append('\', (2 * $slashes + 1)) }
        else { [void]$builder.Append('\', $slashes) }
        $slashes = 0
        [void]$builder.Append($character)
    }
    [void]$builder.Append('\', (2 * $slashes))
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Invoke-TestProcess([string]$Name, [string]$Path, [string[]]$Arguments, [string]$WorkingDirectory = $testRoot) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $Path
    $info.Arguments = (($Arguments | ForEach-Object { ConvertTo-WindowsArgument $_ }) -join ' ')
    $info.WorkingDirectory = $WorkingDirectory
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.EnvironmentVariables['APPDATA'] = Join-Path $testRoot 'isolated roaming'
    $info.EnvironmentVariables['LOCALAPPDATA'] = Join-Path $testRoot 'isolated local'
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    $outputPath = Join-Path $logsRoot ($Name + '.stdout.log')
    $errorPath = Join-Path $logsRoot ($Name + '.stderr.log')
    [IO.File]::WriteAllText((Join-Path $logsRoot ($Name + '.command.txt')), $info.FileName + [Environment]::NewLine + $info.Arguments)
    $stdout = $null
    $stderr = $null
    $processStarted = $false
    try {
        $process = Start-FluxOwnedProcess -Process $process
        $processStarted = $true
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill()
            [void]$process.WaitForExit(5000)
            throw "$Name exceeded $TimeoutSeconds seconds; only its owned PID was stopped."
        }
        if (-not $stdout.Wait($TimeoutSeconds * 1000) -or -not $stderr.Wait($TimeoutSeconds * 1000)) { throw "$Name child output did not close before the deadline." }
        [IO.File]::WriteAllText($outputPath, $stdout.Result)
        [IO.File]::WriteAllText($errorPath, $stderr.Result)
        $result = [pscustomobject]@{ ExitCode = $process.ExitCode; Output = $stdout.Result; Error = $stderr.Result }
        $stages.Add([ordered]@{ name = $Name; exit_code = $result.ExitCode; stdout = $outputPath; stderr = $errorPath })
        return $result
    } catch {
        if ($null -ne $stdout -and $stdout.Wait(1000)) { [IO.File]::WriteAllText($outputPath, $stdout.Result) }
        $capturedError = if ($null -ne $stderr -and $stderr.Wait(1000)) { $stderr.Result } else { '' }
        [IO.File]::WriteAllText($errorPath, $capturedError + [Environment]::NewLine + $_.Exception.ToString())
        if ($_.Exception.ToString() -match 'Application Control|blocked by group policy|Win32Exception.*(1260|577)') { throw 'Windows execution policy blocked this build. Acceptance is BLOCKED; no bypass was attempted.' }
        throw
    } finally { try { if ($processStarted -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() } } finally { $process.Dispose() } }
}

function Assert-Exit([object]$Result, [string]$Name, [int]$Expected = 0) {
    if ($Result.ExitCode -ne $Expected) { throw "$Name exited $($Result.ExitCode), expected $Expected. $($Result.Error)" }
}

function Read-SelectedPayload([string]$Root, [switch]$CheckIdentity) {
    if ([IO.File]::ReadAllText((Join-Path $Root '.flux-install-root')).Trim() -cne 'FLUX-INSTALL-ROOT-V1') { throw 'Incorrect install-root ownership marker.' }
    $version = [IO.File]::ReadAllLines((Join-Path $Root 'current.txt'))[0].Trim()
    if (-not $version -or $version -match '[/\\]' -or $version -eq '.' -or $version -eq '..') { throw 'Invalid version pointer.' }
    $directory = Assert-ChildPath (Join-Path (Join-Path $Root 'versions') $version) (Join-Path $Root 'versions')
    foreach ($required in @('flux2.exe', 'flux2.pck', 'BUILD-STATE.json', 'SHA256SUMS.txt')) {
        if (-not (Test-Path -LiteralPath (Join-Path $directory $required) -PathType Leaf)) { throw "Missing installed $required" }
    }
    $seen = @{}
    foreach ($line in [IO.File]::ReadAllLines((Join-Path $directory 'SHA256SUMS.txt'))) {
        if (-not $line.Trim()) { continue }
        if ($line -notmatch '^([a-fA-F0-9]{64})  (.+)$') { throw 'Invalid installed checksum record.' }
        $digest = $Matches[1]
        $relative = $Matches[2]
        if ($seen.ContainsKey($relative)) { throw 'Duplicate installed checksum record.' }
        $seen[$relative] = $true
        $target = Assert-ChildPath (Join-Path $directory $relative) $directory
        if ((Get-FluxFileSha256 $target) -ne $digest) { throw "Installed checksum mismatch: $relative" }
    }
    foreach ($required in @('flux2.exe', 'flux2.pck', 'BUILD-STATE.json')) { if (-not $seen.ContainsKey($required)) { throw "Manifest does not authenticate $required" } }
    $build = Get-Content -LiteralPath (Join-Path $directory 'BUILD-STATE.json') -Raw | ConvertFrom-Json
    if ($build.pack_sha256 -ne (Get-FluxFileSha256 (Join-Path $directory 'flux2.pck'))) { throw 'Build identity disagrees with installed PCK.' }
    if ($CheckIdentity -and ($build.state.runtime.protocol -ne $ExpectedProtocol -or $build.state.content.champions_playable -ne $ExpectedChampions)) { throw 'Installed protocol / roster identity does not match acceptance.' }
    return [pscustomobject]@{ Version = $version; Directory = $directory; Build = $build }
}

function Read-MarkerJson([string]$Text, [string]$Marker) {
    $line = @($Text -split '\r?\n' | Where-Object { $_.StartsWith($Marker) })
    if ($line.Count -ne 1) { throw "Expected one $Marker result; got $($line.Count)." }
    return ($line[0].Substring($Marker.Length) | ConvertFrom-Json)
}

try {
    [void](Assert-ChildPath $testRoot $testParent)
    New-Item -ItemType Directory -Path $logsRoot, (Join-Path $testRoot 'isolated roaming'), (Join-Path $testRoot 'isolated local') -Force | Out-Null
    Write-Output "ISOLATED_TEST_ROOT=$testRoot"
    $preflight = Invoke-TestProcess '00-readonly-root' $Installer @('--quiet', '--print-install-root', "--install-root=$installRoot")
    Assert-Exit $preflight 'Read-only preflight'
    if ($preflight.Output.Trim() -ne "FLUX_INSTALL_ROOT=$installRoot") { throw 'Explicit root resolution disagreed.' }
    if (Test-Path -LiteralPath $installRoot) { throw 'Read-only probe created an install directory.' }
    Assert-Exit (Invoke-TestProcess '01-clean-install' $Installer @('--quiet', '--install-only', '--no-shortcuts', "--install-root=$installRoot")) 'Clean install'
    $selected = Read-SelectedPayload $installRoot -CheckIdentity
    $cleanDirectory = $selected.Directory
    $storedLauncher = Join-Path $installRoot 'FLUX.exe'
    if (-not (Test-Path -LiteralPath $storedLauncher -PathType Leaf)) { throw 'Reusable FLUX.exe was not installed.' }
    if (Test-Path -LiteralPath (Join-Path $installRoot 'FLUX Launcher.exe')) { throw 'Obsolete launcher name was installed.' }
    # Test the same root resolver before permitting a no-override stored launch.
    $inference = Invoke-TestProcess '02-stored-root-inference' $storedLauncher @('--quiet', '--print-install-root')
    Assert-Exit $inference 'Stored root preflight'
    if ($inference.Output.Trim() -ne "FLUX_INSTALL_ROOT=$installRoot") { throw 'Stored launcher targets another installation; stopped before mutation.' }
    Assert-Exit (Invoke-TestProcess '03-stored-reuse' $storedLauncher @('--quiet', '--install-only', '--no-shortcuts')) 'Stored reuse'
    if ((Read-SelectedPayload $installRoot -CheckIdentity).Directory -ne $cleanDirectory) { throw 'Healthy stored launch selected another directory.' }

    # Corrupt only the isolated test PCK, then prove immutable automatic repair.
    $stream = [IO.File]::Open((Join-Path $selected.Directory 'flux2.pck'), [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try { $firstByte = $stream.ReadByte(); $stream.Position = 0; $stream.WriteByte([byte]($firstByte -bxor 255)) } finally { $stream.Dispose() }
    Assert-Exit (Invoke-TestProcess '04-corrupt-pck-repair' $storedLauncher @('--quiet', '--install-only', '--no-shortcuts')) 'Corrupted PCK repair'
    $repaired = Read-SelectedPayload $installRoot -CheckIdentity
    if ($repaired.Directory -eq $cleanDirectory -or -not (Test-Path -LiteralPath $cleanDirectory)) { throw 'Repair overwrote or removed prior payload.' }
    [IO.File]::WriteAllText((Join-Path $repaired.Directory 'SHA256SUMS.txt'), '')
    Assert-Exit (Invoke-TestProcess '05-truncated-manifest-repair' $storedLauncher @('--quiet', '--install-only', '--no-shortcuts', '--repair')) 'Truncated manifest repair'
    $selected = Read-SelectedPayload $installRoot -CheckIdentity
    if ($selected.Directory -eq $repaired.Directory -or -not (Test-Path -LiteralPath $repaired.Directory)) { throw 'Manifest repair failed immutable selection.' }
    Assert-Exit (Invoke-TestProcess '06-repaired-stored-reuse' $storedLauncher @('--quiet', '--install-only', '--no-shortcuts')) 'Repaired stored reuse'
    if ((Read-SelectedPayload $installRoot -CheckIdentity).Directory -ne $selected.Directory) { throw 'Stored launcher reverted repaired pointer.' }
    Assert-Exit (Invoke-TestProcess '07-empty-root-refusal' $Installer @('--quiet', '--install-only', '--no-shortcuts', '--install-root=')) 'Empty root refusal' 2
    $unownedRoot = Join-Path $testRoot 'unowned documents'
    New-Item -ItemType Directory -Path $unownedRoot | Out-Null
    $sentinel = Join-Path $unownedRoot 'preserve.txt'
    [IO.File]::WriteAllText($sentinel, 'Unrelated user data must survive unchanged.')
    $sentinelHash = Get-FluxFileSha256 $sentinel
    $refused = Invoke-TestProcess '08-unowned-root-refusal' $Installer @('--quiet', '--install-only', '--no-shortcuts', "--install-root=$unownedRoot")
    if ($refused.ExitCode -eq 0) { throw 'Installer accepted an unowned nonempty directory.' }
    if ((Get-FluxFileSha256 $sentinel) -ne $sentinelHash -or (Test-Path -LiteralPath (Join-Path $unownedRoot '.flux-install-root')) -or (Test-Path -LiteralPath (Join-Path $unownedRoot 'versions'))) { throw 'Rejected root was mutated.' }
    if ($BaselineInstaller) {
        $updateRoot = Join-Path $testRoot 'update fixture with spaces'
        Assert-Exit (Invoke-TestProcess '09-baseline-preflight' $BaselineInstaller @('--quiet', '--print-install-root', "--install-root=$updateRoot")) 'Hardened baseline preflight'
        Assert-Exit (Invoke-TestProcess '10-baseline-install' $BaselineInstaller @('--quiet', '--install-only', '--no-shortcuts', "--install-root=$updateRoot")) 'Baseline install'
        $baseline = Read-SelectedPayload $updateRoot
        Assert-Exit (Invoke-TestProcess '11-baseline-update' $Installer @('--quiet', '--install-only', '--no-shortcuts', "--install-root=$updateRoot")) 'Baseline update'
        $updated = Read-SelectedPayload $updateRoot -CheckIdentity
        if ($baseline.Version -eq $updated.Version -or -not (Test-Path -LiteralPath $baseline.Directory)) { throw 'Update did not retain a distinct recoverable previous version.' }
    }

    $game = Join-Path $selected.Directory 'flux2.exe'
    $probeScript = Join-Path $repoRoot 'packaging\windows-bootstrap-tests\runtime_probe.gd'
    # --script is tools-only and ignored by release templates. Use the pinned editor
    # against the installed PCK for this no-write probe, never the release EXE.
    $editor = Get-FluxGodot
    $probe = Invoke-TestProcess '12-userdata-argv-probe' $editor (@('--headless', '--path', $selected.Directory, '--main-pack', (Join-Path $selected.Directory 'flux2.pck'), '--log-file', (Join-Path $logsRoot 'userdata-godot.log'), '--script', $probeScript, '--') + $probeArguments) $selected.Directory
    Assert-Exit $probe 'No-write userdata / argv probe'
    $probeData = Read-MarkerJson $probe.Output 'FLUX_BOOTSTRAP_PROBE='
    [void](Assert-ChildPath $probeData.user_data_dir $testRoot)
    if (($probeData.arguments | ConvertTo-Json -Compress) -cne ($probeArguments | ConvertTo-Json -Compress)) { throw 'Harness Windows argv roundtrip failed.' }
    # Exact Windows parsing is an independent contract test, not a claim that
    # release Godot supports a script-override argument it deliberately ignores.
    & (Join-Path $repoRoot 'packaging\windows-bootstrap-tests\test-argv.ps1') -Installer $Installer
    $stages.Add([ordered]@{ name = '13-native-windows-argv-contract'; exit_code = 0 })
    $runtime = Invoke-TestProcess '14-installed-runtime-state' $editor @('--headless', '--path', $selected.Directory, '--main-pack', (Join-Path $selected.Directory 'flux2.pck'), '--log-file', (Join-Path $logsRoot 'runtime-state-godot.log'), '--script', 'res://scripts/runtime-state.gd') $selected.Directory
    Assert-Exit $runtime 'Actual installed runtime summary'
    $runtimeState = Read-MarkerJson $runtime.Output 'FLUX_RUNTIME_STATE='
    if ($runtimeState.runtime.protocol -ne $ExpectedProtocol -or $runtimeState.content.champions_playable -ne $ExpectedChampions) { throw 'Actual PCK content failed protocol / roster acceptance.' }
    $bootLog = Join-Path $logsRoot 'actual-game-boot.log'
    $boot = Invoke-TestProcess '15-actual-launcher-game-boot' $storedLauncher @('--quiet', '--no-shortcuts', '--', '--headless', '--quit-after', '3', '--fixed-fps', '120', '--log-file', $bootLog, '--', '--tick-rate=120', '--no-lan-discovery')
    Assert-Exit $boot 'Actual installed game launch'
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $ownedGames = @(Get-Process -Name 'flux2' -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $game })
        if ($ownedGames.Count -eq 0) { break }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    if ($ownedGames.Count -gt 0) {
        foreach ($ownedGame in $ownedGames) { Stop-Process -Id $ownedGame.Id -Force }
        throw 'Actual isolated game failed to exit after its three-frame smoke test; stopped only exact-path owned processes.'
    }
    $bootText = [IO.File]::ReadAllText($bootLog)
    if ($bootText -notmatch 'FLUX2 match initialized at 120 Hz' -or $bootText -notmatch "FLUX2 bootstrap: 120 Hz, protocol $ExpectedProtocol,") { throw 'Actual game did not confirm complete 120 Hz bootstrap / current protocol.' }
    if ($bootText -match '(?m)^(SCRIPT ERROR|ERROR|WARNING):') { throw 'Actual game emitted an error or warning; inspect retained log.' }
    $isolatedPreferences = Join-Path $probeData.user_data_dir 'player_preferences_v1.json'
    if (-not (Test-Path -LiteralPath $isolatedPreferences -PathType Leaf)) { throw 'Actual release boot did not create its preferences in the probed isolated user directory.' }
    $succeeded = $true
    Write-Output "PASS: isolated clean install, inferred stored launch, actual corrupt-PCK/manifest repair, refusal safety, exact argv, protocol $ExpectedProtocol / $ExpectedChampions champions, real 120 Hz game bootstrap."
    if (-not $BaselineInstaller) { Write-Output 'NOT TESTED: distinct baseline update (supply hardened -BaselineInstaller fixture).' }
} catch { $failure = $_.Exception.ToString(); throw }
finally {
    if (Test-Path -LiteralPath $testRoot) {
        $receipt = [ordered]@{
            schema_version = 2; passed = $succeeded; installer = $Installer; installer_sha256 = Get-FluxFileSha256 $Installer
            baseline_installer = $BaselineInstaller; baseline_update_tested = @($stages | Where-Object { $_.name -eq '11-baseline-update' -and $_.exit_code -eq 0 }).Count -eq 1
            protocol = $ExpectedProtocol; playable_champions = $ExpectedChampions; test_root = $testRoot
            shortcuts_requested = $false; real_home_install_requested = $false; failure = $failure; stages = @($stages.ToArray())
        }
        [IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 12))
        Write-Output "BOOTSTRAP_RECEIPT=$receiptPath"
        if ($succeeded -and -not $KeepArtifacts) {
            $resolved = Assert-ChildPath $testRoot $testParent
            if ((Get-Item -LiteralPath $resolved).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Refusing cleanup of a linked test root.' }
            if (Get-ChildItem -LiteralPath $resolved -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint } | Select-Object -First 1) { throw 'Refusing cleanup with linked descendants.' }
            Remove-Item -LiteralPath $resolved -Recurse -Force
            Write-Output 'Removed only successful isolated test payload; receipt retained.'
        } else { Write-Output "ARTIFACTS_RETAINED=$testRoot" }
    }
}

} finally { Exit-FluxEngineRun $workflowLease }
