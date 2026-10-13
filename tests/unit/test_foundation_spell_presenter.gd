extends FluxTestSuite


const Feedback = preload("res://src/presentation/combat_feedback_model.gd")
const FeedbackHarness = preload("res://tests/support/combat_feedback_harness.gd")


func run() -> int:
	_test_repository_profiles()
	_test_shared_direction_contract()
	_test_startup_readability_geometry()
	_test_startup_sample_contract()
	_test_projectile_presentation_motion()
	_test_fail_closed_catalog_alignment()
	_test_pixel_material_contract()
	_test_pixel_heading_cue()
	_test_pixel_family_weight_and_field_identity()
	_test_truthful_combat_feedback()
	_test_live_combat_feedback_hook()
	return finish("foundation-spell-presenter")


func _test_live_combat_feedback_hook() -> void:
	# Synthetic legacy events retain bounded neutral rendering for archived
	# presentation coverage; their source spells are rejected by live authority.
	var node := FeedbackHarness.new()
	node.session_transport = SessionTransport.new()
	node.ability_catalog = AbilityCatalog.new()
	check(node.ability_catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "live feedback hook catalog loads")
	node.visual_language = VisualLanguage.new()
	check(node.visual_language.load_from_file(), "live feedback hook uses validated element colors")
	node.world = SimWorld.new(120)
	var target := PlayerState.new(2)
	target.position_x = 400000
	target.position_y = 300000
	node.world.players.append(target)
	var before := target.canonical_values()
	var events: Array[Dictionary] = [
		{"type": "beam_fired", "source_wire_id": 155, "owner_id": 1, "target_id": 2, "end_x": 400000, "end_y": 300000, "origin_x": 200000, "origin_y": 300000},
		{"type": "spray_hit", "source_wire_id": 164, "owner_id": 1, "target_id": 2, "damage": 7000},
		{"type": "field_triggered", "source_wire_id": 156, "owner_id": 1, "target_id": 2, "field_id": 4000},
	]
	node._ingest_combat_cues(events)
	equal(node.combat_cues.size(), 3, "actual bootstrap hook creates exactly the admitted feedback cues")
	for index: int in range(events.size()):
		var cue: Dictionary = node.combat_cues[index]
		var description := Feedback.describe(events[index], node.ability_catalog)
		equal(cue.label, description.label, "live ingestion uses truthful model copy")
		var expected_color: Color = node.visual_language.element_color(description.element, "bright") if not String(description.element).is_empty() else node.PARCHMENT_COLOR
		equal(cue.color, expected_color, "live hook uses valid source color or neutral archived-event fallback")
		equal(cue.position, Vector2(400, 300), "existing authoritative cue anchor stays unchanged")
		equal(cue.duration, 0.20 if index == 0 else 0.55, "live ingestion preserves the existing finite cue duration")
	equal(node.combat_cues[0].start, Vector2(200, 300), "Beam origin stays exact and is never inferred from label metadata")
	equal(node.combat_cues[0].end, Vector2(400, 300), "Beam endpoint stays exact")
	node._update_combat_cues(0.21)
	equal(node.combat_cues.size(), 2, "Beam feedback still expires after its original 0.20 seconds")
	node._update_combat_cues(0.35)
	check(node.combat_cues.is_empty(), "all contacts still expire after their original 0.55 seconds")
	for unused: int in range(30):
		node._ingest_combat_cues([events[1]])
	equal(node.combat_cues.size(), 24, "presentation retains its original 24-cue cap")
	equal(target.canonical_values(), before, "real feedback path leaves player authority unchanged")
	node.free()


