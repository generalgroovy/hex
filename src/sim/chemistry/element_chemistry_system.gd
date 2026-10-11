class_name ElementChemistrySystem
extends RefCounted
@warning_ignore_start("integer_division")

const Deposit = preload("res://src/sim/chemistry/element_deposit_state.gd")
const Reaction = preload("res://src/sim/chemistry/element_reaction_state.gd")
const MAX_DEPOSITS: int = 128
const MAX_REACTIONS: int = 32
const MAX_OWNER_DEPOSITS: int = 16
const MAX_TRACKED_ACTORS: int = 16
const MAX_LINKS: int = 4
const CELL_SIZE: int = 96_000
# More time to combine matter; still bounded by the existing five-second wire limit.
const ELEMENT_LIFE_MS: Array[int] = [0, 5000, 4000, 5000, 3000, 5000, 3000, 4000, 4000]
const TRAIL_LIFE_MS: Array[int] = [0, 1500, 1100, 1400, 800, 1400, 800, 1200, 1300]
const TRAIL_RADIUS: int = Deposit.TRAIL_RADIUS
const EXTENT_RATIO: int = 1250
const TRAIL_STRENGTH: int = 250
const TRAIL_SPACING: int = 28000
const TRAIL_SAMPLE_TICKS: int = 8
const MAX_OWNER_TRAILS: int = 4
const MAX_TRAILS: int = 32
const TRAIL_CAST_RESERVE: int = 2
const TRAIL_SUSTAIN_RATIO: int = 600

static func movement_surface_policy() -> Dictionary:
	return {"version": 2, "recipe": 301, "name": "Rampart", "footprint": "cardinal_rectangle", "length": extent(64000), "thickness": extent(36000), "orientation": "dominant_cast_axis_x_ties", "solid": "active_living_only", "overlap": "escape_until_clear_then_block_reentry", "wall_clearance": 18000, "prediction": "exact_authority_tick_rows_v1", "surface_id_base": 100000000}

static func extent(base: int) -> int:
	return base * EXTENT_RATIO / 1000

static func terminal_radius(strength: int) -> int:
	return Deposit.TERMINAL_MIN_RADIUS + strength * (Deposit.TERMINAL_MAX_RADIUS - Deposit.TERMINAL_MIN_RADIUS) / 1000

static func extent_policy() -> Dictionary:
	return {"version": 1, "linear_ratio": EXTENT_RATIO, "terminal_min": Deposit.TERMINAL_MIN_RADIUS, "terminal_max": Deposit.TERMINAL_MAX_RADIUS, "trail_radius": TRAIL_RADIUS, "reaction_max_radius": Reaction.MAX_RADIUS, "reaction_max_length": Reaction.MAX_LENGTH, "hail_pulse_radius": extent(25000), "grow_duration_ms": {"steam": 900, "freeze": 1200}, "damage_lifetime_cost_speed_unchanged": true}

static func rampart_bounds(result: ElementReactionState) -> Rect2i:
	var half_size := Vector2i(extent(18000), extent(32000)) if absi(result.direction_x) >= absi(result.direction_y) else Vector2i(extent(32000), extent(18000))
	return Rect2i(Vector2i(result.position_x, result.position_y) - half_size, half_size * 2)

static func trail_policy() -> Dictionary:
	return {"version": 5, "rapid_trails": false, "one_payload_per_cast": true, "trail_predates_impact": true, "life_ms": TRAIL_LIFE_MS, "radius": TRAIL_RADIUS, "strength": TRAIL_STRENGTH,
		"spacing": TRAIL_SPACING, "sample_ticks": TRAIL_SAMPLE_TICKS, "owner_cap": MAX_OWNER_TRAILS,
		"global_cap": MAX_TRAILS, "cast_reserve": TRAIL_CAST_RESERVE, "sustain_ratio": TRAIL_SUSTAIN_RATIO,
		"needs_terminal_partner": true, "terminal_promotes_same_cell_trail": true,
		"own_trail_reclamation": "successful_whole_cast_oldest_created_then_entity_id",
		"reclaim_terminal": false, "reclaim_nonexpired_reaction_links": false}
