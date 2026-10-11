extends "res://tests/performance/profile_fine_grid_steps.gd"

## Diagnostic subclass; delegates every operation unchanged to production.
class TimedCollision:
	extends HexCollisionWorld
	var effects_phase := false
	var effects_move_us := 0
	var effects_move_calls := 0
	func move_box(position: Vector2i, delta: Vector2i, radius: int) -> MoveResult:
		var started := Time.get_ticks_usec()
		var result := super.move_box(position, delta, radius)
		if effects_phase:
			effects_move_us += Time.get_ticks_usec() - started
			effects_move_calls += 1
		return result

class TimedCourt:
	extends HexChemistryWorld
	var totals := {}
	func _record(label: String, started: int) -> void:
		totals[label] = int(totals.get(label, 0)) + Time.get_ticks_usec() - started
	func select_cells(shape: Dictionary, eligible: Variant = null) -> Array[Vector2i]:
		var started := Time.get_ticks_usec()
		var result := super.select_cells(shape, eligible)
		_record("selection_nested", started)
		return result
	func occupied_cells() -> Dictionary:
		var started := Time.get_ticks_usec()
		var result := super.occupied_cells()
		_record("occupied_nested", started)
		return result
	func move_products(tick: int, physics: CollisionWorld) -> void:
		var started := Time.get_ticks_usec()
		super.move_products(tick, physics)
		_record("move_products", started)
	func apply_product_effects(players: Array[PlayerState], tick: int, config: SimConfig, physics: CollisionWorld, events: Array[Dictionary], paths: Dictionary = {}) -> void:
		var started := Time.get_ticks_usec()
		physics.effects_phase = true
		super.apply_product_effects(players, tick, config, physics, events, paths)
		physics.effects_phase = false
		_record("product_effects", started)
		if tick % 120 == 119:
			print("FINE_GRID_COLLISION_US tick=", tick, " effects_nested=", physics.effects_move_us, " calls=", physics.effects_move_calls)
			physics.effects_move_us = 0
			physics.effects_move_calls = 0
	func advance(players: Array[PlayerState], paths: Dictionary, tick: int, config: SimConfig, events: Array[Dictionary]) -> void:
		var started := Time.get_ticks_usec()
		super.advance(players, paths, tick, config, events)
		_record("advance", started)
		if tick % 120 == 119:
			print("FINE_GRID_STAGE_US tick=", tick, " inclusive_nested=", JSON.stringify(totals))
			totals.clear()

func _fixture(case_name: String) -> Dictionary:
	var fixture := super._fixture(case_name)
	var world: SimWorld = fixture.world
	world.collision = TimedCollision.new(world.collision.base_world)
	world.reaction_movement = world.collision
	var timed := TimedCourt.new()
	_check(timed.configure_geometry(definition.origin, definition.eligible_cells), "timed topology configures")
	timed.chemistry_enabled = true
	timed.collision = world.collision.base_world
	_check(world.collision.set_hex_surfaces(timed, world.tick), "timed wrapper binds same physics")
	world.hex_court = timed
	return fixture
