extends RefCounted
## Opt-in identity skins. Presentation only: no simulation writes or size rules.
## Fixed 18px skull calibration; 58/63/68px anatomy is baked, never fitted per pose.

const PATH := "res://assets/sprites/fullbody_cast_v1/"
const AerialPose = preload("res://src/presentation/pixel_aerial_pose.gd")
const WallPose = preload("res://src/presentation/pixel_wallrun_pose.gd")
const PixelFlipbook = preload("res://src/presentation/pixel_flipbook_presenter.gd")
const DIRS := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
const CELL := Vector2(128, 128)
const PIVOT := Vector2(64, 104)
const ORIGIN := Vector2(16, 20)
const PHASES := 24
const CACHE_LIMIT := 384
const RENDER_CACHE_LIMIT := 256 # Eight live actors, with room for roster QA.
const LOCOMOTION_SETTLE_SECONDS := 0.07
const MAX_BODY_COMPRESSION_PIXELS := 3.0
const MAX_BODY_EXTENSION_PIXELS := 1.4
const WALK_LEAN_DEGREES := 1.8
const SPRINT_LEAN_DEGREES := 4.5
const WALLRUN_LEAN_DEGREES := 5.5
const MAX_GAIT_COUNTERBALANCE_DEGREES := 2.6
var entries: Dictionary = {}
var textures: Dictionary = {}
var portraits: Dictionary = {}
var key_textures: Dictionary = {}
var motions: Dictionary = {}
var meshes: Dictionary = {}
var mesh_order: Array[String] = []
var render_meshes: Dictionary = {}
var render_order: Array[String] = []
var skin_tables: Dictionary = {} # One immutable binding table per admitted skin/direction.
var cast_targets: Dictionary = {} # Terminal cast bones, never blended/mutated in place.
var cast_target_order: Array[String] = []
var indices := PackedInt32Array()
var last_error := ""
var pixel_pilot: RefCounted
var bounded_residency := false
var resident_order: Array[String] = []
var page_load_count := 0
const MAX_ACTIVE_IDENTITIES := 13 # Twelve participants plus one Gallery preview.
const RECENT_IDENTITIES := 2
const MAX_RESIDENT_IDENTITIES := MAX_ACTIVE_IDENTITIES + RECENT_IDENTITIES


func enable_pixel_pilot(catalog_ids: Array, use_full_cast: bool = false) -> bool:
	var candidate := PixelFlipbook.new()
	if not candidate.configure(catalog_ids, use_full_cast, bounded_residency):
		last_error = candidate.last_error
		return false
	var candidate_portraits: Dictionary = {}
	for id: String in candidate.entries:
		# Compact pixel heads extend below the old upper-third crop. Preserve the
		# complete face/chin with a head-and-shoulders half-body crop for this bank.
		var pixels: Image = candidate.portrait_sources[id] if bounded_residency else candidate.textures[id].get_image()
		var portrait := build_portrait(pixels, 1, 0.5 if use_full_cast else 1.0/3.0)
		if portrait.is_empty():
			last_error = "Empty pixel portrait: " + id
			return false
		candidate_portraits[id] = portrait
	# Publish only after both body and portrait admission succeed completely.
	candidate.portrait_sources.clear()
	pixel_pilot = candidate
	portraits.merge(candidate_portraits, true)
	return true


func configure(catalog_ids: Array, use_bounded_residency: bool = false) -> bool:
	bounded_residency = use_bounded_residency
	resident_order.clear()
	pixel_pilot = null
	entries.clear()
	textures.clear()
	portraits.clear()
	key_textures.clear()
	meshes.clear()
	mesh_order.clear()
	render_meshes.clear()
	render_order.clear()
	skin_tables.clear()
	cast_targets.clear()
	cast_target_order.clear()
	indices.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH + "manifest.json"))
	if not parsed is Dictionary or parsed.get("id") != "fullbody-cast-candidate-v1":
		return fail("Invalid fullbody manifest")
	if FileAccess.get_sha256(PATH + "motions.json") != parsed.get("motions_sha256"):
		return fail("Fullbody motion hash mismatch")
	var bank: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH + "motions.json"))
	if not bank is Dictionary or not bank.has("bodies") or not bank.has("actions"):
		return fail("Invalid fullbody motion bank")
	motions = bank
	# Decode JSON coordinates once, not four times per joint per animation frame.
	for body: Dictionary in motions.bodies.values():
		for rest: Dictionary in body.rest.values():
			for joint: String in rest: rest[joint]=vec(rest[joint])
		for clip: Array in body.clips.values():
			for pose: Dictionary in clip:
				for joint: String in pose.points: pose.points[joint]=vec(pose.points[joint])
	# Eager authoring admission remains the default. Live bounded admission
	# verifies one page at a time, retaining only metadata, skin weights and faces.
	if parsed.characters.size() != catalog_ids.size() or parsed.characters.size() > 64:
		return fail("Fullbody roster does not match live catalog")
	for entry: Dictionary in parsed.characters:
		var id: String = entry.id
		if not catalog_ids.has(id) or entries.has(id) or not motions.bodies.has(entry.body):
			return fail("Fullbody identity mismatch: " + id)
		var detail: Dictionary = entry.get("detail", {})
		var texel_scale := 2 if not detail.is_empty() else 1
		var texture := load_page(detail if texel_scale == 2 else entry, Vector2i(1024, 128)*texel_scale)
		if texture == null:
			return false
		entries[id] = entry
		if not bounded_residency: textures[id] = texture
		var admitted_pixels := texture.get_image()
		portraits[id] = build_portrait(admitted_pixels, texel_scale)
		# Transparent atlas padding never becomes visible when its triangles move.
		# Admit a conservative per-facing topology once, before gameplay; retain
		# every quad touching ink plus a source-texel guard. UVs and the remaining
		# bone weights/triangles are exactly the original, not a lower-detail rig.
		for facing: int in DIRS.size():
			var occupied := admitted_pixels.get_region(Rect2i(facing*128*texel_scale,0,128*texel_scale,128*texel_scale)).get_used_rect()
			var local_ink := Rect2(Vector2(occupied.position)/texel_scale-ORIGIN,Vector2(occupied.size)/texel_scale).grow(1.0)
			skin_tables["%s/%d" % [id,facing]] = compile_skin(entry.directions[DIRS[facing]],local_ink)
		if entry.has("keys"):
			var key := load_page(entry.keys, Vector2i(1024, 1024))
			if key == null:
				return false
			if not bounded_residency: key_textures[id] = key
	for y: int in 16:
		for x: int in 16:
			var i := y * 17 + x
			indices.append_array(PackedInt32Array([i, i+1, i+17, i+1, i+18, i+17]))
	last_error = ""
	return true