# Stable recipe order is the authored table, not dictionary order. Geometry,
# timing and executable rule identities belong to simulation, never rendering.
const RECIPE_ROWS: Array = [
	["fortify",1,1,"cover",180,3125,400,18000,64000,0,0,32],
	["magma",1,2,"front",350,2750,500,24000,80000,30000,400,0],
	["mud",1,3,"disk",200,3250,350,62000,0,0,0,0],
	["dustfront",1,4,"corridor",250,2250,350,28000,120000,38000,0,0],
	["permafrost",1,5,"cover",240,3000,650,14000,80000,0,0,18],
	["grounding_network",1,6,"node",250,3250,300,38000,0,0,0,16],
	["crystal_prism",1,7,"plane",400,2750,400,8000,70000,0,0,18],
	["blightsoil",1,8,"disk",300,3000,400,54000,0,0,0,0],
	["conflagration",2,2,"ring",400,3000,400,72000,24000,0,600,0],
	["steam",2,3,"expanding_veil",240,2625,500,90000,0,0,0,0],
	["firestorm",2,4,"corridor",350,2250,350,18000,130000,68000,350,0],
	["thermal_shock",2,5,"fracture",600,100,550,90000,0,0,0,0],
	["plasma_arc",2,6,"branch",450,120,400,10000,180000,0,0,0],
	["solar_flare",2,7,"reveal_pulse",220,100,650,100000,0,0,0,0],
	["cinderveil",2,8,"ember_veil",300,3000,400,56000,0,0,350,0],
	["flood",3,3,"flow",220,3125,350,64000,0,0,0,0],
	["mistcurrent",3,4,"corridor",220,2750,400,25000,160000,25000,0,0],
	["freeze",3,5,"growing_strip",300,2500,350,16000,140000,0,0,0],
	["conductive_flood",3,6,"water_path",500,2625,350,20000,180000,0,600,0],
	["mirrorwater",3,7,"observation",220,3250,350,55000,0,0,0,0],
	["blackwater",3,8,"motion_veil",260,3000,400,62000,0,0,0,0],
	["vortex",4,4,"annulus",400,2750,400,72000,24000,0,0,0],
	["hailstream",4,5,"pulse_lane",400,2813,350,14000,180000,0,450,0],
	["ion_storm",4,6,"drifting_node",450,2625,400,40000,0,22000,700,0],
	["lightbend",4,7,"bend",250,3000,300,45000,0,0,0,0],
	["shadowdraft",4,8,"bands",300,3000,350,30000,150000,30000,300,0],
	["glacier",5,5,"corridor",650,3500,600,24000,160000,0,0,0],
	["superconduct",5,6,"frost_path",500,2250,350,8000,260000,0,900,0],
	["crystal_lens",5,7,"lens",450,2875,400,18000,60000,0,0,20],
	["black_ice",5,8,"entry_mark",300,3125,400,54000,0,0,0,0],
	["overload",6,6,"corridor",650,2000,450,24000,160000,0,0,0],
	["arcflash",6,7,"reveal_line",300,140,400,12000,180000,0,0,0],
	["static_shroud",6,8,"entry_veil",320,2750,400,58000,0,0,0,0],
	["radiance",7,7,"reveal_area",300,3125,400,78000,0,0,0,0],
	["penumbra",7,8,"border",220,3000,250,66000,0,0,0,0],
	["umbral_field",8,8,"attrition_veil",350,3500,450,74000,0,0,600,0],
]

static func recipe(wire_id: int) -> Dictionary:
	var live := HexRecipePolicy.definition(wire_id)
	if live.is_empty(): return {}
	return {"id": live.id, "name": live.name, "wire_id": wire_id, "elements": live.elements,
		"shape": live.geometry_kind, "formation_ms": int(live.formation_ticks) * 1000 / 120,
		"active_ms": int(live.active_ticks) * 1000 / 120, "decay_ms": int(live.decay_ticks) * 1000 / 120,
		"radius": live.radius, "length": live.length, "speed": 0, "pulse_ms": int(live.pulse_ticks) * 1000 / 120, "health": live.health}


static func recipe_wire(element_a: int, element_b: int) -> int:
	return HexRecipePolicy.recipe_wire(element_a, element_b)


static func deposit_terminal(deposits: Array, entity_id: int, cast_id: int, spell_id: int, owner: int, team: int, element: int, position: Vector2i, tick: int, config: SimConfig, direction: Vector2i = Vector2i(1000,0), strength: int = 1000, flight_trail: bool = false, reaction_strength: int = 1) -> int:
	if config == null or entity_id <= 0 or cast_id <= 0 or element not in [1, 2, 3, 4, 7, 8] or strength <= 0 or strength > 1000 or reaction_strength < 1 or reaction_strength > 15:
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

