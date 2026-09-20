extends FluxTestSuite


const MOVEMENT_ANIMATIONS := {
	PlayerState.MovementMode.IDLE: "idle",
	PlayerState.MovementMode.WALK: "walk",
	PlayerState.MovementMode.SPRINT: "sprint",
	PlayerState.MovementMode.HOP: "hop",
	PlayerState.MovementMode.DOUBLE_JUMP: "double_jump",
	PlayerState.MovementMode.SLIDE: "slide",
	PlayerState.MovementMode.SLIDE_JUMP: "slide_jump",
	PlayerState.MovementMode.AIR_DODGE: "air_dodge",
	PlayerState.MovementMode.ROLL: "air_dodge",
	PlayerState.MovementMode.WAVE_DASH: "wavedash",
	PlayerState.MovementMode.WALL_KICK: "wall_kick",
	PlayerState.MovementMode.VAULT: "vault",
	PlayerState.MovementMode.SUPERGLIDE: "superglide",
	PlayerState.MovementMode.LAUNCHED: "hit",
	PlayerState.MovementMode.GRAPPLED: "fall",
	PlayerState.MovementMode.CHARGING: "sprint",
	PlayerState.MovementMode.STUNNED: "stunned",
	PlayerState.MovementMode.ROOTED: "rooted",
	PlayerState.MovementMode.SLOWED: "walk",
}


func run() -> int:
	_test_oh_tipi_candidate_loads_fail_closed()
	_test_animation_and_direction_mapping()
	_test_clock_and_action_frame_equivalence()
	_test_sync_preserves_authority()
	_test_pivot_destination()
	return finish("wellspring-character-sprite")


func _test_oh_tipi_candidate_loads_fail_closed() -> void:
	var sprite := WellspringCharacterSprite.new()
	check(sprite.set_champion("oh_tipi"), "Oh Tipi integrated candidate loads: %s" % sprite.last_error)
	check(sprite.texture != null, "Oh Tipi atlas resolves as a texture")
	equal(sprite.texture.get_size(), Vector2(1920, 2560), "Oh Tipi atlas has the v2 dimensions")
	equal(sprite.animation_lookup.size(), 25, "Oh Tipi exposes every required animation")
	equal(sprite.region_rect.size, Vector2(WellspringCharacterSprite.CELL_SIZE), "runtime region uses one exact character cell")
	check(not sprite.set_champion("missing_champion"), "unknown champion fails closed")
	check(sprite.texture == null, "failed source cannot retain a stale champion texture")
	check(not sprite.region_enabled, "failed source disables its stale atlas region")
	sprite.free()


func _test_animation_and_direction_mapping() -> void:
	var state := PlayerState.new()
	for mode: int in MOVEMENT_ANIMATIONS:
		state.control_state = PlayerState.ControlState.FREE
		state.landing_ticks = 0
		state.movement_mode = mode
		equal(WellspringCharacterSprite.animation_id_for_player(state), MOVEMENT_ANIMATIONS[mode], "movement mode %d maps to its semantic animation" % mode)
	state.control_state = PlayerState.ControlState.STUNNED
	equal(WellspringCharacterSprite.animation_id_for_player(state), "stunned", "control-state stun overrides movement animation")
	state.control_state = PlayerState.ControlState.ROOTED
	equal(WellspringCharacterSprite.animation_id_for_player(state), "rooted", "control-state root overrides movement animation")
	state.control_state = PlayerState.ControlState.FREE
	state.movement_mode = PlayerState.MovementMode.IDLE
	state.landing_ticks = 3
	equal(WellspringCharacterSprite.animation_id_for_player(state), "land", "landing timer selects landing animation")

	var directions := [
		[Vector2i(0, 1000), 0], [Vector2i(707, 707), 1],
		[Vector2i(1000, 0), 2], [Vector2i(707, -707), 3],
		[Vector2i(0, -1000), 4], [Vector2i(-707, -707), 5],
		[Vector2i(-1000, 0), 6], [Vector2i(-707, 707), 7],
	]
	for definition: Array in directions:
		var direction: Vector2i = definition[0]
		equal(WellspringCharacterSprite.direction_index_from_vector(direction.x, direction.y), definition[1], "fixed facing %s resolves to manifest direction" % direction)
	equal(WellspringCharacterSprite.direction_index_from_vector(0, 0), 0, "zero facing fails safe to south")
	equal(WellspringCharacterSprite.direction_index_from_vector(1000, 300), 2, "shallow positive vector remains east")
	equal(WellspringCharacterSprite.direction_index_from_vector(-300, -1000), 4, "steep negative vector remains north")


