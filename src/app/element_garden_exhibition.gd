extends RefCounted
## Local, harmless exhibition authority. No live world, player, save or reward
## reference is accepted. Exhibition stock is explicit; it is not a player cast.
const Mixtures = preload("res://src/content/mixture_catalog.gd")
const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const ExhibitCourt = preload("res://src/app/element_garden_court.gd")
const MAX_RESIDENT := 63
const PLOT_RADIUS := 180.0
const INSPECTION_RADIUS := 200.0
const RESET_TICKS := 24
const TOPOLOGY_RADIUS := 4
const RESTARTS_PER_FRAME := 1
const EXHIBITION_NOTICE := "Exhibit — harmless bounded loop. No player Flux or progress is changed."
const RAW_EFFECTS := {
	1: "Earth matter remains on the ground for another elemental contact. Two Earth sources form Rampart cover.",
	2: "Fire ignites, threatens grounded actors during its active phase, then cools before disappearing.",
	4: "Water remains as contact matter. Two Water sources form Frostway; one deposit does not slow movement.",
	8: "Air remains as contact matter. Two Air sources form a Vortex; one deposit does not create flow.",
	16: "Light remains as contact matter. Two Light sources form Radiance; one deposit does not reveal actors.",
	32: "Dark remains as contact matter. Two Dark sources form Umbral Field; one deposit does not conceal actors.",
}
var last_error := ""
var _plots: Array[Dictionary] = []
var _by_mask: Dictionary = {}
var _resident: Dictionary = {}
var _inspected_mask := 0
var _frame_restart_budget := -1
var _restart_queue: Array[int] = []
var _admission_bounds := Rect2()
var _inspection_bounds := Rect2()
var _visible_view := Rect2()
var _visible_masks: Array[int] = []
var _nearest_observer := Vector2.INF
var _nearest_cached_mask := 0
var _selection_memo := ExhibitCourt.SelectionMemo.new()
var _configuration_generation := 0
var _arrival_active := false
var _arrival_view := Rect2()
var _arrival_observer := Vector2.ZERO
var _arrival_masks: Array[int] = []
var _arrival_staged: Dictionary = {}
var _arrival_first_step: Dictionary = {}
var _arrival_error := ""
var _frame_prepare_budget := 0


func configure(plot_rows: Array) -> bool:
	clear()
	_plots.clear()
	_by_mask.clear()
	_admission_bounds = Rect2()
	_inspection_bounds = Rect2()
	if plot_rows.size() != 63 or not Mixtures.is_valid(): return _fail("Element Garden requires all 63 validated mixtures and plots.")
	var candidate: Array[Dictionary] = []
	var seen := {}
	for value: Variant in plot_rows:
		if not value is Dictionary or not _whole(value.get("mask"), 1, 63): return _fail("Each garden plot needs a unique whole mixture mask.")
		var mask := int(value.mask)
		if seen.has(mask): return _fail("Element Garden repeats a mixture mask.")
		var center_value: Variant = value.get("center")
		var center := Vector2.ZERO
		if center_value is Vector2 or center_value is Vector2i:
			center = Vector2(center_value)
		elif center_value is Array and center_value.size() == 2 and _whole(center_value[0], 180, 7800) and _whole(center_value[1], 180, 7800):
			center = Vector2(float(center_value[0]), float(center_value[1]))
		else: return _fail("Each garden plot needs a finite pixel center.")
		if not is_finite(center.x) or not is_finite(center.y) or center.x < 180 or center.y < 180 or center.x > 7800 or center.y > 7800 or center != center.round(): return _fail("Garden centers must remain whole pixels inside the fixed-point domain.")
		for row: Dictionary in candidate:
			if center.distance_to(row.center) < 216.0: return _fail("Garden plots must leave their actual field footprints separate.")
		var mixture := Mixtures.definition(mask)
		var ingredients := PackedStringArray()
		for element: String in mixture.elements: ingredients.append(AbilityCatalog.element_display_name(element))
		candidate.append({"mask": mask, "center": center, "name": String(mixture.display_name), "recipe_name": String(Policy.runtime_definition(Policy.wire_for_mask(mask)).name), "ingredients": " + ".join(ingredients), "effect": String(mixture.purpose), "counter": String(mixture.counter)})
		seen[mask] = true
	candidate.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _arity(int(a.mask)) < _arity(int(b.mask)) if _arity(int(a.mask)) != _arity(int(b.mask)) else int(a.mask) < int(b.mask))
	_plots = candidate
	for row: Dictionary in _plots:
		_by_mask[int(row.mask)] = row
		var plot_bounds := Rect2(row.center - Vector2.ONE * PLOT_RADIUS, Vector2.ONE * PLOT_RADIUS * 2)
		var inspect_bounds := Rect2(row.center - Vector2.ONE * INSPECTION_RADIUS, Vector2.ONE * INSPECTION_RADIUS * 2)
		_admission_bounds = plot_bounds if not _admission_bounds.has_area() else _admission_bounds.merge(plot_bounds)
		_inspection_bounds = inspect_bounds if not _inspection_bounds.has_area() else _inspection_bounds.merge(inspect_bounds)
	return true


