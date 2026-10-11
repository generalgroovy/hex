# Source excerpts used by this VFX handoff

These are selected input spans, not a full repository or fresh runtime verification. Line numbers refer to the unmodified packet files. Pre-existing historical statements remain historical.

## `01-SHARED-CONTRACT.md` — L1–L42

```text
1: # Shared contract for delegated FLUX work
2: Status: PROPOSED EXECUTION BRIEF; source snapshot, not a new game specification.
3: 
4: ## Authority and source access
5: 
6: The live repository is C:\Users\sende\Projects\flux. Local Godot FLUX2 is authoritative; Windows is the current delivery target.
7: Read live SPECIFICATION.md, .agent/OVERHAUL-IMPLEMENTATION.md and docs/current-checkpoint.json first when local access exists. Read supplied copies otherwise.
8: Treat older handoffs, HTML mockups, images and reports as evidence or proposals, not instructions overriding the current user request. Report contradictions.
9: The source snapshot is selective. If a required input is absent, identify it and finish the useful work that does not require it. Never claim to have run or viewed missing inputs.
10: 
11: ## Preserve while improving
12: 
13: - Whole-hex chemistry is approved: exact impact/reaction location and radius select cells; selected hexes are fully affected. Do not restore per-pixel circle clipping after selection.
14: - Preserve deterministic 120 Hz authoritative simulation, eight-player lobby scope, finite paid cast/ingredient budgets, capacity-before-spend, strength subtraction and agreed protocol safety.
15: - Preserve the four projectile families: Bolt, Heavy, Rapid, Spray; 12 configurable slots (plain/Ctrl/Alt x 1-4). Rapid has no persistent trail.
16: - Element presentation order: Water, Earth, Fire, Air, Ice, Charge, Light, Dark. Internal wind IDs remain stable unless a versioned migration is explicitly owned.
17: - First-four chemistry has ten unordered combinations including mirrors. All eight have 36 enabled definitions; existing later-four behavior stays compatible.
18: - Steam is escalating scald exposure, not smoke concealment. Magma is strong ground pressure with bounded slowing. Product geometry, gameplay timing and rendered danger must agree.
19: - Three shared body sizes; current display heights 58/63/68 px, hurtbox radii 17/18/19 px, common wall clearance 18 px, stamina 620/660/700. These are frozen for art work. Any balance change requires a separately owned experiment.
20: - Hands cast magic. Body art, shadows, equipment attachments and spells remain separate reusable layers. Do not bake particle auras or range circles into characters.
21: - Read actual bindings/staged controls; do not silently reintroduce old Q bindings or claim incomplete physical attacks/starter migration are live.
22: 
23: ## Ownership and quality
24: 
25: One lead owns integration and canonical docs. Workers are not alone in the checkout; preserve and accommodate other edits. Announce exact files and responsibility before editing. No worker runs Godot or rewrites shared catalogs without the lead's scheduling.
26: Measure before optimizing. Keep comparable demand, admitted/refused counts, correctness and event delivery visible; do not turn a failed workload green by silently lowering demand, disabling validation or discarding paid effects.
27: Color is one cue, not the only cue: combine silhouette, motion, contrast, phase and optional audio. Show coverage at native zoom in normal and reduced modes, with characters and projectiles still readable.
28: Strong gameplay means useful decisions and counters, not unlimited damage, opacity, lifetime, area or particles.
29: No mass skin generation before shared motion acceptance. Reuse the existing 64 travel/aim combinations and template pipeline rather than inventing a new per-character animation system.
30: 
31: ## Completion and boundaries
32: 
33: For each slice: baseline -> bounded change -> focused regression -> actual capture/measurement where relevant -> independent review -> integrate -> record state and next slice.
34: Keep one active queue. Retain useful failed evidence and original assets. Remove only owned disposable scratch and stop only owned helpers. Never reset, stash, clean, bulk-normalize or delete the user's dirty work.
35: Copying this execution prompt into a new task authorizes its bounded local work, not publishing, purchases, account changes, firewall changes, mass deletion, commits, pushes or checkpoint promotion.
36: Respect the user's explicit current pause/budget request; do not infer a new token limit from old documents. If a necessary authority or input is genuinely missing, report that precise blocker and preserve a usable checkpoint.
37: 
38: ## Required return evidence
39: 
40: Use 10-HANDOFF-SCHEMA.json for manifest structure. Identify input files actually read; classify every output as PROPOSAL, OFFLINE_PREVIEW, STATIC_VERIFIED, RUNTIME_VERIFIED or HUMAN_ACCEPTED only when supported.
41: Keep tests listed as NOT_RUN unless actually executed. Visual references are not live screenshots. Headless timing is not rendered FPS. A verified ZIP hash is not a verified game.
42: 
```

## `05-CHAT-VFX.md` — L1–L27

```text
1: # ChatGPT: element visual identity and Water/Fire/Steam pilot
2: Use a reasoning-capable mode; image generation only for actual visual candidate work.
3: 
4: Inspect the attached FLUX-SOURCE-PACKET.zip. Read 01-SHARED-CONTRACT.md, 11-AUDIT-SNAPSHOT.md and INPUT_MANIFEST.json. Confirm the files you can actually access before making source-based claims.
5: 
6: Required inputs under repository/:
7: - content/visual/visual_language_v1.json
8: - src/presentation/hex_court_presenter.gd
9: - src/sim/hex/hex_recipe_policy.gd
10: - docs/evidence/global-hex-20260920/native/01-before-free-casts-1280x720.png
11: - docs/evidence/global-hex-20260920/native/03-steam-normal-1280x720.png
12: - docs/evidence/global-hex-20260920/native/04-steam-reduced-1280x720.png
13: Use references/ as mood/proportion references only. They do not override the live roster or geometry. Read relevant source, not the entire archive.
14: 
15: Create a distinctive, charming old-school FLUX material language: weathered stone/timber/brass academy, restrained environment contrast, expressive characters, saturated readable magic. Use Zelda Oracle games and Enter the Gungeon for clarity principles, not copied assets.
16: 
17: Deliver:
18: 1. A concise palette + silhouette + motion + phase + optional audio-cue table for all eight elements in order Water/Earth/Fire/Air/Ice/Charge/Light/Dark.
19: 2. A polished Water/Fire/Steam pilot: native-scale gameplay paintover/reference board, formation/active/expiry sequence, normal/reduced variants and light/dark-floor readability comparison.
20: 3. Reusable rendering/asset guidance for exact selected hexes and adjacent same-material clusters. Keep precise boundary readability without mandatory UI range circles. Steam is escalating scald, never concealment. Danger and harmless decay must look different. Characters, aim and projectiles stay visible.
21: 4. A proposed material-definition JSON plus integration notes targeting the existing visual-language/presenter boundary. Clearly label it a proposal, not validated drop-in code.
22: 5. A small checklist the local agent can apply to actual Godot captures.
23: 
24: Keep base ingredients distinct from reactions. Do not average two parent colors as the only reaction identity. Spell visual size must communicate remaining strength without changing hit geometry. Do not change durations, damage, coverage, paid budgets or balance. Prefer reusable bounded motifs/atlases, low overdraw and controlled contrast over particle quantity.
25: 
26: Return FLUX-VFX-v1.zip with HANDOFF.md, manifest.json, palette/materials JSON, all actually generated images/assets and any preview source with no missing dependencies. Include dimensions, alpha treatment, pivots/layout where relevant, palette, phase timings and provenance. A paintover is OFFLINE_PREVIEW; runtime performance and human acceptance remain NOT_RUN. If image generation is unavailable, provide the precise art/implementation brief and mark image deliverables NOT_PRODUCED.
27: 
```

