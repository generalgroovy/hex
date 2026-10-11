extends "res://tests/visual/capture_gamefeel_gallery.gd"
## Root-only native capture: fixed-scale comparisons, not an animation test.

const IdentityArt = preload("res://src/presentation/fullbody_cast_presenter.gd")
const SHEET_SIZE := Vector2i(1280, 1080)
const GROUPS := ["small", "middle", "large"]
const HEADINGS := [0, 2] # South and East: face, silhouette and profile comparison.
const POSES := ["idle", "walk", "cast", "slide", "jump"]
const POSE_LABELS := ["Idle", "Walk contact A", "Standing cast", "Low / slide reuse", "Air / held rise"]
const IDENTITY_SOURCES := [
	"res://tests/visual/capture_cast_identity_checkpoint.gd",
	"res://tests/visual/capture_gamefeel_gallery.gd",
	"res://tests/visual/capture_glow_flow.gd",
	"res://src/app/bootstrap.gd",
	"res://src/app/character_selection_model.gd",
	"res://src/presentation/character_selection_grid.gd",
	"res://src/presentation/champion_portrait_library.gd",
	"res://src/presentation/fullbody_cast_presenter.gd",
	"res://src/presentation/pixel_flipbook_presenter.gd",
	"res://src/presentation/pixel_action_bank.gd",
	"res://content/champions/foundation_champions_v1.json",
	"res://content/champions/champion_roster_plan_v1.json",
	"res://content/runtime/runtime_build_identity_v1.json",
	"res://assets/sprites/pixel_cast_v1/manifest.json",
	"res://assets/sprites/pixel_actions_v1/manifest.json",
	"res://assets/portraits/champions_v1/manifest.json",
]

var identity_board: IdentityBoard
var identity_roster: Array[Dictionary] = []
var portrait_ids: Array[String] = []
var alpha_images: Dictionary = {}
var image_bytes := 0
var authority_before := ""
var equipped_before := ""


