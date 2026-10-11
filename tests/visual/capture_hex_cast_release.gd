extends "res://tests/visual/capture_unified_wellspring.gd"


# Native production scene, real paid SimCommands, normal/reduced at identical
# authority ticks. Native-sized crops are arranged, never resized or repainted.
# Requires isolated APPDATA supplied by the engine owner, as other native probes.
# --hidden-viewport keeps the root window minimized and unfocusable while the native renderer
# submits the same production scene to an always-updating 1280x720 SubViewport.
const Release = preload("res://src/presentation/hex_cast_release.gd")
const Library = preload("res://src/presentation/pixel_magic_library.gd")
const TARGET := Vector2i(1504_000, 1344_000)
const SPAWN := TARGET + Vector2i(0, 96_000)
const FAMILIES := ["bolt", "heavy", "rapid", "spray"]
const CROP_SIZE := Vector2i(152, 170)
const ACTIVE_SURFACE_WAIT_TICKS := 120
const SPRAY_COVER_SOURCES := ["res://src/sim/hex/hex_court_practice.gd",
	"res://src/sim/core/sim_world.gd",
	"res://src/sim/hex/hex_projectile_combat.gd", "res://src/sim/hex/hex_chemistry_world.gd",
	"res://src/sim/combat/combat_system.gd", "res://src/sim/combat/continuous_contact.gd",
	"res://src/sim/world/collision_world.gd", "res://src/sim/hex/hex_grid.gd",
	"res://content/champions/foundation_champions_v1.json", RuntimeBuildIdentity.MANIFEST_PATH]
const SOURCE_PATHS := ["res://src/presentation/hex_cast_release.gd",
	"res://src/presentation/hex_projectile_facets.gd",
	"res://src/presentation/hex_magic_glow.gd",
	"res://src/presentation/hex_court_presenter.gd", "res://src/app/bootstrap.gd",
	"res://src/presentation/pixel_magic_library.gd", Library.MANIFEST_PATH,
	"res://content/abilities/foundation_abilities_v1.json",
	"res://tests/visual/capture_hex_cast_release.gd"]
var paid_cases: Array[Dictionary] = []
var phase_rows: Array[Dictionary] = []
var source_hashes := {}
var active_surface_evidence: Array[Dictionary] = []
var gallery: NativeGallery
var hidden_viewport := false
var render_viewport: Viewport


func _initialize() -> void:
	hidden_viewport = "--hidden-viewport" in OS.get_cmdline_user_args()
	if hidden_viewport:
		root.unfocusable = true
		root.mode = Window.MODE_MINIMIZED
	super._initialize()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/hex-cast-release-native-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("Provide a fresh native --output=res://.godot/hex-cast-release-native-NAME directory")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Could not create native release evidence directory")
		return
	for path: String in SOURCE_PATHS: source_hashes[path] = FileAccess.get_sha256(path)
	root.size = Vector2i(WIDTH, HEIGHT)
	root.title = "H.E.X. / paid elemental release capture"
	render_viewport = root
	if hidden_viewport:
		root.mode = Window.MODE_MINIMIZED
		var stage := SubViewport.new()
		stage.size = Vector2i(WIDTH, HEIGHT)
		stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(stage)
		render_viewport = stage
	else:
		root.visible = true
	game = BootstrapScene.instantiate()
	render_viewport.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	if game.element_audio != null:
		game.element_audio.set_process(false)
		game.element_audio.volume_percent = 0
	if game.world == null or game.world.hex_court == null:
		_fail("Production Wellspring did not boot with shared hex authority")
		return
	# The inherited _sync touches only game state/cues/history. Bootstrap's
	# camera and visibility queries follow game.get_viewport(), hence the same
	# authority synchronization works under either selected rendering surface.
	if game.get_viewport() != render_viewport or game.get_viewport_rect().size != Vector2(WIDTH, HEIGHT) or (hidden_viewport and root.mode != Window.MODE_MINIMIZED):
		_fail("Native release capture did not retain its selected viewport mode")
		return
	# Optional, bounded diagnostic scenario; the default 32-cast matrix below is
	# unchanged. This route uses production drawing, not the helper comparison.
	if "--spray-cover" in OS.get_cmdline_user_args():
		await _capture_spray_cover()
		return
	gallery = NativeGallery.new()
	render_viewport.add_child(gallery)
	gallery.visible = false
	for family: String in FAMILIES:
		phase_rows.clear()
		for element: String in Library.ELEMENTS:
			if not await _paid_case(element, family): return
		game.visible = false
		gallery.visible = true
		gallery.family = family
		gallery.rows = phase_rows
		for reduced: bool in [false, true]:
			gallery.reduced = reduced
			gallery.queue_redraw()
			if not await _save_root("paid-%s-%s" % [family, "reduced" if reduced else "normal"], "native-size-paid-sequence-board", reduced): return
		gallery.visible = false
		game.visible = true
	if not await _capture_comparison_board(): return
	for path: String in SOURCE_PATHS:
		if String(source_hashes[path]).length() != 64 or FileAccess.get_sha256(path) != source_hashes[path]:
			_fail("Release source changed during native capture: " + path)
			return
	if paid_cases.size() != 32 or frames.size() != 20 or active_surface_evidence.size() != 2:
		_fail("Incomplete paid matrix or bounded native evidence set")
		return
	var receipt := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if receipt == null:
		_fail("Could not write native release receipt")
		return
	receipt.store_string(JSON.stringify({"status":"passed", "frames":frames,"cases":paid_cases,"sources":source_hashes,
		"active_fire_surface":active_surface_evidence,
		"runtime_identity":JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)),
		"display":{"mode":"minimized-subviewport" if hidden_viewport else "visible-window",
			"server":DisplayServer.get_name(),"headless":false,"root_window_visible":root.visible,
			"viewport_type":render_viewport.get_class(),"render_size":[WIDTH,HEIGHT],
			"update_mode":"always" if hidden_viewport else "window-default",
			"evidence":"native renderer output, not desktop-screen or physical-input evidence"},
		"scope":"32 real paid SimCommand casts in production Wellspring; all8elements and4families; native75percent gameplay draw; normal/reduced frozen at identical authority ticks. Each case includes admitted release, travel or instantaneous Spray pulse, hostile contact, finite600matter conservation and cue expiry. Eight family boards use unscaled152x170 native screenshot crops; eight Fire release full frames retain1280x720 context. Two additional full frames show the same paid Fire Bolt's genuinely active material after at most120 neutral-command ticks, recording active regions and normal/reduced presenter surface-glow admissions. Two separate32case A/B helper boards compare old crosses to candidate at age4; those boards are synthetic, not paid gameplay. Twenty retained images in total. No physical input, human feel, multiplayer, performance or capacity acceptance.",
	},"\t") + "\n")
	receipt.close()
	print("PASS hex-cast-release native:32 paid casts,192 same-state cast phase renders,2 active-field renders,20 retained review images")
	quit(0)


