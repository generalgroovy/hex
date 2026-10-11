extends FluxTestSuite
@warning_ignore_start("integer_division")


const ELEMENTS: Array[int] = [3, 2, 4, 1, 7, 8]
const HEAVY_WIRES: Array[int] = [181, 179, 185, 183, 191, 193]
const ORIGINAL_WIRES: Array[int] = [140, 181, 182, 141, 145, 179, 180, 154, 163, 185, 186, 164, 159, 183, 184, 160, 173, 191, 192, 174, 142, 193, 194, 176]
const FAR_POINT := Vector2i(6_000_000, 1_000_000)
const ORIGIN := Vector2i(1_000_000, 1_000_000)


class RefusingAdmissionPolicy:
	extends RefCounted
	var reason: String = ""
	var calls := PackedStringArray()

	func admission_reason(_wire_id: int) -> String:
		calls.append("admission")
		return reason

	func reserve_cast(_owner_id: int, _wire_id: int) -> bool:
		calls.append("reserve")
		# A second policy query would change the existing reservation-failure
		# taxonomy. Production must use the already selected intent and outcome.
		reason = "hex_unsupported_delivery"
		return false

	func cancel_pending(_owner_id: int) -> void:
		calls.append("cancel")

	func commit_payment(_owner_id: int) -> void:
		calls.append("payment")


func run() -> int:
	_test_real_catalog_and_paid_lanes()
	_test_reactive_tempo()
	_test_persistent_hex_tempo_and_retirement()
	_test_held_bolt_controls()
	_test_archived_field_records_are_gated()
	_test_retired_delivery_admission_fails_closed()
	_test_heavy_direct_hit_and_single_terminal()
	_test_heavy_protection_and_split_damage()
	_test_heavy_solid_and_temporary_cover()
	_test_heavy_range_wall_and_lifetime()
	_test_wider_spray_remains_close_range_and_cover_bound()
	_test_private_terminal_event_once()
	_test_rapid_repeat_payment_and_release()
	_test_held_priority_and_silent_refusals()
	_test_held_repeatable_slot_arbitration()
	_test_held_repeatable_priority_gates()
	_test_held_hex_capacity_feedback()
	_test_hex_reservation_failure_feedback()
	_test_held_noncapacity_policy_errors()
	_test_router_plain_ctrl_alt_rapid()
	_test_delivery_replay_in_eight_directions()
	return finish("spell-delivery-expansion")


func _test_reactive_tempo() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "tempo catalog validates")
	equal(catalog.runtime_wire_ids.size(), 504, "expanded library has 63 mixtures times eight live families")
	equal(Array(catalog.runtime_wire_ids.slice(0, 24)), ORIGINAL_WIRES, "the original cadence matrix retains its exact 24 wires and order")
	var family_cooldowns := {"bolt":200, "heavy":900, "rapid":80, "spray":700}
	var wire_cooldowns := {140:170, 141:750, 142:210, 145:190}
	# Preserve the original non-Hex cadence oracle independently of the expanded
	# library. Persistent deliveries have a separate actual Hex route below.
	for wire: int in ORIGINAL_WIRES:
		var ability := catalog.ability_from_wire(wire)
		var family := AbilityCatalog._spell_family(ability)
		var expected_ms := int(wire_cooldowns.get(wire, family_cooldowns[family]))
		var definition := CombatTuning.cast_definition(wire)
		if family == "rapid": equal(int(definition.startup_ms), 8, "Rapid has independently specified8ms startup")
		equal(int(definition.cooldown_ms), expected_ms, "all24 spells retain their explicitly balanced firing interval")
		check(expected_ms >= 80 and expected_ms <= 900, "all paid families retain bounded reactive cadence")
		var world := _world()
		check(world.player().place_proven_spell(0, wire), "tempo fixture equips each live spell")
		var before_flux := world.player().flux
		var starts: Array[int] = []
		# Cooldown begins at release, so complete start-to-start cadence includes
		# startup. Keep that existing rule explicit rather than silently moving it.
		var interval := world.config.milliseconds_to_ticks(expected_ms) + world.config.milliseconds_to_ticks(int(definition.startup_ms))
		for unused: int in interval + 3:
			_step(world, _command(world, SimCommand.SPELL_HELD_BITS[0] if family == "rapid" else 0, 0 if family == "rapid" else SimCommand.PRESSED_SPELL_1))
			for event: Dictionary in _events(world, "cast_started", wire): starts.append(world.tick - 1)
			if starts.size() == 2: break
		equal(starts.size(), 2, "real admission admits two paid casts at the new cadence")
		if starts.size() == 2:
			equal(starts[1] - starts[0], interval, "actual start-to-start cadence is exactly startup plus release-owned cooldown")
		equal(world.player().flux, before_flux - int(definition.flux_cost) * 2, "family cadence pays its authored positive cost on every shot")


func _test_persistent_hex_tempo_and_retirement() -> void:
	# Independent authored timing/cost oracles; both a singleton and a complete
	# mixture must obey the same delivery economy, without a legacy fallback.
	var rules := {
		"mantle": [100, 1500, 16_000], "fuse": [120, 900, 18_000],
		"split": [80, 650, 10_000], "rebound": [80, 650, 9_000],
	}
	# Six ingredients add 75% to base cost, rounded UP to whole Flux before
	# fixed-point conversion. Keep literal expectations independent of compilation.
	var full_mixture_costs := {"mantle": 28_000, "fuse": 32_000, "split": 18_000, "rebound": 16_000}
	for family: String in ["mantle", "fuse", "split", "rebound"]:
		for mask: int in [4, 63]:
			var wire := MixtureCatalog.wire_for(mask, family)
			var definition := CombatTuning.cast_definition(wire)
			var rule: Array = rules[family]
			var expected_cost := int(full_mixture_costs[family]) if mask == 63 else int(rule[2])
			equal(int(definition.startup_ms), int(rule[0]), "persistent family retains independently specified startup")
			equal(int(definition.cooldown_ms), int(rule[1]), "persistent family retains independently specified cooldown")
			equal(int(definition.flux_cost), expected_cost, "persistent family retains independently specified singleton or rounded mixture cost")
			check(not bool(definition.get("repeat_while_held", false)), "new persistent deliveries require deliberate press edges")
			var world := _world()
			world.player().champion_wire_id = 0 # Neutral timing oracle, without an identity perk.
			var court := HexChemistryWorld.new()
			check(court.configure_geometry(ORIGIN, HexGrid.disk(Vector2i.ZERO, 12)), "persistent cadence uses a real bounded Hex court")
			court.chemistry_enabled = true
			world.hex_court = court
			check(world.player().place_proven_spell(0, wire), "new family equips on the live Hex route")
			var before := world.player().flux
			var interval := world.config.milliseconds_to_ticks(int(rule[0])) + world.config.milliseconds_to_ticks(int(rule[1]))
			var starts: Array[int] = []
			for unused: int in range(interval + 3):
				_step(world, _command(world, 0, SimCommand.PRESSED_SPELL_1))
				for event: Dictionary in _events(world, "cast_started", wire): starts.append(world.tick - 1)
				if starts.size() == 2: break
			equal(starts.size(), 2, "actual Hex admission starts two deliberately requested paid casts")
			if starts.size() == 2: equal(starts[1] - starts[0], interval, "persistent start interval includes preparation and release-owned cooldown")
			equal(world.player().flux, before - 2 * expected_cost, "two persistent casts pay exactly twice without a branch surcharge or refund")
			# Four seconds exceeds the longest 3.2s flight + 0.6s Fuse warning +
			# 0.12s preparation. Holding after the last press must add no third cast.
			for unused: int in range(world.config.milliseconds_to_ticks(4000)):
				_step(world, _command(world, SimCommand.SPELL_HELD_BITS[0]))
				equal(_events(world, "cast_started", wire).size(), 0, "held input cannot repeat a deliberate persistent delivery")
				check(world.hex_court.conservation_valid(), "actual release and retirement preserve funded material")
			equal(world.player().pending_cast_wire_id, 0, "persistent preparations finish inside the independent bound")
			equal(world.projectiles.size(), 0, "all new deliveries and Split children retire inside their finite flight/warning bound")
			equal(int(world.hex_court.metrics.matter_paid), 1200, "two releases own exactly two paid source stocks")
			equal(world.player().flux, before - 2 * expected_cost, "held waiting cannot issue another cost, refund, or free cast")
			world.player().flux = 0
			_step(world, _command(world, 0, SimCommand.PRESSED_SPELL_1))
			equal(_events(world, "cast_started", wire).size(), 0, "exhaustion refuses a fresh persistent cast")
			equal(world.player().pending_cast_wire_id, 0, "exhaustion leaves no unfunded preparation")
			equal(int(world.hex_court.metrics.matter_paid), 1200, "exhaustion cannot mint a third source stock")
			check(world.hex_court.conservation_valid(), "failed payment preserves the existing finite ledger")