func _test_truthful_combat_feedback() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "combat feedback reads the current validated catalog")
	var original_catalog := catalog.data.duplicate(true)
	for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		for family: String in ["bolt", "heavy", "rapid", "spray"]:
			var ability := catalog.ability(catalog.spell_id_at(element, family))
			var wire_id := int(ability.wire_id)
			var identity := String(ability.display_name).to_upper()
			var kinds: Array = ["spray_fired", "spray_hit"] if family == "spray" else ["projectile_hit"]
			for kind: String in kinds:
				for hit: int in [0, 1]:
					var event := {"type": kind, "source_wire_id": wire_id, "owner_id": 1, "target_id": hit, "damage": 3125, "hit_count": hit, "field_id": 4000, "end_x": 240000, "end_y": 360000}
					var original := event.duplicate(true)
					var feedback := Feedback.describe(event, catalog)
					var expected := identity
					match kind:
						"projectile_hit": expected = "-3.125"
						"beam_fired": expected += " · HIT" if hit > 0 else ""
						"spray_fired": expected = ""
						"spray_hit": expected = "-3.125"
						"field_triggered": expected += " · CONTACT"
					equal(feedback.label, expected, "feedback identifies the actual " + element + " " + family)
					equal(feedback.element, element, "feedback color cannot borrow a different element")
					check(not String(feedback.label).contains("SLOW") and not String(feedback.label).contains("LAUNCH"), "contact cannot assert a control outcome absent from the event")
					var decoded := SessionSnapshot.decode_event(SessionSnapshot.encode_event(event))
					equal(Feedback.describe(decoded, catalog), feedback, "host and guest use identical existing wire metadata for " + kind)
					equal(event, original, "presentation leaves the semantic event untouched")
					check(ThemeDB.fallback_font.get_string_size(feedback.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= 180.0, "actual cue copy stays compact at the existing 11px font")
	for amount: int in [0, 1, 125, 1000, 3125, 18000]:
		var event := {"type": "projectile_hit", "source_wire_id": 145, "damage": amount}
		var expected: String = {0: "HIT", 1: "-0.001", 125: "-0.125", 1000: "-1", 3125: "-3.125", 18000: "-18"}[amount]
		equal(Feedback.describe(event, catalog).label, expected, "carried damage preserves exact milli-unit precision")
	equal(Feedback.describe({"type": "beam_fired", "source_wire_id": 143, "target_id": 2, "damage": 0}, catalog), {"label": "BEAM · HIT", "element": ""}, "retired Beam event cannot borrow a live spell identity")
	equal(Feedback.describe({"type": "spray_hit", "source_wire_id": 141, "damage": 14000}, catalog), {"label": "-14", "element": "water"}, "Tideline keeps reported damage and element without repeating its name or claiming Launch")
	equal(Feedback.describe({"type": "field_triggered", "source_wire_id": 144}, catalog), {"label": "FIELD · CONTACT", "element": ""}, "retired Field event cannot borrow live identity or imply Slow")
	equal(Feedback.describe({"type": "beam_fired", "source_wire_id": 99999, "target_id": 1}, catalog), {"label": "BEAM · HIT", "element": ""}, "unknown identity stays neutral without inventing a spell")
	equal(Feedback.describe({"type": "beam_fired", "source_wire_id": 141, "target_id": 1}, catalog), {"label": "BEAM · HIT", "element": ""}, "mismatched spell family cannot borrow identity or color")
	equal(Feedback.describe({"type": "beam_fired", "source_wire_id": 155}, null), {"label": "BEAM", "element": ""}, "missing catalog gets a neutral semantic fallback")
	equal(Feedback.describe({"type": "beam_fired", "source_wire_id": 155}, AbilityCatalog.new()), {"label": "BEAM", "element": ""}, "unvalidated catalog cannot supply identity")
	equal(Feedback.describe({"type": "projectile_hit", "damage": -1}, catalog).label, "HIT", "invalid negative amount cannot appear as healing")
	for kind: String in ["cast_started", "cast_refused", "cast_blocked", "field_expired", "unknown"]:
		check(Feedback.describe({"type": kind, "source_wire_id": 155}, catalog).is_empty(), "unrelated events retain their existing presentation path")
	equal(catalog.data, original_catalog, "feedback cannot change validated gameplay data")


func _test_pixel_family_weight_and_field_identity() -> void:
	var spell_source := FileAccess.get_file_as_string("res://src/presentation/pixel_spell_effects.gd")
	# The original Field/Spray material paths have no separate outline. The same
	# file now intentionally draws bounded Fuse/Mantle warnings and delivery marks;
	# those expanded paths are covered by element-delivery-presentation.
	for method: String in ["spray", "field"]:
		var start := spell_source.find("\nfunc " + method + "(")
		check(start >= 0, "the original material method is present before inspecting its drawing contract")
		if start < 0: continue
		var end := spell_source.find("\nfunc ", start + 1)
		var body := spell_source.substr(start, end - start if end >= 0 else spell_source.length() - start)
		check(not body.contains("draw_polyline("), "original " + method + " does not draw a separate range-circle or cone outline")
	var pixels := PixelSpellEffects.new()
	for reduced: bool in [false, true]:
		pixels.library.begin_frame(reduced)
		for element: String in pixels.ELEMENTS:
			for unused: int in range(100):
				pixels.library.take_decoration(pixels.asset_id(element, "field_tile", reduced))
		equal(pixels.library.decoration_remaining(), 0, "field identity fixture exhausts the shared optional budget")
		for element: String in pixels.ELEMENTS:
			var rapid := pixels.impact_profile(element, 5.0, reduced)
			var ordinary := pixels.impact_profile(element, 10.0, reduced)
			var heavy := pixels.impact_profile(element, 16.0, reduced)
			equal(rapid.scale, 0.9375, "Rapid contact gains readability while remaining smaller than a Bolt")
			equal(ordinary.scale, 1.875, "ordinary contact gets a bounded50percent readability expansion")
			equal(heavy.scale, 3.0, "Heavy contact stays distinct from its damage footprint")
			equal(pixels.impact_profile(element, 8.0, reduced).scale, 1.5, "default contacts share the same readable scale")
			equal(rapid.opacity, 0.95 if reduced else 1.0, "reduced mode preserves contact identity without adding flashes")
			equal(pixels.impact_profile(element, 0.1, reduced).scale, 0.75, "tiny valid sources retain a visible but bounded contact")
			check(float(pixels.impact_profile(element, 1000.0, reduced).scale) <= pixels.MAX_IMPACT_SCALE, "cosmetic impact scale has a hard bound")
			check(float(rapid.opacity) > 0.0 and float(heavy.opacity) <= 1.0, "radius scaling never creates overbright layers")
			var lifetime := int(pixels.library.asset(heavy.asset_id).total_ticks)
			check(not pixels.library.sample(heavy.asset_id, lifetime - 1).is_empty(), "contact retains its original one-shot animation")
			check(pixels.library.sample(heavy.asset_id, lifetime).is_empty(), "Heavy contact expires at the original tick, not a scaled lifetime")
			for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
				var tail := pixels.flight_tail_profile(element, Vector2.ZERO, Vector2(direction), 16.0, reduced)
				check(float(tail.scale) <= pixels.MAX_TAIL_SCALE, "Heavy optional trail does not grow into a giant secondary threat")
				check(is_equal_approx((tail.anchor as Vector2).length(), 16.0), "tail attachment still follows the real projectile radius")
			var field := pixels.field_model(element, Vector2(128, 160), 48.0, 12, reduced)
			check(not field.is_empty() and not field.core_frame.is_empty(), "all eight Fields preserve their element core after decoration is exhausted")
			equal(field.core_asset_id, pixels.asset_id(element, "flight", reduced), "Field identity reuses the distinct existing element core in the selected effects mode")
			equal(field.core_frame, pixels.library.sample(field.core_asset_id, 12), "Field core samples real immutable atlas frames at authoritative age")
			equal(field.core_frame.size, Vector2(32, 32), "guaranteed identity remains a single unscaled native cell")
			equal(field.frame, pixels.library.sample(pixels.asset_id(element, "field_tile", reduced), 12), "optional Field material tiles remain unchanged")
			check(field.core_frame.region != field.frame.region, "guaranteed identity no longer repeats the sparse field-tile grains")
			equal(field.core_opacity, 0.55 if reduced else 0.72, "core substitution preserves the accepted mode opacity")
			equal(field.material_opacity, 0.10 if reduced else 0.20, "core substitution does not increase optional material density")
			check(float(field.core_opacity) > float(field.material_opacity) and float(field.material_opacity) <= 0.20, "readable centre does not turn the field into an opaque area")
			equal(field.core_anchor, Vector2(128, 160), "field identity is fixed to the authoritative centre")
			for radius: float in [5.0, 16.0, 48.0, 90.0]:
				field = pixels.field_model(element, Vector2(128, 160), radius, 12, reduced)
				var parts := PixelEffectGeometry.clipped_frame_parts(field.core_frame, field.core_anchor, field.polygons)
				check(not parts.is_empty(), "small and large field cores intersect their real mask")
				for part: Dictionary in parts:
					for point: Vector2 in part.points:
						check(point.distance_to(field.core_anchor) <= radius + 0.001, "stronger native material cannot spill outside actual Field radius")
			equal(pixels.library.decoration_remaining(), 0, "field modeling cannot replenish the optional budget")
	for radius: float in [0.0, -1.0, NAN, INF]:
		check(pixels.impact_profile("fire", radius, false).is_empty(), "invalid radius cannot create an impact")
		check(pixels.field_model("fire", Vector2.ZERO, radius, 0, false).is_empty(), "invalid radius cannot create a Field")
	check(pixels.impact_profile("missing", 16, false).is_empty(), "unknown element cannot borrow an impact")
	check(pixels.field_model("water", Vector2.ZERO, 48, -1, false).is_empty(), "negative Field age is not rendered")


func _test_pixel_heading_cue() -> void:
	var pixels := PixelSpellEffects.new()
	for element: String in pixels.ELEMENTS:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			var heading := Vector2(direction)
			var origin := Vector2(150, 200)
			var normal := pixels.flight_tail_profile(element, origin, heading, 10.0, false)
			var reduced := pixels.flight_tail_profile(element, origin, heading, 10.0, true)
			check(not normal.is_empty() and not reduced.is_empty(), "all eight elements/directions retain a normal and reduced heading cue")
			equal(normal.anchor, reduced.anchor, "reduced mode preserves the actual travel attachment")
			check((origin - (reduced.anchor as Vector2)).dot(heading) > 0.0, "tail stays behind real travel, not facing or camera direction")
			check(is_equal_approx(float(reduced.angle), heading.angle()), "tail preserves continuous travel orientation")
			check(float(reduced.scale) < float(normal.scale) and float(reduced.opacity) < float(normal.opacity), "reduced cue is shorter and quieter, never a larger threat")
			check(not pixels.library.sample(reduced.asset_id, 0).is_empty(), "heading cue uses an existing reduced pixel asset")
	for direction: Vector2 in [Vector2.ZERO, Vector2(INF, 0), Vector2(NAN, 1)]:
		check(pixels.flight_tail_profile("fire", Vector2.ZERO, direction, 10, false).is_empty(), "invalid/stationary heading cannot invent a tail")
	check(pixels.flight_tail_profile("missing", Vector2.ZERO, Vector2.RIGHT, 10, false).is_empty(), "unknown element has no heading art")
	check(pixels.flight_tail_profile("fire", Vector2.ZERO, Vector2.RIGHT, 0, false).is_empty(), "zero radius has no heading art")


func _test_pixel_material_contract() -> void:
	var pixels := preload("res://src/presentation/pixel_spell_effects.gd").new()
	check(pixels.ready(), "supplied pixel magic registry is live in spell presentation")
	for element: String in pixels.ELEMENTS:
		for reduced: bool in [false,true]:
			for effect: String in ["flight","flight_tail","hand_prepare","hand_release","burst_release","beam_body","beam_start","beam_end","spray_grain","field_tile","impact"]:
				var id: String = pixels.asset_id(element,effect,reduced)
				check(not pixels.library.sample(id,0).is_empty(), "%s %s supplies its own %s pixel sequence" % [element,str(reduced),effect])
				check(pixels.library.sample(id,0,false).is_empty(), "authority exit hides every new pixel sequence immediately")
	equal(pixels.lifetime_age(1600,180),12,"phase age is120 Hz lifetime age, never frame-count driven")
	equal(pixels.lifetime_age(100,20),0,"late snapshot cannot create a negative phase")
	for direction: Vector2 in [Vector2.RIGHT,Vector2(0.707,0.707),Vector2(0.91,-0.42),Vector2.LEFT]:
		var origin := Vector2(230,140)
		var end := origin + direction.normalized()*380.0
		var polygon: PackedVector2Array = pixels.spray_polygon(origin,end,820000)
		equal(polygon[0],origin,"spray begins at actual authority origin")
		var forward := (end-origin).normalized()
		for point: Vector2 in polygon:
			var offset := point-origin
			check(offset.length() <= 380.001,"pixel spray cannot exceed range")
			if offset.length() > 0.001:
				check(pow(offset.normalized().dot(forward),2) >= 0.81999,"spray uses catalog cosine, not old approximate triangle")
	equal(pixels.spray_polygon(Vector2.ZERO,Vector2.ZERO,820000).size(),0,"zero-range spray draws no material")
	for kind: String in ["cast_started","cast_refused","cast_blocked","projectile_hit"]:
		check(pixels.accepted_release({"type":kind,"owner_id":1,"wire_id":3}).is_empty(),"unadmitted action is never a pixel release")
	for kind: String in ["projectile_spawned","field_spawned","beam_fired","spray_fired"]:
		var release: Dictionary = pixels.accepted_release({"type":kind,"owner_id":2,"source_wire_id":4,"lane_index":0})
		equal(release.get("dedup_key"),"2:4","only accepted delivery events expose a stable per-tick release key")
	check(pixels.accepted_release({"type":"projectile_spawned","owner_id":2,"wire_id":4,"lane_index":3}).is_empty(),"Burst secondary lanes do not duplicate hand releases")
	check(pixels.accepted_release({"type":"beam_fired","owner_id":0,"source_wire_id":4}).is_empty(),"missing actor cannot invent a release hand")


func _test_repository_profiles() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads for spell presentation")
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "ability catalog loads for spell presentation")
	var presenter := FoundationSpellPresenter.new()
	check(presenter.configure(language, catalog), "foundation spell presentation validates: %s" % presenter.last_error)
	var expected_profiles: Dictionary = {}
	for profile_id: String in FoundationSpellPresenter.REQUIRED_IDS:
		expected_profiles[profile_id] = true
	for wire: int in catalog.runtime_wire_ids:
		check(presenter.profiles_by_wire.has(wire), "every retained runtime spell has an authored or reusable visual profile")
		expected_profiles[String(catalog.ability_from_wire(wire).id)] = true
	equal(presenter.profiles_by_id.size(), expected_profiles.size(), "retained runtime profiles coexist with preserved authored retired visuals")
	equal(presenter.profiles_by_wire.size(), expected_profiles.size(), "preserved visual identities remain one-to-one with stable wires")
	equal(presenter.animation_skeletons.skeletons.size(), 4, "foundation spells share four reusable delivery skeletons")
	check(presenter.animation_skeleton_hash.length() == 64, "foundation spell presentation exposes the skeleton content hash")
	check(presenter.direction_contract_hash.length() == 64, "foundation spell presentation exposes the shared direction content hash")
	equal(String(presenter.animation_skeletons.phase_for("projectile", 0.10).get("cue", "")), "origin_ring", "projectile startup exposes the shared hand-gather cue")
	equal(String(presenter.animation_skeletons.phase_for("projectile", 0.25).get("cue", "")), "release_flash", "projectile release exposes the shared forward-snap cue")
	equal(FoundationSpellPresenter.STARTUPS.size(), 7, "foundation spells own seven delivery-readable startup silhouettes")
	check(presenter.content_hash.length() == 64, "foundation spell presentation has a stable content hash")
	var observed_startups: Dictionary[String, bool] = {}
	for profile_id: String in FoundationSpellPresenter.REQUIRED_IDS:
		var profile: Dictionary = presenter.profiles_by_id[profile_id]
		var ability := catalog.ability(profile_id)
		equal(String(profile.get("shape")), String(ability.get("shape")), "%s visual shape matches simulation content" % profile_id)
		equal(String(profile.get("element")), String(ability.get("element")), "%s visual element matches simulation content" % profile_id)
		equal(String((presenter.animation_skeletons.skeletons[String(profile.get("skeleton_id", ""))] as Dictionary).get("shape", "")), String(profile.get("shape", "")), "%s uses the matching delivery skeleton" % profile_id)
		observed_startups[String(profile.get("startup"))] = true
	equal(observed_startups.size(), 7, "Burst variants share one shape-first startup while other deliveries stay distinct")
	for burst_id: String in FoundationSpellPresenter.BURST_IDS:
		var burst_profile: Dictionary = presenter.profiles_by_id[burst_id]
		equal(String(burst_profile.get("startup", "")), "elemental_burst", "%s reuses the same five-lane startup geometry" % burst_id)
		equal(String(burst_profile.get("silhouette", "")), "burst_mote", "%s reuses the same Burst silhouette contract" % burst_id)
	for wire_id: int in catalog.runtime_wire_ids:
		check(presenter.profiles_by_wire.has(wire_id), "runtime wire %d has a presentation profile" % wire_id)
	var generated: Dictionary = presenter.profiles_by_id["flintshot"]
	equal(String(generated.get("generated_from_family", "")), "bolt", "new spells reuse their attack-family presentation skeleton")
	equal(String(generated.get("element", "")), "earth", "reused family visuals retain distinct element coding")