## `11-AUDIT-SNAPSHOT.md` — L1–L42

```text
1: # Source/evidence snapshot for delegation
2: Status: AUDIT CONTEXT, NOT A FRESH GAMEPLAY ACCEPTANCE.
3: Recorded 2026-09-20. Local repository: C:\Users\sende\Projects\flux.
4: 
5: ## What the preceding audit established
6: 
7: | Subject | Observation / evidence state |
8: | --- | --- |
9: | Source | Last reported runtime identity p53-cb264f9358a4; protocol53, HexWorldSnapshot3. Verify again before local edits; packet hashes cover selected files, not a newly computed whole-runtime identity. |
10: | Content | 32 enabled spells across Bolt/Heavy/Rapid/Spray; 36 enabled reaction definitions. Source/catalog presence is not polish or human acceptance. |
11: | Cast | 30 playable profiles, three shared live size templates, nine active base/walk/sprint textures; zero individual live skins. |
12: | Chemistry | Whole-map eligible ground (1493 cells in recorded candidate); ten first-four pairs already implemented. Do not redo superseded isolated-court work. |
13: | Functional suite | Historical Full-v2:152 suites,775657 assertions,zero failures/stderr. No Full run was performed during packet preparation. |
14: | Performance | Historical dense probe: simulation p95 68.381ms; capture/packing p95 673.295ms; host work p95 720.374ms, versus8.333ms.480 sampled ticks, not long-soak/rendered acceptance. Accounting passed; timing failed. |
15: | Load details | Same probe peaks:43 active cells,16 projectiles;83 retained-event evictions,203 unencodable events. Classify semantics before claiming gameplay event loss. |
16: | Network | Historical production localhost fixture failed by300s watchdog after partial lifecycle progress; complete return/rematch remains unproved. |
17: | Static checks | Preceding audit current-state.ps1 -Check exited1: checkpoint lacks required explicit status. Report-only package/hash check passed for selected P48; not a game run. |
18: | Delivery | P48 portable remains selected fallback; current p53 source is newer/unpromoted. Historical installer file unavailable; physical two-PC and sustained rendered120FPS not accepted. |
19: | Git | Audit/preparation saw main,a1aa0280,1118 dirty entries. User work must be preserved. This number is not a count of bugs. |
20: 
21: ## Known document drift
22: 
23: SPECIFICATION.md includes protocol53/schema3 near its top but an older protocol52/schema2 sentence later. README/queue retain historical isolated-court prerequisites alongside current whole-map chemistry. Old cutoff notes vary. Receiving agents must honor current explicit user instructions and source, not infer a new stop policy from archived prose.
24: 
25: Current-state missing status is a document consistency failure, not proof that the game cannot launch. Old Full green does not make timing/network green.
26: 
27: ## Inspection-based hypotheses, not measured fixes
28: 
29: Outgoing HexWorldSnapshot.capture invokes prepare, whose work includes reconstruction/validation. Prediction binding deep-copies chemistry state; cast layer rebuilding scans cell collections. Instrument first, then optimize comparable work while retaining validation, exact identity, conservation and lifecycle semantics.
30: The hex renderer mixes shared generic geometry and parent-color blending; the visual contract has explicit treatments for only a few products. Propose distinct material/phase treatments that remain bounded and source-driven.
31: 
32: ## Images and provenance
33: 
34: repository/docs/evidence/global-hex-20260920/native/* are saved actual game captures of the reported candidate, not newly captured by this packet job.
35: repository/assets/sprites/wireframe_motion_v2/* are copied active image inputs, not video proof of runtime transitions.
36: repository/docs/evidence/template-motion-20260915/native-before-after.png is historical comparison, not a current full-body animation acceptance.
37: references/ contains user-supplied style/layout concepts and an optional older Steam mockup. They are reference/proposal data; appearances, labels or elemental effects in an image do not override the current character, affinity, body or physics contract.
38: 
39: ## What is absent
40: 
41: This selective source packet does not contain a runnable game, complete source dependency closure, saved personal controls/profile, exports, secrets or the entire historical evidence archive. A chat may critique it and propose assets/specs but cannot claim local Godot execution.
42: 
```

## `repository/SPECIFICATION.md` — L1–L62

