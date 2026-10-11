# Player surface and acceptance audit

Date: 2026-09-21. Scope: static, bounded inventory for the stabilization request; no engine, import, test, profile, capture or export was run by this worker. Only this audit file was written. Other workers share the checkout and own their changes. Original FLUX was not accessed or changed for this task.

Observed HEAD: `1559a566e33255c59337c5963f1c3c685d757f1f`. Existing checkpoint/runtime documentation names `p55-c7b7694f8d23`. This is not verification of a currently running process. No applicable AGENTS.md was found in the checkout (including hidden paths) or its checked ancestors. Read the new attached request, current specification sections on geometry, Loom, shared authority and preservation, the active queue, HEX-RESUME, HEX-PLAYTEST and HEX-SMALL-GRID-CHECKPOINT. The new request supersedes their old stop-after-playtest and all-options-available instructions.

## P0: ordinary Loom acceptance is missing

The production route is station activation -> `SpellLoomEditor.open_editor` -> Bootstrap modal input -> `_submit_spell_loom_choice` -> `_submit_whole_weave` -> local authority or client transport -> confirmation plus matching authority -> `_save_confirmed_weave`. Assign and drag/drop both use the whole-weave transaction; testing only legacy REQUEST_SPELL_EQUIP would miss it.

Concrete static risk: `bootstrap.gd:_handle_spell_loom_input` returns for every event while `pending_weave_request` is nonempty, before Escape, controller Back or close-button processing. `_complete_pending_weave` uses `world.tick`, and its observed callers are network state ingestion and matching acknowledgement. There is no ordinary per-frame wall-clock watchdog in this baseline. This establishes a recovery gap, not the user's exact reproduced cause. The equipping worker owns diagnosis and fixes. UI recovery must not revert an already accepted authoritative transaction; closing a panel and cancelling an authority request are separate operations.

| Existing evidence path | What it covers | Missing acceptance |
| --- | --- | --- |
| `tests/unit/test_weave_acknowledgement.gd` | Sequence/champion acknowledgement, later authoritative state, codec and manually advanced tick deadline | Harness disables Bootstrap startup/process/draw, manually arms pending state and overrides saving. No ordinary submission, wall-clock recovery, running modal loop or persistence restart. |
| `tests/unit/test_character_weave_integration.gd` | Thirty generated kits, bounded request validation, in-memory character restoration, legacy cooldown ownership | Persistence deliberately disabled; direct policy calls do not establish ordinary input -> request -> confirmation -> subsequent gameplay. |
| `tests/unit/test_spell_loom_editor.gd` | Slot/library encoding, filters/navigation, drag source/target and outside cancellation | Editor-level tests do not prove real Bootstrap orchestration, networking or usable gameplay after close. |
| `tests/visual/capture_gameplay_s4.gd` | Production panel/handler starter preview and apply on an inherited fixture; modal quarantine | Initial custom weave is directly applied, preferences are transient and opening is direct. Not native ordinary assignment -> movement/cast -> disk save -> process restart. Historical fixture evidence cannot certify this build's route. |
| `tests/visual/capture_station_bindings.gd` | Binding labels and native station rendering on a fixture | Explicitly no network or audio, transient preferences; labels are not action completion. |
| `docs/verification/hex-small-grid-20260921/native/receipt.json` | Actual paid Water/Fire/Steam native scenario | No complete ordinary Loom, character-switch and persistent restart journey. |
| `docs/verification/hex-small-grid-20260921/package/receipt.json` and `package/zip-audit.json` | Prior package identity, launch/close and ZIP integrity | Launch and archive integrity do not prove equipping or all exposed options. |
| `docs/verification/hex-small-grid-20260921/network/receipt.json` | Same-export lifecycle attempt | FAILED unchanged 300-second deadline; later round/stewardship completion not established. |

### Smallest useful lead-owned P0 gate

First retain a failing ordinary-input reproduction on baseline source and the existing EXE, each with isolated APPDATA. Use a fresh profile and a safely copied user reproduction profile if the fresh case does not reproduce. Record exact build, profile-copy hash, input timeline, wall clock, world tick, pending sequence/context, modal state, acknowledgement/state arrival, save result and stderr. Classify exception, lock, stall, stale UI, invalid state and persistence separately.

