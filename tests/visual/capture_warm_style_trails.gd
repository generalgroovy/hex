extends SceneTree


const Harness = preload("res://tests/support/chemistry_coach_harness.gd")
const ELEMENTS: Array[String] = ["earth", "fire", "water", "wind", "ice", "charge", "light", "dark"]
var output := "res://.godot/warm-style-trails-render"
var node: Node2D
var viewport: SubViewport
var records: Array[Dictionary] = []
var payments: Array[Dictionary] = []
var chemistry_events: Array[Dictionary] = []


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/warm-style-trails-render") or ".." in output or DirAccess.dir_exists_absolute(output):
		fail("Provide a fresh warm-style-trails output; prior evidence is preserved")
		return
	node = Harness.new()
	if not node.configure_fixture(true) or DirAccess.make_dir_recursive_absolute(output) != OK:
		fail("Integrated map/body/material fixture could not configure")
		node.free()
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(node)
	node.player_preferences.pov_mode = PlayerPreferences.POV_FULL
	node.player_preferences.set_camera_zoom_percent(100)
	for champion: String in ["s_wayne", "oh_tipi", "red_baron"]:
		if not reset_trial(champion) or not await capture(champion + "-quiet", {"kind": "actual_quiet_body_size"}):
			return
	for element: String in ELEMENTS:
		if not await capture_spell(element, "bolt"):
			return
	if not await capture_spell("fire", "rapid"):
		return
	if not await capture_one_payload_steam():
		return
	if OS.get_cmdline_user_args().has("--playtest-clarity") and not await capture_paid_protection():
		return
	if OS.get_cmdline_user_args().has("--rampart"):
		for champion: String in ["s_wayne", "oh_tipi", "red_baron"]:
			if not await capture_paid_rampart(champion):
				return
	if OS.get_cmdline_user_args().has("--frostway"):
		for champion: String in ["s_wayne", "oh_tipi", "red_baron"]:
			if not await capture_paid_frostway(champion):
				return
	if OS.get_cmdline_user_args().has("--capacitor:3sizes"):
		for champion: String in ["s_wayne", "oh_tipi", "red_baron"]:
			if not await capture_paid_capacitor(champion):
				return
	if OS.get_cmdline_user_args().has("--element-impact"):
		for wire: int in range(301, 337):
			if not await capture_paid_pair(wire):
				return
	var receipt := FileAccess.open(output.path_join("capture-receipt.json"), FileAccess.WRITE)
	if receipt == null:
		fail("Integrated trail receipt could not be written")
		return
	receipt.store_string(JSON.stringify({"schema_version": 1, "frames": records, "payments": payments, "map_hash": node.campus_layout.content_hash, "ground_style_hash": node.campus_renderer.illustrated_kit.ground_style.content_hash, "trail_policy": ElementChemistrySystem.trail_policy(), "method": "fresh_offline_world_per_trial_real_catalog_spells_paid_inputs_production_bootstrap_draw", "deposits": "never_injected", "authority_unchanged_by_draw": true, "network": "not_started", "audio": "not_started", "preferences": "transient_fixture_only", "human_acceptance": "not_run"}, "  "))
	receipt.close()
	print("PASS:%d integrated actual-game frames;8Bolt flight+terminal,1Rapid flight+terminal,3body sizes,2paid older-trail/new-impact Steam+spent-expiry;optional paid Float/cast/protection expiry and 3size Frostway walk/slide/jump lifecycle;no injected deposits;draw world hashes unchanged" % records.size())
	quit(0)


func form_paid_pair(recipe_wire: int, champion: String = "oh_tipi", capacitor_target: bool = false) -> Dictionary:
	if not reset_trial(champion):
		return {}
	var recipe := ElementChemistrySystem.recipe(recipe_wire)
	var target: Vector2i = node.fixture_anchor + Vector2i(0, -100000 if capacitor_target else -160000)
	if capacitor_target and not add_capacitor_enemy(target + Vector2i(0, -100000), champion):
		return {}
	var first_wire := wire_for(ELEMENTS[int(recipe.elements[0]) - 1], "rapid")
	var second_wire := wire_for(ELEMENTS[int(recipe.elements[1]) - 1], "rapid")
	var first := begin_paid_cast(first_wire, target)
	if first.is_empty():
		return {}
	for unused: int in 200:
		if not step_world():
			return {}
		var actor: PlayerState = node.world.player()
		if not node.world.deposits.is_empty() and node.world.projectiles.is_empty() and actor.pending_cast_wire_id == 0 and actor.cast_recovery_ticks == 0 and actor.spell_cooldown_for_wire(second_wire) == 0:
			break
	var second := begin_paid_cast(second_wire, target, 2)
	if second.is_empty():
		return {}
	for unused: int in 200:
		if not step_world():
			return {}
		if not node.world.reactions.is_empty():
			break
	if node.world.reactions.size() != 1 or node.world.reactions[0].recipe_wire_id != recipe_wire or trail_count() != 0:
		fail("Pair %d requires two paid Rapid admissions and exactly its real result" % recipe_wire)
		return {}
	var reaction: ElementReactionState = node.world.reactions[0]
	return {"kind": "actual_paid_pair", "recipe_wire_id": recipe_wire, "recipe": recipe.id, "first": first, "second": second, "reaction_values": Array(reaction.canonical_values())}


