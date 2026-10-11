class_name HexProductEffects
extends RefCounted
@warning_ignore_start("integer_division")

## Actor-side behavior for already-formed unified hex products.
##
## This adapter never forms, selects, clips, moves, or expires a product. The
## product's stored whole-cell `coverage` is the sole membership authority. A
## compatibility record without `coverage` may derive it from positive legacy
## `cells` allocations; zero legacy allocations do not invent membership.

const ReactionDamage = preload("res://src/sim/hex/hex_reaction_damage.gd")
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
const MISTCURRENT := 317
const VORTEX := 322
const FROSTWAY := 316
const CAPACITOR := 331

const ROOT_OWNED := [CONFLAGRATION, STEAM]
const TEAM_RULES := {
	MAGMA: {"movement": "all_unprotected", "damage": "hostile_unprotected"},
	MUD: {"movement": "all_unprotected", "damage": "hostile_unprotected"},
	DUSTFRONT: {"movement": "hostile_unprotected_once", "damage": "hostile_unprotected_once"},
	FIRESTORM: {"movement": "none", "damage": "hostile_unprotected"},
	MISTCURRENT: {"movement": "all_unprotected", "damage": "hostile_unprotected"},
	VORTEX: {"movement": "all_unprotected", "damage": "hostile_unprotected"},
	FROSTWAY: {"movement": "all", "damage": "none"},
	CAPACITOR: {"movement": "all", "damage": "none", "discharge": "hostile_unprotected"},
}
const ACTOR_EFFECTS := [
	301, MAGMA, MUD, DUSTFRONT, 307, 308, FIRESTORM, 314, 315, FROSTWAY, 325,
	MISTCURRENT, 320, 321, VORTEX, 326, 334, 335, 336,
]