func fail(message: String) -> bool:
	last_error = message
	entries.clear()
	textures.clear()
	portraits.clear()
	key_textures.clear()
	return false


func load_page(definition: Dictionary, size: Vector2i) -> Texture2D:
	var texture := _read_page(definition, size)
	if texture == null: fail(last_error)
	return texture


func _read_page(definition: Dictionary, size: Vector2i) -> Texture2D:
	var leaf := String(definition.get("atlas", ""))
	if leaf.is_empty() or leaf != leaf.get_file() or ".." in leaf:
		last_error = "Unsafe fullbody atlas"
		return null
	var texture := ResourceLoader.load(PATH + leaf, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE if bounded_residency else ResourceLoader.CACHE_MODE_REUSE) as Texture2D
	page_load_count += 1
	if texture == null or Vector2i(texture.get_size()) != size:
		last_error = "Fullbody atlas dimensions: " + leaf
		return null
	var image := texture.get_image()
	if image == null:
		last_error = "Unreadable fullbody atlas: " + leaf
		return null
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	if hash.finish().hex_encode() != definition.get("rgba_sha256"):
		last_error = "Fullbody decoded pixels changed: " + leaf
		return null
	last_error = ""
	return texture


func prepare_character_pages(requested: Array[String]) -> bool:
	if not bounded_residency: return true
	if requested.size() > MAX_ACTIVE_IDENTITIES:
		last_error = "Character page active capacity exceeded"
		return false
	var selected: Array[String] = []
	for id: String in requested:
		if not entries.has(id) or selected.has(id):
			last_error = "Unknown or duplicate character page identity: " + id
			return false
		selected.append(id)
	var recent: Array[String] = []
	for index: int in range(resident_order.size()-1, -1, -1):
		var id: String = resident_order[index]
		if not selected.has(id): recent.push_front(id)
		if recent.size() == RECENT_IDENTITIES: break
	recent.append_array(selected)
	selected = recent
	var staged := {}
	var staged_keys := {}
	for id: String in selected:
		var entry: Dictionary = entries[id]
		var texture: Texture2D = textures.get(id)
		if texture == null:
			var detail: Dictionary = entry.get("detail", {})
			var scale := 2 if not detail.is_empty() else 1
			texture = _read_page(detail if scale == 2 else entry, Vector2i(1024,128)*scale)
		if texture == null: return false
		staged[id] = texture
		if entry.has("keys"):
			var key: Texture2D = key_textures.get(id)
			if key == null: key = _read_page(entry.keys, Vector2i(1024,1024))
			if key == null: return false
			staged_keys[id] = key
	if pixel_pilot != null and not pixel_pilot.prepare_character_pages(selected):
		last_error = pixel_pilot.last_error
		return false
	# No externally visible bank changes until every required page is verified.
	textures = staged
	key_textures = staged_keys
	resident_order = selected
	last_error = ""
	return true


func residency_stats() -> Dictionary:
	var bytes := 0
	for page: Texture2D in textures.values(): bytes += int(page.get_width())*int(page.get_height())*4
	for page: Texture2D in key_textures.values(): bytes += int(page.get_width())*int(page.get_height())*4
	var pixel_count := 0
	var action_count := 0
	if pixel_pilot != null:
		pixel_count = pixel_pilot.textures.size()
		for page: Texture2D in pixel_pilot.textures.values(): bytes += int(page.get_width())*int(page.get_height())*4
		if pixel_pilot.action_bank != null:
			action_count = pixel_pilot.action_bank.textures.size()
			for page: Texture2D in pixel_pilot.action_bank.textures.values(): bytes += int(page.get_width())*int(page.get_height())*4
	return {"bounded":bounded_residency,"resident_ids":resident_order.duplicate(),
		"body_pages":textures.size(),"key_pages":key_textures.size(),"pixel_pages":pixel_count,
		"action_pages":action_count,"native_rgba_bytes":bytes,"portrait_count":portraits.size()}


func inspection_frame(id: String, direction: int) -> Dictionary:
	if pixel_pilot != null and pixel_pilot.has_character(id):
		return pixel_pilot.inspection_frame(id, direction)
	if not textures.has(id) or direction < 0 or direction > 7:
		return {}
	var cell := int(textures[id].get_height())
	return {"texture": textures[id], "region": Rect2(direction*cell, 0, cell, cell),
		"fullbody_art": true, "visual_mode": "fullbody_art_candidate", "body_type": entries[id].body}


func portrait_frame(id: String) -> Dictionary:
	var result: Dictionary = portraits.get(id, {}).duplicate()
	result.merge({"fullbody_art": true, "visual_mode": "fullbody_art_candidate",
		"temporary_body_template": false, "complete_page_override": false}, true)
	if pixel_pilot != null and pixel_pilot.entries.has(id):
		result["pixel_body_pilot"] = true
		result["visual_mode"] = pixel_pilot.visual_mode()
	return result


static func build_portrait(pixels: Image, texel_scale: int = 1, upper_body_fraction: float = 1.0/3.0) -> Dictionary:
	if pixels == null or texel_scale <= 0 or pixels.get_width() < 128*texel_scale or pixels.get_height() < 128*texel_scale:
		return {}
	if not is_finite(upper_body_fraction) or upper_body_fraction <= 0.0 or upper_body_fraction > 1.0:
		return {}
	var occupied := pixels.get_region(Rect2i(0,0,128*texel_scale,128*texel_scale)).get_used_rect()
	if not occupied.has_area():
		return {}
	var source := Rect2i(occupied.position, Vector2i(occupied.size.x, ceili(occupied.size.y*upper_body_fraction)))
	var crop := pixels.get_region(source)
	# Keep the complete selected upper body, but don't shrink faces to make room for
	# empty columns belonging to the original tail/feet width below this crop.
	var ink := crop.get_used_rect()
	if ink.has_area():
		source.position.x += ink.position.x
		source.size.x = ink.size.x
		crop = pixels.get_region(source)
	var scale := minf(32.0/source.size.x,32.0/source.size.y)
	var size := Vector2i(maxi(1,roundi(source.size.x*scale)),maxi(1,roundi(source.size.y*scale)))
	crop.resize(size.x,size.y,Image.INTERPOLATE_NEAREST)
	var image := Image.create(32,32,false,Image.FORMAT_RGBA8)
	var offset := Vector2i((Vector2i(32,32)-size)/2)
	image.blit_rect(crop,Rect2i(Vector2i.ZERO,size),offset)
	return {"texture":ImageTexture.create_from_image(image),"region":Rect2(0,0,32,32),
		"source_region":Rect2(source),"occupied_model_region":Rect2(occupied),"content_region":Rect2(Vector2(offset),Vector2(size))}


