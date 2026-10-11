extends SceneTree


const BootstrapScene = preload("res://scenes/bootstrap/bootstrap.tscn")
const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")

const WIDTH := 1280
const HEIGHT := 720
const ACTOR_ID := 1
const MATTER_PER_CAST := 600
const MAX_DEMO_TICKS := 900
const PAIRS: Array[Dictionary] = [
	{"label": "earth-earth", "first": 1, "second": 1, "recipe": 301},
	{"label": "earth-fire", "first": 1, "second": 2, "recipe": 302},
	{"label": "earth-water", "first": 1, "second": 3, "recipe": 303},
	{"label": "earth-air", "first": 1, "second": 4, "recipe": 304},
	{"label": "fire-fire", "first": 2, "second": 2, "recipe": 309},
	{"label": "fire-water", "first": 2, "second": 3, "recipe": 310},
	{"label": "fire-air", "first": 2, "second": 4, "recipe": 311},
	{"label": "water-water", "first": 3, "second": 3, "recipe": 316},
	{"label": "water-air", "first": 3, "second": 4, "recipe": 317},
	{"label": "air-air", "first": 4, "second": 4, "recipe": 322},
]

var output := ""
var game: Node2D
var frames: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var ui_states: Array[Dictionary] = []
var failed := false
var definition: HexWorldDefinition


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless":
		_fail("unified Wellspring capture requires a visible rendering display")
		return
	# Absolute contained outputs let the same external probe review a frozen PCK.
	var valid_output := output.begins_with("res://.godot/unified-wellspring-") or (output.is_absolute_path() and output.replace("\\", "/").contains("/.godot/unified-wellspring-"))
	if not valid_output or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("fresh contained unified Wellspring output is required")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("could not create unified Wellspring capture directory")
		return

	root.size = Vector2i(WIDTH, HEIGHT)
	root.visible = true
	game = BootstrapScene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	if game == null or game.world == null or game.world.hex_court == null:
		_fail("production Bootstrap did not bind normal Wellspring hex authority")
		return
	# The harness owns deterministic stepping after production Bootstrap has built
	# the real scene, catalogs, campus, roster, renderer, and world.
	game.set_process(false)
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	game.requested_capture_reduced_effects = false
	if game.element_audio != null:
		game.element_audio.set_process(false)

	definition = HexWorldDefinition.from_campus(game.campus_layout)
	if not _valid_normal_wellspring():
		return

	for index: int in range(PAIRS.size()):
		if not await _capture_pair(index, PAIRS[index]):
			return
	if not await _capture_interfaces():
		return
	if failed:
		return
	if cases.size() != PAIRS.size() or frames.size() != PAIRS.size() * 2 + 3:
		_fail("capture cardinality drifted from ten pair states plus three interfaces")
		return

	var receipt := {
		"schema": 1,
		"status": "passed",
		"scope": "visible native production Bootstrap on normal Wellspring; ten unordered first-four paid Bolt pairs through HexPlaygroundDemo; normal/reduced active authority frames; pair matrix and full/Fire-filtered Spell Loom",
		"evidence_boundary": "proves scripted local paid simulation, authoritative selected whole-hex state, and production renderer output; does not prove human visual acceptance, multiplayer behavior, or rendered performance",
		"display": {
			"server": DisplayServer.get_name(),
			"visible_window": root.visible,
			"size": [root.size.x, root.size.y],
			"headless": false,
		},
		"authority": {
			"map_id": game.world.map_id,
			"map_hash": game.world.map_hash,
			"hex_definition_hash": definition.definition_hash,
			"hex_origin": [definition.origin.x, definition.origin.y],
			"eligible_cell_count": definition.eligible_cells.size(),
			"tick_rate": game.world.config.tick_rate,
			"normal_wellspring_bound": true,
		},
		"method": {
			"scene": "res://scenes/bootstrap/bootstrap.tscn",
			"renderer": "Bootstrap._draw with HexCourtPresenter on the normal campus",
			"paid_driver": "HexPlaygroundDemo.begin/command and SimWorld.step with real SimCommand inputs",
			"profile_storage": "isolated APPDATA supplied by the engine-lease wrapper",
			"direct_effect_injection": false,
			"direct_projectile_injection": false,
			"sources": _source_manifest(),
		},
		"output": {
			"resource_path": output,
			"absolute_path": ProjectSettings.globalize_path(output),
			"receipt": "capture-receipt.json",
		},
		"cases": cases,
		"ui_states": ui_states,
		"frames": frames,
	}
	var receipt_path := output + "/capture-receipt.json"
	var file := FileAccess.open(receipt_path, FileAccess.WRITE)
	if file == null:
		_fail("could not open unified Wellspring receipt")
		return
	file.store_string(JSON.stringify(receipt, "  "))
	file.close()
	print("PASS: unified Wellspring visible capture wrote %d frames for %d paid pair cases" % [frames.size(), cases.size()])
	game.queue_free()
	await process_frame
	quit(0)


