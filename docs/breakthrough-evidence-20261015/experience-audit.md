# H.E.X. breakthrough experience audit — 15 October 2026

Owner: Experience. Independent reviewers: Gameplay and Technical. This is a source-backed design and implementation handoff, not a claim of audience demand, commercial success, new performance acceptance or a finished art overhaul. The user selected illustrated 2.5D with smooth animated sprites. The earlier complete-overhaul plan remains the wider direction; this pass selects a coherent playable increment.

## Decision

Make the existing depth easier to experience before adding more breadth. The strongest immediately supportable promise is: **read a rival, win their spell, then use what you learned against the next rival**. The campus gives this journey a place; chemistry and expressive paid movement supply the player's means. A catalog of hundreds of combinations is valuable after the player has a reason to compare them.

Gameplay proposes an optional three-rival Circuit over the existing Conservatory, Tideglass and Basalt encounters. I support that as the first bounded product slice. It can produce a beginning, a decision, a consequence and a satisfying stopping point using real existing encounters. Do not turn it into a new reward currency, random upgrade economy or mandatory unlock tree. Current challenge time limits do not prove a five- or fifteen-minute session; retries, reading, movement and loadout choice determine that in player testing.

The near-term experience work is a prominent Circuit entry, clearer task order, compact-map reliability, readable results and direct earned-spell use. New art, interiors and music should then strengthen this same route. They should not become unrelated demonstration islands.

## What the current build actually provides

| Source / evidence | Finding | Consequence |
|---|---|---|
| `src/app/local_navigation_controller.gd:32` | A flat, paginated list mixes exploration, introduction, Range, challenges, demos, tactical lessons, references, settings and Developer. Its input/availability handling already exists. | Reorder existing choices and add the single Circuit intent; no new menu framework is needed for this increment. |
| `src/app/optional_introduction.gd:110` and `:151` | The introduction observes actual move/jump/cast/recovery/Range actions. Tactical instruction now correctly asks for Jump press and release. Completion broadly suggests Range/challenges. | Keep real action observation and optional skipping; connect completion to a specific next action rather than repeat the fixed tutorial repair. |
| `src/content/signature_learning_path.gd:7` | Three authored lessons already teach gaps, delayed ground and the second lane. Learned advice is separated from the next unlearned spell. | Circuit is a presentation/session layer around this existing progression, not proof that content is missing. |
| `src/presentation/spell_testing_panel.gd:104` | The challenge card already shows tell, counter, lesson and genuinely earned reuse advice. | Preserve this information; surface the relevant part at the moment of choosing or retrying. Do not add another giant explanatory panel. |
| `src/presentation/wellspring_map_panel.gd:47` before this slice | At 480×270 logical, Previous's bottom three pixels intersect Details; Next intersects Travel by one pixel. Pointer dispatch tests Details before Previous. | This is a concrete accessibility/input defect, not a taste preference. Shared draw/hit geometry must be separated at 960×540 and 200% text. |
| `src/presentation/pixel_flipbook_presenter.gd:13–29` | Two walk contacts reuse neutral beats; sidestep/backward-specific anatomy is incomplete; advanced states retain rigid fallback poses. | Smoothing alone will not supply missing action content. The next art slice needs authored anticipation/contact/recovery and direction-aware feet. |
| `src/presentation/hex_court_presenter.gd:349`, `hex_magic_glow.gd` | Projectiles already use atlas art, current-strength size, motion direction, contact-disk pixels and bounded radial glow. | Do not claim that adding glow is a new feature. The outstanding art job is a unified illustrated core/material language without moving the real contact boundary. |
| `src/presentation/element_audio.gd:7–15`, `:87–227`, `:266` | Four playback voices, eight queued cues, local ownership, priorities, suppression and generated short clips already exist. | A bigger mixer or more voices is not the first improvement. Tune an audible purpose only with real listening and preserve the existing lifecycle guards. |
| `src/presentation/visual_language.gd:83–97` | Current cardinal, opaque-worldbone contract explicitly rejects automatic cutaway. | Tall architecture/interiors require an explicit versioned presentation contract and visibility tests, not a silent validator relaxation. |

