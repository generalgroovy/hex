extends "res://tests/performance/profile_hex_draw_components.gd"
@warning_ignore_start("integer_division")

const BoundaryOracle = preload("res://tests/support/hex_boundary_oracle.gd")
const MEASURED_BLOCK := 8
const BLOCK_ORDER := ["before", "after", "after", "before", "after", "before", "before", "after"]

func _profile_id() -> String:
	return "hex-boundary-reuse"

func _oracle_path() -> String:
	return "res://tests/support/hex_boundary_oracle.gd"

func _baseline_presenter() -> HexCourtPresenter:
	return BoundaryOracle.new()

class OuterTimedHarness extends CoachHarness:
	var draw_invocations := 0
	var total_draw_us := 0
	func _draw() -> void:
		var began := Time.get_ticks_usec()
		super._draw()
		total_draw_us = Time.get_ticks_usec() - began
		draw_invocations += 1

class MaterialCourt extends RefCounted:
	var origin := Vector2i(180000, 100000)
	var cells := {}
	var render_revision := 1
	var phase := "forming"
	func view(cell: Vector2i, _tick: float) -> Dictionary:
		var material: String = cells[cell].material
		return {material + "_quantity": 1, material + "_present": true, "steam_heat": 1400}
	func render_regions(cell: Vector2i, material: String, _tick: float) -> Array[Dictionary]:
		if cells[cell].material != material: return []
		var polygon := PackedVector2Array()
		for point: Vector2i in HexGrid.vertices(cell): polygon.append(Vector2(point + origin))
		var actual_phase := phase
		if material == "fire": actual_phase = "ignition" if phase == "forming" else "cooling" if phase == "decaying" else phase
		return [{"polygon": polygon, "footprint_id": int(cells[cell].id), "material": material,
			"phase": actual_phase, "danger": phase == "active", "intensity": 1400, "quantity": 1,
			"owner": 1, "source_ids": [1, 2], "expiry_tick": 500, "recipe_wire_id": cells[cell].wire,
			"direction": Vector2i(1000, 0)}]

class MaterialCanvas extends Node2D:
	var presenter: HexCourtPresenter
	var court: MaterialCourt
	var reduced := false
	var draw_invocations := 0
	var result := false
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color("30372e"))
		result = presenter.draw_ground(self, court, 160.0, reduced, false)
		draw_invocations += 1

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
	_check(output_path.begins_with("res://.godot/" + _profile_id() + "-") and output_path.ends_with(".json") and not ".." in output_path and not FileAccess.file_exists(output_path), "fresh bounded receipt")
	_check(DisplayServer.get_name() != "headless" and root.get_visible_rect().size == Vector2(1280,720), "native viewport")
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "abilities")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "champions")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "campus")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null and definition.eligible_cells.size() == 11337, "unaltered topology")
	if failures > 0:
		quit(1)
		return
	var captures := output_path.trim_suffix(".json") + "-frames"
	_check(not DirAccess.dir_exists_absolute(captures), "fresh native captures")
	_check(DirAccess.make_dir_recursive_absolute(captures) == OK, "capture directory")
	var material_controls := await _material_controls(captures)
	var cases: Array[Dictionary] = []
	for case_name: String in ["sustained-distributed", "dense-crucible"]:
		var fixture: Dictionary = _fixture(case_name)
		var world: SimWorld = fixture.world
		for unused: int in WARMUP_TICKS: _check(world.step(_commands(world, fixture.targets, case_name, false, false)), "neutral warmup")
		for unused: int in ACTIVE_TICKS: _check(world.step(_commands(world, fixture.targets, case_name, true, false)), "paid workload")
		_check(world.players.size() == 8 and world.hex_court.conservation_valid(), "legal paid eight-actor fixture")
		for mode: String in ["normal", "reduced"]:
			cases.append(await _alternating_case(world, case_name, mode, captures))
	var receipt := {"schema_version": 1, "engine": Engine.get_version_info()["string"], "display": DisplayServer.get_name(),
		"cpu": OS.get_processor_name(), "cases": cases, "material_controls": material_controls,
		"assertions": assertions, "failures": failures,
		"scope": "Frozen paid tick160 CPU draw submission: 32 samples per arm per case in ABBA/BAAB blocks, four discarded draws after each switch. Full native RGBA and authority equality. Six additional all-44-material phase/mode images are synthetic correctness controls, not gameplay loads. No GPU, moving cadence, network or 120Hz acceptance.",
		"profile_id": _profile_id(), "oracle_path": _oracle_path(),
		"source_sha256": {"presenter": FileAccess.get_sha256("res://src/presentation/hex_court_presenter.gd"), "oracle": FileAccess.get_sha256(_oracle_path()), "profiler": FileAccess.get_sha256(get_script().resource_path), "shared_runner": FileAccess.get_sha256("res://tests/performance/profile_hex_boundary_reuse.gd")}}
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	_check(file != null, "receipt opens")
	if file != null:
		receipt.assertions = assertions
		receipt.failures = failures
		file.store_string(JSON.stringify(receipt, "\t") + "\n")
		file.close()
	print("%s: %s; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", _profile_id(), assertions, failures, output_path])
	quit(1 if failures > 0 else 0)

