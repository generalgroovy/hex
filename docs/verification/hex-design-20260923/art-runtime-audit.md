# H.E.X. visual authority and runtime audit — 2026-09-23

Status: SOURCE_INSPECTED + EXISTING_IMAGE_REVIEW. Comparison board is OFFLINE_REFERENCE, not runtime replacement or human acceptance. Assignment C owns only this report and `art-comparison/`. No engine, import, test, export, image generation, catalog/source edit or promotion was performed by this worker. Other workers' changes are preserved.

## Current truth

Verified checkout `C:\Users\sende\Projects\hex`, origin `https://github.com/generalgroovy/hex.git`, branch `main`, HEAD `1559a566e33255c59337c5963f1c3c685d757f1f`. No staged diff was present at inspection. Pre-existing dirty Loom/source/docs remain untouched. Inspected generated identity reports candidate `p55-a0952919d4d5`, protocol55, snapshot21; no fresh runtime identity computation was performed here. Selected fallback remains P48 in `docs/current-checkpoint.json`; candidate existence does not promote it. Root owns engine/process and fresh captures.

Current reference: `reference/art/cast_proportions_v5/flux-current-cast-final.png`, visually inspected with its README. Thirty figures occupy five rows of six. This September14 identity/proportion reference is an illustrated board, not a pixel atlas. Its README leaves human aesthetic approval open. No newer accepted cast reference was found in `reference/art` READMEs, current cast documentation or current authority documents. Older Oh Tipi/portrait READMEs use historical authority language; preserve identity provenance, while v5 and current catalog determine shared proportions, names and roster membership. Do not cut the illustrated board into live atlases.

Source load chain: `bootstrap.gd` calls `CartoonChampionPresenter.configure(visual_language)` with default `use_wireframe=true`; that branch configures `assets/sprites/wireframe_motion_v2/manifest.json`. `texture_for_champion()` and `movement_frame()` choose catalog body size. All thirty profiles therefore use three shared warm-adventurer bodies. `champion_page_overrides_v1.json` contains named historical pages, but default mode bypasses them. A page marked `reviewed_complete_runtime_page` does not establish current loading or human acceptance.

## Asset authority table

**V5 rNcN** means row/column in final v5 PNG according to its README. “Accepted reference” here means documented identity/proportion authority, not human aesthetic approval. **S/M/L** mean actual source paths `assets/sprites/wireframe_motion_v2/{small,middle,large}-{base,locomotion,sprint}.png`. These are shared bodies, not ancestry skins.

**C** coverage: ten base rows × eight facings (80 cells), independent walk and sprint banks each 8 travel × 8 aim × 8 phases (512 cells). Total1,104 cells per size;3,312 across nine textures. Base states principally hold single poses. Semantic airborne actions reuse jump; slide/wave-dash/wall-skim reuse slide; moving casts preserve gait. This is structural coverage, not dedicated Float, air-dodge, wall, takeoff/landing or cast-phase animation acceptance. Current source passes a distance-driven locomotion phase; foot planting was not remeasured here.

**T** acceptance: shared temporary template implemented/previously captured; named identity skin NOT_IMPLEMENTED in current default mode; fresh full-motion/human acceptance NOT_RUN. Existing motion presence is not human acceptance.

