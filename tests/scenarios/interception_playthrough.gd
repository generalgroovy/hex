extends SceneTree
@warning_ignore_start("integer_division")


# A standalone source-receipt playthrough of the first Wellspring encounter.
# Setup happens once through InterceptionShowcase. Every later state change comes
# from the two retained SimCommands passed to the ordinary SimWorld step.
const SEED: int = 609_140_072
const OUTPUT_PREFIX := "res://.godot/interception-playthrough-"
const OUTPUT_SUFFIX := ".json"
const MUD_SECOND_CAST_DELAY_TICKS: int = 48
const MUD_TARGET_OFFSET := Vector2i(260_000, 0)
const SIDESTEP_OFFSET: int = 120_000
const SOURCE_PATHS: Array[String] = [
	"src/app/interception_showcase.gd",
	"src/sim/combat/interception_practice.gd",
	"src/sim/combat/spray_interception.gd",
	"src/sim/combat/spray_contact_geometry.gd",
	"src/sim/combat/combat_system.gd",
	"src/sim/core/sim_world.gd",
	"src/sim/core/sim_command.gd",
	"content/abilities/foundation_abilities_v1.json",
	"content/champions/foundation_champions_v1.json",
	"content/maps/sanctum_campus_g2_v1.json",
	"tests/scenarios/interception_playthrough.gd",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_path := _output_argument()
	if not _valid_fresh_output(output_path):
		push_error("Expected a fresh --output=res://.godot/interception-playthrough-<id>.json destination")
		quit(1)
		return

	var errors := PackedStringArray()
	var abilities := AbilityCatalog.new()
	var champions := ChampionCatalog.new()
	var campus := SanctumCampusLayout.new()
	_require(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "ability catalog: %s" % abilities.last_error, errors)
	_require(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "champion catalog: %s" % champions.last_error, errors)
	_require(campus.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "Wellspring campus: %s" % campus.last_error, errors)
	if not errors.is_empty():
		_write_receipt(output_path, {"schema_version":1, "completed":false, "errors":Array(errors)})
		quit(1)
		return

	var world := SimWorld.new(
		InterceptionPractice.TICKS_PER_SECOND,
		SEED,
		campus.build_collision_world(),
		String(campus.data.get("id", "")),
		campus.content_hash,
	)
	var configured := InterceptionShowcase.configure(world, champions, abilities, campus)
	_require(not configured.is_empty(), "InterceptionShowcase.configure accepted the current content", errors)
	_require(world.is_valid() and world.players.size() == 2, "configured world has exactly two valid actors", errors)
	if not errors.is_empty():
		_write_receipt(output_path, _failure_receipt(world, configured, errors))
		quit(1)
		return

	var start_tick := int(configured.start_tick)
	var initial_hash := world.state_hash()
	var initial_actors := _actor_receipt(world)
	var command_trace: Array[Dictionary] = []
	var state_hashes: Array[Dictionary] = []
	var event_trace: Array[Dictionary] = []
	var payments: Array[Dictionary] = []
	var releases: Array[Dictionary] = []
	var refusals: Array[Dictionary] = []
	var interceptions: Array[Dictionary] = []
	var reactions: Array[Dictionary] = []
	var event_counts := {}
	var input_counts := {
		"player_pressed_by_slot": {},
		"opponent_pressed_by_slot": {},
		"opponent_held_by_slot": {},
		"player_movement_ticks": 0,
	}
	var trace := HashingContext.new()
	trace.start(HashingContext.HASH_SHA256)
	while world.tick < start_tick + InterceptionPractice.DURATION_TICKS:
		var input_tick := world.tick
		var player_input := player_command(world, start_tick)
		var opponent_input := InterceptionPractice.command_for_tick(
			input_tick,
			start_tick,
			world.players[1],
			world.players[0],
			configured.opponent_profile.slots,
		)
		if player_input == null or opponent_input == null:
			errors.append("tick %d did not produce both actor commands" % input_tick)
			break
		var commands: Array[SimCommand] = [player_input, opponent_input]
		var command_row := {
			"tick": input_tick,
			"commands": [_command_receipt(player_input), _command_receipt(opponent_input)],
		}
		command_trace.append(command_row)
		_record_input(player_input, "player", input_counts)
		_record_input(opponent_input, "opponent", input_counts)
		trace.update(player_input.canonical_bytes())
		trace.update(opponent_input.canonical_bytes())
		if not world.step(commands):
			errors.append("SimWorld.step rejected tick %d: %s" % [input_tick, world.last_error])
			break
		var post_hash := world.state_hash()
		var events: Array = _json_value(world.combat_events)
		state_hashes.append({"tick":input_tick, "post_tick":world.tick, "hash":post_hash})
		trace.update(post_hash.to_utf8_buffer())
		trace.update(var_to_bytes(world.combat_events))
		if not events.is_empty():
			event_trace.append({"tick":input_tick, "post_tick":world.tick, "events":events})
		_observe_events(input_tick, world.combat_events, payments, releases, refusals, interceptions, reactions, event_counts)

	var expected_ticks := InterceptionPractice.DURATION_TICKS
	_require(world.tick == start_tick + expected_ticks, "playthrough completed all 72 authoritative seconds", errors)
	_require(command_trace.size() == expected_ticks, "every tick retains both submitted commands", errors)
	_require(state_hashes.size() == expected_ticks, "every stepped tick retains its resulting state hash", errors)
	_require(_paid_by_actor(payments, 1) > 0 and _paid_by_actor(payments, 2) > 0, "both actors paid for ordinary casts", errors)
	_require(_released_wire(releases, int(configured.player_profile.wires.water_spray), 1) > 0, "the paid Water Spray actually released", errors)
	_require(_released_wire(releases, int(configured.player_profile.wires.earth_spray), 1) > 0, "the paid Earth Spray actually released", errors)
	_require(_opponent_projectile_releases(releases) > 0, "the opponent pressure actually released projectiles", errors)
	_require(_player_interceptions(interceptions) > 0, "Water Spray intercepted at least one weaker opposing projectile", errors)
	var expected_reaction := _mud_recipe(configured, abilities)
	var water_definition := CombatTuning.cast_definition(int(configured.player_profile.wires.water_spray))
	var earth_definition := CombatTuning.cast_definition(int(configured.player_profile.wires.earth_spray))
	_require(
		MUD_TARGET_OFFSET.length_squared() <= int(water_definition.range) * int(water_definition.range)
		and MUD_TARGET_OFFSET.length_squared() <= int(earth_definition.range) * int(earth_definition.range),
		"the shared Mud ground target is within both Spray ranges",
		errors,
	)
	var water_release_tick := start_tick + InterceptionPractice.RAPID_SINGLE_END + world.config.milliseconds_to_ticks(int(water_definition.startup_ms))
	var earth_release_tick := start_tick + InterceptionPractice.RAPID_SINGLE_END + MUD_SECOND_CAST_DELAY_TICKS + world.config.milliseconds_to_ticks(int(earth_definition.startup_ms))
	var mud_water_release := _release_at(releases, int(configured.player_profile.wires.water_spray), 1, water_release_tick)
	var mud_earth_release := _release_at(releases, int(configured.player_profile.wires.earth_spray), 1, earth_release_tick)
	_require(not mud_water_release.is_empty() and not mud_earth_release.is_empty(), "both scheduled Mud ingredients reached release", errors)
	_require(
		not mud_water_release.is_empty()
		and not mud_earth_release.is_empty()
		and Vector2i(int(mud_water_release.end_x), int(mud_water_release.end_y)) == Vector2i(int(mud_earth_release.end_x), int(mud_earth_release.end_y)),
		"Water and Earth Spray left their ingredients at the same locked ground target",
		errors,
	)
	_require(expected_reaction > 0 and _reaction_count(reactions, expected_reaction) > 0, "separate Water and Earth Sprays formed the expected Mud reaction", errors)
	_require(world.players[0].health > 0, "the playable character survived the circuit", errors)

	var report := {
		"schema_version": 1,
		"workload_version": "interception-playthrough-v1",
		"completed": errors.is_empty(),
		"errors": Array(errors),
		"seed": SEED,
		"tick_rate": world.config.tick_rate,
		"duration_ticks": expected_ticks,
		"duration_seconds": expected_ticks / world.config.tick_rate,
		"start_tick": start_tick,
		"end_tick": world.tick,
		"map_id": world.map_id,
		"map_hash": world.map_hash,
		"source_sha256": _source_hashes(),
		"selected_kit": {
			"player": configured.player_profile,
			"opponent": configured.opponent_profile,
		},
		"initial_state_hash": initial_hash,
		"initial_actors": initial_actors,
		"final_state_hash": world.state_hash(),
		"final_actors": _actor_receipt(world),
		"final_inventory": {
			"projectiles": world.projectiles.size(),
			"deposits": world.deposits.size(),
			"reactions": world.reactions.size(),
			"next_projectile_id": world.next_projectile_id,
			"next_deposit_id": world.next_deposit_id,
			"next_reaction_id": world.next_reaction_id,
		},
		"command_trace": command_trace,
		"state_hashes": state_hashes,
		"event_trace": event_trace,
		"payments": payments,
		"releases": releases,
		"refusals": refusals,
		"interceptions": interceptions,
		"reactions": reactions,
		"mud_evidence": {
			"expected_recipe_wire_id": expected_reaction,
			"water_release": mud_water_release,
			"earth_release": mud_earth_release,
		},
		"event_counts": event_counts,
		"input_counts": input_counts,
		"all_command_state_event_trace_sha256": trace.finish().hex_encode(),
		"authority_scope": "InterceptionShowcase.configure once, then exactly two retained SimCommands per tick through SimWorld.step; no projectile, resource, cooldown, health, deposit, reaction or snapshot mutation by this scenario",
	}
	var wrote := _write_receipt(output_path, report)
	if not wrote:
		push_error("Could not write interception playthrough receipt")
		quit(1)
		return
	print("INTERCEPTION_PLAYTHROUGH ", JSON.stringify({
		"output":output_path,
		"completed":report.completed,
		"errors":report.errors,
		"ticks":command_trace.size(),
		"payments":payments.size(),
		"releases":releases.size(),
		"refusals":refusals.size(),
		"interceptions":interceptions.size(),
		"reactions":reactions.size(),
		"final_state_hash":report.final_state_hash,
		"trace_sha256":report.all_command_state_event_trace_sha256,
	}))
	quit(0 if errors.is_empty() else 1)


# Shared with a rendered harness: this reads only the current authoritative
# world and returns the complete player command for that exact world tick.
static func player_command(world: SimWorld, start_tick: int) -> SimCommand:
	if world == null or world.players.size() != 2 or world.tick < start_tick:
		return null
	var player: PlayerState = world.players[0]
	var opponent: PlayerState = world.players[1]
	var elapsed := world.tick - start_tick
	var state := InterceptionPractice.status(world.tick, start_tick)
	if state.is_empty():
		return null
	var target := Vector2i(opponent.position_x, opponent.position_y)
	var pressed := 0
	var move_y := _sidestep_input(String(state.phase), elapsed, player.position_y)
	if elapsed == InterceptionPractice.RAPID_SINGLE_END:
		pressed = SimCommand.SPELL_PRESSED_BITS[0]
		target = Vector2i(player.position_x, player.position_y) + MUD_TARGET_OFFSET
	elif elapsed == InterceptionPractice.RAPID_SINGLE_END + MUD_SECOND_CAST_DELAY_TICKS:
		pressed = SimCommand.SPELL_PRESSED_BITS[1]
		target = Vector2i(player.position_x, player.position_y) + MUD_TARGET_OFFSET
		# Aim the second ordinary cast at the actual surviving Water ingredient.
		# Earlier enemy displacement makes a fixed original-spawn target unreliable.
		for deposit: ElementDepositState in world.deposits:
			if deposit.owner_id == player.entity_id and deposit.created_tick >= start_tick + InterceptionPractice.RAPID_SINGLE_END and not deposit.is_trail():
				target = Vector2i(deposit.position_x, deposit.position_y)
				break
	elif _reactive_phase(String(state.phase), elapsed, world, player) and _ready_for_slot(player, 1):
		var threat := _spray_counter_target(world, player, 1)
		if threat != null:
			pressed = SimCommand.SPELL_PRESSED_BITS[0]
			target = Vector2i(threat.position_x, threat.position_y)
	var aim := target - Vector2i(player.position_x, player.position_y)
	return SimCommand.new(
		world.tick,
		player.entity_id,
		0,
		move_y,
		0,
		pressed,
		aim.x,
		aim.y,
		target.x,
		target.y,
	)


# Rebuilds an exact retained input without consulting the adaptive controller or
# current projectiles. The rendered harness can therefore replay a candidate
# baseline byte-for-byte instead of regenerating decisions from changed state.
static func command_from_record(record: Dictionary) -> SimCommand:
	for key: String in ["tick", "entity_id", "move_x", "move_y", "held_actions", "pressed_actions", "aim_x", "aim_y", "aim_target_x", "aim_target_y"]:
		if not record.has(key) or not _record_integer(record[key]):
			return null
	var command := SimCommand.new(
		int(record.tick),
		int(record.entity_id),
		int(record.move_x),
		int(record.move_y),
		int(record.held_actions),
		int(record.pressed_actions),
		int(record.aim_x),
		int(record.aim_y),
		int(record.aim_target_x),
		int(record.aim_target_y),
	)
	# These are already canonical input components. Re-normalizing the integer
	# approximation changes some directions on a second pass.
	command.aim_x = int(record.aim_x)
	command.aim_y = int(record.aim_y)
	return command


static func _record_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(float(value)) and float(value) == floorf(float(value))


static func _reactive_phase(phase: String, elapsed: int, world: SimWorld, player: PlayerState) -> bool:
	if phase == InterceptionPractice.PHASE_RAPID_SINGLE:
		# Let earlier Water ingredients and their startup window expire before the
		# authored Water-then-Earth pair. This is input timing, not state cleanup.
		var water := CombatTuning.cast_definition(player.spell_wire_id(1))
		var element_wire := int(water.get("element_wire_id", 0))
		if element_wire <= 0 or element_wire >= ElementChemistrySystem.ELEMENT_LIFE_MS.size():
			return false
		var clearance := world.config.milliseconds_to_ticks(ElementChemistrySystem.ELEMENT_LIFE_MS[element_wire])
		clearance += world.config.milliseconds_to_ticks(int(water.get("startup_ms", 0))) + 4
		return elapsed < InterceptionPractice.RAPID_SINGLE_END - clearance
	return phase in [InterceptionPractice.PHASE_RAPID_PRESSURE, InterceptionPractice.PHASE_FINAL_MIX]


static func _ready_for_slot(player: PlayerState, slot: int) -> bool:
	var wire := player.spell_wire_id(slot)
	var definition := CombatTuning.cast_definition(wire)
	return (
		player.health > 0
		and player.pending_cast_wire_id == 0
		and player.cast_recovery_ticks == 0
		and player.spell_cooldown_for_wire(wire) == 0
		and not definition.is_empty()
		and player.flux >= int(definition.get("flux_cost", 0))
	)


static func _spray_counter_target(world: SimWorld, player: PlayerState, slot: int) -> ProjectileState:
	var spray := CombatTuning.cast_definition(player.spell_wire_id(slot))
	if String(spray.get("shape", "")) != "spray":
		return null
	var startup_ticks := world.config.milliseconds_to_ticks(int(spray.startup_ms))
	var best: ProjectileState = null
	var best_distance := 1 << 62
	for shot: ProjectileState in world.projectiles:
		if shot.owner_id == player.entity_id or shot.team_id == player.team_id or shot.reaction_strength <= 0 or shot.reaction_strength >= int(spray.reaction_strength):
			continue
		var shot_definition := CombatTuning.cast_definition(shot.source_wire_id)
		if not bool(shot_definition.get("repeat_while_held", false)):
			continue
		var toward_player := Vector2i(player.position_x - shot.position_x, player.position_y - shot.position_y)
		if shot.velocity_x * toward_player.x + shot.velocity_y * toward_player.y <= 0:
			continue
		var distance := SimCommand._integer_square_root(toward_player.length_squared())
		var speed := SimCommand._integer_square_root(Vector2i(shot.velocity_x, shot.velocity_y).length_squared())
		var travel_per_tick := speed / world.config.tick_rate
		var trigger_outer := int(spray.range) + travel_per_tick * (startup_ticks + 1)
		var trigger_inner := trigger_outer - maxi(18_000, travel_per_tick * 4)
		if distance >= trigger_inner and distance <= trigger_outer and distance < best_distance:
			best = shot
			best_distance = distance
	return best


static func _sidestep_input(phase: String, elapsed: int, current_y: int) -> int:
	var anchor_y := InterceptionPractice.PLAYER_SPAWN_PX.y * SimConfig.FIXED_SCALE
	var target_y := anchor_y
	if phase in [InterceptionPractice.PHASE_STRONGER_WARNING, InterceptionPractice.PHASE_BOLT_READ, InterceptionPractice.PHASE_FINAL_MIX]:
		var side := 1 if posmod(elapsed - InterceptionPractice.RAPID_PRESSURE_END, 720) < 360 else -1
		target_y += side * SIDESTEP_OFFSET
	var delta := target_y - current_y
	if absi(delta) <= 12_000:
		return 0
	return 850 if delta > 0 else -850


static func _command_receipt(command: SimCommand) -> Dictionary:
	return {
		"tick": command.tick,
		"entity_id": command.entity_id,
		"move_x": command.move_x,
		"move_y": command.move_y,
		"held_actions": command.held_actions,
		"pressed_actions": command.pressed_actions,
		"aim_x": command.aim_x,
		"aim_y": command.aim_y,
		"aim_target_x": command.aim_target_x,
		"aim_target_y": command.aim_target_y,
	}


static func _record_input(command: SimCommand, label: String, counts: Dictionary) -> void:
	var pressed_slot := command.first_pressed_spell_slot()
	var held_slot := command.first_held_spell_slot()
	if pressed_slot > 0:
		var pressed: Dictionary = counts["%s_pressed_by_slot" % label]
		pressed[str(pressed_slot)] = int(pressed.get(str(pressed_slot), 0)) + 1
	if held_slot > 0:
		var held: Dictionary = counts["%s_held_by_slot" % label]
		held[str(held_slot)] = int(held.get(str(held_slot), 0)) + 1
	if label == "player" and (command.move_x != 0 or command.move_y != 0):
		counts.player_movement_ticks = int(counts.player_movement_ticks) + 1


static func _observe_events(
	input_tick: int,
	events: Array[Dictionary],
	payments: Array[Dictionary],
	releases: Array[Dictionary],
	refusals: Array[Dictionary],
	interceptions: Array[Dictionary],
	reactions: Array[Dictionary],
	event_counts: Dictionary,
) -> void:
	for event_order: int in range(events.size()):
		var event: Dictionary = events[event_order]
		var kind := String(event.get("type", ""))
		event_counts[kind] = int(event_counts.get(kind, 0)) + 1
		var observed: Dictionary = _json_value(event)
		observed["tick"] = input_tick
		observed["event_order"] = event_order
		match kind:
			"cast_started":
				var definition := CombatTuning.cast_definition(int(event.get("wire_id", 0)))
				observed["flux_paid"] = int(definition.get("flux_cost", 0))
				payments.append(observed)
			"projectile_spawned", "spray_fired":
				releases.append(observed)
			"cast_refused":
				refusals.append(observed)
			"spray_intercepted":
				interceptions.append(observed)
			"chemistry_formed":
				reactions.append(observed)


static func _paid_by_actor(payments: Array[Dictionary], entity_id: int) -> int:
	var total := 0
	for payment: Dictionary in payments:
		if int(payment.get("entity_id", 0)) == entity_id:
			total += int(payment.get("flux_paid", 0))
	return total


static func _released_wire(releases: Array[Dictionary], wire_id: int, owner_id: int) -> int:
	var total := 0
	for event: Dictionary in releases:
		var event_wire := int(event.get("wire_id", event.get("source_wire_id", 0)))
		if event_wire == wire_id and int(event.get("owner_id", 0)) == owner_id:
			total += 1
	return total


static func _release_at(releases: Array[Dictionary], wire_id: int, owner_id: int, tick: int) -> Dictionary:
	for event: Dictionary in releases:
		var event_wire := int(event.get("wire_id", event.get("source_wire_id", 0)))
		if event_wire == wire_id and int(event.get("owner_id", 0)) == owner_id and int(event.get("tick", -1)) == tick:
			return event
	return {}


static func _opponent_projectile_releases(releases: Array[Dictionary]) -> int:
	var total := 0
	for event: Dictionary in releases:
		if String(event.get("type", "")) == "projectile_spawned" and int(event.get("owner_id", 0)) == 2:
			total += 1
	return total


static func _player_interceptions(interceptions: Array[Dictionary]) -> int:
	var total := 0
	for event: Dictionary in interceptions:
		total += int(int(event.get("owner_id", 0)) == 1 and int(event.get("outcome", 0)) == 1)
	return total


static func _reaction_count(reactions: Array[Dictionary], recipe_wire_id: int) -> int:
	var total := 0
	for event: Dictionary in reactions:
		total += int(int(event.get("recipe_wire_id", 0)) == recipe_wire_id)
	return total


static func _mud_recipe(configured: Dictionary, abilities: AbilityCatalog) -> int:
	var wires: Dictionary = configured.get("player_profile", {}).get("wires", {})
	var water := abilities.ability_from_wire(int(wires.get("water_spray", 0)))
	var earth := abilities.ability_from_wire(int(wires.get("earth_spray", 0)))
	if water.is_empty() or earth.is_empty():
		return 0
	var water_element: Dictionary = abilities.elements_by_id.get(String(water.get("element", "")), {})
	var earth_element: Dictionary = abilities.elements_by_id.get(String(earth.get("element", "")), {})
	return ElementChemistrySystem.recipe_wire(int(water_element.get("wire_id", 0)), int(earth_element.get("wire_id", 0)))


static func _actor_receipt(world: SimWorld) -> Array[Dictionary]:
	var actors: Array[Dictionary] = []
	for actor: PlayerState in world.players:
		actors.append({
			"entity_id": actor.entity_id,
			"champion_wire_id": actor.champion_wire_id,
			"team_id": actor.team_id,
			"position_x": actor.position_x,
			"position_y": actor.position_y,
			"health": actor.health,
			"flux": actor.flux,
			"spell_wire_ids": Array(actor.spell_wire_ids),
		})
	return actors


static func _json_value(value: Variant) -> Variant:
	if value is Dictionary:
		var object := {}
		for key: Variant in value:
			object[str(key)] = _json_value(value[key])
		return object
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(_json_value(item))
		return items
	if value is Vector2i:
		return {"x":value.x, "y":value.y}
	if value is PackedByteArray or value is PackedInt32Array or value is PackedInt64Array or value is PackedStringArray:
		return Array(value)
	if value is StringName:
		return String(value)
	return value


static func _source_hashes() -> Dictionary:
	var hashes := {}
	for path: String in SOURCE_PATHS:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	return hashes


static func _output_argument() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			return argument.trim_prefix("--output=")
	return ""


static func _valid_fresh_output(path: String) -> bool:
	if not path.begins_with(OUTPUT_PREFIX) or not path.ends_with(OUTPUT_SUFFIX) or path.contains("..") or FileAccess.file_exists(path):
		return false
	var identifier := path.trim_prefix(OUTPUT_PREFIX).trim_suffix(OUTPUT_SUFFIX)
	return not identifier.is_empty() and not identifier.contains("/") and not identifier.contains("\\")


static func _require(condition: bool, label: String, errors: PackedStringArray) -> void:
	if not condition:
		errors.append(label)


static func _failure_receipt(world: SimWorld, configured: Dictionary, errors: PackedStringArray) -> Dictionary:
	return {
		"schema_version": 1,
		"workload_version": "interception-playthrough-v1",
		"completed": false,
		"errors": Array(errors),
		"seed": SEED,
		"source_sha256": _source_hashes(),
		"configuration": configured,
		"state_hash": world.state_hash(),
	}


static func _write_receipt(path: String, receipt: Dictionary) -> bool:
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		return false
	output.store_string(JSON.stringify(receipt, "  "))
	output.close()
	return true
