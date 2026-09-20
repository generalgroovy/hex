# Mirror reactions, race foundations and Wellspring

Status: approved implementation order, 2026-09-09; percentage cutoffs disregarded
by the user on 2026-09-12. Platform limits remain applicable.
This is a scoped design reference, not another task queue; execution state lives
in `.agent/OVERHAUL-IMPLEMENTATION.md`. The exact playable build remains selected
by `docs/current-checkpoint.json` until a new candidate passes its delivery gate.

## Play first, add one rule at a time

Every mirror should offer **one recognizable purpose, one expressive opportunity
and one understandable counter**. Learn the element alone before combining it
with another. Paid casting, the one-payload-per-cast rule and all existing caps
remain. Rapid never leaves a trail. Plain deposits are harmless ingredients,
not an invisible damage field. New mirrors below are targets, not live promises.

| Pair | Personality / proposed opportunity | Counter and balance boundary |
|---|---|---|
| Earth + Earth | Rampart: build breakable cover; use it for wallrun and walljump repositioning | Formation warning, no trapping an overlapping player, finite health/lifetime, walk around or break; no ability reset |
| Ice + Ice | Frostway: cyan lane; ordinary grounded walk/sprint target75%, physical projectile travel65%; normal paid slide/air movement | Both teams, nonstacking, no lingering status; leave, slide/jump across or wait; no damage or solid cover |
| Charge + Charge | Capacitor: both teams walk/sprint target125%; one final14px directional displacement | Frostway wins overlaps; capped speed, no damage/stun/cast cancellation; leave or jump before discharge |
| Fire + Fire | Furnace: territorial heat pulses with readable safe intervals | Visible cadence and escape lanes; pressure rather than an opaque continuous damage carpet |
| Water + Water | Current: directional flow you can ride or resist | Direction shown by moving water; bounded push and projectile influence, no invisible redirection |
| Wind + Wind | Gust: directional displacement and aerial steering opportunity | Can reposition, never restore Float/dodge/protection budgets; finite acceleration |
| Light + Light | Sanctuary: reveal plus finite gradual recovery opportunity | Visible location and finite total recovery; no instant heal loop or cover penetration |
| Dark + Dark | Veil: concealment and recovery denial to control an approach | Moving/casting remains readable; Light counter and finite denial, not resource theft |

## M0/M1 engineering contract

C1 readability precedes the next mirror: strengthen source element and result
color identities, increase authoritative footprints by a modest shared scale,
and show the entire permitted area with pixel material rather than range rings.
Damage, lifetimes, costs, source-cast payload budgets and entity caps stay fixed.
Harmless ingredients remain quieter than active reactions; new colors cannot
invent damage or hide formation/expiry. Capture all eight elements and all 36
paid pairs in the actual campus renderer before promoting a new portable.

| Concern | Required rule |
|---|---|
| Authority | Simulation owns geometry, phases, health and movement contacts; art only displays permitted state |
| Compatibility | Host and guest derive the same collision from authoritative state; changed executable contract changes compatibility fingerprint |
| World | Static worldbone stays immutable; temporary geometry has stable separate identities and bounded storage |
| Lifecycle | Warning -> active -> harmless decay; destroyed or expired surfaces cannot preserve wallrun contact |
| Occupants | Formation never teleports or traps a player; overlapping players have an explicit escape rule, consistent after reconciliation |
| Movement | All three sizes use common 18px wall clearance; hurtboxes remain 15/18/21px; no Stamina/airtime/invulnerability reset |
| Cover | Preserve current shot/ray cover and health rules; do not accidentally create permanent or double-counted projectile collision |
| Visuals | Existing pixel assets tile the actual footprint; warning, solid active ridge and crumbling decay are distinguishable without range circles |
| Teaching | F4, pair details, live practice card and README agree with executable behavior; use current bindings in actionable prompts |
| Tests | Formation/overlap/escape/re-entry, destruction/expiry, eight approach directions, three sizes, wallrun/kick, snapshot/replay, unrelated recipe regression |
| Delivery | Focused checks -> frozen source -> Full -> actual-game render review -> fresh portable/PCK/boot -> exact checkpoint pointer |

The current W4 benchmark already misses the 8.333ms simulation budget. Do not
claim sustained 120 FPS or allow unlimited extra work; bound scans, reuse data
and keep deterministic comparison fixtures. Passing headless tests does not
replace human feel/style acceptance or physical two-PC remote playtesting.

## Reusable race visuals

M2a narrows Frostway to one ephemeral material rule: a 200px centreline with
30px round-end radius, stationary along the cast direction, 0.65s formation /
3.5s active / 0.6s harmless decay. Authority and prediction query centre
occupancy at the start of each 120Hz tick; unusually fast crossings can be
sampled one tick later or cross between samples. Ground target speed changes,
not a lingering control status. Sliding retains ordinary drag/cost; no free
speed, airtime, protection or resources. Physical projectiles retain base
velocity, damage, range budget and finite lifetime; Beam/Spray are unchanged.
Required exact-tick lane rows and numeric rules enter the compatibility hash.
New native-pixel floor tiles remain clipped to the actual capsule. This is a
candidate until the current checkpoint pointer explicitly promotes its build.

Small -> Middle -> Large is the production order. Extend the current fixed-bone,
fixed-pivot cloth rig with race silhouette components, not separate physics or
new movement logic. Front/back/side/diagonal orientation must remain unambiguous
at gameplay scale; eight aim directions work independently of eight travel
directions. Feet alternate with distance-driven gait. Heads, body and accessories
cannot change scale between actions. Spell effects and environment remain
separate; hands cast without staffs/wands. Preserve original reference art.

Basic race silhouettes may be piloted while detailed named skins wait for human
template acceptance. Each race needs a reviewed full-direction contact sheet and
in-game comparison, not merely an occupied atlas cell. Cap decoded texture cost;
the held packed-offset moving-cast experiment is not automatically promoted.

## Wellspring: a social playground, not a settings obstacle course

| Place | Activity / purpose | Accessibility |
|---|---|---|
| Central Commons | Spawn together, switch character, orient, observe friends | Immediate compact character and session access |
| Farflow dock | Host/join, readiness, practice invitations | Session controls also accessible without crossing the map |
| Movement grounds | Wide sprint/slide lines, wallrun/kick loops, aerial turnarounds | Optional safe route and reset; no compulsory precision jump |
| Eight element workshops | Try one spell, mirror, counter; then neighbouring cross-pairs | Same spell loadout tools and source-derived pair reader everywhere appropriate |
| Sparring court | Readable duels and projectile-pattern practice | Quick reset and clear opt-in/out; no surprise damage to bystanders |
| Outer loop | Long movement play, alternative approaches, social exploration | Multiple connections; no single bottleneck from spawn |

Expand a useful playable route first, then add distinct points of interest.
Reserve open space for readable bullet patterns and temporary elemental terrain.
Stations provide context and charm; basic controls, accessibility, spell setup
and routine host/join actions should remain compact and available without chores.
