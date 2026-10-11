# Player understanding — compact HUD, useful stations, one reference

**Status: PROPOSAL, informed by supplied source.** The HTML is a design prototype, not the Godot UI. Current facts use [SOURCE_REFERENCES.md](SOURCE_REFERENCES.md); proposed wording and acceptance targets are labeled here. The first-four chemistry review from another chat was not supplied and has not been assumed.

## Resolve source drift before teaching a player

| Conflict | Evidence to use | Integration decision |
|---|---|---|
| Old movement notes teach Q evade and earlier active attacks | Newer README lines 265–319 documents B evade, V technique, Q free; E remains configurable legacy active spell | Read the actual profile/action resolver. Do not overwrite a custom binding or turn an old document into a live prompt. |
| Campus champion prompt says E | README describes Interact F by default and device/rebinding-aware prompts | Show the resolved Interact action, not a literal E/F baked into a sprite. |
| Campus spell-loom copy says Spray does not deposit | Newer README and supplied chemistry authority describe finite ground-target ingredients from surviving paid Spray pulses | Correct presentation copy only after hooking the current data source; do not remove working Spray chemistry. |
| Mouse attacks appear bound | Punch/Kick gameplay is staged and unavailable in the supplied S4 checkpoint | Teach numbered spells, not left/right click as an available attack. |
| Catalog Steam/Dustfront describe obscuration | Effective policy/adapters implement transparent first-four pressure/push | Read effective policy plus adapter, not catalog themes. Steam is escalating scald, not hiding smoke. |
| Old visual prose lists other body heights | Active baked sheet manifest/presenter uses 58/63/68 | Keep the active body contract; do not apply baked scaling twice. |
| Weave appears configurable | README states personal weave is not persisted in current runtime, while settings/bindings are | Do not show an unqualified “Saved” or promise next-session restoration. |

[S02, S06–S09, S12]

## HUD: one active layer, context only when needed

Keep world orientation and session state at the top; health/Flux/stamina bottom-left; four active slots bottom-right. Each slot needs number, spell name, family, element/material cue, current cost/availability and rejection/cooldown state from runtime. Color is supplemental to name and shape. The native composition uses sample values and abbreviated sample slots; it is not a complete final HUD binding implementation.

| Component | Proposed 1280 × 720 placement | Behavior and readable state |
|---|---|---|
| Place / reference | x16,y14,w414,h46 | “The Wellspring / Chemistry Courtyard”; resolved access hint. Avoid a permanent paragraph. |
| Company chip | x1032,y14,w232,h46 | Offline, joining, connected count, or reconnecting; never fake Ready from a local click. |
| Context card | x16,y81,w254,h72 | At most one nearest station prompt, or one selected reaction explanation. Hidden when irrelevant. Never says “safe” solely because a menu is open. |
| Resources | x16,y628,w282,h78 | Numeric current/max and labels. Keep stamina legible during escape. |
| Four slot cards | x616+162i,y639,w155,h67 | One of Plain/Ctrl/Alt; unobstructed name, binding, family and authoritative availability. |
| Layer strip | x616,y610,w334,h23 | “Plain / Ctrl / Alt”; other layers discoverable without twelve permanent large cards. |

These illustrative panel rectangles occupy about **12.9%** of the 1280 × 720 image, excluding shadows/text outside panels; this is geometry, not a measured production HUD statistic. Proposed target: ordinary persistent HUD under 15% of that frame and a clear central play area. A full reference panel is a separate deliberate modal, not an always-on overlay. At larger UI scale, reflow rather than reducing text below legibility. Verify the existing reserved top strip and camera rules before adopting exact rectangles.

The screenshot `07-ui-reference-1280x720.png` is rendered from the offline reference prototype. Its page header is a review shell, not a proposed in-game header. `preview/index.html` includes an 8 × 8 selectable matrix, detail panel, station/movement summary, modifier-layer example and Company state mock. Full matrix details for the first ten pairs come from the inspected effective policy. Later-four cells retain catalog names and wire IDs and explicitly withhold unreviewed behavior; they are not disabled in the game.

## Inputs and layers

