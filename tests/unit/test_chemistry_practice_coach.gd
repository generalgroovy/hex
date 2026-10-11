extends FluxTestSuite

# Current paid Hex fixtures. The full prior two-source suite is preserved in
# .godot/reference-refinement-baseline/live-hex-coach, not relabelled as live63.
const Coach = preload("res://src/presentation/chemistry_practice_coach.gd")
const Guide = preload("res://src/presentation/chemistry_guide_model.gd")
const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const Card = preload("res://src/presentation/practice_coach_card.gd")
const CENTER := Vector2i(800000, 800000)
const BOUNDS := [0, 0, 2000, 2000]
var config := SimConfig.new(120)
var catalog := AbilityCatalog.new()

func run() -> int:
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "live coach uses current abilities")
	equal(Guide.matrix_cell(0, 0).name, "Frostway", "Water self-pair teaches derived frozen result")
	check(5 not in Guide.DISPLAY_WIRES and 6 not in Guide.DISPLAY_WIRES, "retired elements cannot become selectable coach ingredients")
	_test_scope_and_matter()
	_test_fire_ground_phases()
	_test_every_current_product()
	_test_selection_and_pool()
	_test_actual_campus_scope()
	return finish("chemistry-practice-coach")

func _test_scope_and_matter() -> void:
	var world := _world()
	var before := world.state_hash()
	equal(_sample(world, 0).kind, "invitation", "empty active court invites a paid combination")
	for args: Array in [[0,CENTER,0,BOUNDS,true],[1,CENTER,-1,BOUNDS,true],[1,CENTER,0,BOUNDS,false],[1,Vector2i(-1,0),0,BOUNDS,true],[1,CENTER,0,[0,0,0,20],true],[1,CENTER,0,[0,0,2.5,20],true],[1,CENTER,0,[0,0,INF,20],true],[1,CENTER,0,[0,0,20],true]]:
		check(Coach.sample_hex(args[0],args[1],args[2],config,args[3],world,args[4]).is_empty(), "invalid/outside/disallowed coach context refuses")
	check(Coach.sample_hex(1,CENTER,0,null,BOUNDS,world).is_empty(), "missing clock refuses")
	check(Coach.sample_hex(1,CENTER,0,config,BOUNDS,null).is_empty(), "missing world refuses")
	equal(world.state_hash(),before,"all empty/gating observations are read-only")
	world.chemistry_enabled=false
	check(_sample(world,0).is_empty(),"disabled chemistry is not advertised")
	world.chemistry_enabled=true
	_deposit(world,1,3,CENTER,1)
	var record: Dictionary=world.casts.values()[0]
	var part: Dictionary=record.ground_parts.values()[0]
	before=world.state_hash()
	var matter := _sample(world,1)
	equal(matter.kind,"matter","actual paid terminal matter is visible")
	equal(matter.title,"WATER MATTER","canonical display comes from active element")
	equal(matter.quantity,int(part.quantity),"matter quantity is current finite stock")
	equal(matter.remaining_ticks,int(part.expiry_tick)-1,"matter expiry is exact")
	equal(_sample(world,0).kind,"invitation","future matter is hidden")
	equal(_sample(world,int(part.expiry_tick)).kind,"invitation","expired matter disappears immediately")
	equal(Coach.sample_hex(2,CENTER,1,config,BOUNDS,world).kind,"invitation","another actor's matter is not local coaching")
	equal(world.state_hash(),before,"matter queries cannot spend/replenish/refresh source")
	record.paid=false
	equal(_sample(world,1).kind,"invitation","unpaid fixture cannot claim paid matter")
	record.paid=true
	_fit_checks(matter)

func _test_fire_ground_phases() -> void:
	var world := _world()
	_deposit(world,1,2,CENTER,1)
	var record: Dictionary=world.casts.values()[0]
	var part: Dictionary=record.ground_parts.values()[0]
	var ignition := int(part.created)+HexChemistryWorld.IGNITION_TICKS
	var cooling := int(part.expiry_tick)-HexChemistryWorld.COOLING_TICKS
	var before := world.state_hash()
	check(String(_sample(world,ignition-1).phase).begins_with("IGNITING"),"Fire matter cannot advertise early damage")
	check(String(_sample(world,ignition).phase).begins_with("ACTIVE FIRE"),"actual Fire part ignition starts grounded pressure")
	check(String(_sample(world,cooling-1).phase).begins_with("ACTIVE FIRE"),"last damaging Fire tick stays visible")
	check(String(_sample(world,cooling).phase).begins_with("COOLING"),"Fire cooling immediately removes damage promise")
	check(String(_sample(world,ignition).lines[0]).contains("burns grounded actors"),"plain Fire matter is not mislabeled harmless")
	equal(_sample(world,cooling).remaining_ticks,int(part.expiry_tick)-cooling,"cooling countdown retains actual part expiry")
	equal(world.state_hash(),before,"Fire phase sampling is read-only")
	_fit_checks(_sample(world,ignition))

