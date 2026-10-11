class_name SignatureChallengeSession
extends RefCounted
## One bound offline encounter; simulation produces every cast, hit and result.

const Trial = preload("res://src/app/solo_duel_trial.gd")
const Rival = preload("res://src/app/solo_duel_rival.gd")
const WINDUP_TICKS := 96
const PRESSURE_TICKS := 84
const PAUSE_TICKS := 180
const CYCLE_TICKS := WINDUP_TICKS + PRESSURE_TICKS + PAUSE_TICKS

var trial := Trial.new()
var definition: Dictionary = {}
var reward: Dictionary = {}
var tainted := false
var _authority: SimWorld
var _signature_slot := 0
var _reward_checked := false
var _paid_damage := false
var _last_tick := -1
var _locked_target := Vector2i(-1, -1)


func begin(world: SimWorld, bounds_pixels: Rect2i, challenge: Dictionary, offline: bool, developer_active: bool = false) -> bool:
	if not offline or world == null or challenge.is_empty(): return false
	var opponent := world.player(2)
	var wire := int(challenge.get("signature_wire", 0))
	if opponent == null or opponent.champion_wire_id != int(challenge.get("champion_wire_id", 0)) or not CombatTuning.is_runtime_wire_id(wire): return false
	var slot := opponent.spell_slot_index_for_wire(wire) + 1
	if slot <= 0 or not trial.begin(world, bounds_pixels): return false
	_authority = world
	definition = challenge.duplicate(true)
	_signature_slot = slot
	tainted = developer_active
	reward = {}
	_reward_checked = false
	_paid_damage = false
	_last_tick = world.tick
	_locked_target = Vector2i(-1, -1)
	return true


func reset() -> void:
	trial.reset()
	_authority = null
	definition.clear()
	reward.clear()
	tainted = false
	_signature_slot = 0
	_reward_checked = false
	_paid_damage = false
	_last_tick = -1
	_locked_target = Vector2i(-1, -1)


func status(world_tick: int) -> Dictionary:
	if definition.is_empty(): return {}
	var elapsed := maxi(0, world_tick - trial.start_tick)
	if elapsed < Rival.READY_END:
		return {"phase": "ready", "cue": "Read the signature, then defeat the rival to learn it.", "remaining_ticks": Rival.READY_END - elapsed, "telegraph": "", "break": false}
	var phase_tick := posmod(elapsed - Rival.READY_END, CYCLE_TICKS)
	if phase_tick < WINDUP_TICKS:
		return {"phase": "windup", "cue": "Contact Mantle: keep space while the rival approaches." if String(definition.family) == "mantle" else String(definition.tell), "remaining_ticks": WINDUP_TICKS - phase_tick, "telegraph": String(definition.family), "break": false}
	if phase_tick < WINDUP_TICKS + PRESSURE_TICKS:
		return {"phase": "pressure", "cue": String(definition.spell_name) + " attempt; normal Flux and cooldown checks still apply.", "remaining_ticks": WINDUP_TICKS + PRESSURE_TICKS - phase_tick, "telegraph": String(definition.family), "break": false}
	return {"phase": "recover", "cue": "No new casts during this pause; existing shots and fields remain dangerous.", "remaining_ticks": CYCLE_TICKS - phase_tick, "telegraph": "", "break": true}


func command(world: SimWorld) -> SimCommand:
	if world == null or world != _authority or not trial.is_running(): return null
	var opponent := world.player(2)
	var player := world.player(1)
	if not Rival._valid_actors(opponent, player, trial.court): return null
	if opponent.spell_wire_id(_signature_slot) != int(definition.signature_wire):
		tainted = true
		return null
	var aim := Vector2i(opponent.aim_x, opponent.aim_y)
	var move := Vector2i.ZERO
	var held := 0
	var pressed := 0
	var elapsed := world.tick - trial.start_tick - Rival.READY_END
	if elapsed >= 0:
		var phase_tick := posmod(elapsed, CYCLE_TICKS)
		if phase_tick == 0:
			_locked_target = Vector2i(player.position_x, player.position_y)
			aim = _locked_target - Vector2i(opponent.position_x, opponent.position_y)
		var close_mantle := String(definition.family) == "mantle"
		var separation := Vector2i(player.position_x - opponent.position_x, player.position_y - opponent.position_y)
		if phase_tick == WINDUP_TICKS and (not close_mantle or separation.length_squared() <= 100000 * 100000):
			pressed = SimCommand.SPELL_PRESSED_BITS[_signature_slot - 1]
		if String(definition.family) == "rapid" and phase_tick >= WINDUP_TICKS and phase_tick < WINDUP_TICKS + 60:
			held = SimCommand.SPELL_HELD_BITS[_signature_slot - 1]
		if close_mantle and phase_tick < WINDUP_TICKS + PRESSURE_TICKS:
			move = SimCommand._normalized_direction(separation.x, separation.y) if separation.length_squared() > 38000 * 38000 else Vector2i.ZERO
		elif phase_tick >= WINDUP_TICKS + 30 and phase_tick < WINDUP_TICKS + PRESSURE_TICKS:
			move = Rival._movement(opponent, player, trial.court, floori(float(elapsed) / float(CYCLE_TICKS)))
	var target := _locked_target if String(definition.family) == "fuse" else Vector2i(-1, -1)
	return SimCommand.new(world.tick, opponent.entity_id, move.x, move.y, held, pressed, aim.x, aim.y, target.x, target.y)


func observe(world: SimWorld, progression: SignatureProgression, offline: bool, developer_active: bool = false) -> bool:
	# Once tainted, toggling a cheat off cannot turn this same attempt into a reward.
	if not offline or developer_active: tainted = true
	if world == null or world != _authority or world.tick <= _last_tick: return false
	_last_tick = world.tick
	var owned_defeat := false
	for event: Dictionary in world.combat_events:
		if int(event.get("owner_id", 0)) != 1 or int(event.get("target_id", 0)) != 2: continue
		if int(event.get("damage", 0)) > 0: _paid_damage = true
		if String(event.get("type", "")) == "champion_defeated": owned_defeat = true
	if not trial.observe(world): return false
	if trial.is_finished() and not _reward_checked:
		_reward_checked = true
		if trial.phase == Trial.VICTORY and offline and not tainted and _paid_damage and owned_defeat and progression != null:
			reward = progression.record_victory(String(definition.id))
		else:
			reward = {"ok": false, "new": false, "saved": false, "notice": "Developer practice: no earned progress." if tainted else "No signature learned from this result."}
	return true


func view() -> Dictionary:
	var result: Dictionary = trial.view()
	result["challenge"] = definition.duplicate(true)
	result["reward"] = reward.duplicate(true)
	result["developer"] = tainted
	result["rival"] = status(trial.last_observed_tick)
	return result