I visually inspected the preserved `docs/depth-clarity-evidence-20261014/native/world-b/deep-north-reduced-candidate.png` and `native/canonical-a/105-front-canonical-left-accepted-right.png`. They show readable actors and coherent existing masonry but very broad repeated paving and shallow-looking wall mass at normal framing. These are controlled historical fixtures, not current continuous gameplay, a first-session recording or a performance sample. They justify composition questions, not a claim that every district is visually empty.

## Current bounded implementation slice

Root authorized these files after the initial audit; no engines/tests were run by Experience:

- `src/app/local_navigation_controller.gd`: first offline `expansion-circuit` row, label `Rival Circuit · 3 rivals`; learning actions remain together, and all existing tools remain available. No new key binding. Root owns activation in `element_expansion_controller.gd` and Bootstrap.
- `src/presentation/wellspring_map_panel.gd`: destination-list height is admitted after reserving the real paging buttons and gaps above Details/Travel. Paint and hit testing continue to consume the same geometry.
- `tests/unit/test_local_navigation.gd`: original menu navigation now explicitly moves from Circuit to Map; prior action IDs remain unique/reachable; online menus omit Circuit. Actual Bootstrap pointer dispatch exercises pager bottom edges at physical 960×540 / 200% text and checks unchanged world authority.
- `tests/unit/test_wellspring_map.gd`: compact control rectangles must be disjoint; all pager corners and center must page without opening Details/travel; Details and Travel retain their separate intents and availability refusal.

Technical independently source-approved the four exact navigation/map files. They still require root parser/test/native qualification and do not establish the Circuit's completion behavior, save semantics or learning transfer by themselves.

## The first-session experience

The sequence below is the intended product experience. The first Circuit implementation reuses the actual existing ready countdown; it does not add a pre-leg inspect/loaner modal. Its completion surface shows the final result and route total rather than retaining three complete historical leg records. Those richer briefing/recap ideas are later design options, not implemented claims or prerequisites for the first bounded gate. The explicit learned-spell choice temporarily changes slot 1; ordinary Next keeps the currently selected Circuit slot, and final Try opens the real earned Range preset and ends the Circuit.

1. Launch through the existing desktop front door. The character, controls and current loadout are ready. A short first choice offers Circuit, exploration and optional learning through the actual menu; do not require a new profile, lore questionnaire or complete catalog selection.
2. Before a Circuit leg, show the rival's name, spell, one tell and one counter. Preserve a choice to inspect, try a practice loaner, start or leave. Trying a loaner must remain a separate unranked practice route; never silently carry its authority into an earned attempt.
3. During the encounter, keep health/Flux/Stamina, current slots and important threat cues. Do not add an always-on Circuit task paragraph over the arena. Encounter progress belongs at the leg boundary.
4. A result says what actually happened: victory/defeat/timeout, reward learned/already known, and saved/session-only status. Offer Retry, Next rival, Try learned spell and Leave as appropriate. Denial reasons remain visible, especially save failure. Do not label a timeout a loss of a spell the player already owned.
5. A Try action selects the real earned wire through existing loadout/Range authority; it does not grant it or cast automatically. If this changes the loadout, the user sees and confirms that ordinary action. A fresh practice context is explicit.
6. Completion provides a short three-leg recap and a deliberate return to Wellspring. A future rematch is optional. There is no endless modal loop and no hidden punishment for leaving.

Acceptance: through real controller/pointer/key routes, a new player can identify the next task, understand one counter, finish or leave a leg, distinguish saved from unsaved learning, and return to free exploration. Test the full journey with a few unfamiliar people and record their mistaken interpretations. A simulation test cannot prove the journey is fun or understandable.

## Art direction and a memorable hook

Use the approved illustrated 2.5D style as a **lived-in workshop campus**, where rivals are recognizable practitioners rather than interchangeable targets. The visual contrast is warm stone/aged brass/timber at rest versus restrained luminous elemental activity during play. Keep a strong silhouette per hero and a dominant material per district. Small purposeful props near thresholds can show what people do there; uniform texture everywhere is less useful than a clear doorway, a route edge and a distinctive activity.

