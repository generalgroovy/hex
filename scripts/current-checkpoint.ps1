param(
    [string]$PointerPath = 'docs/current-checkpoint.json',
    [switch]$Json,
    [switch]$Quiet,
    [switch]$ReportOnly
)

# Read-only verification: no engine, extraction, network, installer or report writes.
function Get-FluxCheckpointReport($Pointer, [string]$Root) {
    $taskRoot = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $problems = [Collections.Generic.List[object]]::new()
    $seenPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    function Problem([string]$Code, [string]$Path, [string]$Message) {
        $problems.Add([pscustomobject]@{code = $Code; path = $Path; message = $Message})
    }
    function Resolve-CheckpointPath([string]$Relative) {
        if (-not $Relative -or $Relative.Contains('\') -or $Relative.Contains(':') -or $Relative.StartsWith('/') -or $Relative -match '[\x00-\x1f<>"|?*]') { throw 'Expected a canonical repo-relative path using forward slashes.' }
        $segments = $Relative.Split('/')
        foreach ($segment in $segments) {
            if (-not $segment -or $segment -in @('.', '..') -or $segment.EndsWith('.') -or $segment.EndsWith(' ') -or $segment -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') { throw 'Unsafe or noncanonical path segment.' }
        }
        $resolved = [IO.Path]::GetFullPath((Join-Path $taskRoot $Relative))
        if (-not $resolved.StartsWith($taskRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Path escapes the checkout.' }
        $cursor = $taskRoot
        foreach ($segment in $segments) {
            $cursor = Join-Path $cursor $segment
            if (Test-Path -LiteralPath $cursor) {
                if (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Checkpoint paths may not traverse a reparse point.' }
            }
        }
        return $resolved
    }
    function Audit-CheckpointGroup($Group, [string]$Kind, [string[]]$PayloadRoles, [string[]]$EvidenceRoles) {
        $start = $problems.Count
        $records = [Collections.Generic.List[object]]::new()
        if ($null -eq $Group -or $Group.kind -cne $Kind -or [string]$Group.checkpoint_id -cnotmatch '^[a-z0-9][a-z0-9-]+$') {
            Problem 'descriptor' $Kind 'Missing or invalid checkpoint identity/kind.'
            return [pscustomobject]@{kind = $Kind; status = 'invalid'; files = @(); issues = @($problems | Select-Object -Skip $start)}
        }
        foreach ($category in @('payloads', 'evidence')) {
            $directory = [string]$(if ($category -eq 'payloads') { $Group.build_directory } else { $Group.evidence_directory })
            try {
                $null = Resolve-CheckpointPath $directory
                $prefix = if ($category -eq 'payloads') { 'exports/' } else { 'docs/evidence/' }
                if (-not $directory.StartsWith($prefix, [StringComparison]::Ordinal)) { throw "Expected directory below $prefix" }
            } catch { Problem 'path' $directory $_.Exception.Message; continue }
            $expected = if ($category -eq 'payloads') { $PayloadRoles } else { $EvidenceRoles }
            $entries = @($Group.$category)
            $roles = @($entries | ForEach-Object { [string]$_.role })
            if ((($roles | Sort-Object) -join '|') -cne (($expected | Sort-Object) -join '|')) { Problem 'roles' $Kind "Expected exactly these $category roles: $($expected -join ', ')." }
            foreach ($entry in $entries) {
                $relative = [string]$entry.path
                try {
                    $resolved = Resolve-CheckpointPath $relative
                    if (-not $relative.StartsWith($directory + '/', [StringComparison]::Ordinal)) { throw 'Record lies outside its declared checkpoint directory.' }
                    if ($category -eq 'payloads') {
                        $filenames = @{game = 'windows/flux2.exe'; pack = 'windows/flux2.pck'; portable = 'release/FLUX2-Windows-x86_64.zip'; installer = 'release/FLUX.exe'}
                        if (-not $filenames.ContainsKey([string]$entry.role) -or $relative -cne ($directory + '/' + $filenames[[string]$entry.role])) { throw 'Payload role does not address its exact expected game/pack/archive/installer target.' }
                    }
                    if (-not $seenPaths.Add($relative)) { throw 'Duplicate checkpoint file path.' }
                    if ($null -eq $entry.bytes -or $entry.bytes -is [string] -or $entry.bytes -is [bool] -or [double]$entry.bytes -lt 0 -or [double]$entry.bytes -ne [math]::Floor([double]$entry.bytes) -or [string]$entry.sha256 -cnotmatch '^[0-9a-f]{64}$') { throw 'Expected exact nonnegative byte length and lowercase SHA-256.' }
                    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
                        Problem 'missing' $relative 'Pinned local file is unavailable; this is not a passed verification.'
                        $records.Add([pscustomobject]@{role = $entry.role; path = $relative; status = 'missing'})
                        continue
                    }
                    $actualBytes = (Get-Item -LiteralPath $resolved).Length
                    $actualHash = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash.ToLowerInvariant()
                    $matches = $actualBytes -eq $entry.bytes -and $actualHash -ceq $entry.sha256
                    if (-not $matches) { Problem 'identity' $relative 'File size or SHA-256 differs from the pinned checkpoint.' }
                    $records.Add([pscustomobject]@{role = $entry.role; path = $relative; bytes = $actualBytes; sha256 = $actualHash; status = $(if ($matches) { 'verified' } else { 'mismatch' })})
                } catch { Problem 'descriptor' $relative $_.Exception.Message }
            }
        }
        $groupIssues = @($problems | Select-Object -Skip $start)
        $status = if (@($groupIssues | Where-Object code -ne 'missing').Count -gt 0) { 'invalid' } elseif ($groupIssues.Count -gt 0) { 'unavailable' } else { 'verified' }
        return [pscustomobject]@{checkpoint_id = $Group.checkpoint_id; kind = $Kind; status = $status; build_directory = $Group.build_directory; files = @($records); issues = $groupIssues}
    }
    if ($null -eq $Pointer -or $Pointer.schema_version -ne 1 -or $Pointer.schema_version -is [string]) { Problem 'schema' '' 'Expected checkpoint pointer schema 1.' }
    $current = Audit-CheckpointGroup $Pointer.current 'current_portable' @('game', 'pack', 'portable') @('checkpoint', 'full', 'capture', 'boot_log', 'boot_stderr')
    $historical = Audit-CheckpointGroup $Pointer.historical_installer 'historical_installer' @('installer') @('installer_journey')
    # Bind the human summary to already hash-verified receipts, not fresh claims.
    if ($current.status -eq 'verified') {
        try {
            $checkpoint = Get-Content -Raw -LiteralPath (Resolve-CheckpointPath (@($current.files | Where-Object role -eq 'checkpoint')[0].path)) | ConvertFrom-Json
            $full = Get-Content -Raw -LiteralPath (Resolve-CheckpointPath (@($current.files | Where-Object role -eq 'full')[0].path)) | ConvertFrom-Json
            $capture = Get-Content -Raw -LiteralPath (Resolve-CheckpointPath (@($current.files | Where-Object role -eq 'capture')[0].path)) | ConvertFrom-Json
            if ($checkpoint.status -cne 'local_full_export_raw_boot_passed' -or $full.result -cne 'passed' -or $full.tier -cne 'full' -or $full.executed.suite_count -ne $checkpoint.full_suites -or $full.executed.assertion_count -ne $checkpoint.full_assertions -or @($capture.frames).Count -lt 1) { throw 'Checkpoint/Full/capture receipt claims disagree.' }
            if (@($current.files | Where-Object role -eq 'boot_stderr')[0].bytes -ne 0) { throw 'Verified boot must have empty stderr.' }
            foreach ($payload in @($current.files | Where-Object role -in @('game', 'pack', 'portable'))) {
                $recorded = @($checkpoint.payloads | Where-Object { ([string]$_.path).Replace('\', '/').EndsWith('/' + $payload.path, [StringComparison]::Ordinal) -or $_.path -ceq $payload.path })
                if ($recorded.Count -ne 1 -or $recorded[0].sha256 -cne $payload.sha256 -or $recorded[0].bytes -ne $payload.bytes) { throw 'Payload identity disagrees with the checkpoint receipt.' }
            }
            $current | Add-Member -NotePropertyName evidence_summary -NotePropertyValue ([pscustomobject]@{full_suites = $full.executed.suite_count; full_assertions = $full.executed.assertion_count; captures = @($capture.frames).Count; new_installer = $checkpoint.new_installer; human_acceptance = $checkpoint.human_animation_acceptance; two_pc_acceptance = $checkpoint.friend_network_acceptance; sustained_120fps = $checkpoint.sustained_120fps})
        } catch { Problem 'receipt' $current.checkpoint_id $_.Exception.Message; $current.status = 'invalid' }
    }
    if ($historical.status -eq 'verified') {
        try {
            $journey = Get-Content -Raw -LiteralPath (Resolve-CheckpointPath (@($historical.files | Where-Object role -eq 'installer_journey')[0].path)) | ConvertFrom-Json
            $installer = @($historical.files | Where-Object role -eq 'installer')[0]
            if ($journey.passed -isnot [bool] -or -not $journey.passed -or $journey.installer_sha256 -cne $installer.sha256) { throw 'Historical installer does not match its passed journey receipt.' }
        } catch { Problem 'receipt' $historical.checkpoint_id $_.Exception.Message; $historical.status = 'invalid' }
    }
    $status = if (@($problems | Where-Object code -ne 'missing').Count -gt 0) { 'invalid' } elseif ($problems.Count -gt 0) { 'unavailable' } else { 'verified' }
    return [pscustomobject]@{schema_version = 1; status = $status; passed = ($status -eq 'verified'); evidence_scope = 'Read-only local file identity and recorded receipt consistency; not a fresh engine, installer, human or network acceptance run.'; current_portable = $current; historical_installer = $historical; issues = @($problems)}
}

$checkpointRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ([IO.Path]::IsPathRooted($PointerPath) -or $PointerPath.Contains('\') -or $PointerPath.Contains(':') -or '..' -in $PointerPath.Split('/')) { throw 'PointerPath must be repo-relative without traversal.' }
$checkpointPointer = Get-Content -Raw -LiteralPath (Join-Path $checkpointRoot $PointerPath) | ConvertFrom-Json
$report = Get-FluxCheckpointReport $checkpointPointer $checkpointRoot
if ($Json) { $report | ConvertTo-Json -Depth 15 } elseif (-not $Quiet) {
    Write-Output "Current portable: $($report.current_portable.checkpoint_id) / $($report.current_portable.status) / $($report.current_portable.build_directory)"
    Write-Output "Historical installer (different older build): $($report.historical_installer.checkpoint_id) / $($report.historical_installer.status)"
    Write-Output $report.evidence_scope
    foreach ($issue in $report.issues) { Write-Output "$($issue.code): $($issue.path) - $($issue.message)" }
}
if (-not $ReportOnly -and -not $report.passed) { throw "Checkpoint verification is $($report.status); exact pinned payload/evidence checks did not pass." }
