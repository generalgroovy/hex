extends FluxTestSuite
@warning_ignore_start("integer_division")

const BeforeMovement = preload("res://tests/support/movement_before_typed_timers.gd")
const BeforeCommand = preload("res://tests/support/command_before_empty_mask.gd")
const BeforeWorld = preload("res://tests/support/world_before_typed_timers.gd")
const BeforeCooldown = preload("res://tests/support/player_before_cooldown_slots.gd")
const BeforeHeldCombat = preload("res://tests/support/combat_before_held_mask.gd")
const TIMER_FIELDS: Array[StringName] = [
	&"stamina_recovery_delay_ticks", &"hop_cooldown_ticks",
	&"air_dodge_ticks", &"air_dodge_cooldown_ticks", &"wave_dash_ticks",
	&"slide_ticks", &"slide_cooldown_ticks", &"vault_ticks",
	&"vault_cooldown_ticks", &"superglide_ticks", &"wall_memory_ticks",
	&"wall_skim_ticks", &"wall_skim_cooldown_ticks", &"wall_skim_lockout_ticks",
	&"landing_ticks", &"impact_recovery_ticks", &"wall_lockout_ticks", &"control_ticks",
	&"jump_buffer_ticks", &"technique_buffer_ticks", &"slide_buffer_ticks",
	&"variable_jump_grace_ticks", &"jump_protection_ticks", &"evade_buffer_ticks", &"landing_input_ticks",
	&"movement_chain_reset_ticks", &"movement_commitment_ticks", &"wall_air_ticks",
	&"chemistry_reveal_ticks", &"chemistry_conceal_ticks", &"chemistry_regen_block_ticks",
]
const VALUES: Array[int] = [-2_147_483_648,-1,0,1,2,65_535,2_147_483_647,9_223_372_036_854_775_807]

class LookupProbe:
	extends PlayerState
	var lookups := 0
	func spell_slot_index_for_wire(wire_id: int) -> int:
		lookups += 1
		return super.spell_slot_index_for_wire(wire_id)

class HeldBitProbe:
	extends SimCommand
	var checks := 0
	func has_held(action: int) -> bool:
		checks += 1
		return super.has_held(action)


class GroundPerkProbe:
	extends PlayerState
	var airborne_calls := 0
	func is_airborne() -> bool:
		airborne_calls += 1
		if airborne_calls == 1: velocity_x = 100_000
		return super.is_airborne()

class GroundConfigProbe:
	extends SimConfig
	var per_tick_calls := 0
	var observed_actor: PlayerState
	func per_tick(_value_per_second: int) -> int:
		per_tick_calls += 1
		observed_actor.velocity_x = 10_000
		return 7


func run() -> int:
	_test_timer_boundaries()
	_test_simultaneous_transitions()
	_test_spell_masks()
	_test_repeating_held_masks()
	_test_cooldown_slots()
	_test_fixed_step_equivalence()
	_test_stationary_ground_recovery()
	_test_stationary_recovery_gates()
	_test_ground_motion_and_virtual_fallbacks()
	return finish("movement-hot-path")


func _values(actor: PlayerState) -> Dictionary:
	var result := {}
	for property: Dictionary in actor.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0: continue
		var value: Variant = actor.get(property.name)
		result[property.name] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result


func _actor(mode: String) -> PlayerState:
	var actor := PlayerState.new(1)
	actor.last_event = "before"
	actor.landing_intensity = 250
	actor.movement_chain_count = 3
	actor.movement_chain_reset_ticks = 2
	actor.velocity_x = 180_000
	actor.velocity_y = -120_000
	actor.slow_ratio = 700
	actor.control_speed = 210_000
	match mode:
		"rolling":
			actor.hop_mode = PlayerState.MovementMode.ROLL
			actor.air_dodge_ticks = 2
		"air_dodge":
			actor.hop_mode = PlayerState.MovementMode.AIR_DODGE
			actor.air_dodge_ticks = 2
			actor.air_height = 20_000
		"wallrun":
			actor.wall_skim_ticks = 2
			actor.wall_skim_surface_id = 4
			actor.wall_x = -1000
			actor.wall_skim_y = 1000
			actor.air_height = 20_000
		"launched":
			actor.control_state = PlayerState.ControlState.LAUNCHED
			actor.control_ticks = 2
		"stunned":
			actor.control_state = PlayerState.ControlState.STUNNED
			actor.control_ticks = 2
	return actor


