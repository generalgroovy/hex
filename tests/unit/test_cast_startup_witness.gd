extends FluxTestSuite
## Real paid admission and consumer lifecycle. Cosmetic timing never becomes
## authority; decoded replacement controls use ordinary complete snapshots.

const Witness = preload("res://src/presentation/cast_startup_witness.gd")
const HexSnapshot = preload("res://src/net/hex_world_snapshot.gd")
const Perks = preload("res://src/sim/entities/identity_perk_policy.gd")
const ORIGIN := Vector2i(600_000, 500_000)
var abilities := AbilityCatalog.new()
var champions := ChampionCatalog.new()


class PlannedRouter:
	extends InputRouter
	func sample(tick: int, _position: Vector2, _pointer: Vector2) -> SimCommand:
		return SimCommand.new(tick, entity_id, 0, 0, 0, SimCommand.PRESSED_SPELL_1 if tick == 0 else 0, 0, -1000)


class FrameHarness:
	extends "res://src/app/bootstrap.gd"
	func _ready() -> void: set_process(false)
	func _draw() -> void: pass
	func _advance_player_camera(_delta: float, _blocked: bool) -> void: pass


class NoSavePreferences:
	extends PlayerPreferences
	var saves := 0
	func save_to_file(_path: String = DEFAULT_PATH) -> bool:
		saves += 1
		return true


func run() -> int:
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "witness loads actual spells")
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "witness loads actual identities")
	if not abilities.last_error.is_empty() or not champions.last_error.is_empty(): return finish("cast-startup-witness")
	_test_paid_threshold_and_repeat()
	_test_paid_slow_admission()
	_test_same_step_paid_defeat()
	_test_replacement_reset_and_unknown()
	_test_detached_context_validation()
	_test_weak_lifetime()
	_test_actual_bootstrap_catchup()
	return finish("cast-startup-witness")


func _world(champion: String = "oh_tipi", enemy: bool = false) -> SimWorld:
	var world := SimWorld.new(120, 2718, CollisionWorld.new(2_000_000, 2_000_000))
	var court := HexChemistryWorld.new()
	check(court.configure_geometry(ORIGIN, HexGrid.disk(Vector2i.ZERO, 8)), "witness owns a finite actual Hex court")
	court.chemistry_enabled = true
	world.hex_court = court
	check(champions.apply_to_player(world.player(), champion), "witness applies a real authored profile")
	world.player().reset_for_spawn(ORIGIN)
	check(world.player().place_proven_spell(0, MixtureCatalog.wire_for(16, "heavy")), "witness equips ordinary Light Heavy")
	if enemy:
		var attacker := PlayerState.new(2)
		check(champions.apply_to_player(attacker, "s_wayne"), "opponent uses a real profile")
		attacker.reset_for_spawn(ORIGIN + Vector2i(80_000, 0))
		attacker.team_id = 2
		world.players.append(attacker)
	return world


func _commands(world: SimWorld, press: bool = false, enemy_press: bool = false) -> Array[SimCommand]:
	var rows: Array[SimCommand] = [SimCommand.new(world.tick, 1, 0, 0, 0, SimCommand.PRESSED_SPELL_1 if press else 0, 0, -1000)]
	if world.player(2) != null:
		rows.append(SimCommand.new(world.tick, 2, 0, 0, 0, SimCommand.PRESSED_SPELL_1 if enemy_press else 0, -1000, 0))
	return rows


func _observe(world: SimWorld, witness: Variant, started: int) -> Dictionary:
	var before := world.state_hash()
	var events := world.combat_events.duplicate(true)
	var packet := HexSnapshot.capture(world)
	check(not packet.is_empty(), "paid state has a valid complete packet before observation")
	if packet.is_empty():
		var actor_rows: Array[Dictionary] = []
		for actor: PlayerState in world.players:
			actor_rows.append({"entity":actor.entity_id, "champion":actor.champion_wire_id, "health":actor.health, "pending_wire":actor.pending_cast_wire_id, "pending_ticks":actor.pending_cast_ticks, "row_valid":HexSnapshot._valid_player_values(actor.canonical_values())})
		print("WITNESS_PACKET_DIAGNOSTIC ", JSON.stringify({"tick":world.tick, "actors":actor_rows, "pending_owners":world.hex_court.pending, "relations_valid":HexSnapshot._validate_relations(world), "conservation":world.hex_court.conservation_valid(), "events":world.combat_events}))
	witness.observe_local_step(world, world.combat_events, started)
	var row: Dictionary = witness.describe(world, world.player())
	equal(world.state_hash(), before, "witness cannot mutate canonical paid state")
	equal(world.combat_events, events, "witness cannot enrich or consume authoritative events")
	equal(var_to_bytes(HexSnapshot.capture(world)), var_to_bytes(packet), "witness leaves exact serialized gameplay unchanged")
	check(world.hex_court.conservation_valid(), "cosmetic witness preserves finite matter ownership")
	return row


