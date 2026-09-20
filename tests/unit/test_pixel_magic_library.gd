extends FluxTestSuite

const Library = preload("res://src/presentation/pixel_magic_library.gd")
var library := Library.new()
var document: Dictionary = {}


func run() -> int:
	document = JSON.parse_string(FileAccess.get_file_as_string(Library.MANIFEST_PATH))
	check(library.load_from_file(), "all three raw-hash-verified imported magic pages load upfront: %s" % library.last_error)
	if library.asset_count() == 0:
		return finish("pixel-magic-library")
	equal(library.page_count(), 3, "magic prepares exactly three shared textures")
	equal(library.asset_count(), 474, "all authored normal/reduced sequences are addressable")
	# B1 audit: strength admission changes which deposits may combine; authored
	# recipe geometry, phases, pulses and atlas pixels are unchanged. Preserve the
	# original art manifest and acknowledge only this reviewed source difference.
	# Evidence: four-delivery-b-20260913/provenance-final-review.md.
	# S1 adds phase/danger roles while preserving all eight element and legacy
	# Steam atlas RGB tokens. The pixel palette checks below verify that boundary.
	var reviewed_differences: Array[String] = ["src/sim/chemistry/element_chemistry_system.gd", "content/visual/visual_language_v1.json"]
	equal(library.source_hash_differences, reviewed_differences, "reviewed source snapshot has no unexplained drift")
	equal(FileAccess.get_sha256("res://src/sim/chemistry/element_chemistry_system.gd"), "26d35914ab43742fec06e9670cb436edc77e9be5ee3de424d8c30b05ee1a0339", "reviewed B1 strength admission preserves authored visual footprints and lifecycles; future authority drift requires renewed audit")
	equal(library.content_hash, FileAccess.get_sha256(Library.MANIFEST_PATH), "library identity comes from the current raw manifest")
	var stale_snapshot: Dictionary = document.duplicate(true)
	stale_snapshot["source_files"][1]["sha256"] = "a".repeat(64)
	var stale_library := Library.new()
	check(stale_library.load_from_manifest(stale_snapshot), "stale source evidence does not replace structural gameplay validation")
	equal(stale_library.source_hash_differences, [reviewed_differences[0], String(stale_snapshot["source_files"][1]["path"]), reviewed_differences[1]], "one additional deliberately stale source hash is reported exactly in manifest order")
	_test_all_frames_and_absolute_clocks()
	_test_canonical_native_palettes()
	_test_lookup_and_orientation()
	_test_invalid_manifests()
	_test_atomic_page_failure_and_singleton()
	_test_shared_decoration_budget()
	return finish("pixel-magic-library")


func _test_canonical_native_palettes() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "atlas palette audit uses the same canonical language as HUD and glyphs")
	var recipes := {}
	for recipe: Dictionary in document["reactions"]:
		recipes[String(recipe.id)] = recipe.elements
	var inspected := 0
	for authored: Dictionary in document["assets"]:
		var element: Variant = authored.get("element_id")
		var reaction: Variant = authored.get("reaction_id")
		var families: Array = []
		if element != null and String(element) in VisualLanguage.ACTIVE_ELEMENTS:
			families = [String(element)]
		elif reaction != null and recipes.has(String(reaction)):
			families = ["steam"] if String(reaction) == "steam" else recipes[String(reaction)]
		else:
			continue
		for family: String in families:
			for role: String in ["dark", "base", "bright"]:
				var color := Color(String(language.data.reaction_materials.steam[role])) if family == "steam" else language.element_color(family, role)
				check(color.to_html(true) in authored.palette_rgba, "native flight/impact/field/reaction palette matches canonical categorical hue: " + String(authored.id) + " / " + family + " / " + role)
		inspected += 1
	check(inspected >= 400, "palette audit covers all elemental and reaction sequences, not only UI chips")


