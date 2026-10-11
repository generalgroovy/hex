$ErrorActionPreference='Stop'
$hexRoot='C:/Users/sende/Projects/hex'
$hexSource=Join-Path $hexRoot '.godot/pixel-pilot-motion-material-mesh-v1'
$hexPack=Join-Path $hexRoot '.godot/pixel-pilot-motion-material-package-20261005-v1'
$hexEvidence=Join-Path $hexRoot 'docs/material-polish-evidence-20261005'
$hexOutput=Join-Path $hexEvidence 'packaged-motion-comparison-v1.json'
if(Test-Path -LiteralPath $hexOutput){throw 'Fresh comparison receipt required'}
$hexBefore=Get-Content -LiteralPath (Join-Path $hexSource 'receipt.json') -Raw | ConvertFrom-Json
$hexAfter=Get-Content -LiteralPath (Join-Path $hexPack 'receipt.json') -Raw | ConvertFrom-Json
$hexImages=@(Get-ChildItem -LiteralPath $hexSource -Filter '*.png' -File | Sort-Object Name | ForEach-Object {
 $hexNew=Join-Path $hexPack $_.Name
 [ordered]@{image=$_.Name;source_sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant();package_sha256=$(if(Test-Path -LiteralPath $hexNew){(Get-FileHash -LiteralPath $hexNew).Hash.ToLowerInvariant()}else{'MISSING'})}
})
$hexChecks=[ordered]@{
 sourcePassed=$hexBefore.passed -eq $true
 packagePassed=$hexAfter.passed -eq $true
 frames=($hexImages.Count -eq 31 -and $hexAfter.frames.Count -eq 31)
 metadataExact=($hexBefore.frames|ConvertTo-Json -Depth 100 -Compress) -ceq ($hexAfter.frames|ConvertTo-Json -Depth 100 -Compress)
 paidAdmission=($hexBefore.paid_wire -eq $hexAfter.paid_wire -and $hexBefore.paid_air_casts -eq $hexAfter.paid_air_casts -and $hexBefore.air_releases -eq $hexAfter.air_releases)
 pixelsExact=@($hexImages | Where-Object {$_.source_sha256 -ne $_.package_sha256}).Count -eq 0
}
$hexPassed=@($hexChecks.Values | Where-Object {$_ -ne $true}).Count -eq 0
$hexResult=[ordered]@{status=$(if($hexPassed){'passed'}else{'failed'});build_id='p56-9540983772f9';checks=$hexChecks;images=$hexImages;source_capture=$hexSource;packaged_capture=$hexPack;scope='Oct5 native rendering of exported PCK via identical external fixture; Oct4 frozen-source frame hashes and paid motion metadata; synthetic input, not physical input, full art-cycle, FPS or human feel acceptance'}
[IO.File]::WriteAllText($hexOutput,($hexResult | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
$hexChecks|ConvertTo-Json
if(-not $hexPassed){throw 'Packaged motion differs from validated frozen source'}
