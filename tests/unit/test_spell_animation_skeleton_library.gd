extends FluxTestSuite


func run() -> int:
	_test_repository_manifest()
	_test_phase_lookup_is_bounded()
	_test_invalid_manifest_fails_closed()
	return finish("spell-animation-skeleton-library")


func _test_repository_manifest() -> void:
	var library := SpellAnimationSkeletonLibrary.new()
	check(library.load_from_file(), "spell animation skeleton manifest validates: %s" % library.last_error)
	equal(library.skeletons.size(), 4, "all four delivery shapes have reusable skeletons")
	equal(library.phase_order, ["startup", "release", "travel", "impact", "residue"], "spell phases use one canonical order")
	for shape_id: String in SpellAnimationSkeletonLibrary.REQUIRED_SHAPES:
		var skeleton := library.skeleton_for_shape(shape_id)
		equal(String(skeleton.get("shape", "")), shape_id, "%s skeleton preserves its delivery shape" % shape_id)
		equal((skeleton.get("phases", []) as Array).size(), 5, "%s skeleton has five readable phases" % shape_id)


func _test_phase_lookup_is_bounded() -> void:
	var library := SpellAnimationSkeletonLibrary.new()
	check(library.load_from_file(), "phase lookup starts from a valid manifest")
	equal(String(library.phase_for("projectile", -1.0).get("id", "")), "startup", "negative progress clamps to startup")
	equal(String(library.phase_for("projectile", 0.50).get("id", "")), "travel", "mid-flight progress resolves to travel")
	equal(String(library.phase_for("projectile", 1.0).get("id", "")), "residue", "terminal progress resolves to residue")
	equal(library.phase_for("missing", 0.5), {}, "unknown delivery shape fails closed")


func _test_invalid_manifest_fails_closed() -> void:
	var library := SpellAnimationSkeletonLibrary.new()
	library.data = {
		"schema_version": 1,
		"id": "flux2-spell-animation-skeletons-v1",
		"authority": "presentation only; simulation owns spell membership, geometry, timing, collision, resources, damage, control and outcomes",
		"phase_order": ["startup", "release", "travel", "impact", "residue"],
		"budgets": {"maximum_phase_count": 5, "maximum_draw_layers": 4, "maximum_particle_density": 35},
		"skeletons": {"projectile": {"shape": "projectile", "phases": []}}
	}
	check(not library.validate(), "incomplete spell animation manifest fails closed")
	check(not library.last_error.is_empty(), "spell animation refusal is actionable")
