extends FluxTestSuite

const Effects = preload("res://src/presentation/pixel_spell_effects.gd")
const Status = preload("res://src/presentation/element_status_presenter.gd")
const Geometry = preload("res://src/presentation/pixel_effect_geometry.gd")
const MagicLibrary = preload("res://src/presentation/pixel_magic_library.gd")


func run() -> int:
	var config := SimConfig.new(120)
	var language := VisualLanguage.new()
	check(language.load_from_file(), "element presentation uses the validated material language")
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "element presentation uses the actual expanded roster")
	var presenter := FoundationSpellPresenter.new()
	check(presenter.configure(language, catalog), "all new delivery families have admitted preparation/release profiles")
	for mask: int in range(1, 64):
		var expected: Array[String] = []
		for wire: int in [3, 2, 4, 1, 7, 8]:
			var bit: int = {1: 1, 2: 2, 3: 4, 4: 8, 7: 16, 8: 32}[wire]
			if mask & bit: expected.append(String({3: "water", 2: "fire", 4: "wind", 1: "earth", 7: "light", 8: "dark"}[wire]))
		equal(Effects.mixture_elements(mask), expected, "mask preserves every ingredient in the independent display order")
		var sectors := Effects.mixture_sectors(mask, Vector2(100, 200), 18.0)
		equal(sectors.size(), expected.size(), "each ingredient receives exactly one stable material sector")
		var area := 0.0
		for sector: Dictionary in sectors:
			var points: PackedVector2Array = sector.points
			check(points.size() >= 3, "sector never degenerates into a missing visual")
			for point: Vector2 in points: check(point.is_finite() and point.distance_to(Vector2(100, 200)) <= 18.001, "all material pixels remain bounded by the real core")
			area += _area(points)
		check(area > PI * 18.0 * 18.0 * 0.95 and area <= PI * 18.0 * 18.0 * 1.001, "sectors cover one disk without duplicating full-strength silhouettes")
		for family: String in MixtureCatalog.FAMILIES:
			var wire := MixtureCatalog.wire_for(mask, family)
			var definition := CombatTuning.cast_definition_view(wire)
			check(not definition.is_empty() and presenter.profiles_by_wire.has(wire), "every live mixture and delivery has real compilation and hand cues")
			if definition.is_empty(): continue
			if family == "spray":
				_test_spray(wire, definition, expected)
				continue
			var shot := _shot(wire, definition, config)
			var original := shot.canonical_values()
			for reduced: bool in [false, true]:
				var model := Effects.expanded_projectile_model(shot, definition, Vector2(200, 200), config, null, reduced)
				check(not model.is_empty(), "each funded live delivery has visible geometry in both effect profiles")
				if model.is_empty(): continue
				equal(model.elements, expected, "reduced effects retains all six-component information")
				equal(model.radius, float(shot.radius) / 1000.0, "immutable physical contact radius is not reduced with effect density")
				check(not model.protection, "a Mantle attack never masquerades as invulnerability")
				equal(model.warning_radius, 0.0, "travel does not show a planted Fuse blast warning early")
				check(float(model.core_radius) <= float(model.radius), "depth facets stay inside the core")
				equal(shot.canonical_values(), original, "pure presentation cannot spend resources, alter provenance or advance delivery")
			shot.lifetime_ticks = 0
			check(Effects.expanded_projectile_model(shot, definition, Vector2.ZERO, config).is_empty(), "expired shot cannot retain a visual threat")
	_test_delivery_boundaries(config)
	_test_fuse_countdown_readability(config)
	_test_status(config, language)
	_test_status_protection_clearance(config, language)
	return finish("element-delivery-presentation")