The first visual commission should cover one integrated courtyard/doorway and three body types, not thirty complete characters or thirteen new destinations. Reuse the selected Circuit's locations. Finish one action cycle first, then extend the same production rules across those three bodies. The promise of all walls at least twice the standing large-character height remains the user target; measure approved opaque feet-to-crown `Hlarge`. Current pixel nominal 68 and body catalog 76 are different contracts, so 136/152 are examples, not interchangeable universal heights. No silent exception for practice walls. Tall visual mass must not imply a walkable roof or change projectile/collision rules.

A useful future interior is a small Loom/workshop room connected to its courtyard: visible purpose, doorway threshold, one meaningful interaction and a clear exit. Roof/front-wall occlusion should reveal the local living body and ground anchor while preserving enemy information limits and hazard boundaries. Existing self redraw is a starting capability, not a complete room-visibility system. Continuous door walking must preserve held movement and paid actions; only a real scene/world transfer uses travel handoff rules.

The trailer hook is an evidence requirement, not a marketing slogan: record an unbroken playable sequence of reading a rival's attack, winning/learning its signature, and using that signature in the next leg. If it requires a title card listing 504 spells to explain why it is interesting, the route has not yet communicated the hook. Do not stage fake hits, rewards or impossible movement to produce the clip. No trailer capture is authorized in this audit.

## Animation, projectiles and area truth

Authored body content should separate travel direction from aim direction: forward stride, sidestep, backward motion, start/brake, release, hit and recovery. Presentation sampling can interpolate from actual state and existing render alpha; authoritative contact, protection, startup/recovery and resource changes remain fixed-step events. Cosmetic settling must be interruptible immediately. Add no gameplay delay to make a pose finish. Match contact feet to the ground anchor; aerial pose height must come from the existing air model.

For the later illustrated projectile pilot, use a circular energy core with material-specific internal motion, a direction cue and a subordinate halo. Preserve the actual contact-disk boundary independently of strength-consuming interior art. Water, Fire, Air, Earth, Light and Dark are the six active identities; Ice/electric effects are derived treatments. Delivery remains legible through timing and arrangement, not solely colour. Spray is still a fan, and persistent hex coverage remains hex coverage; the request for circular energy balls does not authorize making every damage region circular.

Show harmless preparation, active threat and terminal decay distinctly. A finite shared pool and independent stacked products are different threats. The previous Conflagration coalescing experiment passed captured readability but failed its cost gates; do not revive it as an optimization. Simplifying overlapping decoration needs its own threat-density and performance evidence. New full-screen bloom or persistent particle history would add an unmeasured burden and is outside this implementation slice.

## Sound, accessibility and plug-and-play

Keep a common semantic hierarchy: received harm and confirmed contact are clearer than decorative casting; confirmed earned result is distinct from ordinary impact; refusal is short and informative. Current admission is local/owned rather than spatial enemy audio. Any new audible enemy cue needs a visibility/source rule, not a speculative positional mix. Preserve mute, focus loss, menus/loading, reset and terminal-tail behavior. Existing finite-tail fixes must not be reimplemented.

A short restrained tonal identity for the three-leg journey is a future listening experiment, preferably replacing or arranging existing result material within the same voice budget before adding music systems. Music/ambience buses, licensed recordings and voice acting are not prerequisites for the current loop. No comfort, balance or intelligibility claim can come from Dummy audio or file hashes.

Prioritize keyboard/mouse/controller parity, remaps, release/rearm after menus, 960×540 with 200% text, reduced effects and high contrast. Every critical cue needs shape/timing or text as well as colour and a visible equivalent to audio. Preserve all settings and player saves; test normal close/reopen. A source checkout, a qualified Windows portable, an actual Linux build and a public plug-and-play release remain different outcomes.

## Priority and acceptance handoff

