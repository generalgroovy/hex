class_name SessionRequestPolicy
extends RefCounted


const Attunement = preload("res://src/app/champion_attunement.gd")
const ACCEPTED: int = 0
const REFUSED_COOLDOWN: int = 1
const REFUSED_DISTANCE: int = 2
const REFUSED_UNAVAILABLE: int = 3


static func validate(
	action: int,
	state: PlayerState,
	stations_by_id: Dictionary[String, Dictionary],
	world_tick: int,
	emote_ready_tick: int,
	round_phase: int = SessionRound.Phase.HEARTH,
) -> int:
	if state == null or state.actor_kind != PlayerState.ActorKind.CHAMPION or world_tick < 0:
		return REFUSED_UNAVAILABLE
	if round_phase != SessionRound.Phase.HEARTH and action != SessionTransport.REQUEST_EMOTE:
		return REFUSED_UNAVAILABLE
	match action:
		SessionTransport.REQUEST_EMOTE:
			return ACCEPTED if world_tick >= emote_ready_tick else REFUSED_COOLDOWN
		SessionTransport.REQUEST_TRAINING_RESET:
			return ACCEPTED if _at_station(state, stations_by_id, "training-reset") else REFUSED_DISTANCE
		SessionTransport.REQUEST_CHAMPION_NEXT, SessionTransport.REQUEST_CHAMPION_SELECT:
			if not Attunement.is_available(state):
				return REFUSED_UNAVAILABLE
			return ACCEPTED if _at_station(state, stations_by_id, "champion-loom") else REFUSED_DISTANCE
		SessionTransport.REQUEST_WEAVE_APPLY:
			if not Attunement.is_available(state): return REFUSED_UNAVAILABLE
			return ACCEPTED if (_at_station(state, stations_by_id, "spell-loom") or _at_station(state, stations_by_id, "champion-loom")) else REFUSED_DISTANCE
		SessionTransport.REQUEST_SPELL_EQUIP:
			return ACCEPTED if _at_station(state, stations_by_id, "spell-loom") else REFUSED_DISTANCE
		SessionTransport.REQUEST_IMPACT_PRACTICE:
			if state.control_state != PlayerState.ControlState.FREE or state.impact_recovery_ticks > 0:
				return REFUSED_UNAVAILABLE
			return ACCEPTED if _at_station(state, stations_by_id, "momentum-chime") else REFUSED_DISTANCE
		SessionTransport.REQUEST_READY_TOGGLE, SessionTransport.REQUEST_PRACTICE_START:
			return ACCEPTED if _at_station(state, stations_by_id, "session-hearth") else REFUSED_DISTANCE
	return REFUSED_UNAVAILABLE


static func _at_station(state: PlayerState, stations: Dictionary, station_id: String) -> bool:
	return SanctumStationModel.station_in_reach(stations, station_id, Vector2i(state.position_x, state.position_y))
