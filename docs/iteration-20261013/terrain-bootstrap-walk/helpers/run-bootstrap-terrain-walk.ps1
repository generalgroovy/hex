param([string]$RunSuffix='b')
$ErrorActionPreference='Stop'
. ./scripts/flux2-common.ps1
$hexSavedRoaming=$env:APPDATA
$hexResults=@()
try {
    foreach ($hexDestination in @('element-garden','verdant')) {
        $hexBeforeReceipt=''
        foreach ($hexArm in @('before','after')) {
            $hexRun="$hexArm-$hexDestination-$RunSuffix"
            $hexRelative=".godot/iteration-20261013/bootstrap-terrain-walk-$hexRun"
            if (Test-Path -LiteralPath $hexRelative) { throw "Fresh run required: $hexRelative" }
            $env:APPDATA=Join-Path $PWD ".godot/iteration-20261013/bootstrap-terrain-walk-roaming-$hexRun"
            $hexData=Join-Path $env:APPDATA 'Godot/app_userdata/FLUX 2'
            $hexArgs=@('--path',"$PWD",'--audio-driver','Dummy','--script','res://.godot/iteration-20261013/compare-bootstrap-terrain-walk.gd','--',"--arm=$hexArm","--destination=$hexDestination","--output=res://$hexRelative","--fixture-user-data=$hexData",'--no-lan-discovery','--champion=oh_tipi','--synthetic-application-focus')
            if ($hexArm -eq 'after') { $hexArgs += "--compare=$hexBeforeReceipt" }
            Invoke-FluxGodotChecked -GodotBin (Get-FluxGodot) -Arguments $hexArgs -LogPath (Join-Path $PWD "$hexRelative.log") -TimeoutSeconds 230 -RejectWarnings
            $hexReceipt=Get-Content -LiteralPath "$hexRelative/receipt.json" -Raw | ConvertFrom-Json
            if (-not $hexReceipt.passed -or $hexReceipt.error -ne '' -or -not $hexReceipt.normal_exit -or $hexReceipt.commands.Count -ne 480) { throw "Actual Bootstrap diagnostic receipt failed: $hexRun; $($hexReceipt.error)" }
            foreach ($hexProperty in $hexReceipt.source_hashes.PSObject.Properties) {
                $hexPath=Join-Path $PWD ($hexProperty.Name -replace '^res://','')
                if ((Get-FileHash -LiteralPath $hexPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $hexProperty.Value) { throw "Source drift: $hexPath" }
            }
            $hexResults += [ordered]@{arm=$hexArm;destination=$hexDestination;passed=$true;checks=$hexReceipt.checks;receipt="$hexRelative/receipt.json";sha256=(Get-FileHash -LiteralPath "$hexRelative/receipt.json" -Algorithm SHA256).Hash.ToLowerInvariant();paused_rows=$hexReceipt.paused_rows;process_rows=$hexReceipt.processes.Count;synthetic_application_focus=$hexReceipt.synthetic_application_focus}
            if ($hexArm -eq 'before') { $hexBeforeReceipt="res://$hexRelative/receipt.json" }
            Write-Output "Verified actual Bootstrap $hexArm/$hexDestination : $($hexReceipt.checks) checks, $($hexReceipt.paused_rows) paused rows."
        }
    }
    [ordered]@{schema='hex.bootstrap-terrain-walk-root.v1';passed=$true;cases=$hexResults;scope='Actual Bootstrap with explicit synthetic application focus and tick-scheduled real InputRouter actions. Not human, foreground, FPS or physical-input latency acceptance.'} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath ".godot/iteration-20261013/bootstrap-terrain-walk-summary-$RunSuffix.json" -Encoding utf8
} finally { $env:APPDATA=$hexSavedRoaming }
