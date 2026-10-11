# ChatGPT: Wellspring layout and player understanding
Start after first-four chemistry review; do not depend on another chat's unseen results.

Read attached packet/shared contract/manifest, repository/content/maps/sanctum_campus_g2_v1.json, src/content/sanctum_campus_layout.gd, src/sim/hex/hex_world_definition.gd, hex_grid.gd, hex_footprint.gd and the native Wellspring captures. The nine-district hub catalog contains future/other layout descriptions; live campus code, not a concept map, determines current dimensions, collision and accessible cells.
Read the two supplied hex-map images as inspiration only. If coordinate scale/inputs are missing, flag them; never invent measured navigation results.

Design one compelling chemistry courtyard now and a modular campus expansion later. Preserve continuous eight-direction movement on hex chemistry; this is not turn-based Catan movement. Exact impact/radius selects complete hexes; no circular post-selection clipping.
Use a memorable central fountain and coherent warm stone/timber/brass/greenery, natural material transitions and functional landmarks. Let paths, sightlines and affordances explain the world. Include movement practice, safe chemistry experiments, duel area and host/join/party controls accessible with remote friends. Preserve clear shared spawn and exits; proposals for new sanctuary rules need explicit design review, not silent blanket safe zones.

Deliver:
- LAYOUT.md: current-vs-proposed, player routes, action opportunities, bottlenecks and one small implementable pilot.
- HEX_LAYOUT.json or CSV using documented axial/world units; include bounds, IDs, purpose, entrances/exits, collision/height and obstacle placement. If coordinates cannot be verified, label a schematic and supply the exact missing data list instead.
- One annotated plan-view image and a native-scale gameplay composition if tools allow; distinguish concept views from screenshots.
- UX_TABLES.md: compact HUD, spell slots/modifier layers, source-derived chemistry reference, station interactions and a five-minute first-session flow. Use current bindings; don't invent live keys.
- ACCEPTANCE.md: player tasks, traversal/escape checks, three-size clearance, reduced-effects readability, NPC/station discoverability and multiplayer checks for Codex to run.

Optimize interesting movement decisions and reusable kit pieces before raw acreage. Do not make active simulation cost proportional to whole map size or propose thousands of independent decorative effect nodes. A Steam/Magma route must remain readable with overlapping actors and projectiles.

Return FLUX-MAP-UX-v1.zip with actual artifacts, HANDOFF.md, manifest.json and all preview dependencies. Do not claim the UI HTML or a concept image has been implemented in Godot.

