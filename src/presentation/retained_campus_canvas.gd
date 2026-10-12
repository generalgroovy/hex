extends Node2D
## Six ordered CanvasItems retain Godot draw commands until their actual inputs
## change. No viewport texture, replacement art, authority or visibility cache.
## https://docs.godotengine.org/en/4.6/tutorials/2d/custom_drawing_in_2d.html#updating
const LAYER_NAMES := ["ground", "activity_arena", "buildings", "landmarks", "stations", "district_labels"]

class CampusLayer extends Node2D:
	var renderer: SanctumCampusRenderer
	var layout: SanctumCampusLayout
	var layer := 0
	var tick := 0
	var focus := Vector2.ZERO
	var reduced := false
	var titles := true
	var view := Rect2()
	var details := true
	var context := ""
	var key: Array = []
	var requests := 0
	var draws := 0
	var profile_enabled := false
	var draw_usec := 0
	func prepare(source: SanctumCampusRenderer, campus: SanctumCampusLayout, index: int, values: Dictionary, signature: Array) -> void:
		if key == signature: return
		renderer = source
		layout = campus
		layer = index
		tick = int(values.tick)
		focus = values.focus
		reduced = bool(values.reduced)
		titles = bool(values.titles)
		view = values.view
		details = bool(values.details)
		context = String(values.context)
		key = signature.duplicate()
		requests += 1
		queue_redraw()
	func clear() -> void:
		renderer = null
		layout = null
		key.clear()
		# Release command-held resources even while this layer is hidden. A
		# later prepare always has a new key and schedules its complete redraw.
		RenderingServer.canvas_item_clear(get_canvas_item())
	func _draw() -> void:
		if renderer == null or layout == null: return
		var started := Time.get_ticks_usec() if profile_enabled else 0
		renderer.draw_retained_layer(self, layout, layer, tick, focus, reduced, titles, view, details, context)
		draws += 1
		if profile_enabled: draw_usec += Time.get_ticks_usec() - started

var layers: Array[CampusLayer] = []
var profile_enabled := false
var _font: Font
var _font_revision := 0
var _explicit_revision := 0

func _init() -> void:
	show_behind_parent = true
	visible = false
	# The scene's authored pixel filter is inherited from the same parent as
	# the original draw commands. Do not substitute a viewport texture filter.
	for index: int in LAYER_NAMES.size():
		var layer := CampusLayer.new()
		layer.name = LAYER_NAMES[index]
		layers.append(layer)
		add_child(layer)

func present(renderer: SanctumCampusRenderer, layout: SanctumCampusLayout, tick: int, focus: Vector2, reduced: bool, titles: bool, view: Rect2, details: bool, context: String, world_transform: Transform2D) -> bool:
	if renderer == null or layout == null or not view.has_area() or not view.position.is_finite() or not view.end.is_finite() or not focus.is_finite() or not world_transform.is_finite():
		deactivate()
		return false
	var source := renderer.retained_source()
	if source == null or not source.can_draw_campus(layout):
		deactivate()
		return false
	_bind_font(ThemeDB.fallback_font)
	transform = world_transform
	visible = true
	var common: Array = [source, layout, source.retained_generation, source.floor_guide_hash, source.environment_details.content_hash, source.illustrated_kit, source.illustrated_kit.content_hash, source.BRASS, source.PARCHMENT, source.CYAN, source.PANEL, view, _font, _font_revision, _explicit_revision]
	var keys := signatures(common, tick, focus, reduced, titles, details, context, _terrain_revision(source))
	var values := {"tick": tick, "focus": focus, "reduced": reduced, "titles": titles, "view": view, "details": details, "context": context}
	for index: int in layers.size():
		layers[index].profile_enabled = profile_enabled
		layers[index].prepare(source, layout, index, values, keys[index])
	return true

static func signatures(common: Array, tick: int, focus: Vector2, reduced: bool, titles: bool, details: bool, context: String, terrain_revision: Array) -> Array[Array]:
	# This first experiment preserves the exact reference culling rectangle;
	# camera motion may rebuild static layers. No enlarged/cached visibility.
	var result: Array[Array] = []
	for _index: int in LAYER_NAMES.size(): result.append(common.duplicate())
	result[0].append_array(terrain_revision)
	result[1].append_array([focus, details, context])
	result[3].append_array([focus, reduced, 0 if reduced else tick])
	result[4].append_array([focus, titles])
	return result

static func _terrain_revision(source: SanctumCampusRenderer) -> Array:
	var kit := source.illustrated_kit
	var stream = kit.terrain_stream
	return [kit.ground, kit.ground_overview, -1 if stream == null else stream.uploads, kit.ground_chunks.size()]

func invalidate() -> void:
	# Explicit boundary for an admitted in-place presentation/content change.
	# Normal map/renderer configuration already increments its generation.
	_explicit_revision += 1

func deactivate() -> void:
	if not visible and layers[0].key.is_empty(): return
	visible = false
	for layer: CampusLayer in layers: layer.clear()

func stats() -> Dictionary:
	var result := {"visible": visible, "layer_count": layers.size(), "layers": {}}
	for index: int in layers.size():
		result.layers[LAYER_NAMES[index]] = {"requests": layers[index].requests, "draws": layers[index].draws, "draw_usec": layers[index].draw_usec}
	return result

func _bind_font(font: Font) -> void:
	if font == _font: return
	if _font != null and _font.changed.is_connected(_font_changed): _font.changed.disconnect(_font_changed)
	_font = font
	_font_revision += 1
	if _font != null: _font.changed.connect(_font_changed)

func _font_changed() -> void:
	_font_revision += 1

func _exit_tree() -> void:
	if _font != null and _font.changed.is_connected(_font_changed): _font.changed.disconnect(_font_changed)