## Query made immediately before ordinary ground movement. The caller applies
## these three independent ratios only to walk/sprint acceleration, braking and
## target speed. Action movement, forced control and airborne motion stay 1000.
## Point membership makes Mud and Magma end on the first query after exit.
## Harmful ratios are exposed below clearance even during actions; the movement
## consumer applies them only to ordinary locomotion, not paid action impulses.
## Frostway/Capacitor opt in only for ordinary ground movement.
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
	if authority == null or actor == null or actor.health <= 0 or MovementSystem.avoids_ground_effects(actor):
		return result
	var ordinary_ground := _ordinary_ground_movement(actor)
	var point := Vector2i(actor.position_x, actor.position_y)
	if point_or_path is Vector2i:
		point = point_or_path
	elif point_or_path is Dictionary and point_or_path.get("point", null) is Vector2i:
		point = point_or_path.point
	var endpoint := {}
	var protected := actor.health <= 0 or actor.spawn_protection_ticks > 0
	if not protected and config != null:
		protected = MovementSystem.is_combat_intangible(actor, config)
	var frostway := false
	var capacitor := false
	var ids: Array = authority.products.keys()
	ids.sort()
	for product_id: int in ids:
		var product: Dictionary = authority.products.get(product_id, {})
		var wire := int(product.get("recipe_wire_id", 0))
		if wire not in [MUD,MAGMA,FROSTWAY,CAPACITOR] and wire <= 400: continue
		if not _active(product, tick): continue
		if endpoint.is_empty():
			endpoint.finish = point
			_cache_endpoint(endpoint, authority.origin)
		if not _contains(authority, product, point, endpoint):
			continue
		if wire > 400:
			var compound := RecipePolicy.runtime_definition(wire)
			if ordinary_ground:
				result.ground_target_ratio = mini(int(result.ground_target_ratio), int(compound.get("ground_target_ratio", 1000)))
			if not protected:
				result.acceleration_ratio = mini(int(result.acceleration_ratio), int(compound.get("ground_acceleration_ratio", 1000)))
				result.braking_ratio = mini(int(result.braking_ratio), int(compound.get("ground_braking_ratio", 1000)))
		elif wire == FROSTWAY and ordinary_ground:
			frostway = true
		elif wire == CAPACITOR and ordinary_ground:
			capacitor = true
		elif not protected:
			if wire == MUD:
				var policy := RecipePolicy.runtime_definition(wire)
				var acceleration := int(policy.get("ground_acceleration_ratio", MUD_RATIO))
				var braking := int(policy.get("ground_braking_ratio", MUD_RATIO))
				result.acceleration_ratio = mini(int(result.acceleration_ratio), acceleration)
				result.braking_ratio = mini(int(result.braking_ratio), braking)
			elif wire == MAGMA:
				result.ground_target_ratio = mini(int(result.ground_target_ratio), int(RecipePolicy.runtime_definition(wire).get("slow_ratio", MAGMA_RATIO)))
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
	var flowed: Dictionary = {}
	# Capture the common post-movement foot samples once. Product-driven pushes
	# later in this step cannot manufacture entry into a second product.
	var samples: Dictionary = {}
	for actor: PlayerState in players:
		if actor != null:
			samples[actor.entity_id] = _motion_sample(actor, paths)
	var ids: Array = authority.products.keys()
	ids.sort()
	# All products see the same pre-push paths. Discover touched cells once per
	# actor, then intersect each product's exact coverage. No persistent cache,
	# center-radius approximation, missed high-speed crossing, or moved field.
	var membership := {}
	for product_id: int in ids:
		var product: Dictionary = authority.products.get(product_id,{})
		var wire := int(product.get("recipe_wire_id",0))
		if wire in ROOT_OWNED or (wire not in ACTOR_EFFECTS and wire <= 400) or not _active(product,tick): continue
		var coverage := _coverage(product)
		for cell: Vector2i in coverage:
			if Footprint._selected_cell_active(coverage,cell): membership[cell] = 1
	for sample: Dictionary in samples.values():
		if not membership.is_empty():
			_cache_endpoint(sample, authority.origin)
		sample.touched_cells = Footprint.traversed_selected_cells(membership,authority.origin,sample.start,sample.finish)
	for product_id: int in ids:
		var product: Dictionary = authority.products.get(product_id, {})
		var wire := int(product.get("recipe_wire_id", 0))
		if wire in ROOT_OWNED or (wire not in ACTOR_EFFECTS and wire <= 400) or not _active(product, tick):
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
			var contact: Dictionary = contacts.get(actor_id, {"inside": false, "entered": -1, "last_pulse": -1, "effect_used": false})
			var was_inside := bool(contact.get("inside", false))
			var endpoint: Vector2i = samples[actor_id].finish
			var inside := _endpoint_inside(authority, product, actor, endpoint, samples[actor_id])
			var touched := _path_touches(authority, product, actor, samples[actor_id], false)
			if not tracked and not touched and not inside:
				continue
			if not tracked and contacts.size() >= MAX_TRACKED_ACTORS:
				continue
			var entered := touched and not was_inside
			var exited := not inside and (was_inside or touched)
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
			# Ground contact only affects eligible physical effects below. Keep
			# contact, pulse and visibility bookkeeping ahead of this query.
			var grounded_touched := _path_touches(authority, product, actor, samples[actor_id], true)
			if grounded_touched and not flowed.has(actor_id) and (wire in [MISTCURRENT, VORTEX] or wire > 400 and int(RecipePolicy.runtime_definition(wire).flow_speed) > 0):
				flowed[actor_id] = true
				_apply_ground_push(authority, product_id, product, actor, wire, config, collision, events)
			var hostile := _hostile(product, actor)
			if not hostile:
				continue
			if wire == 308 and grounded_touched or wire > 400 and bool(RecipePolicy.runtime_definition(wire).get("blocks_recovery", false)):
				actor.chemistry_regen_block_ticks = maxi(actor.chemistry_regen_block_ticks, 2)
			var occupied_age := tick - int(contact.get("entered", tick))
			if grounded_touched and wire == 321 and entered:
				MovementSystem.apply_control_state(actor, PlayerState.ControlState.SLOWED, 250, Vector2i.ZERO, 0, config, 650)
			if wire == CAPACITOR and not discharged.has(actor_id) and grounded_touched and inside and tick == int(product.get("decay_tick", 0)) - 1:
				discharged[actor_id] = true
				_apply_capacitor_discharge(product_id, product, actor, collision, events)
			var moving := absi(actor.velocity_x) + absi(actor.velocity_y) > 2000
			var damage := _damage(product, wire, tick, config, grounded_touched, entered, exited, occupied_age, authority, pulse, moving, bool(contact.get("effect_used", false)))
			var first_effect := not bool(contact.get("effect_used", false))
			if damage > 0 and first_effect and bool(RecipePolicy.runtime_definition(wire).get("effect_once_per_actor", false)):
				contact.effect_used = true
				contacts[actor_id] = contact
				if wire == DUSTFRONT and not discharged.has(actor_id):
					discharged[actor_id] = true
					_apply_sandblast_impulse(product_id, product, actor, collision, events)
			# Dose is bounded by matched paid strength; all descendants share the pool.
			damage = damage * mini(1500, int(product.get("strength", 10)) * 100) / 1000
			var actual_damage := ReactionDamage.apply(product, actor, damage, config)
			if actual_damage > 0:
				if wire > 400 and first_effect and int(RecipePolicy.runtime_definition(wire).get("discharge_impulse", 0)) > 0 and not discharged.has(actor_id) and grounded_touched:
					discharged[actor_id] = true
					_apply_capacitor_discharge(product_id, product, actor, collision, events)
				events.append({"type": "chemistry_hit", "reaction_id": int(product.get("id", product_id)), "owner_id": int(product.get("owner", product.get("owner_id", 0))), "target_id": actor_id, "damage": actual_damage})
				if actor.health == 0 and actor.actor_kind == PlayerState.ActorKind.CHAMPION:
					events.append({"type": "champion_defeated", "projectile_id": 0, "owner_id": int(product.get("owner", product.get("owner_id", 0))), "target_id": actor_id})
			if not inside:
				contact.entered = tick + 1
				contacts[actor_id] = contact
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
	if product.is_empty() or int(product.get("recipe_wire_id", 0)) not in RecipePolicy.ACTIVE_RECIPE_WIRES:
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