func _test_shared_direction_contract() -> void:
	var contract := SpellDeliveryDirectionContract.new()
	check(contract.load_from_file(), "shared spell direction contract validates: %s" % contract.last_error)
	equal(contract.data.get("direction_order", []), EightDirectionResolver.DIRECTION_ORDER, "spell delivery uses the canonical S/SE/E/NE/N/NW/W/SW order")
	var cases := [
		{"vector": Vector2(0, 1000), "id": "south"},
		{"vector": Vector2(707, 707), "id": "south_east"},
		{"vector": Vector2(1000, 0), "id": "east"},
		{"vector": Vector2(707, -707), "id": "north_east"},
		{"vector": Vector2(0, -1000), "id": "north"},
		{"vector": Vector2(-707, -707), "id": "north_west"},
		{"vector": Vector2(-1000, 0), "id": "west"},
		{"vector": Vector2(-707, 707), "id": "south_west"},
	]
	for case: Dictionary in cases:
		var vector: Vector2 = case["vector"]
		equal(SpellDeliveryDirectionContract.direction_id(vector), case["id"], "spell delivery classifies %s deterministically" % case["id"])
		var expected_fixed := EightDirectionResolver.fixed_vector(String(case["id"]))
		var expected := Vector2(expected_fixed.x, expected_fixed.y).normalized()
		check(SpellDeliveryDirectionContract.visual_vector(vector).is_equal_approx(expected), "spell delivery exposes the fixed %s visual vector" % case["id"])
	equal(SpellDeliveryDirectionContract.direction_id(Vector2.ZERO), "south", "zero spell aim fails safe to south")
	check(SpellDeliveryDirectionContract.visual_vector(Vector2.ZERO).is_equal_approx(Vector2.DOWN), "zero spell aim exposes a stable down visual vector")
	equal(SpellDeliveryDirectionContract.direction_id(Vector2(0.001, -0.001)), "north_east", "small non-zero continuous aim keeps its diagonal sector")
	var invalid := SpellDeliveryDirectionContract.new()
	invalid.data = contract.data.duplicate(true)
	invalid.data["zero_vector_fallback"] = "east"
	check(not invalid.validate(), "non-canonical spell direction fallback fails closed")
	check(not invalid.last_error.is_empty(), "spell direction contract refusal is actionable")


