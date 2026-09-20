param(
    [string]$Payload = '',
    [string]$Output = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')

$repoRoot = Get-FluxRepoRoot
if (-not $Payload) { $Payload = Join-Path $repoRoot 'exports\release\FLUX2-Windows-x86_64.zip' }
if (-not $Output) { $Output = Join-Path $repoRoot 'exports\release\FLUX.exe' }
$Payload = [System.IO.Path]::GetFullPath($Payload)
$Output = [System.IO.Path]::GetFullPath($Output)
if (-not (Test-Path -LiteralPath $Payload -PathType Leaf)) { throw "Missing Windows payload: $Payload" }

$compilerCandidates = @(
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
)
$compiler = $compilerCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $compiler) { throw 'The Windows .NET Framework C# compiler is required to build the one-file bootstrapper.' }

$payloadHash = Get-FluxFileSha256 $Payload
# Authenticate the installed manifest against bytes embedded in this executable;
# merely trusting an editable SHA256SUMS.txt permits empty-manifest repair bypass.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$payloadArchive = [System.IO.Compression.ZipFile]::OpenRead($Payload)
try {
    $manifestEntries = @($payloadArchive.Entries | Where-Object { $_.FullName -ceq 'SHA256SUMS.txt' })
    if ($manifestEntries.Count -ne 1) { throw 'Payload must contain exactly one root SHA256SUMS.txt.' }
    foreach ($requiredPayloadName in @('flux2.exe', 'flux2.pck', 'BUILD-STATE.json')) {
        if (@($payloadArchive.Entries | Where-Object { $_.FullName -ceq $requiredPayloadName }).Count -ne 1) {
            throw "Payload must contain exactly one $requiredPayloadName."
        }
    }
    $manifestStream = $manifestEntries[0].Open()
    $manifestHasher = [System.Security.Cryptography.SHA256]::Create()
    try {
        $manifestHash = ([System.BitConverter]::ToString($manifestHasher.ComputeHash($manifestStream))).Replace('-', '').ToLowerInvariant()
    }
    finally { $manifestStream.Dispose(); $manifestHasher.Dispose() }
}
finally { $payloadArchive.Dispose() }
$commit = (& git -C $repoRoot rev-parse --short=10 HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or -not $commit) { $commit = 'source' }
$version = "0.1.0-dev-$commit-$($payloadHash.Substring(0, 10))"

$generatedRoot = Join-Path $repoRoot '.godot\windows-bootstrap'
New-Item -ItemType Directory -Path $generatedRoot -Force | Out-Null
$source = Get-Content -LiteralPath (Join-Path $repoRoot 'packaging\windows-bootstrap\FluxBootstrap.cs') -Raw
$source = $source.Replace('__PAYLOAD_VERSION__', $version).Replace('__PAYLOAD_SHA256__', $payloadHash).Replace('__MANIFEST_SHA256__', $manifestHash)
$generatedSource = Join-Path $generatedRoot 'FluxBootstrap.generated.cs'
[System.IO.File]::WriteAllText($generatedSource, $source, [System.Text.UTF8Encoding]::new($false))
New-Item -ItemType Directory -Path (Split-Path -Parent $Output) -Force | Out-Null

$references = @(
    'System.dll',
    'System.Core.dll',
    'System.Drawing.dll',
    'System.Windows.Forms.dll',
    'System.IO.Compression.dll',
    'System.IO.Compression.FileSystem.dll'
)
$arguments = @(
    '/nologo',
    '/target:winexe',
    '/platform:x64',
    '/optimize+',
    "/out:$Output",
    "/win32manifest:$(Join-Path $repoRoot 'packaging\windows-bootstrap\app.manifest')",
    "/resource:$Payload,Flux.Payload.zip"
) + ($references | ForEach-Object { "/reference:$_" }) + @($generatedSource)

& $compiler $arguments
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $Output -PathType Leaf)) {
    throw 'Windows bootstrapper compilation failed.'
}

$releaseRoot = Split-Path -Parent $Output
$legacyOutput = Join-Path $releaseRoot 'FLUX2-Windows-Setup.exe'
if ((Test-Path -LiteralPath $legacyOutput -PathType Leaf) -and
    -not [System.IO.Path]::GetFullPath($legacyOutput).Equals($Output, [System.StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $legacyOutput -Force
}
$manifest = Join-Path $releaseRoot 'SHA256SUMS.txt'
$lines = Get-ChildItem -LiteralPath $releaseRoot -File | Where-Object { $_.FullName -ne $manifest } | Sort-Object Name | ForEach-Object {
    "$(Get-FluxFileSha256 $_.FullName)  $($_.Name)"
}
[System.IO.File]::WriteAllLines($manifest, [string[]]$lines, [System.Text.UTF8Encoding]::new($false))
Write-Output "PASS: one Windows file installs, updates, repairs, and starts FLUX: $Output ($version)"
