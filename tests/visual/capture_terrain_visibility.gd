extends SceneTree

# Native visible-backend capture for the opaque terrain-replacement POV mask.
# This helper intentionally uses the production Bootstrap draw and Wellspring
# world. A synthetic magenta canary is submitted immediately before the mask;
# consecutive baseline/canary frames establish whether the mask fully replaces
# those pixels. Product insertion below is presentation geometry only. Paid
# formation, authority validity and networking are covered by separate suites.
const BootstrapScript = preload("res://src/app/bootstrap.gd")
const WIDTH := 1280
const HEIGHT := 720
const CROP_RADIUS := 10
const SURFACE_CROP_RADIUS := 24
const CANARY_RADIUS := 7.0
const MIN_VISIBLE_CHANGED_PIXELS := 64
const MIN_COVER_SURFACE_CHANGED_PIXELS := 16
const PRODUCT_ID := 9001
const ZOOMS: Array[int] = [50, 75, 100]
const CANARY_COLOR := Color(1.0, 0.0, 0.82, 1.0)
const APPROACH_DIRECTIONS: Array[Vector2] = [
	Vector2(1.0, 0.0),
	Vector2(0.7071067811865476, 0.7071067811865476),
	Vector2(0.0, 1.0),
	Vector2(-0.7071067811865476, 0.7071067811865476),
	Vector2(-1.0, 0.0),
	Vector2(-0.7071067811865476, -0.7071067811865476),
	Vector2(0.0, -1.0),
	Vector2(0.7071067811865476, -0.7071067811865476),
]


class TerrainHarness extends BootstrapScript:
	var oracle_canary_enabled := false
	var oracle_canary_world := Vector2.ZERO
	var oracle_inject_early := false
	var oracle_canary_submissions := 0

	func _draw_combat_cues(camera_origin: Vector2) -> void:
		super._draw_combat_cues(camera_origin)
		if oracle_canary_enabled and oracle_inject_early:
			_draw_oracle_canary(camera_origin)

	func _draw_pov_mask(origin: Vector2, aim: Vector2, camera_origin: Vector2) -> void:
		if oracle_canary_enabled and not oracle_inject_early:
			_draw_oracle_canary(camera_origin)
		super._draw_pov_mask(origin, aim, camera_origin)

	func _draw_oracle_canary(camera_origin: Vector2) -> void:
		var zoom := _camera_zoom_scale()
		var screen := oracle_canary_world * zoom + PixelPresentation.snapped_canvas_origin(camera_origin, player_preferences.camera_zoom_percent)
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(screen - Vector2(CANARY_RADIUS, CANARY_RADIUS), Vector2(CANARY_RADIUS * 2.0 + 1.0, CANARY_RADIUS * 2.0 + 1.0)), CANARY_COLOR, true)
		oracle_canary_submissions += 1


