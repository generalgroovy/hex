extends "res://tests/performance/profile_hex_draw_components.gd"

const NativePresenter = preload("res://tests/support/hex_render_frame_native_presenter.gd")
const FrameCandidate = preload("res://tests/support/hex_render_frame_candidate.gd")
const CYCLES := 4
const BLOCK_SAMPLES := 7
const SAMPLES_PER_ARM := CYCLES * BLOCK_SAMPLES * 2

class NativeHarness extends CoachHarness:
	var draw_invocations := 0
	var total_draw_us := 0
	func install_timers() -> bool:
		var presenter := NativePresenter.new()
		if not presenter.configure(visual_language):
			return false
		hex_court_presenter = presenter
		return true
	func _draw() -> void:
		var began: int = Time.get_ticks_usec()
		super._draw()
		total_draw_us = Time.get_ticks_usec() - began
		draw_invocations += 1

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	_check(output_path.begins_with("res://.godot/hex-render-frame-native-") and output_path.ends_with(".json") and not ".." in output_path and not FileAccess.file_exists(output_path), "fresh native A/B receipt")
	_check(DisplayServer.get_name() != "headless" and root.get_visible_rect().size == Vector2(1280, 720), "native 1280x720 display")
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production abilities")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "production champions")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "production campus")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null and definition.eligible_cells.size() == 2766, "unchanged campus topology")
	var captures := output_path.trim_suffix(".json") + "-frames"
	_check(not DirAccess.dir_exists_absolute(captures), "fresh native A/B captures")
	if failures > 0:
		quit(1)
		return
	_check(DirAccess.make_dir_recursive_absolute(captures) == OK, "native capture directory created")
	if failures > 0:
		quit(1)
		return
	var cases: Array[Dictionary] = []
	for case_name: String in ["sustained-distributed", "dense-crucible"]:
		var fixture: Dictionary = _fixture(case_name)
		var world: SimWorld = fixture.world
		for unused: int in range(WARMUP_TICKS):
			_check(world.step(_commands(world, fixture.targets, case_name, false, false)), "neutral warmup")
		for unused: int in range(ACTIVE_TICKS):
			_check(world.step(_commands(world, fixture.targets, case_name, true, false)), "paid workload")
		_check(world.players.size() == 8 and world.hex_court.conservation_valid() and int(world.hex_court.metrics.admitted) > 0, "legal paid eight-actor fixture")
		var expected: String = world.state_hash()
		var modes: Array[String] = ["normal", "reduced"]
		if case_name == "dense-crucible": modes.reverse()
		for mode: String in modes:
			cases.append(await _native_case(world, case_name, mode, expected, captures))
	_check(cases.size() == 4, "all native A/B cases completed")
	for result: Dictionary in cases:
		_check(result.get("rows", []).size() == SAMPLES_PER_ARM * 2 and result.get("pixel_controls_equal", false), "native case complete and pixels exact")
	var hashes: Dictionary = _source_hashes()
	for path: String in ["tests/performance/profile_hex_render_frame_native_candidate.gd", "tests/performance/profile_hex_draw_components.gd", "tests/support/hex_render_frame_native_presenter.gd", "tests/support/hex_render_frame_candidate.gd", "tests/support/hex_draw_component_harness.gd", "tests/support/chemistry_coach_harness.gd", "src/app/bootstrap.gd", "src/presentation/hex_court_presenter.gd", "src/presentation/sanctum_campus_renderer.gd", "src/presentation/cartoon_champion_presenter.gd", "src/presentation/compact_combat_hud.gd", "src/presentation/pov_terrain_backdrop.gd"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	var receipt := {"schema_version": 1, "profile_version": "hex-render-frame-native-candidate-v1", "engine": Engine.get_version_info()["string"], "display_server": DisplayServer.get_name(), "rendering_method": RenderingServer.get_current_rendering_method(), "processor": OS.get_processor_name(), "logical_processors": OS.get_processor_count(), "viewport": [1280,720], "cycles": CYCLES, "block_samples": BLOCK_SAMPLES, "samples_per_arm_per_case": SAMPLES_PER_ARM, "cases": cases, "source_sha256": hashes, "assertions": assertions, "failures": failures,
		"scope": "Test-only native ABBA/BAAB draws on frozen legal tick160 states, same presenter instance per case, original production draw_ground versus one-call preparation prototype with unchanged inherited draw helpers. No production source edits. No authority advances during measured frames. Not the evolving stress test, export, actual controls, networking, human acceptance or capacity.",
		"timing_semantics": "Ground and enclosing Bootstrap CPU submission are nested, not additive. Present elapsed includes scheduling/render completion. Per-sample image readback, exact byte comparison, state hash and receipt collection are outside every timer. Equal unrecorded warmup per arm. Microbenchmark perturbation and timer overhead remain; no GPU attribution."}
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	_check(file != null, "native A/B receipt opens")
	if file != null:
		receipt.assertions = assertions
		receipt.failures = failures
		file.store_string(JSON.stringify(receipt, "\t") + "\n")
		file.close()
	print("%s: hex-render-frame-native-candidate; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)

func _native_case(world: SimWorld, case_name: String, mode: String, expected_hash: String, captures: String) -> Dictionary:
	var node := NativeHarness.new()
	var configured: bool = _configure_node(node, world, mode, true)
	_check(configured, "native A/B harness configures")
	if not configured:
		node.queue_free()
		await process_frame
		return {}
	var presenter: NativePresenter = node.hex_court_presenter
	node.show()
	var expected_pixels := PackedByteArray()
	var baseline_rgba_sha := ""
	var candidate_rgba_sha := ""
	var pixel_controls_equal := true
	for enabled: bool in [false, true]:
		presenter.candidate_enabled = enabled
		for unused: int in range(4):
			_check(await _present(node), "one native warmup draw")
		var captured: Image = root.get_texture().get_image()
		_check(captured.get_format() == Image.FORMAT_RGBA8, "native A/B RGBA8 image")
		var arm := "candidate" if enabled else "production"
		_check(captured.save_png(captures + "/" + case_name + "-" + mode + "-" + arm + ".png") == OK, "native A/B frame saved")
		if not enabled:
			expected_pixels = captured.get_data()
			baseline_rgba_sha = _bytes_hash(expected_pixels)
		else:
			pixel_controls_equal = expected_pixels == captured.get_data()
			candidate_rgba_sha = _bytes_hash(captured.get_data())
			_check(pixel_controls_equal, "initial candidate and production full-frame pixels equal")
		_check(world.state_hash() == expected_hash, "native warmup leaves authority unchanged")
	var rows: Array[Dictionary] = []
	var samples := {"production": {"ground": PackedInt64Array(), "draw": PackedInt64Array(), "present": PackedInt64Array()}, "candidate": {"ground": PackedInt64Array(), "draw": PackedInt64Array(), "present": PackedInt64Array()}}
	for cycle: int in range(CYCLES):
		var order: Array[bool] = [false, true, true, false]
		if cycle % 2 == 1: order = [true, false, false, true]
		for block_index: int in range(order.size()):
			presenter.candidate_enabled = order[block_index]
			var arm := "candidate" if presenter.candidate_enabled else "production"
			for sample_index: int in range(BLOCK_SAMPLES):
				var began: int = Time.get_ticks_usec()
				var one_draw: bool = await _present(node)
				var present_us: int = Time.get_ticks_usec() - began
				var ground_us: int = presenter.draw_ground_us
				var draw_us: int = node.total_draw_us
				_check(one_draw and ground_us <= draw_us, "single draw with enclosed ground timer")
				var image: Image = root.get_texture().get_image()
				var exact: bool = image.get_format() == Image.FORMAT_RGBA8 and image.get_data() == expected_pixels
				_check(exact, "every measured draw preserves complete baseline RGBA8 bytes")
				pixel_controls_equal = pixel_controls_equal and exact
				_check(world.state_hash() == expected_hash, "every measured draw preserves authority")
				rows.append({"cycle": cycle, "block": block_index, "index": sample_index, "arm": arm, "ground_us": ground_us, "draw_us": draw_us, "present_us": present_us})
				for key: String in ["ground", "draw", "present"]:
					var values: PackedInt64Array = samples[arm][key]
					values.append(ground_us if key == "ground" else draw_us if key == "draw" else present_us)
					samples[arm][key] = values
	var summaries: Dictionary = {}
	for arm: String in ["production", "candidate"]:
		summaries[arm] = {}
		for key: String in ["ground", "draw", "present"]:
			_check((samples[arm][key] as PackedInt64Array).size() == SAMPLES_PER_ARM, "complete alternating native samples")
			summaries[arm][key] = _percentiles(samples[arm][key])
	var result := {"case": case_name, "mode": mode, "world_tick": world.tick, "world_hash": expected_hash, "actors": world.players.size(), "topology_cells": world.hex_court.cells.size(), "paid_metrics": world.hex_court.metrics.duplicate(true), "occupancy": _occupancy(world.hex_court, world.tick), "pixel_controls_equal": pixel_controls_equal, "production_rgba_sha256": baseline_rgba_sha, "candidate_rgba_sha256": candidate_rgba_sha, "rows": rows, "samples": samples, "summary_us": summaries}
	node.queue_free()
	await process_frame
	await process_frame
	return result