func add_capacitor_enemy(position: Vector2i, champion: String) -> bool:
	# A real opposing champion starts ahead of both paid impacts, inside the
	# future capsule. It is never teleported or switched between teams later.
	var target := PlayerState.new(2)
	if not node.champion_catalog.apply_to_player(target, champion):
		fail("Capacitor trial needs a real snapshot-valid opposing champion")
		return false
	target.team_id = 2
	target.reset_for_spawn(position)
	target.spawn_protection_ticks = 0
	target.health_recovery_per_second = 0
	target.flux_recovery_per_second = 0
	node.world.players.append(target)
	node.session_round_values = node.authoritative_session.session_round.capture(node.world)
	node.actor_motion_history.capture(node.world.players)
	return true


func capture_paid_pair(recipe_wire: int) -> bool:
	var evidence := form_paid_pair(recipe_wire)
	if evidence.is_empty():
		return false
	var reaction: ElementReactionState = node.world.reactions[0]
	var name := "pair-%d-%s" % [recipe_wire, evidence.recipe]
	if not await capture(name + "-forming", evidence.duplicate(true)):
		return false
	# Short pulses must be sampled during their actual active interval, not at
	# a fabricated longer lifetime. Long fields get time to establish a motif.
	var target_tick := reaction.active_tick + mini(60, maxi(1, (reaction.decay_tick - reaction.active_tick) / 2))
	while node.world.tick < target_tick:
		if not step_world():
			return false
	if not reaction.active(node.world.tick) or not await capture(name + "-active", evidence.duplicate(true)):
		return false
	node.player_preferences.reduced_motion = true
	if not await capture(name + "-reduced", evidence.duplicate(true)):
		return false
	node.player_preferences.reduced_motion = false
	return true


func capture_paid_frostway(champion: String) -> bool:
	var evidence := form_paid_pair(327, champion)
	if evidence.is_empty():
		return false
	evidence["kind"] = "actual_paid_frostway_movement_lifecycle"
	evidence["policy"] = FrostwayFieldPolicy.policy()
	var reaction: ElementReactionState = node.world.reactions[0]
	var actor: PlayerState = node.world.player()
	var name := champion + "-frostway"
	if node.world.tick >= reaction.active_tick or not await capture(name + "-formation", evidence.duplicate(true)):
		return false
	while node.world.tick < reaction.active_tick + 10:
		if not step_world():
			return false
	# Approach with ordinary accepted movement, never move the actor into the
	# material by editing positions or directly adding chemistry state.
	var entered := false
	for unused: int in 180:
		if not step_world([SimCommand.new(node.world.tick, actor.entity_id, 0, -1000, 0, 0, 0, -1000)]):
			return false
		if frostway_occupied():
			entered = true
			break
	if not entered:
		fail("Paid Frostway must be reachable by actual walking while active")
		return false
	for unused: int in 8:
		if not step_world([SimCommand.new(node.world.tick, actor.entity_id, 0, -1000, 0, 0, 0, -1000)]):
			return false
	if not frostway_occupied() or actor.is_airborne() or actor.slide_ticks > 0 or actor.wall_contact_id > 0:
		fail("Frostway walking evidence requires grounded occupancy without a wall")
		return false
	evidence["walking"] = frostway_actor_evidence()
	if not await capture(name + "-active-walking", evidence.duplicate(true)):
		return false
	node.player_preferences.reduced_motion = true
	if not await capture(name + "-active-reduced", evidence.duplicate(true)):
		return false
	node.player_preferences.reduced_motion = false
	# Sprint builds the normal slide-entry speed even for the large body. Ice
	# must not manufacture a free slide or bypass accepted stamina admission.
	for unused: int in 12:
		if not step_world([SimCommand.new(node.world.tick, actor.entity_id, 0, -1000, SimCommand.HELD_SPRINT, 0, 0, -1000)]):
			return false
	var slide_stamina := actor.stamina
	if not step_world([SimCommand.new(node.world.tick, actor.entity_id, 0, -1000, SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE, 0, -1000)]):
		return false
	for unused: int in 7:
		if not step_world([SimCommand.new(node.world.tick, actor.entity_id, 0, -1000, SimCommand.HELD_SLIDE, 0, 0, -1000)]):
			return false
	if not frostway_occupied() or actor.slide_ticks <= 0 or actor.stamina >= slide_stamina or actor.is_airborne():
		fail("Paid Frostway slide must be accepted, grounded and still inside the active lane")
		return false
	evidence["sliding"] = frostway_actor_evidence()
	evidence["slide_stamina_paid"] = slide_stamina - actor.stamina
	if not await capture(name + "-active-slide", evidence.duplicate(true)):
		return false
	var jump_stamina := actor.stamina
	if not step_world([SimCommand.new(node.world.tick, actor.entity_id, 0, -1000, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP, 0, -1000)]):
		return false
	for unused: int in 7:
		if not step_world([SimCommand.new(node.world.tick, actor.entity_id, 0, -1000, SimCommand.HELD_JUMP, 0, 0, -1000)]):
			return false
	if not frostway_occupied() or not actor.is_airborne() or actor.air_height <= 0 or actor.stamina >= jump_stamina:
		fail("Frostway aerial bypass must use a paid jump above the same active lane")
		return false
	evidence["jumping"] = frostway_actor_evidence()
	evidence["jump_stamina_paid"] = jump_stamina - actor.stamina
	if not await capture(name + "-active-jump", evidence.duplicate(true)):
		return false
	while node.world.tick < reaction.decay_tick + 8:
		if not step_world():
			return false
	if frostway_occupied():
		fail("Frostway movement context must end before harmless decay drawing")
		return false
	if not await capture(name + "-decay", evidence.duplicate(true)):
		return false
	while node.world.tick <= reaction.expiry_tick:
		if not step_world():
			return false
	if not node.world.reactions.is_empty() or not node.world.deposits.is_empty() or chemistry_events.size() != 1:
		fail("Paid Frostway must expire without daughter matter or repeated chemistry")
		return false
	return await capture(name + "-expired", evidence.duplicate(true))