static func step(deposits: Array, reactions: Array, actors: Array, collision: CollisionWorld, config: SimConfig, tick: int, next_reaction_id: int, events: Array) -> int:
	for index: int in range(deposits.size()-1,-1,-1):
		if tick >= int(deposits[index].expiry_tick) or int(deposits[index].strength) <= 0:
			deposits.remove_at(index)
	for index: int in range(reactions.size()-1,-1,-1):
		if tick >= int(reactions[index].expiry_tick):
			reactions.remove_at(index)
	deposits.sort_custom(func(a: ElementDepositState,b: ElementDepositState) -> bool: return a.entity_id < b.entity_id)
	reactions.sort_custom(func(a: ElementReactionState,b: ElementReactionState) -> bool: return a.entity_id < b.entity_id)
	var occupied := {}
	for existing: ElementReactionState in reactions:
		occupied[cell(Vector2i(existing.origin_x,existing.origin_y))] = true
	# 128 inputs bound this exhaustive admission scan to 8128 pair tests; only
	# two finite inputs are consumed when a result slot is actually reserved.
	for left: int in range(deposits.size()):
		if reactions.size() >= MAX_REACTIONS or actors.size() > MAX_TRACKED_ACTORS:
			break
		var a: ElementDepositState = deposits[left]
		if a.strength <= 0:
			continue
		var a_is_trail := a.is_trail()
		var a_source_cast_id := a.source_cast_id
		var a_created_tick := a.created_tick
		var apos := Vector2i(a.position_x,a.position_y)
		var a_radius := a.radius
		for right: int in range(left+1,deposits.size()):
			var b: ElementDepositState = deposits[right]
			if b.strength <= 0 or a_source_cast_id == b.source_cast_id or a.reaction_strength != b.reaction_strength or (a_is_trail and b.is_trail()):
				continue
			# A new impact can cash in an older trail. A passing projectile's
			# fresh trail must not detonate an already-placed terminal ingredient.
			if (a_is_trail and b.created_tick <= a_created_tick) or (b.is_trail() and a_created_tick <= b.created_tick):
				continue
			var bpos := Vector2i(b.position_x,b.position_y)
			var reach := a_radius + b.radius
			if (apos-bpos).length_squared() > reach*reach:
				continue
			var center := midpoint(apos,bpos)
			if occupied.has(cell(center)):
				continue
			# A reserved cell cannot form another result, regardless of LOS.
			# Preserve pair order while avoiding its bounded collision sampling.
			if not clear_line(apos,bpos,collision):
				continue
			var wire := recipe_wire(a.element_wire_id,b.element_wire_id)
			if wire == 0:
				continue
			var result := form_reaction(a,b,next_reaction_id,tick,config)
			_build_path(result,deposits,collision)
			reactions.append(result)
			occupied[cell(center)] = true
			# Fragments share a single paid chemistry payload; no leftover
			# sibling/flight ingredients may form additional free reactions.
			for fragment: ElementDepositState in deposits:
				if fragment.source_cast_id == a_source_cast_id or fragment.source_cast_id == b.source_cast_id:
					fragment.strength = 0
			next_reaction_id += 1
			events.append({"type":"chemistry_formed","reaction_id":result.entity_id,"recipe_wire_id":wire,"owner_id":result.owner_id})
			break
	for index: int in range(deposits.size()-1,-1,-1):
		if int(deposits[index].strength) <= 0:
			deposits.remove_at(index)
	var ordered := actors.duplicate()
	ordered.sort_custom(func(a: PlayerState,b: PlayerState) -> bool: return a.entity_id < b.entity_id)
	for result: ElementReactionState in reactions:
		_update_geometry(result,collision,config,tick)
		if not result.active(tick):
			continue
		_apply_result(result,deposits,reactions,ordered,collision,config,tick,events)
	return next_reaction_id

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

static func _update_geometry(result: ElementReactionState,collision: CollisionWorld,config: SimConfig,tick: int) -> void:
	var definition := recipe(result.recipe_wire_id)
	var age := maxi(0,mini(tick,result.decay_tick)-result.active_tick)
	var direction := Vector2i(result.direction_x,result.direction_y)
	@warning_ignore("integer_division")
	var travel: int = int(definition["speed"]) * age / config.tick_rate
	var origin := Vector2i(result.origin_x,result.origin_y)
	var target := origin + scaled(direction,travel)
	if collision != null:
		target = collision.move_box(origin,target-origin,1000).position
	result.position_x = target.x
	result.position_y = target.y
	if result.recipe_wire_id == 310:
		result.radius = mini(extent(90000),extent(30000) + age*extent(60000)/maxi(1,config.milliseconds_to_ticks(900)))
	if result.recipe_wire_id == 318:
		result.length = mini(extent(140000),extent(20000) + age*extent(120000)/maxi(1,config.milliseconds_to_ticks(1200)))
	if int(definition["speed"]) > 0 or result.recipe_wire_id == 318:
		var endpoint := target + scaled(direction,result.length)
		result.endpoint_x = endpoint.x
		result.endpoint_y = endpoint.y

