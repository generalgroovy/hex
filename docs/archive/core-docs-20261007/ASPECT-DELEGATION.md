# H.E.X. focused aspect delegation

Status: 2026-10-07. Forty-two reusable specialists; six concern assignments across M1/M2 are completed and source-verified by root. The other 36 roles remain queued. Definitions are not forty-two running processes or completed improvements; root is the fourth concurrency slot.

This is an ownership and dispatch manifest, NOT a second implementation queue.
Execution remains in [the single queue](OVERHAUL-IMPLEMENTATION.md); current evidence and playable artifacts remain in [the resume handoff](HEX-RESUME.md).

## First batch: exact player-facing rules

| Ticket | Contract | Ownership / state |
|---|---|---|
| Held jumpsquat | Holding ground preparation stops self-motion, including preparation from a slide. No hidden velocity can return on cancellation or failed release. Instant same-command taps retain earned momentum because they occupy no held-preparation tick. External field pushes remain effective. | `jump_preparation` implements movement, relevant existing movement/prediction tests and movement guide; root owns integration. |
| Slide entry | Slide starts along actual incoming velocity, not stale facing. Existing drag/carve, costs, minimum commitment and explicit brake remain. | Same movement writer; `slide_momentum` independently reviews. Never two writers in movement_system.gd. |
| Exact field footprint | Outline follows authoritative occupied hexes including empty holes. Duplicate compatible region records in one hex must not hide its true boundary. No decorative analytic radius or trail. | `field_readability` owns hex_court_presenter.gd and its existing shared-presenter suite. |

All three repairs pass focused v2 (16 suites / 366,039 assertions) and Full v1 (220 / 3,917,456), zero failures/stderr, import/identity/configured 120 Hz boot. Native/human acceptance remains pending; previous packages are preserved unchanged. See [fresh evidence](../docs/aspect-m1-evidence-20261007/README.md). These repairs do not claim competitive balance, complete animation coverage or dense 120 Hz acceptance.

## Second batch of core integrity repairs

M2 uses three workers: one movement writer, one chemistry writer and one resource
test/independent review worker. Effective Jump/Slide priority, exact fractional
sprint payment and nonincreasing Steam cooling pressure pass focused green
(16 / 302,439) and Full (220 / 3,963,715), with import/identity/120 Hz boot and
zero failures/stderr. [Evidence](../docs/core-m2-evidence-20261007/README.md)
preserves failed controls, fixture corrections and human/native acceptance limits.
The role state below qualifies these bounded repairs, not an entire subsystem.

## Shared dispatch contract

1. Read this contract, the assigned ticket, relevant current queue/specification lines and necessary files only. A role card is not an instruction to start a broad rewrite.
2. Each ticket names the player benefit, current defect, intended invariant, exact write paths, test matrix and stopping condition. Start read-only when the issue is uncertain.
3. Maximum three workers plus root. All specialists sharing movement, combat, chemistry, networking or presentation files work serially or as read-only reviewers. A role owns a concern, not unconditional access to every related file.
4. Root alone edits bootstrap/shared registries/protocol/build identity/checkpoint pointers/shared docs and runs Godot/import/tests/capture/profiling/export. No acceptance run against a moving source tree.
5. Preserve dirty work, original assets, previous working packages and useful receipts. No reset/clean/stash, deletion of unrelated files, commits, push, publishing, deployment, plugin/account changes or silent cap increases.
6. Reuse existing tools/assets. All image generation/editing follows the imagegen skill when needed; this dispatch does not require new artwork or paid/external resources.
7. Repair demonstrable bugs before tuning. Balance means useful choices, counters and trade-offs, not equal numeric values. Show per-choice evidence; do not infer 30 unique identities or 36 balanced reactions from registry completeness.
8. Authoritative state, aim/travel distinction, fixed 120 Hz stepping, paid resources and deterministic replay remain invariant unless a separately reviewed ticket changes them. Presentation may simplify but must never change collision or conceal real danger.
9. Retain canonical eight-element order, four spell families and twelve slots; no trails, orbiting elements, moving fields or invented content. Current mode/roster/cap limitations remain explicit.
10. Return facts, exact paths, tests added, static checks, NOT_RUN gates and dependencies in a compact handoff. Clean only owned disposable scratch. Stop at the bounded checkpoint, not when allowance is consumed.

## Coverage and acceptance matrix

Status here records dispatch, not final game acceptance. Every row has one reusable project-local agent definition in `.cursor/agents/`.