func frostway_occupied() -> bool:
	var actor: PlayerState = node.world.player()
	return FrostwayFieldPolicy.contains(FrostwayFieldPolicy.capture(node.world.reactions, node.world.tick), Vector2i(actor.position_x, actor.position_y), node.world.tick)


func frostway_actor_evidence() -> Dictionary:
	var actor: PlayerState = node.world.player()
	return {"position": [actor.position_x, actor.position_y], "velocity": [actor.velocity_x, actor.velocity_y], "air_height": actor.air_height, "slide_ticks": actor.slide_ticks, "stamina": actor.stamina, "ground_point_inside_active_lane": frostway_occupied(), "event": actor.last_event}


func capture_paid_capacitor(champion: String) -> bool:
	var evidence := form_paid_pair(CapacitorFieldPolicy.RECIPE_WIRE, champion, true)
	if evidence.is_empty():
		return false
	evidence["kind"] = "actual_paid_capacitor_movement_and_discharge_lifecycle"
	evidence["policy"] = CapacitorFieldPolicy.policy()
	var reaction: ElementReactionState = node.world.reactions[0]
	var actor: PlayerState = node.world.player()
	var enemy: PlayerState = node.world.player(2)
	var name := champion + "-capacitor"
	if enemy == null or node.world.tick >= reaction.active_tick or not await capture_modes(name + "-formation", evidence.duplicate(true)):
		return false
	while node.world.tick < reaction.active_tick + 4:
		if not step_world():
			return false
	var entered := false
	for unused: int in 100:
		if not step_world([SimCommand.new(node.world.tick, actor.entity_id, 0, -1000, 0, 0, 0, -1000)]):
			return false
		if capacitor_occupied(actor):
			entered = true
			break
	if not entered:
		fail("Paid Capacitor must be reachable by ordinary grounded walking")
		return false
	for unused: int in 10:
		if not step_world([SimCommand.new(node.world.tick, actor.entity_id, 0, -1000, 0, 0, 0, -1000)]):
			return false
	if not capacitor_occupied(actor) or actor.is_airborne() or actor.sprinting:
		fail("Capacitor walk capture requires an ordinary grounded actor inside the real active capsule")
		return false
	var walk_speed := Vector2i(actor.velocity_x, actor.velocity_y).length()
	evidence["walking"] = capacitor_actor_evidence(actor)
	if not await capture_modes(name + "-active-walk", evidence.duplicate(true)):
		return false
	var sprint_ready := false
	for unused: int in 18:
		if not step_world([SimCommand.new(node.world.tick, actor.entity_id, 0, -1000, SimCommand.HELD_SPRINT, 0, 0, -1000)]):
			return false
		if actor.sprinting and Vector2i(actor.velocity_x, actor.velocity_y).length() > walk_speed:
			sprint_ready = true
			break
	if not sprint_ready or not capacitor_occupied(actor) or actor.is_airborne():
		fail("Capacitor sprint capture requires a faster ordinary paid-stamina sprint inside the capsule")
		return false
	evidence["sprinting"] = capacitor_actor_evidence(actor)
	if not await capture_modes(name + "-active-sprint", evidence.duplicate(true)):
		return false
	var slide_stamina := actor.stamina
	if not step_world([SimCommand.new(node.world.tick, actor.entity_id, 0, -1000, SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE, 0, -1000)]):
		return false
	for unused: int in 3:
		if not step_world([SimCommand.new(node.world.tick, actor.entity_id, 0, -1000, SimCommand.HELD_SLIDE, 0, 0, -1000)]):
			return false
	if actor.slide_ticks <= 0 or actor.stamina >= slide_stamina or actor.is_airborne() or not capacitor_occupied(actor):
		fail("Capacitor slide evidence must use the normal paid grounded action inside the active capsule")
		return false
	evidence["sliding"] = capacitor_actor_evidence(actor)
	evidence["slide_stamina_paid"] = slide_stamina - actor.stamina
	if not await capture_modes(name + "-active-paid-slide", evidence.duplicate(true)):
		return false
	var jump_stamina := actor.stamina
	if not step_world([SimCommand.new(node.world.tick, actor.entity_id, 0, -1000, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP, 0, -1000)]):
		return false
	for unused: int in 4:
		if not step_world([SimCommand.new(node.world.tick, actor.entity_id, 0, -1000, SimCommand.HELD_JUMP, 0, 0, -1000)]):
			return false
	if not actor.is_airborne() or actor.air_height <= 0 or actor.stamina >= jump_stamina:
		fail("Capacitor jump evidence must use the normal paid aerial action without lane acceleration")
		return false
	evidence["jumping"] = capacitor_actor_evidence(actor)
	evidence["jump_stamina_paid"] = jump_stamina - actor.stamina
	if not await capture_modes(name + "-active-paid-jump", evidence.duplicate(true)):
		return false
	var warning_tick := reaction.decay_tick - CapacitorFieldPolicy.FINAL_WARNING_TICKS
	if node.world.tick > warning_tick:
		fail("Capacitor movement sequence overran its real500ms final warning")
		return false
	while node.world.tick < warning_tick:
		if not step_world():
			return false
	evidence["final_warning_tick"] = warning_tick
	if not await capture_modes(name + "-final-warning", evidence.duplicate(true)):
		return false
	while node.world.tick < reaction.decay_tick - 1:
		if not step_world():
			return false
	var enemy_before := Vector2i(enemy.position_x, enemy.position_y)
	var enemy_health := enemy.health
	var enemy_control := [enemy.control_state, enemy.control_ticks]
	evidence["discharge_target_before"] = [enemy_before.x, enemy_before.y]
	if not await capture_modes(name + "-discharge", evidence.duplicate(true)):
		return false
	if not step_world():
		return false
	var enemy_after := Vector2i(enemy.position_x, enemy.position_y)
	var displacement := enemy_after - enemy_before
	if displacement == Vector2i.ZERO or displacement.length() > float(CapacitorFieldPolicy.DISCHARGE_DISTANCE) or enemy.health != enemy_health or [enemy.control_state, enemy.control_ticks] != enemy_control:
		fail("Actual final Capacitor tick must move one grounded enemy at most14px without damage, stun or cancel")
		return false
	var once_position := enemy_after
	if not step_world() or Vector2i(enemy.position_x, enemy.position_y) != once_position:
		fail("Capacitor discharge cannot repeat during harmless decay")
		return false
	evidence["discharge_target_after"] = [enemy_after.x, enemy_after.y]
	evidence["discharge_delta"] = [displacement.x, displacement.y]
	evidence["damage"] = enemy_health - enemy.health
	evidence["control_before_after"] = [enemy_control, [enemy.control_state, enemy.control_ticks]]
	if capacitor_occupied(enemy) or not await capture_modes(name + "-harmless-decay", evidence.duplicate(true)):
		return false
	while node.world.tick <= reaction.expiry_tick:
		if not step_world():
			return false
	if not node.world.reactions.is_empty() or not node.world.deposits.is_empty() or chemistry_events.size() != 1 or Vector2i(enemy.position_x, enemy.position_y) != once_position:
		fail("Paid Capacitor must expire without daughter matter or repeated displacement")
		return false
	return await capture_modes(name + "-expired", evidence.duplicate(true))


