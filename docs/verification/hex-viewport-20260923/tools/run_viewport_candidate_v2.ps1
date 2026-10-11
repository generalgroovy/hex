$ErrorActionPreference = 'Stop'
if ((Get-Location).Path -ne 'C:\Users\sende\Projects\hex') { throw 'HEX checkout required' }
python .godot/preserve_viewport_candidate.py audit
if ($LASTEXITCODE -ne 0) { throw 'Protected baseline changed' }
if (-not (Test-Path -LiteralPath 'docs/verification/hex-viewport-20260923/attempts/v2/freeze.json')) { throw 'Reviewed source freeze required' }
try {
    & ./scripts/probe-hex.ps1 -RunId viewport-v2 -Script res://tests/performance/profile_hex_viewport_candidate.gd -Rendered -Output res://.godot/hex-viewport-candidate-v2.json *> docs/verification/hex-viewport-20260923/probe-v2.out
    Write-Output 'D8 native probe completed; inspect exact pixel and timing receipts separately'
} finally {
    python .godot/preserve_viewport_candidate.py curate --attempt v2
    if ($LASTEXITCODE -ne 0) { throw 'D8 evidence preservation failed' }
}

