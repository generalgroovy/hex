extends RefCounted
## Bounded, append-only authority lanes shared by full and presentation snapshots.
const STATUS_COUNT := 6
const STATUS_STRIDE := 8
const STATUS_SIZE := STATUS_COUNT * STATUS_STRIDE
const CONTACT_CAP := 12
const DELIVERY_SIZE := 4 + CONTACT_CAP
const MAX_ID := 0x7fffffff
const STATUS_POTENCIES := [80, 1000, 120, 80, 1000, 1000]

static func valid_status_values(values: Variant) -> bool:
	if typeof(values) not in [TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY]: return false
	if values.size() != STATUS_SIZE: return false
	for value: int in values:
		if value < 0 or value > MAX_ID: return false
	for channel: int in STATUS_COUNT:
		var at := channel * STATUS_STRIDE
		var ticks: int = values[at]
		if ticks == 0:
			for index: int in range(at, at + STATUS_STRIDE):
				if values[index] != 0: return false
			continue
		if ticks < 1 or ticks > 600 or values[at + 1] < 0 or values[at + 1] > 1000 \
			or values[at + 2] < 0 or values[at + 2] > 100000 or values[at + 3] < 0 or values[at + 3] > 120:
			return false
		if channel != 1 and values[at + 2] != 0: return false
		if values[at + 1] != STATUS_POTENCIES[channel] or values[at + 2] > 2400: return false
		if (channel == 1 and values[at + 3] > 12) or (channel != 1 and values[at + 3] != 0): return false
		for index: int in [4, 5, 6, 7]:
			if values[at + index] <= 0 or values[at + index] > MAX_ID: return false
		if values[at + 5] > 10000 or not CombatTuning.is_runtime_wire_id(values[at + 6]): return false
		var definition := CombatTuning.cast_definition_view(values[at + 6])
		if (int(definition.get("element_mask", 0)) & (1 << channel)) == 0: return false
	return true

static func capture_delivery(shot: ProjectileState) -> PackedInt32Array:
	if shot.delivery_phase < 0 or shot.delivery_phase > 2 or shot.delivery_ticks < 0 or shot.delivery_ticks > 600 \
		or shot.delivery_damage_remaining < 0 or shot.delivery_damage_remaining > 100000 or shot.contact_entity_ids.size() > CONTACT_CAP:
		return PackedInt32Array()
	for entity: int in shot.contact_entity_ids:
		if entity <= 0 or entity > MAX_ID: return PackedInt32Array()
	var result := PackedInt32Array([shot.delivery_phase, shot.delivery_ticks, shot.delivery_damage_remaining, shot.contact_entity_ids.size()])
	for index: int in CONTACT_CAP:
		result.append(int(shot.contact_entity_ids[index]) if index < shot.contact_entity_ids.size() else 0)
	return result if valid_delivery(result, shot.source_wire_id) else PackedInt32Array()

static func valid_delivery(values: Variant, wire: int) -> bool:
	if typeof(values) not in [TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY]: return false
	if values.size() != DELIVERY_SIZE or not CombatTuning.is_runtime_wire_id(wire): return false
	for value: int in values:
		if value < 0 or value > MAX_ID: return false
	if values[0] < 0 or values[0] > 2 or values[1] < 0 or values[1] > 600 \
		or values[2] < 0 or values[2] > 100000 or values[3] < 0 or values[3] > CONTACT_CAP:
		return false
	var definition := CombatTuning.cast_definition_view(wire)
	var family := String(definition.get("family", ""))
	if values[2] > int(definition.get("damage", 0)): return false
	if values[0] == 1 and family != "fuse": return false
	if values[0] == 2 and family != "split": return false
	if family == "mantle" and values[1] != 0: return false
	if family == "fuse" and (values[1] > 72 or (values[0] == 0 and values[1] != 0)): return false
	if family == "split" and (values[2] != 0 or values[1] > 30 or (values[0] == 2 and values[1] != 0)): return false
	if family not in ["mantle", "fuse", "split"] and (values[0] != 0 or values[1] != 0 or values[2] != 0 or values[3] != 0): return false
	var previous := 0
	for index: int in CONTACT_CAP:
		var value: int = values[4 + index]
		if index >= values[3]:
			if value != 0: return false
		else:
			if value <= previous or value > MAX_ID: return false
			previous = value
	return true

static func restore_delivery(shot: ProjectileState, values: Variant) -> bool:
	if shot == null or not valid_delivery(values, shot.source_wire_id): return false
	shot.delivery_phase = values[0]
	shot.delivery_ticks = values[1]
	shot.delivery_damage_remaining = values[2]
	shot.contact_entity_ids = PackedInt64Array(Array(values.slice(4, 4 + values[3])))
	return true