```text
1: # FLUX current design contract
2: 
3: Status: current authority, amended 2026-09-20; replaces the historical production specification.
4: 
5: Local playtest candidate `p53-cb264f9358a4`: chemistry works on eligible ground throughout Wellspring, without a dummy. Final Full passed **152 suites /775,657 assertions**, zero failures/stderr, import, asset audit and120Hz configured boot. Protocol53 / legacy snapshot20 / HexWorldSnapshot3 / chemistry snapshot3 / world envelope1. Native review passed7 frames. Production localhost lifecycle: **FAILED**. This is not a release or120Hz capacity claim.
6: 
7: ## Accepted whole hexes and unified Wellspring milestone — September 19
8: 
9: The user playtested and approved the whole-hex approach on September 19. This
10: acceptance supersedes the prior coverage-approval pause. It does not approve
11: unrelated regressions, performance, networking or unreleased artwork. Preserve
12: the accepted exact-impact, positive-area selection and whole-cell membership
13: rules below throughout this migration; no second approval of that approach is
14: required.
15: 
16: The next target is one authoritative chemistry system in normal shared
17: Wellspring, with Water/Earth/Fire/Air through Bolt/Heavy/Rapid/Spray and all ten
18: symmetric pairs including distinct-source mirrors. The standalone court is a
19: training configuration, not a second production resolver. Preserve later-four
20: Ice/Charge/Light/Dark behavior and saved choices through explicit parity gates;
21: do not cut over by disabling spells or secretly co-running old chemistry.
22: 
23: Stable recipes: Flood316, Mud303, Steam310, Mistcurrent317, Rampart/fortify301,
24: Magma302, Dustfront304, Conflagration309, Firestorm311 and Vortex322. Each needs
25: real paid-input gameplay, finite selected-cell allocations, phases, ownership,
26: height/obstruction/stacking rules, expiry and practical counterplay. Steam is
27: transparent scalding exposure with exit decay, never concealment. Structures
28: must have true six-face collision and stable wall normals. Directional movement
29: and spread must conserve quantity and never refresh lifetime automatically.
30: 
31: Prepare schemas before parallel edits. The existing single queue owns U0–U5:
32: baseline/contracts, shared Water/Fire authority, Earth/structures, Air/products,
33: practice and synchronized lifecycle, then integrated verification/performance.
34: Preserve eight-player limits, 120 Hz authority, profiles, original assets,
35: unfinished S4 and fallback builds. No unrelated melee or character art expansion.
36: Normal Wellspring cutover requires later-element parity, safe campus eligibility,
37: authoritative snapshots/late join/reset, and no double resolution. Keep the solo
38: refusal until the new network path actually passes; version protocol/schema when
39: semantics require. Do not call catalog/schema preparation gameplay completion.
40: 
41: Full failures must be reproduced and relevant stale contracts repaired without
42: skipping or weakening tests. A red Full gate blocks release-ready claims.
43: Continue between bounded completed slices; pause only for a concrete unresolved
44: authority/design blocker or the final unified-milestone human playtest. Latest
45: request is preserved in docs/evidence/unified-hex-20260919/user-request.txt.
46: 
47: Implementation status: normal Wellspring now uses HexChemistryWorld, protocol52,
48: legacy snapshot20, HexWorldSnapshot2 and WorldSnapshotEnvelope1. The sixteen
49: first-four spells and ten pairs are implemented through paid input; current
50: verification and limits belong to docs/HEX-COURT-CHECKPOINT.md. This records
51: implementation, not performance, release or human acceptance of the milestone.
52: 
53: Lethal Fire/Steam pressure and Conflagration must emit the standard champion
54: knockout lifecycle event once, preserving scoring and respawn. Strongest pressure
55: wins; an equal Fire/Steam tie prefers Fire, equal Fire sources use stable source
56: ID (cast fallback), and equal Steam products use stable product ID. Training
57: targets use their own lifecycle. Snapshot actor validation admits their authored
58: zero movement ratio while retaining positive champion ratios and all bounds.
59: 
60: ### Unified ownership and migration schema
61: 
62: One world chemistry object owns cast records, pending reservations, source-to-cast
```

## `repository/.agent/OVERHAUL-IMPLEMENTATION.md` — L1–L12

```text
1: # FLUX active implementation queue
2: 
3: User pause instruction2026-09-20: stop after U6 for playtest;50% cutoff active, latest verified37% used. No credits redeemed.
4: 
5: Status: U6 whole-map chemistry correction COMPLETE at `p53-cb264f9358a4`. Local playtest candidate `p53-cb264f9358a4`: chemistry works on eligible ground throughout Wellspring, without a dummy. Final Full passed **152 suites /775,657 assertions**, zero failures/stderr, import, asset audit and120Hz configured boot. Protocol53 / legacy snapshot20 / HexWorldSnapshot3 / chemistry snapshot3 / world envelope1. Native review passed7 frames. Production localhost lifecycle: **FAILED**. This is not a release or120Hz capacity claim.
6: Next after user feedback: measured hotspots/event retention. Preserve S4/staged work, profiles, originals and P48 fallback.
7: One integration owner:root. Preserve selected Overnight P48 p48-111d911c27fa EXE/PCK/ZIP.
8: Historical four-delivery start: selected8file identity verified; main a1aa02807626823d0fbc1e25e75441ca3b7f4d36;
9: 922 pre-existing dirty entries; no game/engine processes. Old Full/timing receipts
10: are historical until rerun for changed source. Evidence:docs/evidence/four-delivery-a-20260913/.
11: Exact request, source-doc copies, git state and personal-profile backup retained;
12: evidence root excluded from Godot import before any backup scripts are added.
```

## `repository/src/sim/hex/hex_grid.gd` — L1–L55

```text
1: class_name HexGrid
2: extends RefCounted
3: 
4: @warning_ignore_start("integer_division")
5: 
6: 
7: # Pointy-top axial geometry in fixed world units (1000 units per pixel).
8: # HALF_HEIGHT is the integer rational approximation of 32000 / sin(60 deg),
9: # and ROW_PITCH is exactly 3 * HALF_HEIGHT / 2. These authored integers make
10: # shared faces coincide exactly; they are a simulation contract, not final art
11: # scale acceptance.
12: const HALF_WIDTH: int = 32_000
13: const HALF_HEIGHT: int = 36_950
14: const ROW_PITCH: int = 55_425
15: const COLUMN_PITCH: int = 64_000
16: const MAX_ABS_QUERY_COORDINATE: int = 8_000_000
17: const MAX_SWEEP_RADIUS: int = 512_000
18: const NAT_BASE: int = 1_000_000
19: 
20: const LOCAL_VERTICES: Array[Vector2i] = [
21: 	Vector2i(0, -36_950),
22: 	Vector2i(32_000, -18_475),
23: 	Vector2i(32_000, 18_475),
24: 	Vector2i(0, 36_950),
25: 	Vector2i(-32_000, 18_475),
26: 	Vector2i(-32_000, -18_475),
27: ]
28: 
29: const AXIAL_DIRECTIONS: Array[Vector2i] = [
30: 	Vector2i(-1, 0),
31: 	Vector2i(-1, 1),
32: 	Vector2i(0, -1),
33: 	Vector2i(0, 1),
34: 	Vector2i(1, -1),
35: 	Vector2i(1, 0),
36: ]
37: 
38: 
39: static func center(cell: Vector2i) -> Vector2i:
40: 	return Vector2i(
41: 		COLUMN_PITCH * cell.x + HALF_WIDTH * cell.y,
42: 		ROW_PITCH * cell.y,
43: 	)
44: 
45: 
46: static func vertices(cell: Vector2i) -> Array[Vector2i]:
47: 	var result: Array[Vector2i] = []
48: 	var cell_center := center(cell)
49: 	for local_vertex: Vector2i in LOCAL_VERTICES:
50: 		result.append(cell_center + local_vertex)
51: 	return result
52: 
53: 
54: static func world_to_cell(point: Vector2i) -> Vector2i:
55: 	# The inverse lattice transform supplies only a local seed. Membership is
```

