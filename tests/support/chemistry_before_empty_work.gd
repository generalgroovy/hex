extends "res://src/sim/hex/hex_chemistry_world.gd"
@warning_ignore_start("integer_division")

# Exact pre-optimization method bodies; do not update to mirror optimized guards.
# Original source SHA-256: b3b9118b391ab00d20e93873812e0bff2444f8fe8096a6e5d11642f381f5c591

func apply_product_effects(players: Array[PlayerState], tick: int, config: SimConfig, collision: CollisionWorld, events: Array[Dictionary], paths: Dictionary = {}) -> void:
	if not config.is_valid() or collision == null:
		return
	var sampled_paths := paths.duplicate(true)
	for actor: PlayerState in players:
		var previous: Variant = sampled_paths.get(actor.entity_id, Vector2i(actor.position_x, actor.position_y))
		if previous is Vector2i: previous = {"point": previous, "height": actor.air_height}
		previous.finish = Vector2i(actor.position_x, actor.position_y)
		sampled_paths[actor.entity_id] = previous
	HexProductEffects.step(self, players, tick, config, collision, events, sampled_paths)
	paths = sampled_paths
	var ground_paths := {}
	var ids: Array = products.keys()
	ids.sort()
	for product_id: int in ids:
		var product: Dictionary = products[product_id]
		if tick < int(product.active_tick) or tick >= int(product.decay_tick) or tick >= int(product.expiry_tick):
			continue
		var recipe_wire_id: int = int(product.recipe_wire_id)
		if recipe_wire_id == CONFLAGRATION_WIRE:
			if (tick - int(product.active_tick)) % config.milliseconds_to_ticks(600) != 0:
				continue
			for actor: PlayerState in players:
				if actor.spawn_protection_ticks > 0 or MovementSystem.is_combat_intangible(actor, config): continue
				if actor.health <= 0 or MovementSystem.avoids_ground_effects(actor) or not _ground_path_touches(product, actor, paths, ground_paths):
					continue
				var damage: int = int(product.pulse_damage) * int(product.intensity) / 1000
				var actual_damage := ReactionDamage.apply(product, actor, damage, config)
				if actual_damage > 0:
					var owner_id := int(product.get("owner", product.get("owner_id", 0)))
					events.append({"type": "hex_conflagration", "entity_id": actor.entity_id, "product_id": product_id, "owner_id": owner_id, "amount": actual_damage})
					_append_champion_defeated(actor, owner_id, events)


func sync_flights(players: Array[PlayerState], projectiles: Array[ProjectileState]) -> void:
	var live := {}
	for projectile: ProjectileState in projectiles: live[projectile.entity_id] = true
	var live_pending := {}
	for actor: PlayerState in players:
		if actor.health > 0 and actor.pending_cast_wire_id > 0: live_pending[actor.entity_id] = actor.pending_cast_wire_id
	for id: int in casts.keys():
		var record: Dictionary = casts[id]
		if not record.ledger.is_empty():
			for entity_id: int in record.flight_parts.keys():
				if not live.has(entity_id):
					var expired: int = Parts.expire_flight(record, entity_id)
					metrics.matter_expired += maxi(0, expired)
					_sync_cast_ledger(record)
		elif int(live_pending.get(int(record.owner), 0)) != int(record.wire):
			_expire_unallocated(record)
		if int(record.ground) == 0 and int(record.unallocated) == 0:
			if int(pending.get(int(record.owner), 0)) == id: pending.erase(int(record.owner))
			sources.erase(int(record.source))
			casts.erase(id)
