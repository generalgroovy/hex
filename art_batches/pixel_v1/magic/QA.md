# Candidate QA and coverage

**Status: exported candidate pack; production integration and user acceptance are open.**

## Executed checks

`python source/validate_pack.py`: **20,484 assertions, zero failures**, zero cyclic loop-seam outliers. Validation covers all 474 sequences / 1,960 frames and reconstructs every export from its editable pixel source. It checks source/atlas hashes, dimensions, binary alpha, hidden RGB, exact palette membership, stable pivots, padding, connector seams, lifecycle interruption and geometry reference cases.

405 sequences have pixel changes across their frames; 69 are deliberately constant or reused poses (including essential information). These counts describe reusable sequences and variants, not 474 unrelated drawings. Reactions assemble phase-specific material cells and masks; they are not 36 fixed full-effect sprite sheets.

The loop metric flags a last-to-first pixel change greater than 1.5 times the maximum internal frame transition. Four initial outliers (slide-trail and water-beam variants) were corrected and the validator rerun. This numeric check does not certify subjective motion quality.

All inspected authority files still match their captured SHA-256 hashes. No production source changed. The full repository/Godot gate was not run for this independent asset batch: it would not validate an unintegrated candidate, and the latest brief restricts writes to this folder.

## Visual inspection and limits

Visually inspected the exported atlas and representative Fire/Water/Steam key poses plus reaction geometry sheets, including ring safe centres, cover planes, steam, linked paths and optical facets. Narrow cover stamps and long-path framing were corrected after inspection. All nine PNG review sheets and four animated GIFs are reproducible. GIFs contain 72 samples at 50 ms per sample (3.6 seconds); they are candidate motion fixtures, not real game footage.

The interactive HTML includes both ground swatches; 50/75/100% nearest camera scale; normal/reduced; grayscale and an approximate deuteranopia filter; 36 selectable reactions; connected/unconnected paths; movement; individual frames; and dense overlap. Browser UI verification was attempted, but the browser security policy blocked the local file URL. No alternate browser or URL workaround was used. Browser interaction and actual in-game playback therefore remain unverified.

No actual FPS, draw-time, GPU or multiplayer acceptance is claimed. Decoded atlas memory is exactly 12 MiB (three 1024x1024 RGBA pages). Suggested composition budgets are unprofiled. Actual camera shimmer, scale readability during combat, opacity against the real map, visibility clipping, hand anchoring, all body-size interactions and immediate protection transitions must be checked by the integrator.

## Element × effect coverage

Each **C** is an authored/exported normal + reduced candidate, not runtime or user acceptance. Deposit coverage includes formation, active and decay; Beam includes body, start and end caps.

| Element | Prepare | Release | Flight + tail | Impact | Deposit | Beam | Spray | Burst | Field |
|---|---|---|---|---|---|---|---|---|---|
| earth | C | C | C | C | C | C | C | C | C |
| fire | C | C | C | C | C | C | C | C | C |
| water | C | C | C | C | C | C | C | C | C |
| wind | C | C | C | C | C | C | C | C | C |
| ice | C | C | C | C | C | C | C | C | C |
| charge | C | C | C | C | C | C | C | C | C |
| light | C | C | C | C | C | C | C | C | C |
| dark | C | C | C | C | C | C | C | C | C |

## Reaction coverage

All rows provide formation/active/decay × normal/reduced candidate material sequences, a source-shape composition binding and separate essential boundary components. Live code wins over expansive legacy catalog descriptions.

