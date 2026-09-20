extends FluxTestSuite


const ElementGlyphRendererScript = preload("res://src/presentation/element_glyph_renderer.gd")


func run() -> int:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads for shared element glyphs")
	var topology_claims: Dictionary = {}
	for element_id: String in VisualLanguage.REQUIRED_ELEMENTS:
		var contract: Dictionary = ElementGlyphRendererScript.contract(language, element_id)
		check(not contract.is_empty(), "%s has a reusable glyph contract" % element_id)
		equal(String(contract.get("shape", "")), language.element_shape(element_id), "%s glyph uses the central shape token" % element_id)
		equal(String(contract.get("cadence", "")), language.element_cadence(element_id), "%s glyph preserves its motion-cadence token" % element_id)
		var topology := String(contract.get("topology", ""))
		check(not topology_claims.has(topology), "%s remains shape-distinct without relying on color" % element_id)
		topology_claims[topology] = element_id
	equal(topology_claims.size(), VisualLanguage.REQUIRED_ELEMENTS.size(), "all element glyph topologies are unique")
	check(ElementGlyphRendererScript.contract(language, "unknown").is_empty(), "unknown element cannot invent a glyph")
	_test_material_motion(language)
	return finish("element-glyph-renderer")


func _test_material_motion(language: VisualLanguage) -> void:
	var expected := {"fire": "ember", "water": "ripple", "earth": "block", "wind": "stream", "charge": "arc", "ice": "facet", "light": "ray", "dark": "wisp"}
	for element_id: String in expected:
		var profile: Dictionary = ElementGlyphRendererScript.material_contract(language, element_id)
		equal(String(profile.get("motif", "")), expected[element_id], "%s has a distinct reusable material motion" % element_id)
		equal(String(profile.get("cadence", "")), language.element_cadence(element_id), "%s material cadence is sourced from the central token" % element_id)
		equal(String(profile.get("shape", "")), language.element_shape(element_id), "%s material and UI use the same shape contract" % element_id)
		var period := int(profile.get("period", 0))
		check(period >= 54 and period <= 156, "%s animation uses a readable bounded presentation period" % element_id)
		equal(ElementGlyphRendererScript.material_phase(language, element_id, 17, 3), ElementGlyphRendererScript.material_phase(language, element_id, 17 + period, 3), "%s cadence repeats without mutable animation state" % element_id)
		for sample: int in range(11):
			var phase := float(sample) / 10.0
			var motifs: Array[Dictionary] = ElementGlyphRendererScript.material_motifs(language, element_id, phase, 1.0 - phase, false)
			check(not motifs.is_empty() and motifs.size() <= 6, "%s material work remains bounded" % element_id)
			for mark: Dictionary in motifs:
				var offset: Vector2 = mark["offset"]
				var size := float(mark["size"])
				# Square corners have the largest extent of all material glyphs.
				var extent := size * (sqrt(2.0) if String(mark["motif"]) == "block" else 1.25)
				check(offset.length() + extent <= 0.88, "%s interior never moves the authoritative perimeter" % element_id)
				check(float(mark["alpha"]) > 0.0 and float(mark["alpha"]) <= 0.72, "%s interior leaves actor silhouettes readable" % element_id)
			var reduced: Array[Dictionary] = ElementGlyphRendererScript.material_motifs(language, element_id, phase, 0.5, true)
			check(not reduced.is_empty() and reduced.size() <= 3, "%s reduced effects retains a shape with at most three motifs" % element_id)
			equal(reduced, ElementGlyphRendererScript.material_motifs(language, element_id, 0.9, 0.5, true), "%s reduced effects removes cadence flicker, not information" % element_id)
		var opening: Array[Dictionary] = ElementGlyphRendererScript.material_motifs(language, element_id, 0.0, 1.0, false)
		var later: Array[Dictionary] = ElementGlyphRendererScript.material_motifs(language, element_id, 0.5, 0.5, false)
		check(opening != later, "%s formation/active material is visibly phase-driven" % element_id)
		equal(ElementGlyphRendererScript.material_motifs(language, element_id, -5.0, 4.0, false), opening, "%s invalid sample ratios clamp to the opening" % element_id)
	check(ElementGlyphRendererScript.material_contract(language, "unknown").is_empty(), "unknown material fails closed")
	check(ElementGlyphRendererScript.material_contract(language, "time").is_empty(), "planned elements do not silently gain active material motion")
	check(ElementGlyphRendererScript.material_motifs(null, "fire", 0.5, 0.5, false).is_empty(), "material motion needs a validated language")
