# Quality expansion acceptance program

Status: **active; Q0-Q2 are green source slices, Q3 casting clarity is next**.

Q3a is source-green: a shared symbol renderer now reaches actual live projectile
cores, HUD, Loom and cast markers; old projectile smoothing/vocabulary is removed.
Full validation passed 68 suites / 26,670 assertions and a 120 Hz boot. A 40-frame
live capture (`q3-live-glyph-v2`) was produced and frame 30 inspected. Q3b still
requires specimen/impact consistency, cadence and accessibility/density review.

This program orders the current usability, movement, spell-grid and animation
requests into independently playable checkpoints. The aim is a crisp,
room-readable bullet-pattern action game with FLUX's own old-world identity—not
a copy of any reference game's assets, rooms, interface, weapons or mechanics.

| Gate | Player-facing outcome | Required proof |
|---:|---|---|
| Q0 honest world — green | Only authoritative worldbone, functional stations and combat targets appear as physical map objects; no object fades when approached. | All 14 visible buildings compile one-for-one into collision; 91 walk-through decorations and six collisionless landmarks are withheld; focused map/occlusion suites pass; `honest-world-75-v1` inspected. |
| Q1 momentum language — green | Held Jump reaches a 54 px paid apex over a 28 px tap; held Slide can continue from 150 to 480 ms; takeoff/conversion retains earned planar speed; airborne wallrun and wallrun-to-air-dodge work. | 1,294 movement and 797 transition assertions pass at 120 Hz; the 900-unit speed cap and short opening protection windows remain authoritative. |
| Q1.1 combo economy — green | A compact HUD cue exposes the next continuation premium; cost rises 10% per action to 40%, then resets after 333 ms without continuation. | Host prediction/replay canonical state and packed schema-13 snapshots share the counters; refused inputs and holds do not increment them; eight-player packet remains below the 1392-byte MTU. |
| Q1.2 resource retune — green | Every champion gains a body-role-appropriate Stamina reserve; spell Flux costs fall 14–20% while every attack still costs Flux. | Catalog/body bounds and accepted definition signatures updated; 4,210 focused resource/combat assertions pass. |
| Q2 spell matrix — green | The Loom lists Fire/Water/Earth/Wind/Charge/Ice/Light/Dark by row and Bolt/Burst/Spray/Beam/Field by column; all forty cells are playable and Vector Lance remains a separate proven variant. | Schema-4 templates expand to stable wires 154–178; 4,647 focused data/Loom/compiler assertions, forty-spell execution coverage, 1,325 champion/Burst/MTU assertions and inspected `spell-matrix-v1` capture pass. |
| Q3 elemental casting clarity | Cast hands, release cue, projectile body, trail, impact and field boundary share one unmistakable element grammar and distinct delivery silhouette. | Normal/high-contrast/reduced-effects review; color is reinforced by shape and motion; no dual-element attacks before chemistry acceptance. |
| Q4 crisp character motion | Nearest-neighbor silhouettes retain stable size/pivot and use natural bounded contacts/transitions in all eight directions. | No filtered edge, frame-size drift or spell pixels in bodies; sequence review proves leg alternation and readable jump/slide/roll phases. |
| Q5 integrated checkpoint | Windows source/package remains one-step playable and remote-session compatible at the published protocol. | Full and Release gates, truthful captures, Farflow host/join/reconcile/quit, then human playtest pause. |

## Constraints

Worldbone truth beats decoration. Momentum can be retained but never generated
without an authored impulse, and all speeds remain bounded. Combo escalation is
an explicit Stamina price, not a hidden input lock. Each attack remains paid;
lower Flux costs must increase expression without enabling permanent lane
coverage. The spell matrix expands through shared delivery kernels and reusable
presentation assets, never one bespoke script per spell.

## Current evidence

| Check | Actual result |
|---|---|
| Honest-world focused | `wellspring-illustrated-kit`, campus layout, sight occlusion and natural-map suites: 327 assertions, zero failures/stderr |
| Momentum/network focused | Movement, transitions and snapshot: 2,170 assertions, zero failures/stderr; broader eight-suite movement/network/HUD set also green |
| Resource/combat focused | Ability data, compiled definitions, combat, champions, body profiles and resources: 4,210 assertions, zero failures/stderr |
| Spell matrix focused | Catalog/Loom/compiler/summary: 4,647 assertions; all forty cells release through authoritative projectile/spray/beam/field resolvers; maximum eight-player snapshot remains below 1392 bytes |
| Spell matrix visual | Truthful 1280×720 capture `.godot/visual-captures/spell-matrix-v1`; all rows, columns, names and positive costs fit without paging |
| Full repository | 67 suites, 26,619 assertions, source import and protocol-37 120 Hz boot; zero failures/stderr in 36,699 ms; `.godot/receipts/spell-matrix-full-v2.json` |
| Visual review | Truthful 75% capture `.godot/visual-captures/honest-world-75-v1`; collisionless scenery withheld and no approach fade |
