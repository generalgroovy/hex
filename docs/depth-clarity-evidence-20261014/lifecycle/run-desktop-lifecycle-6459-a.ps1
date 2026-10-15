$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = 'C:/Users/sende/Projects/hex'
Set-Location -LiteralPath $repoRoot
$routeDirectory = Join-Path $repoRoot '.godot/iteration-20261013/desktop-route-6459-a'
if (Test-Path -LiteralPath $routeDirectory) { throw 'Route evidence directory already exists.' }
New-Item -ItemType Directory -Path $routeDirectory | Out-Null
$shortcutPath = 'C:/Users/sende/Desktop/H.E.X..lnk'
$wrapperPath = 'C:/Users/sende/Documents/ChatGPT/H.E.X/PLAY-HEX.cmd'
$receiptPath = 'exports/hex-depth-clarity-20261014-6459/receipt.json'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
if ($shortcut.TargetPath -ne [IO.Path]::GetFullPath($wrapperPath) -or $shortcut.Arguments -ne '' -or $shortcut.WorkingDirectory -ne [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($wrapperPath))) { throw 'Unexpected desktop route.' }
$before = [ordered]@{ shortcut = (Get-FileHash -LiteralPath $shortcutPath).Hash.ToLowerInvariant(); wrapper = (Get-FileHash -LiteralPath $wrapperPath).Hash.ToLowerInvariant() }
$receiptSha = (Get-FileHash -LiteralPath $receiptPath).Hash.ToLowerInvariant()
$invocation = @('-Lifecycle', '-CandidatePackageReceipt', $receiptPath, '-CandidatePackageReceiptSha256', $receiptSha, '-OutputDirectory', '.godot/iteration-20261013/desktop-lifecycle-6459-a')
$record = [ordered]@{ schema_version=1; status='running'; route='invoked verified desktop shortcut target; not a physical desktop click'; shortcut=$shortcutPath; target=$shortcut.TargetPath; working_directory=$shortcut.WorkingDirectory; shortcut_arguments=$shortcut.Arguments; wrapper=$wrapperPath; arguments=$invocation; before=$before; started_utc=[DateTime]::UtcNow.ToString('o') }
$record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $routeDirectory 'receipt.json') -Encoding utf8
try {
    & $wrapperPath @invocation
    $exitCode = $LASTEXITCODE
    $after = [ordered]@{ shortcut=(Get-FileHash -LiteralPath $shortcutPath).Hash.ToLowerInvariant(); wrapper=(Get-FileHash -LiteralPath $wrapperPath).Hash.ToLowerInvariant() }
    $record.after = $after
    $record.exit_code = $exitCode
    if ($exitCode -ne 0 -or $before.shortcut -ne $after.shortcut -or $before.wrapper -ne $after.wrapper) { throw 'Desktop lifecycle failed or route changed.' }
    $record.status = 'passed'
} catch {
    $record.status = 'failed'
    $record.error = $_.Exception.Message
    throw
} finally {
    $record.finished_utc = [DateTime]::UtcNow.ToString('o')
    $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $routeDirectory 'receipt.json') -Encoding utf8
}
