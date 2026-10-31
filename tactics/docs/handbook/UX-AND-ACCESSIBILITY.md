# UX and accessibility

This document describes the current release 45 interface and the contracts to preserve when changing it. It is a developer handoff, not a claim of WCAG conformance or a completed assistive-technology audit. For state, networking, and compatibility boundaries, see [Architecture](./ARCHITECTURE.md).

## The decision loop

The interface supports a small repeating sequence:

1. Select a fighter.
2. Choose its intended landing.
3. Choose a spell and fixed aim, or Guard.
4. Review the squad's queued orders and commit.
5. Watch movement, simultaneous casting, effects, and results.
6. Inspect consequences before making the next plan.

The design intent is to make each decision understandable without adding a confirmation modal to every normal turn. The implementation keeps local drafting, inspection, and replay separate from committing an order. Missing orders use the mode's Guard behavior; command summaries expose that rather than implying every fighter has an offensive action queued.

The principal hosts are [`CampaignGameV20`](../../app/components/CampaignGameV20.tsx), [`SkirmishGameV18`](../../app/components/SkirmishGameV18.tsx), and [`TowerBattleV23`](../../app/components/TowerBattleV23.tsx). [`BattleCommandV41`](../../app/components/BattleCommandV41.tsx) and [`PixelBattlefieldV16`](../../app/components/PixelBattlefieldV16.tsx) supply shared planning presentation.

## Layout and visual priority

| Surface | Current arrangement | Preserve when editing |
| --- | --- | --- |
| Desktop battle | Friendly fighters/actions on the left, battlefield in the center, rivals on the right. | Selected fighter, legal options, and commit controls must remain easy to find. Do not cover the relevant board area with repeated explanations. |
| Narrow battle | The board and bounded order panel stack; the primary action remains available through the compact/sticky command layout. Short landscape also keeps a one-line selected-action consequence beside the action set. | Keep controls reachable at small height. Internal scrolling is intentional where content exceeds the panel; there is no universal “no scrolling anywhere” guarantee. |
| Tower route | Full-width route overview, reachable room cards, and one selected room detail. | Every lane/path should fit the overview. Small overview nodes have equivalent large room-card controls. |
| Character/loadout menu | Current build, affinity, equipped spells, and inspected catalogue choice remain together. | Selection must show legality and consequence before replacing a slot. |
| Guide | Compact comparison tables with filters/paging and optional detail cards. | Keep scanning useful; move timing/examples into inspection rather than repeating every rule in each row. |

Focus and overview serve different purposes. Overview shows formation and threats; focus keeps an individual fighter and its conditions readable. Movement and casting use distinct boundaries/markers, while names, shapes, status labels, and numbers supplement elemental color.

Natural ground, temporary elemental fields, and decorative scenery are different information layers. Do not make decorative movement resemble a hazard, walkable gap, or active targeting cue. Walls must read as blocking geometry. Current planning-field animation is bounded and applies to temporary fields; it is not blanket scenery sway.

The intended art direction is coherent pixel characters, environment, effects, and advanced-element icons. This is a design requirement; it does not establish that every asset is artistically finished. Inspect assets at their actual displayed scale as well as at source resolution. Spell choices pair their element icon with a small area-shape glyph, so players can compare targeting patterns before selecting one; the accessible name spells out the shape, and the board remains authoritative for the exact affected hexes.

## Input behavior

| Task | Pointer/touch | Keyboard |
| --- | --- | --- |
| Choose fighter/action | Click or tap its ordinary button. | Tab to the button and activate it. During eligible planning, `M` selects movement, `G` Guard, `U` Undo, and `1`–`5` select the available spell positions. |
| Inspect a tile/fighter | Hover with a mouse; use board inspection/tap controls for a persistent view. | Focus its tile or inspection control. Board cells use a roving focus target, not hundreds of consecutive tab stops. |
| Navigate the hex board | Click/tap tiles; drag-pan in focused view; explicit view/pan controls remain available. | Arrow keys navigate four axial directions; `Q` and `E` provide the other two. `Enter`/`Space` activates the focused tile. `Home` focuses the center. |
| Inspect a status, element, rule, or spell | Hover opens a detail card; tap pins it. Tap outside or use its close button to dismiss. | Focus opens the same information; `Escape` dismisses it. The close button restores trigger focus. |
| Reorder equipped spells | Drag an eligible spell to a slot on desktop, or use slot/spell buttons. | On an equipped slot, `Alt` + Left/Right moves it to the adjacent slot and preserves slot focus. |
| Review resolution | Use playback buttons and speed choices. | The same controls are ordinary focusable buttons. |