class IdentityBoard:
	extends Node2D
	var samples: Array[Dictionary] = []
	var title := ""
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 1080)), Color("26382f"))
		draw_string(ThemeDB.fallback_font, Vector2(20, 30), title, HORIZONTAL_ALIGNMENT_LEFT, 1240, 22, Color("f3dfac"))
		draw_string(ThemeDB.fallback_font, Vector2(20, 54), "Native 1x pixels; shared floor/pivot. Dotted line = declared idle height, not a skull or anatomy measurement.", HORIZONTAL_ALIGNMENT_LEFT, 1240, 14, Color("c7d5c5"))
		for column: int in 5:
			draw_string(ThemeDB.fallback_font, Vector2(244 + column * 200, 89), POSE_LABELS[column], HORIZONTAL_ALIGNMENT_LEFT, 180, 14, Color("f3dfac"))
		for sample: Dictionary in samples:
			var anchor: Vector2 = sample.anchor
			var height: float = sample.display_height
			draw_line(anchor + Vector2(-60, 0), anchor + Vector2(60, 0), Color("9aaa90"), 1.0)
			draw_line(anchor + Vector2(0, -4), anchor + Vector2(0, 5), Color("cfad62"), 1.0)
			for guide_x: int in range(-60, 60, 8):
				draw_line(anchor + Vector2(guide_x, -height), anchor + Vector2(guide_x + 3, -height), Color("596a58"), 1.0)
			IdentityArt.draw_frame(self, sample.frame, anchor)
			if int(sample.column) == 0:
				draw_string(ThemeDB.fallback_font, Vector2(20, anchor.y - 20), String(sample.name), HORIZONTAL_ALIGNMENT_LEFT, 205, 16, Color("f3dfac"))
				draw_string(ThemeDB.fallback_font, Vector2(20, anchor.y), String(sample.id), HORIZONTAL_ALIGNMENT_LEFT, 205, 11, Color("c7d5c5"))
				draw_string(ThemeDB.fallback_font, Vector2(20, anchor.y + 15), "%dpx declared idle height" % height, HORIZONTAL_ALIGNMENT_LEFT, 205, 11, Color("9aaa90"))
		draw_string(ThemeDB.fallback_font, Vector2(20, 1046), "Controlled presenter states; no world lift or per-pose fitting. Low/air keys are not complete action cycles.", HORIZONTAL_ALIGNMENT_LEFT, 1240, 14, Color("c7d5c5"))
		draw_string(ThemeDB.fallback_font, Vector2(20, 1067), "Compare head/body shape visually; alpha bounds include horns, foliage, wings, tails and clothing. Human style/motion acceptance remains open.", HORIZONTAL_ALIGNMENT_LEFT, 1240, 12, Color("c7d5c5"))


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--gallery-ids="):
			for id: String in argument.trim_prefix("--gallery-ids=").split(",", false):
				if id in portrait_ids:
					_fail("Portrait inspection IDs must be unique")
					return
				portrait_ids.append(id)
	var repo := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var roaming := OS.get_environment("APPDATA").replace("\\", "/")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/cast-identity-native-") \
			or ".." in output or DirAccess.dir_exists_absolute(output) or portrait_ids.size() > 6:
		_fail("Use native rendering, a fresh --output=res://.godot/cast-identity-native-NAME and at most six --gallery-ids")
		return
	if OS.get_name() == "Windows" and not roaming.to_lower().begins_with(repo.to_lower() + "/.godot/"):
		_fail("Root must isolate APPDATA inside this checkout's .godot")
		return
	if "--pixel-cast" not in OS.get_cmdline_user_args():
		_fail("Identity capture requires the production --pixel-cast route")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Cannot create fresh identity evidence directory")
		return
	for path: String in IDENTITY_SOURCES:
		source_hashes[path] = FileAccess.get_sha256(path)
	# Optional shared registration contract is captured when installed, without
	# creating a dependency on an unapproved implementation detail.
	var template_path := "res://src/presentation/pixel_body_template.gd"
	if FileAccess.file_exists(template_path):
		source_hashes[template_path] = FileAccess.get_sha256(template_path)
	root.visible = true
	root.mode = Window.MODE_MINIMIZED
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game = BootstrapScene.instantiate()
	game.set_process(false)
	viewport.add_child(game)
	game.set_process(false)
	game.set_process_unhandled_input(false)
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	game.application_input_active = true
	game.controls_input_guard_frames = 0
	if game.element_audio != null:
		game.element_audio.silence()
		game.element_audio.set_process(false)
		game.element_audio.volume_percent = 0
	await process_frame
	if game.world == null or game.character_selection_grid == null \
			or game.cartoon_champion_presenter.fullbody_art == null \
			or game.cartoon_champion_presenter.fullbody_art.pixel_pilot == null:
		_fail("Production pixel-cast Gallery did not initialize")
		return
	authority_before = game.world.state_hash()
	equipped_before = game._champion_visual_id(game._local_player_state())
	if not _prepare_roster(): return
	if not await _capture_identity_gallery(): return
	game.character_selection_grid.close_panel()
	game.hide()
	identity_board = IdentityBoard.new()
	identity_board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(identity_board)
	viewport.size = SHEET_SIZE
	for body: String in GROUPS:
		for heading: int in HEADINGS:
			if not await _capture_group(body, heading): return
	if game.world.state_hash() != authority_before:
		_fail("Identity inspection changed authoritative world state")
		return
	for path: String in source_hashes:
		if String(source_hashes[path]).length() != 64 or FileAccess.get_sha256(path) != source_hashes[path]:
			_fail("Source or artwork changed during identity capture: " + path)
			return
	var receipt := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if receipt == null:
		_fail("Cannot save identity receipt")
		return
	receipt.store_string(JSON.stringify({
		"status": "passed", "frames": frames, "roster": identity_roster, "sources": source_hashes,
		"runtime_identity": JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)),
		"authority_hash_before_and_after": authority_before, "equipped_id": equipped_before,
		"png_count": frames.size(), "png_bytes": image_bytes, "pose_count": 300,
		"display": {"server": DisplayServer.get_name(), "root_minimized": root.mode == Window.MODE_MINIMIZED,
			"sheet_size": [1280, 1080], "gallery_sizes": [[1280, 720], [960, 540]],
			"body_render_scale": 1, "image_resizing": false, "world_lift_applied": false},
		"method": "Six size-grouped South/East sheets, each with ten canonical identities and five controlled states from the production full-pixel presenter. Actual Gallery overview at two resolutions; optional read-only enlarged portraits at both resolutions. One fixed floor anchor per pose, no per-pose normalization or image editing. Descriptor alpha footprints are diagnostic, not anatomical measurements.",
		"limitations": "Controlled states are not paid action execution, a continuous animation, physical input, all-eight-heading coverage, gameplay-scale camera acceptance, completed authored cycles, or human style/proportion acceptance. No saved profile, weave or attunement changes. Root must inspect every PNG."
	}, "\t") + "\n")
	receipt.close()
	print("PASS cast identity native: ", frames.size(), " PNGs; 30 identities / 300 fixed-scale pose samples; human acceptance open")
	quit(0)


