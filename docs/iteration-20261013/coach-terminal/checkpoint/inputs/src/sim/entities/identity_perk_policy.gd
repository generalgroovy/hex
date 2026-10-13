extends RefCounted
## Stateless identity rules. Only existing authoritative actor state selects a
## window; there is no hidden cooldown, random roll, free payload or UI authority.
@warning_ignore_start("integer_division")

const Races = preload("res://src/content/race_perk_catalog.gd")
const Characters = preload("res://src/content/character_perk_catalog.gd")
const EFFECTS := ["ground_speed_ratio", "ground_acceleration_ratio", "ground_braking_ratio", "air_steering_ratio", "incoming_damage_ratio", "knockback_ratio", "health_recovery_ratio", "flux_recovery_ratio", "stamina_recovery_ratio", "movement_cost_ratio", "spell_startup_ratio", "spell_cooldown_ratio"]
const MIN_RATIO := 750
const MAX_RATIO := 1350


static func describe(champion_wire_id: int) -> Dictionary:
	return {"race": Races.definition(Races.ancestry_for_wire(champion_wire_id)).duplicate(true),
		"character": Characters.definition(champion_wire_id).duplicate(true)}


static func ratio(state: PlayerState, effect: String) -> int:
	if state == null or state.champion_wire_id <= 0 or state.health <= 0 or state.actor_kind != PlayerState.ActorKind.CHAMPION:
		return 1000
	var value := 1000
	var race: Dictionary = Races.raw_definition(Races.ancestry_for_wire(state.champion_wire_id))
	var character: Dictionary = Characters.raw_definition(state.champion_wire_id)
	for row: Dictionary in [race, character]:
		var effects: Dictionary = row.get("effects", {})
		if effects.has(effect) and condition_matches(state, String(row.get("condition", ""))):
			value = value * int(effects[effect]) / 1000
	return clampi(value, MIN_RATIO, MAX_RATIO)


static func scale(state: PlayerState, effect: String, amount: int) -> int:
	if amount <= 0:
		return amount
	# Positive admission costs and damage never round to free or immune.
	return maxi(1, amount * ratio(state, effect) / 1000)


static func spell_timing(state: PlayerState, definition: Dictionary, config: SimConfig, status_startup_ratio: int = 1000) -> Dictionary:
	# A paired timing bargain must change both actual timers. In particular a
	# one-tick Rapid cannot buy faster startup by accepting a real repeat penalty.
	# Process ancestry then character, preserving the ordinary stacking order.
	# This is a current-window projection: admission and release call it separately.
	var startup_ms := int(definition.get("startup_ms", 0))
	var cooldown_ms := int(definition.get("cooldown_ms", 0))
	var startup_ratio := 1000
	var cooldown_ratio := 1000
	var suppressed: Array[String] = []
	if state != null and state.champion_wire_id > 0 and state.health > 0 and state.actor_kind == PlayerState.ActorKind.CHAMPION:
		for row: Dictionary in [Races.raw_definition(Races.ancestry_for_wire(state.champion_wire_id)), Characters.raw_definition(state.champion_wire_id)]:
			if not condition_matches(state, String(row.get("condition", ""))): continue
			var effects: Dictionary = row.get("effects", {})
			var startup_factor := int(effects.get("spell_startup_ratio", 1000))
			var cooldown_factor := int(effects.get("spell_cooldown_ratio", 1000))
			var next_startup := clampi(startup_ratio * startup_factor / 1000, MIN_RATIO, MAX_RATIO)
			var next_cooldown := clampi(cooldown_ratio * cooldown_factor / 1000, MIN_RATIO, MAX_RATIO)
			if startup_factor != 1000 and cooldown_factor != 1000:
				var startup_changes := _timer_changes(startup_ms, startup_ratio, next_startup, startup_factor, config, status_startup_ratio)
				var cooldown_changes := _timer_changes(cooldown_ms, cooldown_ratio, next_cooldown, cooldown_factor, config)
				if not startup_changes or not cooldown_changes:
					suppressed.append(String(row.get("name", "Timing perk")))
					continue
			startup_ratio = next_startup
			cooldown_ratio = next_cooldown
	return {"startup_ratio": startup_ratio, "cooldown_ratio": cooldown_ratio,
		"base_startup_ticks": _timing_ticks(startup_ms, 1000, config, status_startup_ratio),
		"base_cooldown_ticks": _timing_ticks(cooldown_ms, 1000, config),
		"startup_ticks": _timing_ticks(startup_ms, startup_ratio, config, status_startup_ratio),
		"cooldown_ticks": _timing_ticks(cooldown_ms, cooldown_ratio, config),
		"suppressed_pairs": suppressed}


