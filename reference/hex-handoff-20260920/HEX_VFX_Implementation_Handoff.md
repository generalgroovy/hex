# H.E.X. VFX — Steam pilot

**Contribution:** one presentation-only Steam pilot, supported by a first-four element/reaction visual specification. **Status:** original technical candidates and an offline authoring preview; not a FLUX source patch, approved art match, Godot build or game-ready asset pack.

Open `index.html` for the self-contained preview. It embeds its three PNG layers and makes no web requests. During the original work, direct `file://` launch was blocked by the container's Chromium policy. The restored HTML has been tested using Playwright `set_content`. Windows/browser file launch is not verified.

## Repost and restoration

This is a restored handoff, not a byte-for-byte copy of the previous ZIP. The three previously displayed PNGs survived and are preserved unchanged in `qa/original_previews/`. The reference code, final technical-asset builder, HTML preview and specification were restored from the previous work. The rebuilt phase/readability boards in `assets/` correspond to the restored final atlases; they differ from the surviving previously displayed boards. `qa/recovery_check.json` records that comparison rather than claiming identical recovery.

All 20 reference tests, 12 technical-image checks and 13 browser-fixture checks were executed again for this restored contribution. The original two rejected image-generated concept boards were not recoverable as image files and are not included. Their prior rejection remains in force; see `qa/generated_art_review.md`.

## Source basis and evidence

The only design input received was **Pasted text.txt**, 11,045 bytes, SHA-256 `b21ae27b4c84672a4afe6c986fc9c74779417f796c8b488729fb3b9506881334`. It is the independent-specialist assignment, with `<VFX>` selected. **No repository commit, checkpoint/build identifier, current queue, separate design contract, production capture, approved reference image or source module was supplied.** The restored synthetic images are outputs, not implementation evidence or approved references.

| Evidence class | What is actually supported |
|---|---|
| Observed input | The assignment and its written constraints were received. No implementation was inspected. |
| Documented intention | Godot authority, Windows release target, 120 Hz target, eight-player target, continuous motion, whole selected hexes, finite paid strength, chemistry at eligible stations/spawns with existing protection, existing delivery/loadout identities. |
| Documented VFX requirement | Four base elements; ten reactions; one Steam pilot covering formation, active exposure, warning/expiry and disappearance; Steam is scalding exposure, not concealment. |
| Proposed design | All palettes, shapes, art, frame geometry, visual timing, render adapter and acceptance gates in this contribution. |
| Hypothesis | Short warm vents, rising open billows and a stable field footprint will read as hot exposure better than a large white cloud. Recognition has not been measured. |
| Executed | Reference-only Python tests, PNG/manifest checks and browser-fixture smoke tests. See `qa/`. |
| Not executed | FLUX code, Godot/Windows import, real geometry/tiling, approved-reference comparison, multiplayer, replay, performance, accessibility or gameplay acceptance. |

**Required source request before integration:** supply the current design contract, active queue and checkpoint/build note; unscaled in-game captures showing Steam and overlapping actors on dark and pale terrain; approved VFX references; and the current Steam/reaction presentation, hex polygon/projection, exposure and spawn-protection source or relevant excerpts. Do not invent names for those production files or adapter fields.

## One recommended solution

Use a **two-layer pixel atlas plus an exact whole-cell union footprint**. A stable ground fill and exposed-edge contour convey occupancy; small hot vents and open rising billows convey Steam. Put both art layers below bodies. No screen-space fog, blur or full-field opacity canopy is needed.

This is one renderer contribution, not a new chemistry system. It consumes a read-only view of resolved Steam occupancy. It does not pick cells from a radius, resolve strength, infer damage, change collisions, create a second gameplay clock or change replicated state. The integration task must map the proposed adapter to the actual code first.

**Principal tradeoff:** reusable cell stamps and a deliberately restrained footprint are less organic than a continuous fluid volume and can repeat visibly.

**Strongest counterargument:** open wisps may resemble benign aroma, healing vapor or Mistcurrent instead of a scalding field. Keep a persistent hot-vent shape and dark/light boundary; use real exposure feedback when available. The pilot must pass a recognition test before being extended to other reactions. More fog is not the fallback.

## Palette and visual grammar — proposals

