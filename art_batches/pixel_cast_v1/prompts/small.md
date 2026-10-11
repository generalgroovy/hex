# Small cast fixed-pixel source prompts

Built-in image generation only. Current names and ancestries were read from content/champions/foundation_champions_v1.json and assets/sprites/fullbody_cast_v1/manifest.json. Reference images inspected before generation. Tool originals retained under .codex/generated_images. Final prompts and targeted corrections are also retained in each character receipt.

## Shared generation prompt

Use case: stylized-concept. Asset: fixed-pixel game sprite atlas on genuinely transparent RGBA.
References: image 1 is exact character identity and clothing; image 2 is retro pixel style only (ignore its old names); image 3 is compact common-head/body proportions and readable charming finish only, NOT its row count.
Make exactly 32 whole-body sprites in exactly 8 equal columns by 4 equal rows. Generous empty transparent gutters, identical size and baseline, feet/hair/appendages fully intact in each cell. Coarse clean pixel clusters, crisp limited-palette outlines, compact modest charming proportions matching image 3; no painterly smoothing.
EVERY row column order: S front, SE front/right45, E right profile, NE back/right45, N straight back, NW back/left45, W left profile, SW front/left45. NE/N/NW show the back of the head with NO frontal eyes. Torso and feet rotate with head. Eight unmistakably distinct directions.
Rows only: 0 idle standing; 1 walk contact with LEFT foot forward and RIGHT arm forward; 2 opposite walk contact RIGHT foot forward and LEFT arm forward, genuinely alternating feet not duplicated poses; 3 planted stance, BOTH EMPTY hands forward casting, no magic. Never add a fifth row.
Maintain exact face, costume, anatomy and palette in all32 frames. No staves, weapons, held objects, ground shadows, scenery, text, labels, grid lines, sparkles or baked spells. Wide transparent canvas.

## Identity subjects

- grace_reava: Grace Riva, small sylph: short teal bob hair, pointed ears, light skin, dark teal and gold tunic with cream sleeves, brown-gold boots, four pale cyan insect wings with distinct gold/cyan veins. Keep four wings coherently attached to back and complete in all directions. Use exact image1 design.
- wa_bidi: Wa Bidi, small goblin: lime-green skin, very long pointed ears, tousled dark charcoal hair, yellow eyes, dark green leaf-panel tunic with gold edging, brown leather wrist guards and boots. NO wings, NO goggles. Use exact image1 identity.
- steezo: Steezo, small goblin: olive-green skin, large pointy ears, short brown-black spiky hair, blue round glass goggles in gold rims, dark brown-black engineer tunic with gold edging and buttons, leather gloves, compact boots. No backpack gadget, no held props. Use exact image1 identity.
- nico_lai: Waka Aren Si (stable asset ID nico_lai), small gnome: pale warm skin, enormous spiky white hair, bushy white eyebrows/moustache/short beard, cyan round goggles in gold rims, navy-blue coat with golden edging and belt, brown gloves and boots. Preserve distinctive white-haired gnome identity from image1. No staff.
- haara: Haara, small nymph: light warm skin, green eyes, long dark-green flowing leaf hair with small pale-pink flowers, pointed ears, leafy dark-green and gold outfit, cream sleeves, brown boots. Long floral leafy hair remains coherent from all angles. Use exact image1 design.
- luuh_i_zeh: Luuh I Zeh, small spiderkin: purple-blue carapace skin, swept segmented spiky purple head, yellow-orange eyes, dark purple and gold fitted armor. Two normal humanoid arms and two normal legs PLUS four jointed purple spider appendages attached to upper back, two per side. Keep this exact appendage count and attach points in all views. No wings. Use exact image1 identity.
- juul_i_yaina: Juul I Yaina, small demon: blue skin, short curly black hair, two small red swept horns, blue pointed ears, golden eyes, navy-black long split coat with ornate gold trim and belt, black boots. No wings or added tail. Use exact image1 design.
- fimu_yashiha: Mifu (stable asset ID fimu_yashiha), small treefolk: warm brown living bark skin, rounded cheerful face, long full foliage hair green/ochre/rust-red leaves with small white daisies, tiny pointed woody ears, teal-blue gold-trimmed tabard and leafy clothing, bare root-like feet. Keep feet genuinely alternating in walk despite leaf coverage. Use exact image1 identity.
- sai_laas: Sai Laas, small nymph: light warm skin, green eyes, short thick spiky rust-orange and green leaf hair with small flowers, long pointed ears, olive-green leaf panel tunic with leather brown straps and gold edging, brown boots. Use exact image1 identity.

## Acceptance boundary

These are generated source candidates for lead assembly. Read each receipt for motion/direction/anatomy gaps. No runtime art, imports, engines, tests, exports, commits, or original reference assets were changed by this worker.

