# Exact source excerpts

These are packet excerpts, not edited game files. Line numbers refer to the source snapshot.

## 01-SHARED-CONTRACT.md

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

## 07-CHAT-ANIMATION.md

```text
1: # ChatGPT: shared body animation review
2: Start after visual direction is selected; source-sheet critique can run earlier. Review/design only.
3: 
4: Inspect FLUX-SOURCE-PACKET.zip, shared contract and manifest. Read repository/src/presentation/wireframe_body_presenter.gd, eight_direction_resolver.gd, repository/assets/sprites/wireframe_motion_v2/manifest.json and the nine active body PNGs. Use the historical native-before-after board only as labeled historical evidence. Style reference images do not prove current runtime animation quality.
5: 
6: Goal: stable, charming, unambiguous movement/aim animations reusable across the three sizes before individual skins.
7: Keep 58/63/68 px display heights, 17/18/19 px hurtboxes, 18 px common wall clearance and unchanged stats. Preserve the 96x96 cells and feet pivot (48,84) unless a separate reviewed migration is proposed. Directions use the resolver/manifest order and coordinate convention, not a guessed compass index.
8: The existing walk/sprint pipeline already supports 8 travel x 8 aim directions x 8 phases. Improve it; do not commission 30 unrelated full character sheets.
9: 
10: Pilot five cases: forward walk with alternating planted feet; true diagonal slide; backward movement while aiming forward; strafing while casting; airborne-to-landing transition. Review Small first, then how the same rig transfers to Middle/Large.
11: Upper body aims toward cursor; gait communicates actual travel. Foot trajectories, torso rotation and blend rules must look plausible for backpedal/strafe. Keep silhouette scale stable across stand/walk/sprint/jump/float/slide/roll/airdodge/wallrun/cast. Identify unsupported transitions without falsely claiming all can be judged from current still sheets.
12: 
13: Return FLUX-ANIMATION-v1.zip containing ANIMATION_REVIEW.md, POSE_TIMING_SPEC.json, COVERAGE_MATRIX.md, actual annotated/pilot images if produced, HANDOFF.md and manifest.json. Mark source-visible, inferred, missing, proposed and human-only separately. No game code edits, massive skin batch or baked spell/environment elements. Supply raster originals and manifests for any produced sprites; do not claim automatic skeleton-sheet compliance from image generation.
14: 
```

## 11-AUDIT-SNAPSHOT.md

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

## repository/SPECIFICATION.md

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
```

```text
649: Cursor-facing amendment: every character body pose follows current cursor or
650: controller aim immediately at the existing eight-direction sprite resolution.
651: Movement-facing stays independent; grounded neutral roll retains its documented
652: facing fallback, while neutral airborne Evade requests vertical fast-fall;
653: backward/strafe cadence derives from aim versus travel. Committed shots retain
654: their recorded start aim; visual turning must never silently retarget them.
655: All voluntary movement modes permit paid casting; one occupied spell startup,
656: forced control, own cooldown, capacity and positive Flux remain explicit gates.
657: Menus/death/spectating do not grant gameplay input or free casts.
658: 
659: The active shared body is a compact fantasy adventurer rasterized over the editable
660: rig (`slide_v1`, retaining proportion_v4 anatomy): about4.14/4.20/4.25 heads tall,
661: visible standing south heights58/63/68px. The bounded slide refinement reclines
662: and rolls the fixed torso with one long and one tucked grounded leg so South
663: reads seated. Only the24 slide base cells change; wallrun shares that silhouette.
664: North/NE detail and real wall-contact transitions remain human-review limits.
665: This does not complete the slide travel/aim and entry/hold/brake/exit banks.
666: Source authoring envelopes remain58/68/76px; per-size baked scales are1,63/68,68/76,
667: constant across every pose. All30 playable identities use the matching size in gameplay
668: and selection; old race skins stay on disk as historical assets, never silent
669: fallbacks. Fixed bones and inverse-kinematic contacts support 64 travel/aim pairs
670: with eight distance-driven stride phases per size. Upper body follows aim;
671: opposed travel uses backpedal/strafe rather than a 180-degree waist twist.
672: Hurtbox radius comes exclusively from Small / Middle / Large (17/18/19px),
673: never race, skin, frame, aim or travel direction. All use 18px wall clearance.
674: Stamina maxima are620/660/700, with prior recovery rates retained. Health, Flux,
675: speed, movement timing and ability budgets remain profile-driven and unchanged
676: by this proportion pass. Visual playback does not alter authority;
677: complete human animation acceptance still gates later detailed character skins.
678: 
679: ## Authority and scope
680: 
681: This file owns current scope. Validated content and simulation own exact executable
682: rules; discrepancies are defects, not permission to invent behavior. README is
683: the player entry, .agent/OVERHAUL-IMPLEMENTATION.md is the only task queue, and
684: docs/CURRENT-CAST.md is the roster. Historical checkpoints prove only their named
685: build. Reference artwork supplies style, never gameplay data.
```

## repository/.agent/OVERHAUL-IMPLEMENTATION.md

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
```

```text
36: | Shared template review | Small first, then Middle/Large; fix front-facing slide silhouette with fixed bones and scale | COMPLETE bounded slide candidate p50-9011a3cfa6dc: pass2 retained after independent source/native review; 24 changed cells, 3288 unchanged non-slide poses, six pixel-identical gait pages. Fresh Full-v3:109 suites/707626 assertions,zero failures/stderr,import+120Hzboot.144 frames each before/pass1/pass2: controlled action/gait boards plus actual paid slides. Two 180-second Full timeouts remain failed receipts; reviewed/tested Full-only300-second watchdog used for final gate. Preserved58/63/68px,17/18/19px hurt,18px clearance,620/660/700 Stamina and all gameplay. Human slide review pending; North/NE overlap, aim-only slide bank, real wall-contact/airborne/landing/cast transitions remain open. Layer package preparation only. Next: user feedback and next bounded template defect; no mass named skins or B2 expansion before template acceptance. Evidence:docs/evidence/template-motion-20260915/; handoff:docs/PROPORTION-CAST-CHECKPOINT.md. |
37: | User visual/roster amendment | Compact4â€“4.5-head shared anatomy;58/63/68px;620/660/700 Stamina;17/18/19px hurtboxes/common18px wall clearance; H. Lenee/Mifu names, Mifu Air, Sai Laas Small Air2/Fire1, retire unnamed Angel | PAUSED verified local source p50-53a535028e4f: Full v3 109 suites/707626 assertions,zero failures/stderr,import+120Hzboot;32 rendered frames;3312-cell bake.30 playable/30 identities,10 per size. No individual skin rollout, combat expansion,export or pointer promotion. Evidence:docs/PROPORTION-CAST-CHECKPOINT.md and docs/evidence/proportions-v4-20260914/. Next: human proportion/direction/size-feel review; continuation brief .agent/PROPORTION-CAST-CONTINUE.md. |
```