## `repository/src/sim/hex/hex_chemistry_world.gd` — L10–L33

```text
10: const MAX_CASTS := 64
11: const MAX_PRODUCTS := 32
12: const MATTER_PER_CAST := 600
13: const WATER_TICKS := 720
14: const FIRE_TICKS := 480
15: const IGNITION_TICKS := 24
16: const COOLING_TICKS := 60
17: const STEAM_TICKS := 600
18: const MEDIUM_RADIUS := 64_000
19: const MEDIUM_FORMATION_TICKS := 24
20: const MEDIUM_ACTIVE_TICKS := 360
21: const MEDIUM_DECAY_TICKS := 60
22: const CONFLAGRATION_WIRE := 309
23: const STEAM_WIRE := 310
24: const FLOOD_WIRE := 316
25: const PULSE_TICKS := 30
26: const STEAM_HEIGHT := 48_000
27: const EXPOSURE_CAP := 240
28: const COVERAGE := {"rapid": 1, "bolt": 3, "spray": 5, "heavy": 7}
29: const WATER := 3
30: const FIRE := 2
31: 
32: var origin := Vector2i.ZERO
33: var cells: Dictionary = {}
```

## `repository/src/sim/hex/hex_chemistry_world.gd` — L95–L108

```text
95: func view(cell: Vector2i, tick: float) -> Dictionary:
96: 	var result := {"fire_phase": "none", "steam_heat": 1000}
97: 	if not cells.has(cell): return result
98: 	for material: String in material_layers():
99: 		var quantity := 0
100: 		var present := false
101: 		for region: Dictionary in render_regions(cell, material, tick):
102: 			present = true
103: 			quantity += int(region.quantity)
104: 			if material == "fire": result.fire_phase = region.phase
105: 			if material == "steam": result.steam_heat = maxi(int(result.steam_heat), int(region.intensity))
106: 		result[material + "_quantity"] = quantity
107: 		result[material + "_present"] = present
108: 	return result
```

## `repository/src/sim/hex/hex_chemistry_world.gd` — L248–L275

```text
248: func render_regions(cell: Vector2i, material: String, tick: float) -> Array[Dictionary]:
249: 	var result: Array[Dictionary] = []
250: 	if not cells.has(cell) or not cells[cell].has(material): return result
251: 	var is_product := material not in Policy.INGREDIENT_LAYERS.values()
252: 	for id: int in cells[cell][material]:
253: 		if is_product:
254: 			var product: Dictionary = products.get(id, {})
255: 			if product.is_empty() or tick >= int(product.expiry_tick): continue
256: 			var phase := "forming" if tick < int(product.active_tick) else "decaying" if tick >= int(product.decay_tick) else "active"
257: 			result.append({"footprint_id": id, "polygon": whole_cell_polygon(cell), "phase": phase,
258: 				"danger": phase == "active", "intensity": int(product.intensity), "quantity": int(product.cells[cell]),
259: 				"owner": int(product.owner), "source_ids": product.source_ids.duplicate(), "expiry_tick": int(product.expiry_tick),
260: 				"recipe_wire_id": int(product.recipe_wire_id), "direction": product.flow_aim, "material": material})
261: 		else:
262: 			var record: Dictionary = casts.get(id, {})
263: 			for part_id: int in record.get("ground_parts", {}):
264: 				var part: Dictionary = record.ground_parts[part_id]
265: 				if not part.coverage.has(cell) or tick >= int(part.expiry_tick): continue
266: 				var phase := "forming" if tick < int(part.created) + IGNITION_TICKS else "decaying" if tick >= int(part.expiry_tick) - COOLING_TICKS else "active"
267: 				if material == "fire": phase = "ignition" if phase == "forming" else "cooling" if phase == "decaying" else phase
268: 				result.append({"footprint_id": part_id, "polygon": whole_cell_polygon(cell), "phase": phase,
269: 					"danger": material == "fire" and phase == "active", "intensity": 1000, "quantity": int(part.cells[cell]),
270: 					"owner": int(record.owner), "source_ids": [int(record.source)], "expiry_tick": int(part.expiry_tick),
271: 					"recipe_wire_id": 0, "direction": record.aim, "material": material})
272: 	return result
273: 
274: 
275: func whole_cell_polygon(cell: Vector2i) -> PackedVector2Array:
```

## `repository/src/sim/hex/hex_chemistry_world.gd` — L314–L324

```text
314: 	metrics.deposited += 1
315: 	value_revision += 1
316: 	_try_ground_reactions(record, event.position, tick)
317: 
318: static func trail_lifetime(element: int) -> int:
319: 	if element < 1 or element >= ElementChemistrySystem.TRAIL_LIFE_MS.size(): return 0
320: 	return SimConfig.new(120).milliseconds_to_ticks(int(ElementChemistrySystem.TRAIL_LIFE_MS[element]))
321: 
322: static func ingredient_lifetime(element: int) -> int:
323: 	return WATER_TICKS if element == WATER else FIRE_TICKS if element == FIRE else ElementChemistrySystem.ELEMENT_LIFE_MS[element] * 120 / 1000
324: 
```

## `repository/src/sim/hex/hex_chemistry_world.gd` — L408–L428

