# Respawning practice targets

Status: helper implemented and directly tested (1,119 assertions, zero failures
or warnings, Godot 4.7.1 / 120 Hz). The isolated run is recorded in
`.godot/diagnostics/training-target-20260906.log`. Integration and network/visual
verification are recorded by the coordinating lead; those are not implied by
the helper test. This is not a larger-map completion claim.

## Player contract

- Defeated practice effigies return automatically after **3 seconds**.
- Each effigy returns to its authored stand with full Health and **250 ms of
  spawn protection**. Existing Health, Flux and Stamina profiles are preserved.
- Targets retain their stable identity and do not award champion defeat credit.
- Old knockback, slows, pending casts and movement commitments are cleared.
- The Practice Bell still resets the shared practice seed immediately; it also
  cancels any pending target countdown through normal spawn initialization.
- Countdown and protection need an in-world read, and a guest must see the same
  target health/countdown as the host. No white body surround is introduced.

## Authority and integration

`TrainingTargetSystem.step_target` is called once per target after all combat
resolution, in stable entity order. The first defeated observation arms 360
ticks at the canonical 120 Hz. The next 360 calls consume those ticks; the same
actor instance resets at zero. No per-target queue, timer node, random state or
new actor allocation is involved.

PlayerState owns `training_respawn_ticks`, `training_spawn_x` and
`training_spawn_y`. Its spawn reset must clear the countdown while preserving
the authored anchor; canonical values must include all three. Compact target
snapshots must carry countdown, anchor and `spawn_protection_ticks`, with bounds
validation, to support late join and countdown agreement. Snapshot/schema and
protocol integration belongs to the lead. Lifecycle strings are local cues;
replicated target health/timers, not unreliable events, own visible state.

## Acceptance checks

- Focused helper tests: exact delay/protection, no early or duplicate respawn,
  anchor restoration, stable identity/object, independent targets, repeated
  defeat, manual-reset cancellation and champion exclusion.
- Ordinary `SimWorld.step`: a real cast defeats an effigy, no defeated-actor
  natural regeneration runs, then it returns once after the complete interval.
- Hash/replay: changing only countdown/anchor changes canonical state; replaying
  the same lethal command and subsequent empty commands reproduces the cycle.
- Snapshot: down, waiting and protected-return samples round-trip; invalid
  countdowns/anchors/protection fail closed; late join shows the current phase.
- Source boot and real host/guest smoke stay warning-clean; Full gate passes.
- Live review: readable countdown, quiet reform cue, correct stand/Health and
  no lingering control or invisible early collision under normal/reduced effects.

## Next map expansion seam — not implemented here

The current campus is already **3072 × 1728**; its short advanced garden
centerline is approximately 816 world units. A longer course should be a
connected chain of extended wall contact, reversal, slide-jump and landing
sections, each with a wide ordinary bypass and an immediate recovery/reset.
Safe circulation between the Loom, range, source court and Crucible must remain.

Increasing world size is an atomic content/presentation/collision change:
`SanctumCampusLayout.REQUIRED_CANVAS` and schema, authored districts/routes and
building worldbone, illustrated floor texture dimensions, camera bounds,
station/spawn safety and route-reachability tests all move together. Network
coordinate validation and real rendered frame cost must be checked at the new
extent. Enlarging only a background does not create a longer playable course.
