extends RefCounted

const CELL := Vector2i(96, 96)
const PIVOT := Vector2(48, 84)
const ATLAS_SIZE := Vector2i(768, 960)
const SIZES := ["small", "middle", "large"]
const ROWS := ["grounded", "jump", "cast", "hit", "walk", "sprint", "slide", "roll", "walk_b", "sprint_b"]
const DIRECTIONS := ["south", "south_east", "east", "north_east", "north", "north_west", "west", "south_west"]
const DIRECTION_LABELS := ["S / front", "SE", "E", "NE", "N / back", "NW", "W", "SW"]
const ACTIONS := ["idle", "walk", "sprint", "jump", "float", "slide", "roll", "air_dodge", "wave_dash", "wall_kick", "wallrun", "cast", "hit", "defend", "interact", "taunt", "defeated"]
const ACTION_ROWS := {
	"idle": ["grounded"], "walk": ["walk", "walk_b"], "sprint": ["sprint", "sprint_b"],
	"jump": ["jump"], "float": ["jump"], "slide": ["slide"], "roll": ["roll"],
	"air_dodge": ["jump"], "wave_dash": ["slide"], "wall_kick": ["jump"], "wallrun": ["slide"],
	"cast": ["cast"], "hit": ["hit"], "defend": ["grounded"], "interact": ["grounded"],
	"taunt": ["grounded"], "defeated": ["hit"],
}

var textures: Dictionary = {}
var status_lines: Array[String] = []


static func runtime_directory() -> String:
	var project_root := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	return project_root.get_base_dir().path_join("runtime").simplify_path()


func reload_sheets() -> int:
	textures.clear()
	status_lines.clear()
	for size_name: String in SIZES:
		var path := runtime_directory().path_join(size_name + ".png")
		if not FileAccess.file_exists(path):
			status_lines.append("%s: waiting for ../runtime/%s.png" % [size_name.capitalize(), size_name])
			continue
		var image := Image.new()
		if image.load(path) != OK:
			status_lines.append("%s: PNG could not be decoded" % size_name.capitalize())
			continue
		if image.get_size() != ATLAS_SIZE or image.get_format() != Image.FORMAT_RGBA8:
			status_lines.append("%s: expected 768x960 RGBA8; found %s, format %d" % [size_name.capitalize(), image.get_size(), image.get_format()])
			continue
		textures[size_name] = ImageTexture.create_from_image(image)
		status_lines.append("%s: loaded 10 rows x 8 directions" % size_name.capitalize())
	return textures.size()


static func sequence(action: String) -> Array:
	return ACTION_ROWS.get(action, [])


static func source_region(row: String, direction: int) -> Rect2:
	var row_index := ROWS.find(row)
	if row_index < 0 or direction < 0 or direction >= DIRECTIONS.size():
		return Rect2()
	return Rect2(direction * 96, row_index * 96, 96, 96)


static func pose_label(action: String, frame: int) -> String:
	var rows := sequence(action)
	if rows.is_empty():
		return "Unknown action - no invented pose"
	var current := String(rows[posmod(frame, rows.size())])
	if rows.size() == 2:
		return "%s: 2 supplied contact poses (%s / %s); showing %s. Preview cadence only." % [action.capitalize(), rows[0], rows[1], current]
	var alias := " Reused reference pose, not a dedicated animation." if action != current and not (action == "idle" and current == "grounded") else " No multi-frame motion is supplied."
	return "%s: 1 static source pose (%s).%s" % [action.capitalize(), current, alias]
