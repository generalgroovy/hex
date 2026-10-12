extends FluxTestSuite
@warning_ignore_start("integer_division")

var abilities := AbilityCatalog.new()
var champions := ChampionCatalog.new()


func run() -> int:
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"),"route decisions load current spells")
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json",abilities),"route decisions use actual champion profiles")
	_test_open_braking()
	_test_wall_approach_release()
	_test_combat_reentry()
	return finish("movement-route-decisions")


func _test_open_braking() -> void:
	var outcomes := []
	for reverse: bool in [false,true]:
		var world := SimWorld.new(120,173,CollisionWorld.new(10000000,10000000))
		check(champions.apply_to_player(world.player(),"oh_tipi"),"paired brake starts from identical real body")
		var actor := world.player()
		actor.reset_for_spawn(Vector2i(5000000,5000000))
		for tick: int in range(60):
			check(world.step([SimCommand.new(world.tick,1,1000,0,SimCommand.HELD_SPRINT)]),"ordinary paid sprint builds the braking approach")
		var origin := actor.position_x
		var reserve := actor.stamina
		var stopped := false
		for tick: int in range(240):
			check(world.step([SimCommand.new(world.tick,1,-1000 if reverse else 0,0)]),"braking route uses current directional intent")
			if actor.velocity_x<=0:
				outcomes.append({"ticks":tick+1,"distance":actor.position_x-origin,"reserve":actor.stamina,"start_reserve":reserve})
				stopped = true
				break
		check(stopped,"both routes reach a real stop or reversal without an action grant")
		check(actor.stamina>=reserve,"ordinary braking itself spends no movement action reserve")
	if outcomes.size()==2:
		check(int(outcomes[1].ticks)<int(outcomes[0].ticks),"opposite input stops the same earned momentum sooner than release")
		check(int(outcomes[1].distance)<int(outcomes[0].distance),"earlier counter-braking reduces forward exposure rather than granting speed")


func _test_wall_approach_release() -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"),"wall route uses authored campus collision")
	var world := SimWorld.new(120,174,layout.build_collision_world(),String(layout.data.id),layout.content_hash)
	check(champions.apply_to_player(world.player(),"oh_tipi"),"wall route uses actual nonflying identity")
	var actor := world.player()
	actor.reset_for_spawn(Vector2i(400000,1790000))
	var reserve := actor.stamina
	check(world.step([SimCommand.new(world.tick,1,0,-1000,SimCommand.HELD_JUMP,SimCommand.PRESSED_JUMP)]),"normal grounded press begins wall approach")
	check(actor.jumpsquat_active,"approach first shows grounded anticipation")
	check(world.step([SimCommand.new(world.tick,1,0,-1000)]),"release pays normal jump")
	for unused: int in range(60):
		if actor.wall_contact_id==115 and actor.movement_commitment_ticks==0: break
		check(world.step([SimCommand.new(world.tick,1,0,-1000)]),"air steering reaches actual wall contact")
	equal(actor.wall_contact_id,115,"collision discovers the real wall without contact seeding")
	check(actor.is_airborne(),"wall approach retains real earned height")
	var run_cost := MovementSystem._movement_action_cost(actor,MovementTuning.WALL_SKIM_COST)
	var before := actor.stamina
	check(world.step([SimCommand.new(world.tick,1,1000,0,SimCommand.HELD_JUMP,SimCommand.PRESSED_JUMP)]),"fresh held tangent input requests wallrun")
	check(actor.wall_skim_ticks>0 and actor.wall_skim_surface_id==115,"ordinary paid route attaches to authored wall")
	equal(before-actor.stamina,run_cost,"real wallrun pays its current chain cost")
	for unused: int in range(60):
		if actor.movement_commitment_ticks==0: break
		check(world.step([SimCommand.new(world.tick,1,1000,0,SimCommand.HELD_JUMP)]),"held tangent stays on finite exposed wall")
	var jump_cost := MovementSystem._movement_action_cost(actor,MovementTuning.HOP_COST)
	before = actor.stamina
	check(world.step([SimCommand.new(world.tick,1,0,1000)]),"release chooses an outward exit")
	check(actor.wall_skim_ticks==0 and actor.is_airborne() and actor.velocity_y>0,"wall release actually changes the route into clear ground")
	equal(before-actor.stamina,jump_cost,"outward walljump pays another current chain cost")
	check(actor.stamina<reserve,"complete alternate route has a real finite reserve tradeoff")
	check(world.collision.can_occupy(Vector2i(actor.position_x,actor.position_y),MovementTuning.PLAYER_RADIUS),"wall exit remains collision safe")


