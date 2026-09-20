extends SceneTree

@warning_ignore_start("integer_division")

## Bounded source-locked Steam measurement. Every row creates Steam through two
## real paid SimWorld commands, then measures authored occupation/re-entry traces.
## It changes no coefficient and owns no balance acceptance threshold.

const SEED := 920_310
const TICK_RATE := 120
const TARGET := Vector2i(1_504_000, 1_344_000)
const SPAWN := TARGET + Vector2i(0, 96_000)
const BODY_TYPES: Array[String] = ["small", "middle", "large"]
const WINDOWS: Array[int] = [12, 30, 60, 120, 240]
const SOURCE_PATHS: Array[String] = [
	"src/sim/hex/hex_chemistry_world.gd",
	"src/sim/hex/hex_recipe_policy.gd",
	"src/sim/hex/hex_footprint.gd",
	"src/sim/core/sim_world.gd",
	"content/abilities/foundation_abilities_v1.json",
	"content/champions/body_type_profiles_v1.json",
]

var failures := 0
var assertions := 0
var output_path := ""
var abilities := AbilityCatalog.new()
var bodies := BodyTypeProfileCatalog.new()
var layout := SanctumCampusLayout.new()
var definition: HexWorldDefinition


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	_check(output_path.begins_with("res://.godot/hex-steam-balance-") and output_path.ends_with(".json") and not ".." in output_path and not FileAccess.file_exists(output_path), "fresh scoped Steam balance receipt path")
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production ability catalog loads")
	_check(bodies.load_from_file(), "three authored body profiles load")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "normal Wellspring campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null, "normal campus supplies the production whole-hex definition")
	var policy := HexRecipePolicy.definition(310)
	_check(int(policy.get("exposure_cap", 0)) == 240, "profile is pinned to the authored 240 exposure cap")
	_check(int(policy.get("exposure_exit_decay", 0)) == 2, "profile is pinned to the authored two-per-tick exit decay")
	_check(String(policy.get("purpose", "")) == "visible capped scald pressure", "profile is pinned to visible scald rather than concealment tuning")
	if failures > 0:
		_finish([])
		return

	var rows: Array[Dictionary] = []
	for body_type: String in BODY_TYPES:
		rows.append(_measure_body(body_type))
	_finish(rows)


