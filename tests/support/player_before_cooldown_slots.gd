extends "res://src/sim/entities/player_state.gd"

# Frozen cooldown implementation before zero-work / alias lookup reuse.
# Source SHA-256: dc310912992acbe88ce2631cdfb36a5bf66a041837ad2f6d24e7a539189ac5d0

func advance_spell_cooldowns() -> void:
	if spell_cooldown_ticks.size() != SPELL_SLOT_COUNT:
		spell_cooldown_ticks = PackedInt32Array()
		spell_cooldown_ticks.resize(SPELL_SLOT_COUNT)
		spell_cooldown_ticks.fill(0)
	_import_legacy_spell_cooldowns()
	if spell_slot_index_for_wire(primary_wire_id) < 0: primary_cooldown_ticks = maxi(0, primary_cooldown_ticks - 1)
	if spell_slot_index_for_wire(active_1_wire_id) < 0: active_1_cooldown_ticks = maxi(0, active_1_cooldown_ticks - 1)
	if spell_slot_index_for_wire(active_2_wire_id) < 0: active_2_cooldown_ticks = maxi(0, active_2_cooldown_ticks - 1)
	for slot_index: int in range(SPELL_SLOT_COUNT):
		spell_cooldown_ticks[slot_index] = maxi(0, int(spell_cooldown_ticks[slot_index]) - 1)
	_sync_legacy_spell_cooldowns()


func _import_legacy_spell_cooldowns() -> void:
	for pair: Vector2i in [
		Vector2i(primary_wire_id, primary_cooldown_ticks),
		Vector2i(active_1_wire_id, active_1_cooldown_ticks),
		Vector2i(active_2_wire_id, active_2_cooldown_ticks),
	]:
		var slot_index := spell_slot_index_for_wire(pair.x)
		if pair.x > 0 and slot_index >= 0:
			spell_cooldown_ticks[slot_index] = maxi(int(spell_cooldown_ticks[slot_index]), pair.y)


func _sync_legacy_spell_cooldowns() -> void:
	# E and controller aliases retain their own cooldown if absent from the
	# configurable weave; a slot holding the same spell shares that cooldown.
	if spell_slot_index_for_wire(primary_wire_id) >= 0: primary_cooldown_ticks = _stored_spell_cooldown(primary_wire_id)
	if spell_slot_index_for_wire(active_1_wire_id) >= 0: active_1_cooldown_ticks = _stored_spell_cooldown(active_1_wire_id)
	if spell_slot_index_for_wire(active_2_wire_id) >= 0: active_2_cooldown_ticks = _stored_spell_cooldown(active_2_wire_id)
	if active_2_wire_id <= 0: active_2_cooldown_ticks = 0


func _stored_spell_cooldown(wire_id: int) -> int:
	var slot_index := spell_slot_index_for_wire(wire_id)
	return int(spell_cooldown_ticks[slot_index]) if slot_index >= 0 and spell_cooldown_ticks.size() == SPELL_SLOT_COUNT else 0
