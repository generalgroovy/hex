# Candidate character sheet review

This diagnostic loads **one read-only PNG**, not the live game or the entire cast. It reuses the neutral-body viewer's source-row/direction grammar and never generates character pixels, changes saves, or connects to a lobby.

From the repository root in PowerShell:

```powershell
# Interactive paging and flipbook viewer.
.\scripts\review-character-sheet.ps1 -Sheet 'C:\path with spaces\candidate.png'

# Headless format/coverage check (not visual acceptance).
.\scripts\review-character-sheet.ps1 -Sheet 'C:\path\candidate.png' -Mode Check

# Actual Godot render: 32 PNG pages and a detailed JSON report in a new directory.
.\scripts\review-character-sheet.ps1 -Sheet 'C:\path\candidate.png' -Mode Export
```

| Review | Behavior |
|---|---|
| Source admission | PNG header is bounded before decode; exact 768x960 RGBA8, binary alpha, 80 nonempty cells, transparent cell borders |
| Rows | grounded, jump, cast, hit, walk, sprint, slide, roll, walk_b, sprint_b |
| Directions | S, SE, E, NE, N, NW, W, SW; original 96px cells and `(48,84)` pivot |
| Contact pages | Every cell exactly once at 1x (2 pages) and 2x (10 pages), on light and dark backgrounds |
| Playback | Walk A/B, sprint A/B, or all ten source rows; pause and single-step; all eight headings visible |
| Duplicate contacts | Identical A/B pixel hashes are warnings, never evidence of alternating legs |
| Export | 24 contact pages plus 8 walk/sprint A/B pages; JSON includes every cell's bounds, occupied pixels, edge pixels and hash |
| Memory | One 2.8125 MiB decoded sheet plus its texture, not an eager 27-character preload |

Keyboard: **Space** pauses, **Left/Right** step, **Page Up/Down** change contact pages, **1/2** select scale, **B** switches background, **Escape** closes. Buttons and the action dropdown provide mouse control.

The preview cadence is **6 source poses/second** with a **120 FPS cap**, not gameplay animation timing or a performance guarantee. Format pass does not approve anatomy, charm, symmetry, heading accuracy, proportions, foot alternation, or movement feel. Single-pose actions are labeled honestly; this viewer adds no synthetic in-between frames or movement offsets.

Outputs are uniquely named under `.godot/character-qa/` and never overwrite a source. The graphics-capable export is hidden and exits after capture. Invalid native alpha or clipped/missing cells fail admission instead of being silently cleaned.

Model and control checks: run the pinned Godot editor with `--headless --path . --script res://tests/visual/test_character_sheet_qa.gd`. The tool is excluded from release through the existing `tests/*` and `scripts/*.ps1` filters.