func clear() -> void:
	# Suspend transient exhibitions across mode/world transitions; retain the
	# validated map directory so returning to Wellspring can start fresh loops.
	_configuration_generation += 1
	cancel_arrival()
	_frame_prepare_budget = 0
	_resident.clear()
	_selection_memo.clear()
	_inspected_mask = 0
	_frame_restart_budget = -1
	_restart_queue.clear()
	_visible_view = Rect2()
	_visible_masks = []
	_nearest_observer = Vector2.INF
	_nearest_cached_mask = 0
	last_error = ""


func plots() -> Array[Dictionary]:
	return _plots.duplicate(true)


func plot_info(mask: int) -> Dictionary:
	if not _by_mask.has(mask): return {}
	var result: Dictionary = _by_mask[mask].duplicate(true)
	result["notice"] = EXHIBITION_NOTICE
	result["phase"] = "offscreen"
	result["phase_label"] = "Approach to watch the field"
	result["timing"] = "Finite exhibit; repeats after expiry."
	if not _resident.has(mask): return result
	var entry: Dictionary = _resident[mask]
	var tick := int(entry.tick)
	var end_tick := int(entry.expiry)
	var phase := _phase(entry)
	var next_tick := end_tick + RESET_TICKS
	if tick < end_tick:
		next_tick = int(entry.active) if tick < int(entry.active) else int(entry.decay) if tick < int(entry.decay) else end_tick
	result["phase"] = phase
	result["demonstration"] = String(entry.mode)
	result["phase_label"] = ("Single deposit" if entry.mode == "raw" else "Two matching sources" if entry.mode == "self" else "Mixture field") + " · " + phase.capitalize()
	result["timing"] = "%.1fs to next phase · %.1fs finite cycle" % [float(maxi(0, next_tick - tick)) / 120.0, float(end_tick - int(entry.started)) / 120.0]
	if phase == "resetting" and tick >= next_tick: result["timing"] = "Expired · queued to repeat."
	if entry.mode == "raw":
		result["effect"] = String(RAW_EFFECTS[mask])
		result["counter"] = "In combat, leave active Fire or jump over it." if mask == 2 else "This single deposit is ingredient matter; combine it to create its field."
	else:
		result["name"] = String(result.recipe_name)
		if entry.mode == "self": result["ingredients"] = String(result.ingredients) + " + " + String(result.ingredients)
	return result


func nearest_info(observer: Vector2) -> Dictionary:
	if not is_finite(observer.x) or not is_finite(observer.y): return {}
	return plot_info(_nearest_mask(observer))


func _nearest_mask(observer: Vector2) -> int:
	# Catch-up steps and the inspection card often ask about the same point.
	# Cache only the spatial answer; phase, timing and effect copy stay live.
	if observer == _nearest_observer: return _nearest_cached_mask
	_nearest_observer = observer
	_nearest_cached_mask = 0
	# Inclusive outer edges preserve the existing <= inspection-distance rule.
	if not _inspection_bounds.has_area() or observer.x < _inspection_bounds.position.x or observer.y < _inspection_bounds.position.y or observer.x > _inspection_bounds.end.x or observer.y > _inspection_bounds.end.y:
		return 0
	var nearest := 0
	var distance := INSPECTION_RADIUS * INSPECTION_RADIUS
	for row: Dictionary in _plots:
		var candidate := observer.distance_squared_to(row.center)
		if candidate <= distance:
			nearest = int(row.mask)
			distance = candidate
	_nearest_cached_mask = nearest
	return nearest