func _prepare_roster() -> bool:
	var grid: CharacterSelectionGrid = game.character_selection_grid
	if not _inspect(equipped_before, equipped_before): return false
	var cells := grid.model.display_cells()
	if cells.size() != 30 or game.champion_catalog.ordered_champion_ids().size() != 30:
		_fail("Identity checkpoint expects the exact current 30-character roster")
		return false
	var seen := {}
	for cell: Vector2i in cells:
		var entry: Dictionary = grid.model.characters(cell.x)[cell.y]
		var id := String(entry.id)
		if seen.has(id):
			_fail("Repeated identity in capture roster")
			return false
		seen[id] = true
		identity_roster.append({"id": id, "name": entry.display_name, "body": entry.body_type})
		for folder: String in ["pixel_cast_v1", "pixel_actions_v1"]:
			var path := "res://assets/sprites/%s/%s.png" % [folder, id]
			source_hashes[path] = FileAccess.get_sha256(path)
	for id: String in portrait_ids:
		if not seen.has(id):
			_fail("Unknown canonical portrait ID: " + id)
			return false
		var path := "res://assets/portraits/champions_v1/%s.png" % id
		source_hashes[path] = FileAccess.get_sha256(path)
	return true


func _capture_identity_gallery() -> bool:
	var grid: CharacterSelectionGrid = game.character_selection_grid
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		viewport.size = resolution
		if not _inspect(equipped_before, equipped_before) or not await _redraw(): return false
		if not _save_identity("all-30-gallery", "production-gallery", {"selected": equipped_before,
			"menu_scale": game._compendium_scale(), "portrait_expanded": false}): return false
		for id: String in portrait_ids:
			if not _inspect(id, equipped_before): return false
			var source := grid.hero_portrait_source(id)
			if not bool(source.get("detailed_portrait", false)):
				_fail("Requested Gallery portrait is unavailable: " + id)
				return false
			grid.toggle_portrait()
			if not grid.portrait_expanded or not await _redraw(): return false
			if grid.model.pending_wire != 0 or grid.model.equipped_id != equipped_before \
					or game.world.state_hash() != authority_before:
				_fail("Read-only portrait inspection changed equipped/request/authority state")
				return false
			if not _save_identity(id + "-portrait", "production-portrait", {"selected": id,
				"equipped": equipped_before, "read_only": true, "cache_ids": grid.portrait_library.cached_ids()}): return false
	return true


func _capture_group(body: String, heading: int) -> bool:
	var art: RefCounted = game.cartoon_champion_presenter.fullbody_art
	identity_board.samples.clear()
	identity_board.title = "H.E.X. cast identity / %s / %s / ten champions, five poses" % [body.capitalize(), IdentityArt.DIRS[heading]]
	var records: Array[Dictionary] = []
	var row := 0
	for entry: Dictionary in identity_roster:
		if String(entry.body) != body: continue
		alpha_images.clear() # Bound temporary decoded images to this identity's two banks.
		for column: int in POSES.size():
			var state := _identity_state(String(entry.id), POSES[column], heading)
			if state == null: return false
			var before := state.canonical_values()
			var frame: Dictionary = art.frame(String(entry.id), state, 0.0, game.world.config, 0.0)
			if frame.is_empty() or frame.get("visual_mode") != "pixel_cast" or frame.has("mesh") \
					or frame.has("render_mesh") or frame.get("action") != POSES[column] or state.canonical_values() != before:
				_fail("Identity pose lost fixed-pixel action or mutated its controlled state")
				return false
			var measured := _measure_descriptor(frame)
			if measured.is_empty(): return false
			var anchor := Vector2(310 + column * 200, 176 + row * 88)
			identity_board.samples.append({"id": entry.id, "name": entry.name, "column": column,
				"anchor": anchor, "frame": frame, "display_height": int(frame.display_height)})
			records.append({"id": entry.id, "name": entry.name, "body": body, "pose": POSES[column],
				"heading": IdentityArt.DIRS[heading], "anchor": [anchor.x, anchor.y],
				"frame_id": frame.get("frame_id", ""), "declared_display_height": frame.display_height,
				"pivot": [frame.pivot.x, frame.pivot.y], "descriptor": measured,
				"reused_pose": frame.get("rigid_pose_fallback", false), "source_pose": frame.get("source_pose", ""),
				"independent_cast_pose": frame.get("independent_cast_pose", false)})
		row += 1
	alpha_images.clear()
	if row != 10 or records.size() != 50:
		_fail("Every size group must contain ten identities and fifty poses")
		return false
	identity_board.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	return _save_identity(body + "-" + IdentityArt.DIRS[heading].to_lower() + "-five-poses", "controlled-fixed-scale-sheet",
		{"body": body, "heading": IdentityArt.DIRS[heading], "poses": records})


