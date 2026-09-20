extends FluxTestSuite


const TIDE_SHELL_WIRE_ID: int = 181
const RILL_STREAM_WIRE_ID: int = 182


const MIN_I64: int = -9_223_372_036_854_775_807 - 1
const MAX_I64: int = 9_223_372_036_854_775_807


func run() -> int:
	_test_signed_boundaries_and_offsets()
	_test_seeded_full_width_values()
	_test_utf8_string_lengths()
	_test_reaction_strength_is_append_only()
	_test_production_command_and_world_payloads()
	_measure_append_cost()
	return finish("canonical-bytes")


static func _reference_append(output: PackedByteArray, value: int) -> void:
	# Frozen pre-optimization implementation; do not use encode_s64/decode_s64
	# here or the compatibility test would compare a native codec to itself.
	for byte_index: int in range(8):
		output.append((value >> (byte_index * 8)) & 0xff)


static func _reference_string(output: PackedByteArray, value: String) -> void:
	var encoded := value.to_utf8_buffer()
	_reference_append(output, encoded.size())
	output.append_array(encoded)


func _test_signed_boundaries_and_offsets() -> void:
	var values := PackedInt64Array([MIN_I64, MIN_I64 + 1, -4_294_967_296, -2_147_483_649,
		-2_147_483_648, -65_536, -256, -255, -1, 0, 1, 127, 128, 255, 256, 65_535,
		2_147_483_647, 2_147_483_648, 4_294_967_295, MAX_I64 - 1, MAX_I64])
	for offset: int in [0, 1, 7, 8, 13, 63]:
		for value: int in values:
			var prefix := PackedByteArray()
			for index: int in range(offset):
				prefix.append((index * 73 + 19) & 0xff)
			var actual := prefix.duplicate()
			var expected := prefix.duplicate()
			CanonicalBytes.append_i64(actual, value)
			_reference_append(expected, value)
			equal(actual, expected, "signed64 value %d preserves exact bytes at offset %d" % [value, offset])
			equal(actual.size(), offset + 8, "one integer appends exactly eight bytes")
			equal(actual.slice(0, offset), prefix, "native encoding never overwrites existing bytes")
	var endian := PackedByteArray()
	CanonicalBytes.append_i64(endian, 0x0102030405060708)
	equal(endian.hex_encode(), "0807060504030201", "canonical signed64 is explicitly little-endian")
	var minimum := PackedByteArray()
	CanonicalBytes.append_i64(minimum, MIN_I64)
	equal(minimum.hex_encode(), "0000000000000080", "minimum signed64 preserves its two's-complement bit")
	var negative := PackedByteArray()
	CanonicalBytes.append_i64(negative, -1)
	equal(negative.hex_encode(), "ffffffffffffffff", "negative one preserves all sign bits")


func _test_seeded_full_width_values() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 607_064
	var actual := PackedByteArray([0x33, 0x00, 0x80])
	var expected := actual.duplicate()
	for index: int in range(4_096):
		var value: int = (int(random.randi()) << 32) | int(random.randi())
		CanonicalBytes.append_i64(actual, value)
		_reference_append(expected, value)
		equal(actual.slice(actual.size() - 8), expected.slice(expected.size() - 8), "seeded full-width signed value %d is byte-exact" % index)
	equal(actual, expected, "4,096 appended values retain the entire unaligned output buffer")
	equal(CanonicalBytes.sha256_hex(actual), CanonicalBytes.sha256_hex(expected), "seeded canonical buffer SHA-256 is unchanged")


func _test_utf8_string_lengths() -> void:
	var actual := PackedByteArray([0xaa, 0x55, 0x00])
	var expected := actual.duplicate()
	for value: String in ["", "FLUX", "Wellspring — café", "風・水・氷", "🧙🏽‍♀️", "é", "line one\nline two\tend"]:
		var offset := actual.size()
		CanonicalBytes.append_string(actual, value)
		_reference_string(expected, value)
		equal(actual, expected, "UTF-8 string and byte-length prefix remain exact: %s" % value)
		var prefix := PackedByteArray()
		_reference_append(prefix, value.to_utf8_buffer().size())
		equal(actual.slice(offset, offset + 8), prefix, "string prefix measures UTF-8 bytes, not characters")
	CanonicalBytes.append_i64(actual, MIN_I64)
	_reference_append(expected, MIN_I64)
	equal(actual, expected, "integer following variable-width strings respects its nonzero offset")
	equal(CanonicalBytes.sha256_hex(actual), CanonicalBytes.sha256_hex(expected), "UTF-8 payload hash is unchanged")


