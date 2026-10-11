# Fixed-pixel body pilot

Newly generated pixel-style S. Wayne / Oh Tipi / Red Baron banks. This is a
three-size **ground/cast candidate**, not all-character/all-action completion.
Sources are immutable copies of the image tool outputs; generated originals
remain outside the repo. The rejected full-sheet Oh Tipi rear-facing edit remains
in the generation history; only the separate corrective rear sheet is assembled.

| Contract | Value |
|---|---|
| Runtime | `assets/sprites/pixel_body_pilot_v1/`, three1024x768 RGBA pages |
| Grid / feet |128px cell, fixed(64,104) pivot, nearest sampling |
| Sizes |58/63/68px neutral height; volume-first, no stat/hurtbox changes |
| Rows |Idle, contactA, neutral passA, contactB, neutral passB, cast |
| Facing |S,SE,E,NE,N,NW,W,SW; separate corrected Oh Tipi rear diagonals |
| Motion |Both layers face aim; travel owns gait/reverse playback; same-heading cast overlay; two unscaled blits |
| Explicit reuse |Both passing beats reuse neutral art; no fabricated tween frames |
| Not complete |Dedicated sidestep art, authored low/air/control actions, smooth passing poses, remaining27 identities |

`python art_batches/pixel_body_pilot_v1/build.py` reconstructs the banks and
review board. This is deterministic assembly authorized by the user: binary
alpha cleanup, neighbour-fragment rejection, uniform per-sheet nearest scaling,
registration and packing. It never edits source artwork, invents body pixels or
exports the old deforming rig. `review/assembly.json` records source hashes and
mapping. `.gdignore` keeps production sources/reviews out of runtime imports.

Visual direction alone is not acceptance. Review native8x8 composites, foot
contacts, belt seams, casting, portraits and transitions to fallback in actual
Wellspring. Do not promote if split-body joins twist or disconnect visibly.

Rejected v2: independently facing upper and lower halves cut tails/capes and
produced disconnected costume fragments. Keep one body heading; no claim that
ordinary walking frames are newly authored lateral footwork. The v2 cast capture
also sampled wire1's zero-weight first startup tick, so its cast label was not
cast-pose evidence. Corrected native review samples the reached cast pose.
