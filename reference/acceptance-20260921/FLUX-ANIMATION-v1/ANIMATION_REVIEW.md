# FLUX · shared animation foundation v1

**Status: PROPOSAL + OFFLINE_PREVIEW. Source structure checked; no game execution or human acceptance.**

Review order: **Small first → the same rules on Middle → the same rules on Large → skins only after shared-motion acceptance.** This package does not replace live textures, edit game code, change stats, or commission the roster. The warm adventurer foundation remains the visual baseline. The supplied reference image is not treated as approval of a new style.

## 1. What was actually available

The supplied packet is a selective source snapshot, not a buildable repository. Its manifest reports `main`, head `a1aa02807626823d0fbc1e25e75441ca3b7f4d36`, 1,118 dirty entries and runtime identity `p53-cb264f9358a4`; these are **reported identities, not freshly computed runtime identity or a live Git inspection**. All **63 listed files** matched their packet byte counts and SHA-256 hashes. That verifies the packet, not the game. See `evidence/input-integrity.json` and `INPUT_MANIFEST.json` in the input packet.

Read the shared contract, task brief, input manifest, audit snapshot, current source-authority sections, body presenter, complete direction resolver, active atlas manifest, body profiles and relevant motion/checkpoint/control documentation. All **nine active PNGs** were decoded and checked across **3,312 cells**. Visual inspection covered every base row/direction and seven selected travel/aim rows of eight phases from **each** walk/sprint bank, Small first. It was not a human review of every one of the 3,312 poses.

The September 15 before/after board was viewed **only as historical slide evidence**. The September 20 normal/reduced Steam images are saved gameplay stills; they establish the supplied visual context, not a fresh animation playtest or a continuous sequence. No source footage of the five requested transitions is supplied. Full input scopes and exact source excerpts are in `evidence/inputs-read.json` and `evidence/SOURCE_EXCERPTS.md`.

Important missing inputs: `CartoonChampionPresenter` and its action-priority/cast integration, the producer of `normalized_phase`, the original editable fixed-bone rig/exporter/baker, actual aerial/landing presentation sampler, associated animation tests, complete import/dependency closure, a runnable project and continuous captured sequences. The task permits useful source review without pretending these are present. [Shared contract, Authority and Completion; audit snapshot, What is absent; sprite pipeline L21–27.]

### Evidence vocabulary

| Label | Meaning in this review |
|---|---|
| **SOURCE_VISIBLE** | Directly observed code, manifest, or source pixels. |
| **DOCUMENTED_NOT_TRACEABLE** | Supplied documentation describes it, but the implementing caller/rig is absent. |
| **INFERRED** | A plausible visual risk or interpretation, not established runtime behavior. |
| **MISSING** | No required input or corresponding atlas slot supplied. |
| **PROPOSED** | A candidate change or acceptance rule, not implementation. |
| **HUMAN_ONLY** | Readability, plausibility and feel requiring actual viewing/play. |

Output classifications use the separate shared handoff vocabulary: PROPOSAL, OFFLINE_PREVIEW and STATIC_VERIFIED. Nothing here is RUNTIME_VERIFIED or HUMAN_ACCEPTED.

## 2. Preserve the existing architecture

**SOURCE_VISIBLE.** The presenter already implements **8 travel × 8 aim × 8 phases** in each of two separate gait banks. It is not a four-direction system, and it does not need a replacement locomotion architecture. Indexing is `((travel*8+aim)*8+phase)`, packed into 16 columns × 32 rows of 96×96 cells. The feet pivot is `(48,84)`. Direction order is **S, SE, E, NE, N, NW, W, SW**; screen-positive Y is South. NE is `(707,-707)`, not a guessed index 1. [Presenter L5–19, L50–57, L104–132; resolver L5–25.]

**SOURCE_VISIBLE.** For moving `walk`, `walk_b`, `sprint` or `sprint_b`, the presenter quantizes the supplied phase to eight entries. Sprint uses its own texture. All other known states take a base cell indexed by **aim**. Unknown states return an empty result. The current base rows are grounded, jump, cast, hit, walk, sprint, slide, roll, walk_b and sprint_b. The presence of a jump row does not establish a complete Float, air-dodge or landing animation. [Presenter L15, L97–132.]

