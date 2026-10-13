extends RefCounted
## Presentation-only admission evidence. Events received from a replica are not
## admission evidence: the caller must observe a successful local step before
## the next catch-up step. No authority, event or snapshot is retained or changed.

const MAX_WITNESSES := 8 # Supported champion roster; extra actors stay unknown.
var _world: WeakRef
var _last_observed_tick := -1
var _records: Dictionary = {}


func clear() -> void:
	_world = null
	_last_observed_tick = -1
	_records.clear()


func observe_local_step(world: SimWorld, events: Array[Dictionary], step_started_tick: int) -> void:
	if world == null or world.config == null or not world.config.is_valid() or world.tick != step_started_tick + 1:
		clear()
		return
	if _world == null or _world.get_ref() != world or world.tick < _last_observed_tick:
		clear()
		_world = weakref(world)
	if world.tick == _last_observed_tick:
		return # Repeated delivery cannot restart the same paid clock.
	if _last_observed_tick >= 0 and world.tick != _last_observed_tick + 1:
		_records.clear() # A missed boundary may contain cancellation/readmission.
	_last_observed_tick = world.tick
	for entity_id: int in _records.keys():
		if not _matches(world, world.player(entity_id), _records[entity_id]):
			_records.erase(entity_id)
	for event: Dictionary in events:
		if event.get("type") != "cast_started" or typeof(event.get("entity_id")) != TYPE_INT or typeof(event.get("wire_id")) != TYPE_INT:
			continue
		var actor: PlayerState = world.player(event.entity_id)
		if not _active(actor) or actor.pending_cast_wire_id != event.wire_id or _records.has(actor.entity_id) or _records.size() >= MAX_WITNESSES:
			continue
		_records[actor.entity_id] = {"actor": weakref(actor), "wire": actor.pending_cast_wire_id,
			"tick": world.tick, "total": actor.pending_cast_ticks}


func describe(world: SimWorld, actor: PlayerState) -> Dictionary:
	if world == null or world.config == null or not world.config.is_valid():
		clear()
		return {}
	if _world != null and (_world.get_ref() != world or world.tick != _last_observed_tick):
		clear()
	if not _active(actor):
		if actor != null: _records.erase(actor.entity_id)
		return {}
	var record: Dictionary = _records.get(actor.entity_id, {})
	if record.is_empty() or _world == null or _world.get_ref() != world or not _matches(world, actor, record):
		_records.erase(actor.entity_id)
		return for_state(actor, world.config)
	var total: int = record.total
	var elapsed: int = world.tick - int(record.tick)
	var progress := float(elapsed) / float(total)
	return {"entity_id": actor.entity_id, "wire_id": actor.pending_cast_wire_id,
		"remaining_ticks": actor.pending_cast_ticks, "tick_rate": world.config.tick_rate,
		"known_total": true, "total_ticks": total, "elapsed_ticks": elapsed,
		"progress": progress, "animation_progress": progress}


func _matches(world: SimWorld, actor: PlayerState, record: Dictionary) -> bool:
	return _active(actor) and world.player(actor.entity_id) == actor and (record.actor as WeakRef).get_ref() == actor \
		and actor.pending_cast_wire_id == int(record.wire) and world.tick >= int(record.tick) \
		and actor.pending_cast_ticks == int(record.total) - (world.tick - int(record.tick))


static func _active(actor: PlayerState) -> bool:
	return actor != null and actor.actor_kind == PlayerState.ActorKind.CHAMPION and actor.health > 0 \
		and actor.pending_cast_wire_id > 0 and actor.pending_cast_ticks > 0


static func known_for(state: PlayerState, tick_rate: int, timing: Dictionary) -> bool:
	if not _active(state) or not SimConfig.is_supported_tick_rate(tick_rate) \
		or typeof(timing.get("known_total")) != TYPE_BOOL or timing.known_total != true:
		return false
	for key: String in ["entity_id", "wire_id", "remaining_ticks", "tick_rate", "total_ticks", "elapsed_ticks"]:
		if typeof(timing.get(key)) != TYPE_INT: return false
	if timing.entity_id != state.entity_id or timing.wire_id != state.pending_cast_wire_id \
		or timing.remaining_ticks != state.pending_cast_ticks or timing.tick_rate != tick_rate \
		or timing.total_ticks <= 0 or timing.elapsed_ticks < 0 or timing.elapsed_ticks >= timing.total_ticks \
		or timing.total_ticks - timing.elapsed_ticks != state.pending_cast_ticks:
		return false
	for key: String in ["progress", "animation_progress"]:
		if typeof(timing.get(key)) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(timing[key])) \
			or not is_equal_approx(float(timing[key]), float(timing.elapsed_ticks) / float(timing.total_ticks)):
			return false
	return true


static func for_state(state: PlayerState, config: SimConfig, timing: Dictionary = {}) -> Dictionary:
	if not _active(state) or config == null or not config.is_valid(): return {}
	if known_for(state, config.tick_rate, timing): return timing # Read-only borrowed scalar projection.
	return {"entity_id": state.entity_id, "wire_id": state.pending_cast_wire_id,
		"remaining_ticks": state.pending_cast_ticks, "tick_rate": config.tick_rate,
		"known_total": false, "total_ticks": 0, "elapsed_ticks": -1, "progress": -1.0,
		"animation_progress": animation_progress(state, config)}


static func animation_progress(state: PlayerState, config: SimConfig, timing: Dictionary = {}) -> float:
	if state == null or state.health <= 0 or state.pending_cast_wire_id <= 0 or config == null or not config.is_valid(): return 0.0
	if known_for(state, config.tick_rate, timing): return float(timing.progress)
	# An artistic release-proximity coordinate for an unknown admission. This
	# is never exposed as elapsed time or a HUD fraction. Preserve the existing
	# authored anticipation window without inventing a new cast on observation.
	var definition := CombatTuning.cast_definition_view(state.pending_cast_wire_id)
	var window := maxi(1, config.milliseconds_to_ticks(int(definition.get("startup_ms", 0))))
	return clampf(1.0 - float(state.pending_cast_ticks) / float(window), 0.0, 1.0)


static func remaining_label(ticks: int, tick_rate: int) -> String:
	if ticks <= 0 or not SimConfig.is_supported_tick_rate(tick_rate): return ""
	# A still-active clock must never round down to a ready-looking 0.0 seconds.
	return "%.1fs" % (float(ceili(float(ticks) * 10.0 / float(tick_rate))) / 10.0)
