extends FluxTestSuite
@warning_ignore_start("integer_division")

const Perks = preload("res://src/sim/entities/identity_perk_policy.gd")
const Races = preload("res://src/content/race_perk_catalog.gd")
const Characters = preload("res://src/content/character_perk_catalog.gd")
const Scenarios = preload("res://tests/support/identity_perk_scenarios.gd")
const CharacterAudit = preload("res://tests/support/character_perk_audit.gd")

var abilities := AbilityCatalog.new()
var champions := ChampionCatalog.new()
var config := SimConfig.new(120)
var arena := CollisionWorld.new(10_000_000, 10_000_000)


func run() -> int:
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "perk tests load real abilities")
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "perk tests load real champion profiles")
	for error: String in CharacterAudit.errors(champions):
		check(false, error)
	_test_catalog_and_windows()
	_test_thresholds_and_guards()
	_test_damage_and_recovery_hooks()
	_test_movement_hooks()
	_test_cast_timing_hooks()
	_test_all_character_prediction_and_snapshots()
	_write_report()
	return finish("identity-perks")


func _actor(wire: int, enabled: bool = true) -> PlayerState:
	var state := PlayerState.new(1)
	check(champions.apply_to_player(state, String(champions.champion_ids_by_wire[wire])), "real profile applies for perk wire %d" % wire)
	state.position_x = 5_000_000
	state.position_y = 5_000_000
	state.health = state.health_maximum / 2
	state.flux = state.flux_maximum / 2
	state.stamina = state.stamina_maximum / 2
	if not enabled: state.champion_wire_id = 0
	return state


func _wire_for_ancestry(ancestry: String) -> int:
	for wire: int in champions.champion_ids_by_wire:
		var id := String(champions.champion_ids_by_wire[wire])
		if String(champions.champions_by_id[id].ancestry) == ancestry: return wire
	return 0


func _test_catalog_and_windows() -> void:
	equal(Races.all().size(), 21, "all twenty-one ancestries have a defined passive")
	equal(Characters.all().size(), 30, "all thirty characters have a personal passive")
	var ids := {}
	var signatures := {}
	var ancestry_ids: Array[String] = []
	var rows: Array[Dictionary] = Races.all()
	rows.append_array(Characters.all())
	for row: Dictionary in rows:
		var id := String(row.id)
		check(not ids.has(id), "passive stable ID is unique: " + id)
		ids[id] = true
		var signature := Characters.mechanical_signature(row)
		check(not signatures.has(signature), "condition/effect identity differs beyond a percentage: " + id)
		signatures[signature] = true
		for field: String in ["name", "summary", "window", "counter", "reference", "condition"]:
			check(not String(row.get(field, "")).is_empty(), id + " explains " + field)
		check(String(row.reference).begins_with("https://"), "passive has an inspectable external example")
		var wire := int(row.get("wire_id", 0))
		if row.has("ancestry"):
			ancestry_ids.append(String(row.ancestry))
			wire = _wire_for_ancestry(String(row.ancestry))
		check(wire > 0, "each passive has a current playable representative: " + id)
		if wire <= 0: continue
		var active := _actor(wire)
		check(Scenarios.prepare(active, String(row.condition)), "test fixture recognizes complete condition: " + id)
		check(Perks.condition_matches(active, String(row.condition)), "positive condition is actually satisfiable: " + id)
		var found := false
		for active_row: Dictionary in Perks.active_rows(active): found = found or String(active_row.id) == id
		check(found, "runtime resolves the expected ancestry or character passive: " + id)
		var nonneutral := false
		for effect: String in row.effects:
			check(effect in Perks.EFFECTS, "passive uses an implemented hook: " + effect)
			check(int(row.effects[effect]) >= 850 and int(row.effects[effect]) <= 1200, "individual effect stays in the authored small range")
			var actual := Perks.ratio(active, effect)
			check(actual >= 750 and actual <= 1350, "combined effects respect the runtime envelope")
			nonneutral = nonneutral or actual != 1000
			check(Perks.scale(active, effect, 1) >= 1, "positive costs and damage never round to zero")
			equal(Perks.scale(active, effect, 0), 0, "zero amounts cannot invent a resource or timer")
		check(nonneutral, "positive window changes at least one actual factor: " + id)
		_disable_first_condition(active, String(row.condition))
		check(not Perks.condition_matches(active, String(row.condition)), "leaving one required condition closes the window: " + id)
	ancestry_ids.sort()
	var supported := ChampionCatalog.SUPPORTED_ANCESTRIES.duplicate()
	supported.sort()
	equal(ancestry_ids, supported, "race catalog exactly covers current supported ancestries")
	for wire: int in champions.champion_ids_by_wire:
		var id := String(champions.champion_ids_by_wire[wire])
		equal(Races.ancestry_for_wire(wire), String(champions.champions_by_id[id].ancestry), "runtime race mapping matches actual content for " + id)
	var copied := Races.definition("dwarf")
	copied.effects.incoming_damage_ratio = 1
	equal(int(Races.definition("dwarf").effects.incoming_damage_ratio), 930, "public nested metadata cannot mutate runtime ancestry effects")
	check(Races.definition("unknown").is_empty() and Races.ancestry_for_wire(999) == "", "unknown ancestry and wire have no invented perk")