func _compare_timers(actual: PlayerState, expected: PlayerState, label: String) -> void:
	var config := SimConfig.new(120)
	MovementSystem._advance_timers(actual,config)
	BeforeMovement._advance_timers(expected,config)
	equal(_values(actual),_values(expected),label + " exact fields and event ordering")


func _test_timer_boundaries() -> void:
	equal(TIMER_FIELDS.size(),31,"reference covers every original reflective timer")
	for mode: String in ["plain","rolling","air_dodge","wallrun","launched","stunned"]:
		for field: StringName in TIMER_FIELDS:
			for value: int in VALUES:
				var actual := _actor(mode)
				var expected := _actor(mode)
				actual.set(field,value)
				expected.set(field,value)
				_compare_timers(actual,expected,"%s %s=%d" % [mode,field,value])
	# Independent literal witnesses complement the old-method comparison.
	var plain := _actor("plain")
	plain.hop_cooldown_ticks = -1
	plain.stamina_recovery_delay_ticks = 2
	MovementSystem._advance_timers(plain,SimConfig.new(120))
	equal(plain.hop_cooldown_ticks,0,"negative imported timer clamps to zero")
	equal(plain.stamina_recovery_delay_ticks,1,"positive timer loses exactly one tick")
	equal(plain.last_event,"before","unrelated countdown creates no event")
	var roll := _actor("rolling")
	roll.air_dodge_ticks = 1
	MovementSystem._advance_timers(roll,SimConfig.new(120))
	equal(roll.last_event,"roll_end","completed real roll retains its exact event")
	check(roll.landing_ticks > 0,"roll completion still starts the landing window")


func _test_simultaneous_transitions() -> void:
	for mode: String in ["plain","rolling","air_dodge","wallrun","launched","stunned"]:
		for value: int in VALUES:
			var actual := _actor(mode)
			var expected := _actor(mode)
			for field: StringName in TIMER_FIELDS:
				actual.set(field,value)
				expected.set(field,value)
			_compare_timers(actual,expected,"all timers %s=%d" % [mode,value])
		for seed: int in 24:
			var actual := _actor(mode)
			var expected := _actor(mode)
			for index: int in TIMER_FIELDS.size():
				var value := VALUES[(index*7+seed*3)%VALUES.size()]
				actual.set(TIMER_FIELDS[index],value)
				expected.set(TIMER_FIELDS[index],value)
			for tick: int in 4:
				_compare_timers(actual,expected,"mixed vector %s seed%d tick%d" % [mode,seed,tick])


func _test_spell_masks() -> void:
	var actual := SimCommand.new()
	var expected := BeforeCommand.new()
	var combined := 0
	for bit: int in SimCommand.SPELL_PRESSED_BITS: combined |= bit
	equal(SimCommand.SPELL_ACTION_MASK,combined,"zero guard mask matches all current spell bits exactly")
	# Every low16-bit pattern retains lowest-slot precedence and independent
	# pressed/held masks; controls/high bits never become spell intent.
	for mask: int in 65_536:
		actual.pressed_actions = mask
		actual.held_actions = mask ^ 0xFFFF
		expected.pressed_actions = actual.pressed_actions
		expected.held_actions = actual.held_actions
		equal(actual.first_pressed_spell_slot(),expected.first_pressed_spell_slot(),"pressed mask%d" % mask)
		equal(actual.first_held_spell_slot(),expected.first_held_spell_slot(),"independent held mask%d" % actual.held_actions)
	for mask: int in [-1,-65_536,-2_147_483_648,1<<16,1<<17,1<<40,9_223_372_036_854_775_807]:
		for suffix: int in [0,1<<4,1<<15,0xFFF0]:
			actual.pressed_actions = mask | suffix
			actual.held_actions = actual.pressed_actions
			expected.pressed_actions = actual.pressed_actions
			expected.held_actions = actual.held_actions
			equal(actual.first_pressed_spell_slot(),expected.first_pressed_spell_slot(),"signed/outlier pressed mask remains exact")
			equal(actual.first_held_spell_slot(),expected.first_held_spell_slot(),"signed/outlier held mask remains exact")


