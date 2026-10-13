extends CartoonChampionPresenter
## Frozen preceding wrapper and Fullbody frame preparation. This test-only
## presenter keeps legacy offsets, startup-definition copies and routing work.
## Common utility methods/assets are unchanged; compare complete descriptors.

class PrecedingFullbody:
	extends "res://src/presentation/fullbody_cast_presenter.gd"
	func frame(id: String, state: PlayerState, tick: float, config: SimConfig, locomotion_phase: float, reduced_motion: bool = false, wall_travel: Vector2i = Vector2i.ZERO, _cast_timing: Dictionary = {}) -> Dictionary:
		if not entries.has(id): return {}
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
				var charge := CombatTuning.cast_definition(state.pending_cast_wire_id)
				phase = clampf(1.0-float(state.pending_cast_ticks)/maxi(1,config.milliseconds_to_ticks(int(charge.get("startup_ms",0)))),0,1)
		elif action == "defeated": phase = 1.0
		var travel_facing := bool(motions.actions[action].get("travel_facing", false))
		var facing := travel if travel_facing else aim
		var casting := (state.pending_cast_wire_id > 0 or state.cast_recovery_ticks > 0) and action not in ["hit","stunned","defeated"]
		var cast_phase := 0.5
		var cast_weight := 1.0
		if state.pending_cast_wire_id > 0:
			var cast_definition := CombatTuning.cast_definition(state.pending_cast_wire_id)
			var startup := maxi(1,config.milliseconds_to_ticks(int(cast_definition.get("startup_ms",0))))
			cast_phase = clampf(1.0-float(state.pending_cast_ticks)/startup,0,1)
			cast_weight = smoothstep(0.0,0.35,cast_phase)
		elif state.cast_recovery_ticks > 0:
			cast_phase = 1.0
			cast_weight = smoothstep(0.0,1.0,clampf(float(state.cast_recovery_ticks)/maxi(1,config.milliseconds_to_ticks(90)),0,1))
		if pixel_pilot != null:
			var fixed_frame: Dictionary = pixel_pilot.frame(id,action,aim,travel,phase,casting,cast_weight,reduced_motion)
			if not fixed_frame.is_empty():
				return fixed_frame
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


func enable_fullbody_art(use_pixel_pilot: bool = false, use_full_cast: bool = false, bounded_residency: bool = false) -> bool:
	# Signature adapter only: this frozen oracle intentionally stays eager.
	if bounded_residency:
		last_error = "Frozen preceding renderer does not implement bounded residency"
		return false
	var candidate := PrecedingFullbody.new()
	if not candidate.configure(champions.keys()):
		last_error = candidate.last_error
		return false
	if (use_pixel_pilot or use_full_cast) and not candidate.enable_pixel_pilot(champions.keys(), use_full_cast):
		last_error = candidate.last_error
		return false
	fullbody_art = candidate
	configuration_generation += 1
	return true


