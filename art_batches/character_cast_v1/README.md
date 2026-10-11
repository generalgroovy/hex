# Named-character sprite candidates

## Active lane: genuine full-body artwork

The latest request supersedes the head-on-shared-body bake. Use `fullbody.py`
for authored whole-character sprites in all eight directions. The first deliverable
is deliberately **eight static idle views**, not fabricated walking animations.

```powershell
python art_batches/character_cast_v1/fullbody.py preflight
python art_batches/character_cast_v1/fullbody.py build --out art_batches/character_cast_v1/output/fullbody-v1
python art_batches/character_cast_v1/fullbody.py check --out art_batches/character_cast_v1/output/fullbody-v1
```

Each catalog item points to `fullbody_recipe`. Recipe schema 1 contains matching
`character_id`, `directions`, hash-locked `source_png`, `source_sha256`, measured
front `reference_body_height`, and eight `body_parts` entries. Each entry has a
nonoverlapping transparent-border crop and local `ground_anchor`. Target front
heights are 58 / 63 / 68 pixels; one uniform scale applies to all eight views of
that character, preserving authored volume instead of stretching height. The
ground registration is 48,84 inside a 96×96 cell.

Output is a 768×96 RGBA strip per character, `fullbody-roster.png`, a complete
direction review board and a hash-checked manifest. `animation_status` remains
`idle_only`; movement integration requires separately authored/baked animation
and visual acceptance. No runtime replacement occurs here.

## Preserved experimental lane: component rigging

This is a staged, offline assembly lane, not a replacement for the playable
checkpoint. Authored directional head artwork is required for every named
character. The source image, measured crops and anchors are hash-locked; there
is no front-view rotation, automatic gender inference, or palette-only identity
substitution. Shared limbs remain explicitly **partial anatomy**.

## Inputs and boundaries

| Input | Contract |
|---|---|
| `catalog.json` | Current named IDs, race, small/middle/large size, presentation metadata, relative component recipe |
| Component recipe | Schema 1; matching `character_id`; `source_png` and required `source_sha256`; `directions` S, SE, E, NE, N, NW, W, SW |
| `heads` | Eight direction keys; each has integer `[x,y,width,height]` crop and measured local `chin_anchor` |
| Scale | Positive measured `reference_head_height`; one fixed head scale per named size across every action |
| Optional `torso` | Independent hash-locked source with eight `parts`, each containing crop, `neck_anchor` and `pelvis_anchor` |
| `palette` | Optional editable shared-limb materials; never counted as unique identity art |
| Volume | Reuses `character_volume_v1/volume.py`; anatomical width, depth and girth, not stretching a finished image |

All crop edges must be transparent. Explicit alpha thresholding is recorded;
background color removal is not guessed. A missing source blocks the selected
build before writing output. Two named characters cannot silently share the
same complete head component fingerprint.

## Commands (repository root)

```powershell
python art_batches/character_cast_v1/build.py preflight
python art_batches/character_cast_v1/build.py sample --out art_batches/character_cast_v1/output/review-v1
python art_batches/character_cast_v1/build.py build --out art_batches/character_cast_v1/output/cast-v1
python art_batches/character_cast_v1/build.py check --out art_batches/character_cast_v1/output/cast-v1
python -m unittest discover -s tests/art -p test_character_cast.py -v
```

Use `--characters actual_id another_id` for a bounded subset. Fresh output paths
are mandatory. Samples cover grounded, slide and roll in all eight directions;
full builds cover 80 base poses, 512 walk and 512 sprint frames per character.

The builder assembles and validates one character atlas at a time. Frame cells
are 96×96 with a fixed 48,84 pivot. Atlas records include decoded frame hashes,
alpha bounds, action, aim, travel and gait phase. A contact board is provided for
visual review. `.gdignore` prevents accidental source-art imports.

## Acceptance

Technical receipts prove coverage, transparency, bounds and provenance only.
They do not prove natural motion, exact facing readability, racial appendages,
named-costume completeness, gameplay performance, or human approval. Candidate
manifests retain `production_ready`, `runtime_verified` and `human_approved` as
false. Production presenters, portraits, afterimages, gameplay balance and the
working checkpoint are outside this builder's authority.
