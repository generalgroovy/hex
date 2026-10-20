# Tower 23: separate squads, shared ascent

The starting team is a proposal. Both slots can be replaced before a solo or cooperative climb with any two distinct legal starting characters. Thirty champion appearances use the existing five-affinity, three-element and four-spell rules; twelve lesser creatures use canonical two-affinity kits and bonds. A player can start with two champions, a mixed pair, or two creatures. Advanced creature classes remain recruitment rewards.

Each run keeps its original team allocation for encounter scaling: 4, 7 or 10 starting affinity. Earned affinity, missing health, equipment changes and the number of connected friends do not secretly increase opposition. Canonical enemy classes and champion allocations vary by starting tier. Starting champions stay in the party; starting creatures and later recruits can be replaced when the three-character party is full. Creature-only teams always receive an actionable reward, even when fully healed.

## Shared climb

A private lobby reserves two to six places. The host starts once at least two players have joined and everyone present is ready; empty reserved places do not prevent starting. Each player owns a separate run and controls its whole squad. Joining closes when the climb starts.

Room selection, combat orders, simultaneous resolution, outcome review and reward selection are independent. One player may take an elite encounter while another chooses an ordinary fight. A completed squad waits at the stairs until every surviving squad has finished the floor and claimed its reward. The server opens the next floor for everyone in the same state transition; a fast client cannot enter early.

At that checkpoint, the group shares learned spells. Different rooms can provide different enemy techniques and drafts, so routes contribute to the group's options. Sharing changes the spell library only: affinity requirements, four equipped spells, health and progression budgets still apply. Combat remains the frozen rules 22 resolver. There are no cross-room projectile collisions or shared-battle Link bonuses.

A defeated squad can watch the remaining climb. A player may explicitly retire its own squad to release the checkpoint. Disconnection does not silently kill a squad or waive its unfinished floor; the same browser can reconnect with its saved seat key. Rooms expire seven days after creation.

## Watching and input

The player strip shows every joined player's current room, floor, phase and battle round. Selecting a friend requests that encounter's state; returning to the player's own squad restores its existing draft. Spectator controls allow inspection, reports and replay but never movement, casting, finishing another player's result or choosing its rewards. Only the currently watched board is transmitted alongside the viewer's own state and compact group summaries.

Private enemy plans are generated before player submissions and never included in snapshots. Every action is authorized against the caller's seat, not a client-supplied target seat. Per-squad step IDs reject stale actions without making another friend's independent move invalidate a draft. Request receipts and compare-and-swap writes keep retries and concurrent room updates from applying twice.

## Compatibility and verification

New solo storage uses `hex-confluence-tower-v23`; cooperative state uses a new `tower_rooms_v23` table and `/api/tower-v23`. Rules 22 solo and co-op routes remain playable at `/tower/legacy-v22` and `/tower/coop/legacy-v22`; rules 21 stays at `/tower/legacy`. Previous storage and room tables are preserved.

Verification focuses on legal two-character construction, all three starting-power bands, reward availability, strict saves, six concurrent seats, distinct room choices, independent turns, synchronized floor release, shared discoveries, read-only spectating, ownership, idempotency and reconnect. Browser checks and actual resolver outcomes are recorded separately from unit fixtures. Bot results establish specific pacing and viability evidence, not human win rates or enjoyment.

[Model and balance verification](tower-v23-verification.md) records the tested starts, drafting policy, observed results and source hashes. `tests/http-tower-v23-smoke.mjs` runs six real first-floor encounters against an HTTP server, checks the shared checkpoint and enters the next floor. `tests/tower-battle-render-v23.test.ts` separately guards read-only spectator controls. Browser QA covered a six-seat lobby, three independently chosen rooms, spectator switching, retained draft orders, reconnect, independent resolution and the actual 360×640 CSS viewport.
