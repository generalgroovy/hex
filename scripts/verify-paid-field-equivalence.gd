extends SceneTree
@warning_ignore_start("integer_division")
# Native exact-pixel comparison against independently frozen pre-paid-mesh code.
# Two <=512px viewports; isolated paid simulation, no Bootstrap/transport/progression.
const Court = preload("res://src/presentation/hex_court_presenter.gd")
const CourtBefore = preload("res://tests/support/hex_court_before_paid_mesh.gd")
const BeforeGlow = preload("res://tests/support/hex_magic_glow_before_paid_mesh.gd")
const Marks = preload("res://src/presentation/retro_material_marks.gd")
const Quality = preload("res://src/presentation/render_quality.gd")
const Grid = preload("res://src/sim/hex/hex_grid.gd")
const SIZE := Vector2i(512, 384)
const SOURCE_PATHS := ["res://src/presentation/hex_court_presenter.gd", "res://src/presentation/retro_material_marks.gd", "res://src/presentation/hex_material_surface.gd", "res://src/presentation/pixel_magic_library.gd", "res://src/presentation/hex_magic_glow.gd", "res://src/presentation/hex_water_material_presenter.gd", "res://tests/support/hex_court_before_paid_mesh.gd", "res://tests/support/retro_material_marks_before_paid_mesh.gd", "res://tests/support/hex_material_surface_before_paid_mesh.gd", "res://src/presentation/hex_surface_glow_cache.gd", "res://tests/support/hex_magic_glow_before_paid_mesh.gd", "res://scripts/verify-paid-field-equivalence.gd"]
const PINNED_REFERENCE_HASHES := {"res://tests/support/hex_court_before_paid_mesh.gd": "d37dfe0b465a122f147a64009e03c8c4f1fb39a3d9f0ebfc7ce496b698fff584", "res://tests/support/retro_material_marks_before_paid_mesh.gd": "09ab9a67a4a0d661b14725b9e5b777e7d46c2aa73c2bedd19c27711a088735b4", "res://tests/support/hex_material_surface_before_paid_mesh.gd": "6f2d3ca43e8e1eadfa3144a280c63d20138cdaaca8d5dda524ea7dbed66b0aae", "res://tests/support/hex_magic_glow_before_paid_mesh.gd": "4dff9c0ae52cb3aaed3a507bec6d00a4cd6b885fd739cbddc4ba5b8ece8fbdca", "res://src/presentation/hex_magic_glow.gd": "4dff9c0ae52cb3aaed3a507bec6d00a4cd6b885fd739cbddc4ba5b8ece8fbdca"}
var output := ""
var candidate: Board
var reference: Board
var candidate_view: SubViewport
var reference_view: SubViewport
var results: Array[Dictionary] = []
var failures := 0
var sources: Dictionary = {}
var checker_hash := ""
var paid_receipt: Dictionary = {}
var paid_comparisons := 0
var allow_empty := false

class Fixture extends RefCounted:
	var origin := Vector2i.ZERO
	var render_revision := 0
	var cells: Dictionary = {}
	var material := ""
	var wire := 0
	var phase := "active"
	var variant := 0
	func _init() -> void:
		cells[Vector2i.ZERO] = {}
		for cell: Vector2i in Grid.neighbors(Vector2i.ZERO): cells[cell] = {}
	func view(_cell: Vector2i, _tick: float) -> Dictionary:
		return {material + "_quantity": 100, material + "_present": true, "fire_phase": phase, "steam_heat": 1000}
	func render_regions(cell: Vector2i, requested: String, _tick: float) -> Array[Dictionary]:
		if requested != material: return []
		var polygon := PackedVector2Array()
		for point: Vector2i in Grid.vertices(cell): polygon.append(Vector2(point))
		var actual_phase := phase
		if material == "fire": actual_phase = "ignition" if phase == "forming" else "cooling" if phase == "decaying" else phase
		var owner := 2 if variant == 1 and cell.x > 0 else 1
		var row := {"material": material, "recipe_wire_id": wire, "footprint_id": 1,
			"polygon": polygon, "phase": actual_phase, "quantity": 100, "intensity": 1000,
			"danger": phase == "active" and variant != 2, "owner_key": owner, "owner": owner,
			"source_ids": [owner], "active_tick": 200, "decay_tick": 500, "expiry_tick": 720, "direction": Vector2i(1000, 0)}
		var rows: Array[Dictionary] = [row]
		if variant == 3:
			var overlap := row.duplicate(true)
			overlap.footprint_id = 2
			overlap.intensity = 500
			overlap.owner = 3
			overlap.owner_key = 3
			overlap.source_ids = [3]
			overlap.decay_tick = 560
			rows.append(overlap)
			if material == "conflagration":
				for layer: int in range(2,6):
					var extra := row.duplicate(true)
					extra.footprint_id = layer+1
					extra.owner = layer%2+1
					extra.owner_key = extra.owner
					extra.source_ids = [layer+10]
					extra.intensity = 250+layer*125
					rows.append(extra)
		return rows