```text
138: | B0 discard diagnostics | Complete separate frame-clamp/catch-up counters; no performance pass inferred |
139: | C1/C2 delivery/build identity | Complete source-derived README, full production SHA identity, P48 recovery, reconnect/LAN checks, PCK identity and new portable; no publication |
140: | C3 test preference/import isolation | Complete guarded Full isolated boot-write proof; 117 canonical class paths checked after import. Earlier personal-settings incident remains disclosed |
141: | D route/readability | Complete labels plus feedback/LAN/court layout collision fixes; 52 final interface captures, bounded independent visual review pass. Human route learning pending |
142: | E shared body refinement | Walk-frame landing shortcut rejected after actual art review; original rigs preserved. Dedicated planted pose and animation/human review remain |
143: | W4 performance | FAILED: final real-map p95 16.658/16.934ms versus8.333ms; 494/471 of720 ticks over budget.47,398 exact checks pass. No optimization retained; strict-order fast-path remains unimplemented proposal |
144: | Final delivery | COMPLETE: Full102/691,883 zero failures/stderr;221 paid-gameplay +52 interfaces;3,122 unchanged frozen inputs; new portable/PCK/raw boot; exact-export localhost lifecycle passed. New and fallback payload/evidence identities verified |
145: 
146: Evidence: docs/evidence/overnight-20260913/ and docs/evidence/windows-overnight-p48-20260913/.
147: Final Full is final/full-v3.json; interface evidence is v4. Full v1 failed because
148: owned .gd evidence backups shadowed three canonical classes during import; v2
149: stopped on a missing draft document Status line. Both are retained. Evidence
150: .gdignore plus the exact class-cache guard corrected the import problem. Do not
151: use the superseded v3 images as canonical loaded-controls proof.
152: 
153: Run incident: an early root frame harness saved defaults over the personal FLUX
154: profile at00:16:02UTC. No proven pre-run backup found; no speculative restoration.
155: Harness and test-runner isolation are fixed; final Full/captures preserve the
156: observed real-profile hash. User must check settings. See integration/preferences-incident.md.
157: 
158: Next three evidence-backed slices, only on continuation:
159: 1. Matched chemistry strict-order fast-path experiment with exact order/state
160:    oracles and prospective performance gates; retain only a demonstrated win.
161: 2. Physical controller and same-ZIP two-PC discovery/input/lifecycle acceptance.
162: 3. One planted landing/compression pose in shared size rigs, with actual sequence
163:    review before character-skin expansion.
```

## repository/src/presentation/wireframe_body_presenter.gd