| Priority | Concrete change | Owner / independent review | Required evidence |
|---|---|---|---|
| Now | Circuit menu intent + map controls separation | Experience / Technical | Source review, existing map/navigation suites, transformed pointer and pad, native 960/200 and 1280/100 views |
| Now | Three-leg session/result/use flow over current trials | Gameplay + Root / Experience + Technical | Paid real encounters; reward/save/retry/leave invariants; compact panel real input; end-to-end human first-session observation |
| Before declaring smoothness | Current-build Full versus Light observer comparison through the same launcher | Technical + Root / Experience | Matched source/settings/foreground/memory conditions and separate observer cost; no transfer from old Profile B |
| Next content gate | One complete expressive action set, then three anatomy types in the same route | Experience art owner / Gameplay + Technical | Source-to-runtime asset identity, measured residency/setup cost, actual movement/interruption/body-footprint views and human readability |
| Next world gate | One tall purposeful doorway/room and honest self visibility | Experience + Technical / Gameplay | All-walls height rule, collision/LOS independence, actor/hazard/hidden-enemy views, enter/exit/save lifecycle, moving-frame cost |
| After actual listening | Bounded result/contact sound refinement | Experience / Gameplay + Technical | Real output listening at normal/reduced/mute, simultaneous priority and lifecycle controls; no extra voice count by default |

Suggested formative checks are decision aids, not statistical proof: ask unfamiliar players what they think will hurt, what they just learned, how they would use it, and where they would go next. Record wrong answers before explaining. Measure route completion, voluntary retry and control confusion; do not equate these with retention, sales or a promised hit.

## Primary sources and the new inference from each

1. [Riot — Clarity in League](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/), read 15 October 2026. Riot explains silhouette identity, visual hierarchy and keeping effects accurate to gameplay. **Transfer:** give each rival one dominant recognizable feature and use the same attack language in preview, encounter and learned use. This supports consistency, not a blanket claim that more glow is clearer.
2. [Nintendo — Yoshiki Haruhana on Link's Awakening's graphic direction](https://www.nintendo.com/de-de/News/2019/Oktober/Grafikdirektor-Yoshiki-Haruhana-enthullt-was-hinter-dem-uberarbeiteten-Grafikstil-von-The-Legend-of-Zelda-Link-s-Awakening-steckt--1656228.html), 9 October 2019, read 15 October 2026. The art director describes the tension between a charming detailed miniature and the small character scale, including carefully authored interiors. **Transfer:** concentrate detail at meaningful human-scale thresholds and activity areas rather than increasing texture density over every plaza. This does not prescribe H.E.X.'s camera, pipeline or collision.
3. [Supergiant — Hades FAQ](https://www.supergiantgames.com/blog/hades-faq/), updated 16 July 2025, read 15 October 2026. The developer describes optional character/story engagement alongside combat and a development structure shaped by player feedback. **Transfer:** the return after a short challenge can provide recognition and a useful next choice while remaining skippable. H.E.X. should validate that loop before expanding it. Hades' commercial reception does not establish causation or predict H.E.X.'s results.

These sources informed concrete choices; they do not justify cloning another game's content, expanding scope automatically or claiming proven commercial success. The prior overhaul document remains the deeper contract for asset economics, authority migrations and shipping gates.

## Cross-review record

- Gameplay reviewed this experience proposal and confirmed the six-element, cosmetic-height, continuous-door and captured-versus-live boundaries; the briefing/recap distinction above incorporates its implementation-scope correction.
- Technical source-approved navigation/map controller and tests at `6210c535` / `ac977a81` / `b6f499d8` / `220d58e3`. Root owns runtime and native acceptance.
- Experience reviewed Technical's draft and requested upper-bound wording for paired-bank memory arithmetic. During downstream launcher review, Experience found that the original Light invocation conflicted with the profiler's AllFixedSteps prohibition. Technical corrected it; exact launcher `501699f6` and pure test `88fcff54` were source-approved with honest Full/Light scope. No profile was run by Experience.
- Experience reviewed the Circuit model/result panel/tests: coherent compact action rectangles, distinct saved/session-only status, input-only intents and stable per-attempt focus; actual fonts, paid integration and native readability remain root gates. All three authored reward names should be covered by the prepared font checks.