func _capture_spray_cover() -> void:
	for path: String in SPRAY_COVER_SOURCES: source_hashes[path] = FileAccess.get_sha256(path)
	var world := SimWorld.new(120, 8675309)
	if not HexCourtPractice.configure(world, game.ability_catalog, false):
		_fail("Spray cover scenario could not configure the production diagnostic court")
		return
	game.world = world
	game.authoritative_session.world = world
	game.combat_cues.clear()
	game.station_notice_seconds = 0.0
	game.hex_playground_open = false
	game.show_debug_overlay = true # Production draws exact fixture collision boxes.
	var origin := HexCourt.ORIGIN
	var aim := origin + Vector2i(380_000, 0)
	var actor := world.player()
	if not game.champion_catalog.apply_to_player(actor, "oh_tipi"):
		_fail("Spray cover caster identity unavailable")
		return
	game.selected_champion_id = "oh_tipi"
	actor.reset_for_spawn(origin)
	actor.spawn_protection_ticks = 0
	actor.aim_x = 1000
	actor.aim_y = 0
	var obstacles := [
		CollisionWorld.Obstacle.new(901, origin.x + 80_000, origin.y - 10_000, origin.x + 90_000, origin.y + 10_000),
		CollisionWorld.Obstacle.new(902, origin.x + 120_000, origin.y - 90_000, origin.x + 130_000, origin.y - 30_000)]
	var cover_rows: Array[Dictionary] = []
	for obstacle: CollisionWorld.Obstacle in obstacles:
		world.collision.add_obstacle(obstacle)
		cover_rows.append({"id":obstacle.obstacle_id, "bounds_fixed":[obstacle.minimum_x, obstacle.minimum_y, obstacle.maximum_x, obstacle.maximum_y]})
	var target_rows: Array[Dictionary] = [
		{"id":3,"champion":"s_wayne","role":"upper-side-blocked","offset":Vector2i(250_000,-90_000),"expected_hits":0},
		{"id":4,"champion":"red_baron","role":"center-blocked","offset":Vector2i(250_000,0),"expected_hits":0},
		{"id":5,"champion":"grace_reava","role":"lower-clear","offset":Vector2i(250_000,90_000),"expected_hits":1}]
	# Avoid entity2: the production diagnostic court reserves it for its dummy.
	for row: Dictionary in target_rows:
		var target := PlayerState.new(int(row.id))
		if not game.champion_catalog.apply_to_player(target, String(row.champion)):
			_fail("Spray cover target identity unavailable")
			return
		target.reset_for_spawn(origin + Vector2i(row.offset))
		target.spawn_protection_ticks = 0
		target.team_id = actor.team_id + 1
		world.players.append(target)
		row.position_fixed = _point(origin + Vector2i(row.offset))
		row.erase("offset")
		row.health_before = target.health
		row.hit_count = 0
		if not world.collision.can_occupy(Vector2i(target.position_x,target.position_y), target.radius):
			_fail("Spray cover target overlaps fixture collision")
			return
	var wire := int(game.ability_catalog.ability(game.ability_catalog.spell_id_at("water","spray")).get("wire_id",0))
	var cast := CombatTuning.cast_definition(wire)
	if not actor.place_proven_spell(0,wire) or String(cast.get("family","")) != "spray" or not world.collision.can_occupy(origin,actor.radius):
		_fail("Spray cover fixture cannot equip its real paid Water Spray")
		return
	_sync()
	game.player_camera.clear()
	for _unused: int in 120:
		game.player_camera.advance(game.current_position,Vector2.ZERO,Vector2.RIGHT,1.0/120.0,Vector2(WIDTH,HEIGHT),Rect2(0,0,1280,960),64.0)
	var initial_flux := actor.flux
	var paid_flux := 0
	var release_tick := -1
	var released: Dictionary = {}
	var committed_cast_id := 0
	var committed_source_id := 0
	var phases: Array[Dictionary] = []
	var pulse_captured := false
	var aftermath_captured := false
	for index: int in range(160):
		var command := SimCommand.new(world.tick,1,0,0,0,int(SimCommand.SPELL_PRESSED_BITS[0]) if index == 0 else 0,1000,0,aim.x,aim.y)
		if not world.step([command]) or not world.hex_court.conservation_valid():
			_fail("Spray cover paid authority/conservation failed")
			return
		if index == 0:
			paid_flux = initial_flux - actor.flux
			if paid_flux != int(cast.flux_cost) or int(world.hex_court.metrics.get("matter_paid",0)) != 600:
				_fail("Spray cover cast did not pay exact upfront Flux and 600 matter")
				return
		for event: Dictionary in world.combat_events:
			if event.get("type") in ["cast_refused","cast_blocked"]:
				_fail("Spray cover paid cast was refused: " + str(event))
				return
			if event.get("type") == "spray_fired":
				if not released.is_empty():
					_fail("Spray cover fixture released more than one pulse")
					return
				released = event.duplicate(true)
				release_tick = world.tick
			for row: Dictionary in target_rows:
				if event.get("type") == "spray_hit" and int(event.get("target_id",0)) == int(row.id):
					row.hit_count += 1
		_sync()
		if release_tick < 0: continue
		if not pulse_captured and world.tick >= release_tick + 4:
			for row: Dictionary in target_rows:
				var target := world.player(int(row.id))
				row.health_after_contact = target.health
				row.expected_damage = int(cast.damage) * int(row.expected_hits)
				if int(row.hit_count) != int(row.expected_hits) or int(row.health_before) - target.health != int(row.expected_damage):
					_fail("Spray cover target did not match actual blocked/clear damage: " + String(row.role))
					return
			var expected_end := origin + Vector2i(int(cast.range),0)
			var actual_end := Vector2i(int(released.get("end_x",0)),int(released.get("end_y",0)))
			var diagnostic := _spray_cover_diagnostic(released,cast,target_rows)
			if int(released.get("hit_count",-1)) != 1 or int(released.get("range",0)) != int(cast.range) or actual_end != expected_end:
				_fail("Spray cover public envelope mismatch: " + JSON.stringify(diagnostic))
				return
			# SimWorld consumes private projectile_terminal events before step()
			# returns. Read the actual committed paid record, never fabricate an
			# event or replay a terminal/deposit just to obtain capture evidence.
			if world.hex_court.casts.size() != 1:
				_fail("Spray cover expected exactly one committed paid source: " + JSON.stringify(diagnostic))
				return
			committed_cast_id = int(world.hex_court.casts.keys()[0])
			var record: Dictionary = world.hex_court.casts[committed_cast_id]
			committed_source_id = int(record.get("source",0))
			var expected_shape := HexFootprint.sector(origin,Vector2i(1000,0),int(cast.range),int(cast.cone_cosine_squared_per_million))
			if not bool(record.get("paid",false)) or int(record.get("owner",0)) != actor.entity_id or int(record.get("wire",0)) != wire \
				or committed_source_id <= 0 or int(world.hex_court.sources.get(committed_source_id,0)) != committed_cast_id \
				or not HexCastParts.validate(record) or int(record.get("ground",0)) != 600 \
				or int(record.get("ledger",{}).get("flight_quantity",-1)) != 0 or not record.get("flight_parts",{}).is_empty() \
				or record.get("origin") != origin or record.get("footprint") != expected_shape \
				or record.get("ground_parts",{}).size() != 1 or not world.hex_court.pending.is_empty():
				_fail("Spray cover committed source/material mismatch: " + JSON.stringify(diagnostic))
				return
			if not await _capture_spray_cover_phase("pulse",wire,committed_cast_id,target_rows,phases): return
			pulse_captured = true
		if pulse_captured and world.tick >= release_tick + 30:
			if not await _capture_spray_cover_phase("aftermath",wire,committed_cast_id,target_rows,phases): return
			aftermath_captured = true
			break
	if not pulse_captured or not aftermath_captured or frames.size() != 4 or phases.size() != 4 or int(world.hex_court.metrics.get("matter_paid",0)) != 600:
		_fail("Spray cover evidence did not finish its bounded four-frame sequence")
		return
	for path: String in source_hashes:
		if String(source_hashes[path]).length() != 64 or FileAccess.get_sha256(path) != source_hashes[path]:
			_fail("Spray cover source changed during capture: " + path)
			return
	var receipt := FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
	if receipt == null:
		_fail("Could not write Spray cover receipt")
		return
	receipt.store_string(JSON.stringify({"status":"passed","mode":"spray-cover-only","frames":frames,"sources":source_hashes,
		"runtime_identity":JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)),
		"display":{"server":DisplayServer.get_name(),"headless":false,"mode":"minimized-subviewport" if hidden_viewport else "visible-window",
			"root_window_visible":root.visible,"viewport_type":render_viewport.get_class(),"render_size":[WIDTH,HEIGHT],"native_resize":false},
		"fixture":{"map_id":world.map_id,"map_hash":world.map_hash,"origin_fixed":_point(origin),"aim_fixed":_point(aim),"collision_boxes":cover_rows,
			"caster":"oh_tipi","targets":target_rows,"debug_collision_drawing":true,"pov_mask_enabled":true,
			"cover_semantics":"Collision-only boxes block paid Spray rays; they are not opaque building/hex-pillar LOS surfaces. Target and cell POV visibility is recorded, not inferred from shot cover."},
		"paid_cast":{"element":"water","family":"spray","wire_id":wire,"flux_paid":paid_flux,"matter_paid":600,"release_tick":release_tick,
			"committed_cast_id":committed_cast_id,"source_cast_id":committed_source_id,
			"material_evidence":"Actual post-step committed cast footprint, source ownership, one ground part, 600 ground and zero flight; private terminal events are consumed by SimWorld.",
			"release_event":released,"physical_radius_fixed":int(cast.radius),"conservation_valid":world.hex_court.conservation_valid(),"direct_deposit_injection":false},
		"phases":phases,
		"scope":"One real paid SimCommand Water Spray in production Bootstrap's diagnostic HexCourtPractice, two fixture collision boxes, three real hostile champion profiles. Four unscaled full native frames: pulse and paid active aftermath, each Normal/Reduced at identical authority hashes. Production collision debug overlay exposes fixture geometry; cached production five-spoke geometry and all candidate/selected cell visibility are recorded. Default 32-cast matrix is not run by this option.",
		"limitations":"Scripted local scenario, not physical input, human visual acceptance, natural Wellspring pillar artwork, multiplayer, capacity, performance, full-roster or all-element acceptance. Whole-cell selection clips center rays; it does not stencil partial hexes. Diagnostic shot-cover boxes do not establish opaque POV occlusion. No injected spells, fields, or deposits."},"\t") + "\n")
	receipt.close()
	print("PASS Spray-cover native: one paid Water Spray, clear flank hit, two covered targets, four matched-authority native frames")
	quit(0)


