# Pure admission/capture-parser controls. No engines, payload access or writes.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$tokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'verify-launcher-lifecycle.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }
foreach ($name in @('Get-HexLifecycleRequest','Assert-HexLifecyclePackageIdentity','Get-HexLifecycleCastSummary','Assert-HexLifecycleCasts')) {
    $definitions = @($ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name}, $true))
    if ($definitions.Count -ne 1) { throw "Expected one lifecycle function $name" }
    Invoke-Expression $definitions[0].Extent.Text
}
$checks = 0
function Check-Lifecycle([bool]$Condition, [string]$Label) { $script:checks++; if (-not $Condition) { throw "FAIL: $Label" } }
function Reject-Lifecycle([string]$Label, [scriptblock]$Action) {
    $rejected=$false; try { & $Action | Out-Null } catch { $rejected=$true }
    Check-Lifecycle $rejected $Label
}
function Clone-Lifecycle([object]$Value) { return ($Value | ConvertTo-Json -Depth 12 | ConvertFrom-Json) }
$testRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$pointer = [pscustomobject]@{schema_version=1;qualified_build_id='p61-abcdef012345';launcher='exports/hex-qualified/windows/PLAY-HEX.cmd'}
$request = Get-HexLifecycleRequest $testRoot $pointer '' ''
Check-Lifecycle ($request.kind -ceq 'qualified_portable' -and $request.expected_build_id -ceq $pointer.qualified_build_id -and $request.receipt_relative -ceq 'exports/hex-qualified/receipt.json') 'Default derives only the qualified package'
$request = Get-HexLifecycleRequest $testRoot $pointer 'exports/hex-candidate/receipt.json' ('b'*64)
Check-Lifecycle ($request.kind -ceq 'explicit_candidate_package' -and $request.expected_build_id -ceq '' -and $request.qualified_default -ceq $pointer.qualified_build_id -and $request.receipt_pin -ceq ('b'*64)) 'Explicit pinned candidate preserves the qualified default'
foreach ($bad in @('../outside/receipt.json','exports/receipt.json','exports/hex-candidate/windows/hex.exe','exports/hex-candidate/nested/receipt.json','docs/receipt.json')) {
    Reject-Lifecycle "Reject non-package candidate $bad" { Get-HexLifecycleRequest $testRoot $pointer $bad ('b'*64) }
}
Reject-Lifecycle 'Candidate needs a pin' { Get-HexLifecycleRequest $testRoot $pointer 'exports/hex-candidate/receipt.json' '' }
Reject-Lifecycle 'Orphan pin is rejected' { Get-HexLifecycleRequest $testRoot $pointer '' ('b'*64) }
Reject-Lifecycle 'Malformed hash is rejected' { Get-HexLifecycleRequest $testRoot $pointer 'exports/hex-candidate/receipt.json' 'passed' }
$badPointer=Clone-Lifecycle $pointer; $badPointer.schema_version=$true
Reject-Lifecycle 'Boolean schema is rejected' { Get-HexLifecycleRequest $testRoot $badPointer '' '' }
$sourceHash='abcdef012345'+('c'*52); $packHash='d'*64
$package=[pscustomobject]@{status='passed';build_id='p61-abcdef012345';runtime_source_sha256=$sourceHash;pack_sha256=$packHash}
$identity=[pscustomobject]@{schema_version=1;scope_id='production-runtime-source-v1';build_id=$package.build_id;runtime_source_sha256=$sourceHash;protocol_version=61;snapshot_schema=24;record_count=3444;engine_identity='4.7.1.stable.official.a13da4feb'}
$loaded=[pscustomobject]@{source_kind='exported_pack';pack_sha256=$packHash;state=[pscustomobject]@{runtime=[pscustomobject]@{build_identity=(Clone-Lifecycle $identity)}}}
Assert-HexLifecyclePackageIdentity $package $identity $loaded $package.build_id
Check-Lifecycle $true 'Receipt, exported source stamp and loaded-pack state agree'
Reject-Lifecycle 'Qualified ID cannot silently change' { Assert-HexLifecyclePackageIdentity $package $identity $loaded 'p61-000000000000' }
foreach ($change in @(@{field='status';value='failed'},@{field='runtime_source_sha256';value=('e'*64)},@{field='build_id';value='candidate'})) {
    $bad=Clone-Lifecycle $package; $bad.($change.field)=$change.value
    Reject-Lifecycle "Package rejects $($change.field) drift" { Assert-HexLifecyclePackageIdentity $bad $identity $loaded '' }
}
$bad=Clone-Lifecycle $identity; $bad.runtime_source_sha256='f'*64
Reject-Lifecycle 'Detached source stamp cannot identify a different runtime' { Assert-HexLifecyclePackageIdentity $package $bad $loaded '' }
$bad=Clone-Lifecycle $loaded; $bad.pack_sha256='e'*64
Reject-Lifecycle 'Loaded pack hash must match receipt' { Assert-HexLifecyclePackageIdentity $package $identity $bad '' }
$bad=Clone-Lifecycle $loaded; $bad.state.runtime.build_identity.record_count++
Reject-Lifecycle 'Loaded identity record count must agree' { Assert-HexLifecyclePackageIdentity $package $identity $bad '' }
$lines=@()
for($i=0;$i -lt 12;$i++) {
    $lines += 'FLUX2 spell capture: tick '+($i*2+1)+' pending 145/8 projectiles 0 fields 0 events [{"entity_id":1,"type":"cast_started","wire_id":145}]'
    $lines += 'FLUX2 spell capture: tick '+($i*2+2)+' pending 0/0 projectiles 1 fields 0 events [{"owner_id":1,"projectile_id":'+(1000+$i)+',"type":"projectile_spawned","wire_id":145}]'
}
$summary=Get-HexLifecycleCastSummary $lines
Assert-HexLifecycleCasts $summary 145
Check-Lifecycle ($summary.capture_rows -eq 24 -and $summary.starts.Count -eq 12 -and $summary.releases.Count -eq 12) 'Twelve exact ordinary starts and distinct releases accepted'
Assert-HexLifecycleCasts (Get-HexLifecycleCastSummary @('Godot header')) 0
Check-Lifecycle $true 'Idle route admits no cast outcomes'
Reject-Lifecycle 'Idle route rejects a start' { Assert-HexLifecycleCasts $summary 0 }
Reject-Lifecycle 'Foreign wire cannot satisfy target counts' { Assert-HexLifecycleCasts $summary 1319 }
Reject-Lifecycle 'Incomplete workload is rejected' { Assert-HexLifecycleCasts (Get-HexLifecycleCastSummary $lines[0..21]) 145 }
Reject-Lifecycle 'Refusal is not an accepted attempt' { Assert-HexLifecycleCasts (Get-HexLifecycleCastSummary ($lines+@('FLUX2 spell capture: tick 25 pending 0/0 projectiles 0 fields 0 events [{"type":"cast_refused","wire_id":145}]'))) 145 }
Reject-Lifecycle 'Thirteenth admission is rejected' { Assert-HexLifecycleCasts (Get-HexLifecycleCastSummary ($lines+@('FLUX2 spell capture: tick 25 pending 145/8 projectiles 0 fields 0 events [{"type":"cast_started","wire_id":145}]'))) 145 }
Reject-Lifecycle 'Malformed capture prefix is not ignored' { Get-HexLifecycleCastSummary @('FLUX2 spell capture: malformed') }
Reject-Lifecycle 'Duplicate ticks are rejected' { Get-HexLifecycleCastSummary @($lines[0],$lines[0]) }
Reject-Lifecycle 'Backward ticks are rejected' { Get-HexLifecycleCastSummary @($lines[1],$lines[0]) }
Reject-Lifecycle 'Boolean wire is rejected' { Get-HexLifecycleCastSummary @($lines[0].Replace('"wire_id":145','"wire_id":true')) }
Reject-Lifecycle 'Missing wire is rejected' { Get-HexLifecycleCastSummary @($lines[0].Replace(',"wire_id":145','')) }
$duplicate=@($lines); $duplicate[-1]=$duplicate[-1].Replace('1011','1000')
Reject-Lifecycle 'Duplicate projectile release is rejected' { Assert-HexLifecycleCasts (Get-HexLifecycleCastSummary $duplicate) 145 }
Write-Output "PASS: $checks pure launcher lifecycle assertions; no engine or payload launched."