func _world(before: bool) -> SimWorld:
	var world: SimWorld = BeforeWorld.new(120,991,CollisionWorld.new()) if before else SimWorld.new(120,991,CollisionWorld.new())
	world.hex_court = HexChemistryWorld.new()
	check(world.hex_court.configure_geometry(Vector2i(650_000,500_000),HexGrid.disk(Vector2i.ZERO,12)),"replay uses real Hex authority")
	world.hex_court.chemistry_enabled = true
	world.players.clear()
	for index: int in 30:
		var actor: PlayerState = BeforeCooldown.new(index+1) if before else PlayerState.new(index+1)
		actor.team_id = index+1
		actor.position_x = 650_000 + (index%5)*20_000
		actor.position_y = 650_000 - (index/5)*20_000
		actor.spawn_protection_ticks = 0
		actor.health = actor.health_maximum
		actor.health_recovery_delay_ticks = 3+index
		actor.flux_recovery_delay_ticks = 3+index
		actor.stamina_recovery_delay_ticks = 3+index
		actor.landing_ticks = index%3
		actor.landing_intensity = 250
		check(actor.place_proven_spell(0,145),"actual Fire Bolt occupies first replay slot")
		check(actor.set_spell_cooldown(145,13),"replay includes a real spell cooldown")
		if index > 0:
			actor.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
			actor.movement_speed_ratio = 0
			actor.health_recovery_per_second = 0
			actor.flux_recovery_per_second = 0
			actor.stamina_recovery_per_second = 0
		world.players.append(actor)
	world.players[1].velocity_x = 180_000
	world.players[2].air_height = 40_000
	world.players[2].air_vertical_velocity = -120_000
	world.players[3].control_state = PlayerState.ControlState.LAUNCHED
	world.players[3].control_ticks = 1
	world.players[3].control_speed = 200_000
	world.players[3].control_x = 1000
	SpellStatusPolicy.apply_hit(world.players[4],145,900,1,1,4000,world.config,Vector2i(1000,0))
	check(SpellStatusPolicy.active(world.players[4],1),"replay carries actual admitted Fire status and finite damage pool")
	return world


func _test_fixed_step_equivalence() -> void:
	var actual := _world(false)
	var expected := _world(true)
	var admitted_casts := 0
	var status_hits := 0
	var airborne_ticks := 0
	for tick: int in 160:
		var pressed := 0
		var held := 0
		if tick in [4,28]: pressed |= SimCommand.PRESSED_JUMP
		if tick >= 4 and tick < 12: held |= SimCommand.HELD_JUMP
		if tick >= 38 and tick < 42: held |= SimCommand.HELD_FAST_FALL
		if tick == 75: pressed |= SimCommand.PRESSED_EVADE
		if tick == 120: pressed |= SimCommand.PRESSED_SLIDE
		if tick == 60: pressed |= SimCommand.PRESSED_SPELL_1
		if tick >= 140: held |= SimCommand.SPELL_HELD_BITS[0]
		var movement := 1000 if tick >= 15 and tick < 55 else 0
		var command := SimCommand.new(tick,1,movement,0,held,pressed,0,-1000,700_000,500_000)
		var old_command := BeforeCommand.new(tick,1,movement,0,held,pressed,0,-1000,700_000,500_000)
		check(actual.step([command]),"optimized full tick remains admitted")
		check(expected.step([old_command]),"prior movement/command full tick remains admitted")
		equal(actual.state_hash(),expected.state_hash(),"complete authority replay matches at tick%d" % tick)
		equal(actual.combat_events,expected.combat_events,"exact ordered combat events match at tick%d" % tick)
		for index: int in actual.players.size():
			equal(_values(actual.players[index]),_values(expected.players[index]),"all actor fields/resources/timers/statuses match at tick%d actor%d" % [tick,index])
		for event: Dictionary in actual.combat_events:
			if event.get("type","") == "cast_started": admitted_casts += 1
			if event.get("type","") == "spell_status_hit": status_hits += 1
		if actual.player().air_height > 0: airborne_ticks += 1
	check(admitted_casts > 0,"world comparison actually includes paid casting")
	check(status_hits > 0,"world comparison actually advances finite status damage")
	check(airborne_ticks > 0,"world comparison actually executes existing jump controls")


