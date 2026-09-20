extends SceneTree

# Standalone: godot --headless --path <project> --script <this-file> -- --require-png
# With no PNGs, pure contract tests still run. Once any PNG exists all three are
# required automatically. --require-png also refuses a wholly missing atlas set.
const Body = preload("neutral_body_sprite.gd")
var assertions := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sprite := Body.new()
	_check(sprite.centered == false and sprite.offset == Vector2(-48, -84), "exact shared feet pivot")
	_check(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "nearest pixels")
	_check(sprite.scale == Vector2.ONE and sprite.rotation == 0.0, "no body rescale or rotation")
	for size_index: int in range(3):
		_check(sprite.set_body_type(size_index), "body accepted")
		for action: String in Body.ACTION_POSES:
			for facing: int in range(8):
				_check(sprite.set_state(action, facing), "active action/direction accepted")
				var frame: Dictionary = sprite.frame_model()
				_check(frame.region == Rect2(facing * 96, Body.POSES.find(Body.ACTION_POSES[action]) * 96, 96, 96), "exact action cell")
				_check(frame.pivot == Vector2i(48, 84) and not frame.gallery_only, "active body contract")
		for action: String in ["walk", "sprint"]:
			sprite.set_state("idle", 0)
			sprite.set_state(action, 0)
			var cycle: int = sprite.frame_model().cycle_ticks_at_60
			_check(cycle == (Body.WALK_CYCLES[size_index] if action == "walk" else Body.SPRINT_CYCLES[size_index]), "size cadence")
			_check(sprite.frame_model().contact_frame == 0, "first contact")
			sprite.advance_animation(float(cycle) / 120.0)
			_check(sprite.frame_model().contact_frame == 1, "half-cycle second contact")
			sprite.set_state(action, 7)
			_check(sprite.frame_model().contact_frame == 1, "direction change preserves phase")
			sprite.playing = false
			sprite.advance_animation(3.0)
			_check(sprite.frame_model().contact_frame == 1, "pause preserves phase")
			sprite.playing = true
			sprite.advance_animation(float(cycle) / 120.0)
			_check(sprite.frame_model().contact_frame == 0, "loop wrap")
		for action: String in ["float", "jump", "cast", "hit", "wallrun", "roll", "defeated"]:
			sprite.set_state(action, 3)
			var before: Dictionary = sprite.frame_model()
			sprite.advance_animation(1000.0)
			_check(sprite.frame_model() == before, "one-pose action is held, not invented animation")
	for alias: String in Body.SEMANTIC_ALIASES:
		_check(sprite.set_state(alias, 2), "compatibility name accepted")
		_check(sprite.action_semantic == Body.SEMANTIC_ALIASES[alias], "alias exposes current action name")
	for action: String in Body.GALLERY_POSES:
		_check(not sprite.set_state(action, 0), "gallery cannot impersonate gameplay")
		_check(sprite.set_gallery_state(action, 0), "explicit gallery action accepted")
		_check(sprite.frame_model().gallery_only, "gallery metadata remains explicit")
	sprite.set_state("float", 4)
	var retained: Dictionary = sprite.frame_model()
	for action: String in ["vault", "superglide", "missing", "", "FLOAT"]:
		_check(not sprite.set_state(action, 0), "unknown/inactive action refused")
		_check(sprite.frame_model() == retained, "refusal leaves frame unchanged")
	for direction_index: int in [-1, 8, 99]:
		_check(not sprite.set_state("walk", direction_index), "invalid direction refused")
		_check(sprite.frame_model() == retained, "direction refusal atomic")
	for size_index: int in [-1, 3, 99]:
		_check(not sprite.set_body_type(size_index), "invalid body refused")
		_check(sprite.frame_model() == retained, "body refusal atomic")
	for delta: float in [-1.0, INF, NAN]:
		_check(not sprite.advance_animation(delta), "invalid clock refused")
	_check(sprite.position == Vector2.ZERO and sprite.scale == Vector2.ONE and sprite.rotation == 0.0, "animation never owns transforms")
	var source_dir: String = get_script().resource_path.get_base_dir()
	var scene := load(source_dir.path_join("neutral_body_sprite.tscn")) as PackedScene
	_check(scene != null, "portable scene loads with relative script")
	if scene != null:
		var instance := scene.instantiate()
		_check(instance is Sprite2D and instance.get_script() == Body, "scene uses standalone body component")
		instance.free()
	var require_png := "--require-png" in OS.get_cmdline_user_args()
	for size_index: int in range(3):
		require_png = require_png or FileAccess.file_exists(sprite.texture_path(size_index)) or ResourceLoader.exists(sprite.texture_path(size_index), "Texture2D")
	if require_png:
		for size_index: int in range(3):
			sprite.set_body_type(size_index)
			var loaded: bool = sprite.load_body_texture()
			_check(loaded, "PNG load: " + sprite.last_error)
			if loaded:
				_check(sprite.texture.get_size() == Vector2(768, 960), "PNG dimensions")
				var second := Body.new()
				second.set_body_type(size_index)
				_check(second.load_body_texture() and second.texture == sprite.texture, "shared texture without repeated upload")
				second.free()
		_check(Body.texture_cache_size() == 3, "exact three-page texture cache")
	else:
		print("PNG checks deferred: all three atlas pages are absent; rerun with --require-png after generation.")
	sprite.free()
	print("neutral-body-reference: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		print("FAIL: " + label)