func _test_spray(wire: int, definition: Dictionary, expected: Array[String]) -> void:
	var collision := CollisionWorld.new(1000000, 1000000)
	collision.add_obstacle(CollisionWorld.Obstacle.new(1, 390000, 180000, 410000, 220000))
	var cue := {"kind": "spray", "source_wire_id": wire, "start": Vector2(200, 200), "end": Vector2(520, 200), "duration": 0.20, "remaining": 0.10}
	cue.spray_geometry = HexCourtPresenter.prepare_spray_cue(cue, collision)
	var before := cue.duplicate(true)
	for reduced: bool in [false, true]:
		var model := Effects.mixed_spray_model(cue, definition, reduced)
		check(not model.is_empty(), "real prepared spray remains a finite clipped cone in both modes")
		if model.is_empty(): continue
		equal(model.segments.size(), expected.size() * (3 if reduced else 5), "every visible spray spoke carries each ingredient without spawning projectiles")
		for segment: Dictionary in model.segments:
			check(segment.element in expected, "spray never claims an absent ingredient")
			check((segment.start as Vector2).distance_to(cue.start) <= (cue.spray_geometry.endpoints[int(segment.ray)] as Vector2).distance_to(cue.start) + 0.001, "segment starts inside its physically clipped spoke")
			check((segment.end as Vector2).distance_to(cue.start) <= (cue.spray_geometry.endpoints[int(segment.ray)] as Vector2).distance_to(cue.start) + 0.001, "segment ends before cover, never on a regenerated full cone")
		equal(cue, before, "mixed spray presentation does not modify the retained visibility or physical cache")
	var hidden: Dictionary = cue.duplicate(true)
	hidden.spray_geometry.endpoints[0] = hidden.spray_geometry.start
	hidden.spray_geometry.brace = PackedVector2Array([hidden.start, hidden.start])
	var filtered := Effects.mixed_spray_model(hidden, definition, false)
	equal(filtered.segments.size(), expected.size() * 4, "observer-hidden spoke remains absent")
	check(not filtered.origin_visible, "hidden origin brace cannot be resurrected as a glyph")
	hidden.remaining = 0.0
	check(Effects.mixed_spray_model(hidden, definition, false).is_empty(), "expired spray cannot reappear through fallback drawing")


func _test_delivery_boundaries(config: SimConfig) -> void:
	var wire := MixtureCatalog.wire_for(63, "fuse")
	var definition := CombatTuning.cast_definition_view(wire)
	var shot := _shot(wire, definition, config)
	shot.position_x = 500000; shot.position_y = 500000
	shot.previous_x = 300000; shot.previous_y = 500000
	shot.delivery_phase = 1
	shot.delivery_ticks = 72
	var first := Effects.expanded_projectile_model(shot, definition, Vector2(300, 500), config)
	equal(first.center, Vector2(500, 500), "newly planted Fuse warning never interpolates backward along the old flight")
	equal(first.warning_radius, 110.0, "Fuse shows its independently authored 110px blast radius")
	equal(first.countdown_ratio, 1.0, "full actual600ms fuse has a full deadline meter")
	shot.delivery_ticks = 1
	var last := Effects.expanded_projectile_model(shot, definition, Vector2(300, 500), config)
	check(absf(float(last.countdown_ratio) - 1.0 / 72.0) < 0.000001, "last armed tick cannot restart the deadline meter")
	var collision := CollisionWorld.new(1000000, 1000000)
	collision.add_obstacle(CollisionWorld.Obstacle.new(1, 530000, 470000, 540000, 530000))
	var geometry := Geometry.new()
	var mask := geometry.disk_mask(first.center, float(first.warning_radius), collision)
	check(Geometry.contains_point(mask.polygons, Vector2(480, 500)), "Fuse warning retains unobstructed nearby space")
	check(not Geometry.contains_point(mask.polygons, Vector2(550, 500)), "solid cover and its shadow cannot be painted as guaranteed blast coverage")
	check(not Geometry.contains_point(mask.polygons, Vector2(389, 500)), "warning never exceeds actual blast radius")
	shot.delivery_damage_remaining = 0
	check(Effects.expanded_projectile_model(shot, definition, Vector2.ZERO, config).is_empty(), "spent Fuse cannot show an armed threat")
	var mantle_wire := MixtureCatalog.wire_for(7, "mantle")
	var mantle_definition := CombatTuning.cast_definition_view(mantle_wire)
	var mantle := _shot(mantle_wire, mantle_definition, config)
	var owner := PlayerState.new(1)
	owner.air_height = 40000
	owner.air_vertical_velocity = 0
	var before := owner.canonical_values()
	var airborne := Effects.expanded_projectile_model(mantle, mantle_definition, Vector2(200, 200), config, owner, false)
	var reduced := Effects.expanded_projectile_model(mantle, mantle_definition, Vector2(200, 200), config, owner, true)
	check(float(airborne.center.y) < 200.0 and float(reduced.center.y) < 200.0, "owner-height Mantle contacts are displayed above the floor in both motion modes")
	equal(airborne.ground_center, Vector2(200, 200), "lift does not move the actual world contact projection")
	equal(airborne.radius, 36.0, "Mantle contact radius stays36px independent of its depth rendering")
	mantle.delivery_damage_remaining = 8000
	equal(Effects.expanded_projectile_model(mantle, mantle_definition, Vector2.ZERO, config, owner).pool_ratio, 0.5, "Mantle actual shared paid pool owns its budget chips")
	equal(owner.canonical_values(), before, "rendering height never changes owner physics")
	owner.entity_id = 99
	check(Effects.expanded_projectile_model(mantle, mantle_definition, Vector2.ZERO, config, owner).is_empty(), "foreign owner cannot lend a fake height to another Mantle")
	var split_definition := CombatTuning.cast_definition_view(MixtureCatalog.wire_for(12, "split"))
	var split_shot := _shot(MixtureCatalog.wire_for(12, "split"), split_definition, config)
	check(Effects.expanded_projectile_model(split_shot, split_definition, Vector2.ZERO, config).split_parent, "unsplit paid parent shows future fork")
	split_shot.delivery_phase = 2
	var child := Effects.expanded_projectile_model(split_shot, split_definition, Vector2.ZERO, config)
	check(child.split_child and not child.split_parent, "actual split branches cannot suggest another unpaid split")
	check(Effects.mixture_sectors(64, Vector2.ZERO, 10).is_empty(), "unknown masks cannot invent ingredients")
	check(Effects.mixture_sectors(3, Vector2(INF, 0), 10).is_empty(), "invalid centers cannot reach drawing")
	check(Effects.expanded_projectile_model(split_shot, split_definition, Vector2.ZERO, SimConfig.new(0)).is_empty(), "unsupported timing configuration cannot fabricate deadlines")