**SOURCE_VISIBLE.** `frame()` calls the resolver’s **stateless** classifier. The resolver also offers a stateful 8-degree hysteresis margin, but that does not prove the presenter uses hysteresis. Exact sector-boundary equality is cardinal. A zero travel vector prevents gait-bank selection and uses the base row; its reported travel index falls back to aim. Zero aim defaults to South in this function. The upstream retained-aim policy cannot be established from this function alone. Do not add smoothing delay to immediate cursor-facing behavior or change shot directions while “fixing” flicker. [Resolver L31–43, L91–123; presenter L114–127; specification L649–656.]

**DOCUMENTED_NOT_TRACEABLE.** The pipeline document says real ground distance drives phase, one cycle per 1.30 body heights, capped at three walk/five sprint visual cycles per second. Stops and blocked motion freeze phase; turns and bank switches preserve it; air/slide/roll and prediction corrections must not produce footsteps. The producer is absent. In particular, the document alone does not resolve whether its body-height scalar means reference or display height after the proportion amendment. Keep the existing producer when available; do not silently choose a new scalar for Middle/Large. [Sprite pipeline L49–57.]

## 3. Small first: findings that matter

### F01 — Contact alternation exists; stronger evidence of planting does not

**SOURCE_VISIBLE.** Small forward walk `T0/A0`, backward `T4/A0` and lateral sequences contain visibly different leg placements. Each of all 64 pairs has eight distinct decoded cells in both banks. The walk and sprint pages are distinct; sprint is not just fast playback of walk. This is a foundation to refine, not a missing feature to build from scratch.

**INFERRED.** At native resolution, tightly overlapping feet and dark boot/clothing values can make support identity harder to read than it is at 4×. A lowest opaque pixel is not necessarily a planted sole: it may be a passing toe, clothing or another extremity. The static strip cannot reveal whether the supporting foot slides across the actual floor while the actor moves.

**PROPOSED.** Preserve the eight phases and existing gait clock. Clarify a flat supporting-sole cluster and a separated passing toe. Use anatomical left/right identifiers in authoring and debug output, not permanent colored boots. The proposed contact labels are L support for phases 0–3 and R support for 4–7; reconcile this phase-zero convention with the missing rig rather than renumbering an accepted gait blindly. Do not alter travel speed, stance length or cadence caps to make a demonstration look planted.

**Important limit:** held eight-frame raster animation cannot keep a foot pixel continuously world-locked while the actor translates. Even a perfect keyframe trajectory moves with the root between frame changes. Under the documented Small example, a cycle is 75.4 px and the distance per phase is 9.425 px. A proposed ≤1 px residual is a **sampled keyframe rig target**, not a promise of sub-frame foot lock. At a cadence cap, faster real travel can create additional slip. Measure both; do not hide slip by moving the authoritative actor, redefining the pivot or introducing an unreviewed live IK system. [Presenter L104–132; sprite pipeline L49–70; `evidence/static-source-audit.json`.]

### F02 — True diagonal slide art and true diagonal travel are different questions

**SOURCE_VISIBLE.** Small has distinct diagonal slide drawings. However, `frame("slide", aim, travel, phase)` selects its base region from aim; travel and phase do not select a different slide cell. With aim South and travel NE it still returns the South slide pose. This can be shown exactly without a runnable game.

**DOCUMENTED_NOT_TRACEABLE.** The checkpoint explicitly records an aim-only slide bank, no entry/exit phase bank, and wallrun inheriting the same slide body. It also flags North/NE head/torso overlap. A historical paid-slide review accepted a bounded source candidate for further human review, not the whole animation milestone.

**PROPOSED.** Keep the seated long-leg/tucked-leg improvement, but author travel-dependent ground contact and recline while head, chest and pelvis remain coherently aimed. NE travel must read through the body/contact axis without skid particles or a 2D rotation of a cardinal bitmap. **Sliding soles are gliding contacts, not walking plants.** Entry, held slide, brake and exit need distinct action meaning. The pilot specification assigns eight bounded action slots while keeping the existing eight direction indices; it is not a new gait clock or a live schema patch. Protection remains a separately owned authoritative cue, never the duration of the seated silhouette. [Presenter L97–132; proportion checkpoint L12–27, L69–75; specification L659–673.]

### F03 — Backpedal must remain travel-aware without twisting the waist

**SOURCE_VISIBLE.** `relative_gait()` classifies offset 3/4/5 as backward. `T4/A0` exists as an independent eight-phase sequence and is not a byte-identical forward loop. Do not solve backpedal by flipping a South body, turning its chest North or simply reversing forward-frame order.