func _visible_in(view_rect: Rect2) -> Array[int]:
	# Exact rectangle equality preserves inclusive-edge admission and every
	# visible plot. No quantization, padding, camera delay or exhibition state.
	if view_rect == _visible_view: return _visible_masks
	var result: Array[int] = []
	for row: Dictionary in _plots:
		if Rect2(row.center - Vector2.ONE * PLOT_RADIUS, Vector2.ONE * PLOT_RADIUS * 2).intersects(view_rect, true): result.append(int(row.mask))
	result.make_read_only()
	_visible_view = view_rect
	_visible_masks = result
	return _visible_masks


func begin_frame() -> void:
	# Bootstrap calls once before its fixed-step loop. Harmless preparation must
	# not multiply with catch-up steps; direct simulation fixtures retain a
	# one-restart-per-step fallback when no presentation frame is supplied.
	_frame_restart_budget = RESTARTS_PER_FRAME
	_frame_prepare_budget = 1


func configuration_generation() -> int:
	return _configuration_generation


func request_arrival(view_rect: Rect2, observer: Vector2) -> bool:
	if _plots.size() != 63 or not _finite_view(view_rect, observer):
		cancel_arrival()
		_arrival_error = "Element Garden requires a configured finite arrival view."
		return _fail(_arrival_error)
	if _arrival_active and _arrival_view == view_rect:
		_arrival_observer = observer
		return true
	# Only a committed app travel calls this seam. Ordinary walking never does.
	cancel_arrival()
	_arrival_active = true
	_arrival_view = view_rect
	_arrival_observer = observer
	_arrival_masks.assign(_visible_in(view_rect))
	# The committed view has left these mutable courts behind. Retire them
	# before staging so resident + unpublished courts can never exceed 63.
	for mask: int in _resident.keys():
		if mask not in _arrival_masks:
			_resident.erase(mask)
			_restart_queue.erase(mask)
	return true


func prepare_arrival() -> bool:
	if not _arrival_active: return false
	if _frame_prepare_budget <= 0: return true
	for mask: int in _arrival_masks:
		if _resident.has(mask) or _arrival_staged.has(mask): continue
		_frame_prepare_budget -= 1
		var entry := _new_entry(mask)
		if entry.is_empty():
			var failure := last_error
			cancel_arrival()
			_arrival_error = failure
			return false
		_arrival_staged[mask] = entry
		break
	return true


func arrival_status() -> Dictionary:
	var prepared := 0
	for mask: int in _arrival_masks:
		if _resident.has(mask) or _arrival_staged.has(mask): prepared += 1
	return {"active": _arrival_active, "ready": _arrival_active and prepared == _arrival_masks.size(), "required": _arrival_masks.size(), "prepared": prepared, "remaining": _arrival_masks.size() - prepared, "error": _arrival_error, "total_courts": _resident.size() + _arrival_staged.size()}


func publish_arrival() -> bool:
	if not bool(arrival_status().ready): return false
	for mask: int in _arrival_masks:
		if _resident.has(mask): continue
		_resident[mask] = _arrival_staged[mask]
		_arrival_staged.erase(mask)
		_arrival_first_step[mask] = true
	_inspected_mask = _nearest_mask(_arrival_observer)
	_arrival_active = false
	_arrival_masks.clear()
	_arrival_view = Rect2()
	_arrival_error = ""
	last_error = ""
	return true


func cancel_arrival() -> void:
	_arrival_active = false
	_arrival_staged.clear()
	_arrival_first_step.clear()
	_arrival_masks.clear()
	_arrival_view = Rect2()
	_arrival_error = ""


