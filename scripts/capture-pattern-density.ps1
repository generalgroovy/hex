[CmdletBinding()]
param(
    [ValidatePattern('^[a-z0-9][a-z0-9-]{0,19}$')][string]$Name = 'pattern-density',
    [ValidateSet(120)][int]$TickRate = 120,
    [ValidateRange(90, 120)][int]$Frames = 120,
    [ValidateRange(1024, 65520)][int]$Port = 24950
)

. (Join-Path $PSScriptRoot 'flux2-common.ps1')

$repoRoot = Get-FluxRepoRoot
$captureScript = Join-Path $PSScriptRoot 'capture-visual.ps1'
$captureRoot = Join-Path $repoRoot '.godot\visual-captures'
$existing = @(Get-ChildItem -LiteralPath $captureRoot -Filter "$Name-*" -ErrorAction SilentlyContinue)
if ($existing.Count -gt 0) {
    throw "Pattern-density prefix already exists; choose a new -Name: $Name"
}

$profiles = @(
    @{ id = 'standard'; argument = 'standard'; reduced = $false },
    @{ id = 'grayscale'; argument = 'grayscale'; reduced = $false },
    @{ id = 'reduced-effects'; argument = 'standard'; reduced = $true }
)
$zooms = @(50, 75, 100)
$reviewFrames = @(28, 48, 68, 88)
$manifestEntries = [System.Collections.Generic.List[object]]::new()

foreach ($zoom in $zooms) {
    foreach ($profile in $profiles) {
        $captureName = "$Name-z$zoom-$($profile.id)"
        $hostArguments = [System.Collections.Generic.List[string]]::new()
        foreach ($argument in @(
            '--pov-mode=full',
            "--camera-zoom=$zoom",
            '--champion=oh_tipi',
            '--capture-pointer=980,720',
            '--capture-spell-sequence=2,3,1,1,1,1,1',
            '--capture-wait-for-peer',
            "--capture-visual-profile=$($profile.argument)"
        )) { $hostArguments.Add($argument) }
        if ($profile.reduced) { $hostArguments.Add('--capture-reduced-effects') }

        $guestArguments = @(
            '--champion=s_wayne',
            '--capture-pointer=120,720',
            '--capture-spell-sequence=2,1,1,1,1,1',
            '--capture-wait-for-peer'
        )
        & $captureScript -Name $captureName -Resolution '1280x720' -TickRate $TickRate `
            -Frames $Frames -FarflowPair -Port $Port -FarflowGuestArguments $guestArguments `
            -GameArguments $hostArguments.ToArray()

        $directory = Join-Path $captureRoot $captureName
        $framesFound = @(Get-ChildItem -LiteralPath $directory -Filter 'frame*.png' -File | Sort-Object Name)
        if ($framesFound.Count -ne $Frames) {
            throw "Pattern cell $captureName produced $($framesFound.Count) frames; expected $Frames."
        }
        foreach ($reviewFrame in $reviewFrames) {
            $selectedIndex = [Math]::Min($reviewFrame, $framesFound.Count - 1)
            $manifestEntries.Add([ordered]@{
                id = "$captureName-f$selectedIndex"
                kind = 'two-player-pattern-density'
                label = "$zoom% | $($profile.id) | frame $selectedIndex"
                resolution = '1280x720'
                tick_rate = $TickRate
                frame_count = $Frames
                review_frame = $selectedIndex
                review_image = $framesFound[$selectedIndex].FullName.Substring($repoRoot.Length + 1).Replace('\', '/')
                host_sequence = @(2, 3, 1, 1, 1, 1, 1)
                guest_sequence = @(2, 1, 1, 1, 1, 1)
            })
        }
        $Port += 1
    }
}

$manifestPath = Join-Path $captureRoot "$Name-manifest.json"
$manifest = [ordered]@{
    schema_version = 1
    authority = 'review evidence only; cast commands still pass through host authority'
    source_commit = (git -C $repoRoot rev-parse HEAD).Trim()
    generated_utc = [DateTime]::UtcNow.ToString('o')
    contract = [ordered]@{
        champions = @('oh_tipi', 's_wayne')
        shapes = @('projectile', 'beam', 'spray', 'field')
        zoom_percentages = $zooms
        review_profiles = @($profiles | ForEach-Object { $_.id })
        real_farflow_pair = $true
        quiet_actor_ring_required = $true
        readable_escape_lane_required = $true
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

Write-Output "PASS: two-player pattern-density matrix captured; manifest=$manifestPath"
Write-Output "PASS: contact sheet=$contactSheetPath"