func _test_held_bolt_controls() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "held Bolt fixture uses the real catalog")
	for ability_id: String in ["cinder-shell", "tideline"]:
		var invalid := AbilityCatalog.new()
		invalid.data = catalog.data.duplicate(true)
		if ability_id == "cinder-shell":
			invalid.data.spell_matrix.family_templates.heavy.repeat_while_held = true
		else:
			for ability: Dictionary in invalid.data.abilities:
				if String(ability.id) == ability_id: ability.repeat_while_held = true
		check(not invalid.validate() and invalid.last_error.contains("only Bolt and Rapid"),
			"authoring rejects held %s, not just the current data values: %s" % [ability_id, invalid.last_error])
	for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		var wire := int(catalog.ability(catalog.spell_id_at(element, "bolt")).wire_id)
		var definition := CombatTuning.cast_definition(wire)
		check(bool(definition.repeat_while_held), "every element's Bolt supports the same held input")
		for slot: int in [0, 4, 8]:
			var world := _world()
			check(world.player().place_proven_spell(slot, wire), "Bolt can be assigned to each layer")
			var before := world.player().flux
			var starts := 0
			for tick: int in 84:
				_step(world, _command(world, SimCommand.SPELL_HELD_BITS[slot], SimCommand.SPELL_PRESSED_BITS[slot] if tick == 0 else 0))
				starts += _events(world, "cast_started", wire).size()
			check(starts >= 3, "held Bolt repeats through the normal cooldown without repeated press edges")
			equal(before - world.player().flux, starts * int(definition.flux_cost), "every repeated Bolt pays exactly once")
			var after_release := world.player().flux
			for tick: int in 40:
				_step(world, _command(world))
				equal(_events(world, "cast_started", wire).size(), 0, "release stops new Bolts; an already paid startup may finish")
			equal(world.player().flux, after_release, "released input never schedules or pays a latent repeat")
			world.player().flux = 0
			for tick: int in 40:
				_step(world, _command(world, SimCommand.SPELL_HELD_BITS[slot]))
				equal(_events(world, "cast_started", wire).size(), 0, "holding Bolt cannot mint Flux or bypass payment")
				equal(_events(world, "cast_refused").size(), 0, "held unaffordable Bolt does not spam refusals")
		var priority := _world()
		check(priority.player().place_proven_spell(0, wire) and priority.player().place_proven_spell(1, 179), "priority uses one held Bolt and a deliberate Heavy")
		_step(priority, _command(priority, SimCommand.SPELL_HELD_BITS[0], SimCommand.PRESSED_SPELL_2))
		equal(priority.player().pending_cast_wire_id, 179, "fresh Heavy wins over held Bolt when ready, without replacing paid startup")
		equal(priority.player().flux, 140_000, "switching from held Bolt pays exactly20 Flux for one Heavy only")


func _world(seed: int = 8209) -> SimWorld:
	var world := SimWorld.new(120, seed, CollisionWorld.new(8_000_000, 8_000_000))
	_configure(world.player())
	return world


func _configure(actor: PlayerState) -> void:
	actor.champion_wire_id = 1
	actor.position_x = ORIGIN.x
	actor.position_y = ORIGIN.y
	actor.team_id = 1
	actor.health_recovery_per_second = 0
	actor.flux_maximum = 160_000
	actor.flux = 160_000
	actor.flux_recovery_per_second = 0


func _victim(entity_id: int, position: Vector2i) -> PlayerState:
	var actor := PlayerState.new(entity_id)
	_configure(actor)
	actor.team_id = 2
	actor.position_x = position.x
	actor.position_y = position.y
	return actor


func _command(world: SimWorld, held: int = 0, pressed: int = 0, target: Vector2i = FAR_POINT, direction: Vector2i = Vector2i.ZERO) -> SimCommand:
	return SimCommand.new(world.tick, 1, direction.x, direction.y, held, pressed, 1000, 0, target.x, target.y)


func _step(world: SimWorld, command: SimCommand = null) -> void:
	var commands: Array[SimCommand] = []
	if command != null:
		commands.append(command)
	check(world.step(commands), "real delivery tick succeeds: %s" % world.last_error)
	check(world.last_error.is_empty(), "a paid cast keeps its terminal matter reservation")


func _events(world: SimWorld, kind: String, wire: int = 0) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event: Dictionary in world.combat_events:
		if String(event.get("type", "")) == kind and (wire == 0 or int(event.get("wire_id", event.get("source_wire_id", 0))) == wire):
			found.append(event)
	return found


func _terminal_deposits(world: SimWorld, seen_trail_ids: Dictionary) -> Array[ElementDepositState]:
	var found: Array[ElementDepositState] = []
	for deposit: ElementDepositState in world.deposits:
		if deposit.is_trail():
			# Keep IDs even after expiry or promotion: both material roles share
			# the allocator, but only a terminal proves the Heavy has impacted.
			seen_trail_ids[deposit.entity_id] = true
		else:
			found.append(deposit)
	return found


func _start(world: SimWorld, wire: int, target: Vector2i = FAR_POINT) -> void:
	check(world.player().place_proven_spell(0, wire), "real delivery wire %d can be woven" % wire)
	var before := world.player().flux
	_step(world, _command(world, 0, SimCommand.PRESSED_SPELL_1, target))
	equal(world.player().pending_cast_wire_id, wire, "wire %d owns paid startup" % wire)
	equal(world.player().flux, before - int(CombatTuning.cast_definition(wire)["flux_cost"]), "wire %d pays exactly its authored Flux cost" % wire)
	equal(_events(world, "cast_started", wire).size(), 1, "one explicit press accepts exactly one cast")


func _release(world: SimWorld, wire: int) -> Array[Dictionary]:
	for _tick: int in range(90):
		# Later aim changes may not redirect an accepted cursor endpoint.
		_step(world, _command(world, 0, 0, Vector2i(1_000_000, 6_000_000)))
		var spawned := _events(world, "projectile_spawned", wire)
		if not spawned.is_empty():
			return spawned
	check(false, "wire %d releases within its bounded startup" % wire)
	return []


