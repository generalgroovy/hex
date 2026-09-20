class_name WellspringCharacterSprite
extends Sprite2D


const CATALOG_PATH := "res://content/visual/wellspring_visual_catalog_v2.json"
const CELL_SIZE := Vector2i(64, 64)
const PIVOT := Vector2i(32, 56)
const BLOCK_SIZE := Vector2i(384, 512)

@export_enum("champion", "race_base", "race_exemplar") var source_kind: String = "champion"
@export var source_id: String = "nico_lai"
@export_enum("small", "middle", "large") var body_type: String = "middle"
@export_enum("masculine", "feminine") var presentation: String = "masculine"
@export var animation_id: String = "idle"
@export_range(0, 7, 1) var direction_index: int = 0
@export var playing: bool = true

var last_error: String = ""
var catalog: Dictionary = {}
var animation_lookup: Dictionary = {}
var current_frame: int = 0
var elapsed: float = 0.0
var frame_count: int = 1
var animation_fps: float = 6.0
var animation_loop: bool = true
var _block := Vector2i.ZERO


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = true
	region_enabled = true
	offset = Vector2(CELL_SIZE.x * 0.5 - PIVOT.x, CELL_SIZE.y * 0.5 - PIVOT.y)
	if not load_source():
		push_error(last_error)


func _process(delta: float) -> void:
	if not playing or texture == null or frame_count <= 1:
		return
	elapsed += delta
	var seconds_per_frame := 1.0 / maxf(animation_fps, 1.0)
	while elapsed >= seconds_per_frame:
		elapsed -= seconds_per_frame
		if current_frame + 1 >= frame_count:
			current_frame = 0 if animation_loop else frame_count - 1
		else:
			current_frame += 1
		_apply_region()


func load_source() -> bool:
	last_error = ""
	texture = null
	region_enabled = false
	animation_lookup.clear()
	catalog = _load_json(CATALOG_PATH)
	if catalog.is_empty():
		return false
	_build_animation_lookup()
	var atlas_path := _resolve_atlas_path()
	if atlas_path.is_empty():
		return false
	var atlas_resource: Resource = load(atlas_path)
	if not atlas_resource is Texture2D:
		return _fail("character atlas could not be loaded: %s" % atlas_path)
	texture = atlas_resource
	region_enabled = true
	return set_animation_state(animation_id, direction_index, true)


func set_champion(champion_id: String) -> bool:
	source_kind = "champion"
	source_id = champion_id
	return load_source()


func set_race_base(race_id: String, new_body_type: String, new_presentation: String) -> bool:
	source_kind = "race_base"
	source_id = race_id
	body_type = canonical_body_type(new_body_type)
	if body_type.is_empty():
		return _fail("unsupported character body type: %s" % new_body_type)
	presentation = new_presentation
	return load_source()


func set_race_exemplar(race_id: String) -> bool:
	source_kind = "race_exemplar"
	source_id = race_id
	return load_source()


func set_animation_state(new_animation_id: String, new_direction_index: int, restart: bool = false) -> bool:
	if not animation_lookup.has(new_animation_id):
		return _fail("unknown character animation: %s" % new_animation_id)
	animation_id = new_animation_id
	direction_index = clampi(new_direction_index, 0, 7)
	var definition: Dictionary = animation_lookup[animation_id]
	var block: Array = definition.get("block", [])
	if block.size() != 2:
		return _fail("animation block is malformed: %s" % animation_id)
	_block = Vector2i(int(block[0]), int(block[1]))
	frame_count = int(definition.get("frames", 1))
	animation_fps = float(definition.get("fps", 6))
	animation_loop = bool(definition.get("loop", false))
	if restart or current_frame >= frame_count:
		current_frame = 0
		elapsed = 0.0
	_apply_region()
	return true


func set_direction(new_direction_index: int) -> void:
	direction_index = clampi(new_direction_index, 0, 7)
	_apply_region()


func set_animation_frame(new_frame: int) -> void:
	current_frame = clampi(new_frame, 0, max(0, frame_count - 1))
	_apply_region()


func sync_from_player(
	state: PlayerState,
	config: SimConfig,
	simulation_tick: int,
	interpolation_alpha: float = 0.0,
) -> bool:
	if texture == null:
		return _fail("character texture is not loaded")
	if config == null or not config.is_valid() or simulation_tick < 0:
		return _fail("character presentation requires a valid simulation clock")
	var requested_animation := animation_id_for_player(state)
	var requested_direction := direction_index_from_vector(state.facing_x, state.facing_y)
	var restart := requested_animation != animation_id
	if not set_animation_state(requested_animation, requested_direction, restart):
		return false
	var definition: Dictionary = animation_lookup[animation_id]
	var requested_frame: int = 0
	if animation_loop:
		var frames_per_second := maxi(1, int(definition.get("fps", 1)))
		@warning_ignore("integer_division")
		requested_frame = (simulation_tick * frames_per_second / config.tick_rate) % frame_count
	else:
		var phase := _action_phase(state, config, interpolation_alpha, animation_id)
		requested_frame = mini(frame_count - 1, floori(phase * float(frame_count)))
	set_animation_frame(requested_frame)
	return true