func capacitor_occupied(actor: PlayerState) -> bool:
	if actor == null:
		return false
	var lanes := CapacitorFieldPolicy.capture(node.world.reactions, node.world.tick)
	return CapacitorFieldPolicy.contains(lanes, Vector2i(actor.position_x, actor.position_y), node.world.tick)


func capacitor_actor_evidence(actor: PlayerState) -> Dictionary:
	return {"position": [actor.position_x, actor.position_y], "velocity": [actor.velocity_x, actor.velocity_y], "air_height": actor.air_height, "slide_ticks": actor.slide_ticks, "stamina": actor.stamina, "sprinting": actor.sprinting, "ground_point_inside_active_capsule": capacitor_occupied(actor), "event": actor.last_event}


func capture_modes(name: String, evidence: Dictionary) -> bool:
	node.player_preferences.reduced_motion = false
	var normal := evidence.duplicate(true)
	normal["reduced_effects"] = false
	if not await capture(name, normal):
		return false
	node.player_preferences.reduced_motion = true
	var reduced := evidence.duplicate(true)
	reduced["reduced_effects"] = true
	var accepted := await capture(name + "-reduced", reduced)
	node.player_preferences.reduced_motion = false
	return accepted


func capture_paid_rampart(champion: String) -> bool:
	if not reset_trial(champion):
		return false
	var target: Vector2i = node.fixture_anchor + Vector2i(0, -160000)
	var wire := wire_for("earth", "rapid")
	var first := begin_paid_cast(wire, target)
	if first.is_empty():
		return false
	for unused: int in 160:
		if not step_world():
			return false
		var actor: PlayerState = node.world.player()
		if not node.world.deposits.is_empty() and node.world.projectiles.is_empty() and actor.pending_cast_wire_id == 0 and actor.cast_recovery_ticks == 0 and actor.spell_cooldown_for_wire(wire) == 0:
			break
	var second := begin_paid_cast(wire, target, 2)
	if second.is_empty():
		return false
	for unused: int in 160:
		if not step_world():
			return false
		if not node.world.reactions.is_empty():
			break
	if node.world.reactions.size() != 1 or int(node.world.reactions[0].recipe_wire_id) != 301 or trail_count() != 0:
		fail("Earth pilot requires exactly one paid Rapid + Rapid mirror, no injected matter or trails")
		return false
	var reaction: ElementReactionState = node.world.reactions[0]
	var evidence := {"kind": "paid_earth_mirror_lifecycle", "first": first, "second": second, "reaction_values": Array(reaction.canonical_values())}
	if node.world.tick >= reaction.active_tick or not await capture(champion + "-rampart-formation", evidence):
		return false
	while node.world.tick <= reaction.active_tick + 10:
		if not step_world():
			return false
	var actor: PlayerState = node.world.player()
	for unused: int in 110:
		if not step_world([SimCommand.new(node.world.tick, actor.entity_id, 0, -1000, 0, 0, 0, -1000)]):
			return false
	if actor.wall_contact_id <= 0 or actor.position_y <= reaction.position_y:
		fail("Paid active Rampart must block approaching movement and expose a real wall contact")
		return false
	evidence["contact_id"] = actor.wall_contact_id
	evidence["contact_position"] = [actor.position_x, actor.position_y]
	if not await capture(champion + "-rampart-contact", evidence):
		return false
	while node.world.tick <= reaction.decay_tick + 3:
		if not step_world():
			return false
	if not await capture(champion + "-rampart-decay", evidence):
		return false
	for unused: int in 90:
		if not step_world([SimCommand.new(node.world.tick, actor.entity_id, 0, -1000, 0, 0, 0, -1000)]):
			return false
	if actor.position_y >= reaction.position_y or actor.wall_contact_id == int(evidence.contact_id):
		fail("Expired Rampart must release passage and cannot retain its wall contact")
		return false
	return await capture(champion + "-rampart-expired-passage", evidence)


