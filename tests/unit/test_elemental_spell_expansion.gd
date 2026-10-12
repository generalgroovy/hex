extends FluxTestSuite

const Snapshot = preload("res://src/net/hex_world_snapshot.gd")
const StatusCodec = preload("res://src/net/expanded_spell_state_codec.gd")
const StatusText = preload("res://src/content/spell_status_catalog.gd")
const Perks = preload("res://src/sim/entities/identity_perk_policy.gd")
const CENTER := Vector2i(800_000, 800_000)
const OLD_WIRES := [140,181,182,141,145,179,180,154,163,185,186,164,159,183,184,160,173,191,192,174,142,193,194,176]
var catalog := AbilityCatalog.new()

func run() -> int:
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "504 spell catalog loads: " + catalog.last_error)
	if not catalog.last_error.is_empty(): return finish("elemental-spell-expansion")
	_test_catalog_and_all_paid_admissions()
	_test_mixture_metadata_rejects()
	_test_mixed_terminal_funding()
	_test_all_family_actual_hits()
	_test_status_bounds_and_protection()
	_test_paid_gust_push_difference()
	_test_paid_urzh_slow_tradeoff()
	_test_paid_black_ice_urzh_window()
	_test_paid_pooled_damage_perks()
	_test_paid_burning_perks()
	_test_paid_wither_recovery_difference()
	_test_split_budget()
	_test_split_capacity_reservations()
	_test_fuse_warning_and_shared_pool()
	_test_mantle_touch_and_trail()
	_test_rebound()
	_test_mask_optics()
	return finish("elemental-spell-expansion")

func _world() -> SimWorld:
	var world := SimWorld.new(120, 61, CollisionWorld.new(2_000_000, 2_000_000))
	var court := HexChemistryWorld.new()
	check(court.configure_geometry(CENTER, HexGrid.disk(Vector2i.ZERO, 12)), "finite expansion court configures")
	court.chemistry_enabled = true
	world.hex_court = court
	var actor := world.player()
	actor.champion_wire_id = 0
	actor.position_x = CENTER.x - 100_000
	actor.position_y = CENTER.y
	actor.spawn_protection_ticks = 0
	actor.flux_maximum = 100_000
	actor.flux = 100_000
	actor.health_recovery_per_second = 0
	actor.flux_recovery_per_second = 0
	return world

func _target(world: SimWorld, id: int, point: Vector2i) -> PlayerState:
	var target := PlayerState.new(id)
	target.champion_wire_id = 0
	target.team_id = 2
	target.position_x = point.x
	target.position_y = point.y
	target.spawn_protection_ticks = 0
	target.health_maximum = 1_000_000
	target.health = 1_000_000
	target.health_recovery_per_second = 0
	target.flux_recovery_per_second = 0
	world.players.append(target)
	return target

func _paid(world: SimWorld, wire: int, point: Vector2i = Vector2i(-1,-1)) -> bool:
	var actor := world.player()
	check(actor.place_proven_spell(0, wire), "actual slot accepts expanded wire %d" % wire)
	var before := actor.flux
	check(world.step([SimCommand.new(world.tick,1,0,0,0,SimCommand.SPELL_PRESSED_BITS[0],1000,0,point.x,point.y)]), "real admission advances")
	equal(before-actor.flux, int(CombatTuning.cast_definition_view(wire).flux_cost), "exact positive authored Flux is paid once")
	equal(actor.pending_cast_wire_id, wire, "actual paid startup owns requested identity")
	for unused: int in range(32):
		if actor.pending_cast_wire_id == 0: break
		check(world.step([]), "paid startup advances without repeated input")
	equal(actor.pending_cast_wire_id, 0, "bounded authored preparation releases")
	equal(int(world.hex_court.metrics.matter_paid), 600, "one admission creates exactly one paid matter stock")
	check(world.hex_court.conservation_valid(), "release preserves paid material ownership")
	return actor.pending_cast_wire_id == 0

func _test_catalog_and_all_paid_admissions() -> void:
	equal(CombatTuning.runtime_wire_ids().size(), 504, "exact63 masks times8 families are live")
	equal(Array(CombatTuning.runtime_wire_ids().slice(0,24)), OLD_WIRES, "retained24 preserve exact runtime order and wires")
	var seen := {}
	for mask: int in range(1,64):
		var mixture := MixtureCatalog.definition(mask)
		equal(int(mixture.get("element_mask",0)), mask, "named payload exists for every nonempty subset")
		check(not String(mixture.get("display_name","")).is_empty(), "each payload has an authored readable name")
		for family: String in MixtureCatalog.FAMILIES:
			var wire := MixtureCatalog.wire_for(mask,family)
			check(not seen.has(wire), "wire uniquely identifies mask and family")
			seen[wire] = true
			equal(MixtureCatalog.mask_for_wire(wire), mask, "stable wire resolves exact payload")
			equal(MixtureCatalog.family_for_wire(wire), family, "stable wire resolves exact delivery")
			var definition := CombatTuning.cast_definition_view(wire)
			check(not String(catalog.ability_from_wire(wire).get("display_name","")).is_empty(),"every actual spell has its authored display name")
			equal(int(definition.element_mask), mask, "compiled mask is authority independent of palette")
			check(int(definition.flux_cost)>0 and int(definition.reaction_strength)>0, "every cell requires paid positive source strength")
			_paid(_world(),wire)
	for element: String in ElementRules.IDS:
		for family: String in MixtureCatalog.FAMILIES:
			var id := catalog.spell_id_at(element,family)
			var row := catalog.ability(id)
			equal(String(row.get("element","")),element,"singleton lookup does not index expanded runtime order as a rectangle")
			equal(AbilityCatalog._spell_family(row),family,"starter and matrix lookup preserve exact family")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json",catalog),"all thirty original twelve-slot starters still load: "+champions.last_error)
	for id: String in champions.ordered_champion_ids():
		var starter := CharacterStarterKit.build(champions,catalog,id)
		check(bool(starter.valid),"expanded library preserves authored starter")
		equal(starter.wire_ids.size(),12,"expanded library does not increase equipped slots")
		for wire: int in starter.wire_ids: check(wire in OLD_WIRES,"starter remains in always-available original24")
	for family: String in ["mantle","fuse","split","rebound"]:
		var legacy := SimWorld.new()
		var wire := MixtureCatalog.wire_for(4,family)
		check(legacy.player().place_proven_spell(0,wire),"boundary control equips valid wire")
		var before := legacy.player().flux
		check(legacy.step([SimCommand.new(0,1,0,0,0,SimCommand.SPELL_PRESSED_BITS[0])]),"archive harness accepts valid command")
		equal(legacy.player().flux,before,"new finite-ledger family refuses unsupported authority before payment")
		equal(legacy.player().pending_cast_wire_id,0,"unsupported legacy path cannot partially start new family")

