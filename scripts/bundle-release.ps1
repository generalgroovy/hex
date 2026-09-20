param(
    [ValidateSet('Windows', 'Linux', 'All')][string]$Target = 'All',
    [string]$ExportRoot = '',
    [string]$ReleaseRoot = ''
)
. (Join-Path $PSScriptRoot 'flux2-common.ps1')

$repoRoot = Get-FluxRepoRoot
if (-not $ExportRoot) { $ExportRoot = Join-Path $repoRoot 'exports' }
if (-not $ReleaseRoot) { $ReleaseRoot = Join-Path $ExportRoot 'release' }
$ExportRoot = [System.IO.Path]::GetFullPath($ExportRoot)
$ReleaseRoot = [System.IO.Path]::GetFullPath($ReleaseRoot)
$packagingRoot = Join-Path $repoRoot 'packaging'

function Assert-ReleaseChild([string]$Path) {
    $full = [System.IO.Path]::GetFullPath($Path)
    $prefix = $ReleaseRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to modify a path outside the release root: $full"
    }
    return $full
}

function Reset-ReleaseDirectory([string]$Path) {
    $safePath = Assert-ReleaseChild $Path
    if (Test-Path -LiteralPath $safePath) { Remove-Item -LiteralPath $safePath -Recurse -Force }
    New-Item -ItemType Directory -Path $safePath -Force | Out-Null
}

function Write-PlatformManifest([string]$Directory) {
    $manifest = Join-Path $Directory 'SHA256SUMS.txt'
    $lines = Get-ChildItem -LiteralPath $Directory -File | Where-Object { $_.FullName -ne $manifest } | Sort-Object Name | ForEach-Object {
        "$(Get-FluxFileSha256 $_.FullName)  $($_.Name)"
    }
    [System.IO.File]::WriteAllLines($manifest, [string[]]$lines, [System.Text.UTF8Encoding]::new($false))
}

function Copy-ExportFiles([string]$Source, [string]$Destination) {
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) { throw "Missing export directory: $Source" }
    $files = @(Get-ChildItem -LiteralPath $Source -File)
    if ($files.Count -eq 0) { throw "Export directory is empty: $Source" }
    Copy-Item -LiteralPath $files.FullName -Destination $Destination
}

New-Item -ItemType Directory -Path $ReleaseRoot -Force | Out-Null

if ($Target -in @('Windows', 'All')) {
    $source = Join-Path $ExportRoot 'windows'
    if (-not (Test-Path -LiteralPath (Join-Path $source 'flux2.exe') -PathType Leaf)) { throw "Windows export is missing flux2.exe at $source" }
    $bundle = Assert-ReleaseChild (Join-Path $ReleaseRoot 'FLUX2-Windows-x86_64')
    Reset-ReleaseDirectory $bundle
    Copy-ExportFiles $source $bundle
    Copy-Item -LiteralPath (Join-Path $packagingRoot 'PLAY-FLUX.cmd') -Destination $bundle
    Copy-Item -LiteralPath (Join-Path $packagingRoot 'README-FIRST.txt') -Destination $bundle
    Write-PlatformManifest $bundle
    $archive = Assert-ReleaseChild (Join-Path $ReleaseRoot 'FLUX2-Windows-x86_64.zip')
    if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
    Compress-Archive -LiteralPath (Get-ChildItem -LiteralPath $bundle | ForEach-Object FullName) -DestinationPath $archive -CompressionLevel Optimal
}

if ($Target -in @('Linux', 'All')) {
    $source = Join-Path $ExportRoot 'linux'
    if (-not (Test-Path -LiteralPath (Join-Path $source 'flux2.x86_64') -PathType Leaf)) { throw "Linux export is missing flux2.x86_64 at $source" }
    $bundle = Assert-ReleaseChild (Join-Path $ReleaseRoot 'FLUX2-Linux-x86_64')
    Reset-ReleaseDirectory $bundle
    Copy-ExportFiles $source $bundle
    Copy-Item -LiteralPath (Join-Path $packagingRoot 'play-flux.sh') -Destination $bundle
    Copy-Item -LiteralPath (Join-Path $packagingRoot 'README-FIRST.txt') -Destination $bundle
    Write-PlatformManifest $bundle
    $archive = Assert-ReleaseChild (Join-Path $ReleaseRoot 'FLUX2-Linux-x86_64.tar.gz')
    if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) { throw 'Python 3 is required to preserve Linux executable bits in a cross-platform archive.' }
    & $python.Source (Join-Path $PSScriptRoot 'create-release-tar.py') $bundle $archive
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $archive -PathType Leaf)) { throw 'Linux archive creation failed.' }
}

$rootManifest = Join-Path $ReleaseRoot 'SHA256SUMS.txt'
$rootLines = Get-ChildItem -LiteralPath $ReleaseRoot -File | Where-Object { $_.FullName -ne $rootManifest } | Sort-Object Name | ForEach-Object {
    "$(Get-FluxFileSha256 $_.FullName)  $($_.Name)"
}
[System.IO.File]::WriteAllLines($rootManifest, [string[]]$rootLines, [System.Text.UTF8Encoding]::new($false))
Write-Output "PASS: portable $Target bundle(s) written to $ReleaseRoot"