func _test_real_catalog_and_paid_lanes() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "expanded real catalog validates")
	for index: int in range(ELEMENTS.size()):
		for family: String in ["heavy", "rapid"]:
			var wire: int = HEAVY_WIRES[index] + int(family == "rapid")
			var definition := CombatTuning.cast_definition(wire)
			equal(int(definition.get("element_wire_id", 0)), ELEMENTS[index], "%s wire %d preserves element identity" % [family, wire])
			if family == "heavy":
				for key: String in ["speed", "radius", "damage", "blast_radius", "blast_damage", "flux_cost", "startup_ms", "cooldown_ms"]:
					var expected: Dictionary = {"speed": 180_000, "radius": 30_000, "damage": 24_000, "blast_radius": 120_000, "blast_damage": 18_000, "flux_cost": 20_000, "startup_ms": 200, "cooldown_ms": 900}
					equal(int(definition.get(key, 0)), int(expected[key]), "Heavy %d has the shared %s contract" % [wire, key])
			elif family == "rapid":
				for key: String in ["speed", "radius", "damage", "flux_cost", "startup_ms", "cooldown_ms"]:
					var expected: Dictionary = {"speed": 600_000, "radius": 4000, "damage": 3000, "flux_cost": 2000, "startup_ms": 8, "cooldown_ms": 80}
					equal(int(definition.get(key, 0)), int(expected[key]), "Rapid %d has the shared %s contract" % [wire, key])
				equal(bool(definition.get("repeat_while_held", false)), true, "every element's Rapid explicitly opts into held-number repeat")
			var world := _world()
			_start(world, wire)
			var spawned := _release(world, wire)
			equal(spawned.size(), 1, "wire %d releases its one authored lane in one authoritative tick" % wire)
			equal(world.projectiles.size(), 1, "wire %d does not silently add projectiles" % wire)
			var strength := 0
			var first_cast := 0
			var remaining := -1
			for lane: ProjectileState in world.projectiles:
				if first_cast == 0:
					first_cast = lane.source_cast_id
					remaining = lane.remaining_distance
				equal(lane.source_cast_id, first_cast, "all lanes share one paid cast identity")
				equal(lane.element_wire_id, ELEMENTS[index], "live projectile carries its real element")
				equal(lane.radius, int(definition["radius"]), "live collision radius exactly matches authored simulation geometry")
				check(lane.velocity_x > 0, "later mouse movement cannot redirect the locked eastward release")
				check(lane.remaining_distance > 0 and absi(lane.remaining_distance - remaining) <= 10, "lanes share one finite locked range")
				strength += lane.material_strength
			equal(strength, 1000, "one cast partitions exactly one material contribution")


func _test_archived_field_records_are_gated() -> void:
	# Archived-data coverage preserves identity and authored geometry without
	# equipping a Field or constructing a live cast definition.
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "catalog loads for archived Field data")
	var field_ids: Array[String] = ["rimewake", "hearthring", "springwell", "stonehold", "updraft", "static-snare", "halo-ground", "umbral-pool"]
	for ability_id: String in field_ids:
		var ability: Dictionary = catalog.ability(ability_id)
		var wire := int(ability.get("wire_id", 0))
		var baseline_radius := 72_000 if wire == 144 else 85_000
		equal(String(ability.get("runtime_status", "")), "catalog_only", ability_id + " remains explicitly archived")
		equal(int(ability.get("radius", 0)) * 5, baseline_radius * 6, ability_id + " preserves its authored enlarged radius")
		check(not CombatTuning.is_runtime_wire_id(wire), ability_id + " is excluded from runtime admission")
		check(CombatTuning.cast_definition(wire).is_empty(), ability_id + " has no compiled live cast definition")


func _test_retired_delivery_admission_fails_closed() -> void:
	var state := PlayerState.new()
	for wire: int in [146, 155, 156, 101, 167, 170, 171, 187, 188, 189, 190]:
		var before_slots := PackedInt32Array(state.spell_wire_ids)
		var before_cooldowns := PackedInt32Array(state.spell_cooldown_ticks)
		var before_flux := state.flux
		check(not state.place_proven_spell(0, wire), "retired delivery or Ice/Charge base wire is rejected: %d" % wire)
		equal(state.spell_wire_ids, before_slots, "retired delivery rejection preserves weave positions")
		equal(state.spell_cooldown_ticks, before_cooldowns, "retired delivery rejection preserves cooldowns")
		equal(state.flux, before_flux, "retired delivery rejection spends no Flux")


func _test_heavy_direct_hit_and_single_terminal() -> void:
	for index: int in range(ELEMENTS.size()):
		var wire := HEAVY_WIRES[index]
		var world := _world()
		var direct := _victim(2, ORIGIN + Vector2i(200_000, 0))
		var splash := _victim(3, ORIGIN + Vector2i(175_000, 55_000))
		world.players.append_array([direct, splash])
		var direct_before := direct.health
		var splash_before := splash.health
		_start(world, wire)
		var hit_count := {2: 0, 3: 0}
		var terminals := 0
		var initial_deposit_id := world.next_deposit_id
		var seen_trail_ids := {}
		var terminal_deposits: Array[ElementDepositState] = []
		for _tick: int in range(150):
			_step(world)
			for event: Dictionary in _events(world, "projectile_hit", wire):
				var target_id := int(event["target_id"])
				hit_count[target_id] = int(hit_count.get(target_id, 0)) + 1
			# SimWorld consumes the private event before exposing combat_events.
			# Discount every observed flight allocation without treating a trail
			# as impact evidence; retain the exact one-terminal allocation check.
			terminal_deposits = _terminal_deposits(world, seen_trail_ids)
			terminals = world.next_deposit_id - initial_deposit_id - seen_trail_ids.size()
			if not terminal_deposits.is_empty():
				break
		equal(direct.health, direct_before - 24_000, "Heavy %d direct victim receives its stronger contact hit, never a second blast hit" % wire)
		equal(splash.health, splash_before - 18_000, "Heavy %d applies one nearby area hit" % wire)
		equal(hit_count, {2: 1, 3: 1}, "direct and area victims each receive exactly one hit event")
		equal(terminals, 1, "Heavy emits exactly one normal terminal event")
		equal(terminal_deposits.size(), 1, "one Heavy terminal becomes one existing elemental deposit, separately from flight trails")
		equal(world.projectiles.size(), 0, "Heavy direct impact retires the projectile rather than stopping the fixture on a trail")
		if terminal_deposits.size() == 1:
			equal(terminal_deposits[0].element_wire_id, ELEMENTS[index], "Heavy terminal preserves its authored element")
		for _tick: int in range(3):
			_step(world)
			equal(_events(world, "projectile_hit", wire).size(), 0, "spent Heavy cannot reapply its blast on later ticks")


func _shell(wire: int = 179, damage: int = 18_000) -> ProjectileState:
	return ProjectileState.new(1000, 1, 1, wire, int(CombatTuning.cast_definition(wire)["element_wire_id"]), ORIGIN, Vector2i(400_000, 0), 16_000, damage, 200)


