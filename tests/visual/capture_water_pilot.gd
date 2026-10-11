extends SceneTree

# External-script compatible against source or an exact mounted Windows PCK.
# Isolated APPDATA must be provided by the lead's runner before Bootstrap starts.
# Only initial location and pointer are arranged. InputRouter/Bootstrap own the
# spell request, resource payment, launch, collision, material and natural expiry.
const Bootstrap = preload("res://src/app/bootstrap.gd")
const HEAVY_WATER := 181
const MAX_TICKS := 1200
var game: Node2D
var output := ""
var frames: Array[Dictionary] = []
var events: Array[Dictionary] = []
var checks: Array[Dictionary] = []
var pixel_pairs: Array[Dictionary] = []
var failed := false
var reached: Dictionary = {}
var startup_payment: Dictionary = {}
var launch_tick := -1
var impact_tick := -1
var previous_flights: Dictionary = {}
var observed_projectiles: Dictionary = {}
var terminal_parts: Dictionary = {}
var previous_deposited := 0
var terminal_commitments: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or output.is_empty() or ".." in output or DirAccess.dir_exists_absolute(output):
		print("FAIL: Water capture requires native rendering and a fresh explicit output directory")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.visible = true
	game = Bootstrap.new()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	game.requested_capture_reduced_effects = false
	if game.element_audio != null: game.element_audio.set_process(false)
	if not _check(game.world != null and game.world.hex_court != null, "production Wellspring authority initialized"):
		await _finish()
		return
	var actor: PlayerState = game._local_player_state()
	var slot := actor.spell_wire_ids.find(HEAVY_WATER)
	if not _check(slot >= 0 and slot < 4, "isolated starter weave exposes Tide Shell in an ordinary first-four slot"):
		await _finish()
		return
	# Existing chemistry bench; no actor/effect/chemistry is added to the world.
	var bench := HexPlaygroundDemo.BENCH
	if not _check(game.world.collision.can_occupy(bench, MovementTuning.PLAYER_RADIUS), "existing bench is clear"):
		await _finish()
		return
	actor.position_x = bench.x
	actor.position_y = bench.y
	actor.position_remainder_x = 0
	actor.position_remainder_y = 0
	game.capture_pointer_world = Vector2i(HexPlaygroundDemo.TARGET / 1000)
	game.current_position = game._player_position()
	game.previous_position = game.current_position
	game._reset_motion_history()
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game.player_preferences.set_camera_zoom_percent(75)
	for warmup: int in 4: game._process(1.0 / 120.0)
	await process_frame
	if not _check(not game._gameplay_input_blocked(), "ordinary gameplay input is available"):
		await _finish()
		return
	if not _check(game.hex_court_presenter.water_material.ready(), "runtime loaded and verified both Water atlas resources: " + game.hex_court_presenter.water_material.last_error):
		await _finish()
		return
	await _capture_modes("before", false)
	var flux_before := actor.flux
	var paid_before := int(game.world.hex_court.metrics.get("matter_paid", 0))
	var action := StringName("spell_%d" % (slot + 1))
	Input.action_press(action)
	_advance_observed_step()
	Input.action_release(action)
	startup_payment = {"action": String(action), "slot": slot + 1, "wire_id": HEAVY_WATER, "flux_before": flux_before, "flux_after_admission": actor.flux, "paid_before": paid_before, "paid_after": int(game.world.hex_court.metrics.get("matter_paid", 0)), "pending_wire": actor.pending_cast_wire_id}
	_check(actor.pending_cast_wire_id == HEAVY_WATER and actor.flux < flux_before, "ordinary spell input admitted a positive-cost Water Heavy")
	_check(int(startup_payment.paid_after) - paid_before == 600, "paid chemistry admission reserves exactly600 matter")
	await _capture_modes("startup", false)
	for step: int in MAX_TICKS:
		if failed: break
		_advance_observed_step()
		var regions := _water_regions()
		var phases := {}
		for region: Dictionary in regions:
			if terminal_parts.has(int(region.footprint_id)): phases[String(region.phase)] = true
		if launch_tick >= 0 and not reached.has("launch"):
			reached.launch = true
			await _capture_modes("launch", false)
		elif launch_tick >= 0 and game.world.tick >= launch_tick + 3 and not game.world.projectiles.is_empty() and not reached.has("travel"):
			reached.travel = true
			await _capture_modes("travel", false)
		if impact_tick >= 0 and not reached.has("impact"):
			reached.impact = true
			await _capture_modes("impact", true)
		for phase: String in ["forming", "active", "decaying"]:
			if phases.has(phase) and not reached.has(phase):
				reached[phase] = true
				await _capture_modes(phase, true)
				if phase == "active":
					game.player_preferences.set_camera_zoom_percent(50)
					await _capture_modes("active-zoom50", true)
					game.player_preferences.set_camera_zoom_percent(75)
		if reached.has("decaying") and regions.is_empty() and game.world.projectiles.is_empty():
			reached.expired = true
			await _capture_modes("expired", true)
			break
		if step % 24 == 0: await process_frame
	for required: String in ["launch", "travel", "impact", "forming", "active", "decaying", "expired"]:
		_check(reached.has(required), "paid journey reached " + required)
	_check(terminal_commitments.size() == 1, "single paid Heavy commits exactly one observed terminal footprint")
	_check(game.world.hex_court.conservation_valid(), "Water journey conserves finite paid material")
	_check(int(game.world.hex_court.metrics.get("matter_paid", 0)) - paid_before == 600, "journey admitted one paid cast only")
	await _finish()


