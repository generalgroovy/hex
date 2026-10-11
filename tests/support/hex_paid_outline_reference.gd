extends HexCourtPresenter

# Exact pre-batch outline and mark dispatch, 2026-10-10. Presentation-only
# native A/B oracle; authority and all unrelated drawing remain the base class.

func _draw_region_outline(canvas: CanvasItem, region: Dictionary, edge_counts: Dictionary, color: Color, width: float) -> void:
	var polygon: PackedVector2Array = region.polygon
	var fixed_polygon: PackedVector2Array = region.fixed_polygon
	var prefix := _region_edge_prefix(region)
	var segments := _boundary_segments(fixed_polygon)
	var geometry: Array = []
	for index: int in polygon.size():
		var key := prefix + segments[index]
		if int(edge_counts.get(key, 0)) > 1:
			continue
		if geometry.is_empty(): geometry = _boundary_triangles(polygon, width)
		# Draw the cell boundary inward so hazard ink remains inside the complete
		# authoritative selected hex, including in reduced-effects mode.
		for triangle: Array in geometry[index]:
			canvas.draw_primitive(PackedVector2Array(triangle), PackedColorArray([color]), PackedVector2Array())


func _draw_shared_material_mark(canvas: CanvasItem, region: Dictionary, style: Dictionary, tick: float, seed: int, reduced: bool, surface_painted: bool = false) -> void:
	var polygon: PackedVector2Array = region.polygon
	var center := _polygon_centroid(polygon)
	var radius := _polygon_clearance(center, polygon) - 3.0
	if radius < 4.0:
		return
	radius *= float(style.get("mark_scale", 1.0))
	var shape := String(style.shape)
	var material := String(style.get("visual_material", style.material))
	if bool(style.get("backdraft_warning", false)):
		# One stable impending-burst mark replaces the veil motif in both modes.
		canvas.draw_line(center + Vector2(0, -radius * 0.55), center + Vector2(0, radius * 0.18), Color(style.bright), 3.0)
		canvas.draw_rect(Rect2(center + Vector2(-1.5, radius * 0.40), Vector2(3, 3)), Color(style.bright))
		return
	# The native surface replaces the emblem, not essential physical-cover or
	# directional information. Keep exactly the previously reached cue branches.
	var retain_cover := String(region.phase) == "active" and material in ["permafrost", "grounding_network", "crystal_prism", "crystal_lens"]
	if surface_painted and not retain_cover:
		if int(style.wire_id) == 301 and String(region.phase) == "active":
			_draw_earth_pillar(canvas, polygon, style.dark, style.base, style.bright, radius)
			return
		if material in COMBAT_PHASE_MATERIALS or material in ["earth", "wind", "mud", "magma", "vortex", "ice", "charge", "light", "dark"]:
			return
		if material not in ["firestorm", "dustfront", "mistcurrent"] and shape not in ["corridor", "flow", "water_path", "growing_strip", "pulse_lane", "bands", "frost_path", "reveal_line"]:
			return
	if material in COMBAT_PHASE_MATERIALS:
		# One bounded retro stamp replaces several thin line segments. It follows
		# the existing harmless-warning/active/decay scale and stays clipped inside
		# the authoritative cell; the unchanged fill/outline communicates reach.
		var mark_polygon := PackedVector2Array()
		var scale := float(style.get("mark_scale", 1.0))
		for point: Vector2 in polygon: mark_polygon.append(center + (point - center) * scale)
		var mark_base: Color = style.base if String(region.phase) == "active" else style.bright
		if retro_marks.draw_region(canvas, material, mark_polygon, style.dark, mark_base, style.bright, tick, seed,
			reduced or String(region.phase) != "active", 0.98 if bool(style.danger) else 0.72):
			return
	if material == "earth":
		# Loose, harmless ingredient stock must not imply an active solid pillar.
		if retro_marks.draw_region(canvas, "earth", polygon, style.dark, style.base, style.bright, tick, seed, true):
			return
		for offset: Vector2 in [Vector2(-0.30, 0.12), Vector2(0.22, -0.20), Vector2(0.31, 0.30)]:
			var pebble := center + offset * radius
			canvas.draw_rect(Rect2(pebble - Vector2(3, 2), Vector2(6, 4)), Color(style.dark, 0.82))
			canvas.draw_line(pebble - Vector2(2, 2), pebble + Vector2(2, -2), Color(style.bright, 0.88), 1.0)
		return
	if int(style.wire_id) == 301 and String(region.get("phase", "")) == "active":
		_draw_earth_pillar(canvas, polygon, style.dark, style.base, style.bright, radius)
		return
	# Compact material stamps replace smooth glyphs for the most common cells.
	# Cover, directional lanes and warning/decay boundaries retain their specific
	# grammar. The exact cell fill/border continues to define the real footprint.
	if material in ["wind", "mud", "magma", "vortex", "ice", "charge", "light", "dark"]:
		if retro_marks.draw_region(canvas, material, polygon, style.dark, style.base, style.bright, tick, seed, reduced, 0.94 if String(style.phase) == "active" else 0.72):
			return
	var motion := 0.0 if reduced else sin((tick + float(seed % 71)) * _cadence_rate(String(style.cadence))) * minf(2.0, radius * 0.08)
	var direction := Vector2(region.get("direction", Vector2i(0, -1000))).normalized()
	if direction.is_zero_approx():
		direction = Vector2.UP
	var side := Vector2(-direction.y, direction.x)
	if material == "firestorm":
		if not surface_painted or String(region.phase) != "active":
			_draw_fire_region_mark(canvas, polygon, style.phase, style.dark, style.base, style.bright, style.bright, tick, seed, reduced)
		# Arrowheads indicate front travel; the flame remains the danger mark.
		for sign_value: float in [-1.0, 1.0]:
			var tip := center + side * radius * 0.62 * sign_value + direction * radius * 0.18
			canvas.draw_polyline(PackedVector2Array([tip - direction * radius * 0.22 - side * radius * 0.12, tip, tip - direction * radius * 0.22 + side * radius * 0.12]), Color(style.bright, 0.90), 2.0, false)
		return
	if material == "magma":
		var crack := PackedVector2Array([center + Vector2(-0.66, 0.35) * radius, center + Vector2(-0.16, 0.03) * radius, center + Vector2(0.18, 0.16) * radius, center + Vector2(0.58, -0.44) * radius])
		canvas.draw_polyline(crack, Color(style.dark, 0.96), 6.0, false)
		canvas.draw_polyline(crack, Color(style.bright, 0.96), 2.0, false)
		canvas.draw_line(center + Vector2(-0.16, 0.03) * radius, center + Vector2(-0.34, -0.48) * radius, Color(style.base, 0.96), 3.0)
		return
	if material in ["dustfront", "mistcurrent"]:
		var flow := side if material == "dustfront" else direction
		var flow_side := Vector2(-flow.y, flow.x)
		for lane: float in [-0.32, 0.32]:
			var tip := center + flow * radius * (0.36 + motion / maxf(radius, 1.0)) + flow_side * lane * radius
			canvas.draw_polyline(PackedVector2Array([tip - flow * radius * 0.48 - flow_side * radius * 0.16, tip, tip - flow * radius * 0.48 + flow_side * radius * 0.16]), Color(style.bright, 0.94), 2.0, false)
		return
	if material == "wind" or shape in ["corridor", "flow", "water_path", "growing_strip", "pulse_lane", "bands", "frost_path", "reveal_line"]:
		for lane: float in [-0.34, 0.0, 0.34]:
			var lane_center := center + side * radius * lane + direction * motion
			canvas.draw_line(lane_center - direction * radius * 0.56, lane_center + direction * radius * 0.56, Color(style.bright, 0.82), 2.0)
		return
	if material == "vortex":
		var angle := 0.0 if reduced else tick * 0.035
		for spoke: int in 3:
			var start := angle + float(spoke) * TAU / 3.0
			var finish := start + PI * 0.43
			canvas.draw_polyline(_arc_points(center, radius * 0.63, start, finish, 9), Color(style.bright, 0.92), 2.0, false)
			var tip := center + Vector2.from_angle(finish) * radius * 0.63
			var tangent := Vector2(-sin(finish), cos(finish))
			var radial := Vector2.from_angle(finish)
			canvas.draw_polyline(PackedVector2Array([tip - tangent * radius * 0.23 - radial * radius * 0.12, tip, tip - tangent * radius * 0.23 + radial * radius * 0.12]), Color(style.dark, 0.94), 2.0, false)
		return
	if shape in ["ring", "annulus", "border"]:
		canvas.draw_polyline(_arc_points(center, radius * 0.72, 0.0, TAU, 24), Color(style.dark, 0.86), 3.0, false)
		canvas.draw_polyline(_arc_points(center, radius * 0.46, 0.0, TAU, 20), Color(style.bright, 0.76), 2.0, false)
		return
	if material == "ice" or shape in ["fracture", "lens", "entry_mark"]:
		for arm: int in 6:
			var angle := float(arm) * TAU / 6.0
			canvas.draw_line(center, center + Vector2.from_angle(angle) * radius * 0.68, Color(style.bright, 0.86), 2.0)
		return
	if material == "charge" or shape in ["branch", "node", "drifting_node"]:
		var bolt := PackedVector2Array([
			center + Vector2(-radius * 0.34, -radius * 0.62), center + Vector2(radius * 0.04, -radius * 0.12),
			center + Vector2(-radius * 0.12, -radius * 0.12), center + Vector2(radius * 0.34, radius * 0.62),
		])
		canvas.draw_polyline(bolt, Color(style.bright, 0.94), 3.0, false)
		return
	if material == "light" or shape in ["plane", "reveal_pulse", "observation", "bend", "reveal_area"]:
		var diamond := PackedVector2Array([
			center + Vector2(0, -radius * 0.62), center + Vector2(radius * 0.52, 0),
			center + Vector2(0, radius * 0.62), center + Vector2(-radius * 0.52, 0), center + Vector2(0, -radius * 0.62),
		])
		canvas.draw_polyline(diamond, Color(style.bright, 0.90), 2.0, false)
		return
	if material == "dark" or shape in ["disk", "ember_veil", "motion_veil", "entry_veil", "attrition_veil"]:
		canvas.draw_polyline(_arc_points(center - Vector2(radius * 0.10, 0), radius * 0.54, -PI * 0.70, PI * 0.70, 13), Color(style.dark, 0.88), 3.0, false)
		canvas.draw_polyline(_arc_points(center + Vector2(radius * 0.10, 0), radius * 0.38, -PI * 0.70, PI * 0.70, 11), Color(style.bright, 0.76), 2.0, false)
		return
	# Remaining authored products retain both source colors in a bounded crossed
	# mark. The mark names the recipe family without implying its gameplay rule.
	canvas.draw_line(center - direction * radius * 0.54, center + direction * radius * 0.54, Color(style.dark, 0.90), 3.0)
	canvas.draw_line(center - side * radius * 0.42, center + side * radius * 0.42, Color(style.bright, 0.86), 2.0)