static func _cache_endpoint(sample: Dictionary, origin: Vector2i) -> void:
	# The sample is local to one query/effects pass. Cache only the canonical
	# endpoint owner; product coverage and actor eligibility remain live reads.
	sample.finish_valid = Footprint._world_point_valid(sample.finish)
	if sample.finish_valid:
		sample.finish_cell = HexGrid.world_to_cell(Vector2i(sample.finish) - origin)


static func _contains(authority: HexChemistryWorld, product: Dictionary, point: Vector2i, endpoint: Dictionary = {}) -> bool:
	var coverage := _coverage(product)
	if endpoint.has("finish_valid"):
		return bool(endpoint.finish_valid) and Footprint._selected_cell_active(coverage, endpoint.finish_cell)
	return not coverage.is_empty() and Footprint.contains_selected(coverage, authority.origin, point)


static func _endpoint_inside(authority: HexChemistryWorld, product: Dictionary, actor: PlayerState, point: Vector2i, endpoint: Dictionary = {}) -> bool:
	var policy := RecipePolicy.runtime_definition(int(product.get("recipe_wire_id", 0)))
	# Actor contact and visibility remain height-agnostic for ground surfaces.
	# Their physical effects use the separate grounded path query below. This is
	# observable for Black Ice: entry reveals at any playable height, while its
	# delayed slow remains grounded-only.
	var maximum_height := 256_000 if bool(policy.get("ground_only", false)) else int(policy.get("maximum_height", 256_000))
	if actor.wall_skim_ticks <= 0 and actor.air_height > maximum_height:
		return false
	return _contains(authority, product, point, endpoint)


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
	var policy := RecipePolicy.runtime_definition(int(product.get("recipe_wire_id", 0)))
	var requires_ground := grounded_only
	var maximum_height := MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT if requires_ground else (256_000 if bool(policy.get("ground_only", false)) else int(policy.get("maximum_height", 256_000)))
	if requires_ground and MovementSystem.avoids_ground_effects(actor):
		return false
	if not requires_ground and actor.wall_skim_ticks <= 0 and actor.air_height > maximum_height:
		return false
	var finish: Vector2i = sample.finish
	var start: Vector2i = sample.start
	var previous_height := int(sample.previous_height)
	# A landing samples only its grounded endpoint. It cannot expose an airborne
	# segment to a lower product layer on the same tick.
	if actor.wall_skim_ticks <= 0 and ((requires_ground and previous_height >= maximum_height) or (not requires_ground and previous_height > maximum_height)):
		start = finish
	var coverage := _coverage(product)
	if coverage.is_empty():
		return false
	if sample.has("touched_cells"):
		if start == finish:
			if sample.has("finish_valid"):
				return bool(sample.finish_valid) and Footprint._selected_cell_active(coverage, sample.finish_cell)
			return Footprint.contains_selected(coverage,authority.origin,finish)
		for cell: Vector2i in sample.touched_cells:
			if Footprint._selected_cell_active(coverage,cell): return true
		return false
	return Footprint.touches_selected(coverage, authority.origin, start, finish)


static func _hostile(product: Dictionary, actor: PlayerState) -> bool:
	return actor.team_id != int(product.get("team", product.get("team_id", 0)))