func _advance_observed_step() -> void:
	# SimWorld processes the current tick, then increments tick before returning.
	# Snapshot the actual pre-step boundary; do not infer it from render frames.
	var processed_tick: int = game.world.tick
	previous_flights.clear()
	for cast: Dictionary in game.world.hex_court.casts.values():
		if int(cast.get("wire", 0)) == HEAVY_WATER and bool(cast.get("paid", false)):
			previous_flights[int(cast.get("source", 0))] = (cast.flight_parts as Dictionary).duplicate(true)
	previous_deposited = int(game.world.hex_court.metrics.get("deposited", 0))
	game._process(1.0 / 120.0)
	if not _check(game.world.tick == processed_tick + 1, "capture application step advances exactly one simulation tick"):
		return
	_record_events(processed_tick)


func _record_events(processed_tick: int) -> void:
	for event: Dictionary in game.world.combat_events:
		var kind := String(event.get("type", ""))
		if kind in ["cast_started", "projectile_spawned", "projectile_hit", "projectile_impact", "projectile_terminal", "cast_refused", "cast_blocked"]:
			var copy := event.duplicate(true)
			copy["observed_world_tick"] = game.world.tick
			copy["processed_tick"] = processed_tick
			events.append(copy)
		if kind == "projectile_spawned" and int(event.get("wire_id", 0)) == HEAVY_WATER:
			launch_tick = game.world.tick
			observed_projectiles[int(event.projectile_id)] = true
	_observe_terminal_commitment(processed_tick)