func capture_paid_protection() -> bool:
	if not reset_trial("s_wayne"):
		return false
	var actor: PlayerState = node.world.player()
	var starting_stamina := actor.stamina
	if not step_world([SimCommand.new(node.world.tick, actor.entity_id, 1000, 0, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP, 0, -1000)]):
		return false
	for unused: int in range(10):
		if not step_world([SimCommand.new(node.world.tick, actor.entity_id, 1000, 0, 0, 0, 0, -1000)]):
			return false
	if not step_world([SimCommand.new(node.world.tick, actor.entity_id, 1000, 0, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP, 0, -1000)]):
		return false
	if not actor.air_floating or actor.stamina >= starting_stamina or CompactCombatHud.protection_status(actor) != "PROTECTED / FLOAT":
		fail("Protection capture must use an actual paid jump into finite Float")
		return false
	if not await capture("paid-float-protected", {"kind": "paid_jump_float", "stamina_paid": starting_stamina - actor.stamina, "float_ticks": actor.float_ticks, "protection": CompactCombatHud.protection_status(actor)}):
		return false
	var wire := wire_for("fire", "bolt")
	if not actor.place_proven_spell(0, wire):
		return false
	var starting_flux := actor.flux
	if not step_world([SimCommand.new(node.world.tick, actor.entity_id, 1000, 0, SimCommand.HELD_JUMP, SimCommand.PRESSED_SPELL_1, 0, -1000, node.fixture_target.x, node.fixture_target.y)]):
		return false
	if actor.pending_cast_wire_id != wire or actor.flux != starting_flux - int(CombatTuning.cast_definition(wire).flux_cost) or not actor.air_floating:
		fail("Moving protected cast must pay Flux without ending Float")
		return false
	if not await capture("paid-float-cast-startup", {"kind": "paid_cast_during_float", "flux_paid": starting_flux - actor.flux, "pending_wire": wire, "protection": CompactCombatHud.protection_status(actor)}):
		return false
	for unused: int in range(100):
		if not step_world([SimCommand.new(node.world.tick, actor.entity_id, 0, 0, 0, 0, 0, -1000)]):
			return false
	if not CompactCombatHud.protection_status(actor).is_empty():
		fail("Released protection must visibly end using accepted current state")
		return false
	return await capture("paid-float-ended", {"kind": "paid_float_released", "protection": CompactCombatHud.protection_status(actor)})


func reset_trial(champion: String = "oh_tipi") -> bool:
	# Independent controlled initial conditions, never inserted chemistry state.
	node.world = SimWorld.new(120, 909, node.campus_layout.build_collision_world())
	node.authoritative_session.world = node.world
	var actor: PlayerState = node.world.player()
	if not node.champion_catalog.apply_to_player(actor, champion):
		fail("Real champion identity could not configure")
		return false
	actor.reset_for_spawn(node.fixture_anchor)
	actor.spawn_protection_ticks = 0
	actor.flux_recovery_per_second = 0
	actor.health_recovery_per_second = 0
	actor.aim_x = 0
	actor.aim_y = -1000
	if not node.world.collision.can_occupy(node.fixture_anchor, actor.radius):
		fail("Authored trial anchor must remain outside real collision")
		return false
	node.selected_champion_id = champion
	node.session_round_values = node.authoritative_session.session_round.capture(node.world)
	node.actor_motion_history.clear()
	chemistry_events.clear()
	sync_fixture()
	return true


