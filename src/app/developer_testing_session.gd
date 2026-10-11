class_name DeveloperTestingSession
extends RefCounted
## Explicit offline session tools. No save APIs, no earned unlocks, no time scale.

const TOGGLES: Array[String] = ["all_spells", "immortality", "infinite_flux", "infinite_stamina", "no_cooldown", "freeze_rival"]
const ACTIONS: Array[String] = ["refill", "reset_cooldowns", "reset_targets", "clear_shots"]
var active := false
var last_error := ""
var toggles := {"all_spells": false, "immortality": false, "infinite_flux": false, "infinite_stamina": false, "no_cooldown": false, "freeze_rival": false}
var _guard_actor: PlayerState
var _guard_world: SimWorld
var _original_guard_expiry := -1


func enter(offline: bool, in_hearth_or_practice: bool) -> bool:
	if not offline or not in_hearth_or_practice:
		last_error = "Developer tools require an offline sandbox or practice world."
		return false
	active = true
	last_error = ""
	return true


func set_all_spells(enabled: bool) -> bool:
	return set_toggle("all_spells", enabled)


func set_toggle(id: String, enabled: bool) -> bool:
	if not active or id not in TOGGLES: return false
	toggles[id] = enabled
	if id == "immortality" and not enabled: _restore_guard()
	return true


func leave() -> void:
	_restore_guard()
	active = false
	for id: String in TOGGLES: toggles[id] = false
	last_error = ""


func all_spells_enabled() -> bool:
	return active and bool(toggles.all_spells)


func freezes_rival() -> bool:
	return active and bool(toggles.freeze_rival)


func apply_continuous(world: SimWorld, offline: bool, practice: bool) -> bool:
	if not _admit(world, offline, practice): return false
	var actor := world.player(1)
	if bool(toggles.immortality):
		if _guard_actor != actor or _guard_world != world:
			_restore_guard()
			_guard_actor = actor
			_guard_world = world
			_original_guard_expiry = world.tick + actor.spawn_protection_ticks
		# This is the real damage guard; renderer and damage system agree. Keep
		# a natural longer spawn shield rather than cutting it to the cheat lease.
		actor.spawn_protection_ticks = maxi(actor.spawn_protection_ticks, 2)
	if bool(toggles.infinite_flux): actor.flux = actor.flux_maximum
	if bool(toggles.infinite_stamina): actor.stamina = actor.stamina_maximum
	if bool(toggles.no_cooldown): _reset_cooldowns(actor)
	return true


func apply(action: String, world: SimWorld, offline: bool, practice: bool) -> bool:
	if action not in ACTIONS or not _admit(world, offline, practice): return false
	return apply_practice_action(action, world, offline, practice)


static func apply_practice_action(action: String, world: SimWorld, offline: bool, practice: bool) -> bool:
	# Range exposes explicit reset/refill independently of developer toggles.
	# Caller must designate an isolated local practice, never a shared Hearth.
	if not offline or not practice or world == null or not world.is_valid() or world.player(1) == null or action not in ACTIONS: return false
	var actor := world.player(1)
	match action:
		"refill":
			if actor.health <= 0: return false
			actor.health = actor.health_maximum
			actor.flux = actor.flux_maximum
			actor.stamina = actor.stamina_maximum
		"reset_cooldowns":
			_reset_cooldowns(actor)
		"reset_targets":
			for target: PlayerState in world.players:
				if target.actor_kind == PlayerState.ActorKind.TRAINING_TARGET:
					target.reset_for_spawn(Vector2i(target.training_spawn_x, target.training_spawn_y), 0)
		"clear_shots":
			world.projectiles.clear()
			world.fields.clear()
			world.deposits.clear()
			world.reactions.clear()
			for state: PlayerState in world.players:
				state.pending_cast_wire_id = 0
				state.pending_cast_ticks = 0
				state.pending_cast_target_x = -1
				state.pending_cast_target_y = -1
			if world.hex_court != null:
				world.hex_court.retire_round_material()
				if world.collision is HexCollisionWorld: world.collision.set_hex_surfaces(world.hex_court, world.tick)
	return true


func view() -> Dictionary:
	var labels: Array[String] = []
	for id: String in TOGGLES:
		if bool(toggles[id]): labels.append("pause rival commands" if id == "freeze_rival" else id.replace("_", " "))
	return {"active": active, "toggles": toggles.duplicate(), "active_labels": labels,
		"notice": "DEVELOPER SESSION - no earned progress; overrides end when you leave." if active else "Developer tools are off.",
		"characters": "All 30 characters are already available.", "error": last_error}


func _admit(world: SimWorld, offline: bool, practice: bool) -> bool:
	if not offline:
		leave()
		last_error = "Developer tools ended before network play."
		return false
	if not active or not practice or world == null or not world.is_valid() or world.player(1) == null: return false
	return true


func _restore_guard() -> void:
	if _guard_actor != null and _guard_world != null:
		_guard_actor.spawn_protection_ticks = maxi(0, _original_guard_expiry - _guard_world.tick)
	_guard_actor = null
	_guard_world = null
	_original_guard_expiry = -1


static func _reset_cooldowns(actor: PlayerState) -> void:
	for wire: int in actor.spell_wire_ids: actor.set_spell_cooldown(wire, 0)
	for wire: int in actor.kit_spell_wire_ids(): actor.set_spell_cooldown(wire, 0)
