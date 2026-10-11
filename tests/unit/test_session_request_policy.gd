extends FluxTestSuite


const CAMPUS_PATH: String = "res://content/maps/sanctum_campus_g2_v1.json"
const Attunement = preload("res://src/app/champion_attunement.gd")


func run() -> int:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file(CAMPUS_PATH), "campus loads for interaction policy")
	var state := PlayerState.new(2)
	_place_at(state, layout, "training-reset")
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_TRAINING_RESET, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.ACCEPTED, "Practice Bell request is accepted only at its authoritative position")
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_CHAMPION_NEXT, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.REFUSED_DISTANCE, "Champion request is refused at the Practice Bell")
	_place_at(state, layout, "champion-loom")
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_CHAMPION_NEXT, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.ACCEPTED, "Champion request is accepted at the Loom")
	_place_at(state, layout, "spell-loom")
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_SPELL_EQUIP, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.ACCEPTED, "spell weave is accepted only at the Spell Loom")
	_place_at(state, layout, "momentum-chime")
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_IMPACT_PRACTICE, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.ACCEPTED, "impact practice is accepted only at the Momentum Chime")
	state.control_state = PlayerState.ControlState.LAUNCHED
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_IMPACT_PRACTICE, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.REFUSED_UNAVAILABLE, "impact practice cannot be retriggered during authored loss of control")
	state.control_state = PlayerState.ControlState.FREE
	state.impact_recovery_ticks = 2
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_IMPACT_PRACTICE, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.REFUSED_UNAVAILABLE, "impact practice cannot erase the recovery decision window")
	state.impact_recovery_ticks = 0
	state.position_x = 400_000
	state.position_y = 400_000
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_TRAINING_RESET, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.REFUSED_DISTANCE, "remote station request fails closed away from every station")
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_EMOTE, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.ACCEPTED, "social emote works away from stations")
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_SPELL_EQUIP, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.REFUSED_DISTANCE, "remote spell weave fails closed away from the Loom")
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_IMPACT_PRACTICE, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.REFUSED_DISTANCE, "remote impact practice fails closed away from the Chime")
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_EMOTE, state, layout.stations_by_id, 20, 21), SessionRequestPolicy.REFUSED_COOLDOWN, "social emote cooldown is host-validated")
	equal(SessionRequestPolicy.validate(99, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.REFUSED_UNAVAILABLE, "unknown request fails closed")
	_place_at(state, layout, "session-hearth")
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_READY_TOGGLE, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.ACCEPTED, "readiness toggle is accepted only at the Session Hearth")
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_PRACTICE_START, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.ACCEPTED, "practice start intent is accepted at the Session Hearth before host-role validation")
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_READY_TOGGLE, state, layout.stations_by_id, 20, 0, SessionRound.Phase.ACTIVE), SessionRequestPolicy.REFUSED_UNAVAILABLE, "active court refuses Hearth mutation")
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_EMOTE, state, layout.stations_by_id, 20, 0, SessionRound.Phase.ACTIVE), SessionRequestPolicy.ACCEPTED, "active court keeps bounded social emotes available")
	state.position_x = 2_300_000
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_READY_TOGGLE, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.REFUSED_DISTANCE, "remote readiness fails closed away from the Hearth")
	state.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_EMOTE, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.REFUSED_UNAVAILABLE, "non-champion cannot issue a social request")
	_test_exact_attunement_policy(layout)
	_test_colocated_action_permissions(layout)
	_test_attunement_application()
	return finish("session-request-policy")


