extends FluxTestSuite

const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")
const Deposit = preload("res://src/sim/chemistry/element_deposit_state.gd")
const Reaction = preload("res://src/sim/chemistry/element_reaction_state.gd")
var config := SimConfig.new(120)

func run() -> int:
	_test_readable_lifetimes()
	_test_enlarged_extents()
	_test_deposits()
	_test_pairs()
	_test_effects()
	_test_optics()
	_test_connectivity()
	_test_capacity_and_replay()
	_test_archived_beam_routing()
	_test_cover_lifecycle_edges()
	_test_all_reaction_boundaries_and_replay()
	_test_link_expiry_and_pulse_windows()
	_test_entry_bounds_edges()
	return finish("element-chemistry")


func _test_readable_lifetimes() -> void:
	var expected := [0, 5000, 4000, 5000, 3000, 5000, 3000, 4000, 4000]
	for element: int in range(1, 9):
		equal(Chemistry.ELEMENT_LIFE_MS[element], expected[element], "temporary elements retain the authored3to5second combining window")
	var impulses := {312: 100, 313: 120, 314: 100, 332: 140}
	for wire: int in range(301, 337):
		var definition := Chemistry.recipe(wire)
		var reaction := _reaction(wire)
		check(reaction.validate(), "longer reactions remain inside existing snapshot validation bounds")
		check(reaction.expiry_tick - reaction.created_tick <= 600, "all phases together remain within5seconds")
		if impulses.has(wire):
			equal(definition.active_ms, impulses[wire], "instant reaction active window is not stretched into repeated hits")
		elif wire == 331:
			equal(definition.active_ms, 2000, "Capacitor has a finite two-second acceleration window before its single discharge")
		else:
			check(int(definition.active_ms) >= 2250, "sustained effects now offer a longer readable interaction window")