```text
1: class_name WireframeBodyPresenter
2: extends RefCounted
3: 
4: 
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
25: var sprint_textures: Dictionary[String, Texture2D] = {}
26: 
27: 
28: func clear() -> void:
29: 	base_textures.clear()
30: 	locomotion_textures.clear()
31: 	sprint_textures.clear()
32: 	content_hash = ""
33: 
34: 
35: func configure(path: String = DEFAULT_PATH) -> bool:
36: 	clear()
37: 	last_error = ""
38: 	if not FileAccess.file_exists(path):
39: 		return _fail("Wireframe body manifest is missing: " + path)
40: 	var source := FileAccess.get_file_as_string(path)
41: 	var parsed: Variant = JSON.parse_string(source)
42: 	if not parsed is Dictionary:
43: 		return _fail("Wireframe body manifest must be an object")
44: 	var data: Dictionary = parsed
45: 	if String(data.get("style_id", "")) != STYLE_ID or String(data.get("presentation_scale_policy", "")) != SCALE_POLICY \
46: 		or data.has("presentation_scale"):
47: 		return _fail("Adventurer style or per-size presentation scale policy changed")
48: 	if String(data.get("motion_revision", "")) != MOTION_REVISION:
49: 		return _fail("Adventurer motion revision changed")
50: 	var layout: Variant = data.get("locomotion")
51: 	if int(data.get("schema_version", -1)) != 2 or not _matches_dimensions(data.get("cell"), Vector2i(96, 96)) \
52: 		or not _matches_dimensions(data.get("pivot"), Vector2i(48, 84)) or data.get("directions") != EightDirectionResolver.DIRECTION_ORDER \
53: 		or data.get("base_rows") != BASE_ROWS or not layout is Dictionary:
54: 		return _fail("Wireframe body cell, pivot or direction contract changed")
55: 	if layout.get("columns") != 16 or layout.get("rows") != 32 or layout.get("phases") != 8 \
56: 		or layout.get("index_formula") != "((travel*8+aim)*8+phase)":
57: 		return _fail("Wireframe locomotion matrix contract changed")
58: 	var sizes: Variant = data.get("sizes")
59: 	if not sizes is Dictionary or sizes.size() != BODY_TYPES.size():
60: 		return _fail("Wireframe bodies require exactly three shared size templates")
61: 	for body_type: String in BODY_TYPES:
62: 		if not sizes.get(body_type) is Dictionary:
63: 			return _fail("Wireframe body size is missing: " + body_type)
64: 		var definition: Dictionary = sizes[body_type]
65: 		if int(definition.get("reference_height", -1)) != int(BODY_HEIGHTS[body_type]):
66: 			return _fail("Wireframe reference height changed: " + body_type)
67: 		if int(definition.get("display_height", -1)) != int(DISPLAY_HEIGHTS[body_type]):
68: 			return _fail("Adventurer baked display height changed: " + body_type)
69: 		var baked_scale: Variant = definition.get("presentation_scale")
70: 		if typeof(baked_scale) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(baked_scale)) \
71: 			or not is_equal_approx(float(baked_scale), float(PRESENTATION_SCALES[body_type])):
72: 			return _fail("Adventurer baked presentation scale changed: " + body_type)
73: 		var base := _load_verified(definition, "base", BASE_DIMENSIONS, body_type)
74: 		if base == null:
75: 			return _fail(last_error)
76: 		var locomotion := _load_verified(definition, "locomotion", MATRIX_DIMENSIONS, body_type)
77: 		if locomotion == null:
78: 			return _fail(last_error)
79: 		var sprint := _load_verified(definition, "sprint", MATRIX_DIMENSIONS, body_type)
80: 		if sprint == null:
81: 			return _fail(last_error)
82: 		base_textures[body_type] = base
83: 		locomotion_textures[body_type] = locomotion
84: 		sprint_textures[body_type] = sprint
85: 	content_hash = source.sha256_text()
86: 	return true
87: 
88: 
89: func ready() -> bool:
90: 	return not content_hash.is_empty() and base_textures.size() == 3 and locomotion_textures.size() == 3 and sprint_textures.size() == 3
91: 
92: 
93: func base_texture(body_type: String) -> Texture2D:
94: 	return base_textures.get(body_type) if ready() else null
95: 
96: 
97: static func base_region(animation_state: String, aim_index: int) -> Rect2:
98: 	var row := BASE_ROWS.find(animation_state)
99: 	if row < 0 or aim_index < 0 or aim_index >= 8:
100: 		return Rect2()
101: 	return Rect2(Vector2(aim_index * 96, row * 96), CELL)
102: 
103: 
104: static func locomotion_region(travel_index: int, aim_index: int, phase_index: int) -> Rect2:
105: 	if travel_index < 0 or travel_index >= 8 or aim_index < 0 or aim_index >= 8 or phase_index < 0 or phase_index >= PHASE_COUNT:
106: 		return Rect2()
107: 	var index := ((travel_index * 8 + aim_index) * PHASE_COUNT + phase_index)
108: 	return Rect2(Vector2((index % MATRIX_COLUMNS) * 96, floori(float(index) / MATRIX_COLUMNS) * 96), CELL)
109: 
110: 
111: func frame(body_type: String, animation_state: String, aim: Vector2i, travel: Vector2i, normalized_phase: float) -> Dictionary:
112: 	if not ready() or not base_textures.has(body_type):
113: 		return {}
114: 	var aim_index := EightDirectionResolver.classify_index(aim.x, aim.y)
115: 	var region := base_region(animation_state, aim_index)
116: 	if not region.has_area():
117: 		return {}
118: 	var texture: Texture2D = base_textures[body_type]
119: 	var travel_index := EightDirectionResolver.classify_index(travel.x, travel.y, aim_index)
120: 	var phase_index := 0
121: 	if animation_state.trim_suffix("_b") in ["walk", "sprint"] and travel != Vector2i.ZERO:
122: 		if not is_finite(normalized_phase):
123: 			return {}
124: 		phase_index = mini(PHASE_COUNT - 1, floori(fposmod(normalized_phase, 1.0) * PHASE_COUNT))
125: 		region = locomotion_region(travel_index, aim_index, phase_index)
126: 		texture = locomotion_textures[body_type]
127: 		if animation_state.trim_suffix("_b") == "sprint":
128: 			texture = sprint_textures[body_type]
129: 	return {"texture": texture, "source_region": region, "gait_frame": phase_index,
130: 		"aim_index": aim_index, "travel_index": travel_index, "wireframe_body": true,
131: 		"style_id": STYLE_ID, "motion_revision": MOTION_REVISION, "baked_presentation_scale": PRESENTATION_SCALES[body_type], "display_height": DISPLAY_HEIGHTS[body_type],
132: 		"gait_bank": "sprint" if texture == sprint_textures[body_type] else ("walk" if texture == locomotion_textures[body_type] else "base")}
133: 
134: 
135: func _load_verified(definition: Dictionary, key: String, dimensions: Vector2, body_type: String) -> Texture2D:
136: 	var path := String(definition.get(key, ""))
137: 	var source_hash := String(definition.get(key + "_sha256", ""))
138: 	var rgba_hash := String(definition.get(key + "_rgba_sha256", ""))
139: 	if path != "res://assets/sprites/wireframe_motion_v2/%s-%s.png" % [body_type, key] \
140: 		or not _matches_dimensions(definition.get(key + "_dimensions"), Vector2i(dimensions)) \
141: 		or source_hash.length() != 64 or rgba_hash.length() != 64 or not ResourceLoader.exists(path):
142: 		last_error = "Wireframe texture contract is invalid: " + key
143: 		return null
144: 	if OS.has_feature("editor") and FileAccess.file_exists(path) and FileAccess.get_sha256(path) != source_hash:
145: 		last_error = "Wireframe source texture hash changed: " + path
146: 		return null
147: 	var texture := load(path) as Texture2D
148: 	if texture == null or texture.get_size() != dimensions:
149: 		last_error = "Wireframe texture dimensions changed: " + path
150: 		return null
151: 	var pixels := texture.get_image()
152: 	if pixels == null or pixels.is_empty() or pixels.has_mipmaps():
153: 		last_error = "Wireframe texture must decode without mipmaps: " + path
154: 		return null
155: 	pixels.convert(Image.FORMAT_RGBA8)
156: 	var digest := HashingContext.new()
157: 	digest.start(HashingContext.HASH_SHA256)
158: 	digest.update(pixels.get_data())
159: 	if digest.finish().hex_encode() != rgba_hash:
160: 		last_error = "Wireframe decoded texture hash changed: " + path
161: 		return null
162: 	return texture
163: 
164: 
165: func _fail(message: String) -> bool:
166: 	clear()
167: 	last_error = message
168: 	return false
169: 
170: 
171: static func _matches_dimensions(value: Variant, expected: Vector2i) -> bool:
172: 	if not value is Array or value.size() != 2:
173: 		return false
174: 	for index: int in 2:
175: 		if typeof(value[index]) not in [TYPE_INT, TYPE_FLOAT] or float(value[index]) != float(expected[index]):
176: 			return false
177: 	return true
```

## repository/src/presentation/eight_direction_resolver.gd

