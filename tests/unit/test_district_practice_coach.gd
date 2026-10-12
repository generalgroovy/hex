extends FluxTestSuite

const Coach = preload("res://src/presentation/district_practice_coach.gd")
var layout := SanctumCampusLayout.new()
var abilities := AbilityCatalog.new()
var champions := ChampionCatalog.new()
var preferences := PlayerPreferences.new()
var route_trace: Array[String] = []


func run() -> int:
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"),"district routes use the admitted current map")
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"),"district route abilities load")
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json",abilities),"district routes use real champion movement")
	_test_real_routes()
	_test_guards_and_prompts()
	return finish("district-practice-coach")


func _course(id: String) -> Dictionary:
	for row: Dictionary in layout.data.movement_courses:
		if String(row.district)==id: return row
	return {}


func _world(course: Dictionary) -> SimWorld:
	var world := SimWorld.new(120,719,layout.build_collision_world())
	check(champions.apply_to_player(world.player(),"oh_tipi"),"route fixture applies a real nonflying champion")
	var point := SanctumCampusLayout._parse_point(course.contact)*SimConfig.FIXED_SCALE
	world.player().position_x = point.x
	world.player().position_y = point.y
	check(world.collision.can_occupy(point,MovementTuning.PLAYER_RADIUS),"route begins at its authored clear contact")
	return world


func _advance(world: SimWorld, coach: RefCounted, direction: Vector2i = Vector2i.ZERO, held: int = 0, pressed: int = 0) -> void:
	check(world.step([SimCommand.new(world.tick,1,direction.x,direction.y,held,pressed)]),"route advances through a normal full authority tick")
	var before := world.player().canonical_values()
	var old_step: int = coach.step
	var old_district: String = coach.district
	coach.observe(world,layout)
	if route_trace.size()<24 and (old_step!=coach.step or old_district!=coach.district):
		var actor := world.player()
		route_trace.append("t%d %s:%d -> %s:%d at %d,%d (%s)" % [world.tick,old_district,old_step,coach.district,coach.step,actor.position_x,actor.position_y,actor.last_event])
	equal(world.player().canonical_values(),before,"district observation never moves, refills or otherwise changes the actor")


func _test_real_routes() -> void:
	for id: String in Coach.KINDS:
		route_trace.clear()
		var course := _course(id)
		var world := _world(course)
		var coach := Coach.new()
		coach.observe(world,layout)
		equal(coach.district,id,"observer selects the actual district")
		equal(coach.view(world.player(),preferences).practice_kind,String(course.practice_kind),"live executable route agrees with frozen map metadata")
		var initial_stamina := world.player().stamina
		if id in ["tideglass-quays","basalt-foundry"]:
			# Run, paid tap Jump, then a fresh held Jump after its commitment.
			# Existing collision discovers the real wall; no contact/height injection.
			for tick: int in range(44):
				var held := SimCommand.HELD_SPRINT if tick<20 else (SimCommand.HELD_JUMP if tick>=31 and tick<43 else 0)
				var pressed := SimCommand.PRESSED_JUMP if tick==20 else 0
				var direction := Vector2i(1000,0)
				if tick==43: direction = Vector2i(0,1000)
				_advance(world,coach,direction,held,pressed)
			if id=="basalt-foundry":
				check(coach.step>=2,"foundry route requires a real wall entry and a different exit direction")
				var wall := SanctumCampusLayout._parse_bounds(layout.buildings_by_id[int(course.wall_id)].bounds)
				var clear_x := (wall.end.x+64)*1000
				var clear_y := (wall.position.y-64)*1000
				# The outward paid kick needs room to land; steering left through
				# its airborne carry can leave this district before touchdown.
				# Use the actual open floor, then the ordinary right-hand bypass.
				for unused: int in range(900):
					if coach.step>=3: break
					var actor := world.player()
					var direction := Vector2i.ZERO if actor.is_airborne() else (Vector2i(1000,0) if actor.position_x<clear_x else (Vector2i(0,-1000) if actor.position_y>clear_y else Vector2i.ZERO))
					_advance(world,coach,direction)
		elif id=="verdant-reaches":
			for unused: int in range(300):
				if coach.step>=3: break
				var direction := Vector2i.ZERO if coach.step==1 else Vector2i(1000,0)
				_advance(world,coach,direction,SimCommand.HELD_SPRINT if coach.step==0 else 0)
		else:
			for tick: int in range(420):
				if coach.step>=3: break
				var direction := Vector2i(1000,0) if tick<53 else Vector2i.ZERO
				var held := SimCommand.HELD_SPRINT if tick<40 else (SimCommand.HELD_JUMP if tick>=45 and tick<53 else 0)
				var pressed := SimCommand.PRESSED_SLIDE if tick==40 else (SimCommand.PRESSED_JUMP if tick==45 else 0)
				_advance(world,coach,direction,held,pressed)
		equal(coach.step,3,"ordinary accepted route completes its distinct three stages: "+id+"; "+" / ".join(route_trace))
		var view: Dictionary = coach.view(world.player(),preferences)
		check(bool(view.get("completed",false)) and String(view.get("phase","")).contains("optional"),"completion is optional practice feedback")
		var lines: PackedStringArray = view.get("lines",PackedStringArray())
		check(lines.size()>1 and String(lines[1]).contains("No refill or reward"),"practice never advertises an earned unlock or resource grant")
		check(world.player().stamina<=initial_stamina,"route never manufactures reserve beyond the real character maximum")


