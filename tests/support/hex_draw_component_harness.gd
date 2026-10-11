extends "res://tests/support/chemistry_coach_harness.gd"

# Test-only timers around unchanged, typed production calls. The inherited
# Bootstrap _draw is never copied. Backdrop UPDATE_ONCE work is excluded because
# timing is active only during this node's synchronous _draw call.
class Counters extends RefCounted:
	var active := false
	var owner_instance_id := 0
	var elapsed: Dictionary = {}
	var calls: Dictionary = {}
	var ground_elapsed: Dictionary = {}

	func start(canvas: CanvasItem = null) -> int:
		return Time.get_ticks_usec() if active and (canvas == null or canvas.get_instance_id() == owner_instance_id) else -1

	func finish(component: String, began: int) -> void:
		if began < 0:
			return
		var duration: int = Time.get_ticks_usec() - began
		elapsed[component] = int(elapsed.get(component, 0)) + duration
		calls[component] = int(calls.get(component, 0)) + 1

class TimedCampus extends SanctumCampusRenderer:
	var counters: Counters
	func draw(canvas: CanvasItem, layout: SanctumCampusLayout, presentation_tick: int, focus_world_position: Vector2 = Vector2(-1000000.0, -1000000.0), reduced_effects: bool = false, station_titles: bool = true, visible_world_rect: Rect2 = Rect2(), practice_details: bool = true, court_context: String = "") -> void:
		var began: int = counters.start(canvas)
		super.draw(canvas, layout, presentation_tick, focus_world_position, reduced_effects, station_titles, visible_world_rect, practice_details, court_context)
		counters.finish("campus", began)

class TimedGround extends HexCourtPresenter:
	var counters: Counters
	func _prepare_court(court: RefCounted, include_empty: bool = true) -> bool:
		var began := counters.start()
		var result := super._prepare_court(court, include_empty)
		if began >= 0: counters.ground_elapsed["membership"] = Time.get_ticks_usec() - began
		return result

	func _prepare_frame_bundle(court: RefCounted, tick: float) -> Dictionary:
		var began := counters.start()
		var result := super._prepare_frame_bundle(court, tick)
		if began >= 0: counters.ground_elapsed["frame_bundle"] = Time.get_ticks_usec() - began
		return result

	func _draw_water(canvas: CanvasItem, views: Dictionary, regions: Dictionary, tick: float, reduced: bool) -> void:
		var began := counters.start(canvas)
		super._draw_water(canvas, views, regions, tick, reduced)
		if began >= 0: counters.ground_elapsed["water_submission"] = Time.get_ticks_usec() - began

	func _detail(key: String, began: int) -> void:
		if began >= 0: counters.ground_elapsed[key] = int(counters.ground_elapsed.get(key, 0)) + Time.get_ticks_usec() - began

	func _draw_fire(canvas: CanvasItem, views: Dictionary, regions: Dictionary, tick: float, reduced: bool) -> void:
		var began := counters.start(canvas)
		super._draw_fire(canvas, views, regions, tick, reduced)
		_detail("fire_submission", began)

	func _draw_steam(canvas: CanvasItem, views: Dictionary, regions: Dictionary, tick: float, reduced: bool) -> void:
		var began := counters.start(canvas)
		super._draw_steam(canvas, views, regions, tick, reduced)
		_detail("steam_submission", began)

	func _draw_shared_material(canvas: CanvasItem, regions: Dictionary, material: String, tick: float, reduced: bool) -> void:
		var began := counters.start(canvas)
		super._draw_shared_material(canvas, regions, material, tick, reduced)
		_detail("material_" + material, began)

	func _region_edge_counts(regions: Dictionary) -> Dictionary:
		var began := counters.start()
		var result := super._region_edge_counts(regions)
		_detail("edge_counts", began)
		return result

	func _draw_region_outline(canvas: CanvasItem, region: Dictionary, counts: Dictionary, color: Color, width: float) -> void:
		var began := counters.start(canvas)
		super._draw_region_outline(canvas, region, counts, color, width)
		_detail("outlines", began)

	func _shared_material_style(material: String, region: Dictionary, reduced: bool) -> Dictionary:
		var began := counters.start()
		var result := super._shared_material_style(material, region, reduced)
		_detail("shared_style", began)
		return result

	func _draw_shared_material_mark(canvas: CanvasItem, region: Dictionary, style: Dictionary, tick: float, seed: int, reduced: bool, surface_painted: bool = false) -> void:
		var began := counters.start(canvas)
		super._draw_shared_material_mark(canvas, region, style, tick, seed, reduced, surface_painted)
		_detail("shared_marks", began)

	func draw_ground(canvas: CanvasItem, court: RefCounted, tick: float, reduced: bool, draw_district_base: bool = true) -> bool:
		var began: int = counters.start(canvas)
		var result: bool = super.draw_ground(canvas, court, tick, reduced, draw_district_base)
		counters.finish("hex_ground", began)
		return result

