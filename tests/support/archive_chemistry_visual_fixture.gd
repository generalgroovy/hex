extends RefCounted
# Historical visual-fixture construction only. Extracted from the byte-preserved
# pre-six kernel; no step/damage/authority admission is included or advertised.
# Frozen art identity is separately validated by ArchiveMagicContract.
const Core = preload("res://src/sim/chemistry/element_chemistry_system.gd")
const Deposit = preload("res://src/sim/chemistry/element_deposit_state.gd")
const Reaction = preload("res://src/sim/chemistry/element_reaction_state.gd")
const Archive = preload("res://src/presentation/archive_magic_contract.gd")
const ELEMENTS := ["", "earth", "fire", "water", "wind", "ice", "charge", "light", "dark"]
const TRAIL_SPACING = Core.TRAIL_SPACING
const MAX_TRAILS = Core.MAX_TRAILS
const MAX_OWNER_TRAILS = Core.MAX_OWNER_TRAILS
const MAX_DEPOSITS = Core.MAX_DEPOSITS
const MAX_OWNER_DEPOSITS = Core.MAX_OWNER_DEPOSITS
const TRAIL_STRENGTH = Core.TRAIL_STRENGTH
const TRAIL_RADIUS = Core.TRAIL_RADIUS
const TRAIL_LIFE_MS = Core.TRAIL_LIFE_MS
const ELEMENT_LIFE_MS = Core.ELEMENT_LIFE_MS
const TRAIL_SUSTAIN_RATIO = Core.TRAIL_SUSTAIN_RATIO

static func recipe(wire_id: int) -> Dictionary:
	if wire_id < 301 or wire_id > 336: return {}
	var row: Dictionary = Archive.REACTIONS[wire_id - 301]
	var display_name := "Rampart" if wire_id == 301 else "Frostway" if wire_id == 327 else "Capacitor" if wire_id == 331 else String(row.id).replace("_", " ").capitalize()
	return {"id":row.id,"name":display_name,"wire_id":wire_id,"elements":[ELEMENTS.find(row.elements[0]),ELEMENTS.find(row.elements[1])],"shape":row.shape,"formation_ms":row.formation_ms,"active_ms":row.active_ms,"decay_ms":row.decay_ms,"radius":roundi(float(row.nominal_radius_px)*1000.0),"length":roundi(float(row.nominal_length_px)*1000.0),"speed":roundi(float(row.speed_px_per_second)*1000.0),"pulse_ms":row.pulse_ms,"health":int(row.cover_health)*1000}

static func recipe_wire(element_a: int, element_b: int) -> int:
	for row: Dictionary in Archive.REACTIONS:
		var first := ELEMENTS.find(row.elements[0])
		var second := ELEMENTS.find(row.elements[1])
		if mini(element_a,element_b)==first and maxi(element_a,element_b)==second: return int(row.wire_id)
	return 0

static func deposit_terminal(deposits: Array, entity_id: int, cast_id: int, spell_id: int, owner: int, team: int, element: int, position: Vector2i, tick: int, config: SimConfig, direction: Vector2i = Vector2i(1000,0), strength: int = 1000, flight_trail: bool = false, reaction_strength: int = 1) -> int:
	if config == null or entity_id <= 0 or cast_id <= 0 or element < 1 or element > 8 or strength <= 0 or strength > 1000 or reaction_strength < 1 or reaction_strength > 15:
		return -1
	var owner_count := 0
	var owner_trails := 0
	var trail_count := 0
	var promoted: ElementDepositState = null
	var coalesces := false
	for existing: ElementDepositState in deposits:
		if existing.owner_id == owner:
			owner_count += 1
		if existing.is_trail():
			trail_count += 1
			if existing.owner_id == owner:
				owner_trails += 1
		if existing.source_cast_id != cast_id:
			continue
		# Check every sibling before returning a coalesced result or mutating a
		# trail. Material quantity may differ, but cast strength may not.
		if existing.reaction_strength != reaction_strength:
			return -1
		var point := Vector2i(existing.position_x, existing.position_y)
		if flight_trail:
			if (point - position).length_squared() < TRAIL_SPACING * TRAIL_SPACING:
				coalesces = true
		elif cell(point) == cell(position):
			# Real impact replaces a same-cell narrow trail exactly once. A
			# second real impact still coalesces without refreshing its lifetime.
			if not existing.is_trail():
				coalesces = true
			if promoted == null:
				promoted = existing
	if coalesces:
		return 0
	if flight_trail and (trail_count >= MAX_TRAILS or owner_trails >= MAX_OWNER_TRAILS):
		return -1
	if promoted == null and (deposits.size() >= MAX_DEPOSITS or owner_count >= MAX_OWNER_DEPOSITS):
		return -1
	if promoted != null:
		# New identity disconnects any older reaction path linked to the trail;
		# the impact must not move or extend an existing conductor in place.
		deposits.erase(promoted)
	var result := Deposit.new()
	result.entity_id = entity_id
	result.source_cast_id = cast_id
	result.reaction_strength = reaction_strength
	result.source_wire_id = spell_id
	result.owner_id = owner
	result.team_id = team
	result.element_wire_id = element
	result.position_x = position.x
	result.position_y = position.y
	var normalized := SimCommand._normalized_direction(direction.x, direction.y)
	result.direction_x = normalized.x if normalized != Vector2i.ZERO else 1000
	result.direction_y = normalized.y
	result.strength = mini(strength, TRAIL_STRENGTH) if flight_trail else strength
	result.radius = TRAIL_RADIUS if flight_trail else terminal_radius(strength)
	result.created_tick = tick
	result.expiry_tick = tick + config.milliseconds_to_ticks(TRAIL_LIFE_MS[element] if flight_trail else ELEMENT_LIFE_MS[element])
	deposits.append(result)
	deposits.sort_custom(func(a: ElementDepositState,b: ElementDepositState) -> bool: return a.entity_id < b.entity_id)
	return 1

