extends SceneTree

const Preview = preload("res://art_batches/race_sprite_factory_v1/preview.gd")
var failed := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed += 1
		push_error(message)

func _initialize() -> void:
	check(Preview.INTERACTIVE_ANCHOR == Vector2(650, 540), "mouse aim and drawing share the same on-screen feet pivot")
	check(Preview.direction_index((Preview.INTERACTIVE_ANCHOR + Vector2(100, 0)) - Preview.INTERACTIVE_ANCHOR) == 2, "cursor directly right of displayed actor aims east")
	check(Preview.direction_index((Preview.INTERACTIVE_ANCHOR + Vector2(0, -100)) - Preview.INTERACTIVE_ANCHOR) == 4, "cursor directly above displayed actor aims north")
	var fixture: Variant = JSON.parse_string('{"cell":[96,96],"pivot":[48,84],"dimensions":[1536,6624],"directions":["S","SE","E","NE","N","NW","W","SW"],"rows":["grounded","jump","cast","hit","walk","sprint","slide","roll","walk_b","sprint_b"]}')
	check(fixture is Dictionary, "real JSON fixture decodes")
	check(Preview.number_pair_matches(fixture.cell, Vector2i(96, 96)), "JSON float cell matches exact integer contract")
	check(Preview.number_pair_matches(fixture.pivot, Vector2i(48, 84)), "JSON float pivot matches exact integer contract")
	check(Preview.number_pair_matches(fixture.dimensions, Vector2i(1536, 6624)), "JSON float atlas dimensions match exact integer contract")
	check(fixture.directions == Preview.DIRECTIONS, "JSON facing strings match contract")
	check(fixture.rows == Preview.ROWS, "JSON action strings match contract")
	check(Preview.number_pair_matches([96, 96], Vector2i(96, 96)), "integer pair also accepted")
	for malformed: Variant in [null, [], [96], [96, 96, 96], ["96", 96], [true, 96], [96.5, 96], [NAN, 96], [INF, 96], [-INF, 96], [96, 95]]:
		check(not Preview.number_pair_matches(malformed, Vector2i(96, 96)), "invalid numeric pair rejected without truncation or coercion")
	check(Preview.safe_root("res://.godot/race-sprite-candidates/demo/manifest.json"), "candidate root allowed")
	for unsafe: String in ["res://assets/manifest.json", "res://.godot/race-sprite-candidates/../secret", "C:/outside/manifest.json"]:
		check(not Preview.safe_root(unsafe), "unsafe root rejected")
	for unsafe: String in ["../atlas.png", "res://atlas.png", "sub/atlas.png", "sub\\atlas.png", ""]:
		check(not Preview.safe_leaf(unsafe), "unsafe leaf rejected")
	check(Preview.safe_leaf("seakin-middle-neutral.png"), "atlas leaf allowed")
	for direction: int in 8:
		var angle := direction * PI / 4.0
		check(Preview.direction_index(Vector2(sin(angle), cos(angle))) == direction, "8-direction resolver order")
		check(Preview.frame_key("slide", 0, direction, 0.0, true) == "slide/%d" % direction, "slide follows travel")
		check(Preview.frame_key("grounded", direction, 0, 0.0, false) == "grounded/%d" % direction, "grounded follows aim")
		for aim: int in 8:
			for phase: int in 8:
				for gait: String in ["walk", "sprint"]:
					var expected := "%s/%d/%d/%d" % ["locomotion" if gait == "walk" else "sprint_locomotion", direction, aim, phase]
					check(Preview.frame_key(gait, aim, direction, float(phase) / 8.0, true) == expected, "independent travel/aim/phase key")
	check(Preview.frame_key("walk", 2, 7, 0.5, false) == "walk/2", "stationary never advances locomotion")
	if failed == 0:
		print("PASS: candidate preview contract %d checks; renderer and human review not run" % checks)
	quit(1 if failed else 0)