```text
1: class_name EightDirectionResolver
2: extends RefCounted
3: 
4: 
5: const SOUTH := 0
6: const SOUTH_EAST := 1
7: const EAST := 2
8: const NORTH_EAST := 3
9: const NORTH := 4
10: const NORTH_WEST := 5
11: const WEST := 6
12: const SOUTH_WEST := 7
13: const DIRECTION_ORDER: Array[String] = [
14: 	"south", "south_east", "east", "north_east",
15: 	"north", "north_west", "west", "south_west",
16: ]
17: const FIXED_VECTORS: Array[Vector2i] = [
18: 	Vector2i(0, 1000), Vector2i(707, 707), Vector2i(1000, 0), Vector2i(707, -707),
19: 	Vector2i(0, -1000), Vector2i(-707, -707), Vector2i(-1000, 0), Vector2i(-707, 707),
20: ]
21: const CARDINAL_IDS: Array[String] = ["south", "east", "north", "west"]
22: const SECTOR_SCALE := 1_000_000
23: const DIAGONAL_THRESHOLD := 414_214 # ceil(tan(22.5 degrees) * SECTOR_SCALE)
24: const HYSTERESIS_MARGIN_DEGREES := 8.0
25: const HYSTERESIS_HOLD_DOT := 0.8616291604415258 # cos(22.5 + 8 degrees)
26: 
27: var last_index := SOUTH
28: var has_direction := false
29: 
30: 
31: static func classify_index(x: int, y: int, fallback_index: int = SOUTH) -> int:
32: 	var fallback := _safe_index(fallback_index)
33: 	if x == 0 and y == 0:
34: 		return fallback
35: 	var absolute_x := absi(x)
36: 	var absolute_y := absi(y)
37: 	if absolute_x * SECTOR_SCALE <= absolute_y * DIAGONAL_THRESHOLD:
38: 		return SOUTH if y >= 0 else NORTH
39: 	if absolute_y * SECTOR_SCALE <= absolute_x * DIAGONAL_THRESHOLD:
40: 		return EAST if x >= 0 else WEST
41: 	if x >= 0:
42: 		return SOUTH_EAST if y >= 0 else NORTH_EAST
43: 	return SOUTH_WEST if y >= 0 else NORTH_WEST
44: 
45: 
46: static func direction_id_from_vector(x: int, y: int, fallback_id: String = "south") -> String:
47: 	return DIRECTION_ORDER[classify_index(x, y, direction_index(fallback_id))]
48: 
49: 
50: static func direction_index(direction_id: String) -> int:
51: 	var index := DIRECTION_ORDER.find(direction_id)
52: 	return index if index >= 0 else SOUTH
53: 
54: 
55: static func fixed_vector(direction_id: String) -> Vector2i:
56: 	return FIXED_VECTORS[direction_index(direction_id)]
57: 
58: 
59: static func is_fixed_vector(value: Vector2i) -> bool:
60: 	return value in FIXED_VECTORS
61: 
62: 
63: static func nearest_cardinal_id(x: int, y: int, fallback_id: String = "south") -> String:
64: 	if x == 0 and y == 0:
65: 		return fallback_id if fallback_id in CARDINAL_IDS else "south"
66: 	if absi(x) > absi(y):
67: 		return "east" if x >= 0 else "west"
68: 	return "south" if y >= 0 else "north"
69: 
70: 
71: static func relative_gait(facing_index: int, travel_index: int) -> String:
72: 	if facing_index < SOUTH or facing_index > SOUTH_WEST or travel_index < SOUTH or travel_index > SOUTH_WEST:
73: 		return "idle"
74: 	var difference := posmod(travel_index - facing_index, DIRECTION_ORDER.size())
75: 	if difference in [0, 1, 7]:
76: 		return "forward"
77: 	if difference in [3, 4, 5]:
78: 		return "backward"
79: 	return "strafe_left" if difference == 2 else "strafe_right"
80: 
81: 
82: static func relative_gait_from_vectors(facing: Vector2i, travel: Vector2i) -> String:
83: 	if travel == Vector2i.ZERO:
84: 		return "idle"
85: 	return relative_gait(
86: 		classify_index(facing.x, facing.y, SOUTH),
87: 		classify_index(travel.x, travel.y, SOUTH),
88: 	)
89: 
90: 
91: func resolve_index(x: int, y: int, fallback_index: int = SOUTH, use_hysteresis: bool = true) -> int:
92: 	if x == 0 and y == 0:
93: 		if not has_direction:
94: 			last_index = _safe_index(fallback_index)
95: 			has_direction = true
96: 		return last_index
97: 	var raw_index := classify_index(x, y, fallback_index)
98: 	if has_direction and use_hysteresis and raw_index != last_index and _inside_hold_cone(x, y, last_index):
99: 		return last_index
100: 	last_index = raw_index
101: 	has_direction = true
102: 	return last_index
103: 
104: 
105: func resolve_id(x: int, y: int, fallback_id: String = "south", use_hysteresis: bool = true) -> String:
106: 	return DIRECTION_ORDER[resolve_index(x, y, direction_index(fallback_id), use_hysteresis)]
107: 
108: 
109: func reset(direction_id: String = "south") -> void:
110: 	last_index = direction_index(direction_id)
111: 	has_direction = true
112: 
113: 
114: func clear() -> void:
115: 	last_index = SOUTH
116: 	has_direction = false
117: 
118: 
119: static func _inside_hold_cone(x: int, y: int, direction: int) -> bool:
120: 	var sample := Vector2(float(x), float(y)).normalized()
121: 	var center_value := FIXED_VECTORS[_safe_index(direction)]
122: 	var center := Vector2(float(center_value.x), float(center_value.y)).normalized()
123: 	return sample.dot(center) >= HYSTERESIS_HOLD_DOT
124: 
125: 
126: static func _safe_index(value: int) -> int:
127: 	return value if value >= SOUTH and value <= SOUTH_WEST else SOUTH
```

## repository/docs/SPRITE-PIPELINE.md

