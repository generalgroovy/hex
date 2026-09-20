extends FluxTestSuite


class RecordingLibrary:
	extends PixelMagicLibrary
	var draws: Array[Dictionary] = []
	func draw_stamp(_canvas: CanvasItem, id: String, anchor: Vector2, age: int, angle: float = 0.0, opacity: float = 1.0, scale: float = 1.0, alive: bool = true) -> bool:
		draws.append({"id": id, "anchor": anchor, "age": age, "angle": angle, "opacity": opacity, "scale": scale})
		return not sample(id, age, alive).is_empty()


func run() -> int:
	var presenter := _configured()
	_test_live_pixel_contract(presenter)
	_test_fail_closed(presenter)
	_test_impact_profiles()
	_test_authored_contact(presenter)
	return finish("burst-projectile-presenter")


func _test_authored_contact(presenter: BurstProjectilePresenter) -> void:
	var library := RecordingLibrary.new()
	check(library.load_from_file(), "authored contact reuses only the existing validated three-page pack")
	var pixels := PixelSpellEffects.new(library)
	var canvas := Node2D.new()
	var anchor := Vector2(340, 280)
	for reduced: bool in [false, true]:
		var masks: Dictionary = {}
		for element: String in PixelSpellEffects.ELEMENTS:
			var impact_id := pixels.asset_id(element, "impact", reduced)
			var core_id := pixels.asset_id(element, "flight", reduced)
			var authored_total := int(library.asset(impact_id).total_ticks)
			var total := pixels.impact_duration_ticks(authored_total)
			equal(total, ceili(authored_total * 1.5), "contact lasts50percent longer without looping or growing its hazard")
			var frame := library.sample(impact_id, 0)
			var image := (frame.texture as Texture2D).get_image()
			var flight_frame := library.sample(core_id, 0)
			var flight_image := (flight_frame.texture as Texture2D).get_image()
			var contact_pixels := 0
			var flight_pixels := 0
			var mask := PackedByteArray()
			for y: int in range(32):
				for x: int in range(32):
					var covered := image.get_pixel(int(frame.region.position.x) + x, int(frame.region.position.y) + y).a > 0.0
					mask.append(1 if covered else 0)
					contact_pixels += 1 if covered else 0
					flight_pixels += 1 if flight_image.get_pixel(int(flight_frame.region.position.x) + x, int(flight_frame.region.position.y) + y).a > 0.0 else 0
			masks[mask.hex_encode()] = element
			check(contact_pixels > flight_pixels, "authored opening contact is fuller than the flying core in both visual modes")
			for radius: float in [6.0, 10.8, 19.2]:
				var profile := pixels.impact_profile(element, radius, reduced)
				for age: int in range(total):
					var model := pixels.impact_model(element, anchor, age, reduced, radius)
					check(not model.is_empty(), "existing one-shot contact remains available at every live age")
					equal(model.anchor, anchor, "authored contact stays exactly at the source impact")
					equal(model.breakup, profile, "contact size, alpha and asset remain unchanged")
					check(model.imprint.is_empty(), "full contact never borrows or overlays a looping flight sprite")
					equal(model.sample_age_ticks, floori(float(age) * 2.0 / 3.0), "full authored contact preserves finite 1.5x sampling")
				check(pixels.impact_model(element, anchor, total, reduced, radius).is_empty(), "original one-shot expiry hides all contact art")
				library.begin_frame(reduced)
				library.draws.clear()
				check(pixels.impact(canvas, element, anchor, 3, reduced, radius), "actual impact path draws admitted contact")
				equal(library.draws.size(), 1, "available budget still emits exactly one full contact, never duplicate art")
				equal(library.decoration_stats().used, 0, "guaranteed single contact neither consumes nor adds optional capacity")
				for draw: Dictionary in library.draws:
					equal(draw.anchor, anchor, "actual draw calls keep exact stationary anchor")
					equal(draw.angle, 0.0, "upright material silhouettes are not rotated by travel heading")
			library.begin_frame(reduced)
			for kind: String in PixelSpellEffects.ELEMENTS:
				for unused: int in range(100):
					library.take_decoration(pixels.asset_id(kind, "field_tile", reduced))
			equal(library.decoration_remaining(), 0, "zero-budget fixture exhausts the normal/reduced shared pool")
			library.draws.clear()
			check(pixels.impact(canvas, element, anchor, 3, reduced), "budget exhaustion cannot remove meaningful contact identity")
			equal(library.draws.size(), 1, "zero budget cannot spawn an optional extra stamp")
			equal(library.draws[0].id, impact_id, "zero budget retains full authored contact, not generic dust or a flight sprite")
			equal(library.decoration_remaining(), 0, "impact cannot replenish exhausted decoration")
			library.draws.clear()
			check(pixels.impact(canvas, element, anchor, pixels.IMPACT_IMPRINT_TICKS, reduced), "later contact remains available at the historical capture checkpoint")
			equal(library.draws.size(), 1, "later contact remains exactly one original stamp")
			equal(library.draws[0].id, impact_id, "later phase returns only the original one-shot artwork")
			library.draws.clear()
			check(pixels.impact(canvas, element, anchor, total, reduced), "expired valid contact is handled so legacy fallback art cannot reappear")
			check(library.draws.is_empty(), "expired contacts issue zero GPU stamps")
		equal(masks.size(), 8, "eight source contact silhouettes differ in alpha shape, not merely palette")
	for bad_position: Vector2 in [Vector2(INF, 0), Vector2(NAN, 1)]:
		check(pixels.impact_model("fire", bad_position, 0, false).is_empty(), "invalid anchor cannot create contact")
	for radius: float in [-1.0, 0.0, INF, NAN]:
		check(pixels.impact_model("fire", anchor, 0, false, radius).is_empty(), "invalid radius cannot create a silhouette")
	check(pixels.impact_model("unknown", anchor, 0, false).is_empty(), "unknown element cannot borrow contact pixels")
	check(pixels.impact_model("fire", anchor, -1, false).is_empty(), "unborn contact is hidden")
	check(not pixels.impact(null, "fire", anchor, 0, false), "missing canvas has no drawing side effects")
	# The outer terminal-deposit adapter can impose an even shorter authority gate.
	presenter.pixel_effects = pixels
	library.draws.clear()
	check(not presenter.draw_impact(canvas, "fire", anchor, Vector2.RIGHT, 24, 24), "authoritative caller duration cuts off the contact before atlas expiry")
	check(library.draws.is_empty(), "outer authority exit cannot leave a looped core")
	canvas.free()


