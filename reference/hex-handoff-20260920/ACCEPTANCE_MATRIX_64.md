# 64 movement/aim acceptance cells

**All cells are NOT_RUN. Codes are expected gaits, not pass results.**

Review convention: 0° N, clockwise in 45° steps. Rows = movement; columns = aim. 
`relative = (movement_index - aim_index) mod 8`.

| Move \ Aim | N 0° | NE 45° | E 90° | SE 135° | S 180° | SW 225° | W 270° | NW 315° |
|---|---|---|---|---|---|---|---|---|
| N 0° | F | FL | L | BL | B | BR | R | FR |
| NE 45° | FR | F | FL | L | BL | B | BR | R |
| E 90° | R | FR | F | FL | L | BL | B | BR |
| SE 135° | BR | R | FR | F | FL | L | BL | B |
| S 180° | B | BR | R | FR | F | FL | L | BL |
| SW 225° | BL | B | BR | R | FR | F | FL | L |
| W 270° | L | BL | B | BR | R | FR | F | FL |
| NW 315° | FL | L | BL | B | BR | R | FR | F |

**Forward family:** F, FR, FL (24 cells). **Lateral:** R, L (16). **Reverse:** BR, B, BL (24).

Every cell covers S/M/L × walk/run = 6 steady-state variants (384 across the matrix), each for at least two cycles. Retarget entry on both L and R support is additional coverage, not included in the 384 count.

F forward; FR forward-right; R right strafe; BR backward-right; B backward; BL backward-left; L left strafe; FL forward-left. Relative directions are anatomical/body-relative, not screen-relative.

Eight common gates:

| Gate | Acceptance |
|---|---|
| G1 | Visual output never changes world movement, continuous aim, hurtboxes, clearance, collisions or action timing. |
| G2 | Expected relative gait and stable aim-facing torso/pelvis; diagonal rows are not cosmetic cardinal duplicates. |
| G3 | Steady pelvis/torso match; transient torso/pelvis difference stays within the proposed 45° cap. Large turns release support rather than teleport a planted limb. |
| G4 | L/R contacts alternate. A planted foot remains within 1 native texel (L∞) of its contact position over the entire stance, after common camera/output transforms. Double support must satisfy both targets; otherwise revise art/contact timing. |
| G5 | Casts, gait retargets and direction changes preserve anatomical contact semantics. Walk/run phase transfer does not invent a plant during flight. |
| G6 | Fixed ground root, continuous torso seam, no limb swapping, alpha clipping or erroneous front/back layer order. |
| G7 | Cast accent affects body presentation only; spells/environment are separate; visual hand socket does not choose authoritative projectile origin. |
| G8 | Repeat at presentation rates 30/60/120 Hz against the same existing 120 Hz target simulation trace; camera motion, correction and interruption must not create false steps or collision changes. No such trace was supplied. |

Idle, air, slide, turns and state transitions need P0/P3/P4 in addition to this ground-locomotion matrix. None of these reviews has been run.
