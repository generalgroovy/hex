Status: historical source-only reconciliation; current results supersede its NOT_RUN statements.

# HEX handoff reconciliation

Status: source-audited integration preparation at the isolated HEX checkout. The
new test and measurement sources are written but **NOT_RUN**. No gameplay value,
production coefficient, test registration, engine process, export, pointer, or
release artifact is changed here.

## Scope and acceptance boundary

This reconciles `HEX_QA_ACCEPTANCE.md`, `HEX_BALANCE.md`, and
`HEX_BALANCE.experiments.json` with the current FLUX source. The external handoff
correctly labels all twelve game cases and all three balance experiments
`NOT_RUN`; its proposed percentages and family ratios are hypotheses rather than
production constants. Godot execution and registration remain owned by the root
integration task.

The bounded contribution is one independent Steam occupation regression and one
measurement-only paid-cast profile. Both preserve these current invariants:

- continuous movement and projectile flight; selected whole cells are the
  gameplay membership authority;
- Steam is visible capped scald pressure, with exposure cap 240, exit decay 2,
  one shared pressure pulse every 30 authoritative ticks, and a hard 12,000
  damage ceiling;
- two paid sources transfer two finite 600-unit matter budgets once; exposure,
  traversal, protection, and re-entry do not spend, refresh, or clone them;
- spawn protection suppresses actor exposure/damage while the ground product
  remains live;
- Small/Middle/Large keep their authored 17/18/19 px hurt radii. Current Steam
  authority samples the grounded foot path, so body size cannot secretly change
  field membership;
- no external 0.80/1.00/1.20 coefficient, 5%/8% crossing bound, 25–45% dwell
  band, or 1.05 re-entry ratio is promoted into the product contract.

## Decision table

| Handoff contribution | Decision | Current source evidence | Integration result |
|---|---|---|---|
| QA-01/02 exact origin and whole selected cells | **ADAPT** | `src/sim/hex/hex_grid.gd`, `hex_footprint.gd`, and `hex_chemistry_world.gd`; existing `test_hex_selection.gd`, `test_hex_footprint.gd`, and `test_hex_whole_coverage.gd` already cover boundaries, whole-cell rendering/gameplay, swept traversal, protection, and finite allocation. | The new Steam regression adds an explicit outside-generating-radius point inside a selected whole cell. It does not duplicate the geometry suites. |
| QA-03 eligible Wellspring ground with protection kept separate | **ADAPT** | U6 records whole-campus eligibility; `HexChemistryWorld._expose` gates protected actors before live ground sampling changes any actor state. | New protected/unprotected actors share the same live Steam product. Protection decays prior exposure without removing or refreshing the product. |
| QA-04 finite strength and ingredient accounting | **ADOPT** | `hex_chemistry_world.gd`, `strength_budget.gd`, `hex_cast_parts.gd`; existing `test_hex_chemistry.gd`, `test_hex_strength.gd`, `test_partitioned_strength_budget.gd`, and `test_reaction_strength_provenance.gd`. | New fixtures require exactly 1,200 paid matter in Steam before and after every exposure schedule and require `conservation_valid()`. |
| QA-05 unequal interception and residual ownership | **ADOPT existing; no duplicate test** | Existing ordered-strength suites cover residual use, retirement, and no ghost terminal deposit: `test_hex_field_interception.gd`, `test_hex_projectile_combat.gd`, `test_projectile_contact_order.gd`, and `test_strength_budget.gd`. | Kept out of the Steam slice. |
| QA-06 all ten first-four pairs, both orders, competing finite sources | **ADOPT existing pair oracle; defer only contested three-input addition** | `tests/unit/test_unified_hex_paid_matrix.gd:20` iterates the ten unordered pairs. Lines 22–27 execute both orders through field formation, projectile clash, and ground deposit. Lines 90, 192, and 278 require the exact 1,200-unit product; lines 116, 219, and 280 require conservation. `tests/scenarios/chemistry_pair_order_oracle.gd` supplies a separate ordered oracle. | No pair-matrix duplication. A future independent same-tick three-input contention fixture remains useful. |
| QA-07 Steam crossing, occupation, re-entry, and render cadence | **ADAPT and implement the authoritative portion** | `hex_recipe_policy.gd:241-244` defines cap/decay/damage bounds. `hex_chemistry_world.gd:861-936` implements fixed-tick whole-cell exposure, strongest-product pressure, protection, and the 30-tick pulse. Existing `test_hex_chemistry.gd:371-427` covers formation boundary, height, overlap maximum, intangibility, and one exit-decay sample. | `test_hex_steam_occupation.gd` adds 12-vs-60 tick occupation, exact independent damage arithmetic, six-tick exit/re-entry, same-product seam deduplication, protection expiry, and all three body radii. Presentation frame-rate comparison remains outside this headless unit slice. |
| BAL-E1 Steam coefficient sweep and percentage bands | **DEFER tuning; adopt measurement shape** | No source evidence says the current coefficient is wrong, and the proposed bands were never run. | `profile_hex_steam_balance.gd` measures 12/30/60/120/240 contact windows, five 12-tick visits separated by 15 outside ticks, and a continuous 60-tick comparator. It changes no coefficient and applies no proposed band. |
| BAL-E2 family-role ratios | **REJECT as current acceptance; defer research** | Current family strengths and paid behavior already exist; the handoff ratios are unverified hypotheses. | No family buff, nerf, or role gate is added. |
| BAL-E3 requested 1/4/16 packet and 1/7/19-cell matrix | **REJECT as required production geometry; retain invariant** | Existing whole-cell and partitioned-strength suites require finite allocation without inventing unsupported delivery shapes. | The invariant “child allocation cannot exceed paid parent budget” remains; unsupported fixture counts are not synthesized. |
| QA-08–11 late join, reconnect, lifecycle, and event pressure | **DEFER** | The active queue records physical two-PC as `NOT_RUN`, production localhost lifecycle as failed, and performance capacity as unaccepted. | These remain separate networking/performance work; the Steam slice makes no acceptance claim. |
| QA-12 reduced-effects human readability | **DEFER human gate** | Native captures do not establish reviewer understanding or accessibility acceptance. | No five-reviewer claim is made. |

