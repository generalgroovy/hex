extends SceneTree
## Native production draw queries; fixed authority fixtures, not physical play.

const Aerial = preload("res://src/presentation/pixel_aerial_pose.gd")

const SOURCE_PATHS := ["res://src/presentation/pixel_aerial_pose.gd", "res://src/presentation/pixel_flipbook_presenter.gd", "res://src/presentation/fullbody_cast_presenter.gd", "res://src/presentation/cartoon_champion_presenter.gd", "res://src/presentation/actor_motion_history.gd", "res://src/presentation/jump_presentation.gd", "res://src/sim/movement/movement_system.gd", "res://src/sim/movement/movement_tuning.gd", "res://content/champions/foundation_champions_v1.json", "res://assets/sprites/pixel_cast_v1/manifest.json", "res://assets/sprites/pixel_actions_v1/manifest.json", "res://tests/visual/capture_aerial_readability.gd", "res://src/presentation/pixel_magic_library.gd", "res://src/presentation/pixel_movement_effects.gd", "res://art_batches/pixel_v1/magic/manifest.json", "res://src/presentation/wellspring_illustrated_kit.gd", "res://content/visual/wellspring_illustrated_v1.json", "res://assets/environment/wellspring_v3/surfaces.png"]
const JUMP_ROWS := ["ground", "gather", "first rise", "first turn", "second rise", "second turn", "second fall"]
const STATUS_ROWS := ["flight last tick", "flight expired", "spawn shield", "roll opening", "roll protected", "roll expired", "air dodge opening", "air dodge protected", "air dodge expired"]
var output := ""