func wire_for(element: String, family: String) -> int:
	var id: String = node.ability_catalog.spell_id_at(element, family)
	var definition: Dictionary = node.ability_catalog.ability(id)
	return int(definition.get("wire_id", 0)) if String(definition.get("runtime_status", "")) == "playable" else 0


func begin_paid_cast(wire: int, target: Vector2i, slot: int = 1) -> Dictionary:
	var actor: PlayerState = node.world.player()
	var definition := CombatTuning.cast_definition(wire)
	var cost := int(definition.get("flux_cost", 0))
	if wire <= 0 or cost <= 0 or not actor.place_proven_spell(slot - 1, wire):
		fail("Trial requires an ordinary available catalog spell")
		return {}
	var before := actor.flux
	var command := SimCommand.new(node.world.tick, actor.entity_id, 0, 0, 0, SimCommand.SPELL_PRESSED_BITS[slot - 1], 0, -1000, target.x, target.y)
	if not step_world([command]) or actor.flux != before - cost or actor.pending_cast_wire_id != wire:
		fail("Trial cast must be accepted and pay exact authored Flux")
		return {}
	var accepted := false
	for event: Dictionary in node.world.combat_events:
		accepted = accepted or (String(event.get("type", "")) == "cast_started" and int(event.get("wire_id", 0)) == wire)
	if not accepted:
		fail("Paid trial needs its actual cast_started event")
		return {}
	var payment := {"wire_id": wire, "tick": node.world.tick - 1, "flux_before": before, "flux_after": actor.flux, "flux_paid": cost, "target": [target.x, target.y], "slot": slot}
	payments.append(payment)
	return payment


func capture_spell(element: String, family: String) -> bool:
	if not reset_trial():
		return false
	var wire := wire_for(element, family)
	var payment := begin_paid_cast(wire, node.fixture_anchor + Vector2i(0, -220000))
	if payment.is_empty():
		return false
	var flight_ticks := 0
	var source_id := 0
	var flight_ready := false
	for unused: int in 120:
		if not step_world():
			return false
		if not node.world.projectiles.is_empty():
			flight_ticks += 1
			source_id = node.world.projectiles[0].source_cast_id
		if family == "rapid" and not node.world.deposits.is_empty() and not node.world.projectiles.is_empty():
			fail("Rapid flight must never seed a deposit")
			return false
		if not node.world.projectiles.is_empty() and ((family == "rapid" and flight_ticks >= 16) or (family == "bolt" and trail_count() >= 2)):
			flight_ready = true
			break
	if not flight_ready or source_id <= 0 or not node.world.reactions.is_empty():
		fail("Independent trial must show real flight and bounded trails without self-reaction")
		return false
	var evidence := {"kind": "actual_paid_%s" % family, "element": element, "wire_id": wire, "source_cast_id": source_id, "payment": payment}
	if not await capture(element + "-" + family + "-flight", evidence):
		return false
	var terminal: ElementDepositState
	for unused: int in 120:
		if not step_world():
			return false
		for deposit: ElementDepositState in node.world.deposits:
			if deposit.source_cast_id == source_id and not deposit.is_trail():
				terminal = deposit
		if terminal != null and node.world.projectiles.is_empty():
			break
	if terminal == null or terminal.radius < ElementDepositState.TERMINAL_MIN_RADIUS or terminal.radius > ElementDepositState.TERMINAL_MAX_RADIUS or not node.world.projectiles.is_empty() or not node.world.reactions.is_empty():
		fail("Independent paid projectile must end in source-bounded terminal matter")
		return false
	if family == "rapid" and trail_count() != 0:
		fail("Rapid exception must leave terminal matter only")
		return false
	# Let the initial contact imprint settle while retaining the actual terminal.
	for unused: int in 8:
		if not step_world():
			return false
	evidence["terminal_id"] = terminal.entity_id
	evidence["terminal_radius"] = terminal.radius
	return await capture(element + "-" + family + "-terminal", evidence)


