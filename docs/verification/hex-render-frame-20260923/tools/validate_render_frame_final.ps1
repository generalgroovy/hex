$ErrorActionPreference = 'Stop'
if ((Get-Location).Path -ne 'C:\Users\sende\Projects\hex') { throw 'HEX checkout required' }
$frameEvidence = 'docs/verification/hex-render-frame-20260923'
& ./scripts/runtime-build-identity.ps1 -Mode Check *> "$frameEvidence/identity-check.out"
python .godot/freeze_render_frame.py
if ($LASTEXITCODE -ne 0) { throw 'Source freeze failed' }
& ./scripts/test.ps1 -Tier Full -ReceiptPath "$frameEvidence/full-v1.json" *> "$frameEvidence/full-v1.out"
Write-Output 'PASS: frozen Full integration gate'
& ./scripts/probe-hex.ps1 -RunId render-frame-draw-v1 -Script res://tests/performance/profile_hex_draw_components.gd -Rendered -Output res://.godot/hex-draw-components-render-frame-v1.json *> "$frameEvidence/draw-components-v1.out"
python .godot/check_render_frame_pixels.py
if ($LASTEXITCODE -ne 0) { throw 'Integrated baseline pixel comparison failed' }
Write-Output 'PASS: integrated native capture and preserved-baseline pixels'
& ./scripts/probe-hex.ps1 -RunId render-frame-stress-v1 -Script res://tests/performance/profile_unified_wellspring_rendered.gd -Rendered -Output res://.godot/unified-wellspring-render-profile-render-frame-v1.json *> "$frameEvidence/rendered-stress-v1.out"
Write-Output 'COMPLETE: evolving stress correctness profile; inspect timing misses separately'
& ./.godot/validate_render_frame_package.ps1
Write-Output 'PASS: final Windows functional validation; capacity and human gates remain separate'
