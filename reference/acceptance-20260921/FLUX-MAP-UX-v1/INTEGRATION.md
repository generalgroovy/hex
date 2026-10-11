# Integration notes — reversible and source-gated

## What this package changes, and what it does not

This deliverable writes only its own standalone folder. No live repository was accessed or modified, no branch was switched and nothing was pushed. It supplies a proposed campus JSON, forward/reverse patches, verified coordinate data, actual PNG/SVG design artifacts, offline HTML and explicit acceptance tasks. It does not claim UI, terrain textures, material animation, network service, collision runtime or full game implementation.

The packet reports source identity `p53-cb264f9358a4`; the archive is a selective source/evidence snapshot, not a bootable project. Selected portable/checkpoint information and audit history are not evidence that this candidate is already promoted. Preserve the actual current branch and last known-good build. [S01, S12]

## Safe map candidate workflow

The only concrete proposed live JSON target is `content/maps/sanctum_campus_g2_v1.json`. The forward patch has nine operations: add buildings 117/118; change points and width of one advanced marking; change activity label/purpose and practice-group label/purpose/label anchor. It leaves ordinary routes, connections, targets, spawn, arena, all station fields, reset zones, canvas, chemistry and tuning untouched.

`pilot/patch_contract.json` contains exact expected baseline and candidate SHA-256 values. The patch uses array indices; **never apply it to a newer/different file just because its filename matches**. The included tool refuses a mismatched source, an existing output, a missing output directory or an in-place target. It copies the exact tested candidate bytes to a new file; rollback copies the exact original bytes to a new file. It does not apply a speculative merge.

```sh
# Run from this extracted package. Choose a NEW output outside the live target.
python tools/apply_pilot.py \
  --source evidence/source/repository/content/maps/sanctum_campus_g2_v1.json \
  --output courtyard-review-candidate.json

# Create a separate baseline restoration; never overwrite concurrent edits.
python tools/apply_pilot.py --rollback \
  --source courtyard-review-candidate.json \
  --output courtyard-review-baseline.json
```

Windows can use the same commands on one line. No shell-specific installation or privileged command is required. The new files are experimental outputs, not automatically integrated game files.

In an isolated review branch/worktree, the integrator should first rebase the intent against the current source, run its real content/route/practice validator, then install the candidate under ordinary review. Do not import a rejected v0 file. A clean approved candidate can be reverted by the inverse patch or restoring the byte-exact baseline, but only while it still matches the expected version.

## Topology and networking

The added immutable obstacles change eligible chemistry topology: 1493 → 1474 cells in the offline port. Whole-cell authority continues to use the existing 18 px-expanded building exclusion and source bounds. Do not manufacture a safe band in the remaining walkable ground, change ownership ties or post-clip a selected cell to a circle.

Run current topology/hash generation and content negotiation on all peers. The supplied campus builder hashes canonical map content, so changing obstacles must not preserve an old content identity. Do not manually edit stable recipe/element IDs or claim this patch needs a new packet field. The networking owner must verify current snapshot/static-topology assumptions against the complete checkout. Late join, replay/fixture baselines and stale-client refusal require fresh acceptance evidence. [S03–S05, S12]

## Presentation handoff

| Work | Existing source anchor | Exact boundary |
|---|---|---|
| Campus geometry | Known JSON target; `src/content/sanctum_campus_layout.gd` validator/builder | Reuse the current schema. Keep validator rules; do not weaken them to accept the pilot. |
| Eligible cells | `src/sim/hex/hex_world_definition.gd`, `hex_grid.gd`, `hex_footprint.gd` | Read-only integration constraints. Regenerate using current authority; do not replace geometry with SVG coordinates. |
| Body scale | `wireframe_body_presenter.gd`, active body manifest and profile | Source frames are already baked; maintain display sizes, pivot and stats. No body edits in this task. |
| Campus floor/fountain/station art | Full campus rendering/presentation entry point is missing from the packet | Integrator must locate the actual owner. Do not treat `hex_court_presenter.gd` as proof that it owns the campus station UI. No guessed production filename is supplied. |
| Reference / Company UI | Existing F4 entry described by README; handlers and action resolver missing | Add only through the actual UI/input/session owners. No bypass of authority, proximity, paid-action latch, controller focus or acknowledgement. |
| Chemistry display | Effective policy/adapters and current visual contract | Bind names, values, phase and coverage to runtime data. The fixture's manual Magma allocation is not an authoritative solver. |

