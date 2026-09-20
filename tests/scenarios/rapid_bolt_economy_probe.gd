extends SceneTree

# Paid, empty-lane comparison. This measures setup economy, not combat strength,
# opponent counterplay, or balance. No free deposits, altered costs or cooldowns.
const SEED: int = 609913
const SOURCE_PATHS: Array[String] = [
	"src/sim/core/sim_world.gd", "src/sim/combat/combat_system.gd",
	"src/sim/chemistry/element_chemistry_system.gd", "content/abilities/foundation_abilities_v1.json",
]
var failures := 0
var assertions := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rows: Array = []
	for distance: int in [120000, 400000]:
		for pair: Array in [[180, 182], [145, 140], [180, 140], [145, 182]]:
			var first := _measure(pair, distance)
			var repeated := _measure(pair, distance)
			_check(first == repeated, "same seed and paid command schedule reproduce every sampled hash and metric")
			rows.append(first)
	var sources := {}
	for path: String in SOURCE_PATHS:
		sources[path] = FileAccess.get_sha256("res://" + path)
	var report := {"schema_version": 1, "seed": SEED, "tick_rate": 120,
		"scope": "two paid Fire/Water casts at the same explicit endpoint; cast two begins on the tick after cast one's terminal; zero Flux regeneration; no opponent; repeated exact trace",
		"sources_sha256": sources, "rows": rows, "assertions": assertions, "failures": failures}
	print("RAPID_BOLT_ECONOMY_JSON=" + JSON.stringify(report))
	print("%s: rapid-bolt-economy; %d assertions; %d failures; 8 cases repeated twice" % ["PASS" if failures == 0 else "FAIL", assertions, failures])
	quit(0 if failures == 0 else 1)

func _measure(pair: Array, distance: int) -> Dictionary:
	var world := SimWorld.new(120, SEED, CollisionWorld.new(4000000, 4000000))
	var caster := world.player()
	caster.champion_wire_id = 1
	caster.position_x = 1000000
	caster.position_y = 1000000
	caster.flux_recovery_per_second = 0
	_check(caster.place_proven_spell(0, pair[0]) and caster.place_proven_spell(1, pair[1]), "both compared spells come from the real catalog")
	var initial_flux := caster.flux
	var first_terminal_tick := -1
	var first_terminal_strength := -1
	var first_terminal_radius := -1
	var second_started := false
	var peak_trails := 0
	var peak_material := 0
	var refusals := 0
	var trace := PackedStringArray()
	var reaction: ElementReactionState = null
	for _step: int in range(420):
		var pressed := 0
		if world.tick == 0:
			pressed = SimCommand.PRESSED_SPELL_1
		elif first_terminal_tick >= 0 and not second_started:
			pressed = SimCommand.PRESSED_SPELL_2
			second_started = true
		var command := SimCommand.new(world.tick, 1, 0, 0, 0, pressed, 1000, 0, caster.position_x + distance, caster.position_y)
		_check(world.step([command]), "paid setup step executes without capacity or terminal overflow")
		trace.append(world.state_hash())
		for event: Dictionary in world.combat_events:
			if event.get("type") == "cast_refused":
				refusals += 1
		var trail_count := 0
		for deposit: ElementDepositState in world.deposits:
			if deposit.is_trail():
				trail_count += 1
			elif first_terminal_tick < 0 and deposit.source_wire_id == int(pair[0]):
				first_terminal_tick = deposit.created_tick
				first_terminal_strength = deposit.strength
				first_terminal_radius = deposit.radius
		peak_trails = maxi(peak_trails, trail_count)
		peak_material = maxi(peak_material, world.projectiles.size() + world.deposits.size())
		if not world.reactions.is_empty():
			reaction = world.reactions[0]
			break
	_check(reaction != null, "the two paid Fire/Water terminals form real Steam")
	_check(refusals == 0, "comparison has no unpaid or capacity-refused attempted cast")
	_check(initial_flux - caster.flux == int(CombatTuning.cast_definition(pair[0]).flux_cost) + int(CombatTuning.cast_definition(pair[1]).flux_cost), "exact authored cost of both casts was paid")
	var result := {"first_wire": pair[0], "second_wire": pair[1], "distance_milli_px": distance,
		"flux_spent": initial_flux - caster.flux, "first_terminal_tick": first_terminal_tick,
		"first_terminal_strength": first_terminal_strength, "first_terminal_radius": first_terminal_radius,
		"peak_trails": peak_trails, "peak_physical_material": peak_material, "refusals": refusals,
		"all_tick_trace_sha256": "\n".join(trace).sha256_text(), "final_hash": world.state_hash(), "simulated_ticks": world.tick}
	if reaction != null:
		result.merge({"recipe_wire": reaction.recipe_wire_id, "formed_tick": reaction.created_tick,
			"active_tick": reaction.active_tick, "active_ticks": reaction.decay_tick - reaction.active_tick,
			"expiry_tick": reaction.expiry_tick})
	return result

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)
