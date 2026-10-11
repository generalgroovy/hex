$ErrorActionPreference='Stop'
$hexRoot='C:/Users/sende/Projects/hex'
$hexBuild=Join-Path $hexRoot 'exports/hex-material-polish-20261005'
$hexPayload=Join-Path $hexBuild 'windows'
$hexPackage=Get-Content -LiteralPath (Join-Path $hexBuild 'receipt.json') -Raw | ConvertFrom-Json
$hexOut=Join-Path $hexBuild 'delivery-files.json'
if(Test-Path -LiteralPath $hexOut){throw 'Fresh verification output required'}
$hexChecks=[ordered]@{}
$hexChecks.packageReceiptPassed=$hexPackage.status -eq 'passed'
$hexChecks.runtimeIdentity=$hexPackage.build_id -eq 'p56-9540983772f9'
$hexChecks.packHash=(Get-FileHash -LiteralPath (Join-Path $hexPayload 'hex.pck')).Hash.ToLowerInvariant() -eq $hexPackage.pack_sha256
$hexChecks.zipHash=(Get-FileHash -LiteralPath $hexPackage.zip).Hash.ToLowerInvariant() -eq $hexPackage.zip_sha256
$hexManifest=@{}
foreach($hexLine in Get-Content -LiteralPath (Join-Path $hexPayload 'SHA256SUMS.txt')) {
 if($hexLine -notmatch '^([a-f0-9]{64})  ([^/\\]+)$'){throw 'Malformed payload hash line'}
 $hexName=$Matches[2];$hexHash=$Matches[1]
 if($hexManifest.ContainsKey($hexName)){throw 'Duplicate manifest name'}
 $hexManifest[$hexName]=$hexHash
 if((Get-FileHash -LiteralPath (Join-Path $hexPayload $hexName)).Hash.ToLowerInvariant() -ne $hexHash){throw "Payload mismatch: $hexName"}
}
$hexFiles=@(Get-ChildItem -LiteralPath $hexPayload -File)
$hexChecks.payloadInventory=$hexFiles.Count -eq $hexManifest.Count+1
$hexArchive=[IO.Compression.ZipFile]::OpenRead($hexPackage.zip)
$hexZipRows=@()
try {
 foreach($hexEntry in $hexArchive.Entries) {
  if($hexEntry.FullName -ne $hexEntry.Name -or -not (Test-Path -LiteralPath (Join-Path $hexPayload $hexEntry.Name))){throw 'Unexpected ZIP member'}
  $hexStream=$hexEntry.Open();$hexSha=[Security.Cryptography.SHA256]::Create()
  try {$hexEntryHash=[Convert]::ToHexString($hexSha.ComputeHash($hexStream)).ToLowerInvariant()} finally {$hexSha.Dispose();$hexStream.Dispose()}
  $hexLocalHash=(Get-FileHash -LiteralPath (Join-Path $hexPayload $hexEntry.Name)).Hash.ToLowerInvariant()
  if($hexEntryHash -ne $hexLocalHash){throw "ZIP bytes differ: $($hexEntry.Name)"}
  $hexZipRows += [ordered]@{name=$hexEntry.Name;bytes=$hexEntry.Length;sha256=$hexEntryHash}
 }
 $hexChecks.zipInventory=$hexArchive.Entries.Count -eq $hexFiles.Count
} finally {$hexArchive.Dispose()}
$hexReadme=Get-Content -LiteralPath (Join-Path $hexPayload 'README-FIRST.txt') -Raw
$hexLauncher=Get-Content -LiteralPath (Join-Path $hexPayload 'PLAY-HEX.cmd') -Raw
$hexChecks.launcherPixelFlags=$hexLauncher.Contains('--fullbody-art --pixel-cast %*')
$hexChecks.instructionsPixelChoice=$hexReadme.Contains('Starting hex.exe directly retains skeleton mode.') -and -not $hexReadme.Contains('Skeleton mode is the default.')
$hexChecks.instructionsInteraction=$hexReadme.Contains('Interact with buildings: F')
$hexChecks.instructionsAttune=$hexReadme.Contains('Academy > Champions > Attune') -and $hexReadme.Contains("saved weave; uncustomized characters use their starter kit.")
$hexChecks.instructionsLimits=$hexReadme.Contains('Internet relay is not') -and $hexReadme.Contains('not an installer/updater')
$hexChecks.fallbackPackUnchanged=(Get-FileHash -LiteralPath (Join-Path $hexRoot 'exports/hex-polish3-20261004/windows/hex.pck')).Hash.ToLowerInvariant() -eq 'd47d5a61ea4d8c59bbc8674065a22ef6637667e11d85fbb8019d5b74ccdb2b24'
$hexChecks.fallbackZipUnchanged=(Get-FileHash -LiteralPath (Join-Path $hexRoot 'exports/hex-polish3-20261004/HEX-p56-c2695a33fd56-Windows-x64.zip')).Hash.ToLowerInvariant() -eq '052de3e8ba00df688370cf8499cfac91a0c92a2b3da4cebd9058c8ca116459f9'
$hexPassed=@($hexChecks.Values | Where-Object {$_ -ne $true}).Count -eq 0
$hexResult=[ordered]@{status=$(if($hexPassed){'passed'}else{'failed'});build_id=$hexPackage.build_id;checks=$hexChecks;zip_bytes=(Get-Item -LiteralPath $hexPackage.zip).Length;zip_entries=$hexZipRows;scope='Payload and archive bytes, launcher instructions, preserved fallback; not installer or physical networking acceptance'}
[IO.File]::WriteAllText($hexOut,($hexResult | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
$hexChecks | ConvertTo-Json
if(-not $hexPassed){throw 'Delivery file verification failed'}
