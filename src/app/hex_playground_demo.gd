class_name HexPlaygroundDemo
extends RefCounted


const BENCH := Vector2i(1_504_000, 1_440_000)
const TARGET := Vector2i(1_504_000, 1_344_000)
const ElementRules = preload("res://src/content/element_rules.gd")
const ELEMENT_IDS = ElementRules.IDS
const MATTER_PER_CAST := 600
const CANCEL_TIMEOUT_TICKS := 240

const PHASE_IDLE := 0
const PHASE_READY_FIRST := 1
const PHASE_WAIT_FIRST_ACCEPT := 2
const PHASE_WAIT_FIRST_TERMINAL := 3
const PHASE_WAIT_SECOND_ACCEPT := 4
const PHASE_WAIT_SECOND_TERMINAL := 5
const PHASE_CANCEL_DRAIN := 6

var _phase: int = PHASE_IDLE
var _world: SimWorld = null
var _actor_id: int = 0
var _elements := PackedStringArray()
var _wires := PackedInt32Array()
var _slot_indices := PackedInt32Array()
var _recipe_wire_id: int = 0
var _start_tick: int = 0
var _deadline_tick: int = 0
var _issued_tick: int = -1
var _issued_cast_floor: int = 0
var _issued_index: int = -1
var _paid_receipts: Array[Dictionary] = []
var _observed_product: Dictionary = {}
var _terminal_result: Dictionary = {}
var _result_world: SimWorld = null
var _result_actor: PlayerState = null
var _saved_wires := PackedInt32Array()
var _saved_cooldowns := PackedInt32Array()
var _saved_primary_wire: int = 0
var _saved_active_1_wire: int = 0
var _saved_active_2_wire: int = 0
var _saved_primary_cooldown: int = 0
var _saved_active_1_cooldown: int = 0
var _saved_active_2_cooldown: int = 0
var _status: String = "Paid demo is ready."


func begin(world: SimWorld, actor_id: int, element_a: Variant, element_b: Variant, catalog: AbilityCatalog) -> bool:
	if is_active():
		_status = "Paid demo is already running."
		return false
	dismiss_result()
	var first_id := _element_id(element_a)
	var second_id := _element_id(element_b)
	if world == null or not world.is_valid() or world.hex_court == null:
		return _refuse_begin("ordinary whole-hex practice is unavailable")
	if not bool(world.hex_court.chemistry_enabled) or not world.fields.is_empty() or not world.deposits.is_empty() or not world.reactions.is_empty():
		return _refuse_begin("the world is not a clear whole-hex practice authority")
	if catalog == null or first_id.is_empty() or second_id.is_empty():
		return _refuse_begin("choose two of Water, Fire, Air, Earth, Light, or Dark")
	var actor := world.player(actor_id)
	if actor == null:
		return _refuse_begin("the selected actor is unavailable")
	if actor.health <= 0:
		return _refuse_begin("the selected actor must be alive")
	if actor.is_airborne() or actor.air_height != 0 or actor.air_vertical_velocity != 0 or actor.air_floating:
		return _refuse_begin("stand on the ground before running the paid demo")
	if actor.pending_cast_wire_id != 0:
		return _refuse_begin("finish the current cast before running the paid demo")
	if not actor.has_valid_spell_slots():
		return _refuse_begin("the current twelve-spell weave is invalid")
	if not world.collision.can_occupy(BENCH, MovementTuning.PLAYER_RADIUS):
		return _refuse_begin("the existing experiment bench is obstructed")
	if _has_owner_flight(world, actor_id):
		return _refuse_begin("finish the actor's current projectile before running the demo")

	var first := catalog.ability(catalog.spell_id_at(first_id, "bolt"))
	var second := catalog.ability(catalog.spell_id_at(second_id, "bolt"))
	if not _legal_bolt(first) or not _legal_bolt(second):
		return _refuse_begin("the selected production Bolt spells are unavailable")
	var first_wire := int(first.get("wire_id", 0))
	var second_wire := int(second.get("wire_id", 0))
	var first_cast := CombatTuning.cast_definition(first_wire)
	var second_cast := CombatTuning.cast_definition(second_wire)
	var required_flux := int(first_cast.get("flux_cost", 0)) + int(second_cast.get("flux_cost", 0))
	if required_flux <= 0 or actor.flux < required_flux:
		return _refuse_begin("both paid Bolts require %.1f Flux" % (float(required_flux) / float(SimConfig.FIXED_SCALE)))
	var recipe_wire := HexRecipePolicy.recipe_wire(
		int(AbilityCatalog.DISPLAY_ELEMENT_WIRES[first_id]),
		int(AbilityCatalog.DISPLAY_ELEMENT_WIRES[second_id]),
	)
	if recipe_wire <= 0 or HexRecipePolicy.definition(recipe_wire).is_empty():
		return _refuse_begin("the selected whole-hex recipe is unavailable")

	_world = world
	_actor_id = actor_id
	_elements = PackedStringArray([first_id, second_id])
	_wires = PackedInt32Array([first_wire, second_wire])
	_slot_indices = PackedInt32Array([0, 0 if first_wire == second_wire else 1])
	_recipe_wire_id = recipe_wire
	_start_tick = world.tick
	_saved_wires = actor.spell_wire_ids.duplicate()
	_saved_cooldowns = actor.spell_cooldown_ticks.duplicate()
	_saved_primary_wire = actor.primary_wire_id
	_saved_active_1_wire = actor.active_1_wire_id
	_saved_active_2_wire = actor.active_2_wire_id
	_saved_primary_cooldown = actor.primary_cooldown_ticks
	_saved_active_1_cooldown = actor.active_1_cooldown_ticks
	_saved_active_2_cooldown = actor.active_2_cooldown_ticks
	if not actor.place_proven_spell(0, first_wire) or (first_wire != second_wire and not actor.place_proven_spell(1, second_wire)):
		_restore_loadout(actor, world.tick)
		_clear_run()
		return _refuse_begin("the temporary Bolt slots could not be equipped")

	# This is the one explicit spatial mutation: use the existing clear bench.
	# The normal commands below own movement, aim, payment, release, and contact.
	actor.position_x = BENCH.x
	actor.position_y = BENCH.y
	actor.position_remainder_x = 0
	actor.position_remainder_y = 0
	_start_tick = world.tick
	_deadline_tick = world.tick + maxi(actor.spell_cooldown_for_wire(first_wire), actor.spell_cooldown_for_wire(second_wire)) \
		+ actor.cast_recovery_ticks + _cast_window_ticks(world, first_cast) + _cast_window_ticks(world, second_cast) \
		+ CANCEL_TIMEOUT_TICKS
	_paid_receipts.clear()
	_observed_product.clear()
	_phase = PHASE_READY_FIRST
	_status = "Paid demo ready: %s Bolt, then %s Bolt, at the experiment target." % [_display_name(first_id), _display_name(second_id)]
	return true