| Character ID | Accepted reference | Size / race | Loaded body asset | Action / direction coverage | Missing work | Runtime acceptance |
|---|---|---|---|---|---|---|
| oh_tipi | V5 r1c1 | middle / seakin | M | C | Named anatomy, clothing, palette and action transitions | T |
| s_wayne | V5 r1c2 | small / hobbit | S | C | Named anatomy, clothing, palette and action transitions | T |
| red_baron | V5 r1c3 | large / undead | L | C | Named anatomy, clothing, palette and action transitions | T |
| grace_reava | V5 r2c3 | small / sylph | S | C | Named anatomy, clothing, palette and action transitions | T |
| wa_bidi | V5 r2c2 | small / goblin | S | C | Named anatomy, clothing, palette and action transitions | T |
| steezo | V5 r1c4 | small / goblin | S | C | Named anatomy, clothing, palette and action transitions | T |
| treevor_mason | V5 r1c5 | large / treefolk | L | C | Named anatomy, clothing, palette and action transitions | T |
| oll_i | V5 r1c6 | large / werewolf | L | C | Named anatomy, clothing, palette and action transitions | T |
| fluup | V5 r2c1 | large / orc | L | C | Named anatomy, clothing, palette and action transitions | T |
| nico_lai | V5 r2c4 | small / gnome | S | C | Named anatomy, clothing, palette and action transitions | T |
| spai_si | V5 r2c5 | middle / demon | M | C | Named anatomy, clothing, palette and action transitions | T |
| leaf_hidden | V5 r2c6 | middle / treefolk | M | C | Named anatomy, clothing, palette and action transitions | T |
| ha_rekt | V5 r3c1 | large / wyrmborn | L | C | Named anatomy, clothing, palette and action transitions | T |
| dr_apex | V5 r3c2 | large / stoneborn | L | C | Named anatomy, clothing, palette and action transitions | T |
| haara | V5 r3c3 | small / nymph | S | C | Named anatomy, clothing, palette and action transitions | T |
| hesus_christo | V5 r3c4 | middle / elf | M | C | Named anatomy, clothing, palette and action transitions | T |
| grimm_bow | V5 r3c5 | large / troll | L | C | Named anatomy, clothing, palette and action transitions | T |
| biggy_bob | V5 r3c6 | middle / dwarf | M | C | Named anatomy, clothing, palette and action transitions | T |
| jan_wicked | V5 r4c1 | middle / human | M | C | Named anatomy, clothing, palette and action transitions | T |
| ba_djoh | V5 r4c2 | large / minotaur | L | C | Named anatomy, clothing, palette and action transitions | T |
| urzh | V5 r4c3 | large / stoneborn | L | C | Named anatomy, clothing, palette and action transitions | T |
| donnok | V5 r4c4 | middle / dwarf | M | C | Named anatomy, clothing, palette and action transitions | T |
| djonah_thaan | V5 r4c5 | middle / vampire | M | C | Named anatomy, clothing, palette and action transitions | T |
| luuh_i_zeh | V5 r5c1 | small / spiderkin | S | C | Named anatomy, clothing, palette and action transitions | T |
| juul_i_yaina | V5 r5c2 | small / demon | S | C | Named anatomy, clothing, palette and action transitions | T |
| faab_i_yaina | V5 r5c3 | middle / angel | M | C | Named anatomy, clothing, palette and action transitions | T |
| joh_haynes | V5 r5c4 | large / orc | L | C | Named anatomy, clothing, palette and action transitions | T |
| h_le_ne | V5 r5c5 | middle / stoneborn | M | C | Named anatomy, clothing, palette and action transitions | T |
| fimu_yashiha | V5 r5c6 | small / treefolk | S | C | Named anatomy, clothing, palette and action transitions | T |
| sai_laas | V5 r4c6 | small / nymph | S | C | Named anatomy, clothing, palette and action transitions | T |

All ten-per-size memberships agree with current catalog. Preserve stable aliases `grace_reava` → Grace Riva, `nico_lai` → Waka Aren Si, `donnok` → Don Doko Don, `h_le_ne` → H. Lenee and `fimu_yashiha` → Mifu. The old unnamed Angel asset folder is historical, not a31st current identity. S. Wayne's neutral shared body does not satisfy his dark-skinned identity. Preserve Biggy Bob's brown hair; male Spai Si/Juul I Yaina, bald male Faab I Yaina, female Wa Bidi/H. Lenee/Mifu; Sai Laas gender unspecified.

## Existing sample and gaps

Open `art-comparison/index.html` locally. It links original files, provides source aim/travel/eight-phase inspection, and labels playback as an offline preview. Its wall-clock preview does not reproduce game travel. No image was generated/copied/edited/promoted. `.gdignore` excludes this directory from engine imports.

