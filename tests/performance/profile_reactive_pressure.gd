extends "res://tests/performance/profile_fine_grid_steps.gd"
## Real paid eight-player rapid bursts followed by Heavy/Spray/Bolt choices.
## No resource, capacity, cooldown, lifespan or movement overrides.

func _commands(world: SimWorld, targets: Dictionary, _case_name: String, active: bool, reverse_order: bool) -> Array[SimCommand]:
	var commands: Array[SimCommand] = []
	var phase := posmod(world.tick - WARMUP_TICKS, 480)
	for actor: PlayerState in world.players:
		var held := SimCommand.SPELL_HELD_BITS[3] if active and phase < 240 else 0
		var pressed := 0
		if active:
			if phase == 240: pressed = SimCommand.SPELL_PRESSED_BITS[1]
			elif phase == 300: pressed = SimCommand.SPELL_PRESSED_BITS[2]
			elif phase == 360: pressed = SimCommand.SPELL_PRESSED_BITS[0]
		var target: Vector2i = targets[actor.entity_id]
		var aim := target - Vector2i(actor.position_x, actor.position_y)
		commands.append(SimCommand.new(world.tick, actor.entity_id, 0, 0, held, pressed, aim.x, aim.y, target.x, target.y))
	if reverse_order: commands.reverse()
	return commands

func _workload_description() -> String:
	return "Eight real champions: 240 ticks held Rapid, Heavy at240, Spray at300, Bolt at360; 480-tick cycle. 720 measured ticks, original and reversed command order; no caps/resources bypassed. No rendered/network/128-projectile capacity claim."