Then repeat against fixed source and the frozen exported candidate:

1. Enter the actual Spell Loom from the ordinary station. Select a filtered spell and one position in each base/Ctrl/Alt group; assign using actual modal input. Also execute one drag/drop and one existing-spell swap. Observe actual authority confirmation, with no direct final-state injection.
2. Close via Escape, close button and controller Back representatives. Freshly press movement and cast input: verify position changes, correct wire releases, Flux payment, cooldown ownership and no held-input leakage. Reopen and compare displayed and authoritative slots.
3. Save, safely quit, restart the process with the same isolated profile, and verify exact restored weave; switch character and back. Hash real personal profiles before/after to show isolation.
4. Hold simulation tick fixed in a controlled regression and test missing acknowledgement, acknowledgement-before-state, refusal, disconnect, late/duplicate/stale response, focus loss, rapid repeat and changed character/session. Close must recover on wall clock; retained authority must remain valid and accepted changes must not be falsely undone. Force save failure separately: usable session state, honest unsaved feedback, previous disk bytes intact.
5. For every enabled wire, data-drive all 12 positions through request/confirmation and a paid cast; test actual base/Ctrl/Alt input chords for each position and representative keyboard/controller/filter/drag paths. Preserve unique spell identity, stable wire mapping and per-spell cooldowns. Existing direct model tests remain useful supporting coverage.

The receipt should identify input-generated transitions, authoritative outcomes and persisted restart results independently. A screenshot or directly applied loadout cannot satisfy these assertions. Multiplayer acceptance still needs the unchanged full same-export lifecycle; UI recovery tests do not clear that gate.

## P1: visible surfaces and evidence status

“Enabled” below means exposed by baseline source, not accepted for this milestone. Every row needs mode-specific executed evidence before being marked accepted.

| Feature | Mode / player action | Expected outcome | Source / existing evidence | Enabled / blocked status |
| --- | --- | --- | --- | --- |
| Spell assignment and starters | Offline/host/client; select, assign/drag, preview/apply | Valid atomic weave, correct wire/slot, clear result, gameplay resumes | `spell_loom_editor.gd`, `spell_loom_presenter.gd`, Bootstrap handlers; P0 table above | Exposed; current user failure blocks acceptance |
| Cast 32 catalog spells | Gameplay modes; 12 positions and held Rapid | Correct paid release, refusal, effect, expiry and cooldown | `combat_tuning.gd`, `combat_system.gd`, `input_router.gd`, paid chemistry suites | All catalog choices exposed; no inspected evidence proves every enabled spell's complete player journey |
| Character selection/restoration | Gallery; choose profile, return to prior profile | Correct actor/template and retained per-character configuration | `character_weave_coordinator.gd`, `character_weave_library.gd`, `test_character_weave_integration.gd` | 30 profiles exposed through three body templates; no 30-finished-skins claim; ordinary persistence acceptance missing |
| Movement/rebinding | Move, sprint, slide, jump/Float/dodge; Controls Lectern | Intended movement/cost; effective binding and restart restore; safe modal/focus recovery | `input_router.gd`, Bootstrap control handlers, movement/controls suites | Exposed; historical automated evidence is not fresh full journey acceptance |
| Practice/reset | Playground pair/demo, targets, Momentum Chime, Reset Wellspring | Paid demo; correct target lifecycle; permitted reset retains weaves and clears paid state | `hex_playground_demo.gd`, `hex_playground_panel.gd`, Bootstrap handlers, `session_request_policy.gd` | Exposed with scattered host/free-practice restrictions; no claim all pairs/counters accepted |
| Settings/accessibility/audio/zoom | Controls/settings and hotkeys | Visual/audio change now, correct persistence, no authority change | Bootstrap `_commit_control_bindings`, sound/accessibility helpers; visual capture fixtures | Exposed; native settings -> restart and physical audio acceptance require separate evidence |
| Multiplayer | Host/join, ready, reconnect, spectate, rematch, leave, steward controls | Complete same-build lifecycle, truthful state and recovery | Bootstrap station/transport handlers; network receipt above | Offered; milestone acceptance BLOCKED by failed same-export lifecycle |
| Help/compendium/station prompts | Read/select sections and use described actions | Accurate capability, mode restriction and configured-binding explanation | `player_compendium.gd`, `spell_loom_presenter.gd`, `_station_lines`, interaction presenter | Baseline says all 32 available/selectable and advertises shared play; needs shared-policy projection |
| Launch/close/install/update | Run.cmd or packaged PLAY-HEX.cmd; normal close | Correct build, safe shutdown, intact PCK/profile | Small-grid package/ZIP receipts | Prior local launch/close supported; new candidate requires fresh export evidence. Installer/updater not supplied/accepted here |

