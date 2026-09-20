class_name HexProductEffects
extends RefCounted
@warning_ignore_start("integer_division")

## Actor-side behavior for already-formed unified hex products.
##
## This adapter never forms, selects, clips, moves, or expires a product. The
## product's stored whole-cell `coverage` is the sole membership authority. A
## compatibility record without `coverage` may derive it from positive legacy
## `cells` allocations; zero legacy allocations do not invent membership.

const Footprint = preload("res://src/sim/hex/hex_footprint.gd")
const RecipePolicy = preload("res://src/sim/hex/hex_recipe_policy.gd")

const MAX_TRACKED_ACTORS := 12
const DEFAULT_RATIO := 1000
const MUD_RATIO := 700
const MAGMA_RATIO := 750
const FROSTWAY_RATIO := 750
const CAPACITOR_RATIO := 1250
const CAPACITOR_DISCHARGE := 14_000
const SIGHT_READABLE_DISTANCE := 64_000

const MAGMA := 302
const MUD := 303
const DUSTFRONT := 304
const CONFLAGRATION := 309
const STEAM := 310
const FIRESTORM := 311
const FLOOD := 316
const MISTCURRENT := 317
const VORTEX := 322
const FROSTWAY := 327
const CAPACITOR := 331

const ROOT_OWNED := [CONFLAGRATION, STEAM, FLOOD]
const TEAM_RULES := {
	MAGMA: {"movement": "all_unprotected", "damage": "hostile_unprotected"},
	MUD: {"movement": "all_unprotected", "damage": "none"},
	DUSTFRONT: {"movement": "all_unprotected", "damage": "none"},
	FIRESTORM: {"movement": "none", "damage": "hostile_unprotected"},
	MISTCURRENT: {"movement": "all_unprotected", "damage": "none"},
	VORTEX: {"movement": "all_unprotected", "damage": "none"},
	FROSTWAY: {"movement": "all", "damage": "none"},
	CAPACITOR: {"movement": "all", "damage": "none", "discharge": "hostile_unprotected"},
}
const ACTOR_EFFECTS := [
	MAGMA, DUSTFRONT, 308, FIRESTORM, 313, 314, 315,
	MISTCURRENT, 318, 319, 320, 321, VORTEX, 323, 324, 326,
	328, 330, CAPACITOR, 332, 333, 334, 335, 336,
]


## Query made immediately before ordinary ground movement. The caller applies
## these three independent ratios only to walk/sprint acceleration, braking and
## target speed. Action movement, forced control and airborne motion stay 1000.
## Point membership makes Mud and Magma end on the first query after exit.
static func pre_movement(
	authority: HexChemistryWorld,
	actor: PlayerState,
	tick: int,
	point_or_path: Variant = null,
	config: SimConfig = null,
) -> Dictionary:
	var result := {
		"acceleration_ratio": DEFAULT_RATIO,
		"braking_ratio": DEFAULT_RATIO,
		"ground_target_ratio": DEFAULT_RATIO,
	}
	if authority == null or actor == null or actor.health <= 0 or not _ordinary_ground_movement(actor):
		return result
	var point := Vector2i(actor.position_x, actor.position_y)
	if point_or_path is Vector2i:
		point = point_or_path
	elif point_or_path is Dictionary and point_or_path.get("point", null) is Vector2i:
		point = point_or_path.point
	var protected := actor.health <= 0 or actor.spawn_protection_ticks > 0
	if not protected and config != null:
		protected = MovementSystem.is_combat_intangible(actor, config)
	var frostway := false
	var capacitor := false
	var ids: Array = authority.products.keys()
	ids.sort()
	for product_id: int in ids:
		var product: Dictionary = authority.products.get(product_id, {})
		if not _active(product, tick) or not _contains(authority, product, point):
			continue
		var wire := int(product.get("recipe_wire_id", 0))
		if wire == FROSTWAY:
			frostway = true
		elif wire == CAPACITOR:
			capacitor = true
		elif not protected:
			if wire == MUD:
				var policy := RecipePolicy.definition(wire)
				var acceleration := int(policy.get("ground_acceleration_ratio", MUD_RATIO))
				var braking := int(policy.get("ground_braking_ratio", MUD_RATIO))
				result.acceleration_ratio = mini(int(result.acceleration_ratio), acceleration)
				result.braking_ratio = mini(int(result.braking_ratio), braking)
			elif wire == MAGMA:
				result.ground_target_ratio = mini(int(result.ground_target_ratio), int(RecipePolicy.definition(wire).get("slow_ratio", MAGMA_RATIO)))
	# Frostway wins its explicit overlap with Capacitor. A Magma surface slow is
	# independently bounded to the same 75%, so it cannot be cancelled by Charge.
	if frostway:
		result.ground_target_ratio = mini(int(result.ground_target_ratio), FROSTWAY_RATIO)
	elif capacitor and int(result.ground_target_ratio) == DEFAULT_RATIO:
		result.ground_target_ratio = CAPACITOR_RATIO
	return result


