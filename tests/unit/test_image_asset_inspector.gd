extends FluxTestSuite


func run() -> int:
	var image := ImageAssetInspector.load_image("res://assets/effects/projectiles/burst_v3/burst_fire_runtime_32.png")
	check(image != null, "import-safe inspector decodes an imported runtime texture")
	if image != null:
		equal(image.get_size(), Vector2i(512, 256), "import-safe inspector preserves source dimensions")
		check(not image.is_empty(), "import-safe inspector returns visible image data")
	check(ImageAssetInspector.load_image("res://content/abilities/foundation_abilities_v1.json") == null, "non-image content fails closed")
	check(ImageAssetInspector.load_image("res://assets/missing.png") == null, "missing image fails closed")
	check(ImageAssetInspector.load_image("C:/outside.png") == null, "non-resource paths fail closed")
	return finish("image-asset-inspector")
