# Joh Haynes neutral-calibrated action source v2

Date: 2026-10-04. Built-in image_gen with transparent_background=true. One initial generation and at most one targeted correction for a gross anatomy/facing/grid/cropping defect. No CLI/API fallback.

The integration lead selected Joh Haynes after the 30-character current-runtime scale audit and Fluup's native-board checkpoint. Canon: joh_haynes / Joh Haynes / orc / large. Native assembly, lead acceptance, runtime transitions and human acceptance remain NOT_RUN.

## Reference images in order

1. C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/joh_haynes.png - primary approved neutral anatomy, body mass, costume and headings.
2. C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/joh_haynes-detail.png - supporting costume and profile/rear details.
3. C:/Users/sende/Pictures/styleref1.png - retro pixel style only.

All three references were inspected with view_image. Existing action v1 is a diagnostic rejected-proportion comparison only, not a generation input. The neutral-row recipe supplies layout/registration logic, never another character's anatomy.

## Exact initial prompt

Use case: stylized-concept.
Asset type: production pixel-art sprite-sheet source for H.E.X. Joh Haynes (joh_haynes), the existing large-bodied male orc champion. New neutral-calibrated whole-body jump sheet, not a redesign.

Input image roles: Image 1 is the PRIMARY APPROVED current runtime Joh Haynes atlas. Its FIRST ROW defines exact standing anatomy, head with hair/beard/jaw size, broad shoulder and chest mass, thick limbs, costume, colors and eight directions. Image 2 supports Joh Haynes costume and genuine side/rear anatomy, subordinate to the approved runtime first-row proportions. Image 3 is STYLE ONLY: charming retro fantasy pixel clusters and dark colored outlines. Ignore its other figures, labels, names, props, magic and weapons; in particular do NOT substitute Fluup or another orc for Joh Haynes.

Create a genuinely transparent RGBA image, approximately 2048x1280, with exactly EIGHT equal columns by FIVE equal rows: 40 complete separate sprites of the SAME identical character. Uniform cell centers, wide transparent gutters; every ponytail, beard edge, shoulder plate, finger and boot fully within its own cell. No borders, captions, labels, text, arrows, watermark, background or ground shadow.

Exact column order in EVERY row:
1 S directly front, facing viewer.
2 SE front three-quarter facing screen RIGHT.
3 E true right profile.
4 NE BACK three-quarter facing screen RIGHT, body and back of head turned 45 degrees AWAY, not another side or front view.
5 N full direct back, rear hair/ponytail and back armor, no face on back.
6 NW BACK three-quarter facing screen LEFT, body and back of head turned 45 degrees AWAY.
7 W true left profile.
8 SW front three-quarter facing screen LEFT.
Genuine whole-body directions, not head-only turns, rotated flat sprites or fake mirrored headings. Back quarters show rear armor planes, back shoulder planes and back of ponytail, never a front chest with its face erased.

Rows from top to bottom:
ROW 1 NEUTRAL CALIBRATION: upright relaxed standing like Image 1 first row, heavy boots planted, legs softly straight, substantial empty hands slightly clear of hips. This row is an anatomical and scale reference, not a jump pose.
ROW 2 ANTICIPATION: visibly bend knees and hips, lower pelvis roughly 10 percent of standing height, keep boots planted apart, elbows comfortably bent. Keep the SAME substantial head/beard, chest, shoulder armor, biceps, fists and limb lengths as neutral. Crouch by joint articulation, never by miniaturizing the model.
ROW 3 RISING TUCKED JUMP: BOTH knees flex up toward the hips, heavy boots naturally tucked beneath/back toward pelvis; arms spread for balance, torso upright and full-sized. Roughly 10 percent shorter overall than neutral. Do not dangle two long straight legs or curl the whole orc into a ball.
ROW 4 DESCENDING FEET-READY: open hips and knees so boots are ready below the body, soft knees and balancing forearms forward/outward. Near-neutral total height, visibly different leg and arm silhouette from ROW 3. Preserve the neutral massive anatomy, do not make a lanky slimmer airborne model.
ROW 5 COMPRESSED LANDING: deeper real knee bend than ROW 2, pelvis between spread planted boots, torso leaning naturally forward, empty hands balancing near knees. Approximately 18 percent shorter overall than neutral. Thick thighs and calves remain anatomically connected; never scale or squash the body or head.