```text
408: 		product.quantity += amount
409: 		product.source_ids.append(int(record.source))
410: 		var expanded: Array[Vector2i] = []
411: 		for cell: Vector2i in product.cells:
412: 			expanded.append(cell)
413: 		if heating:
414: 			product.heated = true
415: 			product.intensity = mini(1500, int(product.intensity) + consumed_strength * 50)
416: 			product.expiry_tick = tick + maxi(1, (int(product.expiry_tick) - tick) / 2)
417: 			product.expires = int(product.expiry_tick)
418: 			product.decay_tick = mini(int(product.decay_tick), maxi(int(product.active_tick), int(product.expiry_tick) - MEDIUM_DECAY_TICKS))
419: 		else:
420: 			product.cooled = true
421: 			# Literal policy: I' = I - min(floor(I/2), 50*S). Thus 750
422: 			# cooled by strength5 becomes500, while strength1 100 becomes50.
423: 			var cooling: int = mini(int(product.intensity) / 2, consumed_strength * 50)
424: 			product.intensity = maxi(0, int(product.intensity) - cooling)
425: 			# Cooling changes paid intensity; it cannot add whole neighboring hexes.
426: 		_retile_product(product, expanded)
427: 		metrics.modifiers += 1
428: 		value_revision += 1
```

## `repository/src/sim/hex/hex_chemistry_world.gd` — L520–L548

```text
520: 	var material := _product_material(recipe_wire_id)
521: 	var allocations := _equal_allocations(selected, quantity)
522: 	var oldest_aim := _oldest_source_aim(parent_sources)
523: 	var policy := Policy.definition(recipe_wire_id)
524: 	var first: Dictionary = casts[int(sources[int(parent_sources[0])])]
525: 	var active := tick + int(policy.formation_ticks)
526: 	var decay := active + int(policy.active_ticks)
527: 	var expiry := decay + int(policy.decay_ticks)
528: 	var selected_membership := {}
529: 	for cell: Vector2i in selected: selected_membership[cell] = 1
530: 	products[id] = {
531: 		"id": id,
532: 		"recipe_wire_id": recipe_wire_id,
533: 		"material": material,
534: 		"strength": matched_strength,
535: 		"source_ids": parent_sources.duplicate(),
536: 		"footprint": Policy.selection_shape(recipe_wire_id, point, oldest_aim),
537: 		"cells": allocations,
538: 		"coverage": selected_membership,
539: 		"quantity": quantity,
540: 		"created": tick,
541: 		"formation_tick": tick,
542: 		"active_tick": active,
543: 		"decay_tick": decay,
544: 		"expiry_tick": expiry,
545: 		"expires": expiry,
546: 		"intensity": mini(1500, matched_strength * 100),
547: 		"heated": false,
548: 		"cooled": false,
```

## `repository/src/sim/hex/hex_chemistry_world.gd` — L861–L934

```text
861: func _expose(actor: PlayerState, previous: Variant, tick: int, config: SimConfig, events: Array[Dictionary]) -> void:
862: 	var id := actor.entity_id
863: 	var old_exposure := int(exposure.get(id, 0))
864: 	if actor.health <= 0 or actor.spawn_protection_ticks > 0 or MovementSystem.is_combat_intangible(actor, config):
865: 		exposure[id] = maxi(0, old_exposure - 2)
866: 		return
867: 	var finish := Vector2i(actor.position_x, actor.position_y)
868: 	var start: Vector2i = previous if previous is Vector2i else previous.point
869: 	var previous_height := 0 if previous is Vector2i else int(previous.height)
870: 	# A landing tick uses only the grounded endpoint, never the airborne path.
871: 	if (previous_height > 0 and actor.air_height == 0) or (previous_height > STEAM_HEIGHT and actor.air_height <= STEAM_HEIGHT):
872: 		start = finish
873: 	var membership := occupied_cells()
874: 	var touched := HexFootprint.traversed_selected_cells(membership, origin, start, finish)
875: 	metrics.exposure_queries += 1
876: 	var steam_density := {}
877: 	var pressure_winner := {}
878: 	for cell: Vector2i in touched:
879: 		if not cells.has(cell):
880: 			continue
881: 		var record: Dictionary = cells[cell]
882: 		if actor.air_height == 0:
883: 			for cast_id: int in record.fire:
884: 				if not casts.has(cast_id): continue
885: 				var cast: Dictionary = casts[cast_id]
886: 				for part: Dictionary in cast.ground_parts.values():
887: 					if not part.coverage.has(cell) or tick < int(part.created) + IGNITION_TICKS or tick >= int(part.expiry_tick) - COOLING_TICKS: continue
888: 					# Damage rounds once from the finite part's mean density. Coverage
889: 					# cannot disappear because its integer allocation rounded to zero.
890: 					var fire_damage := maxi(1, 4000 * int(part.quantity) / (MATTER_PER_CAST * part.coverage.size()))
891: 					var source_id := int(cast.get("source", 0))
892: 					pressure_winner = _stronger_pressure_candidate(pressure_winner, {
893: 						"damage": fire_damage,
894: 						"kind": 0,
895: 						"stable_id": source_id if source_id > 0 else cast_id,
896: 						"owner_id": int(cast.get("owner", 0)),
897: 						"source_id": source_id,
898: 						"cast_id": cast_id,
899: 						"product_id": 0,
900: 					})
901: 		if actor.air_height <= STEAM_HEIGHT:
902: 			for product_id: int in record.steam:
903: 				if tick < int(products[product_id].active_tick) or tick >= int(products[product_id].decay_tick): continue
904: 				steam_density[product_id] = maxi(int(steam_density.get(product_id, 0)), maxi(1, int(record.steam[product_id])))
905: 	exposure[id] = mini(EXPOSURE_CAP, old_exposure + 1) if not steam_density.is_empty() else maxi(0, old_exposure - 2)
906: 	if tick % PULSE_TICKS != 0:
907: 		return
908: 	for product_id: int in steam_density:
909: 		var density: int = steam_density[product_id]
910: 		var ramp := 2000 + 6000 * int(exposure[id]) / EXPOSURE_CAP
911: 		var normal := mini(8000, ramp * density / 400)
912: 		var product: Dictionary = products[product_id]
913: 		var steam_damage := mini(12000, normal * int(product.intensity) / 1000)
914: 		pressure_winner = _stronger_pressure_candidate(pressure_winner, {
915: 			"damage": steam_damage,
916: 			"kind": 1,
917: 			"stable_id": product_id,
918: 			"owner_id": int(product.get("owner", product.get("owner_id", 0))),
919: 			"source_id": 0,
920: 			"cast_id": 0,
921: 			"product_id": product_id,
922: 		})
923: 	var pressure := int(pressure_winner.get("damage", 0))
924: 	if pressure > 0 and PlayerResourcesSystem.damage(actor, pressure, config):
925: 		var owner_id := int(pressure_winner.get("owner_id", 0))
926: 		events.append({
927: 			"type": "hex_pressure",
928: 			"entity_id": id,
929: 			"amount": pressure,
930: 			"exposure": int(exposure[id]),
931: 			"owner_id": owner_id,
932: 			"source_id": int(pressure_winner.get("source_id", 0)),
933: 			"cast_id": int(pressure_winner.get("cast_id", 0)),
934: 			"product_id": int(pressure_winner.get("product_id", 0)),
```

