extends SceneTree

# Read-only pixel inspection: crops are QA evidence, never authored body pixels.
func _initialize() -> void:
	var original := Image.new()
	if original.load_png_from_buffer(FileAccess.get_file_as_bytes("res://art_batches/character_style_v1/jan_wicked/gaits-roll-v1.png")) != OK:
		quit(1)
		return
	var crop := original.get_region(Rect2i(392, 409, 156, 191))
	crop.resize(624, 764, Image.INTERPOLATE_NEAREST)
	crop.save_png("res://art_batches/character_style_v1/jan_wicked/sprint-east-source-review.png")
	quit(0)