## Existing all-pair oracle coverage

The external handoff treated pair identity and implementation as unknown because
it did not receive the repository. Current coverage is already precise:

- `src/sim/hex/hex_recipe_policy.gd:22-30` stores the explicit symmetric
  first-eight triangular wire matrix; `FIRST_TEN_WIRES` identifies the ten
  Water/Earth/Fire/Air products.
- `tests/unit/test_unified_hex_paid_matrix.gd:20-27` enumerates each of the ten
  unordered first-four pairs and invokes both orders through three real paid
  trigger paths.
- `_test_pair` at line 77 checks stable recipe identity, two distinct sources,
  quantity 1,200, a live product outcome, and conservation.
- `_test_projectile_clash_pair` at line 123 uses two real champions and actual
  paid Bolt startups; it checks canonical recipe identity, equal-strength
  exhaustion, absence of a terminal clone, exact source ledgers, and complete
  product transfer.
- `_test_paid_deposit` at line 223 proves terminal-only whole-cell overlap can
  form the same canonical product without an earlier projectile/field clash.

The minimal missing all-pair case is not another 10×2 table. It is one
independently expected, same-tick Water/Earth/Fire contention fixture that
varies irrelevant candidate enumeration and proves one deterministic affordable
commit with no double debit.

## Steam additions

`tests/unit/test_hex_steam_occupation.gd` derives expected exposure and damage
without calling the production exposure helper. It uses the authored numeric
contract directly and checks:

1. a selected-cell point 80 px from product origin is affected despite lying
   outside Steam's 64 px generating radius;
2. 12 and 60 stationary contact ticks produce exactly the independently
   calculated exposure/damage, and the longer occupation is not safer;
3. 12 inside, six outside, and 12 inside yields exposure 12 after the authored
   two-per-tick exit decay, with no entry bonus or budget refresh;
4. crossing an adjacent-cell seam in one product yields one exposure and one
   pressure pulse, matching a stationary comparator on the stronger allocation;
5. protected and unprotected actors on the same live ground diverge only by the
   protection rule; clearing protection resumes accumulation without changing
   product quantity;
6. all outcomes are identical for the authored 17/18/19 px body radii because
   current Steam authority uses the grounded foot-path convention.

`tests/performance/profile_hex_steam_balance.gd` forms one Steam field per body
type from two real paid Bolt commands on the production campus. It runs at most
240 measured ticks with eight actors, records exact contact/exposure/damage
traces for all five requested windows plus continuous/re-entry/protected controls,
checks each result against an independent fixed-tick calculation, preserves the
1,200-unit product, hashes the source inputs, and writes a scoped JSON receipt.
It is a deterministic balance measurement, not a rendered or networked
performance acceptance test.