| Domain | Viewed/source evidence | Finding | Next gate |
|---|---|---|---|
| Characters | v5 final, middle-base, staged size-transfer board, Sept20/21 native captures | Reference identities are rich and compact; neutral brown human-like body can merge with warm paving. Three sizes do not supply thirty skins. | Shared contact/transition motion; one complete Small identity at gameplay scale. |
| Projectile | `assets/sprites/hex_court_v1/projectile_atlas.png`, `HexCourtPresenter` | Already compact four-family silhouettes and elemental cores. Atlas stored order Earth/Fire/Water/Air/Ice/Charge/Light/Dark differs from requested review order; preserve stable wires. Presentation dimensions18/24/32/24 are not collision proof. | Paid launch/travel/interception/impact/expiry in normal/reduced; collision equivalence. |
| Materials | Native Steam normal/reduced; six staged Water/Fire/Steam motif sheets | Repeated angular native marks have material identity; staged crests/flames/open curls improve motion vocabulary but use old64×80 cells. | Water-only0.75 cosmetic adapter, authoritative polygon clip, phase mapping and exported load proof. |
| Fog | Sept20 after-v2 edge-step native; Sept21 Steam native | Outside-sight terrain is very dark with a sharp transition. Historical stills do not reproduce the current wall endpoint bug. | Root's fresh matched surface case; separate terrain shade from strict dynamic clipping. |
| Environment/UI | Sept21 native, staged map references | Warm paving/grass coherent, repetitive floor detail competes with small brown body; dense labels need quiet combat hierarchy. | One real Wellspring area after body/material gate; optional floor detail first. |

Native/reference boundary: `docs/verification/hex-small-grid-20260921/native/` and `hex-vision-20260920/captures/` are historical game captures. V5, staged `images/`/`artifacts/`, and this HTML are references/offline previews. A staged composition filename containing “native” is not fresh game proof. The Animation pack contains duplicates of nine existing body textures, not replacement authored atlases; its P01–P05 proposals expose contact, diagonal slide, backpedal, moving-cast and landing questions. Current source resolves some formerly missing inputs (caller/gait parameter); proposed fixes remain unimplemented. No repeated-cell storyboard is a game recording.

## Original pixel-art contract for first sample

1. Compact form before detail: v5 short necks, sturdy torso, separated hands/feet, approximately4–4.5 heads. Use a few readable clusters: ancestry silhouette, coat/body mass, face/hair cue. Oracle-era economy and Gungeon-like threat priority inspire original H.E.X. assets; do not pixelate the illustrated reference and call it production art.
2. Stable construction:96×96 cells, pivot(48,84), baked visible standing heights58/63/68. Authoring references58/68/76 are distinct. No per-frame fitting or scale pulse. Hurt radii17/18/19 and common18 wall clearance stay fixed. Transparent body-only sheets, empty hands, no baked shadow/aura/spell/label/scenery/staff/wand.
3. Crisp shared rendering: deliberate one-pixel exterior contour clusters, coherent material ramps, restrained highlights. No scattered noise, filtered gradients or inconsistent outlines. Nearest/no mipmaps. Judge source pivots and actual gameplay-scale readability separately. Thin cues also need mass/shape support when zoomed out.
4. Eight-direction anatomy: change limb overlap and front/back information, not a mirrored front image. Reuse timing/pivots Small→Middle→Large, then ancestry/clothing. Recolors do not finish a cast. Distinct support/passing-foot shapes during walk/run/strafe/backpedal; real ground travel drives phase. Air/Float/dodge/wall/slide/landing transitions remain explicit fallback gaps until reviewed.
5. Contrast priority: immediate danger and local body/cursor; actionable actors/cover surfaces; ground/station landmarks; decoration. Glow is decoration, never damage coverage. Finite strength can shrink/quiet cores without expanding collision/budget. Rapid receives no heavyweight persistent trail.
6. Element grammar in Water/Earth/Fire/Air/Ice/Charge/Light/Dark review order: crests; chunky facets; forked tongues; ribbons; icy slivers; broken zigzags; bright rays; contained dark mass with readable edge. This is proposed shape vocabulary, not mechanics. Reactions retain two curated component accents and distinguishable shape/motion; avoid muddy color averages.
7. Formation/active/expiry: essential contour and phase survive both effects modes. Existing authority controls timing and selected cells. Safe holes are absent authoritative cells. Reduced removes optional particle/glow density before danger footprint or phase identity. Steam uses open curls and does not imply concealment without gameplay authority.
8. Sight: first wall face stays readable. Terrain beyond is gently darker with restrained transition; actors/health/labels/attached effects remain strictly filtered. Retain360° character-centered sight, local body/cursor, no aim cone. Visual hiding is not network secrecy.

## Smallest sample and acceptance matrix