Source defaults: WASD move, mouse aim, Shift sprint, Space/wheel up jump/hold/Float, C/wheel down slide/hold/fast fall, B evade/air dodge, V technique, F Interact, numbered spell positions, T speech, R reset and fixed F4 compendium. F8–F11 are documented view actions. Do not introduce a map key or remote-management key and call it live. All configurable action prompts must resolve rebound controls and active device; do not use the literal default as the persistent asset label. [S08]

| Layer | Positions | Conflict / focus rule |
|---|---|---|
| Plain | 1–4 | Default four visible slots |
| Ctrl | Ctrl+1–4 | Shows slots 5–8, without moving their four physical card positions |
| Alt | Alt+1–4 | Shows slots 9–12; Alt wins when Ctrl and Alt are both held |
| Controller, selected P48 description | D-pad directions; LB/RB modifier layers | RB wins with both held. Custom/partial profiles remain authoritative; do not assume the older portable uses this layout. |

After a modal or Alt-Tab, require release and a fresh press for paid actions. Directional movement may resume under current rules. Clear displayed held-modifier state on focus loss; do not cast as a side effect of selecting a reference cell. The world continues while the local input is modal. The HTML exercises layer display and input-state cleanup only; it does not execute the game's input resolver or paid-action gating. [S08]

## Four delivery families: choose a tool, not four tutorial lanes

| Family | What supplied source establishes | Useful courtyard comparison | Do not imply |
|---|---|---|---|
| Bolt | Paid projectile; actual terminal position deposits an ingredient; bounded optional trail allocation | Aim at the same open ground endpoint, then change approach angle behind a shoulder | Trail is free material or guaranteed along the entire flight |
| Heavy | Paid heavier projectile family with actual terminal deposit and bounded optional trail allocation | Compare commitment/arrival against a target that can choose either exit | Larger visual size grants a new map collision or universal immunity bypass |
| Rapid | Repeated paid projectiles, actual terminal deposits, no persistent trail | Strafe through the courtyard while keeping aim, stop to inspect finite endpoint ingredients | A continuously painted floor trail |
| Spray | Surviving paid pulse deposits one finite ingredient at its ground target within reach | Compare nearby aim/reach and endpoint formation without projecting a trail | “No deposits,” free repeated material or infinite reach |

Bolt/Heavy may allocate up to 150 of their 600 paid material units to trail according to the supplied README; this is not extra material. Every attack spends positive Flux; no automatic refill or tutorial cast exemption is introduced. Actual family costs, cadence, resource regeneration and delivery-dependent strength must be read from current runtime data. The missing combat-tuning/input dependencies prevent promising complete cost/firing-time values here. [S06–S08]

## Source-derived first-four chemistry table

The following durations are effective source policy at 120 ticks/s, **not proposals**. They are formation / active / decay, not total travel time. Selection shapes choose whole eligible cells; they do not remain analytic damage boundaries. Reverse ingredient order maps to the same recipe identity, although source, aim, amounts and placement can still differ. Product action summaries are conditional on current protection, ownership, height and phase rules. Full dependencies and human acceptance remain pending. [S06–S07]

| Pair → result / wire | Selection | F / A / D ticks (seconds) | Action and counter |
|---|---|---|---|
| Water + Water → **Flood** / 316 | disk 64 px | 24/360/60 (0.2/3.0/0.5) | Grounded directional flow; jump or leave the current. |
| Water + Earth → **Mud** / 303 | disk 77.5 px | 24/390/42 (0.2/3.25/0.35) | Ordinary-ground acceleration and braking become 70%; target speed unchanged. Leave to restore. |
| Water + Fire → **Steam** / 310 | disk 64 px | 24/360/60 (0.2/3.0/0.5) | Transparent escalating scald through height 48 px. Leave; a fresh Water cast can cool once. A low hop is not immunity. |
| Water + Air → **Mistcurrent** / 317 | sector length 200 px | 27/330/48 (0.225/2.75/0.4) | Wet directional steering with finite suppression; jump or exit laterally. Not concealment. |
| Earth + Earth → **Rampart** / 301 | disk 34 px selecting hex pillars | 22/375/48 (0.1833/3.125/0.4) | Temporary breakable six-face cover; go around, break or wait. No assumed vaulting. |
| Earth + Fire → **Magma** / 302 | sector length 100 px | 42/330/60 (0.35/2.75/0.5) | Grounded hostile damage; ordinary-ground target speed 75%, no after-exit slow. Jump or leave. |
| Earth + Air → **Dustfront** / 304 | sector length 150 px | 30/270/42 (0.25/2.25/0.35) | Transparent lateral ground push; jump or exit sideways. |
| Fire + Fire → **Conflagration** / 309 | disk 64 px (not catalog ring) | 24/360/60 (0.2/3.0/0.5) | Grounded burn pulses every 72 ticks. Leave/jump during warning. |
| Fire + Air → **Firestorm** / 311 | sector length 162.5 px | 42/270/42 (0.35/2.25/0.35) | Moving damaging route cut; use lateral exit or solid cover. Do not promise a low-hop dodge. |
| Air + Air → **Vortex** / 322 | annulus inner 30 / outer 90 px | 48/330/48 (0.4/2.75/0.4) | Grounded tangential push; use an actually unselected opening, jump or leave. Analytic center is not automatically safe after whole-cell selection. |

