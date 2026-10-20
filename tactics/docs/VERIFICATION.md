# Archived Confluence verification — v1 and v2

This file preserves the alternating PLAYTEST 01 and v2 records from 2026-10-15/16. The sections through “Acceptance limits” concern v1; the v2 sections follow. Their rules, protocol requirements and pending-at-the-time statements are historical. They do not describe the current simultaneous candidate. See [V3-VERIFICATION.md](V3-VERIFICATION.md) for current evidence and [DESIGN.md](DESIGN.md) for the current rules.

## Source and assets

The H.E.X. source was inspected read-only. It has concurrent work occurring in another context; this task did not edit its files, run Godot, or change its launchers or qualified builds. The spinoff lives entirely in the new `outputs/hex-confluence` project.

Six canonical identities and original portraits were checked against the current catalog. Browser WebP derivatives total 434,136 bytes. Original assets remain in H.E.X. and exact copied PNGs remain in this project's ignored work folder. See SOURCE-PROVENANCE.md for hashes.

## Automated checks

- TypeScript whole-project check: passed.
- Game rules and SQLite room tests: 29 passed, zero failures (22 engine and 7 room tests).
- Production Vinext build: passed before final integration; final deployment build result is recorded with the deployment handoff.
- Local HTTP smoke: passed creation, join, missing-token rejection, wrong-seat rejection, concurrent-turn compare-and-swap, complete match, identical peer snapshots, credential non-disclosure, and mutual rematch. The recorded match ended in round5 at5–9 after19 actions. That score is a functional test result, not a balance result.

Independent review found and fixed mirrored Air-push asymmetry and missing lethal Glass follow-up in previews. A second review fixed stale network replies affecting a newly opened match and manual-code reentry failing to recover a saved seat.

## Browser checks

Using the supported in-app browser:

- Home, canonical portrait draft, and practice match render.
- Champion selection reveals legal targets; movement consumes an action and moves the token.
- Casting Water onto the central well changes the surface, consumes the second action, and automatically passes play to the AI.
- Online match creation opens the waiting view with a twelve-character code.
- A separate guest browser origin joins the invitation, starts the match, and receives the host's move.
- Returning home and entering the formatted existing code restores the original host seat with its previous action state.
- Layouts observed at actual browser widths around790 and1280px without horizontal overflow. A requested390px override did not take effect in this browser, so phone-width visual QA is unverified.

These are two local browser origins, not two physical machines on separate networks. Hosted HTTP checks and deployment status are recorded separately in the final handoff.

## Acceptance limits

No human usability, human balance, physical phone touch, adversarial penetration, sustained load, or retention study has been performed. Bot diagnostics exposed seat and Air tendencies under the shallow practice heuristic; no competitive-balance or commercial-success claim follows. No analytical tracking is installed. The product remains explicitly marked PLAYTEST01.

## V2 candidate — rules and compatibility

The retained v2 rules are the one-action opening for Player 1, two actions on every later turn, fixed Player 1 then Player 2 order, held-well scoring at the owner's turn start, and victory only after both players complete a round. Guard consumes one action and the champion's cast allowance. Air deals 1 damage at range 2 and pushes only adjacent surviving, unguarded enemies. Dark deals 2 damage and heals its caster by 1 only after actual enemy damage on a hex that was already Dark before the cast. Light heals a friendly champion or itself by up to 2, or deals 1 enemy damage. Water, Fire and Earth deal 2. Surfaces last four player-turn endings. A respawning champion cannot score a well immediately upon returning.

The paragraph above records the retained v2 contract. [DESIGN.md](DESIGN.md) now describes v3; do not use it to reinterpret an existing v2 match. Abandoned diagnostic candidates were not the retained v2 specification.

Compatibility is explicit rather than a conversion of active games:

- `lib/game-v1.ts` preserves the source engine copied from the opened PLAYTEST 01 source, SHA `4f03469`. Untagged states continue through that engine. New states declare `rulesVersion: 2`.
- `lib/rules.ts` dispatches authoritative actions, legal targets, previews, movement paths, push predictions and practice AI to the state's engine. A Classic Guard request is rejected. Unsupported state versions are not silently upgraded.
- Current clients send protocol version 2. Older clients can read and act in an existing Classic game; create, join, rematch and v2 state access require protocol 2. Rejection is HTTP 426 with a readable reload message, `reload: true` and `requiredProtocolVersion: 2`.
- Snapshots expose both rules and protocol versions. Waiting rooms advertise v2 because a newly joined game uses current rules. Room revisions remain separate from engine state revisions.
- Both players must give current-protocol rematch consent. A Classic consent queued before the update does not count toward accepting v2. The existing room schema supports this without a D1 migration.
- Local restore checks the saved state's shape, supported rules version, champion identities, board cells, coordinates, ownership, Health and active occupancy before play. Invalid saves remain stored for recovery; a failed restore does not replace them with a new match.