func _test_all_frames_and_absolute_clocks() -> void:
	var textures := {}
	var frame_count := 0
	for authored: Dictionary in document["assets"]:
		var asset_id := String(authored["id"])
		var prepared := library.asset(asset_id)
		check(prepared.is_read_only() and (prepared["sampled_frames"] as Array).is_read_only() and (prepared["frame_ends"] as Array).is_read_only(), "prepared frame registry cannot be resized or retimed by callers")
		var total := 0
		for index: int in range(authored["frames"].size()):
			var frame: Dictionary = authored["frames"][index]
			var sampled := library.sample(asset_id, total)
			equal(sampled["index"], index, "declared duration boundary starts the exact next frame")
			equal(library.frame_index(asset_id, total + int(frame["duration_ticks"]) - 1), index, "a pose holds through its last declared120Hz tick")
			check(sampled.is_read_only(), "sample returns prepared read-only frame metadata")
			var texture: Texture2D = sampled["texture"]
			textures[texture.get_instance_id()] = true
			equal(texture.get_size(), Vector2(1024, 1024), "every frame references one full nearest atlas page")
			var rect: Array = frame["rect"]
			equal(sampled["region"], Rect2(rect[0], rect[1], rect[2], rect[3]), "sample preserves exact untrimmed author rectangle")
			equal(sampled["pivot"], Vector2(frame["pivot_px"][0], frame["pivot_px"][1]), "sample retains the stable authored attachment pivot")
			equal((sampled["local_rect"] as Rect2).position + (sampled["pivot"] as Vector2), Vector2.ZERO, "every animation pose resolves the same local attachment anchor")
			var uvs: PackedVector2Array = sampled["uvs"]
			equal(uvs.size(), 4, "rotated stamp uses one prepared four-corner UV set")
			equal(uvs[0], Vector2(rect[0], rect[1]) / 1024.0, "first normalized UV begins at the exact atlas cell")
			equal(uvs[2], Vector2(rect[0] + rect[2], rect[1] + rect[3]) / 1024.0, "last normalized UV ends before the transparent gutter")
			total += int(frame["duration_ticks"])
			frame_count += 1
		equal(library.frame_index(asset_id, -1), -1, "unborn sequence never draws")
		equal(library.frame_index(asset_id, 0, false), -1, "authority cancellation hides even the first pose")
		check(library.sample(asset_id, total * 10, false).is_empty(), "held and looping information disappears on exact authority exit")
		for age: int in range(total + 2):
			equal(library.frame_index(asset_id, age), _reference_frame(authored, age), "absolute phase sampling agrees with independent duration walk")
		for age: int in [total, total * 3 + 1, 1_000_000_000]:
			equal(library.frame_index(asset_id, age), _reference_frame(authored, age), "large skipped/render-independent age preserves exact loop or end behavior")
		if bool(authored["loop"]):
			equal(library.frame_index(asset_id, total), 0, "loop wraps precisely at summed durations")
		elif authored["end_behavior"] == "hide":
			check(library.sample(asset_id, total).is_empty(), "one-shot sequence vanishes at its own finite end")
		else:
			equal(library.frame_index(asset_id, total), authored["frames"].size() - 1, "hold behavior keeps last pose only inside the same live authority phase")
	equal(frame_count, 1960, "all1960 actual authored frames were sampled")
	equal(textures.size(), 3, "1960 frames share three textures without per-frame texture allocation")


static func _reference_frame(authored: Dictionary, elapsed: int) -> int:
	if elapsed < 0:
		return -1
	var durations: Array[int] = []
	var total := 0
	for frame: Dictionary in authored["frames"]:
		var duration := int(frame["duration_ticks"])
		durations.append(duration)
		total += duration
	if bool(authored["loop"]):
		elapsed %= total
	elif elapsed >= total:
		return -1 if authored["end_behavior"] == "hide" else durations.size() - 1
	for index: int in range(durations.size()):
		elapsed -= durations[index]
		if elapsed < 0:
			return index
	return -1