Map art should use quiet warm stone/slate, timber/brass and restrained peripheral greenery. `05-reusable-kit.svg` communicates six reusable shapes/materials; it is not a shipping texture atlas. The proposed fountain is flush and non-solid: recognizable light/rill/brass detail, not an invisible walk-through basin. Its water animation is decorative, not a source of ingredients. Test whether players understand the distinction; a real basin is a separate collision/topology experiment.

Normal/reduced effects must share selection, danger state, actor visibility and expiry. Internal accents can reduce; boundaries and phase cannot disappear. Draw footprint material below actors, body/feet/aim above it, then only sparse high accents that cannot occlude those cues. Use bounded atlas motifs or existing batched rendering—not a new scene/node per affected cell. Existing whole-cell coverage is authoritative even when quantities allocated to some selected cells are zero. [S01, S05–S07, S09]

## Cost discipline

Proposed pilot envelope: two extra static obstacles, zero added NPC/AI agents, zero autonomous chemistry emitters, one bounded fountain motif and six reusable terrain/presentation piece types. Prefer replacing repeated prop meshes/sprites, not adding duplicates. Do not implement one running script per tile, per sign or per decoration. The full 3-district campus remains available; inactive rendering/culling behavior is not presumed to be solved.

Existing runtime constants (4096 topology cells, 64 cast records, 32 products and finite paid material limits in the supplied authority) are constraints, not permission to fill them constantly. Catalog-wide older bounds do not override the supplied active authority. Adding two obstacles removes 19 eligible cells but is **not** evidence of cheaper simulation or serialization. Benchmark matched demand, record rejected as well as admitted casts and retain the performance red flags from ACCEPTANCE.md. No increase in damage, area, lifetime, intensity or particle allowance is part of this package. [S01, S07, S12]

## Missing inputs / approval gates

The complete live checkout/build, bootstrap, actual `CollisionWorld`, `MovementSystem`/tuning, input and combat-tuning dependencies, `HexStructures`, active station/session/roster handlers, UI focus/navigation implementation and full campus renderer are absent. Current saved profile, selected loadout, camera transform of historical captures and target-device/hardware data are not supplied. No unseen first-four chemistry review, newer VFX/animation result or newly recorded multiplayer session has been assumed.

Additional review is required for global remote management semantics, reset isolation, malicious spawn/station pressure and any proposed sanctuary. Future module world placement, collision, elevation travel, streaming/culling and budget ownership are unknown. A district's `elevation` integer is not proof of traversable 3D terraces. An authored fast-travel landmark marker is not proof of a working teleport service. [S02–S03]

## Preview and reproduction

Unzip the whole folder, then open `preview/index.html` in a browser. It uses no CDN, web font, external library, game server or fetch API; all UI data is inline and all images are relative local files. Browser/administrator policies may restrict local-file access. A loopback-only alternative on a normal machine is:

```sh
python -m http.server 8765 --bind 127.0.0.1
# Open http://127.0.0.1:8765/preview/index.html in your browser.
# Stop the server with Ctrl+C. Do not bind it publicly.
```

This environment blocked file/loopback navigation, so actual URL launch is labeled unexecuted; the HTML's behavior was tested with in-memory content and embedded local PNGs. Relative resource paths are checked by the package validator. Preview buttons are mocks: no game connection, reset, spending or dismissal occurs.

Offline numeric checks require Python only. Optional visual regeneration uses Pillow, CairoSVG and a locally installed DejaVu Sans (or adapt to a locally available font); no font files are distributed. `tools/render_visuals.py` can use the included source evidence root for the three baked body sheets. `tools/build_data.py` expects an extracted original packet plus the original zip beside it to recompute input integrity; it is an authoring/rebuild tool, not part of integration. Changing generated outputs invalidates manifest hashes and requires a new manifest/review.
