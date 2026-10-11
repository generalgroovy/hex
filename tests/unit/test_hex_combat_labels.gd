extends FluxTestSuite


const LabelModel = preload("res://src/presentation/hex_combat_label.gd")
const Feedback = preload("res://src/presentation/combat_feedback_model.gd")
const Harness = preload("res://tests/support/combat_feedback_harness.gd")


func run() -> int:
	_test_layout_boundaries()
	_test_live_catalog_labels()
	_test_spray_contact_hierarchy()
	_test_hex_ingestion_ownership()
	return finish("hex-combat-labels")


func _cue(label: String = "-3.125") -> Dictionary:
	return {"label": label, "position": Vector2(400.25, 300.25), "event_type": "projectile_hit", "color": Color(0.8, 0.9, 1.0, 0.8), "duration": 0.55, "remaining": 0.55}


func _test_layout_boundaries() -> void:
	var font := ThemeDB.fallback_font
	for label: String in ["-1", "-0.001", "RADIANT VEIL · -3.125", "COURT FULL | LET MATTER FADE"]:
		var cue := _cue(label)
		var original := cue.duplicate(true)
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, LabelModel.FONT_SIZE).x
		for remaining: float in [0.55, 0.275, 0.001, 1.0]:
			cue.remaining = remaining
			var normal := LabelModel.layout(cue, font, false)
			var reduced := LabelModel.layout(cue, font, true)
			check(not normal.is_empty() and not reduced.is_empty(), "live label retains core information in both effects modes")
			for placement: Dictionary in [normal, reduced]:
				equal(placement.label, label, "layout never clips, renames or invents cue information")
				check(absf(float(placement.baseline.x) + width * 0.5 - float(cue.position.x)) <= 0.5, "pixel-snapped text is centered within half a pixel")
				equal(placement.baseline, (placement.baseline as Vector2).round(), "baseline stays on the pixel grid")
				check(is_equal_approx(float(placement.opacity), clampf(remaining / 0.55, 0.0, 1.0)), "label fades with the existing finite cue lifetime")
				check(is_equal_approx(float(placement.color.a), 0.8 * float(placement.opacity)), "fade preserves authored color opacity")
			equal(reduced.baseline.y, roundf(float(cue.position.y) - LabelModel.CONTACT_LIFT), "reduced effects suppress optional vertical drift")
			check(float(normal.baseline.y) <= float(reduced.baseline.y) and float(reduced.baseline.y) - float(normal.baseline.y) <= LabelModel.MAX_DRIFT, "normal effects add only bounded upward drift")
			equal(normal.opacity, reduced.opacity, "reduced effects retain the same readability fade and information")
		cue.remaining = original.remaining
		equal(cue, original, "label layout leaves the authoritative anchor and owning cue unchanged")
	var non_contact := _cue("NO FLUX")
	non_contact.event_type = "cast_refused"
	equal(LabelModel.layout(non_contact, font, true).baseline.y, roundf(float(non_contact.position.y) - LabelModel.OTHER_LIFT), "non-contact notices keep their separate modest lift")
	for patch: Dictionary in [{"label": ""}, {"remaining": 0.0}, {"remaining": -1.0}, {"remaining": INF}, {"remaining": NAN}, {"duration": 0.0}, {"duration": -1.0}, {"duration": INF}, {"position": Vector2(INF, 0)}, {"position": "invalid"}]:
		var invalid := _cue()
		invalid.merge(patch, true)
		check(LabelModel.layout(invalid, font, false).is_empty(), "empty, expired or nonfinite labels fail closed")
	check(LabelModel.layout(_cue(), null, false).is_empty(), "missing font does not fabricate label measurements")


func _test_live_catalog_labels() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "hex label suite loads the current live catalog")
	for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		for family: String in AbilityCatalog.SPELL_MATRIX_FAMILIES:
			var ability := catalog.ability(catalog.spell_id_at(element, family))
			var event := {"type": "spray_hit" if family == "spray" else "projectile_hit", "source_wire_id": int(ability.wire_id), "owner_id": 1, "target_id": 2, "damage": 3125}
			var description := Feedback.describe(event, catalog)
			var remote := Feedback.describe(SessionSnapshot.decode_event(SessionSnapshot.encode_event(event)), catalog)
			equal(remote, description, "current host and guest retain identical label information for " + element + "/" + family)
			var cue := _cue(description.label)
			cue.event_type = event.type
			var placement := LabelModel.layout(cue, ThemeDB.fallback_font, false)
			equal(placement.label, description.label, "current family label uses semantic reported damage without new gameplay claims")
			check(String(placement.label).contains("-3.125"), "sub-point paid impact precision remains intact")