[`input-v7.ts`](../../lib/input-v7.ts) rejects single-key game shortcuts while editing text, composing input, using browser modifier shortcuts, or repeating a held key. Hosts additionally disable them during inspection/modal states and when planning is unavailable. Preserve these guards when adding shortcuts.

The board's pan gesture has a movement threshold so dragging does not also issue a tile command. Do not assume that pinch zoom or a native mobile drag gesture exists merely because mouse drag works. Required operations have ordinary buttons/taps.

## Loadouts: legal choices with fewer operations

[`TowerCharacterBuilderV23`](../../app/components/TowerCharacterBuilderV23.tsx) and [`CampaignWorkshopV20`](../../app/components/CampaignWorkshopV20.tsx) use [`useSpellDragV45`](../../app/components/useSpellDragV45.ts) and [`loadout-interaction-v45.ts`](../../lib/loadout-interaction-v45.ts).

- Four equipped spell slots are configurable; a champion's own signature remains separate.
- Affinity, learning, and signature restrictions determine availability. A visible spell is not necessarily an eligible replacement.
- Placing a spell already equipped swaps slots. Placing a different eligible spell replaces the selected slot.
- Drag is a shortcut, not the only method. The Tower builder supports slot-then-spell selection; the Story workshop supports selecting a slot, inspecting a spell, and equipping it.
- The drag payload is an allowlisted spell ID with the application-specific drag type. External text/URLs are not interpreted as spells.
- Placement and final build validation still enforce legality. Disabling a visual drag source alone is not validation.

Creature kits are fixed and should not be described as champion loadouts. Tower supplies are also separate: a charm/scroll belongs to one fighter and has its own mode-specific rules. A scroll uses a normal cast action; do not make its extra button suggest an extra free action.

## Information before committing

The command panel should answer four questions: **where will I try to finish, what can I cast there, what is known to happen, and what remains conditional?**

| Readout | What it means | What it must not imply |
| --- | --- | --- |
| Movement outline/path | Legal movement effort and route under the visible state; ice slide and blocked/contested landing information when known. | A guarantee that an opponent will leave a destination free. |
| Casting range/shape | The current fighter's effective spell, selected landing, saved spell model, and applicable status/terrain modifiers. | Printed catalogue range when current affinity, Blind, high ground, or a scroll changes it. |
| Center/inner/rim profile | Deterministic focused-area strengths. “Centre crit” is used only when the center actually has a stronger contribution. | A random critical-hit chance or identical damage across the area. |
| Known-volley prediction | Current permitted allied orders and visible fields, including known projectile meetings. | Knowledge of sealed enemy movement or attacks. |
| Damage/Guard alternatives | Conditional outcomes for the stated target assumptions. | A guaranteed whole-exchange health total. |
| Displacement | Conditional landing/impact outcomes, including blocking and known protections. | Certainty if the target dies, moves, or another unresolved action changes occupancy. |
| Enemy reach overlay | Public movement/attack capability. | The enemy's chosen order or a private AI plan. |

