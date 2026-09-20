# Warm pixel foundation and finite material trails

Status: verified local Windows portable checkpoint, 2026-09-09. Uncommitted and
unpublished; previous awareness/tempo portable retained unchanged.
Weekly cutoff: 20% remaining. This replaces the earlier 25% stop floor.

## What is implemented

| Slice | Live change | Preserved boundary |
|---|---|---|
| Shared bodies | Charcoal cloth, brown leather, gold trim, broader boots/gloves and clearer garment volume across all 3,312 cells; 92% baked visual scale | Three shared sizes, 9 banks, same fixed bones, 96px cells, feet pivot; 53/63/70px south display heights; no new race skins |
| Wellspring ground | Warmer staggered stone, muted moss/earth, stronger edges; 135 terrain entries | Same 3,072 x 2,304 campus, collision, stations and routes; one cached texture, two ground draw calls; no extra buildings |
| Basic magic | 112 editable normal/reduced sequences, 480 frames: flight, tail, impact, matter phases and field tiles across all eight elements | Original palettes, timings and pivots; one guaranteed impact stamp; no new gameplay inferred from pixels |
| Flight ingredients | Bolt, Heavy and Wave may leave narrow finite matter; Rapid never does | Plain matter has no automatic damage, status, healing or movement buff |
| Impact ingredients | Wider terminal footprint, 24-32px radius versus 16px trail | Actual cursor/obstacle/target end, not a cosmetic collision override |
| Chemistry budget | One reaction payload per contributing cast; sustained trail combinations get 60% active time | Paid direct projectile damage remains; no free reactions from leftover siblings, prism splits or later terminal residue |

The [supplied cast sheet](../reference/art/cast_style_post_templates_v1/cast-style-reference.png)
is the common style target, not a claim of final cast fidelity. Its SHA-256 is
`4f24f503007ac34eb5e41411186ff3ac8880c58e9c438ef9b01c17ddcba68eba`.
The source-native body, terrain and magic systems were extended; no new generated
image sheet was substituted for verified animation coverage.

## Trail rules and tradeoffs

| Rule | Exact behavior |
|---|---|
| Rapid | Too small/weak to create flight trails; retains normal direct damage and terminal matter while unspent |
| Lifetime | Earth 1.5s; Fire 1.1s; Water/Ice 1.4s; Wind/Charge 0.8s; Light 1.2s; Dark 1.3s |
| Admission | Samples every 8 ticks per projectile with 28px same-cast spacing; max 4 trails per owner / 32 globally, inside existing 16/128 material caps |
| Paid priority | Pending/live terminal reservations are accounted for; two spare cast slots are not consumed by optional trails |
| Pressure tradeoff | Existing trails occupy real material slots until spent/expired; with 4 trails, at most 12 other projectile/material reservations fit for that owner. Two spare slots permit single shots, not a new five-lane Wave |
| Combination | A new terminal may hit a strictly older trail; trail + trail, same-cast and same-tick terminal/trail pairs cannot react |
| One payload | A reaction spends every matter fragment from both source casts and zeroes material strength on their still-flying siblings; damage remains intact |
| Sustained result | 60% normal active time; formation/decay, pulse behavior and five instant windows unchanged |
| Promotion | A cast's real impact replaces its own same-cell trail using a fresh entity ID; no refresh or movement of old reaction links |
| Compatibility | Protocol 47 / snapshot 18 field layout retained; compiled-content fingerprint changed; friends must use this same build |

Terminal + terminal remains the reliable longer-duration route. Trails offer
short-lived placement opportunities and consume the source spell's finite
chemistry budget early. Element personalities currently come from distinct art,
lifetimes and the existing 36 effects, not eight untested automatic trail buffs.

## Verification ledger

| Evidence | Current result |
|---|---|
| Magic pack | 20,484 assertions, zero failures; 413 animated sequences, 474 sequences / 1,960 frames / 3 atlases in complete pack |
| Shared body source | 33,120 fixed-bone checks; 384 complete eight-phase pairs; all 24 grounded height anchors preserved after garment-volume refinement |
| Terrain source | 1,550 alpha/seam checks; source atlas untouched; runtime derivative adds 720KiB decoded |
| Gameplay focused | Trail, base chemistry, paid projectile integration, snapshots and presenter suites pass; final four-suite copy/Heavy/capacity correction: 46,070 assertions, zero stderr |
| Actual captures | 23 actual-game frames / 11 paid casts; all eight Bolt trails, terminal footprints, Rapid control, three bodies, Steam payload expenditure and expiry |
| Renderer | Fixed local-coordinate triangulation with unchanged world vertices/UVs; 69,244 focused assertions and clean 23-frame rerun; 1,056 parts / 6,192 triangles valid; all world hashes match pre-fix |
| Full | 94 suites / 532,858 assertions, zero failures / stderr; import, asset audit and 120Hz boot passed |
| Export | Strict release export, isolated standalone EXE/PCK boot and portable ZIP passed; 2,133 source records stayed unchanged |
| Human / remote / performance | Not accepted in this checkpoint; no two-PC test or sustained rendered 120fps certification |

Historical failed runs remain in `docs/evidence/warm-style-trails-v1`, including
the initial command typo, fixture failures and render diagnosis; final passing
evidence must be recorded separately. Source-authority hashes and raw atlas
allowlists are refreshed explicitly, never disabled.

## Test this build

Open [flux2.exe](../exports/windows-warm-trails-p47-20260909/windows/flux2.exe),
keeping its adjacent PCK. For another Windows PC, extract the complete
[97.6MB portable ZIP](../exports/windows-warm-trails-p47-20260909/release/FLUX2-Windows-x86_64.zip)
and keep its files together. No editor or new installation is needed.
Both peers must use the same new build. Existing LAN/direct-address behavior
is retained; physical remote connection acceptance is still pending.

| Payload | SHA-256 |
|---|---|
| Windows PCK | `4108090ac878c2c5038759fb93a753e91d867c284a7f1afa13384ab2ac656889` |
| Portable ZIP | `208ff6fbc8840d4fe9400ba05bb785c8595b6de19789c0cf454f3f53d5e0048d` |

The [machine-readable checkpoint](evidence/warm-style-trails-v1/checkpoint.json)
links exact payload sizes, hashes and evidence. No installer retry, security
change, publishing or visible game launch was performed for this checkpoint.

The initial Full additionally caught old Heavy tests treating the first allocated
trail as a terminal, a Gallery label, and a capacity fixture assuming trails cost
no slots. Tests now wait for actual impacts, keep exact damage/terminal-count
assertions, and prove the shared capacity tradeoff without raising any cap.

## Reusable inputs and next gates

| Next | Scope | Acceptance before expansion |
|---|---|---|
| Player check | Walk/sprint/strafe, cast while moving, compare Rapid and Bolt; terrain contrast at 50/75/100% | Readable headings/contacts and visually smaller bodies, without confusing hit geometry |
| Named skin pilot | One Small character over the accepted shared rig | Eight aim directions x eight travel directions, all actions; no per-frame scale drift |
| Reaction-art pilot | Steam and Magma, then remaining first-grade reactions | Exact finite masks/phases, clear counterplay, reduced mode, no range-circle substitute |
| Load / connection | Dense paid trails+reactions, real rendered load and same-build two-PC session | 120Hz tick budget measured separately from render rate and network behavior |

Editable sources: [body rig](../art_batches/character_style_v1/wireframe_motion_v2/README.md),
[magic refinement](../art_batches/magic_style_v3/README.md),
[terrain refinement](../art_batches/wellspring_style_v2/README.md).
