# Moving-cast feasibility — candidate only

This is one Large **walking** page, not a production migration. It tests 64 travel/aim pairs × eight existing leg phases × three upper-body states: neutral counter-swing, accepted-startup preparation, and recovery/release. Sprint, other sizes, gameplay state routing, live viewport drawing, and packaged-build performance are outside this slice.

`export_candidate.gd` reads the current W2 rig and reuses the existing fixed-bone guide's two-bone IK. Only elbow/hand landmarks, their projected positions, and arm depth ordering change. Every leg, pelvis, shoulder, neck, and head landmark remains exact. No runtime page, runtime manifest, bootstrap, or production presenter is written.

`build_candidate.py` renders complete native cells with the current W2 pixel rasterizer. It verifies all 512 neutral frames against the current live Large walk page byte-for-byte; checks fixed bones and unchanged non-arm anchors; and requires all three upper states to have distinct pixels for every direction/phase key. It then deduplicates equal cropped tiles and packs them into one fixed **1536×3072** candidate page, using deterministic best-fit shelves, no rotation, and one-pixel transparent gutters. Failure to fit aborts instead of growing the page.

`candidate-manifest.json` maps every logical 96×96 frame to a packed rectangle, original crop offset, margin, and full reconstructed RGBA digest. The offline builder reconstructs every frame and checks exact pixels. `check_atlas_roundtrip.gd` independently creates real Godot `AtlasTexture` views and checks their logical dimensions and `get_image()` RGBA digest. That check deliberately tests the margin behavior rather than assuming it works.

When an engine lease is granted, the bounded sequence is:

```powershell
# Run both Godot invocations through the project's hidden checked wrapper.
Godot --headless --path . --script res://art_batches/character_style_v1/wireframe_motion_v2/moving_cast_feasibility/export_candidate.gd
python art_batches/character_style_v1/wireframe_motion_v2/moving_cast_feasibility/build_candidate.py
Godot --headless --path . --script res://art_batches/character_style_v1/wireframe_motion_v2/moving_cast_feasibility/check_atlas_roundtrip.gd
```

## Result: art packing passes; drop-in image readback fails

The candidate contains all **1,536 Large walking frames**: all 64 travel/aim pairs, eight leg phases, and three distinct upper poses. All 512 neutral frames are byte-identical to the working W2 Large walk page. The builder passed 21,504 exact non-arm landmark/projected-anchor checks, 15,360 fixed-bone checks, and all 1,536 reconstructed 96×96 pixel comparisons. The exported packets contain only arm deltas; original W2 non-arm values are retained directly rather than round-tripped through another JSON number formatter. Identical leg geometry does not imply identical visible leg pixels where changed arms occlude them.

All 1,536 crops are unique and fit one **1536×3072 / 18 MiB decoded** page, with transparent gutters and no rotation. Occupied shelf height is **2,454 of 3,072 rows** (618 spare rows); crop rectangles occupy 72.44% of the page. This proves this particular Large walk candidate fits its existing page allocation, not that all sizes and sprint are already packed. The candidate is not loaded by production, whose nine textures remain **116.4375 MiB decoded**.

The real Godot 4.7.1 `AtlasTexture` check **failed all 1,536 logical image roundtrips**. The first view reports a logical size of 96×96, but `get_image()` returns its cropped **40×71** image rather than a padded 96×96 image. Its intended full-cell digest cannot match. This is a measured API-contract limitation, not a rig or packing failure. The raw failing test and nonzero exit are preserved in `moving-cast-atlas-roundtrip-v1.log` and `atlas-roundtrip-evidence.json`.

The native light and enlarged dark boards were inspected. Preparation clearly raises both forearms; recovery extends the release-side hand, especially in side/diagonal views. South-facing preparation versus recovery remains a subtler foreshortened change. This is pose-readability evidence, not normal-speed transition or accepted-cast timing acceptance.

**Do not promote this as a drop-in AtlasTexture replacement.** A next reviewed implementation would need an explicit packed-frame rectangle/offset contract and a padded 96×96 CPU reconstruction helper for the existing afterimage/image consumers, plus ordinary-view and POV drawing tests. Reconstruct on bounded cache misses, not every draw; account separately for any CPU/GPU cache growth. State routing must use accepted preparation/recovery while leg phase keeps advancing. None of those production adapters, routing changes, or caches were implemented here.

`packing-evidence.json` records the earlier offline stage; `atlas-roundtrip-evidence.json` records the later independent engine failure; **`feasibility-verdict.json` is the combined final status**. All nine live PNG source hashes still match the unchanged W2 manifest, and the W2 rig remains unchanged. No result in this folder authorizes switching the live presentation. Sprint, smaller bodies, live viewport/POV/afterimage compatibility, gameplay timing, normal-speed gesture feel, and packaged performance remain unverified.