At the latest component verification point, **12 room/compatibility tests passed** against SQLite using the generated D1 schema. They cover authenticated snapshots, wrong-seat and stale-turn rejection, atomic seat claims and turn updates, token non-disclosure, expiry and rate limits, current-protocol gating, archived action parity, mutual upgrade consent, local restore, and a Classic last-action lethal Glass-push preview. The legacy preview test ensures automatic turn-end respawn does not hide the predicted push destination. These tests exercise local persistence and code paths; they are not a penetration or load test.

The engine owner reports **34 engine tests passed** for the locked rules, including held-well timing, equal completed-turn victory, Guard behavior, action legality, adjacent Air push, conditional Dark siphon and the respawn-on-well regression. The integration owner must record the final combined check against the final source before treating these separate component passes as release evidence.

## V2 balance diagnostic — bounded and still unfavorable by seat

The final retained candidate was selected for clearer responses to Air and Dark and improved spread across squads in the diagnostic, not because the game has been shown balanced. [The final diagnostic artifact](../tests/balance-final-diagnostic-results.json) contains 120 deterministic matches: all twenty three-champion rosters against their complementary roster, three cyclic deployment orders, two shallow heuristic policies, and paired seats. These repeated configurations are non-independent; they do not cover every opposing-roster matchup or human strategy.

The recorded result was Player 1 winning 37, Player 2 winning 82, and one draw: **31.25% versus 68.75% when the draw counts as half a win per seat**. The remaining seat effect is substantial. The one-action opening must be treated as provisional, and paired human playtests are required before a fairness claim. Mean match length was 6.89 rounds and the bots used Guard 218 times; neither measure demonstrates human pacing or decision quality.

The per-champion diagnostic reports the win share of **squads containing that champion**, not the isolated strength or causal contribution of the champion:

| Squad contains | Win share, including half draws |
|---|---:|
| Water | 45.4% |
| Fire | 47.1% |
| Air | 56.3% |
| Earth | 57.1% |
| Light | 51.2% |
| Dark | 42.9% |

This 42.9–57.1% spread is narrower than the earlier diagnostic's approximately 85% share for squads containing Air, but changed rules and heuristic interactions prevent attribution to a single fix. Neither result establishes balanced drafts, expert counterplay or human replay value.

The engine owner confirmed this artifact against `lib/game.ts` SHA-256 `3d281fed4de847e159fd97e9a6ff3178cf31a958cf488fbcc3da07e0d7659b2c`. Reproduce it with `node --experimental-strip-types tests/balance-diagnostic.ts --current-only`. Other diagnostic result files record earlier hypotheses and must not be substituted for the final retained candidate.

## V2 pending integration and player evidence

At this documentation handoff, final whole-project TypeScript, combined tests, production build, updated HTTP smoke, v2 browser checks and publication status remain for the integration owner to record. Historical v1 browser checks above do not prove the new confirmation flow, mobile layout, Guard, adjacent push, prepared siphon or Classic badge work in the final browser build. Opening a preview or a successful build also does not establish those interactions.

The required v2 browser cases include select-preview-confirm/cancel, confirmation reset after an incoming room revision, turn-ending opening action, held-well scoring, Guard consumption, range-two Air without displacement, adjacent push arrows, Dark siphon only on pre-existing Dark, readable health and spell outcomes, resumed room credentials, stale-action recovery, Classic continuation and mutual v2 rematch. Narrow-screen checks must record the actual viewport achieved. Physical-phone touch, separate-network friend play and human learning/balance tests remain pending even if local browser automation passes.

No human balance, retention or commercial-success result is claimed. [DESIGN.md](DESIGN.md) specifies the bounded next playtest rather than an open-ended feature expansion.

## V2 integration verification — 2026-10-16

The integrated source passed TypeScript checking and all **46 tests** (34 engine + 12 room/compatibility). The production build completed. Both development and built-Worker HTTP smoke runs passed create/join, cached-client426, missing credentials401, wrong-seat400, one-success/one-conflict concurrent actions, full match completion, identical peer states, token non-disclosure and mutual rematch. The final local full match ended in round6 at4–8 after23 actions.

Browser checks used real CSS iframe viewports, because the in-app browser viewport override did not reliably set its actual dimensions. At390px outer width (381px content with scrollbar), draft, target preview, free cancellation and confirmed movement were exercised. Preview left the opening action unspent; confirming moved Oh Tipi and passed play to the AI. At320px outer width (310px content), saved practice resumed, Guard preview/confirmation spent exactly1 action and disabled the champion's cast, and the board label exposed guarded state. Neither width had horizontal overflow. Narrow action buttons measured46px high; hexes are smaller at320px. The390×844 layout was also measured before switching to shorter500px fixtures. These are browser layout/input checks, not physical touchscreen validation. Runtime screenshots from this desktop browser capture only its visible panel region, so they must not be treated as full-phone screenshots.

A browser check caught transient defeat effects on restored games; initial online snapshots and restored local matches now reset the visual comparison state. The production rebuild and final public receipt are maintained by the integration owner. Numeric reaction edge cases and legacy parity are covered by tests, not claimed as separately completed browser scenarios. Separate-network two-person play, physical-phone touch, assistive-technology review and human balance/retention remain unverified.
