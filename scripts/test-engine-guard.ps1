param([switch]$IdentityOnly)

# Synthetic identity checks, then real cross-process checks using disposable
# PowerShell children, never Godot. IdentityOnly does not inspect real processes.
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$checks = 0
function Assert-Guard([bool]$Condition, [string]$Label) {
    if (-not $Condition) { throw "FAIL: $Label" }
    $script:checks += 1
    Write-Output "PASS: $Label"
}
& {
    # The mock exists only in this scope, so the cross-process checks below
    # always use the real cmdlet. No protected process is queried or stopped.
    function Get-Process { param($Id, $ErrorAction) return $mockProcess }
    $record = @{pid=123; started='0'; executable='C:\guard-test\hex.exe'}
    $mockProcess = [pscustomobject]@{ProcessName='svchost'; Reads=@{start=0; path=0}}
    $mockProcess | Add-Member ScriptProperty StartTime { $this.Reads.start += 1; throw 'Access denied.' }
    $mockProcess | Add-Member ScriptProperty Path { $this.Reads.path += 1; throw 'Access denied.' }
    Assert-Guard (-not (Test-FluxRecordedProcess $record)) 'a different readable process name disproves a reused protected PID'
    Assert-Guard ($mockProcess.Reads.start -eq 0 -and $mockProcess.Reads.path -eq 0) 'name mismatch does not read protected start time or path'
    foreach ($name in @('hex', 'HEX', '', ' ', $null)) {
        $mockProcess.ProcessName = $name
        $refused = $false
        try { Test-FluxRecordedProcess $record | Out-Null } catch { $refused = $_.Exception.Message -match 'Cannot establish engine ownership' }
        Assert-Guard $refused "matching or unknown process name remains fail closed ('$name')"
    }
    $mockProcess = [pscustomobject]@{ProcessName='HEX'; StartTime=[datetime]::UtcNow; Path=$record.executable}
    $record.started = $mockProcess.StartTime.ToUniversalTime().Ticks.ToString()
    Assert-Guard (Test-FluxRecordedProcess $record) 'case-only process name differences retain full identity matching'
    $mockProcess.Path = $null
    $refused = $false
    try { Test-FluxRecordedProcess $record | Out-Null } catch { $refused = $_.Exception.Message -match 'Cannot establish engine ownership' }
    Assert-Guard $refused 'matching start identity with an unavailable path remains fail closed'
    $mockProcess.Path = 'C:\another\hex.exe'
    Assert-Guard (-not (Test-FluxRecordedProcess $record)) 'matching names still require the recorded executable path'
    $record.started = '0'
    Assert-Guard (-not (Test-FluxRecordedProcess $record)) 'matching names still require the recorded start identity'
    $mockProcess = $null
    Assert-Guard (-not (Test-FluxRecordedProcess $record)) 'an exited recorded process is not alive'
}
if ($IdentityOnly) {
    Write-Output "PASS: engine guard identity; $checks checks; synthetic processes only"
    return
}
$testRoot = Join-Path (Get-FluxRepoRoot) ('.godot/guard-tests/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$shell = (Get-Process -Id $PID).Path
$commonLiteral = (Join-Path $PSScriptRoot 'flux2-common.ps1').Replace("'", "''")
$children = [Collections.Generic.List[Diagnostics.Process]]::new()
function Start-GuardProbe([string]$Name, [string]$Body) {
    $path = Join-Path $testRoot ($Name + '.ps1.txt')
    [IO.File]::WriteAllText($path, $Body)
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Body))
    $process = Start-Process -FilePath $shell -ArgumentList @('-NoProfile','-EncodedCommand',$encoded) -RedirectStandardOutput (Join-Path $testRoot "$Name.log") -RedirectStandardError (Join-Path $testRoot "$Name.log.err") -WindowStyle Hidden -PassThru
    $children.Add($process)
    return $process
}
function Wait-GuardProbe($Process) {
    if (-not $Process.WaitForExit(10000)) { throw 'Guard probe timed out.' }
    $Process.WaitForExit(); $Process.Refresh()
}
$contenderBody = ". '$commonLiteral'`ntry { `$lease = Enter-FluxEngineRun 'contender'; Exit-FluxEngineRun `$lease; exit 0 } catch { Write-Output `$_.Exception.Message; exit 23 }"
try {
    $outer = Enter-FluxEngineRun 'guard-tests'
    try {
        $inner = Enter-FluxEngineRun 'nested'
        Exit-FluxEngineRun $inner
        $contender = Start-GuardProbe 'contender' $contenderBody
        Wait-GuardProbe $contender
        Assert-Guard ($contender.ExitCode -eq 23) 'nested release retains outer cross-process exclusion'
        $otherRoot = Join-Path $testRoot 'other-checkout'
        New-Item -ItemType Directory -Path $otherRoot -Force | Out-Null
        $otherLiteral = $otherRoot.Replace("'", "''")
        $independent = Start-GuardProbe 'independent' (". '$commonLiteral'`nfunction Get-FluxRepoRoot { return '$otherLiteral' }`n`$lease = Enter-FluxEngineRun 'independent'; Exit-FluxEngineRun `$lease")
        Wait-GuardProbe $independent
        Assert-Guard ($independent.ExitCode -eq 0) 'different checkouts admit independently'
    } finally { Exit-FluxEngineRun $outer }
    $after = Start-GuardProbe 'after-release' $contenderBody
    Wait-GuardProbe $after
    Assert-Guard ($after.ExitCode -eq 0) 'outer release admits the next workflow'

    $readyPath = Join-Path $testRoot 'child-ready.json'
    $readyLiteral = $readyPath.Replace("'", "''")
    $shellLiteral = $shell.Replace("'", "''")
    $sleeperCode = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes('Start-Sleep -Seconds 60'))
    $owner = Start-GuardProbe 'abandoned-owner' @"