var output := ""
var game: TerrainHarness
var fixture: Dictionary = {}
var captures: Array[Dictionary] = []
var assertions := 0
var failed := false
var source_identity := {}
var fractional_camera_cases := 0
var cover_surface_oracle := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=").replace("\\", "/")
	if DisplayServer.get_name() == "headless":
		_fail("terrain visibility capture requires a native visible display backend")
		return
	if not output.is_absolute_path() or output.begins_with("res://") or output.begins_with("user://") or ".." in output or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output):
		_fail("a fresh absolute --output directory is required")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("could not create capture output directory")
		return

	root.size = Vector2i(WIDTH, HEIGHT)
	root.visible = true
	game = TerrainHarness.new()
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	root.add_child(game)
	await process_frame
	await process_frame
	await process_frame
	game.set_process(false)
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	if game.element_audio != null:
		game.element_audio.set_process(false)
	game.show_debug_overlay = false
	game.hex_playground_open = false
	if not game.player_preferences.set_pov_mode("relative") or not game.player_preferences.set_pov_angle_degrees(PlayerPreferences.RELATIVE_SIGHT_ANGLE_DEGREES) or not game.player_preferences.set_pov_range(PlayerPreferences.RELATIVE_SIGHT_RANGE):
		_fail("production relative POV policy could not be selected")
		return
	game.world = game._new_wellspring_world(120)
	if game.world == null or game.world.hex_court == null or not (game.world.collision is HexCollisionWorld):
		_fail("production Wellspring whole-hex world is unavailable")
		return
	game.authoritative_session.world = game.world
	game.input_router.entity_id = 1
	fixture = _choose_wall_fixture()
	if fixture.is_empty():
		_fail("no authored wall supports all eight real collision-safe approaches")
		return
	source_identity = _source_identity()

	# Eight different approach bearings against one authored rectangle. The
	# alternating modes avoid claiming a Cartesian 8 x 3 x 2 coverage matrix.
	for index: int in 8:
		var approach: Dictionary = fixture.approaches[index]
		_stage_observer(approach.observer)
		if not await _capture_case("wall-approach-%d" % index, approach.hidden, true, 75, index % 2 == 1, "behind_real_wall"):
			return

	# Both visual modes at every supported zoom use the same first approach.
	var primary: Dictionary = fixture.approaches[0]
	_stage_observer(primary.observer)
	for zoom: int in ZOOMS:
		for reduced: bool in [false, true]:
			if not await _capture_case("wall-zoom-%03d-%s" % [zoom, "reduced" if reduced else "normal"], primary.hidden, true, zoom, reduced, "behind_real_wall_zoom_matrix"):
				return

	# Exact owning wall pixels must be replaced as well as its far shadow.
	for zoom: int in ZOOMS:
		_stage_observer(primary.observer)
		if not await _capture_case("inside-wall-%03d" % zoom, fixture.bounds.get_center(), true, zoom, zoom == 75, "inside_real_wall_surface"):
			return

	# An unobstructed, in-range marker proves that the canary is really drawn and
	# that the oracle can detect it through the unchanged production draw stack.
	for zoom: int in ZOOMS:
		_stage_observer(primary.observer)
		if not await _capture_case("visible-control-%03d" % zoom, primary.visible, false, zoom, zoom == 75, "visible_control"):
			return

	# Camera clamping near the left map edge keeps an out-of-range point on-screen
	# at all three zooms. LOS remains clear so this isolates the range mask.
	var range_fixture := _choose_range_fixture()
	if range_fixture.is_empty():
		_fail("no clear on-screen range fixture exists at all supported zooms")
		return
	for zoom: int in ZOOMS:
		_stage_observer(range_fixture.observer)
		if not await _capture_case("range-%03d" % zoom, range_fixture.hidden, true, zoom, zoom == 75, "outside_720_ground_units"):
			return

	# Inject one complete active Fortify presentation record and cell membership
	# to exercise the production region-to-cover-to-mask path. No paid formation
	# is claimed; the complete fixture is removed and exact authority hash restored.
	_stage_observer(primary.observer)
	game.player_preferences.set_camera_zoom_percent(75)
	game.requested_capture_reduced_effects = false
	var cover := _choose_cover_fixture(primary.observer)
	if cover.is_empty():
		_fail("no eligible visible whole cell supports the cover presentation fixture")
		return
	var hash_before_cover := game.world.state_hash()
	var cover_restore := {
		"cell": (game.world.hex_court.cells[cover.cell] as Dictionary).duplicate(true),
		"value_revision": game.world.hex_court.value_revision,
		"render_revision": game.world.hex_court.render_revision,
	}
	if not _install_cover_fixture(cover, cover_restore):
		return
	var active_regions: Array[Dictionary] = game.world.hex_court.render_regions(cover.cell, "fortify", float(game.world.tick))
	if active_regions.size() != 1 or String(active_regions[0].get("phase", "")) != "active" or int(active_regions[0].get("recipe_wire_id", 0)) != 301:
		_fail("synthetic cover did not prepare one canonical active Fortify render region")
		return
	var active_surface: Image = await _plain_frame("cover-active-surface")
	if active_surface == null:
		return
	if not _remove_cover_fixture(cover, cover_restore):
		return
	var removed_surface: Image = await _plain_frame("cover-removed-surface")
	if removed_surface == null:
		return
	if not _record_cover_surface_oracle(cover, active_regions[0], active_surface, removed_surface):
		return
	_check(game.world.state_hash() == hash_before_cover, "first synthetic cover add/remove restores exact authority hash")
	if failed or not _install_cover_fixture(cover, cover_restore):
		return
	for reduced: bool in [false, true]:
		if not await _capture_case("cover-active-%s" % ("reduced" if reduced else "normal"), cover.center, true, 75, reduced, "inside_exact_active_hex_cover"):
			return
	if not _remove_cover_fixture(cover, cover_restore):
		return
	_check(game.world.state_hash() == hash_before_cover, "synthetic cover add/remove restores exact authority hash")
	if failed:
		return
	for reduced: bool in [false, true]:
		if not await _capture_case("cover-removed-%s" % ("reduced" if reduced else "normal"), cover.center, false, 75, reduced, "same_cell_after_cover_removal"):
			return

	# A defeated local player is not a valid observer. The production method must
	# replace the complete viewport; use a normally visible target as the canary.
	_stage_observer(primary.observer)
	var observer := game.world.player(1)
	var original_health := observer.health
	observer.health = 0
	for reduced: bool in [false, true]:
		if not await _capture_case("observer-invalid-%s" % ("reduced" if reduced else "normal"), primary.visible, true, 75, reduced, "invalid_dead_observer_full_viewport"):
			return
	observer.health = original_health

	# Missing local authority returns before the ordinary mask call. Inject once
	# after combat cues (still before the regular mask) and prove that hook with a
	# living visible control before removing the actor. The missing-actor case then
	# exercises Bootstrap's own full-viewport fail-closed return branch.
	_stage_observer(primary.observer)
	game.oracle_inject_early = true
	if not await _capture_case("early-hook-visible-control", primary.visible, false, 75, false, "visible_control_for_pre_return_hook"):
		return
	var local_actor := game.world.player(1)
	var hash_before_missing := game.world.state_hash()
	game.world.players.erase(local_actor)
	if not await _capture_case("observer-missing-local", primary.visible, true, 75, false, "missing_local_actor_full_viewport"):
		return
	game.world.players.append(local_actor)
	game.oracle_inject_early = false
	_check(game.world.state_hash() == hash_before_missing, "missing-local fixture restores exact authority hash")

	_check(fractional_camera_cases > 0, "at least one capture uses a noninteger camera origin")
	_check(game.oracle_canary_submissions == captures.size(), "exactly one canary submission occurred for each after frame")
	if failed:
		return
	var receipt := {
		"schema_version": 1,
		"status": "native_opaque_terrain_visibility_capture_complete",
		"engine": Engine.get_version_info().get("string", ""),
		"display_server": DisplayServer.get_name(),
		"window": [WIDTH, HEIGHT],
		"map_id": game.world.map_id,
		"map_hash": game.world.map_hash,
		"pov": {"mode": game.player_preferences.pov_mode, "angle_degrees": game.player_preferences.pov_angle_degrees, "range": game.player_preferences.pov_range},
		"fixture": _json_fixture(),
		"captures": captures,
		"cover_surface_oracle": cover_surface_oracle,
		"assertions": assertions,
		"failures": 0,
		"fractional_camera_cases": fractional_camera_cases,
		"source_identity": source_identity,
		"helper_sha256": FileAccess.get_sha256(get_script().resource_path),
		"runtime_identity": _runtime_identity(),
		"method": "Native production Bootstrap draw. Before cover canary frames, a complete synthetic active Fortify presentation region must visibly differ from the same restored cell without cover. A test subclass then draws a 15x15 magenta canary immediately before super._draw_pov_mask. The missing-local branch uses an earlier after-combat-cues hook because Bootstrap returns before the ordinary mask; that hook has its own living visible control. Each case compares consecutive baseline/canary viewport crops: hidden cases require byte-identical pixels; visible controls require at least %d changed pixels. Every pair requires an unchanged SimWorld state hash and unchanged runtime object identities." % MIN_VISIBLE_CHANGED_PIXELS,
		"coverage": ["eight bearings around one authored los_cutaway wall", "normal and reduced modes at 50/75/100 zoom", "fractional camera origin", "inside authored wall surface", "clear in-range visible control", "clear point outside 720 projected ground units", "inside one exact active Rampart hex and the same cell after removal", "dead local observer fail-closed", "missing local actor full-viewport fallback with separately proven early injection hook"],
		"not_run": ["real spectator viewpoint: requires a connected-client/session fixture; no fake _is_spectating override is used", "paid cover formation and removal", "multiplayer information filtering", "headless rendering", "performance profiling", "human visual acceptance"],
		"evidence_limits": ["Local native presentation only", "The complete Fortify record and material membership are explicitly injected into trusted local authority for presentation geometry and are not proof of a paid recipe journey", "Consecutive pixel equality proves the canary was replaced in the sampled crop; it does not prove every hidden world pixel or GPU/backend", "Eight approaches share one authored rectangular wall selected at runtime", "Normal/reduced and zoom cases reuse deterministic staged authority rather than player navigation", "Spectator, networking, exported-build, hardware and release acceptance remain separate"],
		"profile_storage": "transient preferences; runner must provide isolated APPDATA because production Bootstrap initializes preferences before the helper disables persistence",
	}
	var receipt_path := output.path_join("capture-receipt.json")
	var file := FileAccess.open(receipt_path, FileAccess.WRITE)
	if file == null:
		_fail("could not write capture receipt")
		return
	file.store_string(JSON.stringify(receipt, "  ") + "\n")
	file.close()
	print("PASS opaque terrain visibility native capture cases=%d assertions=%d output=%s" % [captures.size(), assertions, output])
	quit(0)


