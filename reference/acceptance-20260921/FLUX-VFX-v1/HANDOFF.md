# FLUX-VFX-v1

**Status: PROPOSAL + OFFLINE_PREVIEW. Not a validated drop-in.**

Open `preview-standalone.html` for the self-contained material workshop, or `index.html` with the extracted folder intact. No server, network connection, CDN, web font or game installation is required by the preview. Document links expect the extracted ZIP beside the HTML. This sandbox blocked direct file-URL navigation; Chromium rendering was tested by feeding the self-contained HTML as page content. That restriction is recorded, not reported as a successful file launch.

## What is delivered

| Output | Contents |
|---|---|
| `PALETTE-AND-MOTION.md`, `definitions/palette.json` | Eight elements in the requested order, exact contract colors, silhouettes, motion, phases and optional audio briefs. Air keeps internal `wind`. Steam is a reaction, never a ninth base element. |
| `assets/motifs/` | Six original RGBA8 atlases: Water, Fire and Steam, each normal/reduced. 176 frame cells in total. |
| `definitions/materials.proposed.json`, `definitions/atlas-layout.json` | Palette phases, lifecycle bindings, atlas dimensions, pivots, alpha, sampling, bounded motifs, coverage and integration constraints. |
| `boards/paintover-*-1280x720.png` | Native-resolution paintovers over an actual saved game capture. Proposed effects and labels are offline additions. |
| `boards/normal-*.png`, `boards/reduced-*.png` | Light/dark-floor comparisons at 50%, 75% and 100% fixture camera. Actual supplied body-sheet pixels remain separate from effects. |
| `boards/lifecycle-*.png`, `boards/pilot-lifecycle-*.apng` | Formation, active and harmless expiry; two animated 6.4-second, 15-fps sampled reference sequences. |
| `boards/steam-*.png`, `boards/coverage-and-scald.png` | Hot/cool modifiers, different-owner seams, mixed materials and explicit actor-exposure examples. |
| `boards/stress-fixture.png`, `boards/projectile-strength.png` | A labeled synthetic density fixture and the existing strength-to-visual-size rule. Neither is a physics/performance acceptance. |
| `preview/`, `tools/`, `tests/`, `evidence/` | All preview source/dependencies, reproducible asset tools, checks, receipts, input provenance and a quarantined rejected image-generator exploration. |

## Chosen direction

The academy is the quiet foundation: weathered warm stone, timber in joints and fixtures, restrained brass highlights, cardinal floors and upper-left lighting. This pilot changes no map layout or architecture. Low-contrast stone swatches are test backgrounds, not replacement map assets. The actual Wellspring screenshot supplies the contextual environment.

Magic uses dense, deliberate two-world-pixel clusters rather than more particles. **Water has hooked rolling crests; Fire has unequal upward forks; Steam has paired open kettle-like curls with sparse copper scald marks.** The complete selected polygon is the material surface. A motif is an identifier inside that surface, not a hit mask.

Existing ingredients remain distinct from reactions. Water is not Flood: it has no forcing chevrons and gains no damage, slow or push. Fire is not Conflagration: it has no mirror-product crown. Steam uses its explicit phase palette and open-curl silhouette, not a Fire/Water color average. The later reactions, reserve elements and playable roster are untouched.

## Source access and authority

Input packet: `flux-delegation-20260920`. Reported runtime identity: `p53-cb264f9358a4`. The packet reports `main` at `a1aa02807626823d0fbc1e25e75441ca3b7f4d36` with 1,118 dirty entries. None of that is a fresh live-checkout observation or recomputed runtime identity.

The archive contains 64 files; its 63 manifest records were checked against exact bytes and SHA-256. Required instructions, material contract, presenter, recipe policy, hex geometry and relevant lifecycle/exposure code were inspected. All four supplied 1280×720 gameplay captures were opened. The nine active body textures are accessible; the three copied base sheets were decoded and tested, and their grounded facing references were inspected. The complete locomotion matrix was not visually accepted. Concept images were used only for material/proportion mood.

The packet is **not a buildable repository**. The live checkout, complete renderer caller/layer order, `VisualLanguage` implementation, the actual projectile atlas, nested chemistry snapshot dependencies and saved camera/profile settings are absent. See `evidence/INPUT-ACCESS.md` and `evidence/source-excerpts.md` for scope and exact source spans. This work changed no supplied source file and no live repository file.

## Four integration decisions that must survive handoff

**1. Whole-cell coverage is immutable presentation input.** Use `render_regions` → `_prepare_region` → the six received vertices. Never recreate a disk/sector clip or shrink the ground footprint with animation/strength. Preserve present cells even when a per-cell integer allocation is zero. Draw material seams inward and join only edges equivalent under the existing legacy tuple, including owner, footprint, phase, danger, intensity and expiry. Different lifetimes/owners must not become one anonymous puddle.