func _test_repeating_held_masks() -> void:
	var families := {}
	var additional_rapid := 0
	for wire: int in CombatTuning.runtime_wire_ids():
		var definition := CombatTuning.cast_definition_view(wire)
		var family := String(definition.get("family", ""))
		if family == "rapid" and families.has(family) and additional_rapid == 0: additional_rapid = wire
		if not families.has(family): families[family] = wire
	for family: String in ["mantle","fuse","split","rebound","rapid","bolt","spray","heavy"]:
		check(families.has(family),"held-repeat oracle includes actual family: " + family)
		if not families.has(family): return
	check(additional_rapid > 0,"last-slot positive control has a distinct live Rapid wire")
	if additional_rapid <= 0: return
	for family: String in ["mantle","fuse","split","rebound","spray","heavy"]:
		check(not bool(CombatTuning.cast_definition_view(int(families[family])).get("repeat_while_held",false)),"single-press family does not acquire held ownership: " + family)
	for family: String in ["rapid","bolt"]:
		check(bool(CombatTuning.cast_definition_view(int(families[family])).get("repeat_while_held",false)),"repeat family supplies real positive held witness: " + family)
	var actor := PlayerState.new()
	actor.spell_wire_ids = PackedInt32Array([int(families.mantle),0,int(families.rapid),int(families.fuse),int(families.bolt),int(families.split),int(families.rebound),int(families.heavy),int(families.spray),0,0,additional_rapid])
	var command := SimCommand.new()
	for mask: int in 65_536:
		command.held_actions = mask
		equal(CombatSystem._first_held_repeating_slot(actor,command),BeforeHeldCombat._first_held_repeating_slot(actor,command),"actual mixed-family repeat selection preserves mask%d" % mask)
	for mask: int in [-1,-65_536,-2_147_483_648,1<<16,1<<40,9_223_372_036_854_775_807]:
		for suffix: int in [0,1<<4,1<<6,1<<15,0xFFF0]:
			command.held_actions = mask | suffix
			equal(CombatSystem._first_held_repeating_slot(actor,command),BeforeHeldCombat._first_held_repeating_slot(actor,command),"signed/high-bit repeating intent preserves original priority")
	command.held_actions = SimCommand.SPELL_HELD_BITS[0] | SimCommand.SPELL_HELD_BITS[1]
	equal(CombatSystem._first_held_repeating_slot(actor,command),0,"a held single-press spell and empty slot do not become cast intent")
	command.held_actions |= SimCommand.SPELL_HELD_BITS[2] | SimCommand.SPELL_HELD_BITS[4] | SimCommand.SPELL_HELD_BITS[11]
	equal(CombatSystem._first_held_repeating_slot(actor,command),3,"lowest actual repeating slot wins across nonrepeat and empty positions")
	command.held_actions = SimCommand.SPELL_HELD_BITS[11]
	equal(CombatSystem._first_held_repeating_slot(actor,command),12,"last slot remains available")
	for unrelated: int in [0,1,15,1<<40,-65_536]:
		var probe := HeldBitProbe.new()
		probe.held_actions = unrelated
		equal(CombatSystem._first_held_repeating_slot(actor,probe),0,"nonspell holds remain outside repeat admission")
		equal(probe.checks,0,"empty spell mask eliminates every per-slot has_held call")
		equal(BeforeHeldCombat._first_held_repeating_slot(actor,probe),0,"preserved reference agrees on nonspell holds")
		equal(probe.checks,12,"old reference independently witnesses twelve omitted checks")