func _spray_cover_diagnostic(released: Dictionary, cast: Dictionary, targets: Array[Dictionary]) -> Dictionary:
	var world: SimWorld = game.world
	var records: Array[Dictionary] = []
	for id: int in world.hex_court.casts:
		var record: Dictionary = world.hex_court.casts[id]
		records.append({"id":id,"source":record.get("source",0),"owner":record.get("owner",0),"wire":record.get("wire",0),
			"paid":record.get("paid",false),"origin":_point(record.get("origin")),"footprint":record.get("footprint",{}),
			"flight_quantity":record.get("ledger",{}).get("flight_quantity",-1),"ground":record.get("ground",-1),
			"flight_parts":record.get("flight_parts",{}).size(),"ground_parts":record.get("ground_parts",{}).size()})
	var actors: Array[Dictionary] = []
	for actor: PlayerState in world.players:
		actors.append({"id":actor.entity_id,"kind":actor.actor_kind,"team":actor.team_id,"health":actor.health,
			"position_fixed":[actor.position_x,actor.position_y]})
	return {"tick":world.tick,"released":released,"expected_hit_count":1,"expected_range":int(cast.range),
		"expected_endpoint":_point(HexCourt.ORIGIN+Vector2i(int(cast.range),0)),"targets":targets,"actors":actors,
		"committed_casts":records,"pending_casts":world.hex_court.pending.size(),"matter_paid":world.hex_court.metrics.get("matter_paid",0)}


