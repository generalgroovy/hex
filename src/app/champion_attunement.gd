class_name ChampionAttunement
extends RefCounted


const REFUSED: int = -1
const UNCHANGED: int = 0
const CHANGED: int = 1


# Location and round authority belong to SessionRequestPolicy. This shared
# application boundary also refuses active/dead actors and unknown catalog IDs.
static func apply(catalog: ChampionCatalog, state: PlayerState, champion_wire_id: int) -> int:
	if catalog == null or not is_available(state) or champion_wire_id < 1 or champion_wire_id > 4096:
		return REFUSED
	var champion_id := catalog.champion_id_from_wire(champion_wire_id)
	if champion_id.is_empty():
		return REFUSED
	# Do not call the profile initializer on a no-op: it resets weave, cooldowns,
	# recovery clocks and fractional resource accounting even in ratio mode.
	if state.champion_wire_id == champion_wire_id:
		return UNCHANGED
	return CHANGED if catalog.apply_to_player(state, champion_id, true) else REFUSED


static func is_available(state: PlayerState) -> bool:
	if state == null or state.actor_kind != PlayerState.ActorKind.CHAMPION or state.health <= 0:
		return false
	if state.is_airborne() or state.air_vertical_velocity != 0 or state.air_floating:
		return false
	if state.control_state != PlayerState.ControlState.FREE or state.control_ticks > 0:
		return false
	if state.pending_cast_wire_id != 0:
		return false
	# Timers, not presentation mode labels, determine whether an action is live.
	# Ground walking/sprinting and passive cooldowns remain usable at the Loom.
	for ticks: int in [state.pending_cast_ticks, state.cast_recovery_ticks,
		state.movement_commitment_ticks, state.hop_ticks, state.air_dodge_ticks,
		state.slide_ticks, state.wave_dash_ticks, state.vault_ticks,
		state.superglide_ticks, state.wall_skim_ticks, state.impact_recovery_ticks,
		state.jump_protection_ticks, state.spawn_protection_ticks]:
		if ticks > 0:
			return false
	return true