func _disable_first_condition(state: PlayerState, condition: String) -> void:
	match String(condition.split("&")[0]):
		"grounded", "grounded_walking", "grounded_crouching", "stationary_grounded", "retreating_grounded", "sprinting", "sliding", "jumpsquat", "landing": state.air_height = 36_000
		"low_health", "high_health": state.health = state.health_maximum / 2
		"low_flux", "high_flux": state.flux = state.flux_maximum / 2
		"low_stamina", "high_stamina": state.stamina = state.stamina_maximum / 2
		"pending_cast": state.pending_cast_ticks = 0
		"cast_recovery": state.cast_recovery_ticks = 0
		"airborne_rising", "airborne_descending": state.air_vertical_velocity = 0
		"airborne_spent_dodge": state.air_dodge_used = false
		"flight_active": state.air_floating = false
		"wallrunning": state.wall_skim_ticks = 0
		"slowed": state.control_ticks = 0
		"impact_recovery": state.impact_recovery_ticks = 0
		_: check(false, "missing negative fixture for " + condition)


func _test_thresholds_and_guards() -> void:
	var state := _actor(19)
	state.health_maximum = 120_000
	state.flux_maximum = 120_000
	state.stamina_maximum = 600_000
	for row: Array in [["health", "low_health", 40_000], ["flux", "low_flux", 40_000], ["stamina", "low_stamina", 200_000]]:
		state.set(row[0], row[2])
		check(Perks.condition_matches(state, row[1]), "low resource threshold includes exact one-third")
		state.set(row[0], int(row[2]) + 1)
		check(not Perks.condition_matches(state, row[1]), "one integer above the low threshold is excluded")
	for row: Array in [["health", "high_health", 90_000], ["flux", "high_flux", 80_000], ["stamina", "high_stamina", 400_000]]:
		state.set(row[0], row[2])
		check(Perks.condition_matches(state, row[1]), "high resource threshold includes its exact fraction")
		state.set(row[0], int(row[2]) - 1)
		check(not Perks.condition_matches(state, row[1]), "one integer below the high threshold is excluded")
	for mode: String in ["unknown", "defeated", "training"]:
		state = _actor(18)
		Scenarios.prepare(state, "grounded_crouching")
		if mode == "unknown": state.champion_wire_id = 999
		elif mode == "defeated": state.health = 0
		else: state.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
		for effect: String in Perks.EFFECTS: equal(Perks.ratio(state, effect), 1000, mode + " cannot activate an identity factor")
	for token: String in ["grounded_walking", "stationary_grounded", "retreating_grounded"]:
		for lock: int in [PlayerState.ControlState.LAUNCHED, PlayerState.ControlState.STUNNED, PlayerState.ControlState.ROOTED]:
			state = _actor(19)
			Scenarios.prepare(state, token)
			state.control_state = lock
			state.control_ticks = 12
			check(not Perks.condition_matches(state, token), "forced control is not voluntary ordinary posture")
		for timer: StringName in [&"air_dodge_ticks", &"wave_dash_ticks", &"slide_ticks", &"superglide_ticks", &"impact_recovery_ticks"]:
			state = _actor(19)
			Scenarios.prepare(state, token)
			state.set(timer, 12)
			check(not Perks.condition_matches(state, token), "authored action cannot masquerade as ordinary posture")
	check(not Perks.condition_matches(state, "unknown_condition"), "unknown window fails closed")
	state = _actor(20)
	Scenarios.prepare(state, "sprinting&high_stamina")
	equal(Perks.ratio(state, "ground_braking_ratio"), 750, "stacked 0.85 ancestry and character braking clamps at 0.75")