func _choose_wall_fixture() -> Dictionary:
	var opaque := _opaque_bounds()
	for building_id: int in [103, 106, 101, 105, 104, 107, 108, 109]:
		var building: Dictionary = game.campus_layout.buildings_by_id.get(building_id, {})
		if building.is_empty() or String(building.get("occlusion_policy", "")) != "los_cutaway":
			continue
		var bounds := Rect2(SanctumCampusLayout._parse_bounds(building.bounds))
		var center := bounds.get_center()
		var approaches: Array[Dictionary] = []
		for raw_direction: Vector2 in APPROACH_DIRECTIONS:
			var direction := raw_direction.normalized()
			var tx := INF if is_zero_approx(direction.x) else bounds.size.x * 0.5 / absf(direction.x)
			var ty := INF if is_zero_approx(direction.y) else bounds.size.y * 0.5 / absf(direction.y)
			var edge_distance := minf(tx, ty)
			var observer := center + direction * (edge_distance + 92.0) + Vector2(0.375, 0.625)
			var hidden := center - direction * (edge_distance + 70.0) + Vector2(0.125, 0.375)
			var visible := observer + direction.rotated(PI * 0.5) * 96.0
			if not game.world.collision.can_occupy(Vector2i(observer * SimConfig.FIXED_SCALE), 18_000):
				approaches.clear()
				break
			if SightOcclusion.line_clear(observer, hidden, opaque) or not SightOcclusion.line_clear(observer, visible, opaque):
				approaches.clear()
				break
			if not _screen_safe(observer, hidden, 75) or not _screen_safe(observer, visible, 75):
				approaches.clear()
				break
			approaches.append({"observer": observer, "hidden": hidden, "visible": visible, "direction": direction})
		if approaches.size() == 8:
			return {"building_id": building_id, "building_name": building.get("name", ""), "bounds": bounds, "approaches": approaches, "opaque": opaque}
	return {}


