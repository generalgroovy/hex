$ErrorActionPreference = 'Stop'
. ./scripts/flux2-common.ps1
$hexSavedRoaming = $env:APPDATA
$hexResults = @()
try {
    foreach ($hexCase in @('normal','failure','io')) {
        $hexRun = "$hexCase-$([guid]::NewGuid().ToString('N'))"
        $hexRelative = ".godot/iteration-20261013/t7-cleanup-runs/$hexRun"
        $hexLog = Join-Path $PWD ".godot/iteration-20261013/t7-cleanup-$hexRun.log"
        $env:APPDATA = Join-Path $PWD ".godot/iteration-20261013/t7-cleanup-roaming/$hexRun"
        $hexArgs = @('--path',"$PWD",'--audio-driver','Dummy','--script','res://.godot/iteration-20261013/verify-completed-stage-cleanup.gd','--',"--cleanup-case=$hexCase","--cleanup-directory=res://$hexRelative",'--no-lan-discovery')
        $hexQuoted = $hexArgs | ForEach-Object { '"' + $_.Replace('"','\"') + '"' }
        $hexLease = Enter-FluxEngineRun 't7-expected-cleanup-failure'
        $hexProcess = $null
        try {
            $hexProcess = Start-FluxOwnedProcess @{ FilePath=(Get-FluxGodot); ArgumentList=$hexQuoted; WindowStyle='Hidden'; RedirectStandardOutput=$hexLog; RedirectStandardError="$hexLog.err" }
            if (-not $hexProcess.WaitForExit(90000)) { throw "Owned T7 process timed out: $hexRun" }
            $hexProcess.WaitForExit()
            $hexProcess.Refresh()
            $hexReceiptPath = Join-Path $PWD "$hexRelative/receipt.json"
            $hexReceipt = Get-Content -LiteralPath $hexReceiptPath -Raw | ConvertFrom-Json
            if (-not $hexReceipt.passed -or $hexReceipt.errors.Count -ne 0) { throw "Cleanup receipt failed: $hexReceiptPath" }
            $hexExpectedExit = if ($hexCase -eq 'normal') { 0 } else { 1 }
            if ($null -eq $hexProcess.ExitCode -or [int]$hexProcess.ExitCode -ne $hexExpectedExit) { throw "Unexpected exit code for $hexCase : $($hexProcess.ExitCode)" }
            $hexErr = Get-Content -LiteralPath "$hexLog.err" -Raw
            $hexOut = Get-Content -LiteralPath $hexLog -Raw
            $hexHeadings = @([regex]::Matches(($hexOut + "`n" + $hexErr),'(?m)^(?:ERROR:|WARNING:|SCRIPT ERROR|Parse Error|Compile Error|FAIL:).*$') | ForEach-Object {$_.Value.Trim()})
            if ($hexCase -eq 'normal') {
                if (-not [string]::IsNullOrWhiteSpace($hexErr) -or $hexHeadings.Count -ne 0) { throw 'Unexpected normal cleanup stderr or diagnostics.' }
            } else {
                if ($hexHeadings.Count -ne 1 -or $hexHeadings[0] -cne ('ERROR: ' + $hexReceipt.expected_error_text)) { throw "Unexpected error diagnostics for $hexCase : $($hexHeadings -join ', ')" }
                if ($hexErr -match '(?i)leaked|orphan|Invalid call|Failed to load|ObjectDB instances') { throw 'Unexpected teardown/script diagnostics.' }
            }
            foreach ($hexProperty in $hexReceipt.sources.PSObject.Properties) {
                $hexSourcePath = Join-Path $PWD ($hexProperty.Name -replace '^res://','')
                if ((Get-FileHash -LiteralPath $hexSourcePath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $hexProperty.Value) { throw "Source drift: $hexSourcePath" }
            }
            $hexResults += [ordered]@{case=$hexCase;passed=$true;exit_code=$hexProcess.ExitCode;checks=$hexReceipt.checks;receipt=$hexReceiptPath;receipt_sha256=(Get-FileHash -LiteralPath $hexReceiptPath -Algorithm SHA256).Hash.ToLowerInvariant();log=$hexLog;stderr="$hexLog.err";expected_error=$hexReceipt.expected_error_text}
            Write-Output "T7 cleanup $hexCase : $($hexReceipt.checks) checks; expected exit $hexExpectedExit; passed"
        } finally {
            try { if ($null -ne $hexProcess -and -not $hexProcess.HasExited) {$hexProcess.Kill();$hexProcess.WaitForExit()} }
            finally { Exit-FluxEngineRun $hexLease }
        }
    }
    $hexSummary = [ordered]@{schema='hex.t7-cleanup-root-verification.v1';passed=$true;cases=$hexResults;scope='Three native actual enclosing profiler cleanup paths. Expected failure exits/errors are exact, independently checked against receipt; no application foreground or close claim.'}
    $hexSummary | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath '.godot/iteration-20261013/t7-cleanup-summary.json' -Encoding utf8
} finally { $env:APPDATA = $hexSavedRoaming }
