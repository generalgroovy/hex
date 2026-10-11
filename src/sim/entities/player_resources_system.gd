class_name PlayerResourcesSystem
extends RefCounted

const Recovery = preload("res://src/sim/entities/resource_recovery.gd")
const Perks = preload("res://src/sim/entities/identity_perk_policy.gd")

static func step(state: PlayerState, config: SimConfig) -> void:
	state.spawn_protection_ticks = maxi(0, state.spawn_protection_ticks - 1)
	state.health_recovery_delay_ticks = maxi(0, state.health_recovery_delay_ticks - 1)
	state.flux_recovery_delay_ticks = maxi(0, state.flux_recovery_delay_ticks - 1)
	state.flux_recovery_idle_ticks = Recovery.advance_idle(state.flux_recovery_idle_ticks, state.flux_recovery_delay_ticks, config.tick_rate)
	if state.health > 0 and state.health_recovery_delay_ticks == 0 and state.chemistry_regen_block_ticks == 0 and not SpellStatusPolicy.active(state,5):
		_apply_health_rate(state, state.health_recovery_per_second, config)
	if state.flux_recovery_delay_ticks == 0 and state.chemistry_regen_block_ticks == 0 and not SpellStatusPolicy.active(state,5):
		_apply_flux_rate(state, Recovery.rate_per_second(state.flux_recovery_per_second, state.flux_recovery_idle_ticks, config.tick_rate), config)


static func damage(state: PlayerState, amount: int, config: SimConfig) -> bool:
	if amount <= 0 or state.health <= 0 or MovementSystem.is_combat_intangible(state, config):
		return false
	state.health = maxi(0, state.health - Perks.scale(state, "incoming_damage_ratio", amount))
	state.health_recovery_remainder = 0
	state.health_recovery_delay_ticks = config.milliseconds_to_ticks(PlayerTuning.HEALTH_RECOVERY_DELAY_MS)
	return true


static func spend_flux(state: PlayerState, amount: int, config: SimConfig) -> bool:
	if amount <= 0 or state.flux < amount:
		return false
	state.flux -= amount
	state.flux_recovery_remainder = 0
	state.flux_recovery_delay_ticks = config.milliseconds_to_ticks(PlayerTuning.FLUX_RECOVERY_DELAY_MS)
	state.flux_recovery_idle_ticks = 0
	return true


static func _apply_health_rate(state: PlayerState, rate_per_second: int, config: SimConfig) -> void:
	rate_per_second = Perks.scale(state, "health_recovery_ratio", rate_per_second)
	var total: int = state.health_recovery_remainder + rate_per_second
	@warning_ignore("integer_division")
	var amount: int = total / config.tick_rate
	state.health_recovery_remainder = total - amount * config.tick_rate
	state.health = clampi(state.health + amount, 0, state.health_maximum)


static func _apply_flux_rate(state: PlayerState, rate_per_second: int, config: SimConfig) -> void:
	rate_per_second = Perks.scale(state, "flux_recovery_ratio", rate_per_second)
	var total: int = state.flux_recovery_remainder + rate_per_second
	@warning_ignore("integer_division")
	var amount: int = total / config.tick_rate
	state.flux_recovery_remainder = total - amount * config.tick_rate
	state.flux = clampi(state.flux + amount, 0, state.flux_maximum)