static func form_reaction(a: ElementDepositState,b: ElementDepositState,entity_id: int,tick: int,config: SimConfig) -> ElementReactionState:
	var result := Reaction.new()
	result.entity_id = entity_id
	result.recipe_wire_id = recipe_wire(a.element_wire_id,b.element_wire_id)
	var definition := recipe(result.recipe_wire_id)
	var origin := midpoint(Vector2i(a.position_x,a.position_y),Vector2i(b.position_x,b.position_y))
	result.position_x = origin.x
	result.position_y = origin.y
	result.origin_x = origin.x
	result.origin_y = origin.y
	# Oldest stable source owns the result; pair ordering does not change this.
	var source: ElementDepositState = a if a.entity_id < b.entity_id else b
	result.owner_id = source.owner_id
	result.team_id = source.team_id
	result.direction_x = source.direction_x
	result.direction_y = source.direction_y
	result.source_a = mini(a.source_cast_id,b.source_cast_id)
	result.source_b = maxi(a.source_cast_id,b.source_cast_id)
	result.created_tick = tick
	result.active_tick = tick + config.milliseconds_to_ticks(int(definition["formation_ms"]))
	var active_ms := int(definition["active_ms"])
	# Trail-assisted recipes retain identity/geometry and their warning window,
	# but sustained effects have 60% uptime. Instant windows are not multiplied.
	if (a.is_trail() or b.is_trail()) and active_ms >= 1000:
		active_ms = active_ms * TRAIL_SUSTAIN_RATIO / 1000
	result.decay_tick = result.active_tick + config.milliseconds_to_ticks(active_ms)
	result.expiry_tick = result.decay_tick + config.milliseconds_to_ticks(int(definition["decay_ms"]))
	result.radius = int(definition["radius"])
	result.length = int(definition["length"])
	result.health = int(definition["health"])
	result.capacity = 36_000 if result.recipe_wire_id == 306 else 0
	var endpoint := origin + scaled(Vector2i(result.direction_x,result.direction_y),result.length)
	result.endpoint_x = endpoint.x
	result.endpoint_y = endpoint.y
	return result

static func extent(value: int) -> int:
	return Core.extent(value)

static func terminal_radius(value: int) -> int:
	return Core.terminal_radius(value)

static func cell(point: Vector2i) -> Vector2i:
	return Core.cell(point)

static func midpoint(a: Vector2i, b: Vector2i) -> Vector2i:
	return Core.midpoint(a,b)

static func scaled(direction: Vector2i, amount: int) -> Vector2i:
	return Core.scaled(direction,amount)

static func rampart_bounds(state: ElementReactionState) -> Rect2i:
	return Core.rampart_bounds(state)

static func _concealing(state: ElementReactionState, tick: int, config: SimConfig) -> bool:
	return Core._concealing(state,tick,config)

static func contains(state: ElementReactionState, point: Vector2i, tick: int, config: SimConfig) -> bool:
	return Core.contains(state,point,tick,config)

static func clear_line(a: Vector2i, b: Vector2i, collision: CollisionWorld) -> bool:
	return Core.clear_line(a,b,collision)

static func deposit_from_archive_values(values: PackedInt64Array) -> ElementDepositState:
	if values.size()!=15: return null
	var result := Deposit.new()
	var fields: Array[String]=["entity_id","source_cast_id","source_wire_id","owner_id","team_id","element_wire_id","position_x","position_y","direction_x","direction_y","radius","strength","created_tick","expiry_tick","reaction_strength"]
	for index: int in fields.size(): result.set(fields[index],values[index])
	return result if result.validate_archive() else null