func _test_enlarged_extents() -> void:
	equal(Chemistry.extent_policy().linear_ratio, 1250, "one fingerprinted policy enlarges footprints by25percent linearly")
	for element: int in range(1, 9):
		for strength: int in [1, 250, 1000]:
			var deposits: Array = []
			equal(Chemistry.deposit_terminal(deposits, element, element, 100, 1, 1, element, Vector2i(500000, 500000), 0, config, Vector2i(1000, 0), strength), 1, "each supported impact strength creates finite material")
			var deposit: ElementDepositState = deposits[0]
			equal(deposit.radius, 30000 + strength * 10, "every element uses30to40px authoritative impact radius")
			check(deposit.radius > Chemistry.TRAIL_RADIUS, "every impact is larger than the20px trail")
			check(Deposit.from_values(deposit.canonical_values()) != null, "enlarged impact survives canonical serialization")
	var full := _deposit(1, 1).canonical_values()
	for invalid_radius: int in [20001, 29999, 40001]:
		var bad := full.duplicate()
		bad[10] = invalid_radius
		check(Deposit.from_values(bad) == null, "unknown or excessive material footprint fails closed")
	for wire: int in range(301, 337):
		var row: Array = Chemistry.RECIPE_ROWS[wire - 301]
		var definition := Chemistry.recipe(wire)
		var reaction := _reaction(wire)
		equal(reaction.radius, int(float(row[7]) * 1.25), "all36 reaction radii grow exactly25percent")
		equal(reaction.length, int(float(row[8]) * 1.25), "all36 strips, cover lengths and safe ring centers grow consistently")
		for item: Array in [["formation_ms", 4], ["active_ms", 5], ["decay_ms", 6], ["speed", 9], ["pulse_ms", 10]]:
			equal(int(definition[item[0]]), int(row[item[1]]), "extent changes never alter phase timing, travel speed or pulse cadence")
		equal(reaction.health, int(row[11]) * 1000, "extent changes never add cover health")
		check(Reaction.from_values(reaction.canonical_values()) != null, "all36 enlarged result shapes survive wire validation")
	var steam := _reaction(310)
	Chemistry._update_geometry(steam, null, config, steam.active_tick)
	equal(steam.radius, 37500, "Steam begins at the enlarged readable formation radius")
	Chemistry._update_geometry(steam, null, config, steam.active_tick + config.milliseconds_to_ticks(900))
	equal(steam.radius, 112500, "Steam reaches its enlarged extent after the unchanged growth window")
	var freeze := _reaction(318)
	Chemistry._update_geometry(freeze, null, config, freeze.active_tick)
	equal(freeze.length, 25000, "Freeze starts with an enlarged strip")
	Chemistry._update_geometry(freeze, null, config, freeze.active_tick + config.milliseconds_to_ticks(1200))
	equal(freeze.length, 175000, "Freeze reaches enlarged length after the unchanged growth window")
	equal(freeze.endpoint_x - freeze.origin_x, freeze.length, "Freeze endpoint matches live geometry rather than old nominal length")
	var hail := _reaction(323)
	var origin := Vector2i(hail.position_x, hail.position_y)
	check(Chemistry.contains(hail, origin + Vector2i(31250, 0), hail.active_tick, config), "Hail pulse includes its enlarged31.25px edge")
	check(not Chemistry.contains(hail, origin + Vector2i(31251, 0), hail.active_tick, config), "Hail pulse excludes even one fixed unit beyond its true edge")
	var ring := _reaction(309)
	check(not Chemistry.contains(ring, origin + Vector2i(29999, 0), ring.active_tick, config), "enlarged ring preserves a proportionately larger safe center")
	check(Chemistry.contains(ring, origin + Vector2i(90000, 0), ring.active_tick, config), "enlarged ring contains its outer edge")
	check(not Chemistry.contains(ring, origin + Vector2i(90001, 0), ring.active_tick, config), "enlarged ring never hits outside visible area")
	var mud := _reaction(303)
	check(Chemistry.contains(mud, origin + Vector2i(77500, 0), mud.active_tick, config), "larger disks affect the newly added footprint")
	check(not Chemistry.contains(mud, origin + Vector2i(77501, 0), mud.active_tick, config), "larger disks retain exact authoritative boundary")
	var bad_result := _reaction(314).canonical_values()
	bad_result[14] = Reaction.MAX_RADIUS + 1
	check(Reaction.from_values(bad_result) == null, "reaction radius retains strict upper wire bound")
	bad_result = _reaction(328).canonical_values()
	bad_result[15] = Reaction.MAX_LENGTH + 1
	check(Reaction.from_values(bad_result) == null, "linked reaction reach retains strict upper wire bound")
	equal(Chemistry.MAX_DEPOSITS, 128, "enlarged areas do not increase global material count")
	equal(Chemistry.MAX_REACTIONS, 32, "enlarged areas do not increase concurrent result budget")

func _deposit(id: int,element: int,at: Vector2i = Vector2i(500000,500000),cast_id: int = -1) -> ElementDepositState:
	var deposits: Array = []
	equal(Chemistry.deposit_terminal(deposits,id,id if cast_id < 0 else cast_id,100,1,1,element,at,0,config),1,"paid terminal produces finite material")
	return deposits[0]

func _reaction(wire: int) -> ElementReactionState:
	var pair: Array = Chemistry.recipe(wire)["elements"]
	return Chemistry.form_reaction(_deposit(1,int(pair[0])),_deposit(2,int(pair[1])),4000,0,config)

func _actor(at: Vector2i = Vector2i(500000,500000)) -> PlayerState:
	var actor := PlayerState.new(2)
	actor.team_id = 2
	actor.position_x = at.x
	actor.position_y = at.y
	return actor

func _apply(result: ElementReactionState,actor: PlayerState,tick: int,others: Array = [],deposits: Array = []) -> void:
	var reactions: Array = [result]
	reactions.append_array(others)
	var events: Array = []
	Chemistry.step(deposits,reactions,[actor],null,config,tick,5000,events)