static func team_rules(wire: int) -> Dictionary:
	return TEAM_RULES.get(wire, {"movement": "none", "damage": "hostile_unprotected"}).duplicate()


## Applies actor effects from existing products in stable product/actor order.
## The supplied paths are canonical previous-foot samples, either Vector2i or
## `{point:Vector2i,height:int}`. Contacts live in each product dictionary so a
## snapshot can resume entry age and same-tick deduplication exactly.
static func step(
	authority: HexChemistryWorld,
	players: Array[PlayerState],
	tick: int,
	config: SimConfig,
	collision: CollisionWorld,
	events: Array,
	paths: Dictionary = {},
) -> void:
	if authority == null or config == null or not config.is_valid():
		return
	var discharged: Dictionary = {}
	# Capture the common post-movement foot samples once. Product-driven pushes
	# later in this step cannot manufacture entry into a second product.
	var samples: Dictionary = {}
	for actor: PlayerState in players:
		if actor != null:
			samples[actor.entity_id] = _motion_sample(actor, paths)
	var ids: Array = authority.products.keys()
	ids.sort()
	for product_id: int in ids:
		var product: Dictionary = authority.products.get(product_id, {})
		var wire := int(product.get("recipe_wire_id", 0))
		if wire in ROOT_OWNED or wire not in ACTOR_EFFECTS or not _active(product, tick):
			continue
		# Legacy chemistry advances one product pulse clock before visiting actors.
		# This lets every actor observe the same pulse while a zero-period impulse
		# remains a single activation attempt instead of refreshing every tick.
		var pulse := _consume_pulse(product, wire, tick, config)
		var contacts: Dictionary = product.get("contacts", {})
		for actor: PlayerState in players:
			if actor == null or actor.health <= 0:
				continue
			var actor_id := actor.entity_id
			var tracked := contacts.has(actor_id)
			if not tracked and contacts.size() >= MAX_TRACKED_ACTORS:
				continue
			var contact: Dictionary = contacts.get(actor_id, {"inside": false, "entered": -1, "last_pulse": -1})
			var was_inside := bool(contact.get("inside", false))
			var endpoint: Vector2i = samples[actor_id].finish
			var inside := _endpoint_inside(authority, product, actor, endpoint)
			var touched := _path_touches(authority, product, actor, samples[actor_id], false)
			var grounded_touched := _path_touches(authority, product, actor, samples[actor_id], true)
			if not tracked and not touched and not inside:
				continue
			if not tracked and contacts.size() >= MAX_TRACKED_ACTORS:
				continue
			var entered := touched and not was_inside
			var exited := not inside and was_inside
			if entered:
				contact.entered = tick
			contact.inside = inside
			contacts[actor_id] = contact
			if int(contact.get("last_pulse", -1)) == tick:
				continue
			contact.last_pulse = tick
			contacts[actor_id] = contact
			_apply_visibility(product, actor, wire, tick, config, touched, entered, exited, pulse)
			if not touched:
				continue
			var protected := actor.spawn_protection_ticks > 0 or MovementSystem.is_combat_intangible(actor, config)
			if protected:
				continue
			if grounded_touched and wire in [DUSTFRONT, MISTCURRENT, VORTEX]:
				_apply_ground_push(authority, product_id, product, actor, wire, config, collision, events)
			var hostile := _hostile(product, actor)
			if not hostile:
				continue
			if wire == 308:
				actor.chemistry_regen_block_ticks = maxi(actor.chemistry_regen_block_ticks, 2)
			var occupied_age := tick - int(contact.get("entered", tick))
			if grounded_touched and (wire == 318 and entered or wire == 330 and occupied_age >= config.milliseconds_to_ticks(350)):
				MovementSystem.apply_control_state(actor, PlayerState.ControlState.SLOWED, 250, Vector2i.ZERO, 0, config, 650)
			if wire == CAPACITOR and not discharged.has(actor_id) and grounded_touched and inside and tick == int(product.get("decay_tick", 0)) - 1:
				discharged[actor_id] = true
				_apply_capacitor_discharge(product_id, product, actor, collision, events)
			var damage := _damage(product, wire, tick, config, grounded_touched, entered, occupied_age, authority, pulse)
			if damage > 0 and PlayerResourcesSystem.damage(actor, damage, config):
				events.append({"type": "chemistry_hit", "reaction_id": int(product.get("id", product_id)), "owner_id": int(product.get("owner", product.get("owner_id", 0))), "target_id": actor_id, "damage": damage})
				if actor.health == 0 and actor.actor_kind == PlayerState.ActorKind.CHAMPION:
					events.append({"type": "champion_defeated", "projectile_id": 0, "owner_id": int(product.get("owner", product.get("owner_id", 0))), "target_id": actor_id})
		product.contacts = contacts


