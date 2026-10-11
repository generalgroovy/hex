extends SceneTree

# Diagnostic-only wrappers; production source and personal saves remain intact.
const Mixtures = preload("res://src/content/mixture_catalog.gd")

class TimedGarden:
	extends "res://src/presentation/element_garden_presenter.gd"
	var skip_draw := false
	var samples: Array[float] = []
	func draw_ground(canvas: CanvasItem, entries: Array[Dictionary], reduced: bool) -> void:
		var started := Time.get_ticks_usec()
		if not skip_draw: super.draw_ground(canvas, entries, reduced)
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)

class TimedGame:
	extends "res://src/app/bootstrap.gd"
	var process_samples: Array[float] = []
	var draw_samples: Array[float] = []
	var garden_step_samples: Array[float] = []
	var frame_samples: Array[float] = []
	var previous_usec := 0
	var skip_garden_step := false
	var casting := false
	var next_cast_tick := 0
	var attempts := 0
	var max_projectiles := 0
	var max_paid_cells := 0
	func _process(delta: float) -> void:
		var started := Time.get_ticks_usec()
		if previous_usec > 0: frame_samples.append(float(started - previous_usec) / 1000.0)
		previous_usec = started
		application_input_active = true
		super._process(delta)
		process_samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
		if world != null:
			max_projectiles = maxi(max_projectiles, world.projectiles.size())
			max_paid_cells = maxi(max_paid_cells, world.hex_court.occupied_cells().size())
	func _draw() -> void:
		var started := Time.get_ticks_usec()
		super._draw()
		draw_samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	func _update_element_garden() -> void:
		var started := Time.get_ticks_usec()
		if not skip_garden_step: super._update_element_garden()
		garden_step_samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	func _sample_gameplay_command(tick: int, _position: Vector2, _pointer: Vector2, _blocking: bool) -> SimCommand:
		var pressed := 0
		if casting and tick >= next_cast_tick:
			pressed = SimCommand.SPELL_PRESSED_BITS[0]
			next_cast_tick = tick + 120
			attempts += 1
		return SimCommand.new(tick, input_router.entity_id, 0, 0, 0, pressed, 1000, 0)
	func reset_samples() -> void:
		process_samples.clear()
		draw_samples.clear()
		garden_step_samples.clear()
		frame_samples.clear()
		previous_usec = 0
		attempts = 0
		max_projectiles = 0
		max_paid_cells = 0