**PROPOSED.** The face and ready hands continue to communicate South aim; posterior placement and unloading communicate North travel. Keep a stable head/chest/pelvis yaw relationship and low, readable passing feet. Begin with contact clarity rather than shortening the stride: a shorter drawn step against an unchanged distance clock can increase apparent skating. Test back-diagonal neighbors and reversals through zero actual velocity, not only steady-state movement. [Resolver L71–88; specification L649–675; sprite pipeline L63–70.]

### F04 — A moving-cast action layer is a documented gap, not code shown here

**SOURCE_VISIBLE.** The presenter exposes a static `cast` row but does not combine it with a gait region in `frame()`. A direct cast call returns the cast base pose even with nonzero travel. A moving walk call returns a gait pose. It would be false to claim this function already blends cast arms and gait legs.

**DOCUMENTED_NOT_TRACEABLE.** The checkpoint says moving casts retain gait legs without a new casting-arm layer. The missing higher-level caller presumably chooses the lower-body presentation; the exact routing cannot be reconstructed safely from the checkpoint alone.

**PROPOSED.** Preserve the existing gait phase while admitted upper-body action communicates hand preparation, release and recovery. For the pilot use travel North/aim East, a lateral relationship whose hand extension is easier to inspect. Action timing must follow the actual cast’s progress/release event, **not** phase 3 of every walk cycle. Current body aim still turns immediately; an already committed projectile retains its recorded start aim. Refused casts get no release pose. No spell glow, magic impact or aura is baked into the body. No universal cast duration is invented: the JSON intentionally leaves unavailable family-specific ticks null. [Presenter L111–132; proportion checkpoint L73–75; specification L649–656.]

### F05 — Landing needs a load pose, not a recycled walk contact

**SOURCE_VISIBLE.** There is no landing/compression row in the active manifest. Small South jump occupies 46 px of height while grounded occupies 58 px; both end at the same registered source baseline. These are source pose bounds, **not physical height or inferred ground contact**.

**DOCUMENTED_NOT_TRACEABLE.** Jump/Float/air-dodge/walljump share a jump-body selection in the checkpoint. The control document describes canonical landing intensity, a land strip, shadow squash and an external rune cue. Those are not evidence that a dedicated landing body pose exists. The queue explicitly records rejection of a walk-frame landing shortcut.

**PROPOSED.** On confirmed ground contact, give a dedicated two-foot load pose; compress by knee flexion with fixed bones and a rigid torso, then recover. Start with a maximum 3 px Small pelvis drop and a 14-tick (116.7 ms) **cosmetic** post-contact envelope, immediately interruptible. This adds no recovery lock, protection, jump restriction, momentum change or cast delay. For a moving landing, do not drag a frozen two-foot pose with the root: transition to the first appropriate moving support immediately. A small lift in reduced effects must not be mistaken for grounding. Never infer touchdown solely from shadow size or elapsed animation time. [Presenter L15–19; proportion checkpoint L69–75; control document L218–222, L295–318; queue L142, L162–163.]

## 4. Dimensions: what the pixels establish, and what they do not

Every source texture matched **both** its PNG hash and its decoded RGBA hash. Every cell was nonempty, binary-alpha and clear of the outermost cell edge. The nine decoded textures total **122,093,568 bytes / 116.4375 MiB**. These are offline measurements, not Godot import checks or GPU residency measurements.

Measured South base bounds, height only:

| Body | Standing | Jump | Cast | Walk | Sprint | Slide | Roll |
|---|---:|---:|---:|---:|---:|---:|---:|
| Small | 58 | 46 | 58 | 59 | 55 | 43 | 29 |
| Middle | 63 | 50 | 63 | 64 | 60 | 46 | 32 |
| Large | 68 | 55 | 68 | 69 | 64 | 50 | 34 |

A walk reaching one pixel above the standing rectangle is not automatically a scaling bug; an upright-to-seated height reduction is not automatically body shrinkage. **Never normalize these actions back to standing height.** All South examples have an exclusive maximum Y of 84, leaving rows 84–95 transparent; pivot Y=84 is the baseline edge, not a requirement to paint a sole at row 84. The annotated registration board shows this convention.

The presenter enforces reference heights 58/68/76, display heights 58/63/68 and pre-baked scales 1, 63/68 and 68/76. It does not apply a new pose-fitting transform in this function. The source says the rig has fixed bones, but raster bounds and matching hashes **cannot independently prove joint lengths**. That proof requires the absent rig/pose data. [Presenter L5–19, L65–79, L135–161; specification L659–676.]