static func animation_id_for_player(state: PlayerState) -> String:
	if state.control_state == PlayerState.ControlState.STUNNED:
		return "stunned"
	if state.control_state == PlayerState.ControlState.ROOTED:
		return "rooted"
	if state.landing_ticks > 0 and not state.is_airborne() and state.vault_ticks == 0:
		return "land"
	match state.movement_mode:
		PlayerState.MovementMode.WALK, PlayerState.MovementMode.SLOWED:
			return "walk"
		PlayerState.MovementMode.SPRINT, PlayerState.MovementMode.CHARGING:
			return "sprint"
		PlayerState.MovementMode.HOP:
			return "hop"
		PlayerState.MovementMode.DOUBLE_JUMP:
			return "double_jump"
		PlayerState.MovementMode.SLIDE:
			return "slide"
		PlayerState.MovementMode.SLIDE_JUMP:
			return "slide_jump"
		PlayerState.MovementMode.AIR_DODGE:
			return "air_dodge"
		PlayerState.MovementMode.ROLL:
			return "air_dodge"
		PlayerState.MovementMode.WAVE_DASH:
			return "wavedash"
		PlayerState.MovementMode.WALL_KICK:
			return "wall_kick"
		PlayerState.MovementMode.WALL_SKIM:
			return "wall_kick"
		PlayerState.MovementMode.VAULT:
			return "vault"
		PlayerState.MovementMode.SUPERGLIDE:
			return "superglide"
		PlayerState.MovementMode.FAST_FALL:
			return "fall"
		PlayerState.MovementMode.LAUNCHED:
			return "hit"
		PlayerState.MovementMode.IMPACT_RECOVERY:
			return "hit"
		PlayerState.MovementMode.GRAPPLED:
			return "fall"
		PlayerState.MovementMode.STUNNED:
			return "stunned"
		PlayerState.MovementMode.ROOTED:
			return "rooted"
		_:
			return "idle"


static func direction_index_from_vector(x: int, y: int) -> int:
	return EightDirectionResolver.classify_index(x, y)


static func destination_rect(body_anchor: Vector2) -> Rect2:
	return Rect2(body_anchor - Vector2(PIVOT), Vector2(CELL_SIZE))


func _apply_region() -> void:
	var x := _block.x * BLOCK_SIZE.x + current_frame * CELL_SIZE.x
	var y := _block.y * BLOCK_SIZE.y + direction_index * CELL_SIZE.y
	region_rect = Rect2(Vector2(x, y), Vector2(CELL_SIZE))


func _action_phase(state: PlayerState, config: SimConfig, interpolation_alpha: float, requested_animation: String) -> float:
	if requested_animation in ["hop", "double_jump", "wall_kick", "air_dodge", "slide_jump", "vault", "superglide"]:
		return JumpPresentation.sample(state, config, interpolation_alpha).normalized_phase
	if requested_animation == "land":
		return _remaining_phase(
			state.landing_ticks,
			config.milliseconds_to_ticks(MovementTuning.LANDING_WINDOW_MS),
			interpolation_alpha,
		)
	if requested_animation == "wavedash":
		return _remaining_phase(
			state.wave_dash_ticks,
			config.milliseconds_to_ticks(MovementTuning.WAVE_DASH_DURATION_MS),
			interpolation_alpha,
		)
	return 0.0


func _remaining_phase(remaining_ticks: int, total_ticks: int, interpolation_alpha: float) -> float:
	if remaining_ticks <= 0 or total_ticks <= 0:
		return 0.0
	var elapsed_ticks := float(total_ticks - remaining_ticks) + clampf(interpolation_alpha, 0.0, 1.0)
	return clampf(elapsed_ticks / float(total_ticks), 0.0, 1.0)


func _resolve_atlas_path() -> String:
	if source_kind == "champion":
		var champions: Dictionary = catalog.get("champions", {})
		if not champions.has(source_id):
			_fail("unknown champion visual source: %s" % source_id)
			return ""
		return str((champions[source_id] as Dictionary).get("atlas", ""))
	var races: Dictionary = catalog.get("races", {})
	if not races.has(source_id):
		_fail("unknown race visual source: %s" % source_id)
		return ""
	var race: Dictionary = races[source_id]
	if source_kind == "race_exemplar":
		return str((race.get("exemplar", {}) as Dictionary).get("atlas", ""))
	var variants: Dictionary = race.get("base_variants", {})
	var legacy_size_id := legacy_size_id_for_body_type(body_type)
	var sizes: Dictionary = variants.get(legacy_size_id, {})
	var variant: Dictionary = sizes.get(presentation, {})
	var path := str(variant.get("atlas", ""))
	if path.is_empty():
		_fail("missing race-base atlas for %s/%s/%s" % [source_id, body_type, presentation])
	return path


static func canonical_body_type(value: String) -> String:
	match value.to_lower():
		"small", "tiny", "size_1_tiny", "size_2_small":
			return "small"
		"middle", "medium", "size_3_medium":
			return "middle"
		"large", "huge", "size_4_large", "size_5_huge":
			return "large"
		_:
			return ""


static func legacy_size_id_for_body_type(value: String) -> String:
	match canonical_body_type(value):
		"small":
			return "size_2_small"
		"middle":
			return "size_3_medium"
		"large":
			return "size_4_large"
		_:
			return ""


func _build_animation_lookup() -> void:
	animation_lookup.clear()
	var contract: Dictionary = catalog.get("character_contract", {})
	for definition_variant: Variant in contract.get("animations", []):
		if definition_variant is Dictionary:
			var definition: Dictionary = definition_variant
			animation_lookup[str(definition.get("id", ""))] = definition


func _load_json(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		_fail("JSON file does not exist: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("could not open JSON file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_fail("JSON root must be an object: %s" % path)
		return {}
	return parsed


func _fail(message: String) -> bool:
	last_error = message
	return false
