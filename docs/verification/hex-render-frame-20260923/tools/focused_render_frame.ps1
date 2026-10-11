$ErrorActionPreference = 'Stop'
if ((Get-Location).Path -ne 'C:\Users\sende\Projects\hex') { throw 'HEX checkout required' }
& ./scripts/test.ps1 -Tier Focused -Suite @('hex-render-frame','hex-court-presenter','hex-shared-presenter','hex-handoff-presentation','hex-water-pilot','hex-whole-coverage','hex-authored-shapes') -ReceiptPath docs/verification/hex-render-frame-20260923/focused-v2.json *> docs/verification/hex-render-frame-20260923/focused-v2.out