func _test_colocated_action_permissions(layout: SanctumCampusLayout) -> void:
	var actions := {
		SessionTransport.REQUEST_TRAINING_RESET: "training-reset",
		SessionTransport.REQUEST_IMPACT_PRACTICE: "momentum-chime",
		SessionTransport.REQUEST_CHAMPION_NEXT: "champion-loom",
		SessionTransport.REQUEST_CHAMPION_SELECT: "champion-loom",
		SessionTransport.REQUEST_SPELL_EQUIP: "spell-loom",
		SessionTransport.REQUEST_WEAVE_APPLY: "spell-loom",
		SessionTransport.REQUEST_READY_TOGGLE: "session-hearth",
		SessionTransport.REQUEST_PRACTICE_START: "session-hearth",
	}
	var layout_before := CanonicalContent.sha256(layout.data)
	for action: int in actions:
		var station_id := String(actions[action])
		var station: Dictionary = layout.stations_by_id[station_id]
		var anchor := SanctumCampusLayout._parse_point(station["position"]) * SimConfig.FIXED_SCALE
		var state := PlayerState.new(2)
		for offset: Vector2i in [Vector2i.ZERO, Vector2i(0, 32000), Vector2i(-36000, 0), Vector2i(36000, 0)]:
			state.position_x = anchor.x + offset.x
			state.position_y = anchor.y + offset.y
			var state_before := state.canonical_values()
			equal(SessionRequestPolicy.validate(action, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.ACCEPTED, "requested colocated action is admitted independently of the lexical focus winner")
			equal(state.canonical_values(), state_before, "range admission is intent validation, not a resource/round/action mutation")
		_place_at(state, layout, station_id)
		state.position_y -= 17000
		equal(SessionRequestPolicy.validate(action, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.REFUSED_DISTANCE, "rear-door intent is refused despite being within the circular radius")
		_place_at(state, layout, station_id)
		state.position_y += int(station["interaction_radius"]) * SimConfig.FIXED_SCALE + 1
		equal(SessionRequestPolicy.validate(action, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.REFUSED_DISTANCE, "requested action uses its own radius, not another nearby action's range")
		for other_id: String in ["movement-guide", "momentum-chime", "champion-loom", "farflow-host"]:
			if String(layout.stations_by_id[other_id]["service_group"]) == String(station["service_group"]):
				continue
			_place_at(state, layout, other_id)
			equal(SessionRequestPolicy.validate(action, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.REFUSED_DISTANCE, "a different building group cannot authorize the requested service")
		_place_at(state, layout, station_id)
		for phase: int in [SessionRound.Phase.ACTIVE, SessionRound.Phase.RESULT]:
			equal(SessionRequestPolicy.validate(action, state, layout.stations_by_id, 20, 0, phase), SessionRequestPolicy.REFUSED_UNAVAILABLE, "colocation cannot bypass the existing round-phase gate")
		state.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
		equal(SessionRequestPolicy.validate(action, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.REFUSED_UNAVAILABLE, "colocation cannot grant service authority to a training target")
		state.actor_kind = PlayerState.ActorKind.CHAMPION
		equal(SessionRequestPolicy.validate(action, state, layout.stations_by_id, -1, 0), SessionRequestPolicy.REFUSED_UNAVAILABLE, "invalid host tick cannot admit grouped service intent")
	var practice_state := PlayerState.new(2)
	_place_at(practice_state, layout, "momentum-chime")
	practice_state.position_y += 80000
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_TRAINING_RESET, practice_state, layout.stations_by_id, 20, 0), SessionRequestPolicy.ACCEPTED, "Restore's 96 px range remains reachable at 80 px from the shared door")
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_IMPACT_PRACTICE, practice_state, layout.stations_by_id, 20, 0), SessionRequestPolicy.REFUSED_DISTANCE, "Momentum cannot borrow Restore's longer range")
	var narrowed: Dictionary[String, Dictionary] = layout.stations_by_id.duplicate(true)
	narrowed["spell-loom"]["interaction_radius"] = 24
	var academy_state := PlayerState.new(2)
	_place_at(academy_state, layout, "champion-loom")
	academy_state.position_y += 40000
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_CHAMPION_SELECT, academy_state, narrowed, 20, 0), SessionRequestPolicy.ACCEPTED, "requested champion selection keeps its own 96 px range")
	equal(SessionRequestPolicy.validate(SessionTransport.REQUEST_SPELL_EQUIP, academy_state, narrowed, 20, 0), SessionRequestPolicy.REFUSED_DISTANCE, "alphabetical Champion focus cannot grant an out-of-range spell equip")
	for action: int in [SessionTransport.REQUEST_CHAMPION_SELECT, SessionTransport.REQUEST_WEAVE_APPLY, SessionTransport.REQUEST_IMPACT_PRACTICE]:
		var state := PlayerState.new(2)
		_place_at(state, layout, String(actions[action]))
		state.control_state = PlayerState.ControlState.STUNNED
		equal(SessionRequestPolicy.validate(action, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.REFUSED_UNAVAILABLE, "grouped action selection cannot erase a live control state")
	equal(CanonicalContent.sha256(layout.data), layout_before, "grouped policy checks do not rewrite authority or action definitions")


func _test_exact_attunement_policy(layout: SanctumCampusLayout) -> void:
	for action: int in [SessionTransport.REQUEST_CHAMPION_NEXT, SessionTransport.REQUEST_CHAMPION_SELECT]:
		var state := PlayerState.new(2)
		_place_at(state, layout, "champion-loom")
		equal(SessionRequestPolicy.validate(action, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.ACCEPTED, "both attunement actions accept a free grounded actor at the Gallery")
		for phase: int in [SessionRound.Phase.ACTIVE, SessionRound.Phase.RESULT]:
			equal(SessionRequestPolicy.validate(action, state, layout.stations_by_id, 20, 0, phase), SessionRequestPolicy.REFUSED_UNAVAILABLE, "attunement remains Wellspring-only")
		_place_at(state, layout, "training-reset")
		equal(SessionRequestPolicy.validate(action, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.REFUSED_DISTANCE, "exact/cycle attunement cannot operate remotely")
		_place_at(state, layout, "champion-loom")
		for control: int in [PlayerState.ControlState.LAUNCHED, PlayerState.ControlState.GRAPPLED, PlayerState.ControlState.CHARGING, PlayerState.ControlState.STUNNED, PlayerState.ControlState.ROOTED, PlayerState.ControlState.SLOWED]:
			state.control_state = control
			equal(SessionRequestPolicy.validate(action, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.REFUSED_UNAVAILABLE, "attunement cannot erase active control state %d" % control)
		state.control_state = PlayerState.ControlState.FREE
		for field: String in ["control_ticks", "pending_cast_wire_id", "pending_cast_ticks", "cast_recovery_ticks", "movement_commitment_ticks", "hop_ticks", "air_dodge_ticks", "slide_ticks", "wave_dash_ticks", "vault_ticks", "superglide_ticks", "wall_skim_ticks", "impact_recovery_ticks", "jump_protection_ticks", "spawn_protection_ticks", "air_height", "air_vertical_velocity"]:
			state.set(field, 1)
			equal(SessionRequestPolicy.validate(action, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.REFUSED_UNAVAILABLE, "attunement refuses live state %s" % field)
			state.set(field, 0)
		state.air_floating = true
		equal(SessionRequestPolicy.validate(action, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.REFUSED_UNAVAILABLE, "Float cannot be replaced through a stale zero-height state")
		state.air_floating = false
		state.air_vertical_velocity = -1
		equal(SessionRequestPolicy.validate(action, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.REFUSED_UNAVAILABLE, "vertical transition must resolve actual landing first")
		state.air_vertical_velocity = 0
		state.health = 0
		equal(SessionRequestPolicy.validate(action, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.REFUSED_UNAVAILABLE, "dead actor cannot attune")
		state.health = 1
		state.velocity_x = 100_000
		state.movement_mode = PlayerState.MovementMode.WALK
		state.hop_cooldown_ticks = 12
		equal(SessionRequestPolicy.validate(action, state, layout.stations_by_id, 20, 0), SessionRequestPolicy.ACCEPTED, "ground walking and passive cooldowns do not unnecessarily lock Gallery interaction")


func _test_attunement_application() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "attunement ability catalog loads")
	var catalog := ChampionCatalog.new()
	check(catalog.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "attunement champion catalog loads")
	var state := PlayerState.new(2)
	check(catalog.apply_to_player(state, catalog.default_champion_id), "initial champion profile applies")
	state.health = state.health_maximum / 2
	state.flux = state.flux_maximum / 3
	state.stamina = state.stamina_maximum / 4
	state.health_recovery_remainder = 7
	state.flux_recovery_remainder = 13
	state.stamina_remainder = 29
	state.health_recovery_delay_ticks = 11
	state.flux_recovery_delay_ticks = 17
	state.stamina_recovery_delay_ticks = 19
	state.flux_recovery_idle_ticks = 23
	state.stamina_recovery_idle_ticks = 31
	state.primary_cooldown_ticks = 37
	state.active_1_cooldown_ticks = 41
	state.active_2_cooldown_ticks = 43
	state.hop_cooldown_ticks = 47
	state.movement_chain_count = 2
	check(state.place_proven_spell(11, CombatTuning.CINDERBOLT_WIRE_ID), "custom weave is present before no-op selection")
	state.spell_cooldown_ticks[11] = 53
	state.last_event = "unchanged_attunement_fixture"
	var before := state.canonical_values()
	for _repeat: int in range(4):
		equal(Attunement.apply(catalog, state, state.champion_wire_id), Attunement.UNCHANGED, "same champion is an explicit no-op")
		equal(state.canonical_values(), before, "same-ID selection preserves all canonical resources, weave, cooldowns and fractional recovery clocks")
		equal(state.last_event, "unchanged_attunement_fixture", "same-ID selection preserves semantic event")
	for wire: int in [0, -1, 4096, 4097]:
		equal(Attunement.apply(catalog, state, wire), Attunement.REFUSED, "unregistered/out-of-range champion cannot fall back to a default")
		equal(state.canonical_values(), before, "refused identity is mutation-free")
	var next_id := catalog.next_champion_id(catalog.default_champion_id)
	var next_wire := int(catalog.champions_by_id[next_id]["wire_id"])
	state.spawn_protection_ticks = 1
	var protected_before := state.canonical_values()
	equal(Attunement.apply(catalog, state, next_wire), Attunement.REFUSED, "direct helper cannot bypass actor safety")
	equal(state.canonical_values(), protected_before, "unsafe attunement is mutation-free")
	state.spawn_protection_ticks = 0
	var old_health_max := state.health_maximum
	var old_flux_max := state.flux_maximum
	var old_stamina_max := state.stamina_maximum
	var old_resources := Vector3i(state.health, state.flux, state.stamina)
	var old_position := Vector2i(state.position_x, state.position_y)
	equal(Attunement.apply(catalog, state, next_wire), Attunement.CHANGED, "different validated champion applies once")
	equal(state.champion_wire_id, next_wire, "exact requested champion becomes authoritative")
	equal(state.health, old_resources.x * state.health_maximum / old_health_max, "changed champion preserves health ratio")
	equal(state.flux, old_resources.y * state.flux_maximum / old_flux_max, "changed champion preserves Flux ratio")
	equal(state.stamina, old_resources.z * state.stamina_maximum / old_stamina_max, "changed champion preserves Stamina ratio")
	equal(Vector2i(state.position_x, state.position_y), old_position, "attunement does not teleport actor")
	check(state.has_valid_spell_slots(), "new champion receives a validated default weave")
	var changed_before := state.canonical_values()
	equal(Attunement.apply(catalog, state, next_wire), Attunement.UNCHANGED, "second exact request acknowledges current champion")
	equal(state.canonical_values(), changed_before, "repeated application remains byte-stable")

func _place_at(state: PlayerState, layout: SanctumCampusLayout, station_id: String) -> void:
	var point := SanctumCampusLayout._parse_point(layout.stations_by_id[station_id]["position"]) * SimConfig.FIXED_SCALE
	state.position_x = point.x
	state.position_y = point.y
