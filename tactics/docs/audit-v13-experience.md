# Experience review — rules 13

Reviewer: `overhaul_experience`. Reviewed the raw current interface, renderer,
spells, state, feedback, map generator and existing tests, rather than treating
the previous release report as evidence of ease or enjoyment.

## Findings and design decision

The game already contains enough interactions to support interesting decisions.
The largest experience gap is the path from understanding a turn to explaining
its result. The existing interface hides the objective in a guide, offers many
unfamiliar spell names before consequences, counts movement as a queued order,
and puts creature narration ahead of failed actions in the short result report.
The revision teaches one exchange, preserves reversible planning, and promotes
consequences without adding phases, currencies or a longer catalogue.

## Independent review of every area

| Area | Retain / change / defer | Acceptance evidence and limits |
| --- | --- | --- |
| Core identity | Retain simultaneous control of a shared elemental landscape; teach it through the first exchange. | A new player can describe the goal and why a field helps either team. Contextual guidance is implemented; human observation remains required. |
| Turn structure | Retain movement, spells, fields and scoring. Separate explicit cast/Guard decisions from safe fallback orders. | Readiness tests exclude movement-only orders and recovering characters. Root integration must preserve this through saved drafts. |
| Tactical choices | Reveal public consequences and landing dependence without claiming hidden rival orders are known. | Fizzle guidance requires an actual own fizzle; previews explicitly allow rival changes. |
| Elements and combinations | Retain all 63 exact fields. Present the resulting rule beside the actual planned spell. | Shared forecast continues to use natural ground, own orders and announced creature effects. Existing exact-chemistry tests remain applicable. |
| Spell design | Retain four configured spells plus signature; show effective damage, healing, control and allied exposure before expanded prose. | Effect-label tests use scaled values and distinguish harmful area effects from ally healing. Full conditional descriptions remain available. |
| Characters and races | Retain canonical art and identities. Inspect real combat statistics directly from the battlefield. Remove inherited promises of racial mechanics elsewhere. | Inspect mode opens the selected character without issuing an order. No racial stat differences are invented. World reviewer owns canon wording. |
| Team composition | Retain stable match kits; make each member's action completeness explicit. | Root integrates a ready count and next-character flow. No mid-match kit editor is introduced. |
| Progression | Retain Story-earned affinity and free reassignment of earned points. Explain the next useful choice rather than adding currencies. | Existing progression/reward tests; root/world inspect current threshold copy. Long-term progression motivation needs human play. |
| Resources and statuses | Keep bounded control and shared status vocabulary. Display actual Flux, status duration and current spell consequences. | Inspection reads the current unit, availability and effective spell. Status meaning still has full text in details. |
| Objectives | Teach occupied-well scoring and defeat points before the first commitment. | Guidance derives the victory threshold from the engine constant. Score and capture summaries derive actual state changes. |
| Map design | Retain large terrain patches and original environment assets. Prioritize visible relevant units and consequences over ornament. | Existing seeded prop/cliff tests and camera fit remain; parent owns visual browser checks. |
| Procedural generation | Retain repeatable seeds and mirrored terrain costs. Defer additional biome types. | Generator tests and route diagnostics, not decorative variety, establish navigability. |
| Balance | Do not equate equal affinity or deterministic seat symmetry with equal strength. Review Guard's absolute displacement immunity and inaccessible strong moves. | Systems owns rules 13 changes and adversarial fixtures. Match diagnostics are narrow evidence. |
| Story and encounters | Give each encounter a tactical purpose before extra exposition. Retain creatures as public landscape participants. | World agent owns encounter guidance and content audit. Narrative quality still needs reader/player response. |
| Opponent AI | Preserve public-state planning and counterplay. Improve decisions that demonstrate the rules instead of adding a fake personality layer. | Systems legal-plan, pressure and paired-match diagnostics; no hidden-plan access. |
| Multiplayer | Retain sealed planning, idempotent retries and immutable versioned engines. Make locked/waiting status unambiguous. | Root transport and two-seat HTTP validation. Presentation changes do not reveal opponent intentions. |
| Onboarding | Add brief nonmodal guidance that follows actual actions and retires after round three. | Opening/action/next/commit/fizzle/finished tests pass; mobile copy stays at or below 100 characters. Dismissal is controlled by root. |
| Interface | Promote one action flow and consequential results; avoid duplicate character inspection or repeated summaries. | In-place inspection is a fallback only when the root supplies no dialog callback. Root owns assembled layout. |
| Input and mobile | Preserve selection and cast semantics. Inspect must be a safe distinct mode; drag must not accidentally inspect or cast. | Renderer checks drag and active resolution before callbacks. Browser keyboard/touch journeys are required beyond pure tests. |
| Visuals and animation | Retain authored material silhouettes, anticipation and resolution timing. Do not add animation that obscures aim or statuses. | Existing motion, audio-clock and reduced-motion behavior preserved. New UI has no forced animation. |
| Audio | Retain optional material cues and restrained voice budget. Important failures already receive sound and now also receive visible report priority. | Existing scheduling/lifecycle tests remain. Listening quality is not established by code inspection. |
| Accessibility | Use named controls, visible effects and keyboard-operable Inspect. Keep the game understandable while muted or motion-reduced. | Named inspection/close controls and readable consequence text; actual screen-reader and physical-device evaluation remains pending. |
| Pacing and replayability | Reduce planning ambiguity and explain setbacks. Defer more phases, maps or currencies without evidence. | Root/systems full matches and planning journeys. Agent play is not evidence that humans prefer replay. |
| Validation and production | Exercise difficult interaction sequences, not only static layout and happy-path rendering. | Pure feedback/readiness tests plus parent integration, browser, production HTTP and publication checks. These do not establish market success. |

## Implemented presentation scope

- `battle-guidance-v13.ts`: explicit action readiness; short opening guidance;
  effective spell consequence labels. No game-state mutation or enemy prediction.
- `TurnCoachV13.tsx` and `experience-v13.css`: quiet, dismissible teaching surface;
  short phone copy, ordinary focusable 44px dismissal, no modal or forced motion.
- `feedback-v13.ts`: defeats, own fizzles/blocked movement, captures and real HP
  changes precede ambient reaction/creature narration. Duplicate blocked-move
  explanations are suppressed when the same unit's fizzle already explains it.
- `PixelBattlefieldV13.tsx`: Inspect can open a character's current statistics and
  spells. Normal movement/casting clicks are unchanged. Planned spell effects and
  field rules appear together, explicitly qualified by unknown rival orders.

Six focused tests passed at initial integration. Parent owns complete-suite,
assembled browser, phone, network and publication evidence. Retest after combined
rules changes; do not represent these focused tests as a complete release check.
