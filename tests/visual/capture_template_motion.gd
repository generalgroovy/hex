extends SceneTree

const Harness = preload("res://tests/support/chemistry_coach_harness.gd")
const IDS := ["s_wayne", "oh_tipi", "red_baron"]
const ACTIONS := ["idle", "walk", "sprint", "slide", "jump", "float", "air_dodge", "wallrun", "walljump", "landing", "casting"]
var output := ""
var viewport: SubViewport
var game: Node2D
var records: Array[Dictionary] = []

class Board:
	extends Node2D
	var presenter: CartoonChampionPresenter
	var config: SimConfig
	var champion := ""
	var actors: Array[PlayerState] = []
	var labels: Array[String] = []
	var phase := 0.0
	var title := ""
	var failures := 0
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 1152), Color("182420"))
		draw_string(ThemeDB.fallback_font, Vector2(20, 25), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("ead9b6"))
		draw_string(ThemeDB.fallback_font, Vector2(20, 48), "Controlled production body at 75% camera scale; no input sequence or human acceptance implied", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("b2bfaf"))
		for index: int in actors.size():
			var row := index / 8
			var column := index % 8
			var anchor := Vector2(178 + column * 147, 144 + row * 94)
			if column == 0:
				draw_string(ThemeDB.fallback_font, Vector2(8, anchor.y - 18), labels[row], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ead9b6"))
			if row == 0:
				draw_string(ThemeDB.fallback_font, Vector2(anchor.x - 27, 73), EightDirectionResolver.DIRECTION_ORDER[column], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("b2bfaf"))
			draw_line(anchor + Vector2(-32, 1), anchor + Vector2(32, 1), Color("34493a"))
			draw_set_transform(anchor, 0.0, Vector2(0.75, 0.75))
			if not presenter.draw(self, actors[index], champion, Vector2.ZERO, phase * 120, config, true, Vector2.ZERO, phase):
				failures += 1
			draw_set_transform(Vector2.ZERO)

func _initialize() -> void:
	root.hide()
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/template-motion-") or ".." in output or DirAccess.dir_exists_absolute(output):
		fail("New contained output required")
		return
	game = Harness.new()
	if not game.configure_fixture(true):
		fail("Production fixture failed")
		return
	game.player_preferences.set_camera_zoom_percent(75)
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		fail("Cannot create output")
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 1152)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(game)
	game.hide()
	var board := Board.new()
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	board.presenter = game.cartoon_champion_presenter
	board.config = game.world.config
	viewport.add_child(board)
	for champion: String in IDS:
		board.champion = champion
		for kind: String in ["actions", "walk", "sprint"]:
			board.actors.clear()
			board.labels.clear()
			var rows := ACTIONS.size() if kind == "actions" else 8
			for row: int in rows:
				var action: String = ACTIONS[row] if kind == "actions" else kind
				board.labels.append(action if kind == "actions" else "travel " + EightDirectionResolver.DIRECTION_ORDER[row])
				for aim: int in 8:
					board.actors.append(make_actor(champion, action, aim, 2 if kind == "actions" else row))
			for phase: int in 8:
				board.phase = phase / 8.0
				board.title = "%s / %s / phase %d of 8" % [champion, kind, phase + 1]
				var before := board_values(board)
				board.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				if before != board_values(board) or board.failures:
					fail("Board draw mutated authority or failed")
					return
				if not save_view("%s-%s-%02d" % [champion, kind, phase], {"kind": "controlled_production_presenter", "champion": champion, "group": kind, "phase": phase, "actors": before}):
					return
	board.queue_free()
	await process_frame
	viewport.size = Vector2i(1280, 720)
	game.show()
	for champion: String in IDS:
		game.champion_catalog.apply_to_player(game.world.player(), champion)
		game.selected_champion_id = champion
		for aim_index: int in 8:
			var actor: PlayerState = game.world.player()
			actor.reset_for_spawn(game.fixture_anchor + Vector2i(-100000, -100000))
			actor.spawn_protection_ticks = 0
			game.actor_motion_history.clear()
			var aim := EightDirectionResolver.FIXED_VECTORS[aim_index]
			for tick: int in 24:
				if not step(aim, SimCommand.HELD_SPRINT): return
			var stamina_before := actor.stamina
			if not step(aim, SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE): return
			if actor.movement_mode != PlayerState.MovementMode.SLIDE or actor.stamina >= stamina_before:
				fail("Slide must be admitted and paid through normal input")
				return
			for tick: int in 24:
				if not step(aim, SimCommand.HELD_SLIDE): return
				if tick in [0, 7, 15]:
					if actor.movement_mode != PlayerState.MovementMode.SLIDE:
						fail("Actual slide ended before sampled phase")
						return
					var before_hash: String = game.world.state_hash()
					game.queue_redraw()
					await process_frame
					await RenderingServer.frame_post_draw
					if before_hash != game.world.state_hash():
						fail("Gameplay draw mutated world")
						return
					if not save_view("%s-slide-aim-%d-tick-%02d" % [champion, aim_index, tick], {"kind": "actual_paid_slide", "champion": champion, "aim": aim_index, "slide_tick": tick, "world_hash": before_hash, "state": actor.canonical_values(), "stamina_before": stamina_before, "stamina_now": actor.stamina}): return
	var file := FileAccess.open(output.path_join("capture-receipt.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 1, "frames": records, "camera_percent": 75, "draw_authority_unchanged": true, "network": "not_started", "audio": "not_started", "profiles": "transient_only", "human_acceptance": "pending", "limitation": "Action boards are held synthetic states; live input coverage is paid slide. Wallrun uses WALL_SKIM, Float uses air_floating, landing uses landing_ticks. No distinct phase art is implied."}, "  "))
	file.close()
	print("PASS: ", records.size(), " rendered template frames; controlled all-direction bodies and actual paid slides")
	quit(0)

func make_actor(champion: String, action: String, aim: int, travel: int) -> PlayerState:
	var actor := PlayerState.new(1)
	game.champion_catalog.apply_to_player(actor, champion)
	actor.spawn_protection_ticks = 0
	var look := EightDirectionResolver.FIXED_VECTORS[aim]
	var direction := EightDirectionResolver.FIXED_VECTORS[travel]
	actor.aim_x = look.x
	actor.aim_y = look.y
	actor.velocity_x = direction.x * 300
	actor.velocity_y = direction.y * 300
	actor.movement_mode = PlayerState.MovementMode.WALK
	match action:
		"idle", "casting", "landing":
			actor.velocity_x = 0
			actor.velocity_y = 0
			actor.movement_mode = PlayerState.MovementMode.IDLE
		"sprint": actor.movement_mode = PlayerState.MovementMode.SPRINT
		"slide":
			actor.movement_mode = PlayerState.MovementMode.SLIDE
			actor.slide_ticks = 12
		"jump", "float", "air_dodge", "wallrun", "walljump":
			actor.air_height = 20000
			actor.movement_mode = PlayerState.MovementMode.HOP
			if action == "float": actor.air_floating = true
			if action == "air_dodge": actor.movement_mode = PlayerState.MovementMode.AIR_DODGE
			if action == "walljump": actor.movement_mode = PlayerState.MovementMode.WALL_KICK
			if action == "wallrun":
				actor.movement_mode = PlayerState.MovementMode.WALL_SKIM
				actor.wall_skim_ticks = 12
	if action == "casting":
		actor.pending_cast_wire_id = actor.primary_wire_id
		actor.pending_cast_ticks = 4
	if action == "landing":
		actor.landing_ticks = 4
		actor.landing_intensity = 1000
	return actor

func step(aim: Vector2i, held: int, pressed: int = 0) -> bool:
	var actor: PlayerState = game.world.player()
	var commands: Array[SimCommand] = [SimCommand.new(game.world.tick, actor.entity_id, 1000, 0, held, pressed, aim.x, aim.y)]
	if not game.world.step(commands):
		fail("Paid gameplay step failed")
		return false
	game.current_position = Vector2(actor.position_x, actor.position_y) / 1000.0
	game.previous_position = game.current_position
	game.previous_air_height = actor.air_height
	game.actor_motion_history.capture(game.world.players)
	game._update_character_gaits(1.0 / 120.0)
	return true

func save_view(label: String, metadata: Dictionary) -> bool:
	var pixels := viewport.get_texture().get_image()
	if pixels == null or pixels.save_png(output.path_join(label + ".png")) != OK:
		fail("PNG write failed")
		return false
	metadata["file"] = label + ".png"
	records.append(metadata)
	return true

static func board_values(board: Board) -> Array:
	var values: Array = []
	for actor: PlayerState in board.actors: values.append(actor.canonical_values())
	return values

func fail(message: String) -> void:
	push_error(message)
	quit(1)
