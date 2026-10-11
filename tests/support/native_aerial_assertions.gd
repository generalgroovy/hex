extends RefCounted
## Independent native geometry oracle shared by full-roster presentation tests.
## This checks draw descriptors; it does not certify the rendered silhouette.

const BALL_ACTIONS := ["jump", "double_jump", "slide_jump", "walljump", "fall", "fast_fall"]
const RADII := {"small": 19, "middle": 22, "large": 25}
const HEIGHTS := {"small": 58, "middle": 63, "large": 68}


static func assert_frame(suite: FluxTestSuite, frame: Dictionary, bank: RefCounted, id: String, action: String, aim: int) -> void:
	var flying := action == "fly"
	var body: String = bank.entries[id].body
	var radius: int = RADII[body]
	suite.check(flying or action in BALL_ACTIONS, "native aerial assembly is limited to the explicitly authorized aerial states")
	suite.check(frame.get("procedural_pixel_pose", false), "aerial assembly explicitly discloses its native-part construction")
	suite.equal(frame.get("aerial_pose"), "open_flight" if flying else "tucked_ball", "actual aerial state selects the appropriate open or compact silhouette")
	suite.check(not frame.get("pixel_action_key", true) and not frame.get("rigid_pose_fallback", false), "assembled aerial pose claims neither new painted keys nor a whole-body fallback")
	suite.check(not frame.get("all_action_art_complete", true) and not frame.get("independent_cast_pose", false), "aerial parts do not claim complete action art or separate casting hands")
	suite.equal(frame.get("components", []), [], "aerial assembly contains no hidden upright whole-body blit")
	suite.equal(frame.get("pixel_shapes", []), [], "aerial silhouette contains no backing disc or replacement painted body")
	suite.equal(frame.get("texture"), bank.action_bank.textures[id], "all aerial parts use exactly this identity's admitted native action atlas")
	suite.check(String(frame.get("frame_id", "")).begins_with(id + "/aerial/" + action + "/"), "aerial descriptor retains its actual identity and action")
	suite.equal(frame.get("aim_index"), aim, "aerial source crops preserve instantaneous independent aim")
	suite.equal(frame.get("display_height"), HEIGHTS[body] if flying else radius * 2, "open flight retains native height and tuck has the independently specified compact diameter")
	suite.equal(frame.get("body_bounds"), Rect2(-64, -104, 128, 128) if flying else Rect2(-radius, -radius * 2, radius * 2, radius * 2), "anchor-relative aerial envelope has exact support registration")
	suite.check(not frame.has("pivot") and not frame.has("cell_size"), "anchor-relative parts are never subjected to a second atlas-cell pivot")
	suite.equal(frame.get("offset"), Vector2.ZERO, "aerial assembly adds no overall bob or anchor correction")
	var parts: Array = frame.get("pixel_parts", [])
	suite.equal(parts.size(), 5 if flying else 4, "flight retains five native strips; tuck retains torso, two folded limbs and face")
	if flying and parts.size() == 5:
		suite.equal(parts[1].at, Vector2(-14, -104), "original central face and torso remain completely stationary while wings move")
		suite.equal(parts[3].at, Vector2(-64, -12), "left lower anatomy keeps its original native registration")
		suite.equal(parts[4].at, Vector2(14, -12), "right lower anatomy keeps its original native registration")
		suite.equal(parts[0].at.x, -64.0, "left wing never changes its original horizontal registration")
		suite.equal(parts[2].at.x, 14.0, "right wing never changes its original horizontal registration")
		suite.check(parts[0].at.y in [-107.0, -104.0, -101.0] and parts[2].at.y == parts[0].at.y, "outer native wings use the same bounded three-pixel held key")
	if not flying:
		suite.equal((frame.source_region as Rect2).size, (frame.head_destination as Rect2).size, "face crops preserve their exact native painted size")
	var atlas := Rect2(0, 0, 1024, 512)
	var column := Rect2(aim * 128, 0, 128, 512)
	for part: Dictionary in parts:
		var source: Rect2 = part.source
		var rotation := float(part.rotation)
		suite.check(source.has_area() and atlas.encloses(source) and column.encloses(source), "every native part remains inside its own identity atlas and exact aim column")
		suite.check(is_zero_approx(rotation) or is_equal_approx(absf(rotation), PI / 2.0), "native parts use only pixel-preserving quarter turns")
		suite.check(not part.has("scale"), "native anatomy is never resized to fit the new silhouette")
		if flying:
			suite.check(not part.has("meshes") and is_zero_approx(rotation), "open flight uses unchanged native strips without clipping or rotation")
			var at: Vector2 = part.at
			suite.check(is_finite(at.x) and is_finite(at.y) and at == at.round(), "every flight destination is finite and registered on the native pixel grid")
			suite.check(Rect2(-64, -107, 128, 134).encloses(Rect2(at, source.size)), "actual flight strips stay within their exact native width and explicit three-pixel vertical wing allowance")
			continue
		suite.check(part.has("meshes"), "compact native anatomy explicitly carries its round clipping geometry")
		suite.check(not part.get("meshes", []).is_empty(), "each original torso, limb and face retains visible clipping geometry")
		for mesh: Dictionary in part.get("meshes", []):
			var points: PackedVector2Array = mesh.points
			var uvs: PackedVector2Array = mesh.uvs
			suite.check(points.size() >= 3 and points.size() == uvs.size(), "every clipped polygon has a complete native UV for each vertex")
			var twice_area := 0.0
			for index: int in points.size(): twice_area += points[index].cross(points[(index + 1) % points.size()])
			suite.check(absf(twice_area) > 0.0, "each clipped native polygon has positive visible area rather than a collapsed line")
			for index: int in points.size():
				var point := points[index]
				var sampled := uvs[index] * Vector2(1024, 512)
				suite.check(point.distance_to(Vector2(0, -radius)) <= radius + 0.75, "all visible native anatomy stays inside the independently bounded compact circle")
				suite.check(source.grow(0.001).has_point(sampled), "round clipping still samples only the selected native body part")
				suite.equal(point, point.round(), "held quarter-turn keys retain exact pixel-grid vertices")
