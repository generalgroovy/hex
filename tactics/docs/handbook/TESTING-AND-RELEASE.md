# Testing and release qualification

Correctness, presentation, balance, human enjoyment and publication are separate claims. A passing test suite is necessary evidence for specified behavior, not evidence of commercial success.

## Verification layers

| Layer | Command or activity | Establishes | Does not establish |
|---|---|---|---|
| Documentation | `npm run docs:check` | Local handbook links resolve | Every prose statement is correct |
| Types | `npm run typecheck` | Type compatibility across app and tests | Runtime semantics or layout |
| Native rules | `npm test` | Assertions against real deterministic resolvers, storage and service code | Browser rendering or remote infrastructure |
| Production assets | `npm run build` then `npm run assets:check` | Worker/client output and RSC/SSR asset presence | Successful publication |
| HTTP/D1 | Versioned smoke scripts in [Development](DEVELOPMENT.md) | Actual requests, authorization, persistence, ownership, sealed orders and synchronization | Internet latency or hosting capacity |
| Browser | Normal GUI input, replay, saving, inspection and viewport checks | Exercised controls and visible presentation | Physical-device performance |
| Bot diagnostics | `node --experimental-strip-types tests/balance-v44-diagnostic.mjs` | Pacing and matchup evidence under the recorded seed/policy | Human difficulty, interesting choices or broad balance |
| Publication | Terminal deploy result, live routes and byte comparisons | The expected build is reachable | All possible player paths work |

The full native suite takes several minutes. Use focused tests while editing, then the full relevant checks before a release. Avoid asserting exact markup when semantic roles, ownership, values or visible consequences are the real contract.

## Current baseline

[Release 45 evidence](../release45-evidence/verification.json) records the shipped source, deployment, checks and limits:

- 1,442 native tests passed, none failed or skipped.
- Full TypeScript and the official production build passed.
- Arena: 636 HTTP assertions; six squads sharing one Tower room: 3,774; three paired Tower rooms: 4,031. These successful runs issued 652 requests in total.
- Simultaneous independent network suites produced local 503 responses. Tower recovered through its retry path; the Arena smoke passed when run independently. Preserve the failure context rather than presenting this as a capacity benchmark.
- Browser checks covered 1280×800, 390×844 and 790×444 CSS viewports, with no horizontal document overflow in the exercised views. A save exported from the development origin imported and resumed on the built Worker.
- Live checks loaded five main routes and compared fifteen emitted assets byte-for-byte.
- Eight opening parties on one seed all won in 4–12 exchanges (median eight). No earned charms/scrolls were present; later floors, gear and co-op balance are not covered by this diagnostic.

The GitHub import may run additional CI against the same gameplay source. Its logs and commit identify those checks separately; do not relabel Windows release evidence as a Linux or phone test.

## Change-oriented checks

| Change | Especially relevant coverage |
|---|---|
| Spell power, area or affinity | `spell-profile-*`, `spell-focus-*`, `target-impact-*`, catalogue/legality tests and actual seeded combat |
| Movement, ice, collision or displacement | Movement, terrain, interception, volume-collision and forecast tests; compare preview with resolver |
| Tower rewards/equipment | `tower-supplies-v45`, service and rendering suites; consumption, fizzle, interception, replacement, retry and cross-owner cases |
| Co-op grouping/floor flow | Tower room/shared-battle tests plus both actual Tower HTTP scenarios |
| Story progression | Campaign profile, encounter, creature and storage tests; first-defeat teachings in lost and won battles |
| Animation/playback | Resolution rendering, playback clock, presentation and actual browser pause/seek/speed/replay |
| Audio | Lifecycle, gain, cancellation and bounded voice tests, followed by real listening |
| UI/Guide | Reference and SSR checks, keyboard/focus/touch, phone portrait/landscape and actual hover/tap placement |
| Art | Alpha/component/anchor/frame checks, atlas hashes, actual animation in context; inspect on light and dark ground |

Use the filenames in [tests/](../../tests) as the exact inventory. Version numbers describe compatibility contracts, not obsolete code that can automatically be deleted.

## Human acceptance still required

Observe first-time players without explaining controls. Record time to issue a legal move and cast, whether they predict the result, how they find enemy reach/statuses, and why they choose a room/reward. Separate unclear information from an uninteresting decision.

Run paired and six-person sessions on real networks; include a disconnect, lost response, late room completion and a defeated squad watching allies. Measure waiting and recovery, not only fight length. Play defensive and offensive starters across multiple seeds, late floors and equipment allocations.

Check real phones in both orientations, low-end rendering and reduced motion. Listen to a quiet duel and a crowded twelve-ally volley on headphones and small speakers. Inspect newly packed frames in motion for silhouette, anchor, alpha and timing defects. These are open acceptance tasks, not completed release-45 claims.

## Release checklist

1. Freeze the intended source and record dirty boundaries.
2. Review compatibility and hidden-order information.
3. Complete targeted checks and the full release checks appropriate to the change.
4. Inspect the built game through normal GUI actions and record representative screenshots.
5. Record the exact source revision, asset/build identities, diagnostic seeds and any failed attempts.
6. Publish only the corresponding build and wait for terminal success.
7. Verify the live pages/assets and retain rollback evidence. Source, CI, browser acceptance and live release each keep their own identity.