func _test_mixture_metadata_rejects() -> void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(MixtureCatalog.PATH))
	check(MixtureCatalog.valid_document(parsed),"complete source metadata independently validates")
	check(not MixtureCatalog.valid_document(null),"missing mixture source cannot silently use empty metadata")
	var bad: Dictionary=parsed.duplicate(true)
	bad.mixtures.pop_back()
	check(not MixtureCatalog.valid_document(bad),"one missing named mask refuses all catalog admission")
	bad=parsed.duplicate(true);bad.mixtures[0].status_duration_ms=0
	check(not MixtureCatalog.valid_document(bad),"zero status duration cannot silently compile fallback timing")
	bad=parsed.duplicate(true);bad.mixtures[0].element_mask=1.5
	check(not MixtureCatalog.valid_document(bad),"fractional masks are rejected before integer coercion")
	bad=parsed.duplicate(true);bad.mixtures[0].elements=["fire"]
	check(not MixtureCatalog.valid_document(bad),"mask and teaching ingredients must agree exactly")
	bad=parsed.duplicate(true);bad.mixtures[0].reaction_wire_id=309
	check(not MixtureCatalog.valid_document(bad),"mask cannot claim a different reaction identity")
	bad=parsed.duplicate(true);bad.mixtures[0].representative_element_wire_id=3
	check(not MixtureCatalog.valid_document(bad),"palette adapter must come from canonical constituent order")
	bad=parsed.duplicate(true);bad.mixtures[0].counter=" "
	check(not MixtureCatalog.valid_document(bad),"every named mixture requires usable counter teaching")

func _test_mixed_terminal_funding() -> void:
	for mask: int in range(1,64):
		if (mask & (mask-1)) == 0: continue
		var world := _world()
		var wire := MixtureCatalog.wire_for(mask,"bolt")
		_paid(world,wire,CENTER)
		for unused: int in range(70):
			if world.projectiles.is_empty(): break
			check(world.step([]),"mixed paid projectile reaches actual cursor endpoint")
		equal(world.hex_court.products.size(),1,"one mixed paid source forms one named reaction")
		if world.hex_court.products.size()!=1: continue
		var product: Dictionary = world.hex_court.products.values()[0]
		equal(int(product.element_mask),mask,"terminal retains all payload ingredients")
		equal(product.source_ids.size(),1,"a premixed spell has exactly one paid provenance source")
		equal(int(product.funded_strength),5,"mixture arity never multiplies Bolt strength")
		equal(int(product.damage_budget_remaining),20_000,"all57 mixed Bolt fields get one linear5-strength pool")
		check(world.hex_court.conservation_valid(),"direct mixed terminal conserves exactly600 units")
		_roundtrip(world,"mixed single-source terminal %d"%mask)

func _test_all_family_actual_hits() -> void:
	for family: String in MixtureCatalog.FAMILIES:
		var world := _world()
		var distance := 45_000 if family=="mantle" else (200_000 if family=="split" else 80_000)
		var target := _target(world,2,Vector2i(world.player().position_x+distance,CENTER.y))
		_paid(world,MixtureCatalog.wire_for(63,family))
		for unused: int in range(180):
			if target.health<target.health_maximum: break
			check(world.step([]),"family reaches its actual hit window")
		check(target.health<target.health_maximum,"every family damages through actual combat: "+family)
		for channel: int in 6: check(SpellStatusPolicy.active(target,channel),"actual six-element hit applies channel%d for%s"%[channel,family])
		check(StatusCodec.valid_status_values(target.spell_status_values),"actual channels conform to replicated fixed layout")
		_roundtrip(world,"actual status "+family)

func _test_status_bounds_and_protection() -> void:
	var config := SimConfig.new(120)
	var actor := PlayerState.new(2)
	actor.champion_wire_id=0; actor.team_id=2; actor.spawn_protection_ticks=10
	var wire := MixtureCatalog.wire_for(63,"bolt")
	SpellStatusPolicy.apply_hit(actor,wire,1000,1,1,8000,config,Vector2i(1000,0))
	equal(actor.spell_status_values.count(0),48,"spawn protection admits no status lane")
	actor.spawn_protection_ticks=0; actor.air_dodge_ticks=config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS)
	SpellStatusPolicy.apply_hit(actor,wire,1000,1,1,8000,config,Vector2i(1000,0))
	equal(actor.spell_status_values.count(0),48,"timed dodge protection admits no status lane")
	actor.air_dodge_ticks=0
	SpellStatusPolicy.apply_hit(actor,wire,1000,1,1,0,config,Vector2i(1000,0))
	equal(actor.spell_status_values.count(0),48,"zero-loss hit cannot apply statuses")
	SpellStatusPolicy.apply_hit(actor,wire,1000,1,1,8000,config,Vector2i(1000,0))
	equal(SpellStatusPolicy.startup_ratio(actor),1080,"Earth gives an8percent future-startup window")
	equal(SpellStatusPolicy.movement_ratio(actor),880,"Water gives one12percent ground slow")
	equal(actor.velocity_x,80_000,"Air applies one bounded80px/s shove")
	equal(int(actor.spell_status_values[10]),2000,"Burn receives one quarter of actual damage within cap")
	SpellStatusPolicy.apply_hit(actor,wire,1001,1,1,8000,config,Vector2i(1000,0))
	equal(actor.velocity_x,80_000,"refresh cannot stack the same shove")
	equal(int(actor.spell_status_values[10]),2000,"refresh cannot add a second damage pool")
	check(not SpellStatusPolicy.active(actor,-1) and not SpellStatusPolicy.active(actor,6),"bad channel indices are harmless")
	actor.health=50_000; actor.flux=10_000; actor.health_recovery_delay_ticks=0; actor.flux_recovery_delay_ticks=0
	var health_before:=actor.health; var flux_before:=actor.flux
	PlayerResourcesSystem.step(actor,config)
	equal(actor.health,health_before,"Wither blocks otherwise ready Health recovery")
	equal(actor.flux,flux_before,"Wither blocks otherwise ready Flux recovery")
	var events: Array[Dictionary]=[]
	for unused: int in range(72): SpellStatusPolicy.advance(actor,config,events)
	equal(health_before-actor.health,2000,"finite Burn never exceeds its single bounded pool")
	equal(actor.spell_status_values.count(0),48,"expiry clears every attribution and timer lane")
	var predicted:=PlayerState.new(3)
	predicted.team_id=2; predicted.spawn_protection_ticks=0
	SpellStatusPolicy.apply_hit(predicted,wire,1000,1,1,8000,config,Vector2i.ZERO)
	health_before=predicted.health
	for unused: int in range(13): SpellStatusPolicy.advance(predicted,config,events,false)
	equal(predicted.health,health_before,"prediction advances status clocks without authoring damage")
	equal(int(predicted.spell_status_values[11]),11,"prediction still advances exact Burn pulse clock")

