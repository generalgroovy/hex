<#
.SYNOPSIS
Freeze tested source, then produce one fresh Windows portable checkpoint.
.DESCRIPTION
Inventory is source-only and must precede Full/capture. Build validates those
receipts and unchanged scoped source membership, exports Windows, probes its
PCK, bundles a portable ZIP, and performs an isolated hidden raw executable
smoke. Existing destinations are never reused. No installer/security/network/
publication/current-pointer action is included. Capture currently requires the
existing actual-game warm-style-trails receipt/log schema; other schemas fail.
.EXAMPLE
./scripts/checkpoint-portable.ps1 -Mode Inventory -SourceInventoryPath docs/evidence/freeze-example/source-state.json
.EXAMPLE
./scripts/checkpoint-portable.ps1 -BuildName example-checkpoint -ExportRoot exports/example-checkpoint -EvidenceRoot docs/evidence/example-checkpoint -SourceInventoryPath docs/evidence/freeze-example/source-state.json -FullReceiptPath .godot/receipts/example-full.json -CaptureReceiptPath .godot/warm-style-trails-render-example/capture-receipt.json -CaptureLogPath .godot/windows-tests/example-capture.log
#>
[CmdletBinding()]
param(
    [ValidateSet('Inventory', 'Build')][string]$Mode = 'Build',
    [string]$BuildName = '',
    [string]$ExportRoot = '',
    [string]$EvidenceRoot = '',
    [Parameter(Mandatory)][string]$SourceInventoryPath,
    [string]$FullReceiptPath = '',
    [string]$CaptureReceiptPath = '',
    [string]$CaptureLogPath = ''
)

# Portable-only workflow. Inventory is an explicit pre-Full freeze step; Build
# consumes that freeze and passed receipts. No current pointer is ever changed.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-PortableRuntimeIdentity($Actual, $Expected) {
    if ($null -eq $Actual -or $null -eq $Expected) { throw 'Runtime identity is missing from acceptance evidence.' }
    foreach ($field in @('build_id', 'runtime_source_sha256', 'protocol_version', 'snapshot_schema', 'engine_identity', 'record_count')) {
        if ([string]$Actual.$field -cne [string]$Expected.$field) { throw "Runtime identity differs from frozen source: $field" }
    }
}