Follow root's single queue: wall-surface/fog correctness, then one paid Water patch with existing normal/reduced sheets, then shared Small motion and one complete S. Wayne skin candidate. His dark skin, compact Hobbit silhouette and distinctive coat test identity against neutral bodies. Keep shared Middle/Large as size controls. No named-skin promotion follows this recommendation. Stage Fire/Steam only after Water succeeds; current projectile cores need event review before replacement generation.

| Case | Required observation | Evidence |
|---|---|---|
| Default/zoomed-out × normal/reduced | Same dangerous selected cells/phase; body/cursor/first wall face clear on stone/grass. Record numeric zoom/resolution/mode. | Fresh source/exact-export NOT_RUN here. |
| Pixel/pivot |58/63/68 standing; pivot48,84 stable. No stretching low poses, cell bleed, alpha fringe, rescaling, smear or collision changes. | Source measurement plus actual motion. |
|8 facings × forward/back/strafe | Alternating contact, walk↔sprint continuity, immediate aim, stop/block freeze. | Continuous source/export trace; human plausibility separate. |
| Slide/jump/Float/dodge/wall/landing/moving cast | Entry/hold/exit and interruption clear, paid committed shot direction retained, no invented delays/gait reset. | State/event-aligned native sequence. |
| Water lifecycle | Existing phase metadata, exact holes/seams/owners/expiry/overlap/map edge; normal/reduced equally honest. | Paid equivalence + native + PCK loaded asset proof. |
| Four deliveries | Distinct launch/interception/impact/expiry; core direction/strength clear; glow not damage. | Input→paid cast→event→capture. |
| Walls/cover | Static, active hex, corner, low cover,8 directions, interpolated actors, spectator, creation/destruction. Wall visible; behind actor/labels/effects absent. | Root fresh fixtures/captures. |
| Dense view | Optional texture/particles recede before threats; hazards/targets readable. | Matched rendered cost, not sheet byte count. |
| Human acceptance | Identify identity, travel/aim and danger/expiry without debug aid. | HUMAN_ONLY pending; assertions cannot close it. |

Keep matched camera/build/input, preserve failed attempts. Root's fresh fog images may append an explicit addendum; never upgrade old captures retroactively.

## Gentle-fog dependency: dynamic path audit for integration lead

`bootstrap.gd::_draw` currently draws every `hex_court_presenter.draw_ground` region, `movement_trace`, `world.fields`, `_draw_element_chemistry` deposit/heavy-blast/impact/reaction and `world.projectiles` before the global mask. `_draw_projectile` has no LOS gate in its court/burst/foundation/fallback branches. `_draw_field` gates a release owner's cue, but not the field itself. Reducing global mask opacity would expose these live effects. Existing actor/practice/social/cue guards do not fix the unguarded materials/projectiles; even a visible cue anchor/endpoints can draw extent behind a wall.

Smallest correct architecture: static terrain pass, strict masked dynamic pass, separate gentle terrain shading. Reuse existing observer/range/opaque and chemistry geometry projected into one binary union mask; clip full dynamic pixels including trail/glow/labels. Preserve actor/cue semantic guards (including chemistry reveal), because raster clipping complements them. Center-only culling is insufficient for a straddling field and wrong when its visible edge should remain visible. Keep observer body/cursor on deliberate post-mask pass. Terrain wall self-shadow exemption must not broaden dynamic visibility inside opaque footprints. Distinguish static visible wall surface from opaque volume and behind-shadow.

Add fixtures for hidden fields/projectiles, visible center with hidden glow/trail, partially visible field with hidden center, beam with visible ends but blocked middle, delayed labels, missing/dead observer and spectator. Dynamic mask must remain strict even when terrain alpha is only0.3. No gameplay geometry changes follow from this presentation split. Source/API design only; integration/testing belongs to root.

## Three highest-value creative proposals

1. Coherent effect grammar and complexity budget: immediate clarity, bounded presentation work, existing Water motifs, no new chemistry state.
2. Reusable native animation laboratory: inspect existing8×8 travel/aim and transitions before thirty skins. Start with actual gait clock/templates, no new production toolchain. Moderate fixture cost, low authority risk.
3. One rehearsal station: after input/sight reliability, demonstrate existing paid Water→Fire/Steam, escape and reset. Moderate scene/UI cost; tests understanding before more recipes or campus expansion.