func _test_damage_and_recovery_hooks() -> void:
	var state := _actor(18)
	Scenarios.prepare(state, "grounded_crouching")
	var before := state.health
	check(PlayerResourcesSystem.damage(state, 10_000, config), "actual damage routine admits crouched hit")
	equal(before - state.health, 9300, "Low Bastion reduces actual Health loss, not projectile payload")
	check(state.health_recovery_delay_ticks > 0, "passive cannot remove the normal damage recovery delay")
	state = _actor(14)
	Scenarios.prepare(state, "jumpsquat")
	check(MovementSystem.apply_control_state(state, PlayerState.ControlState.LAUNCHED, 200, Vector2i(1000, 0), 400_000, config), "actual hit applies launch")
	equal(state.control_speed, 340_000, "Gathering Weight reduces actual launch before preparation cancels")
	check(not state.jumpsquat_active, "defensive passive cannot retain interrupted preparation")
	for row: Array in [[17, "stationary_grounded", "health"], [7, "low_flux", "flux"]]:
		state = _actor(int(row[0]))
		var ordinary := _actor(int(row[0]), false)
		Scenarios.prepare(state, row[1])
		Scenarios.prepare(ordinary, row[1])
		var resource := String(row[2])
		PlayerResourcesSystem.step(state, config)
		PlayerResourcesSystem.step(ordinary, config)
		check(int(state.get(resource)) > int(ordinary.get(resource)), "existing resource tick receives the contextual " + resource + " recovery")
		state.set(resource + "_recovery_delay_ticks", 10)
		before = int(state.get(resource))
		PlayerResourcesSystem.step(state, config)
		equal(int(state.get(resource)), before, "identity recovery cannot bypass its existing delay")
	state = _actor(23)
	var normal := _actor(23, false)
	Scenarios.prepare(state, "high_stamina")
	Scenarios.prepare(normal, "high_stamina")
	MovementSystem.step(state, SimCommand.new(0, 1), config, arena)
	MovementSystem.step(normal, SimCommand.new(0, 1), config, arena)
	check(state.stamina < normal.stamina, "Held Vigor pays its Stamina recovery drawback through real grounded movement")


func _test_movement_hooks() -> void:
	var state := _actor(7)
	var normal := _actor(7, false)
	Scenarios.prepare(state, "low_flux")
	Scenarios.prepare(normal, "low_flux")
	for tick: int in range(30):
		MovementSystem.step(state, SimCommand.new(tick, 1, 1000, 0), config, arena)
		MovementSystem.step(normal, SimCommand.new(tick, 1, 1000, 0), config, arena)
	check(state.velocity_x < normal.velocity_x, "Deep Reserve's actual walking target is slower")
	state = _actor(16)
	normal = _actor(16, false)
	Scenarios.prepare(state, "grounded_walking")
	Scenarios.prepare(normal, "grounded_walking")
	MovementSystem.step(state, SimCommand.new(0, 1, 1000, 0), config, arena)
	MovementSystem.step(normal, SimCommand.new(0, 1, 1000, 0), config, arena)
	check(state.velocity_x > normal.velocity_x, "Passing Rhythm changes real walking acceleration")
	state = _actor(20)
	normal = _actor(20, false)
	Scenarios.prepare(state, "sprinting&high_stamina")
	Scenarios.prepare(normal, "sprinting&high_stamina")
	MovementSystem.step(state, SimCommand.new(0, 1, -1000, 0, SimCommand.HELD_SPRINT), config, arena)
	MovementSystem.step(normal, SimCommand.new(0, 1, -1000, 0, SimCommand.HELD_SPRINT), config, arena)
	check(state.velocity_x > normal.velocity_x, "Committed Stride actually needs more distance to counter-brake")
	state = _actor(4)
	normal = _actor(4, false)
	Scenarios.prepare(state, "airborne_rising")
	Scenarios.prepare(normal, "airborne_rising")
	MovementSystem.step(state, SimCommand.new(0, 1, 0, 1000), config, arena)
	MovementSystem.step(normal, SimCommand.new(0, 1, 0, 1000), config, arena)
	check(state.air_velocity_y > normal.air_velocity_y, "Rising Current changes the actual air-steering vector")
	state = _actor(2)
	normal = _actor(2, false)
	Scenarios.prepare(state, "low_stamina")
	Scenarios.prepare(normal, "low_stamina")
	var before := state.stamina
	MovementSystem.step(state, SimCommand.new(0, 1, 0, 0, 0, SimCommand.PRESSED_JUMP), config, arena)
	MovementSystem.step(normal, SimCommand.new(0, 1, 0, 0, 0, SimCommand.PRESSED_JUMP), config, arena)
	check(state.is_airborne() and normal.is_airborne(), "discount test takes an actual paid jump in both cases")
	check(state.stamina > normal.stamina and state.stamina < before, "Last Step gives a real discount without making movement free")
	state.stamina = 0
	state.air_dodge_used = false
	var spent := state.movement_chain_count
	MovementSystem.step(state, SimCommand.new(1, 1, 1000, 0, 0, SimCommand.PRESSED_EVADE), config, arena)
	equal(state.movement_chain_count, spent, "empty reserve cannot buy a discounted follow-up")