func _test_clock_and_action_frame_equivalence() -> void:
	var first := WellspringCharacterSprite.new()
	var repeat := WellspringCharacterSprite.new()
	check(first.set_champion("oh_tipi"), "120 Hz sprite candidate loads")
	check(repeat.set_champion("oh_tipi"), "repeat 120 Hz sprite candidate loads")
	var walking := PlayerState.new()
	walking.movement_mode = PlayerState.MovementMode.WALK
	check(first.sync_from_player(walking, SimConfig.new(120), 60), "120 Hz loop sample synchronizes")
	check(repeat.sync_from_player(walking, SimConfig.new(120), 60), "repeat 120 Hz loop sample synchronizes")
	equal(first.current_frame, repeat.current_frame, "120 Hz loop frame selection is deterministic")
	equal(first.region_rect, repeat.region_rect, "120 Hz loop atlas region is deterministic")

	var jump_120 := _jump_state_at_half_phase(120)
	check(first.sync_from_player(jump_120, SimConfig.new(120), 16, 0.0), "120 Hz jump sample synchronizes")
	check(repeat.sync_from_player(jump_120, SimConfig.new(120), 16, 0.0), "repeat 120 Hz jump sample synchronizes")
	equal(first.animation_id, "hop", "jump selects hop animation")
	equal(first.current_frame, repeat.current_frame, "120 Hz normalized jump frame is deterministic")
	equal(first.region_rect, repeat.region_rect, "120 Hz normalized jump region is deterministic")
	first.free()
	repeat.free()


func _test_sync_preserves_authority() -> void:
	var sprite := WellspringCharacterSprite.new()
	check(sprite.set_champion("oh_tipi"), "authority test candidate loads")
	var state := PlayerState.new()
	state.position_x = 411_000
	state.position_y = 287_000
	state.radius = 21_000
	state.movement_mode = PlayerState.MovementMode.SLIDE_JUMP
	state.hop_mode = PlayerState.MovementMode.SLIDE_JUMP
	state.hop_ticks = SimConfig.new(120).milliseconds_to_ticks(MovementTuning.SLIDE_JUMP_DURATION_MS)
	var before := state.canonical_values()
	check(sprite.sync_from_player(state, SimConfig.new(120), 0), "authoritative state synchronizes for presentation")
	equal(state.canonical_values(), before, "sprite synchronization never mutates canonical values")
	equal(state.position_x, 411_000, "sprite synchronization preserves collision x")
	equal(state.position_y, 287_000, "sprite synchronization preserves collision y")
	equal(state.radius, 21_000, "sprite synchronization preserves collision radius")
	sprite.free()


func _test_pivot_destination() -> void:
	equal(WellspringCharacterSprite.canonical_body_type("size_1_tiny"), "small", "legacy tiny body maps to small")
	equal(WellspringCharacterSprite.canonical_body_type("medium"), "middle", "legacy medium body maps to middle")
	equal(WellspringCharacterSprite.canonical_body_type("huge"), "large", "legacy huge body maps to large")
	equal(WellspringCharacterSprite.legacy_size_id_for_body_type("small"), "size_2_small", "small maps to the retained small archive path")
	equal(WellspringCharacterSprite.legacy_size_id_for_body_type("middle"), "size_3_medium", "middle maps to the retained medium archive path")
	equal(WellspringCharacterSprite.legacy_size_id_for_body_type("large"), "size_4_large", "large maps to the retained large archive path")
	var destination := WellspringCharacterSprite.destination_rect(Vector2(100.0, 100.0))
	equal(destination.position, Vector2(68.0, 44.0), "body anchor maps to the exact (32,56) atlas pivot")
	equal(destination.size, Vector2(64.0, 64.0), "body draw uses one unscaled virtual-pixel cell")
	equal(destination.position + Vector2(WellspringCharacterSprite.PIVOT), Vector2(100.0, 100.0), "destination round-trips the body anchor")


func _jump_state_at_half_phase(tick_rate: int) -> PlayerState:
	var state := PlayerState.new()
	state.movement_mode = PlayerState.MovementMode.HOP
	state.hop_mode = PlayerState.MovementMode.HOP
	var total_ticks := SimConfig.new(tick_rate).milliseconds_to_ticks(MovementTuning.HOP_DURATION_MS)
	state.hop_ticks = total_ticks / 2
	return state
