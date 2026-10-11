extends FluxTestSuite


const Elements = preload("res://src/content/element_rules.gd")
# Eight-style primitive tests remain historical art coverage; wire parity uses six live elements.
const Contact = preload("res://src/presentation/hex_contact_punctuation.gd")
const Library = preload("res://src/presentation/pixel_magic_library.gd")
const Effects = preload("res://src/presentation/pixel_spell_effects.gd")
const FeedbackHarness = preload("res://tests/support/combat_feedback_harness.gd")
const Feedback = preload("res://src/presentation/combat_feedback_model.gd")
var library := Library.new()
var presenter: RefCounted


func run() -> int:
	check(library.load_from_file(), "contact punctuation loads the existing verified atlas pages: " + library.last_error)
	if library.asset_count() == 0:
		return finish("hex-contact-punctuation")
	presenter = Contact.new(library)
	_test_elements_tiers_and_accessibility()
	_test_exact_finite_sequence()
	_test_invalid_and_unsupported()
	_test_wire_parity()
	_test_production_ingestion()
	_test_shared_frames_and_source_isolation()
	_test_reported_force_envelope()
	return finish("hex-contact-punctuation")


func _test_reported_force_envelope() -> void:
	for element: String in Effects.ELEMENTS:
		for damage: int in [3000, 10000, 24000]:
			var cue := _cue(damage)
			var opening: Dictionary = presenter.sample(cue, element, false)
			var duration: int = opening.duration_ticks
			for age: int in duration:
				cue.age_ticks = age
				var before := var_to_bytes(cue)
				var normal: Dictionary = presenter.sample(cue, element, false)
				var reduced: Dictionary = presenter.sample(cue, element, true)
				var envelope := Effects.impact_envelope(age, duration, normal.tier, false)
				equal(normal.render_scale, normal.scale * envelope.x, "reported hit damage owns bounded point-contact weight through the full envelope")
				equal(reduced.render_scale, reduced.scale, "reduced hit retains exact force tier without scale motion")
				check(normal.render_scale <= 2.161 and reduced.render_scale <= 2.0, "point-contact emphasis cannot become an oversized blast")
				equal(normal.frame, library.sample(normal.asset_id, normal.sample_age_ticks), "force emphasis never swaps or deforms the existing elemental atlas art")
				equal(var_to_bytes(cue), before, "impact emphasis leaves source hit damage, contact and lifetime untouched")
				cue["velocity"] = Vector2(1, 0)
				var slowed: Dictionary = presenter.sample(cue, element, false)
				cue["velocity"] = Vector2(1000000, 0)
				equal(presenter.sample(cue, element, false), slowed, "field-slowed velocity cannot buff visual force or contact size")


func _cue(damage: int = 9000, age: int = 0, kind: String = "projectile_hit") -> Dictionary:
	return {"event_type": kind, "position": Vector2(412.125, 298.875), "damage": damage,
		"age_ticks": age, "remaining": 0.55, "duration": 0.55, "label": "-9"}


func _test_elements_tiers_and_accessibility() -> void:
	var boundaries: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(3125, 0),
		Vector2i(5000, 0), Vector2i(5001, 1), Vector2i(9000, 1), Vector2i(12000, 1),
		Vector2i(12001, 2), Vector2i(14000, 2), Vector2i(1_000_000, 2)]
	for element: String in Effects.ELEMENTS:
		for kind: String in ["projectile_hit", "spray_hit"]:
			for boundary: Vector2i in boundaries:
				var normal: Dictionary = presenter.sample(_cue(boundary.x, 0, kind), element, false)
				for reduced: bool in [false, true]:
					var cue := _cue(boundary.x, 0, kind)
					var before := var_to_bytes(cue)
					var model: Dictionary = presenter.sample(cue, element, reduced)
					check(not model.is_empty(), "each admitted hit has an elemental contact sample")
					if model.is_empty(): continue
					check(model.handled and model.visible, "new contact is both handled and visible")
					equal(model.position, cue.position, "contact preserves the exact fractional authority/presentation anchor")
					equal(model.damage, boundary.x, "contact retains exact reported damage without base-stat substitution")
					equal(model.tier, boundary.y, "damage boundary chooses only its bounded cosmetic tier")
					equal(model.scale, [1.0, 1.5, 2.0][boundary.y], "contact scales have exactly three bounded values")
					equal(model.asset_id, Effects.asset_id(element, "impact", reduced), "contact reuses the exact authored element/accessibility sequence")
					equal(model.frame, library.sample(model.asset_id, 0), "first contact uses the prepared first atlas pose")
					for key: String in ["position", "damage", "tier", "scale", "age_ticks", "sample_age_ticks", "duration_ticks"]:
						equal(model[key], normal[key], "Reduced Effects retains critical contact information: " + key)
					equal(var_to_bytes(cue), before, "sampling never changes source cue, label, geometry or lifetime")
					check(not model.has("radius") and not model.has("control") and not model.has("reaction"), "cosmetic size cannot advertise reach, control or a reaction")
	var missing_damage := _cue()
	missing_damage.erase("damage")
	equal(presenter.sample(missing_damage, "fire", false).tier, 0, "missing damage has minimal emphasis, never fabricated base damage")
	equal(presenter.sample(_cue(0x7fffffffffffffff), "fire", false).scale, 2.0, "large integer report stays at the same bounded maximum")


