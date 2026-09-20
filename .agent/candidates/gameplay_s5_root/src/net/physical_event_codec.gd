class_name PhysicalEventCodec
extends RefCounted

const TYPES := ["physical_attack_started", "physical_attack_buffered", "physical_attack_phase", "physical_attack_ready", "physical_attack_refused", "physical_attack_cancelled", "physical_attack_contact"]
const REASONS := ["", "invalid", "death", "movement", "busy", "tuning", "stamina", "modal", "control", "cast"]
const PHASES := ["none", "startup", "active", "recovery"]
const VALUE_COUNT := 16

static func encode(event: Dictionary, event_id: int) -> PackedInt64Array:
	var type_index := TYPES.find(String(event.get("type", "")))
	if type_index < 0: return PackedInt64Array()
	var contact: Vector2i = event.get("contact_position", Vector2i(int(event.get("aim_x", 0)), int(event.get("aim_y", 0))))
	var target: Vector2i = event.get("target_position_before_knockback", Vector2i.ZERO)
	var push: Vector2i = event.get("knockback_delta", Vector2i.ZERO)
	var kind := 1 if event.get("kind", "") == "punch" else 2 if event.get("kind", "") == "kick" else 0
	return PackedInt64Array([
		(event_id << 8) | (27 + type_index), int(event.get("entity_id", event.get("attacker_id", 0))), kind,
		int(event.get("sequence_id", 0)), PHASES.find(String(event.get("phase", "none"))), REASONS.find(String(event.get("reason", ""))),
		int(event.get("damage", event.get("stamina_cost", event.get("ticks", event.get("recovery_debt", 0))))), int(event.get("target_id", 0)),
		contact.x, contact.y, target.x, target.y, push.x, push.y,
		int(bool(event.get("first_contact", false))) | (int(bool(event.get("knockback_guarded", false))) << 1), int(event.get("wall_id", 0)),
	])

static func validate(values: PackedInt64Array) -> bool:
	if values.size() != VALUE_COUNT: return false
	var kind := int(values[0]) & 255
	if kind < 27 or kind > 33 or values[0] < 0 or (values[0] >> 8) > 0x7fffffff: return false
	if values[1] <= 0 or values[1] > 8 or values[2] < 0 or values[2] > 2: return false
	if values[3] < 0 or values[3] > 2_000_000_000 or values[4] < 0 or values[4] > 3: return false
	if values[5] < 0 or values[5] >= REASONS.size() or values[6] < 0 or values[6] > 1_000_000: return false
	if values[7] < 0 or values[7] > 0x7fffffff or values[14] < 0 or values[14] > 3: return false
	for index: int in range(8, 14):
		if absi(values[index]) > 100_000_000: return false
	if kind in [27, 33] and (values[2] == 0 or values[3] == 0): return false
	if kind == 33 and (values[7] <= 0 or values[7] == values[1]): return false
	return values[15] >= -2 and values[15] <= 0x7fffffff

static func decode(values: PackedInt64Array) -> Dictionary:
	var type_index := (int(values[0]) & 255) - 27
	var result := {"type": TYPES[type_index], "event_id": int(values[0]) >> 8, "entity_id": int(values[1]), "kind": "punch" if values[2] == 1 else "kick" if values[2] == 2 else "none", "sequence_id": int(values[3])}
	match type_index:
		0: result.merge({"stamina_cost": int(values[6]), "aim_x": int(values[8]), "aim_y": int(values[9])})
		2: result.merge({"phase": PHASES[values[4]], "ticks": int(values[6])})
		4: result.reason = REASONS[values[5]]
		5: result.merge({"reason": REASONS[values[5]], "recovery_debt": int(values[6])})
		6:
			result.merge({"attacker_id": int(values[1]), "target_id": int(values[7]), "damage": int(values[6]), "contact_position": Vector2i(values[8], values[9]), "target_position_before_knockback": Vector2i(values[10], values[11]), "knockback_delta": Vector2i(values[12], values[13]), "first_contact": (values[14] & 1) != 0, "knockback_guarded": (values[14] & 2) != 0, "wall_id": int(values[15])})
	return result