func movement_frame(champion_id: String, state: PlayerState, presentation_tick: float, config: SimConfig, reduced_effects: bool = false, locomotion_phase: float = -1.0, wall_travel: Vector2i = Vector2i.ZERO, _cast_timing: Dictionary = {}) -> Dictionary:
	if state == null or config == null or not champions.has(champion_id):
		return {}
	var definition: Dictionary = champions[champion_id]
	var animation_state := silhouette_state(state)
	var motion_id := MinimalChampionMotion.motion_id(state)
	# Bare-hand cast effects remain separate. Moving casts must not freeze the
	# legs or replace an airborne/low silhouette with an upright aiming body.
	if animation_state in ["walk", "sprint"]:
		motion_id = animation_state
	elif animation_state in ["slide", "roll"]:
		motion_id = "low"
	elif animation_state == "jump":
		motion_id = "air"
	var motion_elapsed := preceding_elapsed_for_state(state, motion_id, presentation_tick, config)
	# Contact pose and secondary motion share one seeded phase. Previously the
	# opposite foot could be selected while the torso was still on contact A.
	if motion_id in ["walk", "sprint"]:
		if locomotion_phase >= 0.0 and is_finite(locomotion_phase):
			motion_elapsed = motion.locomotion_elapsed_at_phase(String(definition.get("motion_profile", "")), motion_id, locomotion_phase)
		else:
			# Pure preview/legacy callers without world travel history retain the
			# deterministic timed cycle; the live game supplies a distance phase.
			motion_elapsed += float(maxi(0, state.entity_id) * 3)
	var motion_sample := motion.sample(String(definition.get("motion_profile", "")), motion_id, motion_elapsed, reduced_effects)
	if motion_id in ["walk", "sprint"]:
		var response := movement_response_scale(state)
		motion_sample.offset *= response
		motion_sample.aura_scale = lerpf(1.0, motion_sample.aura_scale, response)
		_apply_relative_gait_motion(motion_sample, locomotion_gait(state), reduced_effects)
	# Foot plants retain their exact pivot; the between-contact motion is tiny
	# and smooth, never a scale pulse or blended directional atlas frame.
	var pose_offset := motion_sample.offset.round() if motion_id in ["cast", "hit"] else Vector2.ZERO
	if motion_id in ["walk", "sprint"]:
		pose_offset = motion.locomotion_pivot_offset(String(definition.get("motion_profile", "")), motion_id, motion_elapsed, Vector2(state.velocity_x, state.velocity_y), movement_response_scale(state), reduced_effects)
	var contact_frame := 0
	if animation_state in EXPECTED_PHASE_STATES:
		contact_frame = motion.locomotion_contact_frame(String(definition.get("motion_profile", "")), motion_id, motion_elapsed)
		if contact_frame == 1:
			animation_state += "_b"
	var result := {"animation_state": animation_state, "motion_id": motion_id, "contact_frame": contact_frame, "offset": pose_offset, "scale": Vector2.ONE, "aura_scale": motion_sample.aura_scale, "source_region": source_region_for_animation_state(champion_id, state, animation_state), "display_height": int(definition.get("height", 68))}
	result["squat_depth"] = JumpPresentation.squat_depth(state, config)
	if wireframe_mode and fullbody_art == null:
		var phase := locomotion_phase
		if phase < 0.0 or not is_finite(phase):
			var duration := motion.locomotion_elapsed_at_phase(String(definition.get("motion_profile", "")), motion_id, 0.5) * 2.0
			phase = motion_elapsed / maxf(1.0, duration)
		var body_travel := Vector2i(state.velocity_x, state.velocity_y)
		if animation_state == "slide":
			body_travel = presentation_facing_vector(state, animation_state)
		var body_frame := wireframe_body.frame(String(definition["body_type"]), animation_state, presentation_facing_vector(state, animation_state), body_travel, phase)
		if body_frame.is_empty():
			return {}
		result.merge(body_frame, true)
	if fullbody_art != null:
		result.merge(fullbody_art.frame(champion_id, state, presentation_tick, config, locomotion_phase, reduced_effects, wall_travel), true)
	return result


static func preceding_elapsed_for_state(state: PlayerState, motion_id_value: String, visual_tick: float, config: SimConfig) -> float:
	if state == null or config == null:
		return maxf(0.0, visual_tick)
	if motion_id_value == "air":
		var timer := MinimalChampionMotion._air_timer(state, config)
		if timer.y > 0:
			return float(timer.y - timer.x) * 60.0 / float(config.tick_rate)
	if motion_id_value == "cast" and state.pending_cast_wire_id > 0:
		var definition := CombatTuning.cast_definition(state.pending_cast_wire_id)
		var total := config.milliseconds_to_ticks(int(definition.get("startup_ms", 0)))
		if total > 0:
			return float(maxi(0, total - state.pending_cast_ticks)) * 60.0 / float(config.tick_rate)
	return maxf(0.0, visual_tick)