func _configured() -> BurstProjectilePresenter:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads")
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "ability catalog loads")
	var presenter := BurstProjectilePresenter.new()
	check(presenter.configure(language, catalog), "live pixel projectile contract validates: %s" % presenter.last_error)
	return presenter


func _test_live_pixel_contract(presenter: BurstProjectilePresenter) -> void:
	equal(presenter.pixel_effects.library, PixelMagicLibrary.default_library(), "projectiles reuse shared active atlases rather than loading legacy sheets")
	equal(presenter.pixel_effects.library.page_count(), 3, "only three shared magic pages are used")
	check(presenter.content_hash.length() == 64 and presenter.direction_contract_hash.length() == 64, "active pixels and shared direction contract have stable hashes")
	var source := FileAccess.get_file_as_string("res://src/presentation/burst_projectile_presenter.gd")
	check(not source.contains("ResourceLoader.load(") and not source.contains("assets/effects/projectiles/") and not source.contains("textures_by_element"), "live adapter has no legacy atlas loading dependency")
	var config := SimConfig.new(120)
	var count := 0
	for wire: int in presenter.catalog.runtime_wire_ids:
		var ability := presenter.catalog.ability_from_wire(wire)
		if String(ability.get("shape", "")) != "projectile":
			continue
		count += 1
		var projectile := ProjectileState.new(3010, 1, 1, wire, 1, Vector2i.ZERO, Vector2i.ZERO, 10000, 1000, 120)
		projectile.source_wire_id = wire
		projectile.lifetime_ticks = config.milliseconds_to_ticks(int(ability.lifetime_ms)) - 5
		projectile.radius = int(ability.radius)
		projectile.previous_x = 100000
		projectile.previous_y = 200000
		projectile.position_x = 104000
		projectile.position_y = 202000
		projectile.velocity_x = 83111
		projectile.velocity_y = -19234
		var before := projectile.canonical_values()
		var model := presenter.projectile_model(projectile, 0.5)
		check(not model.is_empty(), "every live projectile family uses the same active material contract")
		if model.is_empty():
			continue
		equal(model.element, ability.element, "exact admitted element is retained")
		equal(model.position, Vector2(102, 201), "continuous position interpolation is retained")
		check(model.direction.is_equal_approx(Vector2(83111, -19234).normalized()), "aim remains continuous rather than snapped to archived eight rows")
		equal(model.radius, float(projectile.radius) / 1000.0, "real radius is not taken from artwork")
		equal(model.age_ticks, 5, "animation follows actual120Hz lifetime age")
		for reduced: bool in [false, true]:
			var id := PixelSpellEffects.asset_id(model.element, "flight", reduced)
			check(not presenter.pixel_effects.library.sample(id, model.age_ticks).is_empty(), "normal and reduced projectile identities are available")
			equal(presenter.pixel_effects.library.rotation_for(id, 0.713), 0.0, "material cores stay upright at arbitrary real aim")
		equal(projectile.canonical_values(), before, "presentation sampling cannot alter simulation")
		projectile.lifetime_ticks = 0
		check(presenter.projectile_model(projectile).is_empty(), "expired projectiles disappear exactly")
	check(count > 0, "test covers actual runtime projectile families")


