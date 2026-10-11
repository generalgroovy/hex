# Acceptance — evidence now, tasks for integration

**No Godot game, real traversal, player study or multiplayer session was executed for this deliverable.** Source `CollisionWorld`, movement/input service dependencies, scene/bootstrap and full renderer are not supplied. This package cannot be treated as a runnable checkout. Historical packet results are not results for this candidate.

## Checks actually executed

| Evidence | Actual result | What it does not establish |
|---|---|---|
| `evidence/input_integrity.json` | All 63 input-manifest records match source bytes/hashes; archive contains the manifest as an additional file | Authenticity of an unseen live checkout or correctness of the source |
| `evidence/static_geometry_checks.json` | 247/247 checks pass; 1493 baseline cells; 1474 candidate cells; patch and rollback object equivalence | Godot validator, live `can_occupy`, dynamic collision, latency or player success |
| `evidence/rejected_v0_static_geometry_checks.json` | Two route-clearance failures retained from the first proposal | Not a passing candidate; do not import `rejected_v0_campus.json` |
| `evidence/browser_checks.json` | 28/28 checks pass: matrix, symmetry, layer priority, focus, pending/ack mock, confirmation expiry, image loading and responsive width | Game UI, actual network authority, screen-reader acceptance, controller navigation or direct packaged launch |
| `evidence/package_checks.json` | 179/179 local structure, source-copy, coordinate-pointer, image/reference and guarded candidate-tool checks pass | Godot schema execution or runtime acceptance |

Browser checks load the generated HTML into Chromium memory with local PNGs embedded as data URIs. The environment administrator blocked both file-URL and loopback-HTTP navigation. The packaged preview uses normal relative paths, checked separately; direct launch in a normal user browser remains **NOT_RUN here**. Nothing was fetched from an external service. A demonstration acknowledgement is not a real network event.

The static route checker calculates Euclidean point/segment-to-AABB distances; the actual collision implementation and exact contact norm are missing. It is stronger than checking only sparse sample points within that model, but not interchangeable with `CollisionWorld.can_occupy` or `move_box`. Integer whole-hex eligibility follows the supplied expanded-AABB/SAT rule. These two checks have different scopes.

### Reproduce offline checks

From this extracted folder:

```sh
python tools/validate_geometry.py
python tools/check_preview.py
```

The first uses Python standard library only. The second requires Playwright and Chromium and uses in-memory content; it performs no game networking. Rebuilding images requires Pillow/CairoSVG and local font availability; reading the preview does not. Source artwork and generated PNGs are included. See INTEGRATION.md for safe candidate creation and optional local serving.

## Godot / human task register

**Every task below is NOT_RUN.** Report PASS/FAIL only with build identity, profile, hardware, map hash, participants, capture/trace and observed result. Use the same controls/casts/demand for current-versus-candidate comparisons. Do not repair a failed test by changing global physics, body radius, chemistry radius, lifetime, damage or simulation caps under this map task.

