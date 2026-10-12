param(
 [ValidatePattern('^[a-z0-9-]+$')][string]$RunId = ('hex-' + (Get-Date -Format 'yyyyMMdd-HHmmss')),
 [switch]$CharacterArt,
 [switch]$PixelBodyPilot,
 [switch]$PixelCast
)
$ErrorActionPreference = 'Stop'
if ($PixelBodyPilot -and $PixelCast) { throw 'Choose one pixel bank, not both' }
if ($PixelBodyPilot -or $PixelCast) { $CharacterArt = $true }
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$hexLease = Enter-FluxEngineRun 'package-hex-portable'
$hexSavedAppData = $env:APPDATA
try {
 $hexRoot=Get-FluxRepoRoot
 $hexOutput=Join-Path $hexRoot "exports/$RunId"
 if(Test-Path -LiteralPath $hexOutput){throw 'Fresh export RunId required; existing builds are preserved'}
 & (Join-Path $PSScriptRoot 'doctor.ps1') -RequireExportTemplates -ExportTarget Windows
 & (Join-Path $PSScriptRoot 'runtime-build-identity.ps1') -Mode Check
 $hexIdentity=Get-Content (Join-Path $hexRoot 'content/runtime/runtime_build_identity_v1.json') -Raw | ConvertFrom-Json
 $hexPayload=Join-Path $hexOutput 'windows'
 $hexLogs=Join-Path $hexOutput 'logs'
 New-Item -ItemType Directory -Path $hexPayload,$hexLogs | Out-Null
 $hexExe=Join-Path $hexPayload 'hex.exe'
 Invoke-FluxGodotChecked (Get-FluxGodot) @('--headless','--path',$hexRoot,'--export-release','Windows x86_64',$hexExe) (Join-Path $hexLogs 'export.log') -RejectWarnings -TimeoutSeconds 900 | Out-Null
 # Export may rescan scripts after the Full gate; require canonical class paths
 # again before trying to boot a package that excludes evidence directories.
 & (Join-Path $PSScriptRoot 'check-script-class-cache.ps1') -Json | Set-Content -LiteralPath (Join-Path $hexLogs 'script-class-cache.json')
 $env:APPDATA=Join-Path $hexLogs 'isolated-roaming'
 New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
 & (Join-Path $PSScriptRoot 'runtime-state.ps1') -PackPath (Join-Path $hexPayload 'hex.pck') -OutputPath (Join-Path $hexPayload 'BUILD-STATE.json')
 Push-Location -LiteralPath $hexPayload
 $hexArtArguments = @()
 if ($CharacterArt) { $hexArtArguments = @('--fullbody-art') }
 if ($PixelBodyPilot) { $hexArtArguments += '--pixel-body-pilot' }
 if ($PixelCast) { $hexArtArguments += '--pixel-cast' }
 try { Invoke-FluxGodotChecked $hexExe (@('--windowed','--resolution','1280x720','--','--safe-quit-smoke','--no-lan-discovery') + $hexArtArguments) (Join-Path $hexLogs 'export-smoke.log') -RejectWarnings -TimeoutSeconds 120 | Out-Null } finally { Pop-Location }
 $hexSmoke=Get-Content (Join-Path $hexLogs 'export-smoke.log') -Raw
 if(-not $hexSmoke.Contains($hexIdentity.build_id) -or -not $hexSmoke.Contains('safe quit: local state flushed and network peer closed')) {throw 'Export did not prove expected identity and safe close'}
 if ($CharacterArt -and -not $hexSmoke.Contains('H.E.X. fullbody art candidate: 30 identity skins')) { throw 'Export did not admit character art' }
 if ($PixelBodyPilot -and -not $hexSmoke.Contains('H.E.X. fixed-pixel pilot: three identities')) { throw 'Export did not admit fixed-pixel pilot' }
 if ($PixelCast -and -not $hexSmoke.Contains('H.E.X. fixed-pixel cast: 30 identities')) { throw 'Export did not admit complete fixed-pixel cast' }
 if ($PixelCast -and -not $hexSmoke.Contains('H.E.X. fixed-pixel action keys: 30 identities')) { throw 'Export did not admit complete reviewed jump-key extension' }
 [IO.File]::WriteAllText((Join-Path $hexPayload 'PLAY-HEX.cmd'), "@echo off`r`ncd /d `"%~dp0`"`r`nstart `"H.E.X.`" `"%~dp0hex.exe`" -- $($hexArtArguments -join ' ') %*`r`n", [Text.UTF8Encoding]::new($false))
 Copy-Item -LiteralPath (Join-Path $hexRoot 'content/runtime/runtime_build_identity_v1.json') -Destination (Join-Path $hexPayload 'SOURCE-IDENTITY.json')
 $hexInstructions = @"
H.E.X. $($hexIdentity.build_id)
LOCAL SOLO PLAYTEST CANDIDATE
Open PLAY-HEX.cmd. Keep hex.exe and hex.pck together.

START
Extract the whole ZIP first; do not run from inside the archive. Open
PLAY-HEX.cmd to use this build's tested presentation settings. Close the game
window normally when finished. Keep an older working build until you have
tested its replacement. Saved controls and personal weaves are preserved.
Skeleton mode is the default.

PERFORMANCE
Menu > Display & text size selects Low or Standard visual detail, a 60, 120 or
unlimited frame limit, and 100/125/150/200 percent text. Low and 60 FPS are the
defaults. Low trims decorative
glow and Garden samples while keeping complete spell areas and danger cues.
Movement, collision and paid spell rules still run at 120 Hz. Reduced Motion
remains a separate accessibility option. Far travel prepares its destination
before offline movement resumes; saved controls and weaves are retained.
Small windows and larger text reflow spell, controls, map, Gallery and Compendium
panels. Selected identity stays visible while full details page. At the smallest
layout, Options/O/controller Back reveals reference controls; B closes. The
combination picker outlines controller focus. Loom accepts L3 for Options.
Range Setup/T/controller X contains target settings and tools. More/O/L3 pages
those tools, including delivery selection. Existing controller category/facing
shortcuts remain available.

TRY A NEW BUILD
Extract each portable into its own folder. Keep the previous working folder
until you have tried the replacement. This archive is ready to run; no Godot
installation or administrator permission is required. It contains no installer
or automatic updater.

DEFAULT CONTROLS (saved bindings take priority)
Move: WASD                 Aim: mouse
Sprint: Shift              Slide: C
Jump: hold/release Space   Evade: B       Technique: V
Spells: 1-4, Ctrl+1-4, Alt+1-4           Compendium: F4
Interact with buildings: F
Menu: Esc / controller Back / click Menu     World map: M
Controller Start keeps its gameplay emote action.
Controls has separate movement and aim stick deadzones. Four remappable digital
aim directions default unbound, preserving established custom keys. Release held
inputs after closing a menu or restoring focus before beginning a fresh action.

WHERE TO GO
Approach a building's front door and press your Interact binding.
Academy: characters and Spell Loom. Routekeeper Lodge: movement and controls.
Farflow Hall: experimental sessions. Rest Pavilion: practice and reset.
Hover cards for details. Walk south to Chain Courtyard, Cover Garden and Open
Laboratory. Menus do not pause the shared world.
Open Menu > World map, or M, for thirteen named offline travel destinations.
Select a place, read its context, then confirm Travel / Enter / controller A.
Details/C/controller Y pages district and practice purpose. Highlighted authored
district links suggest connections; you still choose a path around local cover.
The smallest map shows the selected pin and player; its list reaches all places.
The four new regions are Tideglass Quays, Verdant Reaches, Basalt Foundry and
Starward Terraces. Travel preserves Health, Flux, Stamina, spell cooldowns and
your weave; it does not reset resources. Land and finish active actions first.
Travel is unavailable during rounds, challenges or isolated practice; the map
shows the reason. The Compendium also has a Map action on M / controller L3.

ELEMENT GARDEN
Menu > World map > Element Garden reaches 63 physical plots in Tideglass.
Six single-element plots alternate raw deposits and two-source self reactions;
the other 57 show mixed fields. Together they display six raw materials and all 63
reaction identities. Approach a plot for its ingredients, phase, effect and counter.
These are harmless, bounded exhibits that expire and repeat. Your spells remain
live and their real ground effects draw above the exhibits. Use Spell Range for
full-footprint combat tests. Opening the Range from a nearby plot selects that
mixture, ready for your explicit Equip and paid cast. The garden spends no player
Flux or progression.

TRY IT
Hold Jump to prepare, release to launch; non-fliers have one double jump.
While preparing, the small panel above Stamina shows charge and release cost,
or why release is not ready. The cue disappears on launch or cancellation.
Sylph/wyrmborn/angel/demon enter finite paid flight with a second airborne Jump
press, then hold to sustain. Release ends it. Hold airborne Jump at a
suitable wall and release to walljump. Slide faces travel. Height and low
profile evade appropriate attacks, not all damage; a low jump does not clear Steam.
Paid Slide adds a capped entry boost. Fresh airborne Slide also fast-falls and
buffers a landing Slide for 100 ms outside an active dodge; it pays only if the
landing still meets the speed, resource, cooldown and commitment requirements.
Try an air dodge, then change direction and press Technique (V by default)
after its initial commitment. A paid air turn redirects the remaining dodge;
it does not refresh the dodge's timer or protection.

SPELLS AND CHARACTERS
The Loom has twelve positions: four keys in each normal/Ctrl/Alt layer.
Choose Water, Fire, Air, Earth, Light and Dark: 63 compositions in eight families, 504 spells.
Ice and Charge are derived effects. Old saved weaves show a slot-by-slot preview;
Apply confirms migration and preserves an original-file backup.
Combine element buttons, choose a delivery, review Swap/Replace, then confirm.
The wide selector starts with four core forms; More Forms reveals the other four.
The compact reading view keeps the spell name and current costs visible. Options
reveals form arrows and Browse for spell/slot focus; Assign confirms your choice.
Compare/C/right-stick click in the Loom compares the equipped and selected spell.
Range Compare uses C/controller Y. Read the full purpose/counter and timing pages;
direct hits and shared damage pools are not sustained DPS estimates.
Damaging hits apply finite status effects. Mixed payloads can form their named field;
single ingredients need another paid source to react. Read the effect and counter.
Bolt and Rapid repeat while held; Heavy and Spray require a fresh press.
Fresh presses take priority. Held Heavy/Spray does not block a held Bolt/Rapid.
If several repeat buttons are held, the lowest position wins even on cooldown.
Every admitted cast pays Flux. Releasing does not cancel a paid startup.
Loom navigation: arrows/WASD/D-pad; Tab/Y changes pane; PgUp/PgDn or LB/RB
filters; Enter/A assigns; Esc/B closes. Drag/drop is also supported.
F5 starts/skips the optional introduction; F6 opens the all-spell Range.
Shift+F6 opens 30 Signature Challenges; a clean victory teaches the rival's spell.
Shift+F5 opens offline developer testing. These shortcuts respect existing custom bindings.
Outside a challenge, one compact Menu opens the relevant activities and settings.
During a challenge the Menu button stays hidden to keep the rival visible;
the card retains return, next-rival and Developer keys.
Range shows ingredients, Flux cost, startup/cooldown, hit statuses and field counters.
Its loans go in slot 1 and never overwrite saved weaves. Equip does not cast.
Setup selects still/moving targets, their paid firing and Small/Medium/Large size.
Settings do not refill resources. Statistics distinguish casts/Flux and damage
components; Reset statistics changes only the observation window. Use the separate
refill, reset and clear tools deliberately. Leaving practice starts a fresh world
with your own weave. All 30 sandbox characters are already available.
In the Range, Menu contains Change Range spell, Spell Loom, Characters,
Reset practice court and Return to Wellspring. Hazard help appears when relevant.
Menu > Tactical lessons optionally observes actual chains, mixed hits, rival
avoidance and clean saved victory. Skip whenever you want. Signature suggestions
start with Wa Bidi in Conservatory, Oh Tipi in Tideglass and S. Wayne in Basalt;
every rival remains selectable in any order.
Earned progress maintains a verified rolling last-good backup. Missing/damaged
progress offers explicit Recover progress backup; a damaged copy is preserved.
Retry progress save remains available when a session reward is not yet saved.
Developer overrides are temporary and do not earn challenge rewards. The tools
also offer explicit offline Record 60-second replay and Export recorded replay.
Continuous cheats must be off; resets/world changes stop recording. Export is
a local file, never an automatic upload, and verification remains a separate step.
Gallery clicks inspect. Attune switches character and restores that character's
saved weave; uncustomized characters use their starter kit.
Every character has one ancestry perk and one personal perk. Gallery overview
shows both; Details explains the activation window, benefit and tradeoff.
Use the existing controls: posture, movement and resource levels activate them.
Base stat bars stay comparable; recovery waits and paid action limits still apply.
Spell startup checks your posture before payment; its cooldown checks at release.
Every champion has a detailed Gallery portrait. Click the portrait, press P,
or controller Start to enlarge it; Esc/B/Back returns to the roster. Inspecting
art does not equip the character. The actual body preview remains beside it.
F4 shows reaction roles, timing and counters. Inspect all 63 combinations in the
combination builder; guided demonstrations cast a paid pair of any live elements.
After a demo, the result card retains what actually formed and what you paid.
Hover it for effect/counter details and retry keys from your restored loadout.
Missing spells point to the Loom; no free spells or refunds are granted.
Escape or the card's close button dismisses it without blocking movement.

TEAM PLAY
Before hosting, choose Duos (exactly four players) or Trios (exactly six).
Join the same build, mark everyone ready at the Hearth, then the host starts.
AMBER and TEAL alternate the sorted roster: P1/P3/P5 versus P2/P4/P6.
First team to 3 in 90 seconds; tied winning trades and tied deadlines draw.
Only enemy-team knockouts score. Fire, Steam and Conflagration can also harm
you and allies. A whole team leaving forfeits; earned points are retained.
Late joiners observe until the next match. Return to Hearth for a rematch.
Protocol $($hexIdentity.protocol_version) rejects older builds; everyone must use this exact package.

READABILITY
Fields occupy the marked whole hexes. Formation and decay are harmless; leave
active danger. Mantle trails spend finite paid matter; character wakes are visual only.
Floor inlays are flat decoration,
not extra walls. Hover resource bars for recovery and movement-cost details.
Try Normal and Reduced Effects. Reduced Motion is available in settings.
Controller aim stays inside the visible play window near map edges; its shorter
display distance does not change the accepted aim direction or spell range.

LIMITS
This is a portable local playtest. Historical installers and their receipts
describe their own older builds. Online automatic updates are not configured.
Multiplayer is experimental and requires the same build. Internet relay is not
deployed; minimal-effort play between homes is not established. Eight configured
players is not capacity certification; 16/32/64-player sessions are unsupported.
Same-LAN trial: Farflow Hall > Host on one PC, Join on the other; use local
discovery or the host's local IP. Both PCs must use the same build.
Historical dense-load probes missed the 120 Hz budget; this build has no new
dense-performance certification. Character animation cycles,
human feel, balance, audio quality and physical two-PC acceptance remain open.

Current documentation: docs/README.md in the repository. Expansion evidence:
docs/element-expansion-evidence-20261009/integration.md. Focused trial:
docs/HEX-PLAYTEST.md. Personal profiles retain the
existing Godot/app_userdata/FLUX 2 location for compatibility.
"@
 [IO.File]::WriteAllText((Join-Path $hexPayload 'README-FIRST.txt'),$hexInstructions,[Text.UTF8Encoding]::new($false))
 if ($CharacterArt -and -not $PixelCast) {
  $hexReadmePath=Join-Path $hexPayload 'README-FIRST.txt'
  $hexReadme=[IO.File]::ReadAllText($hexReadmePath).Replace('Skeleton mode is the default.', 'CHARACTER ART TEST: 30 individual source-detail skins with common skull proportions; 3 identities have authored low/air keyposes, 27 use shared-rig motion. Full authored animation cycles are NOT complete. PLAY-HEX.cmd enables the art; starting hex.exe directly retains skeleton mode. Body sizes and stats are unchanged.')
  [IO.File]::WriteAllText($hexReadmePath,$hexReadme,[Text.UTF8Encoding]::new($false))
 }
 if ($PixelBodyPilot) {
  $hexPilotNote = @"

FIXED-PIXEL BODY PILOT
S. Wayne, Oh Tipi and The Red Baron have new retro pixel banks for grounded
idle/walk/sprint/rooted and casts. No runtime mesh deformation in these frames.
Bodies face aim; backward travel reverses the gait. Dedicated sidestep art is
still pending. The two contact poses use neutral art on passing beats.
Slide/jump/roll/flight/control actions retain the previous working renderer;
other27 characters remain unchanged. This is NOT full animation completion.
Use TEST-S-WAYNE.cmd / TEST-OH-TIPI.cmd / TEST-RED-BARON.cmd for quick comparison.
Loom: scrolling over the library browses spells without changing destination.
New artwork changes visual proportions only; size-tier stats, hurtboxes,
wall clearance and all simulation rules remain unchanged.
Pilot scope and evidence: docs/HEX-PIXEL-BODY-PILOT.md in the checkout.
"@
  [IO.File]::AppendAllText((Join-Path $hexPayload 'README-FIRST.txt'),$hexPilotNote,[Text.UTF8Encoding]::new($false))
  foreach($hexPilot in @(@('S-WAYNE','s_wayne'),@('OH-TIPI','oh_tipi'),@('RED-BARON','red_baron'))) {
   $hexShortcut = "@echo off`r`ncd /d `"%~dp0`"`r`nstart `"H.E.X. pixel pilot`" `"%~dp0hex.exe`" -- --fullbody-art --pixel-body-pilot --champion=$($hexPilot[1]) %*`r`n"
   [IO.File]::WriteAllText((Join-Path $hexPayload "TEST-$($hexPilot[0]).cmd"),$hexShortcut,[Text.UTF8Encoding]::new($false))
  }
 }
 if ($PixelCast) {
  $hexReadmePath=Join-Path $hexPayload 'README-FIRST.txt'
  $hexReadme=[IO.File]::ReadAllText($hexReadmePath).Replace('Skeleton mode is the default.', 'PLAY-HEX.cmd selects the all-character pixel presentation, including tucked jump somersaults and ancestry flight. Starting hex.exe directly retains skeleton mode. Body art does not change collision geometry.')
  [IO.File]::WriteAllText($hexReadmePath,$hexReadme,[Text.UTF8Encoding]::new($false))
  $hexCastNote = @"

FULL-ROSTER FIXED-PIXEL GROUND/CAST CANDIDATE
All 30 current characters have fixed-pixel ground/cast banks. Non-fliers tuck
into a compact ball assembly for jump and double jump, with slower held quarter
turns that start from the actual lift. Second jumps reverse the tuck, including
during descent. Fliers retain original wing/body art on deliberate second-jump
flight, with longer, clearer wing poses. Walk and sprint poses are slower while
movement speed and input response stay unchanged.
Spawn shields use a shield badge and square-corner markers; dodge protection
uses a translucent body, slash badge, diagonal markers and a small remaining-time
meter only while its protection is active. The body becomes solid again on the
first vulnerable recovery frame. Reduced effects keep the same protection cues.
Dedicated strafe/backward, slide, roll, flight and independent airborne-casting
artwork are unfinished; working fallbacks remain. The tuck uses assembled
existing art. Proportions and continuous-motion appeal still need human review.
Animation decisions and checks: docs/element-expansion-evidence-20261009/native-review.md;
the preceding jump-art record is docs/reference-refinement-evidence-20261009/animation-followup.md.
Academy > Champions > Attune switches identity. For a direct start:
PLAY-HEX.cmd --champion=grace_reava (replace with an ID from the current catalog).
The pixel presentation flag does not change stats, movement, spell behavior,
hurtboxes or wall clearance; the same identity perks apply in both renderers.
"@
  [IO.File]::AppendAllText((Join-Path $hexPayload 'README-FIRST.txt'),$hexCastNote,[Text.UTF8Encoding]::new($false))
  foreach($hexTrial in @(@('S-WAYNE','s_wayne'),@('OH-TIPI','oh_tipi'),@('RED-BARON','red_baron'))) {
   $hexActionShortcut = "@echo off`r`ncd /d `"%~dp0`"`r`nstart `"H.E.X. movement test`" `"%~dp0hex.exe`" -- --fullbody-art --pixel-cast --champion=$($hexTrial[1]) %*`r`n"
   [IO.File]::WriteAllText((Join-Path $hexPayload "TEST-$($hexTrial[0]).cmd"),$hexActionShortcut,[Text.UTF8Encoding]::new($false))
  }
  [IO.File]::AppendAllText((Join-Path $hexPayload 'README-FIRST.txt'),"`r`nTEST-S-WAYNE.cmd / TEST-OH-TIPI.cmd / TEST-RED-BARON.cmd compare all three sizes without changing saved bindings. Academy > Champions offers all30 identities.`r`n",[Text.UTF8Encoding]::new($false))
 }
 $hexHashes=@(Get-ChildItem -LiteralPath $hexPayload -File | Sort-Object Name | ForEach-Object {"$(Get-FluxFileSha256 $_.FullName)  $($_.Name)"})
 [IO.File]::WriteAllLines((Join-Path $hexPayload 'SHA256SUMS.txt'),[string[]]$hexHashes,[Text.UTF8Encoding]::new($false))
 $hexZip=Join-Path $hexOutput "HEX-$($hexIdentity.build_id)-Windows-x64.zip"
 Compress-Archive -LiteralPath (Get-ChildItem -LiteralPath $hexPayload -File | ForEach-Object FullName) -DestinationPath $hexZip -CompressionLevel Optimal
 [ordered]@{status='passed';build_id=$hexIdentity.build_id;runtime_source_sha256=$hexIdentity.runtime_source_sha256;executable=$hexExe;pack_sha256=(Get-FluxFileSha256 (Join-Path $hexPayload 'hex.pck'));zip=$hexZip;zip_sha256=(Get-FluxFileSha256 $hexZip);export_smoke='native launch plus source identity and safe close';logs=$hexLogs;installer='NOT_RUN';checkpoint_promoted=$false} | ConvertTo-Json | Set-Content (Join-Path $hexOutput 'receipt.json') -Encoding utf8
 Write-Output "PASS: H.E.X. portable $hexZip"
} finally {$env:APPDATA=$hexSavedAppData;Exit-FluxEngineRun $hexLease}
