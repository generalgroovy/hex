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
var _committed_view: SubViewport
var _committed_context := ""
var _spare_view: SubViewport
var _spare_terrain: TerrainCanvas
var _pending_view: SubViewport
var _pending_rect := Rect2()
var _pending_context := ""
var _last_visible := Rect2()
var _pending_completion := Callable()
const MAX_VIEWPORT := Vector2i(2560, 1536)
const VIEW_MARGIN := 96.0
const VIEW_ALIGNMENT := 64.0
const REFRESH_GUARD := 32.0


func prepare_view(visible: Rect2) -> bool:
	if _terrain == null or not visible.has_area() or not visible.position.is_finite() or not visible.end.is_finite(): return false
	_last_visible = visible
	# Begin the next capture before motion reaches the currently sampled edge.
	# Keep using the complete previous image while the inactive target renders.
	var guarded := visible.grow(REFRESH_GUARD)
	# Cancel an obsolete destination even when replacement tiles are still cold
	# or the current view has reached its refresh guard. Otherwise a late distant
	# capture could evict useful completed coverage during an immediate return.
	if _pending_view != null and (_pending_context != _court_context or not _pending_rect.encloses(visible)):
		_pending_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_pending_view = null
		_disconnect_capture_signal()
		_revision += 1
	if ready_for(guarded): return true
	if _pending_view != null and _pending_context == _court_context and _pending_rect.encloses(guarded): return ready_for(visible)
	var expanded := visible.grow(VIEW_MARGIN)
	var origin := (expanded.position / VIEW_ALIGNMENT).floor() * VIEW_ALIGNMENT
	var end := (expanded.end / VIEW_ALIGNMENT).ceil() * VIEW_ALIGNMENT
	var requested_rect := Rect2(origin, end - origin)
	# Rendering an incomplete tile cohort must never mark a blank backdrop as
	# ready. Root pumps terrain outside drawing before requesting this capture.
	if not _terrain.renderer.terrain_ready_for(requested_rect): return ready_for(visible)
	_schedule_capture(requested_rect)
	return ready_for(visible)


func ready_for(visible: Rect2) -> bool:
	# A teleport or camera expansion must never sample pixels from the old origin.
	return _rendered_revision >= 0 and _committed_view != null and _committed_context == _court_context and visible.has_area() and visible.position.is_finite() and visible.end.is_finite() and world_rect.encloses(visible)


func backdrop_texture() -> Texture2D:
	return _committed_view.get_texture() if _committed_view != null else null


func _schedule_capture(requested_rect: Rect2) -> void:
	var target: SubViewport = self
	var canvas: TerrainCanvas = _terrain
	if _committed_view == self:
		if _spare_view == null:
			_spare_view = SubViewport.new()
			_configure_target(_spare_view)
			_spare_terrain = _make_canvas(_terrain.renderer, _terrain.layout)
			_spare_view.add_child(_spare_terrain)
			add_child(_spare_view)
		target = _spare_view
		canvas = _spare_terrain
	var scale_ratio := minf(1.0, minf(float(MAX_VIEWPORT.x) / requested_rect.size.x, float(MAX_VIEWPORT.y) / requested_rect.size.y))
	target.size = Vector2i((requested_rect.size * scale_ratio).ceil())
	var canvas_scale := Vector2(target.size) / requested_rect.size
	canvas.world_rect = requested_rect
	canvas.position = -requested_rect.position * canvas_scale
	canvas.scale = canvas_scale
	canvas.court_context = _court_context
	_pending_view = target
	_pending_rect = requested_rect
	_pending_context = _court_context
	# Initial allocation has no published texture yet. Keep its requested bounds
	# available for diagnostics, but readiness still waits for frame_post_draw.
	if _committed_view == null: world_rect = requested_rect
	_disconnect_capture_signal()
	_revision += 1
	canvas.queue_redraw()
	target.render_target_update_mode = SubViewport.UPDATE_ONCE
	_pending_completion = _complete_capture.bind(_revision)
	RenderingServer.frame_post_draw.connect(_pending_completion, CONNECT_ONE_SHOT)


func _complete_capture(requested: int) -> void:
	if requested != _revision or _pending_view == null: return
	_disconnect_capture_signal()
	if _pending_context != _court_context or not _pending_rect.encloses(_last_visible):
		_pending_view = null
		return
	# Publish pixels and their UV coordinate system together, never a new origin
	# against old pixels. The other bounded target stays dormant until needed.
	_committed_view = _pending_view
	world_rect = _pending_rect
	_committed_context = _pending_context
	_rendered_revision = requested
	_pending_view = null


func _disconnect_capture_signal() -> void:
	if _pending_completion.is_valid() and RenderingServer.frame_post_draw.is_connected(_pending_completion):
		RenderingServer.frame_post_draw.disconnect(_pending_completion)
	_pending_completion = Callable()


func _exit_tree() -> void:
	_disconnect_capture_signal()
	if _pending_view != null: _pending_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_pending_view = null
	_revision += 1


func set_court_context(context: String) -> bool:
	# Only known local encounter contexts change this static navigation label. Unknown
	# contexts keep the renderer's ordinary court fallback, without recapturing.
	var next := context if context in [SanctumCampusRenderer.SOLO_DUEL_CONTEXT, SanctumCampusRenderer.SIGNATURE_CHALLENGE_CONTEXT] else ""
	if next == _court_context:
		return false
	_court_context = next
	if _terrain != null:
		_terrain.court_context = next
		if _last_visible.has_area(): prepare_view(_last_visible)
	return true


func configure(renderer: SanctumCampusRenderer, layout: SanctumCampusLayout) -> void:
	_configure_target(self)
	_terrain = _make_canvas(renderer, layout)
	add_child(_terrain)


static func _configure_target(target: SubViewport) -> void:
	target.disable_3d = true
	target.transparent_bg = false
	target.gui_disable_input = true
	target.handle_input_locally = false
	# Allocation follows the view, never the expanded world dimensions.
	target.size = Vector2i.ONE
	target.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	target.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _make_canvas(renderer: SanctumCampusRenderer, layout: SanctumCampusLayout) -> TerrainCanvas:
	var canvas := TerrainCanvas.new()
	canvas.renderer = renderer
	canvas.layout = layout
	canvas.court_context = _court_context
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return canvas