static func _finite_view(view_rect: Rect2, observer: Vector2) -> bool:
	return view_rect.has_area() and is_finite(view_rect.position.x) and is_finite(view_rect.position.y) and is_finite(view_rect.end.x) and is_finite(view_rect.end.y) and is_finite(observer.x) and is_finite(observer.y)


func step(view_rect: Rect2, observer: Vector2) -> bool:
	if _plots.size() != 63: return _fail("Element Garden has not been configured.")
	if not _finite_view(view_rect, observer): return _fail("Element Garden requires a finite visible view.")
	# Direct callers retain synchronous admission. App staging must publish
	# atomically before resuming simulation; partial work is never half shown.
	if _arrival_active: cancel_arrival()
	# Most Wellspring frames are nowhere near a teaching plot. Exact per-plot
	# admission remains unchanged inside this conservative envelope; departing
	# views still retire every exhibition and queued repeat immediately.
	if not _admission_bounds.intersects(view_rect, true):
		_resident.clear()
		_arrival_first_step.clear()
		_restart_queue.clear()
		_inspected_mask = _nearest_mask(observer)
		last_error = ""
		return true
	var visible := _visible_in(view_rect)
	# Never silently show empty visible plots. Supported map/camera geometry
	# fits the finite authored count, including enlarged desktop windows.
	if visible.size() > MAX_RESIDENT: return _fail("Element Garden view exceeds its visible exhibition budget.")
	_inspected_mask = _nearest_mask(observer)
	var restart_budget := RESTARTS_PER_FRAME if _frame_restart_budget < 0 else _frame_restart_budget
	for mask: int in _resident.keys():
		if mask not in visible:
			_resident.erase(mask)
			_restart_queue.erase(mask)
			_arrival_first_step.erase(mask)
	for mask: int in visible:
		if not _resident.has(mask):
			var entry := _new_entry(mask)
			if entry.is_empty(): return false
			_resident[mask] = entry
		else:
			# Ordinary first admission emits tick zero during this very step.
			# Published arrivals are already drawable, but must consume that same
			# admission step once before their clocks start advancing.
			if _arrival_first_step.erase(mask): continue
			var entry: Dictionary = _resident[mask]
			entry.tick = int(entry.tick) + 1
			var court: HexChemistryWorld = entry.court
			court.current_tick = int(entry.tick)
			# These courts have one deposit/product and no actors or flights.
			# Production mutation is needed only at actual lifecycle boundaries.
			if int(entry.tick) == int(entry.active):
				court.fracture_products(int(entry.tick))
				if not court.products.is_empty(): entry.decay = int(court.products.values()[0].decay_tick)
			if int(entry.tick) == int(entry.expiry):
				court.expire_at(int(entry.tick))
				court.sync_flights([], [])
			if int(entry.tick) >= int(entry.expiry) + RESET_TICKS and mask not in _restart_queue:
				_restart_queue.append(mask)
	# FIFO gives every expired plot a turn before a shorter earlier plot can
	# repeat again. Directory order is never used as repeat priority.
	while restart_budget > 0 and not _restart_queue.is_empty():
		var mask: int = _restart_queue.pop_front()
		var entry: Dictionary = _resident[mask]
		entry.cycle = int(entry.cycle) + 1
		if not _emit_cycle(mask, entry): return false
		restart_budget -= 1
	if _frame_restart_budget >= 0: _frame_restart_budget = restart_budget
	last_error = ""
	return true


func render_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in _plots:
		var mask := int(row.mask)
		if not _resident.has(mask): continue
		result.append(_render_entry(mask, _resident[mask]))
	return result


func arrival_render_entries() -> Array[Dictionary]:
	# Explicit preparation reads the same projection, without making detached
	# courts visible or advancing their funded first cycle. Metadata is fresh;
	# the borrowed court is read only by presentation, as in render_entries.
	var result: Array[Dictionary] = []
	if not _arrival_active: return result
	for mask: int in _arrival_masks:
		if _resident.has(mask): result.append(_render_entry(mask, _resident[mask]))
		elif _arrival_staged.has(mask): result.append(_render_entry(mask, _arrival_staged[mask]))
	return result


