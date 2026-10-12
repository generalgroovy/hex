extends RefCounted
## Use the same criterion for painting, input transforms and pointer hit tests.
static func needs_reflow(viewport: Vector2, percent: int) -> bool:
	var scale := clampf(minf(viewport.x/1280.0,viewport.y/720.0),1.0,1.5)*float(percent)/100.0
	var logical := viewport/scale
	return logical.x < 1150 or logical.y < 650