static func action_for_state(state: PlayerState) -> String:
	# Resolve actual planes before the legacy atlas collapses them into silhouettes.
	if state.health <= 0: return "defeated"
	if state.control_state in [PlayerState.ControlState.LAUNCHED, PlayerState.ControlState.GRAPPLED]: return "hit"
	if state.control_state == PlayerState.ControlState.STUNNED: return "stunned"
	if state.control_state == PlayerState.ControlState.ROOTED: return "rooted"
	if state.control_state == PlayerState.ControlState.CHARGING: return "cast"
	if state.impact_recovery_ticks > 0 or state.movement_mode in [PlayerState.MovementMode.LAUNCHED, PlayerState.MovementMode.GRAPPLED, PlayerState.MovementMode.IMPACT_RECOVERY]: return "hit"
	if state.movement_mode == PlayerState.MovementMode.STUNNED: return "stunned"
	if state.movement_mode == PlayerState.MovementMode.ROOTED: return "rooted"
	if state.movement_mode == PlayerState.MovementMode.CHARGING: return "cast"
	if state.jumpsquat_active: return "jumpsquat"
	if state.is_rolling(): return "roll"
	if state.air_dodge_ticks > 0: return "air_dodge"
	if state.wall_skim_ticks > 0: return "wallrun"
	if state.crouching: return "crouch"
	if state.movement_mode == PlayerState.MovementMode.WAVE_DASH: return "wavedash"
	if state.movement_mode == PlayerState.MovementMode.SLIDE: return "slide"
	if state.is_airborne():
		if state.air_floating and state.flight_capable and state.float_ticks > 0 and state.stamina > 0: return "fly"
		if state.movement_mode == PlayerState.MovementMode.FAST_FALL: return "fast_fall"
		if state.air_vertical_velocity < 0: return "fall"
		if state.hop_mode == PlayerState.MovementMode.DOUBLE_JUMP: return "double_jump"
		if state.hop_mode == PlayerState.MovementMode.WALL_KICK: return "walljump"
		if state.hop_mode == PlayerState.MovementMode.SLIDE_JUMP: return "slide_jump"
		return "jump"
	if state.landing_ticks > 0 and state.velocity_x == 0 and state.velocity_y == 0: return "land"
	if state.velocity_x != 0 or state.velocity_y != 0:
		return "sprint" if state.movement_mode == PlayerState.MovementMode.SPRINT else "walk"
	return "idle"