class TimedActors extends CartoonChampionPresenter:
	var counters: Counters
	func draw(canvas: CanvasItem, state: PlayerState, champion_id: String, body_anchor: Vector2, presentation_tick: float, config: SimConfig, reduced_effects: bool = false, ground_anchor: Vector2 = Vector2.INF, locomotion_phase: float = -1.0, wall_travel: Vector2i = Vector2i.ZERO) -> bool:
		var began: int = counters.start(canvas)
		var result: bool = super.draw(canvas, state, champion_id, body_anchor, presentation_tick, config, reduced_effects, ground_anchor, locomotion_phase, wall_travel)
		counters.finish("actor_bodies", began)
		return result

class TimedHud extends CompactCombatHud:
	var counters: Counters
	func draw(canvas: CanvasItem, viewport_size: Vector2, state: PlayerState, ability_catalog: AbilityCatalog, champion_id: String, champion_name: String, location_name: String, session_label: String, active_layer: int, tick_rate: int, spectating: bool, capacity: Vector2i = Vector2i(-1, -1), cast_gate: String = "", pointer: Vector2 = Vector2(-1000, -1000), feedback_label: String = "", preferences: PlayerPreferences = null) -> void:
		var began: int = counters.start(canvas)
		super.draw(canvas, viewport_size, state, ability_catalog, champion_id, champion_name, location_name, session_label, active_layer, tick_rate, spectating, capacity, cast_gate, pointer, feedback_label, preferences)
		counters.finish("hud", began)

var counters := Counters.new()
var timing_enabled := false
var draw_invocations := 0
var total_draw_us := 0

func install_timers() -> bool:
	counters.owner_instance_id = get_instance_id()
	# Reconfigure the same production classes and catalogues through subclasses.
	# The existing one-time static backdrop retains its original renderer.
	var campus := TimedCampus.new()
	campus.counters = counters
	if not campus.configure(visual_language) or not campus.configure_campus(campus_layout):
		return false
	campus_renderer = campus
	var ground := TimedGround.new()
	ground.counters = counters
	if not ground.configure(visual_language):
		return false
	hex_court_presenter = ground
	var actors := TimedActors.new()
	actors.counters = counters
	if not actors.configure(visual_language):
		return false
	cartoon_champion_presenter = actors
	var hud := TimedHud.new()
	hud.counters = counters
	if not hud.configure(visual_language):
		return false
	compact_hud = hud
	compact_hud.champion_art = actors
	return true

func _draw() -> void:
	counters.elapsed.clear()
	counters.calls.clear()
	counters.ground_elapsed.clear()
	counters.active = timing_enabled
	var began: int = Time.get_ticks_usec()
	super._draw()
	total_draw_us = Time.get_ticks_usec() - began
	counters.active = false
	draw_invocations += 1

func _draw_pov_mask(origin: Vector2, aim: Vector2, camera_origin: Vector2) -> void:
	var began: int = counters.start()
	super._draw_pov_mask(origin, aim, camera_origin)
	counters.finish("pov_mask", began)

func _draw_projectile(projectile: ProjectileState, position: Vector2, color: Color, interpolation_alpha: float) -> void:
	var began: int = counters.start()
	super._draw_projectile(projectile, position, color, interpolation_alpha)
	counters.finish("projectiles", began)

func _draw_combat_cues(camera_origin: Vector2) -> void:
	var began: int = counters.start()
	super._draw_combat_cues(camera_origin)
	counters.finish("combat_cues", began)

func _draw_element_chemistry(visual_tick: float, camera_origin: Vector2) -> void:
	var began: int = counters.start()
	super._draw_element_chemistry(visual_tick, camera_origin)
	counters.finish("legacy_chemistry", began)