## 5. Transfer to Middle and Large

Do not enlarge the Small PNG. Reuse the established rig’s normalized contact rules, phase labels, aim/travel relationships and action-event timing on each size’s original proportions, then bake **once** about `(48,84)`. Existing display ratios are 63/58 and 68/58 relative to Small; source-to-display scales are separately 63/68 and 68/76. They are not interchangeable.

The proposed passing-foot separation and maximum landing compression round to 3/3/4 display pixels for Small/Middle/Large. These are pilot readability targets, not anatomical source lengths or new gameplay values. If the original rig cannot reach them without changing rest lengths, revise the pose target, not the bones. Keep the same event timings across sizes; heavier-looking Large movement does not authorize slower input response or extra invulnerability.

Middle and Large need their own native raster check: shoulder/hand occlusion, one-pixel sole gaps and the North/NE slide overlap can change after the per-size bake. Their hurt radii remain 18/19 px while **both still use 18 px common wall clearance**. Wider apparent shoulders or a seated body do not change those rules. Health, Flux, speed, recovery and stamina remain frozen; stamina maxima remain 620/660/700. [Shared contract, Preserve; presenter L9–12, L65–72; specification L666–676.]

## 6. Pilot artifacts and their limits

`images/P01…P05-annotated.png` contain exact Small source crops at **1×**, selected crops at **3×**, and a separate proposed contact/action timeline. Original body pixels are not repainted. Aim/travel arrows, pivot marks and L/R symbols are review annotations, not live effects or body textures. The light/dark backgrounds are neutral test swatches, not map captures. Separate source PNG originals and crop manifests make the views reproducible.

The five GIFs are **offline lookup/storyboard flipbooks**, 800 ms per eight samples for inspection. Walk/backpedal use real phase order; slide deliberately repeats the one selected source cell; moving cast shows the gait-only probe with the missing arm phase called out; landing deliberately cuts between jump and grounded to reveal the missing intermediate body. They do not simulate authoritative movement or prove runtime transition selection. The direction/phase glyphs are proposals and must not be mistaken for measurements of the source rig.

`REVIEW.html` is a self-contained, offline atlas explorer. It includes all nine original images, the five pilot selections, explicit source-versus-storyboard labels, all travel/aim combinations, walk/sprint comparison, pause/scrub, native integer zoom, light/dark swatches and optional guides. Reduced mode intentionally does not alter the body pixels: its accompanying note explains the missing sampler and the separately owned normal/reduced lift. Native means one atlas pixel per CSS pixel at 1×; browser/OS scaling and camera zoom still require an actual game capture.

## 7. Integration and rejection criteria

First repair **one Small contact-readability defect** in the original rig and rebake only the affected existing cells. Second validate a Small NE-travel/South-aim slide plus brake/exit. Third author a dedicated planted landing pose and test interruption. Fourth prove moving-cast phase separation. Transfer each accepted rule to Middle/Large only after Small passes. Do not turn these parallel proposals into multiple active integration queues.

Reject any candidate that changes physics/configuration, flips aim to travel, restarts feet on a cast, delays the actual release event, extends protection by pose duration, changes fixed rig lengths or double-scales a body. Also reject a change that looks clearer only with debug arrows, only in slow motion, or only at 3×. Keep before/after native captures with normal and reduced effects, on light and dark floors, including wall approach and overlapping projectiles.

The current loader validates layout, motion revision, dimensions, PNG hashes and imported RGBA hashes. A lone replacement PNG is **not** an integrable patch. Additional slide/landing/arm layouts require a coordinated, separately reviewed presenter/manifest/test change. A full 64×8 action bank across three sizes adds **54 MiB** of raw RGBA; three cast stages multiplied across all gait combinations add **162 MiB**. A hypothetical 8-aim × 3-stage masked arm set across sizes is 2.53125 MiB before other costs, but correct occlusion and draw integration are not implemented or approved here. Prefer bounded pilots and measured costs over filling enormous pages. [Presenter L45–79, L135–161; sprite pipeline L21–47.]

**Human acceptance remains pending.** Structure, hashes and offline viewer tests do not prove planted movement, responsive casting, convincing landing, network correctness or sustained rendered performance. The existing runnable project and integrator’s scheduled captures are the next required evidence, not a whole-roster batch.
