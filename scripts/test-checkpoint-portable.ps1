# Source-level only: extract pure validators from the builder AST. Never dot
# source its executable body; no Godot/export/bundler/EXE launch or file writes.
$ErrorActionPreference = 'Stop'
$portableTestRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$portableScriptPath = Join-Path $PSScriptRoot 'checkpoint-portable.ps1'
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($portableScriptPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }
$needed = @('Assert-PortableRuntimeIdentity', 'Resolve-PortablePath', 'Assert-PortableFreshPlan', 'Assert-PortableCleanText', 'Test-PortableInteger', 'Convert-PortableUtcInstant', 'Assert-PortableFullData', 'Assert-PortableInventory', 'Assert-PortableCaptureData', 'Test-PortableInventoryMember')
foreach ($name in $needed) {
    $definitions = @($ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name}, $true))
    if ($definitions.Count -ne 1) { throw "Expected one validator $name" }
    Invoke-Expression $definitions[0].Extent.Text
}
$assertions = 0
function Check([bool]$Condition, [string]$Message) {
    $script:assertions++
    if (-not $Condition) { throw "FAIL: $Message" }
}
function Reject([string]$Label, [scriptblock]$Action) {
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    Check $rejected $Label
}
$expectedIdentity = [pscustomobject]@{build_id='p48-aaaaaaaaaaaa';runtime_source_sha256=('a' * 64);protocol_version=48;snapshot_schema=18;engine_identity='4.7.1.stable.official.a13da4feb';record_count=12}
Assert-PortableRuntimeIdentity $expectedIdentity $expectedIdentity
Check $true 'Exact Full/source/PCK runtime identities agree'
Reject 'Missing identity cannot inherit an earlier Full or pack claim' { Assert-PortableRuntimeIdentity $null $expectedIdentity }
foreach ($field in $expectedIdentity.PSObject.Properties.Name) {
    $changedIdentity = $expectedIdentity | ConvertTo-Json | ConvertFrom-Json
    $changedIdentity.$field = 'changed'
    Reject "Drifted Full or PCK identity fails: $field" { Assert-PortableRuntimeIdentity $changedIdentity $expectedIdentity }
}
$expectedInstant = [DateTime]::new(2026, 9, 9, 14, 34, 44, [DateTimeKind]::Utc)
$jsonInstant = ('{"completed_at_utc":"2026-09-09T14:34:44Z"}' | ConvertFrom-Json).completed_at_utc
foreach ($value in @($expectedInstant, $expectedInstant.ToLocalTime(), $jsonInstant,
    [DateTimeOffset]::new($expectedInstant).ToOffset([TimeSpan]::FromHours(2)),
    '2026-09-09T14:34:44Z', '2026-09-09T16:34:44+02:00', '2026-09-09T09:34:44-05:00')) {
    $actualInstant = Convert-PortableUtcInstant $value
    Check ($actualInstant.Kind -eq [DateTimeKind]::Utc -and $actualInstant.Ticks -eq $expectedInstant.Ticks) 'Typed UTC/local/offset and explicit ISO timestamps preserve the exact same UTC instant'
    $started = $actualInstant.AddMilliseconds(-107772)
    $frozenAt = [DateTime]::new(2026, 9, 9, 14, 32, 55, [DateTimeKind]::Utc)
    Check ($frozenAt -le $started) 'Actual reported freeze precedes Full start without a timezone shift'
}
$fractional = Convert-PortableUtcInstant '2026-09-09T14:34:44.1234567Z'
Check ($fractional.Ticks -eq $expectedInstant.Ticks + 1234567) 'ISO fractional ticks are retained without precision loss'
foreach ($value in @([DateTime]::SpecifyKind($expectedInstant, [DateTimeKind]::Unspecified), '2026-09-09T14:34:44', '09/09/2026 14:34:44', '2026-09-09T14:34:44+25:00', 123, $null)) { Reject 'Ambiguous/invalid timestamp fails closed' { Convert-PortableUtcInstant $value } }
$full = Get-Content -LiteralPath (Join-Path $portableTestRoot 'docs/evidence/warm-style-trails-v1/full-receipt.json') -Raw | ConvertFrom-Json
$suiteText = Get-Content -LiteralPath (Join-Path $portableTestRoot 'docs/evidence/warm-style-trails-v1/suite.log') -Raw
Assert-PortableFullData $full $suiteText
Check $true 'Historical complete Full receipt/log validates structurally, not as current-source freshness'
foreach ($mutation in @(
    {param($x) $x.tier = 'focused'}, {param($x) $x.result = 'failed'}, {param($x) $x.schema_version = '1'},
    {param($x) $x.requested_suite_ids = @('combat')}, {param($x) $x.stderr_bytes = 1}, {param($x) $x.failure = 'oops'},
    {param($x) $x.executed.suite_count = 93}, {param($x) $x.executed.assertion_count++},
    {param($x) $x.executed.suites[0].failures = 1}, {param($x) $x.executed.suites[0].assertions = '113'},
    {param($x) $x.executed.suites[1].id = $x.executed.suites[0].id}, {param($x) $x.executed.import = $false},
    {param($x) $x.executed.boot_120_hz = $false}, {param($x) $x.executed.package_and_installer = $true}
    {param($x) $x.executed.suite_count = '94'}, {param($x) $x.stderr_bytes = '0'}, {param($x) $x.executed.suites[0].failures = $false},
    {param($x) $x.duration_ms = -1}, {param($x) $x.executed.suites[0].assertions = 1.5}
)) {
    $bad = $full | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    & $mutation $bad
    Reject 'Mutated Full gate fails closed' { Assert-PortableFullData $bad $suiteText }
}
Reject 'Filtered runner log cannot pass Full' { Assert-PortableFullData $full ($suiteText.Replace('PASS: all FLUX2 headless suites', 'PASS: 94 selected FLUX2 headless suites')) }
foreach ($badLog in @('', 'ERROR: triangulation', 'WARNING: import drift', 'SCRIPT ERROR: broken', 'FAIL: test', 'Compile Error')) { Reject 'Empty/error/warning log rejected' { Assert-PortableCleanText $badLog } }
$freshName = 'portable-source-test-' + [guid]::NewGuid().ToString('N')
$plan = Assert-PortableFreshPlan $portableTestRoot $freshName "exports/$freshName" "docs/evidence/$freshName"
Check (-not (Test-Path -LiteralPath $plan.export) -and -not (Test-Path -LiteralPath $plan.evidence)) 'Planning does not create output directories'
foreach ($badPath in @('../escape', '/absolute', 'C:/absolute', 'exports/../escape', 'exports/NUL.exe', 'exports/a:ads', 'exports/a.', 'exports/a ', 'exports\\x', 'exports-sibling/x')) {
    Reject 'Unsafe or out-of-prefix destination rejected' { Resolve-PortablePath $portableTestRoot $badPath 'exports' }
}
Reject 'Existing evidence remains immutable' { Assert-PortableFreshPlan $portableTestRoot 'warm-style-trails-v1' 'exports/warm-style-trails-v1' 'docs/evidence/warm-style-trails-v1' }
Reject 'Mismatch between explicit name and path rejected' { Assert-PortableFreshPlan $portableTestRoot 'good-name' 'exports/other-name' 'docs/evidence/good-name' }
$row = [pscustomobject]@{file = 'src/example.gd'; bytes = 3; sha256 = 'a' * 64}
Assert-PortableInventory @($row) @($row)
Check $true 'Exact source identity compares without mutation'
Reject 'Added runtime file invalidates frozen membership' { Assert-PortableInventory @($row) @($row, $row) }
Reject 'Removed runtime file invalidates frozen membership' { Assert-PortableInventory @($row) @() }
foreach ($field in @('file', 'bytes', 'sha256')) {
    $bad = $row | ConvertTo-Json | ConvertFrom-Json
    $bad.$field = if ($field -eq 'bytes') { 4 } elseif ($field -eq 'sha256') { 'b' * 64 } else { 'src/new.gd' }
    Reject 'Changed source record invalidates freeze' { Assert-PortableInventory @($row) @($bad) }
}
foreach ($included in @('src/new.gd', 'scripts/checkpoint-portable.ps1', 'tests/new.gd', 'assets/a.png', 'project.godot', 'export_presets.cfg', 'packaging/PLAY-FLUX.cmd', 'packaging/README-FIRST.txt', 'art_batches/pixel_v1/magic/manifest.json', 'art_batches/pixel_v1/map/export/terrain/atlas.png', 'art_batches/wellspring_style_v2/runtime/terrain.png')) { Check (Test-PortableInventoryMember $included) 'Runtime/test/shipped portable membership is included' }
foreach ($excluded in @('docs/evidence/result.json', 'docs/README.md', 'art_batches/pixel_v1/magic/source/editable.json', 'art_batches/pixel_v1/map/previews/a.png', 'art_batches/character_style_v1/candidate.png', 'exports/a.exe', '.godot/imported/a.ctex', 'packaging/play-flux.sh')) { Check (-not (Test-PortableInventoryMember $excluded)) 'Non-runtime evidence/source art is explicitly out of scope' }
$capture = Get-Content -LiteralPath (Join-Path $portableTestRoot 'docs/evidence/warm-style-trails-v1/actual-game/capture-receipt.json') -Raw | ConvertFrom-Json
Assert-PortableCaptureData $capture
Check $true 'Actual-game capture schema validates, without claiming current-source freshness'
foreach ($mutation in @({param($x) $x.authority_unchanged_by_draw = $false}, {param($x) $x.network = 'started'}, {param($x) $x.frames = @()}, {param($x) $x.frames[0].file = '../outside.png'}, {param($x) $x.frames[0].world_hash = ''}, {param($x) $x.frames[0].footprint_audit.invalid_parts = @('bad')})) {
    $bad = $capture | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    & $mutation $bad
    Reject 'Malformed/non-passing capture rejected' { Assert-PortableCaptureData $bad }
}
$source = Get-Content -LiteralPath $portableScriptPath -Raw
Check (-not $source.Contains('build-windows-bootstrap.ps1') -and -not $source.Contains('package.ps1') -and -not $source.Contains('test-windows-bootstrap.ps1')) 'Builder cannot invoke the installer workflow'
Check ($source.Contains("-Target Windows -ExportRoot") -and $source.Contains("'--export-release', 'Windows x86_64'")) 'Only the exact Windows export and portable bundler are wired'
$rawCall = @($ast.FindAll({param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Invoke-FluxGodotChecked' -and $node.CommandElements[1].Extent.Text -ceq '$exe'}, $true))
Check ($rawCall.Count -eq 1) 'One bounded raw executable smoke is wired'
Check (-not $rawCall[0].Extent.Text.Contains('--path') -and $rawCall[0].Extent.Text.Contains('--headless') -and $rawCall[0].Extent.Text.Contains('--tick-rate=120') -and $rawCall[0].Extent.Text.Contains('--no-lan-discovery') -and $rawCall[0].Extent.Text.Contains('-RejectWarnings')) 'Raw executable smoke is no-source-path, headless,120Hz,noLAN,strict'
Check ($source.Contains("foreach (`$key in `$savedEnvironment.Keys)") -and $source.Contains('finally { Pop-Location }')) 'Environment and working directory have restoration paths'
$inventoryDefinition = @($ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-PortableSourceInventory'}, $true))[0].Extent.Text
Check (-not $inventoryDefinition.Contains('ls-files') -and $inventoryDefinition.Contains('Get-ChildItem -LiteralPath') -and $inventoryDefinition.Contains('-Force')) 'Filesystem inventory includes ignored and hidden source files instead of Git-filtered membership'
Check ($inventoryDefinition.IndexOf('[IO.FileAttributes]::ReparsePoint') -lt $inventoryDefinition.IndexOf('$pending.Push($entry.FullName)')) 'Reparse entries are rejected before any directory traversal'
foreach ($payloadInput in @('packaging/PLAY-FLUX.cmd', 'packaging/README-FIRST.txt', 'art_batches/wellspring_style_v2/ground_style.gd')) {
    Check ($inventoryDefinition.Contains("'$payloadInput'")) 'Both shipped launcher/text inputs are explicitly enumerated, not just admitted by the scope predicate'
    $originalInput = [pscustomobject]@{file = $payloadInput; bytes = 3; sha256 = 'a' * 64}
    $changedInput = [pscustomobject]@{file = $payloadInput; bytes = 3; sha256 = 'b' * 64}
    Reject 'Same-length shipped launcher/text drift invalidates the freeze' { Assert-PortableInventory @($originalInput) @($changedInput) }
}
Write-Output "PASS: portable builder source-only regression, $assertions assertions; no engine, export, executable, installer or file writes."