var game: TimedGame
var garden: TimedGarden
var results: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.mode = Window.MODE_WINDOWED
	root.visible = true
	var instance: Node = load("res://scenes/bootstrap/bootstrap.tscn").instantiate()
	instance.set_script(TimedGame)
	game = instance
	garden = TimedGarden.new()
	game.element_garden_presenter = garden
	root.add_child(game)
	await _wait_seconds(4.0)
	var startup := {"process_ms": _stats(game.process_samples), "draw_ms": _stats(game.draw_samples)}
	await _measure("hearth_idle", 12.0)
	var travel_ok: bool = game.local_navigation.travel("element-garden")
	print("GARDEN_TRAVEL ", travel_ok)
	await _wait_seconds(4.0)
	await _measure("garden_entry", 12.0)
	var plot_rows: Array[Dictionary] = game.element_garden.plots()
	var center := Vector2.ZERO
	for row: Dictionary in plot_rows: center += Vector2(row.center)
	center /= float(plot_rows.size())
	_place(center)
	await _wait_seconds(4.0)
	await _measure("garden_middle", 12.0)
	game.requested_capture_reduced_effects = true
	await _wait_seconds(2.0)
	await _measure("garden_middle_reduced", 12.0)
	game.requested_capture_reduced_effects = false
	garden.skip_draw = true
	await _wait_seconds(2.0)
	await _measure("diagnostic_garden_ground_not_drawn", 12.0)
	game.skip_garden_step = true
	await _wait_seconds(2.0)
	await _measure("diagnostic_garden_ground_and_sim_skipped", 12.0)
	game.skip_garden_step = false
	garden.skip_draw = false
	_place(Vector2(3072, 2688))
	await _wait_seconds(4.0)
	var actor: PlayerState = game._local_player_state()
	assert(actor.place_proven_spell(0, Mixtures.wire_for(2, "bolt")))
	game.casting = true
	game.next_cast_tick = game.world.tick
	await _measure("paid_fire_bolt_every_120_ticks", 16.0)
	game.casting = false
	await _wait_seconds(4.0)
	assert(actor.place_proven_spell(0, Mixtures.wire_for(63, "mantle")))
	game.casting = true
	game.next_cast_tick = game.world.tick
	await _measure("paid_all_six_mantle_every_120_ticks", 16.0)
	game.casting = false
	var output := {"schema": "hex-performance-assessment-v1", "scope": "Native current source, instrumented debug runtime, ordinary main loop. Diagnostic comparisons, not portable release certification or GPU timing. Isolated saves; fixtures equip slot and position only; casts use ordinary paid SimCommand. Frame samples are process start intervals, not physical presentation or input latency.", "window": root.size, "display": DisplayServer.get_name(), "startup": startup, "results": results}
	var file := FileAccess.open("res://.godot/performance-assessment-20261010.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	file.close()
	print("ASSESSMENT_COMPLETE ", JSON.stringify(output))
	game.queue_free()
	await process_frame
	quit(0)

func _place(point: Vector2) -> void:
	var actor: PlayerState = game._local_player_state()
	actor.position_x = roundi(point.x * 1000.0)
	actor.position_y = roundi(point.y * 1000.0)
	actor.velocity_x = 0
	actor.velocity_y = 0
	game.current_position = point
	game.previous_position = point
	game.accumulator_seconds = 0.0
	game._reset_motion_history()
	game.player_camera.clear()

func _wait_seconds(seconds: float) -> void:
	var started := Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - started) / 1000000.0 < seconds: await process_frame

func _measure(label: String, seconds: float) -> void:
	game.reset_samples()
	garden.samples.clear()
	var tick_before: int = game.world.tick
	var paid_before := int(game.world.hex_court.metrics.matter_paid)
	var dropped_before: float = game.dropped_time_seconds
	var started := Time.get_ticks_usec()
	await _wait_seconds(seconds)
	var elapsed := float(Time.get_ticks_usec() - started) / 1000000.0
	var row := {"label": label, "wall_seconds": elapsed, "frame_interval_ms": _stats(game.frame_samples), "process_cpu_ms": _stats(game.process_samples), "draw_command_cpu_ms": _stats(game.draw_samples), "garden_draw_cpu_ms": _stats(garden.samples), "garden_step_cpu_ms": _stats(game.garden_step_samples), "ticks_per_wall_second": float(game.world.tick - tick_before) / elapsed, "dropped_accumulator_seconds": game.dropped_time_seconds - dropped_before, "resident_plots": game.element_garden._resident.size(), "cast_attempts": game.attempts, "matter_paid_delta": int(game.world.hex_court.metrics.matter_paid) - paid_before, "max_projectiles": game.max_projectiles, "max_paid_cells": game.max_paid_cells, "draw_calls_last": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives_last": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "texture_memory_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED), "window_focus": root.has_focus()}
	results.append(row)
	print("ASSESSMENT_CASE ", JSON.stringify(row))
	var file := FileAccess.open("res://.godot/performance-assessment-20261010-partial.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))

func _stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {"n": 0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	var over33 := 0
	for value: float in values:
		total += value
		if value > 33.333: over33 += 1
	return {"n": values.size(), "mean": total / values.size(), "p50": sorted[int((sorted.size() - 1) * 0.5)], "p95": sorted[int((sorted.size() - 1) * 0.95)], "p99": sorted[int((sorted.size() - 1) * 0.99)], "max": sorted[-1], "over_33ms": over33}
