extends "res://src/sim/core/sim_command.gd"

# Exact original slot-search bodies (no zero-mask shortcut).
# Source SHA-256: 1f3232ed44aae4aa4b4b0d5b49585799fde3c613c009b434f17914b9792b263f

func first_pressed_spell_slot() -> int:
	for index: int in range(SPELL_PRESSED_BITS.size()):
		if has_pressed(SPELL_PRESSED_BITS[index]):
			return index + 1
	return 0


func first_held_spell_slot() -> int:
	for index: int in range(SPELL_HELD_BITS.size()):
		if has_held(SPELL_HELD_BITS[index]):
			return index + 1
	return 0
