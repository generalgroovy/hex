extends FluxTestSuite


func run() -> int:
	_test_repository_language()
	_test_element_color_separation()
	_test_pixel_presentation()
	_test_live_renderer_binding()
	_test_fail_closed_contract()
	return finish("visual-language")


func _test_repository_language() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads: %s" % language.last_error)
	equal(language.ramps.size(), 11, "visual language exposes eleven material/UI ramps")
	equal(language.elements.size(), 12, "all twelve element shape languages are present")
	equal(language.layer_index.size(), 17, "ordered render layers are explicit")
	equal(language.layer_index["actor_shadow"] + 1, language.layer_index["actor"], "actor shadow renders immediately before actor")
	equal(language.layer_index["cutaway"] + 1, language.layer_index["world_prompt"], "world prompts render after cutaways")
	check(language.ramp_color("warm_stone", 4).get_luminance() > language.ramp_color("warm_stone", 0).get_luminance(), "warm-stone ramp orders values dark to light")
	check(language.element_color("water", "bright").get_luminance() > language.element_color("water", "dark").get_luminance(), "element family exposes readable value separation")
	equal(language.ui_metric("combat_hud_maximum_height"), 104, "combat HUD height budget is canonical")
	var perspective: Dictionary = language.data.get("perspective_contract", {})
	equal(String(perspective.get("projection")), "top_down_cardinal_with_tilted_facades", "perspective preserves cardinal-friendly floors")
	check(bool(perspective.get("forbid_diamond_grid")), "misleading diamond navigation is explicitly forbidden")
	equal(perspective.foreground_cutaway_required, false, "current map never requires automatic proximity fading")
	equal(perspective.worldbone_opaque, true, "worldbone remains opaque")
	var character: Dictionary = language.data.get("character_contract", {})
	check(VisualLanguage._numeric_array_equals(character.get("head_height_ratio"), [0.20, 0.23]), "cartoon champions reserve a mature compact ordinary-head read")
	equal(character.get("required_directions"), CartoonChampionPresenter.EXPECTED_DIRECTIONS, "art and runtime agree on all eight headings")
	equal(character.get("required_silhouette_states"), CartoonChampionPresenter.EXPECTED_ATLAS_STATES, "art contract matches runtime ten action/contact rows")
	equal((character.get("required_directions") as Array).size() * (character.get("required_silhouette_states") as Array).size(), 80, "silhouette checklist covers all80 cells")
	for body: String in VisualLanguage.CHARACTER_BODY_HEIGHTS:
		equal(float(character.body_heights[body]), float(VisualLanguage.CHARACTER_BODY_HEIGHTS[body]), "exact registered height: " + body)
	equal(character.portrait_source, "south_grounded_occupied_top_third", "portraits use front sprite top third")
	check(character.preserve_sensible_anatomy and character.preserve_fixed_body_scale and character.forbid_photorealistic_rendering, "sensible proportions are compatible with expressive pixel rendering")
	var active: Array = language.data.element_availability.active
	equal(active.size(), AbilityCatalog.FIRST_EIGHT_ELEMENTS.size(), "only current eight elements are active")
	for element: String in AbilityCatalog.FIRST_EIGHT_ELEMENTS:
		check(element in active, "active palette includes live element: " + element)
	for element: String in VisualLanguage.RESERVED_ELEMENT_STYLES:
		check(element not in active and element in language.elements, "reserved style remains compatible without claiming playability: " + element)
	check(language.content_hash().length() == 64, "visual language exposes a stable content hash")


func _test_element_color_separation() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "canonical color coding loads")
	for element: String in VisualLanguage.ACTIVE_ELEMENTS:
		var base := language.element_color(element)
		var shadow := language.element_color(element, "dark")
		var bright := language.element_color(element, "bright")
		check(bright.get_luminance() > base.get_luminance() and base.get_luminance() > shadow.get_luminance(), "each element retains dark silhouette / colored body / bright accent: " + element)
		check(base.s >= (0.20 if element == "light" else 0.65), "native body retains its categorical hue rather than near-white wash: " + element)
		for other: String in VisualLanguage.ACTIVE_ELEMENTS:
			if other <= element:
				continue
			var compare := language.element_color(other)
			check(Vector3(base.r, base.g, base.b).distance_to(Vector3(compare.r, compare.g, compare.b)) > 0.25, "element bodies remain color-separated: " + element + " / " + other)
	var steam := Color(String(language.data.reaction_materials.steam.base))
	check(steam.s < 0.12, "legacy Steam atlas base remains unchanged for preserved pixel assets")
	var active_steam := language.reaction_phase_color("steam", "active", "base")
	var scald := language.reaction_phase_color("steam", "active", "danger")
	check(active_steam.b > active_steam.r and active_steam.s < 0.30, "S1 active Steam has pale blue-gray vapor")
	check(scald.r > scald.b and scald.s > 0.45, "Steam scalding uses a distinct warm danger accent")
	equal(language.element_phase_color("water", "active"), language.element_color("water"), "Water phase lookup keeps canonical saturated blue")
	check(language.element_color("ice").g > language.element_color("water").g + 0.30, "Ice cyan remains distinctly greener than Water blue")
	check(language.element_color("charge").s > language.element_color("light").s + 0.45, "Charge yellow stays distinct from ivory Light")