func _test_cast_timing_hooks() -> void:
	var wire := int(abilities.ability(abilities.spell_id_at("fire", "heavy")).wire_id)
	var other_wire := int(abilities.ability(abilities.spell_id_at("water", "bolt")).wire_id)
	var definition := CombatTuning.cast_definition(wire)
	var transition := ActionTransitionPolicy.new()
	check(transition.load_from_file(), "real cast transition policy loads")
	for scenario: Array in [[10, false], [10, true], [22, false]]:
		var champion_wire := int(scenario[0])
		var crosses_threshold := bool(scenario[1])
		var quicker_repeat := champion_wire == 22
		var state := _actor(champion_wire)
		var normal := _actor(champion_wire, false)
		for actor: PlayerState in [state, normal]:
			check(actor.place_proven_spell(0, wire), "timing test equips a real Heavy")
			check(actor.place_proven_spell(1, other_wire), "timing test also equips an unrelated spell")
			check(actor.set_spell_cooldown(other_wire, 123), "unrelated cooldown starts from a known independent clock")
			actor.flux = actor.flux_maximum if not crosses_threshold else actor.flux_maximum * 2 / 3 + int(definition.flux_cost) / 2
			actor.stamina = actor.stamina_maximum
		var paid_before := state.flux
		var events: Array[Dictionary] = []
		CombatSystem.step_player(state, SimCommand.new(0, 1, 0, 0, 0, SimCommand.PRESSED_SPELL_1), config, 1000, 2000, arena, events, transition)
		CombatSystem.step_player(normal, SimCommand.new(0, 1, 0, 0, 0, SimCommand.PRESSED_SPELL_1), config, 1000, 2000, arena, [], transition)
		if quicker_repeat:
			check(state.pending_cast_ticks > normal.pending_cast_ticks, "Set the Anvil pays its slower initial startup through actual admission")
		else:
			check(state.pending_cast_ticks > 0 and state.pending_cast_ticks < normal.pending_cast_ticks, "high-Flux startup changes the actual admitted timer")
		equal(state.flux, paid_before - int(definition.flux_cost), "contextual startup still pays the full unchanged Flux price")
		var released_shots: Array[ProjectileState] = []
		for actor: PlayerState in [state, normal]:
			var ticks := actor.pending_cast_ticks
			for tick: int in range(ticks):
				var released: Variant = CombatSystem.step_player(actor, SimCommand.new(tick + 1, 1), config, 1000, 2000, arena, [], transition)
				if released is Array and not released.is_empty(): released_shots.append(released[0])
			equal(actor.spell_cooldown_for_wire(other_wire), 123 - 1 - ticks, "casting a perk spell only naturally ticks the unrelated spell's clock")
		if quicker_repeat:
			check(state.spell_cooldown_for_wire(wire) < normal.spell_cooldown_for_wire(wire), "Set the Anvil earns an actual shorter same-spell repeat wait after a settled release")
		elif crosses_threshold:
			equal(state.spell_cooldown_for_wire(wire), normal.spell_cooldown_for_wire(wire), "repeat cooldown samples below-threshold release state, not hidden admission history")
		else:
			check(state.spell_cooldown_for_wire(wire) > normal.spell_cooldown_for_wire(wire), "remaining high Flux pays an actual longer wait before the same spell can repeat")
		equal(state.cast_recovery_ticks, normal.cast_recovery_ticks, "per-spell repeat timing leaves cosmetic cast recovery unchanged")
		equal(released_shots.size(), 2, "both timing variants release one real Heavy")
		if released_shots.size() == 2:
			equal(released_shots[0].damage, released_shots[1].damage, "contextual timing cannot increase projectile damage")
			equal(released_shots[0].reaction_strength, released_shots[1].reaction_strength, "contextual timing cannot increase elemental material")
			equal(released_shots[0].radius, released_shots[1].radius, "timing passive cannot enlarge the projectile")
		_test_repeat_admission(state, wire, other_wire, transition)


