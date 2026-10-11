class_name SpellStatusPolicy
extends RefCounted
## Six fixed nonstacking channels. No status hit creates another status or matter.
const STRIDE := 8
const VALUE_COUNT := 48
const BITS: Array[int] = [1,2,4,8,16,32]
const NAMES: Array[String] = ["Fractured Focus", "Burning", "Chilled", "Gusted", "Revealed", "Withered"]
const Perks = preload("res://src/sim/entities/identity_perk_policy.gd")

static func active(state: PlayerState, channel: int) -> bool:
	return channel >= 0 and channel < 6 and state != null and state.spell_status_values.size() == VALUE_COUNT and state.spell_status_values[channel*STRIDE] > 0

static func potency(state: PlayerState, channel: int) -> int:
	return int(state.spell_status_values[channel*STRIDE+1]) if active(state,channel) else 0

static func startup_ratio(state: PlayerState) -> int:
	return 1000+potency(state,0)

static func movement_ratio(state: PlayerState) -> int:
	return 1000-potency(state,2)

static func apply_hit(target: PlayerState, wire: int, source: int, owner: int, team: int, actual_loss: int, config: SimConfig, direction: Vector2i) -> void:
	if actual_loss <= 0 or target.health <= 0 or target.spawn_protection_ticks > 0 or MovementSystem.is_combat_intangible(target,config): return
	if target.entity_id == owner or target.team_id == team or source <= 0: return
	var definition := CombatTuning.cast_definition_view(wire)
	var mask := int(definition.get("element_mask",0))
	var ticks := config.milliseconds_to_ticks(int(definition.get("status_duration_ms",600)))
	var strengths: Array[int] = [80,1000,120,80,1000,1000]
	for channel: int in 6:
		if mask & BITS[channel] == 0: continue
		var offset := channel*STRIDE
		var was_active := active(target,channel)
		var pool := mini(2400,maxi(1,actual_loss/4)) if channel == 1 else 0
		# Replacement keeps one source of attribution and never adds two pools.
		# Exact ties choose the smaller stable source, independent of row order.
		var old_pool := int(target.spell_status_values[offset+2])
		var replace := not was_active or pool > old_pool or (pool == old_pool and source < int(target.spell_status_values[offset+7]))
		target.spell_status_values[offset] = maxi(ticks,int(target.spell_status_values[offset]))
		if replace:
			var row := PackedInt32Array([target.spell_status_values[offset],strengths[channel],pool,12 if channel == 1 else 0,owner,team,wire,source])
			for index: int in STRIDE: target.spell_status_values[offset+index] = row[index]
		if channel == 3 and not was_active:
			# One immediate bounded push; no launch state, stun, or refreshed shove.
			target.velocity_x = clampi(target.velocity_x + direction.x*80,-2_000_000,2_000_000)
			target.velocity_y = clampi(target.velocity_y + direction.y*80,-2_000_000,2_000_000)
			target.air_velocity_x = clampi(target.air_velocity_x + direction.x*80,-2_000_000,2_000_000)
			target.air_velocity_y = clampi(target.air_velocity_y + direction.y*80,-2_000_000,2_000_000)

static func advance(state: PlayerState, config: SimConfig, events: Array[Dictionary], damage_enabled: bool = true) -> void:
	if state.spell_status_values.size() != VALUE_COUNT: return
	if state.health <= 0:
		state.spell_status_values.fill(0)
		return
	for channel: int in 6:
		var offset := channel*STRIDE
		if state.spell_status_values[offset] <= 0: continue
		state.spell_status_values[offset] -= 1
		if state.spell_status_values[offset] == 0:
			for index: int in STRIDE: state.spell_status_values[offset+index] = 0
			continue
		if channel != 1: continue
		state.spell_status_values[offset+3] = maxi(0,state.spell_status_values[offset+3]-1)
		if state.spell_status_values[offset+3] > 0: continue
		state.spell_status_values[offset+3] = 12
		if not damage_enabled: continue
		if state.spawn_protection_ticks > 0 or MovementSystem.is_combat_intangible(state,config): continue
		var remaining := int(state.spell_status_values[offset+2])
		if remaining <= 0: continue
		var desired := mini(remaining,400)
		var low := 0
		var high := desired*2+1
		while low+1 < high:
			var mid := (low+high)/2
			if Perks.scale(state,"incoming_damage_ratio",mid) <= desired: low = mid
			else: high = mid
		var before := state.health
		if low <= 0 or not PlayerResourcesSystem.damage(state,low,config): continue
		var loss := before-state.health
		state.spell_status_values[offset+2] -= loss
		events.append({"type":"spell_status_hit","owner_id":int(state.spell_status_values[offset+4]),"source_wire_id":int(state.spell_status_values[offset+6]),"target_id":state.entity_id,"damage":loss,"status":"burning"})
		if state.health == 0:
			events.append({"type":"champion_defeated","projectile_id":0,"owner_id":int(state.spell_status_values[offset+4]),"target_id":state.entity_id})
			state.spell_status_values.fill(0)
			return