func _render_entry(mask: int, entry: Dictionary) -> Dictionary:
	var row: Dictionary = _by_mask[mask]
	return {"mask": mask, "center": row.center, "court": entry.court, "tick": int(entry.tick), "phase": _phase(entry), "name": row.name if entry.mode == "raw" else row.recipe_name, "ingredients": row.ingredients, "material": entry.material, "cycle": int(entry.cycle), "decay": int(entry.decay), "inspected": mask == _inspected_mask}


func _new_entry(mask: int) -> Dictionary:
	var court := ExhibitCourt.new(_selection_memo)
	var center: Vector2 = _by_mask[mask].center
	if not court.configure_geometry(Vector2i(center * 1000.0), HexGrid.disk(Vector2i.ZERO, TOPOLOGY_RADIUS)):
		_fail("Element Garden could not prepare bounded exhibit topology.")
		return {}
	court.chemistry_enabled = true
	var entry := {"court": court, "tick": 0, "cycle": 0, "started": 0, "expiry": 0, "mode": ""}
	return entry if _emit_cycle(mask, entry) else {}


func _emit_cycle(mask: int, entry: Dictionary) -> bool:
	var court: HexChemistryWorld = entry.court
	var tick := int(entry.tick)
	# Previous stock has already expired. Retire only the isolated exhibition
	# history; fresh monotonic source IDs keep every loop's supply distinct.
	court.retire_round_material()
	var singleton := _arity(mask) == 1
	entry.mode = "raw" if singleton and int(entry.cycle) % 2 == 0 else "self" if singleton else "mixed"
	entry.started = tick
	var wire := Mixtures.wire_for(mask, "bolt")
	var definition := CombatTuning.cast_definition_view(wire)
	if definition.is_empty(): return _fail("Element Garden cannot find its ordinary Bolt definition.")
	for unused: int in range(2 if entry.mode == "self" else 1):
		var source := court.next_cast_id
		if not court.reserve_cast(1, wire): return _fail("Element Garden exhibition source was refused.")
		court.commit_payment(1)
		court.bind_release(1, source, court.origin, Vector2i(1000, 0), 1)
		court.deposit_terminal({"source_cast_id": source, "source_wire_id": wire, "projectile_id": source,
			"owner_id": 1, "team_id": 1, "element_wire_id": int(definition.element_wire_id),
			"position": court.origin, "direction": Vector2i(1000, 0), "strength": 1000,
			"reaction_strength": int(definition.reaction_strength)}, tick)
	if entry.mode == "raw":
		if court.casts.size() != 1 or not court.products.is_empty(): return _fail("Single exhibition deposit did not remain ingredient matter.")
		entry.expiry = int(court.casts.values()[0].expires)
		entry.active = tick + HexChemistryWorld.IGNITION_TICKS
		entry.decay = int(entry.expiry) - HexChemistryWorld.COOLING_TICKS
		entry.material = Policy.ingredient_layer(int(court.casts.values()[0].element))
	else:
		if court.products.size() != 1 or int(court.products.values()[0].recipe_wire_id) != Policy.wire_for_mask(mask): return _fail("Exhibition sources did not form the exact selected recipe.")
		entry.expiry = int(court.products.values()[0].expiry_tick)
		entry.active = int(court.products.values()[0].active_tick)
		entry.decay = int(court.products.values()[0].decay_tick)
		entry.material = String(court.products.values()[0].material)
	court.sync_flights([], [])
	if not court.conservation_valid(): return _fail("Exhibition source conservation failed.")
	return true


static func _phase(entry: Dictionary) -> String:
	var tick := int(entry.tick)
	if tick >= int(entry.expiry): return "resetting"
	var phase := "forming" if tick < int(entry.active) else "active" if tick < int(entry.decay) else "decaying"
	if entry.material == "fire": return "ignition" if phase == "forming" else "cooling" if phase == "decaying" else phase
	return phase


static func _arity(mask: int) -> int:
	var count := 0
	for bit: int in [1, 2, 4, 8, 16, 32]:
		if mask & bit: count += 1
	return count


static func _whole(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == float(int(value)) and int(value) >= low and int(value) <= high


func _fail(message: String) -> bool:
	last_error = message
	return false