| Wire | Reaction | Actual shape | Formation / active / decay (ms) | Completion |
|---:|---|---|---|---|
| 301 | fortify | cover | 180 / 2500 / 400 | Composable candidate |
| 302 | magma | front | 350 / 2200 / 500 | Composable candidate |
| 303 | mud | disk | 200 / 2600 / 350 | Composable candidate |
| 304 | dustfront | corridor | 250 / 1800 / 350 | Composable candidate |
| 305 | permafrost | cover | 240 / 2400 / 650 | Composable candidate |
| 306 | grounding_network | node | 250 / 2600 / 300 | Composable candidate |
| 307 | crystal_prism | plane | 400 / 2200 / 400 | Composable candidate |
| 308 | blightsoil | disk | 300 / 2400 / 400 | Composable candidate |
| 309 | conflagration | ring | 400 / 2400 / 400 | Composable candidate |
| 310 | steam | expanding_veil | 240 / 2100 / 500 | Composable candidate |
| 311 | firestorm | corridor | 350 / 1800 / 350 | Composable candidate |
| 312 | thermal_shock | fracture | 600 / 100 / 550 | Composable candidate |
| 313 | plasma_arc | branch | 450 / 120 / 400 | Composable candidate |
| 314 | solar_flare | reveal_pulse | 220 / 100 / 650 | Composable candidate |
| 315 | cinderveil | ember_veil | 300 / 2400 / 400 | Composable candidate |
| 316 | flood | flow | 220 / 2500 / 350 | Composable candidate |
| 317 | mistcurrent | corridor | 220 / 2200 / 400 | Composable candidate |
| 318 | freeze | growing_strip | 300 / 2000 / 350 | Composable candidate |
| 319 | conductive_flood | water_path | 500 / 2100 / 350 | Composable candidate |
| 320 | mirrorwater | observation | 220 / 2600 / 350 | Composable candidate |
| 321 | blackwater | motion_veil | 260 / 2400 / 400 | Composable candidate |
| 322 | vortex | annulus | 400 / 2200 / 400 | Composable candidate |
| 323 | hailstream | pulse_lane | 400 / 2250 / 350 | Composable candidate |
| 324 | ion_storm | drifting_node | 450 / 2100 / 400 | Composable candidate |
| 325 | lightbend | bend | 250 / 2400 / 300 | Composable candidate |
| 326 | shadowdraft | bands | 300 / 2400 / 350 | Composable candidate |
| 327 | glacier | cover | 650 / 2800 / 600 | Composable candidate |
| 328 | superconduct | frost_path | 500 / 1800 / 350 | Composable candidate |
| 329 | crystal_lens | lens | 450 / 2300 / 400 | Composable candidate |
| 330 | black_ice | entry_mark | 300 / 2500 / 400 | Composable candidate |
| 331 | overload | push_pulse | 650 / 100 / 450 | Composable candidate |
| 332 | arcflash | reveal_line | 300 / 140 / 400 | Composable candidate |
| 333 | static_shroud | entry_veil | 320 / 2200 / 400 | Composable candidate |
| 334 | radiance | reveal_area | 300 / 2500 / 400 | Composable candidate |
| 335 | penumbra | border | 220 / 2400 / 250 | Composable candidate |
| 336 | umbral_field | attrition_veil | 350 / 2800 / 450 | Composable candidate |

## Movement coverage

| Component | Normal/reduced | Acceptance |
|---|---|---|
| air_dash_afterimage_mask | Both exported | Candidate; caller state required |
| float_budget_tick | Both exported | Candidate; caller state required |
| float_wing | Both exported | Candidate; caller state required |
| jump_takeoff | Both exported | Candidate; caller state required |
| landing_contact | Both exported | Candidate; caller state required |
| landing_dust | Both exported | Candidate; caller state required |
| protection_badge | Both exported | Candidate; caller state required |
| protection_corner | Both exported | Candidate; caller state required |
| slide_dust | Both exported | Candidate; caller state required |
| slide_trail | Both exported | Candidate; caller state required |
| walljump_burst | Both exported | Candidate; caller state required |
| wallrun_sparks | Both exported | Candidate; caller state required |

`air_dash_afterimage_mask` is a stencil only. It requires the caller body-only atlas and never includes character art or protection cues.

## Provenance and reproducibility

Original authored integer pixel matrices. No smooth vector rasterization, pixelation filter, photographic texture, generated-image model output or copied reference pixels were used. Source creation, export, geometry, preview and validation scripts are included. New files stay under this candidate namespace. Existing hash expectations were not replaced.

Source-tested: **yes**. Candidate key poses/selected geometry sheets visually inspected: **yes**. Browser playback: **blocked / unverified**. Production gameplay: **not integrated**. Human acceptance: **pending**.
