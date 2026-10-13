# H.E.X. player guide

Status: **development is active; this guide's qualified portable is p60-1e084a50a029.**
The [October 13 iteration](iteration-20261013/README.md) tracks the new working candidate.
Open the [current launcher](../exports/hex-iteration-20261012/windows/PLAY-HEX.cmd),
or extract the [Windows x64 ZIP](../exports/hex-iteration-20261012/HEX-p60-1e084a50a029-Windows-x64.zip)
(161,159,896 bytes; 153.7 MiB) into its own folder before launching.
These are local files. The [README](../README.md#install-or-play-on-windows)
explains source setup and portable use.

The [Full run](iteration-20261012/full-final.json) passed 261 suites /
7,543,825 assertions with zero failures and stderr, including the 120 Hz boot check.
The matching portable passed [package/archive](iteration-20261012/delivery-files.json),
[133-image terrain](iteration-20261012/terrain-pack.json) and
[five-case normal-close/reopen checks](iteration-20261012/portable-lifecycle.json).
The [current performance record](iteration-20261012/foreground-current-record.json)
passes its focus and source checks, but steady 60 FPS is not yet achieved.
Physical-controller behavior, human balance and movement feel remain acceptance work.

The [be680 fallback launcher](../exports/hex-smoothness-20261012/windows/PLAY-HEX.cmd)
and [smoothness record](smoothness-20261012/README.md) remain available.
The [845f fallback](../exports/hex-comprehensive-20261012/windows/PLAY-HEX.cmd)
retains its [comprehensive record and 196 UI captures](implementation-20261012/README.md).
The [d8 audit](audit-implementation-20261011/README.md) and
[be3 performance evidence](performance-implementation-20261010.md) describe their own earlier builds.
The [portable record](iteration-20261012/README.md) owns the evidence for this playable build;
the [active iteration](iteration-20261013/README.md) owns ongoing work.

## Start small

Move with **WASD**, aim with the mouse, and try one of **1–4**. **Ctrl+1–4**
and **Alt+1–4** are the other eight positions in your twelve-spell weave.
Your saved control choices take precedence; the game shows current bindings.
Spell prompts follow the last deliberately used keyboard/mouse or controller.
Controller drift does not switch the prompts. A missing binding is shown as
unbound so a keyboard fallback cannot conceal a missing controller action.

The optional **Introduction / F5** follows your actual movement, jump, paid
cast and Flux recovery. It does not take control, equip a spell, spend resources
or require completion. Use **Skip guide** or F5 whenever you want to explore.
The final optional steps introduce a mixed spell in the Range.

**Menu → Tactical lessons** adds an optional sequence: execute a paid movement
chain, damage a target with a mixed spell, evade a Signature rival's attack,
then win cleanly and save the learned spell. It observes actual accepted
actions and results. Range changes and challenge entry keep this guide active;
Developer tools cannot complete it. At narrow layouts, **Why / details** or
**Menu → Guide action / explanation** switches between the task and its explanation.

| Open | Default shortcut | Purpose |
|---|---|---|
| Menu | Esc / controller Back / click Menu | Contextual access to the map, practice and settings |
| World map | M or Menu → World map | Inspect the world and choose a travel destination |
| Compendium | F4 or Menu → Compendium | Inspect movement, elements, combinations and their counters |
| Introduction | F5 | Learn basic actions by doing; skip at any time |
| Spell Range | F6 | Borrow any mixture/delivery and test it with explicit reset tools |
| Signature Challenges | Shift+F6 | Fight a rival to earn that rival's spell |
| Developer tools | Shift+F5 | Clearly marked local overrides; no earned progress |
| Services | F at a building door | Controls, Gallery, Spell Loom, practice and session options |

One **Menu** button replaces the separate activity buttons. Its choices change
with the current place. Esc or controller Back opens it during free play; Esc closes an open panel;
during a challenge, Esc returns to Wellspring instead. The challenge card keeps
the next-rival and Developer shortcuts, while the Menu button stays hidden.
Custom gameplay bindings take priority over Esc/M and F5/F6 convenience keys.
F7 retains the movement-reference preset shortcut; sight is no longer a setting.
Menus consume their own inputs so a
selection does not cast a spell in the world.

## Display and readable text

Open **Menu → Display & text size**. **Low** reduces decorative
glow and extra Garden details; **Standard** restores those embellishments.
Spell footprints, warnings, character poses and movement rules stay readable in
both. **Reduced Effects/Motion** remains a separate accessibility preference.

The default limit is **60 FPS**, with **120 FPS** and **Unlimited** available.
This is a maximum, not a promise that the hardware will reach it. Changes save
locally. Arrow keys or the controller select and change a row; clicking the
left or right side changes its value. **Esc / B** closes the panel.

**Text size** offers **100%, 125%, 150% and 200%**, independently of the fixed world
camera. Narrow windows also use a reading layout at 100%. The Loom and Range
show one selected spell with pages of full details; Controls shows one device
tab and a scrollable action list. Previous/Next buttons, mouse wheel, keys and
controller navigation keep every selection reachable. Menu and map lists also
page when their rows would no longer fit. The compact HUD moves its four active
spell cards into two columns when necessary. The Chemistry demo reflows to two
ingredient selectors with paged recipe details and explicit tools. Small service
directories show one service at a time; arrow buttons, keys or the controller
reach every service and its full details before Open.

The Compendium and Champion Gallery also use the enlarged reading view. At the
smallest layout, the selected name and useful facts stay visible while
**Options / O / controller Back** reveals category, portrait or filter controls. Existing controller
category and facing shortcuts still work. In the compact Loom, **Options / O / L3**
reveals filters and browsing focus. In the compact Range, **Setup / T / X**
contains delivery selection and the explicit tools; **More / O / L3** pages them.
Previous/Next detail buttons retain complete descriptions without shrinking text.
Controller reference shortcuts remain direct: shoulders change Gallery size groups
or Compendium categories; D-pad selects entries. Gallery Start toggles the portrait
and stick clicks change facing. In Compendium chemistry, right-stick click opens
combinations, D-pad chooses an ingredient and A toggles it. X/Y pages details.
In compact Gallery/Compendium, Back switches between Options and reading; B
closes. The visible ingredient picker outlines its current controller focus.

Controls also exposes separate **movement deadzone** and **aim deadzone** settings.
Adjust the stick that needs correction independently. Four digital aim directions
can be bound in Controls; they start **unbound** so existing custom keys remain
available. Mouse aim and existing controller aim continue to work. Releasing
inputs after a menu or focus change prevents held input from unexpectedly acting.
In enlarged Controls, **Aim cue** toggles the visible aim highlight.

Fast travel can briefly show **Preparing this area…** while terrain and Garden
exhibits become ready. Offline control resumes when the complete view is ready.
Walking keeps its normal controls. The [current performance record](iteration-20261012/README.md)
records the tested build and remaining limits; steady 60 FPS is not yet achieved.

## Read the current view

Your character's 360-degree view covers the screen, including its corners as
the camera moves or the window changes. Spectating follows the watched character.
Gameplay uses fixed **75% camera framing**; the old F11 zoom shortcut explains
that fixed framing rather than changing it.
Opaque buildings, active solid hex cover and chemical concealment still hide
characters and their attached information; a wider view does not see through cover.

Raised spell faces and grounded shadows help separate projectiles from the floor.
Element sectors identify mixtures. These cues do not enlarge a hit area or make
a forming warning dangerous before its active phase. District floor motifs help
identify routes and places while keeping route centers and arrival spaces clear.
Short neutral movement wakes follow the displayed body through turns and fade
quickly. They are not extra bodies or damaging ground effects. Reduced Effects
removes these wakes while retaining the important movement and protection cues.

Cast and contact sounds have distinct short cues. Local damage, refused casts,
landing, wall exit and earned spell confirmation have their own quiet cues;
consequences get priority before new cast chatter. These do not reveal hidden
enemy positions. New preferences start at
**30% sound volume**; your saved setting takes priority. Change it in Controls.
Reduced Effects retains essential warnings and protection cues. Movement feel,
continuous-motion clarity and sound quality still need physical play and listening.

## Find a place and travel

Open **World map**, select a named row or its matching numbered pin, and read
the destination description. **Details / C / controller Y** pages its district,
practice purpose and suggested district connections. Highlighted connections
follow authored routes; choose how to negotiate local walls and cover yourself.
At the smallest layout only the selected pin appears, while the named list keeps
every destination reachable. Selection only highlights a place. Choose **Travel**
or press **Enter / A** to go there. Arrows, D-pad or the left stick change the
selection; page buttons reach the remaining destinations. **Esc / B** closes.
The map identifies your current area and marks you with a diamond.

With a controller, **Back → World map** opens the same overview.
The Map action, M and L3 also work inside the Compendium. **Start remains
the existing emote control.** In an isolated Range, the overview says “Away from
Wellspring”; return before travelling.

There are **13 named destinations**, including Element Garden in Tideglass. Wellspring, Academy, Movement Garden,
Farflow Hall, Pattern Range, Duel Court, Crucible and Recovery Grove retain
their familiar services and practice spaces. Four new areas give you more room
to explore:

| Area | Try there |
|---|---|
| Tideglass Quays | Long shore approaches and contact chains along jetty walls |
| Verdant Reaches | A long garden loop, braking corners and routes through the grove |
| Basalt Foundry | Perpendicular cover, committed wall turns and open bypasses |
| Starward Terraces | Broad sightlines, short contact chains and an outside route |

The district coach tracks different optional routes: shore sprint → marked
wall contact → walljump; grove speed → braking → controlled walking rejoin;
foundry wall contact → direction change → landing behind real cover; terrace
slide → slide jump → landing and Stamina recovery. Accepted movement advances
the steps. The coach grants no refill or reward, and leaving the district
restarts it. Every district keeps its walking bypass.

Fast travel is for **offline free exploration**. Land and finish the current
action; let your shots and status effects end, and recover from a recent hit.
Rounds, challenges and isolated practice require a return to Wellspring first.
Blocked or occupied arrivals are refused with a message inside the map.
Travel itself does **not** refill Health, Flux or Stamina, reset spell cooldowns,
or change your character or weave. These routes and visuals passed local structural and native checks; human wayfinding and physical playtesting remain open.

## Walk the Element Garden

Choose **Menu → World map → Element Garden → Travel**. Walk among 63 named
plots, ordered from single ingredients through the all-six mixture. Approach
a plot to read its ingredients, current phase, effect, counter and time until
the next phase. No extra inspect button is required.

The six single-element plots alternate one raw deposit with the reaction from
two matching sources. The other 57 plots show mixed fields. Together they show
**six raw ground materials and all 63 reaction identities**. A single Water
deposit is ingredient matter; its separate two-source Frostway phase teaches
the actual freezing field.

These are **harmless, bounded exhibits** that expire and repeat. They do not
spend your Flux, grant progress or reset your weave. Long fields are clipped
to their plot; use **Spell Range** to test full combat size, payment and damage.
Your own spells remain live in the garden, so their ground effects remain
visible above the exhibit.

## Read three resources and three kinds of effect

**Health** shows how much damage you can still survive. **Flux** pays spells when startup is accepted.
**Stamina** pays movement techniques. Recovery has a wait; holding a denied
cast is different from pausing attacks and allowing resources to recover.
A spell's cooldown begins at release and belongs to that spell even if it moves
to another slot. Swapping positions is not a cooldown reset.

A hit can cause **damage**, a temporary **status**, a **terrain/field effect**,
or several together. Damage subtracts Health. Status changes an actor's behavior
or condition for its stated duration. Terrain and fields affect their visible
occupied cells, with their own formation, active and fading phases. A vivid
effect is not automatically active danger; read its phase and the counter.

## Ingredients choose the payload; delivery chooses how it arrives

The six ingredients are **Water, Fire, Air, Earth, Light and Dark**. Ice comes
from Water's effects, and Charge from Fire's effects; they are not extra
selectable ingredients. There are 63 nonempty ingredient sets, including the
six single elements and the all-six mixture. Each can use all eight deliveries,
giving 504 definitions. You still equip only twelve at a time.

| Delivery | What to try | What to watch |
|---|---|---|
| Bolt | A focused travelling shot; hold for repeat fire | Aim, cover and repeated Flux cost |
| Heavy | A deliberate slower shell with impact splash | Startup, the real splash boundary and cover |
| Rapid | A short burst of small repeated shots | Low strength per shot and sustained resource use |
| Spray | A short fan for nearby coverage/interception | Fan range and the individual cover-clipped directions |
| Mantle | Approach with a contact effect around the caster; movement leaves a finite paid ground trail | Close spacing, its finite lifetime and shared material budget |
| Fuse | Place a delayed explosive to challenge a route | Its visible warning; leave the marked blast before detonation |
| Split | Send a shot that divides into bounded branches | Branch coverage shares the paid source; it is not free extra matter |
| Rebound | Test an angle that banks off a wall | Limited banks and lifetime; it does not home onto a target |

In the working source follow-up, Bolt, Rapid, Split and Rebound travel faster
than the movement cap in clear space. Their finite reach remains bounded;
Heavy and Fuse keep slower roles. Cover, lateral movement, a paid jump and
Frostway's slowing field remain useful responses. Faster travel does not add
damage or make every delivery a fast shot.

Use the actual **Effect** and **Counter** text for the selected mixture. Those
explain the payload; the delivery changes how you place it. Compound spell
names do not grant undocumented healing, immunity or endless damage.
For a single ingredient, the described self-reaction field needs two matching
paid sources to meet. One Earth Bolt does not automatically raise a Rampart.
A mixed payload carries its field recipe directly, subject to its real delivery,
collision and finite material rules.
Mixing existing fields consumes accounted material and preserves finite
deadlines. Their current phase is more useful than assuming every new-looking
field gets a fresh full lifetime.

Successful enemy hits also carry bounded ingredient statuses. They require
actual Health loss; a protected or zero-damage contact cannot add a status.

| Ingredient | On-hit status | Practical meaning |
|---|---|---|
| Earth | Fractured Focus | Slows a future cast's startup; does not retime one already paid |
| Fire | Burning | A small finite damage pool pulses; it is not an unlimited stack |
| Water | Chilled | Slows ground target speed; it does not reduce air steering |
| Air | Gusted | Shoves once on entering its window; refreshing is not another launch |
| Light | Revealed | Helps reveal the target subject to physical cover |
| Dark | Withered | Temporarily blocks ready Flux recovery; an ordinary damaging hit already delays Health recovery longer than this status. Stamina remains separate |

## Build a weave without losing the old one

The **Spell Loom** first focuses the selected slot's ingredients and the four
core deliveries. The wide overview uses **More Forms** to reveal Mantle, Fuse,
Split and Rebound; the compact reading view uses the form arrows to reach all
eight deliveries under **Options** at the smallest layout. Ingredient buttons combine into an exact mixture filter.
Filters and pages keep the full catalog reachable without showing hundreds of
cards at once.

Select a spell and a destination, then assign. In the wide overview you can also
drag the spell onto a slot. In the compact view, **Browse / Tab / controller Y**
switches spell/slot focus; **Previous/Next** selects and **Assign / Enter / A** confirms.
An already-equipped spell swaps positions; a new spell replaces one position.
The preview tells you which will happen. Merely inspecting the Loom changes
nothing. Locked signature cards identify the rival that teaches them and point
to the Range for a free temporary trial.

**Compare / C / right-stick click** compares the selected spell with the equipped
spell, including Flux, cast cycle, direct hit or shared damage pool, field purpose
and counter. Comparison details name the equipped and selected spells before
their values; wider reading layouts keep the selected name visible as you page.
Read the complete detail pages: these values are not sustained DPS, and ground
damage remains separate.

The selected spell's timing uses your current character, status and effective
simulation ticks. Preparation checks the condition **before Flux payment**;
cooldown checks it **at release**. The comparison therefore describes the current
projection, not a promise that a perk threshold will survive payment. A paired
speed/cooldown perk is held back when rounding would
remove either its benefit or its trade-off. The Loom names that held pair rather
than promising a speed change that cannot happen.

Existing valid saved/equipped spells retain access. Older elemental weave
migrations show the proposed replacements before Apply and preserve the
original-file backup. If a save fails, read the message: a working session
change is not automatically a saved change.

## Test every spell in the Range

1. Open **Spell Range**. The wide overview places mixtures on the left and deliveries on the right. In the compact reading view use the visible mixture arrows; **Setup → More** reaches delivery selection at the smallest layout. Mixtures start with the six single elements, then pairs, then larger mixtures.
2. Read the ingredients, **Flux / startup / cooldown**, **On damaging hit**,
   **Field**, **Counter**, and any delivery warning.
3. Choose **Equip**. This creates a temporary loaner in slot 1; it does not cast.
4. Close the selector, aim, and press the normal slot control. Real resource
   payment, collision, protection, damage and status rules still apply.
5. Use **Refill**, **Reset cooldowns**, **Reset targets** or **Clear fields**
   deliberately when you need a repeatable comparison. Changing a selection
   alone does not reset a cooling spell.

Open **Setup / T / X** to choose a still or moving target, toggle its firing,
choose Small/Medium/Large size, and inspect observed casts, Flux and damage.
Target firing uses ordinary paid commands and finite resources. Changing a
setting does not heal or refill anyone. **Reset statistics** begins a new
observation window without resetting combat state. Use **More / O / L3** to
reach the separate refill/reset/clear, guide and delivery controls.

Opening the Range while inspecting an **Element Garden** plot selects that
plot's mixture. The exhibit itself is harmless and bounded; explicitly equip
and cast the preset in the Range to test paid combat effects.

Outside the selector, open **Menu** for **Change Range spell**, **Spell Loom**,
**Characters**, **Reset practice court** or **Return to Wellspring**. The temporary
loaner label stays visible during practice. Steam exposure appears only while
you have accumulated exposure; there is no permanent help panel over the court.
Introduction/Skip introduction is available here too; starting a fresh lesson
returns you to ordinary Wellspring, while Skip simply ends the current guide.

Keyboard/controller users switch between the list, delivery choices and tools
with Left/Right or Tab, then move with Up/Down and activate with Enter/A.
PageUp/PageDown or the shoulder buttons move through longer lists. Pointer
buttons address the same choices. **Clear fields** also retires live shots and
pending casts through the local testing path; it does not create a refund.

Choose **Menu → Return to Wellspring** to return to your own weave. Range loaners never become
a saved character weave or an earned unlock. Changing loaners preserves each
spell's cooldown; leaving the practice world starts a fresh ordinary world with
your original weave. The Range lets you explore trade-offs; all 504 choices
still require balance playtesting.

## Learn a rival's signature

Every one of the 30 current characters has an assigned signature challenge.
The optional suggested path is **Wa Bidi in Conservatory Gap Court**,
**Oh Tipi in Tideglass Fuse Court**, then **S. Wayne in Basalt Bank Court**.
It teaches pressure gaps, delayed-area exits and bank geometry in distinct
courts. The suggestion follows earned progress; every challenge remains
selectable in any order.
Read the spell, windup and counter before beginning. Rivals cast through the
ordinary paid simulation; they can run out of resources or have a cast refused.
A visible pause means no new rival commands, not that existing shots or fields
have stopped being dangerous.
Each delivery now has its own approach distance and rhythm. Rapid uses separated
bursts, Mantle closes the gap, Fuse makes you read its delayed blast, and Rebound
can choose a verified bank off a real wall. The final tell stops the rival's
steering before its committed attack; each pattern leaves a readable recovery.

A clean victory teaches that rival's signature spell. Actual owned damage and
defeat must occur in the bound encounter. Mutual defeat, leaving the court,
timeout, or a developer attempt does not earn it. Repeat victories do not
duplicate unlocks. The result distinguishes a newly learned spell from one
already learned, and says when a save failed. Earned progress is separate from
controls and saved weaves.

If progress remains unsaved, **Menu → Retry progress save** stays available.
The finished challenge also offers a clickable retry, with **X** on controller.
Successful saves maintain a verified rolling last-good backup alongside the
original pre-save copy. When a saved file is missing or damaged and a validated
backup exists, **Recover progress backup** is an explicit action. It preserves
a damaged copy before restoring the backup and merging
spells learned in the current session. The game does not silently replace your
progress with defaults. Return to Wellspring with Esc/Back to reach the Menu.

**All 30 characters are already playable in the sandbox.** Signature learning
unlocks spells; it does not add an invented character grind. The original
24 spells remain freely available. You can borrow locked signatures in the
Range before choosing which challenge to attempt.

## Move and read protection honestly

Press **Jump** to prepare and release it to launch. A non-flying character uses
a compact tucked first jump and a visibly reversed second tuck. A flying race
also starts with the ordinary first jump; deliberately press Jump again while
airborne and hold it to spend its finite flight budget. The body keeps the
authored identity and slower held poses, without delaying accepted movement.

Build speed before Slide; side input carves and opposite input brakes.
Release and press Slide again for the dedicated slide brake. Directional
air-dodge spends Stamina; neutral Evade descends. The Compendium gives the
current costs, thresholds and precise wall/landing chain instructions. Optional
route-choice details compare open braking, a wall approach/release and combat
re-entry. They explain exposure and base costs plus the current next-action
projection; later actions still recheck their own conditions and costs.

Spawn protection has an **opaque shield** cue. The short protected opening of
a roll or air-dodge uses **translucency, slash marks and remaining-window pips**.
When the character becomes opaque again, two low flat bars mark the vulnerable
recovery tail. They disappear with the action, and never extend protection. Jump height,
flight and a low profile clear appropriate threats; they do not grant blanket
immunity or let the body pass through walls. Reduced Effects keeps the same
meaning even when motion and decoration are reduced.

## Developer tools are a temporary testing session

Open **Developer tools** when you explicitly want overrides. The visible DEV
label remains while the session is active. Available tools include all-spell
access, actual damage protection, infinite Flux/Stamina, no cooldown, and
**Pause rival commands**. That last option suppresses new rival input; existing
motion, paid startups, projectiles and fields continue. No time-scale control
is introduced.

All-spell access is a session override, not an earned grant. A developer
attempt stays ineligible for rewards even if its toggles are switched off
before victory. Choose **Leave Developer** to end the tools; merely closing its
menu keeps the visible session active. World/network transitions end overrides
and restore temporary weave state. Developer choices are not written into the
earned progression file.

The same tools offer **Record 60-second replay** and **Export recorded replay**
for an explicit offline bug reproduction. Continuous resource/protection cheats
must be off. Recording has diagnostic overhead and stops on world changes or
reset actions; it keeps the completed commands available to export. Export writes
a local diagnostics file and does not upload anything. Its message explicitly
says that deterministic verification has not yet run.

For exact executable values and scope, use the [specification](../SPECIFICATION.md).
For source/package qualification, use the [handoff](../.agent/HEX-RESUME.md).