func frame(id: String, state: PlayerState, tick: float, config: SimConfig, locomotion_phase: float, reduced_motion: bool = false, wall_travel: Vector2i = Vector2i.ZERO) -> Dictionary:
	if not entries.has(id) or not textures.has(id): return {}
	var action := action_for_state(state)
	var aim_vec := CartoonChampionPresenter.presentation_facing_vector(state)
	var aim := EightDirectionResolver.classify_index(aim_vec.x, aim_vec.y)
	var velocity := Vector2i(state.velocity_x, state.velocity_y)
	var travel := EightDirectionResolver.classify_index(velocity.x, velocity.y) if velocity != Vector2i.ZERO else aim
	if action == "wallrun" and wall_travel != Vector2i.ZERO:
		travel = EightDirectionResolver.classify_index(wall_travel.x,wall_travel.y)
	elif action == "wallrun" and velocity == Vector2i.ZERO:
		# Contact can cancel planar speed at an inner corner. Keep the wall's
		# stored tangent rather than turning a braced body with cursor aim.
		travel = EightDirectionResolver.classify_index(state.wall_skim_x,state.wall_skim_y)
	if action in ["slide","wavedash"]:
		var lane := CartoonChampionPresenter.presentation_facing_vector(state,"slide")
		travel = EightDirectionResolver.classify_index(lane.x,lane.y)
	# Respect each clip's cadence. Live wall travel owns a distance phase;
	# timer sampling remains only for previews without that presentation history.
	var definition: Dictionary = motions.actions[action]
	var seconds := tick / 60.0 if is_finite(tick) else 0.0
	var phase := seconds * float(definition.fps) / maxi(1, int(definition.frames))
	if action in ["walk", "sprint", "wallrun"] and locomotion_phase >= 0.0 and is_finite(locomotion_phase):
		phase = locomotion_phase
	elif action == "wallrun":
		phase = float(maxi(0, config.milliseconds_to_ticks(MovementTuning.WALL_SKIM_DURATION_MS)-state.wall_skim_ticks)) / config.tick_rate * float(definition.fps) / int(definition.frames)
		if velocity == Vector2i.ZERO: phase = 0.0 # Stable contact, not running in place.
	elif action in ["slide", "wavedash"]:
		phase = 0.5 # A held pose, not a repeating entry animation.
	elif action == "jumpsquat":
		phase = minf(1.0, float(state.jumpsquat_ticks) / maxi(1,config.milliseconds_to_ticks(MovementTuning.JUMPSQUAT_CHARGE_MS)))
	elif action == "land":
		phase = clampf(1.0-float(state.landing_ticks)/maxi(1,config.milliseconds_to_ticks(MovementTuning.LANDING_WINDOW_MS)),0,1)
	elif action in ["jump", "fall", "double_jump", "walljump", "slide_jump"]:
		# Rise unfolds toward the apex; descent gathers the feet for landing.
		# Read actual vertical velocity, never invent or delay an exposure plane.
		phase = airborne_pose_phase(action, state.air_vertical_velocity)
	elif action in ["roll", "air_dodge"]:
		var duration := MovementTuning.ROLL_DURATION_MS if action == "roll" else MovementTuning.AIR_DODGE_DURATION_MS
		phase = clampf(1.0 - float(state.air_dodge_ticks)/maxi(1, config.milliseconds_to_ticks(duration)), 0, 1)
	elif action == "hit":
		# Forced displacement is not walking. A held recoil remains immediate;
		# the existing impact-recovery timer alone advances its return to rest.
		phase = clampf(1.0-float(state.impact_recovery_ticks)/maxi(1,config.milliseconds_to_ticks(MovementTuning.IMPACT_RECOVERY_DURATION_MS)),0,1) if state.impact_recovery_ticks > 0 else 0.35
	elif action == "cast":
		phase = 0.35 # Control-owned charge without a pending spell holds its gather.
		if state.pending_cast_wire_id > 0:
			var charge := CombatTuning.cast_definition_view(state.pending_cast_wire_id)
			phase = clampf(1.0-float(state.pending_cast_ticks)/maxi(1,config.milliseconds_to_ticks(int(charge.get("startup_ms",0)))),0,1)
	elif action == "defeated": phase = 1.0
	var casting := (state.pending_cast_wire_id > 0 or state.cast_recovery_ticks > 0) and action not in ["hit","stunned","defeated"]
	var cast_phase := 0.5
	var cast_weight := 1.0
	if state.pending_cast_wire_id > 0:
		var cast_definition := CombatTuning.cast_definition_view(state.pending_cast_wire_id)
		var startup := maxi(1,config.milliseconds_to_ticks(int(cast_definition.get("startup_ms",0))))
		cast_phase = clampf(1.0-float(state.pending_cast_ticks)/startup,0,1)
		cast_weight = smoothstep(0.0,0.35,cast_phase)
	elif state.cast_recovery_ticks > 0:
		cast_phase = 1.0
		cast_weight = smoothstep(0.0,1.0,clampf(float(state.cast_recovery_ticks)/maxi(1,config.milliseconds_to_ticks(90)),0,1))
	if pixel_pilot != null:
		if action == "wallrun" and WallPose.is_attached(state):
			var wall_frame: Dictionary = pixel_pilot.wallrun_frame(id, aim, travel, phase,
				Vector2(state.wall_x, state.wall_y), velocity != Vector2i.ZERO, reduced_motion)
			if not wall_frame.is_empty():
				wall_frame["cast_overlay_requested"] = casting
				return wall_frame
		# Explicit authority gates; the DOUBLE_JUMP adapter alone never means flight.
		# Non-fliers keep their compact tuck throughout voluntary jump descent.
		if action == "fly" or (state.is_airborne() and not state.flight_capable and action in AerialPose.BALL_ACTIONS):
			var pose_tick := AerialPose.pose_ticks(state, config)
			var aerial: Dictionary = pixel_pilot.aerial_frame(id, action, aim, travel, pose_tick, state.air_vertical_velocity, reduced_motion, state.hop_mode == PlayerState.MovementMode.DOUBLE_JUMP)
			if not aerial.is_empty():
				aerial["cast_overlay_requested"] = casting
				return aerial
		var pixel_cast_weight := cast_weight
		if casting and state.pending_cast_wire_id > 0 and state.cast_recovery_ticks > 0:
			# A legal recovery-to-startup chain has no idle gap. Keep its painted
			# upper row on the new startup's zero-weight sample, without extending
			# either timer or changing the legacy rig's independent cast envelope.
			var recovery_weight := smoothstep(0.0,1.0,clampf(float(state.cast_recovery_ticks)/maxi(1,config.milliseconds_to_ticks(90)),0,1))
			pixel_cast_weight = maxf(pixel_cast_weight,recovery_weight)
		var fixed_frame: Dictionary = pixel_pilot.frame(id,action,aim,travel,phase,casting,pixel_cast_weight,reduced_motion)
		if not fixed_frame.is_empty():
			return fixed_frame
		var rigid_fallback: Dictionary = pixel_pilot.rigid_fallback_frame(id,action,aim,travel,phase,casting)
		if not rigid_fallback.is_empty():
			return rigid_fallback
	var travel_facing := bool(motions.actions[action].get("travel_facing", false))
	var facing := travel if travel_facing else aim
	var region := Rect2(facing*128, 0, 128, 128)
	var result := {"texture": textures[id], "source_region": region, "cell_size": CELL, "pivot": PIVOT,
		"fullbody_art": true, "action": action, "aim_index": aim, "travel_index": travel,
		"wireframe_body": false, "visual_mode": "fullbody_art_candidate",
		"display_height": {"small":58, "middle":63, "large":68}[entries[id].body], "squat_depth":0,
		"offset": Vector2.ZERO, "art_pose_quality": "shared-rig candidate", "motion_phase":phase,
		"independent_cast_pose":false, "texel_scale":int(textures[id].get_height())/128}
	var row := authored_row(action, phase)
	# Incomplete key sheets remain explicit keyed poses, not invented full cycles.
	if key_textures.has(id) and not row.is_empty() and not casting:
		var rows: Array = entries[id].keys.rows
		if rows.has(row):
			result.texture = key_textures[id]
			result.texel_scale = 1
			result.source_region = Rect2(facing*128, rows.find(row)*128, 128, 128)
			result.art_pose_quality = "authored key pose"
			result["secondary_body_response"] = 0.0 # Painted heads are never warped.
			result["secondary_body_lean"] = 0.0
			result["gait_counterbalance"] = 0.0
			return result
	var looping := bool(motions.actions[action].loop)
	var cursor := fposmod(phase,1.0)*PHASES if looping else clampf(phase,0,1)*(PHASES-1)
	var slot := mini(PHASES-1,floori(cursor))
	var next_slot := (slot+1)%PHASES if looping else mini(slot+1,PHASES-1)
	var stride_weight := 1.0
	if action in ["walk","sprint"]:
		stride_weight = clampf(Vector2(state.velocity_x,state.velocity_y).length()/MovementTuning.BASE_SPEED,0,1)
	# Only unmodified locomotion is cached. Continuous cast/stride parameters
	# never multiply the cache key space or allocate a new GPU mesh each frame.
	var secondary_motion := not reduced_motion
	var key := "%s/%s/%d/%d/%d/%d/%d" % [id,action,aim,facing,travel,slot,int(secondary_motion)]
	var pose_phase := float(slot)/(PHASES if bool(motions.actions[action].loop) else PHASES-1)
	result["sample_phase"] = pose_phase
	result["mesh"] = cached_mesh(key,id,action,aim,travel,pose_phase,secondary_motion)
	var next_key := "%s/%s/%d/%d/%d/%d/%d" % [id,action,aim,facing,travel,next_slot,int(secondary_motion)]
	var next_phase := float(next_slot)/(PHASES if looping else PHASES-1)
	var next_mesh := cached_mesh(next_key,id,action,aim,travel,next_phase,secondary_motion)
	var blend := cursor-slot
	result["pose_blend"] = blend
	# Blend geometry, never ghost/crossfade differently facing textures. Exactly
	# one small vertex upload per changed actor pose; no mesh reconstruction or
	# GPU readback each frame. Repeated fog/afterimage draws reuse the same mesh.
	var render_key := "%s/%d/%d" % [id,state.entity_id,facing]
	var signature := key+"/"+next_key+"/"+str(blend)+"/"+str(seconds)+"/"+str(casting)+"/"+str(cast_phase)+"/"+str(cast_weight)+"/"+str(stride_weight)
	if render_meshes.has(render_key) and render_meshes[render_key].signature == signature:
		result["render_mesh"] = render_meshes[render_key].mesh
	else:
		var continuous := PackedVector3Array()
		if casting or stride_weight < 1.0:
			# Sample the actual cast envelope and speed, not eight arm poses and
			# five stride/recovery levels. Fixed bones and authored bounds remain.
			var exact_phase := fposmod(phase,1.0) if looping else clampf(phase,0,1)
			continuous = build_vertices(id,action,aim,travel,exact_phase,casting,cast_phase,cast_weight,stride_weight,secondary_motion)
		result["render_mesh"] = interpolate_mesh(render_key,signature,result.mesh,next_mesh,blend,seconds,action,continuous)
	result["independent_cast_pose"] = casting
	result["stride_weight"] = stride_weight
	result["cast_weight"] = cast_weight if casting else 0.0
	result["secondary_body_response"] = secondary_pose_amount(action,phase) if secondary_motion else 0.0
	result["secondary_body_lean"] = locomotion_lean_radians(action,phase,travel,stride_weight) if secondary_motion else 0.0
	result["gait_counterbalance"] = gait_counterbalance_radians(action,phase,travel,stride_weight) if secondary_motion else 0.0
	return result


