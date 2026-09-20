param([double]$Seconds = 3.2)
$ErrorActionPreference = 'Stop'
$reviewRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$reviewManifest = Get-Content -Raw -LiteralPath (Join-Path $reviewRoot 'packed/manifest.json') | ConvertFrom-Json
$reviewNames = @('fire', 'water', 'earth', 'wind', 'charge', 'ice', 'light', 'dark')
$reviewFfmpeg = (Get-Command ffmpeg -ErrorAction Stop).Source
$reviewFont = 'C\:/Windows/Fonts/consola.ttf'
$reviewOutput = Join-Path $reviewRoot 'review'
New-Item -ItemType Directory -Path $reviewOutput -Force | Out-Null
$reviewArgs = [System.Collections.Generic.List[string]]::new()
$reviewArgs.AddRange([string[]]@('-hide_banner','-loglevel','warning','-y'))
$reviewFilters = [System.Collections.Generic.List[string]]::new()
for ($i = 0; $i -lt $reviewNames.Count; $i++) {
    $name = $reviewNames[$i]
    $asset = $reviewManifest.assets.$name
    if ($null -eq $asset -or $asset.frames.Count -ne 8) { throw "Eight checked frames required: $name" }
    $reviewArgs.AddRange([string[]]@('-loop','1','-framerate','120','-t',$Seconds.ToString([Globalization.CultureInfo]::InvariantCulture),'-i',(Join-Path $reviewRoot "packed/$name.png")))
    $durations = @($asset.frames | ForEach-Object { [int]$_.duration_ticks })
    $totalTicks = ($durations | Measure-Object -Sum).Sum
    $ends = @()
    $cumulative = 0
    foreach ($duration in $durations) { $cumulative += $duration; $ends += $cumulative }
    $frameExpression = '7'
    for ($frame = 6; $frame -ge 0; $frame--) {
        $frameExpression = "if(lt(mod(n,$totalTicks),$($ends[$frame])),$frame,$frameExpression)"
    }
    $label = $name.ToUpperInvariant()
    $reviewFilters.Add("[$i`:v]crop=32:32:x='mod($frameExpression,4)*32':y='floor(($frameExpression)/4)*32',scale=160:160:flags=neighbor[body$i]")
    $reviewFilters.Add("color=c=0x182329:s=192x208:r=120[bg$i]")
    $reviewFilters.Add("[bg$i][body$i]overlay=16:34:shortest=1,drawtext=fontfile='$reviewFont':text='$label':x=(w-text_w)/2:y=8:fontsize=18:fontcolor=0xe8e4d6[v$i]")
}
$reviewFilters.Add('[v0][v1][v2][v3]hstack=inputs=4[top]')
$reviewFilters.Add('[v4][v5][v6][v7]hstack=inputs=4[bottom]')
$reviewFilters.Add('[top][bottom]vstack=inputs=2,fps=30,format=rgb24,split[colors][content]')
$reviewFilters.Add('[colors]palettegen=stats_mode=diff[palette]')
$reviewFilters.Add('[content][palette]paletteuse=dither=none[result]')
$reviewArgs.AddRange([string[]]@('-filter_complex',($reviewFilters -join ';'),'-map','[result]','-t',$Seconds.ToString([Globalization.CultureInfo]::InvariantCulture),'-loop','0',(Join-Path $reviewOutput 'basic-elements-animated.gif')))
& $reviewFfmpeg @reviewArgs
if ($LASTEXITCODE -ne 0) { throw "Animation review encoding failed: $LASTEXITCODE" }
& $reviewFfmpeg -hide_banner -loglevel warning -y -i (Join-Path $reviewOutput 'basic-elements-animated.gif') -frames:v 1 -update 1 (Join-Path $reviewOutput 'basic-elements-overview.png')
if ($LASTEXITCODE -ne 0) { throw 'Review still encoding failed' }
Write-Output 'Rendered eight basic-element studies only. GIF is a review sampling of the 120Hz metadata, not a game-performance test.'