func _test_heavy_protection_and_split_damage() -> void:
	var config := SimConfig.new(120)
	var collision := CollisionWorld.new(8_000_000, 8_000_000)
	for index: int in range(ELEMENTS.size()):
		for protection: String in ["none", "height_only", "below_clearance", "slide", "neutral_slide", "crouch", "wallrun", "ally", "owner", "dead", "spawn", "float", "hop", "air_dodge", "excluded", "outside"]:
			var victim := _victim(2, ORIGIN + Vector2i(50_000, 0))
			match protection:
				"height_only":
					victim.air_height = MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT
					victim.hop_ticks = 10
				"below_clearance": victim.air_height = MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT - 1
				"slide": victim.slide_ticks = 10
				"neutral_slide":
					victim.champion_wire_id = 19 # Jan's Human and personal windows are inactive while sliding.
					victim.slide_ticks = 10
				"crouch": victim.crouching = true
				"wallrun":
					victim.air_height = 60_000
					victim.wall_skim_ticks = 10
				"ally": victim.team_id = 1
				"owner": victim.entity_id = 1
				"dead": victim.health = 0
				"spawn": victim.spawn_protection_ticks = 5
				"float":
					victim.air_height = 25_000
					victim.flight_capable = true
					victim.air_floating = true
					victim.float_ticks = 10
				"hop":
					victim.hop_ticks = 10
					victim.jump_protection_ticks = 5
				"air_dodge": victim.air_dodge_ticks = config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS)
				"outside": victim.position_x = ORIGIN.x + 200_000
			var before := victim.health
			var events: Array[Dictionary] = []
			var players: Array[PlayerState] = [victim]
			CombatSystem._explode_projectile(_shell(HEAVY_WIRES[index]), players, config, collision, [], 50, events, 2 if protection == "excluded" else 0)
			var damages := protection in ["none", "below_clearance", "slide", "neutral_slide", "crouch", "wallrun", "hop"]
			# The same grounded slide is hittable for both identities. OhTipi's
			# Seakin tradeoff adds exactly 5% incoming damage during this window.
			var expected_damage := 18_900 if protection == "slide" else 18_000
			equal(victim.health, before - expected_damage if damages else before, "Heavy %d ground blast respects %s height, timed protection and situational vulnerability" % [HEAVY_WIRES[index], protection])
			var hit_events := events.filter(func(event: Dictionary) -> bool: return event.get("type") == "projectile_hit")
			equal(hit_events.size(), 1 if damages else 0, "ineligible area victims emit no misleading hit event")
			if not hit_events.is_empty():
				equal(int(hit_events[0].damage), expected_damage, "area hit feedback reports actual Health loss, including the independently expected Seakin slide tradeoff")
		var split_target := _victim(2, ORIGIN + Vector2i(50_000, 0))
		var before := split_target.health
		var split_events: Array[Dictionary] = []
		CombatSystem._explode_projectile(_shell(HEAVY_WIRES[index], 9000), [split_target], config, collision, [], 50, split_events)
		equal(split_target.health, before - 9000, "an optical half-damage shell cannot recreate a full-strength blast")
	var defeated := _victim(2, ORIGIN + Vector2i(50_000, 0))
	defeated.health = 10_000
	var events: Array[Dictionary] = []
	CombatSystem._explode_projectile(_shell(), [defeated], config, collision, [], 50, events)
	equal(defeated.health, 0, "area damage defeats a low-health champion")
	equal(events.filter(func(event: Dictionary) -> bool: return event.get("type") == "champion_defeated").size(), 1, "one lethal area hit emits exactly one defeat")


func _cover() -> ElementReactionState:
	var cover := ElementReactionState.new()
	cover.entity_id = 4000
	cover.recipe_wire_id = 301
	cover.owner_id = 3
	cover.team_id = 3
	cover.position_x = ORIGIN.x + 25_000
	cover.position_y = ORIGIN.y
	cover.origin_x = cover.position_x
	cover.origin_y = cover.position_y
	# Cover direction is its normal; the physical long axis is perpendicular.
	cover.direction_x = 1000
	cover.direction_y = 0
	cover.created_tick = 0
	cover.active_tick = 20
	cover.decay_tick = 100
	cover.expiry_tick = 140
	var definition := ElementChemistrySystem.recipe(301)
	cover.radius = int(definition.radius)
	cover.length = int(definition.length)
	cover.health = 32_000
	cover.source_a = 2000
	cover.source_b = 2001
	cover.endpoint_x = cover.position_x + cover.length
	cover.endpoint_y = cover.position_y
	check(cover.validate(), "temporary cover fixture is a valid authoritative Fortify")
	return cover


func _test_heavy_solid_and_temporary_cover() -> void:
	var config := SimConfig.new(120)
	for obstruction: String in ["worldbone", "active_cover", "forming_cover", "decaying_cover", "broken_cover"]:
		var collision := CollisionWorld.new(8_000_000, 8_000_000)
		var target := _victim(2, ORIGIN + Vector2i(60_000, 0))
		var cover := _cover()
		var reactions: Array[ElementReactionState] = []
		var tick := 50
		if obstruction == "worldbone":
			collision.add_obstacle(CollisionWorld.Obstacle.new(7, ORIGIN.x + 20_000, ORIGIN.y - 100_000, ORIGIN.x + 30_000, ORIGIN.y + 100_000))
		else:
			reactions.append(cover)
			if obstruction == "forming_cover": tick = cover.active_tick - 1
			if obstruction == "decaying_cover": tick = cover.decay_tick
			if obstruction == "broken_cover": cover.health = 0
		var before := target.health
		var cover_before := cover.canonical_values()
		var events: Array[Dictionary] = []
		CombatSystem._explode_projectile(_shell(), [target], config, collision, reactions, tick, events)
		var blocked := obstruction in ["worldbone", "active_cover"]
		equal(target.health, before if blocked else before - 18_000, "blast line of sight respects exact %s lifecycle" % obstruction)
		equal(cover.canonical_values(), cover_before, "blast visibility checks never mutate cover per candidate victim")
	# The impact integration must originate outside surviving cover; otherwise
	# starting a visibility ray inside the cover hides even its exposed side.
	var collision := CollisionWorld.new(8_000_000, 8_000_000)
	var cover := _cover()
	check(not ElementChemistrySystem.contains(cover, ORIGIN, 50, config), "construct impact fixture launches outside the temporary cover")
	check(ElementChemistrySystem.contains(cover, ORIGIN + Vector2i(10_000, 0), 50, config), "construct impact fixture crosses the cover's exposed boundary")
	var front := _victim(2, ORIGIN + Vector2i(-30_000, 40_000))
	var back := _victim(3, ORIGIN + Vector2i(60_000, 0))
	var before_front := front.health
	var before_back := back.health
	var active: Array[ProjectileState] = [_shell()]
	var events: Array[Dictionary] = []
	for _tick: int in range(10):
		active = CombatSystem.advance_projectiles(active, [front, back], config, collision, events, [cover], 50)
		if active.is_empty(): break
	check(active.is_empty() and cover.health > 0, "Heavy really impacts, but does not destroy, the temporary Fortify")
	equal(cover.health, 14_000, "one Heavy impact spends its 18 damage on temporary cover once")
	equal(front.health, before_front - 18_000, "Heavy construct impact splashes the exposed side of surviving cover")
	equal(back.health, before_back, "surviving temporary cover still blocks the same impact blast on its sheltered side")
	equal(events.filter(func(event: Dictionary) -> bool: return event.get("type") == "projectile_terminal").size(), 1, "construct contact emits exactly one ordinary terminal matter event")
	# Compare actual explosion origins on both sides of the source-derived
	# face, not offsets that become interior after a footprint balance change.
	var face_x := ElementChemistrySystem.rampart_bounds(cover).position.x - ORIGIN.x
	for penetrated: bool in [true, false]:
		var offset_x := face_x + (1000 if penetrated else -1000)
		equal(ElementChemistrySystem.contains(cover, ORIGIN + Vector2i(offset_x, 0), 50, config), penetrated, "negative-control origin is actually inside or outside the live cover face")
		var sample_target := _victim(4, ORIGIN + Vector2i(-30_000, 40_000))
		var sample_before := sample_target.health
		var sample_shell := _shell()
		sample_shell.position_x += offset_x
		var sample_events: Array[Dictionary] = []
		CombatSystem._explode_projectile(sample_shell, [sample_target], config, collision, [cover], 50, sample_events)
		equal(sample_target.health, sample_before if penetrated else sample_before - 18_000, "inside versus exposed sample proves why Heavy contact-origin correction is necessary")


