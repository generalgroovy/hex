extends RefCounted

static var preparation_counts := {"emit": 0, "counts": 0, "parts": 0, "sort": 0, "preflight": 0}


## Optional projectile residue for the unified finite cast ledger. The helper
## runs after terminal consumption, never admits or pays a cast, and never
## resolves chemistry. A source's four cumulative-floor installments move
## 37,38,37,38 of its original 600 units into trail parts, leaving at least
## 450 units in flight for its eventual terminal. This is the finite-ledger
## form of the legacy 250/1000 optional-trail ratio: both allocate exactly25%.
const Parts = preload("res://src/sim/hex/hex_cast_parts.gd")
const Footprint = preload("res://src/sim/hex/hex_footprint.gd")
const Grid = preload("res://src/sim/hex/hex_grid.gd")
const LegacyChemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")

const SAMPLE_TICKS := 8
const SPACING := 28_000
const RADIUS := 20_000
const MAX_OWNER_TRAILS := 4
const MAX_TRAILS := 32
const OPTIONAL_ALLOWANCE := 150
const INSTALLMENTS := 4
const TERMINAL_RESERVE := HexChemistryWorld.MATTER_PER_CAST - OPTIONAL_ALLOWANCE


## Returns the number of admitted trail parts. Refused candidates do not mutate
## their cast record, part ID, layers, metrics, or revision.
static func emit(world: SimWorld, only_family: String = "") -> int:
	preparation_counts.emit += 1
	if world == null or world.config == null or not world.config.is_valid() or not (world.hex_court is HexChemistryWorld):
		return 0
	var authority: HexChemistryWorld = world.hex_court
	if not authority.chemistry_enabled or authority.cell_count() == 0 or world.projectiles.is_empty():
		return 0
	if not _has_sample_candidate(world, only_family):
		return 0
	var counts := _live_trail_counts(authority, world.tick)
	var global_count := int(counts.global)
	var owner_counts: Dictionary = counts.owners
	if global_count >= MAX_TRAILS:
		return 0
	preparation_counts.sort += 1
	var ordered: Array[ProjectileState] = world.projectiles.duplicate()
	ordered.sort_custom(func(left: ProjectileState, right: ProjectileState) -> bool:
		return left.entity_id < right.entity_id)
	var admitted := 0
	for projectile: ProjectileState in ordered:
		if not only_family.is_empty() and HexChemistryWorld.family(projectile.source_wire_id) != only_family: continue
		if HexChemistryWorld.family(projectile.source_wire_id) == "mantle":
			var owner: PlayerState = world.player(projectile.owner_id)
			if owner == null or owner.air_height > 0: continue
		if global_count >= MAX_TRAILS:
			break
		if not _delivery_eligible(projectile) or posmod(world.tick + projectile.entity_id, SAMPLE_TICKS) != 0:
			continue
		var source := projectile.source_cast_id
		if source <= 0 or not authority.sources.has(source):
			continue
		var cast_id := int(authority.sources[source])
		var record: Dictionary = authority.casts.get(cast_id, {})
		if not _provenance_valid(record, projectile) or not Parts.validate(record):
			continue
		var owner_count := int(owner_counts.get(projectile.owner_id, 0))
		if owner_count >= MAX_OWNER_TRAILS:
			continue
		var installment := _next_installment(int(record.get("trail_spent", 0)))
		if installment <= 0:
			continue
		var branch_quantity := int(record.flight_parts.get(projectile.entity_id, 0))
		var aggregate_flight := int(record.ledger.flight_quantity)
		if branch_quantity < installment or aggregate_flight - installment < TERMINAL_RESERVE:
			continue
		var point := Vector2i(projectile.position_x, projectile.position_y)
		if not _trusted_point(authority, point) or _too_close(record, point, world.tick):
			continue
		var shape := Footprint.disk(point, RADIUS)
		var selected := authority.select_cells(shape)
		if selected.is_empty():
			continue
		var element := int(record.element)
		if element < 1 or element >= LegacyChemistry.TRAIL_LIFE_MS.size():
			continue
		var lifetime := HexChemistryWorld.trail_lifetime(element)
		if lifetime <= 0:
			continue
		var prior_ground := int(record.ground)
		var part_id := authority.next_ground_part_id
		var previous_cells: Array = record.cells.keys()
		var moved := Parts.deposit_flight(record, projectile.entity_id, part_id, selected, shape,
			world.tick, world.tick + lifetime, true, installment)
		if moved != installment:
			continue
		authority.next_ground_part_id += 1
		record.trail_spent = int(record.get("trail_spent", 0)) + moved
		if prior_ground == 0:
			record.created = world.tick
		var direction := SimCommand._normalized_direction(projectile.velocity_x, projectile.velocity_y)
		if direction != Vector2i.ZERO:
			record.aim = direction
		record.footprint = shape
		record.expires = maxi(int(record.expires), world.tick + lifetime)
		authority._sync_cast_ledger(record)
		authority._rebuild_cast_layers(record, previous_cells)
		authority.metrics.deposited += 1
		authority.value_revision += 1
		global_count += 1
		owner_counts[projectile.owner_id] = owner_count + 1
		admitted += 1
	return admitted


## Persistent-field consumers use this union to exclude every trail-only cell.
## The returned map is detached and never mutates the source record.
static func terminal_coverage(record: Dictionary) -> Dictionary:
	return _part_coverage(record, -1, false)