func _capture_spray_cover_phase(phase: String, wire: int, committed_cast_id: int, targets: Array[Dictionary], evidence: Array[Dictionary]) -> bool:
	var world: SimWorld = game.world
	var authority_hash := world.state_hash()
	var record: Dictionary = world.hex_court.casts.get(committed_cast_id,{})
	if record.is_empty() or int(record.get("wire",0)) != wire or not HexCastParts.validate(record) \
		or int(record.get("ground",0)) != 600 or int(record.get("ledger",{}).get("flight_quantity",-1)) != 0 \
		or not world.hex_court.conservation_valid():
		_fail("Spray cover aftermath is not the original finite paid ground allocation")
		return false
	var cast := CombatTuning.cast_definition(wire)
	var cell_rows: Array[Dictionary] = []
	var selected_count := 0
	var blocked_count := 0
	var clear_beyond_cover := 0
	var active_regions := 0
	for cell: Vector2i in HexFootprint.selected_cells(record.footprint,world.hex_court.origin,world.hex_court.topology_cells_view()):
		var center: Vector2i = world.hex_court.origin + HexGrid.center(cell)
		var ray_clear := ContinuousContact.wall_contact(Vector2i(record.origin),center,int(cast.radius),world.collision).is_empty()
		var selected: bool = record.cells.has(cell)
		if selected != ray_clear:
			_fail("Spray material selection disagrees with full-radius candidate cell ray")
			return false
		if selected:
			selected_count += 1
			if center.x > HexCourt.ORIGIN.x + 130_000 and center.y > HexCourt.ORIGIN.y: clear_beyond_cover += 1
		else: blocked_count += 1
		for region: Dictionary in world.hex_court.render_regions(cell,"water",float(world.tick)):
			if String(region.get("phase","")) == "active": active_regions += 1
		cell_rows.append({"cell":_point(cell),"center_fixed":_point(center),"ray_clear":ray_clear,"selected":selected,
			"quantity":int(record.cells.get(cell,0)),"pov_visible":game._pov_point_visible(Vector2(center)/1000.0)})
	if selected_count == 0 or blocked_count == 0 or clear_beyond_cover == 0 or (phase == "aftermath" and active_regions == 0):
		_fail("Spray cover lacks positive clear/blocked whole-cell or active-material evidence")
		return false
	var spray_cue: Dictionary = {}
	for cue: Dictionary in game.combat_cues:
		if cue.get("kind") == "spray" and int(cue.get("source_wire_id",0)) == wire: spray_cue = cue
	if (phase == "pulse" and (spray_cue.is_empty() or not game._combat_cue_visible(spray_cue))) or (phase == "aftermath" and not spray_cue.is_empty()):
		_fail("Spray pulse visibility/finite expiry disagrees with its selected phase")
		return false
	var endpoints: Array = []
	var observer_view: Dictionary = {}
	if not spray_cue.is_empty():
		var draw_view: Dictionary = game._spray_cue_draw_view(spray_cue)
		if draw_view.is_empty():
			_fail("Visible paid Spray has no current production observer draw view")
			return false
		observer_view = {"visible_spoke_indices":Array(draw_view.spray_visible_indices),
			"spoke_point_probes":int(draw_view.spray_visibility_probes),"chemical_broadphase":bool(draw_view.spray_chemical_broadphase),
			"chemical_box_checks":int(draw_view.spray_chemical_box_checks),"active_concealer_count":int(draw_view.spray_concealer_count),
			"label_visible":not String(draw_view.get("label", "")).is_empty()}
		var geometry: Dictionary = spray_cue.get("spray_geometry",{})
		var points: PackedVector2Array = geometry.get("endpoints",PackedVector2Array())
		if points.size() != 5:
			_fail("Production Spray cue did not cache its five clipped spokes")
			return false
		for index: int in points.size():
			endpoints.append({"index":index,"position_world":[points[index].x,points[index].y],"pov_visible":game._pov_point_visible(points[index])})
		if points[2].distance_to(Vector2(HexCourt.ORIGIN)/1000.0) >= 80.0 or points[4].distance_to(Vector2(HexCourt.ORIGIN)/1000.0) < float(cast.range)/1000.0 - 1.0:
			_fail("Production Spray spokes did not retain a full clear flank beside the clipped center")
			return false
	var target_views: Array[Dictionary] = []
	for row: Dictionary in targets:
		var actor := world.player(int(row.id))
		var visible: bool = game._chemistry_actor_visible(actor)
		if not visible:
			_fail("Spray diagnostic target unexpectedly hidden by production POV")
			return false
		target_views.append({"id":actor.entity_id,"role":row.role,"health":actor.health,"position_fixed":[actor.position_x,actor.position_y],"pov_visible":visible})
	for reduced: bool in [false,true]:
		game.requested_capture_reduced_effects = reduced
		game.queue_redraw()
		if not await _save_root("spray-cover-%s-%s" % [phase,"reduced" if reduced else "normal"],"production-paid-spray-cover",reduced): return false
		if world.state_hash() != authority_hash:
			_fail("Spray normal/reduced drawing changed paid authority")
			return false
		evidence.append({"phase":phase,"reduced":reduced,"tick":world.tick,"world_hash":authority_hash,
			"pulse_visible":not spray_cue.is_empty(),"pulse_endpoints":endpoints,"observer_draw_view":observer_view,
			"mode_spoke_indices":HexCourtPresenter.SPRAY_CUE_REDUCED_RAYS if reduced else HexCourtPresenter.SPRAY_CUE_RAYS,
			"targets":target_views,"candidate_cells":cell_rows,"selected_cell_count":selected_count,"blocked_candidate_count":blocked_count,
			"clear_lower_cells_beyond_cover":clear_beyond_cover,"active_water_regions":active_regions,"finite_ground_quantity":600})
	return true


