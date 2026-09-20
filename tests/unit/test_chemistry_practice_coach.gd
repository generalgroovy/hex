extends FluxTestSuite

const Coach = preload("res://src/presentation/chemistry_practice_coach.gd")
const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")
const Guide = preload("res://src/presentation/chemistry_guide_model.gd")
const Harness = preload("res://tests/support/chemistry_coach_harness.gd")
const CounterHarness = preload("res://tests/support/chemistry_counter_harness.gd")
var config := SimConfig.new(120)
var bounds: Array = []
var anchor := Vector2i.ZERO


func run() -> int:
	var frost_text := " ".join(Guide.pair_lines(4, 4))
	equal(Guide.matrix_cell(4, 4).name, "Frostway", "Ice mirror display comes from the live recipe")
	check(frost_text.contains("75%") and frost_text.contains("65%") and frost_text.contains("200 px") and frost_text.contains("60 px"), "Frostway details expose source-derived speeds and full capsule width")
	check(not frost_text.contains("Shot-cover health") and frost_text.contains("Both teams") and frost_text.contains("No lingering slow"), "Frostway teaching cannot promise obsolete cover or enemy-only status")
	check(String(Coach.CUES[26][1]).contains("Slide or jump"), "Frostway practice card teaches an executable movement counter")
	check(String(Coach.CUES[9][1]).contains("Light + Light") and String(Coach.CUES[9][1]).contains("Radiance"), "Steam suggests its source-proven reveal counter before the player has already created it")
	var campus := SanctumCampusLayout.new()
	check(campus.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "coach test loads live campus geometry")
	var group: Dictionary = campus.practice_groups_by_id["crucible-experiment"]
	bounds = group["bounds"].duplicate()
	var authored_anchor: Array = group["firing_anchors"][0]
	anchor = Vector2i(int(authored_anchor[0]), int(authored_anchor[1])) * SimConfig.FIXED_SCALE
	_test_invitation_and_scope()
	_test_matter()
	_test_reaction_phases_and_copy()
	_test_ownership_and_selection()
	_test_conditional_effects()
	_test_invalid_state_and_nonmutation()
	_test_inherited_gating()
	_test_paid_cast_lifecycle_and_guest()
	_test_actual_guest_owned_experiment()
	_test_actual_font_fit_and_capacity_copy()
	_test_paid_radiance_steam_counter()
	_test_radiance_steam_context_selection()
	return finish("chemistry-practice-coach")