func _step(world: SimWorld, witness: Variant, press: bool = false, enemy_press: bool = false) -> Dictionary:
	var started := world.tick
	check(world.step(_commands(world, press, enemy_press)), "ordinary paid witness route advances")
	return _observe(world, witness, started)


func _assert_known(row: Dictionary, total: int, elapsed: int, remaining: int, label: String) -> void:
	check(not row.is_empty() and bool(row.get("known_total", false)), label + " has actual admission provenance")
	if row.is_empty(): return
	equal(int(row.total_ticks), total, label + " retains paid total")
	equal(int(row.elapsed_ticks), elapsed, label + " uses actual successful ticks")
	equal(int(row.remaining_ticks), remaining, label + " matches current authority")
	check(absf(float(row.progress) - float(elapsed) / float(total)) < 0.000001, label + " fraction uses witnessed total")


func _assert_unknown(row: Dictionary, remaining: int, label: String) -> void:
	check(not row.is_empty() and not bool(row.get("known_total", true)), label + " remains honest about missing total")
	if row.is_empty(): return
	equal(int(row.remaining_ticks), remaining, label + " keeps real remaining time")
	equal(int(row.total_ticks), 0, label + " does not invent total")
	equal(int(row.elapsed_ticks), -1, label + " does not invent elapsed time")
	equal(float(row.progress), -1.0, label + " preserves unknown sentinel")


func _test_paid_threshold_and_repeat() -> void:
	var world := _world(String(champions.champion_ids_by_wire[10]))
	var actor := world.player()
	var wire := actor.spell_wire_id(1)
	var definition := CombatTuning.cast_definition_view(wire)
	actor.flux = actor.flux_maximum * 2 / 3 + int(definition.flux_cost) / 2
	var recovery_control: SimWorld = HexSnapshot.prepare(HexSnapshot.capture(world), world)
	check(recovery_control != null, "threshold control restores the exact pre-admission paid state")
	if recovery_control == null: return
	check(recovery_control.step(_commands(recovery_control)), "neutral control retains the identical ordinary resource recovery step")
	var before := Perks.spell_timing(actor, definition, world.config, SpellStatusPolicy.startup_ratio(actor))
	var witness := Witness.new()
	var row := _step(world, witness, true)
	var total := actor.pending_cast_ticks
	check(total > 1 and total == int(before.startup_ticks), "ordinary threshold admission uses its pre-payment projection")
	equal(recovery_control.player().flux - actor.flux, int(definition.flux_cost), "threshold cast pays exact authored Flux after identical ordinary recovery")
	check(actor.flux * 3 < actor.flux_maximum * 2, "payment really crosses high-Flux condition")
	var after := Perks.spell_timing(actor, definition, world.config, SpellStatusPolicy.startup_ratio(actor))
	check(int(after.startup_ticks) > total, "current perk projection cannot reconstruct the paid shorter total")
	_assert_known(row, total, 0, total, "initial paid threshold")
	var admission_events := world.combat_events.duplicate(true)
	witness.observe_local_step(world, admission_events, world.tick - 1)
	equal(witness.describe(world, actor), row, "duplicate same-boundary event cannot restart the clock")
	for elapsed: int in range(1, total):
		row = _step(world, witness)
		_assert_known(row, total, elapsed, total - elapsed, "paid startup")
		var displayed := Witness.for_state(actor, world.config, row)
		_assert_known(displayed, total, elapsed, total - elapsed, "display context")
	row = _step(world, witness)
	check(row.is_empty() and actor.pending_cast_wire_id == 0 and not world.projectiles.is_empty(), "ordinary release removes the completed witness and creates real flight")
	var second_paid := false
	for unused: int in 400:
		var ready := actor.pending_cast_wire_id == 0 and actor.cast_recovery_ticks == 0 and actor.spell_cooldown_for_wire(wire) == 0
		row = _step(world, witness, ready)
		if ready and actor.pending_cast_wire_id == wire:
			second_paid = true
			_assert_known(row, actor.pending_cast_ticks, 0, actor.pending_cast_ticks, "same-wire later paid admission")
			break
	check(second_paid, "a later same-wire cast is admitted after real cooldown without a refill")
	equal(int(world.hex_court.metrics.matter_paid), 1200, "exactly two paid casts own finite matter")