func _valid_normal_wellspring() -> bool:
	if definition == null or game.world.map_id != String(game.campus_layout.data.id) \
		or game.world.map_hash != game.campus_layout.content_hash \
		or definition.map_hash != game.world.map_hash \
		or definition.eligible_cells.is_empty() \
		or game.world.hex_court.origin != definition.origin \
		or game.world.hex_court.cells.size() != definition.eligible_cells.size() \
		or not bool(game.world.hex_court.chemistry_enabled):
		_fail("normal Wellspring HexWorldDefinition binding is incomplete")
		return false
	for cell: Vector2i in definition.eligible_cells:
		if not game.world.hex_court.cells.has(cell):
			_fail("bound authority omitted a trusted Wellspring cell")
			return false
	return true


func _capture_pair(index: int, pair: Dictionary) -> bool:
	if not game._restart_shared_seed(120):
		_fail("normal Wellspring reset failed before " + String(pair.label))
		return false
	game.set_process(false)
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	game.requested_capture_reduced_effects = false
	game.hex_playground_open = false
	_sync()
	if not _valid_normal_wellspring():
		return false
	var world: SimWorld = game.world
	var authority: HexChemistryWorld = world.hex_court
	var actor: PlayerState = world.player(ACTOR_ID)
	if actor == null or not authority.products.is_empty() or int(authority.metrics.get("matter_paid", 0)) != 0:
		_fail("pair reset did not provide a clear paid authority: " + String(pair.label))
		return false
	var expected_wire := Policy.recipe_wire(int(pair.first), int(pair.second))
	if expected_wire != int(pair.recipe) or Policy.definition(expected_wire).is_empty():
		_fail("pair policy drifted for " + String(pair.label))
		return false
	if not game.hex_playground_demo.begin(world, ACTOR_ID, int(pair.first), int(pair.second), game.ability_catalog):
		_fail("production paid demo refused " + String(pair.label) + ": " + game.hex_playground_demo.status())
		return false

	var payments: Array[Dictionary] = []
	for _tick: int in range(MAX_DEMO_TICKS):
		_enrich_payments(payments, authority, [])
		var paid_before := int(authority.metrics.get("matter_paid", 0))
		var flux_before := actor.flux
		var command: SimCommand = game.hex_playground_demo.command(world)
		if command == null:
			if game.hex_playground_demo.is_active():
				_fail("paid demo returned no command while active: " + String(pair.label))
				return false
			break
		if not world.step([command]):
			_fail("authoritative paid demo step failed: " + String(pair.label))
			return false
		# A point-blank second Bolt can release and be wholly consumed in this
		# same step. Retain its real spawn event before its ledger is retired.
		for event: Dictionary in world.combat_events:
			if String(event.get("type", "")) != "projectile_spawned" or int(event.get("owner_id", 0)) != ACTOR_ID or int(event.get("lane_count", 0)) != 1:
				continue
			for payment: Dictionary in payments:
				if int(payment.get("source_cast_id", 0)) == 0 and int(payment.wire_id) == int(event.get("wire_id", 0)):
					payment.source_cast_id = int(event.projectile_id)
					payment.release_tick = world.tick - 1
					break
		var paid_after := int(authority.metrics.get("matter_paid", 0))
		if paid_after != paid_before:
			if paid_after != paid_before + MATTER_PER_CAST or payments.size() >= 2:
				_fail("paid demo committed a non-600 or extra budget: " + String(pair.label))
				return false
			var cast_id := int(authority.pending.get(ACTOR_ID, 0))
			var cast: Dictionary = authority.casts.get(cast_id, {})
			if cast_id <= 0 or cast.is_empty() or not bool(cast.get("paid", false)) or int(cast.get("budget", 0)) != MATTER_PER_CAST:
				_fail("paid demo admission was not represented by a paid 600 cast")
				return false
			payments.append({
				"ordinal": payments.size() + 1,
				"accepted_tick": world.tick - 1,
				"cast_id": cast_id,
				"wire_id": int(cast.get("wire", 0)),
				"element_wire_id": int(cast.get("element", 0)),
				"matter_before": paid_before,
				"matter_after": paid_after,
				"matter_committed": MATTER_PER_CAST,
				"flux_before": flux_before,
				"flux_after": actor.flux,
			})
		if not authority.conservation_valid():
			_fail("matter conservation failed during paid demo: " + String(pair.label))
			return false
		_sync()
	if game.hex_playground_demo.is_active() or not game.hex_playground_demo.status().begins_with("Paid demo complete:"):
		_fail("paid demo did not complete within its bounded authored window: " + String(pair.label))
		return false
	if payments.size() != 2 or int(authority.metrics.get("matter_paid", 0)) != MATTER_PER_CAST * 2:
		_fail("paid demo did not produce exactly two 600 starts: " + String(pair.label))
		return false

	var product := _product_for(expected_wire)
	if product.is_empty() or int(product.get("quantity", 0)) != MATTER_PER_CAST * 2:
		_fail("paid pair did not conserve into one 1200 product: " + String(pair.label))
		return false
	var source_ids: Array = product.get("source_ids", [])
	if source_ids.size() != 2 or int(source_ids[0]) == int(source_ids[1]):
		_fail("paid product did not retain two distinct sources: " + String(pair.label))
		return false
	_enrich_payments(payments, authority, source_ids)
	while world.tick < int(product.get("active_tick", -1)):
		if not _neutral_step():
			return false
		product = _product_for(expected_wire)
		if product.is_empty():
			_fail("product expired before its selected active frame: " + String(pair.label))
			return false
	if world.tick < int(product.get("active_tick", -1)) or world.tick >= int(product.get("decay_tick", -1)):
		_fail("selected pair frame is not in the authoritative active phase: " + String(pair.label))
		return false
	var selected := _selected_cells(product, authority)
	if selected.is_empty():
		_fail("active product has no canonical selected whole hexes: " + String(pair.label))
		return false
	var product_before: Variant = HexChemistryWorld._stable(product)
	var state_hash := world.state_hash()
	var prefix := "%02d-%s-active" % [index + 1, String(pair.label)]
	game.requested_capture_reduced_effects = false
	var normal_frame := await _capture_frame(prefix + "-normal", "authority", false)
	if normal_frame.is_empty():
		return false
	game.requested_capture_reduced_effects = true
	var reduced_frame := await _capture_frame(prefix + "-reduced", "authority", true)
	game.requested_capture_reduced_effects = false
	if reduced_frame.is_empty() or world.state_hash() != state_hash or HexChemistryWorld._stable(product) != product_before:
		_fail("normal/reduced presentation changed pair authority: " + String(pair.label))
		return false
	if not authority.conservation_valid():
		_fail("active pair capture failed matter conservation: " + String(pair.label))
		return false
	var policy := Policy.definition(expected_wire)
	cases.append({
		"index": index + 1,
		"label": pair.label,
		"element_wires": [int(pair.first), int(pair.second)],
		"element_layers": [Policy.ingredient_layer(int(pair.first)), Policy.ingredient_layer(int(pair.second))],
		"recipe_wire_id": expected_wire,
		"product_name": String(policy.get("name", "")),
		"product_layer": Policy.product_layer(expected_wire),
		"capture_tick": world.tick,
		"phase_ticks": {
			"formation": int(product.get("formation_tick", product.get("created", 0))),
			"active": int(product.get("active_tick", 0)),
			"decay": int(product.get("decay_tick", 0)),
			"expiry": int(product.get("expiry_tick", product.get("expires", 0))),
		},
		"paid_starts": payments,
		"source_ids": source_ids.duplicate(),
		"product_summary": {
			"id": int(product.get("id", 0)),
			"quantity": int(product.get("quantity", 0)),
			"owner": int(product.get("owner", 0)),
			"team": int(product.get("team", 0)),
			"position": _point(product.get("position", Vector2i.ZERO)),
			"origin": _point(product.get("origin", Vector2i.ZERO)),
			"flow_aim": _point(product.get("flow_aim", Vector2i.ZERO)),
			"selected_cell_count": selected.size(),
		},
		"product_snapshot": product_before,
		"products_snapshot": HexChemistryWorld._stable(authority.products),
		"active_cells": selected,
		"metrics": HexChemistryWorld._stable(authority.metrics),
		"conservation_valid": true,
		"world_hash": state_hash,
		"authority_hash": authority.state_hash(),
		"frames": [normal_frame.file, reduced_frame.file],
	})
	return true