static func _build_path(result: ElementReactionState,deposits: Array,collision: CollisionWorld) -> void:
	var material := 3 if result.recipe_wire_id == 319 else 5 if result.recipe_wire_id == 328 else 6 if result.recipe_wire_id == 313 else 0
	if material == 0:
		return
	var previous := Vector2i(result.position_x,result.position_y)
	result.path_points.append_array(PackedInt64Array([previous.x,previous.y]))
	for unused: int in range(1 if material == 6 else MAX_LINKS):
		var best: ElementDepositState = null
		var best_distance := result.length*result.length + 1
		for deposit: ElementDepositState in deposits:
			if deposit.element_wire_id != material or deposit.source_cast_id in [result.source_a,result.source_b] or result.linked_deposit_ids.has(deposit.entity_id) or deposit.strength <= 0:
				continue
			var point := Vector2i(deposit.position_x,deposit.position_y)
			var distance := (point-previous).length_squared()
			if distance < best_distance and clear_line(previous,point,collision):
				best = deposit
				best_distance = distance
		if best == null:
			break
		previous = Vector2i(best.position_x,best.position_y)
		result.linked_deposit_ids.append(best.entity_id)
		result.path_points.append_array(PackedInt64Array([previous.x,previous.y]))
	result.endpoint_x = previous.x
	result.endpoint_y = previous.y

static func _links_alive(result: ElementReactionState,deposits: Array) -> bool:
	for id: int in result.linked_deposit_ids:
		var found := false
		for deposit: ElementDepositState in deposits:
			if deposit.entity_id == id and deposit.strength > 0:
				found = true
				break
		if not found:
			return false
	return true

