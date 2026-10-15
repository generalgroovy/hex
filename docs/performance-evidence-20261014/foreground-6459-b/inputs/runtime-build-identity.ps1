[CmdletBinding()]
param(
    [ValidateSet('Check', 'Generate')][string]$Mode = 'Check',
    [string]$Root = '',
    [switch]$Force,
    [switch]$Json
)

# Source-only identity generation/checking. No engine, export, import, network,
# package or delivery-pointer action is performed here. Generate must run before
# the authoritative Full/freeze; Check is read-only.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ManifestPath = 'content/runtime/runtime_build_identity_v1.json'
$EngineIdentity = '4.7.1.stable.official.a13da4feb'

function Test-FluxRuntimeIdentityInteger($Value, [long]$Minimum = 0) {
    return $null -ne $Value -and $Value -isnot [string] -and $Value -isnot [bool] -and
        $Value -is [ValueType] -and [double]::IsFinite([double]$Value) -and
        [double]$Value -ge $Minimum -and [double]$Value -eq [math]::Floor([double]$Value)
}

function Resolve-FluxRuntimeIdentityPath([string]$RepoRoot, [string]$Relative) {
    if (-not $Relative -or [IO.Path]::IsPathRooted($Relative) -or $Relative.Contains('\') -or
        $Relative.Contains(':') -or $Relative.StartsWith('/') -or $Relative -match '[\x00-\x1f<>"|?*]') {
        throw 'Expected one canonical repo-relative path using forward slashes.'
    }
    $segments = $Relative.Split('/')
    foreach ($segment in $segments) {
        if (-not $segment -or $segment -in @('.', '..') -or $segment.EndsWith('.') -or
            $segment.EndsWith(' ') -or $segment -notmatch '^[A-Za-z0-9._-]+$' -or
            $segment -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') {
            throw 'Unsafe or noncanonical runtime identity path segment.'
        }
    }
    $rootPath = [IO.Path]::GetFullPath($RepoRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) { throw 'Runtime identity root is unavailable.' }
    if (((Get-Item -LiteralPath $rootPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Runtime identity root may not be a reparse point.' }
    $resolved = [IO.Path]::GetFullPath((Join-Path $rootPath $Relative))
    if (-not $resolved.StartsWith($rootPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Runtime identity path escapes the checkout.'
    }
    $cursor = $rootPath
    foreach ($segment in $segments) {
        $cursor = Join-Path $cursor $segment
        if (Test-Path -LiteralPath $cursor) {
            if (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'Runtime identity paths may not traverse a reparse point.'
            }
        }
    }
    return $resolved
}

function Test-FluxRuntimeIdentityMember([string]$Relative, [string]$ManifestRelative = 'content/runtime/runtime_build_identity_v1.json') {
    if ($Relative -ceq $ManifestRelative) { return $false }
    return $Relative -ceq 'project.godot' -or
        $Relative -ceq 'art_batches/wellspring_style_v2/ground_style.gd' -or
        $Relative -cmatch '^(src|content|scenes|addons|assets)/' -or
        $Relative -cmatch '^art_batches/pixel_v1/(magic|map)/(manifest\.json$|export/)' -or
        $Relative -cmatch '^art_batches/wellspring_style_v2/runtime/'
}

function Get-FluxRuntimeIdentityRequiredFiles {
    return @(
        'project.godot',
        'art_batches/pixel_v1/magic/manifest.json',
        'art_batches/pixel_v1/map/manifest.json',
        'art_batches/wellspring_style_v2/ground_style.gd'
    )
}

function Get-FluxRuntimeIdentityRecords([string]$RepoRoot, [string]$ManifestRelative) {
    $rootPath = [IO.Path]::GetFullPath($RepoRoot)
    $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $requiredFiles = @(Get-FluxRuntimeIdentityRequiredFiles)
    $requiredTrees = @(
        'src', 'content', 'scenes', 'addons', 'assets',
        'art_batches/pixel_v1/magic/export',
        'art_batches/pixel_v1/map/export',
        'art_batches/wellspring_style_v2/runtime'
    )
    foreach ($relative in $requiredFiles) {
        $resolved = Resolve-FluxRuntimeIdentityPath $rootPath $relative
        if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "Required runtime identity file is missing: $relative" }
        if (-not $paths.Add($relative)) { throw "Duplicate runtime identity input: $relative" }
    }
    foreach ($relativeRoot in $requiredTrees) {
        $resolvedRoot = Resolve-FluxRuntimeIdentityPath $rootPath $relativeRoot
        if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) { throw "Required runtime identity tree is missing: $relativeRoot" }
        $pending = [Collections.Generic.Stack[string]]::new()
        $pending.Push($resolvedRoot)
        while ($pending.Count -gt 0) {
            $directory = $pending.Pop()
            foreach ($entry in Get-ChildItem -LiteralPath $directory -Force) {
                if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Runtime identity scope contains a reparse point: $($entry.FullName)" }
                if ($entry.PSIsContainer) {
                    $pending.Push($entry.FullName)
                    continue
                }
                $relative = [IO.Path]::GetRelativePath($rootPath, $entry.FullName).Replace('\', '/')
                if (Test-FluxRuntimeIdentityMember $relative $ManifestRelative) {
                    if (-not $paths.Add($relative)) { throw "Duplicate runtime identity input: $relative" }
                }
            }
        }
    }
    [string[]]$orderedPaths = @($paths | ForEach-Object { [string]$_ })
    [Array]::Sort($orderedPaths, [StringComparer]::Ordinal)
    $records = foreach ($relative in $orderedPaths) {
        if (-not (Test-FluxRuntimeIdentityMember $relative $ManifestRelative)) { throw "Runtime identity enumerator escaped its declared scope: $relative" }
        $resolved = Resolve-FluxRuntimeIdentityPath $rootPath $relative
        if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "Runtime identity input disappeared while hashing: $relative" }
        [pscustomobject][ordered]@{
            path = $relative
            bytes = (Get-Item -LiteralPath $resolved).Length
            sha256 = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
    if (@($records).Count -lt 1) { throw 'Runtime identity scope is unexpectedly empty.' }
    return @($records)
}

function Test-FluxRuntimeIdentityRecord($Record) {
    if ($null -eq $Record -or [string]$Record.path -cnotmatch '^[A-Za-z0-9._/-]+$' -or
        -not (Test-FluxRuntimeIdentityInteger $Record.bytes) -or
        [string]$Record.sha256 -cnotmatch '^[0-9a-f]{64}$') { return $false }
    foreach ($segment in ([string]$Record.path).Split('/')) {
        if (-not $segment -or $segment -in @('.', '..') -or $segment.EndsWith('.') -or
            $segment.EndsWith(' ') -or $segment -notmatch '^[A-Za-z0-9._-]+$' -or
            $segment -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') { return $false }
    }
    return $true
}

function Get-FluxRuntimeIdentityCanonicalText($Records, [int]$ProtocolVersion, [int]$SnapshotSchema, [string]$EngineIdentity) {
    if ($ProtocolVersion -lt 1 -or $SnapshotSchema -lt 1 -or $EngineIdentity -cnotmatch '^[A-Za-z0-9._-]{1,80}$') {
        throw 'Runtime identity protocol, snapshot schema or engine identity is invalid.'
    }
    $recordsByPath = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($record in @($Records)) {
        if (-not (Test-FluxRuntimeIdentityRecord $record)) { throw 'Malformed runtime identity source record.' }
        $path = [string]$record.path
        if (-not $recordsByPath.TryAdd($path, $record)) { throw "Duplicate runtime identity source path: $path" }
    }
    if ($recordsByPath.Count -lt 1) { throw 'Runtime identity requires at least one record.' }
    [string[]]$orderedPaths = @($recordsByPath.Keys | ForEach-Object { [string]$_ })
    [Array]::Sort($orderedPaths, [StringComparer]::Ordinal)
    $utf8 = [Text.UTF8Encoding]::new($false)
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add('FLUX_RUNTIME_BUILD_IDENTITY_V1')
    $lines.Add("protocol:$ProtocolVersion")
    $lines.Add("snapshot_schema:$SnapshotSchema")
    $lines.Add("engine_utf8:$($utf8.GetByteCount($EngineIdentity)):$EngineIdentity")
    $lines.Add("record_count:$($orderedPaths.Count)")
    foreach ($path in $orderedPaths) {
        $record = $recordsByPath[$path]
        $lines.Add("path_utf8:$($utf8.GetByteCount($path)):$path")
        $lines.Add("bytes:$([long]$record.bytes)")
        $lines.Add("sha256:$([string]$record.sha256)")
    }
    return ($lines -join "`n") + "`n"
}

function Get-FluxRuntimeIdentityDigest($Records, [int]$ProtocolVersion, [int]$SnapshotSchema, [string]$EngineIdentity) {
    $canonical = Get-FluxRuntimeIdentityCanonicalText $Records $ProtocolVersion $SnapshotSchema $EngineIdentity
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($canonical)
        return [Convert]::ToHexString($algorithm.ComputeHash($bytes)).ToLowerInvariant()
    } finally { $algorithm.Dispose() }
}

function New-FluxRuntimeBuildIdentity($Records, [int]$ProtocolVersion, [int]$SnapshotSchema, [string]$EngineIdentity) {
    $digest = Get-FluxRuntimeIdentityDigest $Records $ProtocolVersion $SnapshotSchema $EngineIdentity
    return [pscustomobject][ordered]@{
        schema_version = 1
        status = 'candidate_generated_not_promoted'
        scope_id = 'production-runtime-source-v1'
        canonical_encoding = 'utf8-lf-tagged-length-v1'
        protocol_version = $ProtocolVersion
        snapshot_schema = $SnapshotSchema
        engine_identity = $EngineIdentity
        record_count = @($Records).Count
        runtime_source_sha256 = $digest
        build_id = "p$ProtocolVersion-$($digest.Substring(0, 12))"
        authority = 'Generated from canonical production runtime source records; delivery, publication and acceptance remain separate.'
    }
}

function Assert-FluxRuntimeBuildIdentity($Manifest, $Expected) {
    if ($null -eq $Manifest -or $null -eq $Expected) { throw 'Runtime build identity manifest is missing.' }
    $expectedNames = @('schema_version', 'status', 'scope_id', 'canonical_encoding', 'protocol_version', 'snapshot_schema', 'engine_identity', 'record_count', 'runtime_source_sha256', 'build_id', 'authority')
    $actualNames = @($Manifest.PSObject.Properties.Name)
    $remainingNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($name in $expectedNames) { $null = $remainingNames.Add($name) }
    if ($actualNames.Count -ne $expectedNames.Count) { throw 'Runtime build identity has missing or unexpected fields.' }
    foreach ($name in $actualNames) {
        if (-not $remainingNames.Remove([string]$name)) { throw 'Runtime build identity has missing or unexpected fields.' }
    }
    if ($remainingNames.Count -ne 0) { throw 'Runtime build identity has missing or unexpected fields.' }
    foreach ($name in @('schema_version', 'protocol_version', 'snapshot_schema', 'record_count')) {
        if (-not (Test-FluxRuntimeIdentityInteger $Manifest.$name 1) -or [long]$Manifest.$name -ne [long]$Expected.$name) {
            throw "Runtime build identity integer differs from current source: $name"
        }
    }
    foreach ($name in @('status', 'scope_id', 'canonical_encoding', 'engine_identity', 'runtime_source_sha256', 'build_id', 'authority')) {
        if ([string]$Manifest.$name -cne [string]$Expected.$name) { throw "Runtime build identity differs from current source: $name" }
    }
    if ([string]$Manifest.runtime_source_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
        [string]$Manifest.build_id -cnotmatch '^p[1-9][0-9]*-[0-9a-f]{12}$' -or
        [string]$Manifest.build_id -cne "p$($Manifest.protocol_version)-$(([string]$Manifest.runtime_source_sha256).Substring(0, 12))") {
        throw 'Runtime build ID is not the exact derived protocol/source identity.'
    }
    return $true
}

function Get-FluxSourceConstantInteger([string]$RepoRoot, [string]$Relative, [string]$Name) {
    $path = Resolve-FluxRuntimeIdentityPath $RepoRoot $Relative
    $matches = [regex]::Matches((Get-Content -Raw -LiteralPath $path), '(?m)^const\s+' + [regex]::Escape($Name) + ':\s*int\s*=\s*([0-9][0-9_]*)\s*$')
    if ($matches.Count -ne 1) { throw "Expected one integer source authority $Name in $Relative" }
    return [int]($matches[0].Groups[1].Value.Replace('_', ''))
}

$identityRoot = if ($Root) { [IO.Path]::GetFullPath($Root) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')) }
$resolvedManifest = Resolve-FluxRuntimeIdentityPath $identityRoot $ManifestPath
$protocol = Get-FluxSourceConstantInteger $identityRoot 'src/sim/core/sim_config.gd' 'PROTOCOL_VERSION'
$snapshot = Get-FluxSourceConstantInteger $identityRoot 'src/net/session_snapshot.gd' 'SCHEMA_VERSION'
$records = @(Get-FluxRuntimeIdentityRecords $identityRoot $ManifestPath)
$expectedIdentity = New-FluxRuntimeBuildIdentity $records $protocol $snapshot $EngineIdentity

if ($Mode -eq 'Generate') {
    if ((Test-Path -LiteralPath $resolvedManifest) -and -not $Force) {
        throw 'Runtime build identity already exists; use -Force only for an intentional pre-Full regeneration.'
    }
    $manifestParent = Split-Path -Parent $resolvedManifest
    if (-not (Test-Path -LiteralPath $manifestParent)) {
        $null = New-Item -ItemType Directory -Path $manifestParent
    }
    if (-not (Test-Path -LiteralPath $manifestParent -PathType Container)) { throw 'Runtime build identity parent directory is unavailable.' }
    $temporary = Join-Path $manifestParent ('.runtime-build-identity-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $jsonText = ($expectedIdentity | ConvertTo-Json -Depth 6) + "`n"
        [IO.File]::WriteAllText($temporary, $jsonText, [Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temporary -Destination $resolvedManifest -Force:$Force
    } finally {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) { Remove-Item -LiteralPath $temporary -Force }
    }
    Write-Output "GENERATED: $ManifestPath / $($expectedIdentity.build_id) / $($expectedIdentity.record_count) records. Candidate metadata only; run Check before Full/freeze."
    if ($Json) { $expectedIdentity | ConvertTo-Json -Depth 6 }
    return
}

if ($Force) { throw '-Force is valid only with -Mode Generate.' }
if (-not (Test-Path -LiteralPath $resolvedManifest -PathType Leaf)) { throw 'Runtime build identity is missing; integration owner must generate it before Full/freeze.' }
$manifest = Get-Content -Raw -LiteralPath $resolvedManifest | ConvertFrom-Json
$null = Assert-FluxRuntimeBuildIdentity $manifest $expectedIdentity
if ($Json) {
    $expectedIdentity | ConvertTo-Json -Depth 6
} else {
    Write-Output "PASS: runtime build identity $($expectedIdentity.build_id), $($expectedIdentity.record_count) canonical production records; source-only check, no engine or payload action."
}
