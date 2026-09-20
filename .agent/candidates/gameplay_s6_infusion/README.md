# S6 paid melee infusion candidate

Status: **isolated source candidate; NOT RUN; not integrated; no visual, feel,
snapshot, replay, network or human acceptance**.

This candidate adds only the Water/Fire material payload state machine and its
validated trial data. It relies on the separate
`.agent/candidates/gameplay_s6_hex` reserve/commit/release/cancel API. It does
not edit live source, shared `PlayerState`, `SimCommand`, `SimWorld`, physical
contact resolution, snapshots, input, presentation or test registration.

## Fixed contract

The data authority is exactly Water then Fire, strength 3, matter budget 180,
Flux cost 4,000 and independent readiness 36 ticks. A selected Bolt, Heavy,
Rapid or Spray contributes only its canonical Water/Fire identity. Infusion
does not call the ranged cast profile, copy ranged damage/strength/quantity, or
read/write the selected spell's cooldown. The 36-tick readiness is its complete
cooldown authority.

`MeleeInfusionSystem.begin_tick(world, state, original_command)` runs after the
physical state machine and before ranged combat. Same-tick melee start plus
spell therefore enters Startup and is eligible. New selection is open during
Startup and only the first Active tick (`remaining == total`), provided the
physical sequence has no prior confirmed hit. It scans positions 1 through 12,
skips unsupported elements, and accepts the first valid Water/Fire position.
All simultaneous spell-position edges are returned in
`consumed_pressed_actions`, including explicit refusal, so the root command
copy can prevent a ranged leak.

Admission checks readiness, Flux and one live solo hex court before mutation.
It reserves strength 3 / quantity 180 against the current
`world.next_projectile_id`, then spends Flux, then commits the ledger. The ID
increments only after all three succeed. Commit failure cancels the reservation
and restores Flux plus every recovery-clock side effect exactly. Accepted
payment is never refunded.

Once accepted, the paid hold has a separate lifetime from the selection cutoff:
it survives every remaining Active frame until the first confirmed enemy hit.
`confirm_first_contact(world, state, pre_knockback_point, first_contact)` runs
after physical damage succeeds and before knockback. It releases once into the
target's canonical occupied hex through `HexCourt.release_infusion`, clears the
held wire/source, and keeps `infusion_used == 1` until the next physical
sequence. Friendly, protected, intangible or otherwise rejected contacts never
call this hook. Entering Recovery without a hit, physical interruption, death,
modal, character change or world reset calls `cancel`, which expires paid
matter once and creates no delayed terrain.

## Root-owned integration

Promote these files and change both candidate preload/default paths to live:

| Candidate | Live destination |
| --- | --- |
| `content/combat/melee_infusions_v1.json` | `content/combat/melee_infusions_v1.json` |
| `src/sim/combat/melee_infusion_tuning.gd` | `src/sim/combat/melee_infusion_tuning.gd` |
| `src/sim/combat/melee_infusion_system.gd` | `src/sim/combat/melee_infusion_system.gd` |
| `tests/unit/test_melee_infusion_system.gd` | `tests/unit/test_melee_infusion_system.gd` |

Add these exact integer fields to `PlayerState`, canonical state, complete
snapshot and client reconciliation, with reset defaults zero:

```gdscript
var infusion_wire_id: int = 0
var infusion_source_id: int = 0
var infusion_sequence_id: int = 0
var infusion_ready_ticks: int = 0
var infusion_used: int = 0
```

Validate wire `0..65535`, source/sequence `0..0x7fffffff`, readiness `0..36`,
and used `0|1`. A live held wire/source must be paired, paid in
`hex_court.held_infusions`, match the actor and current physical sequence, and
have `used == 1`. A released/cancelled sequence retains exactly `wire=0`,
`source=0`, `sequence=current physical sequence`, `used=1` until a different
physical sequence begins. `PhysicalStateCodec` and snapshot validators must
admit this stable state; the physical start path must not reset it because this
system detects the sequence change and rearms usage itself.

Root call order per living actor is Movement, Physical begin, Infusion begin,
then Combat with `consumed_pressed_actions` cleared. Root must also quarantine
all ordinary cast aliases/held spell input while physical state owns input; this
system only returns the twelve position edges it inspects. Insert
`confirm_first_contact` at the marked S5 hook after successful enemy damage and
before `_apply_knockback`, using `target_position_before_knockback`. Call
`cancel` before physical movement interruption cleanup, modal opening, death,
champion replacement and world replacement. Reset both systems on spawn.

Add the accepted/refused/released/cancelled events to bounded codecs only if
presentation consumes them. Add the tuning content hash to compatibility/runtime
identity and bump shared snapshot/protocol revisions with the S5 fields. Keep
the solo hex snapshot refusal; this candidate does not make the court network
ready.

## Static evidence and gates

The focused candidate test covers exact/atomic tuning, ascending valid
selection, Heavy identity without Heavy payload, ranged-cooldown independence,
one Flux payment/source allocation, ordinary-world/unsupported/Flux/readiness/
capacity refusal, commit rollback, one pre-push hex release, a target entering
on the final Active tick, late new-selection refusal without premature expiry,
duplicate contact, paid whiff, rejected contact, death and sequence cleanup. It
assumes root first
adds the five shared fields and promotes the S6 hex fork. **No Godot command,
import, test, capture, profiling or visual review was run.**

Rollback before promotion is deletion of this candidate directory. Integrated
rollback must remove these four mapped files and reverse the shared fields,
call sites, event codecs, identity hashes and revision bumps as one change.