Shared contour `#252B36`, shared warm highlight `#F4ECD8`. Use deliberate low-resolution clusters, selective outlines and upper-left material highlights. Avoid soft gradients, outline-every-pixel noise and mandatory bloom. The palette's shadows and highlights are not gameplay states.

| Element | Dark → light palette | Shape language | Animation behavior |
|---|---|---|---|
| Water | `#244F72`, `#337FA5`, `#79BDC9`, `#D2E7DB` | Flattened lobes, short crescent rims, joined puddle edges, falling droplets. | Low lateral flow, weighty droplets, ripple expansion and collapse; no flame-shaped upward tail. |
| Earth | `#514335`, `#806648`, `#B49561`, `#DBC38C` | Broad stepped facets, squat angular masses, chipped corners. | Short lift or impact, heavy settle, then near-stillness; no weightless looping debris. |
| Fire | `#8F342B`, `#D4552D`, `#EF9743`, `#F5D284` | Tapered hooks, broken crowns, narrow tips above a broad hot base. | Fast irregular rise, alternating tongue lengths and detached short-lived embers; no smooth looping blob. |
| Air | `#485F76`, `#819FAE`, `#BBCCD0`, `#E8EBDE` | Open ribbons, spaced parallel strokes, large negative spaces. | Directional sweep followed by a clean reset; no filled white cloud or water drops. |

“Air” is display terminology only. Do not rename existing internal `wind` identifiers. Delivery silhouettes for Bolt, Heavy, Rapid and Spray, twelve-slot configuration and character bodies are not changed.

## Ten reaction signatures — proposals

The assignment supplies the ten pairs and ten retained identities. The mapping below follows their listed order; the actual reaction table is still required to verify implementation naming. These are **visual identities**, not claims about currently implemented forces, movement, collision or balance.

| Pair | Identity | Primary signature | Motion and non-hue discriminator |
|---|---|---|---|
| Water / Water | Flood | Broad joined water shelf with double shallow wave crests. | Low traveling ripple bands; no tall plume or hot vent. |
| Water / Earth | Mud | Squat uneven puddles with chunky dull clods and thick interrupted rims. | A clod bulges, slumps and settles; deliberately sticky-looking, not sparkling. |
| Water / Fire | Steam | Twin hot-vent strokes beneath open cream-gray billows. | Short vertical lift, split curl and dissolution; persistent hot footprint, never a concealment cloud. |
| Water / Air | Mistcurrent | Long shallow combed fans of cool fine droplets. | Coherent lateral streaks, without Steam's upright hot vents. Direction follows supplied state only where meaningful. |
| Earth / Earth | Rampart | Interlocking stepped stone teeth with broad flat tops. | Heavy short rise/settle and stable mass; do not imply new blocking geometry absent in source. |
| Earth / Fire | Magma | Dark crust islands divided by thick bright fissures. | Slow brightening under crust and occasional blister collapse, not a carpet of flame tips. |
| Earth / Air | Dustfront | Low serrated sweep with large leading grit and trailing fine grains. | Chopped horizontal progression; no circular vortex or Steam billow. |
| Fire / Fire | Conflagration | Broad rooted fire crown with multiple uneven upright tips. | Rapid upward flicker across a stable base; not orbiting. |
| Fire / Air | Firestorm | Canted hooked flame tongues arranged along a broken spiral. | Flames orbit the supplied footprint, not an invented translating hazard. |
| Air / Air | Vortex | Paired open pressure arcs around a clearly outlined footprint. | Coherent rotation, no fire tips, water drops or dirt grains. Negative space in the art never creates an unselected/safe center. |

All reaction floor coverage remains distinct from decoration: open ribbons, crust gaps or a curl's hollow center do not subtract gameplay coverage from an affected hex. Distinguish each reaction through silhouette and rhythm before relying on hue. Only Steam is implemented in the technical candidate assets.

## Steam pilot

### Anatomy and layers