func capture_one_payload_steam() -> bool:
	if not reset_trial():
		return false
	var fire_payment := begin_paid_cast(wire_for("fire", "bolt"), node.fixture_anchor + Vector2i(0, -300000))
	if fire_payment.is_empty():
		return false
	for unused: int in 80:
		if not step_world():
			return false
		if trail_count() >= 2:
			break
	for unused: int in 60:
		var actor: PlayerState = node.world.player()
		if actor.pending_cast_wire_id == 0 and actor.cast_recovery_ticks == 0:
			break
		if not step_world():
			return false
	if node.world.projectiles.is_empty() or node.world.deposits.is_empty() or trail_count() < 2:
		fail("Steam pilot needs an older real Fire trail while its paid parent remains in flight")
		return false
	var old: ElementDepositState = node.world.deposits[0]
	var old_values := Array(old.canonical_values())
	var water_payment := begin_paid_cast(wire_for("water", "bolt"), Vector2i(old.position_x, old.position_y), 2)
	if water_payment.is_empty():
		return false
	for unused: int in 120:
		if not step_world():
			return false
		if not node.world.reactions.is_empty():
			break
	if node.world.reactions.size() != 1:
		fail("Older Fire trail plus new Water terminal must create exactly one real recipe")
		return false
	var reaction: ElementReactionState = node.world.reactions[0]
	var spent_sources: Array[int] = [reaction.source_a, reaction.source_b]
	var spent_live: Array[Dictionary] = []
	for projectile: ProjectileState in node.world.projectiles:
		if projectile.source_cast_id in spent_sources:
			if projectile.material_strength != 0:
				fail("Live parent must retain zero chemistry after its one payload is consumed")
				return false
			spent_live.append({"id": projectile.entity_id, "source_cast_id": projectile.source_cast_id, "material_strength": projectile.material_strength, "damage": projectile.damage})
	if reaction.recipe_wire_id != 310 or spent_live.is_empty() or not node.world.deposits.is_empty() or old.created_tick >= reaction.created_tick:
		fail("Steam evidence needs actual older-trail/new-terminal ordering, a spent live parent, and no leftover source fragments")
		return false
	var evidence := {"kind": "actual_paid_older_trail_new_impact_steam", "older_trail": old_values, "fire_payment": fire_payment, "water_payment": water_payment, "reaction_values": Array(reaction.canonical_values()), "spent_live_projectiles_at_formation": spent_live}
	while node.world.tick < reaction.active_tick + 12:
		if not step_world() or not no_regenerated_payload(spent_sources):
			return false
	if not await capture("older-fire-trail-water-impact-steam-active", evidence):
		return false
	while node.world.tick <= reaction.expiry_tick:
		if not step_world() or not no_regenerated_payload(spent_sources):
			return false
	if not node.world.projectiles.is_empty() or not node.world.deposits.is_empty() or not node.world.reactions.is_empty() or chemistry_events.size() != 1:
		fail("Spent parents must finish without daughter matter or repeated chemistry")
		return false
	evidence["no_payload_regeneration_through_tick"] = node.world.tick
	evidence["chemistry_formed_events"] = chemistry_events.duplicate(true)
	return await capture("steam-expired-no-child-matter", evidence)


func no_regenerated_payload(spent_sources: Array[int]) -> bool:
	for deposit: ElementDepositState in node.world.deposits:
		if deposit.source_cast_id in spent_sources:
			fail("Consumed casts regenerated a trail or terminal")
			return false
	for projectile: ProjectileState in node.world.projectiles:
		if projectile.source_cast_id in spent_sources and projectile.material_strength != 0:
			fail("Consumed projectile regained chemistry")
			return false
	return true


func step_world(commands: Array[SimCommand] = []) -> bool:
	if not node.world.step(commands):
		fail("Actual integrated simulation step failed: " + node.world.last_error)
		return false
	for event: Dictionary in node.world.combat_events:
		if String(event.get("type", "")) == "chemistry_formed":
			chemistry_events.append(event.duplicate(true))
	sync_fixture()
	return true


func sync_fixture() -> void:
	var actor: PlayerState = node.world.player()
	node.current_position = Vector2(actor.position_x, actor.position_y) / 1000.0
	node.previous_position = node.current_position
	node.previous_air_height = actor.air_height
	node.actor_motion_history.capture(node.world.players)


func trail_count() -> int:
	var count := 0
	for deposit: ElementDepositState in node.world.deposits:
		if deposit.is_trail():
			count += 1
	return count