func _test_startup_readability_geometry() -> void:
	for direction_id: String in EightDirectionResolver.DIRECTION_ORDER:
		var fixed := EightDirectionResolver.fixed_vector(direction_id)
		var geometry := FoundationSpellPresenter.startup_readability_geometry(Vector2(fixed.x, fixed.y), 0.5)
		var focus: Vector2 = geometry["focus"]
		var side: Vector2 = geometry["side"]
		check(focus.length() >= 10.0 and focus.length() <= 18.0, "%s startup focus remains in the bounded hand lane" % direction_id)
		check(absf(focus.normalized().dot(side)) < 0.001, "%s startup brace remains perpendicular to release" % direction_id)
		equal(float(geometry.get("half_width", 0.0)), 5.25, "%s startup fork uses the same color-independent width" % direction_id)
	var fallback := FoundationSpellPresenter.startup_readability_geometry(Vector2.ZERO, -2.0)
	check((fallback["focus"] as Vector2).normalized().is_equal_approx(Vector2.DOWN), "zero aim startup fails safe to south")
	equal(float(fallback.get("half_width", 0.0)), 6.0, "startup progress clamps before geometry is emitted")


func _test_projectile_presentation_motion() -> void:
	var projectile := ProjectileState.new(7, 1, 1, 146, 2, Vector2i(200_000, 80_000), Vector2i(700_000, 0), 8_000, 4_000, 120)
	projectile.previous_x = 100_000
	projectile.previous_y = 40_000
	equal(ProjectilePresentationMotion.interpolated_position(projectile, -1.0), Vector2(100.0, 40.0), "projectile interpolation clamps to the previous authoritative sample")
	equal(ProjectilePresentationMotion.interpolated_position(projectile, 0.5), Vector2(150.0, 60.0), "projectile interpolation fills the visual half-step smoothly")
	equal(ProjectilePresentationMotion.interpolated_position(projectile, 2.0), Vector2(200.0, 80.0), "projectile interpolation clamps to the current authoritative sample")
	check(ProjectilePresentationMotion.travel_direction(projectile).is_equal_approx(Vector2.RIGHT), "projectile direction remains stable from canonical velocity")
	var full_trail := ProjectilePresentationMotion.trail_length(projectile, false)
	check(full_trail > 18.0 and full_trail < 19.0, "readable projectile owns a bounded continuous motion trail")
	check(ProjectilePresentationMotion.trail_length(projectile, true) < full_trail, "reduced effects shortens rather than removes the readability trail")
	equal(ProjectilePresentationMotion.visual_diameter(projectile), 28.0, "projectile art remains larger than its collision core at gameplay zoom")
	equal(ProjectilePresentationMotion.leading_point(projectile), Vector2(11.0, 0.0), "projectile leading point exposes travel without relying on color")
	var large_projectile := ProjectileState.new(8, 1, 1, 142, 8, Vector2i.ZERO, Vector2i(780_000, 0), 20_000, 4_000, 120)
	equal(ProjectilePresentationMotion.visual_diameter(large_projectile), 46.0, "projectile art diameter stays inside the presentation budget")