func _test_fuse_countdown_readability(config: SimConfig) -> void:
	var wire := MixtureCatalog.wire_for(63, "fuse")
	var definition := CombatTuning.cast_definition_view(wire)
	var shot := _shot(wire, definition, config)
	check(Effects.fuse_countdown_model(Effects.expanded_projectile_model(shot, definition, Vector2(200, 200), config)).is_empty(), "travelling Fuse cannot advertise a planted countdown")
	shot.delivery_phase = 1
	for ticks: int in [72, 36, 1, 0, -1, 144]:
		shot.delivery_ticks = ticks
		var original := shot.canonical_values()
		var expected_width := 32.0 * clampf(float(ticks) / 72.0, 0.0, 1.0)
		var ordinary := {}
		for reduced: bool in [false, true]:
			var model := Effects.expanded_projectile_model(shot, definition, Vector2(900, 900), config, null, reduced)
			var meter := Effects.fuse_countdown_model(model)
			check(not meter.is_empty(), "planted Fuse has a separate deadline in both effect modes")
			if meter.is_empty(): continue
			var track: Rect2 = meter.track
			var fill: Rect2 = meter.fill
			equal(track.size, Vector2(32, 6), "deadline is a separate 32px high-contrast bar, not a competing core glyph")
			check(track.position.y > float(model.center.y) + float(model.radius), "deadline remains below the immutable projectile envelope")
			check(absf(fill.size.x - expected_width) < 0.000001 and fill.size.y == track.size.y, "full, half and final deadline widths follow the actual finite clock")
			check(track.encloses(fill), "negative or excess remaining ticks cannot draw outside the finite meter")
			equal(model.warning_radius, 110.0, "deadline readability cannot enlarge or shorten the real outer blast warning")
			equal(shot.canonical_values(), original, "countdown rendering never changes delivery state or payment")
			if reduced: equal(meter, ordinary, "reduced effects neither flashes nor omits remaining-time information")
			else: ordinary = meter
			for zoom: float in [0.75, 1.0]:
				check(track.size.x * zoom >= 24.0 and track.size.y * zoom >= 4.5, "supported zoom preserves a readable countdown track footprint")
	shot.delivery_damage_remaining = 0
	check(Effects.fuse_countdown_model(Effects.expanded_projectile_model(shot, definition, Vector2.ZERO, config)).is_empty(), "spent Fuse cannot leave a countdown behind")
	check(Effects.fuse_countdown_model({"armed": true, "center": Vector2(INF, 0), "radius": 18.0, "countdown_ratio": 1.0}).is_empty(), "invalid countdown position is refused")
	check(Effects.fuse_countdown_model({"armed": true, "center": Vector2.ZERO, "radius": 18.0, "countdown_ratio": NAN}).is_empty(), "nonfinite countdown cannot reach drawing")


