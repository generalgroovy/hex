$ErrorActionPreference='Stop'
$hexRoot='C:/Users/sende/Projects/hex'
$hexOutput=Join-Path $PSScriptRoot 'native-reviewed-v2.json'
if(Test-Path -LiteralPath $hexOutput){throw 'Fresh review receipt required'}
$hexBuild='p56-98549e4db122'
$hexRows=[Collections.Generic.List[object]]::new()
$hexGroups=@(
 @{name='jump-preparation';count=16;reviewAll=$true},
 @{name='aim-reticle';count=28;reviewAll=$false}
)
$hexReticleReviewed=@('near-header-left-1280x720.png','near-hotbar-bottom-1600x900.png')
foreach($hexLabel in @('center-controller','center-mouse','edge-northwest','edge-southeast','near-header-top','near-resource-left')) {
 foreach($hexSize in @('1280x720','1600x900')) {$hexReticleReviewed += "$hexLabel-$hexSize.png"}
}
foreach($hexGroup in $hexGroups) {
 $hexEarlier=Join-Path $hexRoot ".godot/$($hexGroup.name)-native-20261005-v1"
 $hexFinal=Join-Path $hexRoot ".godot/$($hexGroup.name)-native-20261005-v2"
 $hexReceipt=Get-Content -LiteralPath (Join-Path $hexFinal 'receipt.json') -Raw | ConvertFrom-Json
 if($hexReceipt.runtime_identity.build_id -ne $hexBuild -or $hexReceipt.frames.Count -ne $hexGroup.count){throw 'Final native identity/coverage mismatch'}
 if($hexGroup.name -eq 'jump-preparation') {
  if($hexReceipt.status -ne 'passed' -or $hexReceipt.checks -ne 766){throw 'Jump native gate failed'}
 } elseif(-not $hexReceipt.passed -or $hexReceipt.failures.Count -ne 0 -or $hexReceipt.checks.Count -ne 290) {throw 'Reticle native gate failed'}
 $hexNames=@(Get-ChildItem -LiteralPath $hexFinal -File -Filter '*.png' | Sort-Object Name | ForEach-Object Name)
 if($hexNames.Count -ne $hexGroup.count){throw 'Unexpected final native PNG inventory'}
 $hexOldNames=@(Get-ChildItem -LiteralPath $hexEarlier -File -Filter '*.png' | Sort-Object Name | ForEach-Object Name)
 if(($hexNames -join '|') -cne ($hexOldNames -join '|')){throw 'Old/final native inventory mismatch'}
 foreach($hexName in $hexNames) {
  $hexOldHash=(Get-FileHash -LiteralPath (Join-Path $hexEarlier $hexName)).Hash.ToLowerInvariant()
  $hexFinalHash=(Get-FileHash -LiteralPath (Join-Path $hexFinal $hexName)).Hash.ToLowerInvariant()
  if($hexOldHash -cne $hexFinalHash){throw "Native pixels changed: $hexName"}
  $hexRows.Add([ordered]@{group=$hexGroup.name;file=$hexName;sha256=$hexFinalHash;identical_to_v1=$true;visually_reviewed=($hexGroup.reviewAll -or $hexName -cin $hexReticleReviewed)})
 }
}
$hexResult=[ordered]@{status='passed';build_id=$hexBuild;frames=$hexRows.ToArray();automated_frame_count=44;visually_reviewed_count=@($hexRows | Where-Object visually_reviewed).Count;scope='Final native source render matches the prior reviewed pixels exactly. All16 jump frames and14 representative reticle frames visually reviewed across root and delegated reviewers. Reticle automated glyph checks cover all28. Synthetic logical viewport evidence, not physical input, window resize, DPI or human acceptance.'}
[IO.File]::WriteAllText($hexOutput,($hexResult | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
[pscustomobject]$hexResult | Select-Object status,build_id,automated_frame_count,visually_reviewed_count | ConvertTo-Json