Magma movement affects eligible unprotected actors, while its damage adapter filters hostile unprotected actors. The inspected Flood/Conflagration root loop and Steam pressure path do not supply a blanket self/allied exclusion. Do not teach a teammate to stand in them as if friendly fire rules guaranteed safety. Steam exposure is capped and sheds outside the field; a low hop below its 48 px height envelope is not immunity. A fresh Water cast can cool the current Steam channel once under source rules, not erase every overlapping product.

The product adapters gate active effects between active and decay ticks. Depict formation as warning, active state as danger, and decay as fading spent material. End-of-life and pre-existing actor state must still be checked at the exact boundary; a fading sprite is not sufficient authority. Do not promise an automatically safe analytic Vortex center after whole-cell selection.

## Station design and remote-party management

Keep commands, authority, station positions and interaction radii in the pilot. Replace repetitive presentation, not the underlying functional anchors. At most one nearest eligible station gets a short world prompt; the panel supplies the longer instruction, accessible label and current binding. A new global Company tab under the existing F4 entry is **PROPOSED**; its authority and any permitted remote invocation must be approved, not implemented by bypassing proximity checks.

| Existing station ID | World px / radius | Existing command / authority | Proposed functional object / short label |
|---|---|---|---|
| `movement-guide` | (1216, 640) / 96 px | `movement_guide` / local | Footstep relief / Movement |
| `training-reset` | (1888, 1376) / 96 px | `training_reset` / host | Distinct reset bell / Reset practice |
| `momentum-chime` | (832, 928) / 72 px | `impact_practice` / host | Impact chime / Movement feedback |
| `champion-loom` | (1568, 640) / 96 px | `champion_switch` / host | Standing mirror / Champion |
| `spell-loom` | (1744, 640) / 96 px | `configure_spells` / host | Brass weave frame / Spells |
| `farflow-host` | (1216, 1008) / 88 px | `host_session` / local | Outgoing pennant / Host |
| `farflow-join` | (1392, 1008) / 88 px | `join_session` / local | Incoming pennant / Join |
| `farflow-charter` | (1568, 1008) / 88 px | `session_charter` / local | Seal / Rules |
| `session-hearth` | (1744, 1008) / 92 px | `session_hearth` / host | Lantern / Ready |
| `company-ledger` | (2016, 896) / 72 px | `session_ledger` / host | Roster plaque / Company |
| `parting-bell` | (2016, 1056) / 72 px | `session_parting` / host | Guarded bell / Parting |
| `controls-lectern` | (1392, 640) / 96 px | `configure_controls` / local | Key-and-stick plate / Controls |

The learning canopy is a destination with four clearly different objects, not a single ambiguous mega-interaction. The Farflow rail groups six small function-specific cues while retaining all six anchors. The movement chime and reset bell stay visually distinct: sound feedback is not a reset command. An icon supplements accessible text and focus order; hover-only tooltips are insufficient for controller users.

