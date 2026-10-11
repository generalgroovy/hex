extends FluxTestSuite

const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const CENTER := Vector2i(800_000, 800_000)
var catalog := AbilityCatalog.new()


func run() -> int:
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "cadence uses the live six-element catalog")
	_test_held_streams()
	_test_exhaustion_and_gates()
	_test_paid_six_input_route()
	return finish("six-element-cadence")


func _test_held_streams() -> void:
	for element: String in ElementRules.IDS:
		var world := _world()
		var actor := world.player()
		var wire := _wire(element, "rapid")
		check(actor.place_proven_spell(0, wire), "Rapid equips for " + element)
		var definition := CombatTuning.cast_definition(wire)
		equal(int(definition.startup_ms), 8, "Rapid has one120Hz preparation tick")
		equal(int(definition.cooldown_ms), 80, "Rapid keeps ten120Hz cooldown ticks")
		equal(int(definition.damage), 3000, "cadence does not increase damage per paid shot")
		equal(int(definition.reaction_strength), 1, "cadence does not grant free reaction strength")
		var starts: Array[int] = []
		var releases: Array[int] = []
		var flux_before := actor.flux
		for tick: int in range(55):
			check(world.step([SimCommand.new(world.tick, 1, 0, 1000, SimCommand.SPELL_HELD_BITS[0], 0, 1000, 0)]), "real held stream advances: " + world.last_error)
			for event: Dictionary in world.combat_events:
				if String(event.type) == "cast_started": starts.append(tick)
				if String(event.type) == "projectile_spawned": releases.append(tick)
		equal(starts, [0, 11, 22, 33, 44], "held stream admits exactly every eleven ticks")
		equal(releases, [1, 12, 23, 34, 45], "every paid admission retains its one-tick warning")
		equal(actor.flux, flux_before - 10_000, "five actual casts pay exactly five2Flux costs")
		equal(int(world.hex_court.metrics.matter_paid), 3000, "five casts mint only five paid600-unit source stocks")
		check(actor.position_y > CENTER.y, "held firing preserves ordinary movement input")
		check(world.hex_court.conservation_valid(), "held stream source ownership stays finite")


func _test_exhaustion_and_gates() -> void:
	var world := _world()
	var actor := world.player()
	var wire := _wire("fire", "rapid")
	check(actor.place_proven_spell(0, wire), "exhaustion stream equips")
	actor.flux = 10_000
	actor.flux_recovery_delay_ticks = world.config.milliseconds_to_ticks(PlayerTuning.FLUX_RECOVERY_DELAY_MS)
	var count := 0
	for tick: int in range(70):
		check(world.step([SimCommand.new(world.tick, 1, 0, 0, SimCommand.SPELL_HELD_BITS[0])]), "exhaustion held command advances")
		for event: Dictionary in world.combat_events:
			if String(event.type) == "cast_started": count += 1
	equal(count, 5, "a10Flux balance buys exactly five Rapid shots")
	equal(actor.flux, 0, "held retries cannot bypass the independent recovery wait")
	equal(int(world.hex_court.metrics.matter_paid), 3000, "exhaustion cannot issue unfunded source stock")
	for unused: int in range(60):
		check(world.step([SimCommand.new(world.tick, 1)]), "deliberate post-exhaustion pause advances recovery")
	check(actor.flux > 0, "ordinary recovery resumes after the last actual payment wait")
	equal(actor.pending_cast_wire_id, 0, "recovered stock does not cast without input")
	var policy := ActionTransitionPolicy.new()
	check(policy.load_from_file(), "capacity control loads actual admission policy")
	var state := PlayerState.new(1)
	state.champion_wire_id = 0
	check(state.place_proven_spell(0, wire), "capacity control equips live Rapid")
	var before := state.flux
	var events: Array[Dictionary] = []
	CombatSystem.step_player(state, SimCommand.new(0, 1, 0, 0, SimCommand.SPELL_HELD_BITS[0]), world.config, 100, 200, world.collision, events, policy, 0, 1)
	equal(state.pending_cast_wire_id, 0, "held stream respects a full physical projectile allowance")
	equal(state.flux, before, "capacity refusal cannot charge or mint a cast")
	CombatSystem.step_player(state, SimCommand.new(1, 1, 0, 0, SimCommand.SPELL_HELD_BITS[0]), world.config, 100, 200, world.collision, events, policy, 1, 1)
	equal(state.pending_cast_wire_id, wire, "one available physical slot permits the same held input")
	equal(state.flux, before - 2000, "capacity-positive control pays the full cost")
	var disabled := _world()
	var locked := disabled.player()
	check(locked.place_proven_spell(0, wire), "control refusal equips Rapid")
	MovementSystem.apply_control_state(locked, PlayerState.ControlState.STUNNED, 500, Vector2i.ZERO, 0, disabled.config)
	before = locked.flux
	check(disabled.step([SimCommand.new(0, 1, 0, 0, SimCommand.SPELL_HELD_BITS[0])]), "controlled held input remains a valid command")
	equal(locked.pending_cast_wire_id, 0, "faster Rapid cannot bypass stun")
	equal(locked.flux, before, "stun refusal retains Flux")
	var heavy := _world()
	check(heavy.player().place_proven_spell(0, _wire("fire", "heavy")), "manual Heavy counterpoint equips")
	check(heavy.step([SimCommand.new(0, 1, 0, 0, SimCommand.SPELL_HELD_BITS[0])]), "held Heavy input advances")
	equal(heavy.player().pending_cast_wire_id, 0, "deliberate Heavy remains edge-triggered")