func _capture_interfaces() -> bool:
	if not game._restart_shared_seed(120):
		_fail("normal Wellspring reset failed before interface captures")
		return false
	game.set_process(false)
	game.requested_capture_reduced_effects = false
	game.hex_playground_pair = Vector2i(3, 2)
	game.hex_playground_open = true
	_sync()
	var matrix_cells: Array[Dictionary] = []
	for row: int in range(4):
		for column: int in range(4):
			matrix_cells.append(HexPlaygroundPanel.matrix_cell(row, column))
	var matrix_frame := await _capture_frame("21-hex-playground-matrix", "hex_playground_matrix", false)
	if matrix_frame.is_empty():
		return false
	ui_states.append({
		"kind": "hex_playground_matrix",
		"frame": matrix_frame.file,
		"selected": HexChemistryWorld._stable(HexPlaygroundPanel.selection_model(game.hex_playground_pair)),
		"matrix_cells": matrix_cells,
	})

	game.hex_playground_open = false
	game.spell_loom_editor.open_editor(game._local_player_state(), game.ability_catalog)
	if not game.spell_loom_editor.set_element_filter(""):
		_fail("Spell Loom refused its full matrix filter")
		return false
	var full_wires := _visible_loom_wires()
	if full_wires.size() != SpellLoomEditor.VISIBLE_SPELL_COUNT:
		_fail("full Spell Loom did not expose its 32 production entries")
		return false
	var full_frame := await _capture_frame("22-spell-loom-full-matrix", "spell_loom_full", false)
	if full_frame.is_empty():
		return false
	ui_states.append({"kind": "spell_loom_full", "frame": full_frame.file, "filter": "", "visible_wires": full_wires})

	if not game.spell_loom_editor.set_element_filter("fire"):
		_fail("Spell Loom refused the Fire filter")
		return false
	var fire_wires := _visible_loom_wires()
	if fire_wires.size() != 4:
		_fail("Fire-filtered Spell Loom did not expose exactly four families")
		return false
	for wire: int in fire_wires:
		if String(game.ability_catalog.ability_from_wire(wire).get("element", "")) != "fire":
			_fail("filtered Spell Loom exposed a non-Fire wire")
			return false
	var filtered_frame := await _capture_frame("23-spell-loom-fire-filtered", "spell_loom_filtered", false)
	if filtered_frame.is_empty():
		return false
	ui_states.append({"kind": "spell_loom_filtered", "frame": filtered_frame.file, "filter": "fire", "visible_wires": fire_wires})
	game.spell_loom_editor.close_editor()
	return true


