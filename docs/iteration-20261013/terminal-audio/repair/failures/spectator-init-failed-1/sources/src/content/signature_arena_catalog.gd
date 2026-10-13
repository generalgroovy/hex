extends RefCounted
## Fresh encounter anchors on real campus collision, not labels on one court.
## These three optional lessons retain ordinary paid combat and an explicit
## administrative boundary. Other rivals keep the existing Proving Court.
const LESSON_COURTS := {
	"wa_bidi":{"arena_id":"conservatory-gap-court","district_id":"conservatory-gardens","bounds":Rect2i(240,720,640,360),"player":Vector2i(440,900),"opponent":Vector2i(670,900),"purpose":"Cross the open lane between Rapid bursts."},
	"oh_tipi":{"arena_id":"tideglass-fuse-court","district_id":"tideglass-quays","bounds":Rect2i(3536,1184,640,512),"player":Vector2i(3680,1440),"opponent":Vector2i(3910,1440),"purpose":"Keep a lateral exit from the committed Fuse landing."},
	"s_wayne":{"arena_id":"basalt-bank-court","district_id":"basalt-foundry","bounds":Rect2i(2496,3264,800,608),"player":Vector2i(2700,3440),"opponent":Vector2i(2930,3440),"purpose":"Read the reflected route from the actual Foundry wall."},
}


static func contract(id: String, layout: SanctumCampusLayout, collision: CollisionWorld) -> Dictionary:
	if layout==null or collision==null or layout.content_hash.is_empty(): return {}
	if not LESSON_COURTS.has(id):
		var original := InterceptionPractice.spawn_contract(layout)
		if original.is_empty(): return {}
		original["district_id"] = "wayfarer-proving-quarter"
		original["district_label"] = "Proving Court"
		original["purpose"] = "Read the signature, then answer during its recovery."
		return original
	var source: Dictionary = LESSON_COURTS[id]
	var district: Dictionary = layout.districts_by_id.get(String(source.district_id),{})
	if district.is_empty(): return {}
	var bounds: Rect2i = source.bounds
	if not SanctumCampusLayout._parse_bounds(district.get("bounds",[])).encloses(bounds): return {}
	var player: Vector2i = source.player
	var opponent: Vector2i = source.opponent
	for point: Vector2i in [player,opponent]:
		if not bounds.grow(-40).has_point(point) or not collision.can_occupy(point*SimConfig.FIXED_SCALE,MovementTuning.PLAYER_RADIUS): return {}
	return {"arena_id":String(source.arena_id),"district_id":String(source.district_id),"district_label":String(district.label),"purpose":String(source.purpose),
		"bounds":bounds,"player_spawn_px":player,"opponent_spawn_px":opponent,
		"player_spawn_fixed":player*SimConfig.FIXED_SCALE,"opponent_spawn_fixed":opponent*SimConfig.FIXED_SCALE}
