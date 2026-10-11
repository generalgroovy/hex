# Shared heads, body-led sizes — September 27 follow-up

Follow-up: the user subsequently requested in-game implementation. The separate
[runtime candidate handoff](IN-GAME-INTEGRATION.md) supersedes the staging-only
delivery status below; this document preserves the original source-art evidence.

User steering: heads approximately equal across all sizes; body volume and limbs
carry more of the Small / Middle / Large difference. Continue the remaining cast.

## Current construction

| Measure | Small | Middle | Large |
|---|---:|---:|---:|
| Anatomical skull target | 18 px | 18 px | 18 px |
| Allowed reviewed identity variation | 16–20 px | 16–20 px | 16–20 px |
| Neutral full anatomical height | 58 px | 63 px | 68 px |
| Below-skull body budget | 40 px | 45 px | 50 px |

The skull measurement excludes hair, horns, crown, ears, beard, hood and wings.
Its aspect ratio stays intact. Source measurements remain estimates, especially
for hidden/nonhuman anatomy. Never advertise exact uniform visible silhouettes:
large ears, snouts or elaborate hair legitimately alter the outer head shape.

## Applied work

- `head_calibration.json`: source-hash-locked cranial estimates for all 30 IDs.
- `head_contract.py`: size-independent scale, identity tolerance and body budget.
- `shared_heads.py`: complete-jaw repartition, one fixed head/body calibration
  per identity and shared nearest-pixel registration to avoid separate-cut seams.
- `output/motion-common-heads-v3/`: rebuilt layered candidates for all 30 / 240
  views. Padded artwork canvas preserves ornament extents instead of shrinking
  the character. No gameplay values or existing original sheets were rewritten.
- `action_keys.py`: now accepts every current character ID with explicit cranial
  measurement; no head scale inferred from the pose bounding box.
- `output/authored-keys-v2/`: Wa Bidi, Jan Wicked and Fluup each have 64 new
  full-body action keys, all using an estimated 18 px skull target.

New rows: slide entry/hold, roll anticipation/tuck, jumpsquat, jump rise, fall,
landing. This adds 192 keyposes; it does not add 192 completed animation cycles.
The historical S. Wayne / Oh Tipi / Red Baron pack is preserved but is not silently
declared compliant with the new rule. Its source poses need the same correction
before joining a unified accepted animation catalog.

## Safety and review

Common-head v1 stopped on padding/clipping checks. V2 passed technical validation
but the visual roster exposed cut-resampling seams. V3 replaces independent cut
sampling with a connected source-pixel map. Keep these statuses distinct.

The workbench is not a production actor renderer. Generic extreme-pose skinning,
exact 45-degree yaw, low/air moving-cast projections, hidden clothing, wing/cape
occlusion and complete timing/transition cycles remain acceptance work. At-rest
registration does not prove motion quality. No game export or promotion.

## Next bounded work

1. Review the shared-head roster and the three new action sheets at game scale.
2. Correct ambiguous frontal/rear-quarter headings and jumpsquat silhouettes.
3. Recalibrate the three historical pilots and finish real gait/roll/slide cycles.
4. Expand by costume family: goblin/gnome, humanoid coats, plant bodies, heavy
   armor, then tails/wings/spider appendages; keep explicit per-character gaps.
5. Integrate accepted actor, portrait, selection and afterimage consumers only
   after all relevant motion and performance checks pass.

Generated new source PNGs and exact prompts are in `art_batches/character_motion_v1/`
under `reference/*-shared-head-actions-v1.png` and `prompts/*-shared-head-actions.txt`.
Built-in image generation was used; originals were retained.

## Final verification

| Check | Fresh result |
|---|---|
| Combined art suite | 96 tests passed in244.264s |
| All-cast build | 30 identities /240 source views /24 candidate actions /8,640 shared pose samples |
| Native validation | 30 loads /28,800 finite transform samples; empty stderr |
| Native captures | 42 boards, six representatives x seven actions; empty stderr |
| New authored-key registration | 192 cells reassembled byte-identically; source/recipe/atlas hashes verified |
| Production identity | p56-5dc9b5f3bdc0 /2,800 canonical records unchanged |

Native validation logs: `.godot/character-motion/20260927-134554-82a24e35`.
Capture logs: `.godot/character-motion/20260927-134656-35f06e58`.
Images: `output/motion-common-heads-v3/native-review/` beneath this art batch.

Lead inspected all30 frontal roster, six-character size comparison, new front
action board, native Jan Wicked slide, Fluup jump and S. Wayne idle. Corrected
registration removes the conspicuous static cut seams seen in v2. Exact yaw,
animation-cycle quality and all-direction mask quality are not yet accepted.
Three new sheets were generated with the built-in tool, then assembled through
the explicitly authorized deterministic source-pixel workflow. No live-game
replacement, gameplay change, export, commit or push. Owned engine runs closed.