Event explanation follows when existing authoritative data can be surfaced without another simulation. Counterplay arenas follow accepted reaction rules; audio follows event priority and listening; resource-neutral synergy remains a mechanics proposal requiring approval.

## Handoff

Viewed final cast, middle body atlas, projectile atlas, three normal motif sheets, staged size-transfer board and historical native screenshots. Source/catalog inspection produced all30 rows. Board path checks and roster counts are recorded below after execution. No runtime or human acceptance follows from HTML.

Files: this report; `art-comparison/index.html`; `art-comparison/.gdignore`. Fresh fog visual review pending root capture supply. Human taste/full animation, exact-export asset loading, rendered performance and multiplayer remain open. No source/catalog/queue edit or asset promotion.

Static verification executed: PASS — 30 roster rows, ten per size; all static HTML image/report links, all nine body banks and all six motif sheets exist. Browser rendering and JavaScript interaction were not executed by this worker.


## Provisional fog-source review addendum — 2026-09-23

Read-only review of root's provisional `pov_terrain_backdrop.gd`, `_draw_pov_mask`, `_draw_pov_terrain`, `_draw_hex_pillar_occlusion_shadows`, and `SightOcclusion.shadow_outside_surface`. No engine/test/capture execution by this worker.

**Sound elements:** cached backdrop contains static campus presentation only, with a fixed tick and no observer focus. Full-alpha replacement hides earlier live pixels in covered regions, unlike translucent fog. All static building footprints are first restored opaquely, then all shadows are applied, so one building cannot accidentally repaint over another building's later shadow. Shade `(0.66,0.66,0.66,1)` changes brightness rather than mask opacity. Range feather remains opaque. Strict actor/cue eligibility remains separate. These are source-level findings; first-frame texture readiness, rendered alignment and cost still require native evidence.

**P1 — first-visible structural Hex interior can retain unrelated dynamic pixels.** `_draw_hex_pillar_occlusion_shadows` subtracts each exact polygon from its own shadow but does not restore the polygon's interior. Current `_draw` rendered fields, projectiles, glow/trails and other material pixels over the original structural drawing before this mask. Pixels landing inside the exempt first-visible polygon therefore survive. Actor LOS guards do not remove them. Visible cover surface is correct; visible unrelated effect pixels inside its opaque volume are not established by that surface exception. Reproduction fixture: form active Fortify, then place a bright non-cover effect over its interior while keeping the first surface within range and free of another occluder's shadow. Compare with static wall interior, which is already correctly overwritten.

Smallest correction: restore static terrain opaquely over exact structural polygons, then render only the authorized structural surface using existing current-region style/phase, then apply every other occluder's shadow and the range mask. Preserve exact hex geometry. A dedicated cover-only presenter hook is safer than calling all `draw_ground`, which would restore hidden unrelated chemistry. Cover surfaces outside range/behind other occluders must remain suppressed. Never use an unfiltered snapshot of the already-composited dynamic frame as the cover source.

**P2 visual consistency to inspect:** range feather is drawn after obstacle shadows with a white inner edge, so static terrain inside the feather can brighten back from0.66 to1 even where an obstacle shadow was already applied. This does not reveal live effects because replacement remains opaque, but may produce a bright halo through occluded terrain. A native corner plus range-boundary fixture should check it. Combine opacity-independent shade conservatively (minimum brightness) if the artifact is visible, without changing sight authority.

**Existing boundary, not a new claim:** actor/cue LOS includes chemistry concealment; the polygon replacement pass enumerates static and structural blockers only. It cannot be described as comprehensive geometry-equivalent clipping for every chemistry concealment rule. Retain current semantic actor/attached-effect guards and keep that distinction explicit.

Review disposition: **CHANGES_NEEDED** for structural Hex interior isolation before claiming all dynamic effects remain hidden. Fresh after-capture review remains pending. No runtime source was edited by this worker.

## Corrected source and development-image review — 2026-09-23

