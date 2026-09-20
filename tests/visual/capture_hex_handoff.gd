extends "res://tests/visual/capture_unified_wellspring.gd"

# Bounded derivative of the native Wellspring capture. Root owns engine execution.
# Steam uses real paid inputs; motion boards deliberately label held pose fixtures.
const BODY_IDS: Array[String] = ["s_wayne", "oh_tipi", "red_baron"]
const MOTION_CASES: Array[String] = ["forward", "strafe", "backward", "opposing_aim", "slide", "airborne_cast"]
var motion_records: Array[Dictionary] = []

class MotionBoard:
	extends Node2D
	var presenter: CartoonChampionPresenter
	var config: SimConfig
	var actors: Array[PlayerState] = []
	var champions: Array[String] = []
	var label := ""
	var draw_failures := 0
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color("182420"))
		draw_string(ThemeDB.fallback_font, Vector2(24, 30), "HEX / SHARED BODY PILOT / " + label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ead9b6"))
		draw_string(ThemeDB.fallback_font, Vector2(24, 56), "Held production poses at phases 0 / 0.5; 2x nearest. No legal input, turn transition or world foot-lock proof.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("b2bfaf"))
		for index: int in actors.size():
			var column := index % 3
			var row := index / 3
			var anchor := Vector2(215 + column * 420, 340 + row * 340)
			var phase := float(row) * 0.5
			var body_type := String(presenter.champions[champions[index]]["body_type"])
			draw_string(ThemeDB.fallback_font, anchor + Vector2(-170, -220), "%s / phase %.1f" % [body_type, phase], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ead9b6"))
			draw_line(anchor + Vector2(-150, 1), anchor + Vector2(150, 1), Color("526850"))
			draw_set_transform(anchor, 0.0, Vector2(2, 2))
			if not presenter.draw(self, actors[index], champions[index], Vector2.ZERO, phase * 120.0, config, true, Vector2.ZERO, phase):
				draw_failures += 1
			draw_set_transform(Vector2.ZERO)


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/hex-handoff-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("visible display and fresh contained hex-handoff output required")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("could not create capture output")
		return
	root.size = Vector2i(WIDTH, HEIGHT)
	root.visible = true
	game = BootstrapScene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	if game.world == null or game.world.hex_court == null:
		_fail("production bootstrap did not create Wellspring authority")
		return
	game.set_process(false)
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	if game.element_audio != null:
		game.element_audio.set_process(false)
	definition = HexWorldDefinition.from_campus(game.campus_layout)
	if not _valid_normal_wellspring():
		return
	if not await _steam_phases() or not await _terrain_fields() or not await _binding_views() or not await _motion_boards():
		return
	if failed or frames.size() != 22:
		_fail("bounded handoff capture requires exactly twenty-two frames")
		return
	var sources := _source_manifest()
	sources.append({"path": "res://tests/visual/capture_hex_handoff.gd", "sha256": FileAccess.get_sha256("res://tests/visual/capture_hex_handoff.gd")})
	var receipt := {
		"status": "scripted_local_capture_complete", "frames": frames, "steam": cases,
		"ui": ui_states, "motion": motion_records, "sources": sources,
		"runtime_identity": JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)),
		"display": DisplayServer.get_name(), "source_map": game.world.map_id,
		"evidence_boundary": "Native Steam and UI frames; controlled shared-body pose boards. Human acceptance, actual movement replay, planted-foot drift and turn timing are NOT_RUN.",
		"missing_gates": ["overlapping contributors and partial expiry", "hole topology capture", "eight-player readability", "performance", "30/60/120 presentation trace", "legal slide/airborne/cast sequence", "animated contact drift"],
		"profile_storage": "transient settings; integration wrapper must supply isolated APPDATA",
	}
	var file := FileAccess.open(output + "/capture-receipt.json", FileAccess.WRITE)
	if file == null:
		_fail("could not write receipt")
		return
	file.store_string(JSON.stringify(receipt, "  ") + "\n")
	file.close()
	print("PASS hex-handoff native capture frames=", frames.size(), " motion=held-fixtures")
	quit(0)


func _steam_phases() -> bool:
	if not game._restart_shared_seed(120):
		_fail("normal Wellspring restart failed")
		return false
	game.set_process(false)
	game.hex_playground_open = false
	game.requested_capture_reduced_effects = false
	var world: SimWorld = game.world
	if not game.hex_playground_demo.begin(world, ACTOR_ID, 3, 2, game.ability_catalog):
		_fail("existing paid Water/Fire demo refused")
		return false
	var product: Dictionary = {}
	for _tick: int in MAX_DEMO_TICKS:
		var command: SimCommand = game.hex_playground_demo.command(world)
		if command == null or not world.step([command]):
			_fail("paid Steam demo stopped before forming product")
			return false
		_sync()
		product = _product_for(310)
		if not product.is_empty():
			break
	var authority: HexChemistryWorld = world.hex_court
	if product.is_empty() or int(authority.metrics.get("matter_paid", 0)) != 1200 or not authority.conservation_valid():
		_fail("Steam must originate from two real paid casts and conserved matter")
		return false
	var source_ids: Array = product.get("source_ids", [])
	if source_ids.size() != 2 or source_ids[0] == source_ids[1]:
		_fail("Steam source provenance missing")
		return false
	# SimWorld.step expires products at its incoming tick, then increments tick.
	# At world.tick == expiry_tick the last processed tick was expiry_tick - 1;
	# render_regions already omits expired state, but storage cleanup runs on the
	# next ordinary step. Capture gone after that real removal step, never erase it.
	var product_expiry_tick := int(product.expiry_tick)
	var phase_ticks := [world.tick, int(product.active_tick), int(product.decay_tick), product_expiry_tick + 1]
	if world.tick >= int(product.active_tick):
		_fail("formation capture missed the real formation interval")
		return false
	for index: int in 4:
		while world.tick < int(phase_ticks[index]):
			if not _neutral_step():
				return false
		var phase_name: String = ["forming", "active", "decaying", "gone"][index]
		var current := _product_for(310)
		if (index < 3 and current.is_empty()) or (index == 3 and not current.is_empty()):
			_fail("Steam phase presence mismatch: " + phase_name)
			return false
		var selected: Array[Dictionary] = []
		if not current.is_empty():
			selected = _selected_cells(current, authority)
			if selected.is_empty():
				_fail("Steam occupied-cell source unavailable")
				return false
		var before := world.state_hash()
		var phase_frames: Array[String] = []
		for reduced: bool in [false, true]:
			game.requested_capture_reduced_effects = reduced
			var frame := await _capture_frame("steam-%s-%s" % [phase_name, "reduced" if reduced else "normal"], "paid_steam_" + phase_name, reduced)
			if frame.is_empty():
				return false
			phase_frames.append(String(frame.file))
		if world.state_hash() != before or not authority.conservation_valid():
			_fail("Steam presentation changed authoritative state")
			return false
		cases.append({"phase": phase_name, "tick": world.tick, "last_processed_tick": world.tick - 1, "source_expiry_tick": product_expiry_tick, "removal_method": "ordinary SimWorld.step expiry processing; no direct cleanup", "product": HexChemistryWorld._stable(current), "selected_cells": selected, "paid_material": authority.metrics.matter_paid, "source_ids": source_ids, "world_hash": before, "frames": phase_frames})
	game.requested_capture_reduced_effects = false
	return true


# Three ordinary champions pay for six Bolts. No effect injection or resource reset
# occurs after fixture initialization. Targets are real eligible campus cells.
func _terrain_fields() -> bool:
	for family: String in ["grass", "paving"]:
		game.world = game._new_wellspring_world(120)
		game.authoritative_session.world = game.world
		var world: SimWorld = game.world
		var authority: HexChemistryWorld = world.hex_court
		var selection := _terrain_patch(family)
		if selection.is_empty():
			_fail("no source-verified open three-cell " + family + " patch")
			return false
		var targets: Array[Vector2i] = []
		targets.assign(selection.targets)
		var starts: Array = []
		world.players.clear()
		for index: int in 3:
			var actor := PlayerState.new(index + 1)
			if not game.champion_catalog.apply_to_player(actor, BODY_IDS[index]):
				_fail("terrain fixture champion unavailable")
				return false
			actor.reset_for_spawn(targets[index] + Vector2i(0, 128000))
			actor.spawn_protection_ticks = 0
			for slot: int in 2:
				var element := "water" if slot == 0 else "fire"
				var wire := int(game.ability_catalog.ability(game.ability_catalog.spell_id_at(element, "bolt")).wire_id)
				if not actor.place_proven_spell(slot, wire):
					_fail("terrain fixture cannot equip production Bolt")
					return false
			starts.append({"actor": actor.entity_id, "champion": BODY_IDS[index], "flux": actor.flux, "position": [actor.position_x, actor.position_y]})
			world.players.append(actor)
		game.selected_champion_id = BODY_IDS[0]
		game.hex_playground_open = false
		game.requested_capture_reduced_effects = false
		_sync()
		if (await _capture_frame("terrain-" + family + "-before", "native_terrain_before", false)).is_empty():
			return false
		for step_index: int in 180:
			var commands: Array[SimCommand] = []
			for index: int in 3:
				var actor: PlayerState = world.players[index]
				var target := targets[index]
				var delta := target - Vector2i(actor.position_x, actor.position_y)
				var pressed := int(SimCommand.SPELL_PRESSED_BITS[0]) if step_index == 0 else int(SimCommand.SPELL_PRESSED_BITS[1]) if step_index == 80 else 0
				commands.append(SimCommand.new(world.tick, actor.entity_id, 0, 0, 0, pressed, delta.x, delta.y, target.x, target.y))
			if not world.step(commands):
				_fail("ordinary terrain fixture command failed")
				return false
			_sync()
		var products: Array[Dictionary] = []
		var occupancy := {}
		var provenance := {}
		var all_steam_active := true
		for product_value: Variant in authority.products.values():
			var product: Dictionary = product_value
			if int(product.get("recipe_wire_id", 0)) != 310:
				continue
			if world.tick < int(product.active_tick) or world.tick >= int(product.decay_tick):
				all_steam_active = false
			products.append(product.duplicate(true))
			for cell: Vector2i in HexChemistryWorld.coverage(product):
				occupancy[cell] = true
			for source: Variant in product.get("source_ids", []):
				provenance[int(source)] = true
		var diagnostic := _terrain_diagnostic(family, selection, products, provenance, occupancy)
		diagnostic["all_steam_active"] = all_steam_active
		diagnostic["actual_occupied_terrain_samples"] = _terrain_material_counts(occupancy)
		print("TERRAIN_DIAGNOSTIC ", JSON.stringify(diagnostic))
		var diagnostic_file := FileAccess.open(output + "/terrain-" + family + "-diagnostic.json", FileAccess.WRITE)
		if diagnostic_file != null:
			diagnostic_file.store_string(JSON.stringify(diagnostic, "  ") + "\n")
			diagnostic_file.close()
		if not all_steam_active or products.size() != 3 or provenance.size() != 6 or occupancy.size() < 3 or not _connected_cells(occupancy) or int(authority.metrics.get("matter_paid", 0)) != 3600 or not authority.conservation_valid():
			_fail("terrain fixture requires three conserved connected Steam products from six paid sources")
			return false
		var phase_frames: Array[String] = []
		for reduced: bool in [false, true]:
			game.requested_capture_reduced_effects = reduced
			var frame := await _capture_frame("terrain-%s-connected-%s" % [family, "reduced" if reduced else "normal"], "paid_connected_steam", reduced)
			if frame.is_empty():
				return false
			phase_frames.append(String(frame.file))
		cases.append({"kind": "three_product_connected_field", "terrain_family": family, "terrain_label_scope": "three target centers; mixed surrounding terrain allowed", "actual_occupied_terrain_samples": diagnostic.actual_occupied_terrain_samples, "selection": HexChemistryWorld._stable(selection), "products": HexChemistryWorld._stable(products), "occupied_cells": HexChemistryWorld._stable(occupancy.keys()), "source_count": provenance.size(), "matter_paid": authority.metrics.matter_paid, "fixture_actor_starts": starts, "actor_end_flux": [world.players[0].flux, world.players[1].flux, world.players[2].flux], "direct_product_injection": false, "resource_replenishment": "ordinary simulation only after initial spawn", "frames": phase_frames})
	game.requested_capture_reduced_effects = false
	return true


func _terrain_diagnostic(family: String, selection: Dictionary, steam: Array[Dictionary], provenance: Dictionary, occupancy: Dictionary) -> Dictionary:
	var authority: HexChemistryWorld = game.world.hex_court
	var cast_records: Array[Dictionary] = []
	for value: Variant in authority.casts.values():
		var record: Dictionary = value
		cast_records.append({"id": record.get("id"), "source": record.get("source"), "wire": record.get("wire"), "element": record.get("element"), "paid": record.get("paid"), "reacted": record.get("reacted"), "ledger": record.get("ledger", {}), "ground_parts": record.get("ground_parts", {})})
	# _stable converts Dictionary values to ordered key/value arrays. Keep the
	# diagnostic envelope a Dictionary so callers can append status/sample fields.
	return {"terrain_family": family, "tick": game.world.tick, "selection": HexChemistryWorld._stable(selection), "steam_product_count": steam.size(), "all_product_count": authority.products.size(), "steam_source_count": provenance.size(), "steam_occupied_cell_count": occupancy.size(), "steam_connected": _connected_cells(occupancy), "conservation_valid": authority.conservation_valid(), "metrics": authority.metrics.duplicate(true), "products": HexChemistryWorld._stable(authority.products.values()), "casts": HexChemistryWorld._stable(cast_records), "world_error": game.world.last_error}


func _terrain_patch(family: String) -> Dictionary:
	var authority: HexChemistryWorld = game.world.hex_court
	var kit: WellspringIllustratedKit = game.campus_renderer.illustrated_kit
	var candidates: Array[Vector2i] = []
	candidates.assign(definition.eligible_cells)
	var rejected := {"outside_search_area": 0, "target_ineligible": 0, "spawn_blocked": 0, "target_center_family": 0, "lane_blocked": 0, "empty_steam_selection": 0, "lane_interference": 0, "steam_disconnected": 0}
	var mixed_candidates := 0
	var desired := Vector2i(600000, 1000000) if family == "grass" else Vector2i(1504000, 880000)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return HexGrid.center(a).distance_squared_to(desired) < HexGrid.center(b).distance_squared_to(desired))
	for center_cell: Vector2i in candidates:
		var center := HexGrid.center(center_cell) + authority.origin
		if family == "grass" and (center.x < 160000 or center.x > 800000 or center.y < 400000 or center.y > 1700000):
			rejected.outside_search_area += 1
			continue
		if family == "paving" and (center.x < 1280000 or center.x > 1792000 or center.y < 640000 or center.y > 944000):
			rejected.outside_search_area += 1
			continue
		var targets: Array[Vector2i] = []
		var cells: Array[Vector2i] = []
		var materials: Array[int] = []
		var valid := true
		var reasons := {}
		var mixed := false
		# A 34k Bolt disk at an adjacent 64k center can share whole cells.
		# Three axial steps separate ingredient lanes while 64k Steam disks
		# can still select edge-adjacent cells. Verify actual source selections.
		for offset: int in [-3, 0, 3]:
			var cell := center_cell + Vector2i(offset, 0)
			var target := HexGrid.center(cell) + authority.origin
			if not authority.cells.has(cell):
				reasons["target_ineligible"] = true
				valid = false
				break
			if not game.world.collision.can_occupy(target + Vector2i(0, 128000), MovementTuning.PLAYER_RADIUS):
				reasons["spawn_blocked"] = true
				valid = false
				break
			# Names describe actual target-center terrain. Adjacent hexes may
			# legitimately cross paths or borders; report those samples honestly.
			if WellspringIllustratedKit.pixel_family(kit.surface_at(Vector2(target) / 1000.0)) != family:
				reasons["target_center_family"] = true
				valid = false
			var points: Array[Vector2i] = [target]
			for vertex: Vector2i in HexGrid.vertices(cell):
				points.append(vertex + authority.origin)
			for point: Vector2i in points:
				var material := kit.surface_at(Vector2(point) / 1000.0)
				if WellspringIllustratedKit.pixel_family(material) != family:
					mixed = true
				materials.append(material)
			# The projectile lane is inspected for real blocking world geometry.
			for distance: int in [32000, 64000, 96000]:
				if not game.world.collision.can_occupy(target + Vector2i(0, distance), MovementTuning.PLAYER_RADIUS):
					reasons["lane_blocked"] = true
					valid = false
			targets.append(target)
			cells.append(cell)
		if not valid:
			for reason: String in reasons:
				rejected[reason] += 1
			continue
		var ingredient_regions: Array = []
		var lane_regions: Array = []
		var steam_regions: Array = []
		var steam_union := {}
		for target: Vector2i in targets:
			# Full-strength Bolt is the conservative maximum of its terminal
			# footprint; weakened deposits and 20k optional trails are smaller.
			ingredient_regions.append(authority.select_cells(HexFootprint.disk(target, 34000)))
			lane_regions.append(authority.select_cells(HexFootprint.capsule(target, target + Vector2i(0, 128000), 34000)))
			var selected := authority.select_cells(HexRecipePolicy.selection_shape(310, target, Vector2i(0, -1000)))
			steam_regions.append(selected)
			if selected.is_empty():
				reasons["empty_steam_selection"] = true
				valid = false
			for cell: Vector2i in selected:
				steam_union[cell] = true
				# Check every selected hex, not just the three target centers.
				var sample_points: Array[Vector2i] = HexGrid.vertices(cell)
				sample_points.append(HexGrid.center(cell))
				for point: Vector2i in sample_points:
					var material := kit.surface_at(Vector2(point + authority.origin) / 1000.0)
					if WellspringIllustratedKit.pixel_family(material) != family:
						mixed = true
		for first: int in 3:
			for second: int in 3:
				if first == second:
					continue
				for cell: Vector2i in lane_regions[first]:
					if lane_regions[second].has(cell) or steam_regions[second].has(cell):
						reasons["lane_interference"] = true
						valid = false
		if not _connected_cells(steam_union):
			reasons["steam_disconnected"] = true
			valid = false
		if mixed:
			mixed_candidates += 1
		if valid:
			var selected := {"targets": targets, "cells": cells, "target_axial_spacing": 3, "target_spacing_world": 192000, "target_center_family": family, "terrain_label_scope": "three target centers only; surrounding actual terrain may be mixed", "predicted_terrain_samples": _terrain_material_counts(steam_union), "mixed_predicted_terrain": mixed, "search_rejections": rejected, "terrain_material_samples": materials, "ingredient_selections": ingredient_regions, "conservative_lane_selections": lane_regions, "predicted_steam_selections": steam_regions, "predicted_steam_connected": true, "ingredient_lanes_disjoint": true, "neighbor_steam_modifier_contact_excluded": true, "surface_source": "WellspringIllustratedKit.surface_at at selected hex centers and vertices", "coverage_source": "HexChemistryWorld.select_cells with actual eligible cells and worldbone occlusion"}
			_write_terrain_search(family, rejected, mixed_candidates, selected)
			return selected
		for reason: String in reasons:
			rejected[reason] += 1
	_write_terrain_search(family, rejected, mixed_candidates, {})
	return {}