| ID | Setup and player action | Acceptance / rollback criterion |
|---|---|---|
| M01 — source/load | In a separate current checkout, compare hashes, load candidate through `SanctumCampusLayout`, run current source validators | No unknown fields, invalid IDs, route/group/anchor failure or content-hash ambiguity. Stop/rebase on source mismatch. |
| M02 — exact lattice | Rebuild current/candidate topology in Godot and compare sorted q,r sets with both JSON sets | Exact set equality expected under the supplied snapshot; explain any version-driven difference. Radius-zero owner, shared-face owner, strict tangency and +1 fixed-unit overlap match. Never merely compare counts. |
| M03 — frozen contracts | Capture size, hurtbox, common wall radius, stamina, spawn/arena/gather positions and all gameplay tuning before/after | 58/63/68 display, 17/18/19 hurt radius, common wall 18, stamina 620/660/700 unchanged. No new collider from paving/fountain/station art. |
| T01 — continuous movement | For each size, traverse each entry/return in all eight headings while aiming in each of eight independent headings; include diagonal slide and reverse movement | No hex-center snapping, six-direction restriction, corner capture or aim-driven travel rotation. Record all 64 travel/aim combinations per size; animations remain readable. |
| T02 — ordinary clearance | Traverse every ordinary route and connection at center and each promised edge; compare live sampled `can_occupy` with analytic evidence | Full declared width remains legal under actual collision semantics. No corner failure, hidden art collider, wall snag or size-specific adjustment. Run exact source validator, not only this Python checker. |
| T03 — low-resource escape | Start at assay target, firing anchor and beside each new shoulder with exhausted premium-movement resources; take both returns with ordinary movement | An unblocked route remains traversable without sprint, dash, wall technique or vault. No mandatory paid action to leave a static pocket. |
| T04 — corner / wall technique | Approach every new shoulder face and vertex during sprint, slide, jump, fast fall and supported technique; test approach from both sides | Stable normals/contact, no penetration, false climb/vault, new speed exploit or invalid landing. Presentation height does not change solid 2D collision. |
| T05 — traffic and bodies | 2, 4 then 8 mixed-size actors pass on the south public route, enter/leave courtyard and share returns | No persistent pin, single-file funnel replacing the declared width, wall eject or unreadable actor stack. Record body-to-body limitations separately from static wall clearance. |
| C01 — paid formation | Repeat each of the ten first-four pairs, including mirrors, at fixed endpoint/aim with distinct paid source IDs; test all four deliveries where legal | Actual paid amounts/ledger, endpoint, selected cells, strength subtraction and later-four IDs preserved. A source cannot react with itself; rejected capacity does not spend or spawn free matter. |
| C02 — two exits under pressure | One consenting attacker creates the agreed baseline Steam or Magma setup while defender chooses either shoulder route; switch roles/sizes and approach angles | Visible warning allows a legal choice under the declared fixture. No map-caused inescapable static pocket. Record blocked/contested routes rather than claiming universal safety against arbitrary spam. |
| C03 — temporary structures | Form Rampart near both shoulder corners, returns, workshop and an occupied actor point; add controlled Flood/Vortex movement | Safe-creation/overlap policy, escape and wall normals remain correct. No entombment, out-of-bounds push or six-face gap exploit. Missing structure implementation must be reviewed first. |
| C04 — phase and exposure | Enter at active_tick−1, active_tick, decay_tick−1, decay_tick and expiry_tick; cross Steam with low/high jump and leave; test Magma grounded and airborne | Damage/movement state matches actual authority at each tick; spent visual expiry is unmistakable. Steam exit shedding and 48 px envelope are not misrepresented. No magical safe paving. |
| C05 — self/team/ownership | Repeat overlapping products with self, allied and hostile actors, finite protection and two owners; trace identity and expiry independently | UI describes the actual eligibility, not generic friendly-fire safety. Overlay selection does not merge owners, clocks or costs. |
| C06 — spawn/station harassment | Under existing protection/session rules, cast near shared spawn, all Farflow actions, reset/gather and open menus; include late join | No hidden assumption of sanctuary. Log whether harassment or blocking is possible; unresolved first-session lockout blocks release. Any sanctuary/rule change requires separate approval. |
| R01 — moving native scale | Capture the two exits at 1280×720 with Steam+Magma, all four projectile families and 8 moving mixed-size actors; repeat normal/reduced | Observers can identify affected cells, danger vs expiry, each actor's feet/aim and approaching projectile direction. No smoke curtain, indistinguishable overlap or labels covering aim. Still images do not pass this test. |
| R02 — floor/view/scale | Repeat on quiet stone/slate, light/dark floor, available full/cone views and actual 100/75/50% world-view presets; vary supported UI scale | Danger is not dependent on color alone; feet/selected-cell edges survive. Do not assume pixel size in old captures equals current camera zoom. Record the exact transform. |
| R03 — fountain and props | Walk through the flush fountain; view every station from all approaches with actors/projectiles beside it | Memorable landmark without hiding bodies/aim. Water art cannot be mistaken for a cast, free ingredient or safe zone. Feet/shadow and non-solid affordance agree. |
| U01 — discoverability | New user identifies movement, champion, spells, controls, party, reset and duel route without a paragraph at each prop; approach overlapping interaction radii | One correct nearest prompt, visible focus, non-hover access and distinguishable chime/reset. No added NPC dependency; no interactive NPC is established by supplied campus data. |
| U02 — bindings/modal | Test current source defaults, customized/partial/unbound maps, controller and device swaps; hold paid actions/modifiers across F4, panel close and Alt-Tab | Actual prompts agree with the resolver; B/V modern defaults are not imposed on custom profiles. Alt/RB priority correct. No stale key, duplicate paid cast, free cast or world pause. |
| U03 — reference truth | Compare 8×8 matrix identities and full effective rules against runtime; check all 12 slots and failures, later-four cells, cost display and unavailable Punch/Kick | No catalog theme presented as live behavior, no fake disabled later-four family, no hardcoded stale costs or false weave persistence. |
| U04 — five minutes | Conduct the 300-second flow with a new solo player, then with an available remote friend; record task timings and errors | Player identifies both exits, explains Steam scald rather than concealment, finds party state and chooses a next activity. Proposed target: at least 4 of 5 first-time participants without verbal rescue. Not a measured result. |
| N01 — two-PC lifecycle | Two physical PCs: host/join, ready, gather, start existing duel, defeat, respawn, results, rematch, return, leave and rejoin | Every transition completes with matching authoritative state and no stuck input/modal. Do not substitute a localhost unit test. |
| N02 — 4/8 peers | Repeat lifecycle and courtyard traffic at 4 and 8 participants; include late join during chemistry and a pending operation | No duplicated actors/ingredients, stale topology, lost mandatory lifecycle state or peer-ID reuse error. Preserve stable protocol/wire IDs. |
| N03 — adverse link | Use declared latency/loss/jitter profiles on a controlled test network; disconnect host/client during Ready, selected peer and armed Parting | Pending/error states remain truthful; host validates identity/authority; selection never dismisses. Separate three-second confirmation expires, retries do not duplicate actions, recovery is defined. |
| N04 — remote authority | Client opens Company far from station and requests each operation; test client/host/observer permissions and session-generation change | Either approved remote path works with acknowledgement or access is explicitly denied. No accidental proximity/authority bypass or secret exposure. |
| P01 — matched load | Baseline/candidate, same hardware/build, same 8 actors, cast schedule, active products/cells/projectiles and recording overhead | Log p50/p95/p99 sim, pack, total host and rendered frame time, deadlines, allocations, retained/evicted/unencodable events and cleanup. Explain demand mismatches. Proposed pilot non-regression target ≤5% p95 increase; not a substitute for the absolute 120 Hz target. |
| P02 — saturated/idle | Exercise near-capacity paid casts/products, long repeated loops, then idle and leave/rejoin; include normal/reduced effects | Existing caps/refusal-before-spend and cleanup hold. No unlimited fountains, live decoration agents, tile nodes, event flood or unbounded memory. Static art cost is bounded independently of world acreage. |
| P03 — release gate | Sustained rendered workload on declared target hardware, actual remote lifecycle and the exact candidate topology | 120 Hz authority budget and required rendering targets must actually be met. A headless result or a ≤5% regression against a failing baseline does not pass release. |
| X01 — rollback | With a clean candidate, create the exact baseline via guarded tool; compare hashes and run the same source validator | Exact baseline bytes restored in separate output; newer edits are refused, not overwritten. Content/version peers return to the same agreed map. |

## Existing red evidence stays red

The supplied profile's dense-crucible run reports p95 step 68.381 ms, capture/wire-pack 673.295 ms and total host work 720.374 ms, against an 8.333 ms authority interval. These are historical fixture measurements, not newly measured performance. The supplied network artifact records a failed 300-second watchdog with partial lifecycle evidence. Neither a static cell-count decrease nor this HTML makes those gates green. See copied raw evidence and the audit snapshot. [S12]

## Minimum pilot decision

Approve geometry integration only after M01–M03, T01–T05 and C01–C06 pass the declared fixtures and known lifecycle/performance blockers are addressed for the intended release scope. Approve presentation after R01–R03/U01–U04. Approve remote management only after N01–N04. Approve any new acreage only after P01–P03 on the established courtyard. A local experiment branch can remain explicitly experimental while broader release gates stay red.
