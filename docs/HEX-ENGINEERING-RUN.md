# H.E.X. engineering research and checkpoint

Status: October 3 engineering checkpoint `p56-a15adfd5d74b` READY FOR LOCAL SOLO
TEST. Full and native Windows launch/close pass; same-export multiplayer lifecycle
FAILED its 120-second deadline. Previous `p56-90e292bc8237` is preserved as fallback.

This run targets measured crowd cost, transactional client state and the next
snapshot representation seam. It turns reference-game inspiration into small
acceptance tests. The [execution prompt](../.agent/OVERHAUL-PROMPT.md) and
[single queue](../.agent/OVERHAUL-IMPLEMENTATION.md) own execution order.

## Research translated into acceptance

Applications in the right column are H.E.X. design inferences, not assertions
that another studio used our implementation or test procedure.

| Primary source | Supported lesson | Application and acceptance |
|---|---|---|
| [Noita official FAQ](https://www.noitagame.com/) | Characteristic materials combine through simplified chemistry and physics | Keep a compact reaction grammar; repeated paid combinations must give consistent effects, costs and counters |
| [Nintendo on intuitive interactions](https://www.nintendo.com/us/whatsnew/ask-the-developer-vol-9-the-legend-of-zelda-tears-of-the-kingdom-part-5/) | Visual distinctions communicate what objects can do | Compare visible walls/hazards with actual obstruction and affected cells; decoration must not imply nonexistent mechanics |
| [Nintendo on memorable characteristics](https://www.nintendo.com/us/whatsnew/ask-the-developer-vol-13-the-legend-of-zelda-echoes-of-wisdom-part-2/) | Distinct capabilities and immediate intuitive results support experimentation | Acknowledge admitted/refused input truthfully; never fake early spell release |
| [Riot on clarity](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/) | Importance, silhouette, direction and hitbox correspondence matter | Native eight-heading stills on room palettes, normal/reduced effects; identify aim, travel and active danger without trails |
| [Respawn action blocks](https://gdcvault.com/play/1025105/Designing-Unforgettable-Titanfall-Single-Player) | Isolated rapid gameplay prototypes supported Titanfall level development | Test one room, two routes, a paid hazard and pressure source before expanding the map |
| [Riot on shaders and clarity](https://www.riotgames.com/en/news/valorant-shaders-and-gameplay-clarity) | Performance and visual settings must preserve competitive information | Exact native comparisons for presentation reuse; all-visible workload matters as much as culling savings |
| [Respawn network engineering](https://www.ea.com/games/apex-legends/apex-legends/news/servers-netcode-developer-deep-dive) | Tick work, delivery, bandwidth and prediction are separate concerns | Measure simulation, encode/decode, packet load, correction and frame time independently; render proxies do not prove capacity |
| [Godot CPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html) | Profile repeatedly and account for cache effects | Pair old/new measurements, cold admission and warm paths, frozen semantics and memory tradeoffs |
| [OpenAI multi-agent guidance](https://developers.openai.com/api/docs/guides/responses-multi-agent) | Bounded independent work benefits from separate context; shared-state work can cost more | Three owned workstreams, one integration/engine owner, short artifact-based handoffs |
| [OpenAI prompting revision](https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra) | Accumulated instructions can become redundant context | One current queue and concise prompt; preserve invariants/evidence without repeatedly copying historical narrative |

No inaccessible frame data or engine internals are attributed to Melee, Magicka,
Gungeon, Hades or Zelda Oracle. Their aesthetic/gameplay role remains, but no
proprietary assets, exact physics constants or unverified implementation claims
are imported. Do not add per-pixel fluids or bundle movement retunes while
current dense timing remains over budget.

## Work ownership

| Workstream | Owner and boundary | Gate |
|---|---|---|
| Replica and prediction publication | Lead; bootstrap/prediction and dedicated tests | Refusal leaves published state intact; same/new epoch and spectator paths coherent |
| Presentation work removal | Presentation worker; wrapper/full-body/motion, frozen oracle and paired probe | Exact outputs, caller isolation, native pixels and measured cost without eager descriptor cache |
| Immutable topology prototype | Snapshot worker; test/support only | Signed64 metadata, exact order/bytes, sparse zero coverage, detached mutation, honest import costs |
| Research and review | Read-only specialist | Primary links, scoped inferences, adversarial review after implementation |

## Evidence and remaining limits

| Fresh experiment | Result | Decision |
|---|---|---|
| Focused v1 | Six suites, 160,502 assertions, zero failures/stderr | Covers initial implementation only; expanded publication edges and replacement renderer still need execution |
| Eager pixel-descriptor cache | Exact outputs passed, but about 18.1 MiB extra allocation; 64-walk wrapper 10.341 to 10.276 ms median and 64-jump bank regressed 1.199 to 1.331 ms | Rejected; production banks restored byte-for-byte; sources/receipt retained as rejected evidence |
| Immutable topology probe v1 | Outer runner FAILED on eight typed-array errors; internal PASS was incomplete | V2 corrected ordering and added fail-closed receipt/sample/trace/source validation |
| Immutable topology probe v2 | PASS 1,510 assertions; four complete cases, eight paired states, every 40-tick paid trace, unchanged sources, zero stderr | Ownership/replay prototype accepted, not shipping storage; paid-state clone medians 23.994–43.311 ms full vs 0.201–1.130 ms sparse, while strict imports still cost 606–696 ms |
| Focused v2 | All seven internal assertion summaries passed, but mesh-metadata errors caused outer FAIL | Test helper repaired to inspect available geometry explicitly; fresh rerun required |
| Focused v3 | Publication and nine available suites pass; descriptor suite did not instantiate due to inferred Variant boolean in test helper | Outer FAIL retained; explicit bool correction, then fresh run |
| Presentation probe v2 | Parse FAIL from an undeclared fixture action | Both arms now use identical fixture action/cast values |
| Presentation subtraction v3 | PASS 48 paired cases, 871,739 assertions, unchanged source, zero stderr | 8-object walking 1.174 to 1.043 ms; 64-object moving cast 9.881 to 8.664 ms median; no new persistent cache |
| Native presentation v1 | PASS 108 exact culling comparisons; all 108 PNGs also hash-match the preceding scale/performance capture | Fixed-pixel and wireframe paths, normal/reduced, three zooms; no changed pixels in this fixture |
| Focused v4 | PASS 10 suites, 193,070 assertions, zero stderr | Production publication/prediction, complete descriptor/fallback geometry and existing snapshot regressions |
| Producer bridge unit v1 | PASS 340 assertions, zero stderr | Exact old/new capture, refusal, isolation, single-use source binding and adversarial config re-entry |
| Native UI v1 | PASS 70 checks and 13 frames, zero stderr | Actual application routes for Loom assignment, paid cast, hidden layer, rebinding, Gallery and station refusal; isolated profile |
| Producer bridge profile v1 | PASS 1,273 assertions, 12 complete states across four cases, exact snapshot/wire bytes and source guard | Complete capture medians 10.1–14.0% lower; still 347.8–394.7 ms, not cadence acceptance |

### Shipping snapshot candidate: complete capture

One call-local operation reuses its locally validated topology order, indices,
bytes and fingerprint only inside producer encoding/self-roundtrip. The operation
is single-use and retains its own detached geometry and snapshot witness. Public
incoming preparation does not accept such a context and validates topology fresh.
Dynamic lane decode, paid conservation, source/projectile/actor relationships,
canonical hashes and detached authority remain mandatory. Protocol 56, snapshot
schemas and current capacity limits do not change.

| Ordinary paid fixture, forward input order | Before median | Candidate median |
|---|---:|---:|
| Distributed, empty | 419.439 ms | 370.685 ms |
| Distributed, paid tick 40 | 430.695 ms | 382.031 ms |
| Distributed, next mutating tick 41 | 435.271 ms | 391.492 ms |
| Dense, paid tick 40 | 415.465 ms | 365.102 ms |

Displayed rows are rounded; the [raw producer receipt](engineering-evidence-20261003/producer-topology-reuse-v1.json)
owns exact values. Each state has one cold observation per arm and six alternating
warm samples per arm. P95/P99 are sample-limited, not reliable tail estimates.
These timings include complete encoding, compression, detached self-validation
and hashes, but exclude transport, sockets, rendering and simulation. Inputs are
unchanged eight-champion fixtures, not 64-player evidence. The persistent cache
from the rejected presentation experiment is absent.

## Release candidate

Source identity `p56-a15adfd5d74b`, SHA-256
`a15adfd5d74b719ca87a323d4460194a2bab6354c6fb92517dbdc1c4d6046a28`,
3,083 runtime records. Full regression PASS: 184 suites, 3,344,204 assertions,
zero failures and zero stderr bytes; import and 120 Hz boot passed. The complete
gate took 634,297 ms; this is test duration, not runtime performance. [Full receipt](engineering-evidence-20261003/full-v1.json).
Windows portable export and native launch/safe close PASS. [Package receipt](engineering-evidence-20261003/package-v1.json).
Launch `exports/hex-engineering-20261003/windows/PLAY-HEX.cmd`; keep EXE/PCK together.
ZIP `HEX-p56-a15adfd5d74b-Windows-x64.zip`: 115,766,367 bytes (110.4 MiB).
PCK SHA-256 `75a5c0c0b41f0934c8b8aac0c8a9adc1343be4d3ea7b30b0fe2b5a86df05b5d8`;
ZIP SHA-256 `b1ad55130d51c8f493954005e2aac33b2c23b8759867a9404a880a3760acbc86`.
The mounted-PCK v2 native diagnostic passes all 108 comparisons; all 108 PNGs
also SHA-256 match the source capture. [Pack render receipt](engineering-evidence-20261003/native-pack-v2.json).
The production source is frozen. Native UI captured this identity; render/culling
fixtures preserve the same presentation source. The prior scale/performance
portable remains the safe fallback throughout candidate work.

### Networking and delivery boundary

[Same-export lifecycle](engineering-evidence-20261003/network-v1.json) FAILED at
120 seconds. Connection, shared emote, readiness, authoritative guest movement,
first round, and late-guest spectating occurred; Hearth handoff and rematch did
not complete by the deadline. All three stderr logs are empty. Capturing/sending
snapshots remains hundreds of milliseconds and first-round countdown ran far
slower than real time. This is a dependency, not a cosmetic warning or a test
timeout to hide by raising the watchdog. Physical internet play and relay remain
unaccepted; no installer, publication, push or historical pointer promotion.

The first mounted-PCK image check used a read-only `res://` output directory and
FAILED before rendering. The diagnostic now also accepts a fresh normalized
absolute `.godot/character-viewport-*` output; production is unchanged. This is
retained as a diagnostic failure, not a failed game boot.

The preceding scale/performance PCK/ZIP hashes were freshly rechecked unchanged.
All task-owned engine processes are closed by their wrappers. Original assets,
dirty user work, failed diagnostics and earlier portable builds are preserved.
Eight export directories now remain: the previous cleanup block was not bypassed.
Only the new candidate and preceding scale/performance build are the current
recommended comparison pair; older folders are history, not newly accepted builds.

## Next bounded dependency

The next production slice is enforced immutable topology plus sparse mutable
ownership, then exact canonical/hash and prediction integration. The prototype
proves ownership and copy opportunity, not a ready drop-in replacement. Migrate
all direct cell readers/writers and preserve zero coverage, signed metadata,
complete timed products and canonical order before removing full-cell views.
Then repeat exact replay, incoming malformed-state refusal, complete snapshot
profiling and actual package lifecycle. No capacity increase comes first.

Art continuity pilots (Red Baron/Fluup/Haara), distinct lateral/low/flight cycles
and one small encounter room follow their own native/human gates. Research and
engineering completed here do not establish final art, balance, audio quality or
an exquisite all-around human experience; those require visible/played acceptance.

Independent static review found and corrected a custom-config re-entry hole in
the producer candidate and cold-test cache contamination. Concrete configuration
and transition-policy admission now joins the existing concrete world/actor
gate; subclasses keep strict revalidation. The mandatory detached blank is copied
before encoding, never from a later possibly changed source. Cold oracle and
candidate arms reset their shared cache separately.

The native UI fixture arranges station position/focus and supplies synthetic
input; it does not prove physical input or human readability. Representative
inspected output: [Wellspring HUD](engineering-evidence-20261003/wellspring-hud.png)
and [Spell Loom](engineering-evidence-20261003/spell-loom.png). No new art, movement
rules, spell balance, size stats or body templates were introduced in this run.

### Shipping presentation candidate: measured CPU preparation

Each row has 40 warm-up pairs and 240 measured pairs in alternating ABBA order.
All objects are queried; savings here are not caused by hiding offscreen actors.
The independent preceding wrapper preserves its old discarded calculations and
definition copies. Complete descriptors match after every pair. Art banks are
unchanged and act as a control.

| Render objects / action | Before median | Candidate median | Change |
|---|---:|---:|---:|
| 8 walking | 1.174 ms | 1.043 ms | -11.2% |
| 8 moving pending cast | 1.182 ms | 1.057 ms | -10.6% |
| 64 walking | 9.869 ms | 8.798 ms | -10.9% |
| 64 moving pending cast | 9.881 ms | 8.664 ms | -12.3% |
| 64 jumping | 6.664 ms | 6.367 ms | -4.5% |

This is synthetic CPU preparation, not drawing, GPU frame time, input latency,
simulation, sockets, or 64 admitted players. In particular several 64-object
preparation rows alone exceed the 8.333 ms full-tick budget. Exact sources/raw
samples: [presentation receipt](engineering-evidence-20261003/presentation-subtraction-v3.json).
Prototype receipt: [topology ownership experiment](engineering-evidence-20261003/immutable-topology-v2.json).

The prototype exposes a real ownership advantage, but complete compatibility
projection still builds full legacy state. Its clone result excludes admission,
strict import, collision, canonical projection, rendering and networking. Do not
apply that percentage to the game. A separate production bridge now targets
redundant topology passes inside one synchronous snapshot capture; incoming
untrusted preparation must remain strict and byte-identical.

Prior portable 179 suites and native/package checks do not validate this
candidate. Dense 120 Hz remains FAILED; 16/32/64-player tiers remain UNSUPPORTED.
Physical internet play, full anatomical continuity, complete animation cycles
and human feel remain separate gates. Presentation object counts are not active
networked-player capacity, and prototype ownership proof is not shipping snapshot
optimization.
