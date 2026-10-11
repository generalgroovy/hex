extends FluxTestSuite
## Ground-contact presentation must not reinterpret a recovery timer as height.

const BODY_IDS := {"small": "s_wayne", "middle": "oh_tipi", "large": "red_baron"}


func run() -> int:
	var abilities := AbilityCatalog.new()
	var champions := ChampionCatalog.new()
	var admitted := abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json")
	check(admitted, "airborne landing fixtures load canonical abilities")
	if not admitted: return finish("landing-airborne-contact")
	admitted = champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities)
	check(admitted, "airborne landing fixtures load all three authored body profiles")
	if not admitted: return finish("landing-airborne-contact")
	for body: String in BODY_IDS:
		_test_paid_jump_and_recovery(champions, body)
		_test_grounded_recovery_and_roll(champions, body)
	_test_canonical_airborne_boundary()
	return finish("landing-airborne-contact")


func _test_paid_jump_and_recovery(champions: ChampionCatalog, body: String) -> void:
	var world := _world(champions, BODY_IDS[body])
	var untouched := _world(champions, BODY_IDS[body])
	var state := world.player()
	var stamina := state.stamina
	var flux := state.flux
	var health := state.health
	var radius := state.radius
	equal(radius, BodyTypeProfileCatalog.HURT_RADII[body], body + " fixture uses its actual authored hurt radius")
	_step_pair(world, untouched, SimCommand.PRESSED_JUMP)
	check(state.is_airborne() and state.air_height > 0, body + " ordinary tap starts a real physical jump")
	equal(state.stamina, stamina - MovementTuning.HOP_COST, body + " real jump pays the unchanged Stamina cost")
	equal(state.flux, flux, body + " movement does not spend spell Flux")
	for target: SimWorld in [world, untouched]:
		check(MovementSystem.apply_control_state(target.player(), PlayerState.ControlState.LAUNCHED, 50, Vector2i.RIGHT, 300000, target.config), body + " supported planar knockback starts during the real jump")
	var recovered_in_air := false
	for _index: int in 16:
		_step_pair(world, untouched)
		_assert_air_contact_hidden(state, world.config)
		if state.control_state != PlayerState.ControlState.LAUNCHED:
			recovered_in_air = state.is_airborne() and state.air_height > 0 and state.impact_recovery_ticks > 0 and state.landing_ticks > 0 and state.landing_intensity > 0
			break
	check(recovered_in_air, body + " actual launch expiry seeds impact/landing recovery while still physically aloft")
	if not recovered_in_air: return
	equal(state.last_event, "impact_recovery", body + " fixture reaches the real recovery transition, not an injected cue")
	var landed := false
	for _index: int in 120:
		_step_pair(world, untouched)
		if state.is_airborne():
			_assert_air_contact_hidden(state, world.config)
		else:
			landed = true
			break
	check(landed and state.air_height == 0 and state.air_vertical_velocity == 0, body + " the unchanged physical trajectory reaches exact floor contact")
	if not landed: return
	equal(state.last_event, "land", body + " real floor contact owns the new landing event")
	check(state.landing_ticks > 0 and state.landing_intensity > 0, body + " actual ground contact supplies its normal landing cue")
	_assert_ground_contact(state, world.config)
	equal(state.radius, radius, body + " sampling never changes hurtbox size")
	equal(state.health, health, body + " presentation never changes health")
	equal(state.flux, flux, body + " presentation never spends or refills spell Flux")
	equal(state.canonical_values(), untouched.player().canonical_values(), body + " sampled and unsampled authority remain identical through landing")
	for _index: int in 32:
		if state.landing_ticks <= 0: break
		_step_pair(world, untouched)
	equal(state.landing_ticks, 0, body + " real landing cue expires on the ordinary timer")
	for reduced: bool in [false, true]:
		_assert_inactive(LandingPresentation.sample(state, world.config, 0.5, reduced), "expired ground cue leaves no retained contact")


func _test_grounded_recovery_and_roll(champions: ChampionCatalog, body: String) -> void:
	var world := _world(champions, BODY_IDS[body])
	var state := world.player()
	check(MovementSystem.apply_control_state(state, PlayerState.ControlState.LAUNCHED, 50, Vector2i.RIGHT, 300000, world.config), body + " grounded forced launch starts normally")
	for _index: int in 16:
		check(world.step([SimCommand.new(world.tick, state.entity_id)]), "grounded launch tick advances")
		if state.control_state != PlayerState.ControlState.LAUNCHED: break
	check(not state.is_airborne() and state.impact_recovery_ticks > 0, body + " grounded impact remains physically grounded")
	_assert_ground_contact(state, world.config)
	var roll_world := _world(champions, BODY_IDS[body])
	var rolling := roll_world.player()
	var stamina := rolling.stamina
	check(roll_world.step([SimCommand.new(roll_world.tick, rolling.entity_id, 1000, 0, 0, SimCommand.PRESSED_EVADE)]), body + " ordinary paid ground roll begins")
	check(rolling.is_rolling() and not rolling.is_airborne(), body + " fixture is a real ground roll, not an aerial dodge")
	equal(rolling.stamina, stamina - MovementTuning.ROLL_COST, body + " roll preserves its authored payment")
	for _index: int in 64:
		if not rolling.is_rolling(): break
		check(roll_world.step([SimCommand.new(roll_world.tick, rolling.entity_id)]), "ground roll advances to its actual ending")
	check(not rolling.is_airborne() and rolling.landing_ticks > 0, body + " grounded roll ending retains its accepted contact window")
	_assert_ground_contact(rolling, roll_world.config)