func _terrain_material_counts(cells: Dictionary) -> Dictionary:
	var families := {}
	var material_ids := {}
	for cell: Vector2i in cells:
		var points: Array[Vector2i] = HexGrid.vertices(cell)
		points.append(HexGrid.center(cell))
		for point: Vector2i in points:
			var material: int = game.campus_renderer.illustrated_kit.surface_at(Vector2(point + game.world.hex_court.origin) / 1000.0)
			var family := WellspringIllustratedKit.pixel_family(material)
			families[family] = int(families.get(family, 0)) + 1
			material_ids[str(material)] = int(material_ids.get(str(material), 0)) + 1
	return {"hex_count": cells.size(), "family_sample_counts": families, "material_id_sample_counts": material_ids, "method": "seven samples per selected hex, center plus vertices; shared vertices repeat; not area percentages"}


func _write_terrain_search(family: String, rejected: Dictionary, mixed_candidates: int, selection: Dictionary) -> void:
	var diagnostic := {"family": family, "rejection_counts": rejected, "mixed_candidates_after_lane_checks": mixed_candidates, "selection": HexChemistryWorld._stable(selection)}
	print("TERRAIN_SEARCH ", JSON.stringify(diagnostic))
	var file := FileAccess.open(output + "/terrain-" + family + "-search.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(diagnostic, "  ") + "\n")
		file.close()


static func _connected_cells(cells: Dictionary) -> bool:
	if cells.is_empty():
		return false
	var pending: Array[Vector2i] = [cells.keys()[0]]
	var visited := {}
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		if visited.has(cell):
			continue
		visited[cell] = true
		for neighbor: Vector2i in HexGrid.neighbors(cell):
			if cells.has(neighbor) and not visited.has(neighbor):
				pending.append(neighbor)
	return visited.size() == cells.size()


func _binding_views() -> bool:
	var actor: PlayerState = game._local_player_state()
	if not actor.place_proven_spell(11, 176):
		_fail("could not stage existing legal custom slot")
		return false
	var loadout_before := actor.spell_wire_ids.duplicate()
	game.player_preferences.keyboard_bindings[&"spell_1"] = KEY_Q
	game.player_preferences.keyboard_bindings[&"spell_layer_ctrl"] = KEY_SHIFT
	game.spell_loom_editor.open_editor(actor, game.ability_catalog)
	game.spell_loom_editor.selected_slot_index = 4
	for unbound: bool in [false, true]:
		if unbound:
			game.player_preferences.keyboard_bindings[&"spell_layer_ctrl"] = 0
		var label := "custom-unbound" if unbound else "custom-rebound"
		var frame := await _capture_frame("ui-" + label, "native_spell_loom", false)
		if frame.is_empty() or actor.spell_wire_ids != loadout_before or _visible_loom_wires().size() != 32:
			_fail("binding presentation changed custom loadout or 32-spell visibility")
			return false
		var labels: Array[String] = []
		for slot: int in 12:
			labels.append(SpellLoomPresenter.slot_binding_label(slot, game.player_preferences))
		ui_states.append({"fixture": label, "slot_labels": labels, "loadout": Array(loadout_before), "custom_slot_retained": true, "frame": frame.file, "interaction": "staged transient settings, not user rebind interaction"})
	game.spell_loom_editor.close_editor()
	return true


func _motion_boards() -> bool:
	game.hide()
	var board := MotionBoard.new()
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	board.presenter = game.cartoon_champion_presenter
	board.config = game.world.config
	root.add_child(board)
	for case_name: String in MOTION_CASES:
		board.label = case_name
		board.actors.clear()
		board.champions.clear()
		var snapshots: Array = []
		for row: int in 2:
			for champion: String in BODY_IDS:
				var actor := _motion_actor(champion, case_name, row)
				board.actors.append(actor)
				board.champions.append(champion)
				snapshots.append(Array(actor.canonical_values()))
		board.queue_redraw()
		var frame := await _capture_frame("motion-" + case_name, "controlled_production_pose", true)
		if frame.is_empty() or board.draw_failures > 0:
			_fail("production body fixture did not render")
			return false
		for index: int in board.actors.size():
			if Array(board.actors[index].canonical_values()) != snapshots[index]:
				_fail("body draw mutated held state")
				return false
		motion_records.append({"case": case_name, "champions": BODY_IDS, "phases": [0.0, 0.5], "states": snapshots, "frame": frame.file, "method": "held source-confirmed state fields, not input sequence; opposing aim is endpoints only"})
	board.queue_free()
	await process_frame
	game.show()
	return true


func _motion_actor(champion: String, case_name: String, row: int) -> PlayerState:
	# Same controlled-state method as capture_template_motion.make_actor.
	var actor := PlayerState.new(1)
	game.champion_catalog.apply_to_player(actor, champion)
	actor.spawn_protection_ticks = 0
	actor.aim_x = 0
	actor.aim_y = -1000
	actor.velocity_x = 0
	actor.velocity_y = -300000
	actor.movement_mode = PlayerState.MovementMode.SPRINT
	if case_name in ["strafe", "opposing_aim"]:
		actor.velocity_x = 300000
		actor.velocity_y = 0
	if case_name == "backward":
		actor.velocity_y = 300000
	if case_name == "opposing_aim":
		actor.aim_x = 1000 if row == 0 else -1000
		actor.aim_y = 0
	if case_name == "slide":
		actor.movement_mode = PlayerState.MovementMode.SLIDE
		actor.slide_ticks = 12
	if case_name == "airborne_cast":
		actor.air_height = 20000
		actor.movement_mode = PlayerState.MovementMode.HOP
		actor.pending_cast_wire_id = actor.primary_wire_id
		actor.pending_cast_ticks = 4
	return actor