func _measure_body(body_type: String) -> Dictionary:
	var world := SimWorld.new(TICK_RATE, SEED, layout.build_collision_world(), String(layout.data.id), layout.content_hash)
	_check(definition.bind_world(world), "%s measurement binds the production campus authority" % body_type)
	var caster := world.player()
	caster.reset_for_spawn(SPAWN)
	caster.spawn_protection_ticks = 0
	caster.flux_recovery_per_second = 0
	var initial_flux := caster.flux
	var initial_paid := int(world.hex_court.metrics.matter_paid)
	_paid_cast(world, caster, "water")
	for unused: int in 36:
		_check(world.step([]), "%s waits the real first-cast recovery" % body_type)
	_paid_cast(world, caster, "fire")
	var product: Dictionary = {}
	for candidate: Dictionary in world.hex_court.products.values():
		if int(candidate.get("recipe_wire_id", 0)) == 310:
			product = candidate
	_check(not product.is_empty(), "%s two real paid casts form Steam310" % body_type)
	if product.is_empty():
		return {"body_type": body_type, "blocked": "paid Steam did not form"}
	_check(initial_flux - caster.flux > 0, "%s real Water and Fire inputs spend positive authored Flux" % body_type)
	_check(int(world.hex_court.metrics.matter_paid) == initial_paid + 1_200, "%s real inputs reserve exactly two 600-unit budgets" % body_type)
	_check(int(product.quantity) == 1_200, "%s Steam owns the two finite paid budgets once" % body_type)
	_check(world.hex_court.conservation_valid(), "%s paid formation conserves finite matter" % body_type)
	while world.tick < int(product.active_tick):
		_check(world.step([]), "%s advances through authored Steam formation" % body_type)

	var radius := bodies.hurt_radius(body_type)
	var inside := Vector2i(product.position)
	var inside_cell := HexGrid.world_to_cell(inside - world.hex_court.origin)
	var density := int(product.cells.get(inside_cell, 0))
	var outside := inside + HexGrid.center(Vector2i(5, 0))
	_check(density > 0 and product.coverage.has(inside_cell), "%s measurement point has positive paid Steam allocation" % body_type)
	_check(not world.hex_court.contains_stored(product, outside), "%s outside point is outside stored Steam coverage" % body_type)

	var roles := {}
	var tracked: Array[PlayerState] = []
	for index: int in WINDOWS.size():
		var actor := PlayerState.new(index + 2)
		_prepare_actor(actor, radius, outside)
		world.players.append(actor)
		roles[actor.entity_id] = {"kind": "window", "window": WINDOWS[index]}
		tracked.append(actor)
	var repeated := PlayerState.new(7)
	_prepare_actor(repeated, radius, outside)
	world.players.append(repeated)
	roles[repeated.entity_id] = {"kind": "repeated", "window": 60}
	tracked.append(repeated)
	var continuous := PlayerState.new(8)
	_prepare_actor(continuous, radius, outside)
	world.players.append(continuous)
	roles[continuous.entity_id] = {"kind": "continuous", "window": 60}
	tracked.append(continuous)
	# Preserve the caster's post-payment resources; reset_for_spawn would refill
	# Flux and would invalidate this paid-input measurement.
	caster.position_x = inside.x
	caster.position_y = inside.y
	caster.velocity_x = 0
	caster.velocity_y = 0
	caster.radius = radius
	caster.team_id = 99
	caster.health_recovery_per_second = 0
	caster.spawn_protection_ticks = 1_000
	roles[caster.entity_id] = {"kind": "protected", "window": 240}
	tracked.append(caster)
	_check(world.players.size() == 8, "%s profile stays within the eight-player target" % body_type)

	var observations := {}
	for actor: PlayerState in tracked:
		observations[actor.entity_id] = {
			"role": roles[actor.entity_id], "contact_ticks": 0, "expected_exposure": 0,
			"peak_exposure": 0, "expected_damage": 0, "first_damage_tick": -1,
			"start_health": actor.health,
		}
	var sample_start_tick := world.tick
	for sample_index: int in 240:
		var processed_tick := world.tick
		for actor: PlayerState in tracked:
			var inside_now := _inside_schedule(roles[actor.entity_id], sample_index)
			actor.position_x = inside.x if inside_now else outside.x
			actor.position_y = inside.y if inside_now else outside.y
		_check(world.step([]), "%s measured authoritative tick %d advances" % [body_type, sample_index])
		for actor: PlayerState in tracked:
			var observation: Dictionary = observations[actor.entity_id]
			var inside_now := _inside_schedule(roles[actor.entity_id], sample_index)
			var protected := String(roles[actor.entity_id].kind) == "protected"
			if inside_now and not protected:
				observation.contact_ticks += 1
				observation.expected_exposure = mini(240, int(observation.expected_exposure) + 1)
				if processed_tick % 30 == 0:
					var damage := _expected_damage(product, density, int(observation.expected_exposure))
					observation.expected_damage += damage
					if damage > 0 and int(observation.first_damage_tick) < 0:
						observation.first_damage_tick = processed_tick
			else:
				observation.expected_exposure = maxi(0, int(observation.expected_exposure) - 2)
			observation.peak_exposure = maxi(int(observation.peak_exposure), int(world.hex_court.exposure.get(actor.entity_id, 0)))

	var results: Array[Dictionary] = []
	for actor: PlayerState in tracked:
		var observation: Dictionary = observations[actor.entity_id]
		var actual_damage := int(observation.start_health) - actor.health
		_check(int(world.hex_court.exposure.get(actor.entity_id, 0)) == int(observation.expected_exposure), "%s %s final exposure matches the independent tick schedule" % [body_type, String(observation.role.kind)])
		_check(actual_damage == int(observation.expected_damage), "%s %s damage matches the independent authored formula" % [body_type, String(observation.role.kind)])
		results.append({
			"entity_id": actor.entity_id,
			"role": observation.role,
			"contact_ticks": observation.contact_ticks,
			"peak_exposure": observation.peak_exposure,
			"final_exposure": int(world.hex_court.exposure.get(actor.entity_id, 0)),
			"damage": actual_damage,
			"expected_damage": observation.expected_damage,
			"first_damage_tick": observation.first_damage_tick,
		})
	_check(int(product.quantity) == 1_200, "%s all exposure schedules leave paid product quantity unchanged" % body_type)
	_check(world.hex_court.conservation_valid(), "%s all exposure schedules preserve finite accounting" % body_type)
	return {
		"body_type": body_type,
		"hurt_radius": radius,
		"sample_start_tick": sample_start_tick,
		"sample_ticks": 240,
		"real_paid_casts": 2,
		"flux_spent": initial_flux - caster.flux,
		"matter_paid": int(world.hex_court.metrics.matter_paid) - initial_paid,
		"steam_quantity": int(product.quantity),
		"steam_density_at_measurement_point": density,
		"results": results,
		"final_state_hash": world.state_hash(),
	}