```text
1: # Current character sprite pipeline
2: 
3: Status: compact shared-body source contract,2026-09-14. See
4: [proportion/roster checkpoint](PROPORTION-CAST-CHECKPOINT.md) for fresh validation.
5: Live visible heights58/63/68px and4–4.5-head anatomy are baked per size around the
6: same pivot; source authoring envelopes58/68/76 remain historical calibration.
7: 
8: Active gate: playtest the shared Small, Middle and Large skeletons before any
9: named-character repair or addition. The current production front door is
10: [wireframe motion v2](../art_batches/character_style_v1/wireframe_motion_v2/README.md),
11: which reuses the fixed-bone template-v2 guide and supplies 64 independent
12: travel/aim pairs with eight phases in each of two distinct gaits, walk and sprint,
13: per size. All30 live identities use their corresponding size skeleton.
14: 
15: Deferred character-look authority: the [current label-free cast sheet](../reference/art/cast_proportions_v5/README.md),
16: only after all three basic templates are complete in every direction and live
17: action/animation mapping and receive user acceptance. Filled80-slot coverage is
18: not itself proof of complete motion. Use accepted skeletons for construction and
19: the new sheet for later silhouette, face, clothing and material treatment.
20: 
21: The live path is CartoonChampionPresenter delegating to WireframeBodyPresenter
22: and assets/sprites/wireframe_motion_v2/manifest.json, schema 2. It loads nine shared
23: textures: three base, three walk and three sprint. The 3,312 registered cells
24: decode to 116.44 MiB total (8.44 MiB base, 54 MiB walk, 54 MiB sprint), with no
25: per-character copies. Source and imported-RGBA hashes must match. Lossless
26: imports disable alpha-border repair and mipmaps; draw sampling stays nearest.
27: The [current cast contract](CURRENT-CAST.md) owns identity and size mappings.
28: Historical foundation/override pages and catalog fallback declarations remain
29: provenance only; the old32px/cardinal skeleton remains retired. Detailed skin
30: assembly steps later in this document resume only after neutral-body acceptance.
31: 
32: | Invariant | Value |
33: | --- | --- |
34: | Guides | Small 58 px, Middle 68 px, Large 76 px |
35: | Cell/anchor | 96 x 96, feet (48, 84), transparent gutters, fixed global body scale |
36: | Direction columns | south, south_east, east, north_east, north, north_west, west, south_west |
37: | Pose/contact rows | grounded, jump, cast, hit, walk, sprint, slide, roll, walk_b, sprint_b |
38: | Base page | 8 columns x 10 rows = 80 cells per size; 240 total |
39: | Each gait bank | 8 travel x 8 aim x 8 phases = 512 cells per size, packed 16 x 32 |
40: | All shared pages | 240 base + 1,536 walk + 1,536 sprint = 3,312 cells; nine textures |
41: | Sampling/layers | Nearest, no mipmaps; body/clothing/anatomy only; independent effects/shadows |
42: | Physics separation | Three fixed, size-specific hurtboxes; common wall clearance; neither derives from animation pixels |
43: 
44: Reuse size guides, landmarks, timing, direction resolution and registration.
45: Related anatomy shares construction guides, not cloned identity pixels. Tails/
46: fins/wings require reviewed pivots/occlusion. Prefer offline page assembly into
47: the existing renderer, not a second live paper-doll stack.
48: 
49: ## Motion truth
50: 
51: Real ground distance drives a shared normalized gait phase, including contact
52: frames and body-pivot motion. Distance maps to one cycle per 1.30 body heights,
53: subject to mode-specific readable cadence limits: walking at three visual
54: cycles/s, sprinting at five. Stops/blocked travel freeze stepping; heading changes and
55: walk/sprint switches preserve phase. Air/slide/roll motion and local prediction
56: correction offsets do not masquerade as footsteps. Authoritative actor metadata
57: owns character identity, body and lifecycle; predicted data supplies motion only.
58: 
59: HUD and Gallery portraits are the exact top third of occupied south-grounded
60: source bounds (full width, ceil(height/3)), proportionally nearest-fit into a
61: transparent 32px cache. They do not require separately authored portrait artwork.
62: 
63: Both live gait banks visibly exchange anatomical support and passing legs.
64: Pelvis, chest and head face aim B together with zero waist yaw twist; legs stride
65: along travel A, using backpedaling or a short non-crossing side shuffle when
66: needed. Hands stay aim-ready rather than counter-swinging away from the cursor.
67: Sprint has independently baked longer steps, stronger lean and higher foot lift,
68: not simply faster playback of walking pixels. Bones, 58/68/76 body scales and
69: size-specific hurtboxes stay fixed. Preserve volume/direction during other base
70: actions; physical lift and receiving-surface shadows stay separate.
71: 
72: The older [six-texture skeleton checkpoint](SKELETON-MOTION-CHECKPOINT.md) is
73: historical: it used one shared walk/run gait bank, 1,776 cells and 62.44 MiB.
74: Its six base/walk PNGs were retained byte-for-byte; the current sprint bank is
75: additive. That checkpoint does not establish acceptance of the new nine-texture
76: integration. The [latest checkpoint](MOTION-AWARENESS-CHECKPOINT.md) owns combined
77: test, game-capture and export status. Source/asset checks and focused runtime
78: passes are not human movement acceptance or sustained-120-FPS evidence.
```

## repository/docs/PROPORTION-CAST-CHECKPOINT.md

