extends RefCounted
## Cosmetic budgets only. Simulation, spell telegraphs and accessibility are
## independent of render detail; the same commands produce the same world.

static var profile: String = "standard"

static func set_profile(value: String) -> bool:
	if value not in ["low", "standard"]: return false
	profile = value
	return true

static func surface_glow_limit(normal_limit: int) -> int:
	return 0 if profile == "low" else maxi(0, normal_limit)

static func decoration_limit(normal_limit: int) -> int:
	return maxi(1, normal_limit >> 1) if profile == "low" and normal_limit > 0 else maxi(0, normal_limit)

static func garden_sample_limit() -> int:
	return 1 if profile == "low" else 3
