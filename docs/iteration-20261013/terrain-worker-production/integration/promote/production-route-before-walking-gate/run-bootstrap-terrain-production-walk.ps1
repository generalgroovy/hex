param([ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$')][string]$RunSuffix='a')
$ErrorActionPreference='Stop'
. ./scripts/flux2-common.ps1
$hexSavedRoaming=$env:APPDATA
$hexResults=@()
$hexSummaryPath=Join-Path $PWD ".godot/iteration-20261013/bootstrap-terrain-production-walk-summary-$RunSuffix.json"
if (Test-Path -LiteralPath $hexSummaryPath) { throw "Fresh summary required: $hexSummaryPath" }
try {
    foreach ($hexDestination in @('element-garden','verdant')) {
        $hexBeforeReceipt=''
        foreach ($hexArm in @('before','after')) {
            $hexRun="$hexArm-$hexDestination-$RunSuffix"
            $hexRelative=".godot/iteration-20261013/bootstrap-terrain-production-walk-$hexRun"
            $hexRoaming=Join-Path $PWD ".godot/iteration-20261013/bootstrap-terrain-production-walk-roaming-$hexRun"
            foreach ($hexFresh in @($hexRelative, "$hexRelative.log", "$hexRelative.log.err", $hexRoaming)) {
                if (Test-Path -LiteralPath $hexFresh) { throw "Fresh run required: $hexFresh" }
            }
            $env:APPDATA=$hexRoaming
            $hexData=Join-Path $env:APPDATA 'Godot/app_userdata/FLUX 2'
            $hexArgs=@('--path',"$PWD",'--audio-driver','Dummy','--script','res://.godot/iteration-20261013/compare-bootstrap-terrain-production-walk.gd','--',"--arm=$hexArm","--destination=$hexDestination","--output=res://$hexRelative","--fixture-user-data=$hexData",'--no-lan-discovery','--champion=oh_tipi','--synthetic-application-focus')
            if ($hexArm -eq 'after') { $hexArgs += "--compare=$hexBeforeReceipt" }
            Invoke-FluxGodotChecked -GodotBin (Get-FluxGodot) -Arguments $hexArgs -LogPath (Join-Path $PWD "$hexRelative.log") -TimeoutSeconds 230 -RejectWarnings
            $hexReceipt=Get-Content -LiteralPath "$hexRelative/receipt.json" -Raw | ConvertFrom-Json
            if (-not $hexReceipt.passed -or $hexReceipt.error -ne '' -or -not $hexReceipt.normal_exit -or $hexReceipt.commands.Count -ne 480) { throw "Actual Bootstrap diagnostic receipt failed: $hexRun; $($hexReceipt.error)" }
            if ($hexArm -eq 'after' -and (-not $hexReceipt.injection.production_owner_retained -or $hexReceipt.injection.original_closed -or $hexReceipt.injection.selection -cne 'inherited production kit owner')) { throw "After arm did not retain the actual production owner: $hexRun" }
            foreach ($hexProperty in $hexReceipt.source_hashes.PSObject.Properties) {
                $hexPath=Join-Path $PWD ($hexProperty.Name -replace '^res://','')
                if ((Get-FileHash -LiteralPath $hexPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $hexProperty.Value) { throw "Source drift: $hexPath" }
            }
            $hexResults += [ordered]@{arm=$hexArm;destination=$hexDestination;passed=$true;checks=$hexReceipt.checks;receipt="$hexRelative/receipt.json";sha256=(Get-FileHash -LiteralPath "$hexRelative/receipt.json" -Algorithm SHA256).Hash.ToLowerInvariant();paused_rows=$hexReceipt.paused_rows;process_rows=$hexReceipt.processes.Count;synthetic_application_focus=$hexReceipt.synthetic_application_focus}
            if ($hexArm -eq 'before') { $hexBeforeReceipt="res://$hexRelative/receipt.json" }
            Write-Output "Verified actual Bootstrap $hexArm/$hexDestination : $($hexReceipt.checks) checks, $($hexReceipt.paused_rows) paused rows."
        }
    }
    $hexSummaryText=([ordered]@{schema='hex.bootstrap-terrain-production-walk-root.v1';passed=$true;cases=$hexResults;scope='Actual production kit owner retained in after; before uses the exact idle original-stream control. Explicit synthetic application focus and tick-scheduled real InputRouter actions. Not human, foreground, FPS or physical-input latency acceptance.'} | ConvertTo-Json -Depth 8) + [Environment]::NewLine
    $hexSummaryBytes=[Text.UTF8Encoding]::new($false).GetBytes($hexSummaryText)
    $hexSummaryFile=[IO.File]::Open($hexSummaryPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
    try { $hexSummaryFile.Write($hexSummaryBytes,0,$hexSummaryBytes.Length); $hexSummaryFile.Flush($true) } finally { $hexSummaryFile.Dispose() }
    if ([IO.File]::ReadAllText($hexSummaryPath) -cne $hexSummaryText) { throw 'Production route summary read-back differs.' }
} finally { $env:APPDATA=$hexSavedRoaming }