function Resolve-PortablePath([string]$Root, [string]$Relative, [string]$Prefix = '') {
    if (-not $Relative -or $Relative.Contains('\') -or $Relative.Contains(':') -or $Relative.StartsWith('/') -or $Relative -match '[\x00-\x1f<>"|?*]') { throw 'Use a canonical repo-relative path with forward slashes.' }
    $segments = $Relative.Split('/')
    foreach ($segment in $segments) {
        if (-not $segment -or $segment -in @('.', '..') -or $segment.EndsWith('.') -or $segment.EndsWith(' ') -or $segment -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') { throw 'Unsafe path segment.' }
    }
    if ($Prefix -and -not $Relative.StartsWith($Prefix + '/', [StringComparison]::Ordinal)) { throw "Expected a child below $Prefix." }
    $rootPath = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    if (((Get-Item -LiteralPath $rootPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Repository root cannot be a reparse point.' }
    $cursor = $rootPath
    foreach ($segment in $segments) {
        $cursor = Join-Path $cursor $segment
        if (Test-Path -LiteralPath $cursor) {
            if (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Refusing reparse-point traversal: $cursor" }
        }
    }
    return [IO.Path]::GetFullPath($cursor)
}

function Assert-PortableFreshPlan([string]$Root, [string]$Name, [string]$Export, [string]$Evidence) {
    if ($Name -cnotmatch '^[a-z0-9][a-z0-9-]{2,79}$') { throw 'BuildName must be a fresh lowercase slug (3-80 characters).' }
    $exportPath = Resolve-PortablePath $Root $Export 'exports'
    $evidencePath = Resolve-PortablePath $Root $Evidence 'docs/evidence'
    if ($Export.Split('/')[-1] -cne $Name -or $Evidence.Split('/')[-1] -cne $Name) { throw 'Both destination leaf names must equal BuildName.' }
    foreach ($path in @($exportPath, $evidencePath)) {
        if (Test-Path -LiteralPath $path) { throw "Fresh immutable destination required; existing checkpoints are never reused: $path" }
    }
    return @{export = $exportPath; evidence = $evidencePath}
}

function Assert-PortableCleanText([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text) -or $Text -match '(?im)^(?:FAIL(?:URE)?(?::|\b)|ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|Invalid call') { throw 'Required log is empty or contains a failure/warning.' }
}

function Test-PortableInteger($Value, [long]$Minimum = 0) {
    return $null -ne $Value -and $Value -isnot [string] -and $Value -isnot [bool] -and
        $Value -is [ValueType] -and [double]::IsFinite([double]$Value) -and
        [double]$Value -ge $Minimum -and [double]$Value -eq [math]::Floor([double]$Value)
}

function Convert-PortableUtcInstant($Value) {
    # PowerShell7 ConvertFrom-Json may already return a DateTime. Never route
    # that value back through a zone-less culture-dependent string conversion.
    if ($Value -is [DateTimeOffset]) { return $Value.UtcDateTime }
    if ($Value -is [DateTime]) {
        if ($Value.Kind -eq [DateTimeKind]::Utc) { return $Value }
        if ($Value.Kind -eq [DateTimeKind]::Local) { return $Value.ToUniversalTime() }
        throw 'Receipt timestamp DateTime must have an explicit UTC or Local kind.'
    }
    if ($Value -isnot [string] -or $Value -cnotmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?(?:Z|[+-]\d{2}:\d{2})$') { throw 'Receipt timestamp text must be ISO8601 with Z or an explicit offset.' }
    return [DateTimeOffset]::Parse($Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None).UtcDateTime
}

function Assert-PortableFullData($Receipt, [string]$SuiteText) {
    if ($Receipt.schema_version -cne 1 -or $Receipt.schema_version -is [string] -or $Receipt.tier -cne 'full' -or $Receipt.result -cne 'passed' -or $null -ne $Receipt.failure -or @($Receipt.requested_suite_ids).Count -ne 0 -or $Receipt.stderr_bytes -ne 0) { throw 'Require an unfiltered passed Full schema1 receipt with zero errors.' }
    foreach ($gate in @('current_state_check', 'asset_inventory', 'doctor', 'import', 'deterministic_suite_runner', 'boot_120_hz')) {
        if ($Receipt.executed.$gate -isnot [bool] -or -not $Receipt.executed.$gate) { throw "Full omitted required gate: $gate" }
    }
    if ($Receipt.executed.package_and_installer -isnot [bool] -or $Receipt.executed.package_and_installer) { throw 'This workflow requires Full, not an installer/release receipt.' }
    if (-not (Test-PortableInteger $Receipt.stderr_bytes) -or -not (Test-PortableInteger $Receipt.duration_ms 1) -or -not (Test-PortableInteger $Receipt.executed.suite_count 94) -or -not (Test-PortableInteger $Receipt.executed.assertion_count 1)) { throw 'Full totals/timing must be real nonnegative integers.' }
    $suites = @($Receipt.executed.suites)
    if ($suites.Count -lt 94 -or $Receipt.executed.suite_count -ne $suites.Count) { throw 'Full requires at least94 recorded suites, with matching count.' }
    Assert-PortableCleanText $SuiteText
    if ($SuiteText -notmatch '(?m)^PASS: all FLUX2 headless suites\r?$' -or $SuiteText -match '(?m)^PASS: \d+ selected') { throw 'Suite log must prove the unfiltered all-suite runner.' }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $sum = 0L
    foreach ($suite in $suites) {
        if ([string]$suite.id -cnotmatch '^[a-z0-9-]+$' -or -not $seen.Add([string]$suite.id) -or -not (Test-PortableInteger $suite.failures) -or $suite.failures -ne 0 -or -not (Test-PortableInteger $suite.assertions 1)) { throw 'Invalid/duplicate suite, failure or assertion count.' }
        $pattern = '(?m)^' + [regex]::Escape([string]$suite.id) + ': ' + [string]$suite.assertions + ' assertions, 0 failures\r?$'
        if ([regex]::Matches($SuiteText, $pattern).Count -ne 1) { throw 'Suite receipt/log rows disagree.' }
        $sum += [long]$suite.assertions
    }
    if ([regex]::Matches($SuiteText, '(?m)^[^:\r\n]+: [0-9]+ assertions, [0-9]+ failures\r?$').Count -ne $suites.Count -or $sum -ne $Receipt.executed.assertion_count) { throw 'Full log totals do not match its receipt.' }
}

function Get-PortableSourceInventory([string]$Root) {
    # Godot all_resources can include ignored files. Enumerate the actual
    # scoped filesystem, never Git's ignore-filtered index. Walk one directory
    # at a time so a reparse directory is rejected BEFORE traversing it.
    $paths = [Collections.Generic.List[string]]::new()
    foreach ($directory in @('src', 'content', 'assets', 'scenes', 'addons', 'scripts', 'tests',
        'art_batches/pixel_v1/magic/export', 'art_batches/pixel_v1/map/export', 'art_batches/wellspring_style_v2/runtime')) {
        $directoryPath = Resolve-PortablePath $Root $directory
        if (-not (Test-Path -LiteralPath $directoryPath -PathType Container)) { throw "Inventory root missing: $directory" }
        $pending = [Collections.Generic.Stack[string]]::new()
        $pending.Push($directoryPath)
        while ($pending.Count -gt 0) {
            foreach ($entry in Get-ChildItem -LiteralPath $pending.Pop() -Force) {
                if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Inventory cannot traverse a reparse point: $($entry.FullName)" }
                if ($entry.PSIsContainer) { $pending.Push($entry.FullName) }
                else { $paths.Add([IO.Path]::GetRelativePath($Root, $entry.FullName).Replace('\', '/')) }
            }
        }
    }
    foreach ($file in @('project.godot', 'export_presets.cfg', 'packaging/PLAY-FLUX.cmd', 'packaging/README-FIRST.txt', 'art_batches/pixel_v1/magic/manifest.json', 'art_batches/pixel_v1/map/manifest.json', 'art_batches/wellspring_style_v2/ground_style.gd')) {
        $path = Resolve-PortablePath $Root $file
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Inventory input missing: $file" }
        $paths.Add($file)
    }
    $ordered = @($paths | Sort-Object -Unique)
    $records = foreach ($relative in $ordered) {
        if (-not (Test-PortableInventoryMember $relative)) { throw 'Filesystem enumerator escaped its explicit inventory scope.' }
        $path = Resolve-PortablePath $Root $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Inventory file disappeared while hashing: $relative" }
        [ordered]@{file = $relative; bytes = (Get-Item -LiteralPath $path).Length; sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()}
    }
    return @($records)
}

function Test-PortableInventoryMember([string]$Relative) {
    return $Relative -in @('project.godot', 'export_presets.cfg', 'packaging/PLAY-FLUX.cmd', 'packaging/README-FIRST.txt', 'art_batches/wellspring_style_v2/ground_style.gd') -or
        $Relative -match '^(src|content|assets|scenes|addons|scripts|tests)/' -or
        $Relative -match '^art_batches/pixel_v1/(magic|map)/(manifest\.json$|export/)' -or
        $Relative -match '^art_batches/wellspring_style_v2/runtime/'
}

function Assert-PortableInventory($Expected, $Actual) {
    if (@($Expected).Count -lt 1 -or @($Expected).Count -ne @($Actual).Count) { throw 'Source inventory membership changed; rerun freeze/Full/capture.' }
    for ($index = 0; $index -lt @($Expected).Count; $index++) {
        $left = $Expected[$index]; $right = $Actual[$index]
        if ($left.file -cne $right.file -or -not (Test-PortableInteger $left.bytes) -or $left.bytes -ne $right.bytes -or [string]$left.sha256 -cnotmatch '^[0-9a-f]{64}$' -or $left.sha256 -cne $right.sha256) { throw "Source changed since freeze: $($right.file)" }
    }
}

function Assert-PortableCaptureData($Capture) {
    if ($Capture.schema_version -ne 1 -or $Capture.authority_unchanged_by_draw -isnot [bool] -or -not $Capture.authority_unchanged_by_draw -or $Capture.network -cne 'not_started' -or $Capture.method -cne 'fresh_offline_world_per_trial_real_catalog_spells_paid_inputs_production_bootstrap_draw' -or @($Capture.frames).Count -lt 1) { throw 'Require the actual-game warm-trails capture schema with unchanged authority and no network.' }
    $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($frame in @($Capture.frames)) {
        if ([string]$frame.file -cnotmatch '^[a-zA-Z0-9_-]+\.png$' -or -not $names.Add([string]$frame.file) -or [string]$frame.world_hash -cnotmatch '^[0-9a-f]{64}$') { throw 'Invalid/duplicate capture frame or missing authority hash.' }
        if ($null -ne $frame.PSObject.Properties['footprint_audit'] -and @($frame.footprint_audit.invalid_parts).Count -gt 0) { throw 'Capture contains invalid rendered footprint parts.' }
    }
}

function Write-PortableJson([string]$Path, $Value) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($Value | ConvertTo-Json -Depth 30) + [Environment]::NewLine)
        $stream.Write($bytes, 0, $bytes.Length)
    } finally { $stream.Dispose() }
}

. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$workflowLease = Enter-FluxEngineRun 'checkpoint-portable'
try {
$portableRoot = Get-FluxRepoRoot
$verifiedRuntimeIdentity = (& (Join-Path $PSScriptRoot 'runtime-build-identity.ps1') -Mode Check -Json | Out-String) | ConvertFrom-Json
$inventoryPath = Resolve-PortablePath $portableRoot $SourceInventoryPath 'docs/evidence'
if ($Mode -eq 'Inventory') {
    if (Test-Path -LiteralPath $inventoryPath) { throw 'Inventory is immutable; choose a fresh file.' }
    $inventoryParent = Split-Path -Parent $inventoryPath
    New-Item -ItemType Directory -Path $inventoryParent -Force | Out-Null
    if (-not (Test-Path -LiteralPath (Join-Path $inventoryParent '.gdignore'))) { [IO.File]::WriteAllText((Join-Path $inventoryParent '.gdignore'), '') }
    Write-PortableJson $inventoryPath (Get-PortableSourceInventory $portableRoot)
    Write-Output "PASS: source-only freeze written to $SourceInventoryPath; run fresh Full and capture before Build."
    return
}

$plan = Assert-PortableFreshPlan $portableRoot $BuildName $ExportRoot $EvidenceRoot
$fullPath = Resolve-PortablePath $portableRoot $FullReceiptPath
$capturePath = Resolve-PortablePath $portableRoot $CaptureReceiptPath
$captureLog = Resolve-PortablePath $portableRoot $CaptureLogPath
$full = Get-Content -Raw -LiteralPath $fullPath | ConvertFrom-Json
$capture = Get-Content -Raw -LiteralPath $capturePath | ConvertFrom-Json
$frozen = @(Get-Content -Raw -LiteralPath $inventoryPath | ConvertFrom-Json)
$before = @(Get-PortableSourceInventory $portableRoot)
Assert-PortableInventory $frozen $before
$completed = Convert-PortableUtcInstant $full.completed_at_utc
$started = $completed.AddMilliseconds(-[double]$full.duration_ms)
if ((Get-Item -LiteralPath $inventoryPath).LastWriteTimeUtc -gt $started) { throw 'Source freeze must predate the Full run, not retrospectively label it.' }
if ((Get-Item -LiteralPath $capturePath).LastWriteTimeUtc -lt (Get-Item -LiteralPath $inventoryPath).LastWriteTimeUtc) { throw 'Capture predates the source freeze.' }
$head = (& git -C $portableRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $head -cne $full.source.head) { throw 'Checkout HEAD differs from Full receipt.' }
$verifiedLogs = @()
$logNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$suiteText = ''
foreach ($entry in @($full.logs)) {
    $path = Resolve-PortablePath $portableRoot ([string]$entry.path)
    $name = [IO.Path]::GetFileName($path)
    if ($name -cnotin @('import.log', 'suite.log', 'boot-120.log') -or -not $logNames.Add($name)) { throw 'Full requires each exact import/suite/boot log once.' }
    if ([string]$entry.sha256 -cnotmatch '^[0-9a-f]{64}$' -or (Get-FluxFileSha256 $path) -cne $entry.sha256 -or $entry.stderr_bytes -ne 0 -or -not (Test-Path -LiteralPath "$path.err") -or (Get-Item -LiteralPath "$path.err").Length -ne 0) { throw 'Full log identity/error gate failed; preserve and provide the exact passed logs.' }
    $text = Get-Content -Raw -LiteralPath $path
    Assert-PortableCleanText $text
    if ($name -ceq 'boot-120.log' -and ($text -notmatch 'FLUX2 match initialized at 120 Hz' -or $text -notmatch 'FLUX2 bootstrap: 120 Hz, protocol [0-9]+,')) { throw 'Full boot log lacks the real120Hz startup signature.' }
    if ($text -match '(?m)^PASS: all FLUX2 headless suites\r?$') { if ($suiteText) { throw 'Duplicate Full suite logs.' }; $suiteText = $text }
    $verifiedLogs += $path
}
if ($verifiedLogs.Count -ne 3) { throw 'Require exact Full import, suite and boot logs.' }
Assert-PortableFullData $full $suiteText
$verifiedReports = @{}
foreach ($report in @(@('current-state.json', $full.source.current_state_sha256), @('asset-inventory.json', $full.source.asset_inventory_sha256))) {
    $field = if ($report[0] -eq 'current-state.json') { 'current_state_path' } else { 'asset_inventory_path' }
    # Earlier receipts had shared report paths. Preserve their exact hash gate,
    # while new receipts carry durable per-run report locations.
    $path = if ($full.source.PSObject.Properties.Name -contains $field) {
        Resolve-PortablePath $portableRoot $full.source.$field
    } else { Join-Path $portableRoot ('.godot/reports/' + $report[0]) }
    if ((Get-FluxFileSha256 $path) -cne $report[1]) { throw 'Full source/asset report changed or is missing.' }
    $verifiedReports[$report[0]] = $path
}
$fullSourceState = Get-Content -Raw -LiteralPath $verifiedReports['current-state.json'] | ConvertFrom-Json
Assert-PortableRuntimeIdentity $fullSourceState.runtime.build_identity $verifiedRuntimeIdentity
Assert-PortableCaptureData $capture
$captureText = Get-Content -Raw -LiteralPath $captureLog
Assert-PortableCleanText $captureText
if ($captureText -notmatch '(?m)^PASS:' -or -not (Test-Path -LiteralPath "$captureLog.err") -or (Get-Item -LiteralPath "$captureLog.err").Length -ne 0) { throw 'Capture requires a passed log and empty stderr.' }
$capturePass = [regex]::Matches($captureText, '(?m)^PASS:\s*([0-9]+) integrated actual-game frames;')
if ($capturePass.Count -ne 1 -or [int]$capturePass[0].Groups[1].Value -ne @($capture.frames).Count) { throw 'Capture frame count differs from the passed actual-game log.' }
$frameFiles = foreach ($frame in @($capture.frames)) {
    $relative = ([IO.Path]::GetRelativePath($portableRoot, (Join-Path (Split-Path -Parent $capturePath) $frame.file))).Replace('\', '/')
    $path = Resolve-PortablePath $portableRoot $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -eq 0) { throw 'Capture image is missing or empty.' }
    $path
}

# Only now create fresh outputs. A failed run remains diagnosable and cannot be
# retried into the same directories. Existing builds/pointers remain untouched.
New-Item -ItemType Directory -Path $plan.export | Out-Null
New-Item -ItemType Directory -Path $plan.evidence | Out-Null
[IO.File]::WriteAllText((Join-Path $plan.evidence '.gdignore'), '')
$windows = Join-Path $plan.export 'windows'
$release = Join-Path $plan.export 'release'
New-Item -ItemType Directory -Path $windows | Out-Null
$inputs = Join-Path $plan.evidence 'inputs'
New-Item -ItemType Directory -Path $inputs | Out-Null
$captureCopy = Join-Path $inputs 'capture'
New-Item -ItemType Directory -Path $captureCopy | Out-Null
Copy-Item -LiteralPath $fullPath -Destination (Join-Path $inputs 'full-receipt.json')
Copy-Item -LiteralPath $capturePath -Destination (Join-Path $captureCopy 'capture-receipt.json')
Copy-Item -LiteralPath $frameFiles -Destination $captureCopy
Copy-Item -LiteralPath $captureLog -Destination (Join-Path $inputs 'capture.log')
Copy-Item -LiteralPath "$captureLog.err" -Destination (Join-Path $inputs 'capture.log.err')
Copy-Item -LiteralPath $inventoryPath -Destination (Join-Path $inputs 'source-inventory.json')
foreach ($reportName in @('current-state.json', 'asset-inventory.json')) {
    Copy-Item -LiteralPath $verifiedReports[$reportName] -Destination (Join-Path $inputs $reportName)
}
for ($index = 0; $index -lt $verifiedLogs.Count; $index++) {
    Copy-Item -LiteralPath $verifiedLogs[$index] -Destination (Join-Path $inputs "full-$index.log")
    Copy-Item -LiteralPath ($verifiedLogs[$index] + '.err') -Destination (Join-Path $inputs "full-$index.log.err")
}
$exe = Join-Path $windows 'flux2.exe'
$pack = Join-Path $windows 'flux2.pck'
$status = 'failed'
$failure = $null
$savedEnvironment = @{}
foreach ($key in @('APPDATA', 'LOCALAPPDATA', 'FLUX2_TEST_SUITES', 'FLUX2_TEST_MODE')) { $savedEnvironment[$key] = [Environment]::GetEnvironmentVariable($key, 'Process') }
try {
    $godot = Get-FluxGodot
    Assert-FluxExportTemplates 'Windows'
    Invoke-FluxGodotChecked $godot @('--headless', '--path', $portableRoot, '--export-release', 'Windows x86_64', $exe) (Join-Path $plan.evidence 'export.log') -RejectWarnings | Out-Null
    foreach ($path in @($exe, $pack)) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Windows export did not create both executable and external PCK.' } }
    $runtimeLog = Join-Path $plan.evidence 'runtime-pack.log'
    # Same production runtime-state.gd as runtime-state.ps1, with a unique log
    # and a pack-directory path so missing resources cannot use source fallback.
    Invoke-FluxGodotChecked $godot @('--headless', '--main-pack', $pack, '--path', $windows, '--script', 'res://scripts/runtime-state.gd') $runtimeLog -RejectWarnings | Out-Null
    $lines = @(Get-Content -LiteralPath $runtimeLog | Where-Object { $_.StartsWith('FLUX_RUNTIME_STATE=') })
    if ($lines.Count -ne 1) { throw 'Exported PCK must emit exactly one runtime-state record.' }
    $runtime = $lines[0].Substring('FLUX_RUNTIME_STATE='.Length) | ConvertFrom-Json
    if ($runtime.schema_version -ne 1 -or $runtime.runtime.simulation_hz -ne 120 -or $runtime.runtime.protocol -le 0) { throw 'Exported PCK did not prove exact120Hz runtime identity.' }
    Assert-PortableRuntimeIdentity $runtime.runtime.build_identity $verifiedRuntimeIdentity
    Write-PortableJson (Join-Path $windows 'BUILD-STATE.json') ([ordered]@{schema_version = 1; source_kind = 'exported_pack'; pack_sha256 = Get-FluxFileSha256 $pack; state = $runtime})
    $previousWarningPreference = $WarningPreference
    try {
        $WarningPreference = 'Stop'
        & (Join-Path $PSScriptRoot 'bundle-release.ps1') -Target Windows -ExportRoot $plan.export -ReleaseRoot $release | Tee-Object -FilePath (Join-Path $plan.evidence 'bundle.log') | Out-Null
        [IO.File]::WriteAllText((Join-Path $plan.evidence 'bundle.log.err'), '')
    } finally { $WarningPreference = $previousWarningPreference }
    $zip = Join-Path $release 'FLUX2-Windows-x86_64.zip'
    if (-not (Test-Path -LiteralPath $zip -PathType Leaf)) { throw 'Windows portable ZIP is missing.' }
    foreach ($key in @('APPDATA', 'LOCALAPPDATA')) {
        $isolated = Join-Path $plan.evidence ('isolated-' + $key.ToLowerInvariant())
        New-Item -ItemType Directory -Path $isolated | Out-Null
        [Environment]::SetEnvironmentVariable($key, $isolated, 'Process')
    }
    [Environment]::SetEnvironmentVariable('FLUX2_TEST_SUITES', $null, 'Process')
    [Environment]::SetEnvironmentVariable('FLUX2_TEST_MODE', $null, 'Process')
    $bootLog = Join-Path $plan.evidence 'raw-boot.log'
    # Invoke-FluxGodotChecked launches Hidden, bounds the owned process, rejects
    # warnings and errors, and waits for its exit. Crucially no --path here.
    Push-Location -LiteralPath $windows
    try {
        Invoke-FluxGodotChecked $exe @('--headless', '--quit-after', '3', '--fixed-fps', '120', '--', '--tick-rate=120', '--no-lan-discovery') $bootLog -RejectWarnings | Out-Null
    } finally { Pop-Location }
    $boot = Get-Content -Raw -LiteralPath $bootLog
    if ($boot -notmatch 'FLUX2 match initialized at 120 Hz' -or $boot -notmatch ('FLUX2 bootstrap: 120 Hz, protocol ' + [regex]::Escape([string]$runtime.runtime.protocol) + ',')) { throw 'Raw executable did not confirm exact120Hz/current-PCK protocol boot.' }
    foreach ($log in Get-ChildItem -LiteralPath $plan.evidence -Filter '*.log' -File) {
        if (-not (Test-Path -LiteralPath ($log.FullName + '.err')) -or (Get-Item -LiteralPath ($log.FullName + '.err')).Length -ne 0) { throw 'Export/runtime/boot stderr must be empty.' }
    }
    Assert-PortableInventory $frozen @(Get-PortableSourceInventory $portableRoot)
    $payloads = foreach ($path in @($exe, $pack, $zip)) { [ordered]@{path = $path; bytes = (Get-Item -LiteralPath $path).Length; sha256 = Get-FluxFileSha256 $path} }
    Write-PortableJson (Join-Path $plan.evidence 'checkpoint.json') ([ordered]@{
        schema_version = 1; status = 'local_full_export_raw_boot_passed'; build_name = $BuildName
        completed_at_utc = [DateTime]::UtcNow.ToString('o'); full_suites = $full.executed.suite_count
        full_assertions = $full.executed.assertion_count; source_records = $frozen.Count; payloads = @($payloads)
        source_inventory_sha256 = Get-FluxFileSha256 $inventoryPath; full_receipt_sha256 = Get-FluxFileSha256 $fullPath
        source_inventory_scope = 'Actual filesystem, including ignored files: src,content,assets,scenes,addons,scripts,tests; project.godot,export_presets.cfg; packaging/PLAY-FLUX.cmd,packaging/README-FIRST.txt; art_batches/pixel_v1/{magic,map}/{manifest.json,export/**}; art_batches/wellspring_style_v2/runtime/**. Reparse traversal rejected; not entire repository, docs, source art or unrelated packaging files.'
        capture_receipt_sha256 = Get-FluxFileSha256 $capturePath; runtime = $runtime.runtime
        new_installer = 'not_attempted_portable_only'; current_pointer = 'not_changed'; publication = 'not_attempted'
        human_animation_acceptance = 'pending'; friend_network_acceptance = 'pending'; sustained_120fps = 'not_certified'
    })
    $status = 'passed'
} catch { $failure = $_.Exception.Message; throw }
finally {
    foreach ($key in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($key, $savedEnvironment[$key], 'Process') }
    Write-PortableJson (Join-Path $plan.evidence 'attempt.json') ([ordered]@{schema_version = 1; result = $status; failure = $failure; finished_at_utc = [DateTime]::UtcNow.ToString('o'); prior_builds = 'preserved'; environment_restored = $true})
    $evidenceFiles = @(Get-ChildItem -LiteralPath $plan.evidence -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/]isolated-(appdata|localappdata)[\\/]' } | Sort-Object FullName | ForEach-Object {
        [ordered]@{path = [IO.Path]::GetRelativePath($plan.evidence, $_.FullName).Replace('\', '/'); bytes = $_.Length; sha256 = Get-FluxFileSha256 $_.FullName}
    })
    Write-PortableJson (Join-Path $plan.evidence 'evidence-files.json') $evidenceFiles
}
Write-Output "PASS: portable checkpoint $BuildName; see $EvidenceRoot/checkpoint.json. No installer, pointer update or publication."

} finally { Exit-FluxEngineRun $workflowLease }
