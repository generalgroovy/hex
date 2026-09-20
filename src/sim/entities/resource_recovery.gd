class_name ResourceRecovery
extends RefCounted


# Pure integer helper shared by simulation and read-only presentation. Idle
# age is independent per resource, bounded, and reset only by positive spending.
static func maximum_idle_ticks(tick_rate: int) -> int:
	@warning_ignore("integer_division")
	var ticks := (PlayerTuning.RESOURCE_RECOVERY_RAMP_MS * maxi(1, tick_rate) + 999) / 1000
	return maxi(1, ticks)


static func advance_idle(idle_ticks: int, recovery_delay_ticks: int, tick_rate: int) -> int:
	var maximum := maximum_idle_ticks(tick_rate)
	var current := clampi(idle_ticks, 0, maximum)
	return current if recovery_delay_ticks > 0 else mini(maximum, current + 1)


static func rate_per_second(base_rate: int, idle_ticks: int, tick_rate: int) -> int:
	var safe_base := maxi(0, base_rate)
	var maximum := maximum_idle_ticks(tick_rate)
	var quiet_ticks := clampi(idle_ticks, 0, maximum)
	@warning_ignore("integer_division")
	var bonus := safe_base * (PlayerTuning.RESOURCE_RECOVERY_MAXIMUM_RATIO - 1000) * quiet_ticks / (maximum * 1000)
	return safe_base + bonus
