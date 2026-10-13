class_name SimConfig
extends RefCounted


# Heavy terminal blasts, authored held-slot Rapid firing and the expanded Loom.
# Existing wire fields remain; old peers must not simulate different attacks.
# The 48px hex lattice changes cell ownership, structures and map identity.
# Older 64px peers/replays must not enter the same authoritative simulation.
# Release jump, flight capabilities and movement cancellation change authority.
# Frozen teams, retained score ledgers and explicit result reasons change the
# replicated round contract. Old peers must not reinterpret these packets.
# Identity perk prediction now carries identity, resource and cast clocks.
const PROTOCOL_VERSION: int = 61
const FIXED_SCALE: int = 1000
const TICK_RATE: int = 120
# Cast admission and replication share one finite authority envelope. Pending
# casts reserve whole patterns before payment; presentation never hides a hit.
const MAX_ACTIVE_PROJECTILES: int = 128
const MAX_PROJECTILES_PER_PLAYER: int = 16
const MAX_ACTIVE_FIELDS: int = 32
const MAX_FIELDS_PER_PLAYER: int = 4

var tick_rate: int


func _init(requested_tick_rate: int = TICK_RATE) -> void:
	tick_rate = requested_tick_rate if is_supported_tick_rate(requested_tick_rate) else 0


static func is_supported_tick_rate(value: int) -> bool:
	return value == TICK_RATE


func is_valid() -> bool:
	return is_supported_tick_rate(tick_rate)


func milliseconds_to_ticks(milliseconds: int) -> int:
	if not is_valid() or milliseconds <= 0:
		return 0
	@warning_ignore("integer_division")
	return maxi(1, (milliseconds * tick_rate + 999) / 1000)


func per_tick(value_per_second: int) -> int:
	if not is_valid():
		return 0
	@warning_ignore("integer_division")
	return value_per_second / tick_rate
