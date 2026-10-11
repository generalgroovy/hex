# The Wellspring — one chemistry courtyard now

**Status: PROPOSAL.** Source-based geometry and offline checks, not a Godot implementation. The only executable map change supplied is a separately hash-gated JSON candidate. Source references below resolve through [SOURCE_REFERENCES.md](SOURCE_REFERENCES.md). All coordinates refer to the supplied snapshot, not an inspected live checkout.

## The spatial idea

**Two casts. Two exits. One clear return.** A quiet assay floor gives one experiment a readable place. A pair of small stone shoulders makes the decision to continue aiming, cut southeast, or retreat around the northwest edge meaningful. The broad south return remains usable without jumping, sprinting or spending stamina. A recognizable fountain, a functional learning canopy and a Farflow rail explain arrival, preparation and company management. They do not each need a paragraph on a lectern.

This is continuous eight-direction movement with independent aim. Hexes describe affected material, not permitted movement steps. North is decreasing world y. A diagonal path is a real continuous line; no movement, impact point, exit or station is snapped to a hex center.

## Current versus proposed

| Subject | Supplied current campus | Proposed v1; implementation boundary |
|---|---|---|
| Extent | 3072 × 2304 px; chemistry world starts at y=112 | Same extent. No new acreage. |
| Districts | Three overlapping authored district rectangles: conservatory, nexus, proving quarter | Keep all three. The nine-district hub catalog is a future description, not this map. |
| Solids | 16 building AABBs; supplied builder does not add collision for paving, stations or landmarks | Add only two reused 72 × 72 practice-wall AABBs. No silent fountain collision. |
| Source Court | Spawn, north learning stations, south Farflow stations; fountain landmark has an authored position | Same anchors. Propose one flush, walk-through fountain landmark and distinct functional station objects. Presentation work is NOT in the JSON patch. |
| Crucible | 960 × 448 activity rectangle, one 320 × 336 open practice group; target and firing lane already exist | Rename to Chemistry Courtyard; frame the same group with quiet stone/slate and two shoulder walls. |
| Routes | Twelve authored routes and seven connections; ordinary routes promise full-width passage | Keep ordinary routes/connections exactly. Change only one advanced practice marking. New illustrated escape lines are choices, not forced paths or colliders. |
| Dueling | Existing arena, target range, four duel obstacles and eight spawn anchors | Retain them. Reuse east-return access; do not put a second duel arena in the chemistry space. |
| Stations | Twelve anchors/commands; similar lecterns and small repeated labels in captures | Preserve the twelve functional anchors. Group presentation into recognizable destinations; put detailed reference and proposed remote management in a panel. |
| Chemistry authority | Whole selected eligible cells; finite paid material; runtime caps | No changed recipe, cost, lifetime, strength, cap or input rule. Eligible-cell topology changes only because two immutable obstacles are proposed. |
| Safety | No evidence of a permanent source-court sanctuary | None added. Safer practice is achieved through spacing, warning, consent, retreat and waiting for expiry—not immunity. |

Source: campus JSON `/canvas_size`, `/districts`, `/buildings`, `/activity_areas`, `/stations`, `/arena`; campus builder lines 435–577; shared contract. [S01–S05]

## What the captures actually establish

The four supplied 1280 × 720 frames are historical gameplay evidence. They show the Source Court, repeated north-row lecterns, Farflow controls, character/HUD scale in those frames, whole Water cells and transparent Steam near shared circulation. They do not establish the camera-to-world transform, a complete map, animation timing, long-session performance, networking reliability or current live-checkout behavior. A visually prominent fountain at the authored anchor is not evident in these frames; that is a presentation opportunity, not proof that the landmark definition is absent or broken.

[03-current-capture-annotated.png](artifacts/03-current-capture-annotated.png) retains the source capture at 1:1 image pixels and adds numbered observations. The two supplied concept-map images supplied atmosphere and landmark ideas only. Neither was traced, measured or substituted for the campus geometry. [S10–S11]

## Exact coordinate contract

One world pixel is 1000 fixed units. The pointy-top lattice uses the authored integer approximation—not a freshly calculated ideal regular hexagon:

```
center_fixed(q,r) = (64000*q + 32000*r, 55425*r)
center_px(q,r)    = (64*q + 32*r, 55.425*r)
local vertices, fixed units, in winding order:
(0,-36950), (32000,-18475), (32000,18475),
(0,36950), (-32000,18475), (-32000,-18475)
```