```text
1: # Shared template slide review checkpoint
2: 
3: Status: verified local-source candidate p50-9011a3cfa6dc, September 15, 2026;
4: paused for human slide review. The broader shared-template milestone remains open.
5: 
6: Protocol50/snapshot20; Godot Windows source. Run `scripts/run.cmd` for this
7: candidate. Existing EXEs contain earlier builds. No export, installer, commit,
8: publication or selected-checkpoint change was made in this slice.
9: 
10: ## Current change and playtest
11: 
12: The shared South-facing slide looked nearly upright in actual paid gameplay.
13: Two bounded rig passes produced a seated, asymmetric pose with one long planted
14: leg and one tucked leg. Small was inspected first, then Middle/Large. The change
15: uses a rigid torso recline/roll and fixed-bone IK; no per-frame scaling or fitting.
16: Only24 slide cells changed. Wallrun currently shares that body and inherits it.
17: 
18: Standing display targets remain58/63/68px, Stamina620/660/700, hurt radii17/18/19px
19: and common18px clearance. All30 identities and affinities remain unchanged.
20: Source anatomy, neck/head dimensions and pivot(48,84) are retained. No named skins
21: were promoted; the isolated attachment/layer package is preparation only.
22: 
23: 1. Run `scripts/run.cmd`; select S. Wayne in the Gallery.
24: 2. Sprint across open ground, hold C to slide, and aim South, then SE/SW and North
25:    while keeping travel independent. Compare the lower body and feet at normal zoom.
26: 3. Repeat with Oh Tipi and The Red Baron. Inspect start/hold/release into movement;
27:    the pose change does not add newly authored entry/braking/exit animation phases.
28: 4. Compare the [actual before/after scenes and direction boards](evidence/template-motion-20260915/comparison.html).
29: 
30: ## Fresh evidence and limits
31: 
32: Evidence root: `docs/evidence/template-motion-20260915/`.
33: 
34: - Baseline source identity Check verified p50-53a535028e4f on dirty main,977 entries;
35:   the prior Full-v3 receipt's three log hashes matched. Its109/707626 and32 frames
36:   remain historical proof of that earlier source.
37: - New capture:144 frames per baseline/pass1/pass2. Each set includes72 controlled
38:   presenter boards and72 actual paid-slide frames at75% camera zoom. All three
39:   sizes, all eight aim headings,11 held action selections and64 travel/aim pairs
40:   for walk and sprint over8 phases are represented. Controlled boards are not
41:   continuous gameplay or admission evidence for airborne/wall actions.
42: - Pass1 Focused passed2 suites/83,337 assertions,zero failures/stderr. It was
43:   rejected visually because South still looked upright. Pass2 is the retained
44:   art candidate. Fresh final `full-final-v3.json` passed 109 suites / 707,626
45:   assertions, zero failures / stderr, import and 120 Hz boot in 283,718 ms overall.
46:   The first two attempts timed out at the 180-second engine guard after 106/107
47:   completed suites, with no assertion failures or stderr. Both are failed gates
48:   retained with their logs. The final frozen source includes a reviewed, tested
49:   300-second Full-suite watchdog; all other engine calls retain 180 seconds.
50:   This is test supervision, not a change to the simulation performance budget.
51:   Release packaging was NOT RUN and still has its prior watchdog.
52: - Offline pass2 proof:3312 poses,3288 non-slide poses unchanged exactly;216 non-slide
53:   base cells and all six gait pages pixel-identical.24 slide cells changed;
54:   fixed bones,96 grounded ankle/toe endpoints, rigid dimensions, gaze yaw-plane
55:   and intended pitch checks pass. PNG containers were re-encoded; that is not
56:   a claim of byte-identical source image files. Nine banks/decoded allocation stay
57:   unchanged. Source/rig/bake proof and prior pass remain preserved.
58: - Independent Astra source/native review recommends retaining pass2 for human
59:   review. South slide heights43/46/50px versus53/58/63px before reflect the pose,
60:   not a change to standing display size. Human template approval is still pending.
61: - The final identity check and `final-summary.json` verify 3,164 frozen inputs,
62:   150 unchanged gameplay/content hashes, personal profile, selected pointer and
63:   all eight selected fallback members. All 144 before/after capture authority
64:   records match; all 48 rendered gait boards are byte-identical. The `referenced/`
65:   tree retains 575 evidence files, including all capture sets and receipt logs
66:   from failed attempts. Guard supervision passed
67:   13 ownership/cancellation checks plus the configurable-timeout fixture.
68: 
69: Remaining issues: North/NE have tight head/torso overlap at native scale. Slide
70: still follows aim using one base pose, without a separate travel/aim or entry/exit
71: phase bank. Wallrun inherits the deeper recline; physical wall-contact sequences
72: and their transitions were NOT RUN here. Jump,Float,air-dodge and walljump retain
73: shared jump-body selection; landing lacks a newly authored body transition;
74: moving casts retain gait legs without a new casting-arm layer. Held-state boards
75: are not approval of those animations. This completes the bounded slide-review
76: slice, not the entire shared-template milestone.
77: 
78: Performance/latency, physical multiplayer, eight-socket new-event validation,
79: audio listening, new portable/installer and human acceptance: NOT RUN. Historical
80: B2a host p95 10.592–11.085ms remains over the8.333ms budget. Presentation proof
81: does not clear that gate. After human template acceptance, follow the existing
82: queue's B2 contact and measured host/event-retention work before field expansion.
83: 
84: P48 and B2a packages remain operational fallbacks. The selected pointer still
85: names P48; its EXE is `exports/windows-overnight-p48-20260913/windows/flux2.exe`.
86: The baseline presentation ZIP and rig preserve the actual dirty source inputs;
87: do not partially restore old atlas files into new source as a rollback procedure.
88: 
89: ## Files in this bounded slice
90: 
91: - Rig: `art_batches/character_style_v1/template_v2/pose_guide_model.gd`;
92:   exporter, baker and regenerated rig under
93:   `art_batches/character_style_v1/wireframe_motion_v2/`.
94: - Runtime: `src/presentation/wireframe_body_presenter.gd`,
95:   `assets/sprites/wireframe_motion_v2/` and generated runtime identity.
96:   Presenter test revision updated in `tests/unit/test_wireframe_body_presenter.gd`.
97: - Capture: `scripts/capture-template-motion.ps1` and
98:   `tests/visual/capture_template_motion.gd`.
99: - Supervision: `scripts/flux2-common.ps1` and `scripts/test.ps1`;
```

## repository/docs/PLAYER-CONTROLS-AND-POV.md