func _test_paid_gust_push_difference() -> void:
	var resisted := _paid_gust_observation(true)
	var neutral := _paid_gust_observation(false)
	for row: Dictionary in [resisted, neutral]:
		equal(int(row.paid_casts), 1, "Gust comparison has exactly one ordinary paid admission")
		equal(int(row.paid_flux), 2000, "Gust comparison pays the actual singleton Rapid cost")
		equal(int(row.hit_damage), 3000, "Gust comparison owns the same real direct loss")
		check(int(row.hit_tick) > 0, "ordinary paid Air projectile reaches the prepared target")
		check(bool(row.stationary_before_hit), "paid contact reaches a genuinely stationary eligible posture")
		equal(int(row.status_ticks), SimConfig.new().milliseconds_to_ticks(int(CombatTuning.cast_definition_view(MixtureCatalog.wire_for(8, "rapid")).status_duration_ms)), "paid Gust keeps its authored first-entry duration")
		equal(int(row.control_state), PlayerState.ControlState.FREE, "paid Gust creates no launch or stun")
		equal(int(row.matter_paid), 600, "paid Gust retains one finite source allocation")
	equal(int(resisted.hit_tick), int(neutral.hit_tick), "paired contacts preserve geometry and timing")
	equal(resisted.velocity, Vector2i(68_000, 0), "Treevor's active stance resists the actual paid Gust by fifteen percent")
	equal(resisted.air_velocity, resisted.velocity, "paid stance scales both stored velocities from the same pre-push window")
	equal(neutral.velocity, Vector2i(80_000, 0), "same profile with identities disabled retains the authored neutral push")
	equal(neutral.air_velocity, neutral.velocity, "neutral paid contact preserves matching ground and air impulse")


func _paid_gust_observation(enabled: bool) -> Dictionary:
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", catalog), "paid Gust uses the real target profile")
	var world := _world()
	var actor := world.player()
	var target := _target(world, 2, Vector2i(actor.position_x+80000, CENTER.y))
	check(champions.apply_to_player(target, "treevor_mason"), "paid Gust applies Treevor's current profile")
	target.spawn_protection_ticks = 0
	target.flux = target.flux_maximum
	if not enabled: target.champion_wire_id = 0
	check(actor.place_proven_spell(0, MixtureCatalog.wire_for(8, "rapid")), "Gust comparison equips actual Air Rapid")
	var result := {"paid_casts":0, "paid_flux":0, "hit_tick":-1, "hit_damage":0, "stationary_before_hit":false,
		"velocity":Vector2i.ZERO, "air_velocity":Vector2i.ZERO, "status_ticks":0, "control_state":-1, "matter_paid":0}
	for tick: int in range(80):
		var before_flux := actor.flux
		var stationary := target.velocity_x == 0 and target.velocity_y == 0 and target.air_height == 0 and target.flux*3 >= target.flux_maximum*2
		var pressed := SimCommand.SPELL_PRESSED_BITS[0] if tick == 0 else 0
		check(world.step([SimCommand.new(world.tick, 1, 0, 0, 0, pressed, 1000, 0)]), "paired paid Gust advances ordinary authority without fixture mutation")
		for event: Dictionary in world.combat_events:
			if String(event.get("type", "")) == "cast_started" and int(event.get("entity_id", 0)) == 1:
				result.paid_casts += 1
				result.paid_flux += before_flux-actor.flux
			if String(event.get("type", "")) == "projectile_hit" and int(event.get("owner_id", 0)) == 1 and int(event.get("target_id", 0)) == 2:
				result.hit_tick = world.tick
				result.hit_damage += int(event.get("damage", 0))
				result.stationary_before_hit = stationary
		if int(result.hit_tick) > 0:
			result.velocity = Vector2i(target.velocity_x, target.velocity_y)
			result.air_velocity = Vector2i(target.air_velocity_x, target.air_velocity_y)
			result.status_ticks = int(target.spell_status_values[3*SpellStatusPolicy.STRIDE])
			result.control_state = target.control_state
			result.matter_paid = int(world.hex_court.metrics.matter_paid)
			check(world.hex_court.conservation_valid(), "paid perk-modified Gust conserves its source")
			_roundtrip(world, "paid Gust identity %s" % enabled)
			break
	return result


func _test_paid_urzh_slow_tradeoff() -> void:
	var enabled := _paid_urzh_observation(true)
	var neutral := _paid_urzh_observation(false)
	var heavy := CombatTuning.cast_definition_view(MixtureCatalog.wire_for(16, "heavy"))
	var base_ticks := SimConfig.new().milliseconds_to_ticks(int(heavy.startup_ms))
	var slowed_ticks := SimConfig.new().milliseconds_to_ticks(int(int(heavy.startup_ms)*1150/1000))
	check(slowed_ticks > base_ticks, "chosen paid Heavy has a real whole-tick casting penalty")
	for row: Dictionary in [enabled, neutral]:
		equal(int(row.paid_casts), 5, "Urzh comparison has three offensive and two defensive ordinary paid admissions")
		equal(int(row.paid_flux), 6000+2*int(heavy.flux_cost), "Urzh sequence pays every authored cost without a refill")
		equal(int(row.matter_paid), 3000, "five admissions retain five finite paid source allocations")
		equal(row.hit_losses.size(), 3, "Water and both Light shots cause actual owned direct loss")
		equal(row.startup_ticks.size(), 2, "both Heavy startup windows are observed at actual paid admission")
		check(int(row.chill_expiry_tick) > int(row.water_hit_tick), "ordinary stepping reaches natural Chill expiry")
		check(bool(row.first_followup_chilled) and not bool(row.second_followup_chilled), "positive and negative paid followups straddle real status expiry")
		equal(int(row.products), 0, "actor contacts and outbound Heavy cannot smuggle in a hostile slow product")
		if row.hit_losses.size() == 3:
			equal(int(row.hit_losses[0]), 3000, "initial Water damage occurs before Chill can grant resistance")
			equal(int(row.hit_losses[2]), 3000, "post-expiry paid Light returns to ordinary damage")
	if enabled.hit_losses.size() == 3 and neutral.hit_losses.size() == 3:
		equal(int(enabled.hit_losses[1]), 2700, "Chilled grounded Urzh resists the actual subsequent paid hit")
		equal(int(neutral.hit_losses[1]), 3000, "same profile without identities takes unchanged followup damage")
	if enabled.startup_ticks.size() == 2 and neutral.startup_ticks.size() == 2:
		equal(enabled.startup_ticks, [slowed_ticks, base_ticks], "actual Urzh startup keeps the15percent penalty only during Chill")
		equal(neutral.startup_ticks, [base_ticks, base_ticks], "matched neutral Heavy timing remains unchanged")
	equal(enabled.water_hit_tick, neutral.water_hit_tick, "paired Water admission and first contact preserve geometry")
	var protected := _paid_urzh_observation(true, true)
	equal(int(protected.paid_casts), 1, "protected negative still requires one real paid Water attempt")
	equal(int(protected.paid_flux), 2000, "protected contact cannot refund the paid Water spell")
	check(protected.hit_losses.is_empty() and int(protected.water_hit_tick) < 0, "spawn-protected actor receives no damaging Water hit")
	check(not bool(protected.ever_chilled), "no paid damaging contact means no Chill or Urzh activation")
	equal(int(protected.final_damage_ratio), 1000, "protection alone cannot activate the timed-slow perk")