## `repository/src/presentation/hex_court_presenter.gd` — L323–L385

```text
323: 			prepared.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.footprint_id) < int(b.footprint_id))
324: 			material_regions[cell] = prepared
325: 	return result
326: 
327: 
328: func _prepare_region(value: Variant, material: String, expected_polygon: PackedVector2Array = PackedVector2Array()) -> Dictionary:
329: 	if not value is Dictionary:
330: 		return {}
331: 	var source: Dictionary = value
332: 	var phase := String(source.get("phase", ""))
333: 	var has_owner := source.has("owner_key") or source.has("owner") or source.has("owner_id") or source.has("source_ids")
334: 	var has_expiry := source.has("expiry_tick") or source.has("expires")
335: 	if phase.is_empty() or not source.has("footprint_id") or not source.has("danger") or not source.has("intensity") or not has_owner or not has_expiry:
336: 		return {}
337: 	var descriptor := _material_descriptor(material)
338: 	var direction_value: Variant = source.get("direction", Vector2i(0, -1000))
339: 	var source_ids_value: Variant = source.get("source_ids", [])
340: 	if (
341: 		descriptor.is_empty()
342: 		or (source.has("recipe_wire_id") and int(source.recipe_wire_id) != int(descriptor.wire_id))
343: 		or not direction_value is Vector2i
344: 		or not source_ids_value is Array
345: 		or (source.has("material") and String(source.material) != material)
346: 	):
347: 		return {}
348: 	var raw_polygon: Variant = source.get("polygon")
349: 	if not raw_polygon is PackedVector2Array:
350: 		return {}
351: 	var fixed_polygon: PackedVector2Array = raw_polygon
352: 	# Court storage cells are the coverage contract. A region is one complete
353: 	# authored cell polygon; presentation must not resurrect analytic disk/sector
354: 	# clipping or invent a fallback for malformed authority data.
355: 	if fixed_polygon.size() != 6:
356: 		return {}
357: 	var result := {
358: 		"footprint_id": int(source.footprint_id), "fixed_polygon": fixed_polygon,
359: 		"polygon": PackedVector2Array(), "phase": phase, "danger": bool(source.danger),
360: 		"intensity": maxi(1, int(source.intensity)), "material": material,
361: 		"owner_key": source.get("owner_key", source.get("owner", source.get("owner_id", source.get("source_ids", [])))),
362: 		"owner": int(source.get("owner", source.get("owner_id", 0))),
363: 		"source_ids": (source_ids_value as Array).duplicate(),
364: 		"quantity": maxi(0, int(source.get("quantity", 0))),
365: 		"expiry_tick": int(source.get("expiry_tick", source.get("expires", 0))),
366: 		"recipe_wire_id": int(source.get("recipe_wire_id", 0)),
367: 		"direction": direction_value,
368: 	}
369: 	var polygon := PackedVector2Array()
370: 	for fixed_point: Vector2 in fixed_polygon:
371: 		var point := fixed_point / 1000.0 # Court returns absolute world-fixed cell vertices.
372: 		if not point.is_finite():
373: 			return {}
374: 		polygon.append(point)
375: 	if expected_polygon.size() == 6 and not _same_polygon_vertices(polygon, expected_polygon):
376: 		return {}
377: 	result.polygon = polygon
378: 	return result
379: 
380: 
381: static func _same_polygon_vertices(first: PackedVector2Array, second: PackedVector2Array) -> bool:
382: 	if first.size() != second.size():
383: 		return false
384: 	var remaining: Array[Vector2] = []
385: 	for point: Vector2 in second:
```

## `repository/src/presentation/hex_court_presenter.gd` — L442–L479

```text
442: func _draw_water(canvas: CanvasItem, _views: Dictionary, regions_by_cell: Dictionary, tick: float, reduced: bool) -> void:
443: 	var edge_counts := _region_edge_counts(regions_by_cell)
444: 	for cell: Vector2i in regions_by_cell:
445: 		for region: Dictionary in regions_by_cell[cell]:
446: 			var style := _water_region_style(region, reduced)
447: 			canvas.draw_colored_polygon(region.polygon, Color(style.base, style.fill_opacity))
448: 			_draw_region_outline(canvas, region, edge_counts, Color(style.edge, style.edge_opacity), style.edge_width)
449: 			var seed := _cell_seed(cell, int(region.footprint_id) * 401)
450: 			_draw_water_region_mark(canvas, region.polygon, style.bright, style.phase, tick, seed, reduced)
451: 
452: 
453: func _draw_fire(canvas: CanvasItem, _views: Dictionary, regions_by_cell: Dictionary, tick: float, reduced: bool) -> void:
454: 	var edge_counts := _region_edge_counts(regions_by_cell)
455: 	for cell: Vector2i in regions_by_cell:
456: 		for region: Dictionary in regions_by_cell[cell]:
457: 			var style := _fire_region_style(region, reduced)
458: 			canvas.draw_colored_polygon(region.polygon, Color(style.base, style.fill_opacity))
459: 			_draw_region_outline(canvas, region, edge_counts, Color(style.edge, style.edge_opacity), style.edge_width)
460: 			var seed := _cell_seed(cell, int(region.footprint_id) * 809)
461: 			_draw_fire_region_mark(canvas, region.polygon, style.phase, style.dark, style.base, style.bright, style.danger_color, tick, seed, reduced)
462: 
463: 
464: func _draw_steam(canvas: CanvasItem, views: Dictionary, regions_by_cell: Dictionary, tick: float, reduced: bool) -> void:
465: 	var edge_counts := _region_edge_counts(regions_by_cell)
466: 	for cell: Vector2i in regions_by_cell:
467: 		var heat := int((views.get(cell, {}) as Dictionary).get("steam_heat", 1000))
468: 		for region: Dictionary in regions_by_cell[cell]:
469: 			var style := _steam_region_style(region, heat, reduced)
470: 			canvas.draw_colored_polygon(region.polygon, Color(style.base, style.fill_opacity))
471: 			_draw_region_outline(canvas, region, edge_counts, Color(style.dark, style.edge_opacity), style.edge_width)
472: 			if bool(style.danger):
473: 				_draw_region_outline(canvas, region, edge_counts, Color(style.danger_color, style.danger_opacity), 1.0)
474: 			var seed := _cell_seed(cell, int(region.footprint_id) * 1201 + heat)
475: 			_draw_steam_region_mark(canvas, region.polygon, style.dark, style.bright, style.danger_color, style.palette_phase, tick, seed, reduced, bool(style.danger))
476: 
477: 
478: func _draw_shared_material(canvas: CanvasItem, regions_by_cell: Dictionary, material: String, tick: float, reduced: bool) -> void:
479: 	if regions_by_cell.is_empty():
```