func cached_mesh(key: String, id: String, action: String, aim: int, travel: int, phase: float, secondary_motion: bool = true) -> ArrayMesh:
	if not meshes.has(key):
		var mesh := build_mesh(id,action,aim,travel,phase,false,0.0,1.0,1.0,secondary_motion)
		if mesh_order.size() >= CACHE_LIMIT: meshes.erase(mesh_order.pop_front())
		meshes[key] = mesh
		mesh_order.append(key)
	return meshes[key]


func interpolate_mesh(key: String, signature: String, first: ArrayMesh, second: ArrayMesh, blend: float, seconds: float, action: String, continuous: PackedVector3Array = PackedVector3Array()) -> ArrayMesh:
	var entry: Dictionary = render_meshes.get(key,{})
	if not entry.is_empty() and entry.signature == signature: return entry.mesh
	var a: PackedVector3Array = first.get_meta("cpu_vertices")
	var b: PackedVector3Array = second.get_meta("cpu_vertices")
	var vertices := continuous
	if vertices.is_empty():
		vertices.resize(a.size())
		for index: int in a.size(): vertices[index] = a[index].lerp(b[index],clampf(blend,0,1))
	# Only ordinary locomotion may settle between clips. Low/air/defeat/control
	# poses are immediate so no visual smoothing disguises exposure or input.
	# Direction has its own buffer: never smear an old facing into a new one.
	if not entry.is_empty():
		var gap := seconds-float(entry.get("seconds",seconds))
		var ordinary := action in ["idle","walk","sprint"] and String(entry.get("action","")) in ["idle","walk","sprint"]
		if gap <= 0.0 or gap > 0.1 or not ordinary:
			entry.erase("settle")
		elif entry.action != action:
			var previous: PackedVector3Array = entry.mesh.get_meta("cpu_vertices")
			var correction := PackedVector3Array()
			correction.resize(vertices.size())
			for index: int in vertices.size(): correction[index] = (previous[index]-vertices[index]).limit_length(5.0)
			entry.settle = correction
			entry.settle_start = seconds
		if entry.has("settle"):
			var weight := 1.0-smoothstep(0.0,LOCOMOTION_SETTLE_SECONDS,seconds-float(entry.settle_start))
			if weight <= 0.0: entry.erase("settle")
			else:
				var correction: PackedVector3Array = entry.settle
				for index: int in vertices.size(): vertices[index] += correction[index]*weight
	if entry.is_empty():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_TEX_UV] = first.get_meta("cpu_uvs")
		arrays[Mesh.ARRAY_INDEX] = first.get_meta("cpu_indices")
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
		mesh.custom_aabb = AABB(Vector3(-16,-16,-1),Vector3(160,160,2))
		entry = {"mesh":mesh}
		if render_order.size() >= RENDER_CACHE_LIMIT: render_meshes.erase(render_order.pop_front())
		render_order.append(key)
	else:
		(entry.mesh as ArrayMesh).surface_update_vertex_region(0,0,vertices.to_byte_array())
	entry.signature = signature
	entry.seconds = seconds
	entry.action = action
	entry.mesh.set_meta("cpu_vertices",vertices)
	render_meshes[key] = entry
	return entry.mesh


static func airborne_pose_phase(action: String, vertical_velocity: int) -> float:
	if action == "fall":
		return lerpf(0.15,0.85,clampf(-float(vertical_velocity)/MovementTuning.AIR_TERMINAL_FALL_SPEED,0,1))
	return lerpf(0.15,0.85,1.0-clampf(float(vertical_velocity)/MovementTuning.CHARGED_JUMP_VERTICAL_SPEED,0,1))


static func authored_row(action: String, phase: float) -> String:
	match action:
		"slide", "wavedash": return "slide_hold"
		"roll": return "roll_anticipation" if phase < 0.3 else "roll_tuck"
		"jumpsquat", "jump", "fall", "land": return {"jumpsquat":"jumpsquat", "jump":"jump_rise", "fall":"fall", "land":"land"}[action]
	return ""


