param(
    [Parameter(Mandatory)][string]$PackageDir,
    [string]$OutputDir = ''
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$PackageDir = [IO.Path]::GetFullPath($PackageDir)
if (-not $OutputDir) { $OutputDir = Join-Path $repoRoot ('exports\hex-installer-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
if ($OutputDir.Equals($PackageDir, [StringComparison]::OrdinalIgnoreCase) -or $OutputDir.StartsWith($PackageDir.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputDir must be outside PackageDir; authenticated source packages are never modified.'
}
if (Test-Path -LiteralPath $OutputDir) { throw 'A fresh output directory is required; existing artifacts are preserved.' }

function Assert-NoLink([string]$Path) {
    $itemPath = [IO.Path]::GetFullPath($Path)
    while ($itemPath) {
        if ((Test-Path -LiteralPath $itemPath) -and ((Get-Item -LiteralPath $itemPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Linked build paths are not supported: $itemPath"
        }
        $parentPath = Split-Path -Parent $itemPath
        if ($parentPath -eq $itemPath) { break }
        $itemPath = $parentPath
    }
}
Assert-NoLink $PackageDir
Assert-NoLink $OutputDir
if (-not (Test-Path -LiteralPath $PackageDir -PathType Container)) { throw 'PackageDir must be an existing complete portable Windows directory.' }
$manifest = Join-Path $PackageDir 'SHA256SUMS.txt'
if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { throw 'Package checksum manifest is missing.' }
if ((Get-Item -LiteralPath $manifest).Length -gt 1MB) { throw 'Package manifest exceeds its bound.' }
$listed = @{}
foreach ($line in [IO.File]::ReadAllLines($manifest)) {
    if (-not $line.Trim()) { continue }
    if ($line -notmatch '^([a-fA-F0-9]{64})  ([a-zA-Z0-9_.-]+)$') { throw 'Portable package manifest must contain safe root-level files.' }
    $hash = $Matches[1]; $name = $Matches[2]
    if ($name -eq 'SHA256SUMS.txt' -or $name -in @('.', '..') -or $name.EndsWith('.') -or $listed.ContainsKey($name)) { throw "Invalid duplicate/reserved manifest entry: $name" }
    $path = Join-Path $PackageDir $name
    Assert-NoLink $path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $hash) { throw "Package integrity mismatch: $name" }
    $listed[$name] = $true
}
foreach ($required in @('hex.exe','hex.pck','BUILD-STATE.json','SOURCE-IDENTITY.json','PLAY-HEX.cmd')) {
    if (-not $listed.ContainsKey($required)) { throw "Package does not authenticate $required" }
}
foreach ($entry in Get-ChildItem -LiteralPath $PackageDir -Force) {
    if ($entry.PSIsContainer -or ($entry.Name -ne 'SHA256SUMS.txt' -and -not $listed.ContainsKey($entry.Name))) { throw "Unlisted package content: $($entry.Name)" }
}
$identity = Get-Content -LiteralPath (Join-Path $PackageDir 'SOURCE-IDENTITY.json') -Raw | ConvertFrom-Json
$build = Get-Content -LiteralPath (Join-Path $PackageDir 'BUILD-STATE.json') -Raw | ConvertFrom-Json
if ($identity.build_id -notmatch '^p[0-9]+-[a-f0-9]{12}$' -or $build.state.runtime.build_identity.build_id -ne $identity.build_id) { throw 'Package build identities disagree or are malformed.' }
if ($build.pack_sha256 -ne (Get-FileHash -LiteralPath (Join-Path $PackageDir 'hex.pck') -Algorithm SHA256).Hash.ToLowerInvariant()) { throw 'PCK does not match BUILD-STATE.' }
$command = [IO.File]::ReadAllText((Join-Path $PackageDir 'PLAY-HEX.cmd'))
$launchLine = @($command -split '\r?\n' | Where-Object { $_ -match '^start "H\.E\.X\." "%~dp0hex\.exe" -- (.*?)\s*%\*$' })
if ($launchLine.Count -ne 1 -or $launchLine[0] -notmatch '^start "H\.E\.X\." "%~dp0hex\.exe" -- (.*?)\s*%\*$') { throw 'Portable launcher defaults could not be authenticated.' }
$defaultArguments = @($Matches[1].Split(' ', [StringSplitOptions]::RemoveEmptyEntries))
foreach ($argument in $defaultArguments) { if ($argument -notin @('--fullbody-art','--pixel-cast','--pixel-body-pilot')) { throw "Unsupported portable presentation flag: $argument" } }
$compiler = @((Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'), (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe')) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $compiler) { throw 'The Windows .NET Framework C# compiler is required. No dependency was installed.' }

New-Item -ItemType Directory -Path $OutputDir | Out-Null
[IO.File]::WriteAllText((Join-Path $OutputDir '.gdignore'), "# Windows delivery artifacts are not game assets.`n", [Text.UTF8Encoding]::new($false))
$payload = Join-Path $OutputDir 'payload.zip'
Compress-Archive -LiteralPath @(Get-ChildItem -LiteralPath $PackageDir -File -Force | ForEach-Object FullName) -DestinationPath $payload -CompressionLevel Optimal
$payloadHash = (Get-FileHash -LiteralPath $payload -Algorithm SHA256).Hash.ToLowerInvariant()
$manifestHash = (Get-FileHash -LiteralPath $manifest -Algorithm SHA256).Hash.ToLowerInvariant()
$version = $identity.build_id + '-' + $payloadHash.Substring(0, 10)
$source = Get-Content -LiteralPath (Join-Path $repoRoot 'packaging\hex-windows\HexBootstrap.cs') -Raw
$source = $source.Replace('__PAYLOAD_VERSION__', $version).Replace('__PAYLOAD_SHA256__', $payloadHash).Replace('__MANIFEST_SHA256__', $manifestHash)
$argumentSource = ($defaultArguments | ForEach-Object { '"' + $_ + '"' }) -join ', '
$source = $source.Replace('__DEFAULT_GAME_ARGUMENTS__', $argumentSource).Replace('new[] {  }', 'new string[0]')
$generated = Join-Path $OutputDir 'HexBootstrap.generated.cs'
[IO.File]::WriteAllText($generated, $source, [Text.UTF8Encoding]::new($false))
$installer = Join-Path $OutputDir ('HEX-Setup-' + $identity.build_id + '.exe')
$references = @('System.dll','System.Core.dll','System.Drawing.dll','System.Windows.Forms.dll','System.IO.Compression.dll','System.IO.Compression.FileSystem.dll','System.Security.dll')
$compilerArguments = @('/nologo','/target:winexe','/platform:x64','/optimize+', "/out:$installer", "/win32manifest:$(Join-Path $repoRoot 'packaging\hex-windows\app.manifest')", "/resource:$payload,Hex.Payload.zip") + @($references | ForEach-Object { "/reference:$_" }) + @($generated)
& $compiler $compilerArguments
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $installer)) { throw 'H.E.X. installer compilation failed; build directory retained.' }
$setupHash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $OutputDir 'SHA256SUMS.txt'), "$setupHash  $([IO.Path]::GetFileName($installer))`r`n", [Text.UTF8Encoding]::new($false))
$receipt = [ordered]@{ schema_version=1; status='built_not_gameplay_certified'; build_id=$identity.build_id; package_dir=$PackageDir; installer=$installer; installer_sha256=$setupHash; manifest_sha256=$manifestHash; embedded_payload_sha256=$payloadHash; presentation_arguments=$defaultArguments; signing=(Get-AuthenticodeSignature -LiteralPath $installer).Status.ToString(); remote_update_feed='not_configured'; source_files_unchanged=$true }
[IO.File]::WriteAllText((Join-Path $OutputDir 'build-receipt.json'), ($receipt | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
Write-Output "HEX_INSTALLER=$installer"
Write-Output "HEX_INSTALLER_SHA256=$setupHash"
