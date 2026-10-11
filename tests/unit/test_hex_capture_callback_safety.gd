extends FluxTestSuite

const Snapshot = preload("res://src/net/hex_world_snapshot.gd")
const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"

# These are contract regressions, not comparisons with frozen E8: E8 also
# omitted the final live-source comparison. An extensible producer must not
# publish stale authority or bypass an existing virtual state_hash override.
class HashOverrideWorld:
	extends SimWorld
	var hash_calls := 0
	func state_hash() -> String:
		hash_calls += 1
		return "f".repeat(64)

class PassthroughWorld:
	extends SimWorld
	var hash_calls := 0
	func state_hash() -> String:
		hash_calls += 1
		return super.state_hash()

class MutatingPlayer:
	extends PlayerState
	var court: HexChemistryWorld
	var armed := false
	var calls := 0
	func canonical_values() -> PackedInt64Array:
		calls += 1
		if armed:
			armed = false
			court.metrics.requested += 1
			court.metrics.refused += 1
		return super.canonical_values()

class MutatingCollision:
	extends CollisionWorld
	var court: HexChemistryWorld
	var armed := false
	var calls := 0
	func obstacle_view() -> Array[Obstacle]:
		calls += 1
		if armed:
			armed = false
			court.metrics.requested += 1
			court.metrics.refused += 1
		return super.obstacle_view()

class AlternateDynamicCollision:
	extends HexCollisionWorld

class AlternateObstacle:
	extends CollisionWorld.Obstacle

class OpaqueKey:
	extends RefCounted
	var calls := 0
	func _to_string() -> String:
		calls += 1
		return "opaque"


func run() -> int:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "callback fixtures load unchanged production abilities")
	if not catalog.last_error.is_empty(): return finish("hex-capture-callback-safety")
	_test_safe_concrete_capture(catalog)
	_test_world_hash_dispatch(catalog)
	_test_actor_mutation_refused(catalog)
	_test_collision_mutation_refused(catalog, false)
	_test_collision_mutation_refused(catalog, true)
	_test_dynamic_subclass_fallback(catalog)
	_test_opaque_authority_and_obstacle_admission(catalog)
	return finish("hex-capture-callback-safety")


func _fixture(catalog: AbilityCatalog, requested: SimWorld = null) -> SimWorld:
	var world := SimWorld.new() if requested == null else requested
	check(HexCourtPractice.configure(world, catalog, false), "callback fixture configures ordinary practice loadout")
	var selected: Array[Vector2i] = []
	for cell: Vector2i in world.hex_court.cell_keys(): selected.append(cell)
	var authority := HexChemistryWorld.new()
	check(authority.configure_geometry(world.hex_court.origin, selected), "callback fixture admits exact concrete chemistry geometry")
	authority.chemistry_enabled = true
	var base: CollisionWorld = world.collision
	var collision := HexCollisionWorld.new(base)
	check(collision.set_hex_surfaces(authority, world.tick), "callback fixture admits concrete collision surfaces")
	authority.collision = base
	world.hex_court = authority
	world.collision = collision
	world.reaction_movement = collision
	return world


func _test_safe_concrete_capture(catalog: AbilityCatalog) -> void:
	var world := _fixture(catalog)
	check(Snapshot._producer_reuse_eligible(world), "known concrete authority and collision remain eligible for synchronous reuse")
	var before := world.state_hash()
	var snapshot := Snapshot.capture(world)
	check(not snapshot.is_empty(), "safe concrete snapshot still captures")
	if snapshot.is_empty(): return
	equal(snapshot.state_hash, before, "safe concrete capture carries exact live full authority hash")
	var restored := Snapshot.prepare(snapshot, world)
	check(restored != null and restored.state_hash() == before, "safe concrete snapshot independently reconstructs exact authority")
	equal(world.state_hash(), before, "safe concrete capture never changes source")