func _paid_case(element: String, family: String) -> bool:
	# Use production world construction rather than hundreds of full boot/reset
	# cycles. A controlled hostile actor is scenario setup, never a fake spell.
	game.world = game._new_wellspring_world(120)
	if game.world == null:
		_fail("Production world construction failed")
		return false
	game.authoritative_session.world = game.world
	game.combat_cues.clear()
	game.station_notice_seconds = 0.0
	game.hex_playground_open = false
	var world: SimWorld = game.world
	var actor: PlayerState = world.player()
	if not game.champion_catalog.apply_to_player(actor, "oh_tipi"):
		_fail("Production release actor unavailable")
		return false
	game.selected_champion_id = "oh_tipi"
	actor.reset_for_spawn(SPAWN)
	actor.spawn_protection_ticks = 0
	actor.aim_x = 0
	actor.aim_y = -1000
	var target := PlayerState.new(2)
	if not game.champion_catalog.apply_to_player(target, "s_wayne"):
		_fail("Production hostile target identity unavailable")
		return false
	target.reset_for_spawn(TARGET)
	target.spawn_protection_ticks = 0
	target.team_id = actor.team_id + 1
	world.players.append(target)
	if not world.collision.can_occupy(SPAWN, MovementTuning.PLAYER_RADIUS) or not world.collision.can_occupy(TARGET, MovementTuning.PLAYER_RADIUS):
		_fail("Paid release lane no longer clears current campus geometry")
		return false
	var ability: Dictionary = game.ability_catalog.ability(game.ability_catalog.spell_id_at(element,family))
	var wire := int(ability.get("wire_id",0))
	var definition := CombatTuning.cast_definition(wire)
	if not actor.place_proven_spell(0,wire) or String(definition.get("family","")) != family:
		_fail("Live spell matrix could not equip " + element + " " + family)
		return false
	_sync()
	game.player_camera.clear()
	for _unused: int in 120:
		game.player_camera.advance(game.current_position,Vector2.ZERO,Vector2.UP,1.0/120.0,Vector2(WIDTH,HEIGHT),Rect2(0,0,3072,2304))
	var initial_flux := actor.flux
	var initial_health := target.health
	var release_tick := -1
	var hit_tick := -1
	var release_count := 0
	var hit_count := 0
	var saw_flight := false
	var stages := {}
	var phase_evidence: Array[Dictionary] = []
	var upfront_flux := 0
	for step: int in range(160):
		var commands: Array[SimCommand] = []
		commands.append(SimCommand.new(world.tick,1,0,0,0,int(SimCommand.SPELL_PRESSED_BITS[0]) if step == 0 else 0,0,-1000,TARGET.x,TARGET.y))
		if not world.step(commands) or not world.hex_court.conservation_valid():
			_fail("Paid release step/conservation failed: %s %s" % [element,family])
			return false
		if step == 0:
			upfront_flux = initial_flux - actor.flux
			if upfront_flux != int(definition.flux_cost) or int(world.hex_court.metrics.get("matter_paid",0)) != 600:
				_fail("Real admission did not pay its exact Flux cost and600matter")
				return false
		for event: Dictionary in world.combat_events:
			var kind := String(event.get("type",""))
			if kind in ["cast_refused","cast_blocked"]:
				_fail("Controlled paid release was refused: " + str(event))
				return false
			if kind == ("spray_fired" if family == "spray" else "projectile_spawned") and int(event.get("owner_id",0)) == 1:
				release_tick = world.tick
				release_count += 1
			if kind == ("spray_hit" if family == "spray" else "projectile_hit") and int(event.get("target_id",0)) == 2:
				hit_tick = world.tick
				hit_count += 1
		saw_flight = saw_flight or not world.projectiles.is_empty()
		_sync()
		if release_tick >= 0:
			for stage: int in range(3):
				var due := release_tick + (4 if stage == 0 else 8) if stage < 2 else hit_tick + 4
				if stages.has(stage) or world.tick < due or (stage == 2 and hit_tick < 0): continue
				var phase := "contact"
				if stage == 0: phase = "release"
				elif stage == 1: phase = "instant-pulse" if family == "spray" else "travel"
				if stage == 1 and family != "spray" and world.projectiles.is_empty():
					_fail("Selected travel frame has no live projectile: %s %s" % [element,family])
					return false
				if not await _capture_paid_phase(element,family,stage,phase,phase_evidence): return false
				stages[stage] = true
			if stages.size() == 3 and world.tick >= release_tick + 26 and actor.pending_cast_wire_id == 0 and world.projectiles.is_empty(): break
	var release_remaining := 0
	for cue: Dictionary in game.combat_cues:
		if cue.get("kind") == "pixel_release": release_remaining += 1
	if release_count != 1 or hit_count < 1 or target.health >= initial_health or stages.size() != 3 \
		or release_remaining != 0 or actor.pending_cast_wire_id != 0 or not world.projectiles.is_empty() \
		or int(world.hex_court.metrics.get("matter_paid",0)) != 600 or (family != "spray" and not saw_flight):
		_fail("Incomplete real release/travel/contact/expiry path: %s %s releases=%d hits=%d stages=%d" % [element,family,release_count,hit_count,stages.size()])
		return false
	if element == "fire" and family == "bolt":
		if not await _capture_active_fire_surface(): return false
	paid_cases.append({"element":element,"family":family,"wire_id":wire,"release_tick":release_tick,"hit_tick":hit_tick,
		"release_count":release_count,"hit_count":hit_count,"flux_paid":upfront_flux,"matter_paid":600,
		"target_health_before":initial_health,"target_health_after":target.health,"saw_projectile_flight":saw_flight,
		"release_cue_expired":true,"conservation_valid":true,"world_hash":world.state_hash(),"phases":phase_evidence})
	print("PAID release ",element," ",family," cost=",upfront_flux," release=",release_tick," contact=",hit_tick)
	return true