func _test_deposits() -> void:
	for element: int in range(1,9):
		var deposit := _deposit(element,element)
		check(deposit.validate(),"all eight deposit states validate")
		equal(deposit.expiry_tick,config.milliseconds_to_ticks(Chemistry.ELEMENT_LIFE_MS[element]),"element owns its 3-5 second lifetime")
		var decoded := Deposit.from_values(deposit.canonical_values())
		check(decoded != null,"deposit roundtrip validates")
		equal(decoded.canonical_values(),deposit.canonical_values(),"every deposit field survives roundtrip")
		var deposits: Array = [deposit]
		var original := deposit.canonical_values()
		equal(Chemistry.deposit_terminal(deposits,100,element,100,1,1,element,Vector2i(500001,500001),100,config),0,"same cast/cell coalesces")
		equal(deposit.canonical_values(),original,"repeated contact never refreshes strength or expiry")
		var reactions: Array = []
		var events: Array = []
		Chemistry.step(deposits,reactions,[],null,config,deposit.expiry_tick,4000,events)
		check(deposits.is_empty(),"deposit expires at its exact deadline")
	check(Deposit.from_values(PackedInt64Array([1,2])) == null,"short malformed deposit refuses")
	var corrupt := _deposit(9,1).canonical_values()
	corrupt[5] = 12
	check(Deposit.from_values(corrupt) == null,"deferred element cannot arrive through network")

func _test_pairs() -> void:
	var seen := {}
	for wire: int in range(301,337):
		var definition := Chemistry.recipe(wire)
		var pair: Array = definition["elements"]
		equal(Chemistry.recipe_wire(int(pair[0]),int(pair[1])),wire,"forward pair maps to stable wire")
		equal(Chemistry.recipe_wire(int(pair[1]),int(pair[0])),wire,"all 36 pairs are symmetric")
		check(not seen.has(definition["id"]),"each recipe has a unique decision identity")
		seen[definition["id"]] = true
		var deposits: Array = [_deposit(1,int(pair[0])),_deposit(2,int(pair[1]))]
		var reactions: Array = []
		var events: Array = []
		equal(Chemistry.step(deposits,reactions,[],null,config,0,4000,events),4001,"one finite pair admits one result")
		equal(reactions.size(),1,"pair result is persistent simulation state")
		equal(deposits.size(),0,"both strengths are consumed exactly once")
		var result: ElementReactionState = reactions[0]
		check(result.validate(),"all 36 reaction states validate")
		check(not result.active(0) and result.active(result.active_tick),"formation precedes active effects")
		var decoded := Reaction.from_values(result.canonical_values())
		check(decoded != null,"every recipe canonical state decodes")
		if decoded != null:
			equal(decoded.canonical_values(),result.canonical_values(),"reaction roundtrip is exact")
		Chemistry.step(deposits,reactions,[],null,config,result.expiry_tick,4001,events)
		check(reactions.is_empty(),"every recipe has finite cleanup")
	equal(seen.size(),36,"first-grade upper triangle is complete")