```text
172: Both presets emit the same bounded semantic movement vector. They do not alter
173: acceleration, Stamina costs, collision, speed ceilings, ability outcomes,
174: network authority, replay bytes, or tick-rate behavior. If the pointer overlaps
175: the player exactly, aim-relative movement retains the last valid aim direction
176: rather than producing an undefined basis.
177: 
178: Slide, jump-chain and contextual technique press edges are retained for 180 ms.
179: The buffer stores intent only: speed, aerial stage, cooldown, collision target,
180: Stamina and control-lock requirements are rechecked every tick, and an expired
181: or still-illegal action changes no state and spends no resource.
182: 
183: The local input router combines held-state transitions with Godot's buffered
184: just-pressed transition before creating the semantic command. This prevents a
185: short key, wheel or controller press from disappearing between a render frame
186: and the next simulation sample. The semantic `S+D+slide` path and all seven
187: other compass combinations are tested through input mapping, command creation,
188: buffer consumption and slide direction; simulation integrity is tested at 120
189: Hz. Hardware that never reports a particular three-key chord cannot be
190: reconstructed in software, so wheel-down and in-world remapping remain equal
191: fallbacks rather than privileged mechanics.
192: 
193: Holding Space or wheel-up preserves the authored jump arc. Releasing it cuts
194: remaining air time to a 90 ms minimum; holding C or wheel-down while airborne advances the fall by one
195: additional simulation tick per tick. Fast fall costs no Stamina because the
196: earlier landing is its commitment, and its explicit canonical/presentation state
197: is replayed identically rather than inferred from animation.
198: 
199: Jump startup latches the movement direction held on the accepted jump tick.
200: While airborne, each non-zero movement vector immediately updates body facing
201: and continuously bends jump momentum at the authoritative 120 Hz rate.
202: Releasing movement preserves the current airborne momentum. A hard
203: reversal briefly trades speed for turning instead of snapping through the
204: player; contextual V remains the faster, Stamina-priced air redirect and Q / left trigger
205: remains the committed air dodge. Spell aim stays independent and exact.
206: 
207: V at a runnable practice-wall face starts an at-most-420 ms contact wallrun
208: along the requested tangent for one 18-Stamina purchase. Stable positive wall
209: identity excludes outer world boundaries, a 900 ms same-surface lockout prevents
210: loops, and the end exposes a short recovery cue. The same semantic V press keeps
211: its wall/air-turn and impact-tech roles; explicit Evade on open
212: ground starts a 24-Stamina roll. Roll remains solid against world collision
213: for 240 ms and ignores hostile damage/control only during its opening 130 ms.
214: Jump-family actions likewise ignore hostile damage/control during their opening
215: 90 ms, then become vulnerable before landing. A bright broken contour exposes
216: the exact active evasion phase; neither action passes through walls or topology.
217: 
218: Every completed aerial route and wall-skim exit records a bounded 0–1000 landing
219: intensity in canonical state. Presentation turns that truth into the champion's
220: land strip, a short shadow squash and an expanding four-mark rune ring; heavier
221: routes and fast fall read more strongly without changing collision or recovery.
222: Reduced motion preserves the timing cue with a smaller, thinner, dimmer pulse.
```

```text
295: The schema persists `reduced_motion` and `high_contrast` strictly as booleans.
296: Both default to false, fail closed on malformed values, and do not alter
297: canonical simulation. While the Controls Lectern is open, M/controller L3
298: toggles reduced effects and H/controller R3 toggles high contrast; the header
299: shows both states and normal player changes save immediately. When reduced
300: effects are enabled, the G3 presentation sampler uses a seven-pixel maximum
301: whole-pixel body
302: lift and a lower-scale but still broader/darker shadow cue, instead of the
303: normal 28-pixel apex lift. Timing and authoritative movement remain identical.
304: 
305: Exact command-line movement, POV, angle, range and camera overrides are
306: transient diagnostics. They affect that process only and are not written to the
307: player profile on exit.
308: 
309: ## Acceptance and authority
310: 
311: - Movement transforms are deterministic integer operations before command
312:   construction; replay stores the resulting world vector and independent aim.
313: - Saved profiles round-trip without network access.
314: - Source and imported-resource builds boot at 120 Hz with the same selected preferences.
315: - Equivalent normalized jump samples at 120 Hz produce the same body lift,
316:   shadow width, and shadow opacity across all current aerial traversal modes.
317: - Jump presentation sampling does not mutate position, collision radius,
318:   canonical values, replay data, camera focus, or POV origin.
```

## repository/content/champions/body_type_profiles_v1.json

```text
1: {
2:   "schema_version": 1,
3:   "id": "body-type-profiles-v1-equal-budget",
4:   "authority": "simulation bounds and player-facing role contract; body type never grants automatic damage",
5:   "shared_rules": {
6:     "competitive_budget": 100,
7:     "collision_radius_policy": "shared_foundation_radius",
8:     "hurt_radius_policy": "fixed_body_profile_independent_of_animation",
9:     "visual_template_order": ["small", "middle", "large"],
10:     "visual_template_height_pixels": {"small": 58, "middle": 68, "large": 76},
11:     "visual_size_authority": "presentation_only_no_hidden_reach_evasion_or_damage",
12:     "universal_movement": ["walk", "sprint", "jump", "double_jump", "slide", "slide_jump", "roll", "air_dodge", "wave_dash", "wall_kick", "fast_fall", "wall_skim"]
13:   },
14:   "profiles": {
15:     "small": {
16:       "hurt_radius": 17000,
17:       "role": "skirmisher",
18:       "strengths": ["ground_speed", "flux_recovery", "small_visual_silhouette"],
19:       "tradeoffs": ["health_reserve", "stamina_reserve"],
20:       "stat_bounds": {
21:         "health_maximum": [82000, 98000],
22:         "health_recovery_per_second": [1800, 2800],
23:         "flux_maximum": [116600, 132000],
24:         "flux_recovery_per_second": [21000, 27000],
25:         "stamina_maximum": [610000, 640000],
26:         "stamina_recovery_per_second": [25000, 33000],
27:         "movement_speed_ratio": [1030, 1100]
28:       }
29:     },
30:     "middle": {
31:       "hurt_radius": 18000,
32:       "role": "adapter",
33:       "strengths": ["resource_balance", "route_flexibility", "stable_recovery"],
34:       "tradeoffs": ["no_extreme_stat", "moderate_commitment"],
35:       "stat_bounds": {
36:         "health_maximum": [100000, 118000],
37:         "health_recovery_per_second": [1400, 2200],
38:         "flux_maximum": [107800, 123200],
39:         "flux_recovery_per_second": [17000, 23000],
40:         "stamina_maximum": [645000, 680000],
41:         "stamina_recovery_per_second": [27000, 35000],
42:         "movement_speed_ratio": [950, 1020]
43:       }
44:     },
45:     "large": {
46:       "hurt_radius": 19000,
47:       "role": "anchor",
48:       "strengths": ["health_reserve", "stamina_reserve", "lane_presence"],
49:       "tradeoffs": ["ground_speed", "flux_recovery"],
50:       "stat_bounds": {
51:         "health_maximum": [124000, 145000],
52:         "health_recovery_per_second": [900, 1700],
53:         "flux_maximum": [96800, 114400],
54:         "flux_recovery_per_second": [14000, 19000],
55:         "stamina_maximum": [685000, 715000],
56:         "stamina_recovery_per_second": [29000, 37000],
57:         "movement_speed_ratio": [880, 940]
58:       }
59:     }
60:   }
61: }
```

