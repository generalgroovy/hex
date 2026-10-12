extends FluxTestSuite

const Policy = preload("res://src/app/signature_rival_policy.gd")
const Challenge = preload("res://src/app/signature_challenge_session.gd")
const Challenges = preload("res://src/content/signature_challenge_catalog.gd")
const Mixtures = preload("res://src/content/mixture_catalog.gd")
var abilities := AbilityCatalog.new()
var champions := ChampionCatalog.new()


func run() -> int:
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "rival tests load spells")
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "rival tests load characters")
	_test_profiles_and_commitment()
	_test_range_and_banks()
	_test_all_signatures_act()
	return finish("signature-rival")


func _world(row: Dictionary) -> SimWorld:
	var world := SimWorld.new()
	check(champions.apply_to_player(world.player(), "oh_tipi"), "rival fixture applies actual player")
	check(HexCourtPractice.configure(world, abilities), "rival fixture uses paid Hex authority")
	check(champions.apply_to_player(world.player(2), String(row.id)), "rival fixture applies actual rival")
	world.player(2).actor_kind = PlayerState.ActorKind.CHAMPION
	world.player(2).team_id = 2
	check(world.player(2).place_proven_spell(0, int(row.signature_wire)), "signature equips in a normal slot")
	return world


func _test_profiles_and_commitment() -> void:
	var seen := {}
	for row: Dictionary in Challenges.rows(champions, abilities):
		var family := String(row.family)
		if seen.has(family): continue
		seen[family] = true
		var profile := Policy.profile(family)
		check(int(profile.windup) >= Policy.COMMIT_TICKS and int(profile.pause) >= 120, "every family has a final readable tell and at least a second of recovery")
		equal(String(Policy.status(480,0,family).cue), String(row.tell), "catalog and live cue have one source")
		var world := _world(row)
		var session := Challenge.new()
		check(session.begin(world,Rect2i(0,0,1280,960),row,true), "policy fixture binds")
		var tick := 480+int(profile.windup)-Policy.COMMIT_TICKS
		world.tick = tick # Boundary fixture only; actual acting test advances every tick below.
		var before := world.state_hash()
		var committed := session.command(world)
		check(committed != null, "commit boundary produces ordinary command")
		equal(world.state_hash(), before, "command planning never mutates simulation")
		if committed == null: continue
		world.player(2).aim_x = committed.aim_x
		world.player(2).aim_y = committed.aim_y
		world.player(1).position_x += 40000
		world.tick += 1
		var next := session.command(world)
		equal(Vector2i(next.aim_x,next.aim_y), Vector2i(committed.aim_x,committed.aim_y), "final tell does not silently track a moved player")
		if family != "mantle": equal(Vector2i(next.move_x,next.move_y),Vector2i.ZERO,"ranged final tell requests stationary movement")
		var recovery_tick := 480+int(profile.windup)+int(profile.pressure)
		world.tick = recovery_tick
		var resting := session.command(world)
		equal(resting.pressed_actions & SimCommand.SPELL_ACTION_MASK,0,"recovery requests no new spell edge")
		equal(resting.held_actions & SimCommand.SPELL_ACTION_MASK,0,"recovery cannot sustain Rapid")
		check(bool(session.status(world.tick).break),"the exposed pause is reported to the player")
		world.player(2).position_x = 1300000
		world.tick = 480+int(profile.windup)
		var reenter := session.command(world)
		check(reenter != null and reenter.move_x < 0,"a pushed-out rival requests ordinary reentry")
		equal(reenter.pressed_actions & SimCommand.SPELL_ACTION_MASK,0,"out-of-court rival cannot fire during reentry")
	equal(seen.size(),8,"every current delivery receives a tested policy")
	check(Policy.profile("unknown").is_empty(),"unknown delivery has no guessed policy")
	# Three short held windows, separated by actual no-fire gaps.
	var rapid_row := Challenges.definition("wa_bidi",champions,abilities)
	var rapid_world := _world(rapid_row)
	var rapid_session := Challenge.new()
	check(rapid_session.begin(rapid_world,Rect2i(0,0,1280,960),rapid_row,true),"Rapid command fixture binds")
	for pressure_tick: int in [0,17,18,24,35,36,47,48,65,66,95,96,113,114,143]:
		rapid_world.tick = 480+int(Policy.PROFILES.rapid.windup)+pressure_tick
		var command := rapid_session.command(rapid_world)
		equal(command.has_held(SimCommand.SPELL_HELD_BITS[0]),posmod(pressure_tick,Policy.RAPID_PERIOD_TICKS)<Policy.RAPID_BURST_TICKS,"Rapid bursts leave a full committed-facing crossing gap")


