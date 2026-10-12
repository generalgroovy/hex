class_name SignatureChallengeSession
extends RefCounted
## One bound offline encounter; simulation produces every cast, hit and result.

const Trial = preload("res://src/app/solo_duel_trial.gd")
const Rival = preload("res://src/app/solo_duel_rival.gd")
const Policy = preload("res://src/app/signature_rival_policy.gd")
const DamageEvent = preload("res://src/sim/combat/combat_damage_event.gd")

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
	return Policy.status(world_tick, trial.start_tick, String(definition.family))


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
	var family := String(definition.family)
	var current := status(world.tick)
	var delivery: Dictionary = Policy.PROFILES.get(family, {})
	if current.is_empty() or delivery.is_empty(): return null
	var spell := CombatTuning.cast_definition_view(int(definition.signature_wire))
	var phase := String(current.phase)
	if phase in ["windup", "pressure"]:
		var phase_tick := int(current.cycle_tick)
		var pressure_tick := phase_tick-int(delivery.windup)
		var position := Vector2i(opponent.position_x, opponent.position_y)
		var inside := trial.court.has_point(position)
		var committing := phase_tick >= int(delivery.windup)-Policy.COMMIT_TICKS
		# Rapid's next line is committed at the start of a full tell-length gap.
		# Existing finite shots remain dangerous, but no paid shot retargets.
		var rapid_new_line := family=="rapid" and phase=="pressure" and pressure_tick in [Policy.RAPID_BURST_TICKS,Policy.RAPID_PERIOD_TICKS+Policy.RAPID_BURST_TICKS]
		if phase_tick <= int(delivery.windup)-Policy.COMMIT_TICKS or rapid_new_line:
			_locked_target = Vector2i(player.position_x, player.position_y)
			aim = Policy.committed_aim(position, _locked_target, spell, world.collision) if phase_tick == int(delivery.windup)-Policy.COMMIT_TICKS else _locked_target-position
		if inside and pressure_tick == 0 and Policy.can_attempt(opponent, player, spell):
			pressed = SimCommand.SPELL_PRESSED_BITS[_signature_slot-1]
		if inside and family == "rapid" and phase == "pressure" and posmod(pressure_tick,Policy.RAPID_PERIOD_TICKS) < Policy.RAPID_BURST_TICKS and Policy.can_attempt(opponent, player, spell):
			held = SimCommand.SPELL_HELD_BITS[_signature_slot-1]
		# The final facing tell is stationary. Mantle must pursue to demonstrate
		# actual paid contact; ranged forms may strafe after their startup releases.
		var can_move := not inside or family == "mantle" or (phase == "windup" and not committing) or (phase == "pressure" and pressure_tick >= maxi(30,world.config.milliseconds_to_ticks(int(spell.startup_ms))+1))
		if can_move:
			move = Policy.movement(opponent, player, trial.court, world.collision, family, int(current.cycle_index), phase == "pressure")
	var target := _locked_target if family == "fuse" else Vector2i(-1, -1)
	return SimCommand.new(world.tick, opponent.entity_id, move.x, move.y, held, pressed, aim.x, aim.y, target.x, target.y)


func observe(world: SimWorld, progression: SignatureProgression, offline: bool, developer_active: bool = false) -> bool:
	# Once tainted, toggling a cheat off cannot turn this same attempt into a reward.
	if not offline or developer_active: tainted = true
	if world == null or world != _authority or world.tick <= _last_tick: return false
	_last_tick = world.tick
	var owned_defeat := false
	for event: Dictionary in world.combat_events:
		if int(event.get("owner_id", 0)) != 1 or DamageEvent.target_id(event) != 2: continue
		if DamageEvent.amount(event) > 0: _paid_damage = true
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
