# FLUX-CHEMISTRY-v1 — handoff
**Decision state: PROPOSAL. Integration: NOT_RUN. Human acceptance: PENDING.**

## What is delivered

`IMPLEMENTED_VS_PROPOSED.md` audits supplied execution paths, documents contradictions with thematic prose, and identifies missing runtime evidence. `REACTION_ROLES.md` contains all ten unordered first-four reactions, mirrors first, their numeric selection/phase baselines and all four delivery families. `EXPERIMENTS.json` contains exactly six ordered, reversible experiments, one or two named variables each. `COUNTERPLAY_TESTS.md` specifies 29 deterministic cases and seven short human drills. **Every experiment, game case and human drill is NOT_RUN.**

The `evidence` directory contains source references/excerpts, extracted numeric baselines, the exact supplied input manifest, and checks actually executed. The Python verifier is a package/integrity checker, not a game harness.

## Access and baseline

Read the supplied input manifest, shared contract, audit snapshot, chemistry brief and relevant copies of specification/queue/checkpoint. Inspected all four core chemistry source files, geometry, catalog, presenter, snapshot/prediction wrappers, visual/body metadata, and historical reports. Visually inspected the saved normal/reduced Steam captures; they are not fresh game runs. See `evidence/SOURCE_REFERENCES.md` for exact file paths, read scope, hashes and source ranges.

Source packet: `flux-delegation-20260920`; reported runtime identity `p53-cb264f9358a4`; reported git head `a1aa02807626823d0fbc1e25e75441ca3b7f4d36`. The packet is selective and does not contain a runnable project. All 63 input-manifest records passed byte/hash verification. **No game source was modified, no repository was fetched, no Godot process was run, and no changes were committed or pushed.** [MAN; AUDIT:L9-L19; AUDIT:L39-L41]

## Highest-priority findings

The existing Vortex eye does not survive whole-hex selection. Current Conflagration and ground flows can accumulate through separate product paths. Weak Water cooling can increase Steam's computed pressure because added matter offsets its intensity reduction. Fading Steam can accept paid modifiers after danger ends. The Steam presenter prevents its cool palette through a 1000-intensity cell floor and lends one product's heat to overlapping products. Magma's pulse damage is currently unscaled by matched strength. See findings F01–F16; these are source/arithmetic conclusions or explicitly marked risks, not fabricated playtest outcomes.

Several counters in the thematic catalog are not established runtime hooks: Vortex projectile/airborne redirection, Flood basin/elevation behavior, Steam concealment, automatic wind/ice clearing, and Magma→basalt transformation. Rampart's six-face/safe-creation policy does not prove safe dynamic collision or wall actions without the missing implementation and an actual test. [J:L51-L75; P:L197-L272; C:L576-L583]

## Exact integration sequence

| Order | Experiment / candidate | Primary proposed live targets (relative to repository root) | What stays fixed |
|---|---|---|---|
| 1 | **E01 Vortex eye:** effective inner radius30→74px; raw compiled length24000→59200 | `src/sim/hex/hex_recipe_policy.gd` | Outer90px, flow45px/s, lifetime, exact whole-cell selector, source matter |
| 2 | **E02 Conflagration overlap:** global72-tick pulse plus strongest eligible wire309 contribution | `src/sim/hex/hex_chemistry_world.gd` | Damage formula, teams/protection, every paid field and its quantity/geometry/lifetime; other damage groups |
| 3 | **E03 Ground flow:** aggregate already-eligible first-four deltas; net cap60240units/s (502units/tick) | `src/sim/hex/hex_product_effects.gd`, `src/sim/hex/hex_chemistry_world.gd`; root-owned event serialization if required | Existing per-product carry, common18px collision clearance, all paid products, later-four movement |
| 4 | **E04 Magma commitment:** `floor(5000*min(1000,I)/1000)` per pulse | `src/sim/hex/hex_product_effects.gd` | Slow750/1000, ground contact, moving reach/life, other recipes, actual paid costs |
| 5 | **E05 Steam counter:** cooling matter performs consumed work instead of adding density; skip decay-only modifiers | `src/sim/hex/hex_chemistry_world.gd` | Existing intensity subtraction, finite ledger, original pair transfer, heating behavior, coverage, one-use channels |
| 6 | **E06 Steam style:** source each region's heat from its own intensity | `src/presentation/hex_court_presenter.gd` | All simulation/network state, opacity/particle budgets, phases and coverage |