func _test_lookup_and_orientation() -> void:
	for element: int in range(1, 9):
		for effect: String in Library.EFFECTS:
			for reduced: bool in [false, true]:
				check(not library.asset(Library.element_asset_id(element, effect, reduced)).is_empty(), "every elemental effect selects its requested accessibility variant")
	for wire: int in range(301, 337):
		check(library.reaction(wire).is_read_only(), "reaction binding is shared read-only metadata")
		for phase: String in Library.PHASES:
			for reduced: bool in [false, true]:
				var asset_id := library.reaction_asset_id(wire, phase, reduced)
				equal(library.asset(asset_id)["lifecycle_phase"], phase, "reaction phase chooses correct current phase, not an independent animation clock")
	for effect: String in Library.MOVEMENT:
		check(not library.asset(Library.movement_asset_id(effect)).is_empty(), "all movement components have stable lookup")
	for invalid: String in ["", "magic.missing.normal", "../magic.fire.flight.normal"]:
		check(library.asset(invalid).is_empty() and library.sample(invalid, 0).is_empty() and library.frame_index(invalid, 0) == -1, "unknown asset fails closed without invented art")
	equal(Library.element_asset_id(9, "flight"), "", "unimplemented element does not alias an existing kit")
	equal(Library.element_asset_id(2, "missing"), "", "unknown elemental component does not fabricate an ID")
	equal(library.reaction_asset_id(337, "active"), "", "unknown recipe has no phase binding")
	equal(library.reaction_asset_id(301, "expired"), "", "expired recipe has no active visual binding")
	for angle: float in [-PI, -0.773, 0.0, 0.333, PI]:
		equal(library.rotation_for("magic.fire.flight_tail.normal", angle), angle, "east strip retains continuous cosmetic rotation")
		equal(library.rotation_for("magic.fire.flight.normal", angle), 0.0, "asymmetric projectile billboard stays upright")
	equal(library.rotation_for("magic.fire.flight_tail.normal", NAN), 0.0, "invalid cosmetic angle cannot poison canvas transform")
	check(not library.draw_stamp(null, "magic.fire.flight.normal", Vector2.ZERO, 0), "missing canvas is a safe no-op")
	var canvas := Node2D.new()
	check(not library.draw_stamp(canvas, "magic.fire.flight.normal", Vector2.ZERO, 0, 0.0, 0.0), "zero opacity creates no draw command")
	check(not library.draw_stamp(canvas, "magic.movement.air_dash_afterimage_mask.normal", Vector2.ZERO, 0), "body stencil cannot draw replacement body pixels")
	canvas.free()


func _test_invalid_manifests() -> void:
	var mutations: Array[Callable] = [
		func(data: Dictionary) -> void: data["schema_version"] = 1.5,
		func(data: Dictionary) -> void: data["namespace"] = "other",
		func(data: Dictionary) -> void: data["import_rules"]["filter"] = "linear",
		func(data: Dictionary) -> void: data["import_rules"]["mipmaps"] = true,
		func(data: Dictionary) -> void: data["atlases"].pop_back(),
		func(data: Dictionary) -> void: data["atlases"][0]["path"] = "../outside.png",
		func(data: Dictionary) -> void: data["atlases"][0]["sha256"] = "invalid",
		func(data: Dictionary) -> void: data["atlases"][0]["width"] = 2048,
		func(data: Dictionary) -> void: data["atlases"][0]["decoded_bytes"] = 1,
		func(data: Dictionary) -> void: data["budgets"]["decoded_rgba_bytes"] = 1,
		func(data: Dictionary) -> void: data["source_files"][0]["path"] = "../outside.gd",
		func(data: Dictionary) -> void: data["assets"].pop_back(),
		func(data: Dictionary) -> void: data["assets"][1] = data["assets"][0].duplicate(true),
		func(data: Dictionary) -> void: data["assets"][0]["frames"] = [],
		func(data: Dictionary) -> void: data["assets"][0]["frames"][0]["duration_ticks"] = 0,
		func(data: Dictionary) -> void: data["assets"][0]["frames"][0]["duration_ticks"] = 1.25,
		func(data: Dictionary) -> void: data["assets"][0]["frames"][0]["duration_ticks"] = true,
		func(data: Dictionary) -> void: data["assets"][0]["frames"][0]["pivot_px"] = [1, 1],
		func(data: Dictionary) -> void: data["assets"][0]["pivot_px"] = [-1, 0],
		func(data: Dictionary) -> void: data["assets"][0]["frames"][0]["rect"] = [1020, 1020, 16, 12],
		func(data: Dictionary) -> void: data["assets"][0]["frames"][0]["rect"][0] = 1,
		func(data: Dictionary) -> void: data["assets"][0]["frames"][0]["rect"][2] = 15,
		func(data: Dictionary) -> void: data["assets"][0]["frames"][0]["rect"] = [2, 2, 16],
		func(data: Dictionary) -> void: data["assets"][0]["duration_tick_rate"] = 60,
		func(data: Dictionary) -> void: data["assets"][0]["loop"] = 1,
		func(data: Dictionary) -> void: data["assets"][0]["end_behavior"] = "continue_gameplay",
		func(data: Dictionary) -> void: data["assets"][0]["direction"] = "snap_eight_way",
		func(data: Dictionary) -> void: data["assets"][0]["attachment"]["pivot_stable_all_frames"] = false,
		func(data: Dictionary) -> void: data["assets"][0]["source_path"] = "../../other.json",
		func(data: Dictionary) -> void: data["reactions"].pop_back(),
		func(data: Dictionary) -> void: data["reactions"][0]["formation_ticks"] += 1,
		func(data: Dictionary) -> void: data["reactions"][0]["nominal_radius_px"] += 1,
		func(data: Dictionary) -> void: data["reactions"][0]["shape"] = "disk",
		func(data: Dictionary) -> void: data["reactions"][0]["phases"]["active"]["normal"] = "magic.reaction.mud.active.normal",
		func(data: Dictionary) -> void: data["deposit_lifetime_ticks"]["fire"] += 1,
	]
	for index: int in range(mutations.size()):
		var altered := document.duplicate(true)
		mutations[index].call(altered)
		var rejected := Library.new()
		check(not rejected.validate_manifest(altered), "malformed metadata case%d fails closed" % index)
		check(not rejected.last_error.is_empty(), "malformed metadata provides a useful diagnostic")
	var unrelated_hash := document.duplicate(true)
	unrelated_hash["source_files"][0]["sha256"] = "0".repeat(64)
	check(Library.new().validate_manifest(unrelated_hash), "source byte drift alone is not a gameplay contract change")


