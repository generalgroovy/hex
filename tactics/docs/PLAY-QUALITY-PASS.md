# Play quality pass

2026-10-17. Baseline: published version 12, source f09e4645299a127b6ce4ebdcdd06db5801a17bbf.

The request was to make the existing game better. Three specialists reviewed practice decisions, rendering and interaction reliability; the integration owner implemented the main interface and performed browser checks. This pass keeps the rules, 30-character roster, signatures, seeded geography and multiplayer protocol intact.

## Decisions

| Observed weakness | Player benefit | Implementation and acceptance |
| --- | --- | --- |
| Quiet well holders could Guard while the opponent's scoring rate guaranteed a loss | Practice opponents respond to a losing position | Preserve the baseline plan and replace at most one healthy mage's order with a safe pressure action. Protect winning/tied races, imminent wins and wounded holders. Compare matched games and test actual resolution. |
| Browsing another spell changed its highlight while the previous cast remained queued | The player can tell exactly what will resolve | Separate Queued/Default order from Aim/Preview. Browsing and hovering cannot rewrite the submitted plan; target taps do. Actual handler tests inspect the submitted payload. |
| All untouched characters looked deliberately assigned to Guard | End turn clearly commits the whole team | Show order counts, default Hold/Guard, per-character queue marks and Next selection. Preserve implicit Guard without extra mandatory confirmations. |
| Phone spells and End turn were far below the field | Targets and decisive controls stay close together | Native spell chooser shows descriptions, cost, range and recovery. It closes before aiming. Undo and End turn remain in a bottom bar. A compact short-screen arrangement preserves the original focused hex size. |
| Busy flat terrain competed with small actors and wells | Overview communicates position and scoring | Quieter neutral tiles; consistent team-number markers; ownership-colored well values; selected name and segmented HP in Focus. |
| Multicell spells flashed mainly at their aimed center | Resolution communicates where the spell actually acted | Pulse exact affected cells from the pre-cast board and actual event origin. Preserve blocked-line geometry, self-cast behavior, pointer transparency and reduced motion. |
| Resolution could occur outside the camera or above the scrolled page | The result stays visible | Frame the relevant exchange once, restore the camera after replay, and scroll the field into view only when resolution begins above the current page viewport. |
| Round reports described overheal as recovered health and included zero-damage filler | Reports describe visible consequences | Show actual HP differences, well captures, reactions and status recipients. Exclude respawn HP and overheal from recovered-HP messages. Keep the complete event log available. |

## Validation boundaries

The committed suite includes behavior tests that execute actual client handlers with real combat validation, focused practice-policy scenarios, public-board readouts, round reports and renderer fixtures. It covers queued versus inspected spells, precise submissions, Undo, picker dismissal, locked inspection and stale room responses. The exact final test count, build result and public HTTP checks are recorded in the release receipt outside the source checkout.

Browser checks cover desktop 1280×900, phone 390×844, and short phone 320×568. The short layout keeps essential controls and the field visible without shrinking hexes. Real Water Jet and Fire Lance orders were submitted together; Steam formed and the line's actual affected cells appeared during resolution. A page scrolled below the board returned to the field when resolution started. Browser viewport checks do not establish physical touchscreen comfort.

The practice comparison uses the same deterministic seeds, squads and starting conditions for the baseline and candidate. Its round traces and a separate mirrored-seat matchup are retained beside this document. Small diagnostic samples support the specific policy correction, not general competitive strength or human enjoyment. Existing audio is retained; this pass does not claim new listening evidence.

Final source passes **267 tests**, with no failures, skips or cancellations, plus TypeScript and the production build. The production HTTP match passes all 31 check groups and completes after seven exchanges at 18–15. The final public results remain in the external release receipt.

Six matched diagnostic cases changed total casts from 156 to 168, damage from 230 to 253, defeats from 13 to 16, occupied-well hits from 53 to 56, ownership changes from 2 to 3, and stationary Guard turns from 57 to 49. Total rounds rose from 49 to 51. Every state restored strictly, with no known allied collisions or harmful exposures. Two cases were unchanged and one case had fewer occupied-well hits. In the separate three-seed, mirrored-seat sample, the actual practice squad won six games with the candidate versus four with the baseline. See [paired traces](practice-pressure-comparison.json) and [mirrored matchups](practice-pressure-head-to-head.json). Timings were collected alongside other checks and are not controlled performance benchmarks.

Independent review also corrected a fractional score-race estimate: at scores 11–13 with income 3–2, simultaneous scoring produces 14–15, then 17–17, then 20–19. Holding wins. The final policy projects complete scoring rounds, including continued ties and the round-20 cap, rather than abandoning the well on the fractional estimate. The regression verifies the sequence through the actual resolver.

## Compatibility

No resolver, spell, roster, map generator, point target, server route, database schema or protocol changes. Existing rules-7 saved games and remote matches continue under the same combat rules. All frozen older versions remain untouched. Publication retains the public audience and private room codes.
