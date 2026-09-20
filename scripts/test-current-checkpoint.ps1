# Exact local identity regressions. Requires every pointer-pinned payload and
# evidence file, including the historical installer; no engine or file writes.
$ErrorActionPreference = 'Stop'
$testRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'current-checkpoint.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }
$functions = @($ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-FluxCheckpointReport'}, $true))
if ($functions.Count -ne 1) { throw 'Expected one independent checkpoint verifier.' }
Invoke-Expression $functions[0].Extent.Text
$original = Get-Content -Raw -LiteralPath (Join-Path $testRoot 'docs/current-checkpoint.json') | ConvertFrom-Json
$assertions = 0
function Assert-Checkpoint([bool]$Condition, [string]$Message) {
    $script:assertions++
    if (-not $Condition) { throw "FAIL: $Message" }
}
function Copy-Pointer { return $original | ConvertTo-Json -Depth 20 | ConvertFrom-Json }
function Reject-Pointer([string]$Name, [scriptblock]$Mutation, [string]$Expected = 'invalid') {
    $candidate = Copy-Pointer
    & $Mutation $candidate
    $result = Get-FluxCheckpointReport $candidate $testRoot
    Assert-Checkpoint (-not $result.passed) "$Name must not claim verified delivery"
    Assert-Checkpoint ($result.status -eq $Expected) "$Name must report $Expected"
    Assert-Checkpoint ($result.issues.Count -gt 0) "$Name must explain its failure"
}
$beforePointerHash = (Get-FileHash -LiteralPath (Join-Path $testRoot 'docs/current-checkpoint.json') -Algorithm SHA256).Hash
$baseline = Get-FluxCheckpointReport $original $testRoot
Assert-Checkpoint $baseline.passed 'Actual pinned current portable and historical installer verify'
Assert-Checkpoint ($baseline.current_portable.kind -eq 'current_portable') 'Current portable remains explicitly identified'
Assert-Checkpoint ($baseline.historical_installer.kind -eq 'historical_installer') 'Old installer remains historical'
Assert-Checkpoint ($baseline.current_portable.checkpoint_id -ne $baseline.historical_installer.checkpoint_id) 'Delivery checkpoints do not silently merge'
Assert-Checkpoint ($baseline.current_portable.files.Count -eq 8 -and $baseline.historical_installer.files.Count -eq 2) 'All ten exact payload/evidence identities are checked'
Assert-Checkpoint ($baseline.current_portable.evidence_summary.full_suites -gt 0 -and $baseline.current_portable.evidence_summary.full_assertions -gt 0) 'Passed Full counts come from matching receipts'
Assert-Checkpoint ($baseline.current_portable.evidence_summary.captures -gt 0) 'Capture count comes from its pinned receipt'
Reject-Pointer 'wrong schema' {param($p) $p.schema_version = 99}
Reject-Pointer 'string schema' {param($p) $p.schema_version = '1'}
Reject-Pointer 'missing current group' {param($p) $p.current = $null}
Reject-Pointer 'old installer promoted by label' {param($p) $p.historical_installer.kind = 'current_portable'}
Reject-Pointer 'wrong payload size' {param($p) $p.current.payloads[0].bytes++}
Reject-Pointer 'wrong same-length payload digest' {param($p) $p.current.payloads[0].sha256 = '0' * 64}
Reject-Pointer 'malformed digest' {param($p) $p.current.payloads[0].sha256 = 'not-a-hash'}
Reject-Pointer 'string byte length' {param($p) $p.current.payloads[0].bytes = [string]$p.current.payloads[0].bytes}
Reject-Pointer 'negative byte length' {param($p) $p.current.payloads[0].bytes = -1}
Reject-Pointer 'fractional byte length' {param($p) $p.current.payloads[0].bytes = 1.5}
Reject-Pointer 'wrong evidence hash' {param($p) $p.current.evidence[0].sha256 = '0' * 64}
Reject-Pointer 'missing required payload role' {param($p) $p.current.payloads = @($p.current.payloads | Select-Object -First 2)}
Reject-Pointer 'duplicated required role' {param($p) $p.current.payloads[1].role = 'game'}
Reject-Pointer 'swapped game and pack role' {param($p) $p.current.payloads[0].role = 'pack'; $p.current.payloads[1].role = 'game'}
Reject-Pointer 'duplicate file under another evidence role' {param($p) $p.current.evidence[1].path = $p.current.evidence[0].path}
Reject-Pointer 'missing local evidence' {param($p) $p.current.evidence[0].path = $p.current.evidence_directory + '/missing-checkpoint-regression-59286.json'} 'unavailable'
Reject-Pointer 'missing local exports' {param($p) $old = $p.current.build_directory; $p.current.build_directory = 'exports/missing-checkpoint-regression-59286'; foreach ($f in $p.current.payloads) { $f.path = $p.current.build_directory + $f.path.Substring($old.Length) }} 'unavailable'
Reject-Pointer 'parent traversal' {param($p) $p.current.payloads[0].path = '../outside.exe'}
Reject-Pointer 'absolute path' {param($p) $p.current.payloads[0].path = 'C:/outside.exe'}
Reject-Pointer 'UNC path' {param($p) $p.current.payloads[0].path = '//server/share/file.exe'}
Reject-Pointer 'backslash path' {param($p) $p.current.payloads[0].path = $p.current.payloads[0].path.Replace('/', '\')}
Reject-Pointer 'alternate data stream' {param($p) $p.current.payloads[0].path += ':alternate'}
Reject-Pointer 'Windows device segment' {param($p) $p.current.payloads[0].path = $p.current.build_directory + '/NUL.exe'}
Reject-Pointer 'trailing-dot alias' {param($p) $p.current.payloads[0].path += '.'}
Reject-Pointer 'wrong directory prefix' {param($p) $p.current.build_directory = 'docs/evidence'}
Reject-Pointer 'sibling directory prefix' {param($p) $p.current.payloads[0].path = $p.current.build_directory + '-other/windows/flux2.exe'}
$after = Get-FluxCheckpointReport $original $testRoot
Assert-Checkpoint $after.passed 'Adversarial descriptor copies did not change pinned files'
Assert-Checkpoint ((Get-FileHash -LiteralPath (Join-Path $testRoot 'docs/current-checkpoint.json') -Algorithm SHA256).Hash -eq $beforePointerHash) 'Pointer bytes remain unchanged'
Write-Output "PASS: checkpoint exact local identity regression, $assertions assertions; actual ten pinned files plus adversarial descriptors; no engine or file writes."