func _test_paid_radiance_steam_counter() -> void:
	var node := CounterHarness.new()
	check(node.configure_counter(), "counter uses the real Crucible and actual depositing loadout")
	var starting_flux := node.world.player().flux
	check(node.build_counter(), "four independently paid casts build both reactions: " + node.failure)
	if node.reaction(334) == null or node.reaction(310) == null:
		node.free()
		return
	var radiance := node.reaction(334)
	var steam := node.reaction(310)
	equal(node.cast_receipts.size(), 4, "two independent recipes require exactly four successful startups")
	var total_cost := 0
	for receipt: Dictionary in node.cast_receipts:
		check(int(receipt.spent) > 0, "every counter input pays positive Flux")
		total_cost += int(receipt.spent)
	equal(node.world.player().flux, starting_flux - total_cost, "experiment never refills or rewards its four-cast budget")
	equal(node.world.reactions.size(), 2, "independent overlap does not recursively form a third reaction")
	equal(node.world.deposits.size(), 0, "both pairs consume only their four terminal inputs")
	var sources := {radiance.source_a: true, radiance.source_b: true, steam.source_a: true, steam.source_b: true}
	equal(sources.size(), 4, "two reactions retain four distinct authoritative source casts")
	check(Chemistry.cell(Vector2i(radiance.origin_x, radiance.origin_y)) != Chemistry.cell(Vector2i(steam.origin_x, steam.origin_y)), "actual terminal origins occupy separate admitted cells, independent of requested cursor rounding")
	check(radiance.active(node.world.tick) and Chemistry._concealing(steam, node.world.tick, config), "real Radiance active phase overlaps still-concealing Steam")
	check(node.place_target(node.overlap_point), "target is staged at a legal shared footprint point then simulation advances")
	var target := node.world.player(2)
	check(Chemistry.contains(radiance, node.overlap_point, node.world.tick, config) and Chemistry.contains(steam, node.overlap_point, node.world.tick, config), "target really occupies both current masks")
	check(Chemistry.blocks_sight(Vector2i(node.world.player().position_x, node.world.player().position_y), node.overlap_point, node.world.reactions, node.world.tick), "Steam still obstructs the distant observer-target sightline")
	equal(target.chemistry_reveal_ticks, 2, "Radiance refreshes the actual two-tick reveal status")
	check(target.chemistry_conceal_ticks > 0 and node.target_visible(), "actual reveal overrides simultaneous concealment without consuming Steam")
	equal(node._chemistry_practice_view().title, "RADIANCE / STEAM", "four real paid casts reach the new conditional counter card")
	var health := target.health
	var replica := CounterHarness.new()
	check(replica.configure_counter(), "replica has matching authored geometry")
	replica.session_transport.mode = SessionTransport.Mode.CLIENT
	replica.session_transport.accepted = true
	replica.session_transport.local_entity_id = 1
	_assert_counter_replica(node, replica, "active overlap")
	var before := SessionSnapshot.capture(node.world, {1: "Experimenter", 2: "Observer target"})
	for unused: int in range(4):
		node._chemistry_practice_view()
	equal(SessionSnapshot.capture(node.world, {1: "Experimenter", 2: "Observer target"}), before, "counter observation cannot change resources, status, reactions or wire state")
	check(node.place_target(node.steam_origin + Vector2i(0, 20_000)), "target can leave Radiance while remaining in Steam")
	equal(target.chemistry_reveal_ticks, 1, "first unrefreshed simulation tick retains only the existing reveal tail")
	check(node.target_visible(), "one remaining reveal tick still overrides concealment")
	_assert_counter_replica(node, replica, "one-tick reveal tail")
	check(node.world.step([]), "second unrefreshed tick advances")
	equal(target.chemistry_reveal_ticks, 0, "leaving Radiance expires the reveal, not Steam itself")
	check(not node.target_visible(), "the unchanged Steam conceals again once reveal expires")
	_assert_counter_replica(node, replica, "expired reveal")
	check(node.place_target(node.overlap_point), "re-entry uses the same unconsumed independent reactions")
	equal(target.chemistry_reveal_ticks, 2, "re-entry refreshes reveal while Radiance remains active")
	check(node.advance_to(radiance.decay_tick + 2), "ordinary ticks reach Radiance decay and exhaust its reveal tail")
	equal(target.chemistry_reveal_ticks, 0, "inactive Radiance cannot keep refreshing a reveal")
	check(Chemistry._concealing(steam, node.world.tick, config) and not node.target_visible(), "Steam can still conceal after the earlier Radiance stops revealing")
	check(node._chemistry_practice_view().title != "RADIANCE / STEAM", "actual inactive counter state restores the ordinary Steam lesson")
	_assert_counter_replica(node, replica, "Radiance inactive while Steam conceals")
	check(node.advance_to(maxi(radiance.expiry_tick, steam.expiry_tick) + 1), "ordinary simulation removes both results on their expiry steps")
	equal(node.world.reactions.size(), 0, "expiry removes both finite results without recursive descendants")
	equal(node._chemistry_practice_view().kind, "invitation", "both expiry boundaries leave no stale counter lesson")
	equal(target.health, health, "this reveal/conceal counter never fabricates damage or healing")
	_assert_counter_replica(node, replica, "both reactions expired")
	replica.free()
	node.free()
	var blocked := CounterHarness.new()
	check(blocked.configure_counter(true) and blocked.build_counter(), "same four paid casts work around an immutable test worldbone obstruction: " + blocked.failure)
	if blocked.reaction(334) != null and blocked.reaction(310) != null:
		check(blocked.place_target(blocked.overlap_point), "worldbone fixture target has legal movement clearance")
		check(Chemistry.contains(blocked.reaction(334), blocked.overlap_point, blocked.world.tick, config), "blocked target is still geometrically inside Radiance")
		var actual_origin := Vector2i(blocked.reaction(334).position_x, blocked.reaction(334).position_y)
		check(not Chemistry.clear_line(actual_origin, blocked.overlap_point, blocked.world.collision), "existing clear-line rule detects worldbone between actual Radiance origin and target")
		check(Chemistry.clear_line(blocked.steam_origin, blocked.overlap_point, blocked.world.collision), "same worldbone does not block Steam's own contact")
		equal(blocked.world.player(2).chemistry_reveal_ticks, 0, "worldbone prevents Radiance from applying reveal despite radius overlap")
		check(not blocked.target_visible(), "Steam remains concealing behind Radiance-blocking worldbone")
		var blocked_replica := CounterHarness.new()
		check(blocked_replica.configure_counter(true), "blocked replica uses the identical immutable fixture wall")
		blocked_replica.session_transport.mode = SessionTransport.Mode.CLIENT
		blocked_replica.session_transport.accepted = true
		blocked_replica.session_transport.local_entity_id = 1
		_assert_counter_replica(blocked, blocked_replica, "worldbone interruption")
		blocked_replica.free()
	blocked.free()