func _alternating_case(world: SimWorld, label: String, mode: String, captures: String) -> Dictionary:
	var expected_hash := world.state_hash()
	var nodes := {"before": OuterTimedHarness.new(), "after": OuterTimedHarness.new()}
	for arm: String in nodes:
		var node: OuterTimedHarness = nodes[arm]
		_check(_configure_node(node, world, mode, false), "production harness configures")
		if arm == "before":
			var oracle := _baseline_presenter()
			_check(oracle.configure(node.visual_language), "frozen boundary oracle configures")
			node.hex_court_presenter = oracle
	var samples := {"before": PackedInt64Array(), "after": PackedInt64Array()}
	var rows: Array[Dictionary] = []
	var image_bytes := PackedByteArray()
	var captured := {}
	for arm: String in BLOCK_ORDER:
		for key: String in nodes: nodes[key].visible = key == arm
		var node: OuterTimedHarness = nodes[arm]
		for unused: int in 4: _check(await _present(node), "one discarded warm draw after switch")
		if not captured.has(arm):
			var frame := root.get_texture().get_image()
			_check(frame.get_format() == Image.FORMAT_RGBA8, "full RGBA control")
			if image_bytes.is_empty(): image_bytes = frame.get_data()
			else: _check(image_bytes == frame.get_data(), "before/after full native image exact")
			captured[arm] = _bytes_hash(frame.get_data())
			_check(frame.save_png(captures + "/" + label + "-" + mode + "-" + arm + ".png") == OK, "native image saved")
		for index: int in MEASURED_BLOCK:
			_check(await _present(node), "one measured native draw")
			var elapsed: int = node.total_draw_us
			_check(world.state_hash() == expected_hash, "draw preserves exact authority")
			var values: PackedInt64Array = samples[arm]
			values.append(elapsed)
			samples[arm] = values
			rows.append({"arm": arm, "us": elapsed})
	var summary := {}
	for arm: String in samples:
		_check(samples[arm].size() == 32, "complete alternating samples")
		summary[arm] = _percentiles(samples[arm])
	var after: OuterTimedHarness = nodes.after
	var membership: int = world.hex_court.occupied_cells().size()
	var cache := {"segments": after.hex_court_presenter._edge_segments_cache.size(), "outlines": after.hex_court_presenter._outline_geometry_cache.size()}
	for node: OuterTimedHarness in nodes.values(): node.queue_free()
	await process_frame
	return {"case": label, "mode": mode, "world_hash": expected_hash, "occupancy": _occupancy(world.hex_court, world.tick), "occupied_membership": membership, "rgba": captured, "cache_rows": cache, "rows": rows, "summary_us": summary}

func _material_controls(captures: String) -> Array[Dictionary]:
	var language := VisualLanguage.new()
	_check(language.load_from_file(), "production visual language")
	var court := MaterialCourt.new()
	var probe := HexCourtPresenter.new()
	_check(probe.configure(language), "material descriptor probe")
	for index: int in HexCourtPresenter.MATERIALS.size():
		var material: String = HexCourtPresenter.MATERIALS[index]
		var cell := Vector2i((index % 11) * 3, (index / 11) * 3)
		for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT]:
			court.cells[cell + offset] = {"material": material, "wire": probe._material_descriptor(material).wire_id, "id": index}
	var nodes: Array[MaterialCanvas] = []
	for presenter: HexCourtPresenter in [_baseline_presenter(), HexCourtPresenter.new()]:
		var node := MaterialCanvas.new()
		node.hide()
		node.presenter = presenter
		node.court = court
		_check(presenter.configure(language), "material control presenter")
		root.add_child(node)
		nodes.append(node)
	var results: Array[Dictionary] = []
	for phase: String in ["forming", "active", "decaying"]:
		court.phase = phase
		for reduced: bool in [false, true]:
			var before := PackedByteArray()
			var authority := var_to_bytes(court.cells)
			for index: int in 2:
				for other: MaterialCanvas in nodes: other.hide()
				var node := nodes[index]
				node.reduced = reduced
				node.show()
				_check(await _present(node) and node.result, "all materials render")
				var frame := root.get_texture().get_image()
				if index == 0: before = frame.get_data()
				else:
					_check(before == frame.get_data(), "all 44 materials share exact native boundaries across phase/mode changes")
					_check(authority == var_to_bytes(court.cells), "synthetic authority preserved")
					var label := phase + ("-reduced" if reduced else "-normal")
					_check(frame.save_png(captures + "/materials-" + label + ".png") == OK, "material grid saved")
					results.append({"case": label, "rgba_sha256": _bytes_hash(before), "equal": before == frame.get_data()})
	for node: MaterialCanvas in nodes: node.queue_free()
	await process_frame
	return results