class Board:
	extends Node2D
	var presenter: CartoonChampionPresenter
	var catalog: ChampionCatalog
	var config := SimConfig.new(120)
	var records: Array[Dictionary] = []
	var fixtures: Array[Dictionary] = []
	var reduced := false
	var size := Vector2i(1120, 870)
	var title := ""
	var failed := false
	var surfaces: Texture2D

	func add(id: String, label: String, at: Vector2, facing: int, tick: float = 0.0, physical_phase: float = -1.0) -> void:
		var state := PlayerState.new(fixtures.size() + 1)
		if not catalog.apply_to_player(state, id): failed = true; return
		state.spawn_protection_ticks = 0
		state.aim_x = EightDirectionResolver.FIXED_VECTORS[facing].x
		state.aim_y = EightDirectionResolver.FIXED_VECTORS[facing].y
		state.facing_x = state.aim_x
		state.facing_y = state.aim_y
		var phase := physical_phase
		if phase < 0.0:
			phase = 12.0 if label.ends_with("turn") else (27.0 if label.ends_with("fall") else 0.0)
		if label not in ["ground", "gather", "spawn shield"] and not label.begins_with("roll"):
			state.hop_ticks = 40
			state.air_height = 24_000
			state.air_vertical_velocity = maxi(-MovementTuning.AIR_TERMINAL_FALL_SPEED, MovementTuning.JUMP_VERTICAL_SPEED - roundi(MovementTuning.VERTICAL_GRAVITY * phase / 60.0))
			state.movement_mode = PlayerState.MovementMode.HOP
			state.hop_mode = PlayerState.MovementMode.HOP
		if label == "gather": state.jumpsquat_active = true; state.jumpsquat_ticks = 18
		if label.begins_with("second"):
			state.hop_mode = PlayerState.MovementMode.DOUBLE_JUMP
			state.air_floating = state.flight_capable
			state.double_jump_used = not state.flight_capable
			state.float_ticks = maxi(1, config.milliseconds_to_ticks(state.float_max_duration_ms) - roundi(phase * config.tick_rate / 60.0)) if state.flight_capable else 0
			if state.flight_capable: state.air_vertical_velocity = 0
		if label.begins_with("flight"):
			state.hop_mode = PlayerState.MovementMode.DOUBLE_JUMP
			state.air_floating = state.flight_capable
			state.float_ticks = 1 if label == "flight last tick" and state.flight_capable else 0
			state.air_vertical_velocity = 0
		if label == "spawn shield": state.spawn_protection_ticks = 1
		if label.begins_with("roll") or label.begins_with("air dodge"):
			var rolling := label.begins_with("roll")
			state.hop_mode = PlayerState.MovementMode.ROLL if rolling else PlayerState.MovementMode.AIR_DODGE
			state.movement_mode = state.hop_mode
			var duration := MovementTuning.ROLL_DURATION_MS if rolling else MovementTuning.AIR_DODGE_DURATION_MS
			var protected_ms := MovementTuning.ROLL_INVULNERABILITY_MS if rolling else MovementTuning.AIR_DODGE_INVULNERABILITY_MS
			state.air_dodge_ticks = config.milliseconds_to_ticks(duration) if label.ends_with("opening") else config.milliseconds_to_ticks(duration) - config.milliseconds_to_ticks(protected_ms) + (1 if label.ends_with("protected") else 0)
		var authority := JSON.stringify(state.canonical_values()).sha256_text()
		var frame := presenter.movement_frame(id, state, tick, config, reduced)
		var contract := CartoonChampionPresenter.protection_contract(state, config, reduced, float(frame.get("display_height", 68)))
		fixtures.append({"id": id, "label": label, "at": at, "state": state, "tick": tick, "hash": authority, "reduced": reduced})
		records.append({"id": id, "label": label, "facing": facing, "presentation_tick": tick, "action": frame.get("action"), "pose": frame.get("aerial_pose", "atlas"), "pose_key": frame.get("pose_key", -1), "physical_pose_ticks": Aerial.pose_ticks(state, config), "second_jump_tuck": frame.get("second_jump_tuck", false), "air_vertical_velocity": state.air_vertical_velocity, "float_ticks": state.float_ticks, "protection_kind": contract.kind, "body_alpha": (contract.body_tint as Color).a, "budget_pips": int(contract.budget_pips), "authority_before": authority, "reduced_motion": reduced, "face_region": str(frame.get("source_region", Rect2()))})

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(size)), Color("34443e"))
		draw_string(ThemeDB.fallback_font, Vector2(10,22), title, HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("f3dda9"))
		draw_string(ThemeDB.fallback_font, Vector2(10,41), "Native 1x pixels | arranged physical-phase fields | unchanged authority during draw | no input or balance acceptance", HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("c3ccbc"))
		for fixture: Dictionary in fixtures:
			var at: Vector2 = fixture.at
			if surfaces != null and fixture.has("terrain_tile"):
				var tile := int(fixture.terrain_tile)
				# Exact admitted128px swatches, as WellspringIllustratedKit.tiles;
				# this board deliberately does not compose or claim the whole map.
				draw_texture_rect_region(surfaces, Rect2(at+Vector2(-64,-104),Vector2(128,128)), Rect2(Vector2((tile%4)*128,(tile/4)*128),Vector2(128,128)))
			draw_line(at+Vector2(-43,2), at+Vector2(43,2), Color(0.8,0.85,0.75,0.3))
			if not presenter.draw(self, fixture.state, fixture.id, at, fixture.tick, config, bool(fixture.reduced), at, 0.0): failed = true
			if JSON.stringify(fixture.state.canonical_values()).sha256_text() != fixture.hash: failed = true
			var name_y := 40 if fixture.has("terrain_tile") else 19
			var state_y := 54 if fixture.has("terrain_tile") else 33
			draw_string(ThemeDB.fallback_font, at+Vector2(-64,name_y), String(fixture.id).replace("_"," ").left(20), HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("f3dda9"))
			draw_string(ThemeDB.fallback_font, at+Vector2(-64,state_y), fixture.label, HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("c3ccbc"))


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/aerial-native-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("Provide native rendering and fresh --output=res://.godot/aerial-native-NAME"); return
	if DirAccess.make_dir_recursive_absolute(output) != OK: _fail("Cannot create capture directory"); return
	var hashes := {}
	for path: String in SOURCE_PATHS:
		hashes[path] = FileAccess.get_sha256(path)
		if String(hashes[path]).length() != 64: _fail("Missing source " + path); return
	var abilities := AbilityCatalog.new()
	var catalog := ChampionCatalog.new()
	var language := VisualLanguage.new()
	var presenter := CartoonChampionPresenter.new()
	if not abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json") or not catalog.load_from_file("res://content/champions/foundation_champions_v1.json", abilities) or not language.load_from_file() or not presenter.configure(language, CartoonChampionPresenter.DEFAULT_PATH, CartoonChampionPresenter.DEFAULT_OVERRIDE_PATH, false) or not presenter.enable_fullbody_art(true, true):
		_fail("Production presenter configuration failed: " + presenter.last_error); return
	for id: String in catalog.ordered_champion_ids():
		for folder: String in ["pixel_cast_v1", "pixel_actions_v1"]:
			var path := "res://assets/sprites/" + folder + "/" + id + ".png"
			hashes[path] = FileAccess.get_sha256(path)
	root.visible = true
	root.mode = Window.MODE_MINIMIZED
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	board.presenter = presenter
	board.catalog = catalog
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(board)
	var selected: Array[String] = ["s_wayne", "oh_tipi", "red_baron"]
	for race: String in ["sylph", "wyrmborn", "angel", "demon"]:
		for id: String in catalog.ordered_champion_ids():
			if String(catalog.champions_by_id[id].ancestry) == race:
				selected.append(id); break
	var images: Array[Dictionary] = []
	for reduced: bool in [false, true]:
		board.reduced = reduced
		for group: String in ["jumps", "status", "roster"]:
			board.fixtures.clear(); board.records.clear()
			board.title = "Aerial / " + group + " / reduced=" + str(reduced)
			if group == "roster":
				board.size = Vector2i(1120, 780)
				var ids := catalog.ordered_champion_ids()
				for i: int in ids.size(): board.add(ids[i], "second rise", Vector2(80+(i%7)*160,145+(i/7)*145), i%8)
			else:
				var rows: Array = JUMP_ROWS if group == "jumps" else STATUS_ROWS
				board.size = Vector2i(1120, 65 + rows.size()*116)
				for row: int in rows.size():
					for column: int in selected.size(): board.add(selected[column], rows[row], Vector2(80+column*160,140+row*116), column%8, row*10)
			viewport.size = board.size
			var leaf := "%s-reduced-%d.png" % [group, int(reduced)]
			if not await _capture(viewport, board, leaf, images): return
	# Thirteen samples over one second: enough for the entire800ms native
	# wing cycle. Actual remaining-flight fields progress between fixtures;
	# non-flier physical velocity reaches terminal descent and then holds.
	# These arranged states are not a simulated or input-driven trajectory.
	board.reduced = false
	board.size = Vector2i(1120, 220)
	viewport.size = board.size
	for sample: int in 13:
		board.fixtures.clear(); board.records.clear()
		board.title = "Native phase sample %d / 12 Hz / timer and velocity fields progress" % sample
		for column: int in selected.size(): board.add(selected[column], "second rise", Vector2(80+column*160,160), column%8, 9000.0, sample*5.0)
		if not await _capture(viewport, board, "sequence-%02d.png" % sample, images): return
	# Actual admitted terrain swatches at native and normal75%gameplay zoom;
	# both reduced profiles share each board for direct protection comparison.
	board.surfaces = _admitted_surfaces()
	if board.surfaces == null: _fail("Terrain swatches fail the production manifest pixel contract"); return
	board.size = Vector2i(1120, 920)
	var terrain_ids: Array[String] = ["s_wayne", "oh_tipi", "red_baron", "luuh_i_zeh"]
	var terrain_rows: Array[String] = ["spawn shield", "roll protected", "roll expired", "air dodge protected", "air dodge expired"]
	for zoom: float in [1.0, 0.75]:
		board.fixtures.clear(); board.records.clear()
		board.title = "Protection / actual terrain swatches / zoom %.2f / normal left / reduced right" % zoom
		for row: int in terrain_rows.size():
			for mode: int in 2:
				board.reduced = mode == 1
				for column: int in terrain_ids.size():
					board.add(terrain_ids[column], terrain_rows[row], Vector2(70+mode*560+column*140,150+row*174), column%8, 9000.0)
					var tile: int = [0,2,6][(row+column)%3]
					board.fixtures[-1]["terrain_tile"] = tile
					board.records[-1]["terrain_tile"] = tile
					board.records[-1]["render_zoom"] = zoom
		viewport.size = Vector2i(Vector2(board.size)*zoom)
		viewport.canvas_transform = Transform2D.IDENTITY.scaled(Vector2.ONE*zoom)
		if not await _capture(viewport, board, "protection-terrain-%d.png" % roundi(zoom*100.0), images): return
	viewport.canvas_transform = Transform2D.IDENTITY
	for path: String in hashes:
		if FileAccess.get_sha256(path) != hashes[path]: _fail("Source changed during capture " + path); return
	var receipt := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if receipt == null: _fail("Receipt cannot be written"); return
	receipt.store_string(JSON.stringify({"status":"captured", "images":images, "source_hashes":hashes, "sequence_fps":12, "sequence_seconds":1.0, "sequence_clock":"constant rendering tick9000; authoritative timer/velocity fixtures progress", "authority_unchanged":true, "scope":"production Cartoon/Fullbody draw, all30 identities,3body sizes,4flying races,8directions,normal/reduced,same-facing first/double jump,immediate protection boundaries,full native wing cycle,actual admitted terrain swatches at1x and0.75x", "limitations":"Visual fixtures are not physical input, complete simulation playback, networking, performance, balance, or human acceptance. Inspect every native image and face crop."},"\t")+"\n")
	receipt.close()
	print("PASS aerial native capture: ", images.size(), " images; authority unchanged; visual review required")
	quit(0)


func _admitted_surfaces() -> Texture2D:
	# Match the texture admission at WellspringIllustratedKit.configure lines70–88
	# without invoking its unrelated whole-campus terrain/building composition.
	var definition: Variant = JSON.parse_string(FileAccess.get_file_as_string(WellspringIllustratedKit.PATH))
	if not definition is Dictionary: return null
	var texture := load(String(definition.get("surfaces", ""))) as Texture2D
	if texture == null or texture.get_size() != Vector2(512,512): return null
	var pixels := texture.get_image()
	pixels.convert(Image.FORMAT_RGBA8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(pixels.get_data())
	if hash.finish().hex_encode() != String(definition.get("surfaces_rgba_sha256", "")): return null
	return texture


func _capture(viewport: SubViewport, board: Board, leaf: String, images: Array[Dictionary]) -> bool:
	board.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	if board.failed: _fail("Production draw or authority check failed"); return false
	var image := viewport.get_texture().get_image()
	if image == null or image.save_png(output.path_join(leaf)) != OK: _fail("Native image failed " + leaf); return false
	images.append({"path":leaf,"width":image.get_width(),"height":image.get_height(),"sha256":FileAccess.get_sha256(output.path_join(leaf)),"records":board.records.duplicate(true)})
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