static func _apply_result(result: ElementReactionState,deposits: Array,reactions: Array,actors: Array,collision: CollisionWorld,config: SimConfig,tick: int,events: Array) -> void:
	var definition := recipe(result.recipe_wire_id)
	var wire := result.recipe_wire_id
	var height_policy := HexRecipePolicy.definition(wire)
	var age := tick-result.active_tick
	var period := config.milliseconds_to_ticks(int(definition["pulse_ms"]))
	@warning_ignore("integer_division")
	var pulse: int = age/maxi(1,period)
	var new_pulse := pulse != result.pulse_index and (period > 0 or result.pulse_index < 0)
	if new_pulse:
		result.pulse_index = pulse
	if wire == 312 and new_pulse:
		for cover: ElementReactionState in reactions:
			# Forming/decaying silhouettes are not active cover. Breaking one before
			# activation would also put decay before active_tick in canonical state.
			if cover.active(tick) and cover.health > 0 and contains(result,Vector2i(cover.position_x,cover.position_y),tick,config) and clear_line(Vector2i(result.position_x,result.position_y),Vector2i(cover.position_x,cover.position_y),collision):
				cover.health = maxi(0,cover.health-30_000)
				if cover.health == 0:
					cover.decay_tick = mini(cover.decay_tick,tick)
	var connected := _links_alive(result,deposits)
	for actor: PlayerState in actors:
		if actor.health <= 0:
			continue
		var point := Vector2i(actor.position_x,actor.position_y)
		var inside := contains(result,point,tick,config) and clear_line(Vector2i(result.position_x,result.position_y),point,collision)
		var contact := _contact_index(result,actor.entity_id)
		var was_inside := contact >= 0 and result.contacts[contact+2] == 1
		var entered := inside and not was_inside
		var exited := not inside and was_inside
		if entered and contact < 0 and result.contacts.size() < MAX_TRACKED_ACTORS*3:
			contact = result.contacts.size()
			result.contacts.append_array(PackedInt64Array([actor.entity_id,tick,1]))
		if contact >= 0:
			if entered:
				result.contacts[contact+1] = tick
			result.contacts[contact+2] = 1 if inside else 0
		var occupied_age := tick-int(result.contacts[contact+1]) if contact >= 0 else 0
		var moving := absi(actor.velocity_x)+absi(actor.velocity_y) > 2000
		if wire in [333,335] and (entered or exited):
			actor.chemistry_reveal_ticks = maxi(actor.chemistry_reveal_ticks,config.milliseconds_to_ticks(120 if wire == 333 else 250))
		if not inside:
			continue
		if _concealing(result,tick,config):
			actor.chemistry_conceal_ticks = maxi(actor.chemistry_conceal_ticks,2)
		if wire == 334 or (wire == 314 and new_pulse) or (wire == 332 and new_pulse) or (wire == 320 and (moving or entered)) or (wire in [321,336] and moving) or (wire == 330 and entered):
			actor.chemistry_reveal_ticks = maxi(actor.chemistry_reveal_ticks,config.milliseconds_to_ticks(700 if wire in [314,332] else 250) if wire != 334 else 2)
		if actor.team_id == result.team_id or actor.spawn_protection_ticks > 0 or MovementSystem.is_combat_intangible(actor, config):
			continue
		var grounded := not MovementSystem.avoids_ground_effects(actor)
		if not bool(height_policy.get("ground_only", false)) and actor.wall_skim_ticks <= 0 and actor.air_height > int(height_policy.get("maximum_height", 256_000)):
			continue
		if wire == 308:
			actor.chemistry_regen_block_ticks = maxi(actor.chemistry_regen_block_ticks,2)
		if grounded and (wire == 303 or (wire == 318 and entered) or (wire == 330 and occupied_age >= config.milliseconds_to_ticks(350))):
			MovementSystem.apply_control_state(actor,PlayerState.ControlState.SLOWED,25 if wire == 303 else 250,Vector2i.ZERO,0,config,700 if wire == 303 else 650)
		if grounded and wire in [304,316,322]:
			var push := Vector2i(result.direction_x,result.direction_y)
			if wire == 322:
				var radial := SimCommand._normalized_direction(point.x-result.position_x,point.y-result.position_y)
				push = Vector2i(-radial.y,radial.x)
			elif wire == 304:
				push = Vector2i(-push.y,push.x)
			var amount := config.per_tick(45000 if wire == 322 else 40000 if wire == 316 else 25000)
			var moved := collision.move_box(point,scaled(push,amount),MovementTuning.PLAYER_RADIUS).position if collision != null else point+scaled(push,amount)
			actor.position_x = moved.x
			actor.position_y = moved.y
		var damage := 0
		if new_pulse or (wire == 323 and entered):
			match wire:
				302: damage = 5 if grounded else 0
				309: damage = 8 if grounded else 0
				311: damage = 4
				313: damage = 9 if connected and result.linked_deposit_ids.size() > 0 else 0
				315: damage = 3 if occupied_age >= config.milliseconds_to_ticks(500) else 0
				319: damage = 6 if connected else 0
				323: damage = 3
				324: damage = 5
				328: damage = 8 if connected and result.linked_deposit_ids.size() > 0 else 0
				336: damage = 2 if occupied_age >= config.milliseconds_to_ticks(1000) else 0
		damage *= SimConfig.FIXED_SCALE
		var health_before := actor.health
		if damage > 0 and PlayerResourcesSystem.damage(actor,damage,config):
			events.append({"type":"chemistry_hit","reaction_id":result.entity_id,"owner_id":result.owner_id,"target_id":actor.entity_id,"damage":health_before - actor.health})
			if actor.health == 0 and actor.actor_kind == PlayerState.ActorKind.CHAMPION:
				events.append({"type":"champion_defeated","projectile_id":0,"owner_id":result.owner_id,"target_id":actor.entity_id})

static func _contact_index(result: ElementReactionState,actor_id: int) -> int:
	for index: int in range(0,result.contacts.size(),3):
		if result.contacts[index] == actor_id:
			return index
	return -1

static func contains(result: ElementReactionState,point: Vector2i,tick: int,config: SimConfig) -> bool:
	var origin := Vector2i(result.position_x,result.position_y)
	var offset := point-origin
	# A sampled geometry query needs only the authored shape, not a newly
	# allocated metadata dictionary/name/element array at every sample point.
	var wire := result.recipe_wire_id
	var shape := String(RECIPE_ROWS[wire - 301][3]) if wire >= 301 and wire <= 336 else ""
	var distance := offset.length_squared()
	if wire == 301:
		var bounds := rampart_bounds(result)
		return point.x >= bounds.position.x and point.x <= bounds.end.x and point.y >= bounds.position.y and point.y <= bounds.end.y
	if shape in ["annulus","ring"]:
		return distance <= result.radius*result.radius and distance >= result.length*result.length
	if shape in ["water_path","frost_path","branch"]:
		if result.path_points.size() < 4:
			return shape == "water_path" and distance <= result.radius*result.radius
		for index: int in range(0,result.path_points.size()-2,2):
			if segment_near(point,Vector2i(result.path_points[index],result.path_points[index+1]),Vector2i(result.path_points[index+2],result.path_points[index+3]),result.radius):
				return true
		return false
	if shape in ["corridor","front","growing_strip","pulse_lane","bands","reveal_line"]:
		if not segment_near(point,origin,Vector2i(result.endpoint_x,result.endpoint_y),result.radius):
			return false
		if shape == "pulse_lane":
			var period := config.milliseconds_to_ticks(450)
			var age := maxi(0,tick-result.active_tick)%period
			var moving_point := origin + scaled(Vector2i(result.direction_x,result.direction_y),result.length*age/maxi(1,period))
			var pulse_radius := extent(25000)
			return (point-moving_point).length_squared() <= pulse_radius*pulse_radius
		return true
	if shape in ["cover","plane","lens"]:
		var side := Vector2i(-result.direction_y,result.direction_x)
		return segment_near(point,origin-scaled(side,result.length/2),origin+scaled(side,result.length/2),result.radius)
	return distance <= result.radius*result.radius