func _choose_range_fixture() -> Dictionary:
	var opaque := _opaque_bounds()
	for y: int in range(360, game.campus_layout.canvas_size.y - 160, 80):
		for x: int in range(96, 420, 48):
			var observer := Vector2(float(x) + 0.375, float(y) + 0.625)
			if not game.world.collision.can_occupy(Vector2i(observer * SimConfig.FIXED_SCALE), 18_000):
				continue
			for delta: Vector2 in [Vector2(760.5, 0.25), Vector2(-760.5, 0.25)]:
				var target := observer + delta
				if target.x < 16.0 or target.y < float(game.campus_layout.reserved_ui_top) + 16.0 or target.x >= game.campus_layout.canvas_size.x - 16.0 or target.y >= game.campus_layout.canvas_size.y - 16.0:
					continue
				if not SightOcclusion.line_clear(observer, target, opaque):
					continue
				var all_visible := true
				for zoom: int in ZOOMS:
					if not _screen_safe(observer, target, zoom):
						all_visible = false
				if all_visible and SightOcclusion.inverse_project_ground(target - observer).length() > float(PlayerPreferences.RELATIVE_SIGHT_RANGE) + 20.0:
					return {"observer": observer, "hidden": target}
	return {}


func _choose_cover_fixture(observer: Vector2) -> Dictionary:
	var opaque := _opaque_bounds()
	var cells: Array = game.world.hex_court.cells.keys()
	cells.sort_custom(HexGrid._cell_less)
	for cell_value: Variant in cells:
		var cell: Vector2i = cell_value
		var center := Vector2(game.world.hex_court.origin + HexGrid.center(cell)) / SimConfig.FIXED_SCALE
		var distance := SightOcclusion.inverse_project_ground(center - observer).length()
		if distance < 150.0 or distance > 480.0 or not SightOcclusion.line_clear(observer, center, opaque) or not _screen_safe(observer, center, 75):
			continue
		var screen := _screen_position(observer, center, 75)
		# Stay clear of both the top status bar and bottom combat HUD so the
		# active/removed surface comparison observes the court itself.
		if screen.x < 240.0 or screen.x > 1040.0 or screen.y < 180.0 or screen.y > 500.0:
			continue
		return {"cell": cell, "center": center, "screen": screen}
	return {}