func _test_effects() -> void:
	var actor := _actor()
	var mud := _reaction(303)
	_apply(mud,actor,mud.active_tick)
	equal(actor.slow_ratio,700,"Mud applies proportional grounded slow")
	actor = _actor()
	actor.air_height = 20000
	_apply(_reaction(303),actor,mud.active_tick)
	equal(actor.control_state,PlayerState.ControlState.FREE,"airborne actors clear Mud")
	var blight := _reaction(308)
	actor = _actor()
	_apply(blight,actor,blight.active_tick)
	equal(actor.chemistry_regen_block_ticks,2,"Blightsoil suppresses occupied recovery")
	for wire: int in [304,310,315,317,321,326,333,336]:
		var veil := _reaction(wire)
		actor = _actor()
		_apply(veil,actor,veil.active_tick)
		check(actor.chemistry_conceal_ticks > 0,"%s owns concealment" % Chemistry.recipe(wire)["id"])
		check(Chemistry.blocks_sight(Vector2i(350000,500000),Vector2i(650000,500000),[veil],veil.active_tick),"%s blocks distant sight" % Chemistry.recipe(wire)["id"])
	var steam := _reaction(310)
	_apply(steam,_actor(),steam.active_tick)
	var early := steam.radius
	_apply(steam,_actor(),steam.active_tick+100)
	check(steam.radius > early,"Steam expands radially")
	check(not Chemistry.blocks_sight(Vector2i(350000,500000),Vector2i(650000,500000),[steam],steam.decay_tick-1),"Steam thins before expiry")
	for wire: int in [314,320,321,330,332,334,335,336]:
		var reveal := _reaction(wire)
		actor = _actor()
		actor.velocity_x = 10000
		_apply(reveal,actor,reveal.active_tick)
		check(actor.chemistry_reveal_ticks > 0,"%s executes reveal" % Chemistry.recipe(wire)["id"])
	for wire: int in [304,316,322]:
		var flow := _reaction(wire)
		actor = _actor(Vector2i(550000,500000) if wire in [322,331] else Vector2i(500000,500000))
		var before := Vector2i(actor.position_x,actor.position_y)
		_apply(flow,actor,flow.active_tick)
		check(Vector2i(actor.position_x,actor.position_y) != before,"%s physically displaces grounded actors" % Chemistry.recipe(wire)["id"])
	var vortex := _reaction(322)
	actor = _actor()
	_apply(vortex,actor,vortex.active_tick)
	equal(Vector2i(actor.position_x,actor.position_y),Vector2i(500000,500000),"Vortex has a safe center")
	for wire: int in [302,309,311,323,324]:
		var hazard := _reaction(wire)
		actor = _actor(Vector2i(550000,500000) if wire == 309 else Vector2i(500000,500000))
		_apply(hazard,actor,hazard.active_tick)
		check(actor.health < actor.health_maximum,"%s executes damage" % Chemistry.recipe(wire)["id"])
	for wire: int in [315,336]:
		var delayed := _reaction(wire)
		actor = _actor()
		_apply(delayed,actor,delayed.active_tick)
		equal(actor.health,actor.health_maximum,"delayed attrition gives time to leave")
		_apply(delayed,actor,delayed.active_tick+180)
		check(actor.health < actor.health_maximum,"remaining inside eventually deals damage")
	var freeze := _reaction(318)
	actor = _actor()
	_apply(freeze,actor,freeze.active_tick)
	check(actor.control_ticks > 0,"Freeze slows crossing")
	var initial_length := freeze.length
	_apply(freeze,_actor(),freeze.active_tick+120)
	check(freeze.length > initial_length,"Freeze grows its strip")
	var black_ice := _reaction(330)
	actor = _actor()
	_apply(black_ice,actor,black_ice.active_tick)
	equal(actor.control_state,PlayerState.ControlState.FREE,"Black Ice warns before slowing")
	_apply(black_ice,actor,black_ice.active_tick+50)
	check(actor.control_ticks > 0,"Black Ice slow is delayed")
	var fracture := _reaction(312)
	var cover := _reaction(305)
	cover.active_tick = 1
	var health_before := cover.health
	_apply(fracture,_actor(),fracture.active_tick,[cover])
	check(cover.health < health_before,"Thermal Shock damages temporary cover")

func _test_optics() -> void:
	for wire: int in [301,305]:
		var cover := _reaction(wire)
		var projectile := ProjectileState.new(100,2,2,100,2,Vector2i(510000,500000),Vector2i(500000,0),4000,10,50)
		projectile.previous_x = 490000
		check(bool(Chemistry.projectile_interaction(projectile,[cover],null,config,cover.active_tick)["blocked"]),"%s intercepts projectiles" % Chemistry.recipe(wire)["id"])
		equal(cover.health,int(Chemistry.recipe(wire)["health"])-10,"cover HP is finite")
	for wire: int in [307,325,329]:
		var optical := _reaction(wire)
		var projectile := ProjectileState.new(100,2,2,100,7,Vector2i(510000,500000),Vector2i(500000,0),4000,11,50)
		projectile.previous_x = 490000
		var response := Chemistry.projectile_interaction(projectile,[optical],null,config,optical.active_tick,1)
		check(bool(response["reflected"]) if wire == 307 else bool(response["bent"]),"%s transforms velocity" % Chemistry.recipe(wire)["id"])
		if wire == 329:
			equal(projectile.damage+int(response["split_damage"]),11,"Lens preserves damage budget")
			check((response["split_velocity"] as Vector2i).y < 0 and projectile.velocity_y > 0,"Lens produces two paths")
		var velocity := Vector2i(projectile.velocity_x,projectile.velocity_y)
		Chemistry.projectile_interaction(projectile,[optical],null,config,optical.active_tick,1)
		equal(Vector2i(projectile.velocity_x,projectile.velocity_y),velocity,"optical mask prevents repeated transforms")
		var ray := Chemistry.ray_interaction(Vector2i(400000,500000),Vector2i(650000,500000),7,11,[optical],optical.active_tick)
		check(bool(ray["transformed"]),"immediate beams use same optical primitive")
		equal((ray["rays"] as Array).size(),2 if wire == 329 else 1,"ray fanout bounded")
	var node := _reaction(306)
	var charge := ProjectileState.new(100,2,2,100,6,Vector2i(510000,500000),Vector2i(500000,0),4000,12000,50)
	charge.previous_x = 490000
	check(bool(Chemistry.projectile_interaction(charge,[node],null,config,node.active_tick)["blocked"]) and node.capacity == 24000,"Grounding Network stores bounded incoming charge")
	var bend := _reaction(325)
	var farther_cover := _reaction(301)
	farther_cover.position_x = 600000
	farther_cover.origin_x = 600000
	var bypass := Chemistry.ray_interaction(Vector2i(400000,500000),Vector2i(750000,500000),2,1000,[bend,farther_cover],maxi(bend.active_tick,farther_cover.active_tick))
	check(bool(bypass["blocked"]),"ineligible Lightbend cannot hide farther cover from a Fire beam")
	var prism := _reaction(307)
	var fire := ProjectileState.new(200,2,2,100,2,Vector2i(510000,500000),Vector2i(500000,0),4000,12000,50)
	fire.previous_x = 490000
	check(bool(Chemistry.projectile_interaction(fire,[prism],null,config,prism.active_tick)["reflected"]),"Prism reflects non-Light projectiles as well")
	var narrow := _reaction(317)
	check(Chemistry.blocks_sight(Vector2i(613000,50000),Vector2i(613000,950000),[narrow],narrow.active_tick),"long sight line cannot skip a narrow mist corridor between samples")

