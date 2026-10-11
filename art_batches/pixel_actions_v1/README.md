# Four-key action assembly

The builder reads the current 30-character catalog and never changes ground/cast
art or the original action sources. These are four authored whole-body keys in
eight directions, not animation cycles, synthesized poses, independently aiming
cast limbs, or proof of human acceptance.

## Commands

Run from the H.E.X. repository root:

```powershell
python -B -m unittest discover -s art_batches/pixel_actions_v1 -p test_build.py -v
python -B art_batches/pixel_actions_v1/build.py --available
python -B art_batches/pixel_actions_v1/build.py --available --only s_wayne oh_tipi
```

`--available` writes **only** `review/available/`; it never changes the runtime
bank, even when every source is present. Each review bank contains a runtime-
compatible `manifest.json`, raw atlas PNGs, `boards/<id>.png` comparisons (existing
idle plus all four action rows), `roster.png`, and a detailed `assembly.json`.
The overview shows native-sized pixels for the first direction of all five poses
in three columns (no quarter-scale thumbnails); the full-size
individual boards remain the authority for pixel/proportion review. Missing
source/receipt pairs are reported as pending. Invalid completed sources are
reported and cause a nonzero exit code, while valid sources remain reviewable.

After all workers have completed their sources and review is satisfactory, the
lead can publish the complete bank with:

```powershell
python -B art_batches/pixel_actions_v1/build.py
```

Full mode requires every catalog identity and a matching integration-lead
acceptance record for each source, including S. Wayne. It stages both
`assets/sprites/pixel_actions_v1/` and `review/complete/` only after all validation
passes. Missing/invalid sources or missing, stale, HOLD, or malformed lead reviews
leave both old outputs unchanged. Existing
runtime import sidecars and unrelated runtime-directory files are retained.

`--source-root`, `--ground-root`, `--catalog`, `--output`, and `--review-output`
allow isolated staging. The catalog still must contain exactly 30 unique valid
identities. `--only` is restricted to partial review. Output directories must not
overlap source, ground, or catalog inputs, or each other. Do not point a review
destination at a directory containing unrelated work: review destinations are
wholly generated and replaced as a unit.

## Source completion and mapping

Each new identity needs `source/<id>/source.png` and an adjacent nonempty JSON
object `receipt.json`, written after source completion. The builder computes
its own hashes and rechecks source, recipe, receipt, lead review, ground and catalog bytes
before publication. A receipt is an authoring-completion marker, not a human-
acceptance claim. The lead must still wait for the generating worker to finish.

Before full publication, the integration lead must inspect each assembled native-
pixel board and author `source/<id>/lead-review.json` for that exact selected
source PNG. Original provenance receipts remain unchanged. The acceptance
record must contain these fields (additional review metadata is allowed):

```json
{
  "id": "oh_tipi",
  "source_sha256": "<exact SHA256 of source/oh_tipi/source.png>",
  "accepted": true,
  "reviewer": "integration-lead",
  "review_scope": "assembled-native-pixel-board",
  "reason": "<specific review rationale>"
}
```

The identity and source hash must match exactly; `accepted` must be the JSON
boolean `true`, not a string or number; and `reason` must be a nonblank string.
`accepted: false` is a HOLD and cannot publish. Missing, stale or malformed
reviews fail before any output is staged. Their bytes are also rechecked before
commit, and full assembly reports retain `lead_review_sha256` for each source.
This is an integration-lead visual gate, not a human-acceptance claim.

`--available` does not require or validate lead acceptance, so missing reviews
and held sources can still be assembled for inspection. It is always review-
only, even with all 30 sources present; its report marks the lead gate as
`not_required_partial_review`. It cannot publish a runtime bank.

S. Wayne remains locked to `source/s_wayne/proportion-repair-v3.png`, padding 12,
and the original assembly. Both its raw RGBA hash and exact original PNG hash
are enforced. Its lead review must bind to `proportion-repair-v3.png` and does
not override either pixel lock. A different PNG encoder that changes those
bytes fails closed.

An optional `source/<id>/assembly.json` accepts only these fields:

```json
{
  "source_row_count": 4,
  "source_rows": [0, 1, 2, 3],
  "source_columns": [0, 1, 2, 3, 4, 5, 6, 7],
  "columns_by_row": {},
  "column_padding": 32
}
```

`source_rows` selects exactly four distinct source rows in target order:
`jumpsquat`, `rise`, `fall`, `land`. `source_row_count` is an integer 4..16.
Column lists are permutations of 0..7; `columns_by_row` can override them using
target-row keys `"0"`..`"3"`. Target directions are S, SE, E, NE, N, NW, W, SW.
Padding is an integer 0..64. Booleans, fractions, repeated indices, unknown keys,
unsafe indices, per-pose scales, correction files and transformations are rejected.

An opt-in five-row source can add a separate neutral/standing calibration row:

```json
{
  "source_row_count": 5,
  "source_rows": [1, 2, 3, 4],
  "calibration_source_row": 0
}
```

`calibration_source_row` must be an integer within the source row count and must
not occur in the four selected action rows. It is forbidden for locked S. Wayne.
The neutral row uses `source_columns`; action-only `columns_by_row` overrides do
not remap it. Its largest source ink height determines the **one** source-wide
factor, which is reused unchanged across all four actions. No neutral pixels are
published in the action atlas. Omit this key to retain the exact legacy fall-row
fit and output; existing recipes are not silently migrated.

Neutral calibration is an explicit artist/lead review contract: the neutral
anatomy must match the existing idle bank, not merely its bounding height. A new
row does not itself prove correct skull, torso or limb dimensions. The assembly
report stores `sources[].calibration` with source row, per-direction pre-resize
ink bounds/heights, maximum source height and factor. Coordinates are local to
the extracted source cell; runtime action bounds remain in the existing `cells`
field. Review the native-sized comparison before any runtime publication.

Full publication of a neutral-calibrated source additionally requires
`lead-review.json.assembly_sha256` to equal the SHA256 of the exact raw adjacent
`assembly.json` bytes. Missing/stale values fail before output staging; even a
whitespace-only recipe edit needs a refreshed review hash. The source and recipe
hashes are both retained in the assembly report. Legacy fall-fit reviews remain
unchanged. `--available` bypasses this lead gate for review-only candidates.

## Pixel and transaction guarantees

Assembly uses the existing pilot alpha-cleanup and connected-character helpers:
threshold 128, zero hidden RGB, nearest-neighbour scaling, no drawing, mirroring,
rotation or deformation. Every source receives one uniform scale, calibrated
against the longest selected falling pose, or its explicitly opted-in separate
neutral row, to 58/63/68 px by catalog body type.
The original grid center and one baseline per action row register to pivot 64,104
in 128 px cells. Output is always 1024x512 RGBA. Blank cells, source/cell clipping,
duplicate same-facing action poses, and out-of-budget inputs are rejected.

All output bytes are staged first. Publishing uses same-volume directory
renames, rolling both destinations back on an IO error; a failed rollback keeps
the old directory under `.NAME-stage-*/previous/` for recovery. Windows cannot
atomically exchange two populated directories: readers may briefly observe a
missing directory during the rename pair, but never a partially written new
bank. **Stop live Godot imports before final publication.** Sudden process/power
loss during a rename pair can also leave the recoverable staging directory;
this is not a cross-directory crash-atomic transaction.