func _test_fail_closed(source: BurstProjectilePresenter) -> void:
	var invalid := BurstProjectilePresenter.new()
	check(not invalid.configure(source.language, source.catalog, PixelMagicLibrary.new()), "unloaded active pack fails closed instead of using archived sheets")
	check(not invalid.last_error.is_empty(), "pack failure explains startup refusal")
	check(invalid.catalog == null and invalid.pixel_effects == null and invalid.content_hash.is_empty(), "failed configuration exposes no partially ready renderer")
	check(not invalid.configure(null, source.catalog), "missing visual contract fails closed")
	check(not invalid.configure(source.language, null), "missing catalog fails closed")
	var projectile := ProjectileState.new(3010, 1, 1, 4096, 1, Vector2i.ZERO, Vector2i.ZERO, 10000, 1000, 120)
	projectile.source_wire_id = 4096
	projectile.radius = 10000
	projectile.lifetime_ticks = 12
	check(source.projectile_model(projectile).is_empty(), "unknown spell cannot fabricate a material")
	check(source.projectile_model(null).is_empty(), "missing owner cannot fabricate a projectile")


func _test_impact_profiles() -> void:
	for element: String in BurstProjectilePresenter.REQUIRED_ELEMENTS:
		var start := BurstProjectilePresenter.impact_profile(element, 0, 30)
		var midway := BurstProjectilePresenter.impact_profile(element, 15, 30)
		equal(start.element, element, "impact keeps exact single-element identity")
		check(float(midway.opacity) < float(start.opacity), "contact lifetime fades without lingering")
		check(BurstProjectilePresenter.impact_profile(element, 30, 30).is_empty(), "impact gate stops at expiry")
		check(BurstProjectilePresenter.impact_profile(element, -1, 30).is_empty(), "impact cannot precede its event")
	check(BurstProjectilePresenter.impact_profile("neutral", 0, 30).is_empty(), "inactive neutral art cannot substitute for a current element")
	check(BurstProjectilePresenter.impact_profile("fire", 0, 0).is_empty(), "invalid contact lifetime fails closed")