class Board extends Node2D:
	var court: RefCounted
	var fixture := Fixture.new()
	var mode := "material"
	var reduced := false
	var paid_world: SimWorld
	var paid_tick := 0.0
	var zoom := 1.0
	var retro_tick := 0.0
	var optimized_glow := false
	var glow_variant := 0
	var serial := 0
	var failed := false
	func _draw() -> void:
		serial += 1
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color("aa9978"))
		# Background checker makes translucent fill/shared-edge changes visible.
		for x: int in range(0, SIZE.x, 32):
			for y: int in range(0, SIZE.y, 32):
				if (x / 32 + y / 32) % 2 == 0: draw_rect(Rect2(x, y, 32, 32), Color("243239"))
		if mode == "blank": return
		if mode == "paid":
			# Target-centered crop shows every paid field around the real 200px cursor.
			draw_set_transform(Vector2(SIZE)*0.5 + Vector2(0.25,0.75) - Vector2(1736,880)*zoom,0,Vector2.ONE*zoom)
			if not court.draw_ground(self,paid_world.hex_court,paid_tick,reduced,false): failed = true
			draw_set_transform(Vector2.ZERO)
			return
		if mode == "glow":
			var offset := Vector2(SIZE)*0.5+Vector2(0.25,0.75)+Vector2(glow_variant*0.125,0)
			var polygon := PackedVector2Array()
			for point: Vector2i in Grid.vertices(Vector2i.ZERO): polygon.append(Vector2(point)/1000.0*zoom+offset)
			if glow_variant%2 == 1: polygon.reverse()
			var base := Color(0.23,0.57,0.83,0.36) if glow_variant%2 == 0 else Color(0.71,0.37,0.11,0.92)
			var bright := Color(0.91,0.78,0.49,0.87)
			var opacity := 0.19 if glow_variant%2 == 0 else 0.52
			var count: int = court._surface_glow.draw_surface(self,polygon,base,bright,opacity) if optimized_glow else BeforeGlow.draw_surface(self,polygon,base,bright,opacity)
			if count != 2: failed = true
			return
		if mode == "retro":
			var index := 0
			for kind: String in Marks.MASKS:
				var offset := Vector2(52 + (index%5)*102,48 + (index/5)*92) + Vector2(0.25,0.75)
				var polygon := PackedVector2Array()
				for point: Vector2i in Grid.vertices(Vector2i.ZERO): polygon.append(Vector2(point)/1000.0*zoom + offset)
				if not court.retro_marks.draw_region(self,kind,polygon,Color("152331"),Color(0.57,0.28,0.37,0.82),Color("ffd26d"),retro_tick,index,reduced,0.37 if index%2 == 0 else 0.94): failed = true
				index += 1
			return
		for variant: int in 4:
			fixture.variant = variant
			var anchor := Vector2(128 if variant % 2 == 0 else 384, 96 if variant < 2 else 288) + Vector2(0.25,0.75)
			draw_set_transform(anchor, 0.0, Vector2.ONE * (0.75 if variant == 2 else 1.0))
			# Adjacent real Backdraft deadlines straddle the final72-tick warning.
			if not court.draw_ground(self, fixture, 427.0 if variant == 0 else 428.0, reduced, false): failed = true
			draw_set_transform(Vector2.ZERO)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	output = _option("--output")
	var expected := _option("--verify-user-data").replace("\\", "/").simplify_path().trim_suffix("/")
	var actual := OS.get_user_data_dir().replace("\\", "/").simplify_path().trim_suffix("/")
	if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("--no-lan-discovery") or expected.is_empty() or expected.to_lower() != actual.to_lower():
		_fail("Native window, --no-lan-discovery and exact isolated --verify-user-data are required"); return
	if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output):
		_fail("--output requires a fresh absolute directory"); return
	if DirAccess.make_dir_recursive_absolute(output) != OK: _fail("Cannot create fresh output"); return
	for path: String in SOURCE_PATHS:
		sources[path] = FileAccess.get_sha256(path)
		if String(sources[path]).length() != 64: _fail("Cannot hash inspected source: " + path); return
	for path: String in PINNED_REFERENCE_HASHES:
		if String(sources[path]) != String(PINNED_REFERENCE_HASHES[path]): _fail("Independent frozen oracle hash changed: " + path); return
	Quality.set_profile("standard")
	var language := VisualLanguage.new()
	if not language.load_from_file(): _fail("Visual language unavailable"); return
	candidate = Board.new()
	candidate.court = Court.new()
	candidate.optimized_glow = true
	reference = Board.new()
	reference.court = CourtBefore.new()
	for board: Board in [candidate, reference]:
		if not board.court.configure(language): _fail("Presenter configuration refused"); return
		if int(board.court.material_surface.stats().textures) <= 0: _fail("Native material bank unavailable; fallback-only equivalence cannot qualify"); return
	candidate_view = _viewport(candidate)
	reference_view = _viewport(reference)
	candidate.mode = "blank"
	reference.mode = "blank"
	if not await _compare("baseline/checker"): return
	for material: String in Court.MATERIALS:
		for phase: String in ["forming", "active", "decaying"]:
			for reduced: bool in [false, true]:
				for board: Board in [candidate, reference]:
					board.mode = "material"
					board.fixture.material = material
					board.fixture.wire = Court._material_wire(material)
					board.fixture.phase = phase
					board.reduced = reduced
				if not await _compare("material/%s/%s/%s" % [material, phase, "reduced" if reduced else "normal"]): return
	for tick: int in [0,11,22]:
		for reduced: bool in [false,true]:
			for zoom: float in [1.0,0.75]:
				for board: Board in [candidate,reference]:
					board.mode = "retro"
					board.retro_tick = tick
					board.reduced = reduced
					board.zoom = zoom
				if not await _compare("retro/all19/tick%d/reduced%s/zoom%.2f" % [tick,str(reduced),zoom]): return
	if not await _paid_sequence(): return
	# Fill beyond every retained region capacity, then exercise real old fallback
	# with fractional placement. First resident mesh must remain usable too.
	for index: int in 520:
		var polygon := PackedVector2Array()
		for point: Vector2i in Grid.vertices(Vector2i.ZERO): polygon.append(Vector2(point)/1000.0+Vector2(index*70,9000))
		candidate.court.retro_marks._region_mesh(polygon)
	for reduced: bool in [false,true]:
		for board: Board in [candidate,reference]:
			board.mode = "material"
			board.fixture.material = "conflagration"
			board.fixture.wire = 309
			board.fixture.phase = "active"
			board.reduced = reduced
		if not await _compare("overflow/conflagration/reduced%s" % str(reduced)): return
	var retro_stats: Dictionary = candidate.court.retro_marks.geometry_stats()
	if int(retro_stats.draws) <= 0 or int(retro_stats.builds) <= 0 or int(retro_stats.hits) <= 0 or int(retro_stats.meshes) != 512:
		_fail("Candidate must actually submit and reuse bounded native Retro meshes"); return
	# A distinct direct stamp after capacity exercises the original polygon path.
	for board: Board in [candidate,reference]:
		board.mode = "retro"
		board.zoom = 0.713
		board.reduced = false
		board.retro_tick = 31
	if not await _compare("overflow/new-retro-shapes"): return
	if int(candidate.court.retro_marks.geometry_stats().fallbacks) <= 0:
		_fail("Exact original Retro overflow drawing must execute"); return
	# Exact two-layer Standard glow, including changed live colors/opacities,
	# reversed geometry and legacy fallback after the strict256-entry bound.
	for variant: int in 2:
		for zoom: float in [1.0,0.75]:
			for board: Board in [candidate,reference]:
				board.mode = "glow"
				board.glow_variant = variant
				board.zoom = zoom
			if not await _compare("glow/retained/variant%d/zoom%.2f" % [variant,zoom]): return
	var glow_before: Dictionary = candidate.court._surface_glow.stats()
	if int(glow_before.draws) <= 0 or int(glow_before.hits) <= 0 or int(glow_before.builds) <= 0:
		_fail("Actual retained Standard glow must execute before overflow"); return
	for index: int in 270:
		var polygon := PackedVector2Array()
		for point: Vector2i in Grid.vertices(Vector2i.ZERO): polygon.append(Vector2(point)/1000.0+Vector2(index*70,13000))
		candidate.court._surface_glow.geometry_for_polygon(polygon)
	var old_fallbacks := int(candidate.court._surface_glow.stats().fallbacks)
	for variant: int in range(2,4):
		for zoom: float in [1.0,0.75]:
			for board: Board in [candidate,reference]:
				board.mode = "glow"
				board.glow_variant = variant
				board.zoom = zoom
			if not await _compare("glow/overflow/variant%d/zoom%.2f" % [variant,zoom]): return
	var glow_after: Dictionary = candidate.court._surface_glow.stats()
	if int(glow_after.entries) != 256 or int(glow_after.meshes) != 512 or int(glow_after.fallbacks) <= old_fallbacks:
		_fail("Bounded glow capacity and actual original fallback must execute"); return
	var conversion: Dictionary = candidate.court.region_geometry_cache_stats()
	if int(conversion.builds) <= 0 or int(conversion.hits) <= 0 or int(conversion.entries) > 512:
		_fail("Valid native geometry must use the bounded conversion cache"); return
	for board: Board in [candidate, reference]:
		var stats: Dictionary = board.court.material_surface.stats()
		if int(stats.translated_draws) <= 0 or int(stats.mesh_uploads) + int(stats.mesh_hits) <= 0:
			_fail("No actual native material draws observed; fallback-only result refused"); return
	var unchanged := true
	for path: String in SOURCE_PATHS: unchanged = unchanged and String(sources[path]) == FileAccess.get_sha256(path)
	if not unchanged: failures += 1
	var receipt := {"status": "passed" if failures == 0 else "failed", "scope": "Exact native pixels against independent frozen Court, Retro and material surface implementations: all69 materials at3 phases, overlapping ownership/danger/alpha seams,19 native marks, both effects modes and1/.75 zooms, actual ordinary12 paid Fire casts on current campus through finite expiry, and bounded-cache/glow overflow with current colors and opacity. Arranged sampling and paid-ground rendering only; not FPS, complete gameplay rendering or multiplayer acceptance.",
		"engine": Engine.get_version_info(), "renderer": RenderingServer.get_current_rendering_method(), "viewport": [512,384],
		"source_sha256": sources, "frozen_reference_sha256": PINNED_REFERENCE_HASHES, "sources_unchanged": unchanged, "material_identities": Court.MATERIALS.size(), "comparisons": results.size(), "failed_comparisons": failures,
		"paid_sequence": paid_receipt, "paid_comparisons": paid_comparisons, "candidate_retro_cache": candidate.court.retro_marks.geometry_stats(), "candidate_conversion_cache": conversion, "candidate_glow_cache": glow_after, "candidate_outline_cache": candidate.court.outline_cache_stats(), "candidate_material_surface": candidate.court.material_surface.stats(), "reference_material_surface": reference.court.material_surface.stats(), "rows": results}
	var file := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if file == null: _fail("Cannot write receipt"); return
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK: _fail("Receipt write failed"); return
	print("PAID_FIELD_EQUIVALENCE ", receipt.status, " comparisons=", results.size(), " mismatches=", failures)
	quit(0 if failures == 0 else 1)