**2. Water is non-damaging in the supplied ingredient implementation.** The “active” Water row means a live reagent, not active damage. Fire and Steam use authoritative `danger`, not a visual timer. At harmless decay, hot perimeter accents, upward flames and active scald marks end immediately. Remaining residue is flat and subdued. All drawing stops at actual expiry, even halfway through a visual frame.

**3. Steam heat is not accumulated scald.** `region.intensity` supplies the region's hot/normal/cool palette. The current cell-wide `steam_heat` starts at 1000 and is max-reduced, so it can hide cooled intensity and collapse overlapping heat states. Moving palette selection to the already-prepared region value is a presentation-only proposal; it has not been run in Godot. Cooled Steam can still be dangerous.

The optional three-tick actor cue reads explicitly supplied **actor exposure**, not cloud age. Its 1–80 / 81–160 / 161–240 visual tiers are a display quantization, not new damage thresholds. Until the local lead proves read-only exposure and current eligibility/contact bindings, omit the actor ticks; keep Steam's material danger cues. No new network field is authorized here. The viewer supplies synthetic actor values and does not calculate damage/contact/protection.

**4. Preserve the existing projectile strength rule.** The core's authored size follows `max(min(5, authored_size), authored_size * sqrt(remaining / initial))`, with zero remaining drawing nothing. Do not alter radius, hit geometry, budgets or the existing six-tick shrink cache. Rapid still has no persistent trail. The viewer uses the presenter's source fallback silhouettes because the live atlas is missing; its Spray sample is not a proposal to make instantaneous Spray travel as a projectile.

## Timing and scale

At the supplied 120 Hz reference, unmodified terminal Water has 24 forming + 636 active-reagent + 60 decay ticks; terminal Fire has 24 ignition + 396 active-danger + 60 cooling; unmodified Steam has 24 forming + 360 active-danger + 60 decay. These are **reference examples**, not new game timers. Ground trails and modified products can differ. Steam heating can shorten expiry; read the actual region/product state and never extend a life to complete animation.

The motion atlases use presentation-only active loops of 96 ticks (Water), 64 (Fire) and 120 (Steam). Damage/audio pulses must follow actual delivered events, not a repeated animation frame. Reduced mode holds the active pose while retaining all lifecycle/danger changes.

Hex geometry is 64 × 73.9 world pixels with a 55.425-pixel row pitch. Atlas cells are 64 × 80 with center pivot `[32,40]`; motifs use 2-pixel clusters. The source character cells/pivot remain 96 × 96 / `[48,84]`, with already-baked display references 58/63/68. Do not apply the older 58/68/76 art heights or bake the scale twice.

The actual screenshot paintovers retain the 1280×720 raster and fit proposed cells at 0.75×, inferred from approximately 48-pixel-wide captured hexes. The saved camera transform is absent; this is a documented geometric fit, not verification of a Godot camera setting. The standalone benches explicitly define 50/75/100% fixture transforms. They do not claim the complete game's viewport/upscale pipeline was reproduced.

## Verification and acceptance

The executed receipts show **18 Python asset/data tests and 26 Node geometry/semantic tests passing**. Chromium rendered **432 state combinations** (3 fixture cameras × 3 phases × 3 heat values × 8 grounded facings × 2 effects modes), each with all three materials and both floors, without JavaScript errors or remote requests. Controls, tabs and pause were exercised. This is automated component rendering, not 432 human readability acceptances.

The visual checks cover alpha/cluster layout, inside-hex motif pixels, empty final expiry frames, static reduced poses, source palette equality, copied input integrity, unchanged source bodies and exact source-pixel restoration. Geometry tests cover selected corners, holes, owner/phase/danger/intensity/expiry/footprint seams, zero-allocation presence, reference phase boundaries and strength-size math. See `evidence/verification.json` for current statuses.

**NOT_RUN:** Godot import/integration, Full suite, actual game capture, synchronized normal/reduced gameplay, hot/cool behavior in-engine, render timing/GPU memory, network/rejoin, human readability/quality acceptance and checkpoint promotion. No historic Full green or headless timing result is reused as this pilot's success.

One image-generator board failed the contract (wrong element taxonomy, isometric treatment and opaque cloud language). It is quarantined as `evidence/rejected_generation/REJECTED-imagegen-board.png`, not a palette/geometry/art authority and not an integration candidate. The shipped pixel atlases and comparison boards were authored independently from the supplied contract.

## Next local action

The integration lead should inspect the current live files, compare the supplied hashes, choose a bounded presentation-only slice, and follow `integration/INTEGRATION.md` plus `integration/CAPTURE-CHECKLIST.md`. Stage new assets before altering the live renderer. Preserve dirty work. Do not overwrite catalogs, change protocol/simulation, publish, push, run competing Godot processes or promote a checkpoint from this handoff alone.