func _test_repeat_admission(state: PlayerState, wire: int, other_wire: int, transition: ActionTransitionPolicy) -> void:
	var released_cooldown := state.spell_cooldown_for_wire(wire)
	state.flux = state.flux_maximum # Isolate repeat admission from a second insufficient-Flux gate.
	check(released_cooldown > 2, "real released spell has a testable repeat deadline")
	check(state.place_proven_spell(1, wire), "released spell can move to a second Loom position")
	equal(state.spell_cooldown_for_wire(wire), released_cooldown, "moving the same spell preserves its modified repeat wait")
	for tick: int in range(maxi(0, released_cooldown - 2)):
		CombatSystem.step_player(state, SimCommand.new(tick, 1), config, 1000, 2000, arena, [], transition)
	var flux_before := state.flux
	var refused: Array[Dictionary] = []
	CombatSystem.step_player(state, SimCommand.new(0, 1, 0, 0, 0, SimCommand.PRESSED_SPELL_2), config, 1000, 2000, arena, refused, transition)
	equal(state.spell_cooldown_for_wire(wire), 1, "repeat refusal occurs exactly one tick before the modified deadline")
	equal(state.pending_cast_wire_id, 0, "moving slots cannot admit the same spell before its cooldown expires")
	equal(state.flux, flux_before, "a cooldown refusal cannot spend Flux")
	check(not refused.is_empty() and String(refused[0].get("reason", "")) == "cooldown", "actual admission reports the repeat clock as its reason")
	CombatSystem.step_player(state, SimCommand.new(1, 1, 0, 0, 0, SimCommand.PRESSED_SPELL_2), config, 1000, 2000, arena, [], transition)
	equal(state.pending_cast_wire_id, wire, "same spell admits on the exact modified cooldown deadline")
	equal(state.flux, flux_before - int(CombatTuning.cast_definition(wire).flux_cost), "boundary admission pays the complete spell price")
	var independent := _actor(10)
	independent.flux = independent.flux_maximum
	check(independent.place_proven_spell(0, wire) and independent.place_proven_spell(1, other_wire), "cross-spell admission equips both real spells")
	check(independent.set_spell_cooldown(wire, released_cooldown), "cross-spell control uses the actual measured perk cooldown")
	CombatSystem.step_player(independent, SimCommand.new(0, 1, 0, 0, 0, SimCommand.PRESSED_SPELL_2), config, 1000, 2000, arena, [], transition)
	equal(independent.pending_cast_wire_id, other_wire, "another ready spell admits while the modified spell remains on cooldown")
	equal(independent.spell_cooldown_for_wire(wire), released_cooldown - 1, "another spell cannot clear or restart the modified repeat wait")