# Pure authoritative visibility query over the same active-product and
# whole-cell membership policies used by actor effects. Close silhouettes stay
# readable under the legacy <=64 px rule; presentation owns any reveal override.
static func blocks_sight(authority: HexChemistryWorld, observer: Vector2i, target: Vector2i, tick: int, config: SimConfig) -> bool:
	if authority == null or config == null:
		return false
	if (target - observer).length_squared() <= SIGHT_READABLE_DISTANCE * SIGHT_READABLE_DISTANCE:
		return false
	var ids: Array = authority.products.keys()
	ids.sort()
	for product_id: int in ids:
		var product: Dictionary = authority.products.get(product_id, {})
		var wire := int(product.get("recipe_wire_id", 0))
		if not _active(product, tick) or not _concealing(product, wire, tick, config):
			continue
		var coverage := _coverage(product)
		if coverage.is_empty():
			continue
		if bool(Footprint.selected_segment_interval(coverage, authority.origin, observer, target).get("hit", false)):
			return true
	return false


static func _ordinary_ground_movement(actor: PlayerState) -> bool:
	if actor.air_height > 0 or actor.is_airborne() or actor.slide_ticks > 0 or actor.wave_dash_ticks > 0:
		return false
	return actor.control_state in [PlayerState.ControlState.FREE, PlayerState.ControlState.SLOWED]


static func _active(product: Dictionary, tick: int) -> bool:
	if product.is_empty() or int(product.get("recipe_wire_id", 0)) < 301 or int(product.get("recipe_wire_id", 0)) > 336:
		return false
	if tick < int(product.get("active_tick", 0)) or tick >= int(product.get("decay_tick", 0)) or tick >= int(product.get("expiry_tick", 0)):
		return false
	if product.has("quantity"):
		return int(product.quantity) > 0
	var allocations: Variant = product.get("cells", null)
	if allocations is Dictionary:
		var total := 0
		for cell: Variant in allocations:
			total += maxi(0, int(allocations[cell]))
		return total > 0
	return true # Explicit compatibility for pre-schema unit fixtures only.


static func _coverage(product: Dictionary) -> Dictionary:
	if product.has("coverage"):
		var stored: Variant = product.coverage
		return stored if stored is Dictionary else {}
	var result := {}
	var allocations: Variant = product.get("cells", {})
	if allocations is Dictionary:
		for cell: Variant in allocations:
			if cell is Vector2i and int(allocations[cell]) > 0:
				result[cell] = 1
	return result


static func _contains(authority: HexChemistryWorld, product: Dictionary, point: Vector2i) -> bool:
	var coverage := _coverage(product)
	return not coverage.is_empty() and Footprint.contains_selected(coverage, authority.origin, point)


static func _endpoint_inside(authority: HexChemistryWorld, product: Dictionary, actor: PlayerState, point: Vector2i) -> bool:
	var policy := RecipePolicy.definition(int(product.get("recipe_wire_id", 0)))
	# Actor contact and visibility remain height-agnostic for ground surfaces.
	# Their physical effects use the separate grounded path query below. This is
	# observable for Black Ice: entry reveals at any playable height, while its
	# delayed slow remains grounded-only.
	var maximum_height := 256_000 if bool(policy.get("ground_only", false)) else int(policy.get("maximum_height", 256_000))
	if actor.air_height > maximum_height:
		return false
	return _contains(authority, product, point)


