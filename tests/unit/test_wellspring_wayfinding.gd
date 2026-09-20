extends FluxTestSuite


func run() -> int:
	_test_repository_wayfinding()
	_test_fail_closed_contract()
	return finish("wellspring-wayfinding")


func _test_repository_wayfinding() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads for wayfinding")
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "campus loads for wayfinding")
	var wayfinding := WellspringWayfinding.new()
	check(wayfinding.configure(language, layout), "wayfinding validates: %s" % wayfinding.last_error)
	equal(wayfinding.points.size(), 9, "campus exposes nine purposeful points of interest")
	check(wayfinding.content_hash.length() == 64, "wayfinding has a stable content hash")
	check(int((wayfinding.data["budgets"] as Dictionary).get("label_exclusion_radius", 0)) >= 48, "nearby wayfinding labels yield the actor-readable lane")
	var kinds: Dictionary[String, bool] = {}
	for point: Dictionary in wayfinding.points:
		kinds[String(point.get("kind", ""))] = true
		check(not String(point.get("subtitle", "")).contains("CHEMISTRY SOON"), "wayfinding cannot advertise implemented chemistry as pending")
		if String(point.get("id", "")) == "elemental-crucible":
			check(String(point["subtitle"]).contains("TWO CASTS"), "Crucible wayfinding gives the first practical chemistry action")
	for kind: String in WellspringWayfinding.ALLOWED_KINDS:
		check(kinds.has(kind), "purposeful campus includes %s wayfinding" % kind)


func _test_fail_closed_contract() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads before wayfinding mutation")
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "campus loads before wayfinding mutation")
	var source := WellspringWayfinding.new()
	check(source.configure(language, layout), "valid wayfinding loads before mutation")
	var wayfinding := WellspringWayfinding.new()
	wayfinding.language = language
	wayfinding.data = source.data.duplicate(true)
	((wayfinding.data["points"] as Array)[0] as Dictionary)["position"] = [2559, 1439]
	check(not wayfinding.validate(layout), "out-of-district wayfinding point fails closed")
	check(not wayfinding.last_error.is_empty(), "wayfinding failure is actionable")
