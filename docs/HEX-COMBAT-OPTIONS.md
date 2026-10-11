# H.E.X. — responsive movement and offensive options

Status: locally validated playtest checkpoint, 2026-09-28; return for human feedback.

This gameplay build is preserved as a fallback. The later
[combat-phase-clarity checkpoint](HEX-COMBAT-PHASE-CLARITY.md) includes these same
mechanics with revised forming/active/decay cues and has its own acceptance evidence.

Build: `p56-eefcd94291c1` (2,940 production records). Open
[PLAY-HEX.cmd](../exports/hex-combat-options-20260928/windows/PLAY-HEX.cmd), or extract
[the portable ZIP](../exports/hex-combat-options-20260928/HEX-p56-eefcd94291c1-Windows-x64.zip).
Keep EXE/PCK together. Full 171 suites / 1,531,093 assertions, native paid-pair
captures, separate Windows export/native art boot/safe close passed.
[Fresh receipts and review limits](combat-options-evidence-20260928/README.md).

User direction: better movement, better element capability balance, all elements
offensive, and every element combination a valid combat option. This supersedes
the prior presentation-only freeze for the explicitly listed tuning/effect files.
Preserve `p56-6523a2fb7648` as the immediate working fallback. Nothing committed,
pushed or published; historical checkpoint/installer pointers are unchanged.

## Design contract

Every element has damaging Bolt, Heavy, Rapid and Spray options. Reactions need
a useful tactical outcome, not identical DPS: cover, reflection, steering,
suppression, reveal and concealment can enable an attack without themselves
damaging everyone. No new hard crowd control, universal invulnerability, trails,
larger footprints, lifetime extension, movement technique or extra spell button.
Combat usefulness and balance ultimately require human opposition/playtesting;
a populated matrix and passing tests alone do not establish equal viability.

| Element | Offensive approach | Setup / tradeoff |
|---|---|---|
| Water | Direct pressure; steer opponents into danger | Build wet routes, Steam or conduction; ordinary Water is not Fire damage |
| Earth | Direct heavy pressure; deny firing lines and exits | Temporary breakable cover and ground control; can obstruct the caster too |
| Fire | Immediate pressure and punish prolonged occupation | Visible formation, ground escape where appropriate, finite fuel |
| Air | Direct fire while repositioning; redirect routes/shots | Direction and geometry matter; displacement does not stun-lock |
| Ice | Direct attacks and movement conditioning | Frost lanes reward slides/jumps; entry slows have finite duration |
| Charge | Direct pressure and conductor combinations | Extra links extend reach but remain destructible counters |
| Light | Direct attacks, reveal and limited searing pulses | Newly damaging reveal combinations trade sustained Fire pressure for information |
| Dark | Direct attacks, obscuring approaches and attrition | Moving/revealed silhouettes and delayed pressure preserve counterplay |

## This slice

| Change | Exact scope |
|---|---|
| Movement | Acceleration 2277 -> 2640 px/s²; braking 3450 -> 3960 px/s². Walk/sprint caps, action speed, costs, protection, buffers, hurtboxes and bindings unchanged. Air steering shares the acceleration constant. |
| Thermal Shock: Fire + Ice | 8 damage to eligible grounded enemies once at activation, plus existing structure fracture; 600 ms formation, jump/exit counter. Actor and structure pulse clocks must not swallow or duplicate each other. |
| Plasma Arc: Fire + Charge | Existing 9-damage burst works without an extra conductor cast. If added links are chosen, broken/expired links still disable linked pressure. |
| Superconduct: Ice + Charge | Existing 8-damage/900 ms pressure works without a third cast; optional Ice links still extend reach and remain breakable. |
| Solar Flare: Fire + Light | 6 damage once at activation plus existing reveal; leave its 220 ms forming area. |
| Arcflash: Charge + Light | 6 damage once at activation plus existing reveal along the line; 300 ms formation. |
| Radiance: Light + Light | 3 hostile damage per 600 ms pulse plus reveal; 300 ms formation; leave between pulses. |
| Penumbra: Light + Dark | 3 hostile damage per 600 ms pulse plus crossing reveal; 220 ms formation; cross quickly rather than linger. |
| Compendium | Descriptions/counters and pulse figures follow the same runtime policy; stale moving-Firestorm prose becomes stationary-sector wording. |