func _test_world_hash_dispatch(catalog: AbilityCatalog) -> void:
	var overridden := HashOverrideWorld.new()
	_fixture(catalog, overridden)
	check(not Snapshot._producer_reuse_eligible(overridden), "world hash override cannot enter concrete reuse")
	check(Snapshot.capture(overridden).is_empty(), "producer respects incompatible world hash override and refuses")
	check(overridden.hash_calls > 0, "producer actually dispatches virtual world.state_hash")
	var passthrough := PassthroughWorld.new()
	_fixture(catalog, passthrough)
	check(not Snapshot._producer_reuse_eligible(passthrough), "ordinary world subclass uses validated fallback")
	var snapshot := Snapshot.capture(passthrough)
	check(not snapshot.is_empty(), "semantically unchanged world override still captures")
	check(passthrough.hash_calls >= 2, "fallback hashes live source during assembly and after detached preparation")
	if not snapshot.is_empty(): equal(snapshot.state_hash, passthrough.state_hash(), "passthrough fallback preserves exact authority hash")


func _test_actor_mutation_refused(catalog: AbilityCatalog) -> void:
	var world := _fixture(catalog)
	var original: PlayerState = world.players[0]
	var actor := MutatingPlayer.new(original.entity_id)
	for field: StringName in Snapshot.PLAYER_SCALAR_FIELDS: actor.set(field, original.get(field))
	actor.spell_wire_ids = original.spell_wire_ids.duplicate()
	actor.spell_cooldown_ticks = original.spell_cooldown_ticks.duplicate()
	actor.court = world.hex_court
	world.players[0] = actor
	check(not Snapshot._producer_reuse_eligible(world), "actor canonical callback excludes outer hash reuse")
	var before: String = world.hex_court.state_hash()
	actor.armed = true
	var snapshot := Snapshot.capture(world)
	check(actor.calls > 0 and not actor.armed, "actor callback executes during real capture")
	check(world.hex_court.conservation_valid(), "callback changes valid counters without corrupting conservation")
	check(world.hex_court.state_hash() != before, "actor callback actually changes live chemistry after its detached encoding")
	check(snapshot.is_empty(), "producer refuses authority changed by actor canonical callback")
	var recovery := Snapshot.capture(world)
	check(not recovery.is_empty(), "disarmed actor fallback can capture the current valid state")
	if not recovery.is_empty(): equal(recovery.state_hash, world.state_hash(), "actor callback refusal does not poison subsequent capture")
	actor.court = null
	world.players[0] = original


func _test_collision_mutation_refused(catalog: AbilityCatalog, wrapped: bool) -> void:
	var world := _fixture(catalog)
	var original: CollisionWorld = (world.collision as HexCollisionWorld).base_world
	var collision := MutatingCollision.new(original.width, original.height)
	for obstacle: CollisionWorld.Obstacle in original.obstacle_view():
		collision.add_obstacle(CollisionWorld.Obstacle.new(obstacle.obstacle_id, obstacle.minimum_x, obstacle.minimum_y, obstacle.maximum_x, obstacle.maximum_y, obstacle.vaultable, obstacle.wall_runnable))
	collision.court = world.hex_court
	if wrapped:
		(world.collision as HexCollisionWorld).base_world = collision
	else:
		world.collision = collision
		world.reaction_movement = ReactionMovementWorld.new(collision)
	world.hex_court.collision = collision
	var label := "wrapped base" if wrapped else "direct collision"
	check(not Snapshot._producer_reuse_eligible(world), label + " virtual obstacle view excludes callback-free reuse")
	var before: String = world.hex_court.state_hash()
	collision.armed = true
	var snapshot := Snapshot.capture(world)
	check(collision.calls > 0 and not collision.armed, label + " callback executes inside real detached preparation")
	check(world.hex_court.conservation_valid(), label + " callback preserves valid conservation")
	check(world.hex_court.state_hash() != before, label + " callback actually changes source after captured hash")
	check(snapshot.is_empty(), label + " late source mutation cannot publish stale reconstructed authority")
	var recovery := Snapshot.capture(world)
	check(not recovery.is_empty(), label + " disarmed fallback remains supported")
	if not recovery.is_empty(): equal(recovery.state_hash, world.state_hash(), label + " recovery captures exact current authority")
	# This test intentionally installs authority -> collision -> authority to
	# exercise a late callback. RefCounted cannot collect that observer cycle.
	collision.court = null
	world.hex_court.collision = original
	if wrapped: (world.collision as HexCollisionWorld).base_world = original


