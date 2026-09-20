# Readable projectile and reserve candidate

Status: implemented source candidate, 2026-09-06. Five focused suites pass;
integrated Full, launch, network, density and human feel acceptance remain the
integration lead's next checks. This document does not certify balance or art.

## One observable outcome

Give the player more time to read a moving spell and more reserve for a deliberate
movement/casting exchange, without changing damage, cast cadence, commitment,
ordinary movement or spell access. The broad references inform spacing and
counterplay only; no protected assets, identities or exact systems are copied.

- All 17 moving spell identities (eight Bolts, eight Bursts, Vector Lance) travel
  exactly 20% slower. Lifetime is extended approximately 25% to preserve reach.
- All five playable champions receive exactly 10% more maximum Flux and Stamina.
  Health, recovery rates, recovery delays and movement-speed ratios are unchanged.
- Every first-eight Burst retains the same speed, radius, lifetime, damage,
  five-lane angles, startup, cooldown, recovery and cost as every other Burst.
- The 8-by-5 grid, all 41 spell identities, wire IDs, positive costs, hitbox
  geometry, single-element gate and simulation authority are unchanged.
- Spray/Beam/Field geometry and timing are unchanged. This is a projectile
  readability pass, not a claim that every game action has been slowed.

## Measured projectile comparison

The focused fixture sends both the previous and candidate parameters through the
actual `CombatSystem.advance_projectiles` path at 120 Hz, from the same clear
origin until the authoritative expiry event. It measures the first tick crossing
300 world units, not a theoretical human reaction threshold. The Burst sample
uses its center lane; the existing five-lane tests separately prove identical
mirrored geometry, stable spawn order and valid snapshots for all eight elements.

| Spell/group | Speed, units/s, before -> after | Lifetime, ticks, before -> after | Reach, world units, before -> after | 300-unit arrival, ticks, before -> after |
|---|---:|---:|---:|---:|
| Arc Primary | 960 -> 768 | 144 -> 180 | 1152 -> 1152 | 38 -> 47 |
| Cinderbolt | 840 -> 672 | 150 -> 188 | 1050 -> 1052.8 | 43 -> 54 |
| Rillshot | 900 -> 720 | 138 -> 173 | 1035 -> 1038 | 40 -> 50 |
| Eclipse Disc | 780 -> 624 | 192 -> 240 | 1248 -> 1248 | 47 -> 58 |
| Flintshot, Gale Needle, Rimeshard, Dawn Needle | 720 -> 576 | 192 -> 240 | 1152 -> 1152 | 50 -> 63 |
| All eight Bursts | 700 -> 560 | 132 -> 165 | 770 -> 770 | 52 -> 65 |
| Vector Lance | 850 -> 680 | 180 -> 225 | 1275 -> 1275 | 43 -> 53 |

At that sample distance, measured extra flight time is 9-13 ticks, or
75-108.3 ms. Existing spell startup adds the same warning interval as before.
Cinderbolt and Rillshot require rounding their extended duration to whole
120 Hz ticks; reach drift is respectively +2.8 and +3 world units, below 0.3%.
All other sampled terminal ranges are exact. No range is shortened.

## Resource reserves and sustained pressure

Numbers below are player units; simulation stores each unit as 1,000 fixed-point
units. The before values come from the preceding catalog, and the new values are
validated by applying the actual champion catalog to `PlayerState`.

| Champion | Flux before -> after | Stamina before -> after | Measured paid primary casts from full | Measured exhaustion after |
|---|---:|---:|---:|---:|
| Oh Tipi | 104 -> 114.4 | 120 -> 132 | 19 | 4.600 s |
| S. Wayne | 112 -> 123.2 | 108 -> 118.8 | 17 | 5.250 s |
| The Red Baron | 96 -> 105.6 | 144 -> 158.4 | 17 | 4.825 s |
| Grace Riva | 120 -> 132 | 112 -> 123.2 | 22 | 5.325 s |
| Wa Bidi | 106 -> 116.6 | 116 -> 127.6 | 19 | 5.075 s |

Exhaustion measurements use the ordinary `SimWorld.step` held-primary path and
include finishing the last cast/cooldown before the next cast is unaffordable.
Each count equals floor(maximum Flux / primary cost); the suite then verifies
that a deliberate recovery pause restores another paid cast. Only candidate
exhaustion time is measured here, not a before/after human playtest.

All bodies keep their 100-point declared competitive budget, shared collision,
affinity budget and proportional reserve tradeoffs. The body resource envelopes
move with the +10% reserves. The large Stamina envelope's upper end is clipped at
the existing 160-unit global safety ceiling; The Red Baron's 158.4 fits inside
it. No global authority or transport bound was raised. The larger pools do not
regenerate faster, so refilling an empty pool takes longer at unchanged rates.

## Executed verification

Executed with the repository's pinned Godot 4.7.1 through the ordinary selected
test runner, using an isolated log and warning rejection. No shared
`scripts/test.ps1` log was used by this workstream.

```powershell
. .\scripts\flux2-common.ps1
$gameplayGodot = Get-FluxGodot
$env:FLUX2_TEST_SUITES = 'body-type-profile-catalog,champion-catalog,ability-content,elemental-bursts,combat'
Invoke-FluxGodotChecked $gameplayGodot @('--headless', '--path', (Get-FluxRepoRoot), '--script', 'res://tests/run_all.gd') (Join-Path (Get-FluxRepoRoot) '.godot\diagnostics\gameplay-tuning-20260906-r2.log') -RejectWarnings
```

