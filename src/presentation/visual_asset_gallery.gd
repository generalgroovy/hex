extends Node2D


const ANIMATION_ORDER: Array[String] = [
	"idle", "walk", "sprint", "hop", "double_jump", "rise", "fall", "land",
	"wall_contact", "wall_kick", "air_dodge", "wavedash", "slide", "slide_jump",
	"vault", "superglide", "attack_primary", "cast", "defend", "hit", "stunned",
	"rooted", "defeated", "interact", "taunt",
]

var registry := VisualAssetRegistry.new()
var skeletons := SkeletonAnimationLibrary.new()
var background: Texture2D
var champion_atlas: Texture2D
var element_icons: Texture2D
var ability_icons: Texture2D
var ui_icons: Texture2D
var animation_index: int = 0
var direction_index: int = 0
var frame_index: int = 0
var elapsed: float = 0.0
var direction_elapsed: float = 0.0
var animation_elapsed: float = 0.0


func _ready() -> void:
	if not registry.load_from_file():
		push_error(registry.last_error)
		get_tree().quit(1)
		return
	if not skeletons.load_from_file():
		push_error(skeletons.last_error)
		get_tree().quit(1)
		return
	background = load(registry.nexus_preview_path()) as Texture2D
	champion_atlas = load(registry.champion_atlas_path("nico_lai")) as Texture2D
	element_icons = load(str((registry.icons["elements"] as Dictionary)["path"])) as Texture2D
	ability_icons = load(str((registry.icons["abilities"] as Dictionary)["path"])) as Texture2D
	ui_icons = load(str((registry.icons["ui_states"] as Dictionary)["path"])) as Texture2D
	if background == null or champion_atlas == null:
		push_error("visual gallery textures did not import")
		get_tree().quit(1)
		return
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	direction_elapsed += delta
	animation_elapsed += delta
	if direction_elapsed >= 0.8:
		direction_elapsed = 0.0
		direction_index = (direction_index + 1) % skeletons.directions.size()
	if animation_elapsed >= 2.6:
		animation_elapsed = 0.0
		animation_index = (animation_index + 1) % ANIMATION_ORDER.size()
		frame_index = 0
	var animation_id: String = ANIMATION_ORDER[animation_index]
	var definition: Dictionary = skeletons.animations[animation_id]
	var frames := int(definition["frames"])
	var fps := float(definition["fps"])
	frame_index = int(elapsed * fps) % frames
	queue_redraw()


func _draw() -> void:
	draw_texture(background, Vector2.ZERO)
	var animation_id: String = ANIMATION_ORDER[animation_index]
	var direction_id: String = skeletons.directions[direction_index]
	var source := skeletons.frame_region("small", animation_id, direction_id, frame_index)
	var destination := Rect2(Vector2(364, 332), Vector2(128, 128))
	draw_texture_rect_region(champion_atlas, destination, source)

	draw_rect(Rect2(12, 12, 1256, 58), Color("111514e8"), true)
	draw_rect(Rect2(12, 12, 1256, 58), Color("74532b"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(28, 39), "H.E.X. VISUAL ASSET FOUNDATION V1", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color("e2d8b2"))
	draw_string(
		ThemeDB.fallback_font,
		Vector2(670, 39),
		"NICO LAI \u00b7 %s \u00b7 %s \u00b7 FRAME %d" % [animation_id.to_upper(), direction_id.to_upper(), frame_index],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		14,
		Color("55dbe0"),
	)
	draw_string(ThemeDB.fallback_font, Vector2(28, 61), "Presentation-only gallery \u00b7 authoritative movement/collision remains in src/sim", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("b6a477"))

	draw_rect(Rect2(16, 660, 1248, 48), Color("111514e8"), true)
	draw_texture_rect_region(element_icons, Rect2(28, 672, 256, 32), Rect2(0, 0, 128, 16))
	draw_texture_rect_region(ability_icons, Rect2(320, 668, 384, 64), Rect2(0, 0, 192, 32))
	draw_texture_rect_region(ui_icons, Rect2(744, 672, 384, 32), Rect2(0, 0, 192, 16))