## `repository/src/presentation/hex_court_presenter.gd` — L702–L799

```text
702: func _water_region_style(region: Dictionary, reduced: bool) -> Dictionary:
703: 	var phase := String(region.get("phase", "active"))
704: 	var danger := bool(region.get("danger", false))
705: 	var intensity := _intensity_ratio(region)
706: 	var dark := _language.element_phase_color("water", phase, "dark")
707: 	return {
708: 		"phase": phase, "danger": danger,
709: 		"dark": dark, "base": _language.element_phase_color("water", phase, "base"),
710: 		"bright": _language.element_phase_color("water", phase, "bright"),
711: 		"edge": _language.element_phase_color("water", phase, "danger") if danger else dark,
712: 		"fill_opacity": (0.50 if reduced else 0.60) * intensity,
713: 		"edge_opacity": 0.84, "edge_width": 2.0,
714: 		"motion": not reduced, "mark_count": 1,
715: 	}
716: 
717: 
718: func _fire_region_style(region: Dictionary, reduced: bool) -> Dictionary:
719: 	var phase := String(region.get("phase", "active"))
720: 	var danger := bool(region.get("danger", false))
721: 	var intensity := _intensity_ratio(region)
722: 	var dark := _language.element_phase_color("fire", phase, "dark")
723: 	var danger_color := _language.element_phase_color("fire", phase, "danger")
724: 	return {
725: 		"phase": phase, "danger": danger,
726: 		"dark": dark, "base": _language.element_phase_color("fire", phase, "base"),
727: 		"bright": _language.element_phase_color("fire", phase, "bright"),
728: 		"danger_color": danger_color, "edge": danger_color if danger else dark,
729: 		"fill_opacity": (0.10 if phase != "active" else 0.18) * intensity,
730: 		"edge_opacity": 0.90 if danger else 0.76, "edge_width": 2.5,
731: 		"motion": not reduced, "mark_count": 1,
732: 	}
733: 
734: 
735: func _steam_region_style(region: Dictionary, heat: int, reduced: bool) -> Dictionary:
736: 	var phase := String(region.get("phase", "active"))
737: 	var palette_phase := phase
738: 	if phase == "active":
739: 		palette_phase = "hot" if heat > 1000 else "cool" if heat < 1000 else "active"
740: 	var danger := bool(region.get("danger", false))
741: 	var intensity := _intensity_ratio(region)
742: 	return {
743: 		"phase": phase, "palette_phase": palette_phase, "danger": danger,
744: 		"dark": _language.reaction_phase_color("steam", palette_phase, "dark"),
745: 		"base": _language.reaction_phase_color("steam", palette_phase, "base"),
746: 		"bright": _language.reaction_phase_color("steam", palette_phase, "bright"),
747: 		"danger_color": _language.reaction_phase_color("steam", palette_phase, "danger"),
748: 		"fill_opacity": (0.16 if reduced else 0.20) + 0.04 * intensity,
749: 		"edge_opacity": 0.72, "edge_width": 3.0,
750: 		"danger_opacity": 0.70 if reduced else 0.78,
751: 		"motion": not reduced, "mark_count": 2,
752: 	}
753: 
754: 
755: func _region_edge_counts(regions_by_cell: Dictionary) -> Dictionary:
756: 	var counts: Dictionary = {}
757: 	for cell: Vector2i in regions_by_cell:
758: 		for region: Dictionary in regions_by_cell[cell]:
759: 			var fixed_polygon: PackedVector2Array = region.fixed_polygon
760: 			for index: int in fixed_polygon.size():
761: 				var key := _region_edge_key(region, fixed_polygon[index], fixed_polygon[(index + 1) % fixed_polygon.size()])
762: 				counts[key] = int(counts.get(key, 0)) + 1
763: 	return counts
764: 
765: 
766: func _region_edge_key(region: Dictionary, first: Vector2, second: Vector2) -> String:
767: 	var a := "%d,%d" % [roundi(first.x), roundi(first.y)]
768: 	var b := "%d,%d" % [roundi(second.x), roundi(second.y)]
769: 	var segment := a + ":" + b if a < b else b + ":" + a
770: 	var owner_key := JSON.stringify(region.get("owner_key", null))
771: 	if String(region.material) not in LEGACY_HEX_MATERIALS:
772: 		# Unified fields cohere across adjacent records from the same owner and
773: 		# phase. Record lifetime and intensity alter the fill without inventing an
774: 		# internal wall; ownership, phase and danger remain visible boundaries.
775: 		return "%s/%s/%s/%s/%s" % [String(region.material), String(region.phase), str(bool(region.danger)), owner_key, segment]
776: 	return "%s/%d/%s/%s/%d/%d/%s/%s" % [String(region.material), int(region.footprint_id), String(region.phase), str(bool(region.danger)), int(region.intensity), int(region.get("expiry_tick", 0)), owner_key, segment]
777: 
778: 
779: func _draw_region_outline(canvas: CanvasItem, region: Dictionary, edge_counts: Dictionary, color: Color, width: float) -> void:
780: 	var polygon: PackedVector2Array = region.polygon
781: 	var fixed_polygon: PackedVector2Array = region.fixed_polygon
782: 	var center := _polygon_centroid(polygon)
783: 	for index: int in polygon.size():
784: 		var key := _region_edge_key(region, fixed_polygon[index], fixed_polygon[(index + 1) % fixed_polygon.size()])
785: 		if int(edge_counts.get(key, 0)) > 1:
786: 			continue
787: 		# Draw the cell boundary inward so hazard ink remains inside the complete
788: 		# authoritative selected hex, including in reduced-effects mode.
789: 		for triangle: PackedVector2Array in _inward_edge_triangles(polygon, index, width, center):
790: 			canvas.draw_primitive(triangle, PackedColorArray([color]), PackedVector2Array())
791: 
792: 
793: static func _inward_edge_triangles(polygon: PackedVector2Array, edge_index: int, width: float, centroid: Vector2 = Vector2.INF) -> Array[PackedVector2Array]:
794: 	var result: Array[PackedVector2Array] = []
795: 	var strip := _inward_edge_strip(polygon, edge_index, width, centroid)
796: 	if strip.size() != 4: return result
797: 	for indices: Vector3i in [Vector3i(0, 1, 2), Vector3i(0, 2, 3)]:
798: 		var a := strip[indices.x]
799: 		var b := strip[indices.y]
```

