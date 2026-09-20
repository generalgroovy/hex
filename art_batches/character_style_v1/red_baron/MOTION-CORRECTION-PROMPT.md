# Red Baron targeted motion repair

Built-in imagegen edit of immutable full-page-v1.png. Candidate only, no runtime promotion.

Use case: identity-preserve, precise animation repair. Image1 is the EDIT TARGET: Red Baron8columns×10rows complete sprite sheet. KEEP its same80cell layout, canvas size, art style, character colors, proportions, costume, crown, direction order, all cell gutters and blank backdrop. It is an isolated sprite sheet, no text/shadows/effects/weapons. Return a genuinely transparent background if possible, not a painted checkerboard.

Change only the animation articulation needed below. The basic identity/rendering is already correct; do not redesign.
Direction columns remain S,SE,E,NE,N,NW,W,SW; ten rows remain grounded,jump,cast,hit,walkA,sprintA,slide,roll,walkB,sprintB.

ESSENTIAL REPAIR1: TRUE BACK VIEW column5 may NOT repeat the same upright cloak in every row.
- row3 column5 CAST: viewed entirely from behind, left arm extends forward AWAY from viewer, elbow projects visibly to left side, raised shoulder, right hand near chest, staggered feet; cloak twists left revealing the hip. No face, no magic.
- row4 column5 HIT: viewed from behind, shoulders hunch and recoil, head/neck angled back, knees bent asymmetrically, open hands lifted out; cloak folds and outline distinctly compressed vs idle.
- row5 column5 WALK A: left boot steps FORWARD AWAY from viewer (higher in image), right boot trails nearer viewer (lower), right arm forward away/left arm back, cloak lifted to reveal both knees/boots.
- row9 column5 WALK B: exactly swap the ANATOMICAL LEADING LEG and arm, right boot forward away/higher and left boot trailing near/lower. This is NOT changing costume side, not a horizontal flip of the entire character.
- row6/10 column5 SPRINT A/B: much longer alternating strides away from viewer, leaning torso, cape streaming backward but BOTH separated boots visible, opposite lead between A/B.

ESSENTIAL REPAIR2: WALK B row9, ALL8 columns: fully articulate the opposite leg contact of WALK A row5. If left foot leads row5, right foot must lead row9. Make the lead foot’s sole visible and forward leg clearly load-bearing; bend the trailing knee and lift its heel. Swap arms anatomically too. Row9 must not look like standing idle with nearly parallel legs. Maintain unchanged crown, chest jewel, lapels, torso widths and exact facing, without mirroring identity pixels.
Likewise row10 SPRINT B must visibly switch leading legs relative row6 in every column; not simply another pose in the same left-leading stride.
For side-view columns3 and7, keep near and far legs distinguishable by occlusion: A has near knee/boot extended forward and far leg behind; B extends the FAR knee/boot forward beyond the near shin while near knee folds behind. Both feet remain visible; no impossible extra legs.

Preserve all remaining cells. Exact8columns10rows, full unclipped bodies with generous margins, same global skeleton scale. Do not add duplicate rows, titles, symbols, panels, weapons, magic, trails or shadows.
