extends Sprite2D

# Standalone reference viewer, not a movement controller. The parent owns
# position, height and every effect. Never copy race/element VFX into these cells.
# Copy this folder into a Godot 4 project; no FLUX classes or autoloads are used.
enum BodyType { SMALL, MIDDLE, LARGE }
const BODY_NAMES := ["small", "middle", "large"]
const DIRECTIONS := ["south", "south_east", "east", "north_east", "north", "north_west", "west", "south_west"]
const POSES := ["grounded", "jump", "cast", "hit", "walk", "sprint", "slide", "roll", "walk_b", "sprint_b"]
const CELL := Vector2i(96, 96)
const PIVOT := Vector2i(48, 84)
const ATLAS_SIZE := Vector2i(768, 960)
const VISUAL_HZ := 60.0
# Size-exemplar cadence, in 60 Hz ART ticks (not 120 Hz simulation ticks).
# Both contacts occupy exactly half a cycle. These are not gameplay durations.
const WALK_CYCLES := [26, 22, 28]
const SPRINT_CYCLES := [18, 16, 20]
const ACTION_POSES := {
	"idle": "grounded", "walk": "walk", "sprint": "sprint", "jump": "jump",
	"float": "jump", "slide": "slide", "slide_jump": "jump", "air_dodge": "jump",
	"wave_dash": "slide", "wall_jump": "jump", "wallrun": "slide", "fast_fall": "jump",
	"roll": "roll", "launched": "hit", "grappled": "hit", "charging": "cast",
	"stunned": "hit", "rooted": "grounded", "slowed": "walk", "impact_recovery": "hit",
	"cast": "cast", "cast_recovery": "cast", "defeated": "hit", "hit": "hit",
}
# Current names on the right; left-hand names remain runtime compatibility IDs.
# DOUBLE_JUMP is held Float, not a second lift. WALL_SKIM is current wallrun.
const SEMANTIC_ALIASES := {"double_jump": "float", "wall_skim": "wallrun", "wall_run": "wallrun", "wall_kick": "wall_jump"}
# These are reference/gallery aliases, NOT implemented gameplay actions.
# Explicit set_gallery_state() is required; set_state() rejects them.
const GALLERY_POSES := {"attack_primary": "cast", "defend": "grounded", "interact": "grounded", "taunt": "grounded"}

static var _texture_cache: Dictionary = {}
var last_error := ""
var _body_type := BodyType.SMALL
var _action := "idle"
var _direction := 0
var _gallery_only := false
var _elapsed_visual_ticks := 0.0

@export_enum("Small", "Middle", "Large") var body_type: int = BodyType.SMALL:
	get: return _body_type
	set(value): set_body_type(value)
@export var action_semantic: String = "idle":
	get: return _action
	set(value): set_state(value, _direction)
@export_enum("South", "South East", "East", "North East", "North", "North West", "West", "South West") var direction: int = 0:
	get: return _direction
	set(value): _set_action(_action, value, _gallery_only)
@export var playing := true


func _init() -> void:
	centered = false
	offset = -Vector2(PIVOT)
	region_enabled = true
	region_filter_clip_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_region()


func _ready() -> void:
	# Failure is reported through last_error/return values, never hidden by an
	# unrelated fallback sprite. Missing files are legal in contract-only tests.
	load_body_texture()


func _process(delta: float) -> void:
	advance_animation(delta)


func set_body_type(value: int) -> bool:
	if value < BodyType.SMALL or value > BodyType.LARGE:
		return _fail("Body type must be Small=0, Middle=1 or Large=2")
	if value == _body_type:
		last_error = ""
		return true
	# A live node changes body only after the new page is available. Detached
	# nodes can be configured and contract-tested before PNG generation.
	var next_texture: Texture2D
	if is_inside_tree():
		next_texture = _body_texture(value)
		if next_texture == null:
			return false
	_body_type = value
	_elapsed_visual_ticks = 0.0
	texture = next_texture
	_apply_region()
	last_error = ""
	return true


func set_state(action: String, direction_index: int) -> bool:
	return _set_action(action, direction_index, false)


func set_gallery_state(action: String, direction_index: int) -> bool:
	if not GALLERY_POSES.has(action):
		return _fail("Unknown gallery-only action: " + action)
	return _set_action(action, direction_index, true)