func _test_reaction_strength_is_append_only() -> void:
	var projectile := ProjectileState.new(
		1000, 1, 2, CombatTuning.RILLSHOT_WIRE_ID, 2,
		Vector2i(500_000, 600_000), Vector2i(480_000, -20_000),
		12_000, 9_000, 90,
	)
	projectile.source_cast_id = 7001
	projectile.material_strength = 0
	projectile.chemistry_interaction_mask = (1 << 36) - 1
	projectile.record_graze(3)
	projectile.record_graze(2)
	projectile.reaction_strength = 15
	projectile.range_subunit = 123_456
	var projectile_values := projectile.canonical_values()
	equal(projectile_values.size(), 30, "projectile canonical state appends strength and range remainder after its variable graze history")
	equal(projectile_values[25], 2, "published projectile graze-count index is unchanged")
	equal(projectile_values[26], 2, "first sorted graze ID retains its published index")
	equal(projectile_values[27], 3, "second sorted graze ID retains its published index")
	equal(projectile_values[28], 15, "cast strength follows the complete existing projectile payload")
	equal(projectile_values[29], 123_456, "range remainder follows cast strength without shifting published fields")
	var deposit := ElementDepositState.new()
	deposit.entity_id = 3000
	deposit.source_cast_id = 7001
	deposit.source_wire_id = CombatTuning.RILLSHOT_WIRE_ID
	deposit.owner_id = 1
	deposit.team_id = 2
	deposit.element_wire_id = 2
	deposit.position_x = 500_000
	deposit.position_y = 600_000
	deposit.created_tick = 100
	deposit.expiry_tick = 200
	deposit.reaction_strength = 15
	var deposit_values := deposit.canonical_values()
	equal(deposit_values.size(), 15, "deposit canonical state appends one value")
	equal(deposit_values[13], 200, "published deposit expiry index is unchanged")
	equal(deposit_values[14], 15, "deposit cast strength occupies the appended canonical index")
	check(ElementDepositState.from_values(deposit_values) != null, "fifteen-value deposit canonical state reconstructs")
	check(ElementDepositState.from_values(deposit_values.slice(0, 14)) == null, "fourteen-value deposit state fails closed after protocol migration")


func _test_production_command_and_world_payloads() -> void:
	var command := SimCommand.new(71, 3, -1000, 707, SimCommand.HELD_SPRINT | SimCommand.HELD_JUMP,
		SimCommand.PRESSED_SPELL_12, -333, 777, 98_765_432, 12_345_678)
	var expected_command := PackedByteArray()
	for value: int in [command.tick, command.entity_id, command.move_x, command.move_y,
		command.held_actions, command.pressed_actions, command.aim_x, command.aim_y, command.aim_target_x, command.aim_target_y]:
		_reference_append(expected_command, value)
	equal(command.canonical_bytes(), expected_command, "real command bytes match pre-optimization encoding")
	equal(expected_command.size(), 80, "protocol 43 commands serialize ten signed64 values including captured cursor coordinates")
	var world := SimWorld.new(120, 42, CollisionWorld.new(4_000_000, 3_000_000), "canonical-byte-fixture", "worldbone:風・水;bounds:4000x3000")
	check(world.is_valid(), "production world is valid for canonical encoding comparison")
	for entity_id: int in range(2, 4):
		var state := PlayerState.new(entity_id)
		state.team_id = entity_id
		state.position_x = entity_id * 600_000
		state.position_y = 1_700_000
		world.players.append(state)
	check(world.player(2).place_proven_spell(0, TIDE_SHELL_WIRE_ID), "world fixture equips a retained Heavy")
	check(world.player(3).place_proven_spell(0, RILL_STREAM_WIRE_ID), "world fixture equips a retained Rapid")
	var saw_projectile := false
	var saw_heavy := false
	var saw_rapid := false
	for tick_index: int in range(100):
		var commands: Array[SimCommand] = [
			SimCommand.new(world.tick, 1, -300, 400, SimCommand.HELD_PRIMARY, 0, 0, -1000),
			SimCommand.new(world.tick, 2, 1000, 0, 0, SimCommand.PRESSED_SPELL_1 if tick_index == 0 else 0, 0, -1000),
			SimCommand.new(world.tick, 3, -1000, 0, 0, SimCommand.PRESSED_SPELL_1 if tick_index == 0 else 0, 0, -1000),
		]
		check(world.step(commands), "real simulation advances canonical comparison tick %d" % tick_index)
		saw_projectile = saw_projectile or not world.projectiles.is_empty()
		for projectile: ProjectileState in world.projectiles:
			saw_heavy = saw_heavy or projectile.source_wire_id == TIDE_SHELL_WIRE_ID
			saw_rapid = saw_rapid or projectile.source_wire_id == RILL_STREAM_WIRE_ID
		var reference_payload := _world_payload(world, true)
		var native_payload := _world_payload(world, false)
		equal(native_payload, reference_payload, "full production world canonical bytes match at tick %d" % world.tick)
		equal(world.state_hash(), CanonicalBytes.sha256_hex(reference_payload), "actual SimWorld.state_hash remains exact at tick %d" % world.tick)
	check(saw_projectile and saw_heavy and saw_rapid, "world comparison exercised retained Heavy and Rapid projectiles, not only empty state")
	# Variable-length per-object histories also contribute to canonical bytes.
	if not world.projectiles.is_empty():
		world.projectiles[0].record_graze(3)
		world.projectiles[0].record_graze(2)
	equal(_world_payload(world, false), _world_payload(world, true), "variable-length projectile graze history preserves complete canonical bytes")
	equal(world.state_hash(), CanonicalBytes.sha256_hex(_world_payload(world, true)), "world hash retains variable-length histories")
	# Explicitly exercise nonempty chemistry lanes, their new ID counters, and
	# variable-length reaction data, not merely the two empty-lane count words.
	var matter: Array = []
	for index: int in range(3):
		equal(ElementChemistrySystem.deposit_terminal(matter, 3000 + index, 5000 + index, CombatTuning.CINDERBOLT_WIRE_ID, 1, 1, 2 + index, Vector2i(500_000, 500_000), world.tick, world.config), 1, "canonical fixture builds validated elemental material")
	world.deposits.append(matter[2])
	var reaction := ElementChemistrySystem.form_reaction(matter[0], matter[1], 4000, world.tick, world.config)
	reaction.linked_deposit_ids = PackedInt64Array([3002])
	reaction.path_points = PackedInt64Array([500_000, 500_000, 540_000, 500_000])
	reaction.contacts = PackedInt64Array([2, world.tick, 1, 3, world.tick, 0])
	world.reactions.append(reaction)
	world.next_deposit_id = 3003
	world.next_reaction_id = 4001
	check(world.deposits[0].validate() and reaction.validate(), "nonempty chemistry canonical fixture remains within real state bounds")
	equal(_world_payload(world, false), _world_payload(world, true), "deposit and variable-length reaction bytes preserve the frozen byte-at-a-time encoding")
	equal(world.state_hash(), CanonicalBytes.sha256_hex(_world_payload(world, true)), "actual world hash includes chemistry IDs, counts, fixed values, and variable histories")


