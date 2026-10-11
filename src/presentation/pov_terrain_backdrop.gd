extends SubViewport

# Static worldbone only. Replacing unseen pixels with this texture prevents a
# gentler terrain treatment from exposing live projectiles, fields or actors.
# This is presentation, not packet redaction or an alternate LOS authority.
class TerrainCanvas:
	extends Node2D
	var renderer: SanctumCampusRenderer
	var layout: SanctumCampusLayout
	var court_context := ""
	var world_rect := Rect2()
	func _draw() -> void:
		# Keep static navigation, not player-proximity instructional overlays.
		renderer.draw(self, layout, 0, Vector2(-1000000, -1000000), true, false, world_rect, false, court_context)


var _court_context := ""
var _terrain: TerrainCanvas
var world_rect := Rect2()
var _revision := 0
var _rendered_revision := -1
const MAX_VIEWPORT := Vector2i(2560, 1536)
const VIEW_MARGIN := 96.0
const VIEW_ALIGNMENT := 64.0


func prepare_view(visible: Rect2) -> bool:
	if _terrain == null or not visible.has_area() or not visible.position.is_finite() or not visible.end.is_finite(): return false
	if world_rect.has_area() and world_rect.encloses(visible): return ready_for(visible)
	var expanded := visible.grow(VIEW_MARGIN)
	var origin := (expanded.position / VIEW_ALIGNMENT).floor() * VIEW_ALIGNMENT
	var end := (expanded.end / VIEW_ALIGNMENT).ceil() * VIEW_ALIGNMENT
	var requested_rect := Rect2(origin, end - origin)
	# Rendering an incomplete tile cohort must never mark a blank backdrop as
	# ready. Root pumps terrain outside drawing before requesting this capture.
	if not _terrain.renderer.terrain_ready_for(requested_rect): return false
	world_rect = requested_rect
	var scale_ratio := minf(1.0, minf(float(MAX_VIEWPORT.x) / world_rect.size.x, float(MAX_VIEWPORT.y) / world_rect.size.y))
	size = Vector2i((world_rect.size * scale_ratio).ceil())
	var canvas_scale := Vector2(size) / world_rect.size
	_terrain.world_rect = world_rect
	_terrain.position = -world_rect.position * canvas_scale
	_terrain.scale = canvas_scale
	_schedule_capture()
	return false


func ready_for(visible: Rect2) -> bool:
	# A teleport or camera expansion must never sample pixels from the old origin.
	return _rendered_revision == _revision and world_rect.has_area() and world_rect.encloses(visible)


func _schedule_capture() -> void:
	_revision += 1
	var requested := _revision
	_terrain.queue_redraw()
	render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.frame_post_draw.connect(func() -> void:
		if requested == _revision: _rendered_revision = requested
	, CONNECT_ONE_SHOT)


func set_court_context(context: String) -> bool:
	# Only known local encounter contexts change this static navigation label. Unknown
	# contexts keep the renderer's ordinary court fallback, without recapturing.
	var next := context if context in [SanctumCampusRenderer.SOLO_DUEL_CONTEXT, SanctumCampusRenderer.SIGNATURE_CHALLENGE_CONTEXT] else ""
	if next == _court_context:
		return false
	_court_context = next
	if _terrain != null:
		_terrain.court_context = next
		if world_rect.has_area(): _schedule_capture()
	return true


func configure(renderer: SanctumCampusRenderer, layout: SanctumCampusLayout) -> void:
	disable_3d = true
	transparent_bg = false
	gui_disable_input = true
	handle_input_locally = false
	# Allocation follows the view, never the expanded world dimensions.
	size = Vector2i.ONE
	render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	_terrain = TerrainCanvas.new()
	_terrain.renderer = renderer
	_terrain.layout = layout
	_terrain.court_context = _court_context
	_terrain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_terrain)
