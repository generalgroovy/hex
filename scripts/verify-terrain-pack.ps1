param(
    [Parameter(Mandatory = $true)][string]$PackPath,
    [Parameter(Mandatory = $true)][string]$OutputDirectory
)

# Explicit qualification step, never called by gameplay. Keeps expectations,
# engine logs, and the decoded-pixel receipt together in a fresh directory.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$terrainRoot = Get-FluxRepoRoot
if (-not [IO.Path]::IsPathRooted($PackPath)) { $PackPath = Join-Path $terrainRoot $PackPath }
if (-not [IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory = Join-Path $terrainRoot $OutputDirectory }
$PackPath = [IO.Path]::GetFullPath($PackPath)
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if (-not (Test-Path -LiteralPath $PackPath -PathType Leaf)) { throw "Missing exported pack: $PackPath" }
if (Test-Path -LiteralPath $OutputDirectory) { throw 'A fresh verification output directory is required; existing evidence is preserved.' }
& (Join-Path $PSScriptRoot 'runtime-build-identity.ps1') -Mode Check
$terrainLease = Enter-FluxEngineRun 'verify-exported-terrain'
$terrainHadAppData = Test-Path Env:APPDATA
$terrainSavedAppData = $env:APPDATA
$terrainSourceHash = $null
$terrainCopyHash = $null
$terrainSourceAfter = $null
$terrainCopyAfter = $null
$terrainIsolatedPack = $null
$terrainReceipt = $null
$terrainProject = $null
$terrainProjectHash = $null
$terrainProjectAfter = $null
$terrainMountAdmitted = $false
$terrainProblem = $null
$terrainVerified = $false
try {
    New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    $terrainIsolated = Join-Path $OutputDirectory 'isolated-project'
    New-Item -ItemType Directory -Path $terrainIsolated | Out-Null
    $terrainScript = Join-Path $terrainIsolated 'verify-terrain-pack.gd'
    $terrainIdentity = Join-Path $terrainIsolated 'expected-identity.json'
    $terrainManifest = Join-Path $terrainIsolated 'expected-terrain-manifest.tres'
    $terrainProvenance = Join-Path $terrainIsolated 'expected-provenance.json'
    $terrainReceipt = Join-Path $OutputDirectory 'terrain-pack.json'
    # A real minimal project establishes the physical res:// root. The standalone
    # script explicitly mounts the copied PCK after validating this exact boundary.
    $terrainProject = Join-Path $terrainIsolated 'project.godot'
    $terrainProjectText = (@('config_version=5', '', '[application]', 'config/name="H.E.X. isolated terrain audit"') -join "`n") + "`n"
    $terrainProjectBytes = [Text.UTF8Encoding]::new($false).GetBytes($terrainProjectText)
    [IO.File]::WriteAllBytes($terrainProject, $terrainProjectBytes)
    $terrainProjectHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($terrainProjectBytes)).ToLowerInvariant()
    $terrainIsolatedPack = Join-Path $terrainIsolated 'verified-export.pck'
    $terrainSourceHash = (Get-FileHash -LiteralPath $PackPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Copy-Item -LiteralPath $PackPath -Destination $terrainIsolatedPack
    $terrainCopyHash = (Get-FileHash -LiteralPath $terrainIsolatedPack -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($terrainCopyHash -cne $terrainSourceHash -or (Get-FileHash -LiteralPath $PackPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $terrainSourceHash) { throw 'The isolated PCK copy is not the unchanged supplied export.' }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'verify-terrain-pack.gd') -Destination $terrainScript
    Copy-Item -LiteralPath (Join-Path $terrainRoot 'content/runtime/runtime_build_identity_v1.json') -Destination $terrainIdentity
    Copy-Item -LiteralPath (Join-Path $terrainRoot 'assets/environment/wellspring_ground_v1/manifest.tres') -Destination $terrainManifest
    $terrainSources = @(
        'scripts/bake_wellspring_terrain.gd',
        'src/presentation/wellspring_terrain_stream.gd',
        'src/presentation/wellspring_async_terrain_stream.gd',
        'src/presentation/terrain_hash_job.gd',
        'src/presentation/wellspring_illustrated_kit.gd',
        'src/presentation/hex_environment_layout.gd',
        'src/presentation/pixel_map_library.gd',
        'art_batches/wellspring_style_v2/ground_style.gd',
        'src/sim/hex/hex_grid.gd',
        'src/sim/core/sim_config.gd'
    )
    $terrainSourceHashes = [ordered]@{}
    foreach ($terrainSource in $terrainSources) {
        $terrainSourceHashes['res://' + $terrainSource] = (Get-FileHash -LiteralPath (Join-Path $terrainRoot $terrainSource) -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    [IO.File]::WriteAllText($terrainProvenance, ($terrainSourceHashes | ConvertTo-Json -Depth 4) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    $terrainPackHash = $terrainSourceHash
    foreach ($forbidden in @('assets', 'src', 'content', 'override.cfg')) {
        if (Test-Path -LiteralPath (Join-Path $terrainIsolated $forbidden)) { throw "Isolated directory contains a possible checkout fallback: $forbidden" }
    }
    if ((Get-FileHash -LiteralPath $terrainProject -Algorithm SHA256).Hash.ToLowerInvariant() -cne $terrainProjectHash) { throw 'Minimal isolated project bytes changed before launch.' }
    $env:APPDATA = Join-Path $OutputDirectory 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    $terrainArguments = @(
        '--headless', '--path', $terrainIsolated,
        '--script', $terrainScript, '--',
        "--isolated-root=$terrainIsolated", "--expected-pack=$terrainIsolatedPack",
        "--expected-pack-sha256=$terrainPackHash", "--expected-identity=$terrainIdentity",
        "--expected-manifest=$terrainManifest", "--expected-provenance=$terrainProvenance",
        "--verification-output=$terrainReceipt"
    )
    Push-Location -LiteralPath $terrainIsolated
    try {
        Invoke-FluxGodotChecked (Get-FluxGodot) $terrainArguments (Join-Path $OutputDirectory 'engine.log') -RejectWarnings -TimeoutSeconds 180 | Out-Null
    } finally { Pop-Location }
    if (-not (Test-Path -LiteralPath $terrainReceipt -PathType Leaf)) { throw 'Terrain verifier did not publish a receipt.' }
    $terrainResult = Get-Content -Raw -LiteralPath $terrainReceipt | ConvertFrom-Json
    if ($terrainResult.status -cne 'passed' -or $terrainResult.decoded_image_count -ne 133 -or @($terrainResult.verified_chunks).Count -ne 132 -or $terrainResult.pack_sha256 -cne $terrainPackHash) { throw 'Terrain verification receipt is incomplete or unsuccessful.' }
    if ($terrainResult.mount.method -cne 'ProjectSettings.load_resource_pack' -or $terrainResult.mount.success -cne $true -or $terrainResult.mount.replace_files -cne $false -or $terrainResult.mount.target_resources_absent_before_mount -ne 136 -or $terrainResult.mount.minimal_project_sha256 -cne $terrainProjectHash -or [IO.Path]::GetFullPath($terrainResult.mount.path) -ine $terrainIsolatedPack) { throw 'Explicit pinned-pack mount admission is incomplete or inconsistent.' }
    $terrainMountAdmitted = $true
    foreach ($forbidden in @('assets', 'src', 'content', 'override.cfg')) {
        if (Test-Path -LiteralPath (Join-Path $terrainIsolated $forbidden)) { throw "Isolated directory gained a possible checkout fallback: $forbidden" }
    }
    $terrainVerified = $true
} catch {
    $terrainProblem = $_.Exception.Message
} finally {
    try {
        if ($null -ne $terrainSourceHash) {
            try {
                $terrainSourceAfter = (Get-FileHash -LiteralPath $PackPath -Algorithm SHA256).Hash.ToLowerInvariant()
                $terrainCopyAfter = (Get-FileHash -LiteralPath $terrainIsolatedPack -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($terrainSourceAfter -cne $terrainSourceHash -or $terrainCopyAfter -cne $terrainSourceHash) { throw 'The supplied export or its isolated copy changed during verification.' }
            } catch { $terrainProblem = @($terrainProblem, $_.Exception.Message) | Where-Object { $_ } | Join-String -Separator '; ' }
        }
        if ($null -ne $terrainProjectHash) {
            try {
                $terrainProjectAfter = (Get-FileHash -LiteralPath $terrainProject -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($terrainProjectAfter -cne $terrainProjectHash) { throw 'Minimal isolated project bytes changed during verification.' }
            } catch { $terrainProblem = @($terrainProblem, $_.Exception.Message) | Where-Object { $_ } | Join-String -Separator '; ' }
        }
        if (Test-Path -LiteralPath $OutputDirectory -PathType Container) {
            $provenanceReceipt = [ordered]@{
                schema = 'hex-terrain-pack-copy-provenance-v1'
                status = $(if ($terrainVerified -and -not $terrainProblem) { 'passed' } else { 'failed' })
                scope = 'An unchanged byte-identical copy of the supplied export is eligible only after explicit load_resource_pack admission from a known minimal isolated project, with target resources absent before mount and no loose assets/src/content fallback. Artifact integrity only; no export, deployment, gameplay or performance qualification.'
                mount_method = 'ProjectSettings.load_resource_pack'; explicit_mount_admitted = $terrainMountAdmitted; main_pack_argument_used = $false
                isolated_project_path = $terrainProject; minimal_project_sha256_before = $terrainProjectHash; minimal_project_sha256_after = $terrainProjectAfter
                source_pack_path = $PackPath; isolated_pack_path = $terrainIsolatedPack
                source_sha256_before = $terrainSourceHash; isolated_sha256_before = $terrainCopyHash
                source_sha256_after = $terrainSourceAfter; isolated_sha256_after = $terrainCopyAfter
                decoded_terrain_receipt = $terrainReceipt
                decoded_terrain_receipt_sha256 = $(if ($null -ne $terrainReceipt -and (Test-Path -LiteralPath $terrainReceipt -PathType Leaf)) { (Get-FileHash -LiteralPath $terrainReceipt -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null })
                wrapper_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
                error = $terrainProblem
            }
            $provenancePath = Join-Path $OutputDirectory 'pack-provenance.json'
            $provenanceText = ($provenanceReceipt | ConvertTo-Json -Depth 6) + [Environment]::NewLine
            $provenanceBytes = [Text.UTF8Encoding]::new($false).GetBytes($provenanceText)
            $provenanceFile = [IO.File]::Open($provenancePath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
            try { $provenanceFile.Write($provenanceBytes, 0, $provenanceBytes.Length); $provenanceFile.Flush($true) } finally { $provenanceFile.Dispose() }
            if ([IO.File]::ReadAllText($provenancePath) -cne $provenanceText) { throw 'Pack provenance receipt read-back differs.' }
        }
    } finally {
        if ($terrainHadAppData) { $env:APPDATA = $terrainSavedAppData } else { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue }
        Exit-FluxEngineRun $terrainLease
    }
}
if ($terrainProblem) { throw $terrainProblem }
Write-Output "PASS: all 132 terrain chunks and overview decoded exactly from the unchanged exported pack copy. Receipt: $terrainReceipt"