func _test_canonical_airborne_boundary() -> void:
	var config := SimConfig.new(120)
	for fixture: Dictionary in [
		{"air_height": 1},
		{"air_height": 48000, "air_vertical_velocity": 200000},
		{"air_height": 48000, "air_vertical_velocity": -200000},
		{"air_vertical_velocity": 1},
		{"air_height": 48000, "air_floating": true, "flight_capable": true, "float_ticks": 8},
		{"wall_skim_ticks": 1},
	]:
		var state := PlayerState.new()
		state.landing_ticks = config.milliseconds_to_ticks(MovementTuning.LANDING_WINDOW_MS)
		state.landing_intensity = 1000
		for key: String in fixture: state.set(key, fixture[key])
		check(state.is_airborne(), "fixture exercises the existing canonical airborne predicate")
		_assert_air_contact_hidden(state, config)
	var grounded := PlayerState.new()
	grounded.landing_ticks = config.milliseconds_to_ticks(MovementTuning.LANDING_WINDOW_MS)
	grounded.landing_intensity = 680
	grounded.hop_ticks = 99
	check(not grounded.is_airborne(), "stale arc timer alone does not mean airborne")
	_assert_ground_contact(grounded, config)
	grounded.health = 0
	_assert_inactive(LandingPresentation.sample(grounded, config), "dead actor retains no floor contact")
	_assert_inactive(LandingPresentation.sample(null, config), "missing actor fails closed")
	_assert_inactive(LandingPresentation.sample(PlayerState.new(), null), "missing config fails closed")


func _assert_air_contact_hidden(state: PlayerState, config: SimConfig) -> void:
	check(state.is_airborne(), "air-contact assertion receives actual airborne authority")
	var before := state.canonical_values()
	for reduced: bool in [false, true]:
		for alpha: float in [0.0, 0.5, 1.0]:
			var landing := LandingPresentation.sample(state, config, alpha, reduced)
			_assert_inactive(landing, "airborne recovery cannot draw a false floor contact")
			var jump := JumpPresentation.sample(state, config, alpha, reduced)
			var visible_shadow: Vector2 = landing.shadow_scale if landing.active else jump.shadow_scale
			equal(visible_shadow, jump.shadow_scale, "existing local/remote shadow selection retains the physical airborne shape")
			equal(jump.body_lift_pixels, float(state.air_height) / float(SimConfig.FIXED_SCALE) * (JumpPresentation.REDUCED_HEIGHT_RATIO if reduced else 1.0), "landing admission never modifies physical height or its Reduced Effects cue")
	equal(state.canonical_values(), before, "contact suppression does not cancel recovery or write any authority field")


func _assert_ground_contact(state: PlayerState, config: SimConfig) -> void:
	check(not state.is_airborne() and state.landing_ticks > 0 and state.landing_intensity > 0, "ground-contact assertion requires a real accepted ground window")
	var before := state.canonical_values()
	var total := config.milliseconds_to_ticks(MovementTuning.LANDING_WINDOW_MS)
	for reduced: bool in [false, true]:
		for alpha: float in [0.0, 0.5, 1.0]:
			var sample := LandingPresentation.sample(state, config, alpha, reduced)
			var phase := clampf((float(total - state.landing_ticks) + alpha) / float(total), 0.0, 1.0)
			var intensity := clampf(float(state.landing_intensity) / 1000.0, 0.0, 1.0)
			var pulse := (1.0 - phase) * intensity * (0.55 if reduced else 1.0)
			check(sample.active, "grounded landing, impact and roll contacts stay enabled")
			equal(sample.normalized_phase, phase, "grounded contact keeps its preceding exact phase calculation")
			equal(sample.shadow_scale, LandingPresentation.BASE_SHADOW_SCALE.lerp(LandingPresentation.MAXIMUM_SHADOW_SCALE, pulse), "grounded contact keeps its preceding exact shadow response")
			equal(sample.contact_offsets.size(), 2, "grounded contact keeps the same two open heel marks")
			equal(sample.puff_offsets.size(), 1 if reduced else 3, "grounded contact keeps the original Reduced Effects decoration count")
			equal(sample.reduced_effects, reduced, "grounded contact retains the selected effects variant")
	equal(state.canonical_values(), before, "ground cue sampling preserves every stat, cost, timer and hurtbox field")


func _assert_inactive(sample: LandingPresentation.Sample, label: String) -> void:
	check(not sample.active, label)
	equal(sample.contact_offsets.size(), 0, "inactive contact has no heel geometry")
	equal(sample.puff_offsets.size(), 0, "inactive contact has no dust geometry")
	equal(sample.contact_opacity, 0.0, "inactive heel marks remain transparent")
	equal(sample.puff_opacity, 0.0, "inactive dust remains transparent")
	equal(sample.ring_opacity, 0.0, "inactive legacy contact remains transparent")


func _world(champions: ChampionCatalog, id: String) -> SimWorld:
	var world := SimWorld.new(120, 1, CollisionWorld.new(10000000, 10000000))
	check(world.is_valid(), "isolated paid movement fixture initializes")
	check(champions.apply_to_player(world.player(), id), "actual champion body profile applies: " + id)
	return world


func _step_pair(world: SimWorld, untouched: SimWorld, pressed: int = 0) -> void:
	for target: SimWorld in [world, untouched]:
		check(target.step([SimCommand.new(target.tick, target.player().entity_id, 0, 0, 0, pressed)]), "identical authoritative movement command advances")
	equal(world.player().canonical_values(), untouched.player().canonical_values(), "presentation queries cannot diverge the independently advanced unsampled actor")
