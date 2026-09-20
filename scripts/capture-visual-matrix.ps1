[CmdletBinding()]
param(
    [ValidatePattern('^[a-z0-9][a-z0-9-]{0,19}$')][string]$Name = 'integrated-visual',
    [ValidateSet(120)][int]$TickRate = 120,
    [ValidateRange(12, 60)][int]$Frames = 24,
    [ValidateRange(1024, 65535)][int]$Port = 24930
)

. (Join-Path $PSScriptRoot 'flux2-common.ps1')

$repoRoot = Get-FluxRepoRoot
$captureScript = Join-Path $PSScriptRoot 'capture-visual.ps1'
$captureRoot = Join-Path $repoRoot '.godot\visual-captures'
$existing = @(Get-ChildItem -LiteralPath $captureRoot -Filter "$Name-*" -ErrorAction SilentlyContinue)
if ($existing.Count -gt 0) {
    throw "Visual matrix prefix already exists; choose a new -Name: $Name"
}

$directions = @(
    @{ id = 'south'; vector = @(0, 1) },
    @{ id = 'south_east'; vector = @(1, 1) },
    @{ id = 'east'; vector = @(1, 0) },
    @{ id = 'north_east'; vector = @(1, -1) },
    @{ id = 'north'; vector = @(0, -1) },
    @{ id = 'north_west'; vector = @(-1, -1) },
    @{ id = 'west'; vector = @(-1, 0) },
    @{ id = 'south_west'; vector = @(-1, 1) }
)
$scenarios = @(
    @{ id = 'idle'; movement = 'grounded'; reviewFrame = 8 },
    @{ id = 'walk'; movement = 'walk'; reviewFrame = 12 },
    @{ id = 'sprint'; movement = 'sprint'; reviewFrame = 12 },
    @{ id = 'reverse'; movement = 'reverse'; reviewFrame = 12 },
    @{ id = 'jump'; movement = 'jump'; reviewFrame = 8 },
    @{ id = 'cast'; movement = 'grounded'; reviewFrame = 10; castSlot = 1 },
    @{ id = 'hit'; movement = 'hit'; reviewFrame = 7 },
    @{ id = 'evade'; movement = 'air_dodge'; reviewFrame = 7 }
)
$profiles = @(
    @{ id = 'standard'; argument = 'standard'; reduced = $false },
    @{ id = 'high-contrast'; argument = 'high_contrast'; reduced = $false },
    @{ id = 'grayscale'; argument = 'grayscale'; reduced = $false },
    @{ id = 'reduced-effects'; argument = 'standard'; reduced = $true },
    @{ id = 'protanopia'; argument = 'protanopia'; reduced = $false },
    @{ id = 'deuteranopia'; argument = 'deuteranopia'; reduced = $false },
    @{ id = 'tritanopia'; argument = 'tritanopia'; reduced = $false },
    @{ id = 'high-contrast-reduced'; argument = 'high_contrast'; reduced = $true }
)
$champions = @('oh_tipi', 's_wayne', 'red_baron')
$zoomOrders = @(
    @(50, 75, 100, 50, 75, 100, 50, 75),
    @(100, 50, 75, 100, 50, 75, 100, 75),
    @(75, 100, 50, 75, 100, 50, 75, 100)
)
$profileOffsets = @(0, 4, 2)
$spawn = @(1280, 720)
$manifestEntries = [System.Collections.Generic.List[object]]::new()