func _test_exact_finite_sequence() -> void:
	for element: String in Effects.ELEMENTS:
		for reduced: bool in [false, true]:
			var asset_id := Effects.asset_id(element, "impact", reduced)
			var asset: Dictionary = library.asset(asset_id)
			var total := int(asset.total_ticks)
			var duration := ceili(float(total) * 1.5)
			check(not asset.loop and asset.end_behavior == "hide", "contact relies only on an existing nonlooping hide-at-end sequence")
			for age: int in range(duration + 3):
				var model: Dictionary = presenter.sample(_cue(9000, age), element, reduced)
				check(model.handled, "admitted contact stays handled through and after expiry")
				var expected_age := floori(float(age) * 2.0 / 3.0)
				var expected := library.sample(asset_id, expected_age)
				if age >= duration:
					check(not model.visible and model.frame.is_empty(), "expired contact cannot resurrect the former cross")
				else:
					check(model.visible, "every pre-expiry age keeps the real finite contact visible")
					equal(model.sample_age_ticks, expected_age, "contact preserves the existing finite1.5x playback cadence")
					equal(model.frame, expected, "contact frame agrees with independent atlas-age lookup")
				equal(model.duration_ticks, duration, "sequence duration derives from the admitted atlas, not a second timer")
			var ancient: Dictionary = presenter.sample(_cue(9000, 0x7fffffffffffffff), element, reduced)
			check(ancient.handled and not ancient.visible, "arbitrarily old integer age is handled without overflow or resampling a flight loop")
			# Exercise the real return contract outside drawing: valid expiry must
			# not issue CanvasItem draw calls and must still suppress fallback.
			var canvas := Node2D.new()
			check(presenter.draw(canvas, _cue(9000, duration), element, reduced), "draw reports an expired contact as handled, not unsupported")
			canvas.free()


func _test_invalid_and_unsupported() -> void:
	var invalid: Array[Dictionary] = [{}]
	for value: Variant in [-1, 0.5, "9000", null, true, [], {}]:
		var damage := _cue()
		damage.damage = value
		invalid.append(damage)
		var age := _cue()
		age.age_ticks = value
		invalid.append(age)
	for value: Variant in [Vector2(NAN, 0), Vector2(INF, 0), Vector2(0, -INF), Vector2i(1, 2), [1, 2], null]:
		var cue := _cue()
		cue.position = value
		invalid.append(cue)
	for kind: Variant in ["field_triggered", "hex_clash", "cast_blocked", "cast_refused", "projectile_bounced", "pixel_release", "spray_fired", "beam_fired", "spray_intercepted", 1, null]:
		var cue := _cue()
		cue.event_type = kind
		invalid.append(cue)
	for cue: Dictionary in invalid:
		var before := var_to_bytes(cue)
		check(presenter.sample(cue, "water", false).is_empty(), "invalid or different semantic cannot acquire a damage bloom")
		equal(var_to_bytes(cue), before, "refusal never repairs or mutates a malformed source cue")
	for element: String in ["", "steam", "unknown", "FIRE"]:
		check(presenter.sample(_cue(), element, false).is_empty(), "unknown/reaction material cannot borrow an elemental hit")
	check(not presenter.draw(null, _cue(), "water", false), "missing canvas fails closed")
	var empty := Contact.new(Library.new())
	check(empty.sample(_cue(), "water", false).is_empty(), "unavailable art remains unsupported so existing presentation can fall back")
	presenter.library = null
	check(presenter.sample(_cue(), "water", false).is_empty(), "lost library cannot claim a handled visible contact")
	presenter.library = library


