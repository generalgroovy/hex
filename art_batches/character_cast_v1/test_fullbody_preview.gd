extends SceneTree

const Gallery = preload("res://art_batches/character_cast_v1/fullbody_preview.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	check(Gallery.DIRECTIONS == ["S", "SE", "E", "NE", "N", "NW", "W", "SW"], "eight-facing order")
	check(Gallery.CELL == Vector2i(96,96), "fixed cell")
	check(Gallery.PIVOT == Vector2(48,84), "fixed foot registration")
	var numbers: Variant = JSON.parse_string("[96,96]")
	check(Gallery.exact_numbers(numbers,[96,96]), "JSON floating numeric representation accepted exactly")
	check(Gallery.exact_numbers([0,0,96,96],[0,0,96,96]), "rectangle accepted")
	for bad: Variant in [null, [], [96], [96,96,96], [true,96], ["96",96], [96.1,96], [NAN,96], [INF,96]]:
		check(not Gallery.exact_numbers(bad,[96,96]), "malformed geometry rejected")
	check(Gallery.valid_sha("a".repeat(64)), "sha256 accepted")
	for bad: Variant in [null, 64, "", "a".repeat(63), "a".repeat(65), "g".repeat(64), "A".repeat(64)]:
		check(not Gallery.valid_sha(bad), "malformed hash rejected")
	check(Gallery.safe_root("res://art_batches/character_cast_v1/output/review/manifest.json"), "staged output root")
	for unsafe: String in ["res://assets/manifest.json", "C:/outside/manifest.json", "res://art_batches/character_cast_v1/output/../manifest.json", "res://art_batches/character_cast_v1/output/a\\manifest.json"]:
		check(not Gallery.safe_root(unsafe), "unsafe root rejected")
	check(Gallery.safe_leaf("oh_tipi.png"), "local atlas leaf")
	for unsafe: String in ["", "../x.png", "a/x.png", "a\\x.png", "res://x.png", "C:x.png"]:
		check(not Gallery.safe_leaf(unsafe), "unsafe atlas leaf rejected")
	if failures == 0:
		print("PASS: full-body gallery contract %d checks; native rendering not established" % checks)
	quit(1 if failures else 0)