func _paid_urzh_observation(enabled: bool, protected: bool = false) -> Dictionary:
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", catalog), "Urzh comparison loads actual profile")
	var world := _world()
	var actor := world.player()
	var target := _target(world, 2, Vector2i(actor.position_x+80000, CENTER.y))
	check(champions.apply_to_player(target, "urzh"), "ordinary paid comparison applies actual Urzh stats")
	target.spawn_protection_ticks = 1000 if protected else 0
	target.health_recovery_per_second = 0
	target.flux_recovery_per_second = 0
	if not enabled: target.champion_wire_id = 0
	var water := MixtureCatalog.wire_for(4, "rapid")
	var light := MixtureCatalog.wire_for(16, "rapid")
	var heavy := MixtureCatalog.wire_for(16, "heavy")
	check(actor.place_proven_spell(0, water) and actor.place_proven_spell(1, light) and target.place_proven_spell(0, heavy), "Urzh sequence equips ordinary legal spells before running")
	var result := {"paid_casts":0, "paid_flux":0, "matter_paid":0, "hit_losses":[], "startup_ticks":[],
		"water_hit_tick":-1, "chill_expiry_tick":-1, "first_followup_chilled":false, "second_followup_chilled":true,
		"ever_chilled":false, "final_damage_ratio":1000, "products":0}
	var first_requested := false
	var second_requested := false
	for tick: int in range(600 if not protected else 120):
		var actor_pressed := SimCommand.SPELL_PRESSED_BITS[0] if tick == 0 else 0
		var target_pressed := 0
		# Walk both actors into a fresh parallel lane before each followup. The
		# previous paid terminal remains real, but cannot intercept the next hit.
		var lane_y := CENTER.y-(200000 if result.hit_losses.size() >= 2 else 100000)
		var moving_to_lane := int(result.water_hit_tick) >= 0 and not protected
		var actor_move_y := -1000 if moving_to_lane and actor.position_y > lane_y else 0
		var target_move_y := -1000 if moving_to_lane and target.position_y > lane_y else 0
		var lane_ready := moving_to_lane and actor.position_y <= lane_y and target.position_y <= lane_y
		var ready := actor.pending_cast_wire_id == 0 and actor.cast_recovery_ticks == 0 and actor.spell_cooldown_for_wire(light) == 0 and target.pending_cast_wire_id == 0 and target.cast_recovery_ticks == 0 and target.spell_cooldown_for_wire(heavy) == 0
		if lane_ready and ready:
			if not first_requested:
				first_requested = true
				result.first_followup_chilled = SpellStatusPolicy.active(target, 2)
				actor_pressed = SimCommand.SPELL_PRESSED_BITS[1]
				target_pressed = SimCommand.SPELL_PRESSED_BITS[0]
			elif int(result.chill_expiry_tick) >= 0 and not second_requested:
				second_requested = true
				result.second_followup_chilled = SpellStatusPolicy.active(target, 2)
				actor_pressed = SimCommand.SPELL_PRESSED_BITS[1]
				target_pressed = SimCommand.SPELL_PRESSED_BITS[0]
		var before_actor_flux := actor.flux
		var before_target_flux := target.flux
		var aim := Vector2i(target.position_x-actor.position_x, target.position_y-actor.position_y)
		check(world.step([SimCommand.new(world.tick, 1, 0, actor_move_y, 0, actor_pressed, aim.x, aim.y), SimCommand.new(world.tick, 2, 0, target_move_y, 0, target_pressed, 1000, 0)]), "Urzh paid sequence advances through ordinary lane changes without editing status, resources or clocks")
		for event: Dictionary in world.combat_events:
			if String(event.get("type", "")) == "cast_started":
				result.paid_casts += 1
				if int(event.entity_id) == 1: result.paid_flux += before_actor_flux-actor.flux
				else:
					result.paid_flux += before_target_flux-target.flux
					result.startup_ticks.append(target.pending_cast_ticks)
			if String(event.get("type", "")) == "projectile_hit" and int(event.get("owner_id", 0)) == 1 and int(event.get("target_id", 0)) == 2:
				result.hit_losses.append(int(event.damage))
				if int(event.source_wire_id) == water: result.water_hit_tick = world.tick
		var chilled := SpellStatusPolicy.active(target, 2)
		if bool(result.ever_chilled) and not chilled and int(result.chill_expiry_tick) < 0: result.chill_expiry_tick = world.tick
		result.ever_chilled = bool(result.ever_chilled) or chilled
		result.products = maxi(int(result.products), world.hex_court.products.size())
		if result.hit_losses.size() == 3 and result.startup_ticks.size() == 2: break
	result.matter_paid = int(world.hex_court.metrics.matter_paid)
	result.final_damage_ratio = Perks.ratio(target, "incoming_damage_ratio")
	check(world.hex_court.conservation_valid(), "Urzh status tradeoff preserves actual paid matter")
	_roundtrip(world, "Urzh timed slow %s protected %s" % [enabled, protected])
	return result


func _test_paid_black_ice_urzh_window() -> void:
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", catalog), "Black Ice witness loads actual Urzh profile")
	var world := _world()
	var target := _target(world, 2, CENTER+Vector2i(160000, 0))
	check(champions.apply_to_player(target, "urzh"), "Black Ice witness applies Urzh before the paid run")
	target.spawn_protection_ticks = 0
	_paid(world, MixtureCatalog.wire_for(36, "bolt"), CENTER)
	var observed := false
	for unused: int in 240:
		var move := -1000 if not world.hex_court.products.is_empty() else 0
		check(world.step([SimCommand.new(world.tick, 2, move, 0)]), "ordinary movement enters a genuinely paid Black Ice field")
		if target.control_state != PlayerState.ControlState.SLOWED: continue
		observed = true
		equal(target.slow_ratio, 650, "original Black Ice entry retains its authored timed slow")
		check(target.control_ticks > 0, "Black Ice consumer owns a positive live slow clock")
		check(not SpellStatusPolicy.active(target, 2), "field-only witness does not borrow direct-hit Chill")
		equal(Perks.ratio(target, "incoming_damage_ratio"), 900, "original paid recipe321 route still grants the existing resistance")
		equal(Perks.ratio(target, "spell_startup_ratio"), 1150, "original paid recipe321 route retains the same casting tradeoff")
		break
	check(observed, "finite paid Black Ice plus legal walking actually opens Urzh's original window")
	equal(int(world.hex_court.metrics.matter_paid), 600, "Black Ice entry consumes only the one original paid source")
	check(world.hex_court.conservation_valid(), "original slow field preserves finite paid ownership")
	_roundtrip(world, "Urzh original paid Black Ice entry")