1. **Whole-cell ground field:** a faint continuous value shift over the exact union of active cells. Use the game's polygons, not this preview's illustrative dimensions. It stays visible through formation, activity and warning.
2. **Boundary:** shared ink plus a light inner edge on exposed union edges, including hole boundaries. Suppress internal edges. One union opacity, not additive tint for each overlapping source.
3. **Ground details:** small paired rising heat strokes and boiling contact marks. A tiny warm accent is secondary; removing hue must not remove Steam's identity.
4. **Vapor:** three short open billows in each technical stamp. They rise rather than drift sideways. Vary visual phase without touching simulation RNG.
5. **Bodies and existing character effects:** draw after the Steam layers. Do not cut holes in the gameplay/ground mask around characters. Existing actor outlines may remain; this pack does not modify templates.
6. **Actual exposure feedback:** use existing authoritative exposure/protection data only. No timer, severity level or damage number may be inferred from fog opacity or time visually spent under particles. This preview intentionally has no fabricated exposure HUD.

Ground coverage is exact; an elevated wisp is decorative volume anchored inside a covered cell, not additional eligible ground. Review spill at the real camera angle. Do not let lateral plume drift imply an affected neighboring cell.

### Complete phase specification

| Phase | Proposed art timing | Required behavior |
|---|---|---|
| Formation | 4 frames at 16 fps, 0.25 s | The whole affected floor is visible as soon as supplied state says active. Tiny boiling marks grow into upright billows. This is not a damage grace period or new activation delay. |
| Active exposure | 8 frames at 8 fps, 1 s loop | Persistent hot-vent identity; open billows rise and split. The loop does not determine hazard duration or strength. |
| Warning / expiry | 4 frames at 8 fps during at most the last known 0.5 s | Billows shorten and a low terminal bracket appears. The field and its contour stay present. Do not advertise safety early or use global flashes. Skip predictive warning when final expiry is unknown. |
| Disappearance | 4 frames at 16 fps, at most 0.25 s | On authoritative removal, the floor, contour and hot marks disappear in the first render update processing that removal. Only detached neutral inert vapor may remain. Final frame is empty. Reduced mode has no after-image. |

These are visual timing proposals, not game balance values. At the documented 120 Hz conversion basis they correspond to 30 formation ticks, a 120-tick active visual loop, at most 60 warning ticks and 30 inert disappearance ticks. The adapter does not advance gameplay.

When active state and an already-past expiry disagree, keep the field visible and diagnose the state inconsistency. Never delete an active cell because a visual timer ran out. A mid-life snapshot goes directly to its correct phase; unknown start time skips formation. New activity at the same location cancels any old inert after-image.

### Neighbor joining and partial expiry

Let `S` be the set of cells which the authoritative chemistry view currently resolves as containing active Steam. Draw its polygon union once. Draw cell side `d` only when that cell's neighbor in direction `d` is absent from `S`. Recompute topology when occupancy changes; phase animation alone need not rebuild the union.

This keeps a six-cell ring's central hole open, supports concave boundaries and avoids hex-shaped cages inside a joined field. Do not replace the union with a convex hull or impact circle. The exact impact position can anchor an optional contact accent if supplied; it is not used by VFX to reselect cells or circularly crop already-selected cells.

Overlapping contributors are resolved before this presentation adapter. One contributor expiring must not clear another contributor's active field. Show an expiry warning only when all surviving contributors have known expiries and the final one is within the warning window. Unknown final expiry means no countdown, not no field. Continued occupancy should not replay formation whenever a contributor is added. A neighboring cell may expire separately; rebuild only the affected topology, retaining the others.

The proposed `CellView` in `reference/steam_reference.py` is an adapter DTO, not an assertion that these fields or APIs already exist in FLUX. No new network protocol or snapshot schema is requested.

### Terrain, bodies and reduced effects

The technical proof sheet includes dark stone, pale sand, moss and grayscale. Its three simple opaque mannequins are **synthetic occlusion proxies**, not supplied small/medium/large templates, because those templates were not received.

The ink/light dual contour and outlined paired-vent glyph retain a luminance-and-shape signal on pale terrain. Full vapor and ground details render before bodies. Reduced mode preserves the same field, exterior contour and one small static hot-vent glyph per cell; it removes animated vapor and inert disappearance. A static terminal bracket signals a known-expiry warning without flashing. Neither mode gives immunity-looking holes to protected/spawned players. Existing protection suppresses or changes exposure feedback only according to its actual state; chemistry remains visible across eligible ground.