func _test_guards_and_prompts() -> void:
	var world := _world(_course("basalt-foundry"))
	var coach := Coach.new()
	coach.observe(world,layout)
	var actor := world.player()
	# Negative observation fixtures cannot earn anything: the observer is read
	# only and rejects an unrelated wall or stale repeated tick.
	actor.wall_skim_ticks = 12
	actor.wall_skim_surface_id = 301
	actor.velocity_x = 520000
	world.tick += 1
	coach.observe(world,layout)
	equal(coach.step,0,"wall contact in another course does not satisfy the foundry route")
	actor.wall_skim_surface_id = int(_course("basalt-foundry").wall_id)
	coach.observe(world,layout)
	equal(coach.step,0,"re-reading the same world tick cannot advance a second observation")
	world.tick += 1
	coach.observe(world,layout)
	equal(coach.step,1,"the actual named wall can advance once on a new tick")
	actor.position_x += 200000
	world.tick += 1
	coach.observe(world,layout)
	equal(coach.step,0,"a teleport restarts local route evidence")
	coach.observe(world,layout,false)
	check(coach.view(actor,preferences).is_empty(),"network or temporary-mode exclusion clears optional feedback")
	actor.wall_skim_ticks = 0
	coach.observe(world,layout)
	preferences.prompt_device = ControlBindingEditor.DEVICE_CONTROLLER
	preferences.controller_bindings[&"jump"] = {"kind":"button","index":2,"direction":0}
	check(String(coach.view(actor,preferences).lines[0]).contains("PAD X"),"district instructions follow the active controller's saved binding")
	preferences.controller_bindings.erase(&"jump")
	check(String(coach.view(actor,preferences).lines[0]).contains("unbound"),"missing controller binding remains explicit")
	preferences.prompt_device = ControlBindingEditor.DEVICE_KEYBOARD
	preferences.keyboard_bindings[&"jump"] = 0
	preferences.mouse_bindings[&"jump"] = MOUSE_BUTTON_WHEEL_UP
	check(String(coach.view(actor,preferences).lines[1]).contains("wheel pulse"),"hold lesson explains why a wheel pulse cannot sustain the required action")
	actor.health = 0
	world.tick += 1
	coach.observe(world,layout)
	check(coach.view(actor,preferences).is_empty(),"defeated actor cannot keep a completed route claim")