func _test_paid_slow_admission() -> void:
	var world := _world("urzh", true)
	var actor := world.player()
	check(world.player(2).place_proven_spell(0, MixtureCatalog.wire_for(4, "rapid")), "ordinary opponent equips Water")
	var definition := CombatTuning.cast_definition_view(actor.spell_wire_id(1))
	var neutral := Perks.spell_timing(actor, definition, world.config, SpellStatusPolicy.startup_ratio(actor))
	var initial_health := actor.health
	var witness := Witness.new()
	var chilled := false
	for index: int in 30:
		_step(world, witness, false, index == 0)
		if SpellStatusPolicy.active(actor, 2):
			chilled = true
			break
	check(chilled and actor.health < initial_health, "positive paid Water contact creates a real timed slow")
	var expected := Perks.spell_timing(actor, definition, world.config, SpellStatusPolicy.startup_ratio(actor))
	var flux := actor.flux
	var row := _step(world, witness, true)
	check(actor.pending_cast_ticks == int(expected.startup_ticks) and actor.pending_cast_ticks > int(neutral.startup_ticks), "Urzh pays its existing slower startup tradeoff under real Chill")
	equal(flux - actor.flux, int(definition.flux_cost), "slower admission pays exactly once")
	_assert_known(row, actor.pending_cast_ticks, 0, actor.pending_cast_ticks, "paid slowed startup")
	equal(int(world.hex_court.metrics.matter_paid), 1200, "Water hit and Heavy each retain their real source payment")


func _test_same_step_paid_defeat() -> void:
	var world := _world("oh_tipi", true)
	var actor := world.player()
	actor.health = 1
	actor.health_recovery_per_second = 0
	check(world.player(2).place_proven_spell(0, MixtureCatalog.wire_for(16, "rapid")), "lethal control equips an ordinary paid Light shot")
	var witness := Witness.new()
	var paid_on_defeat := false
	for index: int in 30:
		var imminent := false
		for shot: ProjectileState in world.projectiles:
			if shot.owner_id == 2:
				imminent = absi(shot.position_x - actor.position_x) <= shot.radius + actor.radius + absi(shot.velocity_x) / world.config.tick_rate
		var row := _step(world, witness, imminent, index == 0)
		if actor.health <= 0:
			for event: Dictionary in world.combat_events:
				paid_on_defeat = paid_on_defeat or (String(event.get("type", "")) == "cast_started" and int(event.get("entity_id", 0)) == 1)
			check(row.is_empty(), "same-step lethal paid contact cannot leave a live startup witness")
			break
	check(paid_on_defeat, "fixture actually admits the actor's paid cast in the same ordinary step as lethal contact")
	equal(int(world.hex_court.metrics.matter_paid), 1200, "both same-step sources remain accounted despite defeat")


func _test_replacement_reset_and_unknown() -> void:
	var world := _world()
	var witness := Witness.new()
	var known := _step(world, witness, true)
	check(bool(known.get("known_total", false)), "lifecycle starts with a genuine paid admission")
	var packet := HexSnapshot.capture(world)
	var replica: SimWorld = HexSnapshot.prepare(packet, world)
	check(replica != null and replica.state_hash() == world.state_hash(), "replacement comes from actual complete paid packet")
	if replica == null: return
	_assert_unknown(witness.describe(replica, replica.player()), replica.player().pending_cast_ticks, "world replacement")
	_assert_unknown(witness.describe(world, world.player()), world.player().pending_cast_ticks, "old witness stays withdrawn")
	witness.clear()
	_assert_unknown(witness.describe(world, world.player()), world.player().pending_cast_ticks, "opening mid-cast after explicit reset")
	# A new real admission supplies provenance; a restored actor with identical
	# canonical values has a different lifetime and must not inherit that proof.
	world = _world()
	known = _step(world, witness, true)
	packet = HexSnapshot.capture(world)
	replica = HexSnapshot.prepare(packet, world)
	if replica == null: return
	var before_hash := world.state_hash()
	world.players[0] = replica.player()
	equal(world.state_hash(), before_hash, "same-ID decoded actor replacement changes no canonical gameplay")
	_assert_unknown(witness.describe(world, world.player()), world.player().pending_cast_ticks, "same-ID actor replacement")
	world = _world()
	known = _step(world, witness, true)
	packet = HexSnapshot.capture(world)
	_step(world, witness)
	check(HexSnapshot.restore(packet, world), "actual snapshot restore creates a backwards timeline boundary")
	_assert_unknown(witness.describe(world, world.player()), world.player().pending_cast_ticks, "backwards restoration")
	var late := Witness.new()
	_assert_unknown(late.describe(world, world.player()), world.player().pending_cast_ticks, "late replica observation cannot infer admission")
	var failed_start := world.tick
	check(not world.step([SimCommand.new(world.tick + 1, 1)]), "wrong-tick step fails rather than producing an admission")
	late.observe_local_step(world, world.combat_events, failed_start)
	_assert_unknown(late.describe(world, world.player()), world.player().pending_cast_ticks, "failed step cannot admit timing")


