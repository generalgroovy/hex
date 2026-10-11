extends FluxTestSuite

const Fullbody = preload("res://src/presentation/fullbody_cast_presenter.gd")
const Aerial = preload("res://src/presentation/pixel_aerial_pose.gd")


func run() -> int:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "aerial identity test loads live spells")
	var catalog := ChampionCatalog.new()
	check(catalog.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "aerial identity test loads all real flight capabilities")
	var presenter := Fullbody.new()
	var ids := catalog.ordered_champion_ids()
	check(presenter.configure(ids), "original fullbody bank remains admitted")
	check(presenter.enable_pixel_pilot(ids, true), "native pixel bank and additive poses load atomically")
	if presenter.pixel_pilot == null: return finish("pixel-aerial-pose")
	var config := SimConfig.new(120)
	var flyers := 0
	for id: String in ids:
		var state := PlayerState.new(19)
		check(catalog.apply_to_player(state, id), "actual identity supplies flight eligibility")
		state.spawn_protection_ticks = 0
		state.hop_ticks = 40
		state.air_height = 24_000
		state.air_vertical_velocity = MovementTuning.JUMP_VERTICAL_SPEED
		state.hop_mode = PlayerState.MovementMode.HOP
		state.movement_mode = PlayerState.MovementMode.HOP
		var profile: Dictionary = presenter.pixel_pilot.aerial_profiles[id]
		var original_pixels: Image = (profile.texture as Texture2D).get_image()
		if state.flight_capable: flyers += 1
		for facing: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			state.aim_x = facing.x
			state.aim_y = facing.y
			state.velocity_x = -facing.x * 200
			state.velocity_y = -facing.y * 200
			for reduced: bool in [false, true]:
				var before := state.canonical_values()
				var first: Dictionary = presenter.frame(id, state, 0, config, 0.0, reduced)
				equal(first.get("aerial_pose", ""), "" if state.flight_capable else "tucked_ball", "first grounded jump never advertises airborne flight; non-fliers visibly tuck")
				state.hop_mode = PlayerState.MovementMode.DOUBLE_JUMP
				var second_before := state.canonical_values()
				var second: Dictionary = presenter.frame(id, state, 10, config, 0.0, reduced)
				var unrelated_clock: Dictionary = presenter.frame(id, state, 9999, config, 0.0, reduced)
				equal(second.get("pixel_parts", []), unrelated_clock.get("pixel_parts", []), "global rendering time cannot rotate or flap an unchanged authoritative pose")
				equal(second.get("aerial_pose", ""), "" if state.flight_capable else "tucked_ball", "DOUBLE_JUMP enum alone cannot fabricate flight")
				if not state.flight_capable:
					check((second.components as Array).is_empty(), "tucked ball has no hidden upright whole-body blit")
					check(second.display_height <= 50, "tucked body is compact for every body tier")
					var source: Rect2 = second.source_region
					var destination: Rect2 = second.head_destination
					equal(source.size, destination.size, "identity face keeps native pixels without scaling")
					check(original_pixels.get_region(Rect2i(source)).get_used_rect().has_area(), "all eight identity head crops contain original pixels")
					equal(second.texture, profile.texture, "aerial pose borrows the already admitted identity texture")
					state.air_vertical_velocity = MovementTuning.JUMP_VERTICAL_SPEED - MovementTuning.VERTICAL_GRAVITY / 6
					var rolled: Dictionary = presenter.frame(id, state, 10, config, 0.0, reduced)
					equal(int(rolled.pose_key), 0 if reduced else 1, "physical lift progress advances a slow held key while reduced motion holds upright")
					if not reduced: check(second.pixel_parts != rolled.pixel_parts, "real vertical progress changes the native tuck rather than an unrelated global clock")
					state.air_vertical_velocity = -200_000
					var descent: Dictionary = presenter.frame(id, state, 10, config, 0.0, reduced)
					equal(descent.action, "fall", "descent keeps its truthful public movement action")
					check(descent.get("second_jump_tuck", false), "the second-jump fold and reverse turn survive the apex into descent")
					state.air_vertical_velocity = MovementTuning.JUMP_VERTICAL_SPEED
					equal(second.get("aim_index"), EightDirectionResolver.classify_index(facing.x, facing.y), "tuck never delays immediate aiming")
					equal(second.get("travel_index"), EightDirectionResolver.classify_index(-facing.x, -facing.y), "tuck does not reinterpret independent travel")
					equal(second.pixel_shapes.size(), 0, "tuck has no filled backing disc or rectangular panel")
					for part: Dictionary in second.pixel_parts:
						for mesh: Dictionary in part.meshes:
							for point: Vector2 in mesh.points:
								check(point.distance_to(Vector2(0,-float(second.display_height)/2.0)) <= float(second.display_height)/2.0+0.75, "every native torso/cape/limb pixel is clipped to the compact round envelope")
					equal(second.pixel_parts.size(), 4, "tuck retains native torso, two folded limbs and original face")
				equal(state.canonical_values(), second_before, "pose queries never grant flight, alter jump or spend resources")
				state.hop_mode = PlayerState.MovementMode.HOP
				equal(state.canonical_values(), before, "test restores exact first-jump authority before the next view")
		_test_pose_clock(state, config)
		state.hop_ticks = 0
		state.air_height = 0
		state.air_vertical_velocity = 0
		state.landing_ticks = 1
		var landed: Dictionary = presenter.frame(id, state, 9999, config, 0.0)
		check(landed.get("aerial_pose", "").is_empty(), "physical landing removes the ball immediately without waiting for a visual rotation")
		state.landing_ticks = 0
		if not state.flight_capable:
			_test_ball_keys(id, profile)
		if state.flight_capable:
			_test_flight_clock(presenter, id, state, config)
	check(flyers > 0 and flyers < ids.size(), "all-roster matrix contains both real flight and non-flight identities")
	equal(ids.size(), 30, "aerial matrix covers the current complete roster")
	check(Aerial.frame("unknown", {}, "jump", 0, 0, 0, 0, false).is_empty(), "missing identity fails closed")
	equal(Aerial.pose_ticks(null, config), 0.0, "missing actor cannot produce a non-finite physical pose phase")
	var invalid_state := PlayerState.new(77)
	invalid_state.air_floating = true
	invalid_state.flight_capable = true
	invalid_state.float_ticks = 1
	equal(Aerial.pose_ticks(invalid_state, null), 0.0, "missing configuration fails closed before any time conversion")
	equal(Aerial.pose_ticks(invalid_state, SimConfig.new(0)), 0.0, "invalid zero-rate configuration cannot divide the flight phase by zero")
	return finish("pixel-aerial-pose")