func _test_heavy_range_wall_and_lifetime() -> void:
	for terminal: String in ["range", "wall", "lifetime"]:
		var world := _world()
		var target := ORIGIN + Vector2i(240_000, 0)
		var splash_offset := Vector2i(240_000, 55_000)
		if terminal == "wall":
			world.collision.add_obstacle(CollisionWorld.Obstacle.new(9, ORIGIN.x + 150_000, ORIGIN.y - 100_000, ORIGIN.x + 170_000, ORIGIN.y + 100_000))
			splash_offset = Vector2i(135_000, 55_000)
		if terminal == "lifetime":
			splash_offset = Vector2i(3000, 55_000)
			var projectile := _shell()
			projectile.lifetime_ticks = 1
			projectile.source_cast_id = 1000
			world.projectiles.append(projectile)
		else:
			_start(world, 179, target)
		var splash := _victim(2, ORIGIN + splash_offset)
		var before := splash.health
		world.players.append(splash)
		var terminals := 0
		var initial_deposit_id := world.next_deposit_id
		var seen_trail_ids := {}
		var terminal_deposits: Array[ElementDepositState] = []
		for _tick: int in range(160):
			_step(world, _command(world, 0, 0, ORIGIN + Vector2i(0, 500_000)))
			terminal_deposits = _terminal_deposits(world, seen_trail_ids)
			terminals = world.next_deposit_id - initial_deposit_id - seen_trail_ids.size()
			if not terminal_deposits.is_empty(): break
		equal(terminals, 1, "Heavy %s termination emits one existing matter event" % terminal)
		equal(world.projectiles.size(), 0, "Heavy %s removes the spent projectile" % terminal)
		equal(terminal_deposits.size(), 1, "Heavy %s does not duplicate its terminal residue, separately from flight trails" % terminal)
		equal(splash.health, before - 18_000, "Heavy %s actually blasts a nearby non-contact target" % terminal)
		if terminal_deposits.size() != 1: continue
		var point := Vector2i(terminal_deposits[0].position_x, terminal_deposits[0].position_y)
		if terminal == "range":
			check(absi(point.x - target.x) <= 3 and absi(point.y - target.y) <= 3, "Heavy explodes at its accepted cursor endpoint, not the later cursor")
		elif terminal == "wall":
			check(point.x <= ORIGIN.x + 150_000 and point.y == ORIGIN.y, "wall impact never deposits the shell through solid worldbone")


func _test_wider_spray_remains_close_range_and_cover_bound() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "wide Spray geometry uses every live authored element")
	var config := SimConfig.new(120)
	var owner := PlayerState.new(1)
	_configure(owner)
	for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		var wire := int(catalog.ability(catalog.spell_id_at(element, "spray")).wire_id)
		var definition := CombatTuning.cast_definition(wire)
		for scenario: String in ["wide_left", "wide_right", "angle_edge", "angle_outside", "range_edge", "range_outside", "cover", "airborne", "crouch", "spawn", "ally"]:
			var collision := CollisionWorld.new(8_000_000, 8_000_000)
			var offset := Vector2i(200_000, 160_000) #38.7 degrees: outside either previous25/30-degree half-cone.
			if scenario == "wide_left": offset.y = -offset.y
			if scenario == "angle_edge": offset = Vector2i(100_000, 100_000)
			if scenario == "angle_outside": offset = Vector2i(100_000, 100_001)
			if scenario == "range_edge": offset = Vector2i(int(definition.range), 0)
			if scenario == "range_outside": offset = Vector2i(int(definition.range) + 1, 0)
			var target := _victim(2, ORIGIN + offset)
			if scenario == "cover": collision.add_obstacle(CollisionWorld.Obstacle.new(7, ORIGIN.x + 100_000, ORIGIN.y + 50_000, ORIGIN.x + 120_000, ORIGIN.y + 110_000, false))
			if scenario == "airborne": target.air_height = MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT
			if scenario == "crouch": target.crouching = true
			if scenario == "spawn": target.spawn_protection_ticks = 1
			if scenario == "ally": target.team_id = owner.team_id
			var before := target.health
			var events: Array[Dictionary] = []
			CombatSystem._resolve_spray(owner, wire, definition, ORIGIN, Vector2i(1000, 0), ORIGIN + Vector2i(int(definition.range), 0), [target], config, collision, events)
			var expected_hit := scenario in ["wide_left", "wide_right", "angle_edge", "range_edge"]
			equal(target.health, before - int(definition.damage) if expected_hit else before, "%s Spray: wider %s cone obeys exact range, cover, and avoidance" % [element, scenario])
			var hits := 0
			for event: Dictionary in events:
				if event.get("type", "") == "spray_hit": hits += 1
			equal(hits, 1 if expected_hit else 0, "wide fan never invents an extra or refused damage event")
			if scenario in ["wide_left", "wide_right"]:
				var previous_cone := definition.duplicate(true)
				previous_cone.cone_cosine_squared_per_million = 750_000 if element == "water" else 820_000
				target = _victim(2, ORIGIN + offset)
				events.clear()
				CombatSystem._resolve_spray(owner, wire, previous_cone, ORIGIN, Vector2i(1000, 0), ORIGIN + Vector2i(int(definition.range), 0), [target], config, collision, events)
				equal(target.health, before, "negative control proves newly useful side area came from the wider authored cone")


func _test_rapid_repeat_payment_and_release() -> void:
	for index: int in range(ELEMENTS.size()):
		var wire := HEAVY_WIRES[index] + 1
		var world := _world()
		check(world.player().place_proven_spell(0, wire), "Rapid repeat fixture equips the real elemental spell")
		var before := world.player().flux
		var starts := 0
		var releases: Array[int] = []
		var release_count := 0
		var cast_ids := {}
		for _tick: int in range(100):
			_step(world, _command(world, SimCommand.SPELL_HELD_BITS[0]))
			starts += _events(world, "cast_started", wire).size()
			if not _events(world, "projectile_spawned", wire).is_empty(): releases.append(world.tick)
			release_count += _record_rapid_releases(world, wire, cast_ids)
			equal(_events(world, "cast_refused").size(), 0, "held Rapid cooldown/startup is silent, not an error event every tick")
		check(starts >= 6 and releases.size() >= 6, "holding Rapid %d repeatedly accepts and releases paid shots" % wire)
		equal(before - world.player().flux, starts * 2000, "Rapid pays exactly once per accepted shot, never once per held tick")
		for release_index: int in range(1, releases.size()):
			equal(releases[release_index] - releases[release_index - 1], world.config.milliseconds_to_ticks(8) + world.config.milliseconds_to_ticks(80), "held Rapid pays its exact8ms startup plus80ms release-owned cooldown")
		var after_release := world.player().flux
		for _tick: int in range(50):
			_step(world, _command(world))
			release_count += _record_rapid_releases(world, wire, cast_ids)
			equal(_events(world, "cast_started", wire).size(), 0, "releasing the number key ends auto-repeat immediately")
			# An already accepted startup may finish; no future startup is invented.
			if _tick > world.config.milliseconds_to_ticks(25):
				equal(_events(world, "projectile_spawned", wire).size(), 0, "only an already-paid startup may release after key-up")
		equal(world.player().flux, after_release, "key-up never pays for a phantom follow-up shot")
		equal(release_count, starts, "every paid Rapid startup releases exactly one projectile after the final startup drains")
		equal(cast_ids.size(), starts, "Rapid assigns exactly one distinct cast identity to each paid shot")


func _record_rapid_releases(world: SimWorld, wire: int, cast_ids: Dictionary) -> int:
	var spawned := _events(world, "projectile_spawned", wire)
	if not spawned.is_empty(): equal(spawned.size(), 1, "Rapid releases only one projectile per cast")
	for event: Dictionary in spawned:
		var found := false
		for projectile: ProjectileState in world.projectiles:
			if projectile.entity_id != int(event["projectile_id"]): continue
			found = true
			check(projectile.source_cast_id > 0 and not cast_ids.has(projectile.source_cast_id), "Rapid release owns a new, positive paid cast identity")
			cast_ids[projectile.source_cast_id] = true
		check(found, "Rapid far-range release event corresponds to a real admitted projectile")
	return spawned.size()