func _test_paid_pooled_damage_perks() -> void:
	# The shared pool bounds actual loss, while each authored raw quote still
	# receives the target's ordinary modifier. All posture changes are commands.
	for family: String in ["mantle", "fuse"]:
		for profile: String in ["biggy_bob", "haara"]:
			for count: int in [1, 5]:
				var active := _paid_area_perk_observation(family, profile, true, count)
				var neutral := _paid_area_perk_observation(family, profile, false, count)
				var expected_active: Array = []
				var expected_neutral: Array = []
				if family == "mantle":
					expected_active = [3720] if profile == "biggy_bob" else [4200]
					expected_neutral = [4000]
					if count == 5:
						expected_active = [3720, 3720, 3720, 3720, 1120] if profile == "biggy_bob" else [4200, 4200, 4200, 3400, 0]
						expected_neutral = [4000, 4000, 4000, 4000, 0]
				else:
					expected_active = [18600] if profile == "biggy_bob" else [20000]
					expected_neutral = [20000]
					if count == 5:
						expected_active = [18600, 1400, 0, 0, 0] if profile == "biggy_bob" else [20000, 0, 0, 0, 0]
						expected_neutral = [20000, 0, 0, 0, 0]
				equal(active.losses, expected_active, "paid %s %s keeps raw quotes, incoming perk and ascending target ownership" % [family, profile])
				equal(neutral.losses, expected_neutral, "matched profile with identity disabled retains original %s quotes" % family)
				equal(active.paid_flux, neutral.paid_flux, "incoming-area modifiers never change the caster's payment")
				equal(active.release_tick, neutral.release_tick, "incoming-area modifiers never retime the paid source")
		var protected := _paid_area_perk_observation(family, "biggy_bob", true, 1, true)
		equal(protected.losses, [0], "paid %s cannot spend damage through spawn protection" % family)
		equal(int(protected.remaining), int(protected.pool), "protected paid area retains its entire finite direct pool until retirement")
		check(protected.hit_ids.is_empty(), "protected area contact cannot acquire a hit-history entry")


func _paid_area_perk_observation(family: String, profile: String, enabled: bool, count: int, protected: bool = false) -> Dictionary:
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", catalog), "paid area comparison loads real profiles")
	var world := _world()
	var actor := world.player()
	var wire := MixtureCatalog.wire_for(16, family)
	var definition := CombatTuning.cast_definition_view(wire)
	check(actor.place_proven_spell(0, wire), "area comparison equips the ordinary paid Light delivery")
	var point := Vector2i(actor.position_x+45000, actor.position_y) if family == "mantle" else CENTER
	var targets: Array[PlayerState] = []
	for index: int in count:
		var target := _target(world, index+2, point)
		check(champions.apply_to_player(target, profile), "area comparison applies actual %s profile before stepping" % profile)
		target.health_maximum = 1000000
		target.health = 1000000
		target.health_recovery_per_second = 0
		target.flux_recovery_per_second = 0
		# A short initial protection window expires naturally after the paid
		# Mantle release, so its live pool can be observed before all five hits.
		target.spawn_protection_ticks = 1000 if protected else 30
		if not enabled: target.champion_wire_id = 0
		targets.append(target)
	# Opposite insertion order cannot change the finite pool's target ordering.
	world.players.reverse()
	var result := {"paid_casts":0, "paid_flux":0, "release_tick":-1, "pool":int(definition.damage), "remaining":-1, "losses":[], "hit_ids":[]}
	var source := world.next_projectile_id
	var observed_shot: ProjectileState = null
	for tick: int in 260:
		var commands: Array[SimCommand] = [SimCommand.new(world.tick, 1, 0, 0, 0, SimCommand.SPELL_PRESSED_BITS[0] if tick == 0 else 0, 1000, 0, point.x, point.y)]
		for target: PlayerState in targets:
			commands.append(SimCommand.new(world.tick, target.entity_id, 0, 0, SimCommand.HELD_SLIDE if profile == "biggy_bob" else 0))
		var before_flux := actor.flux
		check(world.step(commands), "finite paid area advances with ordinary crouch/neutral input and no resource edits")
		for shot: ProjectileState in world.projectiles:
			if shot.source_cast_id != source: continue
			observed_shot = shot
			if int(result.release_tick) < 0: result.release_tick = world.tick
			check(shot.delivery_damage_remaining >= 0 and shot.delivery_damage_remaining <= int(result.pool), "live paid area cannot manufacture or overspend its direct pool")
		for event: Dictionary in world.combat_events:
			if String(event.get("type", "")) == "cast_started" and int(event.get("entity_id", 0)) == 1:
				result.paid_casts += 1
				result.paid_flux += before_flux-actor.flux
			if String(event.get("type", "")) != "projectile_hit": continue
			equal(int(event.get("projectile_id", 0)), source, "area direct hit belongs to the one ordinary paid projectile")
			equal(int(event.get("owner_id", 0)), 1, "area damage retains paid caster attribution")
			equal(int(event.get("source_wire_id", 0)), wire, "area damage retains its exact paid delivery and element")
			result.hit_ids.append(int(event.target_id))
			var target := world.player(int(event.target_id))
			equal(Perks.ratio(target, "incoming_damage_ratio"), (930 if profile == "biggy_bob" else 1050) if enabled else 1000, "real hit occurs in the intended ordinary posture window")
			check(SpellStatusPolicy.active(target, 4), "actual positive area loss applies its ordinary Revealed status")
			equal(int(target.spell_status_values[39]), source, "area status retains the paid source rather than a synthetic new cast")
		if observed_shot != null and world.projectiles.is_empty(): break
	check(observed_shot != null and int(result.release_tick) > 0, "paid area actually releases before the bounded observation ends")
	if observed_shot != null:
		result.remaining = observed_shot.delivery_damage_remaining
		equal(Array(observed_shot.contact_entity_ids), result.hit_ids, "only actual damaging contacts enter the one-touch history")
	var total := 0
	for target: PlayerState in targets:
		var loss := 1000000-target.health
		result.losses.append(loss)
		total += loss
		if protected: equal(target.spell_status_values.count(0), 48, "protected paid area cannot allocate an elemental status")
	equal(total+int(result.remaining), int(result.pool), "shared area pool is debited by exact actual Health loss including the final partial victim")
	equal(int(result.paid_casts), 1, "area comparison includes one accepted paid admission")
	equal(int(result.paid_flux), int(definition.flux_cost), "area comparison pays the original positive authored cost exactly once")
	equal(int(world.hex_court.metrics.matter_paid), 600, "area comparison owns exactly one paid material allocation")
	check(world.projectiles.is_empty(), "area flight expires or exhausts naturally without clock changes")
	check(world.hex_court.conservation_valid(), "area modifier comparison retains finite source conservation")
	_roundtrip(world, "paid area modifier %s %s %s %s" % [family, profile, enabled, count])
	return result


