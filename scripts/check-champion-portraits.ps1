param([switch]$RequireImports)

# Read-only delivery audit. Runtime never hashes or decodes the full roster.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PortraitSourceName([object]$Entry) {
    $sourceProperty = $Entry.PSObject.Properties['source_file']
    if ($null -eq $sourceProperty) { return [string]$Entry.file }
    $sourceName = $sourceProperty.Value
    # Provenance may name only a versioned copy of this exact identity, never
    # a path, another champion, or a replacement outside the original folder.
    $pattern = '\A' + [Regex]::Escape([string]$Entry.id) + '-v(?:[2-9]|[1-9][0-9]+)\.png\z'
    if ($sourceName -isnot [string] -or $sourceName -cnotmatch $pattern) { throw 'Noncanonical versioned portrait source.' }
    return $sourceName
}

$portraitRepo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$portraitRoot = Join-Path $portraitRepo 'assets/portraits/champions_v1'
$sourceRoot = Join-Path $portraitRepo 'reference/art/portraits_20261008'
if (((Get-Item -LiteralPath $sourceRoot).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Portrait source root may not be a reparse point.' }
$cast = Get-Content -Raw -LiteralPath (Join-Path $portraitRepo 'content/champions/foundation_champions_v1.json') | ConvertFrom-Json
$manifest = Get-Content -Raw -LiteralPath (Join-Path $portraitRoot 'manifest.json') | ConvertFrom-Json
if ($manifest.id -cne 'hex-champion-portraits-v1' -or $manifest.schema_version -ne 1) { throw 'Unknown portrait manifest.' }
$expected = @($cast.champions.id | Sort-Object -CaseSensitive)
$actual = @($manifest.characters.id | Sort-Object -CaseSensitive)
if (($expected -join '|') -cne ($actual -join '|')) { throw 'Portrait roster must match the live catalog exactly, with no duplicates.' }
$totalBytes = 0L
foreach ($entry in $manifest.characters) {
    if ($entry.id -cnotmatch '^[a-z][a-z0-9_]*$' -or $entry.file -cne ($entry.id + '.png')) { throw 'Noncanonical portrait identity/path.' }
    if ($entry.width -ne 512 -or $entry.height -ne 512) { throw "Expected bounded 512px import: $($entry.id)" }
    if ($entry.sha256 -cnotmatch '^[a-f0-9]{64}$') { throw 'Invalid source hash.' }
    $path = Join-Path $portraitRoot $entry.file
    $source = Join-Path $sourceRoot (Get-PortraitSourceName $entry)
    foreach ($file in @($path, $source)) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing portrait: $file" }
        if (((Get-Item -LiteralPath $file).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Portrait may not traverse a reparse point.' }
        if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -cne $entry.sha256) { throw "Portrait bytes drifted: $file" }
    }
    $bytes = [IO.File]::ReadAllBytes($path)
    if ($bytes.Length -lt 24 -or $bytes.Length -gt 16MB) { throw 'Invalid PNG length.' }
    if ([BitConverter]::ToString([byte[]]$bytes[0..7]).Replace('-', '') -cne '89504E470D0A1A0A') { throw 'Invalid PNG signature.' }
    $width = ([int]$bytes[16] * 16777216) + ([int]$bytes[17] * 65536) + ([int]$bytes[18] * 256) + [int]$bytes[19]
    $height = ([int]$bytes[20] * 16777216) + ([int]$bytes[21] * 65536) + ([int]$bytes[22] * 256) + [int]$bytes[23]
    if ($width -ne $height -or $width -lt 512 -or $width -gt 2048) { throw "Invalid source dimensions: $($entry.id)" }
    if ($entry.source_width -ne $width -or $entry.source_height -ne $height) { throw "Source dimensions drifted: $($entry.id)" }
    if ($RequireImports) {
        $import = Get-Content -Raw -LiteralPath ($path + '.import')
        foreach ($rule in @('(?m)^process/size_limit=512\r?$', '(?m)^compress/mode=0\r?$', '(?m)^mipmaps/generate=false\r?$')) {
            if ($import -notmatch $rule) { throw "Unbounded/lossy portrait importer: $($entry.id)" }
        }
    }
    $totalBytes += $bytes.Length
}
$export = Get-Content -Raw -LiteralPath (Join-Path $portraitRepo 'export_presets.cfg')
if ($export -notmatch 'assets/portraits/champions_v1/\*\.json') { throw 'Portrait manifest missing from export include policy.' }
[ordered]@{
    result = 'passed'
    portraits = $actual.Count
    source_png_bytes = $totalBytes
    imported_edge = 512
    max_selected_cache_textures = 2
    max_selected_rgba_payload_bytes = 2 * 512 * 512 * 4
    imports_checked = [bool]$RequireImports
    scope = 'Roster, exact PNG identity/header dimensions, export metadata and optional importer policy; not visual or performance acceptance.'
} | ConvertTo-Json
