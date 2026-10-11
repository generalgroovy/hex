# Full-body motion workbench

This is an **art candidate**, not the game launcher or a production-ready pack.
All 30 identities have source-preserving layers and anatomical calibration.
The shared rig samples 24 active actions across three sizes; this does not mean
all characters have finished, accepted animation.

## Review

Double-click `preview.cmd` in this folder. Left/Right changes character,
Up/Down changes action, 1-8 selects aim, T changes travel, C previews casting,
M compares mesh and layers, K toggles authored action keys, Space pauses,
B changes background, Esc closes.
Generated full-body action keys for three size representatives are separate
from the original eight standing views and from complete multi-frame cycles.

The historical pilot contains 192 authored keyposes: S. Wayne (Small), Oh Tipi
(Middle), The Red Baron (Large). Eight rows cover slide entry/hold, roll
anticipation/tuck, jumpsquat, rise, fall and landing. They use one fixed scale
per character, without stretching crouched poses back to standing height.
See `output/authored-keys-v1/all-three-action-keys.png`. Diagonal-heading
corrections, full transition cycles and moving-cast anatomy remain pending.

The latest preview uses `output/motion-common-heads-v3/`: all30 layered
candidates share an approximately18px anatomical skull target; the body carries
the size difference. `output/authored-keys-v2/` adds192 action keyposes for
Wa Bidi, Jan Wicked and Fluup. It is the current optional key bank. Old pilot
poses are preserved separately because their prior head calibration is obsolete.
Details: `docs/art/character-motion-20260927/SHARED-HEAD-UPDATE.md`.

## What the visual review caught

Rigid automatic partitions open joints and separate costume fragments in large
poses. The connected textured cage preserves continuity but stretches appendages
and cannot solve limb occlusion. Both are **held from production**. Corrective
artwork is required; do not hide these defects with procedural substitute limbs
or a static standing sprite marked as a completed action.

## Reproduce

```powershell
python -m unittest discover -s tests/art -p 'test_character*.py' -v
python art_batches/character_motion_v1/build.py --out art_batches/character_motion_v1/output/fresh-candidate
./art_batches/character_motion_v1/preview.ps1 -Validate
```

Use a fresh contained output directory. Original art, prior builds and failed
review evidence are preserved. No gameplay balance, physics, selected checkpoint,
installer or network protocol changes belong to this artwork workbench.

Authoritative scope, evidence and next acceptance steps:
`docs/art/character-motion-20260927/HANDOFF.md`.