func _test_private_terminal_event_once() -> void:
	# The world consumes these private events. Verify the actual producer as
	# well as the paid-world deposit allocation checks above.
	var config := SimConfig.new(120)
	for terminal: String in ["actor", "obstacle", "range", "lifetime"]:
		var collision := CollisionWorld.new(8_000_000, 8_000_000)
		var projectile := _shell()
		var players: Array[PlayerState] = []
		if terminal == "actor": players.append(_victim(2, ORIGIN + Vector2i(25_000, 0)))
		if terminal == "obstacle": collision.add_obstacle(CollisionWorld.Obstacle.new(1, ORIGIN.x + 18_000, ORIGIN.y - 100_000, ORIGIN.x + 30_000, ORIGIN.y + 100_000))
		if terminal == "range": projectile.remaining_distance = 1000
		if terminal == "lifetime": projectile.lifetime_ticks = 1
		var events: Array[Dictionary] = []
		var survivors := CombatSystem.advance_projectiles([projectile], players, config, collision, events)
		var terminals: Array[Dictionary] = []
		for event: Dictionary in events:
			if event.get("type") == "projectile_terminal": terminals.append(event)
		equal(survivors.size(), 0, "private %s path retires the Heavy exactly once" % terminal)
		equal(terminals.size(), 1, "private %s path emits exactly one matter event before world consumption" % terminal)
		if terminals.size() == 1:
			equal(String(terminals[0]["reason"]), "range" if terminal == "lifetime" else terminal, "private terminal cause remains the existing pipeline contract")
		events.clear()
		CombatSystem.advance_projectiles(survivors, players, config, collision, events)
		equal(events.size(), 0, "retired Heavy never emits a second terminal on the next step")


func _test_held_priority_and_silent_refusals() -> void:
	for wire: int in [179, 154]:
		var world := _world()
		check(world.player().place_proven_spell(0, wire), "deliberate single-press fixture equips Heavy or Spray")
		var before := world.player().flux
		for _tick: int in range(30): _step(world, _command(world, SimCommand.SPELL_HELD_BITS[0]))
		equal(world.player().flux, before, "holding Heavy or Spray without an edge never auto-starts wire %d" % wire)
		_start(world, wire)
		var starts := 0
		for _tick: int in range(180):
			_step(world, _command(world, SimCommand.SPELL_HELD_BITS[0]))
			starts += _events(world, "cast_started", wire).size()
		equal(starts, 0, "holding Heavy or Spray after its explicit cast cannot repeat wire %d" % wire)
	var priority := _world()
	check(priority.player().place_proven_spell(0, 180) and priority.player().place_proven_spell(1, 179), "priority fixture equips Rapid and Heavy")
	_step(priority, _command(priority, SimCommand.SPELL_HELD_BITS[0] | SimCommand.HELD_PRIMARY, SimCommand.PRESSED_SPELL_2))
	equal(priority.player().pending_cast_wire_id, 179, "fresh explicit Heavy press wins over held Rapid and held primary")
	equal(priority.player().flux, 140_000, "priority resolves one20Flux payment, not multiple concurrent casts")
	for refusal: String in ["flux", "capacity"]:
		var world := _world()
		check(world.player().place_proven_spell(0, 180), "silent refusal fixture equips Rapid")
		if refusal == "flux": world.player().flux = 4000
		else:
			for index: int in range(16):
				var projectile := ProjectileState.new(1000 + index, 1, 1, 180, 2, Vector2i(2_000_000 + 100_000 * index, 2_000_000), Vector2i.ZERO, 5000, 3000, 1000)
				projectile.source_cast_id = 1000 + index
				world.projectiles.append(projectile)
		var before := world.player().flux
		var starts := 0
		for _tick: int in range(70):
			_step(world, _command(world, SimCommand.SPELL_HELD_BITS[0]))
			starts += _events(world, "cast_started", 180).size()
			equal(_events(world, "cast_refused").size(), 0, "unaffordable/full-capacity held Rapid stays silent")
		equal(starts, 2 if refusal == "flux" else 0, "held Rapid cannot exceed available %s" % refusal)
		equal(world.player().flux, 0 if refusal == "flux" else before, "refused repeat spends no resource")
		_step(world, _command(world, 0, SimCommand.PRESSED_SPELL_1))
		var refused := _events(world, "cast_refused")
		equal(refused.size(), 1, "fresh explicit press still reports one actionable refusal")
		if refused.size() == 1: equal(String(refused[0].get("reason", "")), refusal, "explicit refusal identifies the real blocked resource")
	var primary := _world()
	var starts := 0
	for _tick: int in range(100):
		_step(primary, _command(primary, SimCommand.HELD_PRIMARY))
		starts += _events(primary, "cast_started").size()
	check(starts > 1, "existing held-left-mouse primary behavior remains available")


func _test_held_repeatable_slot_arbitration() -> void:
	for repeat_slot: int in range(SimCommand.SPELL_HELD_BITS.size()):
		for repeat_wire: int in [140, 180]:
			for single_wire: int in [179, 154]:
				var world := _world()
				var single_slot := (repeat_slot + 11) % 12
				check(world.player().place_proven_spell(single_slot, single_wire) and world.player().place_proven_spell(repeat_slot, repeat_wire), "held arbitration equips a repeating and a single-press spell across all twelve positions")
				var before := world.player().flux
				var held := SimCommand.SPELL_HELD_BITS[single_slot] | SimCommand.SPELL_HELD_BITS[repeat_slot]
				_step(world, _command(world, held))
				equal(world.player().pending_cast_wire_id, repeat_wire, "held Heavy or Spray cannot suppress held Bolt or Rapid in position %d" % (repeat_slot + 1))
				equal(world.player().flux, before - int(CombatTuning.cast_definition(repeat_wire).flux_cost), "held arbitration admits exactly one paid repeating spell")
				var deliberate := _world()
				check(deliberate.player().place_proven_spell(single_slot, single_wire) and deliberate.player().place_proven_spell(repeat_slot, repeat_wire), "fresh-press arbitration uses the same twelve-position chord")
				_step(deliberate, _command(deliberate, held | SimCommand.HELD_PRIMARY, SimCommand.SPELL_PRESSED_BITS[single_slot]))
				equal(deliberate.player().pending_cast_wire_id, single_wire, "fresh Heavy or Spray overrides every held repeat and primary in position %d" % (single_slot + 1))
				equal(deliberate.player().flux, before - int(CombatTuning.cast_definition(single_wire).flux_cost), "fresh priority still starts and pays exactly one spell")
				var starts := 1
				for _tick: int in range(45):
					_step(world, _command(world, held))
					starts += _events(world, "cast_started", repeat_wire).size()
					check(_events(world, "cast_started", single_wire).is_empty(), "held single-press spell never starts during repeat arbitration")
				check(starts >= 2, "mixed held chord actually repeats the selected Bolt or Rapid")
				equal(world.player().flux, before - starts * int(CombatTuning.cast_definition(repeat_wire).flux_cost), "mixed chord pays the exact complete repeating-cast count")
				var release_flux := world.player().flux
				for _tick: int in range(30):
					_step(world, _command(world, SimCommand.SPELL_HELD_BITS[single_slot]))
					check(_events(world, "cast_started").is_empty(), "releasing repeating input leaves no latent cast behind a held single-press spell")
				equal(world.player().flux, release_flux, "release stops new payment while preserving an already-paid startup")