## `repository/src/presentation/hex_court_presenter.gd` — L1106–L1139

```text
1106: static func projectile_strength_pair(shot: ProjectileState) -> Vector2i:
1107: 	if shot == null:
1108: 		return Vector2i.ZERO
1109: 	if shot.initial_strength > 0:
1110: 		return Vector2i(shot.initial_strength, clampi(shot.remaining_strength, 0, shot.initial_strength))
1111: 	var legacy := maxi(1, shot.reaction_strength)
1112: 	return Vector2i(legacy, legacy)
1113: 
1114: 
1115: static func strength_scaled_size(authored_size: float, remaining_strength: int, initial_strength: int, readable_floor: float = PROJECTILE_READABLE_FLOOR) -> float:
1116: 	if not is_finite(authored_size) or authored_size <= 0.0 or initial_strength <= 0 or remaining_strength <= 0:
1117: 		return 0.0
1118: 	var ratio := clampf(float(remaining_strength) / float(initial_strength), 0.0, 1.0)
1119: 	var minimum_size := clampf(readable_floor, 0.0, minf(PROJECTILE_READABLE_FLOOR, authored_size))
1120: 	return maxf(minimum_size, authored_size * sqrt(ratio))
1121: 
1122: 
1123: static func projectile_cache_identity(shot: ProjectileState) -> String:
1124: 	if shot == null:
1125: 		return ""
1126: 	var strength := projectile_strength_pair(shot)
1127: 	return "%d/%d/%d/%d/%d/%d/%d" % [
1128: 		shot.owner_id, shot.team_id, shot.source_cast_id, shot.source_wire_id,
1129: 		shot.element_wire_id, strength.x, shot.radius,
1130: 	]
1131: 
1132: 
1133: static func cache_projectile_size(cache: Dictionary, entity_id: int, identity: String, lifetime_ticks: int, tick: float, target_size: float, reduced: bool) -> float:
1134: 	if entity_id <= 0 or identity.is_empty() or lifetime_ticks <= 0 or not is_finite(tick) or not is_finite(target_size) or target_size < 0.0:
1135: 		return 0.0
1136: 	var entry: Dictionary = cache.get(entity_id, {})
1137: 	var reused := entry.is_empty() or String(entry.get("identity", "")) != identity or lifetime_ticks > int(entry.get("last_lifetime_ticks", lifetime_ticks))
1138: 	if reused:
1139: 		entry = {
```

## `repository/src/presentation/wireframe_body_presenter.gd` — L5–L24

```text
5: const DEFAULT_PATH := "res://assets/sprites/wireframe_motion_v2/manifest.json"
6: const CELL := Vector2(96, 96)
7: const PIVOT := Vector2(48, 84)
8: const BODY_TYPES: Array[String] = ["small", "middle", "large"]
9: const BODY_HEIGHTS := {"small": 58, "middle": 68, "large": 76}
10: const DISPLAY_HEIGHTS := {"small": 58, "middle": 63, "large": 68}
11: const PRESENTATION_SCALES := {"small": 1.0, "middle": 63.0 / 68.0, "large": 68.0 / 76.0}
12: const SCALE_POLICY := "per_size_baked_about_feet_pivot"
13: const STYLE_ID := "warm_adventurer_foundation_v1"
14: const MOTION_REVISION := "slide_v1"
15: const BASE_ROWS: Array[String] = ["grounded", "jump", "cast", "hit", "walk", "sprint", "slide", "roll", "walk_b", "sprint_b"]
16: const PHASE_COUNT := 8
17: const MATRIX_COLUMNS := 16
18: const MATRIX_DIMENSIONS := Vector2(1536, 3072)
19: const BASE_DIMENSIONS := Vector2(768, 960)
20: 
21: var last_error := ""
22: var content_hash := ""
23: var base_textures: Dictionary[String, Texture2D] = {}
24: var locomotion_textures: Dictionary[String, Texture2D] = {}
```

## `repository/src/net/hex_world_snapshot.gd` — L73–L85

```text
73: static func capture(world: SimWorld) -> Dictionary:
74: 	if not _trusted_world_valid(world):
75: 		return {}
76: 	# The complete outer prepare() below validates this deterministic chemistry
77: 	# encoding in trusted topology, so do not pay for the nested chemistry-only
78: 	# reconstruction here. Incoming paths still use the public strict validators.
79: 	var detached := ChemistrySnapshot._capture_for_outer_roundtrip(world.hex_court)
80: 	if detached.is_empty():
81: 		return {}
82: 	var packed_hex := WirePacking.pack(detached, world.hex_court.cells.size())
83: 	if packed_hex.is_empty():
84: 		return {}
85: 
```

## `repository/src/net/hex_world_snapshot.gd` — L532–L542

```text
532: 		var cast: Dictionary = world.hex_court.casts.get(int(world.hex_court.pending[owner]), {})
533: 		if cast.is_empty() or not bool(cast.paid) or state.pending_cast_wire_id != int(cast.wire):
534: 			return false
535: 	for owner: int in champions:
536: 		var state: PlayerState = champions[owner]
537: 		if (state.pending_cast_wire_id > 0) != world.hex_court.pending.has(owner):
538: 			return false
539: 	for actor_id: int in world.hex_court.exposure:
540: 		if not actors.has(actor_id):
541: 			return false
542: 	for key: String in world.hex_court.flow_carry:
```

## `repository/src/sim/hex/hex_recipe_policy.gd` — current Water/Fire override L275–L284

```text
275: static func _apply_current_water_fire(result: Dictionary) -> void:
276: 	result.selection_kind = Footprint.KIND_DISK
277: 	result.formation_ticks = 24
278: 	result.active_ticks = 360
279: 	result.decay_ticks = 60
280: 	result.radius = 64_000
281: 	result.length = 0
282: 	result.quantity_policy = "matched_source_quantity"
283: 
284: 
```
