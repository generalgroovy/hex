# Gameplay melee native capture candidate

Candidate status: **PREPARED / NOT RUN**. This ignored directory contains no baked art and changes no live source. Root owns promotion, serialized Godot execution, image review, and evidence archival.

## What the capture proves when it passes

`capture_gameplay_melee.gd` uses the production Bootstrap draw path through a side-effect-free `ChemistryCoachHarness` derivative. Every attack starts with a real `SimWorld.step()` command using `SimCommand.PRESSED_PUNCH` or `SimCommand.PRESSED_KICK`; the harness never assigns any `physical_*` or `infusion_*` field and never fabricates an event, cast, source, or ledger.

The main matrix captures exactly 48 paid first-Active states:

- three canonical size templates: `s_wayne` / Small / 58 px, `oh_tipi` / Middle / 63 px, and `red_baron` / Large / 68 px;
- eight latched aim directions in the shared direction order;
- Punch and Kick;
- exact profile validation for Punch `6/4/16` and Kick `12/6/28` Startup/Active/Recovery, plus their current stamina costs and damage;
- one stamina payment at admission, one actual start event, canonical phase/sequence/latched aim, one first contact, expected damage, and no later stamina drain;
- the actual `CartoonChampionPresenter.movement_frame()` selecting a melee atlas region at fixed 96 px cell geometry and the exact compact-rig `hand_r` or `toe_r` attachment.

Twelve additional native 1280x720 images form normal/reduced pairs for an unpaid Before reference and paid Startup, Active, Recovery, out-of-range whiff, and airborne Punch states. They remain separate full gameplay frames because a downscaled contact sheet would weaken review of the already compact 58/63/68 px bodies.

If the integrated S6 resource and Hex Court hold/release methods exist, the capture also issues one same-tick `PRESSED_KICK | SPELL_PRESSED_BITS[slot]` command. It requires the real accepted/released events, 4 fixed Flux, 180 finite matter, and a target placement whose 30 px Kick push crosses a hex boundary. The deposited cell must equal the captured pre-push cell and exclude the post-push cell. If S6 is absent, the receipt records `not_available`; it never emulates the feature.

Drawing is checked against `world.state_hash()` before and after every image. A pass is native rendering plus the listed authority assertions. It is not human visual acceptance, rendered performance, networking, release, or proof on another machine.

## Root promotion and serialized run

After the final S5/S6 production files and generated melee atlas/manifest/attachments are present, root should copy only:

```text
.agent/candidates/gameplay_melee_capture/melee_capture_harness.gd
  -> tests/support/melee_capture_harness.gd
.agent/candidates/gameplay_melee_capture/capture_gameplay_melee.gd
  -> tests/visual/capture_gameplay_melee.gd
```

Then register or invoke the visual capture through the repository's serialized Godot wrapper with one fresh contained argument such as:

```text
--output=res://.godot/gameplay-melee-s5-s6-v1
```

Archive the wrapper log, `capture-receipt.json`, all PNGs, and the exact source/asset hashes before review. Review all 48 Active matrix frames at native size, both modes for the six representative pairs, and the optional infused Kick pair if produced. The candidate does not prescribe a raw Godot command because root owns the active import/capture lane.

## Expected production dependencies

- S5 live `PhysicalAttackSystem`, `PhysicalAttackTuning`, PlayerState schema, command bits, snapshot-safe world integration, and Cartoon/Melee body presenter.
- Generated live `assets/sprites/wireframe_melee_v1/` manifest, three pages, and verified compact attachment table.
- Existing Hex Court and visual-language Bootstrap configuration.
- Optional S6 live same-tick infusion integration and finite Hex Court hold/release API.

The only fixture-owned changes are champion selection, team, spawn position, aim/facing, and disabled resource recovery. Spawn reset clears physical and infusion state before the paid command. All targets are real champion `PlayerState` records and all contact outcomes come from `PhysicalAttackSystem.resolve_all()`.