| Party operation | Proposed UI contract | Authority / failure handling |
|---|---|---|
| Host / Join | Connection state, editable address, explicit submit and cancel; address can be copied without exposing unrelated secrets | Existing local commands initiate service actions. Display pending until actual result; do not claim Internet reachability merely from LAN hosting. |
| Rules | Readable compact current charter; editable only when the actual permission allows | Rejected updates leave acknowledged rules displayed and explain the refusal. |
| Ready / gather | Show own requested versus acknowledged readiness; host sees actual participant state | Preserve current host-authority station semantics and ordered gather spawns. A client request path is a design integration question, not a newly assumed command. |
| Company roster | Stable peer identity, host role, connected/reconnecting/not-ready states | Observer/client inspection must not enable host-only administration. Do not display invented latency measurements. |
| Parting | Select a named traveler, separately arm, then confirm within the existing three-second window | Selection alone never dismisses. Cancel/timeout removes armed state. Host revalidates peer identity, membership, authority and session generation before execution. |
| Disconnect / late join | Clear pending operations, keep the next legal action visible | No orphan modal, duplicate gathering, stale selected peer or accidental action on a newly reused ID. |
| Panel safety | Explicit “world continues” state; escape closes, focus loss clears paid input latch | No pause, invulnerability, free casts, proximity bypass or auto-reset. |

The prototype's Host/Join/Ready/acknowledgement/Parting buttons change local demonstration text only. No packet is sent, no session is hosted and nobody is removed. The existing campus definitions are evidence of command fields, not proof that every service path works. [S02–S03, S08, S12]

## Five-minute first session — target flow, not a measured run

| Time | Place and task | Desired understanding / fallback |
|---|---|---|
| 0:00–0:30 | Arrive at shared spawn. Identify the flush fountain, the distinct mirror/loom north and the Farflow pennants south. Point toward movement and duels without opening a long tutorial. | “I can return here.” No world-coordinate overlay or hex-step tutorial. Missing new art in a runtime build is a test failure, not assumed present. |
| 0:30–1:15 | Walk continuously into the existing crucible. Strafe while aiming at the target; optionally sprint, slide and change direction around either shoulder. | Travel and aim are independent; neither exit requires advanced tech. Resolve controls from profile. No requirement to master a wall technique. |
| 1:15–2:15 | At the preserved firing anchor, use two separately paid Water/Fire terminal casts at the same reachable ground endpoint. Observe warning, active scald and expiry before stepping into a second attempt. | Two paid ingredients cause a whole-cell result; actual endpoint is not snapped. Use the existing available loadout/loom; do not auto-overwrite the player's twelve slots. If affordable casts are unavailable, wait under normal resource rules or observe the host's paid demonstration. |
| 2:15–3:15 | Repeat once. Choose northwest wrap or southeast cutback before danger rises; then compare ground Magma by looking at the reference. A consenting opposing peer can test one brief contact; otherwise observe. | Steam is not concealment or low-hop immunity. Ground-dependent Magma encourages jump/exit. Damage rules need a hostile fixture; do not pretend a self-cast demonstrates hostile damage. No forced injury or unsafe reset. |
| 3:15–4:00 | Open Company via the proposed reference tab or use existing Farflow stations. Solo: inspect Offline and Ready prerequisites. Remote: submit Join/Ready and distinguish pending from acknowledged state. | Management does not require gathering around one tiny prop once an approved remote path exists. Offline players are not blocked on finding a friend. |
| 4:00–5:00 | Follow the east return toward the existing duel court. With a ready consenting peer, enter the existing duel flow; solo, use the pattern target or return west and repeat the escape choice. | End with a self-chosen next activity and a recognizable route home, not another instruction board. Full duel completion is not required inside five minutes. |

These are facilitation budgets totaling 300 seconds, not measured traversal/connection times. If walking, profile editing or network connection consumes the budget, record the delay rather than teleporting, granting resources or claiming completion. The acceptance task measures whether a new player can identify and take both exits, explain Steam's danger and find party state within five minutes; the first duel may occur afterward.

## Readability hierarchy

Quiet floor is background; selected material is the affected ground; feet/body/aim are the actor; projectile material/direction is the immediate threat. Avoid heavy global grid contrast and broad hazes. Put the danger cue inside every selected cell, retain its boundary when overlapping, and distinguish Steam curls from Magma cracks even in reduced effects. Do not let state labels or silhouettes imply all overlaps share one owner or expiry. If independent overlapping coverage cannot be read at native scale, reduce decorative motion first—not actor visibility, authoritative coverage or action information. Native stills demonstrate a candidate composition only; the eight-player moving test remains mandatory.