func _test_pixel_presentation() -> void:
	var camera := Vector2(100.25, 80.75)
	for zoom_percent: int in PixelPresentation.SUPPORTED_ZOOM:
		var origin := PixelPresentation.snapped_canvas_origin(camera, zoom_percent)
		equal(origin, origin.round(), "%d%% camera translation lands on output pixels" % zoom_percent)
		var screen := PixelPresentation.world_to_screen(Vector2(240.25, 180.75), camera, zoom_percent)
		equal(screen, screen.round(), "%d%% world presentation lands on output pixels" % zoom_percent)
		var snapped_world := PixelPresentation.snapped_world_anchor(Vector2(240.25, 180.75), camera, zoom_percent)
		equal(PixelPresentation.world_to_screen(snapped_world, camera, zoom_percent), screen, "%d%% snapped world anchor preserves screen location" % zoom_percent)


func _test_live_renderer_binding() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads before renderer binding")
	var renderer := SanctumCampusRenderer.new()
	check(not renderer.configure(null), "live renderer refuses an absent visual language")
	check(renderer.configure(language), "live renderer binds the validated language")
	check(renderer.natural_kit != null and renderer.natural_kit.content_hash.length() == 64, "live renderer binds the reusable natural-map kit")
	equal(renderer.BRASS, language.ramp_color("aged_brass", 2), "live brass derives from the shared ramp")
	equal(renderer.CYAN, language.ui_color("focus"), "live affordance focus derives from the shared UI token")
	equal(renderer.PARCHMENT, language.ui_color("text_primary"), "live map labels use the shared readable text token")
	equal(renderer.PANEL, language.ui_color("panel_fill"), "live map labels use the shared panel token")


func _test_fail_closed_contract() -> void:
	var mutations: Array[Callable] = [
		func(data: Dictionary) -> void: data["authority"] = "presentation owns collision",
		func(data: Dictionary) -> void: (data["pixel_contract"] as Dictionary)["nearest_neighbor"] = false,
		func(data: Dictionary) -> void: (data["pixel_contract"] as Dictionary)["supported_camera_percent"] = [75],
		func(data: Dictionary) -> void: (data["perspective_contract"] as Dictionary)["projection"] = "diamond_isometric",
		func(data: Dictionary) -> void: (data["perspective_contract"] as Dictionary)["maximum_facade_rise_to_footprint_ratio"] = 1.4,
		func(data: Dictionary) -> void: (data["perspective_contract"] as Dictionary)["foreground_cutaway_required"] = true,
		func(data: Dictionary) -> void: (data["perspective_contract"] as Dictionary)["worldbone_opaque"] = false,
		func(data: Dictionary) -> void: (data["character_contract"] as Dictionary)["style"] = "realistic",
		func(data: Dictionary) -> void: (data["character_contract"] as Dictionary)["head_height_ratio"] = [0.2, 0.25],
		func(data: Dictionary) -> void: (data["character_contract"] as Dictionary)["gameplay_height_pixels"] = [44, 76],
		func(data: Dictionary) -> void: ((data["character_contract"] as Dictionary)["body_heights"] as Dictionary)["small"] = 44,
		func(data: Dictionary) -> void: ((data["character_contract"] as Dictionary)["body_heights"] as Dictionary)["small"] = "58",
		func(data: Dictionary) -> void: ((data["character_contract"] as Dictionary)["body_heights"] as Dictionary)["tiny"] = 44,
		func(data: Dictionary) -> void: ((data["character_contract"] as Dictionary)["required_directions"] as Array).remove_at(3),
		func(data: Dictionary) -> void: ((data["character_contract"] as Dictionary)["required_silhouette_states"] as Array).pop_back(),
		func(data: Dictionary) -> void: (data["character_contract"] as Dictionary)["preserve_sensible_anatomy"] = false,
		func(data: Dictionary) -> void: (data["character_contract"] as Dictionary)["preserve_fixed_body_scale"] = false,
		func(data: Dictionary) -> void: (data["character_contract"] as Dictionary)["portrait_source"] = "separate_portrait",
		func(data: Dictionary) -> void: ((data["element_availability"] as Dictionary)["active"] as Array).append("chaos"),
		func(data: Dictionary) -> void: ((data["element_availability"] as Dictionary)["reserved_style_only"] as Array).clear(),
		func(data: Dictionary) -> void: (data["layers"] as Array).reverse(),
		func(data: Dictionary) -> void: ((data["ramps"] as Dictionary)["warm_stone"] as Array).pop_back(),
		func(data: Dictionary) -> void: ((data["elements"] as Dictionary)["ice"] as Dictionary)["shape"] = ((data["elements"] as Dictionary)["water"] as Dictionary)["shape"],
		func(data: Dictionary) -> void: (data["ui"] as Dictionary)["panel_fill"] = "not-a-color",
		func(data: Dictionary) -> void: (data["budgets"] as Dictionary)["maximum_combat_hud_coverage_percent"] = 80,
		func(data: Dictionary) -> void: (data["rubric"] as Dictionary)["minimum_mean"] = 3.0,
		func(data: Dictionary) -> void: (data["rubric"] as Dictionary)["automatic_acceptance"] = true,
	]
	for mutation: Callable in mutations:
		var language := VisualLanguage.new()
		check(language.load_from_file(), "valid language loads before adversarial mutation")
		language.data = language.data.duplicate(true)
		mutation.call(language.data)
		check(not language.validate(), "unsafe visual-language mutation fails closed")
		check(not language.last_error.is_empty(), "visual-language refusal is actionable")
		equal(language.ramps, {}, "failed validation exposes no ramp state")