func _test_held_repeatable_priority_gates() -> void:
	var empty := _world()
	check(empty.player().place_proven_spell(11, 180), "empty lower hold fixture equips an upper-layer Rapid")
	# Starter weaves fill all twelve positions; make this slot explicitly empty.
	empty.player().spell_wire_ids[5] = 0
	empty.player().spell_cooldown_ticks[5] = 0
	empty.player()._sync_legacy_spell_cooldowns()
	check(empty.player().has_valid_spell_slots() and empty.player().spell_wire_id(6) == 0, "held empty-position fixture is valid and actually empty")
	_step(empty, _command(empty, SimCommand.SPELL_HELD_BITS[5] | SimCommand.SPELL_HELD_BITS[11]))
	equal(empty.player().pending_cast_wire_id, 180, "an empty lower held position cannot mask a repeat-enabled upper position")
	for slot: int in range(SimCommand.SPELL_HELD_BITS.size()):
		var other := (slot + 1) % 12
		var low := mini(slot, other)
		var high := maxi(slot, other)
		var held := SimCommand.SPELL_HELD_BITS[low] | SimCommand.SPELL_HELD_BITS[high] | SimCommand.HELD_PRIMARY
		var world := _world()
		check(world.player().place_proven_spell(low, 140) and world.player().place_proven_spell(high, 180), "two repeat-enabled positions are independently equipped")
		check(world.player().set_spell_cooldown(140, 2), "lower repeating position has one complete refused tick remaining")
		var before := world.player().flux
		_step(world, _command(world, held))
		equal(world.player().pending_cast_wire_id, 0, "cooling lower repeat-enabled slot cannot silently fall through to a higher spell or primary")
		equal(world.player().flux, before, "held cooldown arbitration never makes a replacement payment")
		check(_events(world, "cast_refused").is_empty(), "held cooldown remains silent")
		_step(world, _command(world, held))
		equal(world.player().pending_cast_wire_id, 140, "lowest repeat-enabled position starts exactly when its own cooldown expires")
		equal(world.player().flux, before - int(CombatTuning.cast_definition(140).flux_cost), "cooldown boundary retains ordinary positive payment")
		var fresh := _world()
		check(fresh.player().place_proven_spell(low, 140) and fresh.player().place_proven_spell(high, 180), "fresh priority fixture equips both repeats")
		_step(fresh, _command(fresh, held, SimCommand.SPELL_PRESSED_BITS[high]))
		equal(fresh.player().pending_cast_wire_id, 180, "fresh higher-position repeat wins over deterministic lower held priority")
	for reason: String in ["cooldown", "empty_slot", "flux", "control_rooted"]:
		var fresh := _world()
		check(fresh.player().place_proven_spell(0, 180) and fresh.player().place_proven_spell(11, 179), "refused fresh chord equips held Rapid and deliberate Heavy")
		var pressed := SimCommand.PRESSED_SPELL_12
		if reason == "cooldown": check(fresh.player().set_spell_cooldown(179, 3), "fresh Heavy owns its cooldown")
		if reason == "empty_slot":
			fresh.player().spell_wire_ids[5] = 0
			fresh.player().spell_cooldown_ticks[5] = 0
			fresh.player()._sync_legacy_spell_cooldowns()
			check(fresh.player().has_valid_spell_slots() and fresh.player().spell_wire_id(6) == 0, "fresh empty-position fixture is valid and actually empty")
			pressed = SimCommand.PRESSED_SPELL_6
		if reason == "flux": fresh.player().flux = int(CombatTuning.cast_definition(179).flux_cost) - 1
		if reason == "control_rooted": MovementSystem.apply_control_state(fresh.player(), PlayerState.ControlState.ROOTED, 1000, Vector2i.ZERO, 0, fresh.config)
		var before := fresh.player().flux
		_step(fresh, _command(fresh, SimCommand.SPELL_HELD_BITS[0] | SimCommand.SPELL_HELD_BITS[11] | SimCommand.HELD_PRIMARY, pressed))
		equal(fresh.player().pending_cast_wire_id, 0, "refused fresh " + reason + " cannot fall through to an affordable held alternative")
		equal(fresh.player().flux, before, "fresh " + reason + " refusal cannot spend for another held spell")
		var refused := _events(fresh, "cast_refused")
		equal(refused.size(), 1, "fresh refused priority gives one actionable explanation")
		if refused.size() == 1: equal(String(refused[0].reason), reason, "fresh refusal retains its exact admission reason")
	for reason: String in ["flux", "capacity", "control_rooted"]:
		var world := _world()
		check(world.player().place_proven_spell(0, 179) and world.player().place_proven_spell(11, 180), "mixed hold refusal fixture equips lower Heavy and upper Rapid")
		var actor := world.player()
		if reason == "flux": actor.flux = 0
		if reason == "control_rooted": MovementSystem.apply_control_state(actor, PlayerState.ControlState.ROOTED, 1000, Vector2i.ZERO, 0, world.config)
		var before := actor.flux
		var events: Array[Dictionary] = []
		var held := SimCommand.SPELL_HELD_BITS[0] | SimCommand.SPELL_HELD_BITS[11] | SimCommand.HELD_PRIMARY
		var result: Variant = CombatSystem.step_player(actor, _command(world, held), world.config, 300, 400, world.collision, events, world.transition_policy, 0 if reason == "capacity" else -1)
		check(result == null and actor.pending_cast_wire_id == 0 and events.is_empty(), "mixed held " + reason + " stays silent without a replacement cast")
		equal(actor.flux, before, "mixed held " + reason + " spends no Flux")


func _full_hex_capacity_policy() -> HexChemistryWorld:
	var court := HexChemistryWorld.new()
	check(court.configure_geometry(ORIGIN, [Vector2i.ZERO]), "capacity fixture configures actual immutable hex geometry")
	court.chemistry_enabled = true
	# Exercise actual reservation accounting, without injected product records,
	# raised limits or a synthetic admission_reason implementation.
	for index: int in HexChemistryWorld.MAX_PRODUCTS:
		var owner_id := 100 + index
		var reserved := court.reserve_cast(owner_id, 140)
		check(reserved, "capacity fixture reserves each real finite product slot")
		if reserved: court.commit_payment(owner_id)
	equal(court.reserved_products(), HexChemistryWorld.MAX_PRODUCTS, "real reservations occupy the existing product bound")
	equal(court.admission_reason(180), "hex_capacity", "real hex admission reports product capacity")
	check(court.conservation_valid(), "paid capacity fixture preserves its finite matter")
	return court


func _test_held_hex_capacity_feedback() -> void:
	var court := _full_hex_capacity_policy()
	var court_before := court.state_hash()
	for wire: int in [140, 180]:
		for primary: bool in [false, true]:
			var world := _world()
			var actor := world.player()
			check(actor.place_proven_spell(0, wire), "real hex-capacity fixture equips a repeating Bolt or Rapid")
			actor.primary_wire_id = wire
			var actor_before := actor.canonical_values()
			var last_event_before := actor.last_event
			var held: int = SimCommand.HELD_PRIMARY if primary else SimCommand.SPELL_HELD_BITS[0]
			for _tick: int in range(4):
				var events: Array[Dictionary] = []
				var result: Variant = CombatSystem.step_player(actor, _command(world, held), world.config, 500, 600, world.collision, events, world.transition_policy, -1, -1, court)
				check(result == null and events.is_empty(), "held hex-capacity retry creates neither attack nor repeated refusal")
				equal(actor.canonical_values(), actor_before, "held hex capacity preserves resources, cooldowns and pending cast state")
				equal(actor.last_event, last_event_before, "held hex capacity does not overwrite the latest action with refusal noise")
				equal(court.state_hash(), court_before, "held hex capacity cannot reserve, spend, cancel or change paid authority")
			var events: Array[Dictionary] = []
			var result: Variant = CombatSystem.step_player(actor, _command(world, held, SimCommand.PRESSED_SPELL_1), world.config, 500, 600, world.collision, events, world.transition_policy, -1, -1, court)
			check(result == null and events.size() == 1, "fresh press over held input retains one actionable hex-capacity refusal")
			if events.size() == 1:
				equal(events[0], {"type": "cast_refused", "entity_id": actor.entity_id, "wire_id": wire, "reason": "hex_capacity", "slot": 1}, "explicit hex capacity retains exact event identity and reason")
				equal(SessionSnapshot.decode_event(SessionSnapshot.encode_event(events[0])).reason, "other", "existing protocol keeps its preceding generic guest encoding for hex capacity")
			equal(actor.canonical_values(), actor_before, "explicit hex refusal changes no resources, cooldowns or pending cast")
			equal(court.state_hash(), court_before, "explicit hex refusal leaves all existing reservations untouched")
	check(court.conservation_valid(), "all held and explicit capacity failures leave paid matter conserved")