func _test_pose_clock(state: PlayerState, config: SimConfig) -> void:
	state.air_floating = false
	state.float_ticks = 0
	state.air_height = 24_000
	state.air_vertical_velocity = MovementTuning.JUMP_VERTICAL_SPEED
	for origin: int in [PlayerState.MovementMode.HOP, PlayerState.MovementMode.DOUBLE_JUMP, PlayerState.MovementMode.SLIDE_JUMP, PlayerState.MovementMode.WALL_KICK]:
		state.hop_mode = origin
		for stale_cooldown: int in [0, 1, config.milliseconds_to_ticks(MovementTuning.HOP_COOLDOWN_MS)]:
			state.hop_cooldown_ticks = stale_cooldown
			equal(Aerial.pose_ticks(state, config), 0.0, "fresh physical lift starts upright regardless of stale hop cooldown or jump origin")
		state.air_vertical_velocity = MovementTuning.JUMP_VERTICAL_SPEED - MovementTuning.VERTICAL_GRAVITY / 4
		equal(Aerial.pose_ticks(state, config), 15.0, "quarter-second physical velocity progress selects the same pose phase for every jump origin")
		state.air_vertical_velocity = MovementTuning.JUMP_VERTICAL_SPEED
	state.air_vertical_velocity = MovementTuning.CHARGED_JUMP_VERTICAL_SPEED
	equal(Aerial.pose_ticks(state, config), 0.0, "charged rise remains on the upright entry key instead of fabricating negative elapsed time")
	var before := state.canonical_values()
	Aerial.pose_ticks(state, config)
	equal(state.canonical_values(), before, "physical pose clock reads never alter cooldown, launch speed or resources")