func _active_fire_region_count() -> int:
	var world: SimWorld = game.world
	var count := 0
	for cell: Vector2i in world.hex_court.occupied_cells():
		for region: Dictionary in world.hex_court.render_regions(cell, "fire", float(world.tick)):
			if String(region.get("phase", "")) == "active" and int(region.get("intensity", 0)) > 0 and int(region.get("quantity", 0)) > 0:
				count += 1
	return count


func _capture_active_fire_surface() -> bool:
	var world: SimWorld = game.world
	var start_tick := world.tick
	var waited := 0
	var active_regions := _active_fire_region_count()
	# Continue only the existing paid aftermath through real idle commands.
	# Never inject a field, rewrite its phase, or pay for a second cast.
	while active_regions == 0 and waited < ACTIVE_SURFACE_WAIT_TICKS:
		if not _neutral_step(): return false
		waited += 1
		active_regions = _active_fire_region_count()
	if active_regions <= 0 or not world.hex_court.conservation_valid() or int(world.hex_court.metrics.get("matter_paid", 0)) != 600:
		_fail("Paid Fire Bolt did not produce active conserved material within the bounded idle window")
		return false
	var authority_hash := world.state_hash()
	for reduced: bool in [false, true]:
		game.requested_capture_reduced_effects = reduced
		game.queue_redraw()
		await process_frame
		if hidden_viewport:
			await process_frame # Flush queued CanvasItem draw commands before readback.
			RenderingServer.force_draw(false)
		else:
			await RenderingServer.frame_post_draw
		var admitted := int(game.hex_court_presenter._magic_surface_glows)
		if world.state_hash() != authority_hash or _active_fire_region_count() != active_regions \
			or (admitted != 0 if reduced else admitted <= 0) or admitted > HexCourtPresenter.MagicGlow.SURFACE_LIMIT:
			_fail("Active Fire normal/reduced capture changed authority or violated surface-glow admission")
			return false
		var label := "paid-fire-bolt-active-%s" % ("reduced" if reduced else "normal")
		if not _store_image(render_viewport.get_texture().get_image(), label, "production-active-fire-surface", reduced): return false
		active_surface_evidence.append({"element":"fire", "family":"bolt", "reduced":reduced,
			"start_tick":start_tick, "waited_neutral_ticks":waited, "wait_limit_ticks":ACTIVE_SURFACE_WAIT_TICKS,
			"tick":world.tick, "world_hash":authority_hash, "active_region_count":active_regions,
			"surface_glow_admissions":admitted, "surface_glow_limit":HexCourtPresenter.MagicGlow.SURFACE_LIMIT,
			"matter_paid":600, "conservation_valid":true, "direct_field_injection":false})
	return true