func _test_paid_burning_perks() -> void:
	var crouched := _paid_burning_perk_observation("biggy_bob", true)
	var neutral := _paid_burning_perk_observation("biggy_bob", false)
	var vulnerable := _paid_burning_perk_observation("haara", true)
	var vulnerable_control := _paid_burning_perk_observation("haara", false)
	equal(int(crouched.direct), 3000, "Dwarf first receives the paid Fire hit before choosing crouch")
	equal(int(neutral.direct), 3000, "matched identity-disabled standing Fire contact has equal direct loss")
	equal(crouched.pulses, [372, 372, 6], "ordinary later crouch resists each raw 400 Burn pulse while retaining the exact finite tail")
	equal(neutral.pulses, [400, 350], "neutral Fire retains the original 750-unit finite Burn budget")
	equal(int(vulnerable.direct), 3150, "healthy Nymph takes its ordinary vulnerable initial paid hit")
	equal(vulnerable.pulses, [420, 367], "vulnerability increases the pulse but never overspends its actual-loss-derived 787-unit pool")
	equal(vulnerable_control.pulses, [400, 350], "same-profile identities-disabled control removes vulnerability only")
	for row: Dictionary in [crouched, neutral, vulnerable, vulnerable_control]:
		equal(int(row.paid_casts), 1, "Burn modifier route starts from one accepted paid Fire cast")
		equal(int(row.paid_flux), 2000, "Burn comparison pays the ordinary Fire Rapid cost once")
		equal(int(row.matter_paid), 600, "Burn pulses cannot add paid matter or sources")
		check(int(row.expired_tick) > int(row.hit_tick), "Burn's real status clock expires without edits")
		equal(int(row.total_burn), int(row.initial_pool), "unprotected observation spends at most and eventually exactly its single finite Burn pool")
	var protected := _paid_burning_perk_observation("biggy_bob", true, true)
	equal(int(protected.paid_casts), 1, "protected negative still admits and pays a real Fire shot")
	equal(int(protected.paid_flux), 2000, "protection does not refund the real Fire admission")
	equal(int(protected.direct), 0, "protected Fire contact causes no direct loss")
	check(protected.pulses.is_empty(), "protected contact cannot manufacture a later Burn pulse")
	equal(int(protected.initial_pool), 0, "protected negative allocates no status damage budget")


func _paid_burning_perk_observation(profile: String, enabled: bool, protected: bool = false) -> Dictionary:
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", catalog), "Burn comparison loads actual profile")
	var world := _world()
	var actor := world.player()
	var target := _target(world, 2, Vector2i(actor.position_x+80000, actor.position_y))
	check(champions.apply_to_player(target, profile), "Burn comparison uses actual profile before ordinary simulation")
	target.health_maximum = 1000000
	target.health = 1000000
	target.health_recovery_per_second = 0
	target.flux_recovery_per_second = 0
	target.spawn_protection_ticks = 1000 if protected else 0
	if not enabled: target.champion_wire_id = 0
	var wire := MixtureCatalog.wire_for(2, "rapid")
	check(actor.place_proven_spell(0, wire), "Burn comparison equips real Fire Rapid")
	var source := world.next_projectile_id
	var result := {"paid_casts":0, "paid_flux":0, "matter_paid":0, "direct":0, "hit_tick":-1, "expired_tick":-1, "initial_pool":0, "total_burn":0, "ground_damage":0, "pulses":[]}
	for tick: int in 240:
		var held := SimCommand.HELD_SLIDE if profile == "biggy_bob" and int(result.hit_tick) >= 0 else 0
		var before_flux := actor.flux
		var prior_pool := int(target.spell_status_values[10])
		check(world.step([SimCommand.new(world.tick, 1, 0, 0, 0, SimCommand.SPELL_PRESSED_BITS[0] if tick == 0 else 0, 1000, 0), SimCommand.new(world.tick, 2, 0, 0, held)]), "paid Burning advances with ordinary inputs through natural status expiry")
		for event: Dictionary in world.combat_events:
			var kind := String(event.get("type", ""))
			if kind == "cast_started" and int(event.get("entity_id", 0)) == 1:
				result.paid_casts += 1
				result.paid_flux += before_flux-actor.flux
			if kind == "projectile_hit" and int(event.get("target_id", 0)) == 2:
				equal(int(event.get("projectile_id", 0)), source, "Burn is seeded by the one ordinary paid projectile")
				result.direct += int(event.damage)
				result.hit_tick = world.tick
				result.initial_pool = int(target.spell_status_values[10])
				check(not target.crouching, "initial Fire hit precedes the later defensive crouch")
			if kind == "hex_pressure" and int(event.get("entity_id", 0)) == 2:
				equal(int(event.owner_id), 1, "separate ground pressure retains the original paid caster")
				equal(int(event.source_id), source, "separate ground pressure comes from the original paid Fire terminal")
				equal(int(event.product_id), 0, "single Fire terminal cannot invent a reaction product")
				result.ground_damage += int(event.amount)
			if kind != "spell_status_hit": continue
			equal(int(event.owner_id), 1, "Burn pulse retains its original paid owner")
			equal(int(event.source_wire_id), wire, "Burn pulse retains the Fire source wire")
			equal(int(event.target_id), 2, "Burn cannot redirect the finite pool to another actor")
			equal(int(target.spell_status_values[15]), source, "Burn pulse retains original source identity after projectile retirement")
			check(int(event.damage) > 0 and int(event.damage) <= prior_pool, "positive Burn pulse never overspends remaining actual-loss budget")
			equal(prior_pool-int(target.spell_status_values[10]), int(event.damage), "Burn debits the exact actual pulse loss")
			result.pulses.append(int(event.damage))
			result.total_burn += int(event.damage)
		if int(result.hit_tick) >= 0 and not SpellStatusPolicy.active(target, 1):
			result.expired_tick = world.tick
			break
	result.matter_paid = int(world.hex_court.metrics.matter_paid)
	equal(int(result.initial_pool), int(result.direct)/4, "Burn starts with the existing one-quarter actual-hit budget")
	equal(1000000-target.health, int(result.direct)+int(result.total_burn)+int(result.ground_damage), "complete Health loss is accounted by separately owned direct, Burning and terminal ground events")
	equal(int(result.ground_damage), 0 if protected else (3720 if profile == "biggy_bob" and enabled else (4200 if enabled else 4000)), "real Fire ground damage is measured separately and never credited to Burning pulses")
	equal(target.spell_status_values.count(0), 48, "natural expiry or protected refusal clears all status and attribution lanes")
	check(world.hex_court.conservation_valid(), "finite Burn pulse comparison preserves paid matter")
	_roundtrip(world, "paid Burning modifier %s %s protected %s" % [profile, enabled, protected])
	return result


