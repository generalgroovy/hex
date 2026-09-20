# Spellcasting delivery foundations

Status: **canonical combat-content contract for the first-eight phase**.

FLUX spellcasting is organized by reusable **delivery geometry**, not weapon
classes. Elemental identity is a payload applied to a neutral delivery
foundation. Champion equipment may affect presentation, anchors or authored kit
identity, but universal spell behavior must not depend on guns, staffs, dominant
hands or weapon-specific animation.

## 1. Composition model

```text
delivery kernel
+ elemental payload
+ optional bounded pattern modifier
+ cost / startup / recovery / cooldown
+ targeting / ownership / counterplay
= stable spell definition
```

The delivery kernel owns geometry and timing. The elemental payload owns what
happens when that geometry reaches an actor, material, structure, device or
field.

The same Burst kernel must be able to carry Earth, Fire, Water, Wind, Ice,
Charge, Light or Dark without rewriting burst spawning eight times.

## 2. Universal first-pass delivery set

| ID | Foundation | Runtime geometry | Tactical role |
| --- | --- | --- | --- |
| `bolt` | Bolt | One discrete moving projectile | Precision, leading, simple placement. |
| `burst` | Burst | Several projectiles from one cast around true aim | Gap coverage, short/mid pressure, broad element placement. |
| `beam` | Beam | Sustained or charged line/ray | Lane control, interruption, continuous state application. |
| `spray` | Spray | Continuous cone/stream | Close-space denial and terrain painting. |
| `rapid_fire` | Rapid Fire | Repeated small projectiles/casts | Tracking, suppression, incremental setup. |
| `whip` | Whip | Flexible sweep/tether segment | Mid-range control, sweep, pull/redirect. |
| `orb` | Orb | Slow/persistent/lob-capable payload | Prediction, delayed setup, larger local transformation. |
| `wave` | Wave | Wide moving front/band | Route denial and timing gates. |

Every promoted first-eight element must eventually have at least one legal
variant for each foundation. This is coverage, not a requirement that every
variant be equally strong or equally common.

## 3. Element independence

A neutral delivery foundation contains:

- shape;
- spawn count/order;
- movement/trajectory law;
- collision query type;
- timing and lifetime;
- neutral animation phases;
- attachment/origin contract;
- network/event representation.

It does **not** contain:

- elemental color;
- fire/smoke/water/electric particles;
- elemental status;
- material conversion;
- element-specific damage rules;
- reaction logic.

Elemental presentation is layered over the foundation using the existing VFX
phase grammar:

```text
startup -> cast -> travel -> field -> impact -> residue/status
```

Reduced-motion presentation must communicate the same gameplay state.

## 4. Arbitrary aim and eight-direction presentation

Simulation aim is an authoritative quantized world-space vector and is not
restricted to eight headings.

Directional sprite assets may quantize presentation to:

```text
north, north_east, east, south_east,
south, south_west, west, north_west
```

The simulation trajectory always follows the real aim vector. For suitable
neutral projectiles the renderer may rotate one base sprite instead of selecting
eight discrete frames, but any pixel-art rotation method must preserve
nearest-neighbor readability.

Universal foundations are symmetric:

- east/west are exact mirrors;
- northeast/northwest are exact mirrors;
- southeast/southwest are exact mirrors;
- north/south stay centered;
- no staff, gun, muzzle side or dominant hand is encoded.

## 5. Projectile visual foundation

Neutral moving projectile graphics use **32 x 32 transparent cells** with a
center pivot `(16,16)` unless a later delivery-specific contract explicitly
requires a different canvas.

Character casting animation remains separate from projectile art.

The neutral projectile should leave enough transparent space for elemental
travel effects. Simulation collision radius is explicit data and never inferred
from visible sprite size.

## 6. Burst — first production slice

Burst is the first new delivery kernel because it proves deterministic
multi-projectile spawning while reusing the existing projectile simulation.

### Baseline simulation

Default test variant:

```text
count: 5
relative angles: -24, -12, 0, +12, +24 degrees
release: simultaneous
speed: shared
lifetime: shared
radius: shared
```

The relative angles rotate around the **true aim vector**, not the nearest
cardinal sprite heading.

IDs are allocated in stable angular order:

```text
leftmost -> inner-left -> center -> inner-right -> rightmost
```

This order must remain deterministic at the authoritative 120 Hz and across
replay/network serialization.

### Configurable authored variants

After baseline acceptance:

- 3-shot narrow;
- 5-shot standard;
- 7-shot wide;
- staggered burst;
- radial burst;
- asymmetric patterns only when a specific spell explicitly authors them and
  readability/counterplay justify the exception.

The universal foundation itself remains symmetric.

### Neutral visual phases

Recommended minimum:

