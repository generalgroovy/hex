# H.E.X. playtest route

Status: human playtest route for the locally qualified 504-spell, enlarged-Wellspring
build `p60-6d80c3bce71e`. The [central handoff](../.agent/HEX-RESUME.md)
and [README](../README.md) identify its exact source, portable package and executed
checks. This route records the remaining human acceptance work.

This route checks understandable choices and useful counters. Automated tests
establish the recorded behavior; a player session must still establish feel,
readability and balance. Record the exact build, character, control setup and
Normal/Reduced Effects setting with each finding.

## Start and recover

The [README](../README.md#install-or-play-on-windows) owns launch links. A
qualified portable needs its entire extracted folder and `PLAY-HEX.cmd`.
Development source uses `scripts/run.cmd --pixel-cast` with pinned Godot 4.7.1.
Prefer 1280×720 for the current text and native pixel inspection.

Walk with WASD and aim with the mouse. Saved bindings take precedence; inspect
Controls for keyboard and controller equivalents. F opens a nearby service and
F4 opens the Compendium. Esc or controller Back opens the compact Menu in free
play; Esc closes an open panel. Click the single Menu button for the same choices.
Menus do not pause shared gameplay. Start retains its existing emote action.
The Rest Pavilion and practice reset provide a clear return to a known state.

For a short first session, use the optional introduction: move, release a prepared
jump, pay for one spell, let Flux visibly recover, enter the Range, then equip and
cast a mixture. Default F5 starts/skips it; F6 opens the Range. Shift+F6 opens
Signature Challenges and Shift+F5 opens offline developer tools. Each is also a
menu action; custom bindings take priority. Skipping must not cast, equip or save.
Only actual actions advance the lesson, and an open panel must not advance it.

## Map and the expanded world

Open **Menu → World map**, or press **M** when it is not a custom gameplay bind.
With a controller, use **Back → World map**. Check pointer, arrows,
D-pad and stick selection at 1280×720 and 960×540. Named rows and numbered pins
must identify the same place; selecting alone must not move the character.
The player diamond and current-area label should follow actual position.

Visit all **13 destinations**. Keep the familiar Wellspring/Academy services,
Movement Garden, Farflow Hall, Pattern Range, Duel Court, Crucible and Recovery
Grove reachable. Compare the four new areas through ordinary movement:

| Area | Observe |
|---|---|
| Tideglass Quays | Shore approaches and real jetty-wall contact routes |
| Verdant Reaches | Long loops, readable braking corners and open grove paths |
| Basalt Foundry | Perpendicular cover with usable turns and clear bypass lanes |
| Starward Terraces | Broad sightlines and a choice of contact chains or an outside path |
| Element Garden | 63 plots across Tideglass; six raw/self cycles and 57 mixed cycles with nearby explanations |

At the Garden, inspect a raw element, its same-element reaction, and mixtures
with two through six ingredients. Walk away and open a menu to check that the
card disappears. Watch formation, active effects, decay and the clear reset
interval. The bounded exhibits are harmless; cast a real spell onto a plot to
check that live material remains visible above the sample. Use Spell Range for
full-footprint damage, movement and counterplay testing.

Use **Travel / Enter / A** from eligible offline free exploration. Check that
travel itself preserves Health, Flux, Stamina, spell cooldowns, character and
weave. Compare values immediately around travel, allowing ordinary recovery
over elapsed play time. Airborne/active actions, recent damage, statuses and
live owned shots must show a useful refusal, as must a blocked or occupied
arrival. The reason must remain readable inside the map.

An online session or active round must not gain travel permission. In the
isolated Range, the overview must say “Away from Wellspring” without placing
the Range's local coordinates on the campus. Return before travelling. A
challenge keeps Esc as its exit and hides the Menu entry; clicking the hidden
entry area must not interrupt the fight. Custom gameplay bindings retain
priority over convenience shortcuts, and rebinding capture must retain input.

The [map design record](large-wellspring-evidence-20261009/map-overview.md)
separates established navigation precedents from local layout hypotheses and
records the passed native checks and remaining human wayfinding boundary.

## Movement and animation

Compare a Small, Middle and Large non-flyer, then Grace Riva and a winged race.

| Try through existing controls | Observe and countercheck |
|---|---|
| Walk → Shift sprint → C slide while aiming sideways | Slide captures travel and adds one paid capped boost. Aim does not rotate travel. Opposite input brakes; a later press cannot restore lost speed for free. |
| Slide → press/release Space → fresh C shortly before landing → release/jump again | Jump inherits remaining momentum. C commits fast-fall and can buffer one paid landing Slide for 100 ms. Low speed, cooldown or depleted Stamina prevents that purchase. |
| First and second airborne Jump with a non-flyer | Both use a compact native tuck. Slow turns follow rise/descent; the paid second jump folds more deeply and reverses the turn. Compare the same facing. Charged rise holds the opening longer, terminal descent stops rotating, and landing restores the grounded pose immediately. The visual does not shrink the hurtbox. |
| First Jump, release, then airborne second press/hold with a flyer | First Jump remains ordinary. Only the second press buys finite flight with the original open body and held wing keys, each lasting 200 ms. The central face and torso stay stable. Release, exhaustion, expiry or landing ends the pose immediately; repeated input cannot refill its airborne allowance. |
| Directional B in the air, then a deliberate V turn after commitment | The paid redirect uses remaining momentum and the existing dodge timer. It grants no extra immunity or free air action. |
| Fresh C during an early air dodge and actual landing | The existing fast-fall wavedash route works; it does not also purchase the new landing Slide. |
| Ground roll / air dodge / freshly spawned actor | Spawn protection keeps an opaque body and shield markers. Timed dodge protection makes the body translucent with split marks, slashes and remaining-window pips. Recovery immediately restores opacity and removes those cues. Compare over stone and earth at 100% and 75% zoom. Ordinary jumps and flight grant no immunity; none of these cues imply passing through walls. |
| Repeat with Reduced Effects and Reduced Motion | Reduced Motion holds the upright tuck and open wing pose. Essential attack and protection distinctions remain, including exact protected/recovery boundaries. Slower footwork and held keys do not add input delay. |

The [expanded native review](element-expansion-evidence-20261009/native-review.md) and [preceding animation review](reference-refinement-evidence-20261009/animation-followup-native-review.md)
records the sampled visual pass and compact-detail limits at 75% zoom. Its arranged
states do not replace this physical-input route or establish continuous-motion feel.

Also try a wall approach, held Jump attachment and release into a legal walljump.
The body should face the wall tangent, lean toward contact, and show its remaining
wall time beside that contact. A blocked attachment braces instead of scraping.
Check at 75% zoom with a nonzero camera position; the body and contact must stay
together. These are attachment cues, not protection or extra wall time.
An interrupted or discarded held gesture must not later purchase surprise flight
or wall attachment. Open a menu or lose focus during preparation: it cancels
intent without an unintended jump or refunded paid action.

## Spell rhythm and countercasting

The Loom offers all 63 nonempty combinations of six ingredients in eight
families: 504 named spells across twelve equipped positions. Thirty signatures
are earned from rivals; the original 24 spells stay available. The offline Range
loans any spell for testing without learning or saving it. Inspecting a spell or
choosing a loaner must never fire it.

| Try | Useful difference and counter |
|---|---|
| Hold Rapid, track a moving target, then deliberately rest | Frequent small shots produce pressure and spend two Flux each. Stopping lets recovery begin; empty-held firing is not a sustainable damage-rate claim. |
| Hold Bolt at the same target | A more substantial focused shot travels more slowly and follows its own cadence. No free radial blast is added. |
| Fresh Heavy into open ground, then near narrow cover | A large, slower paid shell gives a clear avoidance interval and impact area. The muzzle cannot pass through cover. |
| Fresh Spray at close range across a partial obstruction | The immediate fan intercepts and threatens exposed targets; covered rays and newly broken cover still protect their shadow for that resolution. |
| Mantle, then approach and move away | Touch threatens nearby enemies and movement leaves limited trail pieces. The same enemy cannot repeatedly drain the shared pool. The open attack ring is not a shield; compare ordinary incoming damage. |
| Fuse into open ground, then beside cover | Landing is harmless. Read the separate countdown and clipped blast boundary, leave before its 600 ms deadline, then compare two occupants sharing the finite blast pool. |
| Split down a lane, then toward narrow cover | One parent becomes two branches after 250 ms. Each branch has only its share of the original damage and material; neither splits again. |
| Rebound toward an angled wall | Follow up to two visible banks. The shot preserves its budget and lifetime; it must not home toward a target or create extra shots. |

Compare the same family across Water, Fire, Air, Earth, Light and Dark. Existing
paid projectiles retain their finite strength when intercepted or slowed.
Faster firing must not duplicate a shot's damage, material or ownership.
Then compare a singleton, a pair and all six in one family: additional ingredients
raise the paid cost and shorten status duration; they do not multiply direct
damage or material. Hold each new family's control after one press: Mantle, Fuse,
Split and Rebound require a fresh press for another cast.

## Distinguish hits, statuses and terrain

Use a living opponent or Range target, with developer protection and resource
cheats off. First land an ordinary paid hit; then repeat against a protected
actor and after the status expires. No blocked hit should apply a status.

| Ingredient on the hit | Check with an ordinary action |
|---|---|
| Earth | A new cast prepares more slowly; a cast already paid before the hit is not retimed. |
| Fire | Burning spends a finite pool and stops; repeated hits refresh one pool rather than stacking many. |
| Water | Ordinary ground travel slows, but jumping does not lose air steering. Another slow must not multiply it. |
| Air | The first hit shoves; repeated hits during the same active window do not repeatedly shove. |
| Light | A concealed target becomes readable; a solid wall still hides it. |
| Dark | Ready Health/Flux recovery waits while affected; Stamina restoration remains separate. |

Try a mixed hit and identify its ingredient badges in both effect settings.
Badges must end with their real timers; they do not imply armor or stun. Detailed
Loom/Range teaching should remain readable even when a tiny Rapid projectile
cannot show six individually legible glyphs in motion.

## Combinations and counterplay

Inspect the six-by-six pair matrix, then select ingredients in the combination
builder. All 63 definitions should show a purpose, warning, payoff and counter.
Guided pair demonstrations perform two ordinary paid casts. A named mixed spell
can also form its reaction from its own paid terminal; a singleton still deposits
an ingredient and needs another paid source for its self-reaction. Test both
direct mixed casting and larger combinations of independently funded fields.

Start with a longer-lived pair such as Earth + Water, then add Air, Fire, Light
and Dark into occupied material. Every upgrade must add an ingredient. The
result inherits the earliest expiry, so a late extra cast may be refused;
short-lived first pairs do not support a leisurely six-cast sequence.

| Representative result | Meaningful counter to try |
|---|---|
| Water + Water: Frostway | Slide or jump across; compare ordinary grounded travel and physical projectile travel before, inside and after the marked cells. |
| Fire + Air: Arcstorm | Leave its warned line before activation. Check a split paid shot cannot hit again after fusion consumes its source. |
| Water + Dark: Black Ice | Enter, then jump out; compare against the first grounded exit. Repeated crossings must not repeat its one-time fracture. |
| Air + Dark: Shadowdraft | Time a crossing for the clear interval instead of remaining through damaging concealment. |
| Light + Dark: Penumbra | Avoid the boundary or shelter in the center; repeated crossings cannot reset its damage latch. |
| All six: Convergence | Read its one-hit ring and safe center. Ground flow/traction, slower travel/shots, reveal and blocked recovery remain distinct from the direct spell hit. Compare a paid Convergence spell with incremental field fusion; neither may refill spent damage or extend an inherited oldest lifetime. |

Every damaging result shares a finite pool across all victims. Compare one
opponent against several occupants, then merge after some damage is spent.
The child inherits only the remainder plus genuinely new paid contributions.
Raw Fire, Steam and Conflagration can also harm the caster and allies.

## Characters, weaves and menus

Each of 21 races and 30 characters has a distinct situational passive using
existing controls. Gallery overview shows both, and Details explains the trigger,
benefit and tradeoff. Trigger each deliberately, then leave the condition; check
that the benefit stops without changing unrelated base stat bars.

Inspecting a champion never equips it. Attune changes a legal grounded character
and restores its saved weave or starter. Every new starter contains six Bolts,
a dominant-affinity Heavy and five experiments. In the Loom, verify empty,
unbound and unavailable positions remain distinguishable.

An older saved Ice/Charge weave opens a per-slot migration preview. Cancel must
leave its file and current actor unchanged. Apply must use host confirmation and
preserve the exact original-file backup before persistence. Reopen after applying:
there should be no repeated migration or missing/duplicate replacement slots.

## Range, signatures and optional tools

1. In the Range, select a mixture and family, inspect its name, cost, status and
   terrain counter, then equip the loaner and cast with its normal control.
   Choosing alone must not spend Flux. Try the selector's reset, refill and clear
   tools separately. Outside it, Menu contains Change Range spell, Spell Loom,
   Characters, Reset practice court and Return to Wellspring. Check that these
   replace the former button strip and persistent help panel. The loaner label
   remains, while Steam exposure appears only above zero and clears afterward.
   Choose Return to Wellspring: the original twelve positions must return in the fresh ordinary world,
   and reopening the saved weave must not show a loaner or an earned signature.
   The same-actor loaner restoration helper preserves elapsed original cooldowns;
   leaving the Range creates a new world rather than carrying that actor's timers.
2. Start a Signature Challenge with developer tools off. Observe the rival's
   committed cast and recovery, win using actual paid damage, and check that
   exactly the shown signature becomes available. Retry an already won challenge:
   no duplicate reward. All 30 characters remain selectable regardless of wins.
3. In a separate disposable attempt, use developer protection, unlimited
   resources, no cooldown or paused rival commands. Confirm the visible session
   label and verify that no signature is earned, even after disabling the tool.
   Pausing commands must not pretend existing shots or paid casts have stopped.
4. Exit developer tools and enter ordinary play or a network session. Temporary
   protections, resource overrides and all-spell access must end. If saving earned
   progress fails, the message must distinguish session access from saved access;
   do not count a failed save as persistence.

The [progression and teaching evidence](element-expansion-evidence-20261009/progression-testing-design.md)
connects the rival-weapon loop to Mega Man and the optional lesson/Range separation
to Street Fighter's practice tools. The [combat evidence](element-expansion-evidence-20261009/combat-design.md)
records the Magicka, Noita and Gungeon techniques. Those precedents guide these
questions; they do not answer whether this build feels fair or understandable.

## Match and delivery checks

Try Solo Duel, then a same-build local match if two players are available.
Verify visible enemy/ally ownership, death and return, reset, retry and loadout
restoration. Duos requires four ready players and Trios six. Team scoring counts
only enemy knockouts; a shared hazard killing an ally awards no point.

Configured 120 Hz simulation and 60 Hz snapshots do not establish dense sustained
performance. Eight players is a configured cap. Physical LAN, different-home
Internet play, listening quality, continuous-motion feel and PvP balance remain
separate acceptance gates. The relay is not deployed.

Record a reproducible input sequence, expected behavior and actual observation.
The [earlier six-element integration evidence](reference-refinement-evidence-20261009/six-integration.md)
records that earlier pass only. The central handoff and the expansion evidence
identify newer executed checks; neither source should silently inherit the
other's Full, native or package result. The [pre-six guide](archive/reference-20261009/HEX-PLAYTEST-before-six.md)
preserves older routes and their exact historical build evidence.