## Incoming terminals may contact a trail only when that trail was created on a
## strictly earlier tick. Callers must not use this helper for trail arrivals.
static func contact_coverage(record: Dictionary, incoming_created: int) -> Dictionary:
	if incoming_created < 0:
		return {}
	return _part_coverage(record, incoming_created, true)


static func _delivery_eligible(projectile: ProjectileState) -> bool:
	if projectile == null or projectile.entity_id <= 0:
		return false
	return HexChemistryWorld.family(projectile.source_wire_id) in ["bolt", "heavy", "mantle"]


static func _provenance_valid(record: Dictionary, projectile: ProjectileState) -> bool:
	return (
		not record.is_empty()
		and bool(record.get("paid", false))
		and int(record.get("source", 0)) == projectile.source_cast_id
		and int(record.get("wire", 0)) == projectile.source_wire_id
		and int(record.get("element", 0)) == projectile.element_wire_id
		and int(record.get("owner", 0)) == projectile.owner_id
		and int(record.get("team", 0)) == projectile.team_id
		and int(record.get("strength", 0)) == projectile.reaction_strength
		and record.get("flight_parts", {}) is Dictionary
		and (record.flight_parts as Dictionary).has(projectile.entity_id)
	)


## Cumulative floors over 150/4 yield 37,38,37,38. Only a prior installment
## boundary is eligible, so malformed counters cannot create a fifth fragment.
static func _next_installment(spent: int) -> int:
	if spent < 0 or spent >= OPTIONAL_ALLOWANCE:
		return 0
	for index: int in range(INSTALLMENTS):
		@warning_ignore("integer_division")
		var lower := index * OPTIONAL_ALLOWANCE / INSTALLMENTS
		@warning_ignore("integer_division")
		var upper := (index + 1) * OPTIONAL_ALLOWANCE / INSTALLMENTS
		if spent == lower:
			return upper - lower
	return 0


static func _trusted_point(authority: HexChemistryWorld, point: Vector2i) -> bool:
	var local := point - authority.origin
	return Grid._query_point_valid(local) and authority.has_cell(Grid.world_to_cell(local))


static func _too_close(record: Dictionary, point: Vector2i, tick: int) -> bool:
	var minimum_squared := SPACING * SPACING
	for part_value: Variant in record.get("ground_parts", {}).values():
		if not part_value is Dictionary:
			continue
		var part: Dictionary = part_value
		if not bool(part.get("trail", false)) or tick >= int(part.get("expiry_tick", 0)):
			continue
		var shape_value: Variant = part.get("footprint", {})
		if not shape_value is Dictionary:
			continue
		var shape: Dictionary = shape_value
		if String(shape.get("kind", "")) != Footprint.KIND_DISK or not shape.get("center") is Vector2i:
			continue
		var offset: Vector2i = point - Vector2i(shape.center)
		if offset.x * offset.x + offset.y * offset.y < minimum_squared:
			return true
	return false


static func _live_trail_counts(authority: HexChemistryWorld, tick: int) -> Dictionary:
	preparation_counts.counts += 1
	var global_count := 0
	var owners := {}
	for cast_id: int in authority.casts:
		var record: Dictionary = authority.casts[cast_id]
		for part_value: Variant in record.get("ground_parts", {}).values():
			preparation_counts.parts += 1
			if not part_value is Dictionary:
				continue
			var part: Dictionary = part_value
			if not bool(part.get("trail", false)) or tick >= int(part.get("expiry_tick", 0)):
				continue
			global_count += 1
			var owner := int(record.get("owner", 0))
			owners[owner] = int(owners.get(owner, 0)) + 1
	return {"global": global_count, "owners": owners}


static func _part_coverage(record: Dictionary, incoming_created: int, include_older_trails: bool) -> Dictionary:
	var result := {}
	var parts_value: Variant = record.get("ground_parts", {})
	if not parts_value is Dictionary:
		return result
	var part_ids: Array = (parts_value as Dictionary).keys()
	part_ids.sort()
	for part_id: Variant in part_ids:
		var part_value: Variant = (parts_value as Dictionary)[part_id]
		if not part_value is Dictionary:
			continue
		var part: Dictionary = part_value
		var is_trail := bool(part.get("trail", false))
		if is_trail and (not include_older_trails or int(part.get("created", incoming_created)) >= incoming_created):
			continue
		var coverage_value: Variant = part.get("coverage", {})
		if not coverage_value is Dictionary:
			continue
		for cell_value: Variant in (coverage_value as Dictionary):
			if cell_value is Vector2i and int((coverage_value as Dictionary)[cell_value]) == 1:
				result[cell_value] = 1
	return result


## Ignored preflight: positive path below remains the complete predecessor.
static func _has_sample_candidate(world: SimWorld, only_family: String) -> bool:
	for projectile: ProjectileState in world.projectiles:
		preparation_counts.preflight += 1
		if projectile == null: continue
		if not only_family.is_empty() and HexChemistryWorld.family(projectile.source_wire_id) != only_family: continue
		if HexChemistryWorld.family(projectile.source_wire_id) == "mantle":
			var owner: PlayerState = world.player(projectile.owner_id)
			if owner == null or owner.air_height > 0: continue
		if not _delivery_eligible(projectile) or posmod(world.tick + projectile.entity_id, SAMPLE_TICKS) != 0: continue
		return true
	return false