func _test_atomic_page_failure_and_singleton() -> void:
	var bad_hash := document.duplicate(true)
	bad_hash["atlases"][2]["sha256"] = "0".repeat(64)
	var rejected := Library.new()
	check(not rejected.load_from_manifest(bad_hash), "corrupted third page hash refuses the complete pack")
	check(rejected.asset_count() == 0 and rejected.page_count() == 0 and rejected.content_hash.is_empty(), "third-page failure publishes no partial texture or frame registry")
	check(rejected.last_error.contains("magic_02.png"), "page hash failure identifies the exact invalid artifact")
	check(not rejected.load_from_file("res://missing-magic-pack.json"), "missing manifest fails without fallback fabrication")
	check(rejected.sample("magic.fire.flight.normal", 0).is_empty(), "failed load cannot expose stale frame state")
	var shared := Library.default_library()
	check(shared == Library.default_library(), "all presenters receive the same shared library instance")
	equal(shared.page_count(), 3, "shared library performs one complete three-page initialization")
	check(shared.sample("magic.fire.flight.normal", 0)["texture"] == Library.default_library().sample("magic.fire.flight.normal", 0)["texture"], "shared sampling reuses the same imported texture object")


func _test_shared_decoration_budget() -> void:
	var shared := Library.default_library()
	for reduced: bool in [false, true]:
		shared.begin_frame(reduced)
		var accepted := 0
		for element: int in range(1, 9):
			var asset_id := Library.element_asset_id(element, "deposit_active", reduced)
			var asset_accepted := 0
			for attempt: int in range(100):
				if shared.take_decoration(asset_id):
					accepted += 1
					asset_accepted += 1
			check(asset_accepted <= int(shared.asset(asset_id)["intended_simultaneous_instance_budget"]), "shared admission retains each authored instance bound")
		equal(accepted, 96 if reduced else 192, "all presentation consumers share the exact normal/reduced budget")
		equal(shared.decoration_remaining(), 0, "global exhaustion is observable without allocating another frame model")
		check(not Library.default_library().take_decoration(Library.element_asset_id(2, "spray_grain", reduced)), "another presenter cannot obtain extra spray decoration after shared chemistry exhausts the budget")
		for id: String in ["magic.fire.flight.normal", "magic.geometry.boundary_active.normal", "magic.geometry.connected_node.normal", "magic.movement.protection_badge.normal"]:
			check(shared.take_decoration(id), "projectile cores and essential information survive total decorative exhaustion")
		equal(shared.decoration_stats().used, accepted, "essential cues never consume or replenish optional capacity")
	check(not shared.take_decoration("magic.unknown.normal"), "unknown decoration fails without consuming or inventing a component")
	shared.begin_frame()
	equal(shared.decoration_remaining(), 192, "next actual canvas frame explicitly restores the normal budget")
