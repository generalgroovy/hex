# Player controls and point-of-view settings

Status: **historical movement/input design record (September4); not the current contract**.

For current defaults and gameplay use [README](../README.md#controls-and-movement),
[SPECIFICATION.md](../SPECIFICATION.md) and the in-game F4 movement table. The
tables below retain earlier timings, map dimensions and double-jump concepts;
they must not override the current finite Float implementation. The September9
default layout is Technique V / Roll-Air Dodge Q; customized bindings stay yours.

## Movement revision: no vaulting (2026-09-04)

**Implemented source revision:** the movement-led 3072 x 1728 campus now precedes
the movement update, as requested. Vault entry and vault-crest superglide are
retired; their serialized IDs/fields remain reserved compatibility slots.
Sprint + Jump always jumps. Q / left trigger is explicit Evade, V / B is
Wall / Air Turn / Impact Tech. C / wheel-down slides, and a second press brakes.
Slide has a 6-tick (50 ms) opening attack-protection window. Tapping Slide buys
the 150 ms opening; holding pays 60 Stamina/s to sustain toward 300 ms. Jump
holding likewise pays 120 Stamina/s beyond its tap arc. Jump protection uses
its own authoritative timer, independent of shortened or sustained airtime.
Material-assisted drift/grip is neutral-only preparation; non-vault landing
burst is excluded. See [current slice and acceptance](WELLSPRING-MOVEMENT-ACCEPTANCE.md).

### Current movement and continuing acceptance

Times below are authored milliseconds, rounded up to 120 Hz simulation ticks.
I-frames mean protection from hostile attack contact, not passage through walls.

| Option | Current implementation | Intended treatment |
|---|---|---|
| Eight-way walk / strafe / counter-strafe | Normalized digital directions, continuous analog magnitude, separate aim, acceleration/braking | Keep; reduce unintended input interpretation before changing speed |
| Sprint | Held Shift, Stamina drain; Sprint+Jump stays Jump | Keep; measure control clarity in playtests |
| Jump / hop | Directional takeoff, active air steering, 28 Stamina opening; hold pays 120 Stamina/s toward the 160 ms cap; release/exhaustion cuts to the tap arc; 90 ms opening attack i-frames | Keep a reliable tap and expressive paid hold; sustain never extends protection |
| Double jump | Second paid stage, 24 Stamina, 200 ms arc; jump-family opening protection | Outward recent air-wall contact deliberately chooses wall kick instead; both spend stage two |
| Slide | C/wheel down; entry-speed gate, 22 Stamina opening; tap commits 150 ms and hold pays 60 Stamina/s toward the 300 ms cap; 780 ms cooldown; **6 protected ticks (50 ms)** | Release/exhaustion cuts the paid tail; second press brakes; sustain never extends protection |
| Slide jump | Late slide conversion, 20 additional Stamina, 230 ms arc; jump-family opening protection | Keep; distinguish early buffered intent from successful conversion and avoid inherited/duplicated i-frames |
| Ordinary air steering / turnaround | Held direction continuously bends travel; body follows input; release preserves momentum | Keep as the default aerial tool; provide broad reversal pockets and honest momentum loss |
| Paid air redirect | V while hopping, 10 Stamina, one redirect per jump stage | Keep a stronger correction than ordinary steering; no new i-frames from direction change |
| Air dodge | Q / left trigger while hopping, 28 Stamina, 180 ms action, 120 ms opening i-frames | Keep as committed evasion; test clearer explicit Evade binding |
| Ground roll | Q / left trigger on ground, 24 Stamina, 240 ms action, 130 ms opening i-frames | Keep as deliberate ground defense, distinct from travel-focused slide |
| Wavedash | Late angled air dodge queues a ground momentum conversion | Keep; ground conversion does not grant a new free protection window |
| Wall jump / kick | Jump consumes recent wall contact; 28 Stamina, 220 ms same-wall lockout | Outward recent airborne wall contact selects kick and spends the second air-action budget; otherwise double jump |
| Wallrun (wall-skim kernel) | V + tangent at a runnable practice wall; 18 Stamina, 420 ms maximum, 900 ms same-surface lockout | Continuous contact, immediate end/away/V detach; no corner magnetism or i-frames; not roof climbing |
| Variable jump / fast fall | Hold Jump pays for extra arc, release/exhaustion cuts it; airborne C accelerates descent | Keep separate timing choices; neither creates a fresh evade |
| Landing cut | Counter-steer during a 110 ms landing window boosts braking response | Keep; explain as landing reversal, not attack-cancel or free speed generation |
| Launch influence / impact tech | Direction bends launch; buffered V recovers from impact for 18 Stamina | Keep; teach one recovery cause and correction, no automatic escape from all control |
| Edgeweave | Hostile projectile near-miss can recover Stamina under bounded eligibility | Keep; audit reward once per source/contact so dense patterns cannot fund perpetual evasion |
| Vault / vault-crest superglide | Runtime activation removed; old numeric IDs/state slots reserved | Do not restore; non-vault landing burst excluded |

### Input and evasion decisions

| Concern | Proposed rule / test |
|---|---|
| Sprint + Jump | Implemented: Space requests Jump even with Shift; C is Slide; the old chord is retired. |
| Separate intent | Implemented: Q / left trigger Evade; V / B Wall/Air Turn/Tech. Near-wall Evade remains a roll. Both actions are remappable. |
| Slide protection | Implemented candidate: 6 ticks (50 ms). Vulnerable tail, original slide cost/speed/cooldown; brake ends protection. Balance still needs player feedback. |
| Distinct defense roles | Walking wins by positioning; slide buys a short protected lane crossing at speed; roll gives a longer committed ground evade; jump changes trajectory/timing; wallrun gives routing, not automatic protection. |
| Honest timing | Track accepted action age independently from a shortened jump arc where necessary. Never reset protection on facing changes, held input, wall-contact refresh, animation loops or presentation correction. |
| Chaining | Permit legal paid transitions with their authored cooldowns/Stamina; do not add a hidden global combo lock. A converted state cannot inherit and restart the same protection purchase. New paid actions remain independently testable. |
| World remains solid | I-frames do not bypass collision, grant wall crossing, remove existing status effects or alter material authority. Jump currently has no general solid-cover clearance; map authors cannot assume it replaces vault teleportation. |
| Resource counterplay | Test maximum-uptime chains plus Edgeweave rewards with every body role. If a renewable loop erases counterplay, adjust the visible cost/cooldown/refund rule, not a silent exception. |

### Wall movement acceptance

Extend the existing wall-skim kernel rather than inventing a parallel wallrun
system. Require an authored runnable face, intentional approach/entry, valid
contact throughout the run, a finite duration/Stamina cost, and immediate
readable detachment at a wall end. No magnetic corner wrapping, outer-boundary
surfing, roof climbing or same-wall infinite refresh. Wallrun itself grants no
i-frames. A separately accepted wall jump may use the jump family's authored
window; it must not reset the remaining air-action budget for free.

Space at fresh airborne wall contact needs an explicit, tested choice between
wall jump and double jump. Prefer outward input + valid wall contact for a kick;
otherwise preserve the requested double jump. Check all eight approach/exit
directions and repeated same/opposite wall cases. This priority is implemented; wall kicks consume stage two and preserve the
remaining redirect budget. Repeated kicks cannot refill it.

### Accepted additions and explicit exclusions

| Candidate | Benefit | Limit / decision |
|---|---|---|
| Slide release / controlled brake | Stop short, bait aim and change commitment without another button | Implemented: second Slide press; ends protection, retains original cost/cooldown and gives no launch boost |
| Deliberate wall detach | Fake a wall jump or choose an ordinary fall/exit | Implemented: outward input or a second Wall press; no new protection |
| Landing-direction buffer | Make intended landing turns reliable during fast combinations | Implemented: 80 ms remembered direction supplies an otherwise empty first landing tick; live input wins |
| Material-assisted drift / grip | Ice-like surfaces preserve a slide; mud-like surfaces change braking and route choice | After first-eight chemistry acceptance; authored friction/steering modifiers with obvious boundaries, no universal free boost or extra element |
| Training input trail and race ghost | Make timing, reversal and route improvement understandable | Implemented local F2 trace / F3 next recording with same-start, same-character previous-run echo; 60-second cap |
| Non-vault landing burst | Potential replacement for superglide expression | Excluded by the current user request; do not implement |

Reject unlimited bunnyhop acceleration, repeated free wall-jump refresh, passive
wallrun invulnerability and mandatory precision traversal to services. These
remove meaningful decisions or accessibility rather than creating useful depth.

### Implementation sequence

| Slice | Outcome | Required proof |
|---|---|---|
| M3a -- campus foundation implemented first | Six physical practice areas, ordinary loop, runnable walls, duel cover, three targets and moved stations | Full-width public-route clearance, spawn/station/target validation; visual playtest still pending |
| M0 -- implemented | Vault entry and dependent crest activation retired; old fields reserved | Protocol 33, snapshot 12; command/replay/prediction tests |
| M1 -- implemented candidate | Consistent Jump, separate Evade, paid jump/slide sustain, six-tick slide protection, brake, independent jump protection timer | Eight-way tests, deterministic tap/hold/exhaustion costs and no protection refresh |
| M2 -- implemented candidate | Contact-based wallrun, outward airborne wall kick and deliberate detach | Finite air budget, contact/end/lockout checks |
| M3b -- pending | Independent concurrent activities, local reset isolation, additional pattern challenge tools | 2/4/8-player pressure and human movement/visual acceptance |

Next resume C6-C9 chemistry, keeping material movement neutral until separately
accepted. Do not claim this physical campus supplies independent concurrent
rounds or material chemistry already. Updated evidence is recorded in
[the acceptance ledger](WELLSPRING-MOVEMENT-ACCEPTANCE.md).

## Implemented checkpoint

FLUX 2 now loads schema-v10 preferences from the stable offline profile
`user://player_preferences_v1.json`. The legacy filename is retained so existing
schema-v1 installations are discovered and migrated in place. Godot stores it
in the current Windows user's application-data area. The file is created with
safe defaults on first launch and requires no account, network, subscription,
or cloud service.

The profile owns these independent concerns:

- physical-key bindings for every current gameplay keyboard action;
- mouse-button and wheel-direction bindings for current combat/movement actions;
- controller button and signed-axis bindings for current combat/movement actions;
- the movement reference preset;
- full-screen versus ranged-cone presentation;
- ranged-cone angle and length;
- a bounded 50/75/100% camera scale that defaults to the wider 75% view;
- the reduced-motion accessibility preference used by G3 presentation;
- the high-contrast presentation preference used by the V6 screen filter.
- the last validated Farflow host/IP address entered at the in-world Join gate.

Schema-v1/v2 profiles migrate the former defaults: C jump becomes Space jump,
Alt sprint becomes Shift sprint, and the former Space primary alias becomes
unbound. Schema-v3's default Ctrl slide becomes C. Explicit saved
alternatives, including J jump or P primary, remain unchanged. New defaults bind
Space only to semantic jump; Arc Primary keeps left mouse and controller trigger.
Schema-v4 profiles gain the controller table and newly optional mouse movement
lanes without altering established jump, slide, primary or active inputs.
Schema-v5/v6 profiles migrate to four number-button actions plus configurable
Ctrl and Alt layer actions. A retired `spell_5` entry is ignored; if a legacy
action already owns Ctrl or Alt, that new layer remains unbound rather than
creating a conflict. Missing mouse/controller lanes migrate to explicit unbound
descriptors, and old profiles gain the 75% camera default. Schema-v7 profiles
gain standard contrast without altering any existing binding or presentation
choice. Schema-v8 profiles gain the safe local Farflow address `127.0.0.1`;
schema-v9 saves a player's subsequently validated host/IP entry.

Unknown actions, unknown modes, conflicting non-zero keyboard keycodes,
fractional values, unsupported schema versions, and values outside documented
bounds fail closed. A keycode of zero intentionally removes that action's
keyboard binding without deleting its mouse or controller binding. Corrupt
preferences fall back to safe defaults with a warning instead of preventing an
offline game from starting.

Walk to the **Controls Lectern** west of the Champion Loom and press F/controller
north-face to open the in-world table. Arrow keys or D-pad select an action and
device; Enter/controller south-face captures the next matching input,
Backspace/controller west-face unbinds, R/controller north-face restores safe
defaults, and Escape/controller east-face closes. Clicking a table cell begins
capture and the mouse wheel can navigate rows. Reusing an occupied input swaps
the two actions visibly instead of silently erasing one. Each accepted change
updates the runtime map and profile immediately; movement and casts are suppressed
locally while the lectern is open, but an online host keeps the session ticking.

## Movement reference presets

| ID | Meaning | Intended use |
| --- | --- | --- |
| `world_relative` | W/A/S/D always map to the screen/world axes; aim remains independent | Classic top-down shooter movement and maximum spatial consistency |
| `aim_relative` | Mouse/right-stick aim is forward; W/S move along that facing and A/D strafe perpendicular to it | Character-relative movement, forward pressure, and players accustomed to facing-led controls |

Both presets emit the same bounded semantic movement vector. They do not alter
acceleration, Stamina costs, collision, speed ceilings, ability outcomes,
network authority, replay bytes, or tick-rate behavior. If the pointer overlaps
the player exactly, aim-relative movement retains the last valid aim direction
rather than producing an undefined basis.

Slide, jump-chain and contextual technique press edges are retained for 180 ms.
The buffer stores intent only: speed, aerial stage, cooldown, collision target,
Stamina and control-lock requirements are rechecked every tick, and an expired
or still-illegal action changes no state and spends no resource.

The local input router combines held-state transitions with Godot's buffered
just-pressed transition before creating the semantic command. This prevents a
short key, wheel or controller press from disappearing between a render frame
and the next simulation sample. The semantic `S+D+slide` path and all seven
other compass combinations are tested through input mapping, command creation,
buffer consumption and slide direction; simulation integrity is tested at 120
Hz. Hardware that never reports a particular three-key chord cannot be
reconstructed in software, so wheel-down and in-world remapping remain equal
fallbacks rather than privileged mechanics.

Holding Space or wheel-up preserves the authored jump arc. Releasing it cuts
remaining air time to a 90 ms minimum; holding C or wheel-down while airborne advances the fall by one
additional simulation tick per tick. Fast fall costs no Stamina because the
earlier landing is its commitment, and its explicit canonical/presentation state
is replayed identically rather than inferred from animation.

Jump startup latches the movement direction held on the accepted jump tick.
While airborne, each non-zero movement vector immediately updates body facing
and continuously bends jump momentum at the authoritative 120 Hz rate.
Releasing movement preserves the current airborne momentum. A hard
reversal briefly trades speed for turning instead of snapping through the
player; contextual V remains the faster, Stamina-priced air redirect and Q / left trigger
remains the committed air dodge. Spell aim stays independent and exact.

V at a runnable practice-wall face starts an at-most-420 ms contact wallrun
along the requested tangent for one 18-Stamina purchase. Stable positive wall
identity excludes outer world boundaries, a 900 ms same-surface lockout prevents
loops, and the end exposes a short recovery cue. The same semantic V press keeps
its wall/air-turn and impact-tech roles; explicit Evade on open
ground starts a 24-Stamina roll. Roll remains solid against world collision
for 240 ms and ignores hostile damage/control only during its opening 130 ms.
Jump-family actions likewise ignore hostile damage/control during their opening
90 ms, then become vulnerable before landing. A bright broken contour exposes
the exact active evasion phase; neither action passes through walls or topology.

Every completed aerial route and wall-skim exit records a bounded 0–1000 landing
intensity in canonical state. Presentation turns that truth into the champion's
land strip, a short shadow squash and an expanding four-mark rune ring; heavier
routes and fast fall read more strongly without changing collision or recovery.
Reduced motion preserves the timing cue with a smaller, thinner, dimmer pulse.

## View modes

`full` leaves the complete viewport visible. `cone` presents only the selected
aim-facing angle inside the selected range:

- angle: any whole degree from 15 through 360;
- range/length: 160 through 4096 world units;
- 360 degrees plus a finite range creates a ground-projected elliptical view;
- full view is a distinct mode and has no artificial range boundary.

The 55-degree ground-plane projection scales vertical range by about 0.819.
Aim, mask geometry and actor tests share this metric; this is not a rotation of
the map or controls. A 72-ground-unit near-awareness ellipse reveals slightly
behind the observer while respecting opaque building cover. The living viewpoint
owner's body alone is drawn above the mask, including during jumps; it creates
no rectangular reveal and does not repaint hidden opponents, aura or spell VFX.

The current checkpoint is a local presentation/accessibility policy in the
offline Wellspring. In cone mode every authored `los_cutaway` building projects a
bounded presentation shadow through its silhouette corners; low practice walls
remain explicitly non-occluding. Actor presentation follows the same cone and
opaque-cover predicate before chemistry reveal/concealment. This is not server
interest filtering: hidden entities may still exist in a client's snapshot. A
competitive or PvPvE mode that restricts information must enforce
visibility on the authoritative host and replicate no hidden actor state; a
client preference may make that view more restrictive, never less restrictive.
Chemistry work budgets and simulation decisions never depend on the camera or
view mask.

Perspective cutaway is a separate later system. A roof, high wall, foliage,
building, or construct that visually overlaps a character inside authoritative
LOS must fade/cut away or yield to a restrained ownership-readable silhouette.
Cone/full preference does not itself grant LOS. A character outside permitted
LOS receives no silhouette, nameplate, shadow, effect, audio marker, material
cue, or diagnostic leak.

## Runtime configuration

| Input | Action |
| --- | --- |
| `Shift` | Sprint while held |
| `C` / wheel down | Tap for the grounded slide opening, hold for paid sustain; airborne input commits fast fall |
| `Space` / wheel up | Tap for short hop / movement-chain press, hold for paid jump sustain |
| `Q` / left trigger | Explicit grounded roll / airborne dodge; late angled dodge can wavedash |
| `V` / B | Recent-contact wallrun, air redirect, or buffered 18-Stamina impact tech |
| `F2` / `F3` | Local practice trace toggle / next recording and same-start previous-run echo |
| `F` | Activate the nearest walk-up Wellspring station; controller north-face is equivalent |
| Left mouse | Arc Primary; no default Space alias |
| `E` / right mouse | Vector Lance |
| `1`–`4` | Request the corresponding position in the active spell layer |
| `Ctrl` + `1`–`4` | Request one of four configurable Ctrl-layer positions |
| `Alt` + `1`–`4` | Request one of four configurable Alt-layer positions; Alt wins if both layer actions are held |
| `F7` | Toggle world-relative / aim-relative movement and save |
| `F8` | Toggle full / cone view and save |
| `F9` / `Shift+F9` | Increase / decrease cone angle by 15 degrees and save |
| `F10` / `Shift+F10` | Increase / decrease cone range by 80 units and save |
| `F11` / `Shift+F11` | Cycle camera scale through 50/75/100% forward or backward and save |

Exact session overrides are also available from the normal launcher:

```bash
scripts/run.sh --movement-reference=aim_relative --pov-mode=cone \
  --pov-angle=135 --pov-range=960 --camera-zoom=75
```

Command-line values clamp to the supported numeric bounds and do not require
editing project data. Exact persistent values and physical-key codes can also
be changed in the generated JSON file while the game is stopped.
Sensitivity/dead-zone curves, named per-device profiles, reset-by-category and
profile import/export remain later presentation layers over this same schema.

The schema persists `reduced_motion` and `high_contrast` strictly as booleans.
Both default to false, fail closed on malformed values, and do not alter
canonical simulation. While the Controls Lectern is open, M/controller L3
toggles reduced effects and H/controller R3 toggles high contrast; the header
shows both states and normal player changes save immediately. When reduced
effects are enabled, the G3 presentation sampler uses a seven-pixel maximum
whole-pixel body
lift and a lower-scale but still broader/darker shadow cue, instead of the
normal 28-pixel apex lift. Timing and authoritative movement remain identical.

Exact command-line movement, POV, angle, range and camera overrides are
transient diagnostics. They affect that process only and are not written to the
player profile on exit.

## Acceptance and authority

- Movement transforms are deterministic integer operations before command
  construction; replay stores the resulting world vector and independent aim.
- Saved profiles round-trip without network access.
- Source and imported-resource builds boot at 120 Hz with the same selected preferences.
- Equivalent normalized jump samples at 120 Hz produce the same body lift,
  shadow width, and shadow opacity across all current aerial traversal modes.
- Jump presentation sampling does not mutate position, collision radius,
  canonical values, replay data, camera focus, or POV origin.
- The mask is drawn after world actors but before HUD/debug panels, so it cannot
  hide configuration state or create simulation authority.
- Future server-enforced vision must be hashed mode content and tested for
  spectator, reconnect, late-join, replay, bot, and anti-information-leak paths.
