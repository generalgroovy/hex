# Pure argument/inspection controls. No engine, profiler execution or writes.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$launcher = Join-Path $PSScriptRoot 'launch-hex.ps1'
$tokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($launcher, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }
$definitions = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-HexProfileArguments' }, $true))
if ($definitions.Count -ne 1) { throw 'Expected one profile invocation constructor.' }
Invoke-Expression $definitions[0].Extent.Text
$producer = Join-Path $PSScriptRoot 'profile-gameplay.ps1'
$producerAst = [Management.Automation.Language.Parser]::ParseFile($producer, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }
# Execute only the actual producer's two observer-admission statements, never its setup or engine path.
$producerGuards = @($producerAst.EndBlock.Statements | Where-Object {
    $_ -is [Management.Automation.Language.IfStatementAst] -and
    $_.Clauses[0].Item1.Extent.Text -cmatch '^\$LightObserver -and \$(AllFixedSteps|ViewportRenderTiming)$'
})
if ($producerGuards.Count -ne 2) { throw 'Expected the two actual producer observer-admission guards.' }
function Confirm-ProfileProducerAdmission([hashtable]$Invocation) {
    $LightObserver = [bool]$Invocation['LightObserver']
    $AllFixedSteps = [bool]$Invocation['AllFixedSteps']
    $ViewportRenderTiming = [bool]$Invocation['ViewportRenderTiming']
    foreach ($guard in $producerGuards) { & ([scriptblock]::Create($guard.Extent.Text)) }
}
$checks = 0
function Check-Profile([bool]$Condition, [string]$Label) { $script:checks++; if (-not $Condition) { throw "FAIL: $Label" } }
function Reject-Profile([string]$Label, [scriptblock]$Action) {
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    Check-Profile $rejected $Label
}
$outputPath = '.godot/profile-launcher-test-not-created'
$full = Get-HexProfileArguments $outputPath $false
$light = Get-HexProfileArguments $outputPath $true
$expectedKeys = @('OutputDirectory','Profiles','Cases','SecondsPerCase','FrameLimit','Width','Height','AllFixedSteps','ReferenceCampus','WaitForForeground','TimeoutSeconds')
Check-Profile ((($full.Keys | Sort-Object) -join ',') -ceq (($expectedKeys | Sort-Object) -join ',')) 'Default retains the exact existing profile argument set'
Check-Profile (-not $full.ContainsKey('LightObserver') -and $light.LightObserver -is [bool] -and $light.LightObserver) 'Only Light explicitly forwards the existing profiler switch'
Check-Profile ($light.Count -eq $full.Count -and -not $light.ContainsKey('AllFixedSteps')) 'Light replaces unsupported completed-step attribution with its observer selector'
foreach ($key in ($expectedKeys | Where-Object { $_ -cne 'AllFixedSteps' })) {
    Check-Profile (($full[$key] | ConvertTo-Json -Compress) -ceq ($light[$key] | ConvertTo-Json -Compress)) "Observer choice preserves $key"
}
Check-Profile ($full.OutputDirectory -ceq $outputPath) 'The caller owns the output path'
Check-Profile (($full.Profiles -join ',') -ceq 'low' -and ($full.Cases -join ',') -ceq 'garden_middle,paid_fire_bolt_sustained,paid_all_six_mantle_sustained') 'Both observers retain the three paid/arrival cases'
Check-Profile ($full.SecondsPerCase -eq 15 -and $full.FrameLimit -eq 60 -and $full.Width -eq 1280 -and $full.Height -eq 720 -and $full.TimeoutSeconds -eq 600) 'Duration, display and supervision stay fixed'
Check-Profile ($full.AllFixedSteps -and $full.ReferenceCampus -and $full.WaitForForeground) 'Completed-step coverage, campus mode and foreground admission stay enabled'
Confirm-ProfileProducerAdmission $full
Check-Profile $true 'Actual producer guards admit the constructed Full invocation'
Confirm-ProfileProducerAdmission $light
Check-Profile $true 'Actual producer guards admit the constructed Light invocation'
Reject-Profile 'Actual producer rejects Light with completed-step attribution' { Confirm-ProfileProducerAdmission @{ LightObserver = $true; AllFixedSteps = $true } }
Reject-Profile 'Actual producer rejects Light with viewport attribution' { Confirm-ProfileProducerAdmission @{ LightObserver = $true; ViewportRenderTiming = $true } }
Reject-Profile 'Empty execution output is rejected' { Get-HexProfileArguments '' $true }
Reject-Profile 'Null execution output is rejected' { Get-HexProfileArguments $null $false }
$defaultInspection = & $launcher -Inspect | ConvertFrom-Json
$fullInspection = & $launcher -Mode Profile -Inspect | ConvertFrom-Json
$lightInspection = & $launcher -Mode Profile -LightObserver -Inspect | ConvertFrom-Json
$falseInspection = & $launcher -Mode Profile -LightObserver:$false -Inspect | ConvertFrom-Json
Check-Profile ($defaultInspection.mode -ceq 'Play' -and $null -eq $defaultInspection.profile_observer) 'Default Play does not claim a profile observer'
Check-Profile ($fullInspection.profile_observer -ceq 'full' -and $falseInspection.profile_observer -ceq 'full') 'Omitted and explicit-false selectors report Full'
Check-Profile ($lightInspection.profile_observer -ceq 'light') 'Light inspection reports the selected observer'
Check-Profile ($fullInspection.profile_all_fixed_steps -and $falseInspection.profile_all_fixed_steps -and -not $lightInspection.profile_all_fixed_steps -and $null -eq $defaultInspection.profile_all_fixed_steps) 'Inspection discloses completed-step attribution only for Full'
Check-Profile ($lightInspection.qualified_build_id -ceq $defaultInspection.qualified_build_id -and $lightInspection.selected_launcher -ceq $defaultInspection.selected_launcher -and $lightInspection.default_selection_unchanged) 'Inspection preserves the qualified portable selection'
foreach ($mode in @('Play','Source','Diagnostic')) {
    Reject-Profile "Reject Light in $mode" { & $launcher -Mode $mode -LightObserver -Inspect }
    Reject-Profile "Reject explicitly false Light in $mode" { & $launcher -Mode $mode -LightObserver:$false -Inspect }
}
Reject-Profile 'Lifecycle does not admit an observer selector' { & $launcher -Lifecycle -LightObserver -Inspect }
Reject-Profile 'Profile cannot accept arbitrary game arguments' { & $launcher -Mode Profile -LightObserver -Inspect -GameArguments @('--fullbody-art') }
Write-Output "PASS: $checks pure profile launcher assertions; no engine or profile executed."
