extends FluxTestSuite


func run() -> int:
	_test_slide_facing()
	_test_clearance_cues()
	_test_jumpsquat()
	_test_guide()
	return finish("movement-checkpoint1-visuals")


func _test_slide_facing() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads")
	var presenter := CartoonChampionPresenter.new()
	check(presenter.configure(language), "live presenter loads: " + presenter.last_error)
	if not presenter.wireframe_body.ready():
		return
	var examples: Dictionary = {}
	for id: String in presenter.champions:
		examples[String(presenter.champions[id]["body_type"])] = id
	var config := SimConfig.new(120)
	for size: String in examples:
		for travel_index: int in 8:
			var travel: Vector2i = EightDirectionResolver.FIXED_VECTORS[travel_index]
			for aim_index: int in 8:
				var aim: Vector2i = EightDirectionResolver.FIXED_VECTORS[aim_index]
				var state := PlayerState.new()
				state.movement_mode = PlayerState.MovementMode.SLIDE
				state.slide_ticks = 12
				state.velocity_x = travel.x * 300
				state.velocity_y = travel.y * 300
				state.slide_x = travel.x
				state.slide_y = travel.y
				state.aim_x = aim.x
				state.aim_y = aim.y
				var before := state.canonical_values()
				var frame := presenter.movement_frame(String(examples[size]), state, 0, config)
				equal(frame.get("source_region"), WireframeBodyPresenter.base_region("slide", travel_index), "every size slides in actual travel direction independently of cursor")
				equal(frame.get("scale"), Vector2.ONE, "slide never stretches body")
				state.velocity_x = 0
				state.velocity_y = 0
				equal(CartoonChampionPresenter.presentation_facing_vector(state, "slide"), travel, "near rest retains the admitted lane")
				state.velocity_x = travel.x * 300
				state.velocity_y = travel.y * 300
				equal(state.canonical_values(), before, "visual sampling leaves authority unchanged")


func _test_clearance_cues() -> void:
	var config := SimConfig.new(120)
	var state := PlayerState.new()
	state.air_height = MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT + 1000
	state.air_vertical_velocity = 100000
	state.hop_mode = PlayerState.MovementMode.HOP
	state.hop_ticks = 20
	state.movement_commitment_ticks = config.milliseconds_to_ticks(MovementTuning.HOP_COMMITMENT_MS)
	check(JumpPresentation.height_contract(state, config)["above"], "above clearance shows upward height cue")
	check(not JumpPresentation.sample(state, config).protection_active, "height is not universal dodge protection")
	check(JumpPresentation.takeoff_contract(state, config)["active"], "takeoff cue works without jump invulnerability timer")
	state.wall_skim_ticks = 10
	state.movement_mode = PlayerState.MovementMode.WALL_SKIM
	check(not JumpPresentation.height_contract(state, config)["active"], "elevated wallrun never shows clearance protection")
	state.wall_skim_ticks = 0
	state.movement_mode = PlayerState.MovementMode.IDLE
	state.air_height = 0
	state.air_vertical_velocity = 0
	state.hop_ticks = 0
	state.crouching = true
	var low := JumpPresentation.height_contract(state, config)
	check(low["active"] and not low["above"], "crouch receives downward cue only")
	state.crouching = false
	check(not JumpPresentation.height_contract(state, config)["active"], "ordinary grounded pose has no height cue")


func _test_jumpsquat() -> void:
	var config := SimConfig.new(120)
	var state := PlayerState.new()
	state.jumpsquat_active = true
	var previous := 0
	for tick: int in range(40):
		state.jumpsquat_ticks = tick
		var depth := JumpPresentation.squat_depth(state, config)
		check(depth >= previous and depth <= 5, "jumpsquat deepens once to a bounded pixel pose")
		previous = depth
	check(not JumpPresentation.height_contract(state, config)["active"], "jumpsquat is not low-profile evasion")
	state.jumpsquat_active = false
	equal(JumpPresentation.squat_depth(state, config), 0, "release removes anticipation immediately")


func _test_guide() -> void:
	var jump := MovementGuideModel.entry_by_id("jump")
	check("release" in String(jump["execution"]), "guide explains release-to-jump")
	equal(jump["protection_ms"], 0, "guide does not promise obsolete jump immunity")
	var wall := MovementGuideModel.entry_by_id("wall_run")
	equal(wall["action"], "jump", "wallrun guide uses held Jump binding")
	var slide := MovementGuideModel.entry_by_id("slide")
	equal(slide["protection_ms"], 0, "guide does not promise obsolete slide immunity")
	equal(MovementGuideModel.compact_cells(slide)[4], "Low profile", "table distinguishes clearance from shield immunity")