func _paid_cast(world: SimWorld, actor: PlayerState, element: String) -> void:
	var wire := int(abilities.ability(abilities.spell_id_at(element, "bolt")).get("wire_id", 0))
	_check(wire > 0 and actor.place_proven_spell(0, wire), "%s Bolt equips through the production catalog" % element)
	var before_flux := actor.flux
	var before_paid := int(world.hex_court.metrics.matter_paid)
	var command := SimCommand.new(world.tick, actor.entity_id, 0, 0, 0, int(SimCommand.SPELL_PRESSED_BITS[0]), 0, -1_000, TARGET.x, TARGET.y)
	_check(world.step([command]), "%s Bolt paid command advances" % element)
	_check(actor.flux < before_flux, "%s Bolt spends positive Flux" % element)
	_check(int(world.hex_court.metrics.matter_paid) == before_paid + 600, "%s Bolt reserves one finite 600-unit matter budget" % element)
	for unused: int in 300:
		if actor.pending_cast_wire_id == 0 and world.projectiles.is_empty():
			break
		_check(world.step([]), "%s Bolt startup and flight advance" % element)
	_check(actor.pending_cast_wire_id == 0 and world.projectiles.is_empty(), "%s Bolt terminates in bounded time" % element)


func _prepare_actor(actor: PlayerState, radius: int, point: Vector2i) -> void:
	actor.reset_for_spawn(point)
	actor.radius = radius
	actor.team_id = 99
	actor.spawn_protection_ticks = 0
	actor.health_recovery_per_second = 0


func _inside_schedule(role: Dictionary, sample_index: int) -> bool:
	match String(role.kind):
		"window", "continuous":
			return sample_index < int(role.window)
		"repeated":
			var visit := sample_index / 27
			return visit < 5 and sample_index % 27 < 12
		"protected":
			return true
	return false


func _expected_damage(product: Dictionary, density: int, exposure: int) -> int:
	var ramp := 2_000 + 6_000 * exposure / 240
	var normal := mini(8_000, ramp * density / 400)
	return mini(12_000, normal * int(product.intensity) / 1_000)


func _finish(rows: Array) -> void:
	var hashes := {}
	for path: String in SOURCE_PATHS:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	var receipt := {
		"schema_version": 1,
		"workload": "hex-steam-balance-v1",
		"status": "MEASUREMENT_ONLY_NO_TUNING",
		"seed": SEED,
		"tick_rate": TICK_RATE,
		"contact_windows_ticks": WINDOWS,
		"authored_contract": {
			"exposure_cap": 240, "exit_decay_per_tick": 2, "pulse_period_ticks": 30,
			"damage_ramp_min": 2_000, "damage_ramp_max": 8_000, "damage_hard_cap": 12_000,
			"paid_matter_per_cast": 600,
		},
		"source_sha256": hashes,
		"rows": rows,
		"assertions": assertions,
		"failures": failures,
		"scope": "Three body radii; one production-campus Steam field per body type formed by two real paid Bolt commands; exact 12/30/60/120/240 occupation windows, five 12-tick visits with 15-tick gaps, a continuous 60-tick comparator, and a protected control. Positions follow a deterministic fixture trace. No coefficient, resource, lifetime, health, protection, or chemistry mutation.",
		"acceptance_boundary": "Headless deterministic measurement only. It does not establish human balance, rendered readability, network capacity, release performance, or approval of the external handoff's proposed percentage bands.",
	}
	if output_path.begins_with("res://.godot/hex-steam-balance-") and not FileAccess.file_exists(output_path):
		var output := FileAccess.open(output_path, FileAccess.WRITE)
		_check(output != null, "Steam balance receipt opens")
		if output != null:
			output.store_string(JSON.stringify(receipt, "\t") + "\n")
			output.close()
	print("HEX_STEAM_BALANCE_JSON=" + JSON.stringify(receipt))
	print("%s: hex-steam-balance; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)