## repository/src/sim/core/sim_config.gd

```text
1: class_name SimConfig
2: extends RefCounted
3: 
4: 
5: # Heavy terminal blasts, authored held-slot Rapid firing and the expanded Loom.
6: # Existing wire fields remain; old peers must not simulate different attacks.
7: const PROTOCOL_VERSION: int = 53
8: const FIXED_SCALE: int = 1000
9: const TICK_RATE: int = 120
10: # Cast admission and replication share one finite authority envelope. Pending
11: # casts reserve whole patterns before payment; presentation never hides a hit.
12: const MAX_ACTIVE_PROJECTILES: int = 128
13: const MAX_PROJECTILES_PER_PLAYER: int = 16
14: const MAX_ACTIVE_FIELDS: int = 32
15: const MAX_FIELDS_PER_PLAYER: int = 4
16: 
17: var tick_rate: int
18: 
19: 
20: func _init(requested_tick_rate: int = TICK_RATE) -> void:
21: 	tick_rate = requested_tick_rate if is_supported_tick_rate(requested_tick_rate) else 0
22: 
23: 
24: static func is_supported_tick_rate(value: int) -> bool:
25: 	return value == TICK_RATE
26: 
27: 
28: func is_valid() -> bool:
29: 	return is_supported_tick_rate(tick_rate)
30: 
31: 
32: func milliseconds_to_ticks(milliseconds: int) -> int:
33: 	if not is_valid() or milliseconds <= 0:
34: 		return 0
35: 	@warning_ignore("integer_division")
36: 	return maxi(1, (milliseconds * tick_rate + 999) / 1000)
37: 
38: 
39: func per_tick(value_per_second: int) -> int:
40: 	if not is_valid():
41: 		return 0
42: 	@warning_ignore("integer_division")
43: 	return value_per_second / tick_rate
```

## repository/docs/current-checkpoint.json

```text
1: {
2:   "schema_version": 1,
3:   "current": {
4:     "checkpoint_id": "overnight-p48-20260913",
5:     "kind": "current_portable",
6:     "build_directory": "exports/windows-overnight-p48-20260913",
7:     "evidence_directory": "docs/evidence/windows-overnight-p48-20260913",
8:     "payloads": [
9:       {
10:         "path": "exports/windows-overnight-p48-20260913/windows/flux2.exe",
11:         "bytes": 109071360,
12:         "sha256": "04baf75cc1d69dd93eb709533ecab4fd7770bb8a530645717017a06a9d9809fc",
13:         "role": "game"
14:       },
15:       {
16:         "path": "exports/windows-overnight-p48-20260913/windows/flux2.pck",
17:         "bytes": 67248700,
18:         "sha256": "ddce9451e871096ca02190deb9092cba71db96bd8d732cd2181fd7c5cd452083",
19:         "role": "pack"
20:       },
21:       {
22:         "path": "exports/windows-overnight-p48-20260913/release/FLUX2-Windows-x86_64.zip",
23:         "bytes": 97760657,
24:         "sha256": "5e49c599f026453917e3eb8201456e86089e9fe0d794efe3b9bcebe1385c041f",
25:         "role": "portable"
26:       }
27:     ],
28:     "evidence": [
29:       {
30:         "path": "docs/evidence/windows-overnight-p48-20260913/checkpoint.json",
31:         "bytes": 2768,
32:         "sha256": "49d8e63826990d048128351137432efaa3c581c8fbaac30b9bc30e326077ee4e",
33:         "role": "checkpoint"
34:       },
35:       {
36:         "path": "docs/evidence/windows-overnight-p48-20260913/inputs/full-receipt.json",
37:         "bytes": 13062,
38:         "sha256": "29a2cf4d961d3245f48039111e49a7d0ce079c6ec6dcf06b4b1cee3156c624e1",
39:         "role": "full"
40:       },
41:       {
42:         "path": "docs/evidence/windows-overnight-p48-20260913/inputs/capture/capture-receipt.json",
43:         "bytes": 747047,
44:         "sha256": "b45e679c5ee5fd03c287494ce9fa6688e586b71e1a0404eab900be32e56e0334",
45:         "role": "capture"
46:       },
47:       {
48:         "path": "docs/evidence/windows-overnight-p48-20260913/raw-boot.log",
49:         "bytes": 913,
50:         "sha256": "057c4bfa51c4ff41ad6eb17b70ac579a0e2e1cb6b20f180f494e99625b31b15d",
51:         "role": "boot_log"
52:       },
53:       {
54:         "path": "docs/evidence/windows-overnight-p48-20260913/raw-boot.log.err",
55:         "bytes": 0,
56:         "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
57:         "role": "boot_stderr"
58:       }
59:     ]
60:   },
61:   "historical_installer": {
62:     "checkpoint_id": "qv-followup-p47-20260909",
63:     "kind": "historical_installer",
64:     "build_directory": "exports/windows-followup-p47-20260909",
65:     "evidence_directory": "docs/evidence/template-delivery-v1/delivery",
66:     "payloads": [
67:       {
68:         "path": "exports/windows-followup-p47-20260909/release/FLUX.exe",
69:         "bytes": 96787968,
70:         "sha256": "4bd03fd6ee50d7161b445bc03e2c8e99477b366a44b63f8fadba084ce31b5121",
71:         "role": "installer"
72:       }
73:     ],
74:     "evidence": [
75:       {
76:         "path": "docs/evidence/template-delivery-v1/delivery/installer-journey-receipt.json",
77:         "bytes": 6594,
78:         "sha256": "6ff13a83092ed3b0206406e495872948be258dcc3709d108d7c9a7a2391bf738",
79:         "role": "installer_journey"
80:       }
81:     ]
82:   },
83:   "boundaries": {
84:     "publication": "not_published",
85:     "human_acceptance": "pending",
86:     "two_pc_acceptance": "pending",
87:     "sustained_rendered_120fps": "not_certified",
88:     "current_installer": "not_attempted_prior_policy_block"
89:   }
90: }
```
