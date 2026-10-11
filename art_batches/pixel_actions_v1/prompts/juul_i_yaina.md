# Juul I Yaina fixed-pixel jump source

Date: 2026-10-03. Built-in image generation only. One source sheet; no runtime integration or human acceptance claim.

## Reference paths

1. `C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/juul_i_yaina.png` - primary runtime identity and proportion reference.
2. `C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/juul_i_yaina-detail.png` - supporting identity/costume detail.
3. `C:/Users/sende/Pictures/styleref1.png` - style only, not identity or species authority.

All three references were visually inspected before generation. The roster identifies this character as small/demon.

## Exact generation prompt

Use case: identity-preserve.
Asset type: H.E.X. production jump-key sprite-sheet source for ONE existing character, Juul I Yaina, Small Demon. Create a new transparent sheet, not a redesign.

Input image roles:
Image 1, assets/sprites/pixel_cast_v1/juul_i_yaina.png, is PRIMARY CURRENT RUNTIME CANON for identity, compact full-bodied proportions, costume, colors, gender presentation and the eight genuine headings.
Image 2, assets/sprites/fullbody_cast_v1/juul_i_yaina-detail.png, supports facial detail, coat construction and genuine rear/profile anatomy. Preserve this exact blue-skinned, red-horned demon.
Image 3, styleref1.png, is STYLE ONLY: charming retro pixel clusters and colored outlines. Ignore all its names, species labels, other characters, props and spells. Juul I Yaina is a SMALL DEMON, not a werewolf.

Scene/backdrop: genuinely transparent RGBA, no painted background or checkerboard. One landscape sheet approximately 2048x1024 with exactly 8 equally spaced columns by 4 equally spaced rows, 32 complete full-body poses. Generous clear gutters; every fingertip, boot, ear and horn stays inside its own cell. No text, numbers, grid marks, titles or labels.

Subject invariants: the same compact masculine-presenting small demon in every cell, cobalt-blue skin, yellow eyes, pointed blue ears, short dense wavy black hair, two curved red horns. Preserve the modest closed dark charcoal/deep-purple long-sleeved coat with rich gold piping, gold fastenings and gold-edged front/rear panels reaching the upper thighs, gold-trim cuffs, belt, dark full trousers and dark sturdy boots. Both hands empty. Preserve the current face, gender presentation, body volume, joint lengths, skull, costume panel layout and colors. Do not invent wings, a tail, wolf features, furry limbs, bare chest or revealing clothing.

Proportion contract is important: neutral standing crown-to-sole scale would be 58 units, with hair crown-to-chin head about 18-20 units, about ONE THIRD of neutral standing height, never one half. Horn tips can project above the hair but do not enlarge the skull. Keep actual neck, torso, waist, pelvis, thighs, knees, calves and boots below the head. Compact but FULL-BODIED, not a baby/chibi giant head on tiny coat and feet. One common head size and one common body scale across ALL 32 sprites. Pose compression occurs only through joints bending, never scaling or stretching the anatomy. Small-body identity is expressed through compact body volume, not omitted legs.

Column headings left to right in EVERY row:
1 S = front, faces camera/viewer.
2 SE = front three-quarter, facing screen RIGHT.
3 E = true right profile.
4 NE = BACK three-quarter facing screen RIGHT; show back and right shoulder, not the front chest.
5 N = full BACK, faces away, back hair and coat panels visible, no face on the back.
6 NW = BACK three-quarter facing screen LEFT.
7 W = true left profile.
8 SW = front three-quarter facing screen LEFT.
Turn the entire head, torso, pelvis and feet together. Genuine eight-direction anatomy, not a turned head on a front torso and not synthetic mirrored columns.

Rows top to bottom, four readable authored action keys:
1 JUMPSQUAT / anticipation: boots planted, knees visibly bent, lowered pelvis, torso balanced above legs, bent elbows and empty hands slightly behind/outside the hips. Posed hair-crown-to-sole height about 48-51 units at the common 58-unit standing scale.
2 RISING TUCKED JUMP: clearly airborne anatomical pose, knees bend and feet tuck backward toward the thighs, elbows bent and arms slightly spread upward/outward for balance. Keep torso and thighs real length; do not curl into a sitting ball. Posed height about 51-55 units; same 18-20-unit head.
3 DESCENDING FEET-READY JUMP: legs unfold clearly beneath the pelvis, knees softly bent, both boots point downward ready for ground contact, hands held more forward/outward and lower than row 2. Readably different long-leg silhouette from tucked row 2, posed height about 56-58 units; same head.
4 DEEPLY COMPRESSED LANDING: both boots planted, knees bend deeply outward/forward, pelvis noticeably lower than anticipation, torso leans naturally forward, elbows bent and empty hands forward beside the knees for balance. Posed height about 44-48 units. Preserve anatomical limb length and coat volume, no squash-scaled body. Visibly deeper and more compressed than row 1.

Registration: use one common sprite-cell coordinate system and one model scale; never fit each pose separately to a cell bounding box. Keep matching per-direction body roots horizontally centered, consistent imaginary feet/root baseline across each row. Do not bake a world-space jump arc into vertical sprite placement; the game provides world-height motion. Natural hand occlusion in rear views is acceptable but hands must stay connected and empty.

Style/medium: crisp deliberate retro pixel-art clusters, clean dark colored outlines, restrained gold highlights and blue-skin shading, same top-left lighting and dark/gold/blue/red palette as runtime reference. Charming expressive face without giant eyes or an oversized hairball. No smoothing, motion blur, ground plane, cast shadow, dust, sparks, spell effects, magic, glow, weapons, staffs, wands, props, extra figures or watermark. Preserve genuine transparent alpha.

## Source review

One built-in generation call produced a 1774x887 RGBA original. All 32 sprites are present with no cropped extremity or gross facing reversal observed. Blue skin, black hair, red horns, pointed ears, gold-trimmed modest dark coat, trousers and boots match the current demon identity. Hands are empty. Tucked rising and feet-ready descending silhouettes differ; landing is visibly more compressed than anticipation. Head size appears broadly consistent across poses at source size; exact comparison against the runtime model at a shared native scale remains unverified. Some rear hands and paired legs are naturally occluded, and profile headings can read slightly rearward. These are source-review limitations, not corrective-call triggers.

The original is copied byte-identically to `source/juul_i_yaina/source.png`. It retains generated partial-alpha pixels; no thresholding, registration, recoloring, cropping or downsampling was performed. Alpha cleanup and assembly belong to the lead. Native-scale, runtime, animation timing and human acceptance are NOT_RUN. No runtime files or shared pipeline files were edited.