func _capture_paid_phase(element: String, family: String, stage: int, phase: String, evidence: Array[Dictionary]) -> bool:
	var world: SimWorld = game.world
	var before := world.state_hash()
	var origin: Vector2 = game._camera_origin(game._camera_focus_position(game.current_position))
	var center := PixelPresentation.world_to_screen(Vector2(SPAWN + TARGET) / 2000.0, origin, PlayerCameraRig.ZOOM_PERCENT)
	var crop := Rect2i(Vector2i(center.round()) - Vector2i(76,100),CROP_SIZE)
	if not Rect2i(Vector2i.ZERO,Vector2i(WIDTH,HEIGHT)).encloses(crop):
		_fail("Paid action crop left its actual viewport")
		return false
	for reduced: bool in [false,true]:
		game.requested_capture_reduced_effects = reduced
		game.queue_redraw()
		await process_frame
		if hidden_viewport:
			await process_frame
			RenderingServer.force_draw(false)
		else:
			await RenderingServer.frame_post_draw
		var rendered := render_viewport.get_texture().get_image()
		if rendered == null or rendered.get_size() != Vector2i(WIDTH,HEIGHT) or world.state_hash() != before:
			_fail("Normal/reduced production draw failed or changed authority")
			return false
		phase_rows.append({"element":element,"stage":stage,"phase":phase,"reduced":reduced,
			"texture":ImageTexture.create_from_image(rendered.get_region(crop))})
		var release_visible := false
		for cue: Dictionary in game.combat_cues:
			if cue.get("kind") == "pixel_release" and game._combat_cue_visible(cue): release_visible = true
		if stage == 0 and not release_visible:
			_fail("Real paid release is not visible in production POV")
			return false
		evidence.append({"phase":phase,"stage":stage,"reduced":reduced,"tick":world.tick,
			"world_hash":before,"release_visible":release_visible,"native_crop":[crop.position.x,crop.position.y,crop.size.x,crop.size.y]})
		if element == "fire" and stage == 0:
			if not _store_image(rendered,"paid-fire-%s-release-%s" % [family,"reduced" if reduced else "normal"],"production-full-frame",reduced): return false
	return true