func command(world: SimWorld) -> SimCommand:
	if not is_active():
		return null
	if world == null or world != _world:
		_abort("Paid demo stopped because the simulation world changed.")
		return null
	_refresh_receipts()
	var actor := world.player(_actor_id)
	if actor == null:
		_abort("Paid demo stopped because the actor left the world.")
		return null
	if actor.health <= 0:
		_abort("Paid demo stopped because the actor was defeated.")
		return null
	if world.tick > _deadline_tick:
		_abort("Paid demo stopped: an ordinary paid cast did not finish within its authored timing window.")
		return null

	match _phase:
		PHASE_READY_FIRST:
			if actor.pending_cast_wire_id == 0 and actor.cast_recovery_ticks == 0 and actor.spell_cooldown_for_wire(_wires[0]) == 0:
				return _issue(world, 0, PHASE_WAIT_FIRST_ACCEPT)
			_status = "Paid demo: waiting for the first Bolt's real cooldown and recovery."
		PHASE_WAIT_FIRST_ACCEPT:
			if _cast_was_paid(world):
				_phase = PHASE_WAIT_FIRST_TERMINAL
				_status = "Paid demo: first Bolt paid; waiting for its owned flight to land and recover."
			elif world.tick > _issued_tick:
				_abort("Paid demo stopped: the first Bolt was refused (%s)." % _refusal_reason(world, _wires[0]))
				return null
		PHASE_WAIT_FIRST_TERMINAL:
			if _cast_settled(world, actor, _wires[0]) and actor.spell_cooldown_for_wire(_wires[1]) == 0:
				return _issue(world, 1, PHASE_WAIT_SECOND_ACCEPT)
			_status = "Paid demo: first Bolt is resolving; both real cooldowns and recovery must be ready before the second."
		PHASE_WAIT_SECOND_ACCEPT:
			if _cast_was_paid(world):
				_phase = PHASE_WAIT_SECOND_TERMINAL
				_status = "Paid demo: second Bolt paid; waiting for the reaction at the target."
			elif world.tick > _issued_tick:
				_abort("Paid demo stopped: the second Bolt was refused (%s)." % _refusal_reason(world, _wires[1]))
				return null
		PHASE_WAIT_SECOND_TERMINAL:
			if _cast_settled(world, actor, _wires[1]):
				var product := _observed_product
				if product.is_empty():
					_abort("Paid demo stopped: both paid sources resolved, but the selected reaction did not form.")
					return null
				var product_name := String(HexRecipePolicy.definition(_recipe_wire_id).get("name", "reaction"))
				var quantity := int(product.get("quantity", 0))
				_complete("Paid demo complete: %s formed from two paid sources (%d matter)." % [product_name, quantity])
				return null
			_status = "Paid demo: second Bolt is resolving through its real flight, recovery, and cooldown."
		PHASE_CANCEL_DRAIN:
			var draining_wire := int(_wires[_issued_index]) if _issued_index >= 0 and _issued_index < _wires.size() else 0
			if draining_wire > 0 and _cast_settled(world, actor, draining_wire):
				_complete("Paid demo canceled after the already-paid Bolt finished; no payment was rolled back.", "canceled")
				return null
			_status = "Canceling paid demo after the already-paid Bolt finishes."
	return _neutral_command(world)