func _set_action(action: String, direction_index: int, gallery: bool) -> bool:
	var canonical := String(SEMANTIC_ALIASES.get(action, action))
	var supported := GALLERY_POSES.has(canonical) if gallery else ACTION_POSES.has(canonical)
	if not supported:
		return _fail("Unknown or inactive action: " + action)
	if direction_index < 0 or direction_index >= DIRECTIONS.size():
		return _fail("Direction must be an integer from 0 through 7")
	if canonical != _action or gallery != _gallery_only:
		_elapsed_visual_ticks = 0.0
	_action = canonical
	_direction = direction_index
	_gallery_only = gallery
	_apply_region()
	last_error = ""
	return true


func advance_animation(delta_seconds: float) -> bool:
	if not is_finite(delta_seconds) or delta_seconds < 0.0:
		return _fail("Animation delta must be finite and nonnegative")
	var cycle := _cycle_ticks()
	if playing and cycle > 0:
		# Reduce before multiplication: even a finite huge delta cannot overflow
		# or grow the stored phase without bound.
		_elapsed_visual_ticks = fposmod(_elapsed_visual_ticks + fposmod(delta_seconds, float(cycle) / VISUAL_HZ) * VISUAL_HZ, float(cycle))
		_apply_region()
	last_error = ""
	return true


func frame_model() -> Dictionary:
	var pose := _base_pose()
	var cycle := _cycle_ticks()
	var contact := 1 if cycle > 0 and _elapsed_visual_ticks >= float(cycle) * 0.5 else 0
	if contact == 1:
		pose += "_b"
	return {
		"body_type": _body_type, "body_name": BODY_NAMES[_body_type], "action": _action,
		"direction": _direction, "direction_name": DIRECTIONS[_direction], "pose": pose,
		"contact_frame": contact, "cycle_ticks_at_60": cycle, "loop": cycle > 0,
		"region": Rect2(_direction * CELL.x, POSES.find(pose) * CELL.y, CELL.x, CELL.y),
		"pivot": PIVOT, "cell": CELL, "gallery_only": _gallery_only,
	}


func _apply_region() -> void:
	region_rect = frame_model()["region"]


func _base_pose() -> String:
	return String(GALLERY_POSES[_action] if _gallery_only else ACTION_POSES[_action])


func _cycle_ticks() -> int:
	var pose := _base_pose()
	if pose == "walk":
		return int(WALK_CYCLES[_body_type])
	if pose == "sprint":
		return int(SPRINT_CYCLES[_body_type])
	return 0 # One pose held until the owner supplies a different state.


func texture_path(value: int = -1) -> String:
	var selected := _body_type if value == -1 else value
	if selected < BodyType.SMALL or selected > BodyType.LARGE:
		return ""
	return get_script().resource_path.get_base_dir().path_join(BODY_NAMES[selected] + ".png")


func load_body_texture() -> bool:
	var loaded := _body_texture(_body_type)
	if loaded == null:
		return false
	texture = loaded
	last_error = ""
	return true


func _body_texture(value: int) -> Texture2D:
	var path := texture_path(value)
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var loaded: Texture2D
	if ResourceLoader.exists(path, "Texture2D"):
		loaded = ResourceLoader.load(path, "Texture2D") as Texture2D
	elif FileAccess.file_exists(path):
		# A reference pack under .gdignore/outside the import root has raw PNGs.
		# Upload once, then share this Texture2D among every same-size instance.
		var pixels := Image.load_from_file(path)
		if pixels != null and pixels.get_size() == ATLAS_SIZE and pixels.get_format() == Image.FORMAT_RGBA8 and not pixels.has_mipmaps():
			loaded = ImageTexture.create_from_image(pixels)
	if loaded == null or loaded.get_size() != Vector2(ATLAS_SIZE):
		_fail("Missing or invalid 768x960 RGBA atlas: " + path)
		return null
	var image := loaded.get_image()
	if image == null or image.has_mipmaps():
		_fail("Reference atlas must expose pixels and have no mipmaps: " + path)
		return null
	_texture_cache[path] = loaded
	return loaded


static func texture_cache_size() -> int:
	return _texture_cache.size()


static func semantic_aliases() -> Dictionary:
	return SEMANTIC_ALIASES.duplicate()


func _fail(message: String) -> bool:
	last_error = message
	return false