static func _motion_sample(actor: PlayerState, paths: Dictionary) -> Dictionary:
	var finish := Vector2i(actor.position_x, actor.position_y)
	var previous: Variant = paths.get(actor.entity_id, finish)
	if previous is Vector2i:
		return {"start": previous, "finish": finish, "previous_height": 0, "height": actor.air_height}
	if previous is Dictionary:
		finish = previous.get("finish", finish)
		var requested: Variant = previous.get("point", finish)
		return {"start": requested if requested is Vector2i else finish, "finish": finish, "previous_height": int(previous.get("height", 0)), "height": actor.air_height}
	return {"start": finish, "finish": finish, "previous_height": actor.air_height, "height": actor.air_height}


static func _path_touches(authority: HexChemistryWorld, product: Dictionary, actor: PlayerState, sample: Dictionary, grounded_only: bool) -> bool:
	var policy := RecipePolicy.definition(int(product.get("recipe_wire_id", 0)))
	var requires_ground := grounded_only
	var maximum_height := 0 if requires_ground else (256_000 if bool(policy.get("ground_only", false)) else int(policy.get("maximum_height", 256_000)))
	if requires_ground and (actor.air_height > 0 or actor.is_airborne()):
		return false
	if not requires_ground and actor.air_height > maximum_height:
		return false
	var finish: Vector2i = sample.finish
	var start: Vector2i = sample.start
	var previous_height := int(sample.previous_height)
	# A landing samples only its grounded endpoint. It cannot expose an airborne
	# segment to a lower product layer on the same tick.
	if (requires_ground and previous_height > 0) or (not requires_ground and previous_height > maximum_height):
		start = finish
	var coverage := _coverage(product)
	if coverage.is_empty():
		return false
	return not Footprint.traversed_selected_cells(coverage, authority.origin, start, finish).is_empty()


static func _hostile(product: Dictionary, actor: PlayerState) -> bool:
	return actor.team_id != int(product.get("team", product.get("team_id", 0)))


static func _apply_visibility(product: Dictionary, actor: PlayerState, wire: int, tick: int, config: SimConfig, touched: bool, entered: bool, exited: bool, pulse: bool) -> void:
	if wire in [333, 335] and (entered or exited):
		actor.chemistry_reveal_ticks = maxi(actor.chemistry_reveal_ticks, config.milliseconds_to_ticks(120 if wire == 333 else 250))
	if not touched:
		return
	if _concealing(product, wire, tick, config):
		actor.chemistry_conceal_ticks = maxi(actor.chemistry_conceal_ticks, 2)
	var moving := absi(actor.velocity_x) + absi(actor.velocity_y) > 2000
	if wire == 334 or wire in [314, 332] and pulse or wire == 320 and (moving or entered) or wire in [321, 336] and moving or wire == 330 and entered:
		var duration := 2 if wire == 334 else config.milliseconds_to_ticks(700 if wire in [314, 332] else 250)
		actor.chemistry_reveal_ticks = maxi(actor.chemistry_reveal_ticks, duration)


static func _concealing(product: Dictionary, wire: int, tick: int, config: SimConfig) -> bool:
	if wire == 326:
		var band := (tick - int(product.get("active_tick", 0))) / maxi(1, config.milliseconds_to_ticks(300))
		return band % 2 == 0
	# The unified first-four contract keeps Dustfront and Mistcurrent threats
	# visible. Later-element concealment retains the established actor behavior.
	return wire in [315, 321, 333, 336]


static func _consume_pulse(product: Dictionary, wire: int, tick: int, config: SimConfig) -> bool:
	var definition := RecipePolicy.definition(wire)
	var period := int(product.get("pulse_ticks", definition.get("pulse_ticks", 0)))
	if product.has("pulse_ms"):
		period = config.milliseconds_to_ticks(int(product.pulse_ms))
	var age := tick - int(product.get("active_tick", 0))
	var pulse_index := age / maxi(1, period)
	var previous_index := int(product.get("pulse_index", -1))
	var due := pulse_index != previous_index and (period > 0 or previous_index < 0)
	if due:
		product.pulse_index = pulse_index
	return due