func _test_spray_contact_hierarchy() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "compact Spray hierarchy uses the live catalog")
	for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		var ability := catalog.ability(catalog.spell_id_at(element, "spray"))
		for count: int in [0, 1, 2, 3, 8, 999]:
			var event := {"type": "spray_fired", "source_wire_id": int(ability.wire_id), "owner_id": 1, "hit_count": count, "end_x": 400000, "end_y": 300000}
			var before := event.duplicate(true)
			var feedback := Feedback.describe(event, catalog)
			equal(feedback.label, "", "cast-wide count cannot reveal unobserved targets or obscure individual impacts")
			equal(feedback.element, element, "silent cast summary retains validated element identity")
			for reduced: bool in [false, true]:
				check(LabelModel.layout(_cue(feedback.label), ThemeDB.fallback_font, reduced).is_empty(), "no empty-summary text is submitted in either effects setting")
			equal(event, before, "summary suppression cannot alter paid event data")
		for amount: int in [0, 1, 125, 3125, 14000]:
			var feedback := Feedback.describe({"type": "spray_hit", "source_wire_id": int(ability.wire_id), "owner_id": 1, "target_id": 2, "damage": amount}, catalog)
			var projectile := Feedback.describe({"type": "projectile_hit", "source_wire_id": 140, "damage": amount}, catalog)
			equal(feedback.label, projectile.label, "Spray and projectile contacts share exact damage vocabulary")
			check(not String(feedback.label).contains(String(ability.display_name).to_upper()), "victim labels do not repeat whole spell names")
			check(ThemeDB.fallback_font.get_string_size(feedback.label, HORIZONTAL_ALIGNMENT_LEFT, -1, LabelModel.FONT_SIZE).x < 55.0, "real contact number remains compact at gameplay font size")
	var node := Harness.new()
	node.ability_catalog = catalog
	node.session_transport = SessionTransport.new()
	node.visual_language = VisualLanguage.new()
	check(node.visual_language.load_from_file(), "Spray hook uses actual element colors")
	node.world = SimWorld.new(120)
	node.world.hex_court = HexChemistryWorld.new()
	var target := PlayerState.new(2)
	target.position_x = 400000
	target.position_y = 300000
	node.world.players.append(target)
	var target_before := target.canonical_values()
	var events: Array[Dictionary] = [
		{"type": "spray_fired", "source_wire_id": 141, "owner_id": 1, "hit_count": 3, "end_x": 400000, "end_y": 300000, "range": 160000},
		{"type": "spray_hit", "source_wire_id": 141, "owner_id": 1, "target_id": 2, "damage": 14000},
	]
	node._ingest_combat_cues(events)
	equal(node.combat_cues.size(), 2, "quieter typography does not discard the fan or target impact")
	equal(node.combat_cues[0].kind, "spray", "the existing fan presentation is retained")
	equal(node.combat_cues[0].label, "", "fan geometry no longer carries a visibility-blind hit count")
	equal(node.combat_cues[1].label, "-14", "target receives exact compact confirmed damage")
	equal(node.combat_cues[1].visibility_entity_id, 2, "contact still belongs to target visibility, not visible caster")
	equal(node.combat_cues[1].damage, 14000, "damage-weighted impact animation remains intact")
	equal(target.canonical_values(), target_before, "presentation simplification leaves simulation untouched")
	node.free()


func _test_hex_ingestion_ownership() -> void:
	var node := Harness.new()
	node.ability_catalog = AbilityCatalog.new()
	node.visual_language = VisualLanguage.new()
	check(node.ability_catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json") and node.visual_language.load_from_file(), "hex ingestion fixture uses validated current catalogs")
	node.world = SimWorld.new(120)
	node.world.hex_court = HexChemistryWorld.new()
	var target := PlayerState.new(2)
	target.position_x = 400000
	target.position_y = 300000
	node.world.players.append(target)
	var before := target.canonical_values()
	var event := {"type": "projectile_hit", "source_wire_id": 140, "owner_id": 1, "target_id": 2, "damage": 3125, "contact_position": Vector2i(398625, 298125)}
	node._ingest_combat_cues([event])
	equal(node.combat_cues.size(), 1, "production hex ingestion still owns exactly one contact cue")
	var cue: Dictionary = node.combat_cues[0]
	equal(cue.position, Vector2(398.625, 298.125), "exact authoritative contact anchor is preserved")
	equal(cue.visibility_entity_id, 2, "label retains the existing target visibility owner")
	equal(cue.duration, 0.55, "existing contact lifetime is unchanged")
	var original := cue.duplicate(true)
	LabelModel.layout(cue, ThemeDB.fallback_font, false)
	LabelModel.layout(cue, ThemeDB.fallback_font, true)
	equal(cue, original, "normal and reduced label sampling never rewrite the owned cue")
	node._update_combat_cues(0.54)
	equal(node.combat_cues.size(), 1, "contact remains alive inside its original finite lifetime")
	node._update_combat_cues(0.02)
	check(node.combat_cues.is_empty(), "production expiry removes the label with its owning cue")
	for unused: int in range(30):
		node._ingest_combat_cues([event])
	equal(node.combat_cues.size(), 24, "hex label rendering does not expand the existing cue cap")
	equal(target.canonical_values(), before, "label ingestion and layout do not alter player authority")
	node.free()