func _capture_frame(label: String, kind: String, reduced: bool) -> Dictionary:
	var before: String = game.world.state_hash()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var resource_path := output + "/" + label + "-%dx%d.png" % [WIDTH, HEIGHT]
	if image == null or image.is_empty() or image.get_width() != WIDTH or image.get_height() != HEIGHT \
		or image.save_png(resource_path) != OK or game.world.state_hash() != before:
		_fail("visible capture failed or mutated authority: " + label)
		return {}
	var record := {
		"file": resource_path.get_file(),
		"resource_path": resource_path,
		"absolute_path": ProjectSettings.globalize_path(resource_path),
		"sha256": FileAccess.get_sha256(resource_path),
		"width": image.get_width(),
		"height": image.get_height(),
		"tick": game.world.tick,
		"kind": kind,
		"reduced_effects": reduced,
		"world_hash": before,
		"authority_hash": game.world.hex_court.state_hash(),
	}
	frames.append(record)
	return record


func _neutral_step() -> bool:
	var world: SimWorld = game.world
	var actor: PlayerState = world.player(ACTOR_ID)
	var command := SimCommand.new(world.tick, ACTOR_ID, 0, 0, 0, 0, actor.aim_x, actor.aim_y)
	if not world.step([command]) or not world.hex_court.conservation_valid():
		_fail("neutral authority step failed while selecting active product frame")
		return false
	_sync()
	return true


