[CmdletBinding()]
param([switch]$Json)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$cachePath = Join-Path $repo '.godot/global_script_class_cache.cfg'
$expected = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
$files = @(Get-ChildItem -LiteralPath (Join-Path $repo 'src') -Recurse -File -Filter '*.gd')
$files += Get-Item -LiteralPath (Join-Path $repo 'tests/support/test_suite.gd')
foreach ($file in $files) {
    $declaration = [regex]::Match([IO.File]::ReadAllText($file.FullName), '(?m)^class_name\s+([A-Za-z_][A-Za-z0-9_]*)\s*$')
    if ($declaration.Success) {
        $relative = [IO.Path]::GetRelativePath($repo, $file.FullName).Replace('\','/')
        $expected.Add($declaration.Groups[1].Value, 'res://' + $relative)
    }
}
$actual = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
$violations = [Collections.Generic.List[string]]::new()
$cacheText = [IO.File]::ReadAllText($cachePath)
foreach ($entry in [regex]::Matches($cacheText, '(?s)"class":\s*&"([^"]+)".*?"path":\s*"([^"]+)"')) {
    $name = $entry.Groups[1].Value
    if ($actual.ContainsKey($name)) { $violations.Add('Duplicate cache class: ' + $name) }
    else { $actual.Add($name, $entry.Groups[2].Value) }
}
foreach ($name in $expected.Keys) {
    if (-not $actual.ContainsKey($name)) { $violations.Add('Missing cache class: ' + $name) }
    elseif ($actual[$name] -cne $expected[$name]) { $violations.Add($name + ': expected ' + $expected[$name] + '; actual ' + $actual[$name]) }
}
foreach ($name in $actual.Keys) {
    if (-not $expected.ContainsKey($name)) { $violations.Add('Unexpected cache class: ' + $name) }
}
$report = [ordered]@{canonical_count=$expected.Count;cache_count=$actual.Count;cache_sha256=(Get-FileHash -LiteralPath $cachePath).Hash.ToLowerInvariant();violations=@($violations.ToArray());passed=($violations.Count -eq 0)}
if ($Json) { $report | ConvertTo-Json -Depth 4 }
if ($violations.Count -gt 0) { throw ('Noncanonical Godot class registry: ' + ($violations -join '; ')) }
if (-not $Json) { Write-Output "PASS: $($expected.Count) Godot classes map exactly to canonical source paths." }