## Controls and loadout persistence correction

The queue statement at `.agent/OVERHAUL-IMPLEMENTATION.md:119-120` saying there
is no new saved-weave feature is stale relative to current source. The present
`CharacterWeaveLibrary` performs bounded JSON validation, staged verified writes,
one recovery backup, and fail-closed replacement. Current tests prove:

- custom weaves, including a retained disabled ability ID, remain unchanged
  while previewing every character (`test_character_weave_library.gd:59-83`);
- backup/primary write failures preserve exact bytes, successful custom storage
  reloads exactly, and repeated save is byte-identical
  (`test_character_weave_library.gd:88-132`);
- applying another character and returning restores the original custom weave
  (`test_character_weave_integration.gd:71-84`);
- bootstrap configures the persistent coordinator when persistence is allowed
  (`src/app/bootstrap.gd:4397-4398`).

Controls persistence separately has round-trip coverage in
`test_controls_round_trip.gd`, `test_control_binding_editor.gd`,
`test_player_preferences.gd`, and `test_input_router.gd`, including custom,
partial, and explicitly empty maps. `LoadoutDefinition` remains the authored
static content projection and should not be conflated with the per-character
saved-weave store.

## Commands for the integration owner

Registration in `tests/run_all.gd` and every Godot process remain root-owned.
After registration, use the repository's normal focused-test runner for:

```powershell
pwsh -NoProfile -File scripts/test.ps1 -Tier Focused -Suite hex-steam-occupation
```

Run the measurement with a fresh receipt name:

```powershell
. .\scripts\flux2-common.ps1
Invoke-FluxGodotChecked (Get-FluxGodot) @('--headless', '--path', (Get-FluxRepoRoot), '--script', 'res://tests/performance/profile_hex_steam_balance.gd', '--', '--output=res://.godot/hex-steam-balance-<fresh-id>.json') '.godot\hex-steam-balance-<fresh-id>.log' -RejectWarnings -TimeoutSeconds 180
```

`Invoke-FluxGodotChecked` resolves the pinned Godot runner, acquires the engine
lease, bounds the process, and retains stdout/stderr. These commands are
documented only; both remain **NOT_RUN** in this handoff.

## Risks and rollback

The largest execution risk is an off-by-one difference between direct unit
ticks and `SimWorld.step`'s reported processed tick. The profile records the
sample start and checks every result against its explicit schedule, so any such
difference should fail visibly rather than become a balance conclusion. A
failed new test establishes only the observed discrepancy; it does not authorize
tuning Steam.

Rollback is deletion of the two unregistered new test files and this document.
No production source or persisted user data depends on them.

## Integrated NET, PERF and presentation decisions

| Package | Decision | Current implementation boundary |
| --- | --- | --- |
| NET handoff | ADOPT evidence-first lifecycle tracing; ADAPT exact p53 trace points | Root traces real close, RESULT countdown, Hearth commit and snapshot send. No timeout/rate reduction. |
| PERF handoff | ADOPT paired measurements, byte equality, explicit ownership; ADAPT hotspot order | Current snapshot stage profile precedes changes. No shared mutable nested caches or unmeasured speed claims. |
| ANIM_SPEC, 64 matrix, validation report | ADAPT pilot criteria; DEFER new art/contact tracks | Existing three-size64move/aim banks already exist; North index4 differs from proposed0. Proposal checks do not prove game animation. |
| VFX handoff, Steam HTML, two inspection PNGs | ADAPT transparent hot vents and phase cues; REJECT labeled boards as atlases | Three embedded PNGs recovered with exact hashes/alpha in reference/art/hex_handoff_steam; absent manifest/builders not invented. Source polygon/phase drives procedural pilot. |
| HEX-UX HTML | ADAPT effective binding labels and explicit missing/unbound states | Preserve native12slots,32spells, drafts, savedcustomweaves; reject four-element replacement. |
| Two map PNGs | ADAPT wayfinding/composition reference; DEFER terrain replacement | Existing campus routes/collision remain. Images provide no usable collision or level data. |

All15 originals are inventoried and copied unchanged under reference/hex-handoff-20260920, which is excluded from Godot import. Historical validation claims remain proposal/package checks. The user explicitly authorized HEX branding/new repository/push, superseding contradictory clauses in the supplied prompt.