The world chemistry rectangle is `[0,112,3072,2192]` in **x,y,width,height**, ending at `(3072,2304)`. All vertices of an eligible cell must lie within the source bounds. Building AABBs are expanded by the common 18 px wall clearance before positive-overlap exclusion. At a shared edge, canonical ownership is the lexicographically smallest `(q,r)` among closed polygons. A disk selects cells by positive-area intersection with its exact impact/radius; exact tangency does not select a neighbor. A zero-radius disk uses canonical ownership. Once selected, the entire cell is affected. A visual circle or clipped hex may never redefine that result. [S04–S05]

| Anchor | Exact world px | Canonical owner q,r | Owner center px | Status |
|---|---:|---:|---:|---|
| Fountain | (1536,800) | (17,14) | (1536,775.950) | Existing authored point |
| Shared spawn | (1536,880) | (16,16) | (1536,886.800) | Preserve |
| Chemistry target / illustrated impact | (1568,1248) | (13,23) | (1568,1274.775) | Existing target; proposed experiment endpoint |
| Chemistry firing foot | (1568,1440) | (11,26) | (1536,1441.050) | Preserve; canonical face ownership is not a centering instruction |
| West return corner | (1120,1408) | (5,25) | (1120,1385.625) | Existing route point |
| East return corner | (1920,1408) | (17,26) | (1920,1441.050) | Existing route point |

`HEX_LAYOUT.json` records bounds, IDs, 47 anchor entries, world/fixed units, canonical owners, proposed entrances, collision semantics, heights and future schematic status. `data/eligible_current.json` and `data/eligible_pilot.json` enumerate the complete offline-derived eligible sets. Arbitrary world anchors can sit away from cell centers and are not guaranteed to be eligible chemistry cells.

## One small map candidate

The courtyard stays in current activity bounds `[1056,1152,960,448]`. Its practice group remains `[1408,1152,320,336]`. Target entity 903 at `(1568,1248)`, target radius/health, firing foot `(1568,1440)`, 64 px lane width and 192 px lane length are unchanged. The stationary target is a reusable endpoint, not a dispenser of free ingredients. [S02, S06–S07]

| Piece | Placement x,y,w,h in world px | Function | Collision / presentation |
|---|---|---|---|
| West shoulder, ID 117 | `[1216,1216,72,72]` | Breaks a westward firing angle; creates a northwest wrap and wall-tech practice face | Solid immutable 2D AABB, `practice_wall`, non-vaultable. Proposed 24 px drawn facade is visual only. |
| East shoulder, ID 118 | `[1768,1216,72,72]` | Makes a southeast cutback different from the west wrap | Same reused piece and collision contract. |
| Existing workshop, ID 106 | `[1264,1504,384,112]` | Existing south-middle sightline stop; teaches returning around an obstacle | Unchanged. Neither proposed lane ends against its face. |
| Quiet slate / warm stone | `[1408,1152,160,336]` / `[1568,1152,160,336]` | Equal-scale dark/light backgrounds for reading the same material | Render-only; no height, collision, damage or safety change. |
| Fountain | Existing `(1536,800)` anchor, proposed 96 × 96 art extent | Arrival landmark, orientation back to shared spawn | Flush grate and contained rill; non-solid, no Water ingredient generation. A solid basin would require a separate topology/collision review. |

Only the first two pieces, one advanced marking and courtyard/group copy are changed by `pilot/campus_candidate.json`. Quiet floors, fountain art, station redesign, remote panel and VFX motifs are design artifacts, **not implemented by that JSON**. The existing constructor marks `practice_wall` as a runnable surface, but actual wall-tech trajectories and inputs require runtime tests. No collider height or vault mechanic is invented. [S03, S08]

The advanced `archive-crown-stair` marking becomes width 64 at `[(1344,1408),(1344,1184),(1728,1184),(1728,1408)]`. It is optional practice, not a reduced-width replacement for public circulation.

### Two escape choices and the return

The northwest choice follows `(1568,1248) → (1360,1168) → (1120,1168) → (1120,1408)`, an offline polyline length of 702.854 px. It goes north of the west shoulder, breaks the approach angle and rejoins the garden-side return.