CRITICAL MASS-CONTINUITY REPAIR: The existing action attempt failed because a nearly equal overall standing height hid a much smaller head, narrower chest/shoulders and thinner limbs. This new sheet must preserve the approved neutral body MASS, not merely total height. Skull with tied-back black hair, full black beard, olive-green broad face/jaw, thick neck, bronze shoulder plate width/volume, biceps, forearms, fists, broad chest, thighs and heavy boots must remain the SAME anatomical dimensions across ALL 40 drawings. A crouched Joh Haynes must look like the same robust orc bending his knees, not a smaller orc. An airborne Joh Haynes must look like the same robust orc lifting his feet, not a skinny orc stretched to fill a tall bounding box. Anchor exact part dimensions to Image 1's FIRST ROW. Standing-equivalent native target is approximately 68 pixels, but never substitute a generic head fraction or stretch height for the actual reference anatomy. Keep his bearded face substantial and recognizable at native game size. No pinhead, reduced shoulder plates, thin arms, tiny fists, elongated shins, huge baby head, lean human redesign or runtime-scaling look.

Identity/costume invariants: Joh Haynes is the broad muscular male olive-green orc in Images 1 and 2, with pointed ears, two small ivory lower tusks, stern readable warm yellow eyes, black tied-back ponytail/topknot and full black beard. Preserve distinctive bronze-brown riveted shoulder plates with rounded gold rims, brown leather torso armor with diagonal straps, bronze bracers, round gold belt buckle, dark green gold-edged hanging waist tabard, leather hip panels, dark trousers and stout brown armored boots. Arms and hands are green. Match exact approved palette and material shapes. No redesign, no Fluup's spiky black/silver steel armor, no giant protruding spikes, added cape, accessories or weapons. Hands are visibly empty with natural readable fingers or fists. Preserve masculine presentation without sexualization.

One common model scale and camera in every cell. NEVER fit a pose to its own bounding box, enlarge a crouch, shrink a head, narrow the torso or change bone length. Register body roots near each cell's horizontal center and use consistent imaginary lower baselines within each row. Do not translate whole airborne bodies upward to fake a trajectory; runtime supplies world-height lift. Only anatomical articulation changes.
Style: crisp deliberate retro pixel-art clusters, clean colored outlines, steady top-left material light, high native-size readability. Preserve true alpha transparency with no baked checkerboard. No weapons, spells, effects, glow, dust, contact shadows, ground plane, props, text or extra figures.

## Assembly contract

Eight columns S, SE, E, NE, N, NW, W, SW. Source row 0 is neutral-only calibration; action rows 1, 2, 3, 4 map to anticipation, rise, fall, landing. One shared source-wide scale. The untouched generated PNG is the source; cleanup, deterministic registration/downsampling and native board review belong to the integration lead.

## Generated source result

Built-in image_gen.imagegen: one initial call, zero corrective calls. Original preserved at C:/Users/sende/.codex/generated_images/01a106a3-1c20-75d1-bb18-92725dded5ca/exec-9cee2cf7-6aff-432e-bb82-17108cc52035.png. Copied unchanged to art_batches/pixel_actions_v2/source/joh_haynes/source.png; both SHA256 values are f9f050594b24bb9c256add335a7c61b6d38bde7663758e97e759245c4719d0c5.

Actual image: 1586 by 992, 32-bit RGBA, 1,586,865 bytes. Source-size inspection found the complete five-row/eight-column grid, consistent broad head/beard and bronze shoulder armor across neutral and actions, tucked rise and opened feet-ready fall, and a deeper landing. No gross missing heading, clipped body part or accidental prop justified a correction. These are qualitative source observations, not native continuity acceptance.

Source has extensive partial alpha and has not been cleaned, painted, rescaled or otherwise edited. The integration lead owns deterministic cleanup, native assembly, fixed-pixel comparison and rendered review. SOURCE_CANDIDATE_PENDING_LEAD_REVIEW; native assembly, lead acceptance, runtime integration, Godot import, rendered transitions and human acceptance NOT_RUN.