func _test_wire_parity() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "wire parity uses the actual admitted runtime spell catalog")
	for element: String in Elements.IDS:
		for kind: String in ["projectile_hit", "spray_hit"]:
			var shape := "projectile" if kind == "projectile_hit" else "spray"
			var wire := 0
			for candidate: int in catalog.runtime_wire_ids:
				var ability := catalog.ability_from_wire(candidate)
				if String(ability.get("element", "")) == element and String(ability.get("shape", "")) == shape:
					wire = candidate
					break
			check(wire > 0, "wire fixture finds a real elemental delivery")
			if wire <= 0: continue
			for damage: int in [1, 3125, 5000, 5001, 12000, 12001, 1_000_000]:
				var event := {"type": kind, "source_wire_id": wire, "owner_id": 1,
					"target_id": 2, "projectile_id": 1000, "damage": damage, "event_id": 91}
				var packed := SessionSnapshot.encode_event(event)
				check(SessionSnapshot._valid_event_values(packed), "reported hit fixture passes the unchanged wire validator")
				var decoded := SessionSnapshot.decode_event(packed)
				var local := _cue(int(event.damage), 9, String(event.type))
				var remote := _cue(int(decoded.damage), 9, String(decoded.type))
				for reduced: bool in [false, true]:
					# Anchors are supplied by the existing local/guest presentation
					# hook; this test does not claim the wire includes hit coordinates.
					equal(presenter.sample(remote, element, reduced), presenter.sample(local, element, reduced), "unchanged wire preserves every damage-driven visual decision")