The shared preview helpers are linked in [Architecture](./ARCHITECTURE.md#native-data-and-presentation). A new spell mechanic is incomplete until its native result, preview, command text, and inspection agree. In particular, Tower scroll previews use the native per-order adapter rather than affinity-scaled equipped-spell values.

Keep the short visible conditional caveat. More precise assumptions belong in its detail card. Removing uncertainty wording to save space would make the interface less truthful.

## Resolved information and pacing

Resolution displays movement first, then simultaneous casting and projectile contacts, followed by effects and results. The base playback lasts 6.9 seconds; boundaries are shared through [`feedback-v16.ts`](../../lib/feedback-v16.ts). These are presentation times, not staggered game turns.

[`PlaybackControlsV44`](../../app/components/PlaybackControlsV44.tsx) offers pause/resume, next-phase stepping, speed choices, and immediate results. Reviewing an exchange is local: it does not submit orders or hold the cooperative floor barrier. Competitive Arena still has a server planning deadline; a local pause does not pause that server clock.

Health, statuses, accessible tile descriptions, and callouts follow the appropriate displayed snapshot so the movement phase does not announce damage that has not yet been shown. Consequence summaries use actual resolved events to distinguish direct damage, protection, healing, status changes, and environmental consequences.

[`CharacterSpeechV45`](../../app/components/CharacterSpeechV45.tsx) and [`character-reactions-v45.ts`](../../lib/character-reactions-v45.ts) add limited character reactions from known outcomes. Reactions are constrained by phase, cooldown, and available space. They must not announce an unknown miss, attribute environmental defeat to a caster without evidence, or cover the important damage/status result.

Humor is secondary feedback. A joke must never be the only explanation of a rule, error, loss, or irreversible decision.

## Tower route and cooperative decisions

[`TowerRouteMap`](../../app/components/TowerRouteMap.tsx) displays three to eight regular lanes according to the saved launch player count. All route paths fit the overview without horizontal map scrolling. The reachable room cards are the larger touch/keyboard controls; [`TowerRoomPreviewV43`](../../app/components/TowerRoomPreviewV43.tsx) shows one detailed preview.

**Previewing is not committing.** Selecting a card changes the inspected room; its action chooses the destination. A newly committed destination synchronizes the preview once, but subsequent browsing can inspect another room without withdrawing or changing the commitment.

Friends' destinations are shown in the party area and on room cards. Card names can ellipsize for stable spacing; full labels/names remain available in the party area and accessible descriptions. The primary room action distinguishes joining friends, choosing a room, changing destination, and the already chosen room.

Before the group launches:

- A player may switch directly to another reachable room.
- Withdrawing the selected destination permits scouting and squad changes again.
- Each champion can scout one aspect of a room on that floor; creatures do not grant extra scouts.
- Partial clues, reports, costs, and reward types inform choice without revealing every hidden encounter/reward detail.
- Reports must match the actual encounter variant. A companion's perk and moves are decision information; a hidden enemy's unrevealed kit is not.

Choosing the same room means fighting on one map with separate ownership of each squad. Choosing different rooms means separate battles, followed by a shared floor barrier. The squad strip lets players watch a friend's state; watching never grants command authority.

[`TowerFirstClimbV44`](../../app/components/TowerFirstClimbV44.tsx) is optional help at this decision point: landing/aim, the consequence of meeting projectiles, and choosing recovery versus future power. It does not restrict the legal two-character custom start.

The interface separates “waiting for combat orders,” “choosing rooms,” and “at the stairs.” Do not replace these with an unexplained global waiting spinner.

## Guide and details

[`CombatReference`](../../app/components/CombatReference.tsx) and [`combat-reference.ts`](../../lib/combat-reference.ts) provide five tabs:

| Tab | Comparison purpose |
| --- | --- |
| Elements | Six tactical roles, tradeoffs, advanced branch identity, and magical ground. |
| Mixtures | Recipes, full resulting field, duration, and risks to either side. |
| Spells | Affinity requirement, Flux, reach, cooldown, footprint, effects, and learning/access context. |
| Map & aim | Natural ground movement/effects and spell targeting forms. Natural Water/Earth are not interchangeable with active Flood/Rough fields. |
| Statuses | Current meaning, timing, refresh, expiry, and counters. |

Spell tables use the selected caster and saved spell model when supplied. Base catalogue browsing must identify itself as base information. A creature's fixed kit must not be filtered through champion-only eligibility.

Interaction and spell lists are filtered/paged rather than expanded into an unbounded modal. Tables have semantic headers/captions, and tabs support arrow/Home/End navigation. Detail triggers are actual buttons.

[`BattleInsightV24`](../../app/components/BattleInsightV24.tsx) is the shared hover/focus/tap mechanism. It positions details inside the viewport and portals them into the nearest native dialog when necessary. This avoids a detail card appearing behind its modal. Only one such card is open at a time; explicit dismissal and focus restoration remain available.

Detail content should add timing, examples, counters, or a precise assumption. Repeating the same sentence under a tooltip heading is not useful progressive disclosure.

## Motion, sound, and recovery

When a solo Tower battle is paused, [`TowerGameV23`](../../app/components/TowerGameV23.tsx) shows the saved round and the surviving enemies' current health with their existing portraits. This is a resume aid sourced from the saved battle snapshot; it must not reveal enemy orders or require opening the battle to recover basic context.

Presentation preferences in [`presentation-preferences-v44.ts`](../../lib/presentation-preferences-v44.ts) default sound to off. Sound requires a user gesture to enable; UI/combat levels and reduced intensity are adjustable. Muting, changing level, and enabling sound during replay are handled by [`useBattlePresentationV44`](../../app/components/useBattlePresentationV44.ts) and [`useBattlePlaybackV44`](../../app/components/useBattlePlaybackV44.ts). Meaningful outcomes remain visible without sound.

An unset motion preference follows the system reduced-motion preference. An explicit user preference can override that default. Instant results and local replay controls provide another way to inspect outcomes without watching the full animation.

Storage failures, incompatible saves, unavailable multiplayer, and stale actions are different failures and should stay distinguishable. Preserve the saved data and original seat identity; do not silently start a fresh game when restore fails.

Tower recovery shows the exact server expiry and the browser's access requirement. An authenticated action renews an unfinished Tower's inactivity window; merely watching/polling does not. The game does not promise indefinite cloud saves. Browser export is the portable recovery mechanism, and its warning must state that it can include private player keys.

## Verification checklist and limits

These are acceptance checks for future edits, not claims that all combinations of browser, device, and assistive technology have been certified.

1. At desktop and narrow phone sizes, select a fighter, move, cast, inspect a status, undo, and commit without horizontal page overflow or an obscured primary control. Also test short landscape height.
2. Complete the same legal build through ordinary buttons and keyboard. Confirm a locked/unlearned spell cannot enter a slot through drag, click, or stale selection.
3. Open/pin/dismiss a detail card by mouse, focus, and tap, including inside a modal and near each viewport edge.
4. Verify tab order, visible focus, board navigation, text-input shortcut suppression, and focus restoration after dialogs.
5. Compare native outcomes with previews for ordinary spells, focused center/rim effects, legacy models, scrolls, allied projectile contacts, and conditional displacement.
6. Pause/step/finish/replay locally while another cooperative player continues. Confirm that only the actual network readiness action changes the group state.
7. Inspect one- and six-player routes. All paths should be visible, room-card controls usable, and preview distinct from the committed destination.
8. Test reduced motion, instant results, sound off/on, muted buses, and enabling sound during playback. Listen on a real audio device; a scheduling assertion does not establish pleasant audio.
9. Interrupt storage/network access, retry a safe request, reload a saved seat, and review an expired-room error without losing the recovery explanation.
10. Ask first-time human players to explain a move, collision, status, and reward choice in their own words. Automation cannot establish comprehension, tactical satisfaction, fairness, or enjoyment.

Focused regression sources include [`loadout-interaction-v45.test.ts`](../../tests/loadout-interaction-v45.test.ts), [`combat-reference-v23.test.ts`](../../tests/combat-reference-v23.test.ts), [`tower-route-pointer.test.ts`](../../tests/tower-route-pointer.test.ts), [`tower-route-layout-v42.test.ts`](../../tests/tower-route-layout-v42.test.ts), and [`tower-room-preview-v43.test.ts`](../../tests/tower-room-preview-v43.test.ts). Server-rendered markup, simulated viewport checks, and native tests are useful but do not replace physical phone input, screen-reader testing, or a complete accessibility review.
