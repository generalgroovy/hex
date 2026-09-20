extends SceneTree

# Read-only discovery aid. A neutral component is not permission to erase it.
func _initialize() -> void:
	var layout_path := "res://art_batches/character_style_v1/nico_lai/source-layout-v2.json"
	var page := 0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--layout="): layout_path = argument.trim_prefix("--layout=")
		if argument.begins_with("--page="): page = int(argument.trim_prefix("--page="))
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(layout.pages[page].path)) != OK:
		quit(1)
		return
	var findings: Array = []
	for cell: Dictionary in layout.pages[page].cells:
		var r: Array = cell.rect
		var region := Rect2i(r[0], r[1], r[2], r[3])
		var visited: Dictionary = {}
		for y: int in range(region.position.y, region.end.y):
			for x: int in range(region.position.x, region.end.x):
				var start := Vector2i(x, y)
				if visited.has(start) or not _neutral(image.get_pixelv(start)): continue
				var pending: Array[Vector2i] = [start]
				var cursor := 0
				var edge := false
				var minimum := start
				var maximum := start
				visited[start] = true
				while cursor < pending.size():
					var point: Vector2i = pending[cursor]
					cursor += 1
					minimum = minimum.min(point)
					maximum = maximum.max(point)
					if point.x == region.position.x or point.y == region.position.y or point.x == region.end.x - 1 or point.y == region.end.y - 1: edge = true
					for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
						var neighbor := point + step
						if region.has_point(neighbor) and not visited.has(neighbor) and _neutral(image.get_pixelv(neighbor)):
							visited[neighbor] = true
							pending.append(neighbor)
				if not edge and pending.size() >= 20 and minimum.y > region.position.y + int(region.size.y * 0.55) and cell.state != "roll":
					findings.append({"state":cell.state,"direction":cell.direction,"seed":[start.x,start.y],"pixels":pending.size(),"rect":[minimum.x,minimum.y,maximum.x-minimum.x+1,maximum.y-minimum.y+1]})
	print(JSON.stringify(findings))
	quit(0)


func _neutral(color: Color) -> bool:
	return color.a > 0.0 and minf(color.r, minf(color.g, color.b)) >= 170.0 / 255.0 and maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b)) <= 18.001 / 255.0