func _test_combat_reentry() -> void:
	var evidence := []
	for paid_route: bool in [false,true]:
		var world := SimWorld.new()
		check(HexCourtPractice.configure(world,abilities),"combat route uses unified paid projectile and ground authority")
		for id: int in [1,2]:
			check(champions.apply_to_player(world.player(id),"oh_tipi"),"paired combat actors use real finite stats")
			world.player(id).actor_kind = PlayerState.ActorKind.CHAMPION
			world.player(id).team_id = id
		world.player().reset_for_spawn(Vector2i(450000,650000))
		world.player(2).reset_for_spawn(Vector2i(650000,350000))
		var bolt := MixtureCatalog.wire_for(16,"bolt")
		check(world.player(2).place_proven_spell(0,bolt),"opposition equips a real paid low projectile")
		var actor := world.player()
		var enemy_paid := 0
		var player_paid := 0
		var enemy_shots := 0
		var player_shots := 0
		var chain_seen := false
		var minimum_stamina := actor.stamina
		for tick: int in range(300):
			var enemy := world.player(2)
			var move := Vector2i(1000,0) if tick<55 else (Vector2i(0,-1000) if tick<105 else Vector2i.ZERO)
			var held := SimCommand.HELD_SPRINT if tick<40 else 0
			var pressed := 0
			if paid_route:
				pressed = SimCommand.PRESSED_SLIDE if tick==40 else (SimCommand.PRESSED_JUMP if tick==45 else (SimCommand.PRESSED_EVADE if tick==55 else 0))
			if tick==62: pressed |= SimCommand.PRESSED_SPELL_2
			var aim := Vector2i(enemy.position_x-actor.position_x,enemy.position_y-actor.position_y)
			var enemy_aim := -aim
			var enemy_press := SimCommand.PRESSED_SPELL_1 if tick in [0,120,240] else 0
			check(world.step([SimCommand.new(world.tick,1,move.x,move.y,held,pressed,aim.x,aim.y),SimCommand.new(world.tick,2,0,0,0,enemy_press,enemy_aim.x,enemy_aim.y)]),"both route choices advance complete commands under real paid opposition")
			chain_seen = chain_seen or actor.movement_chain_count>=3
			minimum_stamina = mini(minimum_stamina,actor.stamina)
			for event: Dictionary in world.combat_events:
				if String(event.get("type",""))=="cast_started":
					if int(event.get("entity_id",0))==1: player_paid += 1
					elif int(event.get("entity_id",0))==2: enemy_paid += 1
				elif String(event.get("type",""))=="projectile_spawned":
					if int(event.get("owner_id",0))==1: player_shots += 1
					elif int(event.get("owner_id",0))==2: enemy_shots += 1
		check(enemy_paid>0 and enemy_shots>0,"re-entry faces actual paid released pressure")
		check(player_paid>0 and player_shots>0,"movement route retains independent paid aiming and casting")
		equal(chain_seen,paid_route,"only the creative route buys the three-action chain")
		check(actor.stamina>=0 and actor.flux>=0,"route spends finite separate resources without underflow or mid-run grants")
		evidence.append({"minimum_stamina":minimum_stamina,"position":Vector2i(actor.position_x,actor.position_y),"health":actor.health})
	check(int(evidence[1].minimum_stamina)<int(evidence[0].minimum_stamina),"combat angle change trades more movement reserve than ordinary steering")
	check(evidence[1].position!=evidence[0].position,"choices produce different actual re-entry lanes; no universal winner is asserted")
