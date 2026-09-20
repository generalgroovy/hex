# Neutral body templates - paused draft

Status: **not a completed runtime sprite pack**. Work paused on 2026-09-07 when the user switched the immediate task to element and chemistry animations. No live game characters were replaced.

## Ready infrastructure

| Component | Status |
|---|---|
| Isolated six-page Godot importer | 317 synthetic assertions passed; rejects fake checkerboard transparency and clipped cells |
| Reusable race-/element-neutral Sprite2D | 1,839 contract assertions passed; actual PNG checks still pending |
| Standalone comparison/animation viewer | 254 assertions passed; missing PNGs explicitly reported |
| Runtime atlases Small/Middle/Large | **Not built**; artwork incomplete |
| Source art | Cardinal core has actual alpha; cardinal motion and diagonal core have opaque checkerboards and are not importable |

## Exact intended output

Three 768x960 RGBA pages, each ten rows by eight columns of 96x96 cells. Shared foot pivot (48,84), standing heights Small58/Middle68/Large76. One size scale for an entire body; never resize individual actions. Body and plain clothing only; race anatomy, equipment, shadows and all magic remain separate.

Direction columns: south, southeast, east, northeast, north, northwest, west, southwest. Rows: grounded, jump, cast, hit, walk, sprint, slide, roll, walk_b, sprint_b.

Walk and sprint have two opposite-contact poses. Other current actions share held poses: Float/jump/air dodge/wall jump use jump; wallrun/wavedash use slide; defeated uses hit. These are current compatibility references, not independent full animation cycles. Vault/superglide remain inactive.

## Resume safely

1. Finish six source pages using small grids: cardinal/diagonal core (4x4), motion (4x4), phase B (4x2).
2. Correct opaque checkerboard sources with image generation; retain the rejected originals and never loosen the import gate to accept them.
3. Verify source row counts, facing, opposite feet, body/head proportions and clean alpha.
4. Run build_pack.gd from the main project; outputs remain inside this ignored reference directory.
5. Run runtime/test_neutral_body.gd with --require-png and preview/test_viewer.gd with --require-sheets.
6. Review the animated viewer at native size and all eight directions before any live integration.

The generated cardinal core still needs final anatomical review. Numeric packing checks do not certify art quality. Full prompts and rejected dense-grid trials are retained alongside source files.
