# H.E.X. presentation audit and implementation plan

Audit date: 2026-10-20. Source: `C:/Users/sende/Documents/Codex/2026-10-15/ana/outputs/hex-confluence`, clean commit `592855cbd88c070683d0c1fdc1fa0eaf235a0514`.

This is an analysis and implementation plan. No game source, assets, save format, dependencies or deployment were changed. No build or broad test suite was run.

## Recommendation

Make the existing game easier to read before adding spectacle. Preserve the cast, the warm shaded pixel art, the quiet environment, the simultaneous exchange and the useful inspect popovers. Concentrate the next production pass on three connected problems:

1. **The command interface becomes physically too small or overlaps at certain viewport sizes.**
2. **Champions, creatures, ground materials and effects do not yet look as though one artist directed them.**
3. **The exchange presents many events, but sound and animation do not always distinguish the events that matter most to the player.**

A stronger result needs a shared presentation contract, a tested combat layout and a small art-quality benchmark. It does not need a new cast, a replacement ruleset, 63 unrelated particle effects or more ambient movement.

## Evidence and boundaries

I traced the public entrypoints, inspected active renderer, animation, sound and UI code, viewed source atlases and the parent agent's calibrated screenshots, and ran a read-only metadata/alpha check on four representative champion atlases. I researched primary sources on game art, animation and accessibility.

Current reachable entrypoints:

- `/` uses `HexHomeV41`.
- `/tower` uses `TowerGameV23`, or `CoopTowerV23` for friends/invitation query parameters.
- `/story` uses `CampaignGameV20`.
- `/skirmish` uses `SkirmishGameV18`.
- Those current combat hosts share `PixelBattlefieldV16`, `BattleCommandV41` and `game-audio-v16`.
- `ChampionFrames`, `CombatCreatureV19`, `CraftedWorldV24`, `ElementEffectsV16`, and the V42 focus/threat overlays are therefore active production components despite their differing version suffixes.
- `/classic`, old `/v*` routes and legacy Tower routes still exist. Their different rules and presentation are not evidence that current Tower uses those systems.
- `/animation-review` exists and uses actual champion/effect rendering. It is a useful production review surface, not proof that every cel has been artistically reviewed.

Rendered evidence:

- [Desktop screenshot, measured 1440×900 CSS px](expert-audit-desktop.png)
- [Phone screenshot, measured 390×844 CSS px](expert-audit-phone.png)
- Parent separately reproduced overlapping spell labels at a measured 790×444 CSS px. That is a browser-confirmed defect reported by the parent, not a conclusion from the screenshot dimensions alone.

These captures show a single saved Tower encounter. They do not establish all-map performance, all-device usability, animation quality in motion, sound quality, color-vision accessibility or the clarity of a six-player endgame.

## What should be preserved

**A recognizable cast with genuine animation infrastructure.** There are 30 animated champion atlases, each 768×1024 with a 6×8 grid of 128px cells. The animation code selects three painted views, mirrors left-facing presentation, and supplies six cels for walking, casting, impact and defeat. Every champion has a motion profile in `lib/character-motion.ts`; cast release is synchronized while recovery and perceived weight vary. This is a strong production base. Frame count and distinct profile values do not certify the quality of each performance.

**Quiet scenery and meaningful terrain changes.** `CraftedWorldV24` explicitly prevents solid terrain and prop swaying. Water and ember movement is localized to material glints. `terrainMaterial` reads the resulting field rather than simply painting the incoming element. Forest props fade around characters, destinations and actual movement routes. Solid ruins use `solidFootprints`, while decorative rocks are kept separate. This directly supports readable tactics and addresses the user's objection to arbitrary motion.

**An established element language.** `lib/element-presentation.ts` gives each family a six-color ramp. Advanced elements retain their base color and receive different emblems and projectile/impact cels. Movement, targeting, affected area and blocked landing cues already use more than hue alone. Keep this structure.

**A comprehensible exchange skeleton.** Movement precedes casting; all projectiles use a common release/flight clock; a real interception gets a meeting-point effect; review has no deadline. There are real health-delta cards, an explicit round report, replay, undo/redo, a skip-to-result action, and an instant presentation option.

**Useful inspection.** `BattleInsightV24` supports mouse hover, keyboard focus and tap pinning, with Escape and outside dismissal. The parent found the Blind popover clear. The route preview groups verified scouting details, names tuition's payer and preserves uncertainty. Extend these successful patterns instead of adding unrelated tooltip systems.

