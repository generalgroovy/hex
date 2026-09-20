extends FluxTestSuite


const MANIFEST_PATH: String = "res://content/animations/skeleton_animation_manifest_v1.json"


func run() -> int:
	_test_repository_manifest()
	_test_all_regions_and_pivots()
	_test_invalid_manifest_fails_closed()
	return finish("skeleton-animation-library")


func _test_repository_manifest() -> void:
	var library := SkeletonAnimationLibrary.new()
	check(library.load_from_file(MANIFEST_PATH), "repository skeleton manifest validates: %s" % library.last_error)
	equal(library.cell_size, Vector2i(32, 32), "all skeletons use one stable cell size")
	equal(library.pivot, Vector2i(16, 28), "all skeletons share the bottom-center pivot")
	equal(library.directions.size(), 8, "eight directions are available")
	equal(library.cardinal_directions, ["south", "east", "north", "west"], "four cardinal animation directions are explicit")
	equal(library.cardinal_direction_indices(), [0, 2, 4, 6], "cardinal directions resolve to stable atlas rows")
	equal(library.body_types.keys(), ["small", "middle", "large"], "exactly three ordered reusable body types are available")
	check(library.animations.size() >= 25, "planned movement, combat, reaction, utility, and cosmetic animations exist")
	equal(library.resolved_animation_id("roll"), "air_dodge", "roll reuses the bounded four-frame evasive skeleton")
	equal(library.resolved_animation_id("jump"), "hop", "player-facing jump resolves to the canonical hop skeleton")
	equal(int(library.action_contract("roll").get("invulnerability_ms", 0)), MovementTuning.ROLL_INVULNERABILITY_MS, "roll skeleton documents the authoritative invulnerability window")
	equal(String(library.action_contract("cast").get("magic_origin", "")), "hands", "cast skeleton is hands-only")


func _test_all_regions_and_pivots() -> void:
	var library := SkeletonAnimationLibrary.new()
	check(library.load_from_file(MANIFEST_PATH), "manifest loads for region tests")
	for body_type_id: String in library.body_types:
		check(not library.atlas_path(body_type_id).is_empty(), "%s has a runtime atlas" % body_type_id)
		check(not library.atlas_path(body_type_id, true).is_empty(), "%s has an overlay-debug atlas" % body_type_id)
		for animation_id: String in library.animations:
			var animation: Dictionary = library.animations[animation_id]
			var frames := int(animation["frames"])
			for direction_id: String in library.directions:
				for frame_index: int in range(frames):
					var region := library.frame_region(body_type_id, animation_id, direction_id, frame_index)
					equal(region.size, library.cell_size, "%s/%s/%s/%d uses exact cell size" % [body_type_id, animation_id, direction_id, frame_index])
					check(region.position.x >= 0 and region.position.y >= 0, "frame origin is non-negative")
					check(region.end.x <= library.atlas_size.x and region.end.y <= library.atlas_size.y, "frame remains within atlas")
				for cardinal_direction: String in library.cardinal_directions:
					var cardinal_region := library.frame_region(body_type_id, animation_id, cardinal_direction, 0)
					check(cardinal_region.has_area(), "%s/%s has a %s cardinal frame" % [body_type_id, animation_id, cardinal_direction])
	equal(library.pivot.x * 2, library.cell_size.x, "pivot is horizontally centered")
	check(library.pivot.y >= library.cell_size.y - 4, "pivot remains close to the feet baseline")
	equal(library.frame_region("middle", "roll", "south", 0), library.frame_region("middle", "air_dodge", "south", 0), "roll alias resolves to the same reusable atlas region")


func _test_invalid_manifest_fails_closed() -> void:
	var library := SkeletonAnimationLibrary.new()
	library.data = {
		"schema_version": 1,
		"cell_size": [32, 32],
		"pivot": [40, 40],
		"atlas_layout": {"atlas_size": [32, 32], "block_size": [32, 32]},
		"direction_order": ["south"],
		"animations": {},
		"body_types": {},
	}
	check(not library.validate(), "invalid pivot and incomplete direction set fail closed")
	check(not library.last_error.is_empty(), "validation failure is diagnosable")