func cancel(world: SimWorld) -> void:
	if not is_active():
		return
	if world == null or world != _world:
		_abort("Paid demo canceled because the simulation world changed.")
		return
	_refresh_receipts()
	var actor := world.player(_actor_id)
	if actor == null:
		_abort("Paid demo canceled because the actor left the world.")
		return
	if actor.pending_cast_wire_id != 0 or _has_owner_flight(world, _actor_id):
		_phase = PHASE_CANCEL_DRAIN
		_deadline_tick = maxi(_deadline_tick, world.tick + CANCEL_TIMEOUT_TICKS)
		_status = "Canceling paid demo after the already-paid Bolt finishes."
		return
	_complete("Paid demo canceled before another paid cast was issued.", "canceled")


func is_active() -> bool:
	return _phase != PHASE_IDLE


func status() -> String:
	return _status


func recipe_wire_id() -> int:
	return _recipe_wire_id


func has_terminal_result() -> bool:
	return not _terminal_result.is_empty()


# A detached, single-run receipt; no progression/history or live world records.
func terminal_result() -> Dictionary:
	return _terminal_result.duplicate(true)


func dismiss_result() -> void:
	_terminal_result.clear()
	_result_world = null
	_result_actor = null


# The application supplies modal/session/round/spectator eligibility. The model
# also protects against a replaced world or actor with a reused entity ID.
func validate_result(world: SimWorld, actor_id: int, eligible: bool = true) -> bool:
	if not has_terminal_result():
		return false
	if not eligible or world == null or world != _result_world or _result_actor == null \
		or actor_id != int(_terminal_result.actor_id) or world.player(actor_id) != _result_actor:
		dismiss_result()
		return false
	return true


func _issue(world: SimWorld, cast_index: int, next_phase: int) -> SimCommand:
	_phase = next_phase
	_issued_tick = world.tick
	_issued_cast_floor = world.hex_court.next_cast_id
	_issued_index = cast_index
	_status = "Paid demo: casting %s Bolt through the ordinary paid slot." % _display_name(_elements[cast_index])
	return _target_command(world, int(_slot_indices[cast_index]))


func _neutral_command(world: SimWorld) -> SimCommand:
	return _target_command(world, -1)


func _target_command(world: SimWorld, pressed_slot_index: int) -> SimCommand:
	var actor := world.player(_actor_id)
	var point := Vector2i(actor.position_x, actor.position_y)
	var delta := TARGET - point
	var pressed := int(SimCommand.SPELL_PRESSED_BITS[pressed_slot_index]) if pressed_slot_index >= 0 else 0
	return SimCommand.new(world.tick, _actor_id, 0, 0, 0, pressed, delta.x, delta.y, TARGET.x, TARGET.y)


func _cast_was_paid(world: SimWorld) -> bool:
	_refresh_receipts()
	return world == _world and _issued_index >= 0 and _paid_receipts.size() > _issued_index


