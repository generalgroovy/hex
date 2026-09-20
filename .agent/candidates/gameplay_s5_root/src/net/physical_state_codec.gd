class_name PhysicalStateCodec
extends RefCounted

# Eight champions and four practice targets can share one physical arc. Keep
# every hit ID; never truncate a hit set and permit repeat damage after restore.
const MAX_HITS := 11
const FIELDS: Array[StringName] = [
	&"physical_kind", &"physical_phase", &"physical_phase_ticks_remaining", &"physical_phase_ticks_total",
	&"physical_aim_x", &"physical_aim_y", &"physical_sequence_id", &"physical_buffer_kind",
	&"physical_buffer_ticks", &"physical_recovery_lock_ticks", &"knockback_guard_ticks",
	&"infusion_wire_id", &"infusion_source_id", &"infusion_sequence_id", &"infusion_ready_ticks", &"infusion_used",
]
const VALUE_COUNT := 28 # Sixteen scalar fields, count, eleven zero-padded hits.

static func capture(state: PlayerState) -> PackedInt32Array:
	var values := PackedInt32Array()
	for field: StringName in FIELDS: values.append(int(state.get(field)))
	values.append(state.physical_hit_ids.size())
	values.append_array(state.physical_hit_ids)
	# Over-cap state remains over-size and fails validation; it is never dropped.
	while values.size() < VALUE_COUNT: values.append(0)
	return values

static func apply(state: PlayerState, values: PackedInt32Array) -> void:
	for index: int in FIELDS.size(): state.set(FIELDS[index], values[index])
	state.physical_hit_ids = values.slice(17, 17 + values[16])

static func validate(values: PackedInt32Array) -> bool:
	if values.size() != VALUE_COUNT: return false
	if values[0] < 0 or values[0] > 2 or values[1] < 0 or values[1] > 3: return false
	if (values[0] == 0) != (values[1] == 0): return false
	if values[2] < 0 or values[2] > values[3] or values[3] > 240: return false
	if values[1] == 0 and (values[2] != 0 or values[3] != 0): return false
	if values[1] > 0 and (values[2] == 0 or values[6] == 0): return false
	if absi(values[4]) > 1000 or absi(values[5]) > 1000: return false
	if values[1] > 0 and values[4] == 0 and values[5] == 0: return false
	if values[6] < 0 or values[6] > 2_000_000_000: return false
	if values[7] < 0 or values[7] > 2 or values[8] < 0 or values[8] > 10: return false
	if (values[7] == 0) != (values[8] == 0): return false
	if values[9] < 0 or values[9] > 240 or values[10] < 0 or values[10] > 48: return false
	if values[11] < 0 or values[11] > 65535 or values[12] < 0 or values[12] > 0x7fffffff: return false
	if values[13] < 0 or values[13] > 2_000_000_000 or values[14] < 0 or values[14] > 36 or values[15] not in [0, 1]: return false
	if (values[11] == 0) != (values[12] == 0): return false
	# After release/cancel, sequence+used remain latched without held stock.
	if values[15] == 0 and (values[11] != 0 or values[13] != 0): return false
	if values[15] == 1 and (values[13] <= 0 or values[13] != values[6]): return false
	if values[11] > 0 and (values[13] != values[6] or values[15] != 1 or values[1] not in [1, 2]): return false
	if values[16] < 0 or values[16] > MAX_HITS: return false
	var previous := 0
	for index: int in MAX_HITS:
		var id := values[17 + index]
		if index < values[16]:
			if id <= previous: return false
			previous = id
		elif id != 0: return false
	return true
