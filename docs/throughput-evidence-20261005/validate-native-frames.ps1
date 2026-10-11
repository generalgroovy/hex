$ErrorActionPreference='Stop'
$hexRoot='C:/Users/sende/Projects/hex'
$hexFinalRelative='.godot/clarity-loom-native-20261005-v3'
$hexFinal=Join-Path $hexRoot $hexFinalRelative
$hexReceiptPath=Join-Path $hexFinal 'receipt.json'
$hexStderrRelative='.godot/hex-probe-clarity-loom-native-20261005-v3/probe.log.err'
$hexStderr=Join-Path $hexRoot $hexStderrRelative
$hexOutput=Join-Path $PSScriptRoot 'native-reviewed-v3.json'
if(Test-Path -LiteralPath $hexOutput){throw 'Fresh native-review output required'}
$hexReceipt=Get-Content -LiteralPath $hexReceiptPath -Raw | ConvertFrom-Json
if($hexReceipt.passed -isnot [bool] -or -not $hexReceipt.passed -or $null -eq $hexReceipt.failures -or $hexReceipt.failures.Count -ne 0){throw 'Final native fixture did not pass'}
if($hexReceipt.checks.Count -ne 102 -or @($hexReceipt.checks | Where-Object {$_.passed -isnot [bool] -or -not $_.passed}).Count -gt 0){throw 'Expected 102 passing native checks'}
if($hexReceipt.frames.Count -ne 12){throw 'Expected 12 final native frames'}
if($hexReceipt.runtime_identity.build_id -cne 'p56-4c82db23d160' -or $hexReceipt.runtime_identity.runtime_source_sha256 -cne '4c82db23d16061baee641a4131c277ec39aeb2fd5a69a8c6034dbc2393b8cba3'){throw 'Final native identity mismatch'}
if(-not (Test-Path -LiteralPath $hexStderr -PathType Leaf) -or (Get-Item -LiteralPath $hexStderr).Length -ne 0){throw 'Final native stderr missing or nonempty'}

[string[]]$hexExpected=@(foreach($hexLabel in @('confirmed','save-failed','starter-refused','starter-timeout','starter-timeout-closed','starter-unsent')){foreach($hexSize in @('1280x720','1600x900')){"$hexLabel-$hexSize.png"}})
[Array]::Sort($hexExpected,[StringComparer]::Ordinal)
$hexFrameNames=@{}
foreach($hexFrame in $hexReceipt.frames){
 $hexName=[string]$hexFrame.image
 if($hexName -cnotin $hexExpected -or $hexFrameNames.ContainsKey($hexName) -or $hexName -cne "$($hexFrame.label).png"){throw 'Unexpected or duplicate receipt frame name'}
 $hexFrameNames[$hexName]=$true
}
foreach($hexDirectory in @($hexFinal,$PSScriptRoot)){
 [string[]]$hexActual=@(Get-ChildItem -LiteralPath $hexDirectory -File -Filter '*.png' | ForEach-Object {$_.Name})
 [Array]::Sort($hexActual,[StringComparer]::Ordinal)
 if($hexActual.Count -ne 12 -or ($hexActual -join '|') -cne ($hexExpected -join '|')){throw "Native PNG inventory mismatch: $hexDirectory"}
}
function Get-HexPngDimensions {
 param([string]$Path)
 $hexBytes=[IO.File]::ReadAllBytes($Path)
 if($hexBytes.Length -lt 24 -or [Convert]::ToHexString([byte[]]$hexBytes[0..7]) -cne '89504E470D0A1A0A' -or [Text.Encoding]::ASCII.GetString($hexBytes,12,4) -cne 'IHDR'){throw "Invalid PNG header: $Path"}
 $hexWidth=[long]$hexBytes[16]*16777216+[long]$hexBytes[17]*65536+[long]$hexBytes[18]*256+$hexBytes[19]
 $hexHeight=[long]$hexBytes[20]*16777216+[long]$hexBytes[21]*65536+[long]$hexBytes[22]*256+$hexBytes[23]
 return @{width=$hexWidth;height=$hexHeight}
}
$hexRows=@()
foreach($hexName in $hexExpected){
 $hexSource=Join-Path $hexFinal $hexName
 $hexEvidence=Join-Path $PSScriptRoot $hexName
 $hexSourceHash=(Get-FileHash -LiteralPath $hexSource -Algorithm SHA256).Hash.ToLowerInvariant()
 $hexEvidenceHash=(Get-FileHash -LiteralPath $hexEvidence -Algorithm SHA256).Hash.ToLowerInvariant()
 if($hexSourceHash -cne $hexEvidenceHash){throw "Final native pixels differ from reviewed evidence: $hexName"}
 $hexDimensions=Get-HexPngDimensions $hexSource
 if($hexName -notmatch '-(1280|1600)x(720|900)\.png$' -or $hexDimensions.width -ne [int]$Matches[1] -or $hexDimensions.height -ne [int]$Matches[2]){throw "PNG dimensions do not match frame identity: $hexName"}
 $hexRows+=[ordered]@{name=$hexName;width=$hexDimensions.width;height=$hexDimensions.height;bytes=(Get-Item -LiteralPath $hexSource).Length;final_path="$hexFinalRelative/$hexName";final_sha256=$hexSourceHash;evidence_path="docs/throughput-evidence-20261005/$hexName";evidence_sha256=$hexEvidenceHash;exact_match=$true}
}
$hexResult=[ordered]@{
 status='passed';build_id=$hexReceipt.runtime_identity.build_id;runtime_source_sha256=$hexReceipt.runtime_identity.runtime_source_sha256
 final_receipt="$hexFinalRelative/receipt.json";final_receipt_sha256=(Get-FileHash -LiteralPath $hexReceiptPath -Algorithm SHA256).Hash.ToLowerInvariant()
 final_stderr=$hexStderrRelative;final_stderr_bytes=0;fixture_checks=102;fixture_failures=0;frame_count=12;frames=$hexRows
 reviewed_image_basis='Root agent inspected the 12 existing evidence PNGs from native v2. This helper verifies final-v3 byte identity and PNG dimensions against those same files; it does not perform visual inspection.'
 scope='Synthetic native UI visual evidence and exact byte preservation. Not physical input, human acceptance, real disk failure, network lifecycle, rendered-performance or capacity acceptance. No duplicate PNG files are created.'
}
[IO.File]::WriteAllText($hexOutput,($hexResult | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
[pscustomobject]$hexResult | Select-Object status,build_id,fixture_checks,fixture_failures,frame_count,final_stderr_bytes | ConvertTo-Json
