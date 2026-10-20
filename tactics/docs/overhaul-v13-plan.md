# Confluence rules 13: design consolidation

This revision strengthens one game: choose three canonical HEX characters,
configure four spells each, and privately plan movement plus one cast or Guard.
Both companies act together on shared elemental ground. Control wells and win
exchanges through position, timing, prediction and the consequences of mixing.

## Review process and evidence

Four independent agents each reviewed all 24 areas below, using engine code,
authored data, current UI components, state transitions and test fixtures.
Their complete findings are in `audit-v13-systems.md`,
`audit-v13-experience.md`, `audit-v13-world.md` and
`audit-v13-challenge.md`. The integration owner reconciled the findings,
implemented transport and controller changes, and checked assembled behavior.
This is four independent reviews per area, not four isolated feature silos.

The strongest shared finding was that the game already has enough systems.
Its weak points were the visibility of decisions, overly universal spell access,
absolute Guard protection from force, generic kits and explanations that did not
match real consequences. The changes below address those weaknesses without
adding another phase, resource or mode.

## Cooperative decisions and acceptance criteria

| Area | Decision | Evidence required |
| --- | --- | --- |
| Core identity | Keep simultaneous territorial spell tactics and shared elemental consequences. | Teach occupied wells, cast/Guard and simultaneous resolution in the opening. |
| Turn structure | Keep move then cast then fields/scoring. Count deliberate actions separately from fallback Guard. | Move-only remains unfinished; cast/Guard marks ready; drafts and undo preserve intent. |
| Tactical decisions | Guard resists one net force; coordinated displacement can overcome it. | Cancellation before resistance; resistance before cap; Anchored and Ice counterexamples. |
| Elements and combinations | Keep all 63 exact nonempty combinations, each with its own field rule. | Existing exhaustive descriptors/resolution and forecast checks remain green. |
| Spell design | Require allocated affinity for every element; preserve six levels and scaling. | All spell thresholds, off-element rejection, borrowed signatures and legal-slot repair. |
| Characters and races | Thirty authored starting kits and truthful tactical roles; canonical identity unchanged. | Every kit legal, distinct and covers native elements; no fabricated racial stats. |
| Team composition | Four configured spells and a fixed signature; no in-match kit editing. | Camp-to-match consistency and fixed-kit boundaries in all modes. |
| Progression | Story grants affinity; preserve profile and free reassignment. | Historical profile migration, first-victory-only rewards, actual next-point preview. |
| Resources and statuses | Preserve bounded control and delayed beneficial status timing. | Aggregate Ward/Guard/terrain mitigation, fresh-mark and fresh-Anchored counterexamples. |
| Objectives | Keep occupied-well and defeat scoring; 16 with a lead, 20-turn limit. | Full-match traces; do not add overtime merely because deterministic mirrors draw. |
| Map design | Preserve large terrain patches, relevant camera controls and original assets. | Seeded route/prop tests plus phone battlefield interaction. |
| Procedural generation | Keep reproducible seeds and mirrored movement costs. | Determinism, navigability and rematch seed preservation. |
| Balance | Replace identified universal advantages and compare actual outcomes. | Paired seeded AI diagnostics; total affinity remains a transparent gauge, not proof of fairness. |
| Story and encounters | Thirty practical lessons, fixed opponent strength and optional closest-strength unfinished recommendation. | All encounters restore, boss signature preview uses actual affinity, recommendation uses allocated points. |
| Opponent AI | Value a spell's marginal contribution to an allied volley and public creature counterplay. | No hidden-order access; friendly exposure, redundant counter and unavailable-resource negatives. |
| Multiplayer | Protocol 13 for new games; frozen engines and validators for existing games. | Secrecy, retries, concurrency, lost joins, v12 pending lock and mutual rematch migration. |
| Onboarding | Brief contextual, dismissible guidance through round three. | Opening, missing action, actual fizzle, finished and dismissal cases. |
| Interface | Spell consequence labels, explicit readiness, Next character and meaningful result priority. | Assembled planning and result journey; no extra confirmation gate. |
| Input and mobile | Preserve reversible planning and use safe Inspect mode for character details. | Phone-width interactions, no horizontal overflow, visible readiness, keyboard access. |
| Visuals and animation | Preserve coherent pixel assets and existing material/timing hierarchy. | Visual inspection and reduced-motion regressions; no ornament that obscures targets. |
| Audio | Preserve optional bounded material cues and scheduling. | Lifecycle/cancellation tests; listening quality requires a separate listening judgment. |
| Accessibility | Retain text/symbol alternatives, reduced motion and named controls. | Keyboard inspection and readable consequences; actual screen-reader/device testing remains distinct. |
| Pacing and replayability | Reduce plan ambiguity and explain setbacks before adding content. | Complete matches and action traces; human replay motivation remains unproven. |
| Validation and production | Freeze rules, exercise actual handlers and publish only a verified package. | Full suite, TypeScript, production build, two-seat production HTTP and public browser checks. |

## Rules and migration boundaries

- Allocating the first point in a new element grants its first-level spells.
  Characters retain the three-element maximum; Story earns the additional points.
- New defaults use authored kits. Existing legal customized slots keep their
  positions. Only missing, duplicate or ineligible slots are repaired.
- Simultaneous push and pull vectors cancel before Guard reduces their net
  strength by one, then the two-step limit applies. Anchored prevents displacement.
  One step onto Ice can still produce a longer slide.
- AI uses the same damage aggregation as resolution, including terrain, Ward,
  piercing and Guard. Its guarded estimate is a conservative scenario, never
  information about the rival's hidden order.
- Rules 1–12 remain frozen. Existing v12 matches may legally contain spells that
  rules 13 would reject. They finish under v12; only a mutually agreed rematch
  adopts current validation and repaired kits.

## Deliberate limits

No new scoring phase, hidden enemy scaling, race statistics, currency or extra
catalogue was introduced. Late Story still allows a stronger player allocation
than the fixed authored opponents; optional recommendations make strength visible
without moving the goalposts. Agent matches establish legality, deterministic
symmetry and activity, not human enjoyment or competitive balance. Browser phone
sizes establish responsive behavior, not physical-device performance. Automated
audio scheduling checks do not establish attractive sound. These distinctions
must survive release reporting.

## Integration evidence before publication

- Full suite: 581 tests passed, zero failed. This includes frozen engine and
  transport behavior as well as the new version.
- After the final inspection fixes: all 16 affected guidance/client integration
  tests passed again. TypeScript and the production build passed.
- Four-reviewer follow-up found and fixed modal shortcut leakage, misleading
  inspection readiness and the overstated barrier-removal label.
- Browser journeys exercised move-only readiness, cast, explicit Guard, Next
  character, undo, complete resolution, safe own/rival inspection, Escape,
  Story setup and affinity explanations. Checked 1200×800, 390×844 and 320×568
  CSS viewports with no horizontal page overflow. Small-screen actions remain
  fixed at the bottom. These are browser viewport checks, not physical devices.
- Final production Worker HTTP run: 244 assertions over 60 requests; complete
  20-round mirror match (31–31), two authenticated seats, hidden plans, identical
  retries, lost join recovery, immutable kits/affinity, rematch consent, stale
  match rejection and equal-affinity entry checks passed.
- Nine complete systems diagnostics restored every state. Six asymmetric games
  finished in 8–12 rounds; swapping seats preserved the outcome. The winning
  team varied by seed. Mirror draws contained substantial combat.

Public deployment identity and post-publication verification are recorded in the
workspace release evidence after the supported publication workflow completes.