func _test_range_and_banks() -> void:
	var row := Challenges.definition("ba_djoh",champions,abilities)
	var world := _world(row)
	var opponent := world.player(2)
	var player := world.player(1)
	player.position_y = opponent.position_y+500000
	var spell := CombatTuning.cast_definition(int(row.signature_wire))
	check(not Policy.can_attempt(opponent,player,spell),"Spray cannot spend on a player beyond its real range")
	var approach := Policy.movement(opponent,player,Rect2i(0,0,1280000,960000),world.collision,"spray",0)
	check(approach.y>0,"short fan approaches instead of using a ranged strafe band")
	var ranges := {"bolt":1152000,"rapid":648000,"split":792000,"rebound":910000}
	for family: String in ranges:
		var fast := CombatTuning.cast_definition(Mixtures.wire_for(16,family))
		var reach := int(ranges[family])
		player.position_x = opponent.position_x+reach
		player.position_y = opponent.position_y
		check(Policy.can_attempt(opponent,player,fast),"rival may attempt at the exact explicit finite reach: "+family)
		player.position_x += 1
		check(not Policy.can_attempt(opponent,player,fast),"rival cannot spend beyond explicit reach even when rounded timeout extends farther: "+family)
		# Passive definition fixture: a missing range retains the previous
		# timeout-derived policy, as used by deliberately slow Heavy and Fuse.
		fast.erase("range")
		var legacy_reach := int(fast.speed)*int(fast.lifetime_ms)/1000
		player.position_x = opponent.position_x+legacy_reach
		check(Policy.can_attempt(opponent,player,fast),"missing explicit range keeps the exact lifetime fallback")
		player.position_x += 1
		check(not Policy.can_attempt(opponent,player,fast),"lifetime fallback still refuses its next fixed unit")
	var bank_world := CollisionWorld.new(1280000,960000)
	bank_world.add_obstacle(CollisionWorld.Obstacle.new(77,300000,250000,900000,300000))
	var rebound := CombatTuning.cast_definition(Mixtures.wire_for(48,"rebound"))
	var origin := Vector2i(400000,400000)
	var target := Vector2i(700000,400000)
	var bank := Policy.bank_target(origin,target,rebound,bank_world)
	check(bank != Vector2i(-1,-1),"nearby real wall provides a bank route")
	if bank != Vector2i(-1,-1):
		equal(bank.y,300000+int(rebound.radius),"bank center uses the real projectile clearance")
		var contact := ContinuousContact.wall_contact(origin,bank+Vector2i(0,-2),int(rebound.radius),bank_world)
		equal(int(contact.get("id",0)),77,"bank aims at an actual swept solid, not the court rectangle")
		check(ContinuousContact.wall_contact(bank+Vector2i(0,2),target,int(rebound.radius),bank_world).is_empty(),"outgoing bank leg reaches target without another obstruction")
		var length := (bank-origin).length()+(target-bank).length()
		var bounded := rebound.duplicate(true)
		bounded.range = floori(length)
		equal(Policy.bank_target(origin,target,bounded,bank_world),Vector2i(-1,-1),"bank planning refuses a real reflected path beyond the explicit distance ceiling")
		bounded.range = ceili(length)+1
		equal(Policy.bank_target(origin,target,bounded,bank_world),bank,"one fixed unit of path clearance admits the same actual wall bank")
		bounded.erase("range")
		equal(Policy.bank_target(origin,target,bounded,bank_world),bank,"bank planning retains lifetime fallback when explicit range is absent")
	var wide := CollisionWorld.new(10000000,10000000)
	var direct_origin := Vector2i(5000000,5000000)
	var direct_target := direct_origin+Vector2i(300000,0)
	equal(Policy.committed_aim(direct_origin,direct_target,rebound,wide),direct_target-direct_origin,"no reachable wall safely falls back to ordinary direct aim")


func _test_all_signatures_act() -> void:
	# All thirty actual actors pay and release their signature. Each bounded run
	# stops after that first release; long victory and taint gates live separately.
	for row: Dictionary in Challenges.rows(champions,abilities):
		var world := _world(row)
		var session := Challenge.new()
		check(session.begin(world,Rect2i(0,0,1280,960),row,true),"acting signature begins: "+String(row.id))
		var paid := false
		var released := false
		var steps_ok := true
		for tick: int in range(1200):
			var rival := session.command(world)
			if rival == null or not world.step([SimCommand.new(world.tick,1),rival]):
				steps_ok = false
				break
			for event: Dictionary in world.combat_events:
				if String(event.get("type","")) == "cast_started" and int(event.get("entity_id",0)) == 2 and int(event.get("wire_id",0)) == int(row.signature_wire): paid = true
				if int(event.get("owner_id",0)) == 2 and int(event.get("wire_id",event.get("source_wire_id",0))) == int(row.signature_wire) and String(event.get("type","")) in ["projectile_spawned","spray_fired"]: released = true
			session.observe(world,null,true)
			if released or session.trial.is_finished(): break
		check(steps_ok,"ordinary rival commands advance authority: "+String(row.id))
		check(paid and released,"rival actually pays and releases signature: "+String(row.id))
		check(world.player(2).flux<world.player(2).flux_maximum,"demonstration has a real resource cost: "+String(row.id))
		check(session.reward.is_empty(),"showing a signature cannot itself grant progress")
