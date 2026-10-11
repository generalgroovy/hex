extends "res://tests/support/chemistry_coach_harness.gd"
@warning_ignore_start("integer_division")


func configure_trial_fixture(render: bool = false) -> bool:
	if not configure_fixture(render): return false
	material_registry = MaterialRegistry.new()
	material_yard = MaterialYardDefinition.new()
	if not material_registry.load_from_file(MATERIAL_CATALOG_PATH) or not material_yard.load_from_file(MATERIAL_YARD_PATH, material_registry): return false
	input_router = InputRouter.new(1)
	InputRouter.ensure_input_map()
	# Use in-memory weave configuration; never read or write the user's library.
	character_weaves.champions = champion_catalog
	character_weaves.abilities = ability_catalog
	return true


func _refresh_material_preview() -> void:
	pass # Unrelated diagnostic texture is not needed by the trial.


func step_trial(player_command: SimCommand) -> bool:
	if _solo_trial_frozen() or not interception_practice_active: return false
	var enemy := _solo_rival_command()
	if enemy == null or not world.step([player_command, enemy]): return false
	solo_trial.observe(world)
	current_position = _player_position()
	previous_position = current_position
	actor_motion_history.capture(world.players)
	return true


# Ordinary counterplay: circle the advertised pressure, then spend Fire Bolts
# during the stationary opening. No health, cooldown or resource injection.
static func attacking_command(trial_world: SimWorld, ready: bool = false) -> SimCommand:
	var player := trial_world.player(1)
	var opponent := trial_world.player(2)
	var delta := Vector2i(opponent.position_x - player.position_x, opponent.position_y - player.position_y)
	if ready: return SimCommand.new(trial_world.tick, 1, 0, 0, 0, 0, delta.x, delta.y)
	var status: Dictionary = preload("res://src/app/solo_duel_rival.gd").status(trial_world.tick, 0)
	var phase := String(status.get("phase", "ready"))
	var distance := int(delta.length())
	var toward := SimCommand._normalized_direction(delta.x, delta.y)
	var movement := Vector2i.ZERO
	if distance > 150000: movement = toward
	elif distance < 100000: movement = -toward
	if phase in ["windup", "pressure"]:
		movement += Vector2i(-toward.y, toward.x)
	# Reviewed actual court; steering is a normal directional command, not a
	# position clamp. Leave room for ordinary momentum and the body radius.
	var position := Vector2i(player.position_x, player.position_y)
	var target_step := position + movement * 120
	target_step.x = clampi(target_step.x, 2232000, 2856000)
	target_step.y = clampi(target_step.y, 960000, 1464000)
	var step_delta := target_step - position
	movement = Vector2i.ZERO if step_delta == Vector2i.ZERO else SimCommand._normalized_direction(step_delta.x, step_delta.y)
	var held := SimCommand.HELD_SPRINT if movement != Vector2i.ZERO and distance > 160000 else 0
	held |= SimCommand.SPELL_HELD_BITS[2]
	# Repeat ordinary charge/release jumps and one later aerial input. This is
	# reachable player input, not a grant of height, protection or Stamina.
	var jump_cycle := posmod(trial_world.tick - 480, 120)
	var pressed := 0
	if jump_cycle < 24: held |= SimCommand.HELD_JUMP
	if jump_cycle == 0 or jump_cycle == 62: pressed |= SimCommand.PRESSED_JUMP
	# Approximate projectile travel plus startup from observable current state.
	# No projectile inspection, future rival inputs, or authority edits.
	var lead_ms := clampi(distance * 1000 / 345600 + 55, 55, 450)
	var target := Vector2i(opponent.position_x, opponent.position_y) + Vector2i(opponent.velocity_x, opponent.velocity_y) * lead_ms / 1000
	var aim := target - Vector2i(player.position_x, player.position_y)
	return SimCommand.new(trial_world.tick, 1, movement.x, movement.y, held, pressed, aim.x, aim.y, target.x, target.y)