The southeast cutback follows `(1568,1248) → (1712,1360) → (1920,1408) → (1920,1120)`, length 683.895 px. It changes direction below the east shoulder and rejoins the route toward Farflow and the proving quarter. These are illustrative centerlines, not measured travel times. Both target a 96 px clear corridor in the offline check. Their similar overall lengths are intentional; one is not a dominant express lane.

The existing 160 px south public route stays centered on y=1408. North entry remains open from Source Court; west/east entries connect to `(1120,1168)` and `(1920,1408)`; south returns pass the workshop at `(1168,1488)` and `(1744,1488)`. An activity rectangle is not a room wall. No exit is labeled permanently safe: a future cast, moving front or temporary structure may change its risk.

For solo practice, aim down the existing clear lane and observe a paid reaction before entering. For two-player drills, one attacker holds an angle while the defender chooses an exit; reverse roles rather than adding more cover. For chemistry comparison, repeat the same endpoint, aim and paid deliveries after expiry. Do not use a shared reset until its isolation is confirmed. For duels, continue east to the already-authored court; keep matchmaking and ready controls away from the firing line.

### Bottlenecks and constraints

The shoulder pairs cannot become permanent shelters against every chemistry footprint. A 34 px Rampart selection can affect a whole hex; test creation while actors occupy either route, at low stamina and beside existing solids. Failure to offer a legal escape is a release blocker, not a reason to shrink bodies or make ground immune.

Public circulation must not become the preferred firing station. Projectiles from the assay lane must not require interacting with the reset bell or Farflow props. Between north-row stations, interaction radii already overlap: selecting the nearest eligible action, one visible prompt, device changes and modal focus all need runtime validation. Do not silently reduce interaction radii to make a screenshot look cleaner.

## An honest static result

The final offline geometry suite passes **247/247** checks. It reproduces 1493 current eligible cells, derives 1474 for the candidate and records 19 removed cells, zero added cells. That is a topology result, not a performance improvement claim. All ordinary route definitions, stations, targets, shared/arena/gather spawns and arena rules remain identical.

The first draft failed two ordinary-route clearance checks. Those failures and the rejected map are retained under `evidence/rejected_v0_*`. Moving the shoulders to the final positions—not narrowing ordinary routes—resolved them. The checker uses analytic point/segment distances to static AABBs and an independently ported integer lattice. It does **not** execute the missing `CollisionWorld.can_occupy` implementation, resolve dynamic contacts, model every collider norm, or certify Godot clearance. [S03–S05]

## Native-scale and reusable pieces

`04-native-normal-1280x720.png` and `04-native-reduced-1280x720.png` use a declared synthetic camera origin `(896,1000)` at 1 world px per output px. The three existing base body frames are copied unscaled from the supplied sheets; their baked display sizes stay 58/63/68. No character asset, proportion, hurtbox, wall clearance or stat changes are proposed. Steam is selected with the source-derived disk rule. Magma is an **explicit illustrative coverage set**, not the output of a formation simulation. These still images test composition and shape separation, not animation, combat readability or runtime occlusion. The actor poses and two projectile motifs are illustrative, not a new animation or projectile asset pack. [S09]

Use six reusable visual pieces: low-noise warm stone, quiet slate, thin brass inlay, the 72 px stone shoulder, a functional station rail, and the flush fountain. Use peripheral greenery, timber grain and weathered edges rather than screen-wide floor noise. Preserve readable feet, bodies, aim and separate Steam/Magma motifs across both floor values. The reduced composition removes internal Steam marks, not coverage or danger information. `05-reusable-kit` is a dimensioned design sheet—not a production atlas or collision import file.

## Modular Wellspring later

First reuse the movement gardens, then the existing proving loop, then the learning/archive presentation. Only after those pass their gates consider one new foundry or seasonal pocket. A module should have one memorable purpose, one visible next destination and at least two exits, with an ordinary 192 px main connector and 160 px secondary connector as **proposed interface dimensions**. Future world placement, transform, collision and streaming are explicitly unknown. `06-modular-expansion` and `HEX_LAYOUT.json/future_modules` are **SCHEMATIC**, not measured geometry.

A new pocket must reuse the six-piece kit, survive the same three-size checks and not scale active work with total acreage. Decorative water is an atlas/material motif, not autonomous chemistry. Reuse visible static chunks; do not spawn a node per tile or a particle system per hex. Streaming and distant-simulation behavior are not supplied, so they are integration questions, not assumed free infrastructure.