. '$commonLiteral'
`$lease = Enter-FluxEngineRun 'abandoned-owner'
`$child = Start-FluxOwnedProcess @{FilePath='$shellLiteral'; ArgumentList=@('-NoProfile','-EncodedCommand','$sleeperCode'); WindowStyle='Hidden'}
@{pid=`$child.Id; started=`$child.StartTime.ToUniversalTime().Ticks.ToString(); executable=`$child.Path} | ConvertTo-Json | Set-Content -LiteralPath '$readyLiteral'
Start-Sleep -Seconds 60
"@
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    while (-not (Test-Path -LiteralPath $readyPath) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
    if (-not (Test-Path -LiteralPath $readyPath)) { throw 'Owner never registered its disposable child.' }
    $childRecord = Get-Content -LiteralPath $readyPath -Raw | ConvertFrom-Json
    $survivor = Get-Process -Id $childRecord.pid
    $children.Add($survivor)
    $owner.Kill(); $owner.WaitForExit()
    $refused = $false
    try { $lease = Enter-FluxEngineRun 'must-refuse'; Exit-FluxEngineRun $lease } catch { $refused = $_.Exception.Message -match 'still alive' }
    Assert-Guard $refused 'terminated owner does not admit while its registered child survives'
    Assert-Guard (Test-FluxRecordedProcess $childRecord) 'refused acquisition leaves the survivor untouched'
    $survivor.Kill(); $survivor.WaitForExit()
    $recovered = Enter-FluxEngineRun 'safe-recovery'
    Exit-FluxEngineRun $recovered
    Assert-Guard $true 'dead owner and exited child recover without stealing a live lock'

    # A reused PID with a different start time is not the recorded child.
    $self = Get-Process -Id $PID
    Assert-Guard (-not (Test-FluxRecordedProcess @{pid=$PID; started='0'; executable=$self.Path})) 'PID reuse is distinguished by process start identity'
    try { $lease = Enter-FluxEngineRun 'exception'; try { throw 'deliberate' } finally { Exit-FluxEngineRun $lease } } catch { }
    $lease = Enter-FluxEngineRun 'after-exception'; Exit-FluxEngineRun $lease
    Assert-Guard $true 'exception finally releases ownership'
    $lease = Enter-FluxEngineRun 'failed-start'
    try {
        $failed = $false
        try { Start-FluxOwnedProcess @{FilePath=(Join-Path $testRoot 'missing.exe'); WindowStyle='Hidden'} | Out-Null } catch { $failed = $true }
        Assert-Guard $failed 'failed child launch preserves a refusal without requiring a process handle'
        $record = Get-Content -LiteralPath (Get-FluxEngineJournalPath) -Raw | ConvertFrom-Json
        Assert-Guard ($null -eq $record.pending_executable) 'failed launch clears only its own pending intent'
    } finally { Exit-FluxEngineRun $lease }

    $cancelPidPath = Join-Path $testRoot 'cancel-child.pid'
    $cancelLiteral = $cancelPidPath.Replace("'", "''")
    $cancelBody = "Set-Content -LiteralPath '$cancelLiteral' -Value `$PID; Start-Sleep -Seconds 60"
    $cancelCode = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cancelBody))
    $cancelLog = (Join-Path $testRoot 'cancel-checked.log').Replace("'", "''")
    $pipeline = [PowerShell]::Create()
    try {
        $null = $pipeline.AddScript(". '$commonLiteral'; Invoke-FluxGodotChecked '$shellLiteral' @('-NoProfile','-EncodedCommand','$cancelCode') '$cancelLog'")
        $invocation = $pipeline.BeginInvoke()
        $deadline = [DateTime]::UtcNow.AddSeconds(10)
        while (-not (Test-Path -LiteralPath $cancelPidPath) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
        if (-not (Test-Path -LiteralPath $cancelPidPath)) { throw 'Checked cancellation child never started.' }
        $cancelChild = Get-Process -Id ([int](Get-Content -LiteralPath $cancelPidPath))
        $children.Add($cancelChild)
        $sentinel = Start-GuardProbe 'unrelated-sentinel' 'Start-Sleep -Seconds 60'
        $pipeline.Stop()
        Assert-Guard ($cancelChild.WaitForExit(5000)) 'cooperative cancellation closes the checked owned child'
        Assert-Guard (-not $sentinel.HasExited) 'cancellation preserves an unrelated process'
        $lease = Enter-FluxEngineRun 'after-cancel'; Exit-FluxEngineRun $lease
        Assert-Guard $true 'cancellation releases the checkout guard'
    } finally { $pipeline.Dispose() }
    Write-Output "PASS: engine guard; $checks checks; evidence $testRoot"
} finally {
    foreach ($child in $children) { if (-not $child.HasExited) { $child.Kill(); $child.WaitForExit() } }
}