Reviewed root's updated cover-only repaint and final shadow ordering. Original P1 is **RESOLVED IN SOURCE**: `_draw_pov_mask` opaquely clears structural Hex interiors, `draw_cover_surfaces` selects only this frame's active Fortify/Permafrost/Grounding Network/Crystal Prism/Crystal Lens regions whose cells occur in current collision polygons, and does not restore Water/Fire/projectiles or unrelated effects. `draw_ground` clears/rebuilds the region cache each frame. These five materials match `HexCollisionWorld` structural wires301/305/306/307/329. Original P2 is **RESOLVED IN SOURCE**: all blocker shadows now follow range-feather rendering, preventing the feather from brightening occluded terrain. An observer inside an opaque polygon receives whole-screen static replacement; local observer-body redraw remains separate.

Viewed `.godot/hex-wall-before-v1/size-0-static-normal.png` and `.godot/hex-wall-after-v1/size-0-static-normal.png`. The DEVELOPMENT after image makes the near left building's roof/facade and surrounding static terrain readable; the prior near-black blanket is removed. Player body, practice targets and HUD remain legible. Ground on the right remains darker with a restrained range transition. The diagonal obstacle shadow remains visibly angular, consistent with blocker geometry. These are model visual observations from still images, not human aesthetic approval or motion/performance proof. The after image was captured before the final cover correction and carries a development identity; it does not validate that correction or the final export. Root will regenerate final evidence.

**Remaining P2 presentation-alignment finding:** `_set_world_transform` uses `PixelPresentation.snapped_canvas_origin(camera_origin, zoom_percent)` while current mask origins/building polygons/Hex polygons use unsnapped `(world - camera_origin) * zoom`. At fractional camera positions the mask/opaque-replacement edge can differ from rendered world edges by up to0.5 screen pixel. This can create a thin leftover dynamic fringe or erase a visible surface edge during movement, even though a static integer-position capture looks correct. Use the same snapped translation for every screen mask point and observer origin; convert `world_covers` back with `(vertex - translation) / zoom` if that change is made. Do not alter authoritative positions. Required fixture: fractional camera movement at default and zoomed-out values across static and Hex boundaries, plus bright effect immediately beside the surface. Source-level issue sent to root; runtime impact not measured here.

No further blocking issue found in the bounded cover/cache/order review. Final native normal/reduced/zoom/Hex/motion and export gates remain root-owned and unclosed by this review. No runtime edits or engine execution by this worker.

### Final source recheck: p55-ede24ea44158

The remaining P2 mask-alignment finding is **RESOLVED IN SOURCE**: POV origin, static building polygons and Hex polygons now use the same snapped canvas translation as world rendering; the cover inverse subtracts that translation before dividing by zoom. The null-local-actor early return now resets the draw transform and opaquely replaces the complete viewport, preventing pre-return live fields/projectiles from remaining exposed. The generated identity inspected is `p55-ede24ea44158`, SHA256 `ede24ea441589507badbc536e87b99887048c2b070451f0753b72a1ae98c8ec1`,2793 source records. This reads root's frozen manifest; this worker did not regenerate or run it.

Bounded source review now has no unresolved finding from the P1/P2 issues reported above. **FINAL_NATIVE_PENDING**: final regenerated matched captures, Full receipt and exact export remain root-owned; the earlier after still is DEVELOPMENT evidence only. Human aesthetic/motion acceptance remains pending. Await final capture paths for targeted visual review without repeating the inventory audit.

## Final frozen PCK and source-canary image review

Reviewed all12 images in `.godot/hex-wall-pack-v1/` and its receipt, identity `p55-ede24ea44158`, at1280×720/75% camera zoom: Small/Middle/Large static normal/reduced and edge-step000/032/064 normal/reduced. Compared the prior before-v1 static/edge images. The previously dark first building surface is now readable; surrounding unseen terrain remains recognizable with restrained darkening. Normal/reduced preserve the same visibility decisions. Wall target is absent in static/000 and appears at032/064, matching receipt state; exposed/rear targets remain visible. No new blocking visual defect was found in these captured cases. This is a bounded model image-review pass, not human approval, continuous animation acceptance or a full eight-direction camera matrix.