func _refresh_receipts() -> void:
	if _world == null or _world.hex_court == null:
		return
	# Admission belongs to this actor, wire and issued command, not the world's
	# aggregate payment counter (other people may cast in shared practice).
	if _issued_index >= 0 and _paid_receipts.size() == _issued_index:
		for record: Dictionary in _world.hex_court.casts.values():
			if int(record.id) >= _issued_cast_floor and int(record.owner) == _actor_id \
				and int(record.wire) == int(_wires[_issued_index]) and bool(record.paid):
				_paid_receipts.append({"cast_id": int(record.id), "source_id": int(record.source),
					"wire_id": int(record.wire), "matter": int(record.budget),
					"flux": int(CombatTuning.cast_definition(int(record.wire)).get("flux_cost", 0))})
				break
		# A same-tick defeat can expire the paid startup before the next poll.
		# cast_started is emitted only after payment, unlike cast intent/refusal.
		if _paid_receipts.size() == _issued_index and _world.tick == _issued_tick + 1:
			for event: Dictionary in _world.combat_events:
				if String(event.get("type", "")) == "cast_started" and int(event.get("entity_id", 0)) == _actor_id \
					and int(event.get("wire_id", 0)) == int(_wires[_issued_index]):
					_paid_receipts.append({"cast_id": 0, "source_id": 0, "wire_id": int(_wires[_issued_index]),
						"matter": MATTER_PER_CAST, "flux": int(CombatTuning.cast_definition(int(_wires[_issued_index])).get("flux_cost", 0))})
					break
	for receipt: Dictionary in _paid_receipts:
		var record: Dictionary = _world.hex_court.casts.get(int(receipt.cast_id), {})
		if not record.is_empty() and int(record.source) > 0:
			receipt.source_id = int(record.source)
	var product := _matching_product(_world)
	if not product.is_empty():
		_observed_product = {"id": int(product.id), "recipe_wire_id": int(product.recipe_wire_id),
			"name": String(HexRecipePolicy.definition(int(product.recipe_wire_id)).get("name", "reaction")),
			"quantity": int(product.quantity), "cell_count": (product.cells as Dictionary).size(),
			"position": product.get("position", TARGET), "source_ids": (product.source_ids as Array).duplicate(),
			"observed_tick": _world.tick}


func _cast_settled(world: SimWorld, actor: PlayerState, wire_id: int) -> bool:
	return actor.pending_cast_wire_id == 0 \
		and actor.cast_recovery_ticks == 0 \
		and actor.spell_cooldown_for_wire(wire_id) == 0 \
		and not _has_owner_flight(world, _actor_id)


func _matching_product(world: SimWorld) -> Dictionary:
	if _paid_receipts.size() != 2:
		return {}
	var first_source := int(_paid_receipts[0].source_id)
	var second_source := int(_paid_receipts[1].source_id)
	if first_source <= 0 or second_source <= 0 or first_source == second_source:
		return {}
	for product: Dictionary in world.hex_court.products.values():
		var sources: Array = product.get("source_ids", [])
		if int(product.get("recipe_wire_id", 0)) == _recipe_wire_id \
			and int(product.get("quantity", 0)) == MATTER_PER_CAST * 2 \
			and sources.size() == 2 and first_source in sources and second_source in sources:
			return product
	return {}


func _complete(message: String, outcome: String = "complete") -> void:
	_finish(message, outcome)


func _finish(message: String, outcome: String) -> void:
	if not is_active():
		return
	_refresh_receipts()
	var actor := _world.player(_actor_id) if _world != null else null
	if actor != null:
		_restore_loadout(actor, _world.tick)
	var paid_matter := 0
	var paid_flux := 0
	for receipt: Dictionary in _paid_receipts:
		paid_matter += int(receipt.matter)
		paid_flux += int(receipt.flux)
	_result_world = _world
	_result_actor = actor
	_terminal_result = {"outcome": outcome, "message": message, "actor_id": _actor_id,
		"recipe_wire_id": _recipe_wire_id, "elements": _elements.duplicate(), "wires": _wires.duplicate(),
		"target": TARGET, "paid_casts": _paid_receipts.size(), "paid_matter": paid_matter, "paid_flux": paid_flux,
		"observed_product": _observed_product.duplicate(true), "weave_restored": actor != null,
		"finished_tick": _world.tick if _world != null else _start_tick}
	_status = message
	_clear_run()


func _abort(message: String) -> void:
	_finish(message, "aborted")


