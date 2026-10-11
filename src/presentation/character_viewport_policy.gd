class_name CharacterViewportPolicy
extends RefCounted
## Read-only rejection for the bounded, stateless part of a remote actor draw.
## Call AFTER sight/chemistry admission and with the current interpolated anchor.
## This never culls shadows, landing, spell startup, labels, health or aim lines:
## bootstrap draws those independently, even when this body query returns true.

const PixelBody = preload("res://src/presentation/pixel_flipbook_presenter.gd")
const PixelActions = preload("res://src/presentation/pixel_action_bank.gd")
const Fullbody = preload("res://src/presentation/fullbody_cast_presenter.gd")

# MinimalChampionMotion admission limits each offset axis to four pixels.
# Its locomotion pivot (1.25 bob + 0.35 lean + 0.16 support) is inside this.
const LEGACY_OFFSET_LIMIT := 4.0
# All legacy movement-accent primitives are bounded by recovery_brace:
# 21 vertical offset + 9 recoil + 20 ray length + 1.5 half stroke = 51.5.
# Include this about BOTH anchors because legacy cues choose floor or body.
const LEGACY_ACCENT_RADIUS := 52.0
# The main transform snaps its translation; a one-device-pixel fringe keeps
# touching/rasterized edges admitted at all supported zooms.
const RASTER_GUARD_PIXELS := 1.0


static func can_skip_body(
	presenter: CartoonChampionPresenter,
	champion_id: String,
	state: PlayerState,
	config: SimConfig,
	body_anchor: Vector2,
	ground_anchor: Vector2,
	camera_origin: Vector2,
	viewport: Rect2,
	zoom_percent: int,
) -> bool:
	if presenter == null or state == null or config == null:
		return false
	if not body_anchor.is_finite() or not ground_anchor.is_finite() \
		or not camera_origin.is_finite() or not viewport.position.is_finite() or not viewport.size.is_finite() \
		or not viewport.has_area() or zoom_percent not in PixelPresentation.SUPPORTED_ZOOM:
		return false
	# Admission only: a visible body OR floor anchor can never justify skipping
	# this draw. Most live actors finish here, before state/cue queries, renderer
	# dispatch or envelope construction. This remains safe for unknown routes,
	# malformed art metadata and unsupported states because it only returns false.
	var zoom := PixelPresentation.zoom_scale(zoom_percent)
	var canvas_origin := (-camera_origin * zoom).round() # Exact production translation.
	var anchor_view := viewport.grow(RASTER_GUARD_PIXELS)
	if anchor_view.has_point(body_anchor * zoom + canvas_origin) \
		or anchor_view.has_point(ground_anchor * zoom + canvas_origin):
		return false
	# walljump_contact stores a past contact during draw; a later burst can be
	# far from the current actor. Do not skip either capture or replay. Pixel
	# wall sparks/takeoff also participate in the shared decoration budget.
	if state.wall_memory_ticks > 0 or state.wall_skim_ticks > 0 \
		or (state.hop_mode == PlayerState.MovementMode.WALL_KICK and state.movement_commitment_ticks > 0):
		return false
	if bool(JumpPresentation.takeoff_contract(state, config)["active"]):
		return false
	# Protection has authored pixel badges/corners as well as fallback lines.
	# Leave that essential cue on the established path, not a guessed margin.
	if JumpPresentation.protection_ratio(state, config) > 0.0:
		return false
	var local_body := stateless_body_bounds(presenter, champion_id, state)
	if not local_body.has_area():
		return false
	var height := float(presenter.champions[champion_id].get("height", 68))
	if presenter.fullbody_art != null:
		height = float(PixelBody.BODY_HEIGHTS.get(presenter.fullbody_art.pixel_pilot.entries[champion_id].body, 68))
	if not is_finite(height):
		return false
	var bounds := Rect2(body_anchor + local_body.position, local_body.size)
	# A rejected/empty fixed frame would have drawn bootstrap's fallback circle
	# at feet (not at the shadow-offset sprite pivot). Keep that region too.
	var radius := float(MovementTuning.PLAYER_RADIUS) / SimConfig.FIXED_SCALE
	var fallback_center := body_anchor - Vector2(0, radius * 0.58)
	var fallback_extent := Vector2.ONE * (radius + 5.0)
	bounds = bounds.merge(Rect2(fallback_center - fallback_extent, fallback_extent * 2.0))
	# Chevron: height+7 center, +/-2 vertices, 4px stroke. Flight meter:
	# height+17 top, 18px width. Four-pixel pose offset applies to either cue.
	var height_cue := Rect2(Vector2(-9, -height - 17), Vector2(18, 14)).grow(LEGACY_OFFSET_LIMIT)
	bounds = bounds.merge(Rect2(body_anchor + height_cue.position, height_cue.size))
	var accent_size := Vector2.ONE * LEGACY_ACCENT_RADIUS * 2.0
	bounds = bounds.merge(Rect2(body_anchor - accent_size * 0.5, accent_size))
	bounds = bounds.merge(Rect2(ground_anchor - accent_size * 0.5, accent_size))
	return outside_viewport(bounds, camera_origin, viewport, zoom_percent)


static func stateless_body_bounds(presenter: CartoonChampionPresenter, champion_id: String, state: PlayerState) -> Rect2:
	if presenter == null or state == null or not presenter.champions.has(champion_id):
		return Rect2()
	if presenter.fullbody_art == null:
		# Legacy atlas/override and baked wireframe regions all use this exact
		# destination cell. A failed frame still falls back to the same bounded
		# actor circle outside this policy; no asset is loaded by this query.
		return Rect2(-CartoonChampionPresenter.PIVOT, CartoonChampionPresenter.CELL_SIZE).grow(LEGACY_OFFSET_LIMIT)
	var art: RefCounted = presenter.fullbody_art
	var pixel: RefCounted = art.pixel_pilot
	if pixel == null or not art.entries.has(champion_id) or not pixel.has_character(champion_id):
		return Rect2()
	var action := Fullbody.action_for_state(state)
	var fixed_route: bool = action in PixelBody.SUPPORTED_ACTIONS
	if pixel.action_bank != null:
		fixed_route = fixed_route or (pixel.action_bank.entries.has(champion_id) and PixelActions.ACTION_ROWS.has(action))
	if not fixed_route:
		# Shared-rig fallback retains short per-actor locomotion settling inside
		# pose generation. It must still advance offscreen for identical reentry.
		return Rect2()
	return Rect2(-PixelBody.PIVOT, PixelBody.CELL)


static func outside_viewport(world_bounds: Rect2, camera_origin: Vector2, viewport: Rect2, zoom_percent: int) -> bool:
	# Unknown/invalid inputs fail open. There is no distance, actor-count,
	# previous-camera, identity or cached-visible flag in this decision.
	if not world_bounds.position.is_finite() or not world_bounds.size.is_finite() \
		or not camera_origin.is_finite() or not viewport.position.is_finite() or not viewport.size.is_finite() \
		or not world_bounds.has_area() or not viewport.has_area() or zoom_percent not in PixelPresentation.SUPPORTED_ZOOM:
		return false
	var zoom := PixelPresentation.zoom_scale(zoom_percent)
	var screen_bounds := Rect2(world_bounds.position * zoom + PixelPresentation.snapped_canvas_origin(camera_origin, zoom_percent), world_bounds.size * zoom)
	return not screen_bounds.grow(RASTER_GUARD_PIXELS).intersects(viewport, true)