func _test_cooldown_slots() -> void:
	var original := PackedInt32Array([140,145,150,155,160,185,141,146,151,156,161,186])
	var duplicate := original.duplicate()
	duplicate[1] = 140
	var rotated := original.duplicate()
	rotated.reverse()
	var short := original.duplicate()
	short.resize(11)
	var long := original.duplicate()
	long.append(140)
	var weaves: Array[PackedInt32Array] = [original,duplicate,rotated,short,long,PackedInt32Array()]
	var aliases: Array[Array] = [[140,145,150],[185,186,199],[140,140,140],[0,-1,0],[4_294_967_436,4_294_967_441,-4_294_967_146]]
	var values: Array[int] = [-2_147_483_649,-2_147_483_648,-1,0,1,2,2_147_483_647,2_147_483_648,9_223_372_036_854_775_807]
	var slot_values: Array[int] = [-2_147_483_648,-1,0,1,2,2_147_483_647]
	for weave: PackedInt32Array in weaves:
		for ids: Array in aliases:
			for size: int in [0,1,11,12,13]:
				for seed: int in values.size():
					var actual := PlayerState.new(9)
					var expected := BeforeCooldown.new(9)
					for actor: PlayerState in [actual,expected]:
						actor.spell_wire_ids = weave.duplicate()
						actor.primary_wire_id = ids[0]
						actor.active_1_wire_id = ids[1]
						actor.active_2_wire_id = ids[2]
						actor.primary_cooldown_ticks = values[seed]
						actor.active_1_cooldown_ticks = values[(seed+1)%values.size()]
						actor.active_2_cooldown_ticks = values[(seed+4)%values.size()]
						actor.spell_cooldown_ticks.resize(size)
						for slot: int in size: actor.spell_cooldown_ticks[slot] = slot_values[(seed+slot)%slot_values.size()]
					for tick: int in 3:
						actual.advance_spell_cooldowns()
						expected.advance_spell_cooldowns()
						equal(_values(actual),_values(expected),"all fields retain prior cooldown import/decrement/sync: weave%d aliases%s clocks%d seed%d tick%d" % [weave.size(),str(ids),size,seed,tick])
	# The exact idle case must eliminate lookups, not simply move them elsewhere.
	for size: int in [0,1,11,12,13]:
		var idle := LookupProbe.new()
		idle.spell_cooldown_ticks.resize(size)
		idle.spell_cooldown_ticks.fill(0)
		idle.lookups = 0
		idle.advance_spell_cooldowns()
		equal(idle.lookups,0,"zero cooldown path performs no alias slot search")
		equal(idle.spell_cooldown_ticks,PackedInt32Array([0,0,0,0,0,0,0,0,0,0,0,0]),"idle path still repairs malformed clock length")
	var active := LookupProbe.new()
	active.spell_wire_ids = original.duplicate()
	active.primary_wire_id = 140
	active.active_1_wire_id = 145
	active.active_2_wire_id = 150
	active.primary_cooldown_ticks = 3
	active.active_1_cooldown_ticks = 1
	active.active_2_cooldown_ticks = 7
	active.lookups = 0
	active.advance_spell_cooldowns()
	equal(active.lookups,3,"active path resolves each ordinary alias once across import/decrement/sync")
	equal(active.spell_cooldown_ticks.slice(0,3),PackedInt32Array([2,0,6]),"three imported active aliases each lose one tick")
	var shared := PlayerState.new()
	shared.spell_wire_ids = duplicate
	shared.primary_wire_id = 140
	shared.active_1_wire_id = 140
	shared.active_2_wire_id = 140
	shared.primary_cooldown_ticks = 4
	shared.active_1_cooldown_ticks = 7
	shared.active_2_cooldown_ticks = 10
	shared.spell_cooldown_ticks[1] = 20
	shared.advance_spell_cooldowns()
	equal(shared.spell_cooldown_ticks[0],9,"duplicate aliases merge the largest old clock before decrement")
	equal(shared.spell_cooldown_ticks[1],19,"duplicate slot preserves first-match alias semantics")
	equal([shared.primary_cooldown_ticks,shared.active_1_cooldown_ticks,shared.active_2_cooldown_ticks],[9,9,9],"all duplicate aliases sync to the same first slot")