## Findings, ordered by player impact

| Priority | Finding and evidence | Consequence | Required direction |
|---|---|---|---|
| P0 | **Responsive command layout can overlap.** Parent reproduced label collisions at 790×444. `battle-command-v41.css:84–103` changes column widths and opponent behavior by viewport width, while later height/orientation blocks override the same controls. At 1440×900 the supplied scene fits. | Correct actions can become difficult to distinguish or select. Desktop success hides an intermediate-width failure. | Replace overlapping breakpoint patches for this active component with a small set of container-size layouts. Test the width and height independently. |
| P0 | **Phone legibility is bought by shrinking essential content.** Final portrait rules at `battle-command-v41.css:145–178` use 8–10px vital/action text, 40px spell cells, a 20px status row, and a 36px preview. The 390×844 capture confirms very small text. | A technically fitting interface still demands effort and precision. Status effects and spell consequences are precisely the content players must understand. | Give essential text a real minimum and move secondary detail into the existing inspection surface. Keep a complete action label, cost and availability visible. Use a deliberate compact layout, not further font reduction. |
| P1 | **Material and pixel density diverge.** The screenshot shows richly shaded champions/trees beside chunky, mostly flat elemental creatures and geometric terrain/effects. `CombatCreatureV19` uses procedural SVG bodies on a 96-unit viewBox; champions use detailed 128px raster cels; many world accents use fractional SVG strokes. | Creatures look like a different product and some elemental fields resemble tokens pasted onto the world. | Match outline weight, highlight direction, shade grouping and effective pixel density. Author one creature-family benchmark before extending it. Keep readable geometry, but give it the same material treatment as the cast. |
| P1 | **Most creature “frames” are moved copies of the same body.** `CombatCreatureV19.tsx:11–14,31–66` supplies action-specific translation arrays; each frame renders the same `CreatureBodyV19`, with limited wing/tail changes and cast motes. All use common action durations in `combat-creature-v19.css`. | The promised species personality is not supported as strongly as champion personality. The result can look like an icon hopping rather than an animal performing. | Author distinct contact, compression, release and recovery silhouettes for a small set of locomotion families. Keep idle bodies still. Timing differences must not alter simultaneous spell release. |
| P1 | **Non-steam interceptions share one generic formation.** `ElementEffectsV16.tsx:52–75` gives Fire+Water a custom steam formation; other combinations use the same heart, pressure outline and orbiting ingredient cels. Ground marks partly differ by mechanical properties. | Steam teaches its identity visually; many other combinations depend on reading their names. Extra ingredients can add busy decoration without explaining the new behavior. | Define a compact interaction grammar by resulting physical behavior: cloud/shelter, crust/obstruction, current/force, growth/recovery, fracture/hazard. Add distinctive major combinations within that grammar rather than one unrelated burst per recipe. |
| P1 | **Resolution is replayable but not locally inspectable in time.** `feedback-v16.ts:7–16` fixes a 6.9s exchange: cast begins at 1.6s, impact at 4.2s, review at 5.6s. Tower has replay and Show result, but no pause/phase step. `TowerBattleV23.tsx:75–77,92,107–109`. | A six-player exchange can be too much to follow in one pass, while a simple exchange consumes the same clock. Players replay everything to investigate one collision. | Use one presentation clock with pause, phase step and normal/fast playback. Keep simulation timing/order unchanged. Make the review accessible at any speed. |
| P1 | **Sound selects by alphabetical element order rather than relevance.** `feedback-v16.ts:151–169` takes the first two unique element names after sorting. Reaction choice prefers ingredient count. All defeat events trigger the same `score` cue. | A selected champion's cast can become inaudible in a mixed volley; an ally's defeat and an enemy's defeat have the same positive-sounding event type. | Rank cues by player relevance and outcome: local action, collision that replaced it, ally loss, enemy defeat, then ambient material. Give defeat/team-loss distinct semantic cues. |
| P1 | **Reduced motion is coupled to loss of combat sound.** In Tower `playback` only calls audio when `sound && !instant`; reduced-motion preference defaults to instant. Animation preference therefore also suppresses outcome sound. | Someone who avoids motion cannot keep the complementary audio feedback. | Separate motion, playback speed and audio preferences. Instant review should play a brief outcome summary or an optional compressed cue sequence. |
| P1 | **Audio contexts are not disposed by current Tower/Campaign cleanup.** `game-audio-v16.ts` exposes `dispose()`, which closes its context. `TowerBattleV23.tsx:75` and `CampaignGameV20.tsx:94` call `cancel()` on unmount instead. Each Tower battle starts with a fresh audio ref. | Repeatedly enabling sound in new rooms can leave allocated contexts behind. This is a code-supported lifecycle risk, not a measured leak-size claim. | Own the audio engine at a stable session boundary or dispose it on unmount; preserve explicit gesture-based enablement. Test that context close occurs once and that pending enable promises cannot revive disposal. |
| P2 | **No mix controls or persistent sound preference are exposed in current Tower.** Sound is a local boolean and a mute toggle; voices connect directly to the destination. There is no master/effect/UI level or mono/spatial preference in this engine. | Players cannot quiet clicks while retaining combat feedback, or adapt the sound for external friend chat. | Start with master, UI and combat buses plus a persistent mute/level setting. If spatial cues are added, keep a mono option. Do not add music until this hierarchy works. |
| P2 | **Camera scaling can change effective pixel size continuously.** Sprites are 192 world units from 128px cells. `focusViewSize`, `planningCamera` and `fitEffect` derive arbitrary scale and centers from the viewport. Projectiles also use smooth CSS offset paths. `image-rendering:pixelated` helps sampling but does not guarantee a stable shared pixel grid. | Some zooms may produce uneven pixel widths or shimmer; source art can be clean while movement looks less crisp. | Validate a few deliberate presentation scales, stable anchors and screen-space rounding. Keep useful readable zoom; do not force a tiny fixed-resolution canvas without comparing it on phones. Shimmer remains a motion hypothesis pending calibrated captures. |
| P2 | **All map cells remain in the SVG tree.** `PixelBattlefieldV16.tsx:391` sorts/maps the full cell list; per-cell rendering checks cast/clash memberships and may instantiate surface cels. Arena radius grows from 9 to 13, i.e. 271 to 547 cells. | Large shared encounters risk more layout/paint work and a substantial SVG tree. Existing bounded accent selection is helpful, but not a performance measurement. | Profile real large matches before replacing the renderer. Cache geometry/membership maps, keep fields quiet at overview, and cull noninteractive decorative detail outside the view. Preserve roving keyboard navigation if visual culling is introduced. |
| P2 | **Persistent side rails are not proportional to their content.** The 1440×900 screenshot has two enemy cards at the top of a mostly empty full-height rail. | A large amount of width is reserved for two small facts while the central encounter needs careful framing. | Use a compact opponent summary with expandable inspection; decide with task testing whether the stable rail helps more than the extra board width. This is a layout hypothesis, not an instruction to always remove the rail. |

