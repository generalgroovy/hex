param(
    [string]$PointerPath = 'docs/current-checkpoint.json',
    [switch]$Json,
    [string]$CheckPath = '',
    [switch]$Quiet
)

# Descriptor-only delivery summary. This reads source metadata but never checks,
# launches, extracts, downloads or writes a payload. Exact local identity remains
# the responsibility of current-checkpoint.ps1.
$ErrorActionPreference = 'Stop'

function Test-FluxSummaryInteger($Value) {
    return $null -ne $Value -and $Value -isnot [string] -and $Value -isnot [bool] -and
        [double]$Value -ge 0 -and [double]$Value -eq [math]::Floor([double]$Value)
}

function Resolve-FluxSummaryRepoPath([string]$Root, [string]$Relative) {
    if (-not $Relative -or [IO.Path]::IsPathRooted($Relative) -or $Relative.Contains('\') -or
        $Relative.Contains(':') -or $Relative.StartsWith('/') -or $Relative -match '[\x00-\x1f<>"|?*]') {
        throw 'Expected a canonical repo-relative path using forward slashes.'
    }
    $segments = $Relative.Split('/')
    foreach ($segment in $segments) {
        if (-not $segment -or $segment -in @('.', '..') -or $segment.EndsWith('.') -or
            $segment.EndsWith(' ') -or $segment -notmatch '^[A-Za-z0-9._-]+$' -or
            $segment -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') {
            throw 'Unsafe or noncanonical path segment.'
        }
    }
    $repoRoot = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $resolved = [IO.Path]::GetFullPath((Join-Path $repoRoot $Relative))
    if (-not $resolved.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Path escapes the checkout.'
    }
    $cursor = $repoRoot
    foreach ($segment in $segments) {
        $cursor = Join-Path $cursor $segment
        if (Test-Path -LiteralPath $cursor) {
            if (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'Summary paths may not traverse a reparse point.'
            }
        }
    }
    return $resolved
}

function Get-FluxSummaryRoleMap($Records, [string[]]$ExpectedRoles, [string]$Directory, [string]$Category) {
    $items = @($Records)
    $roles = @($items | ForEach-Object { [string]$_.role })
    if ((($roles | Sort-Object -CaseSensitive) -join '|') -cne (($ExpectedRoles | Sort-Object -CaseSensitive) -join '|')) {
        throw "Expected exactly these current $Category roles: $($ExpectedRoles -join ', ')."
    }
    $result = @{}
    $seenPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($item in $items) {
        $role = [string]$item.role
        $path = [string]$item.path
        if ($path -notmatch '^[A-Za-z0-9._/-]+$' -or -not $path.StartsWith($Directory + '/', [StringComparison]::Ordinal)) {
            throw "Current $Category path must be a canonical child of its declared directory."
        }
        foreach ($segment in $path.Split('/')) {
            if (-not $segment -or $segment -in @('.', '..') -or $segment.EndsWith('.') -or
                $segment.EndsWith(' ') -or $segment -notmatch '^[A-Za-z0-9._-]+$' -or
                $segment -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') {
                throw "Current $Category path contains an unsafe or noncanonical segment."
            }
        }
        if (-not $seenPaths.Add($path)) { throw "Duplicate current $Category path." }
        if (-not (Test-FluxSummaryInteger $item.bytes) -or [string]$item.sha256 -cnotmatch '^[0-9a-f]{64}$') {
            throw "Current $Category role $role needs an exact nonnegative byte length and lowercase SHA-256."
        }
        $result[$role] = $item
    }
    return $result
}

function Get-FluxCurrentBuildSummary($Pointer) {
    if ($null -eq $Pointer -or $Pointer.schema_version -ne 1 -or $Pointer.schema_version -is [string] -or $Pointer.schema_version -is [bool]) {
        throw 'Expected current checkpoint pointer schema 1.'
    }
    $current = $Pointer.current
    if ($null -eq $current -or [string]$current.kind -cne 'current_portable' -or
        [string]$current.checkpoint_id -cnotmatch '^[a-z0-9][a-z0-9-]+$') {
        throw 'Expected one valid current_portable checkpoint identity.'
    }
    $buildDirectory = [string]$current.build_directory
    $evidenceDirectory = [string]$current.evidence_directory
    if ($buildDirectory -cnotmatch '^exports/[a-z0-9][a-z0-9-]+$') {
        throw 'Current build_directory must identify one canonical child of exports.'
    }
    if ($evidenceDirectory -cnotmatch '^docs/evidence/[a-z0-9][a-z0-9-]+$') {
        throw 'Current evidence_directory must identify one canonical child of docs/evidence.'
    }
    $payloads = Get-FluxSummaryRoleMap $current.payloads @('game', 'pack', 'portable') $buildDirectory 'payload'
    $evidence = Get-FluxSummaryRoleMap $current.evidence @('checkpoint', 'full', 'capture', 'boot_log', 'boot_stderr') $evidenceDirectory 'evidence'
    $expectedPayloadPaths = @{
        game = "$buildDirectory/windows/flux2.exe"
        pack = "$buildDirectory/windows/flux2.pck"
        portable = "$buildDirectory/release/FLUX2-Windows-x86_64.zip"
    }
    foreach ($role in $expectedPayloadPaths.Keys) {
        if ([string]$payloads[$role].path -cne $expectedPayloadPaths[$role]) {
            throw "Current payload role $role does not address its exact expected target."
        }
    }
    if ([string]$evidence.checkpoint.path -cne "$evidenceDirectory/checkpoint.json") {
        throw 'Current checkpoint evidence role must address checkpoint.json.'
    }
    $boundaries = $Pointer.boundaries
    $boundaryNames = @('publication', 'human_acceptance', 'two_pc_acceptance', 'sustained_rendered_120fps', 'current_installer')
    if ($null -eq $boundaries) { throw 'Expected explicit current delivery boundaries.' }
    $boundaryValues = [ordered]@{}
    foreach ($name in $boundaryNames) {
        $value = [string]$boundaries.$name
        if ($value -cnotmatch '^[a-z0-9][a-z0-9_]*$') { throw "Missing or malformed current delivery boundary: $name." }
        $boundaryValues[$name] = $value
    }
    return [pscustomobject][ordered]@{
        schema_version = 1
        descriptor_status = 'pointer_descriptor_valid'
        checkpoint_id = [string]$current.checkpoint_id
        kind = 'current_portable'
        game = [pscustomobject][ordered]@{path = [string]$payloads.game.path; bytes = [long]$payloads.game.bytes; sha256 = [string]$payloads.game.sha256}
        pack = [pscustomobject][ordered]@{path = [string]$payloads.pack.path; bytes = [long]$payloads.pack.bytes; sha256 = [string]$payloads.pack.sha256}
        portable = [pscustomobject][ordered]@{path = [string]$payloads.portable.path; bytes = [long]$payloads.portable.bytes; sha256 = [string]$payloads.portable.sha256}
        evidence_directory = $evidenceDirectory
        boundaries = [pscustomobject]$boundaryValues
        exact_verifier = 'pwsh -NoProfile -File scripts/current-checkpoint.ps1 -ReportOnly'
        summary_scope = 'Pointer metadata only; local payload/evidence bytes, runtime, installer, publication, human acceptance, network acceptance and rendered performance are not freshly verified.'
    }
}

function Format-FluxCurrentBuildMarkdown($Summary) {
    $begin = '<!-- BEGIN CURRENT BUILD SUMMARY: generated by scripts/current-build-summary.ps1 -->'
    $end = '<!-- END CURRENT BUILD SUMMARY -->'
    return @(
        $begin
        "**Pointer-selected delivery metadata ([descriptor](docs/current-checkpoint.json), not fresh availability):** ``$($Summary.checkpoint_id)``."
        "Recorded paths (not verified download links): game ``$($Summary.game.path)``; pack ``$($Summary.pack.path)``; portable ``$($Summary.portable.path)``. Use the verified playtest link at the top of this README."
        "Pinned PCK SHA-256: ``$($Summary.pack.sha256)``"
        "Pinned ZIP SHA-256: ``$($Summary.portable.sha256)``"
        "Pointer boundaries: publication ``$($Summary.boundaries.publication)``; human acceptance ``$($Summary.boundaries.human_acceptance)``; physical two-PC acceptance ``$($Summary.boundaries.two_pc_acceptance)``; sustained rendered 120 FPS ``$($Summary.boundaries.sustained_rendered_120fps)``; current installer ``$($Summary.boundaries.current_installer)``."
        "This generated summary validates pointer metadata only; it does not read or hash local payloads or repeat runtime acceptance. For exact local byte and receipt checks, run ``$($Summary.exact_verifier)``."
        $end
    ) -join "`n"
}

function Assert-FluxCurrentBuildText([string]$Text, [string]$ExpectedBlock) {
    $begin = '<!-- BEGIN CURRENT BUILD SUMMARY: generated by scripts/current-build-summary.ps1 -->'
    $end = '<!-- END CURRENT BUILD SUMMARY -->'
    $normalized = $Text.Replace("`r`n", "`n").Replace("`r", "`n")
    $expected = $ExpectedBlock.Replace("`r`n", "`n").Replace("`r", "`n")
    if ([regex]::Matches($normalized, [regex]::Escape($begin)).Count -ne 1 -or
        [regex]::Matches($normalized, [regex]::Escape($end)).Count -ne 1) {
        throw 'Expected exactly one complete generated current-build summary marker pair.'
    }
    $start = $normalized.IndexOf($begin, [StringComparison]::Ordinal)
    $finish = $normalized.IndexOf($end, $start, [StringComparison]::Ordinal)
    if ($finish -lt $start) { throw 'Generated current-build summary markers are out of order.' }
    $actual = $normalized.Substring($start, $finish + $end.Length - $start)
    if ($actual -cne $expected) {
        throw 'Generated current-build summary is stale or edited; regenerate it from docs/current-checkpoint.json.'
    }
    return $true
}

$summaryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$resolvedPointer = Resolve-FluxSummaryRepoPath $summaryRoot $PointerPath
$pointer = Get-Content -Raw -LiteralPath $resolvedPointer | ConvertFrom-Json
$summary = Get-FluxCurrentBuildSummary $pointer
$markdown = Format-FluxCurrentBuildMarkdown $summary
if ($CheckPath) {
    if ($Json) { throw '-Json and -CheckPath are separate modes.' }
    $resolvedCheck = Resolve-FluxSummaryRepoPath $summaryRoot $CheckPath
    $null = Assert-FluxCurrentBuildText (Get-Content -Raw -LiteralPath $resolvedCheck) $markdown
    if (-not $Quiet) { Write-Output "PASS: $CheckPath current-build summary matches $PointerPath; pointer metadata only, no payload access." }
} elseif ($Json) {
    $summary | ConvertTo-Json -Depth 8
} elseif (-not $Quiet) {
    Write-Output $markdown
}