func _test_production_ingestion() -> void:
	# Inherited Bootstrap ingestion only: no scene startup, process, preferences,
	# network or release effects. This proves the helper receives real cue data.
	var node := FeedbackHarness.new()
	node.ability_catalog = AbilityCatalog.new()
	node.visual_language = VisualLanguage.new()
	check(node.ability_catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json") and node.visual_language.load_from_file(), "contact ingestion uses the current validated catalogs")
	node.world = SimWorld.new(120)
	node.world.hex_court = HexChemistryWorld.new()
	var target := PlayerState.new(2)
	target.position_x = 400000
	target.position_y = 300000
	node.world.players.append(target)
	var actor_before := target.canonical_values()
	var last_event: Dictionary = {}
	for kind: String in ["projectile_hit", "spray_hit"]:
		var family := "bolt" if kind == "projectile_hit" else "spray"
		var ability := node.ability_catalog.ability(node.ability_catalog.spell_id_at("fire", family))
		check(not ability.is_empty(), "ingestion fixture uses an actual paid elemental delivery")
		if ability.is_empty(): continue
		var event := {"type": kind, "source_wire_id": int(ability.wire_id), "owner_id": 1,
			"target_id": 2, "contact_position": Vector2i(398625, 298125)}
		# These malformed scalar reports remain safe for the existing label model;
		# new emphasis must not adopt its permissive integer conversion.
		var reports: Array[Dictionary] = [{}, {"damage": 0}, {"damage": 1}, {"damage": 3125},
			{"damage": 12001}, {"damage": -1}, {"damage": 3125.5}, {"damage": "3125"}, {"damage": true}]
		for report: Dictionary in reports:
			var supplied := event.duplicate(true)
			supplied.merge(report)
			var source_before := var_to_bytes(supplied)
			node.combat_cues.clear()
			node._ingest_combat_cues([supplied])
			equal(node.combat_cues.size(), 1, "real ingestion retains exactly one hit cue")
			if node.combat_cues.size() != 1: continue
			var cue: Dictionary = node.combat_cues[0]
			var accepted := typeof(supplied.get("damage")) == TYPE_INT and int(supplied.damage) >= 0
			equal(cue.has("damage"), accepted, "only explicit nonnegative integer damage reaches contact emphasis")
			if accepted:
				equal(cue.damage, supplied.damage, "production forwards the exact report without rounding or base-damage substitution")
				equal(typeof(cue.damage), TYPE_INT, "forwarded report preserves its integer type")
			equal(cue.position, Vector2(398.625, 298.125), "production keeps the exact reported fractional contact anchor")
			equal(cue.visibility_entity_id, 2, "production retains the original target visibility owner")
			equal(cue.event_type, kind, "production retains the actual hit delivery identity")
			equal(cue.source_wire_id, int(ability.wire_id), "production retains the real spell identity")
			equal(cue.label, Feedback.describe(supplied, node.ability_catalog).label, "contact emphasis does not rewrite established label semantics")
			equal(cue.duration, 0.55, "production keeps the original finite hit duration")
			equal(cue.remaining, 0.55, "production begins at the original full lifetime")
			var model: Dictionary = presenter.sample(cue, "fire", false)
			check(model.handled and model.visible, "the actual ingested cue is accepted by the contact helper")
			equal(model.damage, int(supplied.damage) if accepted else 0, "omitted reports cannot fabricate visual damage emphasis")
			equal(var_to_bytes(supplied), source_before, "ingestion does not mutate the source event")
		last_event = event.duplicate(true)
		last_event.damage = 3125
	for kind: String in ["field_triggered", "cast_blocked", "cast_refused"]:
		var event := {"type": kind, "source_wire_id": 140, "owner_id": 1, "target_id": 2,
			"entity_id": 2, "damage": 12001, "reason": "flux", "contact_position": Vector2i(398625, 298125)}
		node.combat_cues.clear()
		node._ingest_combat_cues([event])
		equal(node.combat_cues.size(), 1, "existing non-hit feedback still creates its original cue")
		if node.combat_cues.size() != 1: continue
		var cue: Dictionary = node.combat_cues[0]
		check(not cue.has("damage"), "a numeric field on a non-hit event cannot become contact emphasis")
		check(presenter.sample(cue, "fire", false).is_empty(), "non-hit cue remains owned by its established feedback path")
		equal(cue.position, Vector2(398.625, 298.125), "non-hit anchor remains unchanged")
		equal(cue.label, "BLOCKED" if kind == "cast_blocked" else "NO FLUX" if kind == "cast_refused" else Feedback.describe(event, node.ability_catalog).label, "non-hit refusal/contact labels stay intact")
		equal(cue.duration, 0.55, "non-hit lifetime stays intact")
	node.combat_cues.clear()
	if not last_event.is_empty():
		node._ingest_combat_cues([last_event])
		node._update_combat_cues(0.54)
		equal(node.combat_cues.size(), 1, "real hit stays alive inside its existing lifetime")
		node._update_combat_cues(0.02)
		check(node.combat_cues.is_empty(), "real hit expires with its owning cue without an added timer")
	equal(target.canonical_values(), actor_before, "production contact ingestion never changes player authority")
	node.free()


func _test_shared_frames_and_source_isolation() -> void:
	var second := Contact.new(library)
	var cue := _cue(9000, 5)
	var retained: Dictionary = presenter.sample(cue, "earth", false)
	var initial_frame: Dictionary = retained.frame
	check(initial_frame.is_read_only(), "contact frame metadata is the shared immutable library entry")
	var texture: Texture2D = initial_frame.texture
	var pages_before := library.page_count()
	var assets_before := library.asset_count()
	var budget_before := library.decoration_stats()
	for _index: int in range(128):
		var current: Dictionary = second.sample(cue, "earth", false)
		equal((current.frame.texture as Texture2D).get_instance_id(), texture.get_instance_id(), "repeated contacts reuse the same admitted atlas texture")
		equal(current.frame, initial_frame, "repeated sampling reuses prepared frame geometry")
	equal(library.page_count(), pages_before, "sampling allocates no extra atlas pages")
	equal(library.asset_count(), assets_before, "sampling generates no additional effect assets")
	equal(library.decoration_stats(), budget_before, "critical contact sampling neither resets nor consumes optional decoration budget")
	retained.scale = 99.0
	retained.position = Vector2.ZERO
	equal(presenter.sample(cue, "earth", false).scale, 1.5, "caller-owned model changes cannot poison later emphasis")
	equal(presenter.sample(cue, "earth", false).position, cue.position, "caller-owned model changes cannot move another contact")
	cue.damage = 14000
	cue.position = Vector2(100, 200)
	var changed: Dictionary = presenter.sample(cue, "earth", false)
	equal(changed.tier, 2, "same-reference source changes are sampled freshly without a stale cue cache")
	equal(changed.position, cue.position, "same-reference source anchor changes are sampled freshly")
	var source := FileAccess.get_file_as_string("res://src/presentation/hex_contact_punctuation.gd")
	check(not source.contains("Image.create") and not source.contains("ImageTexture.create") and not source.contains("load_from_file("), "contact path has no per-cue image generation or asset loading")
	check(not source.contains("take_decoration(") and not source.contains("begin_frame("), "contact path cannot reset or expand the global decoration budget")
	equal(source.count("library.draw_stamp("), 1, "one visible contact has one atlas draw site, not a bloom plus duplicate cross")