static func _timer_changes(milliseconds: int, before_ratio: int, after_ratio: int, factor: int, config: SimConfig, status_ratio: int = 1000) -> bool:
	var before := _timing_ticks(milliseconds, before_ratio, config, status_ratio)
	var after := _timing_ticks(milliseconds, after_ratio, config, status_ratio)
	return after < before if factor < 1000 else after > before


static func _timing_ticks(milliseconds: int, timing_ratio: int, config: SimConfig, status_ratio: int = 1000) -> int:
	if milliseconds <= 0 or config == null: return 0
	var scaled_ms := maxi(1, milliseconds * timing_ratio / 1000)
	scaled_ms = maxi(1, scaled_ms * status_ratio / 1000)
	return config.milliseconds_to_ticks(scaled_ms)


static func active_rows(state: PlayerState) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if state == null or state.health <= 0 or state.actor_kind != PlayerState.ActorKind.CHAMPION:
		return rows
	var descriptions := describe(state.champion_wire_id)
	for key: String in ["race", "character"]:
		var row: Dictionary = descriptions[key]
		if not row.is_empty() and condition_matches(state, String(row.condition)):
			rows.append(row)
	return rows


static func condition_matches(state: PlayerState, condition: String) -> bool:
	if state == null or condition.is_empty():
		return false
	for token: String in condition.split("&"):
		if not _matches(state, token):
			return false
	return true


static func _matches(state: PlayerState, token: String) -> bool:
	var grounded := not state.is_airborne() and state.air_height == 0
	var moving := state.velocity_x != 0 or state.velocity_y != 0
	var ordinary := grounded and state.control_state in [PlayerState.ControlState.FREE, PlayerState.ControlState.SLOWED] and state.impact_recovery_ticks == 0 and state.air_dodge_ticks == 0 and state.wave_dash_ticks == 0 and state.vault_ticks == 0 and state.superglide_ticks == 0 and state.slide_ticks == 0 and not state.jumpsquat_active
	match token:
		"grounded": return grounded
		"grounded_walking": return ordinary and moving and not state.sprinting and not state.crouching
		"grounded_crouching": return grounded and state.crouching
		"stationary_grounded": return ordinary and not moving and not state.crouching
		"retreating_grounded": return ordinary and moving and not state.sprinting and not state.crouching and state.velocity_x * state.aim_x + state.velocity_y * state.aim_y < 0
		"low_health": return state.health > 0 and state.health * 3 <= state.health_maximum
		"high_health": return state.health * 4 >= state.health_maximum * 3
		"low_flux": return state.flux * 3 <= state.flux_maximum
		"high_flux": return state.flux * 3 >= state.flux_maximum * 2
		"low_stamina": return state.stamina * 3 <= state.stamina_maximum
		"high_stamina": return state.stamina * 3 >= state.stamina_maximum * 2
		"pending_cast": return state.pending_cast_wire_id > 0 and state.pending_cast_ticks > 0
		"cast_recovery": return state.cast_recovery_ticks > 0
		"sprinting": return grounded and state.sprinting
		"sliding": return grounded and state.slide_ticks > 0
		"jumpsquat": return grounded and state.jumpsquat_active
		"airborne_rising": return state.is_airborne() and state.air_vertical_velocity > 0
		"airborne_descending": return state.is_airborne() and state.air_vertical_velocity < 0
		"airborne_spent_dodge": return state.is_airborne() and state.air_dodge_used and state.air_dodge_ticks <= 0
		"flight_active": return state.is_airborne() and state.flight_capable and state.air_floating and state.float_ticks > 0
		"wallrunning": return state.is_airborne() and state.wall_skim_ticks > 0
		"landing": return grounded and state.landing_ticks > 0
		"slowed": return (state.control_state == PlayerState.ControlState.SLOWED and state.control_ticks > 0 and state.slow_ratio < 1000) or SpellStatusPolicy.movement_ratio(state) < 1000
		"impact_recovery": return state.impact_recovery_ticks > 0
	return false