func _test_connectivity() -> void:
	for wire: int in [313,319,328]:
		var result := _reaction(wire)
		var element := 6 if wire == 313 else 3 if wire == 319 else 5
		var deposits: Array = [_deposit(10,element,Vector2i(610000,500000))]
		Chemistry._build_path(result,deposits,null)
		equal(result.linked_deposit_ids.size(),1,"conduction preview uses real connected material")
		var actor := _actor(Vector2i(570000,500000))
		_apply(result,actor,result.active_tick,[],deposits)
		check(actor.health < actor.health_maximum,"conduction hits its connected path")
		result.pulse_index = -1
		actor = _actor(Vector2i(570000,500000))
		_apply(result,actor,result.active_tick+1)
		equal(actor.health,actor.health_maximum,"broken connectivity prevents discharge")
	var veil := _reaction(310)
	var wall := CollisionWorld.new(1000000,1000000)
	wall.add_obstacle(CollisionWorld.Obstacle.new(1,520000,0,540000,1000000))
	var actor := _actor(Vector2i(550000,500000))
	var events: Array = []
	Chemistry.step([],[veil],[actor],wall,config,veil.active_tick+90,5000,events)
	equal(actor.chemistry_conceal_ticks,0,"worldbone prevents effect reach")

func _test_capacity_and_replay() -> void:
	var deposits: Array = [_deposit(1,2,Vector2i(500000,500000),7),_deposit(2,2,Vector2i(530000,500000),7)]
	var reactions: Array = []
	var events: Array = []
	Chemistry.step(deposits,reactions,[],null,config,0,4000,events)
	check(reactions.is_empty() and deposits.size() == 2,"Burst siblings cannot self-react")
	deposits = [_deposit(1,2),_deposit(2,3)]
	for index: int in range(32):
		var result := _reaction(310)
		result.entity_id += index
		result.origin_x += index*100000
		reactions.append(result)
	Chemistry.step(deposits,reactions,[],null,config,0,5000,events)
	equal(deposits.size(),2,"full reaction capacity preserves paid inputs")
	equal(reactions.size(),32,"reaction capacity hard bound")
	var crowded: Array = []
	for index: int in range(16):
		equal(Chemistry.deposit_terminal(crowded,index+1,index+1,100,1,1,1,Vector2i(500000+index*100000,500000),0,config),1,"owner may fill reserved slots")
	equal(Chemistry.deposit_terminal(crowded,17,17,100,1,1,1,Vector2i(2500000,500000),0,config),-1,"per-owner admission refuses overflow")
	var left: Array = [_deposit(1,2),_deposit(2,3),_deposit(3,1)]
	var right: Array = [left[2],left[1],left[0]]
	for index: int in range(right.size()):
		right[index] = Deposit.from_values(right[index].canonical_values())
	var a: Array = []
	var b: Array = []
	var events_a: Array = []
	var events_b: Array = []
	Chemistry.step(left,a,[],null,config,0,4000,events_a)
	Chemistry.step(right,b,[],null,config,0,4000,events_b)
	equal(a[0].canonical_values(),b[0].canonical_values(),"third-source resolution uses stable IDs")
	equal(events_a,events_b,"formation events are deterministic")
	var result: ElementReactionState = a[0]
	result.source_a = 2_147_483_648
	check(not result.validate(),"hostile source IDs fail before int32 conversion")

