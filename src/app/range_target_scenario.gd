extends RefCounted
## Isolated offline Range commands and observations. Settings never grant
## player resources, cast a spell, alter a save, or record an earned victory.
const Damage = preload("res://src/sim/combat/combat_damage_event.gd")
const SIZE_IDS := ["s_wayne","oh_tipi","ba_djoh"]
const SIZE_LABELS := ["Small","Medium","Large"]
var active := false
var moving := false
var firing := false
var size_index := 1
var _world: SimWorld
var _radii: Array[int] = []
var _origin := Vector2i.ZERO
var _last_tick := -1
var _started_tick := 0
var _behavior_started_tick := 0
var _stats := {}


func begin(world: SimWorld, champions: ChampionCatalog, offline: bool) -> bool:
	if active or not offline or world==null or champions==null or world.players.size()!=2 or world.player(2).actor_kind!=PlayerState.ActorKind.TRAINING_TARGET: return false
	var radii: Array[int] = []
	for id: String in SIZE_IDS:
		var exemplar := PlayerState.new()
		if not champions.apply_to_player(exemplar,id): return false
		radii.append(exemplar.radius)
	var profile := PlayerState.new()
	if not champions.apply_to_player(profile,"oh_tipi"): return false
	var target := world.player(2)
	var shot := MixtureCatalog.wire_for(16,"rapid")
	if not target.place_proven_spell(0,shot): return false
	# The fresh isolated target receives one ordinary finite practice budget.
	# Switching settings later never refills it or changes its recovery clocks.
	target.flux_maximum = profile.flux_maximum
	target.flux = target.flux_maximum
	target.flux_recovery_per_second = profile.flux_recovery_per_second
	target.movement_speed_ratio = profile.movement_speed_ratio
	_world = world
	_radii = radii
	_origin = Vector2i(target.position_x,target.position_y)
	_behavior_started_tick = world.tick
	active = true
	moving = false
	firing = false
	size_index = 1
	target.radius = _radii[size_index]
	reset_statistics()
	return true


func close() -> void:
	active = false
	_world = null
	_radii.clear()
	_stats.clear()


func set_moving(enabled: bool) -> bool:
	if not _admitted(): return false
	moving = enabled
	return true


func set_firing(enabled: bool) -> bool:
	if not _admitted(): return false
	firing = enabled
	return true


func cycle_size() -> bool:
	if not _admitted() or _radii.size()!=3: return false
	size_index = posmod(size_index+1,3)
	_world.player(2).radius = _radii[size_index]
	return true


func reset_statistics() -> bool:
	if not _admitted(): return false
	_started_tick = _world.tick
	_last_tick = _world.tick
	_stats = {"player_casts":0,"player_flux":0,"target_casts":0,"target_flux":0,
		"damage_to_target":0,"damage_to_player":0,"ground_damage":0,"status_damage":0,"direct_damage":0,
		"status_ticks":[0,0,0,0,0,0]}
	return true


func command() -> SimCommand:
	if not _admitted(): return null
	var target := _world.player(2)
	var actor := _world.player(1)
	if target.health<=0 or actor.health<=0: return null
	var position := Vector2i(target.position_x,target.position_y)
	var direction := Vector2i.ZERO
	if moving:
		var destination := _origin+Vector2i(120000 if posmod(_world.tick-_behavior_started_tick,240)<120 else -120000,0)
		if (destination-position).length_squared()>6000*6000:
			direction = SimCommand._normalized_direction(destination.x-position.x,destination.y-position.y)
	var aim := Vector2i(actor.position_x,actor.position_y)-position
	var held := SimCommand.SPELL_HELD_BITS[0] if firing and posmod(_world.tick-_behavior_started_tick,48)<18 else 0
	return SimCommand.new(_world.tick,2,direction.x,direction.y,held,0,aim.x,aim.y)


func observe() -> void:
	if not _admitted() or _world.tick<=_last_tick: return
	_last_tick = _world.tick
	for event: Dictionary in _world.combat_events:
		if String(event.get("type",""))=="cast_started":
			var owner := int(event.get("entity_id",0))
			if owner not in [1,2]: continue
			var prefix := "player" if owner==1 else "target"
			_stats[prefix+"_casts"] += 1
			_stats[prefix+"_flux"] += int(CombatTuning.cast_definition_view(int(event.wire_id)).flux_cost)
		var damage := Damage.amount(event)
		if damage<=0: continue
		if Damage.target_id(event)==1: _stats.damage_to_player += damage
		if Damage.target_id(event)!=2 or int(event.get("owner_id",0))!=1: continue
		_stats.damage_to_target += damage
		if String(event.get("type","")) in Damage.GROUND_TYPES: _stats.ground_damage += damage
		elif String(event.get("type",""))=="spell_status_hit": _stats.status_damage += damage
		else: _stats.direct_damage += damage
	for index: int in 6:
		if SpellStatusPolicy.active(_world.player(2),index):
			_stats.status_ticks[index] += 1


func view() -> Dictionary:
	if not _admitted(): return {}
	return {"active":active,"moving":moving,"firing":firing,"size":String(SIZE_LABELS[size_index]),
		"radius":_world.player(2).radius,"elapsed_ticks":_world.tick-_started_tick,"elapsed_seconds":float(_world.tick-_started_tick)/_world.config.tick_rate,"statistics":_stats.duplicate(true),
		"scope":"Size changes only the hurt radius. Target movement and shots use ordinary commands and finite Flux. Reset statistics changes counters only; results are this attempt, not a balance ranking."}


func _admitted() -> bool:
	return active and _world!=null and _world.players.size()==2 and _world.player(1)!=null and _world.player(2)!=null and _world.player(2).actor_kind==PlayerState.ActorKind.TRAINING_TARGET