func _identity_state(id: String, pose: String, heading: int) -> PlayerState:
	var state := PlayerState.new(9601)
	if not game.champion_catalog.apply_to_player(state, id):
		_fail("Cannot apply canonical identity to isolated pose state: " + id)
		return null
	var look: Vector2i = EightDirectionResolver.FIXED_VECTORS[heading]
	state.aim_x = look.x; state.aim_y = look.y
	state.facing_x = look.x; state.facing_y = look.y
	state.movement_mode = PlayerState.MovementMode.WALK
	match pose:
		"walk":
			state.velocity_x = look.x * 200; state.velocity_y = look.y * 200
		"cast":
			state.control_state = PlayerState.ControlState.CHARGING
			state.pending_cast_wire_id = 140 # Actual Rillshot definition; fixture only, no cast paid/executed.
			state.pending_cast_ticks = 0
		"slide":
			state.movement_mode = PlayerState.MovementMode.SLIDE
			state.velocity_x = look.x * 200; state.velocity_y = look.y * 200
			state.slide_x = look.x; state.slide_y = look.y; state.slide_ticks = 12
		"jump":
			state.movement_mode = PlayerState.MovementMode.HOP
			state.hop_mode = PlayerState.MovementMode.HOP; state.hop_ticks = 12
			state.air_height = 24000; state.air_vertical_velocity = 30000
	return state


func _measure_descriptor(frame: Dictionary) -> Dictionary:
	var bounds := Rect2()
	var has_ink := false
	var components: Array[Dictionary] = []
	for component: Dictionary in frame.get("components", []):
		var texture: Texture2D = component.texture
		var source: Rect2 = component.source_region
		var destination: Rect2 = component.destination_region
		if source.size != destination.size or source != Rect2(Rect2i(source)) or destination != Rect2(Rect2i(destination)):
			_fail("Fixed-scale identity fixture rejects resampled or fractional body components")
			return {}
		var cache_key := texture.get_instance_id()
		if not alpha_images.has(cache_key):
			var pixels := texture.get_image()
			if pixels == null or (pixels.is_compressed() and pixels.decompress() != OK):
				_fail("Cannot inspect admitted atlas alpha bounds")
				return {}
			alpha_images[cache_key] = pixels
		var image: Image = alpha_images[cache_key]
		var ink := image.get_region(Rect2i(source)).get_used_rect()
		if ink.has_area():
			var local := Rect2(destination.position + Vector2(ink.position), Vector2(ink.size))
			bounds = bounds.merge(local) if has_ink else local
			has_ink = true
		components.append({"texture_path": texture.resource_path, "source": _rectangle_values(source),
			"destination": _rectangle_values(destination), "source_alpha_bounds": _rectangle_values(Rect2(ink))})
	if not has_ink:
		_fail("A required identity pose contains no visible pixels")
		return {}
	return {"components": components, "cell_alpha_bounds": _rectangle_values(bounds),
		"ink_bottom_relative_to_pivot": bounds.end.y - float(frame.pivot.y),
		"measurement_scope": "Alpha silhouette only, including appendages; not skull, torso or limb landmarks."}


func _rectangle_values(rectangle: Rect2) -> Array:
	return [rectangle.position.x, rectangle.position.y, rectangle.size.x, rectangle.size.y]


func _save_identity(label: String, kind: String, details: Dictionary) -> bool:
	var size := viewport.size
	var leaf := "%s-%dx%d.png" % [label, size.x, size.y]
	var path := output.path_join(leaf)
	var pixels := viewport.get_texture().get_image()
	if frames.size() >= 20 or pixels == null or pixels.get_size() != size or pixels.save_png(path) != OK:
		_fail("Bounded native identity capture failed: " + leaf)
		return false
	var saved := FileAccess.open(path, FileAccess.READ)
	if saved == null:
		_fail("Cannot verify native image length")
		return false
	image_bytes += saved.get_length()
	saved.close()
	if image_bytes > 40 * 1024 * 1024:
		_fail("Identity capture exceeded its 40 MiB image budget")
		return false
	frames.append({"file": leaf, "sha256": FileAccess.get_sha256(path), "width": size.x, "height": size.y,
		"kind": kind, "details": details})
	return true
