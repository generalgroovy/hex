extends Node2D


var catalog := CompleteVisualCatalog.new()
var roster: Texture2D
var districts: Texture2D
var props: Texture2D
var element_vfx: Texture2D
var ui_skin: Texture2D


func _ready() -> void:
	if not catalog.load_from_file():
		push_error(catalog.last_error)
		get_tree().quit(1)
		return
	roster = load(str(catalog.overviews.get("roster", ""))) as Texture2D
	districts = load(str(catalog.overviews.get("districts", ""))) as Texture2D
	props = load(str(catalog.props.get("path", ""))) as Texture2D
	element_vfx = load(str(catalog.element_vfx.get("path", ""))) as Texture2D
	ui_skin = load(str(catalog.ui.get("skin", ""))) as Texture2D
	if roster == null or districts == null or props == null or element_vfx == null or ui_skin == null:
		push_error("complete visual gallery textures did not import")
		get_tree().quit(1)
		return
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color("0d1110"), true)
	draw_texture_rect(roster, Rect2(0, 0, 640, 427), false)
	draw_texture_rect(districts, Rect2(640, 0, 640, 480), false)
	draw_rect(Rect2(0, 480, 1280, 240), Color("111514"), true)
	draw_rect(Rect2(0, 480, 1280, 240), Color("74532b"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(20, 508), "LEGACY VISUAL ARCHIVE V1 - NOT THE CURRENT PLAYABLE CAST OR MAP", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color("e2d8b2"))
	draw_string(ThemeDB.fallback_font, Vector2(20, 532), "Archived labels, ancestry silhouettes and size plans are historical. Current roster metadata is maintained separately.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color("55dbe0"))
	draw_texture_rect(props, Rect2(20, 550, 640, 160), false)
	draw_texture_rect(element_vfx, Rect2(680, 550, 144, 160), false)
	draw_texture_rect(ui_skin, Rect2(850, 550, 160, 160), false)
	draw_string(ThemeDB.fallback_font, Vector2(1035, 580), "16 PROPS × 8 STATES", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color("b88438"))
	draw_string(ThemeDB.fallback_font, Vector2(1035, 605), "8 ELEMENTS × 6 PHASES", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color("9b65d9"))
	draw_string(ThemeDB.fallback_font, Vector2(1035, 630), "VERSIONED UI SKIN", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color("55dbe0"))
	draw_string(ThemeDB.fallback_font, Vector2(1035, 675), "PRESENTATION ONLY", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color("e58a38"))