| Phase | Frames | Notes |
| --- | ---: | --- |
| Spawn | 4 | Compact formation around center pivot. |
| Travel | 4 looping | Compact -> slight stretch -> full travel silhouette -> contraction. |
| Impact | 4 | Neutral collision burst; elemental impact overlays later. |
| Expire | 2-4 | Quiet non-hit termination so expiry is distinguishable from impact. |

Directional travel sheet:

```text
8 directions x 4 frames = 32 cells
```

Impact may be rotationally symmetric and therefore does not need eight duplicate
rows unless testing proves orientation materially improves readability.

## 7. Pattern modifiers

Pattern modifiers are authored additions to a delivery kernel rather than new
weapon families.

| Modifier | Meaning | Key safety rule |
| --- | --- | --- |
| Spread | Changes angular offsets | Must remain visibly bounded and deterministic. |
| Stagger | Delays child release | Exact tick schedule. |
| Radial | Emits around center | Stable angular order and count cap. |
| Split | Spawns children | Hard generation depth/count cap. |
| Ricochet | Reflects from semantic collision | Explicit bounce count; readable trajectory. |
| Steering/homing | Curves toward valid target | Bounded turn rate; no perfect hidden tracking. |
| Orbit | Rotates around owner/anchor | Explicit duration/radius/collision. |
| Return | Travels back to source | Return trigger and collision policy explicit. |
| Pierce | Continues through targets | Hit-count cap and repeat-hit guard. |
| Delay | Arms later | Visible warning state. |
| Terrain follow | Wave/projectile follows authored surface/elevation | Fixed deterministic neighbor/path rule. |

## 8. Delivery-specific design targets

### Bolt

The simplest correctness baseline. It should prove projectile origin, swept
collision, impact, expiry and element payload attachment with minimal visual
noise.

### Beam

Beam is not a very fast projectile. It needs explicit startup telegraph, line
query, active duration, obstruction behavior, sweep policy and recovery.

### Spray

Spray is not hundreds of independent projectiles. Prefer a bounded continuous
cone/stream query with sampled elemental deposition and clear tick budget.

### Rapid Fire

Rapid Fire reuses projectile spawning but defines cadence, recoil/spread rules,
resource consumption and rate limits. Network events should be aggregated where
possible without changing authority.

### Whip

Whip uses a bounded curve/segment/tether representation. It must not rely on
rendered spline pixels for hit detection.

### Orb

Orb owns slow/persistent behavior and may later introduce presentation height or
lob semantics. Authoritative projectile elevation must be designed explicitly
before a visual arc can affect gameplay.

### Wave

Wave is a moving region/front rather than a shotgun spread. Its front, width,
speed and interaction with obstacles/elevation are explicit simulation data.

## 9. Element payload examples

The same delivery creates different decisions depending on payload:

| Delivery | Earth | Fire | Water | Wind | Ice | Charge | Light | Dark |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Burst | impact/rubble/structure pressure | heat/ignite | wet/displace | push/vector | chill/brittle | charge/interrupt | reveal/refract | decay/conceal residue |
| Beam | fracture channel | heat line | pressure jet | pressure line | freeze line | electrical lance | reveal/light line | decay/occlusion line |
| Spray | gravel/soil deposition | flamewash | wetting stream | gale fan | frostwash | static cone | radiant fan | umbral mist |
| Wave | fault/raised front | firefront | tideline | shockfront | rimewake | surgefront | dawnfront | nightfall |

These are design roles, not hidden damage multipliers.

## 10. Multiplayer readability

With several players casting simultaneously:

- hostile/allied ownership uses outline, motion, audio and origin cues in
  addition to color;
- elemental identity uses shape/value/particle grammar in addition to hue;
- neutral collision core remains visible through elemental overlays;
- impacts lose visual priority quickly after dangerous frames;
- fields/residues are visually distinct from traveling collision objects;
- team effects must remain readable under grayscale, reduced effects and common
  color-vision conditions.

## 11. Casting character animation

Character animation communicates commitment but never owns spell behavior.

Use semantic phases:

```text
startup -> release -> recovery
```

The current skeleton/character contract can use `attack_primary` or `cast` until
more specific semantic animation IDs are versioned. A future migration may add
per-delivery cast presentation, but it must preserve stable movement/collision
pivots and all eight directions.

## 12. Acceptance gate for each delivery

A delivery is not complete because an animation exists. It needs:

1. deterministic simulation representation;
2. authoritative 120 Hz fixtures;
3. replay/hash stability;
4. network authority and bounded event size;
5. collision/expiry/ownership rules;
6. neutral element-independent visual foundation;
7. at least two contrasting elemental payload tests;
8. counterplay/readability review with several players/effects;
9. reduced-effects/accessibility representation;
10. performance stress bound;
11. exact reset/cleanup where it creates persistent world state.

Implementation order begins with Burst, then Bolt normalization, Beam, Spray,
Rapid Fire, Whip, Orb and Wave unless test evidence suggests a safer dependency
order.