func _paid_sequence() -> bool:
	var abilities := AbilityCatalog.new()
	var champions := ChampionCatalog.new()
	var layout := SanctumCampusLayout.new()
	if not abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json") or not champions.load_from_file("res://content/champions/foundation_champions_v1.json",abilities) or not layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"):
		_fail("Actual paid fixture catalogs refuse"); return false
	var world := SimWorld.new(120,8675309,layout.build_collision_world(),String(layout.data.id),layout.content_hash)
	var definition := HexWorldDefinition.from_campus(layout)
	if definition == null or not definition.bind_world(world) or not champions.apply_to_player(world.player(),"oh_tipi"):
		_fail("Actual campus and champion admission refuse"); return false
	var actor := world.player()
	actor.position_x = 1536000
	actor.position_y = 880000
	if not world.collision.can_occupy(Vector2i(actor.position_x,actor.position_y),actor.radius) or not actor.place_proven_spell(0,145):
		_fail("Actual Hearth placement or Fire equip refuses"); return false
	var attempts := 0
	var admissions := 0
	var refusals := 0
	var schedule: Dictionary = {0:"initial"}
	var products_seen: Dictionary = {}
	var phases_seen: Dictionary = {}
	var raw_seen := false
	var max_products := 0
	var max_regions := 0
	var attempt_ticks: Array[int] = []
	var empty_captured := false
	for _step: int in 1300:
		var pressed := 0
		if attempts < 12 and actor.pending_cast_wire_id == 0 and actor.cast_recovery_ticks == 0 and actor.spell_cooldown_for_wire(145) == 0:
			pressed = SimCommand.PRESSED_SPELL_1
			attempts += 1
			attempt_ticks.append(world.tick)
		var commands: Array[SimCommand] = [SimCommand.new(world.tick,1,0,0,0,pressed,1000,0,1736000,880000)]
		if not world.step(commands) or not world.hex_court.conservation_valid():
			_fail("Ordinary paid sequence or finite conservation fails"); return false
		for event: Dictionary in world.combat_events:
			if String(event.get("type","")) == "cast_started": admissions += 1
			if String(event.get("type","")) == "cast_refused": refusals += 1
		var tick := world.tick-1
		max_products = maxi(max_products,world.hex_court.products.size())
		for product: Dictionary in world.hex_court.products.values():
			var product_id := int(product.id)
			if not products_seen.has(product_id):
				products_seen[product_id] = {"created":int(product.created),"active":int(product.active_tick),"decay":int(product.decay_tick),"expiry":int(product.expiry_tick)}
				for boundary: int in [tick,int(product.active_tick)-1,int(product.active_tick),int(product.decay_tick)-1,int(product.decay_tick),int(product.expiry_tick)-1,int(product.expiry_tick)]: schedule[boundary] = "product-boundary"
		var raw_now := false
		var regions := 0
		for cell: Vector2i in world.hex_court.occupied_cells():
			for material: String in ["fire","conflagration"]:
				var rows: Array[Dictionary] = world.hex_court.render_regions(cell,material,float(tick))
				regions += rows.size()
				for region: Dictionary in rows:
					# Complete paid footprints, not only center pixels, fit both views.
					for point: Vector2 in region.polygon:
						var pixel := Vector2(SIZE)*0.5 + Vector2(0.25,0.75) + (point/1000.0-Vector2(1736,880))
						if not Rect2(Vector2(8,8),Vector2(SIZE)-Vector2(16,16)).has_point(pixel):
							_fail("Paid field boundary lies outside the arranged native crop"); return false
					phases_seen[material+"/"+String(region.phase)] = true
					if material == "fire": raw_now = true
		max_regions = maxi(max_regions,regions)
		if raw_now and not raw_seen: raw_seen = true; schedule[tick] = "first-raw"
		var empty: bool = attempts == 12 and world.projectiles.is_empty() and world.hex_court.casts.is_empty() and world.hex_court.products.is_empty()
		if empty and not empty_captured: schedule[tick] = "fully-expired"; empty_captured = true
		if schedule.has(tick):
			var before_hash := world.state_hash()
			allow_empty = world.hex_court.occupied_cells().is_empty()
			for reduced: bool in [false,true]:
				for zoom: float in [1.0,0.75]:
					for board: Board in [candidate,reference]:
						board.mode = "paid"
						board.paid_world = world
						board.paid_tick = tick
						board.reduced = reduced
						board.zoom = zoom
					if not await _compare("paid/tick%d/%s/reduced%s/zoom%.2f" % [tick,String(schedule[tick]),str(reduced),zoom]): return false
					paid_comparisons += 1
			if world.state_hash() != before_hash: _fail("Presentation mutated paid authority"); return false
			allow_empty = false
		if empty_captured: break
	if attempts != 12 or admissions != 12 or refusals != 0 or int(world.hex_court.metrics.get("matter_paid",0)) != 7200 or products_seen.size() != 6 or max_products != 6 or not raw_seen or not empty_captured:
		_fail("Paid route must prove12 admissions,7200 finite matter,six overlapping self reactions and full expiry"); return false
	for required: String in ["conflagration/forming","conflagration/active","conflagration/decaying"]:
		if not phases_seen.has(required): _fail("Missing actual paid phase: "+required); return false
	paid_receipt = {"attempts":attempts,"admitted":admissions,"refused":refusals,"matter_paid":7200,"attempt_ticks":attempt_ticks,"products":products_seen,"max_products":max_products,"max_prepared_regions":max_regions,"phases_seen":phases_seen.keys(),"fully_expired":empty_captured,"conservation_valid":world.hex_court.conservation_valid(),"actor_world_px":[1536,880],"target_world_px":[1736,880],"resource_refill":false,"authority_unchanged_by_every_comparison":true,"all_paid_boundary_vertices_inside_native_crop":true}
	return true