func _install_cover_fixture(cover: Dictionary, restore: Dictionary) -> bool:
	if game.world.hex_court.products.has(PRODUCT_ID):
		_fail("synthetic cover product id is already occupied")
		return false
	var tick: int = game.world.tick
	game.world.hex_court.products[PRODUCT_ID] = {
		"id": PRODUCT_ID,
		"recipe_wire_id": 301,
		"material": "fortify",
		"strength": 12,
		"source_ids": [7001, 7002],
		"footprint": {"kind": "cell", "center": game.world.hex_court.origin + HexGrid.center(cover.cell)},
		"cells": {cover.cell: 1_200},
		"coverage": {cover.cell: 1},
		"quantity": 1_200,
		"created": tick - 24,
		"formation_tick": tick - 24,
		"active_tick": tick,
		"decay_tick": tick + 120,
		"expiry_tick": tick + 180,
		"expires": tick + 180,
		"intensity": 1_200,
		"heated": false,
		"cooled": false,
		"flow_aim": Vector2i(0, -1000),
		"flow_units_per_second": 0,
		"common_wall_clearance": 18_000,
		"pulse_ms": 0,
		"pulse_damage": 0,
		"geometry_override": "whole_hex",
		"owner": 1,
		"team": 1,
		"health": 32_000,
		"capacity": 0,
		"position": game.world.hex_court.origin + HexGrid.center(cover.cell),
		"origin": game.world.hex_court.origin + HexGrid.center(cover.cell),
		"contacts": {},
		"linked_sources": [],
		"pulse_index": -1,
		"last_motion_tick": tick,
		"motion_carry": Vector2i.ZERO,
	}
	game.world.hex_court.cells[cover.cell]["fortify"][PRODUCT_ID] = 1_200
	game.world.hex_court.value_revision = int(restore.value_revision) + 1
	# Layer changes deliberately leave the topology revision unchanged.
	game.world.hex_court.render_revision = int(restore.render_revision)
	if not game.world.collision.set_hex_surfaces(game.world.hex_court, tick) or game.world.collision.hex_occluders().size() != 1:
		_fail("complete synthetic active cover did not publish exactly one production hex occluder")
		return false
	return true