static func _concealing(result: ElementReactionState,tick: int,config: SimConfig) -> bool:
	if result.recipe_wire_id == 310:
		return tick < result.decay_tick-config.milliseconds_to_ticks(350)
	if result.recipe_wire_id == 326:
		@warning_ignore("integer_division")
		var band := (tick-result.active_tick)/maxi(1,config.milliseconds_to_ticks(300))
		return band%2 == 0
	return result.recipe_wire_id in [304,315,317,321,333,336]

static func blocks_sight(observer: Vector2i,target: Vector2i,reactions: Array,tick: int) -> bool:
	var config := SimConfig.new(120)
	for result: ElementReactionState in reactions:
		if not result.active(tick) or not _concealing(result,tick,config):
			continue
		# Nearby silhouettes remain readable. The visibility owner may override
		# this with authoritative reveal, while threat geometry is never hidden.
		if (target-observer).length_squared() <= 64000*64000:
			continue
		var center := Vector2i(result.position_x,result.position_y)
		if segment_near(center,observer,target,result.radius):
			return true
		if String(recipe(result.recipe_wire_id)["shape"]) in ["corridor","bands"]:
			var endpoint := Vector2i(result.endpoint_x,result.endpoint_y)
			if segment_near(endpoint,observer,target,result.radius) or segments_cross(observer,target,center,endpoint) or contains(result,observer,tick,config) or contains(result,target,tick,config):
				return true
	return false

static func projectile_interaction(projectile: ProjectileState,reactions: Array,collision: CollisionWorld,config: SimConfig,tick: int,available_projectiles: int = 0) -> Dictionary:
	var response := {"blocked":false,"reflected":false,"bent":false,"split_velocity":Vector2i.ZERO,"split_damage":0,"reaction_id":0}
	var start := Vector2i(projectile.previous_x,projectile.previous_y)
	var end := Vector2i(projectile.position_x,projectile.position_y)
	for result: ElementReactionState in reactions:
		if not result.active(tick):
			continue
		var wire := result.recipe_wire_id
		if wire not in [301,305,306,307,320,325,329,335] or not _segment_enters(result,start,end,tick,config):
			continue
		if not clear_line(start,Vector2i(result.position_x,result.position_y),collision):
			continue
		response["reaction_id"] = result.entity_id
		if wire in [301,305,306] or (wire == 329 and projectile.element_wire_id != 7):
			if result.health <= 0:
				continue
			if wire == 306 and projectile.element_wire_id == 6 and result.capacity > 0:
				var absorbed := mini(result.capacity,projectile.damage)
				result.capacity -= absorbed
				projectile.damage -= absorbed
				# Capacity absorbs first; residual damage hits the physical node,
				# never both the node and an actor behind it (same rule as beams).
				response["blocked"] = true
				if projectile.damage > 0:
					result.health = maxi(0,result.health-projectile.damage)
			else:
				result.health = maxi(0,result.health-projectile.damage)
				response["blocked"] = true
			if result.health == 0:
				result.decay_tick = mini(result.decay_tick,tick)
			return response
		var bit: int = 1 << (wire-301)
		if (projectile.chemistry_interaction_mask & bit) != 0:
			continue
		if wire in [320,335]:
			# The observer marker is a state event, not damage or optical bending.
			result.pulse_index = tick
			projectile.chemistry_interaction_mask |= bit
			continue
		if wire == 307:
			var normal := Vector2i(result.direction_x,result.direction_y)
			var velocity := Vector2i(projectile.velocity_x,projectile.velocity_y)
			var dot: int = (velocity.x*normal.x+velocity.y*normal.y)/1000
			velocity -= scaled(normal,2*dot)
			projectile.velocity_x = velocity.x
			projectile.velocity_y = velocity.y
			response["reflected"] = true
		elif wire in [325,329] and projectile.element_wire_id == 7:
			if wire == 329 and (available_projectiles <= 0 or projectile.damage < 2):
				continue # No capacity means no split and no material/damage loss.
			var velocity := Vector2i(projectile.velocity_x,projectile.velocity_y)
			var turned := rotated_fifteen(velocity,1)
			projectile.velocity_x = turned.x
			projectile.velocity_y = turned.y
			response["bent"] = true
			if wire == 329:
				var child_damage := projectile.damage/2
				projectile.damage -= child_damage
				response["split_damage"] = child_damage
				response["split_velocity"] = rotated_fifteen(velocity,-1)
		else:
			continue
		projectile.chemistry_interaction_mask |= bit
		projectile.remainder_x = 0
		projectile.remainder_y = 0
		return response
	return response

