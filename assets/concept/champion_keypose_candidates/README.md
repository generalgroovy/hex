# Champion key-pose candidates

This directory is quarantined from Godot import. Its images are visual-design
proposals only; they are not sprite atlases, animation frames, collision data,
or evidence that a champion is complete.

Promotion requires an original approved visual, deterministic cell extraction,
transparent-background cleanup, the full manifest's frames in all eight
directions, stable dimensions and pivots, nearest-neighbor import, gameplay-zoom
and accessibility review, 60/120 Hz semantic playback, and regression evidence.

The supplied FLUX Champions board is the minimum quality reference. It is not a
sprite sheet and its pixels must not be copied into runtime assets.

`VisualCandidateManifest` validates every checked-in provenance file during
`scripts/test.sh`, including quarantine status, authority, license state, PNG
dimensions/hash, grid claims, exact pose order, source references and blockers.