func _remove_cover_fixture(cover: Dictionary, restore: Dictionary) -> bool:
	game.world.hex_court.products.erase(PRODUCT_ID)
	game.world.hex_court.cells[cover.cell] = (restore.cell as Dictionary).duplicate(true)
	game.world.hex_court.value_revision = int(restore.value_revision)
	game.world.hex_court.render_revision = int(restore.render_revision)
	if not game.world.collision.set_hex_surfaces(game.world.hex_court, game.world.tick) or not game.world.collision.hex_occluders().is_empty():
		_fail("cover removal did not clear production hex occluders")
		return false
	if not game.world.hex_court.render_regions(cover.cell, "fortify", float(game.world.tick)).is_empty():
		_fail("cover removal left a Fortify presentation region")
		return false
	return true


func _plain_frame(label: String) -> Image:
	var identity_before := _object_identity()
	var state_before := game.world.state_hash()
	game.oracle_canary_enabled = false
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if not _valid_image(image) or game.world.state_hash() != state_before or _object_identity() != identity_before:
		_fail("plain surface frame failed or changed authority/source identities: " + label)
		return null
	return image


func _record_cover_surface_oracle(cover: Dictionary, region: Dictionary, active: Image, removed: Image) -> bool:
	var crop := Rect2i(Vector2i(roundi(cover.screen.x), roundi(cover.screen.y)) - Vector2i(SURFACE_CROP_RADIUS, SURFACE_CROP_RADIUS), Vector2i(SURFACE_CROP_RADIUS * 2 + 1, SURFACE_CROP_RADIUS * 2 + 1))
	var active_crop := active.get_region(crop)
	var removed_crop := removed.get_region(crop)
	var changed := _changed_pixels(active_crop, removed_crop)
	if changed < MIN_COVER_SURFACE_CHANGED_PIXELS:
		_fail("prepared active Fortify surface changed only %d pixels versus removed terrain" % changed)
		return false
	var active_full_path := output.path_join("cover-active-surface-plain.png")
	var removed_full_path := output.path_join("cover-removed-surface-plain.png")
	var active_crop_path := output.path_join("cover-active-surface-crop.png")
	var removed_crop_path := output.path_join("cover-removed-surface-crop.png")
	if active.save_png(active_full_path) != OK or removed.save_png(removed_full_path) != OK or active_crop.save_png(active_crop_path) != OK or removed_crop.save_png(removed_crop_path) != OK:
		_fail("could not save active/removed cover surface evidence")
		return false
	cover_surface_oracle = {
		"status": "active_fortify_visibly_differs_from_removed_terrain",
		"changed_pixels": changed,
		"minimum_changed_pixels": MIN_COVER_SURFACE_CHANGED_PIXELS,
		"cell": [cover.cell.x, cover.cell.y],
		"world_center": [cover.center.x, cover.center.y],
		"screen_center": [cover.screen.x, cover.screen.y],
		"crop": [crop.position.x, crop.position.y, crop.size.x, crop.size.y],
		"outside_hud_bounds": cover.screen.x >= 240.0 and cover.screen.x <= 1040.0 and cover.screen.y >= 180.0 and cover.screen.y <= 500.0,
		"prepared_region": {"phase": region.get("phase", ""), "material": region.get("material", ""), "recipe_wire_id": region.get("recipe_wire_id", 0), "quantity": region.get("quantity", 0), "intensity": region.get("intensity", 0)},
		"active_full_file": active_full_path.get_file(),
		"active_full_sha256": FileAccess.get_sha256(active_full_path),
		"removed_full_file": removed_full_path.get_file(),
		"removed_full_sha256": FileAccess.get_sha256(removed_full_path),
		"active_crop_file": active_crop_path.get_file(),
		"active_crop_sha256": FileAccess.get_sha256(active_crop_path),
		"removed_crop_file": removed_crop_path.get_file(),
		"removed_crop_sha256": FileAccess.get_sha256(removed_crop_path),
	}
	assertions += 5
	return true