static func ray_interaction(origin: Vector2i,end: Vector2i,element_wire_id: int,damage: int,reactions: Array,tick: int,interaction_mask: int = 0,first_target: Vector2i = Vector2i(-1,-1)) -> Dictionary:
	var response := {"rays":[{"origin":origin,"end":end,"damage":damage}],"transformed":false,"reaction_id":0,"interaction_mask":interaction_mask,"telegraph":"","entry_point":end,"blocked":false}
	var config := SimConfig.new(120)
	var best: ElementReactionState = null
	var best_point := end
	var best_distance := (end-origin).length_squared()+1
	for result: ElementReactionState in reactions:
		if not result.active(tick) or result.recipe_wire_id not in [301,305,306,307,325,329]:
			continue
		if result.recipe_wire_id == 325 and element_wire_id != 7:
			continue
		var bit: int = 1 << (result.recipe_wire_id-301)
		if (interaction_mask & bit) != 0:
			continue
		var entry := _entry_point(result,origin,end,tick,config)
		if not bool(entry["hit"]):
			continue
		var point: Vector2i = entry["point"]
		var distance := (point-origin).length_squared()
		if distance < best_distance:
			best = result
			best_distance = distance
			best_point = point
	if best == null:
		return response
	if first_target.x >= 0 and (first_target-origin).length_squared() < best_distance:
		return response
	var wire := best.recipe_wire_id
	response["entry_point"] = best_point
	response["reaction_id"] = best.entity_id
	response["interaction_mask"] = interaction_mask | (1 << (wire-301))
	response["telegraph"] = String(recipe(wire)["shape"])
	if wire in [301,305,306] or (wire == 329 and element_wire_id != 7):
		var absorbed := mini(best.capacity,damage) if wire == 306 and element_wire_id == 6 else 0
		best.capacity -= absorbed
		best.health = maxi(0,best.health-(damage-absorbed))
		if best.health == 0:
			best.decay_tick = mini(best.decay_tick,tick)
		response["rays"] = [{"origin":origin,"end":best_point,"damage":damage}]
		response["transformed"] = true
		response["blocked"] = true
		return response
	var remaining := end-best_point
	if wire == 307:
		var normal := Vector2i(best.direction_x,best.direction_y)
		var dot: int = (remaining.x*normal.x+remaining.y*normal.y)/1000
		remaining -= scaled(normal,2*dot)
	elif wire in [325,329] and element_wire_id == 7:
		remaining = rotated_fifteen(remaining,1)
	else:
		return response
	# Original approach remains a trace with zero damage: root must not apply
	# damage twice to the same ray's approach and transformed continuation.
	var rays: Array = [{"origin":best_point,"end":best_point+remaining,"damage":damage}]
	if wire == 329 and damage >= 2:
		var second_damage := damage/2
		rays[0]["damage"] = damage-second_damage
		rays.append({"origin":best_point,"end":best_point+rotated_fifteen(end-best_point,-1),"damage":second_damage})
	response["rays"] = rays
	response["transformed"] = true
	return response

static func rotated_fifteen(vector: Vector2i,sign_value: int) -> Vector2i:
	return Vector2i((vector.x*966-vector.y*259*sign_value)/1000,(vector.x*259*sign_value+vector.y*966)/1000)

static func _segment_enters(result: ElementReactionState,start: Vector2i,end: Vector2i,tick: int,config: SimConfig) -> bool:
	if not _entry_bounds_overlap(result,start,end):
		return false
	var delta := end-start
	var count := mini(512,maxi(1,(SimCommand._integer_square_root(delta.length_squared())+1999)/2000))
	for index: int in range(count+1):
		var point := start+scaled(delta,index*1000/count)
		if contains(result,point,tick,config):
			return true
	return false

