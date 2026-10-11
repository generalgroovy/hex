extends "res://tests/performance/profile_unified_wellspring.gd"
@warning_ignore_start("integer_division")

const TimedHarness = preload("res://tests/support/hex_draw_component_harness.gd")
const CoachHarness = preload("res://tests/support/chemistry_coach_harness.gd")
const COMPONENTS: Array[String] = ["campus", "hex_ground", "actor_bodies", "hud", "pov_mask", "projectiles", "combat_cues", "legacy_chemistry"]
const REPETITIONS := 32
const ACTIVE_TICKS := 40
const PIXEL_WARMUP := 4

class ControlHarness extends CoachHarness:
	var draw_invocations := 0
	func _draw() -> void:
		super._draw()
		draw_invocations += 1

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	_check(output_path.begins_with("res://.godot/hex-draw-components-") and output_path.ends_with(".json") and not ".." in output_path and not FileAccess.file_exists(output_path), "fresh scoped component receipt")
	_check(DisplayServer.get_name() != "headless", "native display required")
	_check(root.get_visible_rect().size == Vector2(1280, 720), "native 1280x720 viewport")
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production abilities")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "production champions")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "production campus")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null and definition.eligible_cells.size() == 11337 and HexGrid.HALF_WIDTH == 12000, "current symbol-sized 24px campus has 11337 cells")
	if failures > 0:
		quit(1)
		return
	var captures := output_path.trim_suffix(".json") + "-frames"
	_check(not DirAccess.dir_exists_absolute(captures), "fresh captures directory")
	if failures > 0:
		quit(1)
		return
	_check(DirAccess.make_dir_recursive_absolute(captures) == OK, "create diagnostic captures")
	if failures > 0:
		quit(1)
		return
	var cases: Array[Dictionary] = []
	for case_name: String in ["sustained-distributed", "dense-crucible"]:
		var fixture: Dictionary = _fixture(case_name)
		var world: SimWorld = fixture.world
		for unused: int in range(WARMUP_TICKS):
			_check(world.step(_commands(world, fixture.targets, case_name, false, false)), "unchanged neutral warmup")
		for unused: int in range(ACTIVE_TICKS):
			_check(world.step(_commands(world, fixture.targets, case_name, true, false)), "unchanged paid workload")
		_check(world.players.size() == 8 and int(world.hex_court.metrics.admitted) > 0 and world.hex_court.conservation_valid(), "eight actors and conserved paid chemistry")
		var frozen_hash: String = world.state_hash()
		var modes: Array[String] = ["normal", "reduced"]
		if case_name == "dense-crucible":
			modes.reverse()
		for mode: String in modes:
			cases.append(await _case(world, case_name, mode, frozen_hash, captures))
		_check(world.state_hash() == frozen_hash, "all component observations preserve authority")
	_check(cases.size() == 4, "all four case/mode results completed")
	for result: Dictionary in cases:
		_check(result.get("rows", []).size() == REPETITIONS and result.get("pixel_controls_equal", false), "complete samples and exact native pixel controls")
	var hashes: Dictionary = _source_hashes()
	for path: String in ["tests/performance/profile_hex_draw_components.gd", "tests/support/hex_draw_component_harness.gd", "tests/support/chemistry_coach_harness.gd", "src/app/bootstrap.gd", "src/presentation/sanctum_campus_renderer.gd", "src/presentation/hex_court_presenter.gd", "src/presentation/cartoon_champion_presenter.gd", "src/presentation/compact_combat_hud.gd", "src/presentation/pov_terrain_backdrop.gd", "src/presentation/wellspring_illustrated_kit.gd"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	var receipt: Dictionary = {
		"schema_version": 1, "profile_version": "hex-frozen-draw-components-v1", "engine": Engine.get_version_info()["string"],
		"display_server": DisplayServer.get_name(), "processor": OS.get_processor_name(), "logical_processors": OS.get_processor_count(),
		"rendering_method": RenderingServer.get_current_rendering_method(), "viewport": [1280, 720], "topology_cells": definition.eligible_cells.size(),
		"source_sha256": hashes, "cases": cases, "assertions": assertions, "failures": failures,
		"scope": "Test-only component attribution at frozen legal tick160 states of the existing eight-actor distributed/dense paid workload. No simulation advances during measured draws; this is not the 720-tick stress profile, actual input, networking, sustained cadence or release acceptance.",
		"timing_semantics": "Eight pairwise disjoint synchronous CPU submission call buckets within inherited Bootstrap._draw; their per-frame sum plus residual equals the outer draw timer. Residual includes untimed production code and diagnostic dispatch/clock/counter overhead. Percentiles cannot be added. Presentation elapsed includes scheduling/render completion and is not additive with draw. Instrumentation may perturb timing; no before/after optimization or GPU attribution is claimed.",
		"controls": "Exact complete-frame RGBA8 bytes: original harness versus timer subclasses disabled, then disabled versus enabled. Frozen state hash after each control arm and measured draw, outside timers. One requested draw per observation. No production source edits or alternative draw body. Static backdrop UPDATE_ONCE calls excluded by active/canvas guard.",
	}
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	_check(file != null, "component receipt opens")
	if file != null:
		receipt.assertions = assertions
		receipt.failures = failures
		file.store_string(JSON.stringify(receipt, "\t") + "\n")
		file.close()
	print("%s: hex-draw-components; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)

func _configure_node(node: Variant, world: SimWorld, mode: String, timers: bool) -> bool:
	node.hide()
	root.add_child(node)
	if not node.configure_fixture(true):
		return false
	if timers and not node.install_timers():
		return false
	if node.visual_accessibility_filter == null:
		node.visual_accessibility_filter = VisualAccessibilityFilter.new()
		if not node.visual_accessibility_filter.configure():
			return false
		node.add_child(node.visual_accessibility_filter)
	node.world = world
	node.authoritative_session = AuthoritativeSession.new()
	node.authoritative_session.world = world
	node.session_round_values = node.authoritative_session.session_round.capture(world)
	node.session_names_by_entity.clear()
	for actor: PlayerState in world.players:
		node.session_names_by_entity[actor.entity_id] = "Profile %d" % actor.entity_id
	node.requested_capture_reduced_effects = mode == "reduced"
	node.player_preferences.reduced_motion = false
	node.input_router.entity_id = 1
	node.accumulator_seconds = 0.0
	node.current_position = node._player_position()
	node.previous_position = node.current_position
	node.previous_air_height = world.player(1).air_height
	node._reset_motion_history()
	var identities: Array[String] = []
	for actor: PlayerState in world.players:
		identities.append(champions.champion_id_from_wire(actor.champion_wire_id))
	return node.cartoon_champion_presenter.prepare_override_pages(identities)

func _case(world: SimWorld, case_name: String, mode: String, expected_hash: String, captures: String) -> Dictionary:
	var control := ControlHarness.new()
	var node := TimedHarness.new()
	var original_ready: bool = _configure_node(control, world, mode, false)
	var timed_ready: bool = _configure_node(node, world, mode, true)
	_check(original_ready, "original control configures")
	_check(timed_ready, "timer subclasses configure unchanged production assets")
	if not original_ready or not timed_ready:
		control.queue_free()
		node.queue_free()
		await process_frame
		return {}
	var stem := case_name + "-" + mode
	control.show()
	for unused: int in range(PIXEL_WARMUP):
		_check(await _present(control), "one original warmup draw")
	var original: Image = root.get_texture().get_image()
	_check(original.get_format() == Image.FORMAT_RGBA8, "original image uses RGBA8")
	_check(world.state_hash() == expected_hash, "original control leaves authority unchanged")
	_check(original.save_png(captures + "/" + stem + "-original.png") == OK, "original capture saved")
	control.hide()
	node.show()
	for unused: int in range(PIXEL_WARMUP):
		_check(await _present(node), "one disabled-timer warmup draw")
	var disabled: Image = root.get_texture().get_image()
	_check(disabled.get_format() == Image.FORMAT_RGBA8, "disabled image uses RGBA8")
	_check(world.state_hash() == expected_hash, "disabled control leaves authority unchanged")
	_check(disabled.save_png(captures + "/" + stem + "-disabled.png") == OK, "disabled capture saved")
	var original_equal: bool = original.get_size() == disabled.get_size() and original.get_format() == disabled.get_format() and original.get_data() == disabled.get_data()
	_check(original_equal, stem + " original/subclass whole-frame pixels identical")
	node.timing_enabled = true
	for unused: int in range(PIXEL_WARMUP):
		_check(await _present(node), "one enabled-timer warmup draw")
	var enabled: Image = root.get_texture().get_image()
	_check(enabled.get_format() == Image.FORMAT_RGBA8, "enabled image uses RGBA8")
	_check(world.state_hash() == expected_hash, "enabled control leaves authority unchanged")
	_check(enabled.save_png(captures + "/" + stem + "-enabled.png") == OK, "enabled capture saved")
	var enabled_equal: bool = disabled.get_size() == enabled.get_size() and disabled.get_format() == enabled.get_format() and disabled.get_data() == enabled.get_data()
	_check(enabled_equal, stem + " enabled/disabled whole-frame pixels identical")
	var rows: Array[Dictionary] = []
	var series: Dictionary = {}
	for key: String in COMPONENTS + ["residual", "total_draw", "present_elapsed"]:
		series[key] = PackedInt64Array()
	for index: int in range(REPETITIONS):
		var began: int = Time.get_ticks_usec()
		var one_draw: bool = await _present(node)
		var present_us: int = Time.get_ticks_usec() - began
		_check(one_draw, "one native draw per measured sample")
		var values: Dictionary = {}
		var total_components := 0
		for key: String in COMPONENTS:
			values[key] = int(node.counters.elapsed.get(key, 0))
			total_components += int(values[key])
		values.residual = node.total_draw_us - total_components
		values.total_draw = node.total_draw_us
		values.present_elapsed = present_us
		_check(int(values.residual) >= 0, "disjoint component sum within enclosing draw")
		for key: String in ["campus", "hex_ground", "hud", "pov_mask", "combat_cues", "legacy_chemistry"]:
			_check(int(node.counters.calls.get(key, 0)) == 1, "exactly one expected component call")
		_check(int(node.counters.calls.get("actor_bodies", 0)) >= 1, "living local body is drawn")
		_check(int(node.counters.calls.get("projectiles", 0)) == world.projectiles.size(), "every frozen projectile submitted exactly once")
		_check(world.state_hash() == expected_hash, "authority hash unchanged after this measured draw")
		# Nested ground timers are diagnostic detail, never added to the eight
		# disjoint buckets above. Preserve raw samples rather than add percentiles.
		rows.append({"index": index, "us": values, "calls": node.counters.calls.duplicate(true), "ground_detail_us": node.counters.ground_elapsed.duplicate()})
		for key: String in series:
			var samples: PackedInt64Array = series[key]
			samples.append(int(values[key]))
			series[key] = samples
	var summaries: Dictionary = {}
	for key: String in series:
		_check((series[key] as PackedInt64Array).size() == REPETITIONS, "complete component sample array")
		summaries[key] = _percentiles(series[key])
	_check(world.state_hash() == expected_hash, "authority hash unchanged across this case")
	var result: Dictionary = {"case": case_name, "mode": mode, "world_tick": world.tick, "world_hash": expected_hash, "topology_cells": world.hex_court.cells.size(), "actors": world.players.size(), "occupancy": _occupancy(world.hex_court, world.tick), "paid_metrics": world.hex_court.metrics.duplicate(true), "pixel_controls_equal": original_equal and enabled_equal, "original_rgba_sha256": _bytes_hash(original.get_data()), "disabled_rgba_sha256": _bytes_hash(disabled.get_data()), "enabled_rgba_sha256": _bytes_hash(enabled.get_data()), "rows": rows, "samples": series, "summary_us": summaries}
	node.queue_free()
	control.queue_free()
	await process_frame
	await process_frame
	return result

func _present(node: Variant) -> bool:
	var before: int = node.draw_invocations
	node.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return int(node.draw_invocations) == before + 1

func _bytes_hash(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()