func _restore_loadout(actor: PlayerState, current_tick: int) -> void:
	if actor == null or _saved_wires.size() != PlayerState.SPELL_SLOT_COUNT or _saved_cooldowns.size() != PlayerState.SPELL_SLOT_COUNT:
		return
	var elapsed := maxi(0, current_tick - _start_tick)
	var live_cooldowns: Dictionary[int, int] = {}
	for wire: int in actor.spell_wire_ids:
		if wire > 0:
			live_cooldowns[wire] = actor.spell_cooldown_for_wire(wire)
	for wire: int in [actor.primary_wire_id, actor.active_1_wire_id, actor.active_2_wire_id]:
		if wire > 0:
			live_cooldowns[wire] = maxi(int(live_cooldowns.get(wire, 0)), actor.spell_cooldown_for_wire(wire))
	var restored_cooldowns := PackedInt32Array()
	for index: int in PlayerState.SPELL_SLOT_COUNT:
		var wire := int(_saved_wires[index])
		var naturally_elapsed := maxi(0, int(_saved_cooldowns[index]) - elapsed)
		restored_cooldowns.append(maxi(naturally_elapsed, int(live_cooldowns.get(wire, 0))))
	actor.primary_wire_id = _saved_primary_wire
	actor.active_1_wire_id = _saved_active_1_wire
	actor.active_2_wire_id = _saved_active_2_wire
	actor.spell_wire_ids = _saved_wires.duplicate()
	actor.spell_cooldown_ticks = restored_cooldowns
	actor.primary_cooldown_ticks = maxi(maxi(0, _saved_primary_cooldown - elapsed), int(live_cooldowns.get(_saved_primary_wire, 0)))
	actor.active_1_cooldown_ticks = maxi(maxi(0, _saved_active_1_cooldown - elapsed), int(live_cooldowns.get(_saved_active_1_wire, 0)))
	actor.active_2_cooldown_ticks = maxi(maxi(0, _saved_active_2_cooldown - elapsed), int(live_cooldowns.get(_saved_active_2_wire, 0))) if _saved_active_2_wire > 0 else 0
	actor._sync_legacy_spell_cooldowns()


func _clear_run() -> void:
	_phase = PHASE_IDLE
	_world = null
	_actor_id = 0
	_elements = PackedStringArray()
	_wires = PackedInt32Array()
	_slot_indices = PackedInt32Array()
	_issued_tick = -1
	_issued_cast_floor = 0
	_issued_index = -1
	_paid_receipts.clear()
	_observed_product.clear()
	_saved_wires = PackedInt32Array()
	_saved_cooldowns = PackedInt32Array()


func _refuse_begin(reason: String) -> bool:
	_status = "Paid demo unavailable: %s." % reason
	return false


static func _element_id(value: Variant) -> String:
	if value is String:
		var requested := String(value).to_lower()
		return requested if requested in ELEMENT_IDS else ""
	if value is int:
		for element_id: String in ELEMENT_IDS:
			if int(AbilityCatalog.DISPLAY_ELEMENT_WIRES[element_id]) == int(value):
				return element_id
	return ""


static func _legal_bolt(definition: Dictionary) -> bool:
	var wire := int(definition.get("wire_id", 0))
	return wire > 0 \
		and String(definition.get("runtime_status", "")) == "playable" \
		and AbilityCatalog._spell_family(definition) == "bolt" \
		and CombatTuning.is_runtime_wire_id(wire) \
		and not CombatTuning.cast_definition(wire).is_empty()


static func _display_name(element_id: String) -> String:
	return AbilityCatalog.element_display_name(element_id)


static func _has_owner_flight(world: SimWorld, actor_id: int) -> bool:
	for projectile: ProjectileState in world.projectiles:
		if projectile.owner_id == actor_id:
			return true
	if world.hex_court == null:
		return false
	for record: Dictionary in world.hex_court.casts.values():
		if int(record.get("owner", 0)) == actor_id and not (record.get("flight_parts", {}) as Dictionary).is_empty():
			return true
	return false


func _refusal_reason(world: SimWorld, wire_id: int) -> String:
	for event: Dictionary in world.combat_events:
		if String(event.get("type", "")) == "cast_refused" \
			and int(event.get("entity_id", 0)) == _actor_id \
			and int(event.get("wire_id", 0)) == wire_id:
			return String(event.get("reason", "unknown"))
	return "no admission receipt"


static func _cast_window_ticks(world: SimWorld, definition: Dictionary) -> int:
	var startup := world.config.milliseconds_to_ticks(int(definition.get("startup_ms", 0)))
	var recovery := world.config.milliseconds_to_ticks(int(definition.get("recovery_ms", 0)))
	var cooldown := world.config.milliseconds_to_ticks(int(definition.get("cooldown_ms", 0)))
	var speed := maxi(1, int(definition.get("speed", 0)))
	var distance := SimCommand._integer_square_root((TARGET - BENCH).length_squared())
	@warning_ignore("integer_division")
	var travel := (distance * world.config.tick_rate + speed - 1) / speed + 4
	return startup + maxi(maxi(recovery, cooldown), travel)
