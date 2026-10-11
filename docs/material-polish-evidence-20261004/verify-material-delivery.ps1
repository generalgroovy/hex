$ErrorActionPreference='Stop'
$hexRoot='C:/Users/sende/Projects/hex'
function Read-Receipt([string]$path) { Get-Content -LiteralPath (Join-Path $hexRoot $path) -Raw | ConvertFrom-Json }
function Same-Data($a,$b) { ($a | ConvertTo-Json -Depth 100 -Compress) -ceq ($b | ConvertTo-Json -Depth 100 -Compress) }
function Image-Comparison([string]$before,[string]$after,[int]$expected) {
 $files=@(Get-ChildItem -LiteralPath (Join-Path $hexRoot $before) -Filter '*.png' -File)
 $matches=@($files | ForEach-Object {
  $new=Join-Path (Join-Path $hexRoot $after) $_.Name
  [ordered]@{image=$_.Name;before_sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant();after_sha256=$(if(Test-Path -LiteralPath $new){(Get-FileHash -LiteralPath $new).Hash.ToLowerInvariant()}else{'MISSING'})}
 })
 [ordered]@{before=$before;after=$after;expected=$expected;count=$matches.Count;passed=($matches.Count -eq $expected -and @($matches | Where-Object {$_.before_sha256 -ne $_.after_sha256}).Count -eq 0);images=$matches}
}
$beforePairs=Read-Receipt '.godot/unified-wellspring-material-before-v1/capture-receipt.json'
$afterPairs=Read-Receipt '.godot/unified-wellspring-material-mesh-v2/capture-receipt.json'
$beforeMotion=Read-Receipt '.godot/pixel-pilot-motion-material-before-v2/receipt.json'
$afterMotion=Read-Receipt '.godot/pixel-pilot-motion-material-mesh-v1/receipt.json'
$beforeGallery=Read-Receipt '.godot/hex-material-gallery-before-v2/receipt.json'
$afterGallery=Read-Receipt '.godot/hex-material-gallery-mesh-v1/receipt.json'
$paired=Read-Receipt '.godot/hex-material-gallery-paired-v2/receipt.json'
$images=@(
 (Image-Comparison '.godot/unified-wellspring-material-after-v2' '.godot/unified-wellspring-material-mesh-v2' 23),
 (Image-Comparison '.godot/pixel-pilot-motion-material-after-v2' '.godot/pixel-pilot-motion-material-mesh-v1' 31),
 (Image-Comparison '.godot/hex-material-gallery-after-v3' '.godot/hex-material-gallery-mesh-v1' 40)
)
$coverage=@()
foreach($old in $beforeGallery.frames) {
 $new=@($afterGallery.frames | Where-Object image -eq $old.image)
 if($new.Count -ne 1){throw "Missing or duplicate gallery frame $($old.image)"}
 $same=if($old.PSObject.Properties.Name -contains 'samples'){Same-Data $old.samples $new[0].samples} elseif($old.PSObject.Properties.Name -contains 'geometry_sha256'){$old.geometry_sha256 -eq $new[0].geometry_sha256} else {Same-Data $old.source_wires $new[0].source_wires}
 $coverage+= [ordered]@{image=$old.image;geometryOrHitWiresIdentical=$same}
}
$checks=[ordered]@{
 pairAuthorityIdentical=(Same-Data $beforePairs.authority $afterPairs.authority)
 allTenPaidCasesIdentical=(Same-Data $beforePairs.cases $afterPairs.cases)
 paidPairRunsPassed=($beforePairs.status -eq 'passed' -and $afterPairs.status -eq 'passed')
 paidMotionFramesIdentical=(Same-Data $beforeMotion.frames $afterMotion.frames)
 paidMotionRunsPassed=($beforeMotion.passed -and $afterMotion.passed)
 paidAdmissionIdentical=($beforeMotion.paid_wire -eq $afterMotion.paid_wire -and $beforeMotion.paid_air_casts -eq $afterMotion.paid_air_casts -and $beforeMotion.air_releases -eq $afterMotion.air_releases)
 galleryCardinality=($beforeGallery.frames.Count -eq 40 -and $afterGallery.frames.Count -eq 40)
 galleryGeometryIdentical=(@($coverage | Where-Object {-not $_.geometryOrHitWiresIdentical}).Count -eq 0)
 optimizedMeshImagesIdentical=(@($images | Where-Object {-not $_.passed}).Count -eq 0)
}
$passed=(@($checks.Values | Where-Object {$_ -ne $true}).Count -eq 0)
$receipt=[ordered]@{
 status=$(if($passed){'passed'}else{'failed'})
 checks=$checks
 baselineBuild='p56-c2695a33fd56'
 finalBuild=(Read-Receipt 'content/runtime/runtime_build_identity_v1.json').build_id
 paidPairs=10;paidMotionFrames=31;arrangedBoards=40;meshEquivalentPngCount=94
 galleryProbeNote='Optional paired-only lane added after baseline; default geometry is compared explicitly, not a same-script-hash claim.'
 imageComparisons=$images;galleryCoverage=$coverage
 pairedTiming=$paired.pooled
 pairedScope=$paired.scope
 scope='Exact paid before/after authority and optimized-mesh output comparison; no human, full-animation, GPU FPS, capacity or internet acceptance.'
}
$out=Join-Path $hexRoot '.godot/material-polish-final-comparison-v1.json'
if(Test-Path -LiteralPath $out){throw 'Fresh receipt required'}
[IO.File]::WriteAllText($out,($receipt | ConvertTo-Json -Depth 100),[Text.UTF8Encoding]::new($false))
$checks | ConvertTo-Json
if(-not $passed){throw 'Final comparison failed'}