func _capture_comparison_board() -> bool:
	game.visible = false
	gallery.visible = false
	var board := ReleaseBoard.new()
	if not board.configure():
		board.free()
		_fail("Could not configure native release comparison board")
		return false
	render_viewport.add_child(board)
	for reduced: bool in [false,true]:
		board.reduced = reduced
		board.queue_redraw()
		if not await _save_root("release-comparison-%s" % ("reduced" if reduced else "normal"),"synthetic-production-helper-comparison",reduced): return false
	board.queue_free()
	return true


func _save_root(label: String, kind: String, reduced: bool) -> bool:
	await process_frame
	if hidden_viewport:
		await process_frame
		RenderingServer.force_draw(false)
	else:
		await RenderingServer.frame_post_draw
	return _store_image(render_viewport.get_texture().get_image(),label,kind,reduced)


func _store_image(rendered: Image, label: String, kind: String, reduced: bool) -> bool:
	var path := output.path_join(label + "-1280x720.png")
	if rendered == null or rendered.get_size() != Vector2i(WIDTH,HEIGHT) or rendered.save_png(path) != OK:
		_fail("Native release image could not be saved")
		return false
	frames.append({"file":path.get_file(),"sha256":FileAccess.get_sha256(path),"kind":kind,"reduced":reduced,"width":WIDTH,"height":HEIGHT})
	return true


class NativeGallery:
	extends Node2D
	var rows: Array[Dictionary] = []
	var family := ""
	var reduced := false
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color("18231f"))
		_text(Vector2(20,28),"H.E.X. / PAID %s / %s" % [family.to_upper(),"REDUCED" if reduced else "NORMAL"],18)
		_text(Vector2(20,51),"Unscaled native75% gameplay crops. Real paid releases, travel or instantaneous Spray pulse, and hostile contact.",13)
		for column: int in Library.ELEMENTS.size():
			_text(Vector2(35 + column * 157,78),String(Library.ELEMENTS[column]).to_upper(),12)
		for row: Dictionary in rows:
			if bool(row.reduced) != reduced: continue
			var column: int = Library.ELEMENTS.find(row.element)
			var at := Vector2(12 + column * 157,104 + int(row.stage) * 194)
			draw_texture(row.texture,at)
			_text(at + Vector2(3,185),String(row.phase),11)
		_text(Vector2(20,700),"One600matter admission each; exact upfront Flux costs; same authority hashes in both modes. No human/performance/multiplayer claim.",12)
	func _text(at: Vector2, value: String, size: int) -> void:
		draw_string(ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color("e4ddc8"))


class ReleaseBoard:
	extends Node2D
	var catalog := AbilityCatalog.new()
	var language := VisualLanguage.new()
	var current := HexCourtPresenter.new()
	var old := HexCourtPresenter.new()
	var reduced := false
	func configure() -> bool:
		if not catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json") or not language.load_from_file() or not current.configure(language) or not old.configure(language): return false
		# Only the isolated comparison's release art is unavailable, reaching the
		# exact preserved old-cross fallback. Production shared library is intact.
		old._cast_release.library = Library.new()
		return true
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color("18231f"))
		_text(Vector2(20,28),"H.E.X. / RELEASE SHAPES / %s / synthetic age4 helper comparison" % ("REDUCED" if reduced else "NORMAL"),18)
		_text(Vector2(20,51),"Each cell: previous cross on left, elemental release on right. Native75% scale. This comparison board is not paid gameplay.",13)
		for column: int in FAMILIES.size(): _text(Vector2(160 + column * 300,81),String(FAMILIES[column]).to_upper(),13)
		for row: int in Library.ELEMENTS.size():
			var element: String = Library.ELEMENTS[row]
			var y := 113 + row * 70
			draw_rect(Rect2(78,y-16,1188,62),Color("827153") if row % 2 else Color("263c32"))
			_text(Vector2(8,y+17),element.to_upper(),11)
			for column: int in FAMILIES.size():
				var wire := int(catalog.ability(catalog.spell_id_at(element,FAMILIES[column])).wire_id)
				var cue := {"kind":"pixel_release","source_wire_id":wire,"position":Vector2.ZERO,"age_ticks":4,"duration":0.20,"remaining":0.20-4.0/120.0}
				draw_set_transform(Vector2(150+column*300,y+12),0,Vector2.ONE*0.75)
				old.draw_cue(self,cue,reduced)
				draw_set_transform(Vector2(235+column*300,y+12),0,Vector2.ONE*0.75)
				current.draw_cue(self,cue,reduced)
				draw_set_transform(Vector2.ZERO)
		_text(Vector2(20,705),"Atlas sources unchanged. One finite stationary hand stamp; no extra hitbox, damage area, trail, timer or particle emitter.",12)
	func _text(at: Vector2, value: String, size: int) -> void:
		draw_string(ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color("e4ddc8"))