Additional nuance:

- The board deliberately shows one changed status per character (`combat-clarity-v23.ts:37–48`) and retains complete changes in the report. That is a defensible density policy. Add a clear “+N changes” when needed rather than showing all popups at once.
- Existing phase highlights have `aria-live="polite"` and report links. Do not characterize the game as having no screen-reader support. Full keyboard/screen-reader completion still needs direct testing.
- A 20px target is a warning, not a standalone WCAG conformance verdict: minimum-target exceptions and spacing require measurement. A 44px touch target is the proposed H.E.X. product budget, above the WCAG minimum.
- The fixed 6.9s sequence is an intentional readability choice. Whether it is too slow in ordinary play needs timing/task evidence; lack of phase inspection is directly observable in the code.

## Raw asset observations

Viewed `oh_tipi.webp`, `treevor_mason.webp` and the original Wellspring prop atlas; checked metadata and alpha for Oh Tipi, Treevor, S. Wayne and Ha Rekt.

| Atlas | Compressed bytes | First idle cel visible bounds | Partially transparent pixels | Opaque pixels on cel borders |
|---|---:|---|---:|---:|
| Oh Tipi | 243,034 | x35–81, y42–103 | 0 | 0 |
| Treevor | 308,774 | x36–90, y43–103 | 0 | 0 |
| S. Wayne | 156,254 | x40–81, y48–103 | 0 | 0 |
| Ha Rekt | 319,522 | x35–94, y37–103 | 0 | 0 |