static func _entry_point(result: ElementReactionState,start: Vector2i,end: Vector2i,tick: int,config: SimConfig) -> Dictionary:
	if not _entry_bounds_overlap(result,start,end):
		return {"hit":false,"point":end}
	var delta := end-start
	var count := mini(512,maxi(1,(SimCommand._integer_square_root(delta.length_squared())+1999)/2000))
	for index: int in range(count+1):
		var point := start+scaled(delta,index*1000/count)
		if contains(result,point,tick,config):
			return {"hit":true,"point":point}
	return {"hit":false,"point":end}

static func _entry_bounds_overlap(result: ElementReactionState,start: Vector2i,end: Vector2i) -> bool:
	# This is only a rejection guard. Every sampled query point lies between
	# its current endpoints, including signed integer truncation in scaled().
	# Recompute current geometry: drifting centers, growing lengths, reflected
	# continuations and clipped approaches must never reuse stale bounds.
	var wire := result.recipe_wire_id
	if wire == 301:
		var bounds := rampart_bounds(result)
		return not (maxi(start.x, end.x) < bounds.position.x or mini(start.x, end.x) > bounds.end.x or maxi(start.y, end.y) < bounds.position.y or mini(start.y, end.y) > bounds.end.y)
	var shape := String(RECIPE_ROWS[wire-301][3]) if wire >= 301 and wire <= 336 else ""
	var bound_start := Vector2i(result.position_x,result.position_y)
	var bound_end := bound_start
	match shape:
		"water_path", "frost_path", "branch":
			# Linked points may lie outside the origin/endpoint envelope. Keep
			# their exact path test without adding another scan of the array.
			return true
		"corridor", "front", "growing_strip", "pulse_lane", "bands", "reveal_line":
			bound_end = Vector2i(result.endpoint_x,result.endpoint_y)
		"cover", "plane", "lens":
			var side := scaled(Vector2i(-result.direction_y,result.direction_x),result.length/2)
			bound_start -= side
			bound_end += side
	# segment_near's clamped integer projection stays inside its endpoint
	# bounds. The other shapes fit their outer disk; annulus holes and moving
	# pulse windows only remove points. Strict separation retains tangencies.
	var radius := absi(result.radius)
	return not (maxi(start.x,end.x) < mini(bound_start.x,bound_end.x)-radius \
		or mini(start.x,end.x) > maxi(bound_start.x,bound_end.x)+radius \
		or maxi(start.y,end.y) < mini(bound_start.y,bound_end.y)-radius \
		or mini(start.y,end.y) > maxi(bound_start.y,bound_end.y)+radius)

static func clear_line(start: Vector2i,end: Vector2i,collision: CollisionWorld) -> bool:
	if collision == null:
		return true
	# Swept AABB axis ordering is not a ray test. Sample a bounded line at
	# <=2px intervals, matching ordinary beam contact clearance semantics.
	var delta := end-start
	var distance := SimCommand._integer_square_root(delta.length_squared())
	var count := mini(512,maxi(1,(distance+1999)/2000))
	for index: int in range(1,count+1):
		if not collision.can_occupy(start+scaled(delta,index*1000/count),0):
			return false
	return true

static func segment_near(point: Vector2i,start: Vector2i,end: Vector2i,radius: int) -> bool:
	var delta := end-start
	var offset := point-start
	var length_squared := delta.length_squared()
	if length_squared == 0:
		return offset.length_squared() <= radius*radius
	var dot: int = clampi(offset.x*delta.x+offset.y*delta.y,0,length_squared)
	@warning_ignore("integer_division")
	var closest := start+scaled(delta,dot*1000/length_squared)
	return (point-closest).length_squared() <= radius*radius

static func segments_cross(a: Vector2i,b: Vector2i,c: Vector2i,d: Vector2i) -> bool:
	var ab := b-a
	var ac := c-a
	var ad := d-a
	var cd := d-c
	var ca := a-c
	var cb := b-c
	var first: int = ab.x*ac.y-ab.y*ac.x
	var second: int = ab.x*ad.y-ab.y*ad.x
	var third: int = cd.x*ca.y-cd.y*ca.x
	var fourth: int = cd.x*cb.y-cd.y*cb.x
	return signi(first) != signi(second) and signi(third) != signi(fourth)

static func scaled(direction: Vector2i,amount: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(direction.x*amount/1000,direction.y*amount/1000)

static func midpoint(a: Vector2i,b: Vector2i) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i((a.x+b.x)/2,(a.y+b.y)/2)

static func cell(point: Vector2i) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(point.x/CELL_SIZE,point.y/CELL_SIZE)