func _test_archived_beam_routing() -> void:
	# Preserve optical geometry coverage without admitting a retired Beam.
	var catalogue := AbilityCatalog.new()
	check(catalogue.load_from_file(CombatDefinitionTable.CATALOG_PATH), "archive optics catalogue loads")
	var definition := CombatDefinitionTable.new()._compile_definition(catalogue.ability_from_wire(143), catalogue)
	check(CombatTuning.cast_definition(143).is_empty(), "archive fixture does not restore live Beam admission")
	var world := CollisionWorld.new(1400000,1000000)
	var owner := PlayerState.new(1)
	owner.position_x = 400000
	owner.position_y = 500000
	var lens := _reaction(329)
	var target_a := _actor(Vector2i(620000,537000))
	var target_b := _actor(Vector2i(620000,463000))
	target_b.entity_id = 3
	var actors: Array[PlayerState] = [owner,target_a,target_b]
	var events: Array[Dictionary] = []
	check(CombatSystem._resolve_chemistry_beam(owner, 143, definition, Vector2i(400000,500000), Vector2i(900000,500000), actors,config,world,events,[lens],lens.active_tick), "archived Beam optical resolver handles Lens")
	var fired := 0
	var shifted_origin := false
	for event: Dictionary in events:
		if String(event.get("type","")) == "beam_fired":
			fired += 1
			shifted_origin = shifted_origin or int(event.get("origin_x",0)) > 400000
	equal(fired,3,"Lens displays approach plus two real outgoing segments")
	check(shifted_origin,"split visuals start at the actual lens rather than owner feet")
	check(target_a.health < target_a.health_maximum and target_b.health < target_b.health_maximum,"real Beam traces hit both split paths")
	var total_damage := target_a.health_maximum-target_a.health+target_b.health_maximum-target_b.health
	check(total_damage <= int(definition["damage"]),"archived Beam split preserves the original total damage budget")
	var cover := _reaction(301)
	var behind := _actor(Vector2i(600000,500000))
	events = []
	check(CombatSystem._resolve_chemistry_beam(owner, 143, definition, Vector2i(400000,500000), Vector2i(900000,500000), [owner,behind],config,world,events,[cover],cover.active_tick), "archived Beam optical resolver handles cover")
	equal(behind.health,behind.health_maximum,"temporary cover intercepts an actual instant Beam")
	check(cover.health < int(Chemistry.recipe(301)["health"]),"actual Beam damages cover")
	var cover_health := cover.health
	events = [{"type":"beam_requested","owner_id":1,"source_wire_id":143,"origin_x":400000,"origin_y":500000,"aim_x":1000,"aim_y":0}]
	CombatSystem.resolve_instant_casts([owner,behind],config,world,events,[cover],cover.active_tick)
	check(events.is_empty(), "live instant resolution discards an injected retired Beam request")
	equal(cover.health, cover_health, "disabled Beam cannot damage persistent cover")