| Specialist | Aspect | Batch | Dispatch | Improvement / invariant | Required evidence |
|---|---|---|---|---|---|
| [hex-jumpsquat](../.cursor/agents/hex-jumpsquat.md) | Ground jump preparation | M1 | SOURCE_VERIFIED | Held preparation stops self-motion; instant same-command taps retain earned momentum; external pushes remain effective. | Eight headings, sprint/neutral/opposed hold, release, cancellation, no stored-motion resurrection, exact prediction replay. |
| [hex-slide](../.cursor/agents/hex-slide.md) | Slide momentum and braking | M1 | SOURCE_VERIFIED | Capture incoming velocity heading and speed; retain authored drag/carve, paid commitment and deliberate brake. | Eight headings plus mismatched facing, neutral/perpendicular/opposed entry, cap, cost, wall and tap-jump controls. |
| [hex-air-movement](../.cursor/agents/hex-air-movement.md) | Jump, double jump, flight and air dodge | M2 | QUEUED | Keep the race-authorized aerial options distinct, directional, chainable and readable without free lift or invulnerability. | Height/contact-plane boundaries, release/hold, eligible versus ineligible flight, exhaustion, landing and low ceilings. |
| [hex-wall-movement](../.cursor/agents/hex-wall-movement.md) | Wallrun and walljump | M2 | QUEUED | Make contact acquisition, tangent travel, release jump and chain exits predictable without wall clipping or free retries. | Corners, gaps, mirrored walls, held/released inputs, momentum, cooldown and resource accounting. |
| [hex-input-bindings](../.cursor/agents/hex-input-bindings.md) | Input, aim and bindings | M2 | QUEUED | Preserve keyboard/mouse/controller equivalence, eight-direction travel, independent cursor aim and safe rebinding. | Focus loss, simultaneous edges, held/modifier keys, wheel impulses, modal ownership, unplug/reconnect, no stuck action. |
| [hex-action-chaining](../.cursor/agents/hex-action-chaining.md) | Action transitions and cancellation | M2 | SOURCE_VERIFIED | Effective Jump/Slide chord repair; the broader paid transition audit remains queued. | Eight-heading real-command regressions, held-repeat and fast-fall positive controls, prediction and Full pass. |
| [hex-hit-volumes](../.cursor/agents/hex-hit-volumes.md) | Hurtboxes, collision and vertical planes | M2 | QUEUED | Use size-only hurtboxes, shared wall clearance and truthful ground/low/air exposure; visuals never silently grant immunity. | All three sizes and poses, walls/corners, ground fields versus projectile planes, invulnerability start/end ticks. |
| [hex-resources](../.cursor/agents/hex-resources.md) | Health, Flux and Stamina economy | B1 | SOURCE_VERIFIED | Exact fractional sprint admission and recovery repair; wider economy tuning remains queued. | Boundary profiles/remainders, exact-funds and walking controls, independent paid casting, depletion/recovery and Full pass. |
| [hex-projectiles](../.cursor/agents/hex-projectiles.md) | Projectile simulation and interception | B2 | QUEUED | Keep Bolt, Heavy, Rapid and Spray distinct in speed, coverage, strength and cost with deterministic swept contacts. | All 32 spells, fast crossings, weaker-strength subtraction, equal-match reactions, walls/cursor endpoints, ordering and load. |
| [hex-chemistry](../.cursor/agents/hex-chemistry.md) | Reaction rules and hex authority | B1 | SOURCE_VERIFIED | Steam cooling counter repair; all-pair economy comparison remains queued. | Actual pressure never increases; finite provenance, footprint, one-use channel, snapshot continuation, truthful zero-intensity cue and Full pass. |
| [hex-field-readability](../.cursor/agents/hex-field-readability.md) | Affected-hex and reaction readability | M1 | SOURCE_VERIFIED | Make the exact occupied footprint, holes, strength and lifecycle visible in both effects settings; no analytic range circles. | Duplicate/adjacent cell boundaries, owner/phase/danger separation, empty holes, expiration, native normal/reduced review. |
| [hex-camera](../.cursor/agents/hex-camera.md) | Camera and spatial framing | V1 | QUEUED | Keep the approved single zoom and subtle smooth follow/lead without disorienting motion or threat cropping. | Abrupt aim reversal, sprint/slide, corners, screen edges, resize, reduced motion and offscreen threat consistency. |
| [hex-visibility](../.cursor/agents/hex-visibility.md) | Sight, occlusion and fog | V1 | QUEUED | Visible wall faces and the local actor remain readable; hidden areas darken gently without revealing enemy information. | Wall-facing, sixth-sense region, cone limits, occlusion corners, local sprite safety, spectator and team information leakage. |
| [hex-network](../.cursor/agents/hex-network.md) | Network authority and recovery | T1 | QUEUED | Keep deterministic prediction/reconciliation, safe validated packets and recoverable lobby/round lifecycles. | Malformed/stale/duplicate inputs, jitter/loss, late join, disconnect, rematch, exact-export localhost then physical Internet. |
| [hex-accessibility](../.cursor/agents/hex-accessibility.md) | Accessibility and readability | U1 | QUEUED | Communicate essentials by shape/text/timing as well as color; respect reduced effects/motion and all control methods. | 960x540 and 1280x720 labels, contrast, color-independent danger cues, focus visibility, readable bindings and audio alternatives. |
| [hex-persistence](../.cursor/agents/hex-persistence.md) | Preferences, saves and safe close | U1 | QUEUED | Persist valid player choices safely with resilient defaults and migration; never damage settings on interruption. | Corrupt/missing/old values, atomic writes, readonly paths, interrupted close/update and preference restoration. |
| [hex-rendering](../.cursor/agents/hex-rendering.md) | Render performance and bounded effects | T1 | QUEUED | Cull only irrelevant presentation; cache/batch by measured benefit and bound transient effects without hiding danger. | Worst visible density, cache invalidation, normal/reduced parity, allocation and p95/p99 rendered profiling separate from simulation. |
| [hex-asset-pipeline](../.cursor/agents/hex-asset-pipeline.md) | Reusable pixel asset pipeline | V1 | QUEUED | Validate palette, alpha, pivot, frame size, eight-direction mapping and import/export registration while preserving originals. | All admitted roster assets, missing frame fallbacks, scale/contact consistency, nearest filtering, deterministic manifests. |
| [hex-physical-combat](../.cursor/agents/hex-physical-combat.md) | Punch, kick and elemental follow-through | B2 | QUEUED | Make physical attacks and spell-imbued contact paid, readable and reliably counterable using the existing contract. | Contact timing, knockback/walls, stamina, imbue payment, miss/no free field, hitstop separation, prediction and team rules. |
| [hex-character-identity](../.cursor/agents/hex-character-identity.md) | Character identity and roster balance | B4 | QUEUED | Audit all 30 identities individually for recognizable art, truthful affinity/stats and a useful horizontal niche without power creep. | Same-weave comparisons, starter kit validity, identity/size/race separation, complete selection, per-character evidence not universal balance claims. |
| [hex-movement](../.cursor/agents/hex-movement.md) | Movement integration | M2 | QUEUED | Cross-action momentum and one shared transition contract | One writer for shared movement code; agreement across all movement specialists |
| [hex-elements](../.cursor/agents/hex-elements.md) | Eight element identities | B1 | QUEUED | Water, Earth, Fire, Air, Ice, Charge, Light and Dark each offensive and useful | Every element has a distinct use, counter and truthful capability description |
| [hex-spells](../.cursor/agents/hex-spells.md) | Spell selection and loadouts | B2 | QUEUED | 32 spells, twelve positions, safe equip and discoverable experiments | No broken exposed choices; modifiers, invalid/empty slots and restoration |
| [hex-races](../.cursor/agents/hex-races.md) | Races and three-size balance | B3 | QUEUED | All 21 races; size, ancestry and visual identity do not get conflated | Same-weave comparisons, flight permissions, hurtbox/wall-clearance distinction |
| [hex-characters](../.cursor/agents/hex-characters.md) | Character poses and facing | V1 | QUEUED | Thirty identities, exact eight-direction facing and consistent body scale | Travel A/aim B, slide follows travel, no mesh morphing or fake missing frames |
| [hex-gait-timing](../.cursor/agents/hex-gait-timing.md) | Walk/run animation timing | V1 | QUEUED | Alternating contacts, believable speed changes and transition continuity | Phase/contact checks plus actual movement viewing; still frames are insufficient |
| [hex-landing-art](../.cursor/agents/hex-landing-art.md) | Jump and landing contact art | V1 | QUEUED | Grounding, takeoff and impact cues using the established retro style | Registration, alpha, lifetime and normal/reduced readability |
| [hex-vfx](../.cursor/agents/hex-vfx.md) | Cast, hit and spell effects | V1 | QUEUED | Immediate element/strength identity and impactful but restrained hit feedback | No stale cues, trails or visual threats outside real geometry |
| [hex-map](../.cursor/agents/hex-map.md) | Wellspring layout and navigation | W1 | QUEUED | Purposeful routes, wall chains, safe practice and clear activity locations | Every apparent path passable and every route useful; collision authority stays exact |
| [hex-environment](../.cursor/agents/hex-environment.md) | Terrain, cover and interactables | W1 | QUEUED | Coherent hex-based retro terrain and readable collision/height | Assets match real walls, materials and visible/occluded states |
| [hex-gui](../.cursor/agents/hex-gui.md) | HUD and combat feedback | U1 | QUEUED | Health, Flux, Stamina, readiness and refusal reasons at a glance | No clipping/stale status at supported sizes or under dense activity |
| [hex-menus](../.cursor/agents/hex-menus.md) | Menus and configuration | U1 | QUEUED | Compact combined cards, safe focus and keyboard/controller navigation | No dead options, lost focus, conflicting edit ownership or accidental world input |
| [hex-sound](../.cursor/agents/hex-sound.md) | Audio, ambience and impact cues | V1 | QUEUED | Distinct informative sound with controlled voice load | Mute/reduction, event priority and cleanup; listening acceptance remains separate |
| [hex-practice](../.cursor/agents/hex-practice.md) | Onboarding and practice | W1 | QUEUED | Learn actions and chemistry by doing, with current bindings and retry | Actual paid demo, restored loadout, truthful cost/timing and useful feedback |
| [hex-solo](../.cursor/agents/hex-solo.md) | Solo Duel and opponent AI | B5 | QUEUED | Fair paid rival behavior, readable tells, retry and useful practice | No omniscient input advantage; valid counters, mutual defeat and restoration |
| [hex-duel](../.cursor/agents/hex-duel.md) | 1v1 Duel | B5 | QUEUED | Mirrored contest, clear results and reliable rematch | Same-tick trades, scoring, departure and spectator rules |
| [hex-duos](../.cursor/agents/hex-duos.md) | 2v2 Duos | B5 | QUEUED | Existing exact-four team mode and coordinated counterplay | Two locked teams, ally labels, shared score, departure and rematch |
| [hex-trios](../.cursor/agents/hex-trios.md) | 3v3 Trios | B5 | QUEUED | Existing exact-six team mode and six-player clarity | Sparse IDs, empty teams, shared score, readable threats and rematch |
| [hex-ffa](../.cursor/agents/hex-ffa.md) | Free-for-all | B5 | QUEUED | Readable multi-way contest without identity or spawn ambiguity | Duplicate names, trades, respawn, scores and observer rules |
| [hex-runtime](../.cursor/agents/hex-runtime.md) | Simulation performance | T1 | QUEUED | Complete 120 Hz simulation/publication work within measured budget | Deterministic exact semantics, p95/p99/cold-spike evidence; no cap increase |
| [hex-delivery](../.cursor/agents/hex-delivery.md) | Install, update and friend connection | T1 | QUEUED | Minimal-effort safe Windows onboarding and honest Internet route | Portable/installer, rollback/safe close, update trust and real two-PC Internet gate |
| [hex-acceptance](../.cursor/agents/hex-acceptance.md) | Independent QA and integration review | ALL | QUEUED | Adversarial review of changed behavior, tests, docs and claims | Fresh versus historical evidence, preserved fallback and no false acceptance |

