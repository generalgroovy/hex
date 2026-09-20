extends "res://tests/support/chemistry_coach_harness.gd"


const FIXTURE_CENTER := HexCourt.ORIGIN
const TARGET_ID := 2
const TARGET_CHAMPION := "oh_tipi"

var last_step_events: Array[Dictionary] = []
var event_history: Array[Dictionary] = []
var last_error: String = ""


func reset_melee_fixture(champion_id: String, aim: Vector2i, attack_kind: int, target_in_range: bool = true) -> bool:
	last_error = ""
	last_step_events.clear()
	event_history.clear()
	selected_champion_id = champion_id
	if aim == Vector2i.ZERO or attack_kind not in [PhysicalAttackSystem.Kind.PUNCH, PhysicalAttackSystem.Kind.KICK]:
		return _fail_fixture("invalid melee fixture request")
	if not _start_hex_court():
		return _fail_fixture("Hex Court reset failed")
	controls_input_guard_frames = 0
	var actor: PlayerState = world.player(1)
	if actor == null:
		return _fail_fixture("local actor missing after Hex Court reset")
	var profile: Dictionary = PhysicalAttackTuning.shared().profile(attack_kind)
	if profile.is_empty():
		return _fail_fixture("physical attack profile missing")

	actor.reset_for_spawn(FIXTURE_CENTER, 0)
	actor.team_id = 1
	actor.aim_x = aim.x
	actor.aim_y = aim.y
	actor.facing_x = aim.x
	actor.facing_y = aim.y
	actor.health_recovery_per_second = 0
	actor.flux_recovery_per_second = 0
	actor.stamina_recovery_per_second = 0

	var target: PlayerState = PlayerState.new(TARGET_ID)
	if not champion_catalog.apply_to_player(target, TARGET_CHAMPION):
		return _fail_fixture("target champion could not be applied")
	var contact_limit: int = int(profile.reach) + int(target.radius)
	var distance: int = maxi(1, int(profile.reach) - 6000) if target_in_range else contact_limit + 72_000
	var target_position: Vector2i = FIXTURE_CENTER + _scaled_direction(aim, distance)
	target.reset_for_spawn(target_position, 0)
	target.team_id = 2
	target.aim_x = -aim.x
	target.aim_y = -aim.y
	target.facing_x = -aim.x
	target.facing_y = -aim.y
	target.health_recovery_per_second = 0
	target.flux_recovery_per_second = 0
	target.stamina_recovery_per_second = 0
	if not world.collision.can_occupy(FIXTURE_CENTER, MovementTuning.PLAYER_RADIUS) \
			or not world.collision.can_occupy(target_position, MovementTuning.PLAYER_RADIUS):
		return _fail_fixture("melee fixture lacks common wall clearance")
	var fighters: Array[PlayerState] = [actor, target]
	world.players = fighters
	world.projectiles.clear()
	world.fields.clear()
	world.deposits.clear()
	world.reactions.clear()
	session_names_by_entity = {1: champion_id, TARGET_ID: "melee target"}
	current_position = _player_position()
	previous_position = current_position
	previous_air_height = actor.air_height
	_reset_motion_history()
	return world.is_valid() and world.hex_court != null and world.hex_court.conservation_valid()


func reset_infusion_fixture() -> bool:
	if not reset_melee_fixture("oh_tipi", Vector2i(1000, 0), PhysicalAttackSystem.Kind.KICK, true):
		return false
	var actor: PlayerState = world.player(1)
	var target: PlayerState = world.player(TARGET_ID)
	# This paid Kick begins 50 px from the target. The 30 px authored push moves
	# the target across the center hex boundary so the deposit can prove it used
	# the captured pre-push point rather than the mutated target position.
	actor.reset_for_spawn(FIXTURE_CENTER + Vector2i(-20_000, 0), 0)
	target.reset_for_spawn(FIXTURE_CENTER + Vector2i(30_000, 0), 0)
	actor.team_id = 1
	target.team_id = 2
	actor.aim_x = 1000
	actor.aim_y = 0
	actor.facing_x = 1000
	actor.facing_y = 0
	actor.health_recovery_per_second = 0
	actor.flux_recovery_per_second = 0
	actor.stamina_recovery_per_second = 0
	target.health_recovery_per_second = 0
	target.flux_recovery_per_second = 0
	target.stamina_recovery_per_second = 0
	current_position = _player_position()
	previous_position = current_position
	previous_air_height = 0
	_reset_motion_history()
	return true


func begin_physical(attack_kind: int, aim: Vector2i, extra_pressed: int = 0) -> bool:
	var bit: int = SimCommand.PRESSED_PUNCH if attack_kind == PhysicalAttackSystem.Kind.PUNCH else SimCommand.PRESSED_KICK
	return step_authority(bit | extra_pressed, aim)


func jump(aim: Vector2i) -> bool:
	return step_authority(SimCommand.PRESSED_JUMP, aim, SimCommand.HELD_JUMP)


func step_authority(pressed: int = 0, aim: Vector2i = Vector2i(1000, 0), held: int = 0, move: Vector2i = Vector2i.ZERO) -> bool:
	var actor: PlayerState = world.player(1)
	if actor == null:
		return _fail_fixture("local actor missing before authority step")
	var command: SimCommand = SimCommand.new(world.tick, actor.entity_id, move.x, move.y, held, pressed, aim.x, aim.y)
	if not world.step([command]):
		return _fail_fixture("world step failed: " + world.last_error)
	last_step_events.clear()
	for event: Dictionary in world.combat_events:
		last_step_events.append(event.duplicate(true))
		event_history.append(event.duplicate(true))
	if world.hex_court != null and not world.hex_court.conservation_valid():
		return _fail_fixture("Hex Court conservation failed")
	_sync_capture_state()
	return true


func advance_to_phase(phase: int, aim: Vector2i, maximum_ticks: int = 96) -> bool:
	for _index: int in range(maximum_ticks + 1):
		var actor: PlayerState = world.player(1)
		if actor != null and actor.physical_phase == phase:
			return true
		if not step_authority(0, aim):
			return false
	return _fail_fixture("physical phase %d was not reached" % phase)


func event_of_type(kind: String, history: bool = true) -> Dictionary:
	var source: Array[Dictionary] = event_history if history else last_step_events
	for index: int in range(source.size() - 1, -1, -1):
		if String(source[index].get("type", "")) == kind:
			return source[index].duplicate(true)
	return {}


func movement_frame(reduced: bool = false) -> Dictionary:
	var actor: PlayerState = world.player(1)
	if actor == null or cartoon_champion_presenter == null:
		return {}
	return cartoon_champion_presenter.movement_frame(
		selected_champion_id,
		actor,
		float(world.tick),
		world.config,
		reduced,
		0.0,
	)


func _sync_capture_state() -> void:
	previous_position = _player_position()
	current_position = previous_position
	var actor: PlayerState = world.player(1)
	previous_air_height = actor.air_height if actor != null else 0
	actor_motion_history.capture(world.players)
	_update_combat_cues(1.0 / 120.0)
	_ingest_combat_cues(world.combat_events)


static func _scaled_direction(direction: Vector2i, distance: int) -> Vector2i:
	return Vector2i(
		int(round(float(direction.x) * float(distance) / 1000.0)),
		int(round(float(direction.y) * float(distance) / 1000.0)),
	)


func _fail_fixture(message: String) -> bool:
	last_error = message
	return false
