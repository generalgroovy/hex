# Wellspring campus v2 image prompts

Status: reference-only generated concept; not implemented.

Tool: built-in image generation. Original prompt used no input image. The
correction used only the first generated map as its edit target. The final map
is `wellspring-campus-v2.png`; the first variant is not promoted or copied into
this proposal folder.

## Original generation prompt

```text
Use case: stylized-concept.
Asset type: a single high-resolution landscape game level-design concept map, for later FLUX project reference, not an implemented screenshot or asset sheet.
Primary request: create a beautiful, charming, highly readable bird's-eye overview of the entire WELLSPRING academy campus for an original old-world magical, top-down movement and spell arena game. This is a modest, activity-dense expansion, not an enormous city. Mix polished chunky pixel-art-inspired miniature illustration with a useful level-design map. The result should be clear enough to trace every ordinary walking route. Landscape 3:2 composition, map filling the page with a narrow title band and narrow footer. Crisp contours and cartoon material shapes, restrained texture, no photorealism.
Perspective: very high overhead camera, screen-north at top. All main floor axes, stairs, walls and buildings align horizontally and vertically to the picture, NEVER a rotated diamond/isometric grid. Only short front-facing facades show depth; no towering structures obscuring paths. The whole map is an overview, not a literal player-camera scale.
Art identity: warm worn sandstone floors, dark timber, compact blue-slate roofs, old brass, deep teal water, rounded mossy foliage, modest cyan fountain light. Handcrafted magical academy, bright readable daylight, welcoming. Quiet pale play spaces; richer detail at scenic edges. Original architecture, symbols and composition. No borrowed game characters, logos, weapons, layouts or interface. No science-fiction or modern military styling.

Spatial composition, exactly six labeled activity areas:
A at the center (50% width, 47% height): SOURCE COURT. Open stone plaza with a SMALL bright water fountain as orientation landmark. Broad, clearly walkable space surrounding fountain. Three modest furniture stations along the quiet north/side rim for character, spells and party settings, not text walls. Several tiny hand-casting cartoon player silhouettes for scale, no held implements. Above the court near the top middle, a compact academy facade is a scenic landmark, NOT another labeled district.
B at upper left (19%, 31%): MOVEMENT GARDENS. A distinct loop of grass and quiet stone paths with a slalom, low vault walls, a short optional sequence of little jump gaps and parallel broad ordinary bypass. Show safe landing pockets, short stairs and obvious wall feet; no mandatory precision jumps on the main route.
C at upper right (81%, 28%): PATTERN GALLERY. A rectangular practice range with three clear firing lanes pointing NORTH into stout backstops, a few visible targets and adjustable practice props. No firing lanes aimed toward the central court. Small covered side shelters, quiet floor.
D at lower right (81%, 65%): DUELING COURT. A separate square sparring arena enclosed by low stone perimeter and two opposing controlled entrances. Symmetric obstacle placement: four small cover islands leaving a large central open floor and two clear crossing lanes. Small spectator strip OUTSIDE its perimeter. No live crossfire on public paths.
E at bottom middle (49%, 82%): ELEMENTAL CRUCIBLE. A bounded alchemy yard with two small reaction basins, exactly eight simple element plinths arranged around the basin area and a short row of separated wood/brick/water/material test plots along the rim. Quiet surrounding walkway, physical containment curbs, a reset bell. Limited little elemental cues, not dense spell explosions.
F at lower left (18%, 76%): RECOVERY GROVE. A sheltered garden with benches, a pond, tiny friendly social props, broad paths and two exits. A calm gathering area without mandatory chores, crafting factories or combat.

Topology matters more than decoration: five broad ordinary walking spokes join the central court to the five outer activities. A second continuous connected ordinary OUTER LOOP joins B-C-D-E-F-B and bypasses the central court. Paths must visibly connect at their endpoints, not stop at water or solid buildings. The outer loop may be softened by garden bends, but keep floors screen-cardinal. Where shallow canals cross a route, include a broad intact bridge. Optional narrow movement shortcuts are secondary to the broad ordinary routes. Island shoreline and deeper water frame the campus edges; do not split the campus into isolated islands or single-entry bottlenecks. Eight players should have room to pass. Small modular structures and trees must not fill the playable floors. Do not draw a UI graph over the map.

Text: Only the following exact clear large labels, on small calm parchment plaques beside their respective areas, without covering route junctions:
"FLUX — WELLSPRING"
"EXPANSION CONCEPT · NOT IMPLEMENTED"
"A  SOURCE COURT"
"B  MOVEMENT GARDENS"
"C  PATTERN GALLERY"
"D  DUELING COURT"
"E  ELEMENTAL CRUCIBLE"
"F  RECOVERY GROVE"
Footer, small but readable: "Central services · Connected outer loop · Optional shortcuts · Contained experiments"
No other text, no HUD, no spell bar, no watermark. Correct spelling. Make this an inviting, professional, usable environment design reference whose layout and original cartoon charm are equally convincing.
```

## Corrective edit prompt

```text
Edit this existing FLUX Wellspring reference map with only two small accuracy corrections. Preserve the entire composition, pixel-inspired illustration, six-zone layout, paths, buildings, colors, title, footer and all existing labels exactly.
1. The central fountain plaza is missing its area label. Add one readable parchment plaque, matching the other plaques, with the exact text "A  SOURCE COURT". Place it inside the central open plaza just below the fountain, without hiding the fountain or any doorway/path junction.
2. The Elemental Crucible currently has nine raised element plinths, but the design needs exactly EIGHT. Remove ONLY the duplicate orange/fire plinth at the lower-left of the Crucible (the bottom-row orange flame directly above the timber sample tray); replace its footprint with matching quiet stone floor. Keep all other eight plinths, the two round basins, the material trays and the reset bell unchanged.
No other additions, rearrangements, new labels, symbols, new buildings, new characters or changes. This is a labeled concept reference, not runtime assets.
```