| Suite | Assertions | Failures |
|---|---:|---:|
| ability-content | 480 | 0 |
| champion-catalog | 941 | 0 |
| body-type-profile-catalog | 43 | 0 |
| combat | 5614 | 0 |
| elemental-bursts | 487 | 0 |
| Total | 7565 | 0 |

The first run found six fixture failures, preserved in
`.godot/diagnostics/gameplay-tuning-20260906.log`: the new Stamina clamp test
needed the movement-owned recovery step, and the old fixed five-second
exhaustion deadline no longer described S. Wayne's larger pool. The corrected
test exercises both ordinary recovery owners and a bounded deadline derived
from authored cost/cadence, while extending exhaustion coverage to all five
champions. No gameplay function was changed to satisfy those assertions.

## Changed files and next acceptance

- `content/abilities/foundation_abilities_v1.json`: speed/lifetime only.
- `content/champions/foundation_champions_v1.json`: Flux/Stamina maxima only.
- `content/champions/body_type_profiles_v1.json`: resource bounds only.
- `tests/unit/test_body_type_profile_catalog.gd`: updated examples and every
  body/stat envelope checked against global safety bounds.
- `tests/unit/test_champion_catalog.gd`: new all-five reserve, unchanged Health/
  regen/movement and cap checks; existing authoritative examples updated.
- `tests/unit/test_elemental_bursts.gd`: shared tuning assertions and measured
  old/new projectile flights across every moving identity.
- `tests/unit/test_combat.gd`: all-five resource exhaustion/recovery coverage and
  cost/cadence-derived deadline.
- This candidate report.

Longer flight lifetimes can leave approximately 25% more projectiles alive under
unchanged sustained casting cadence. This is a capacity implication, not a
measured performance result. The runtime workstream must include the new tuning
in its density/overflow scenario. Next: integrated Full and 120 Hz boot, actual
Farflow with the new content hashes, then visual/interactive review of lane
clarity and escape opportunities at the existing zoom/effect settings. No human
feel approval, rendering-performance claim or increased supported player count
is implied by these headless tests.

## Follow-on: whole-cast capacity admission

The integration lead requested a bounded correctness follow-on so longer-lived
projectiles cannot create dangerous state that the network omits. Implemented in
`src/sim/combat/combat_system.gd` and `src/sim/core/sim_world.gd`, with additional
production-path fixtures in `tests/unit/test_combat.gd`:

- Authority uses the shared `SimConfig` limits supplied by the integration lead:
  128 live/reserved projectiles globally and 16 per owner; 32 live/reserved
  Fields globally and 4 per owner.
- A new startup counts existing live objects plus every living actor's pending
  cast. A Burst reserves all five lanes before any Flux is spent. Fields reserve
  one slot; Beam/Spray need no persistent-object reservation.
- Insufficient space emits `cast_refused` with reason `capacity`, spends no Flux,
  starts no spell cooldown and allocates no object ID. It never truncates a fan
  or removes existing dangerous state to make room.
- An already-paid startup keeps its reserved release. Clearing pending state and
  storing the released object happen in one actor's sequential simulation turn,
  so later actors see live state instead of a double-counted reservation.
- Command validation precedes actor updates. All commanded and idle actors step
  in the same entity-ID order; explicit neutral commands, omitted idle commands
  and reversed incoming order yield the same release IDs and world hashes.
- Expiry frees live capacity through the existing lifecycle. Defeat clears a
  pending cast and releases its reservation without emitting orphan projectiles.
- Direct low-level `step_player` callers retain optional unlimited budget defaults
  for existing isolated fixtures. All `SimWorld.step` paths pass actual authority
  budgets. This does not create a new supported lobby size or modify transport.

Executed follow-on command: the same isolated Godot runner above with selector
`combat,elemental-bursts,core,client-prediction,replay,authoritative-session,action-transition-policy`
and log `.godot/diagnostics/gameplay-admission-20260906-r2.log`. Result:
7 selected suites, 6,808 assertions, zero failures; stderr is empty and warnings
were rejected. Combat contributes 5,996 assertions, elemental-bursts 487,
authoritative-session 111, action-transition-policy 26, core 20,
client-prediction 154 and replay 14. The changed-file whitespace check also passes.

Specific admission evidence covers eight simultaneous complete fans reaching
exactly 128 live projectiles, eight subsequent Fields reaching exactly 32,
reversed actor/command order and omitted-idle hash agreement, repeated distinct
Bursts reaching 15 per-owner projectiles followed by a Bolt reaching 16, whole
fan refusal with fewer than five slots, Field refusal at four per owner, expiry
and death cleanup/reuse, unchanged Flux/cooldown/IDs on refusal, and an instant
Beam admitted while persistent capacity is full. A ninth actor is used solely as
an offline overflow fixture to separate global from per-owner limits; it is not
a nine-player network support claim.

Integration still owns the complete snapshot capacity/hostile-input checks,
player-facing `capacity` explanation, runtime stress trace, Full gate and real
Farflow journey. These headless admission tests do not replace those checks.