func _test_detached_context_validation() -> void:
	var world := _world()
	var witness := Witness.new()
	var known := _step(world, witness, true)
	var detached := known.duplicate(true)
	detached.total_ticks = 999
	equal(witness.describe(world, world.player()), known, "returned scalar timing is detached")
	for key: String in ["entity_id", "wire_id", "remaining_ticks", "total_ticks", "elapsed_ticks", "tick_rate"]:
		var malformed := known.duplicate(true)
		malformed[key] = int(malformed[key]) + 1
		_assert_unknown(Witness.for_state(world.player(), world.config, malformed), world.player().pending_cast_ticks, "mismatched " + key)
	for value: Variant in [-1, 0.5, NAN, INF]:
		var malformed := known.duplicate(true)
		malformed.total_ticks = value
		_assert_unknown(Witness.for_state(world.player(), world.config, malformed), world.player().pending_cast_ticks, "invalid total")
	var malformed := known.duplicate(true)
	malformed.progress = 0.5
	_assert_unknown(Witness.for_state(world.player(), world.config, malformed), world.player().pending_cast_ticks, "incoherent fraction")
	check(not Witness.remaining_label(1, 120).contains("0.0"), "a positive final tick never reads zero seconds")


func _test_weak_lifetime() -> void:
	var witness := Witness.new()
	var world := _world()
	_step(world, witness, true)
	var world_ref: WeakRef = weakref(world)
	var actor_ref: WeakRef = weakref(world.player())
	world = null
	check(world_ref.get_ref() == null and actor_ref.get_ref() == null, "cosmetic witness retains neither paid world nor actor")
	witness.clear()
	check(witness.describe(null, null).is_empty(), "released references and explicit clear are safe")


func _test_actual_bootstrap_catchup() -> void:
	InputRouter.ensure_input_map()
	var mouse_before := Input.mouse_mode
	var node := FrameHarness.new()
	node.preference_overrides_are_transient = true
	node.world = _world()
	var control := _world()
	node.input_router = PlannedRouter.new(1)
	var preferences := NoSavePreferences.new()
	node.player_preferences = preferences
	node.session_steward = SessionSteward.new()
	node.campus_layout = SanctumCampusLayout.new()
	node.ability_catalog = abilities
	node.champion_catalog = champions
	node.authoritative_session = AuthoritativeSession.new()
	check(node.authoritative_session.bind(node.world, champions, Vector2i(600, 500), "Witness Host"), "catch-up binds actual local authority")
	node.session_transport = SessionTransport.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	var total := int(Perks.spell_timing(control.player(), CombatTuning.cast_definition_view(control.player().spell_wire_id(1)), control.config).startup_ticks)
	for index: int in 8: check(control.step(_commands(control, index == 0)), "unobserved control executes the same eight ordinary steps")
	node._process(0.1)
	equal(node.world.tick, 8, "actual inherited Bootstrap advances bounded catch-up")
	equal(node.world.state_hash(), control.state_hash(), "Bootstrap timing observation does not change paid authority")
	equal(var_to_bytes(HexSnapshot.capture(node.world)), var_to_bytes(HexSnapshot.capture(control)), "actual hook preserves exact complete packet")
	_assert_known(node.cast_startup_witness.describe(node.world, node.world.player()), total, 7, total - 7, "actual Bootstrap per-step witness")
	node._reset_motion_history()
	_assert_unknown(node.cast_startup_witness.describe(node.world, node.world.player()), total - 7, "real motion reset withdraws timing proof")
	node._ingest_combat_cues([{"type":"cast_started", "entity_id":1, "wire_id":node.world.player().pending_cast_wire_id}])
	_assert_unknown(node.cast_startup_witness.describe(node.world, node.world.player()), total - 7, "generic late combat-cue ingestion cannot admit a local witness")
	node.session_transport.stop()
	node.free()
	equal(preferences.saves, 0, "catch-up witness test never saves player preferences")
	Input.mouse_mode = mouse_before
