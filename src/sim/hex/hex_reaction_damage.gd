extends RefCounted
## A reaction owns one finite damage pool shared by all actors and descendants.
## Limit the raw quote before the perk applies, then debit actual Health loss.
@warning_ignore_start("integer_division")
const Perks = preload("res://src/sim/entities/identity_perk_policy.gd")
const DAMAGE_PER_STRENGTH := 4_000
const MAX_FUNDED_STRENGTH := 180


static func apply(product: Dictionary, actor: PlayerState, quote: int, config: SimConfig) -> int:
	if quote <= 0 or actor == null or actor.health <= 0 or actor.spawn_protection_ticks > 0 or MovementSystem.is_combat_intangible(actor, config): return 0
	var pool := int(product.get("damage_budget_remaining", 0))
	if pool <= 0: return 0
	var ratio := Perks.ratio(actor, "incoming_damage_ratio")
	# floor(raw*ratio/1000) <= pool, including positive damage's one-unit floor.
	var maximum_quote := ((pool + 1) * 1000 - 1) / ratio
	var damage := mini(quote, maximum_quote)
	if damage <= 0: return 0
	var before := actor.health
	if not PlayerResourcesSystem.damage(actor, damage, config): return 0
	var actual := before - actor.health
	assert(actual >= 0 and actual <= pool)
	product.damage_budget_remaining = pool - actual
	return actual