func _test_status(config: SimConfig, language: VisualLanguage) -> void:
	var actor := PlayerState.new(2)
	actor.team_id = 2
	actor.spawn_protection_ticks = 0
	var wire := MixtureCatalog.wire_for(63, "bolt")
	SpellStatusPolicy.apply_hit(actor, wire, 700, 1, 1, 4000, config, Vector2i(1000, 0))
	var before := actor.canonical_values()
	var badges := Status.model(actor, config, language)
	equal(badges.size(), 6, "a real successful all-element hit exposes all six actual ailments")
	for channel: int in 6:
		var badge: Dictionary = badges[channel]
		equal(badge.channel, channel, "status badges preserve fixed rule order")
		equal(badge.ticks, actor.spell_status_values[channel * 8], "actual remaining ticks own status visibility")
		check(not badge.protection, "ailment badges do not claim evasion or damage protection")
	equal(badges[1].damage_remaining, 1000, "Burn badge reads the real finite quarter-hit damage reserve")
	equal(actor.canonical_values(), before, "status inspection is read-only")
	actor.spell_status_values[0] = 1
	check(absf(float(Status.model(actor, config, language)[0].seconds_remaining) - 1.0 / 120.0) < 0.000001, "refreshed attribution does not invent a starting duration")
	actor.spell_status_values[0] = 0
	equal(Status.model(actor, config, language).size(), 5, "expired channel immediately disappears despite stale metadata")
	actor.spell_status_values[10] = 0
	check(not Status.model(actor, config, language)[0].damage_active, "empty Burn pool is visibly spent while its existing status timer remains")
	actor.health = 0
	check(Status.model(actor, config, language).is_empty(), "defeat does not leave stale floating status badges")
	actor.health = 1000
	actor.spell_status_values.resize(47)
	check(Status.model(actor, config, language).is_empty(), "malformed status lanes cannot be indexed or presented")
	var protected := PlayerState.new(3)
	protected.team_id = 2; protected.spawn_protection_ticks = 20
	SpellStatusPolicy.apply_hit(protected, wire, 701, 1, 1, 4000, config, Vector2i.ZERO)
	check(Status.model(protected, config, language).is_empty(), "rejected protected hit cannot manufacture ailment visuals")