New damage respects exact stored whole-hex membership, protection, phase and team
rules. Formation and decay stay harmless. Low profile is not immunity to a floor
field. Thermal Shock respects ground clearance; light/conductor effects retain
their taller layer. No new persistent state or per-tick spatial scan is added.

## All 36 pair roles

Names and implemented shape/phase/counter details remain in the live F4 matrix.
This table describes roles, not a claim of competitively equal strength.

| First | Self and remaining unordered pairs |
|---|---|
| Water | Water: directional Flood; Earth: Mud handling trap; Fire: escalating Steam; Air: visible wet steering/suppression; Ice: entry slow; Charge: conductive pressure; Light: disturbance reveal; Dark: concealed wet approach |
| Earth | Earth: Rampart cover; Fire: Magma damage/slow; Air: lateral Dustfront; Ice: brittle cover; Charge: charge absorption; Light: reflection plane; Dark: recovery suppression |
| Fire | Fire: concentrated burn; Air: fire sector; Ice: shatter burst/fracture; Charge: conductor burst; Light: damaging reveal flash; Dark: delayed concealed ember pressure |
| Air | Air: Vortex redirection; Ice: hail lane; Charge: charged pressure; Light: optical bend; Dark: pulsing concealment bands |
| Ice | Ice: Frostway mobility lane; Charge: conductor pulses; Light: split/redirect Light; Dark: entry reveal/delayed slow |
| Charge | Charge: Capacitor speed lane/terminal displacement; Light: damaging reveal line; Dark: entry/exit reveal veil |
| Light | Light: reveal/searing pressure; Dark: marked crossing/pressure |
| Dark | Dark: concealment/delayed attrition |

## Validation contract

One lead owns edits and all serialized engine runs. Test all32 offensive
element/delivery combinations through real paid casts; test newly damaging pairs
through paid formation; retain all36 pair/canonical-geometry/strength tests.
Exercise formation/active/decay, allies, protection, air/ground planes, same-tick
deduplication, consumed/broken links, snapshot prediction and all-size/eight-way
movement. Full regression and isolated Windows boot/export are required before
returning a candidate. Native images verify visible output, not competitive
balance or frame-rate capacity. Existing dense 120 Hz failure remains open.

Initial suspicion of shifted last-row descriptions was rejected on rereading:
the original table has36 correctly ordered entries. No reaction order changed.

## Playtest and next decision

| Test | What to judge |
|---|---|
| Strafe, release, reverse, sprint-stop in the open yard | Less unwanted drift without a twitchy increase in cruise speed; aim remains independent |
| Repeat a slide-jump-air-dodge / wall route on each body size | Existing momentum options remain useful; no extra free resource or protection |
| Equip one Bolt from every element at the Academy Spell Loom | All can directly threaten the target; display order remains Water, Earth, Fire, Air, Ice, Charge, Light, Dark |
| Cast the seven revised pairs at the same nearby endpoint | A two-cast setup produces pressure without needing an unexplained third cast; later-element pairs are equipped manually, not through the first-four-only guided demo |
| Compare Light + Light / Light + Dark with Fire + Fire | Light/Dark pressure should feel worth choosing for their information/positioning, without replacing Fire's sustained punishment |
| Compare warning and active cells in both effects settings | Check pale effects on beige ground and fast flash windows in motion; static screenshots do not settle reactability |

Return for feedback at this checkpoint. Next balance work should respond to
specific weak/overpowered pair observations, not enlarge every area or raise all
damage together. Prioritize warning contrast before further burst buffs. Keep
the unresolved dense-tick performance work and multiplayer acceptance separate.