func _test_paid_wither_recovery_difference() -> void:
	# Matched ordinary paid Rapid hits: Light has no recovery modifier; Dark
	# adds Withered. No clocks or resources are edited after the run starts.
	var light := _paid_recovery_observation(16)
	var dark := _paid_recovery_observation(32)
	for row: Dictionary in [light, dark]:
		equal(int(row.paid_casts), 1, "recovery comparison includes exactly one ordinary paid admission")
		equal(int(row.paid_flux), 2000, "matched Rapid pays its positive compiled cost")
		equal(int(row.hit_damage), 3000, "recovery comparison includes the same real owned direct loss")
		check(int(row.hit_tick) >= 0, "matched paid projectile actually reaches the actor")
		check(int(row.first_health_recovery_tick) > int(row.hit_tick), "ordinary Health eventually recovers without resetting its clock")
		equal(int(row.products), 0, "one singleton hit cannot smuggle in a recovery-denial ground product")
	equal(int(light.hit_tick), int(dark.hit_tick), "matched direct contacts occur at the same simulation tick")
	equal(int(light.first_health_recovery_tick), int(dark.first_health_recovery_tick), "Withered adds no Health delay beyond the ordinary longer damage delay")
	check(int(dark.first_health_recovery_tick)-int(dark.hit_tick) >= SimConfig.new().milliseconds_to_ticks(PlayerTuning.HEALTH_RECOVERY_DELAY_MS), "Health recovery still waits for its real 5500 ms damage delay")
	check(int(dark.wither_expiry_tick) > int(dark.hit_tick) and int(dark.wither_expiry_tick) < int(dark.first_health_recovery_tick), "Withered expires before otherwise ready Health recovery")
	check(int(light.flux_after_status_window) > int(dark.flux_after_status_window), "Dark actually denies ready Flux recovery through the paid-hit route")
	equal(int(light.health_after_status_window), int(dark.health_after_status_window), "the hit window cannot claim an additional Health-recovery benefit")
	var text := StatusText.rows_for_mask(32)
	equal(text.size(), 1, "Dark exposes one shared direct-hit status description")
	equal(String(text[0].summary), "Withered: ready Flux recovery blocked", "headline states the actual marginal on-hit benefit")
	check(String(text[0].detail).contains("Ground recovery-denial fields have separate rules"), "direct-hit description keeps sustained ground denial separate")
	text[0].summary = "mutated caller"
	check(StatusText.description(32) != "mutated caller", "description rows are detached from shared player-facing content")
	equal(StatusText.rows_for_mask(63).size(), 6, "complete mixture descriptions preserve all six status channels")
	check(StatusText.rows_for_mask(0).is_empty() and StatusText.description(3).is_empty(), "invalid status identities do not invent an explanation")


func _paid_recovery_observation(mask: int) -> Dictionary:
	var world := _world()
	var actor := world.player()
	var target := _target(world, 2, Vector2i(actor.position_x + 80000, CENTER.y))
	target.health_recovery_per_second = PlayerTuning.HEALTH_RECOVERY_PER_SECOND
	target.flux_maximum = PlayerTuning.FLUX_MAXIMUM
	target.flux = 10000
	target.flux_recovery_per_second = PlayerTuning.FLUX_RECOVERY_PER_SECOND
	var wire := MixtureCatalog.wire_for(mask, "rapid")
	check(actor.place_proven_spell(0, wire), "recovery comparison equips the actual singleton Rapid")
	var result := {"hit_tick":-1, "hit_damage":0, "paid_casts":0, "paid_flux":0,
		"wither_expiry_tick":-1, "first_health_recovery_tick":-1,
		"flux_after_status_window":-1, "health_after_status_window":-1, "products":0}
	var previous_health := target.health
	var had_wither := false
	var window_ticks := world.config.milliseconds_to_ticks(int(CombatTuning.cast_definition_view(wire).status_duration_ms))
	for tick: int in range(900):
		var before_flux := actor.flux
		var pressed := SimCommand.SPELL_PRESSED_BITS[0] if tick == 0 else 0
		check(world.step([SimCommand.new(world.tick, 1, 0, 0, 0, pressed, 1000, 0)]), "paired paid recovery observation advances ordinary authority")
		for event: Dictionary in world.combat_events:
			if String(event.get("type", "")) == "cast_started" and int(event.get("entity_id", 0)) == 1:
				result.paid_casts += 1
				result.paid_flux += before_flux-actor.flux
			if String(event.get("type", "")) == "projectile_hit" and int(event.get("owner_id", 0)) == 1 and int(event.get("target_id", 0)) == 2:
				result.hit_tick = world.tick
				result.hit_damage += int(event.get("damage", 0))
		if int(result.hit_tick) >= 0:
			if target.health > previous_health and int(result.first_health_recovery_tick) < 0:
				result.first_health_recovery_tick = world.tick
			if world.tick-int(result.hit_tick) == window_ticks:
				result.flux_after_status_window = target.flux
				result.health_after_status_window = target.health
		var withered := SpellStatusPolicy.active(target, 5)
		if had_wither and not withered and int(result.wither_expiry_tick) < 0: result.wither_expiry_tick = world.tick
		had_wither = had_wither or withered
		previous_health = target.health
		result.products = maxi(int(result.products), world.hex_court.products.size())
	return result


func _test_split_budget() -> void:
	var world:=_world()
	_paid(world,MixtureCatalog.wire_for(4,"split"))
	for unused: int in range(32):
		if world.projectiles.size()==2: break
		check(world.step([]),"paid splitter reaches its one-time travel delay")
	equal(world.projectiles.size(),2,"one parent becomes exactly two branches")
	if world.projectiles.size()!=2:return
	var source:=world.projectiles[0].source_cast_id
	equal(world.projectiles[1].source_cast_id,source,"children share one paid source")
	equal(world.projectiles[0].damage+world.projectiles[1].damage,14_000,"split partitions direct damage exactly")
	equal(world.hex_court.flight_quantity(source,world.projectiles[0].entity_id)+world.hex_court.flight_quantity(source,world.projectiles[1].entity_id),600,"split partitions finite matter exactly")
	for shot: ProjectileState in world.projectiles: equal(shot.delivery_phase,2,"both branches are permanently marked split")
	_roundtrip(world,"split children")
	for unused: int in range(35): check(world.step([]),"split children continue physical flight")
	equal(world.projectiles.size(),2,"children never split recursively")

func _test_fuse_warning_and_shared_pool() -> void:
	var world:=_world()
	var target:=_target(world,2,CENTER)
	_paid(world,MixtureCatalog.wire_for(4,"fuse"),CENTER)
	for unused: int in range(90):
		if world.projectiles.size()==1 and world.projectiles[0].delivery_phase==1:break
		check(world.step([]),"Fuse reaches its real impact")
	equal(world.projectiles.size(),1,"armed Fuse stays replicated")
	if world.projectiles.is_empty():return
	var shot:=world.projectiles[0]
	equal(shot.delivery_ticks,72,"Fuse arms a full600ms warning")
	equal(target.health,1_000_000,"landing itself does not damage")
	var second:=_target(world,3,Vector2i(shot.position_x,shot.position_y+40_000))
	_roundtrip(world,"armed Fuse warning")
	for unused: int in range(71):check(world.step([]),"full warning advances")
	equal(target.health,1_000_000,"penultimate warning tick remains harmless")
	equal(second.health,1_000_000,"warning is harmless to every nearby actor")
	check(world.step([]),"Fuse executes on exact expiry of warning")
	equal((1_000_000-target.health)+(1_000_000-second.health),20_000,"one shared blast pot is not multiplied per victim")
	equal(world.projectiles.size(),0,"Fuse terminal cannot explode again")
	check(world.hex_court.conservation_valid(),"Fuse consumes only its one paid matter source")

