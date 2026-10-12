extends FluxTestSuite
## Actual paid flight and ordinary jump input. No protection, contact, health,
## resource, cast or lesson state is injected after the fresh scene is built.

func run() -> int:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"),"avoidance feedback loads paid spell definitions")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json",abilities),"avoidance feedback uses ordinary finite champion resources")
	for case: String in ["grounded","jump","blocked_jump","miss_jump"]:
		var world := SimWorld.new()
		check(HexCourtPractice.configure(world,abilities),"feedback uses the real ordered Hex projectile resolver")
		for id: int in [1,2]:
			check(champions.apply_to_player(world.player(id),"oh_tipi"),"paid feedback actor profile applies")
			world.player(id).actor_kind = PlayerState.ActorKind.CHAMPION
			world.player(id).team_id = id
		var player := world.player(1)
		var caster := world.player(2)
		check(caster.place_proven_spell(0,MixtureCatalog.wire_for(16,"bolt")),"enemy prepares a genuine low paid projectile")
		if case=="blocked_jump": world.collision.add_obstacle(CollisionWorld.Obstacle.new(901,580000,590000,700000,610000))
		var paid := false
		var launched := false
		var avoided := false
		var hit := false
		var jump_requested := false
		var shot_survived_contact := false
		for tick: int in range(240):
			var player_pressed := 0
			if case!="grounded" and not jump_requested:
				for shot: ProjectileState in world.projectiles:
					if shot.owner_id==2 and _approaching_within(shot,player,150):
						player_pressed = SimCommand.PRESSED_JUMP
						jump_requested = true
						break
			var held := SimCommand.HELD_JUMP if player_pressed else 0
			var aim := Vector2i(player.position_x-caster.position_x,player.position_y-caster.position_y)
			if case=="miss_jump": aim.x+=180000
			check(world.step([SimCommand.new(world.tick,1,0,0,held,player_pressed),SimCommand.new(world.tick,2,0,0,0,SimCommand.PRESSED_SPELL_1 if tick==0 else 0,aim.x,aim.y)]),"feedback scene advances ordinary paid commands")
			for event: Dictionary in world.combat_events:
				paid = paid or (String(event.get("type",""))=="cast_started" and int(event.get("entity_id",0))==2)
				launched = launched or (String(event.get("type",""))=="projectile_spawned" and int(event.get("owner_id",0))==2)
				hit = hit or (String(event.get("type",""))=="projectile_hit" and int(event.get("target_id",0))==1)
			if player.last_event=="evaded_projectile":
				avoided = true
				for shot: ProjectileState in world.projectiles:
					if shot.owner_id==2 and shot.remaining_strength==shot.initial_strength: shot_survived_contact = true
		check(paid and launched,"every comparison actually pays and releases enemy pressure")
		equal(hit,case=="grounded","only grounded clear-lane control takes the actual swept hit: "+case)
		equal(avoided,case=="jump","only protected actual contact reports avoidance; cover and a geometric miss do not: "+case)
		if case=="jump": check(jump_requested and shot_survived_contact,"paid jump witness neither terminates nor subtracts strength from the passed shot")
	_test_unchanged_paid_paths(abilities,champions)
	return finish("hex-avoidance-feedback")


func _test_unchanged_paid_paths(abilities: AbilityCatalog, champions: ChampionCatalog) -> void:
	for family: String in ["bolt","fuse"]:
		var traces := []
		for friendly: bool in [false,true]:
			var world := SimWorld.new()
			check(HexCourtPractice.configure(world,abilities),"paired passage starts a fresh paid court")
			for id: int in [1,2]:
				check(champions.apply_to_player(world.player(id),"oh_tipi"),"paired passage applies ordinary body and budgets")
				world.player(id).actor_kind = PlayerState.ActorKind.CHAMPION
				world.player(id).team_id = 2 if friendly else id
			var actor := world.player(1)
			var caster := world.player(2)
			check(caster.place_proven_spell(0,MixtureCatalog.wire_for(16,family)),"paired passage prepares actual delivery")
			var landing := Vector2i(actor.position_x,actor.position_y+180000)
			var trace := []
			var jumped := false
			var jump_tick := -1
			var avoided := false
			var armed_beyond := false
			for tick: int in range(220):
				var pressed := 0
				if not jumped:
					for shot: ProjectileState in world.projectiles:
						if shot.owner_id==2 and _approaching_within(shot,actor,150 if family=="bolt" else 346):
							pressed = SimCommand.PRESSED_JUMP
							jumped = true
							jump_tick = tick
							break
				# Preserve height through the complete slow-shot/body overlap.
				# A single hop can land while a slow Fuse still occupies the hurt
				# circle; that later hit is legitimate, not a feedback mutation.
				if jump_tick>=0 and tick==jump_tick+20: pressed = SimCommand.PRESSED_JUMP
				var aim := landing-Vector2i(caster.position_x,caster.position_y)
				check(world.step([SimCommand.new(world.tick,1,0,0,SimCommand.HELD_JUMP if pressed else 0,pressed),SimCommand.new(world.tick,2,0,0,0,SimCommand.PRESSED_SPELL_1 if tick==0 else 0,aim.x,aim.y,landing.x,landing.y)]),"paired hostile/friendly passage advances identical real inputs")
				avoided = avoided or actor.last_event=="evaded_projectile"
				var shots := []
				var ledgers := []
				for shot: ProjectileState in world.projectiles:
					shots.append(shot.canonical_values())
					ledgers.append(world.hex_court.ledger_for_source(shot.source_cast_id).duplicate(true))
				trace.append({"shots":shots,"ledgers":ledgers})
				for event: Dictionary in world.combat_events:
					if String(event.get("type",""))=="fuse_armed": armed_beyond = int(event.get("y",0))>actor.position_y+100000
			check(jumped,"paired input reaches a real paid jump before passage")
			equal(avoided,not friendly,"only hostile protected crossing produces feedback")
			if family=="fuse": check(armed_beyond,"Fuse passes the protected/friendly actor and arms at its actual intended landing")
			traces.append(trace)
		var first_difference := -1
		for tick: int in traces[0].size():
			if traces[0][tick]!=traces[1][tick]:
				first_difference = tick
				break
		var detail := "" if first_difference<0 else "; first tick %d hostile %s friendly %s" % [first_difference,JSON.stringify(traces[0][first_difference]),JSON.stringify(traces[1][first_difference])]
		check(first_difference<0,"protected contact changes no projectile canonical field or paid ledger compared with an ignored friendly actor: "+family+detail)


static func _approaching_within(shot: ProjectileState, actor: PlayerState, lead_ms: int) -> bool:
	# Choose input from observed paid flight, not an obsolete fixed arrival tick.
	# This is only a fixture cue; actual swept contact still decides hit/avoidance.
	var delta := Vector2i(actor.position_x-shot.position_x,actor.position_y-shot.position_y)
	var approach := delta.x*shot.velocity_x+delta.y*shot.velocity_y
	var speed_squared := shot.velocity_x*shot.velocity_x+shot.velocity_y*shot.velocity_y
	return approach>0 and speed_squared>0 and approach*1000<=speed_squared*lead_ms