func _test_ball_keys(id: String, profile: Dictionary) -> void:
	# This is an explicit descriptor-clock sweep, not a claim that a normal
	# physical hop lasts the full800ms presentation envelope.
	for sample: Array in [[0.0,0],[8.999,0],[9.0,1],[20.999,1],[21.0,2],[32.999,2],[33.0,3],[48.0,3],[999.0,3]]:
		var phase := float(sample[0])
		var expected := int(sample[1])
		var frame: Dictionary = Aerial.frame(id, profile, "jump", 0, 0, phase, 200_000, false)
		equal(int(frame.pose_key), expected, "native somersault holds its declared key and never loops after terminal descent")
		var reduced: Dictionary = Aerial.frame(id, profile, "jump", 0, 0, phase, 200_000, true)
		equal(int(reduced.pose_key), 0, "reduced motion holds a stable upright tuck through the entire descriptor envelope")
		var fast: Dictionary = Aerial.frame(id, profile, "fast_fall", 0, 0, phase, -1_000_000, false)
		equal(int(fast.pose_key), 3, "fast fall has an immediate fixed descent key independent of the presentation clock")
	var first: Dictionary = Aerial.frame(id, profile, "jump", 0, 0, 9, 200_000, false)
	var second: Dictionary = Aerial.frame(id, profile, "double_jump", 0, 0, 9, 200_000, false)
	check(first.pixel_parts != second.pixel_parts, "first and repeated jump have visibly different native fold and turn geometry at the same facing and phase")
	var first_fall: Dictionary = Aerial.frame(id, profile, "fall", 0, 0, 21, -200_000, false)
	var second_fall: Dictionary = Aerial.frame(id, profile, "fall", 0, 0, 21, -200_000, false, true)
	check(first_fall.frame_id != second_fall.frame_id, "descriptor identity distinguishes the repeated-jump fold even when both public actions are fall")


func _test_flight_clock(presenter: RefCounted, id: String, state: PlayerState, config: SimConfig) -> void:
	state.hop_ticks = 40
	state.air_height = 24_000
	state.air_vertical_velocity = 0
	state.stamina = state.stamina_maximum
	state.air_floating = true
	state.hop_mode = PlayerState.MovementMode.DOUBLE_JUMP
	var duration := config.milliseconds_to_ticks(state.float_max_duration_ms)
	state.float_ticks = duration
	var before := state.canonical_values()
	var first: Dictionary = presenter.frame(id, state, 900, config, 0.0)
	var clock_only: Dictionary = presenter.frame(id, state, 1900, config, 0.0)
	equal(first.pixel_parts, clock_only.pixel_parts, "flight keys follow paid budget progress instead of unrelated global rendering time")
	equal(Aerial.pose_ticks(state, config), 0.0, "fresh flight budget starts its first wing key")
	equal(state.canonical_values(), before, "flight pose and clock queries preserve complete authority")
	state.float_ticks = duration - 23
	var held: Dictionary = presenter.frame(id, state, 900, config, 0.0)
	equal(first.pixel_parts, held.pixel_parts, "wing key holds through the last native sample before200ms")
	state.float_ticks = duration - 24
	var next: Dictionary = presenter.frame(id, state, 900, config, 0.0)
	check(first.pixel_parts != next.pixel_parts, "exact200ms of paid flight progress changes the wing key")
	equal(next.pixel_parts[1], first.pixel_parts[1], "wing key never changes the central original face and torso")
	var reduced_a: Dictionary = presenter.frame(id, state, 0, config, 0.0, true)
	state.float_ticks = duration - 48
	var reduced_b: Dictionary = presenter.frame(id, state, 999, config, 0.0, true)
	equal(reduced_a.pixel_parts, reduced_b.pixel_parts, "reduced motion retains a stable native open-wing silhouette as real flight budget advances")
	state.float_ticks = 1
	var last: Dictionary = presenter.frame(id, state, 0, config, 0.0)
	equal(last.get("aerial_pose"), "open_flight", "last positive flight tick still displays its actual flight state")
	check(not CartoonChampionPresenter.protection_contract(state, config).active, "flight cannot grant visual protection")
	for exit_kind: String in ["timer", "released", "exhausted", "grounded"]:
		state.float_ticks = 0 if exit_kind == "timer" else 1
		state.air_floating = exit_kind != "released"
		state.stamina = 0 if exit_kind == "exhausted" else state.stamina_maximum
		state.hop_ticks = 0 if exit_kind == "grounded" else 40
		state.air_height = 0 if exit_kind == "grounded" else 24_000
		state.air_vertical_velocity = 0 if exit_kind == "grounded" else 200_000
		var ended: Dictionary = presenter.frame(id, state, 11, config, 0.0)
		check(ended.get("aerial_pose", "") != "open_flight", "timer/release/exhaustion/landing removes flight on the exact query: " + exit_kind)
