extends FluxTestSuite
@warning_ignore_start("integer_division")
const Replay = preload("res://src/sim/replay/current_world_replay.gd")
const Mixtures = preload("res://src/content/mixture_catalog.gd")
var admitted := {}
var released := {}
var saw_paid_chemistry := false


func run() -> int:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "replay loads the actual Wellspring map")
	var world := SimWorld.new(120, 8675309, layout.build_collision_world(), String(layout.data.id), layout.content_hash)
	var definition := HexWorldDefinition.from_campus(layout)
	check(definition != null and definition.bind_world(world), "replay uses current full-map Hex authority")
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "replay catalog")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "replay roster")
	for entity: int in range(1, 9):
		var actor := world.player() if entity == 1 else PlayerState.new(entity)
		check(champions.apply_to_player(actor, "oh_tipi"), "replay uses an ordinary champion")
		actor.team_id = entity
		actor.reset_for_spawn(layout.spawn * SimConfig.FIXED_SCALE + Vector2i((entity % 4) * 65000, (entity / 4) * 65000))
		check(actor.place_proven_spell(0, Mixtures.wire_for(63, Mixtures.FAMILIES[entity - 1])), "eight actors cover eight paid families")
		if entity > 1: world.players.append(actor)
	for unused: int in 60:
		check(world.step(_commands(world)), "ordinary warmup reaches nonzero initial tick")
		_observe(world)
	var before := world.state_hash()
	var replay := Replay.new()
	check(replay.begin(world), "current replay captures admitted eight-actor snapshot")
	equal(world.state_hash(), before, "recording start does not alter authority")
	for unused: int in 120:
		var commands := _commands(world)
		check(world.step(commands), "ordinary paid movement and spells advance")
		_observe(world)
		check(replay.append_tick(commands, world), "every actor command and hash records")
		commands[0].move_x = -commands[0].move_x
	var final_hash := world.state_hash()
	for family: String in Mixtures.FAMILIES:
		check(admitted.has(family), "replay fixture actually pays for " + family)
		check(released.has(family), "replay fixture actually releases " + family)
	check(saw_paid_chemistry, "replay contains real paid ground products")
	var result: Dictionary = replay.verify(world)
	check(bool(result.ok), "all eight actors and paid chemistry replay every tick: " + str(result))
	equal(String(result.get("final_hash", "")), final_hash, "replay reaches actual final authority")
	equal(world.state_hash(), final_hash, "verification does not mutate supplied trusted world")
	var bytes: PackedByteArray = replay.encode()
	check(not bytes.is_empty() and bytes.size() <= Replay.MAX_BYTES, "diagnostic replay export remains bounded")
	var imported := Replay.new()
	check(imported.decode(bytes, world), "exported replay admits against same trusted map")
	check(bool(imported.verify(world).ok), "export/import preserves complete replay")
	var valid_before: PackedByteArray = imported.encode()
	var malformed: Dictionary = bytes_to_var(bytes)
	var duplicate: PackedInt64Array = malformed.frames[0].commands.duplicate()
	duplicate.append_array(duplicate.slice(0, 10))
	malformed.frames[0].commands = duplicate
	check(not imported.decode(var_to_bytes(malformed), world), "duplicate actor command refuses before stepping")
	equal(imported.encode(), valid_before, "failed import leaves prior replay intact")
	malformed = bytes_to_var(bytes)
	malformed.frames.resize(Replay.MAX_FRAMES + 1)
	check(not imported.decode(var_to_bytes(malformed), world), "oversized frame container refuses")
	equal(imported.encode(), valid_before, "oversized import cannot replace prior recording")
	var original := String(imported.frames[37].hash)
	imported.frames[37].hash = "0".repeat(64)
	var divergence: Dictionary = imported.verify(world)
	check(not bool(divergence.ok), "tampered checkpoint fails")
	equal(int(divergence.tick), 97, "reports first actual divergent tick, not only frame offset")
	imported.frames[37].hash = original
	imported.header.map_hash = "wrong"
	equal(int(imported.verify(world).tick), -1, "wrong map fails before any command")
	check(imported.decode(bytes, world), "valid reimport resets metadata")
	imported.header.runtime = "0".repeat(64)
	equal(int(imported.verify(world).tick), -1, "wrong runtime fails before any command")
	check(not imported.decode(PackedByteArray(), world), "empty export refuses")
	var legacy := ReplayData.new()
	legacy.map_id = world.map_id
	check(not bool(legacy.verify().ok), "legacy replay never silently substitutes foundation for current map")
	return finish("current-world-replay")


func _observe(world: SimWorld) -> void:
	for event: Dictionary in world.combat_events:
		var family := String(CombatTuning.cast_definition_view(int(event.get("wire_id", 0))).get("family", ""))
		if String(event.get("type", "")) == "cast_started": admitted[family] = true
		if String(event.get("type", "")) == "projectile_spawned": released[family] = true
	for actor: PlayerState in world.players:
		if actor.last_event.begins_with("cast_release_"):
			released[String(CombatTuning.cast_definition_view(actor.spell_wire_id(1)).get("family", ""))] = true
	saw_paid_chemistry = saw_paid_chemistry or not world.hex_court.products.is_empty()


func _commands(world: SimWorld) -> Array[SimCommand]:
	var result: Array[SimCommand] = []
	for actor: PlayerState in world.players:
		var phase := posmod(world.tick + actor.entity_id * 3, 120)
		var held := SimCommand.SPELL_HELD_BITS[0] if phase < 55 else 0
		if phase < 20: held |= SimCommand.HELD_JUMP
		var pressed := SimCommand.PRESSED_JUMP if phase == 0 else 0
		if phase == 35: pressed |= SimCommand.PRESSED_JUMP
		if phase == 60: pressed |= SimCommand.PRESSED_SPELL_1
		result.append(SimCommand.new(world.tick, actor.entity_id, 1000 if phase < 60 else -1000, 0, held, pressed, 0, -1000))
	return result