static func _damage(product: Dictionary, wire: int, tick: int, config: SimConfig, grounded: bool, entered: bool, occupied_age: int, authority: HexChemistryWorld, pulse: bool) -> int:
	if not pulse and not (wire == 323 and entered):
		return 0
	var base_damage := int(product.get("pulse_damage", RecipePolicy.definition(wire).get("pulse_damage", 0)))
	var damage := 0
	match wire:
		MAGMA: damage = base_damage if grounded else 0
		FIRESTORM: damage = base_damage
		313: damage = base_damage if _links_alive(authority, product, tick) else 0
		315: damage = base_damage if occupied_age >= config.milliseconds_to_ticks(500) else 0
		# Conductive Flood owns a damaging origin disk without extra Water. Once
		# formation chose links, every chosen source must remain live.
		319: damage = base_damage if _links_alive(authority, product, tick, true) else 0
		323: damage = base_damage
		324: damage = base_damage
		328: damage = base_damage if _links_alive(authority, product, tick) else 0
		336: damage = base_damage if occupied_age >= config.milliseconds_to_ticks(1000) else 0
	return damage


static func _links_alive(authority: HexChemistryWorld, product: Dictionary, tick: int, allow_empty: bool = false) -> bool:
	# linked_sources are explicit live chain members chosen during formation.
	# Parent source_ids are deliberately not a compatibility fallback.
	var linked: Variant = product.get("linked_sources", [])
	if not linked is Array:
		return false
	if linked.is_empty():
		return allow_empty
	for source: Variant in linked:
		var source_id := int(source)
		if source_id <= 0 or not authority.sources.has(source_id):
			return false
		var cast_id := int(authority.sources[source_id])
		var cast: Dictionary = authority.casts.get(cast_id, {})
		var linked_coverage: Variant = cast.get("coverage", cast.get("cells", {}))
		if cast.is_empty() or int(cast.get("expires", cast.get("expiry_tick", 0))) <= tick or not linked_coverage is Dictionary or linked_coverage.is_empty():
			return false
	return true


static func _apply_ground_push(authority: HexChemistryWorld, product_id: int, product: Dictionary, actor: PlayerState, wire: int, config: SimConfig, collision: CollisionWorld, events: Array) -> void:
	var point := Vector2i(actor.position_x, actor.position_y)
	var push: Vector2i = product.get("flow_aim", Vector2i(1000, 0))
	if wire == VORTEX:
		var center: Vector2i = product.get("position", point)
		var radial := SimCommand._normalized_direction(point.x - center.x, point.y - center.y)
		push = Vector2i(-radial.y, radial.x)
	elif wire == DUSTFRONT:
		push = Vector2i(-push.y, push.x)
	var speed := int(product.get("flow_speed", RecipePolicy.definition(wire).get("flow_speed", 0)))
	var key := "%d:%d" % [product_id, actor.entity_id]
	var carry: Vector2i = authority.flow_carry.get(key, Vector2i.ZERO)
	var denominator := config.tick_rate * SimConfig.FIXED_SCALE
	var numerator_x := carry.x + speed * push.x
	var numerator_y := carry.y + speed * push.y
	var delta := Vector2i(numerator_x / denominator, numerator_y / denominator)
	authority.flow_carry[key] = Vector2i(numerator_x - delta.x * denominator, numerator_y - delta.y * denominator)
	var moved := collision.move_box(point, delta, MovementTuning.PLAYER_RADIUS).position if collision != null else point + delta
	actor.position_x = moved.x
	actor.position_y = moved.y
	if moved != point:
		events.append({"type": "hex_product_flow", "entity_id": actor.entity_id, "product_id": product_id, "delta": moved - point})


static func _apply_capacitor_discharge(product_id: int, product: Dictionary, actor: PlayerState, collision: CollisionWorld, events: Array) -> void:
	var point := Vector2i(actor.position_x, actor.position_y)
	var direction: Vector2i = product.get("flow_aim", Vector2i.ZERO)
	if direction == Vector2i.ZERO:
		return
	direction = SimCommand._normalized_direction(direction.x, direction.y)
	var delta := _scaled(direction, CAPACITOR_DISCHARGE)
	var moved := collision.move_box(point, delta, MovementTuning.PLAYER_RADIUS).position if collision != null else point + delta
	actor.position_x = moved.x
	actor.position_y = moved.y
	if moved != point:
		events.append({"type": "hex_capacitor_discharge", "entity_id": actor.entity_id, "product_id": product_id, "delta": moved - point})


static func _scaled(direction: Vector2i, amount: int) -> Vector2i:
	return Vector2i(direction.x * amount / SimConfig.FIXED_SCALE, direction.y * amount / SimConfig.FIXED_SCALE)

