extends FluxTestSuite

const Snapshot = preload("res://src/net/hex_world_snapshot.gd")
const StatusCodec = preload("res://src/net/expanded_spell_state_codec.gd")
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
