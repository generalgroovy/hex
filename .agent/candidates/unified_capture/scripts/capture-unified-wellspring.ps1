param([Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$RunId)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')

$uwLease = Enter-FluxEngineRun 'capture-unified-wellspring'
$uwSavedRoaming = $env:APPDATA
$uwRepo = Get-FluxRepoRoot
$uwOutput = Join-Path $uwRepo ".godot/unified-wellspring-$RunId"
$uwLogs = Join-Path $uwRepo ".godot/unified-wellspring-$RunId-logs"
$uwPersonal = Join-Path $uwSavedRoaming 'Godot/app_userdata/FLUX 2/player_preferences_v1.json'
$uwProfileBefore = if (Test-Path -LiteralPath $uwPersonal -PathType Leaf) { Get-FluxFileSha256 $uwPersonal } else { '' }

try {
    if ((Test-Path -LiteralPath $uwOutput) -or (Test-Path -LiteralPath $uwLogs)) {
        throw 'Fresh capture RunId required'
    }
    New-Item -ItemType Directory -Path $uwLogs | Out-Null
    $env:APPDATA = Join-Path $uwLogs 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    & (Join-Path $PSScriptRoot 'runtime-build-identity.ps1') -Mode Check -Json | Set-Content -LiteralPath (Join-Path $uwLogs 'identity.json')

    $uwGodot = Get-FluxGodot
    Invoke-FluxGodotChecked $uwGodot @(
        '--path', $uwRepo,
        '--windowed', '--resolution', '1280x720', '--fixed-fps', '120',
        '--script', 'res://tests/visual/capture_unified_wellspring.gd',
        '--', "--output=res://.godot/unified-wellspring-$RunId", '--tick-rate=120', '--no-lan-discovery'
    ) (Join-Path $uwLogs 'capture.log') -TimeoutSeconds 240

    $uwReceiptPath = Join-Path $uwOutput 'capture-receipt.json'
    if (-not (Test-Path -LiteralPath $uwReceiptPath -PathType Leaf)) {
        throw 'Unified Wellspring capture did not write its receipt.'
    }
    $uwReceipt = Get-Content -LiteralPath $uwReceiptPath -Raw | ConvertFrom-Json
    if ([int]$uwReceipt.schema -ne 1 -or [string]$uwReceipt.status -cne 'passed') {
        throw 'Unified Wellspring receipt schema or status is invalid.'
    }
    if ($uwReceipt.display.headless -or -not $uwReceipt.display.visible_window -or [string]$uwReceipt.display.server -ceq 'headless') {
        throw 'Capture receipt does not prove a visible native rendering display.'
    }
    if (-not $uwReceipt.authority.normal_wellspring_bound -or [int]$uwReceipt.authority.tick_rate -ne 120 -or [int]$uwReceipt.authority.eligible_cell_count -le 0) {
        throw 'Capture receipt does not identify a bound normal Wellspring authority.'
    }
    if (@($uwReceipt.cases).Count -ne 10 -or @($uwReceipt.frames).Count -ne 23 -or @($uwReceipt.ui_states).Count -ne 3) {
        throw 'Unified Wellspring receipt has the wrong case, frame, or interface count.'
    }
    if (@($uwReceipt.method.sources).Count -ne 9) {
        throw 'Unified Wellspring receipt has an incomplete production source manifest.'
    }
    foreach ($uwSource in @($uwReceipt.method.sources)) {
        if ([string]$uwSource.path -cnotmatch '^res://(scenes|src)/' -or [string]$uwSource.sha256 -cnotmatch '^[0-9a-f]{64}$') {
            throw 'Unified Wellspring receipt has an invalid production source record.'
        }
    }
    $uwRecipes = @($uwReceipt.cases | ForEach-Object { [int]$_.recipe_wire_id })
    if (($uwRecipes -join ',') -cne '301,302,303,304,309,310,311,316,317,322') {
        throw 'Unified Wellspring receipt does not cover the ten first-four recipes in canonical order.'
    }
    foreach ($uwCase in @($uwReceipt.cases)) {
        if (@($uwCase.paid_starts).Count -ne 2 -or [int]$uwCase.product_summary.quantity -ne 1200 -or -not $uwCase.conservation_valid -or @($uwCase.active_cells).Count -le 0 -or @($uwCase.products_snapshot).Count -le 0) {
            throw "Incomplete paid authority record for $($uwCase.label)."
        }
        foreach ($uwStart in @($uwCase.paid_starts)) {
            if ([int]$uwStart.matter_committed -ne 600 -or [int]$uwStart.cast_id -le 0 -or [int]$uwStart.source_cast_id -le 0) {
                throw "Invalid paid start record for $($uwCase.label)."
            }
        }
        foreach ($uwCell in @($uwCase.active_cells)) {
            if (@($uwCell.vertices_absolute_fixed).Count -ne 6 -or [int]$uwCell.coverage -ne 1 -or [int]$uwCell.allocation -ne [int]$uwCell.stored_allocation) {
                throw "Invalid selected whole-hex receipt for $($uwCase.label)."
            }
        }
    }
    foreach ($uwFrame in @($uwReceipt.frames)) {
        $uwFramePath = [System.IO.Path]::GetFullPath((Join-Path $uwOutput ([string]$uwFrame.file)))
        if (-not $uwFramePath.StartsWith(([System.IO.Path]::GetFullPath($uwOutput) + [System.IO.Path]::DirectorySeparatorChar), [System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'Receipt frame escaped the fresh capture directory.'
        }
        if (-not (Test-Path -LiteralPath $uwFramePath -PathType Leaf) -or (Get-FluxFileSha256 $uwFramePath) -cne [string]$uwFrame.sha256) {
            throw "Missing or stale capture frame: $($uwFrame.file)"
        }
        $uwExpectedResource = "res://.godot/unified-wellspring-$RunId/$($uwFrame.file)"
        if ([string]$uwFrame.resource_path -cne $uwExpectedResource -or [System.IO.Path]::GetFullPath([string]$uwFrame.absolute_path) -cne $uwFramePath) {
            throw "Capture frame paths disagree: $($uwFrame.file)"
        }
        $uwBytes = [System.IO.File]::ReadAllBytes($uwFramePath)
        if ($uwBytes.Length -lt 24 -or $uwBytes[0] -ne 137 -or $uwBytes[1] -ne 80 -or $uwBytes[2] -ne 78 -or $uwBytes[3] -ne 71) {
            throw "Capture frame is not a PNG: $($uwFrame.file)"
        }
        $uwWidth = [System.BitConverter]::ToInt32([byte[]]@($uwBytes[19], $uwBytes[18], $uwBytes[17], $uwBytes[16]), 0)
        $uwHeight = [System.BitConverter]::ToInt32([byte[]]@($uwBytes[23], $uwBytes[22], $uwBytes[21], $uwBytes[20]), 0)
        if ($uwWidth -ne 1280 -or $uwHeight -ne 720 -or [int]$uwFrame.width -ne 1280 -or [int]$uwFrame.height -ne 720) {
            throw "Capture frame dimensions drifted: $($uwFrame.file)"
        }
    }
    [pscustomobject]@{
        status = 'passed'
        receipt = $uwReceiptPath
        output = $uwOutput
        cases = @($uwReceipt.cases).Count
        frames = @($uwReceipt.frames).Count
        display = [string]$uwReceipt.display.server
    }
}
finally {
    $env:APPDATA = $uwSavedRoaming
    Exit-FluxEngineRun $uwLease
    $uwProfileAfter = if (Test-Path -LiteralPath $uwPersonal -PathType Leaf) { Get-FluxFileSha256 $uwPersonal } else { '' }
    if ($uwProfileAfter -cne $uwProfileBefore) {
        throw 'Personal profile changed during isolated unified Wellspring capture.'
    }
}
