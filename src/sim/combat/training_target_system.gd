class_name TrainingTargetSystem
extends RefCounted


const RESPAWN_DELAY_MS: int = 3000
const RESPAWN_PROTECTION_MS: int = 250
const DOWN_EVENT: String = "training_target_down"
const RESPAWN_EVENT: String = "training_target_respawned"


# Called once after combat resolution, in stable actor order. Lifecycle lives on
# PlayerState so replay, hashing, late join and presentation see the same timer.
# The first observation of a defeat arms the timer; exactly delay_ticks later
# the same actor returns. This helper never advances living actors or champions.
static func step_target(state: PlayerState, config: SimConfig) -> String:
	if state == null or config == null or not config.is_valid() or state.actor_kind != PlayerState.ActorKind.TRAINING_TARGET:
		return ""
	if state.health > 0:
		state.training_respawn_ticks = 0
		return ""
	state.health = 0
	var delay_ticks := config.milliseconds_to_ticks(RESPAWN_DELAY_MS)
	if state.training_respawn_ticks <= 0:
		state.training_respawn_ticks = delay_ticks
		state.spawn_protection_ticks = 0
		state.last_event = DOWN_EVENT
		return DOWN_EVENT
	state.training_respawn_ticks = mini(state.training_respawn_ticks, delay_ticks) - 1
	if state.training_respawn_ticks > 0:
		return ""
	# reset_for_spawn clears transient casts/control/motion while retaining the
	# authored target identity, radius, health maximum and zero resource profile.
	state.reset_for_spawn(
		Vector2i(state.training_spawn_x, state.training_spawn_y),
		config.milliseconds_to_ticks(RESPAWN_PROTECTION_MS),
	)
	state.training_respawn_ticks = 0
	state.movement_mode = PlayerState.MovementMode.IDLE
	state.last_event = RESPAWN_EVENT
	return RESPAWN_EVENT