func _stage_observer(position: Vector2) -> void:
	var actor := game.world.player(1)
	actor.position_x = roundi(position.x * SimConfig.FIXED_SCALE)
	actor.position_y = roundi(position.y * SimConfig.FIXED_SCALE)
	actor.health = actor.health_maximum
	actor.spawn_protection_ticks = 0
	actor.aim_x = 1000
	actor.aim_y = 0
	game.current_position = Vector2(actor.position_x, actor.position_y) / SimConfig.FIXED_SCALE
	game.previous_position = game.current_position
	game.previous_air_height = 0
	game.accumulator_seconds = 0.0
	game._reset_motion_history()


func _capture_case(label: String, canary_world: Vector2, expect_hidden: bool, zoom: int, reduced: bool, reason: String) -> bool:
	game.player_preferences.set_camera_zoom_percent(zoom)
	game.requested_capture_reduced_effects = reduced
	game.oracle_canary_world = canary_world
	var camera := game._camera_origin(game._camera_focus_position(game.current_position))
	var translation := PixelPresentation.snapped_canvas_origin(camera, zoom)
	var screen := canary_world * (float(zoom) / 100.0) + translation
	if not _point_in_capture(screen):
		_fail("canary crop is outside the viewport: %s at %s" % [label, screen])
		return false
	if not is_equal_approx(camera.x, roundf(camera.x)) or not is_equal_approx(camera.y, roundf(camera.y)):
		fractional_camera_cases += 1
	var identity_before := _object_identity()
	var state_before := game.world.state_hash()
	game.oracle_canary_enabled = false
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var baseline: Image = root.get_texture().get_image()
	if not _valid_image(baseline):
		_fail("baseline frame capture failed: " + label)
		return false
	if game.world.state_hash() != state_before or _object_identity() != identity_before:
		_fail("baseline draw changed authority or source identities: " + label)
		return false
	game.oracle_canary_enabled = true
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var after: Image = root.get_texture().get_image()
	game.oracle_canary_enabled = false
	if not _valid_image(after) or game.world.state_hash() != state_before or _object_identity() != identity_before:
		_fail("canary draw failed or changed authority/source identities: " + label)
		return false
	var region := _crop_rect(screen)
	var baseline_crop := baseline.get_region(region)
	var after_crop := after.get_region(region)
	var changed := _changed_pixels(baseline_crop, after_crop)
	if expect_hidden and changed != 0:
		_fail("hidden canary leaked %d changed pixels: %s" % [changed, label])
		return false
	if not expect_hidden and changed < MIN_VISIBLE_CHANGED_PIXELS:
		_fail("visible control changed only %d pixels: %s" % [changed, label])
		return false
	var stem := _safe_name(label)
	var frame_path := output.path_join(stem + "-canary.png")
	var before_path := output.path_join(stem + "-before-crop.png")
	var after_path := output.path_join(stem + "-after-crop.png")
	if after.save_png(frame_path) != OK or baseline_crop.save_png(before_path) != OK or after_crop.save_png(after_path) != OK:
		_fail("could not save capture evidence: " + label)
		return false
	captures.append({
		"label": label,
		"reason": reason,
		"injection_stage": "after_combat_cues_before_missing_actor_return" if game.oracle_inject_early else "immediately_before_pov_mask",
		"expect_hidden": expect_hidden,
		"changed_pixels": changed,
		"full_canary_file": frame_path.get_file(),
		"full_canary_sha256": FileAccess.get_sha256(frame_path),
		"before_crop_file": before_path.get_file(),
		"before_crop_sha256": FileAccess.get_sha256(before_path),
		"after_crop_file": after_path.get_file(),
		"after_crop_sha256": FileAccess.get_sha256(after_path),
		"crop": [region.position.x, region.position.y, region.size.x, region.size.y],
		"canary_world": [canary_world.x, canary_world.y],
		"canary_screen": [screen.x, screen.y],
		"observer_world": [game.current_position.x, game.current_position.y],
		"camera_origin": [camera.x, camera.y],
		"snapped_canvas_translation": [translation.x, translation.y],
		"fractional_camera_origin": not is_equal_approx(camera.x, roundf(camera.x)) or not is_equal_approx(camera.y, roundf(camera.y)),
		"zoom_percent": zoom,
		"reduced": reduced,
		"world_state_hash": state_before,
	})
	assertions += 5
	return true