These examples demonstrate the proposed layering and shape redundancy. They are not color-vision-deficiency testing, human recognition evidence or an approved art match. Do not advertise accessibility certification.

## Artifacts and verified file geometry

| Artifact | Actual geometry / purpose | Background |
|---|---|---|
| `assets/steam_ground_details_atlas.png` | 512 × 256; 8 columns × 4 rows; 64 × 64 frames; 20 used slots. Ground details only, no baked union boundary. | Straight RGBA, transparent. |
| `assets/steam_vapor_atlas.png` | Same geometry, 20 used slots; includes blank terminal disappearance frame. | Straight RGBA, transparent. |
| `assets/steam_reduced_glyph.png` | 16 × 16; outlined paired-vent identity. | RGBA, transparent. |
| `assets/synthetic_hex_mask.png` | 64 × 64 demonstration mask; projected floor bounds 48 × 28; anchor (32, 46). **Not production collision/selection data.** | RGBA, transparent. |
| `assets/steam_labeled_phase_sheet.png` | 1600 × 1000 labeled inspection board. Labels are not embedded in the raw frames. | Opaque RGB. |
| `assets/steam_readability_proof.png` | 1440 × 830; four terrain/monochrome views × full/reduced mode. | Opaque RGB. |
| `manifest.json`, `palette.json` | Frame rectangles, anchor, timings, assumptions and palette. | Data. |
| `index.html` | One-file, offline animated authoring preview with scrub, pause, terrain, union/hole/partial-expiry and reduced-mode controls. | Synthetic scene. |
| `reference/` | Presentation-only Python reference, tests and reproducible technical-asset/HTML builders. | Not Godot source. |
| `qa/` | Fresh executed check logs, screenshot, image audit, restoration record and NOT_RUN gates. | Evidence. |

The raw atlases contain **12 unused transparent slots each**. Rows: formation 0 (4 frames), active 1 (8), warning 2 (4), disappearance 3 (4). Frame rectangle = `(64*column, 64*row, 64, 64)`. Anchor = `(32, 46)`. The source PNGs contain real alpha rather than a baked checkerboard. Their one-pixel frame borders are transparent, but **there are no extruded atlas gutters**. Verify the real import/sampling pipeline; split into separate textures or add appropriate gutters when necessary. Do not claim nearest sampling alone solves every atlas/import artifact.

### Known defects and uncertainties

The technical art is intentionally limited and can look repetitive or diagrammatic at distance. Its three billows per cell may be too busy in a large field. The native scale, projected hex shape, terrain and body proxies are arbitrary review geometry. The vapor loop has eight different bitmaps but its perceived continuity and material recognition are unvalidated. Pale-ground interior detail still needs real-capture review. Actual sprite anchor, camera zoom, overlapping reactions, alpha import and production cell joins remain unknown.

**Both original image-generated concept boards were rejected** for unsupported reaction catalogues and other contract conflicts. Neither is a production atlas or recommended implementation. The first also incorrectly presented Steam as concealment. Their image files are not included in this restored archive; the prior review is retained in writing, explicitly marked as historical rather than newly inspected.

## Checks actually executed again for this repost

- **20/20 Python reference tests passed**, including all 64 center-cell neighbor masks, one/two/seven-cell and ring topology, duplicate-contributor membership, unchanged input records, unknown expiry, stale-expiry visibility, late-join phase selection, warning coverage, reduced-mode occupancy and inert disappearance.
- **12/12 technical-image checks passed:** dimensions/modes, actual alpha, empty unused slots, transparent frame borders, ground confinement to the synthetic mask, empty disappearance ground, empty final vapor frame and eight distinct active vapor bitmaps.
- **13/13 browser-fixture checks passed** using the exact restored HTML loaded with `set_content`: normal/single/ring/partial-expiry occupancy, warning/removal behavior, reduced mode, achromatic grayscale output, narrow-layout overflow, no JavaScript errors and no remote network requests.

During the original work, direct `file://` browser navigation was blocked by administrator policy. That is not presented as a successful local/Windows launch. The later DOM-based browser checks do not validate Godot or FLUX. The current restoration did not retry the direct-file launch.

To rerun standard-library reference tests:

```sh
cd reference
python -m unittest -v test_steam_reference.py
```