func _test_fail_closed_catalog_alignment() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads before spell visual mutation")
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "ability catalog loads before spell visual mutation")
	var source := FoundationSpellPresenter.new()
	check(source.configure(language, catalog), "valid spell presentation loads before mutation")
	var presenter := FoundationSpellPresenter.new()
	presenter.language = language
	presenter.direction_contract = source.direction_contract
	presenter.animation_skeletons = source.animation_skeletons
	presenter.data = source.data.duplicate(true)
	((presenter.data["profiles"] as Array)[0] as Dictionary)["shape"] = "beam"
	check(not presenter.validate(catalog), "visual profile cannot contradict authoritative ability shape")
	check(not presenter.last_error.is_empty(), "spell visual refusal is actionable")
	presenter.data = source.data.duplicate(true)
	((presenter.data["profiles"] as Array)[1] as Dictionary)["startup"] = String(((presenter.data["profiles"] as Array)[0] as Dictionary)["startup"])
	check(not presenter.validate(catalog), "two spells cannot collapse onto one startup silhouette")
	presenter.data = source.data.duplicate(true)
	((presenter.data["profiles"] as Array)[0] as Dictionary)["skeleton_id"] = "beam"
	check(not presenter.validate(catalog), "spell delivery cannot use a mismatched animation skeleton")