func _test_status_protection_clearance(config: SimConfig, language: VisualLanguage) -> void:
	# Composition geometry only. The native paid status/roll fixture supplies the
	# separate actual-input/timer witness; these declared states do not claim it.
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/pixel_cast_v1/manifest.json"))
	var heights: Array[int]=[]
	for row: Dictionary in manifest.characters:
		var height := int(row.display_height)
		check(height in [58,63,68],"status clearance covers every currently admitted body height")
		if height not in heights: heights.append(height)
	heights.sort()
	equal(heights,[58,63,68],"clearance matrix includes all three authored body sizes")
	var actor := PlayerState.new(2)
	actor.team_id=2
	actor.spawn_protection_ticks=0
	SpellStatusPolicy.apply_hit(actor,MixtureCatalog.wire_for(63,"bolt"),700,1,1,4000,config,Vector2i.ZERO)
	var library: RefCounted=MagicLibrary.default_library()
	check(library.asset_count()>0,"spawn crest clearance uses the actual admitted pixel stamp")
	# Current admitted pixel frame builders all have zero offset. Keep the real
	# Bootstrap shadow-to-body anchor difference rather than treating them alike.
	var sprite_offset := Vector2(0,float(MovementTuning.PLAYER_RADIUS)/1000.0*0.58)
	for height: int in heights:
		for reduced: bool in [false,true]:
			for kind: String in ["none","roll","air_dodge","spawn"]:
				actor.air_dodge_ticks=0;actor.air_height=0;actor.spawn_protection_ticks=0
				if kind in ["roll","air_dodge"]:
					actor.hop_mode=PlayerState.MovementMode.ROLL if kind=="roll" else PlayerState.MovementMode.AIR_DODGE
					actor.movement_mode=actor.hop_mode
					actor.air_height=10000 if kind=="air_dodge" else 0
					actor.air_dodge_ticks=config.milliseconds_to_ticks(MovementTuning.ROLL_DURATION_MS if kind=="roll" else MovementTuning.AIR_DODGE_DURATION_MS)
				elif kind=="spawn": actor.spawn_protection_ticks=1
				var before := actor.canonical_values()
				var protection := CartoonChampionPresenter.protection_contract(actor,config,reduced,float(height))
				equal(bool(protection.active),kind!="none","clearance keeps protected and unprotected semantics separate")
				var occupied: Array[Rect2]=[]
				for points: PackedVector2Array in protection.badge_lines:
					occupied.append(_status_stroke_bounds(points,sprite_offset,2.5))
				if kind=="spawn":
					var shield: PackedVector2Array=protection.shield
					var center := sprite_offset+(shield[0]+shield[1])*0.5+Vector2(0,4)
					var sample: Dictionary=library.sample(MagicLibrary.movement_asset_id("protection_badge",reduced),0)
					check(not sample.is_empty(),"actual spawn badge remains admitted in each effects profile")
					if not sample.is_empty(): occupied.append(Rect2(center+(sample.local_rect as Rect2).position,(sample.local_rect as Rect2).size))
				if int(protection.budget_pips)>0:
					for pip: int in 3:
						occupied.append(Rect2(sprite_offset+Vector2(13+pip*5,-float(height)-15),Vector2(4,5)).grow(1))
				for count: int in range(1,7):
					for index: int in count:
						var center := Vector2((float(index)-float(count-1)*0.5)*15.0,Status.BADGE_ROW_Y)
						var plate := Rect2(center-Vector2(6,7),Vector2(12,14))
						check(plate.is_finite() and absf(center.x)<=37.5,"all six status slots retain a finite centered row without extra icons")
						for protected_rect: Rect2 in occupied:
							check(not plate.intersects(protected_rect,true),"status plate cannot cover protected crest or remaining-window pips")
							for zoom: float in [0.75,1.0]:
								check(not Rect2(plate.position*zoom,plate.size*zoom).intersects(Rect2(protected_rect.position*zoom,protected_rect.size*zoom),true),"protection clearance survives both supported capture scales")
					equal(Status.model(actor,config,language).size(),6,"layout never removes an existing ailment to make room for protection")
				equal(actor.canonical_values(),before,"composition queries cannot alter protection or status clocks")
	var canvas := Node2D.new()
	var before := actor.canonical_values()
	for invalid: Vector2 in [Vector2(INF,0),Vector2(0,NAN)]:
		Status.draw(canvas,actor,invalid,config,language)
	equal(actor.canonical_values(),before,"nonfinite anchors return before any CanvasItem command or authority change")
	canvas.free()


static func _status_stroke_bounds(points: PackedVector2Array,offset: Vector2,half_width: float) -> Rect2:
	var rect := Rect2(points[0]+offset,Vector2.ZERO)
	for point: Vector2 in points: rect=rect.expand(point+offset)
	return rect.grow(half_width)


static func _shot(wire: int, definition: Dictionary, config: SimConfig) -> ProjectileState:
	var shot := ProjectileState.new(1, 1, 1, wire, int(definition.element_wire_id), Vector2i(200000, 200000), Vector2i(300000, 0), int(definition.radius), int(definition.damage), config.milliseconds_to_ticks(int(definition.lifetime_ms)))
	shot.initial_strength = int(definition.reaction_strength)
	shot.remaining_strength = shot.initial_strength
	shot.source_cast_id = 700
	shot.delivery_damage_remaining = shot.damage
	shot.delivery_ticks = config.milliseconds_to_ticks(int(definition.get("split_delay_ms", 250))) if String(definition.family) == "split" else 0
	shot.remaining_bounces = int(definition.get("remaining_bounces", 0))
	return shot


static func _area(points: PackedVector2Array) -> float:
	var twice := 0.0
	for index: int in points.size(): twice += points[index].cross(points[(index + 1) % points.size()])
	return absf(twice) * 0.5