Rebuilding the technical images requires Pillow. Run `python build_assets.py`, then `python build_preview.py` in `reference/`. The browser smoke test uses Playwright and an available Chromium executable; `/usr/bin/chromium` in that test is an environment-specific setting, not a Windows launch instruction. The shipped preview needs no Python to inspect in a browser that permits local HTML.

## Required integration gates — all NOT_RUN

| Gate | Input / action | Acceptance criterion |
|---|---|---|
| Source mapping | Inspect actual reaction, occupancy, exposure/protection, renderer and geometry code. | Adapter names and ownership mapped to a recorded checkpoint; no guessed source patch. |
| Exact coverage | Actual cells: isolated, pair, seven-cell cluster, six-cell ring and concave patch; exercise edge/corner impacts using the existing selector. | Presented floor membership equals supplied occupied-cell set exactly; no circular recrop, filled hole or convex-hull shortcut. |
| Joining | Enumerate 64 neighbor masks in the actual projection and animate at real zoom. | No internal perimeter, cracks, doubled edge opacity or outside-ground detail caused by the renderer. |
| Lifecycle | Short/long fields; known/unknown expiry; stale expiry with active occupancy; removal/re-entry; partial expiry and overlapping contributors. | Floor stays until authoritative removal; last contributor controls final warning; re-entry clears old ghost; no invented activation grace. |
| Character/terrain readability | Use all three real templates, actual terrain, moving characters and mixed projectile overlaps. | Foot placement, body silhouette, facing and incoming projectile path stay readable; effect does not obscure bodies or resemble concealment. |
| Reduced effects | Toggle while stationary and during phase transitions. | Identical ground membership and phase meaning; static Steam/expiry shape remains; no vapor, flashes or ghost. |
| Exposure/protection | Compare actual exposed versus currently protected actors in active Steam. | Feedback matches authoritative accumulated exposure/protection; field itself remains present across eligible spawn/station ground. |
| Human recognition | Proposed small pilot: at least 8 reviewers; random 0.5-second glimpses of Steam/Mistcurrent/Flood/Dustfront and active/clear images on real terrain, including grayscale. | Proposed threshold: ≥90% active-versus-clear and ≥80% reaction identity overall, with every wrong-safe report inspected. Not measured; not a statistical certification. |
| Performance/regression | Existing eight-player accepted workload, same seed/settings, effects full versus reduced, before/after. | No gameplay/replay/network change and no new frame-time regression against the integration task's established budget. No speedup or capacity claim is made here. |

## Integration handoff

**Source basis:** assignment only, SHA-256 above; commit/build/checkpoint unknown.

**Recommended contribution:** one Steam renderer pilot with exact union floor, exposed-edge contour, reusable hot-vent/billow atlas, below-body composition and equally informative reduced mode.

**Artifacts:** restored technical RGBA layers, labeled phase/readability sheets, palette/manifest, standalone preview, read-only reference logic, fresh audit logs and unchanged copies of the three surviving previews. Rejected concept boards are not included and must not be integrated.

**Proposed contract changes:** **none**. Proposed pixel dimensions/timings are presentation candidates, not changes to strength, chemistry, simulation, targeting, loadouts or protection.

**Executed / NOT_RUN:** the 20 reference, 12 technical-image and 13 browser-fixture checks above ran again. Godot/Windows, actual-source integration, production geometry/alpha/tiling, player recognition, accessibility, performance, replay and networking did not.

**Unresolved risks:** missing current source and approved images; wrong production scale/projection; repetitive billows; weak Steam-versus-Mistcurrent recognition; pale-terrain detail; overlapping effects and warning ownership; importer/sampling behavior. Restoration is documented, not claimed to be a byte-identical copy of the old archive.

**Smallest next slice:** record the current checkpoint, map its existing Steam occupancy and actual hex polygons, and integrate **only the single-/joined-cell Steam floor and two atlas layers**, initially below one real character. Reuse the existing state path rather than adding new network fields. Accept only when floor coverage exactly matches active whole cells, shared seams disappear, known-expiry warning never clears early, authoritative removal clears immediately in the consuming render update, and reduced mode preserves the same information. Then run the real three-template/terrain recognition check before extending art to any other reaction.

No repository files were changed, committed, published or packaged as a release. This archive is only the specialist handoff.