func _test_hex_reservation_failure_feedback() -> void:
	for pressed: bool in [false, true]:
		for primary: bool in [false, true]:
			var world := _world()
			var actor := world.player()
			check(actor.place_proven_spell(0, 180), "reservation failure fixture equips Rapid")
			actor.primary_wire_id = 180
			var actor_before := actor.canonical_values()
			var last_event_before := actor.last_event
			var policy := RefusingAdmissionPolicy.new()
			var events: Array[Dictionary] = []
			var held: int = SimCommand.HELD_PRIMARY if primary else SimCommand.SPELL_HELD_BITS[0]
			var command := _command(world, held, SimCommand.PRESSED_SPELL_1 if pressed else 0)
			var result: Variant = CombatSystem.step_player(actor, command, world.config, 500, 600, world.collision, events, world.transition_policy, -1, -1, policy)
			check(result == null, "failed reservation never begins or releases an attack")
			equal(policy.calls, PackedStringArray(["admission", "reserve"]), "reservation failure makes no requery, payment or cancellation callback")
			equal(actor.canonical_values(), actor_before, "reservation failure preserves resources, cooldowns and pending action")
			equal(events.size(), 1 if pressed else 0, "reservation failure is actionable only for a fresh explicit press")
			if pressed and events.size() == 1:
				equal(String(events[0].reason), "hex_capacity", "reservation failure retains its original taxonomy even when the callback changes future policy reasons")
				equal(actor.last_event, "cast_refused_hex_capacity_180", "explicit reservation refusal retains its ordinary action label")
			else:
				equal(actor.last_event, last_event_before, "held reservation failure does not overwrite the action label")


func _test_held_noncapacity_policy_errors() -> void:
	for reason: String in ["hex_court_preparation", "hex_unsupported_delivery", "extension_refusal"]:
		for pressed: bool in [false, true]:
			var world := _world()
			var actor := world.player()
			check(actor.place_proven_spell(0, 180), "non-capacity policy fixture equips Rapid")
			var actor_before := actor.canonical_values()
			var policy := RefusingAdmissionPolicy.new()
			policy.reason = reason
			var events: Array[Dictionary] = []
			var command := _command(world, SimCommand.SPELL_HELD_BITS[0], SimCommand.PRESSED_SPELL_1 if pressed else 0)
			var result: Variant = CombatSystem.step_player(actor, command, world.config, 500, 600, world.collision, events, world.transition_policy, -1, -1, policy)
			check(result == null and events.size() == 1, "non-capacity policy errors stay visible for held and pressed input")
			if events.size() == 1: equal(String(events[0].reason), reason, "non-capacity policy feedback retains its exact reason")
			equal(policy.calls, PackedStringArray(["admission"]), "non-capacity rejection cannot reserve or change callback order")
			equal(actor.canonical_values(), actor_before, "non-capacity policy rejection preserves resources, cooldowns and pending cast")


func _test_delivery_replay_in_eight_directions() -> void:
	var directions: Array[Vector2i] = [Vector2i(1000, 0), Vector2i(707, 707), Vector2i(0, 1000), Vector2i(-707, 707), Vector2i(-1000, 0), Vector2i(-707, -707), Vector2i(0, -1000), Vector2i(707, -707)]
	var left := _world(9191)
	var right := _world(9191)
	for world: SimWorld in [left, right]:
		check(world.player().place_proven_spell(0, 180) and world.player().place_proven_spell(1, 179) and world.player().place_proven_spell(2, 154), "replay equips retained Rapid, Heavy, and Spray")
	var observed := {}
	for tick: int in range(480):
		var direction: Vector2i = directions[tick / 60]
		var held: int = SimCommand.SPELL_HELD_BITS[0] if tick % 120 >= 65 and tick % 120 < 105 else 0
		var pressed: int = SimCommand.PRESSED_SPELL_2 if tick % 240 == 0 else (SimCommand.PRESSED_SPELL_3 if tick % 240 == 120 else 0)
		for world: SimWorld in [left, right]:
			_step(world, _command(world, held, pressed, Vector2i(2_000_000, 1_000_000), direction))
		for event: Dictionary in _events(left, "projectile_spawned"):
			observed[int(event["wire_id"])] = true
		for event: Dictionary in _events(left, "spray_fired"):
			observed[int(event["source_wire_id"])] = true
		equal(left.state_hash(), right.state_hash(), "mixed-delivery movement replay is canonical at tick %d" % tick)
		equal(left.combat_events, right.combat_events, "mixed-delivery event order is deterministic at tick %d" % tick)
	equal(observed.size(), 3, "deterministic replay actually releases Heavy, Rapid, and Spray")


func _test_router_plain_ctrl_alt_rapid() -> void:
	InputRouter.ensure_input_map()
	var previous := {}
	for action: StringName in InputMap.get_actions():
		previous[action] = Input.get_action_strength(action)
		Input.action_release(action)
	for slot_index: int in [0, 4, 8]:
		var router := InputRouter.new(1)
		var world := _world()
		check(world.player().place_proven_spell(slot_index, 180), "real router fixture equips Rapid at the plain/Ctrl/Alt number-one slot")
		if slot_index == 4: Input.action_press(InputRouter.SPELL_CTRL_LAYER_ACTION)
		if slot_index == 8: Input.action_press(InputRouter.SPELL_ALT_LAYER_ACTION)
		Input.action_press(InputRouter.SPELL_ACTIONS[0])
		var starts := 0
		for tick: int in range(60):
			var command := router.sample(world.tick, Vector2(ORIGIN) / 1000.0, Vector2(FAR_POINT) / 1000.0)
			equal(command.first_held_spell_slot(), slot_index + 1, "real InputRouter sustains the selected plain/Ctrl/Alt Rapid slot")
			equal(command.first_pressed_spell_slot(), slot_index + 1 if tick == 0 else 0, "real router emits one edge and subsequent held-only Rapid commands")
			_step(world, command)
			starts += _events(world, "cast_started", 180).size()
		check(starts >= 3, "real router plain/Ctrl/Alt hold reaches repeated paid Rapid casts")
		equal(160_000 - world.player().flux, starts * 2000, "real router repeat uses ordinary authoritative per-shot payment")
		Input.action_release(InputRouter.SPELL_ACTIONS[0])
		Input.action_release(InputRouter.SPELL_CTRL_LAYER_ACTION)
		Input.action_release(InputRouter.SPELL_ALT_LAYER_ACTION)
		for _tick: int in range(35):
			var command := router.sample(world.tick, Vector2(ORIGIN) / 1000.0, Vector2(FAR_POINT) / 1000.0)
			equal(command.first_held_spell_slot(), 0, "real router key-up clears every spell-held slot")
			_step(world, command)
			equal(_events(world, "cast_started", 180).size(), 0, "real router key-up cannot create another paid cast")
	for action: StringName in previous:
		Input.action_release(action)
		if float(previous[action]) > 0.0: Input.action_press(action, float(previous[action]))