func _observe_terminal_commitment(processed_tick: int) -> void:
	# SimWorld consumes projectile_terminal internally before publishing events.
	# Observe its real paid flight -> non-trail ground transition at this tick;
	# trail creation alone must never satisfy the terminal impact requirement.
	var authority: HexChemistryWorld = game.world.hex_court
	var live_projectiles := {}
	for shot: ProjectileState in game.world.projectiles: live_projectiles[shot.entity_id] = true
	for cast: Dictionary in authority.casts.values():
		if int(cast.get("wire", 0)) != HEAVY_WATER or not bool(cast.get("paid", false)): continue
		var source := int(cast.get("source", 0))
		for part_id: int in cast.ground_parts:
			var part: Dictionary = cast.ground_parts[part_id]
			if bool(part.trail) or int(part.created) != processed_tick or terminal_parts.has(part_id): continue
			var before: Dictionary = previous_flights.get(source, {})
			var committed: bool = observed_projectiles.has(source) and before.has(source) and int(before[source]) > 0 and not cast.flight_parts.has(source) and not live_projectiles.has(source) and int(part.quantity) > 0 and not part.coverage.is_empty() and int(authority.metrics.get("deposited", 0)) == previous_deposited + 1
			_check(committed, "real source projectile flight commits a positive non-trail terminal footprint")
			if not committed: continue
			impact_tick = game.world.tick
			terminal_parts[part_id] = true
			terminal_commitments.append({"observation": "paid terminal authority transition; private terminal event consumed by SimWorld", "processed_tick": processed_tick, "observed_world_tick": game.world.tick, "source_projectile_id": source, "cast_id": int(cast.id), "wire_id": int(cast.wire), "owner": int(cast.owner), "flight_before": before.duplicate(true), "flight_after": (cast.flight_parts as Dictionary).duplicate(true), "projectile_absent_after": true, "ground_part_id": part_id, "ground_part": part.duplicate(true), "deposited_before": previous_deposited, "deposited_after": int(authority.metrics.get("deposited", 0))})


func _water_regions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var authority: HexChemistryWorld = game.world.hex_court
	var cells := {}
	for cast: Dictionary in authority.casts.values():
		if int(cast.get("element", 0)) != 3: continue
		for part: Dictionary in cast.get("ground_parts", {}).values():
			for cell: Vector2i in part.get("coverage", {}): cells[cell] = true
	var ordered: Array = cells.keys()
	ordered.sort_custom(HexGrid._cell_less)
	for cell: Vector2i in ordered:
		for region: Dictionary in authority.render_regions(cell, "water", float(game.world.tick)):
			var record := region.duplicate(true)
			record["cell"] = cell
			result.append(record)
	return result


func _capture_modes(label: String, compare_baseline: bool) -> void:
	var authority_before: String = game.world.state_hash()
	var regions_before := _water_regions()
	for reduced: bool in [false, true]:
		game.requested_capture_reduced_effects = reduced
		var baseline: Image = null
		for enabled: bool in ([false, true] if compare_baseline else [true]):
			game.hex_court_presenter.water_motifs_enabled = enabled
			game.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var screenshot := root.get_texture().get_image()
			var file_name := "%s-%s-%s.png" % [label, "reduced" if reduced else "normal", "pilot" if enabled else "baseline-marks"]
			var path := output.path_join(file_name)
			_check(screenshot != null and not screenshot.is_empty() and screenshot.save_png(path) == OK, "native capture saved " + file_name)
			_check(game.world.state_hash() == authority_before and _water_regions() == regions_before, "effects/baseline rendering preserves identical whole-cell authority")
			_check(game.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "shared production canvas resolves nearest filtering")
			if compare_baseline:
				if not enabled:
					baseline = screenshot
				else:
					var changed := _changed_pixels(baseline, screenshot)
					pixel_pairs.append({"stage": label, "reduced": reduced, "changed_pixels": changed, "scope": "entire matched native frame", "world_hash": authority_before})
					if label in ["forming", "active", "decaying", "active-zoom50"]:
						_check(changed > 0, "occupied " + label + " pilot visibly differs from baseline marks")
					elif label == "expired":
						_check(changed == 0, "expired pilot and baseline match exactly with no residual Water pixels")
			frames.append({"file": file_name, "sha256": FileAccess.get_sha256(path), "tick": game.world.tick, "zoom_percent": game.player_preferences.camera_zoom_percent, "reduced": reduced, "pilot_enabled": enabled, "world_hash": authority_before, "regions": regions_before, "projectiles": _projectile_evidence(), "canvas_texture_filter": game.texture_filter, "loaded": game.hex_court_presenter.water_material.evidence()})
	game.hex_court_presenter.water_motifs_enabled = true
	game.requested_capture_reduced_effects = false