func _test_cover_lifecycle_edges() -> void:
	for phase: String in ["forming", "active", "decaying"]:
		var fracture := _reaction(312)
		var cover := _reaction(305)
		if phase == "forming":
			cover.active_tick = fracture.active_tick + 1
		elif phase == "decaying":
			cover.decay_tick = fracture.active_tick
		var before := cover.health
		_apply(fracture, _actor(), fracture.active_tick, [cover])
		equal(cover.health, 0 if phase == "active" else before, "Thermal Shock damages active cover only: %s" % phase)
		check(cover.validate(), "fracture never moves cover decay before formation: %s" % phase)
		check(Reaction.from_values(cover.canonical_values()) != null, "fractured cover remains snapshot-decodable: %s" % phase)
	for incoming: int in [4000, 5000, 12000, 30000]:
		var node := _reaction(306)
		node.capacity = 5000
		var beam_node := Reaction.from_values(node.canonical_values())
		var shot := ProjectileState.new(100, 2, 2, 100, 6, Vector2i(510000, 500000), Vector2i(500000, 0), 4000, incoming, 50)
		shot.previous_x = 490000
		var response := Chemistry.projectile_interaction(shot, [node], null, config, node.active_tick)
		check(bool(response["blocked"]), "Grounding Network stops Charge at below/exact/over capacity: %d" % incoming)
		equal(node.capacity, maxi(0, 5000-incoming), "node capacity absorbs only the available charge")
		equal(node.health, maxi(0, 16000-maxi(0, incoming-5000)), "only residual charge damages finite node health")
		var beam := Chemistry.ray_interaction(Vector2i(490000, 500000), Vector2i(510000, 500000), 6, incoming, [beam_node], node.active_tick)
		equal(response["blocked"], beam["blocked"], "Charge projectile and beam agree on cover interception")
		equal(node.canonical_values(), beam_node.canonical_values(), "Charge projectile and beam spend identical node budgets")
		check(node.validate(), "over-capacity node destruction preserves valid state")
		if node.health == 0:
			equal(node.decay_tick, node.active_tick, "broken active node enters decay immediately")
			var later := ProjectileState.new(101, 2, 2, 100, 6, Vector2i(510000, 500000), Vector2i(500000, 0), 4000, 1000, 50)
			later.previous_x = 490000
			check(not bool(Chemistry.projectile_interaction(later, [node], null, config, node.active_tick)["blocked"]), "destroyed node cannot block the next projectile")

func _test_all_reaction_boundaries_and_replay() -> void:
	for wire: int in range(301, 337):
		var original := _reaction(wire)
		for boundary: int in [original.active_tick-1, original.decay_tick, original.expiry_tick]:
			var result := Reaction.from_values(original.canonical_values())
			var actor := _actor()
			var before := actor.canonical_values()
			var reactions: Array = [result]
			var events: Array = []
			Chemistry.step([], reactions, [actor], null, config, boundary, 5000, events)
			equal(actor.canonical_values(), before, "%s has no actor effect outside active phase at %d" % [Chemistry.recipe(wire)["id"], boundary])
			check(events.is_empty(), "inactive reaction cannot emit an effect event")
			equal(reactions.is_empty(), boundary == original.expiry_tick, "expiry removes state at the exact deadline")
		var left := Reaction.from_values(original.canonical_values())
		var right := Reaction.from_values(original.canonical_values())
		var left_actor := _actor(Vector2i(550000, 500000) if wire in [309, 322] else Vector2i(500000, 500000))
		var right_actor := _actor(Vector2i(left_actor.position_x, left_actor.position_y))
		for tick: int in [original.active_tick, original.active_tick+1, original.decay_tick-1]:
			var left_events: Array = []
			var right_events: Array = []
			Chemistry.step([], [left], [left_actor], null, config, tick, 5000, left_events)
			# Replay starts from serialized authoritative state, not shared objects.
			right = Reaction.from_values(right.canonical_values())
			Chemistry.step([], [right], [right_actor], null, config, tick, 5000, right_events)
			equal(left.canonical_values(), right.canonical_values(), "all36 reaction clocks/contacts replay exactly")
			equal(left_actor.canonical_values(), right_actor.canonical_values(), "all36 actor outcomes replay exactly")
			equal(left_events, right_events, "all36 effect events replay exactly")
			check(left.validate(), "all36 active states remain network-valid")

