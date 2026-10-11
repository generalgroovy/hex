param([string]$Installer = '', [string]$TestRoot = '')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $TestRoot) { $TestRoot = Join-Path $repoRoot ('exports\hex-installer-tests\run-' + [guid]::NewGuid().ToString('N')) }
$TestRoot = [IO.Path]::GetFullPath($TestRoot)
$testParent = [IO.Path]::GetFullPath((Join-Path $repoRoot 'exports\hex-installer-tests')).TrimEnd('\') + '\'
if (-not $TestRoot.StartsWith($testParent, [StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $TestRoot)) { throw 'Tests require a fresh owned child of exports/hex-installer-tests.' }
New-Item -ItemType Directory -Path $TestRoot | Out-Null
$checks = New-Object 'System.Collections.Generic.List[string]'
$passed = $false
$failure = ''

function Assert-Test([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "FAILED: $Name" }
    $checks.Add($Name)
    Write-Output "PASS: $Name"
}
function Quote-Argument([AllowEmptyString()][string]$Value) {
    $builder = New-Object Text.StringBuilder
    [void]$builder.Append('"'); $slashes = 0
    foreach ($c in $Value.ToCharArray()) {
        if ($c -eq '\') { $slashes++; continue }
        if ($c -eq '"') { [void]$builder.Append('\', 2 * $slashes + 1) }
        else { [void]$builder.Append('\', $slashes) }
        $slashes = 0; [void]$builder.Append($c)
    }
    [void]$builder.Append('\', 2 * $slashes); [void]$builder.Append('"')
    $builder.ToString()
}
function Invoke-Setup([string]$Path, [string[]]$Arguments, [int]$Expected = 0, [int]$StubDelay = 0) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $Path
    $info.Arguments = (($Arguments | ForEach-Object { Quote-Argument $_ }) -join ' ')
    $info.WorkingDirectory = $TestRoot
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true
    $info.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    $info.EnvironmentVariables['APPDATA'] = Join-Path $TestRoot 'isolated-roaming'
    $info.EnvironmentVariables['LOCALAPPDATA'] = Join-Path $TestRoot 'isolated-local'
    $info.EnvironmentVariables['HEX_STUB_OUTPUT'] = Join-Path $TestRoot 'argv.txt'
    $info.EnvironmentVariables['HEX_STUB_DELAY'] = $StubDelay.ToString()
    $process = [Diagnostics.Process]::Start($info)
    try {
        $out = $process.StandardOutput.ReadToEndAsync(); $err = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(45000)) { $process.Kill(); throw 'Owned setup test exceeded 45 seconds.' }
        $stdout = $out.Result; $stderr = $err.Result
        [IO.File]::AppendAllText((Join-Path $TestRoot 'process.log'), $info.Arguments + "`r`n" + $stdout + $stderr)
        if ($process.ExitCode -ne $Expected) { throw "Setup exit $($process.ExitCode), expected $Expected. $stderr" }
        return $stdout
    } finally { $process.Dispose() }
}
function Get-State([string]$Root) {
    Add-Type -AssemblyName System.Security
    $bytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes((Join-Path $Root 'selection.dat')), [Text.Encoding]::UTF8.GetBytes('HEX-SELECTION-V1'), [Security.Cryptography.DataProtectionScope]::CurrentUser)
    $lines = [Text.Encoding]::UTF8.GetString($bytes).Split("`n")
    $current = $lines[1].Split('|')
    $previous = $lines[2].Split('|')
    [pscustomobject]@{ Version=$current[0]; Hash=$current[1]; Directory=(Join-Path (Join-Path $Root 'versions') $current[0]); Previous=$previous[0] }
}
function New-Package([string]$Name, [string]$BuildId) {
    $directory = Join-Path $TestRoot $Name
    New-Item -ItemType Directory -Path $directory | Out-Null
    Copy-Item -LiteralPath (Join-Path $TestRoot 'stub.exe') -Destination (Join-Path $directory 'hex.exe')
    [IO.File]::WriteAllText((Join-Path $directory 'hex.pck'), "Fixture $Name, not a Godot pack.")
    $pckHash = (Get-FileHash -LiteralPath (Join-Path $directory 'hex.pck') -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText((Join-Path $directory 'SOURCE-IDENTITY.json'), (@{build_id=$BuildId} | ConvertTo-Json))
    [IO.File]::WriteAllText((Join-Path $directory 'BUILD-STATE.json'), (@{pack_sha256=$pckHash; state=@{runtime=@{build_identity=@{build_id=$BuildId}}}} | ConvertTo-Json -Depth 8))
    [IO.File]::WriteAllText((Join-Path $directory 'PLAY-HEX.cmd'), "@echo off`r`nstart `"H.E.X.`" `"%~dp0hex.exe`" -- --fullbody-art --pixel-cast %*`r`n")
    $lines = @(Get-ChildItem -LiteralPath $directory -File | Sort-Object Name | ForEach-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $_.Name })
    [IO.File]::WriteAllLines((Join-Path $directory 'SHA256SUMS.txt'), $lines)
    return $directory
}
try {
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    & $compiler /nologo /target:winexe /platform:x64 "/out:$(Join-Path $TestRoot 'stub.exe')" (Join-Path $repoRoot 'packaging\hex-windows-tests\StubGame.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Native stub compilation failed.' }
    $packageA = New-Package 'package-a' 'p0-aaaaaaaaaaaa'
    $packageB = New-Package 'package-b' 'p0-bbbbbbbbbbbb'
    $nestedOutput = Join-Path $packageA 'installer'
    $rejected = $false
    try { & (Join-Path $PSScriptRoot 'build-hex-installer.ps1') -PackageDir $packageA -OutputDir $nestedOutput | Out-Null } catch { $rejected = $true }
    Assert-Test ($rejected -and -not (Test-Path -LiteralPath $nestedOutput)) 'builder refuses output nested inside authenticated source package'
    & (Join-Path $PSScriptRoot 'build-hex-installer.ps1') -PackageDir $packageA -OutputDir (Join-Path $TestRoot 'build-a')
    & (Join-Path $PSScriptRoot 'build-hex-installer.ps1') -PackageDir $packageB -OutputDir (Join-Path $TestRoot 'build-b')
    $setupA = Join-Path $TestRoot 'build-a\HEX-Setup-p0-aaaaaaaaaaaa.exe'
    $setupB = Join-Path $TestRoot 'build-b\HEX-Setup-p0-bbbbbbbbbbbb.exe'
    $root = Join-Path $TestRoot 'install with spaces'
    $options = @('--quiet','--no-shortcuts',"--install-root=$root")
    $probe = Invoke-Setup $setupA ($options + '--print-install-root')
    Assert-Test ($probe.Trim() -eq "HEX_INSTALL_ROOT=$root" -and -not (Test-Path -LiteralPath $root)) 'read-only explicit root does not install'
    Invoke-Setup $setupA ($options + '--install-only') | Out-Null
    $a = Get-State $root
    $stored = Join-Path $root 'HEX.exe'
    Assert-Test ((Test-Path -LiteralPath $stored) -and (Test-Path -LiteralPath (Join-Path $a.Directory 'hex.pck'))) 'clean offline install'
    $probe = Invoke-Setup $stored @('--quiet','--print-install-root')
    Assert-Test ($probe.Trim() -eq "HEX_INSTALL_ROOT=$root") 'installed launcher infers isolated root'
    Invoke-Setup $stored @('--quiet','--no-shortcuts','--install-only') | Out-Null
    Assert-Test ((Get-State $root).Version -eq $a.Version) 'healthy installed launcher reuses selected build'
    $argsProbe = @('two words','quote"inside','C:\ending path\','one\"two','')
    Invoke-Setup $stored ($options + @('--') + $argsProbe) | Out-Null
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    while (-not (Test-Path -LiteralPath (Join-Path $TestRoot 'argv.txt')) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 50 }
    $actual = @([IO.File]::ReadAllLines((Join-Path $TestRoot 'argv.txt')) | ForEach-Object { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_)) })
    Assert-Test (($actual | ConvertTo-Json -Compress) -ceq (@('--','--fullbody-art','--pixel-cast') + $argsProbe | ConvertTo-Json -Compress)) 'tested presentation flags and exact native argv'
    Start-Sleep -Milliseconds 150
    [IO.File]::WriteAllText((Join-Path $a.Directory 'hex.pck'), 'corrupted')
    Invoke-Setup $stored ($options + '--install-only') | Out-Null
    $repair = Get-State $root
    Assert-Test ($repair.Version -ne $a.Version -and (Test-Path -LiteralPath $a.Directory)) 'corrupt payload repairs without overwriting prior files'
    [IO.File]::WriteAllText((Join-Path $repair.Directory 'SHA256SUMS.txt'), '')
    Invoke-Setup $stored ($options + '--install-only') | Out-Null
    $healthyA = Get-State $root
    Assert-Test ($healthyA.Version -ne $repair.Version) 'empty editable manifest cannot bypass repair'
    [IO.File]::WriteAllText((Join-Path $healthyA.Directory 'unexpected.dll'), 'not authenticated')
    Invoke-Setup $stored ($options + '--install-only') | Out-Null
    $cleanA = Get-State $root
    Assert-Test ($cleanA.Version -ne $healthyA.Version -and -not (Test-Path -LiteralPath (Join-Path $cleanA.Directory 'unexpected.dll'))) 'unlisted adjacent DLL triggers immutable repair'
    $healthyA = $cleanA
    $originalLauncherHash = (Get-FileHash -LiteralPath $stored -Algorithm SHA256).Hash
    # Allow selection reads but deny the final replacement to exercise rollback
    # after staging and launcher replacement, not only an early validation failure.
    $selectionLock = [IO.File]::Open((Join-Path $root 'selection.dat'), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try { Invoke-Setup $setupB ($options + '--install-only') 1 | Out-Null }
    finally { $selectionLock.Dispose() }
    Assert-Test ((Get-State $root).Version -eq $healthyA.Version -and (Get-FileHash -LiteralPath $stored -Algorithm SHA256).Hash -eq $originalLauncherHash) 'failed selection commit restores launcher and keeps prior selected build'
    Invoke-Setup $setupB ($options + '--install-only') | Out-Null
    $b = Get-State $root
    Assert-Test ($b.Version.StartsWith('p0-bbbbbbbbbbbb-') -and $b.Previous -eq $healthyA.Version) 'distinct offline update retains previous selection'
    Invoke-Setup $stored ($options + @('--install-only','--previous')) | Out-Null
    $rolledBack = Get-State $root
    Assert-Test ($rolledBack.Version -eq $healthyA.Version -and $rolledBack.Previous -eq $b.Version) 'verified rollback swaps selections without running an old installer'
    Invoke-Setup $stored ($options + '--install-only') | Out-Null
    Assert-Test ((Get-State $root).Version -eq $healthyA.Version) 'normal launch honors rollback instead of reselecting embedded build'
    [IO.File]::WriteAllText((Join-Path $TestRoot 'argv.txt.executable'), 'waiting for rollback launch')
    Invoke-Setup $stored ($options + '--') | Out-Null
    $expectedGamePath = Join-Path $healthyA.Directory 'hex.exe'
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        Start-Sleep -Milliseconds 50
        $launchedPath = [IO.File]::ReadAllText((Join-Path $TestRoot 'argv.txt.executable'))
    } while ($launchedPath -ne $expectedGamePath -and [DateTime]::UtcNow -lt $deadline)
    Assert-Test ($launchedPath -eq $expectedGamePath) 'actual native launch after rollback runs selected prior executable'
    # Run the delayed installed stub without inherited output pipes: the ordinary
    # launch harness drains child pipes, which can wait until that child exits.
    $runningInfo = New-Object Diagnostics.ProcessStartInfo
    $runningInfo.FileName = $expectedGamePath
    $runningInfo.UseShellExecute = $false; $runningInfo.CreateNoWindow = $true
    $runningInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $runningInfo.EnvironmentVariables['HEX_STUB_DELAY'] = '6000'
    $running = [Diagnostics.Process]::Start($runningInfo)
    try {
        Invoke-Setup $setupB ($options + '--install-only') 1 | Out-Null
        Assert-Test ((Get-State $root).Version -eq $healthyA.Version -and -not $running.HasExited) 'running installed game blocks update without killing game or changing selection'
        if (-not $running.WaitForExit(8000)) { throw 'Delayed native fixture did not exit normally.' }
    } finally { $running.Dispose() }
    [IO.File]::WriteAllText((Join-Path $b.Directory 'hex.exe'), 'tampered executable')
    Invoke-Setup $stored ($options + @('--install-only','--previous')) 1 | Out-Null
    Assert-Test ((Get-State $root).Version -eq $healthyA.Version) 'tampered previous executable rejected without selection change'
    $statePath = Join-Path $root 'selection.dat'
    $trustedState = [IO.File]::ReadAllBytes($statePath)
    [IO.File]::WriteAllBytes($statePath, [Text.Encoding]::UTF8.GetBytes('untrusted manifest'))
    Invoke-Setup $stored ($options + '--install-only') 1 | Out-Null
    [IO.File]::WriteAllBytes($statePath, $trustedState)
    Assert-Test ((Get-State $root).Version -eq $healthyA.Version) 'untrusted selection data fails closed'
    $unowned = Join-Path $TestRoot 'unowned documents'
    New-Item -ItemType Directory -Path $unowned | Out-Null
    [IO.File]::WriteAllText((Join-Path $unowned 'keep.txt'), 'preserve me')
    Invoke-Setup $setupA @('--quiet','--install-only','--no-shortcuts',"--install-root=$unowned") 1 | Out-Null
    Assert-Test (@(Get-ChildItem -LiteralPath $unowned -Force).Count -eq 1) 'nonempty unowned destination is untouched'
    Invoke-Setup $setupA @('--quiet','--install-only','--no-shortcuts','--install-root=') 2 | Out-Null
    Assert-Test $true 'empty destination is refused'
    $junction = Join-Path $TestRoot 'linked install'
    New-Item -ItemType Junction -Path $junction -Target $unowned | Out-Null
    Invoke-Setup $setupA @('--quiet','--install-only','--no-shortcuts',"--install-root=$junction") 1 | Out-Null
    Assert-Test (@(Get-ChildItem -LiteralPath $unowned -Force).Count -eq 1) 'junction destination is refused before mutation'
    # No executable is opened based on external update manifests. Probe path validation
    # directly through the compiled implementation, without invoking a game engine.
    $assembly = [Reflection.Assembly]::LoadFile($setupA)
    $program = $assembly.GetType('Hex.Bootstrap.Program')
    $safe = $program.GetMethod('SafeRelativeFile', [Reflection.BindingFlags]'NonPublic,Static')
    foreach ($bad in @('../escape.exe','C:\escape.exe','CON','sub\..\escape','a:stream','trailing.','double//slash','LPT1.txt')) {
        $rejected = $false
        try { $safe.Invoke($null, @($TestRoot, $bad)) | Out-Null } catch { $rejected = $true }
        Assert-Test $rejected "unsafe archive path rejected: $bad"
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $extract = $program.GetMethod('ExtractSafely', [Reflection.BindingFlags]'NonPublic,Static')
    foreach ($case in @('traversal','duplicate')) {
        $archivePath = Join-Path $TestRoot ($case + '.zip')
        $extractRoot = Join-Path $TestRoot ($case + '-output')
        New-Item -ItemType Directory -Path $extractRoot | Out-Null
        $zip = [IO.Compression.ZipFile]::Open($archivePath, [IO.Compression.ZipArchiveMode]::Create)
        try {
            $names = if ($case -eq 'traversal') { @('../escaped.txt') } else { @('same.txt','same.txt') }
            foreach ($name in $names) { $entry = $zip.CreateEntry($name); $writer = New-Object IO.StreamWriter($entry.Open()); $writer.Write('fixture'); $writer.Dispose() }
        } finally { $zip.Dispose() }
        $rejected = $false
        try { $extract.Invoke($null, @($archivePath, $extractRoot, $null)) | Out-Null } catch { $rejected = $true }
        Assert-Test ($rejected -and -not (Test-Path -LiteralPath (Join-Path $TestRoot 'escaped.txt'))) "malformed $case archive rejected without escape"
    }
    $badPackage = New-Package 'bad-package' 'p0-cccccccccccc'
    [IO.File]::WriteAllText((Join-Path $badPackage 'hex.pck'), 'tampered before packaging')
    $rejected = $false
    try { & (Join-Path $PSScriptRoot 'build-hex-installer.ps1') -PackageDir $badPackage -OutputDir (Join-Path $TestRoot 'bad-build') | Out-Null } catch { $rejected = $true }
    Assert-Test ($rejected -and -not (Test-Path -LiteralPath (Join-Path $TestRoot 'bad-build'))) 'builder refuses corrupted portable payload before creating output'
    Invoke-Setup $stored ($options + @('--update=arbitrary.exe','--install-only')) 2 | Out-Null
    Assert-Test $true 'arbitrary update executable option is not accepted'
    if ($Installer) {
        $realRoot = Join-Path $TestRoot 'real payload install'
        Invoke-Setup ([IO.Path]::GetFullPath($Installer)) @('--quiet','--install-only','--no-shortcuts',"--install-root=$realRoot") | Out-Null
        $real = Get-State $realRoot
        $verify = $program.GetMethod('VerifyInstall', [Reflection.BindingFlags]'NonPublic,Static', $null, [type[]]@([string],[string]), $null)
        Assert-Test ([bool]$verify.Invoke($null, @([string]$real.Directory, [string]$real.Hash))) 'real installer payload files verify without starting Godot'
    }
    $passed = $true
} catch { $failure = $_.Exception.ToString(); throw }
finally {
    $receipt = [ordered]@{ schema_version=1; passed=$passed; checks=@($checks.ToArray()); failure=$failure; test_root=$TestRoot; real_installer=$Installer; godot_run=$false; user_profile_install=$false; shortcuts_created=$false; remote_updates_tested=$false }
    [IO.File]::WriteAllText((Join-Path $TestRoot 'receipt.json'), ($receipt | ConvertTo-Json -Depth 6))
    Write-Output "HEX_INSTALLER_TEST_RECEIPT=$(Join-Path $TestRoot 'receipt.json')"
}