static func _changed_pixels(first: Image, second: Image) -> int:
	if first == null or second == null or first.get_size() != second.get_size(): return -1
	var a := first.duplicate() as Image
	var b := second.duplicate() as Image
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var left := a.get_data()
	var right := b.get_data()
	var changed := 0
	for index: int in range(0, left.size(), 4):
		if left[index] != right[index] or left[index + 1] != right[index + 1] or left[index + 2] != right[index + 2] or left[index + 3] != right[index + 3]:
			changed += 1
	return changed


func _projectile_evidence() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for shot: ProjectileState in game.world.projectiles:
		result.append({"id": shot.entity_id, "wire": shot.source_wire_id, "position": Vector2i(shot.position_x, shot.position_y), "remaining_strength": shot.remaining_strength, "material_strength": shot.material_strength})
	return result


func _check(condition: bool, message: String) -> bool:
	checks.append({"passed": condition, "message": message})
	if not condition:
		failed = true
		print("FAIL: " + message)
	return condition


func _finish() -> void:
	var identity: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/runtime/runtime_build_identity_v1.json"))
	var receipt := {"status": "FAILED" if failed else "PASS", "runtime_identity": identity, "display_server": DisplayServer.get_name(), "window": [root.size.x, root.size.y], "method": "production Bootstrap/InputRouter spell action at arranged existing bench; real paid authority; no effect injection; paired presentation-only marks toggle", "initial_location_arranged": true, "direct_effect_injection": false, "payment": startup_payment, "events": events, "stages": reached, "checks": checks, "frames": frames, "limits": ["scripted application input, not physical controls", "initial placement arranged; not navigation proof", "normal/reduced/baseline captures share paused identical authority", "phase columns are cosmetic; no authority timing changes", "human aesthetic acceptance and rendered performance remain separate", "no new character, reaction or balance change"]}
	receipt["source_files"] = _source_files()
	receipt["water_material"] = game.hex_court_presenter.water_material.evidence() if game != null and game.hex_court_presenter != null else {"ready": false, "last_error": "presenter unavailable"}
	receipt["pixel_pairs"] = pixel_pairs
	receipt["terminal_commitments"] = terminal_commitments
	receipt["identity_limit"] = "Embedded identity may precede this development run; raw source hashes and imported RGBA hashes identify inspected inputs. Final export requires regenerated canonical identity."
	var file := FileAccess.open(output.path_join("capture-receipt.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_json_safe(receipt), "  "))
		file.close()
	print("WATER_PILOT_CAPTURE %s frames=%d checks=%d" % ["FAILED" if failed else "PASS", frames.size(), checks.size()])
	if game != null: game.queue_free()
	await process_frame
	quit(1 if failed else 0)


static func _source_files() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for path: String in ["res://src/presentation/hex_court_presenter.gd", "res://src/presentation/hex_water_material_presenter.gd", "res://assets/sprites/hex_water_pilot_v1/manifest.json", "res://assets/sprites/hex_water_pilot_v1/water-normal.png.import", "res://assets/sprites/hex_water_pilot_v1/water-reduced.png.import", "res://src/app/bootstrap.gd", "res://src/sim/hex/hex_chemistry_world.gd"]:
		var available := FileAccess.file_exists(path)
		result.append({"path": path, "raw_file_available": available, "sha256": FileAccess.get_sha256(path) if available else "", "note": "export may remap scripts; loaded Water RGBA evidence remains required"})
	return result


static func _json_safe(value: Variant) -> Variant:
	if value is Vector2i or value is Vector2: return [value.x, value.y]
	if value is PackedVector2Array or value is Array:
		var list := []
		for item: Variant in value: list.append(_json_safe(item))
		return list
	if value is Dictionary:
		var result := {}
		for key: Variant in value: result[str(key)] = _json_safe(value[key])
		return result
	return value