static func _apply_visibility(product: Dictionary, actor: PlayerState, wire: int, tick: int, config: SimConfig, touched: bool, entered: bool, exited: bool, pulse: bool) -> void:
	if wire > 400 and touched:
		var policy := RecipePolicy.runtime_definition(wire)
		if bool(policy.reveals): actor.chemistry_reveal_ticks = maxi(actor.chemistry_reveal_ticks, 2)
		if bool(policy.conceals):
			actor.chemistry_conceal_ticks = maxi(actor.chemistry_conceal_ticks, 2)
			if absi(actor.velocity_x) + absi(actor.velocity_y) > 2000: actor.chemistry_reveal_ticks = maxi(actor.chemistry_reveal_ticks, config.milliseconds_to_ticks(250))
	if wire == 335 and (entered or exited):
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
	if wire > 400: return bool(RecipePolicy.runtime_definition(wire).get("conceals", false))
	if wire == 326:
		var band := (tick - int(product.get("active_tick", 0))) / maxi(1, config.milliseconds_to_ticks(300))
		return band % 2 == 0
	# The unified first-four contract keeps Dustfront and Mistcurrent threats
	# visible. Later-element concealment retains the established actor behavior.
	if wire == 315:
		return tick < int(product.get("decay_tick", 0)) - config.milliseconds_to_ticks(600)
	return wire == 336


static func _consume_pulse(product: Dictionary, wire: int, tick: int, config: SimConfig) -> bool:
	# Thermal Shock's structure-fracture pass owns pulse_index. Its actor burst
	# shares the activation tick, with per-actor contacts preventing double hits.
	if wire == 312:
		return tick == int(product.get("active_tick", 0))
	var definition := RecipePolicy.runtime_definition(wire)
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


static func _damage(product: Dictionary, wire: int, tick: int, config: SimConfig, grounded: bool, entered: bool, exited: bool, occupied_age: int, authority: HexChemistryWorld, pulse: bool, moving: bool = false, effect_used: bool = false) -> int:
	var base_damage := int(product.get("pulse_damage", RecipePolicy.runtime_definition(wire).get("pulse_damage", 0)))
	# A descendant inherits spent one-time attacks, including activation bursts.
	if effect_used and bool(RecipePolicy.runtime_definition(wire).get("effect_once_per_actor", false)): return 0
	if wire > 400:
		var policy := RecipePolicy.runtime_definition(wire)
		if bool(policy.ground_only) and not grounded: return 0
		match String(policy.trigger):
			"crossing": return base_damage if entered and not effect_used else 0
			"activation": return base_damage if pulse and not effect_used else 0
			"dwell": return base_damage if pulse and occupied_age >= config.milliseconds_to_ticks(1000) else 0
			"moving": return base_damage if pulse and moving else 0
			"pulse": return base_damage if pulse else 0
		return 0
	if wire in [301, 307, 316, 325]:
		return base_damage if entered and not effect_used and (grounded or wire in [307, 325]) else 0
	# Entry/exit attacks spend a bounded actor latch, never the global pulse clock.
	if wire == DUSTFRONT: return base_damage if grounded and entered and not effect_used else 0
	if wire == 321: return base_damage if grounded and exited and not effect_used else 0
	if wire == 335: return base_damage if entered and not effect_used else 0
	# Backdraft has one public detonation time after its transparent warning.
	if wire == 315: return base_damage if tick == int(product.get("decay_tick", 0)) - 1 else 0
	if not pulse: return 0
	match wire:
		MAGMA: return base_damage if grounded else 0
		MUD: return base_damage if grounded and occupied_age >= config.milliseconds_to_ticks(350) else 0
		308: return base_damage if grounded else 0
		FIRESTORM: return base_damage if _links_alive(authority, product, tick, true) else 0
		314, 334: return base_damage
		MISTCURRENT, VORTEX: return base_damage if grounded else 0
		320: return base_damage if moving else 0
		326: return base_damage if _concealing(product, wire, tick, config) else 0
		336:
			if occupied_age < config.milliseconds_to_ticks(1000): return 0
			var extra := (occupied_age - config.milliseconds_to_ticks(1000)) / maxi(1, config.milliseconds_to_ticks(600))
			return mini(6_000, base_damage + extra * 1_000)
	return 0


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
	var speed := int(product.get("flow_speed", RecipePolicy.runtime_definition(wire).get("flow_speed", 0)))
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


static func _apply_sandblast_impulse(product_id: int, product: Dictionary, actor: PlayerState, collision: CollisionWorld, events: Array) -> void:
	var aim: Vector2i = product.get("flow_aim", Vector2i(1000, 0))
	var delta := _scaled(Vector2i(-aim.y, aim.x), 14_000)
	var point := Vector2i(actor.position_x, actor.position_y)
	var moved := collision.move_box(point, delta, MovementTuning.PLAYER_RADIUS).position if collision != null else point + delta
	actor.position_x = moved.x
	actor.position_y = moved.y
	if moved != point:
		events.append({"type": "hex_sandblast_impulse", "entity_id": actor.entity_id, "product_id": product_id, "delta": moved - point})


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