## Safe sequencing and context economy

| Batch | Scope / dependency | Exit gate |
|---|---|---|
| M1 | Held jumpsquat, slide entry, field boundary repair; two disjoint code writers and one reviewer | Focused regressions, full suite, truthful docs and native playtest observations; keep historical package until candidate qualifies |
| M2 | Input, airborne/wall actions, transition/cancellation, hurtboxes and forced displacement | Eight directions x three sizes, authority/prediction parity and clear action refusal |
| B1-B2 | Existing balance queue: resource economy, elements/reactions, projectile families and physical combat | All 32 spells / 36 pairs, paid burst/rest/interception cases and falsifiable tuning targets |
| B3-B5 | Size/ancestry, each character identity and each existing mode | Same-weave comparisons, mode-specific counterplay and human feel; do not invent bonuses to make labels different |
| V1 / U1 | Animation, effects, camera, visibility, audio, HUD, menus, accessibility and persistence | Actual moving frames/listening where appropriate, normal/reduced parity, narrow/default viewport and input recovery |
| W1 | Purposeful Wellspring routes, environment, onboarding and practice | Real paths/collisions, working interactions and novice comprehension; no arbitrary area growth |
| T1 | Complete-path performance, network robustness and delivery | Measured sustained tick budget, bounded memory/draw load, portable/installer checks and actual Internet test when available |

These are dependency groups, not permission to expand the current ticket. Root can pull forward an independent, high-value defect; record that decision in the single queue.

For repeated content (8 elements, 32 spells, 36 pairs, 21 races, 30 characters), the concern owner supplies a coverage matrix and assigns one stable-ID case at a time. Do not create permanent duplicate agents for every data row or allow concurrent registry writers. Use one reviewer for integration, not a second implementation of the same subsystem.

Current source is p57-339c9876cd3a with fresh focused/Full/import/boot evidence. The prior balance candidate p57-c5f23a22d58f and team/fallback exports remain unchanged. No new export/release, dense-render performance, human balance, complete authored animation or physical Internet acceptance follows from this manifest.