func _viewport(board: Board) -> SubViewport:
	var view := SubViewport.new()
	view.size = SIZE
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	view.add_child(board)
	return view

func _compare(label: String) -> bool:
	var before_candidate := candidate.serial
	var before_reference := reference.serial
	candidate.queue_redraw()
	reference.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	if candidate.failed or reference.failed or candidate.serial <= before_candidate or reference.serial <= before_reference:
		_fail("Both actual presenters must redraw: " + label); return false
	var actual: Image = candidate_view.get_texture().get_image()
	var expected: Image = reference_view.get_texture().get_image()
	if actual == null or expected == null or actual.get_size() != SIZE or expected.get_size() != SIZE:
		_fail("Native viewport capture unavailable: " + label); return false
	actual.convert(Image.FORMAT_RGBA8)
	expected.convert(Image.FORMAT_RGBA8)
	var a := actual.get_data()
	var b := expected.get_data()
	var equal_pixels := a == b
	if label == "baseline/checker": checker_hash = _hash(b)
	elif not allow_empty and (_hash(a) == checker_hash or _hash(b) == checker_hash):
		_fail("Empty/background-only draw cannot qualify: " + label); return false
	results.append({"label": label, "equal": equal_pixels, "candidate_rgba_sha256": _hash(a), "reference_rgba_sha256": _hash(b)})
	if not equal_pixels:
		failures += 1
		if failures <= 8:
			actual.save_png(output.path_join("mismatch-%03d-candidate.png" % results.size()))
			expected.save_png(output.path_join("mismatch-%03d-reference.png" % results.size()))
	return true

static func _hash(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func _option(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix + "="): return argument.substr(prefix.length() + 1)
	return ""

func _fail(message: String) -> void:
	printerr("PAID_FIELD_EQUIVALENCE_FAILED: " + message)
	quit(1)