func _test_link_expiry_and_pulse_windows() -> void:
	for wire: int in [313, 319, 328]:
		var result := _reaction(wire)
		var material := 6 if wire == 313 else 3 if wire == 319 else 5
		var link := _deposit(10, material, Vector2i(610000, 500000))
		link.expiry_tick = result.active_tick + 1
		var deposits: Array = [link]
		Chemistry._build_path(result, deposits, null)
		var actor := _actor(Vector2i(570000, 500000))
		_apply(result, actor, result.active_tick, [], deposits)
		check(actor.health < actor.health_maximum, "live conductor supplies the initial discharge")
		result.pulse_index = -1
		actor = _actor(Vector2i(570000, 500000))
		_apply(result, actor, link.expiry_tick, [], deposits)
		check(deposits.is_empty(), "expired conductor is removed before reaction effects")
		equal(actor.health, actor.health_maximum, "expired link cannot supply a same-tick discharge")
	var ring := _reaction(309)
	var target := _actor(Vector2i(550000, 500000))
	var period := config.milliseconds_to_ticks(int(Chemistry.recipe(309)["pulse_ms"]))
	_apply(ring, target, ring.active_tick)
	var first_health := target.health
	_apply(ring, target, ring.active_tick)
	_apply(ring, target, ring.active_tick+period-1)
	# Repeating a tick/occupancy check inside the same pulse cannot add damage.
	equal(target.health, first_health, "one damage application per pulse window")
	_apply(ring, target, ring.active_tick+period)
	equal(target.health, first_health-8000, "next pulse deals exactly its authored 8 HP")
	var final_health := target.health
	_apply(ring, target, ring.decay_tick)
	equal(target.health, final_health, "decay boundary never grants a final hidden damage pulse")

func _test_entry_bounds_edges() -> void:
	var cover := _reaction(301)
	var tangent := Vector2i(cover.position_x+cover.radius, cover.position_y)
	check(Chemistry._entry_bounds_overlap(cover,tangent,tangent), "broadphase retains a capsule tangent")
	equal(Chemistry._entry_point(cover,tangent,tangent,cover.active_tick,config), {"hit":true,"point":tangent}, "zero-length tangent preserves exact contact")
	var outside := tangent+Vector2i(1,0)
	check(not Chemistry._entry_bounds_overlap(cover,outside,outside), "strictly separated capsule is rejected")
	equal(Chemistry._entry_point(cover,outside,outside,cover.active_tick,config), {"hit":false,"point":outside}, "miss returns the supplied endpoint")
	# Permafrost retains the generic capsule; Rampart uses its shared rectangle.
	cover = _reaction(305)
	cover.position_x = -700001
	cover.position_y = -800003
	cover.length = 80003
	cover.direction_x = -731
	cover.direction_y = 317
	var side := Chemistry.scaled(Vector2i(-cover.direction_y,cover.direction_x),cover.length/2)
	var tip := Vector2i(cover.position_x,cover.position_y)+side
	check(Chemistry._entry_bounds_overlap(cover,tip,tip), "mutated negative center and odd-length angled capsule use fresh bounds")
	check(bool(Chemistry._entry_point(cover,tip,tip,cover.active_tick,config)["hit"]), "signed truncation keeps the actual capsule tip")
	for wire: int in [313,319,328]:
		var linked := _reaction(wire)
		linked.path_points = PackedInt64Array([500000,500000,700000,650000,740000,450000])
		var far_tip := Vector2i(740000,450000)
		check(Chemistry._entry_bounds_overlap(linked,far_tip,far_tip), "linked geometry falls through without an extra array scan")
		check(bool(Chemistry._entry_point(linked,far_tip,far_tip,linked.active_tick,config)["hit"]), "remote linked endpoint cannot be falsely culled")
	var hail := _reaction(323)
	var lane_end := Vector2i(hail.endpoint_x,hail.endpoint_y)
	check(Chemistry._entry_bounds_overlap(hail,lane_end,lane_end), "moving pulse uses the conservative whole-lane envelope")
	var prism := _reaction(307)
	var approach := Chemistry.ray_interaction(Vector2i(450000,500000),Vector2i(580000,500000),7,9001,[prism],prism.active_tick)
	check(bool(approach["transformed"]), "guard retains actual prism approach")
	var reflected: Dictionary = approach["rays"][0]
	var continuation := Chemistry.ray_interaction(reflected["origin"],reflected["end"],7,9001,[prism],prism.active_tick,int(approach["interaction_mask"]))
	check(not bool(continuation["transformed"]), "reflected continuation preserves interaction-mask behavior")