func _test_paid_six_input_route() -> void:
	var world := _world()
	var actor := world.player()
	var order: Array[String] = ["earth", "water", "fire", "wind", "light", "dark"]
	var spent := 0
	for index: int in order.size():
		var wire := _wire(order[index], "rapid")
		check(actor.place_proven_spell(index, wire), "six-input route equips an actual canonical spell")
		var point := CENTER
		if not world.hex_court.products.is_empty():
			var product: Dictionary = world.hex_court.products.values()[0]
			var cells: Array = product.coverage.keys()
			cells.sort_custom(HexGrid._cell_less)
			point = world.hex_court.origin + HexGrid.center(cells[0])
		var before := actor.flux
		check(world.step([SimCommand.new(world.tick, 1, 0, 0, 0, SimCommand.SPELL_PRESSED_BITS[index], 1000, 0, point.x, point.y)]), "six-input route enters real admission")
		equal(actor.pending_cast_wire_id, wire, "each ingredient starts through its real cast gate")
		spent += before - actor.flux
		var released := false
		for unused: int in range(100):
			check(world.step([SimCommand.new(world.tick, 1)]), "six-input route advances startup and physical flight")
			if actor.pending_cast_wire_id == 0: released = true
			if released and world.projectiles.is_empty(): break
		check(released and world.projectiles.is_empty(), "each paid projectile reaches a real terminal")
	equal(spent, 12_000, "six-input route spends six full2Flux costs")
	equal(world.hex_court.products.size(), 1, "real paid input route leaves one final combination")
	if world.hex_court.products.size() == 1:
		var product: Dictionary = world.hex_court.products.values()[0]
		equal(int(product.recipe_wire_id), 463, "long-lived starter pair supports actual six-input Convergence")
		equal(int(product.funded_strength), 6, "six Rapid casts contribute exactly six strength")
		equal(int(product.damage_budget_remaining), 24_000, "actual input route preserves the linear finite pool")
	check(world.hex_court.conservation_valid(), "real startup/flight/fusion route conserves all paid material")


func _world() -> SimWorld:
	var world := SimWorld.new(120, 91, CollisionWorld.new(2_000_000, 2_000_000))
	var court := HexChemistryWorld.new()
	check(court.configure_geometry(CENTER, HexGrid.disk(Vector2i.ZERO, 20)), "cadence topology configures")
	court.chemistry_enabled = true
	world.hex_court = court
	var actor := world.player()
	actor.champion_wire_id = 0; actor.position_x = CENTER.x; actor.position_y = CENTER.y
	actor.spawn_protection_ticks = 0
	return world


func _wire(element: String, family: String) -> int:
	return int(catalog.ability(catalog.spell_id_at(element, family)).wire_id)