All four are 768×1024. The animation directory contains 30 WebP files totaling 7,021,380 bytes. A naive decoded RGBA allocation for all thirty is 94,371,840 bytes (90 MiB), excluding renderer overhead; this is arithmetic, not measured browser memory. Actual loading depends on the characters encountered.

These atlases contain nonzero RGB values behind alpha zero. The local image viewer exposes some of that as long colored streaks. Those values are invisible under correct alpha compositing and **are not evidence of visible dead pixels**. Do not erase them or “despeckle” all isolated pixels based on the raw display.

`sprite-integrity-v42.ts` contains nine reviewed one-pixel masks across six atlases, applied by `ChampionFrames`. This preserves original source bytes and intended eye highlights, sparks and fine details. Retain exact-mask regression checks. A cleanliness review should composite every cel over light, dark and checker backgrounds at native and intended display sizes, distinguish detached remnants from intended particles, and record each approved repair coordinate.

The active environment path uses original `wellspring-props.png`, reactive `reactive-props-v17.webp`, and `wellspring-surfaces-pixel-v17.webp`. The larger `wellspring-surfaces-crafted.webp` exists but is not the ground atlas imported by the current battlefield. Do not optimize an unused asset while claiming a current combat gain.

## Coherent visual and motion direction

**Art direction:** shaded miniature fantasy, viewed across a living landscape. The existing champion art is the reference standard. The tactical grid and overlays are a reading aid, not the dominant material. Warm paper, dark teal framing and restrained brass can remain in menus. Remove ornamental duplication before reducing text.

**Hierarchy:** legal action and immediate danger first; acting characters and projectile meeting second; resulting terrain third; scenery fourth. An element should be recognizable from silhouette and motion as well as color. An advanced element retains its family palette but changes its shape and temporal behavior.

**Terrain:** preserve exact collision footprints. Give full-cell ruins continuous occluding mass, readable top faces and local material clusters; preserve the successful canopy fade. Water edges, ice fracture direction and mud depth should describe traversal. A region needs one readable boundary and a few material landmarks, not a unique busy animation on every tile.

**Character performance:** author poses from body mechanics. Oh Tipi gathers low and releases a rolling current; Treevor compresses through planted roots and a heavy shoulder; S. Wayne uses stillness and a short precise hand release. Those three form a benchmark because they exercise different masses and silhouettes. First match one lesser creature and one greater creature to their lighting, pixel cluster size and foot contact.

**Motion:** no automatic whole-object sway. Animate because something moved, struck, burned, froze, flowed or reacted. Distinguish anticipation, synchronized release, recoil and settle. Secondary motion belongs to a tail, loose sleeve, splash or leaf displaced by an action, not the entire tree or rock. Idle charm can be one infrequent blink or tiny creature-specific gesture, tested separately from gameplay-critical motion.

**Interactions:** use physical verbs. Steam expands and settles around feet; ice facets align along the slide direction; metal locks into angular plates; current bends and streams; growth unfolds from the surface; fracture travels outward. Preserve exact underlying areas and contact times. One principal formation, a few secondary accents, then a quiet persistent state is enough.

These are recommendations for H.E.X., informed by primary sources: Valve tested character identification from silhouettes; Riot emphasizes effects that communicate a source and gameplay meaning while remaining stylistically coherent; Disney's animation process stresses timing, staging, anticipation, weight and follow-through. They support a readable performance, not indiscriminate extra motion. [Valve](https://steamcdn-a.akamaihd.net/apps/valve/2007/NPAR07_IllustrativeRenderingInTeamFortress2.pdf), [Riot](https://www.riotgames.com/en/artedu/visual-effects), [Disney](https://www.disneyanimation.com/process/animation/).

## Proposed production budgets

These are starting acceptance targets to validate, not claims that a particular number guarantees quality.