func _test_dynamic_subclass_fallback(catalog: AbilityCatalog) -> void:
	var world := _fixture(catalog)
	var original: HexCollisionWorld = world.collision
	var alternate := AlternateDynamicCollision.new(original.base_world)
	check(alternate.set_hex_surfaces(world.hex_court, world.tick), "dynamic subclass receives identical admitted surfaces")
	world.collision = alternate
	world.reaction_movement = alternate
	check(not Snapshot._producer_reuse_eligible(world), "dynamic collision subclass cannot claim exact concrete receiver admission")
	var before := world.state_hash()
	var snapshot := Snapshot.capture(world)
	check(not snapshot.is_empty(), "unchanged dynamic subclass remains accepted through fallback")
	if not snapshot.is_empty(): equal(snapshot.state_hash, before, "dynamic subclass fallback preserves exact authority")


func _test_opaque_authority_and_obstacle_admission(catalog: AbilityCatalog) -> void:
	var world := _fixture(catalog)
	var key := OpaqueKey.new()
	world.hex_court.metrics[key] = {"nested": [1, 2]}
	check(not Snapshot._producer_reuse_eligible(world), "Object dictionary key excludes callback-free producer admission")
	equal(key.calls, 0, "eligibility detects Object keys without invoking their stringification")
	check(Snapshot.capture(world).is_empty(), "opaque extra authority keeps complete fallback hash refusal")
	check(key.calls > 0, "opaque refusal still executes the existing canonical fallback")
	world.hex_court.metrics.erase(key)
	key.calls = 0
	world.hex_court.metrics.opaque = [{"nested": key}]
	check(not Snapshot._producer_reuse_eligible(world), "deep Object value excludes callback-free producer admission")
	equal(key.calls, 0, "nested admission never formats opaque values")
	world.hex_court.metrics.erase("opaque")
	var deep: Array = []
	var cursor: Array = deep
	for unused: int in range(80):
		var next: Array = []
		cursor.append(next)
		cursor = next
	world.hex_court.metrics.opaque = deep
	check(not Snapshot._producer_reuse_eligible(world), "over-depth plain containers decline reuse without unbounded recursion")
	world.hex_court.metrics.erase("opaque")
	var cyclic: Dictionary = {}
	cyclic.self = cyclic
	world.hex_court.metrics.opaque = cyclic
	check(not Snapshot._producer_reuse_eligible(world), "cyclic caller-owned dictionary declines reuse without recursion failure")
	world.hex_court.metrics.erase("opaque")
	cyclic.clear()
	check(Snapshot._producer_reuse_eligible(world), "corrected same-reference dictionaries are freshly eligible")
	var base: CollisionWorld = (world.collision as HexCollisionWorld).base_world
	base.add_obstacle(AlternateObstacle.new(901, 20_000, 20_000, 40_000, 40_000))
	check(not Snapshot._producer_reuse_eligible(world), "Obstacle subclass cannot introduce getters into callback-free clone")
	var before := world.state_hash()
	var snapshot := Snapshot.capture(world)
	check(not snapshot.is_empty(), "unchanged Obstacle subclass remains valid through fallback")
	if not snapshot.is_empty(): equal(snapshot.state_hash, before, "Obstacle subclass fallback retains exact authority")