## Small shared policy recommendation

Add one pure `PlayerAvailabilityPolicy` with a canonical feature/wire record and a context projection. Distinguish build/mode acceptance (`accepted`, `experimental`, `failed`/`not_run`) from temporary state restrictions (`pending`, `wrong_station`, `round_active`, `disconnected`, actor unavailable). Return enabled/reason/status/evidence key; avoid a single overloaded bool. Evidence belongs to a frozen manifest tied to a source/package identity, not automatically to catalog membership. Admission must use the same policy decision as display, and deterministic authority inputs must not depend on UI wall time or filesystem reads.

Smallest first integration is Loom + casting + its starter/help projections; then station/session actions. Do not introduce separate UI and authority allowlists. Proposed insertion points, requiring explicit ownership before edits:

| Consumer | Existing seam | Required behavior |
| --- | --- | --- |
| Spell selection/panel | `SpellLoomEditor.configure_for_catalog`; `SpellLoomPresenter.draw_panel` | Stable wire IDs; status/reason on gated choices; replace hardcoded “All 32 spells remain available” |
| Starter preview | `CharacterStarterKit.build`; `prepare_starter_preview` | Same accepted subset; never silently overwrite saved unsupported wires |
| Assignment authority | `CharacterWeavePolicy.apply` plus Bootstrap request context / `SessionRequestPolicy.validate` | Structural validation remains separate from mode acceptance; reject invalid new choice atomically |
| Cast input and authority | `InputRouter.sample`; `CombatSystem.step_player` admission | Consistent visible refusal and authoritative refusal without spending; client cannot bypass UI gate |
| Save/restore | `CharacterWeaveCoordinator.restore_actor`, library | Preserve all stable saved IDs/bytes; explain retained gated entries rather than delete/migrate them silently |
| Help/stations | `PlayerCompendium.spell_catalog_lines`, Bootstrap `_station_lines`/activation | Same status/reason for each advertised route; experimental multiplayer is not marketed as accepted |

Critical constraint: current `CharacterWeavePolicy.apply` requires exactly 12 unique runtime wires. The starter builder fills eight Bolts, one Heavy and three Rapid/Spray experiments. A four-spell allowlist alone would make valid twelve-slot requests impossible. Keep all twelve positions. Either prove at least twelve unique wires for an accepted starter or explicitly separate retained-but-gated slots from accepted cast/equip admission without destructive save migration. Do not manufacture twelve entries by duplicates, silently grant untested spells, or treat a hidden menu as a multiplayer fix.

Prioritize Water/Earth/Fire/Air. Which wires become accepted is a gate result, not this audit's declaration. The inspected receipts alone do not establish a fully proven twelve-wire subset. Establish P0 before content expansion; shared policy changes must include the migration/retained-slot decisions and corresponding tests.

## Handoff and risks

No runtime/UI change is proposed as already integrated. Root owns Bootstrap and all engine work; equipping/state worker owns its assigned files. This audit's only artifact is this file. Next smallest action: ordinary baseline reproduction plus targeted loadout/recovery regression, then the lead-run fixed-source journey. Follow with one shared availability-policy slice after interfaces/ownership are assigned.

Main risks: recovery falsely rolling back host acceptance; stale responses crossing actor/session boundaries; cooldown laundering through remove/re-equip; filtering changing canonical wire encoding; unsupported saves being discarded; policy denying all valid twelve-slot weaves; legacy alias/direct command paths bypassing UI gating; misleading evidence inheritance across source/export identities. Full pass, imported artwork and catalog count cannot clear these risks by themselves.