| System | Budget |
|---|---|
| UI type | Essential action/body copy 16 CSS px default; secondary data at least 13–14px. Large-text mode up to 200%. No 8px vital statistics. Reserve the pixel display face for short titles; use a highly readable body face. |
| Touch | 44×44 CSS px for primary actions and repeated controls. Smaller visible icons may live in larger hit areas. Avoid hover-only availability explanations. |
| Command density | One active fighter summary, one action row, four spells plus signature, one consequence preview, one commit area. Details use the existing focus/tap popover or a sheet. Never squeeze five verbose cards into fixed heights to satisfy a no-scroll slogan. |
| Sprite craft | Keep existing 128px source cells and common foot anchor. Define one outline weight, one light direction and controlled shadow/highlight ramps. Review at the actual combat size, not only enlarged art sheets. |
| Animation | Six clear action cels remain a reasonable champion contract; expressive silhouettes matter more than frame count. Creature pose families need real contact/release differences. No independent per-character launch time. |
| Effects | One central impact per spell/interaction, complete readable footprint, at most five secondary accent sites per area (already supported). One primary condition popup per character plus explicit overflow. No full-screen flash as routine feedback. |
| Persistent world | Slow material glints only; no solid-prop transforms. No per-tile floating labels. At overview use one poster cel and region contour. |
| Audio | Initial UI and combat buses under a master gain; at most 2–3 simultaneous focal material cues and 1 salient outcome cue, prioritized semantically. Avoid increasing polyphony merely because more people joined. |
| Loading | Keep the entire cast off the critical first-paint path. Load/preload participating atlases and likely next assets. Track compressed transfer and decoded memory separately. |
| Performance | Establish actual target hardware first. Initial goals: pointer/key feedback under 100ms, no turn-start main-thread task over 50ms during playback initialization, p95 animation frames under 33ms on the nominated phone and under 16.7ms on the nominated desktop. These require profiling and may need adjustment. |

Pixel-perfect rendering is a sampling and coordinate problem as well as an art problem. Unity's primary documentation recommends consistent asset density, point filtering and grid-aligned placement. For this SVG/CSS implementation, use those principles to test stable scale/anchors; there is no need to migrate engines. [Unity pixel-perfect guidance](https://docs.unity.com/en-us/engine/6000.6/manual/unity2d/2d-urp/2d-pixelperfect/prep-sprites).

## Implementation sequence and ownership

### 1. Lock the presentation contract and repair layout

UI lead owns the current battle command and phase layout. Gameplay engineer supplies structured spell names, availability reasons, effects and actor stats; text must not be scraped from prose. Accessibility reviewer validates focus order and touch behavior. Test at measured CSS sizes 320×568, 390×844, 430×932, 790×444, 1024×768 and 1440×900, with 1–3 controlled actors and all five spell slots.

Use component/container dimensions rather than a growing sequence of global overrides. Define compact portrait, compact landscape and desktop layouts. Preserve decision-critical information through controlled disclosure. Confirm that every primary action remains reachable without panning the document horizontally. Make “large text” a layout state, not magnified text clipped by old fixed-height cards.

**Exit:** no overlaps/clipped costs; buttons satisfy target budget; long canonical names fit; the same move→cast→inspect→undo→commit path works with mouse, touch and keyboard.

### 2. Unify the exchange clock and semantic event presentation

Presentation engineer owns one cancellable clock shared by actors, projectiles, field transitions, callouts and sound. Rules engineer verifies that replay state never changes simulation. Add pause/phase-step/fast controls at the existing review surface, preserve exact collision fractions and synchronized launch, and separate motion preference from audio.

Create a compact event projection that includes source, target, actual HP delta, significant status changes, replaced projectile destinations and player relevance. Existing outcomes and phase ledger provide a useful starting point. Preserve the detailed report; do not emit a dozen simultaneous toasts.

**Exit:** stepping and replay reach the identical final snapshot; paused animation does not leave audio running; instant mode preserves outcome cues; a player can identify why an intended hit was replaced.

### 3. Produce one art-quality benchmark

Art lead owns a contact sheet and in-game comparison scene with Oh Tipi, Treevor, S. Wayne, one lesser creature, one greater creature, a forest edge, water, a full-cell ruin, fire, ice and steam. Animation lead reviews foot planting, body mass, silhouette change and recovery at actual size. Rendering engineer validates pixel sampling and masks. This is a quality benchmark, not another public game mode.

Improve only assets that fail the benchmark. Keep source provenance and approved originals. Once the scene reads as one coherent world, extend the same rules to remaining creature families and terrain. Do not regenerate all thirty champions because some creature shapes are weak.

**Exit:** silhouettes remain distinguishable without color; creatures match the cast's material treatment; walls look blocking; fields explain traversal; no accidental opaque specks, clipping or atlas bleed on approved backgrounds.

### 4. Add the interaction vocabulary and purposeful sound