function Invoke-MatrixCapture {
    param(
        [Parameter(Mandatory = $true)][string]$CaptureName,
        [Parameter(Mandatory = $true)][string]$Resolution,
        [Parameter(Mandatory = $true)][int]$CaptureFrames,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$FarflowPair,
        [int]$ReviewFrame = 0,
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Kind
    )

    $parameters = @{
        Name = $CaptureName
        Resolution = $Resolution
        TickRate = $TickRate
        Frames = $CaptureFrames
        GameArguments = $Arguments
    }
    if ($FarflowPair) {
        $parameters.FarflowPair = $true
        $parameters.Port = $Port
    }
    & $captureScript @parameters

    $directory = Join-Path $captureRoot $CaptureName
    $frames = @(Get-ChildItem -LiteralPath $directory -Filter 'frame*.png' -File | Sort-Object Name)
    if ($frames.Count -ne $CaptureFrames) {
        throw "Matrix cell $CaptureName produced $($frames.Count) frames; expected $CaptureFrames."
    }
    $selectedIndex = [Math]::Min([Math]::Max(0, $ReviewFrame), $frames.Count - 1)
    $manifestEntries.Add([ordered]@{
        id = $CaptureName
        kind = $Kind
        label = $Label
        resolution = $Resolution
        tick_rate = $TickRate
        frame_count = $CaptureFrames
        review_frame = $selectedIndex
        review_image = $frames[$selectedIndex].FullName.Substring($repoRoot.Length + 1).Replace('\', '/')
        arguments = $Arguments
    })
}

for ($championIndex = 0; $championIndex -lt $champions.Count; $championIndex++) {
    $champion = $champions[$championIndex]
    for ($directionIndex = 0; $directionIndex -lt $directions.Count; $directionIndex++) {
        $direction = $directions[$directionIndex]
        $scenario = $scenarios[$directionIndex]
        $profile = $profiles[($directionIndex + $profileOffsets[$championIndex]) % $profiles.Count]
        $zoom = $zoomOrders[$championIndex][$directionIndex]
        $captureName = "$Name-d$championIndex-$directionIndex-$($scenario.id)"
        $arguments = [System.Collections.Generic.List[string]]::new()
        foreach ($argument in @(
            '--pov-mode=full',
            "--camera-zoom=$zoom",
            "--champion=$champion",
            "--capture-spawn=$($spawn[0]),$($spawn[1])",
            "--capture-direction=$($direction.id)",
            "--capture-movement=$($scenario.movement)",
            "--capture-visual-profile=$($profile.argument)"
        )) { $arguments.Add($argument) }
        if ($profile.reduced) { $arguments.Add('--capture-reduced-effects') }
        if ($scenario.ContainsKey('castSlot')) {
            $arguments.Add("--capture-cast-slot=$($scenario.castSlot)")
            $pointerX = $spawn[0] + ($direction.vector[0] * 300)
            $pointerY = $spawn[1] + ($direction.vector[1] * 300)
            $arguments.Add("--capture-pointer=$pointerX,$pointerY")
        }
        $label = "$champion | $($direction.id) | $($scenario.id) | $zoom% | $($profile.id)"
        Invoke-MatrixCapture -CaptureName $captureName -Resolution '1280x720' -CaptureFrames $Frames `
            -Arguments $arguments.ToArray() -ReviewFrame $scenario.reviewFrame -Label $label -Kind 'direction-action'
    }
}

foreach ($resolution in @('1280x720', '1920x1080')) {
    $captureName = "$Name-overview-$($resolution.Replace('x', '-'))"
    Invoke-MatrixCapture -CaptureName $captureName -Resolution $resolution -CaptureFrames 4 `
        -Arguments @('--pov-mode=full', '--camera-zoom=75', '--champion=oh_tipi', '--capture-visual-profile=standard') `
        -ReviewFrame 3 -Label "Wellspring overview | $resolution | 75%" -Kind 'overview'
}

$farflowName = "$Name-farflow-pair"
Invoke-MatrixCapture -CaptureName $farflowName -Resolution '1280x720' -CaptureFrames 72 `
    -Arguments @('--pov-mode=full', '--camera-zoom=75', '--champion=oh_tipi', '--capture-visual-profile=standard') `
    -FarflowPair -ReviewFrame 64 -Label 'Farflow | Oh Tipi host + S. Wayne guest | 75%' -Kind 'farflow'

$manifestPath = Join-Path $captureRoot "$Name-manifest.json"
$manifest = [ordered]@{
    schema_version = 1
    authority = 'review evidence only; never gameplay or asset authority'
    source_commit = (git -C $repoRoot rev-parse HEAD).Trim()
    generated_utc = [DateTime]::UtcNow.ToString('o')
    matrix_contract = [ordered]@{
        champions = $champions
        directions = @($directions | ForEach-Object { $_.id })
        action_states = @($scenarios | ForEach-Object { $_.id })
        zoom_percentages = @(50, 75, 100)
        visual_profiles = @($profiles | ForEach-Object { $_.id })
        includes_720p_1080p_overview = $true
        includes_real_farflow_pair = $true
    }
    entries = $manifestEntries
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding utf8

Add-Type -AssemblyName System.Drawing
$columns = 4
$cellWidth = 320
$cellHeight = 220
$imageHeight = 180
$rows = [Math]::Ceiling($manifestEntries.Count / $columns)
$sheet = [System.Drawing.Bitmap]::new($columns * $cellWidth, $rows * $cellHeight)
$graphics = [System.Drawing.Graphics]::FromImage($sheet)
$font = [System.Drawing.Font]::new('Consolas', 8.0)
$labelBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(236, 225, 192))
try {
    $graphics.Clear([System.Drawing.Color]::FromArgb(20, 17, 20))
    for ($index = 0; $index -lt $manifestEntries.Count; $index++) {
        $entry = $manifestEntries[$index]
        $sourcePath = Join-Path $repoRoot $entry.review_image
        $source = [System.Drawing.Image]::FromFile($sourcePath)
        try {
            $x = ($index % $columns) * $cellWidth
            $y = [Math]::Floor($index / $columns) * $cellHeight
            $graphics.DrawImage($source, $x, $y, $cellWidth, $imageHeight)
            $labelBounds = [System.Drawing.RectangleF]::new(
                [single]($x + 4), [single]($y + $imageHeight + 3),
                [single]($cellWidth - 8), [single]($cellHeight - $imageHeight - 4)
            )
            $graphics.DrawString($entry.label, $font, $labelBrush, $labelBounds)
        }
        finally { $source.Dispose() }
    }
    $contactSheetPath = Join-Path $captureRoot "$Name-contact-sheet.png"
    $sheet.Save($contactSheetPath, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $labelBrush.Dispose()
    $font.Dispose()
    $graphics.Dispose()
    $sheet.Dispose()
}

Write-Output "PASS: integrated visual matrix captured; manifest=$manifestPath"
Write-Output "PASS: contact sheet=$contactSheetPath"
