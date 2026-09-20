class_name PixelPresentation
extends RefCounted


const SUPPORTED_ZOOM := [50, 75, 100]


static func zoom_scale(zoom_percent: int) -> float:
	return float(clampi(zoom_percent, 50, 100)) / 100.0


static func snapped_canvas_origin(camera_origin: Vector2, zoom_percent: int) -> Vector2:
	return (-camera_origin * zoom_scale(zoom_percent)).round()


static func world_to_screen(world_position: Vector2, camera_origin: Vector2, zoom_percent: int) -> Vector2:
	return ((world_position - camera_origin) * zoom_scale(zoom_percent)).round()


static func snapped_world_anchor(world_position: Vector2, camera_origin: Vector2, zoom_percent: int) -> Vector2:
	var zoom := zoom_scale(zoom_percent)
	return camera_origin + world_to_screen(world_position, camera_origin, zoom_percent) / zoom