func _funded_shot(world: SimWorld,wire:int) -> ProjectileState:
	var definition:=CombatTuning.cast_definition_view(wire)
	check(world.hex_court.reserve_cast(1,wire),"capacity fixture reserves an actual live spell")
	check(PlayerResourcesSystem.spend_flux(world.player(),int(definition.flux_cost),world.config),"every capacity witness pays its real Flux cost")
	world.hex_court.commit_payment(1)
	var source:=world.next_projectile_id
	world.next_projectile_id+=1
	world.hex_court.bind_release(1,source,CENTER,Vector2i(1000,0),1)
	var shot:=ProjectileState.new(source,1,1,wire,int(definition.element_wire_id),CENTER,Vector2i(330_000,0),int(definition.radius),int(definition.damage),world.config.milliseconds_to_ticks(int(definition.lifetime_ms)))
	shot.source_cast_id=source
	shot.reaction_strength=int(definition.reaction_strength)
	shot.initial_strength=shot.reaction_strength
	shot.remaining_strength=shot.reaction_strength
	HexExpandedDelivery.initialize(shot,world.config)
	world.projectiles.append(shot)
	return shot

func _test_split_capacity_reservations() -> void:
	for pending: bool in [false,true]:
		var world:=_world()
		world.player().flux_maximum=1_000_000;world.player().flux=1_000_000
		var wire:=MixtureCatalog.wire_for(4,"split")
		for index: int in 15:
			var shot:=_funded_shot(world,wire)
			shot.delivery_ticks=1 if index<2 else 30
		if pending:
			check(world.player().place_proven_spell(0,wire),"pending capacity control equips actual Split")
			var before:=world.player().flux
			CombatSystem.step_player(world.player(),SimCommand.new(0,1,0,0,0,SimCommand.SPELL_PRESSED_BITS[0]),world.config,world.next_projectile_id,world.next_field_id,world.collision,world.combat_events,world.transition_policy,1,1,world.hex_court)
			equal(world.player().pending_cast_wire_id,wire,"one free slot belongs to an actually paid pending release")
			equal(before-world.player().flux,10_000,"pending reservation paid exactly once")
		var stock_before:=int(world.hex_court.metrics.matter_paid)
		HexExpandedDelivery.prepare(world)
		equal(world.projectiles.size(),15 if pending else 16,"simultaneous ready parents cannot reuse the same final owner slot")
		var split_count:=0
		for shot: ProjectileState in world.projectiles:
			if shot.delivery_phase==2:split_count+=1
		equal(split_count,0 if pending else 2,"only the admitted parent and child carry spent-split state")
		equal(int(world.hex_court.metrics.matter_paid),stock_before,"branching cannot issue another source stock")
		check(world.hex_court.conservation_valid(),"staged capacity refusal preserves every paid source")
	var held:=_world()
	held.player().flux_maximum=1_000_000;held.player().flux=1_000_000
	for unused: int in 15:_funded_shot(held,MixtureCatalog.wire_for(4,"mantle"))
	_funded_shot(held,MixtureCatalog.wire_for(16,"bolt"))
	var stationary:=HexExpandedDelivery.prepare(held)
	equal(stationary.size(),15,"fifteen real paid Mantles remain stationary")
	equal(held.projectiles.size(),16,"stationary attacks remain in the authority capacity inventory")
	equal(held.available_cast_capacity(1).x,0,"later optical children cannot borrow held Mantle slots")

func _test_mantle_touch_and_trail() -> void:
	var world:=_world()
	var target:=_target(world,2,Vector2i(world.player().position_x+45_000,CENTER.y))
	_paid(world,MixtureCatalog.wire_for(4,"mantle"))
	equal(target.health,996_000,"Mantle touch spends one4k hit")
	equal(world.projectiles.size(),1,"Mantle persists on its paid actor")
	if world.projectiles.is_empty():return
	var shot:=world.projectiles[0]
	equal(shot.delivery_damage_remaining,12_000,"touch debits shared16k pool")
	for unused: int in range(16):check(world.step([]),"stationary Mantle remains finite")
	equal(target.health,996_000,"contact history prevents repeated damage to stationary victim")
	for unused: int in range(35):check(world.step([SimCommand.new(world.tick,1,1000,0)]),"Mantle moves with normal paid owner motion")
	equal(shot.position_x,world.player().position_x,"Mantle follows actual actor position")
	var record: Dictionary=world.hex_court.casts.get(int(world.hex_court.sources.get(shot.source_cast_id,0)),{})
	check(not record.is_empty(),"moving Mantle retains live source ledger")
	if not record.is_empty():
		check(int(record.trail_spent)>0 and int(record.trail_spent)<=150,"moving Mantle deposits only its bounded four-installment trail allowance")
		check(int(record.ledger.flight_quantity)>=450,"trail leaves at least450 paid units for terminal")
	check(world.hex_court.conservation_valid(),"touch and trails never mint paid matter")
	_roundtrip(world,"moving Mantle and finite trail")

func _test_rebound() -> void:
	var world:=_world()
	world.collision.add_obstacle(CollisionWorld.Obstacle.new(10,CENTER.x,CENTER.y-100_000,CENTER.x+20_000,CENTER.y+100_000,false))
	_paid(world,MixtureCatalog.wire_for(4,"rebound"))
	var bounced:=false
	for unused: int in range(60):
		check(world.step([]),"bank shot travels to real cover")
		if not world.projectiles.is_empty() and world.projectiles[0].remaining_bounces==1:
			bounced=true;break
	check(bounced,"Rebound banks from physical cover exactly once")
	if world.projectiles.is_empty():return
	check(world.projectiles[0].velocity_x<0,"surface normal reverses real travel direction")
	equal(world.projectiles[0].damage,11_000,"banking does not create a damage multiplier")
	equal(world.hex_court.flight_quantity(world.projectiles[0].source_cast_id,world.projectiles[0].entity_id),600,"banking preserves one source stock")
	_roundtrip(world,"banked projectile")

func _test_mask_optics() -> void:
	var shot:=ProjectileState.new(1000,1,1,MixtureCatalog.wire_for(20,"bolt"),3,CENTER,Vector2i(1,0),1,100,100)
	var prism: Dictionary={"recipe_wire_id":325,"active_tick":0,"decay_tick":100,"health":100,"capacity":100}
	check(HexProjectileCombat._product_eligible(prism,shot,1),"Light+Water sees optical technique even with Water representative palette")
	shot.source_wire_id=MixtureCatalog.wire_for(4,"bolt")
	check(not HexProjectileCombat._product_eligible(prism,shot,1),"Water-only negative control cannot claim Light behavior")
	shot.source_wire_id=MixtureCatalog.wire_for(6,"bolt")
	prism.recipe_wire_id=317
	check(HexProjectileCombat._product_eligible(prism,shot,1),"Fire+Water can meet Fire suppression gate independent of palette")

func _roundtrip(world: SimWorld,label:String) -> void:
	var packet:=Snapshot.capture(world)
	check(not packet.is_empty(),label+" captures all authoritative state")
	if packet.is_empty():return
	var restored:=Snapshot.prepare(packet,world)
	check(restored!=null,label+" passes complete strict decode")
	if restored==null:return
	equal(restored.state_hash(),world.state_hash(),label+" retains exact canonical authority")