PRELIMINARY CANARY ONLY: the initial cover fixture populated products/collision but omitted the complete presentation cell/region record. Its result proves sampled concealment, not preservation of a rendered structural surface. The initial cover crop also did not provide the required unobstructed surface proof. Do not use the31/159 result as cover-surface acceptance. Inspected `.godot/hex-terrain-v1/capture-receipt.json` and selected cover-active, inside-wall50/75/100, invalid/dead observer, missing-local, and visible-control before/after crops/full images. Receipt:31 cases,159 assertions,0 failures,28 fractional-camera cases, frozen identity above. Every expected-hidden crop records0 changed pixels; visible controls225 and removed-cover controls209 exceed the64-pixel threshold. Selected viewed crops agree: hidden magenta canary absent, control visibly present. Eight wall bearings are sampled, not the full8×3×2 Cartesian product. Cover is explicitly injected trusted local authority; this does not prove paid cover formation/removal. Source canary is not exported-build canary evidence. Native spectator, multiplayer information filtering, all-backend correctness, performance and human acceptance remain outside this receipt; root reports separate headless spectator coverage in Full.

**Nonblocking visual follow-up:** near the right range edge, HOST FARFLOW's static title is partly restored as a trailing fragment (for example “LOW”). The cached backdrop renders with sentinel focus, which makes station-label opacity1, while live campus rendering fades distant labels by observer distance. Mixing these two versions at the range edge produces partial labels. This is static-label continuity, not a dynamic information leak. A future bounded polish should give static-world labels one consistent visibility/fade rule or keep those labels out of the terrain cache and handle them as complete semantic labels. No frozen runtime changes are requested solely for this cosmetic issue.

Final review disposition: **BOUNDED_SOURCE_AND_CAPTURE_REVIEW_PASS**, with the nonblocking static-label follow-up above. Previously reported structural-surface, feather-order and pixel-alignment source issues are resolved. The12 PCK wall images support static-wall behavior; the initial31/159 canary alone did not establish actual rendered-cover preservation. Broader art/runtime/human/performance/network gates in this audit remain unchanged. No engine or runtime edits were performed by this worker.


### Corrected structural-surface oracle — source v2

The incomplete initial cover fixture is superseded for cover evidence by `.godot/hex-terrain-v2/capture-receipt.json`:31 canary cases plus the explicit surface oracle,165 assertions,0 failures, unchanged runtime `p55-ede24ea44158`. The corrected fixture prepares a complete active Fortify region (wire301, intensity/quantity1200) and selects a49×49 surface crop outside HUD bounds at screen center252,264.224. Actual `cover-active-surface-crop.png` visibly contains the ochre raised hex with bright rim/dark sides; `cover-removed-surface-crop.png` shows bare paving. The full active image also shows this cover in the world with its outgoing shadow. These are actual reviewed pixels, not inference from collision state.

The surface oracle records1538 changed pixels between active and removed crops (minimum16). Reviewed active normal before/after canary crops and active reduced after crop retain the same visible ochre surface with no magenta canary; hidden canary changes remain0. Removed-cover control changes are225 in both modes. This supports the bounded source claim: visible structural cover survives replacement while unrelated injected pixels are erased. The cover remains an explicit synthetic trusted-authority fixture, not a paid formation/removal journey. Exact-PCK corrected oracle is pending completion and will be reviewed separately; no package receipt was consumed early.

### Final corrected exact-PCK structural-surface review

After root confirmed completion, reviewed `.godot/hex-terrain-pack-v1/capture-receipt.json` and actual package active/removed surface crops, active normal/reduced canary crops and full active image. Frozen identity is `p55-ede24ea44158`;31 canary cases plus the surface oracle pass165 assertions with0 failures. The package crop visibly preserves the same ochre raised Fortify surface, rim and sides; removed crop is bare paving. Surface difference1538 pixels, active hidden canary difference0 in both modes, removed/visible controls225. The active/removed surface SHA256 values match the corrected source-v2 receipt. Root reports zero stderr; this worker performed read-only receipt/image review, not execution.

**Final bounded package review: PASS.** This closes the previously pending exact-PCK visual proof for the corrected synthetic structural-surface fixture. The receipt's generic sentence that exported-build acceptance remains separate should be read with this runner context: these images exercise the frozen exported PCK, but do not prove every ordinary native EXE player journey or broader release acceptance. Synthetic paid-cover formation/removal, real native spectator, human aesthetics/motion, all hidden pixels/backends, physical controls/two-PC and network-information security remain unproved here. Static-label range-edge continuity remains the documented nonblocking cosmetic follow-up. No runtime edits, engine operations, promotion or other workers' file changes were made by this reviewer.
