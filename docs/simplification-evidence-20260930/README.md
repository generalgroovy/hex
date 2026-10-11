# Reactive tempo and simplification evidence

Status: local playtest checkpoint p56-c47fb65e2bd7. Full/native correctness and Windows package launch/safe-close passed; dense 120 Hz failed.

Scope: faster cast cycles, 25% slower travelling shots, held Bolt ergonomics,
actual-key-first Loom, canonical render identities and bounded phase-local work
reuse. Design and exact values: [HEX-SIMPLIFICATION](../HEX-SIMPLIFICATION.md).

## Evidence classification

| Directory | Meaning |
|---|---|
| `failed-identity` | Rejected stale test dependency on removed duplicate identity table |
| `focused-identity` | Canonical identity parity corrected; 63,950 assertions |
| `failed-style` | Rejected palette test reading a nonexistent Earth phase property |
| `focused-style` | Correct live-palette and bounded style tests; 82,965 assertions |
| `failed-loom` | Rejected reference to nonexistent card-width constant |
| `focused-teaching` | Actual card geometry and key-first layout; 88,855 assertions |
| `failed-tempo-fixture` | Rejected firing-interval fixture omitted startup; 64 failures |
| `focused-tempo` | Actual startup + cooldown and unchanged paid costs; 41,497 assertions |
| `focused-field-reuse-initial` | 41,563 assertions, but missed the empty scheduling branch later caught by stress testing; not sufficient acceptance |
| `pressure/*before*` | New tempo, original repeated field preparation; real paid eight-caster baseline |
| `pressure/*after.json`, `pressure/*after.log*` | FAILED typed-empty-array scheduling; equal hashes do not rehabilitate this run |
| `pressure/*after-v2*` | Corrected field preparation; zero stderr, all 1,440 tick/event states match baseline |
| `native-initial` | Intermediate pre-held-Bolt native style comparison and 42-check/10-frame UI journey; not final source acceptance |
| `failed-held-fixtures` | Held behavior tests passed; old signature normalization, old-speed terminal deadline and changed explanatory wording failed; retained for audit |
| `failed-source-freeze` | Preflight rejected a stale manifest after a validation edit during generation; no engine tests ran; final source frozen/regenerated instead |
| `failed-heavy-authoring-fixture` | Rejected fixture tried to mutate generated Heavy through the explicit-ability list; corrected to its authored family template |
| `failed-full-family-coupling` | Full gate rejected held-Bolt identity inferred from trigger behavior:30 failures and two dependent fixture errors; fixed in runtime by explicit compiled family, not by weakening the paid chemistry fixtures |
| `focused-family` | Correct delivery identities and unchanged paid ground-reaction fixtures:6 suites /39,898 assertions |
| `full` | Final source:172 suites /1,786,509 assertions, zero failures/stderr; import/identity/120Hz configured boot passed |
| `failed-ui-guard` | Added fixture pressed during deliberate menu-close suppression; retained failure, not a released candidate |
| `native/ui` |49 checks /11 captures; three ordinary paid held-Bolt admissions, release-stop and original menus/bindings/attunement |
| `native/hex-style-reuse-final.json`, `native/fields` |1,246 checks;4 paid-scene RGBA/state pairs and6 all-material controls exact; compact Normal performance regressed |
| `pressure/*final*` | Final source matches all1,440 baseline states/events; zero stderr. Performance remains FAILED:p9518.387/17.971ms, worst98.565/99.011ms |
| `package` | Source-bound Windows export; 30 skins, native boot/safe-close, zero export/smoke stderr; payload and ZIP hashes checked again during two-build retention |

No rejected result was packaged or selected as playable. Useful failure logs are
retained instead of replacing them with later passes.

## Measurement boundaries

The paid-pressure fixture uses real champions and ordinary input/admission,
including refused attempts. Peak 29 flights, 32 cast records and 29 products do
not prove 128-flight or 32-player capacity. Simulation p95 remains above 8.333 ms;
the largest Spray tick remains above 80 ms. No caps/resources were raised, no
hazards were hidden and no gameplay state was silently dropped.

The native style profiler alternates uncached and shared-style draw submission
over the same frozen paid world. Both arms retain the accepted boundary cache.
Six all-material phase/mode controls are synthetic correctness images, not
gameplay load. Images/state must match exactly. CPU submission is not GPU FPS,
moving cadence, network, human legibility, balance or physical two-PC acceptance.

Windows package identity and safe close passed. PCK SHA256:
`e0c71784d26c8f0f04d24813ac89299750f4d4e12b9c17ad0c1dfa018ceed6ca`.
ZIP SHA256: `aa748a64b6d2b5c9b8177912e63edf20b275e8cb5f3ffe56ea34f7cc2679d74f`.
The exact retained builds are `hex-simplification-20260930` and
`hex-boundary-reuse-20260930`; the older practice export was removed after both
retained packages verified (299,631,411 bytes). Small old-build receipts remain
under `docs/build-retention/hex-practice-masonry-20260929`.
No installer, remote release, Git commit or push is implied by this local work.
