class_name HexCourtPractice
extends RefCounted

const LOADOUT := [["water", "bolt"], ["fire", "bolt"], ["water", "heavy"], ["fire", "heavy"], ["water", "rapid"], ["fire", "rapid"], ["water", "spray"], ["fire", "spray"], ["earth", "bolt"], ["wind", "bolt"], ["light", "bolt"], ["dark", "bolt"]]

static func configure(world: SimWorld, catalog: AbilityCatalog, with_target: bool = true) -> bool:
	if world == null or catalog == null or world.player() == null or not world.projectiles.is_empty() or not world.deposits.is_empty() or not world.reactions.is_empty() or not world.fields.is_empty():
		return false
	var wires := PackedInt32Array()
	for pair: Array in LOADOUT:
		var definition := catalog.ability(catalog.spell_id_at(String(pair[0]), String(pair[1])))
		var wire := int(definition.get("wire_id", 0))
		if wire <= 0 or not CombatTuning.is_runtime_wire_id(wire):
			return false
		wires.append(wire)
	var actor := world.player()
	world.hex_court = HexCourt.new()
	world.hex_court.chemistry_enabled = true
	world.map_id = "hex-court-v1"
	world.map_hash = "pointy24;radius12;six-elements;solo-v2"
	world.collision = CollisionWorld.new(1_280_000, 960_000)
	world.reaction_movement = ReactionMovementWorld.new(world.collision)
	world.players = [actor]
	actor.reset_for_spawn(Vector2i(640_000, 710_000))
	actor.spell_wire_ids.fill(0)
	actor.spell_cooldown_ticks.fill(0)
	for index: int in wires.size():
		if not actor.place_proven_spell(index, wires[index]):
			return false
	actor.primary_wire_id = wires[4]
	actor.active_1_wire_id = wires[0]
	actor.active_2_wire_id = 0
	if with_target:
		var target := PlayerState.new(2)
		target.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
		target.team_id = 2
		target.position_x = 640_000
		target.position_y = 480_000
		target.training_spawn_x = target.position_x
		target.training_spawn_y = target.position_y
		target.radius = 18_000
		target.health_maximum = 120_000
		target.health = target.health_maximum
		target.health_recovery_per_second = 0
		target.flux_maximum = 0
		target.flux = 0
		target.flux_recovery_per_second = 0
		world.players.append(target)
	return actor.has_valid_spell_slots()

static func help_lines() -> PackedStringArray:
	return PackedStringArray([
		"1 Water Bolt → 2 Fire Bolt at the same ground: Steam.",
		"Fresh Fire heats / shortens it; Water cools the same hexes.",
		"Radius selects whole hexes; effects end at their outer edges.",
		"Ctrl 3/4 Spray: short fan. Clashes subtract: 15 - 5 = 10.",
		"Steam ramps for 2s; leave to cool. Jump clears ground fire.",
		"Attack with spell keys. Punch/Kick are not active yet.",
	])