static func vec(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2(value[0], value[1])


func sample(body: String, action: String, aim: int, travel: int, phase: float) -> Dictionary:
	var definition: Dictionary = motions.actions[action]
	var facing := travel if bool(definition.travel_facing) else aim
	var key := "%s/%d/%d" % [action, facing, travel if bool(definition.travel_matrix) else facing]
	var frames: Array = motions.bodies[body].clips[key]
	var cursor := phase * (frames.size() if bool(definition.loop) else frames.size()-1)
	var first := mini(frames.size()-1, floori(cursor))
	var second := (first+1)%frames.size() if bool(definition.loop) else mini(frames.size()-1, first+1)
	var previous := (first+frames.size()-1)%frames.size() if bool(definition.loop) else maxi(0,first-1)
	var after := (second+1)%frames.size() if bool(definition.loop) else mini(frames.size()-1,second+1)
	var points: Dictionary = {}
	for name: String in frames[first].points:
		var a: Vector2 = frames[first].points[name]
		var b: Vector2 = frames[second].points[name]
		var curved := a.cubic_interpolate(b,frames[previous].points[name],frames[after].points[name],cursor-first)
		# Continuous tangents between source keys, bounded by their authored
		# envelope: no new foot penetration or exaggerated limb excursion.
		points[name] = Vector2(clampf(curved.x,minf(a.x,b.x),maxf(a.x,b.x)),clampf(curved.y,minf(a.y,b.y),maxf(a.y,b.y)))
	return {"points":points, "rest":motions.bodies[body].rest[str(facing)], "facing":facing}


static func retarget(anchors: Dictionary, rest: Dictionary, target: Dictionary, gait: bool = false) -> Dictionary:
	# Fixed-length bones: no frame-dependent body/head scaling.
	var result: Dictionary = {}
	var origin := vec(anchors.pelvis)
	var turn: float = (target.neck-target.pelvis).angle()-(vec(rest.neck)-vec(rest.pelvis)).angle()
	result.pelvis = origin + (target.pelvis-vec(rest.pelvis)).limit_length(4)
	for name: String in ["neck","head","shoulder_l","shoulder_r","hip_l","hip_r"]:
		result[name] = result.pelvis + (vec(anchors[name])-origin).rotated(turn)
	for side: String in ["l","r"]:
		for chain: Array in [["shoulder_"+side,"elbow_"+side,"hand_"+side],["hip_"+side,"knee_"+side,"ankle_"+side,"toe_"+side]]:
			for i: int in range(chain.size()-1):
				var a: String = chain[i]
				var b: String = chain[i+1]
				var delta: float = (target[b]-target[a]).angle()-(vec(rest[b])-vec(rest[a])).angle()
				result[b] = result[a] + (vec(anchors[b])-vec(anchors[a])).rotated(delta)
		if gait:
			# Front/back keyframes express foot lift as projected shortening, not
			# a changed shin angle. Angle-only retargeting erased that information
			# and made both feet slide together. Reach the authored ankle with a
			# two-bone solve instead; neither bone nor skull changes its length.
			var hip := "hip_"+side
			var knee := "knee_"+side
			var ankle := "ankle_"+side
			var toe := "toe_"+side
			var lift: Vector2 = ((target[ankle]-target[hip])-(vec(rest[ankle])-vec(rest[hip]))).limit_length(5.0)
			var upper := vec(anchors[hip]).distance_to(vec(anchors[knee]))
			var lower := vec(anchors[knee]).distance_to(vec(anchors[ankle]))
			var reach: Vector2 = (vec(anchors[ankle])-vec(anchors[hip])).rotated(turn)+lift
			var length := clampf(reach.length(),absf(upper-lower)+0.001,upper+lower-0.001)
			var axis := reach.normalized() if reach.length_squared()>0.0001 else Vector2.DOWN
			result[ankle] = result[hip]+axis*length
			var bend := (vec(anchors[ankle])-vec(anchors[hip])).cross(vec(anchors[knee])-vec(anchors[hip]))
			var side_sign := signf(bend) if absf(bend)>0.01 else (-1.0 if side=="l" else 1.0)
			var along := (upper*upper-lower*lower+length*length)/(2.0*length)
			var across := sqrt(maxf(0.0,upper*upper-along*along))
			result[knee] = result[hip]+axis*along+Vector2(-axis.y,axis.x)*across*side_sign
			result[toe] = result[ankle]+(vec(anchors[toe])-vec(anchors[ankle])).rotated(turn)
	return result


func build_vertices(id: String, action: String, aim: int, travel: int, phase: float, casting: bool, cast_phase: float, cast_weight: float = 1.0, stride_weight: float = 1.0, secondary_motion: bool = true) -> PackedVector3Array:
	var entry: Dictionary = entries[id]
	var sampled := sample(entry.body, action, aim, travel, phase)
	var direction: Dictionary = entry.directions[DIRS[sampled.facing]]
	var anchors: Dictionary = direction.anchors
	var skin_key := "%s/%d" % [id,int(sampled.facing)]
	if not skin_tables.has(skin_key): skin_tables[skin_key]=compile_skin(direction)
	var skin: Dictionary = skin_tables[skin_key]
	if action in ["walk","sprint"] and stride_weight < 1.0:
		# Small decelerating steps instead of a full stride followed by a snap to
		# idle. Work on fresh sampled points, not the shared immutable motion bank.
		for joint: String in sampled.points:
			sampled.points[joint] = vec(sampled.rest[joint]).lerp(sampled.points[joint],stride_weight)
	var target := retarget(anchors, sampled.rest, sampled.points,action in ["walk","sprint","wallrun"])
	var body_response := secondary_pose_amount(action,phase) if secondary_motion else 0.0
	if body_response != 0.0:
		apply_secondary_pose(target,anchors,body_response,travel)
	if secondary_motion:
		apply_locomotion_lean(target,locomotion_lean_radians(action,phase,travel,stride_weight))
		apply_locomotion_lean(target,gait_counterbalance_radians(action,phase,travel,stride_weight))
	if casting:
		# Keep legs on their movement phase. Never rotate a low travel pose to aim.
		var cast_key := "%s/%d/%d" % [skin_key,aim,travel]
		var cast_target: Dictionary
		if cast_phase == 1.0 and cast_targets.has(cast_key): cast_target=cast_targets[cast_key]
		else:
			var cast_sample := sample(entry.body, "cast", aim, travel, cast_phase)
			cast_target = retarget(anchors, cast_sample.rest, cast_sample.points)
			if cast_phase == 1.0:
				if cast_target_order.size() >= CACHE_LIMIT: cast_targets.erase(cast_target_order.pop_front())
				cast_targets[cast_key]=cast_target
				cast_target_order.append(cast_key)
		blend_cast_arms(target,cast_target,cast_weight,secondary_motion and cast_phase == 1.0)
	var transforms: Array[Transform2D] = []
	for part_index: int in skin.parts.size():
		var a: String = skin.joint_a[part_index]
		var b: String = skin.joint_b[part_index]
		var pivot: Vector2 = skin.pivots[part_index]
		var rest_angle: float = skin.rest_angles[part_index]
		var rotation: float = (target[b]-target[a]).angle()-rest_angle
		# Skull stays rigid and legible; tails/capes do not whip through the torso.
		rotation *= skin.rotation_weights[part_index]
		var transform := Transform2D(rotation, target[a]) * Transform2D(0, -pivot)
		if part_index == skin.torso and body_response != 0.0:
			# Stretch only the chest bone, never the complete sprite or skull.
			# Mild reciprocal width gives a volume response without changing feet.
			var posed_axis: Vector2 = target[b]-target[a]
			var length_ratio := clampf(posed_axis.length()/maxf(1.0,float(skin.rest_lengths[part_index])),0.90,1.055)
			transform = Transform2D(posed_axis.angle(),target[a]) * Transform2D(0,Vector2(length_ratio,clampf(1.0/length_ratio,0.96,1.06)),0,Vector2.ZERO) * Transform2D(-rest_angle,Vector2.ZERO) * Transform2D(0,-pivot)
		transforms.append(transform)
	var vertices := PackedVector3Array()
	var points: PackedVector2Array = skin.points
	var primary: PackedInt32Array = skin.primary
	var secondary: PackedInt32Array = skin.secondary
	var weights: PackedFloat64Array = skin.weights
	var limit := 7.0 if action in ["walk","sprint","wallrun"] else 12.0
	vertices.resize(points.size())
	for index: int in points.size():
		var point := points[index]
		var a := transforms[primary[index]]
		var b := transforms[secondary[index]]
		var moved: Vector2 = (b*point).lerp(a*point,weights[index])
		# Restrained deformation protects the original silhouette while more
		# authored joint/occlusion corrections are added. Never fake a scaled head.
		moved = point + (moved-point).limit_length(limit)
		vertices[index]=Vector3(moved.x+16, moved.y+20, 0)
	return vertices


static func compile_skin(direction: Dictionary, occupied: Rect2 = Rect2()) -> Dictionary:
	var parts: Array = direction.bindings.keys()
	var torso := parts.find("torso")
	var source_indices := PackedInt32Array()
	var triangles := PackedInt32Array()
	var admitted: Dictionary = {}
	for y: int in 16:
		for x: int in 16:
			var first := y*17+x
			var corner := vec(direction.vertices[first])
			if occupied.has_area() and not Rect2(corner,Vector2(8,8)).intersects(occupied,true): continue
			for original: int in [first,first+1,first+17,first+1,first+18,first+17]:
				if not admitted.has(original):
					admitted[original]=source_indices.size()
					source_indices.append(original)
				triangles.append(admitted[original])
	var points := PackedVector2Array()
	var primary := PackedInt32Array()
	var secondary := PackedInt32Array()
	var weights := PackedFloat64Array()
	for original: int in source_indices:
		var vertex: Array = direction.vertices[original]
		points.append(Vector2(vertex[0],vertex[1]))
		var first := parts.find(vertex[2])
		var second := parts.find(vertex[3])
		primary.append(first if first>=0 else torso)
		secondary.append(second if second>=0 else torso)
		weights.append(float(vertex[4]))
	var joint_a: Array[String] = []
	var joint_b: Array[String] = []
	var pivots := PackedVector2Array()
	var rest_angles := PackedFloat64Array()
	var rest_lengths := PackedFloat64Array()
	var rotation_weights := PackedFloat64Array()
	for part: String in parts:
		var binding: Array = direction.bindings[part]
		joint_a.append(binding[0])
		joint_b.append(binding[1])
		var pivot := vec(direction.anchors[binding[0]])
		var axis := vec(direction.anchors[binding[1]])-pivot
		pivots.append(pivot)
		rest_angles.append(axis.angle())
		rest_lengths.append(axis.length())
		rotation_weights.append(0.0 if part=="head" else (0.3 if part.begins_with("appendage_") else 1.0))
	return {"parts":parts,"torso":torso,"points":points,"primary":primary,"secondary":secondary,"weights":weights,
		"source_indices":source_indices,"indices":triangles,"joint_a":joint_a,"joint_b":joint_b,"pivots":pivots,
		"rest_angles":rest_angles,"rest_lengths":rest_lengths,"rotation_weights":rotation_weights}


func build_mesh(id: String, action: String, aim: int, travel: int, phase: float, casting: bool, cast_phase: float, cast_weight: float = 1.0, stride_weight: float = 1.0, secondary_motion: bool = true) -> ArrayMesh:
	var vertices := build_vertices(id,action,aim,travel,phase,casting,cast_phase,cast_weight,stride_weight,secondary_motion)
	var facing := travel if bool(motions.actions[action].travel_facing) else aim
	var skin: Dictionary = skin_tables["%s/%d" % [id,facing]]
	var uvs := PackedVector2Array()
	for point: Vector2 in skin.points:
		uvs.append((point+ORIGIN+Vector2(facing*128,0))/Vector2(1024,128))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = skin.indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.set_meta("cpu_vertices",vertices)
	mesh.set_meta("cpu_uvs",uvs)
	mesh.set_meta("cpu_indices",skin.indices)
	return mesh


static func blend_cast_arms(target: Dictionary, cast_target: Dictionary, weight: float, follow_through: bool = false) -> void:
	# Blend rotations, not joint positions: opposing endpoints can collapse an
	# elbow/hand segment and flip its angle during recovery. Keep both authored
	# bone lengths; only the arms change, never legs, pelvis, aim or simulation.
	# During the existing recovery window, the elbow returns first and the
	# hand follows. Both weights stay within0..1 with exactly unchanged ends.
	var hand_weight := weight + 0.5 * weight * (1.0-weight) if follow_through else weight
	for side: String in ["l","r"]:
		var shoulder := "shoulder_"+side
		var elbow := "elbow_"+side
		var hand := "hand_"+side
		var upper: Vector2 = target[elbow]-target[shoulder]
		var lower: Vector2 = target[hand]-target[elbow]
		var cast_upper: Vector2 = cast_target[elbow]-cast_target[shoulder]
		var cast_lower: Vector2 = cast_target[hand]-cast_target[elbow]
		target[elbow] = target[shoulder]+Vector2.from_angle(lerp_angle(upper.angle(),cast_upper.angle(),weight))*upper.length()
		target[hand] = target[elbow]+Vector2.from_angle(lerp_angle(lower.angle(),cast_lower.angle(),hand_weight))*lower.length()


static func secondary_pose_amount(action: String, phase: float) -> float:
	var t := clampf(phase,0.0,1.0) if is_finite(phase) else 0.0
	match action:
		# Readable gather/contact holds, not a perpetual squash oscillator. The
		# action/plane is still immediate; only existing pose progress is shaped.
		"jumpsquat": return MAX_BODY_COMPRESSION_PIXELS * 0.85 * smoothstep(0.0,1.0,t)
		"land": return MAX_BODY_COMPRESSION_PIXELS * (1.0-smoothstep(0.12,0.88,t))
		"jump", "double_jump", "walljump", "slide_jump": return -MAX_BODY_EXTENSION_PIXELS * (1.0-smoothstep(0.22,0.70,t))
	return 0.0


static func locomotion_lean_radians(action: String, phase: float, travel: int, stride_weight: float = 1.0) -> float:
	var degrees := 0.0
	match action:
		"walk": degrees = WALK_LEAN_DEGREES
		"sprint": degrees = SPRINT_LEAN_DEGREES
		"wallrun": degrees = WALLRUN_LEAN_DEGREES
		_: return 0.0
	var t := fposmod(phase,1.0) if is_finite(phase) else 0.0
	var strength := clampf(stride_weight,0.0,1.0) if is_finite(stride_weight) else 0.0
	var heading := Vector2(EightDirectionResolver.FIXED_VECTORS[clampi(travel,0,7)]).normalized()
	# Two contacts per stride. Front/back projection stays symmetric instead
	# of inventing a sideways lean; authored alternating feet provide its gait.
	var contact := 0.82 + 0.18 * cos(t * TAU * 2.0)
	return deg_to_rad(degrees) * heading.x * contact * strength


static func gait_counterbalance_radians(action: String, phase: float, travel: int, stride_weight: float = 1.0) -> float:
	var degrees := 0.0
	match action:
		"walk": degrees = 1.6
		"sprint": degrees = MAX_GAIT_COUNTERBALANCE_DEGREES
		"wallrun": degrees = 2.0
		_: return 0.0
	var t := fposmod(phase,1.0) if is_finite(phase) else 0.0
	var strength := clampf(stride_weight,0.0,1.0) if is_finite(stride_weight) else 0.0
	var heading := Vector2(EightDirectionResolver.FIXED_VECTORS[clampi(travel,0,7)]).normalized()
	# Transfer the chest over alternating support feet, once per full stride.
	# Project along travel (not aim); side-on travel already has forward lean.
	# Only rigid upper-body chains move: no new pelvis bob or planted-foot slip.
	return deg_to_rad(degrees) * cos(t*TAU) * heading.y * strength


static func apply_locomotion_lean(target: Dictionary, radians: float) -> void:
	if not is_finite(radians) or is_zero_approx(radians): return
	var angle := clampf(radians,-deg_to_rad(WALLRUN_LEAN_DEGREES),deg_to_rad(WALLRUN_LEAN_DEGREES))
	var pelvis: Vector2 = target.pelvis
	var skull: Vector2 = target.head-target.neck
	# Rotate only the upper-body chain: every arm/torso segment keeps its
	# length, the head keeps its orientation, and planted feet remain exact.
	for joint: String in ["neck","shoulder_l","shoulder_r","elbow_l","elbow_r","hand_l","hand_r"]:
		target[joint] = pelvis + (target[joint]-pelvis).rotated(angle)
	target.head = target.neck + skull


static func apply_secondary_pose(target: Dictionary, anchors: Dictionary, amount: float, travel: int) -> void:
	# Secondary upper-body inertia is attached to the pelvis. Existing authored
	# lower-body anticipation/IK remains intact: no foot slip or extra jump height.
	var response := clampf(amount,-MAX_BODY_EXTENSION_PIXELS,MAX_BODY_COMPRESSION_PIXELS)
	var heading := Vector2(EightDirectionResolver.FIXED_VECTORS[clampi(travel,0,7)]).normalized()
	var inertia := -heading * absf(response) * 0.18
	var shift := Vector2(inertia.x,response+inertia.y*0.25)
	target.neck += shift
	target.head += shift # Rigid translation: all heads keep their original size.
	for side: String in ["l","r"]:
		var shoulder := "shoulder_"+side
		var outward := signf(vec(anchors[shoulder]).x-vec(anchors.neck).x)
		var arm_shift := shift+Vector2(outward*maxf(0.0,response)*0.10,0.0)
		for joint: String in [shoulder,"elbow_"+side,"hand_"+side]:
			target[joint] += arm_shift


static func draw_frame(canvas: CanvasItem, frame: Dictionary, anchor: Vector2, tint: Color = Color.WHITE) -> void:
	if frame.get("pixel_body_pilot",false):
		PixelFlipbook.draw_frame(canvas,frame,anchor,tint)
		return
	var at := anchor-PIVOT
	if frame.has("mesh"):
		canvas.draw_mesh(frame.get("render_mesh",frame.mesh), frame.texture, Transform2D(0, at), tint)
	else:
		var source: Rect2 = frame.source_region
		var scale: float = frame.get("texel_scale", 1)
		canvas.draw_texture_rect_region(frame.texture, Rect2(at,CELL), Rect2(source.position*scale, source.size*scale), tint)