func _sync() -> void:
	game.accumulator_seconds = 0.0
	game.current_position = game._player_position()
	game.previous_position = game.current_position
	var actor: PlayerState = game.world.player(ACTOR_ID)
	game.previous_air_height = actor.air_height if actor != null else 0
	game._update_combat_cues(1.0 / 120.0)
	game._ingest_combat_cues(game.world.combat_events)
	game._reset_motion_history()


func _product_for(recipe_wire: int) -> Dictionary:
	var ids: Array = game.world.hex_court.products.keys()
	ids.sort()
	for id: Variant in ids:
		var product: Dictionary = game.world.hex_court.products[id]
		if int(product.get("recipe_wire_id", 0)) == recipe_wire:
			return product
	return {}


func _enrich_payments(payments: Array[Dictionary], authority: HexChemistryWorld, source_ids: Array) -> void:
	var source_to_cast: Dictionary = {}
	for source_value: Variant in source_ids:
		var source_id := int(source_value)
		source_to_cast[int(authority.sources.get(source_id, 0))] = source_id
	for payment: Dictionary in payments:
		var cast_id := int(payment.cast_id)
		var cast: Dictionary = authority.casts.get(cast_id, {})
		var source_id := int(source_to_cast.get(cast_id, cast.get("source", 0)))
		if source_id > 0:
			payment.source_cast_id = source_id
		if not cast.is_empty():
			payment.final_cast_snapshot = HexChemistryWorld._stable(cast)


func _selected_cells(product: Dictionary, authority: HexChemistryWorld) -> Array[Dictionary]:
	var coverage := HexChemistryWorld.coverage(product)
	var cells: Array = coverage.keys()
	cells.sort_custom(HexGrid._cell_less)
	var result: Array[Dictionary] = []
	var layer := Policy.product_layer(int(product.get("recipe_wire_id", 0)))
	var allocations: Dictionary = product.get("cells", {})
	for cell: Vector2i in cells:
		var vertices: Array = []
		for local: Vector2i in HexGrid.vertices(cell):
			var point := local + authority.origin
			vertices.append([point.x, point.y])
		var allocation := int(allocations.get(cell, 0))
		var cell_layers: Dictionary = authority.cells.get(cell, {})
		var layer_records: Dictionary = cell_layers.get(layer, {})
		var stored := int(layer_records.get(int(product.get("id", 0)), -1))
		if stored != allocation:
			_fail("selected cell allocation disagrees with the authoritative layer")
			return []
		result.append({
			"q": cell.x,
			"r": cell.y,
			"coverage": int(coverage[cell]),
			"allocation": allocation,
			"stored_allocation": stored,
			"vertices_absolute_fixed": vertices,
		})
	return result


func _visible_loom_wires() -> Array[int]:
	var result: Array[int] = []
	for index: int in game.spell_loom_editor.visible_spell_indices():
		result.append(int(game.spell_loom_editor.available_wire_ids[index]))
	return result


static func _point(value: Variant) -> Array[int]:
	var point: Vector2i = value if value is Vector2i else Vector2i.ZERO
	return [point.x, point.y]


static func _source_manifest() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for path: String in [
		"res://scenes/bootstrap/bootstrap.tscn",
		"res://src/app/bootstrap.gd",
		"res://src/app/hex_playground_demo.gd",
		"res://src/sim/hex/hex_world_definition.gd",
		"res://src/sim/hex/hex_chemistry_world.gd",
		"res://src/sim/hex/hex_recipe_policy.gd",
		"res://src/presentation/hex_court_presenter.gd",
		"res://src/presentation/hex_playground_panel.gd",
		"res://src/presentation/spell_loom_presenter.gd",
	]:
		result.append({"path": path, "sha256": FileAccess.get_sha256(path)})
	return result


func _fail(message: String) -> void:
	if failed:
		return
	failed = true
	push_error(message)
	quit(1)