func _test_all_character_prediction_and_snapshots() -> void:
	for wire: int in range(1, 31):
		var world := SimWorld.new(120, 922, arena)
		var actor := _actor(wire)
		actor.entity_id = 2
		actor.velocity_x = 100_000
		# A session snapshot's Hearth always includes its host. Keep the real
		# default host while exercising this remote identity; a remote-only
		# actor list is intentionally rejected as inconsistent membership.
		check(world.player(SessionCharter.HOST_ENTITY_ID) != null, "snapshot fixture retains the required session host")
		check(champions.apply_to_player(world.player(SessionCharter.HOST_ENTITY_ID), String(champions.champion_ids_by_wire[19])), "snapshot host has a real qualified identity rather than the unassigned wire zero")
		world.players.append(actor)
		var prediction := ClientPrediction.new()
		check(prediction.configure(config, arena, 2), "per-character prediction configures")
		var initial := ClientPrediction.capture_packet(actor, 0, -1)
		check(not initial.is_empty(), "all champion identity/resource fields fit prediction packet")
		check(prediction.reconcile(initial), "per-character prediction restores identity and resources")
		var packets: Array[Dictionary] = []
		for index: int in range(8):
			var command := SimCommand.new(index, 2, 1000 if index < 3 else 0, 0)
			check(prediction.queue_input(index + 1, command), "actual walking and release enter prediction")
			check(world.step([command.copy()]), "full authoritative resource/movement/combat tick advances")
			var packet := ClientPrediction.capture_packet(actor, index + 1, index + 1)
			packets.append(packet)
			equal(ClientPrediction.capture_packet(prediction.predicted_state, index + 1, index + 1).values, packet.values, "all thirty identities predict actual neutral movement and recovery exactly")
			if index == 5:
				check(prediction.reconcile(packets[1], actor.last_event), "delayed identity acknowledgement replays pending input")
				equal(ClientPrediction.capture_packet(prediction.predicted_state, index + 1, index + 1).values, packet.values, "delayed replay preserves all perk-driving state")
		check(prediction.reconcile(packets.back(), actor.last_event), "final identity acknowledgement completes")
		equal(prediction.pending_count(), 0, "no identity input remains pending")
		var compact := SessionSnapshot.capture(world, {}, [])
		check(SessionSnapshot.validate(compact), "all actual identity profiles fit supported non-hex snapshot")
		var restored := SimWorld.new(120, 922, arena)
		check(SessionSnapshot.apply_to_world(compact, restored), "snapshot restores each current identity")
		check(restored.player(2) != null, "restored snapshot contains the actual remote actor")
		if restored.player(2) != null:
			equal(restored.player(2).champion_wire_id, wire, "snapshot preserves the exact character identity, even outside an active perk window")
			for property_name: StringName in [&"health", &"health_maximum", &"flux", &"flux_maximum", &"stamina", &"stamina_maximum"]:
				equal(restored.player(2).get(property_name), actor.get(property_name), "snapshot preserves the exact resource fraction used by " + String(property_name))
			for effect: String in Perks.EFFECTS:
				equal(Perks.ratio(restored.player(2), effect), Perks.ratio(actor, effect), "snapshot preserves each identity's situational factor")


func _write_report() -> void:
	var roster: Array[Dictionary] = []
	var characters: Array[Dictionary] = []
	for wire: int in range(1, 31):
		var id := String(champions.champion_ids_by_wire.get(wire, ""))
		var profile: Dictionary = champions.champions_by_id.get(id, {})
		var mapping := {"wire_id": wire, "champion_id": id, "display_name": String(profile.get("display_name", "")), "ancestry": String(profile.get("ancestry", ""))}
		roster.append(mapping)
		var row := Characters.definition(wire)
		row.merge(mapping, true)
		characters.append(row)
	var races := Races.all()
	for row: Dictionary in races:
		var members: Array[Dictionary] = []
		for mapping: Dictionary in roster:
			if String(mapping.ancestry) == String(row.ancestry): members.append(mapping)
		row["current_characters"] = members
	var file := FileAccess.open("res://.godot/identity-perks-report.json", FileAccess.WRITE)
	check(file != null, "identity review report opens for writing")
	if file == null: return
	file.store_string(JSON.stringify({"schema_version": 1, "status": "passed" if failures == 0 else "failed", "assertions": assertions, "failures": failures,
		"races": races, "characters": characters, "roster": roster, "effects": Perks.EFFECTS,
		"limits": {"individual_ratio_minimum": 850, "individual_ratio_maximum": 1200, "combined_ratio_minimum": Perks.MIN_RATIO, "combined_ratio_maximum": Perks.MAX_RATIO, "positive_amount_floor": 1},
		"evidence_disclaimer": "Executed assertions prove covered condition, hook, admission, snapshot and prediction behavior. Established-game references support the contextual mechanism. Neither proves these original percentages are balanced, enjoyable, or competitively successful; human playtests remain necessary."}, "\t") + "\n")
	file.close()