func _test_radiance_steam_context_selection() -> void:
	var radiance := _reaction(334)
	var steam := _reaction(310)
	radiance.entity_id = 90
	steam.entity_id = 91
	radiance.origin_x -= ElementChemistrySystem.extent(48_000)
	radiance.position_x = radiance.origin_x
	steam.origin_x += ElementChemistrySystem.extent(48_000)
	steam.position_x = steam.origin_x
	steam.source_a = 3
	steam.source_b = 4
	var tick := maxi(radiance.active_tick, steam.active_tick)
	var view := _view(tick, [], [radiance, steam])
	equal(view.title, "RADIANCE / STEAM", "two existing active overlapping local reactions teach their counter")
	equal(view.kind, "reaction", "counter keeps the existing compact card kind")
	equal(view.entity_id, steam.entity_id, "counter keeps ordinary newest-reaction identity")
	equal(view.recipe_wire_id, 310, "counter does not invent a third recipe wire")
	check(view.lines[0].contains("Two reactions") and view.lines[0].contains("Light + Light; Fire + Water"), "copy names two independent pairs, not Radiance plus Steam chemistry")
	check(view.lines[1].contains("it can reach") and view.lines[2].contains("worldbone"), "counter is conditional on real reach and does not assert target visibility")
	equal(view.remaining_ticks, mini(radiance.decay_tick, steam.decay_tick - config.milliseconds_to_ticks(350)) - tick, "overlap countdown ends at the first actual inactive or non-concealing boundary")
	_compact(view)
	for line: String in view.lines:
		check(ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= 412.0, "counter line fits the actual compact card font and width")
	check(ThemeDB.fallback_font.get_string_size(view.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x <= 412.0, "counter title fits the actual header")
	check(ThemeDB.fallback_font.get_string_size(view.phase, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= 412.0, "counter phase fits the actual header")
	equal(_view(tick, [], [steam, radiance]), view, "input array order cannot change the counter lesson")
	check(_view(tick, [], [steam]).title != view.title and _view(tick, [], [radiance]).title != view.title, "one reaction alone never manufactures counter context")
	check(_view(tick, [], [radiance, steam], false).is_empty(), "caller gating still suppresses multi-reaction lessons")
	steam.owner_id = 2
	check(_view(tick, [], [radiance, steam]).title != view.title, "remote-owned counterpart does not become a personal lesson")
	steam.owner_id = 1
	steam.position_x = radiance.position_x + radiance.radius + steam.radius + 1
	check(_view(tick, [], [radiance, steam]).title != view.title, "nearby but currently disjoint masks are not overlap")
	steam.position_x -= 1
	equal(_view(tick, [], [radiance, steam]).title, view.title, "an exact shared boundary remains part of both authoritative masks")
	steam.position_x = steam.origin_x
	steam.radius = 1000
	check(_view(tick, [], [radiance, steam]).title != view.title, "small current Steam footprint is not replaced with its eventual radius")
	steam.radius = int(ElementChemistrySystem.recipe(310).radius)
	var original_origin := steam.origin_x
	steam.origin_x = radiance.origin_x
	check(_view(tick, [], [radiance, steam]).title != view.title, "same-cell synthetic results cannot teach two separately admitted reactions")
	steam.origin_x = original_origin
	steam.origin_x = (int(bounds[0]) - 1) * SimConfig.FIXED_SCALE
	check(_view(tick, [], [radiance, steam]).title != view.title, "out-of-group counterpart is not borrowed")
	steam.origin_x = original_origin
	check(_view(radiance.active_tick - 1, [], [radiance, steam]).title != view.title, "forming Radiance never promises an active counter")
	var thinning_tick := steam.decay_tick - config.milliseconds_to_ticks(350)
	check(_view(thinning_tick, [], [radiance, steam]).title != view.title, "Steam thinning immediately ends the overlap lesson")
	check(_view(radiance.decay_tick, [], [radiance, steam]).title != view.title, "Radiance decay never promises continuing reveal")
	var newer := _reaction(303)
	newer.entity_id = 200
	check(_view(tick, [], [radiance, steam, newer]).title != view.title, "a newer unrelated experiment retains the existing focus policy")
	var earlier_radiance := _reaction(334)
	earlier_radiance.entity_id = 89
	earlier_radiance.origin_x = radiance.origin_x
	earlier_radiance.position_x = radiance.position_x
	earlier_radiance.decay_tick = tick + 1
	equal(_view(tick, [], [earlier_radiance, steam, radiance]), view, "multiple counterparts select the newest stable identity, not incoming order")
	var before := [radiance.canonical_values(), steam.canonical_values()]
	for unused: int in range(4):
		_view(tick, [], [steam, null, {}, radiance])
	equal([radiance.canonical_values(), steam.canonical_values()], before, "counter observation never mutates either independent result")
	radiance.entity_id = 92
	var reversed_focus := _view(tick, [], [steam, radiance])
	equal(reversed_focus.title, view.title, "counter context is symmetric when Radiance is the newest result")
	equal(reversed_focus.recipe_wire_id, 334, "symmetric focus still retains a real recipe identity")


func _assert_counter_replica(authority: Node, replica: Node, label: String) -> void:
	var snapshot := SessionSnapshot.capture(authority.world, {1: "Experimenter", 2: "Observer target"})
	check(SessionSnapshot.validate(snapshot) and SessionSnapshot.apply_to_world(snapshot, replica.world), label + " uses an ordinary validated snapshot")
	replica.session_round_values = snapshot.round
	equal(replica.world.player(2).chemistry_reveal_ticks, authority.world.player(2).chemistry_reveal_ticks, label + " reveal status is host/guest identical")
	equal(replica.world.player(2).chemistry_conceal_ticks, authority.world.player(2).chemistry_conceal_ticks, label + " concealment status is host/guest identical")
	equal(replica.target_visible(), authority.target_visible(), label + " inherited visibility agrees across snapshot replication")
	equal(replica._chemistry_practice_view(), authority._chemistry_practice_view(), label + " compact coach model agrees on host and guest")


func _test_actual_guest_owned_experiment() -> void:
	var authority := Harness.new()
	check(authority.configure_fixture(), "guest-owned fixture uses the real authored Crucible")
	var guest_actor := PlayerState.new(2)
	check(authority.champion_catalog.apply_to_player(guest_actor, "oh_tipi"), "remote actor uses a real playable profile")
	guest_actor.position_x = authority.fixture_anchor.x
	guest_actor.position_y = authority.fixture_anchor.y
	guest_actor.flux_recovery_per_second = 0
	check(guest_actor.place_proven_spell(0, 145) and guest_actor.place_proven_spell(1, 140), "guest equips two real paid projectile spells")
	authority.world.players.append(guest_actor)
	authority.world.player().position_x = 100000
	var replica := Harness.new()
	check(replica.configure_fixture(), "actual guest replica uses the same map")
	replica.session_transport.mode = SessionTransport.Mode.CLIENT
	replica.session_transport.accepted = true
	replica.session_transport.local_entity_id = 2
	for slot: int in [1, 2]:
		check(authority.paid_cast(slot, 2), "host authority accepts and charges the remote actor's real cast")
		for unused: int in range(240):
			check(authority.world.step([]), "remote experiment advances on authoritative ticks")
			if (slot == 1 and not authority.world.deposits.is_empty()) or (slot == 2 and not authority.world.reactions.is_empty()):
				break
		var snapshot := SessionSnapshot.capture(authority.world, {1: "Host", 2: "Guest"})
		check(SessionSnapshot.validate(snapshot) and SessionSnapshot.apply_to_world(snapshot, replica.world), "guest-owned experiment crosses the normal snapshot boundary")
		replica.session_round_values = snapshot.round
		var view := replica._chemistry_practice_view()
		equal(view.get("kind"), "matter" if slot == 1 else "reaction", "guest coach follows its own actual paid experiment")
		check(authority._chemistry_practice_view().is_empty(), "host outside the Crucible does not borrow the guest's lesson")
		equal(replica._local_player_state().entity_id, 2, "ordinary connected-client identity selects the remote actor")
		if slot == 2:
			equal(view.get("recipe_wire_id"), 310, "actual guest-owned Fire plus Water teaches Steam")
	replica.free()
	authority.free()


func _test_inherited_gating() -> void:
	var node := Harness.new()
	check(node.configure_fixture(), "coach integration uses the real campus, actor and inherited gating")
	equal(node._chemistry_practice_view().kind, "invitation", "authored Crucible anchor allows offline free practice")
	for panel: RefCounted in [node.controls_editor, node.spell_loom_editor, node.player_compendium, node.character_selection_grid]:
		panel.set("is_open", true)
		check(node._chemistry_practice_view().is_empty(), "inherited menu/Gallery gate suppresses coaching")
		panel.set("is_open", false)
	for property: String in ["join_address_editor_open", "show_visual_specimen"]:
		node.set(property, true)
		check(node._chemistry_practice_view().is_empty(), "inherited modal/specimen gate suppresses coaching")
		node.set(property, false)
	node.application_input_active = false
	check(node._chemistry_practice_view().is_empty(), "focus interruption hides coach")
	node.application_input_active = true
	node.controls_input_guard_frames = 2
	check(node._chemistry_practice_view().is_empty(), "modal input rearm interval stays quiet")
	node.controls_input_guard_frames = 0
	node.world.player().health = 0
	check(node._chemistry_practice_view().is_empty(), "defeated local actor receives no invitation")
	node.world.player().health = node.world.player().health_maximum
	node.world.player().position_x = 100000
	check(node._chemistry_practice_view().is_empty(), "outside the authored group receives no invitation")
	node.world.player().position_x = node.fixture_anchor.x
	for phase: int in [SessionRound.Phase.ACTIVE, SessionRound.Phase.RESULT]:
		node.session_round_values = PackedInt32Array([1, phase, 1, 120, 0, 3, 2, 1, 0, 0, 2, 0, 0])
		check(SessionRound.validate_packet(node.session_round_values), "round gating fixture uses a valid existing wire packet")
		check(node._chemistry_practice_view().is_empty(), "active/result shared rounds suppress free-practice coach")
	node.session_round_values = node.authoritative_session.session_round.capture(node.world)
	node.session_transport.mode = SessionTransport.Mode.HOSTING
	equal(node._chemistry_practice_view().kind, "invitation", "host free-practice uses its actual authoritative round state")
	node.session_transport.mode = SessionTransport.Mode.CLIENT
	node.session_transport.accepted = true
	node.session_transport.local_entity_id = 1
	node.spectator_focus.active = true
	node.spectator_focus.focus_entity_id = 1
	check(node._is_spectating(), "spectator fixture reaches the real inherited spectator gate")
	check(node._chemistry_practice_view().is_empty(), "spectating cannot show another actor's experiment")
	node.spectator_focus.reset()
	node.session_transport.local_entity_id = 2
	check(node._chemistry_practice_view().is_empty(), "guest missing its own replicated actor must not coach the host fallback")
	node.free()


func _test_paid_cast_lifecycle_and_guest() -> void:
	var node := Harness.new()
	check(node.configure_fixture(), "paid lesson begins on the authored Crucible firing anchor")
	var before := node.world.player().flux
	check(node.paid_cast(1), "first real projectile startup pays its positive Flux cost")
	check(node.advance_until("terminal"), "real cursor endpoint creates terminal matter after any earlier flight trail")
	var terminal_count := 0
	for deposit: ElementDepositState in node.world.deposits:
		if not deposit.is_trail():
			terminal_count += 1
	equal(terminal_count, 1, "one real cast leaves one terminal deposit independently of its flight trail")
	equal(node._chemistry_practice_view().title, "Fire MATTER", "real first cast identifies Fire matter")
	check(node.paid_cast(2), "second separate paid Water cast aims at the same point")
	check(node.advance_until("reaction"), "real overlapping terminal deposits form chemistry without fabricated state")
	equal(node.paid_casts, 2, "experiment required two independently paid cast startups")
	equal(node.world.player().flux, before - int(CombatTuning.cast_definition(145).flux_cost) - int(CombatTuning.cast_definition(140).flux_cost), "only the real two cast costs are spent with recovery disabled in the fixture")
	if node.world.reactions.is_empty():
		node.free()
		return
	var reaction: ElementReactionState = node.world.reactions[0]
	equal(reaction.recipe_wire_id, 310, "production Fire plus Water resolves to Steam")
	check(node._chemistry_practice_view().phase.begins_with("FORMING"), "first production reaction observation is a harmless warning")
	var replica := Harness.new()
	check(replica.configure_fixture(), "guest fixture has the same authored map")
	replica.session_transport.mode = SessionTransport.Mode.CLIENT
	replica.session_transport.accepted = true
	replica.session_transport.local_entity_id = 1
	for target_tick: int in [node.world.tick, reaction.active_tick, reaction.decay_tick, reaction.expiry_tick]:
		check(node.advance_to(target_tick), "lifecycle advances by real 120 Hz simulation ticks")
		var snapshot := SessionSnapshot.capture(node.world, {1: "Coach Test"})
		check(not snapshot.is_empty() and SessionSnapshot.validate(snapshot), "live paid result is a valid normal wire snapshot")
		check(SessionSnapshot.apply_to_world(snapshot, replica.world), "guest applies the ordinary replicated world snapshot")
		replica.session_round_values = snapshot.round
		var expected := node._chemistry_practice_view()
		equal(replica._chemistry_practice_view(), expected, "guest observation of paid chemistry matches host at each phase boundary")
		var actor_before := node.world.player().canonical_values()
		var snapshot_before := SessionSnapshot.capture(node.world, {1: "Coach Test"})
		for unused: int in range(4):
			node._chemistry_practice_view()
		equal(node.world.player().canonical_values(), actor_before, "observing the lesson cannot spend or reward actor resources")
		equal(SessionSnapshot.capture(node.world, {1: "Coach Test"}), snapshot_before, "observing does not change world, matter, reaction or network state")
		if target_tick == reaction.active_tick:
			check(expected.phase.begins_with("ACTIVE"), "coach marks only actual active Steam as active")
		elif target_tick == reaction.decay_tick:
			check(expected.phase.begins_with("HARMLESS DECAY"), "production decay cannot promise an active hazard")
		elif target_tick == reaction.expiry_tick:
			equal(expected.kind, "invitation", "actual expiry clears the lesson without stale success")
	replica.free()
	node.free()


func _test_actual_font_fit_and_capacity_copy() -> void:
	var views: Array[Dictionary] = [_view(0), _view(1, [_deposit(99, 99, 2)])]
	for wire: int in range(301, 337):
		var reaction := _reaction(wire)
		for tick: int in [reaction.created_tick, reaction.active_tick, reaction.decay_tick]:
			views.append(_view(tick, [], [reaction]))
	for view: Dictionary in views:
		check(ThemeDB.fallback_font.get_string_size(view.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x <= 412.0, "title fits actual coach width at its14px font")
		check(ThemeDB.fallback_font.get_string_size(view.phase, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= 412.0, "phase fits actual coach width at its11px font")
		for line: String in view.lines:
			check(ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= 412.0, "every coach line fits actual412px text lane at12px")
	var crystal := _reaction(329)
	var copy := " ".join(_view(crystal.active_tick, [], [crystal]).lines)
	check(copy.contains("can split") and copy.contains("spare capacity") and copy.contains("damage"), "Crystal Lens keeps conditional split capacity and damage caveats")


func _view(tick: int, deposits: Array = [], reactions: Array = [], allowed: bool = true) -> Dictionary:
	return Coach.sample(1, anchor, tick, config, bounds, deposits, reactions, allowed)


func _test_invitation_and_scope() -> void:
	var invitation := _view(0)
	equal(invitation.kind, "invitation", "empty practice invites experimentation, not completion")
	var copy := " ".join(invitation.lines)
	check(copy.contains("separate casts") and copy.contains("matching reaction strength"), "invitation teaches exact-strength ingredients from separate casts")
	check(copy.contains("Cross-element pairs") and copy.contains("one family") and copy.contains("Bolt, Heavy or Rapid"), "invitation turns distinct current family strengths into a cross-element choice")
	check(not copy.contains("Fire") and not copy.contains("Water"), "invitation never assumes an equipped pair")
	check(copy.contains("Spray leaves no chemistry matter") and copy.contains("cannot supply a pair"), "live Spray cannot be mistaken for a chemistry ingredient")
	check(not copy.to_lower().contains("clash") and not copy.to_lower().contains("intercept"), "coach does not promise deferred projectile interactions")
	check(not copy.contains("Wave") and not copy.contains("Beam") and not copy.contains("Field"), "practice invitation recommends only the four runtime families")
	_compact(invitation)
	equal(_view(0, [], [], false), {}, "caller suppresses all coaching during menus and shared modes")
	equal(Coach.sample(1, anchor, 0, config, [], [], []), {}, "missing practice geometry fails closed")
	for bad_bounds: Array in [[0, 0, 0, 0], [0, 0, -1, 10], [0, 0, "wide", 100], [0, 0, 10.5, 100], [0, 0, INF, 10]]:
		equal(Coach.sample(1, anchor, 0, config, bad_bounds, [], []), {}, "invalid bounds fail closed")
	equal(Coach.sample(1, anchor, 0, null, bounds, [], []), {}, "missing clock fails closed")
	equal(Coach.sample(0, anchor, 0, config, bounds, [], []), {}, "no actor means no invitation")
	equal(Coach.sample(1, anchor, -1, config, bounds, [], []), {}, "negative world tick fails closed")
	var outside := Vector2i((int(bounds[0]) + int(bounds[2])) * SimConfig.FIXED_SCALE, anchor.y)
	equal(Coach.sample(1, outside, 0, config, bounds, [], []), {}, "actual practice group's right boundary is excluded")
	var shifted := [int(bounds[0]) + 1000, int(bounds[1]), int(bounds[2]), int(bounds[3])]
	equal(Coach.sample(1, anchor, 0, config, shifted, [], []), {}, "geometry is supplied, never a hardcoded Crucible rectangle")


func _test_matter() -> void:
	var fire := _deposit(10, 10, 2, 1, 10, 15)
	equal(_view(9, [fire]).kind, "invitation", "unborn matter is never taught as present")
	var view := _view(10, [fire])
	equal(view.kind, "matter", "real terminal matter unlocks its contextual instruction")
	equal(view.title, "Fire MATTER", "matter identity comes from the live element guide")
	equal(view.remaining_ticks, fire.expiry_tick - 10, "remaining matter duration uses the state deadline")
	check(view.phase.contains("4.00s"), "120 Hz matter countdown reports the longer authored Fire duration")
	var matter_copy := " ".join(view.lines)
	check(matter_copy.contains("no damage or status"), "plain matter never implies a hazard")
	check(matter_copy.contains("reaction strength 15") and matter_copy.contains("unequal strength stays matter"), "coach reads the deposited source strength and explains exact matching")
	_compact(view)
	var air := _deposit(14, 14, 4, 1, 10)
	equal(_view(10, [air]).title, "Air MATTER", "wind wire four uses the player-facing Air label")
	equal(_view(fire.expiry_tick - 1, [fire]).kind, "matter", "last live tick still shows harmless matter")
	equal(_view(fire.expiry_tick, [fire]).kind, "invitation", "expiry boundary returns invitation without success")
	var remote := _deposit(11, 11, 3, 2, 11)
	equal(_view(12, [remote]).kind, "invitation", "another traveller's matter does not become local setup")
	var outside := _deposit(12, 12, 3, 1, 12)
	outside.position_x = (int(bounds[0]) - 1) * SimConfig.FIXED_SCALE
	equal(_view(13, [outside]).kind, "invitation", "out-of-group local matter does not enter the lesson")
	var newer := _deposit(13, 13, 3, 1, 12)
	equal(_view(13, [newer, fire]).entity_id, 13, "latest matter is independent of incoming array order")
	equal(_view(13, [fire, newer]).entity_id, 13, "latest matter selection is stable")


func _test_reaction_phases_and_copy() -> void:
	for wire: int in range(301, 337):
		var reaction := _reaction(wire)
		check(reaction.validate(), "kernel fixture validates for recipe %d" % wire)
		var definition := Chemistry.recipe(wire)
		var pair := "%s + %s" % [Guide.ELEMENTS[int(definition.elements[0])], Guide.ELEMENTS[int(definition.elements[1])]]
		equal(_view(reaction.created_tick - 1, [], [reaction]).kind, "invitation", "unborn reaction cannot be selected")
		for tick: int in [reaction.created_tick, reaction.active_tick - 1, reaction.active_tick, reaction.decay_tick - 1, reaction.decay_tick, reaction.expiry_tick - 1]:
			var view := _view(tick, [], [reaction])
			equal(view.kind, "reaction", "every live phase is available without manufactured progress")
			equal(view.recipe_wire_id, wire, "display preserves the exact recipe identity")
			equal(view.title, String(definition.name).to_upper(), "recipe name comes from the executable kernel")
			equal(view.lines[0], pair, "displayed pair matches the exact kernel recipe")
			if tick < reaction.active_tick:
				check(view.phase.begins_with("FORMING / HARMLESS WARNING"), "formation explicitly warns without active effects")
				equal(view.remaining_ticks, reaction.active_tick - tick, "formation countdown ends on exact activation tick")
				check(view.lines[1].begins_with("Then: "), "forming effect is conditional future copy")
			elif tick >= reaction.decay_tick:
				check(view.phase.begins_with("HARMLESS DECAY"), "decay is never called active")
				equal(view.remaining_ticks, reaction.expiry_tick - tick, "decay countdown ends at exact expiry")
				check(view.lines[1].contains("does not apply effects"), "decay text cannot claim to clear lingering actor statuses")
			else:
				check(view.phase.begins_with("ACTIVE"), "active lifecycle is distinguished from warning and decay")
				equal(view.remaining_ticks, reaction.decay_tick - tick, "active countdown reads current state deadline")
			_compact(view)
			equal(_view(tick, [], [reaction]), view, "late/repeated observation is stateless")
		equal(_view(reaction.expiry_tick, [], [reaction]).kind, "invitation", "all recipes return to experiment at expiry")
		equal(_view(reaction.active_tick, [], []).kind, "invitation", "court reset does not leave a stale completion or reaction")
		var reversed := _reaction(wire, true)
		equal(_view(reversed.active_tick, [], [reversed]).lines[0], pair, "both cast orders display the same pair")


func _test_ownership_and_selection() -> void:
	var local := _deposit(20, 20, 2, 1, 1)
	var remote := _deposit(21, 21, 3, 2, 2)
	var mixed := Chemistry.form_reaction(remote, local, 30, 10, config)
	equal(mixed.owner_id, 1, "kernel chooses the oldest deposit owner even when arguments reverse")
	equal(_view(mixed.active_tick, [], [mixed]).entity_id, 30, "local-owned mixed-caster reaction is shown without claiming both casts")
	local.entity_id = 22
	mixed = Chemistry.form_reaction(local, remote, 31, 10, config)
	equal(mixed.owner_id, 2, "newer local cast does not steal reaction ownership")
	equal(_view(mixed.active_tick, [], [mixed]).kind, "invitation", "remote-owned mixed-caster result is not attributed to local player")
	var first := _reaction(310)
	var next := _reaction(303)
	next.entity_id = first.entity_id + 1
	equal(_view(next.active_tick, [], [next, first]).entity_id, next.entity_id, "equal creation ticks break ties using stable entity ID")
	equal(_view(next.active_tick, [], [first, next]).entity_id, next.entity_id, "reaction selection never depends on array order")
	first.created_tick += 1
	equal(_view(next.active_tick, [], [first, next]).entity_id, first.entity_id, "creation tick wins before entity ID")
	first.origin_x = (int(bounds[0]) - 1) * SimConfig.FIXED_SCALE
	equal(_view(next.active_tick, [], [first]).kind, "invitation", "reaction origin must belong to supplied practice group")


func _test_conditional_effects() -> void:
	var steam := _reaction(310)
	var thinning_tick := steam.decay_tick - config.milliseconds_to_ticks(350)
	check(_view(thinning_tick - 1, [], [steam]).lines[1].contains("conceals distant"), "Steam description follows its actual concealment interval")
	check(_view(thinning_tick, [], [steam]).lines[1].contains("no longer conceals"), "thin Steam cannot be called concealing while lifecycle stays active")
	for wire: int in [313, 328]:
		var reaction := _reaction(wire)
		check(_view(reaction.active_tick, [], [reaction]).lines[1].contains("cannot deal damage"), "unlinked arc/circuit never promises damage")
		var link := _deposit(50, 50, 6 if wire == 313 else 5, 2, 0)
		reaction.linked_deposit_ids = PackedInt64Array([link.entity_id])
		reaction.path_points = PackedInt64Array([anchor.x, anchor.y, anchor.x + 20000, anchor.y])
		check(not _view(reaction.active_tick, [link], [reaction]).lines[1].contains("cannot deal damage"), "a live remote source can power a locally owned path")
		link.expiry_tick = reaction.active_tick
		check(_view(reaction.active_tick, [link], [reaction]).lines[1].contains("cannot deal damage"), "expired linked source disables damage copy immediately")
	var flood := _reaction(319)
	check(not _view(flood.active_tick, [], [flood]).lines[1].contains("cannot deal damage"), "Conductive Flood can damage locally without extra links")
	flood.linked_deposit_ids = PackedInt64Array([80])
	flood.path_points = PackedInt64Array([anchor.x, anchor.y, anchor.x + 20000, anchor.y])
	check(_view(flood.active_tick, [], [flood]).lines[1].contains("cannot deal damage"), "a missing selected Water link stops linked Flood damage")


func _test_invalid_state_and_nonmutation() -> void:
	var matter := _deposit(70, 70, 3, 1, 0)
	var reaction := _reaction(310)
	var matter_before := matter.canonical_values()
	var reaction_before := reaction.canonical_values()
	var bounds_before := bounds.duplicate()
	var deposits: Array = [matter]
	var reactions: Array = [reaction]
	for tick: int in range(0, reaction.expiry_tick + 2):
		_view(tick, deposits, reactions)
	equal(matter.canonical_values(), matter_before, "coach never mutates terminal matter authority")
	equal(reaction.canonical_values(), reaction_before, "coach never mutates reaction authority")
	equal(bounds, bounds_before, "coach never mutates map geometry")
	equal(deposits, [matter], "coach never sorts or consumes the caller's deposit array")
	equal(reactions, [reaction], "coach never sorts or consumes the caller's reaction array")
	matter.strength = 0
	equal(_view(1, [matter]).kind, "invitation", "consumed zero-strength matter fails closed")
	reaction.recipe_wire_id = 999
	equal(_view(reaction.active_tick, [], [reaction]).kind, "invitation", "unknown recipe cannot produce invented coaching")
	equal(_view(1, [null, {}, 2], [null, {}, 2]).kind, "invitation", "malformed snapshot entries are ignored safely")
	var actor := PlayerState.new(1)
	actor.position_x = anchor.x
	actor.position_y = anchor.y
	var actor_before := actor.canonical_values()
	Coach.sample(actor.entity_id, Vector2i(actor.position_x, actor.position_y), 0, config, bounds, [], [])
	equal(actor.canonical_values(), actor_before, "observer has no actor mutation path")


func _compact(view: Dictionary) -> void:
	check(view.lines.size() <= 3, "coach always has at most three short display lines")
	for line: String in view.lines:
		check(line.length() <= 64, "compact copy stays under 64 characters per line")
		check(not line.to_lower().contains("success") and not line.to_lower().contains("completed"), "snapshot presence never becomes fabricated achievement")


func _deposit(entity_id: int, cast_id: int, element: int, owner: int = 1, tick: int = 0, reaction_strength: int = 1) -> ElementDepositState:
	var deposits: Array = []
	Chemistry.deposit_terminal(deposits, entity_id, cast_id, 100 + element, owner, owner, element, anchor, tick, config, Vector2i(1000, 0), 1000, false, reaction_strength)
	return deposits[0]


func _reaction(wire: int, reverse: bool = false) -> ElementReactionState:
	var recipe := Chemistry.recipe(wire)
	var a := _deposit(1, 1, int(recipe.elements[0]))
	var b := _deposit(2, 2, int(recipe.elements[1]))
	return Chemistry.form_reaction(b, a, 100, 10, config) if reverse else Chemistry.form_reaction(a, b, 100, 10, config)