func _screen_safe(observer: Vector2, target: Vector2, zoom: int) -> bool:
	return _point_in_capture(_screen_position(observer, target, zoom))


func _screen_position(observer: Vector2, target: Vector2, zoom: int) -> Vector2:
	var camera := BootstrapScript.camera_origin_for(observer, Vector2i(WIDTH, HEIGHT), game.campus_layout.canvas_size, game.campus_layout.reserved_ui_top, zoom)
	return target * (float(zoom) / 100.0) + PixelPresentation.snapped_canvas_origin(camera, zoom)


func _point_in_capture(point: Vector2) -> bool:
	return point.x >= CROP_RADIUS + 2 and point.x < WIDTH - CROP_RADIUS - 2 and point.y >= CROP_RADIUS + 2 and point.y < HEIGHT - CROP_RADIUS - 2


func _crop_rect(center: Vector2) -> Rect2i:
	var origin := Vector2i(roundi(center.x), roundi(center.y)) - Vector2i(CROP_RADIUS, CROP_RADIUS)
	return Rect2i(origin, Vector2i(CROP_RADIUS * 2 + 1, CROP_RADIUS * 2 + 1))


func _changed_pixels(before: Image, after: Image) -> int:
	var changed := 0
	for y: int in before.get_height():
		for x: int in before.get_width():
			if before.get_pixel(x, y) != after.get_pixel(x, y):
				changed += 1
	return changed


func _valid_image(image: Image) -> bool:
	return image != null and not image.is_empty() and image.get_size() == Vector2i(WIDTH, HEIGHT)


func _opaque_bounds() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for value: Variant in game.campus_layout.data.get("buildings", []):
		var building: Dictionary = value
		if String(building.get("occlusion_policy", "")) == "los_cutaway":
			result.append(Rect2(SanctumCampusLayout._parse_bounds(building.get("bounds", []))))
	return result


func _object_identity() -> Dictionary:
	return {
		"world": game.world.get_instance_id(),
		"hex_court": game.world.hex_court.get_instance_id(),
		"collision": game.world.collision.get_instance_id(),
		"campus_layout": game.campus_layout.get_instance_id(),
		"terrain_backdrop": game.pov_terrain_backdrop.get_instance_id() if game.pov_terrain_backdrop != null else 0,
	}


func _source_identity() -> Dictionary:
	return {
		"objects": _object_identity(),
		"map_id": game.world.map_id,
		"map_hash": game.world.map_hash,
		"topology_cells": game.world.hex_court.cells.size(),
		"source_sha256": _sources(),
	}


func _sources() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for path: String in ["res://src/app/bootstrap.gd", "res://src/presentation/pov_terrain_backdrop.gd", "res://src/presentation/sight_occlusion.gd", "res://src/presentation/pixel_presentation.gd", "res://src/sim/hex/hex_collision_world.gd", "res://content/maps/sanctum_campus_g2_v1.json"]:
		var readable := FileAccess.file_exists(path)
		result.append({"path": path, "raw_file_available": readable, "sha256": FileAccess.get_sha256(path) if readable else "", "note": "export may remap script source" if not readable else ""})
	return result


func _json_fixture() -> Dictionary:
	var bounds: Rect2 = fixture.bounds
	var approaches: Array[Dictionary] = []
	for approach: Dictionary in fixture.approaches:
		approaches.append({"observer": [approach.observer.x, approach.observer.y], "hidden": [approach.hidden.x, approach.hidden.y], "visible": [approach.visible.x, approach.visible.y], "direction": [approach.direction.x, approach.direction.y]})
	return {"building_id": fixture.building_id, "building_name": fixture.building_name, "bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y], "occlusion_policy": "los_cutaway", "approaches": approaches, "authored_geometry_unchanged": true}


func _runtime_identity() -> Variant:
	var path := "res://content/runtime/runtime_build_identity_v1.json"
	return JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {"status": "not_available_in_mounted_pack"}


func _safe_name(value: String) -> String:
	return value.to_lower().replace(" ", "-").replace("_", "-")


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	if failed:
		return
	failed = true
	push_error(message)
	quit(1)