VFX lead builds a few meaningful physical interaction families under the agreed effect budget. Audio lead builds corresponding attack/formation/outcome cues with semantic priority, side-aware loss/defeat, persistent volume settings and correct context lifetime. Neither changes the resolver.

**Exit:** players can identify element family and principal result with text labels hidden; a collision sounds and looks distinct from an ordinary hit; muting sound loses no essential information; reduced motion retains it.

### 5. Profile and validate in large real scenarios

Performance engineer captures browser traces for six squads sharing one battle, split battles, dense burning/steam fields and many status changes. Optimize measured hot paths. Candidate work is cached cell membership, decoration culling and shared SVG/cel definitions; a full renderer rewrite needs evidence.

Independent testers complete a blind first encounter and a complex replay on desktop and a real phone. Browser screenshots, alpha statistics and automated tests cannot establish charm or tactical comprehension by themselves.

## Acceptance tests that can prove or disprove the direction

- **Decision task:** at least 8 of 10 unfamiliar players can identify selected fighter, move cost, spell cost, affected allies and commit state without assistance after a short first-room introduction. Record errors and time; do not treat this small sample as market demand.
- **Effect recognition:** show 2-second clips and still outcomes for six base families, six branches and five major interaction behaviors. Aim for at least 90% correct family and 80% correct resulting behavior after players have seen the reference once. Collect which silhouettes are confused.
- **Cause and consequence:** after a simultaneous crossing volley, ask what collided, which original target hits were canceled, and which field remains. The player's explanation must agree with the resolver event record.
- **Accessibility:** complete a full encounter keyboard-only; test roving board navigation, dialogs, popover pin/dismiss, undo and phase inspection with NVDA on Windows. Check mute, mono if introduced, reduced motion, 200% text, and color-vision simulations; include users with those access needs because simulations are not substitutes.
- **Layout:** assert real control bounds and text overflow at all supported sizes, including 790×444. Exercise the longest spell/character names, 0/1/multiple statuses, 5 spell slots, errors, network banners and safe-area insets. No overlap is allowed just because clicking still works.
- **Art integrity:** dimension/anchor checks; composite all active cels on several backgrounds; alpha/component review; directional/cast/defeat contact sheets; adjacent-frame bleed checks. Exact intentional particle allowlists, no blanket removal of disconnected pixels.
- **Clock integrity:** test start, replay, pause, step, skip and return to planning. Projectiles must not arrive before release, collisions must use their authoritative fraction, and the visual/audio state must correspond to the selected phase.
- **Audio lifecycle:** repeated room entry/exit with sound enabled leaves no orphaned contexts/sources; disposed enable promises cannot restart audio; maximum mix level is measured offline; selected/critical cues survive crowded exchanges.
- **Performance:** record CPU time, frame times, DOM/SVG node count, active animations, network transfer and decoded memory separately. Compare against the same seeded state on the same devices. Report browser emulation separately from physical-device evidence.

## Primary references applied

- [Xbox XAG 103](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/103): use redundant shape/text/audio cues; do not depend on color alone; test with actual players rather than relying only on color simulations.
- [Xbox XAG 105](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/105): independently configurable sound categories and mono support when spatial audio is used. This supports the proposed mix controls, not a requirement to add voice or music.
- [Xbox XAG 117](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/117): let players control distracting motion and automatic updates. A motion setting should not erase unrelated audio information.
- [Xbox XAG 101](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101): readable/scalable text and icons. Its platform-pixel guidance is not interchangeable with CSS pixels; validate physical size and browser zoom.
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/) and [Reflow explanation](https://www.w3.org/WAI/WCAG22/Understanding/reflow.html): text resizing, reflow and target sizing provide a web-interface baseline. Essential spatial game content has different constraints from surrounding menus; keep accessible menu/action alternatives.
- Art-specific primary sources are linked beside the proposed direction above. Their principles guide H.E.X.'s own style; they are not permission to copy those games' assets.

## Unresolved questions for the combined audit

The current evidence cannot establish whether players feel attached to the characters, whether all thirty action sets have strong silhouettes, whether dense shared battles remain intelligible, whether sounds are pleasant on phone speakers, or whether a compact opponent summary outperforms the stable rail. These require the benchmark scene, motion/audio review, targeted accessibility sessions and recorded player tasks. They should be treated as validation work, not filled in with confident aesthetic claims.