func _test_startup_sample_contract() -> void:
	var language := VisualLanguage.new()
	var catalog := AbilityCatalog.new()
	check(language.load_from_file() and catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"),"startup sample uses actual current visual and spell catalogs")
	var presenter := FoundationSpellPresenter.new()
	check(presenter.configure(language,catalog),"startup sample presenter configures")
	for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		var wire := int(catalog.ability(catalog.spell_id_at(element,"heavy")).wire_id)
		for reduced: bool in [false,true]:
			var clip: Dictionary=presenter.pixel_effects.library.asset(presenter.pixel_effects.asset_id(element,"hand_prepare",reduced))
			check(not clip.is_empty(),"normal and reduced preparation clips are admitted")
			var final_sample := int(clip.total_ticks)-1
			equal(presenter.startup_sample_ticks(wire,0.0,reduced),0,"unknown admission starts from release-proximity clip coordinate")
			equal(presenter.startup_sample_ticks(wire,1.0,reduced),final_sample,"unknown terminal proximity stays inside admitted clip")
			equal(presenter.startup_sample_ticks(wire,0.5,reduced),floori(float(final_sample)*0.5),"unknown sample is explicit clip coordinate, not claimed elapsed time")
			for elapsed: int in [0,1,7,18]:
				var timing := {"wire_id":wire,"known_total":true,"elapsed_ticks":elapsed,"remaining_ticks":21-elapsed,"total_ticks":21}
				equal(presenter.startup_sample_ticks(wire,0.7,reduced,timing),elapsed,"witnessed admission uses actual elapsed ticks independently of fallback coordinate")
				var before := timing.duplicate(true)
				presenter.startup_sample_ticks(wire,0.7,reduced,timing)
				equal(timing,before,"clip selection leaves timing context unchanged")
			var stale := {"wire_id":wire+1,"known_total":true,"elapsed_ticks":7,"remaining_ticks":14,"total_ticks":21}
			equal(presenter.startup_sample_ticks(wire,1.0,reduced,stale),final_sample,"other spell context cannot claim an admission age")
			equal(presenter.startup_sample_ticks(wire,NAN,reduced),0,"invalid proximity fails finite")