func _test_stationary_ground_recovery() -> void:
	var config := SimConfig.new(120)
	var actor := PlayerState.new(1)
	actor.stamina = 100_000
	actor.stamina_remainder = 119
	actor.stamina_recovery_per_second = 121
	actor.sprinting = true
	for tick: int in 4:
		MovementSystem._apply_ground_velocity(actor, SimCommand.new(tick, 1, 0, 0, SimCommand.HELD_SPRINT), Vector2i(1000, 0), config)
	equal([actor.stamina, actor.stamina_remainder], [100_005, 3], "stationary recovery preserves fractional 119 + 4*121 at120Hz")
	equal(Vector2i(actor.velocity_x, actor.velocity_y), Vector2i.ZERO, "stationary recovery introduces no planar impulse")
	check(not actor.sprinting, "held Sprint without movement clears stale sprint admission")
	# Full movement still advances timers and delay before ordinary recovery.
	var idle := PlayerState.new(2)
	idle.position_x = 1_000_000
	idle.position_y = 1_000_000
	idle.stamina = 100_000
	idle.stamina_remainder = 119
	idle.stamina_recovery_per_second = 121
	idle.stamina_recovery_delay_ticks = 2
	idle.landing_ticks = 3
	var collision := CollisionWorld.new(2_000_000, 2_000_000)
	MovementSystem.step(idle, SimCommand.new(0, 2), config, collision)
	equal([idle.stamina, idle.stamina_remainder, idle.stamina_recovery_delay_ticks], [100_000, 119, 1], "first stationary step preserves the remaining recovery delay")
	MovementSystem.step(idle, SimCommand.new(1, 2), config, collision)
	equal([idle.stamina, idle.stamina_remainder, idle.stamina_recovery_delay_ticks], [100_002, 0, 0], "expiry step performs exactly one ordinary fractional recovery")
	equal(idle.landing_ticks, 1, "stationary path does not skip surrounding movement timers")
	equal(Vector2i(idle.position_x, idle.position_y), Vector2i(1_000_000, 1_000_000), "stationary full steps remain at their real position")


func _test_stationary_recovery_gates() -> void:
	var config := SimConfig.new(120)
	for mode: String in ["disabled", "delayed", "chemistry_block", "preserve_idle"]:
		var actor := PlayerState.new(1)
		actor.stamina = 100_000
		actor.stamina_remainder = 119
		actor.stamina_recovery_per_second = 121
		actor.sprinting = true
		if mode == "delayed": actor.stamina_recovery_delay_ticks = 2
		if mode == "chemistry_block": actor.chemistry_regen_block_ticks = 2
		MovementSystem._apply_ground_velocity(actor, SimCommand.new(), Vector2i(1000, 0), config, mode != "disabled", 900_000, mode == "preserve_idle", 1, 1, 1)
		equal([actor.stamina, actor.stamina_remainder], [100_000, 119], mode + " does not recover or discard a fractional remainder")
		check(not actor.sprinting and actor.velocity_x == 0 and actor.velocity_y == 0, mode + " retains idle motion even with a minimum speed and lane modifiers")
	var capped := PlayerState.new(1)
	capped.stamina_remainder = 119
	capped.stamina_recovery_per_second = 121
	MovementSystem._apply_ground_velocity(capped, SimCommand.new(), Vector2i(1000, 0), config)
	equal(capped.stamina, capped.stamina_maximum, "stationary recovery respects finite Stamina maximum")
	equal(capped.stamina_remainder, 0, "resource cap does not bypass the ordinary fractional calculation")


func _test_ground_motion_and_virtual_fallbacks() -> void:
	var config := SimConfig.new(120)
	var walking := PlayerState.new(1)
	MovementSystem._apply_ground_velocity(walking, SimCommand.new(0, 1, 1000, 0), Vector2i(1000, 0), config, false)
	equal(walking.velocity_x, 22_000, "fresh input still applies authored2640000-per-second acceleration")
	var braking := PlayerState.new(1)
	braking.velocity_x = 100_000
	MovementSystem._apply_ground_velocity(braking, SimCommand.new(), Vector2i(1000, 0), config, false)
	equal(braking.velocity_x, 67_000, "released moving actor still pays authored3960000-per-second braking")
	# These public virtual seams have observable behavior even when the actor
	# entered with zero input/velocity; they cannot be replaced by an idle return.
	var derived_actor := GroundPerkProbe.new(1)
	derived_actor.champion_wire_id = 1 # Oh Tipi: real walking/high-Flux braking perk.
	MovementSystem._apply_ground_velocity(derived_actor, SimCommand.new(), Vector2i(1000, 0), config, false)
	check(derived_actor.airborne_calls > 0, "derived actor still receives identity-policy airborne queries")
	equal(derived_actor.velocity_x, 60_400, "observable actor callback precedes current120-percent braking")
	var derived_config := GroundConfigProbe.new(120)
	var configured := PlayerState.new(1)
	derived_config.observed_actor = configured
	MovementSystem._apply_ground_velocity(configured, SimCommand.new(), Vector2i(1000, 0), derived_config, false)
	equal(derived_config.per_tick_calls, 1, "derived tick conversion remains an observable call")
	equal(configured.velocity_x, 9_993, "movement honors the derived tick callback and its returned step")