E03's 502-unit discrete step bound includes a two-unit rounding allowance above 60000/120. Existing per-product carry can produce a diagonal step slightly longer than500 units even for an unchanged60px/s isolated Flood. This bound avoids accidentally nerfing that isolated movement; no field gains speed.

Experiment switch names in JSON are **proposed labels**, not claims that current config keys exist. E01–E03 start with mirrors and overlap; E04–E06 address cross-pair decisions. Run each against an individually frozen baseline; do not silently accumulate all six and lose attribution. E05 has two stated factors and explicit diagnostic arms. Combined accepted changes need an additional whole integration regression, not a seventh unrecorded tuning pass.

Before editing, the integrator must compare the live source with the packet, preserve the user's dirty work, announce exact owned files, schedule engine runs, and resolve actual ability costs/control data. Root owns any event/snapshot version consequences of E03. Coordinate E06 with the VFX worker. No renderer should invent authoritative chemistry state. No shared catalog, source ID, slot, body template or later-four feature is to be mass-rewritten. [CONTRACT:L14-L35]

## Validation and rollback

Use the source references and each JSON baseline to reproduce the current behavior first. D05/D16/D17 deliberately document problematic baselines; do not redefine them as passes. Keep game/human status `NOT_RUN` until real logs/captures are attached. A source hash and Python arithmetic are not Godot integration evidence.

Run the listed deterministic cases, native normal/reduced floor checks, each short human drill, then the equal-demand load comparison. Record all release opportunities and admissions/refusals, eligible and applied effect counts, active-cell work, source conservation, raw/packed/fragmented bytes and event retention/encoding semantics. Keep hidden workload reduction out of the comparison. E01 may intentionally reduce covered cells; E02/E03 may intentionally reduce applied overlap events; disclose those semantic changes instead of presenting them as free performance wins.

Saved Full-v2 success is historical. The supplied timing probe failed the8.333ms deadline badly, and the300s localhost lifecycle did not complete. Relative no-regression is only a diagnostic gate; it cannot promote the current build to accepted120Hz/rendered/network status. Complete local Full and lifecycle evidence, plus human acceptance, remain required. [AUDIT:L13-L18; PROFILE; NETWORK]

Rollback is per experiment: restore only the owned diff/variables, rerun its focused baseline, retain failed evidence and leave unrelated dirty work untouched. Do not reset, stash, clean, delete shared files, switch the shared branch, push, publish or promote P53. Keep the known fallback selected unless separately authorized.

## Missing inputs / unresolved issues

The project, CombatTuning/actual ability catalog, StrengthBudget, HexCastParts, trail emitter, MovementTuning/System/PlayerState, complete dynamic collision, SimWorld order, chemistry snapshot serializer, local controls/profiles and test harness are not present as a complete buildable dependency set. Exact family economics, repeat rates, direct-hit control duration, natural jump reach, safe Rampart embedding/escape and full networking therefore remain unverified. Source wrappers and historical evidence do not fill these gaps.

Known issues outside the six candidate changes remain diagnostic: cross-recipe additive damage, neutral Rampart obstruction/spawn harassment, Heavy blast height/size asymmetry, per-recipe Mistcurrent flight suppression mask, full-utility weak-source Rampart/Mistcurrent/Vortex, spent-capacity cues, and broader multi-layer readability. No additional untested buff or new tertiary interaction is smuggled into this handoff.

## Recheck the delivered package

With Python3, from the extracted output folder:

```text
python tools/verify_package.py
python tools/verify_package.py --source-zip /path/to/FLUX-SOURCE-PACKET.zip
```

The first command checks manifest hashes, source-reference ranges in bundled excerpts and all experiment/case status declarations. The optional second checks the supplied source archive and its 63 input records. Neither launches FLUX. `evidence/PACKAGE_VALIDATION.json` records the checks actually performed during delivery. Treat its success as **STATIC_VERIFIED**, not RUNTIME_VERIFIED or HUMAN_ACCEPTED.