func capture(name: String, evidence: Dictionary) -> bool:
	var before: String = node.world.state_hash()
	node.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var footprint_audit := audit_footprints(name)
	var reaction_draws: Array[Dictionary] = []
	for reaction: ElementReactionState in node.world.reactions:
		var model: Dictionary = node.element_chemistry_presenter.reaction_model(reaction, ElementChemistrySystem.recipe(reaction.recipe_wire_id), node.world.tick)
		var summary := {"id": reaction.entity_id, "model_empty": model.is_empty(), "stats": node.element_chemistry_presenter.stats()}
		if not model.is_empty():
			summary["polygon_count"] = model.mask.polygons.size()
			summary["frame_empty"] = model.frame.is_empty()
			summary["footprint_cells"] = node.element_chemistry_presenter.footprint_cells(model).size()
			summary["opacity"] = model.material_opacity
		if name.contains("frostway") and (model.is_empty() or model.frame.is_empty() or int(summary.get("polygon_count", 0)) <= 0 or int(summary.get("footprint_cells", 0)) <= 0):
			fail("Live Frostway capture requires actual material and authoritative clipped geometry: " + name)
			return false
		reaction_draws.append(summary)
		if name.contains("rampart"):
			print("RAMPART DRAW ", JSON.stringify(summary))
	if not (footprint_audit.invalid_parts as Array).is_empty():
		fail("Actual cached footprint triangles are invalid: " + name)
		return false
	var pixels := viewport.get_texture().get_image()
	if name.contains("rampart-contact"):
		node.hide_chemistry_for_visual_probe = true
		node.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var baseline := viewport.get_texture().get_image()
		var changed := 0
		var strong := 0
		for y: int in range(280,400):
			for x: int in range(580,700):
				var delta: Color = pixels.get_pixel(x,y) - baseline.get_pixel(x,y)
				var amount := maxf(absf(delta.r), maxf(absf(delta.g), absf(delta.b)))
				changed += 1 if amount > 0.02 else 0
				strong += 1 if amount > 0.12 else 0
		evidence["actual_ridge_changed_pixels"] = changed
		evidence["actual_ridge_strong_pixels"] = strong
		print("RAMPART PIXELS changed=", changed, " strong=", strong)
		node.hide_chemistry_for_visual_probe = false
		node.queue_redraw()
		if strong < 900:
			fail("Active Rampart needs a visibly distinct solid footprint at actual gameplay scale")
			return false
	if pixels == null or pixels.save_png(output.path_join(name + ".png")) != OK or before != node.world.state_hash():
		fail("Integrated image capture failed or drawing changed authority: " + name)
		return false
	var deposits: Array[Dictionary] = []
	for deposit: ElementDepositState in node.world.deposits:
		deposits.append({"id": deposit.entity_id, "source_cast_id": deposit.source_cast_id, "element": deposit.element_wire_id, "role": "trail" if deposit.is_trail() else "terminal", "radius": deposit.radius, "strength": deposit.strength, "position": [deposit.position_x, deposit.position_y], "created_tick": deposit.created_tick, "expiry_tick": deposit.expiry_tick})
	var projectiles: Array[Dictionary] = []
	for projectile: ProjectileState in node.world.projectiles:
		projectiles.append({"id": projectile.entity_id, "source_cast_id": projectile.source_cast_id, "element": projectile.element_wire_id, "material_strength": projectile.material_strength, "position": [projectile.position_x, projectile.position_y]})
	var record := {"file": name + ".png", "tick": node.world.tick, "champion": node.selected_champion_id, "world_hash": before, "trail_count": trail_count(), "deposits": deposits, "projectiles": projectiles, "reaction_count": node.world.reactions.size(), "footprint_audit": footprint_audit}
	record.merge(evidence)
	record["reaction_draws"] = reaction_draws
	records.append(record)
	print("RENDERED ", output.path_join(name + ".png"))
	return true


func audit_footprints(frame_name: String) -> Dictionary:
	# Re-read the exact production clipping cache after drawing. This is a
	# capture-only diagnostic; no triangulation repair or state injection.
	var result := {"checked_parts": 0, "checked_triangles": 0, "invalid_parts": [], "legacy_world_failures": []}
	var sources: Array = []
	sources.append_array(node.world.deposits)
	sources.append_array(node.world.reactions)
	for deposit: RefCounted in sources:
		var model: Dictionary = node.element_chemistry_presenter.deposit_model(deposit, float(node.world.tick), false) if deposit is ElementDepositState else node.element_chemistry_presenter.reaction_model(deposit, ElementChemistrySystem.recipe(deposit.recipe_wire_id), float(node.world.tick))
		for cell: Dictionary in node.element_chemistry_presenter.footprint_cells(model):
			for part: Dictionary in cell.parts:
				result.checked_parts += 1
				var indices: PackedInt32Array = part.get("indices", PackedInt32Array())
				var expected := PixelEffectGeometry.local_triangle_indices(part.points)
				var valid := not indices.is_empty() and indices.size() % 3 == 0 and indices == expected
				for index: int in indices:
					valid = valid and index >= 0 and index < part.points.size()
				if valid:
					for offset: int in range(0, indices.size(), 3):
						var origin: Vector2 = part.points[indices[offset]]
						var edge_a: Vector2 = part.points[indices[offset + 1]] - origin
						var edge_b: Vector2 = part.points[indices[offset + 2]] - origin
						valid = valid and edge_a.is_finite() and edge_b.is_finite() and absf(edge_a.cross(edge_b)) > 0.0
						result.checked_triangles += 1
				var legacy_failed := Geometry2D.triangulate_polygon(part.points).is_empty()
				if valid and not legacy_failed:
					continue
				var points: Array = []
				for point: Vector2 in part.points:
					points.append([point.x, point.y])
				var local_points: PackedVector2Array = part.points.duplicate()
				if not local_points.is_empty():
					var local_origin := local_points[0]
					for index: int in range(local_points.size()):
						local_points[index] -= local_origin
				var details := {"frame": frame_name, "deposit_values": Array(deposit.canonical_values()), "points": points, "indices": Array(indices), "cell_anchor": [cell.anchor.x, cell.anchor.y], "local_origin_triangulates": not Geometry2D.triangulate_polygon(local_points).is_empty(), "production_triangles_valid": valid}
				if legacy_failed:
					result.legacy_world_failures.append(details)
					print("LEGACY_WORLD_TRIANGULATION ", JSON.stringify(details))
				if not valid:
					result.invalid_parts.append(details)
					print("INVALID_FOOTPRINT ", JSON.stringify(details))
	return result


func fail(message: String) -> void:
	push_error(message)
	quit(1)