static func _world_payload(world: SimWorld, reference: bool) -> PackedByteArray:
	# Explicit mirror of the published canonical field order; this must change
	# only with a deliberate world-hash contract migration, never for speed.
	var payload := PackedByteArray()
	for value: int in [SimConfig.PROTOCOL_VERSION, world.config.tick_rate, world.tick, world.seed, world.next_projectile_id, world.next_field_id, world.next_deposit_id, world.next_reaction_id]:
		_append_value(payload, value, reference)
	for value: String in [world.map_id, world.map_hash, world.transition_policy.content_hash]:
		if reference:
			_reference_string(payload, value)
		else:
			CanonicalBytes.append_string(payload, value)
	var players := world.players.duplicate()
	players.sort_custom(func(left: PlayerState, right: PlayerState) -> bool: return left.entity_id < right.entity_id)
	_append_value(payload, players.size(), reference)
	for state: PlayerState in players:
		for value: int in state.canonical_values():
			_append_value(payload, value, reference)
	_append_value(payload, world.projectiles.size(), reference)
	for projectile: ProjectileState in world.projectiles:
		for value: int in projectile.canonical_values():
			_append_value(payload, value, reference)
	_append_value(payload, world.fields.size(), reference)
	for field: FieldState in world.fields:
		for value: int in field.canonical_values():
			_append_value(payload, value, reference)
	_append_value(payload, world.deposits.size(), reference)
	for deposit: ElementDepositState in world.deposits:
		for value: int in deposit.canonical_values():
			_append_value(payload, value, reference)
	_append_value(payload, world.reactions.size(), reference)
	for reaction: ElementReactionState in world.reactions:
		for value: int in reaction.canonical_values():
			_append_value(payload, value, reference)
	return payload


static func _append_value(payload: PackedByteArray, value: int, reference: bool) -> void:
	if reference:
		_reference_append(payload, value)
	else:
		CanonicalBytes.append_i64(payload, value)


func _measure_append_cost() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 807_064
	var values := PackedInt64Array()
	for _index: int in range(8_192):
		values.append((int(random.randi()) << 32) | int(random.randi()))
	var reference_us := PackedInt64Array()
	var native_us := PackedInt64Array()
	for repeat_index: int in range(6):
		var reference := PackedByteArray([0x80, 0x00, 0xff])
		var native := reference.duplicate()
		var started := Time.get_ticks_usec()
		for value: int in values:
			_reference_append(reference, value)
		var legacy_elapsed := Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
		for value: int in values:
			CanonicalBytes.append_i64(native, value)
		var native_elapsed := Time.get_ticks_usec() - started
		equal(native, reference, "timed native buffer remains exact in repeat %d" % repeat_index)
		if repeat_index > 0:
			reference_us.append(legacy_elapsed)
			native_us.append(native_elapsed)
	reference_us.sort()
	native_us.sort()
	print("CANONICAL_ENCODING_PROBE values=8192 repeats=5 reference_median_us=%d native_median_us=%d reference_max_us=%d native_max_us=%d" % [
		reference_us[2], native_us[2], reference_us[4], native_us[4],
	])