func _test_every_current_product() -> void:
	var seen := {}
	for wire: int in Policy.active_wire_ids():
		var definition := Policy.definition(wire)
		var fixture := _form(definition.elements)
		var world: HexChemistryWorld=fixture.world
		var product: Dictionary=fixture.product
		if product.is_empty(): continue
		var before := world.state_hash()
		for tick: int in [int(product.created),int(product.active_tick)-1,int(product.active_tick),int(product.decay_tick)-1,int(product.decay_tick),int(product.expiry_tick)-1]:
			var view := _sample(world,tick)
			equal(view.kind,"reaction","%d observes real product through all live phases" % wire)
			equal(view.recipe_wire_id,wire,"%d selected recipe is exact" % wire)
			equal(view.purpose,definition.purpose,"%d full purpose projects current source" % wire)
			equal(view.counter,definition.counter,"%d full counter projects current source" % wire)
			equal(view.damage_budget_remaining,product.damage_budget_remaining,"%d shared pool is observed exactly" % wire)
			var end_tick := int(product.active_tick) if tick<int(product.active_tick) else int(product.decay_tick) if tick<int(product.decay_tick) else int(product.expiry_tick)
			equal(view.remaining_ticks,end_tick-tick,"%d countdown follows actual phase" % wire)
			if tick<int(product.active_tick): check(String(view.phase).begins_with("FORMING"),"warning begins before effects")
			elif tick>=int(product.decay_tick): check(String(view.phase).begins_with("HARMLESS DECAY"),"decay does not promise active damage")
			else: check(String(view.phase).begins_with("ACTIVE"),"active phase begins at exact accepted tick")
			_fit_checks(view)
			var compact := Card.model(view,Vector2(1280,720),Vector2.ZERO)
			equal(compact.lines[0],view.lines[1],"compact card prioritizes actual effect")
			var expanded := Card.model(view,Vector2(1280,720),Vector2(850,100))
			equal(expanded.lines.size(),3,"expanded card retains ingredient/effect/counter hierarchy")
		equal(_sample(world,int(product.expiry_tick)).kind,"invitation","expired product cannot linger")
		equal(world.state_hash(),before,"%d repeated help never changes authority" % wire)
		seen[wire]=true
	equal(seen.size(),63,"every current self/pair/larger recipe has a funded coaching witness")

func _test_selection_and_pool() -> void:
	var fixture := _form([1,2,3,4,7,8])
	var world: HexChemistryWorld=fixture.world
	var product: Dictionary=fixture.product
	if product.is_empty(): return
	var tick := int(product.active_tick)
	product.damage_budget_remaining=0
	var before := world.state_hash()
	var view := _sample(world,tick)
	check(String(view.phase).begins_with("DAMAGE STOCK SPENT"),"depleted shared pool is visible")
	check(String(view.lines[1]).contains("situational effects may remain"),"spent damage does not invent universal control cancellation")
	equal(view.damage_budget_remaining,0,"zero damage pool remains zero")
	equal(world.state_hash(),before,"help cannot refill a spent product")
	product.owner=99
	equal(_sample(world,tick).kind,"invitation","foreign product is not local coaching")
	product.owner=1
	var coverage: Dictionary=product.coverage
	product.coverage={Vector2i(1000,1000):1}
	equal(_sample(world,tick).kind,"invitation","out-of-practice product does not occupy the card")
	product.coverage=coverage
	var older := product.duplicate(true)
	older.id=int(product.id)+1
	world.products[older.id]=older
	equal(_sample(world,tick).entity_id,older.id,"equal creation tick ties deterministically by product ID")
	older.created=int(product.created)-1
	equal(_sample(world,tick).entity_id,product.id,"newer product wins ahead of larger ID")
	older.created=tick+1
	equal(_sample(world,tick).entity_id,product.id,"future product cannot win selection")

func _test_actual_campus_scope() -> void:
	var campus := SanctumCampusLayout.new()
	check(campus.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"),"actual campus geometry loads")
	var group: Dictionary=campus.practice_groups_by_id["crucible-experiment"]
	var anchor: Array=group.firing_anchors[0]
	var point := Vector2i(int(anchor[0]),int(anchor[1]))*1000
	var world := _world()
	check(not Coach.sample_hex(1,point,0,config,group.bounds,world).is_empty(),"actual firing anchor enables contextual coach")
	check(Coach.sample_hex(1,Vector2i.ZERO,0,config,group.bounds,world).is_empty(),"outside real practice group stays silent")

func _fit_checks(view: Dictionary) -> void:
	check(ThemeDB.fallback_font.get_string_size(view.title,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x<=337.0,"title fits actual compact card font")
	check(view.lines.size()<=3,"card has bounded detail lines")
	for line: String in view.lines:
		check(ThemeDB.fallback_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x<=412.0,"visible details fit real font without silent clipping")

func _sample(world: HexChemistryWorld,tick: int) -> Dictionary:
	return Coach.sample_hex(1,CENTER,tick,config,BOUNDS,world)

func _world() -> HexChemistryWorld:
	var world := HexChemistryWorld.new()
	check(world.configure_geometry(CENTER,HexGrid.disk(Vector2i.ZERO,20)),"finite paid court configures")
	world.chemistry_enabled=true
	return world

func _form(elements: Array) -> Dictionary:
	var world := _world()
	for index: int in elements.size():
		var point := CENTER
		if not world.products.is_empty():
			var cells: Array=world.products.values()[0].coverage.keys()
			cells.sort_custom(HexGrid._cell_less)
			point=world.origin+HexGrid.center(cells[0])
		_deposit(world,index+1,int(elements[index]),point,index+1)
		world.sync_flights([],[])
	check(world.products.size()==1,"paid real terminals form one product")
	return {"world":world,"product":{} if world.products.is_empty() else world.products.values()[0]}

func _deposit(world: HexChemistryWorld,source: int,element: int,point: Vector2i,tick: int) -> void:
	var wire := int(catalog.ability(catalog.spell_id_at(Policy.ingredient_layer(element),"bolt")).wire_id)
	check(world.reserve_cast(source,wire),"source reserves before payment")
	world.commit_payment(source)
	world.bind_release(source,source,point,Vector2i(1000,0),1)
	var definition := CombatTuning.cast_definition(wire)
	world.deposit_terminal({"source_cast_id":source,"source_wire_id":wire,"owner_id":source,"team_id":1,"element_wire_id":element,"position":point,"direction":Vector2i(1000,0),"strength":1000,"reaction_strength":int(definition.reaction_strength)},tick)
