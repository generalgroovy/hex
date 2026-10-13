extends FluxTestSuite
@warning_ignore_start("integer_division")

const Progress = preload("res://src/app/signature_progression.gd")
const Challenges = preload("res://src/content/signature_challenge_catalog.gd")
const Challenge = preload("res://src/app/signature_challenge_session.gd")
const Mixtures = preload("res://src/content/mixture_catalog.gd")
const DamageEvent = preload("res://src/sim/combat/combat_damage_event.gd")
const Arenas = preload("res://src/content/signature_arena_catalog.gd")
const RivalPolicy = preload("res://src/app/signature_rival_policy.gd")
const Tutorial = preload("res://src/app/optional_introduction.gd")
const RangeSession = preload("res://src/app/spell_training_range.gd")

class FailedSave:
	extends SignatureProgression
	var fail_primary := false
	func _replace_staged(staged: String, target: String) -> Error:
		if fail_primary and target == path: return ERR_CANT_CREATE
		return super._replace_staged(staged, target)

var abilities: AbilityCatalog
var champions: ChampionCatalog
var folder := ""
var campus := SanctumCampusLayout.new()
var campus_hex: HexWorldDefinition


func run() -> int:
	abilities = AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "progression loads live catalog")
	champions = ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "progression loads roster")
	check(campus.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"),"lesson journey loads actual campus districts")
	campus_hex = HexWorldDefinition.from_campus(campus)
	check(campus_hex!=null,"lesson journey binds whole-map Hex topology")
	folder = "user://signature-tests-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) == OK, "owned progress folder created")
	_test_catalog_and_access()
	_test_persistence()
	_test_bound_reward()
	_test_learning_journey()
	_test_full_delivery_encounters()
	_test_ground_damage_evidence()
	var directory := DirAccess.open(folder)
	if directory != null:
		for file: String in directory.get_files(): DirAccess.remove_absolute(ProjectSettings.globalize_path(folder + "/" + file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	return finish("signature-progression")


func _fresh(path_suffix: String = "missing.json") -> SignatureProgression:
	var progress := Progress.new()
	check(progress.configure(champions, abilities, folder + "/" + path_suffix, false), "fresh profile is read-only until an earned save")
	return progress


func _test_catalog_and_access() -> void:
	var rows := Challenges.rows(champions, abilities)
	equal(rows.size(), 30, "every current rival has one authored signature")
	var wires := {}
	var families := {}
	var progress := _fresh()
	for row: Dictionary in rows:
		check(not wires.has(int(row.signature_wire)), "signature pair is unique: %s" % row.id)
		wires[int(row.signature_wire)] = true
		families[String(row.family)] = true
		equal(Mixtures.wire_for(int(row.mask), String(row.family)), int(row.signature_wire), "catalog alone owns wire lookup")
		check(not progress.can_equip(int(row.signature_wire)), "unearned signature starts locked")
		check(progress.can_equip(int(row.signature_wire), true), "temporary override can inspect every signature")
		equal(progress.learned_ids().size(), 0, "override never grants progress")
		check(not String(row.tell).is_empty() and not String(row.counter).is_empty(), "signature teaches tell and counter")
	equal(families.size(), 8, "signature set demonstrates every delivery family")
	for wire: int in CombatTuning.runtime_wire_ids():
		equal(progress.can_equip(wire), not wires.has(wire), "only explicit thirty signatures lock; all other live spells remain free")
	check(not progress.can_equip(999999, true), "override never admits an unknown spell")
	var preserved := int(rows[0].signature_wire)
	progress.preserve_existing(PackedInt32Array([preserved]))
	check(progress.can_equip(preserved), "existing valid saved spell survives new progression")
	equal(progress.learned_ids().size(), 0, "preservation is not a fabricated victory")
	check(String(progress.view().characters).contains("already available"), "no invented character grind")


func _test_persistence() -> void:
	var path := folder + "/earned.json"
	var progress := FailedSave.new()
	check(progress.configure(champions, abilities, path, true), "missing profile configures")
	check(not FileAccess.file_exists(path), "configure does not create or normalize profile")
	var reward := progress.record_victory("oh_tipi")
	check(bool(reward.ok) and bool(reward.new) and bool(reward.saved), "earned victory persists")
	var original := FileAccess.get_file_as_bytes(path)
	reward = progress.record_victory("oh_tipi")
	check(not bool(reward.new), "duplicate victory is idempotent")
	equal(FileAccess.get_file_as_bytes(path), original, "duplicate victory does not rewrite bytes")
	progress.fail_primary = true
	reward = progress.record_victory("s_wayne")
	check(bool(reward.ok) and not bool(reward.saved) and progress.dirty, "failed replacement retains session unlock and dirty status")
	equal(FileAccess.get_file_as_bytes(path), original, "failed replacement keeps exact original")
	equal(FileAccess.get_file_as_bytes(path + Progress.BACKUP_SUFFIX), original, "first replacement keeps byte-exact backup")
	progress.fail_primary = false
	check(progress.save(), "explicit retry saves pending earned progress")
	var reloaded := Progress.new()
	check(reloaded.configure(champions, abilities, path, true), "earned profile reloads")
	equal(reloaded.learned_ids(), ["oh_tipi", "s_wayne"], "canonical rival IDs survive reload")
	for bad: Variant in [{"schema_version": 2, "defeated": []}, {"schema_version": 1, "defeated": ["unknown"]}, {"schema_version": 1, "defeated": ["oh_tipi", "oh_tipi"]}, {"schema_version": 1, "defeated": [], "all_spells": true}, {"schema_version": 1, "defeated": "all"}]:
		var bad_path := folder + "/invalid.json"
		var bytes := JSON.stringify(bad).to_utf8_buffer()
		var file := FileAccess.open(bad_path, FileAccess.WRITE)
		file.store_buffer(bytes)
		file.close()
		check(not reloaded.configure(champions, abilities, bad_path, true), "unknown or malformed profile refuses atomically")
		check(not bool(reloaded.record_victory("oh_tipi").ok), "invalid profile cannot silently overwrite history")
		equal(FileAccess.get_file_as_bytes(bad_path), bytes, "invalid/future source retained exactly")


func _world(row: Dictionary) -> SimWorld:
	var world := SimWorld.new()
	check(champions.apply_to_player(world.player(), "oh_tipi"), "player receives real champion profile")
	check(HexCourtPractice.configure(world, abilities), "actual paid Hex court configures")
	var rival := world.player(2)
	check(champions.apply_to_player(rival, String(row.champion_id)), "rival receives authored champion")
	rival.actor_kind = PlayerState.ActorKind.CHAMPION
	rival.team_id = 2
	check(rival.place_proven_spell(0, int(row.signature_wire)), "signature occupies an ordinary slot")
	return world


func _test_bound_reward() -> void:
	var row := Challenges.definition("oh_tipi", champions, abilities)
	for contaminated: bool in [false, true]:
		var progress := _fresh("reward-%s.json" % contaminated)
		var world := _world(row)
		var challenge := Challenge.new()
		check(not challenge.begin(world, Rect2i(0, 0, 1280, 960), row, false), "network worlds cannot open signature challenges")
		check(challenge.begin(world, Rect2i(0, 0, 1280, 960), row, true, contaminated), "bound local attempt begins")
		var before := world.state_hash()
		check(challenge.command(world) != null, "rival command is ordinary and available")
		equal(world.state_hash(), before, "AI command planning never changes authority")
		# Real paid Fire Bolts against the actual champion: no health injection,
		# cooldown resets, resource grants or fabricated defeat events in this path.
		var spent := false
		var rival_spent := false
		for unused: int in 8641:
			if challenge.trial.is_finished(): break
			var player := world.player(1)
			var rival := challenge.command(world)
			check(rival != null, "real reward encounter includes the acting rival")
			if rival == null: break
			check(world.step([_counter_command(world, challenge), rival]), "both sides' ordinary paid commands step")
			spent = spent or player.flux < player.flux_maximum
			for event: Dictionary in world.combat_events:
				rival_spent = rival_spent or (String(event.get("type", "")) == "cast_started" and int(event.get("entity_id", 0)) == 2)
			challenge.observe(world, progress, true, false)
		check(spent, "real encounter spent Flux")
		check(rival_spent, "reward test actually faced a paid signature, not an inert target")
		equal(challenge.trial.phase, "victory", "real paid damage produces victory")
		equal(bool(challenge.reward.get("ok", false)), not contaminated, "only clean victory learns; turning off dev cannot untaint")
		equal(progress.learned_ids().size(), 0 if contaminated else 1, "earned count matches clean actual result")
		var count := progress.learned_ids().size()
		challenge.observe(world, progress, true, false)
		equal(progress.learned_ids().size(), count, "duplicate observation never repeats grant")
	var progress := _fresh("no-event.json")
	var world := _world(row)
	var challenge := Challenge.new()
	check(challenge.begin(world, Rect2i(0, 0, 1280, 960), row, true), "negative health-edit fixture binds")
	world.player(2).health = 0
	world.tick += 1
	check(challenge.observe(world, progress, true), "bare health change reaches terminal bookkeeping")
	check(not bool(challenge.reward.ok), "bare health edit without real owned hit/defeat events grants nothing")
	check(progress.learned_ids().is_empty(), "synthetic terminal state does not fabricate progress")


func _counter_command(world: SimWorld, challenge: SignatureChallengeSession) -> SimCommand:
	var player := world.player(1)
	var rival := world.player(2)
	var position := Vector2i(player.position_x,player.position_y)
	var delta := Vector2i(rival.position_x,rival.position_y)-position
	if world.tick < 480: return SimCommand.new(world.tick,1,0,0,0,0,delta.x,delta.y)
	var toward := SimCommand._normalized_direction(delta.x,delta.y)
	var distance := int(delta.length())
	var movement := toward if distance > 180000 else (-toward if distance < 120000 else Vector2i.ZERO)
	if String(challenge.status(world.tick).phase) in ["windup","pressure"]:
		movement += Vector2i(-toward.y,toward.x)
	var safe := challenge.trial.court.grow(-120000)
	var requested := position+movement*120
	requested.x = clampi(requested.x,safe.position.x,safe.end.x-1)
	requested.y = clampi(requested.y,safe.position.y,safe.end.y-1)
	movement = SimCommand._normalized_direction(requested.x-position.x,requested.y-position.y)
	var held := SimCommand.SPELL_HELD_BITS[1]
	var jump_tick := posmod(world.tick-480,180)
	if jump_tick < 24: held |= SimCommand.HELD_JUMP
	var pressed := SimCommand.PRESSED_JUMP if jump_tick in [0,62] else 0
	# This route's ordinary held shot leads using its current authored speed;
	# no simulated motion, timing or target resource is rewritten by the helper.
	var cast_speed := int(CombatTuning.cast_definition(player.spell_wire_ids[1]).speed)
	var travel_ms := clampi(distance*1000/maxi(1,cast_speed)+60,60,550)
	var aim := delta+Vector2i(rival.velocity_x,rival.velocity_y)*travel_ms/1000
	return SimCommand.new(world.tick,1,movement.x,movement.y,held,pressed,aim.x,aim.y)


func _test_ground_damage_evidence() -> void:
	for kind: String in ["hex_pressure","hex_conflagration"]:
		var event := {"type":kind,"entity_id":2,"owner_id":1,"amount":75}
		equal(DamageEvent.amount(event),75,"ground loss retains its actual authoritative amount")
		equal(DamageEvent.target_id(event),2,"ground loss retains its actual damaged actor")
	equal(DamageEvent.amount({"type":"cast_started","entity_id":1,"amount":75}),0,"non-damage amounts cannot fabricate paid damage")
	var row := Challenges.definition("oh_tipi",champions,abilities)
	var world := _world(row)
	var challenge := Challenge.new()
	check(challenge.begin(world,Rect2i(0,0,1280,960),row,true),"paid ground-evidence encounter binds")
	var landing := Vector2i(640000,550000)
	var saw_ground := false
	var saw_direct := false
	var paid := false
	var ground_mask := 0
	for tick: int in range(1400):
		var player := world.player(1)
		var rival := world.player(2)
		var aim := landing-Vector2i(player.position_x,player.position_y)
		var pressed := SimCommand.PRESSED_SPELL_2 if tick==480 else 0
		# The genuine champion walks into an already paid Fire patch. Neither
		# actor's Health, resource, status, cooldown or outcome is injected.
		var toward := landing-Vector2i(rival.position_x,rival.position_y)
		var movement := SimCommand._normalized_direction(toward.x,toward.y) if tick>=580 and toward.length_squared()>4000000 else Vector2i.ZERO
		check(world.step([SimCommand.new(tick,1,0,0,0,pressed,aim.x,aim.y,landing.x,landing.y),SimCommand.new(tick,2,movement.x,movement.y)]),"ordinary cast and target approach advance")
		for event: Dictionary in world.combat_events:
			paid = paid or (String(event.get("type",""))=="cast_started" and int(event.get("entity_id",0))==1)
			if int(event.get("owner_id",0))!=1 or DamageEvent.target_id(event)!=2 or DamageEvent.amount(event)<=0: continue
			if String(event.get("type","")) in DamageEvent.GROUND_TYPES:
				saw_ground = true
				ground_mask = DamageEvent.element_mask(event,world)
			else: saw_direct = true
		challenge.observe(world,null,true)
		if saw_ground: break
	check(paid and saw_ground,"real paid Fire ground pressure supplies encounter damage evidence")
	check(not saw_direct,"ground evidence regression did not accidentally rely on a direct projectile hit")
	check(challenge._paid_damage,"actual owned ground loss counts toward the legitimate victory gate")
	equal(ground_mask,2,"ground attribution resolves the actual paid Fire source")
	check(challenge.reward.is_empty(),"ground damage alone does not grant a victory or bypass owned defeat")


func _test_learning_journey() -> void:
	var path := folder+"/learning-journey.json"
	var progress := Progress.new()
	check(progress.configure(champions,abilities,path,true),"learning journey begins with a new isolated earned profile")
	var coach := _prepare_joined_tutorial()
	var visited := {}
	for index: int in Progress.LearningPath.LESSONS.size():
		var lesson: Dictionary = Progress.LearningPath.LESSONS[index]
		var guidance: Dictionary = progress.view().learning_path
		equal(int(guidance.completed),index,"guidance follows actual earned results")
		equal(String(guidance.next.id),String(lesson.id),"next optional lesson follows the first unearned counter skill")
		check(bool(guidance.optional),"suggested order never invents an unlock gate")
		var row := Challenges.definition(String(lesson.id),champions,abilities)
		check(not progress.can_equip(int(row.signature_wire)),"journey does not pre-unlock its reward")
		var result := _complete_encounter(row,progress,true,coach)
		visited[String(result.district_id)] = true
		equal(result.phase,"victory","ordinary paid lesson encounter reaches a genuine victory: "+String(row.id))
		check(bool(result.reward.get("ok",false)) and bool(result.reward.get("saved",false)),"clean owned defeat earns and persists the exact lesson signature")
		var reloaded := Progress.new()
		check(reloaded.configure(champions,abilities,path,true),"earned lesson is read from the actual saved profile")
		equal(reloaded.learned_ids().size(),index+1,"reload preserves each real victory once")
		check(reloaded.can_equip(int(row.signature_wire)),"earned spell passes ordinary equip availability after reload")
		_test_learned_paid_cast(row,reloaded)
		progress = reloaded
	var complete: Dictionary = progress.view().learning_path
	check(bool(complete.complete) and complete.next.is_empty(),"three earned lessons complete the optional route")
	equal(Challenges.rows(champions,abilities).size(),30,"learning route retains all existing selectable rivals")
	equal(visited.size(),3,"three lesson victories occur in three actual collision districts")
	check(coach.complete and not coach.active,"joined optional lessons observe a real chain, mixed hit, protected rival crossing and earned saved result without advancing lesson state by hand; final="+JSON.stringify(coach.view()))
	var detached: Dictionary = progress.view().learning_path
	detached.title = "edited"
	check(String(progress.view().learning_path.title)!="edited","view edits cannot rewrite authored lesson text")


func _prepare_joined_tutorial() -> OptionalIntroduction:
	var world := SimWorld.new()
	check(champions.apply_to_player(world.player(),"oh_tipi") and HexCourtPractice.configure(world,abilities),"joined tutorial begins with ordinary fresh actor and paid practice world")
	var intro := Tutorial.new()
	check(intro.start(world),"optional introduction starts through its public action")
	var loaner := RangeSession.new()
	var previous_step := -1
	var selected := false
	for tick: int in range(1800):
		if intro.complete: break
		var actor := world.player()
		var target := world.player(2)
		var move := -1000 if intro.step==0 else 0
		var pressed := 0
		var held := 0
		if intro.step==1 and previous_step!=1:
			pressed = SimCommand.PRESSED_JUMP
			held = SimCommand.HELD_JUMP
		if intro.step==2 and tick%30==0: pressed |= SimCommand.PRESSED_SPELL_1
		if intro.step==4 and not loaner.active: check(loaner.begin(actor,true,world.tick),"intro opens an actual temporary Range lease")
		if intro.step==5:
			if not selected:
				var preview := loaner.preview(3,"bolt",abilities)
				if not preview.is_empty():
					selected = CharacterWeavePolicy.apply(actor,preview.wire_ids)
					check(selected,"intro applies mixed loaner through normal cooldown-preserving equip")
			if selected and tick%30==0: pressed |= SimCommand.PRESSED_SPELL_1
		previous_step = intro.step
		var aim := Vector2i(target.position_x-actor.position_x,target.position_y-actor.position_y)
		check(world.step([SimCommand.new(world.tick,1,move,0,held,pressed,aim.x,aim.y),SimCommand.new(world.tick,2)]),"joined intro advances actual movement, jump, payment and natural recovery")
		intro.observe(world,world.combat_events,{"range":loaner.active})
	check(intro.complete and selected,"all six introduction gates complete from authoritative commands and actual Range context")
	var coach := Tutorial.new()
	check(coach.start_tactical(world),"next optional coach starts without replacing or injecting authority")
	for tick: int in range(1000):
		if coach.step>=2: break
		var actor := world.player()
		var target := world.player(2)
		var move := 1000 if tick<80 else 0
		var held := SimCommand.HELD_SPRINT if tick<40 else 0
		var pressed := SimCommand.PRESSED_SLIDE if tick==40 else (SimCommand.PRESSED_JUMP if tick==45 else (SimCommand.PRESSED_EVADE if tick==55 else 0))
		if tick>=180 and tick%120==0: pressed |= SimCommand.PRESSED_SPELL_1
		var aim := Vector2i(target.position_x-actor.position_x,target.position_y-actor.position_y)
		check(world.step([SimCommand.new(world.tick,1,move,0,held,pressed,aim.x,aim.y),SimCommand.new(world.tick,2)]),"joined coach links finite paid movement and lands a real mixed loaner")
		coach.observe(world,world.combat_events,{"range":loaner.active})
	equal(coach.step,2,"real chain admission and owned mixed damage reach the rival counter lesson")
	check(loaner.restore(world.player(),world.tick),"leaving the joined Range restores ordinary weave with real remaining cooldowns")
	return coach


func _campus_encounter(row: Dictionary) -> Dictionary:
	var world := SimWorld.new(120,8675309,campus.build_collision_world(),String(campus.data.id),campus.content_hash)
	check(campus_hex.bind_world(world),"district encounter uses complete paid campus terrain authority")
	check(not InterceptionShowcase.configure(world,champions,abilities,campus).is_empty(),"fresh public encounter setup creates ordinary actors")
	var anchors := Arenas.contract(String(row.id),campus,world.collision)
	check(not anchors.is_empty(),"district court validates authored map membership and spawn collision")
	var actor := world.player(1)
	var rival := world.player(2)
	check(champions.apply_to_player(actor,"oh_tipi") and champions.apply_to_player(rival,String(row.id)),"district lesson uses actual player and rival profiles")
	# The same ordinary Fire Bolt counter slot used by the smaller encounters.
	check(actor.place_proven_spell(1,Mixtures.wire_for(2,"bolt")),"district journey equips its ordinary paid counter before starting")
	check(rival.place_proven_spell(0,int(row.signature_wire)),"actual rival equips its earned signature")
	actor.reset_for_spawn(anchors.player_spawn_fixed)
	rival.reset_for_spawn(anchors.opponent_spawn_fixed)
	if String(row.id)=="s_wayne":
		var spell := CombatTuning.cast_definition(int(row.signature_wire))
		var bank := RivalPolicy.bank_target(anchors.opponent_spawn_fixed,anchors.player_spawn_fixed,spell,world.collision)
		check(bank!=Vector2i(-1,-1),"Foundry lesson offers a real reachable wall bank")
		if bank!=Vector2i(-1,-1):
			var contact := ContinuousContact.wall_contact(anchors.opponent_spawn_fixed,bank+Vector2i(0,-2),int(spell.radius),world.collision.base_world)
			equal(int(contact.get("id",0)),313,"Rebound lesson reflects from the existing Basalt wall, never the administrative boundary")
	return {"world":world,"anchors":anchors}


func _joined_counter_command(world: SimWorld, session: SignatureChallengeSession, coach: OptionalIntroduction) -> SimCommand:
	if coach==null or not coach.active or coach.step!=2: return _counter_command(world,session)
	# The usual circling counter can miss a shot geometrically without ever
	# crossing its flight. For this optional lesson, stand in the actual paid
	# lane and jump on the approaching shot; proximity merely requests input.
	# Only the resolver's later protected swept contact advances the observer.
	var actor := world.player(1)
	var rival := world.player(2)
	var pressed := 0
	if not actor.is_airborne() and not actor.jumpsquat_active:
		for shot: ProjectileState in world.projectiles:
			if shot.owner_id!=2: continue
			var delta := Vector2i(actor.position_x-shot.position_x,actor.position_y-shot.position_y)
			var approach := delta.x*shot.velocity_x+delta.y*shot.velocity_y
			var speed_squared := shot.velocity_x*shot.velocity_x+shot.velocity_y*shot.velocity_y
			# Keep the observed150ms input lead when authored speed changes;
			# only subsequent real protected contact completes the lesson.
			if approach>0 and speed_squared>0 and approach*1000<=speed_squared*150:
				pressed = SimCommand.PRESSED_JUMP
				break
	var aim := Vector2i(rival.position_x-actor.position_x,rival.position_y-actor.position_y)
	return SimCommand.new(world.tick,1,0,0,SimCommand.HELD_JUMP if pressed else 0,pressed,aim.x,aim.y)


func _complete_encounter(row: Dictionary, progress: SignatureProgression, use_district: bool = false, coach: OptionalIntroduction = null) -> Dictionary:
	var prepared := _campus_encounter(row) if use_district else {}
	var world: SimWorld = prepared.world if use_district else _world(row)
	var bounds: Rect2i = prepared.anchors.bounds if use_district else Rect2i(0,0,1280,960)
	var session := Challenge.new()
	check(session.begin(world,bounds,row,true),"complete real delivery encounter binds")
	if coach!=null: check(coach.rebind(world),"joined coach carries its observed lesson state into the new real district encounter")
	var rival_paid := 0
	var rival_released := 0
	var rival_spray_intercepted := 0
	var real_damage := 0
	var phases := {}
	for unused: int in 8641:
		if session.trial.is_finished(): break
		var rival := session.command(world)
		if rival == null:
			check(false,"full encounter unexpectedly lost its valid rival")
			break
		phases[String(session.status(world.tick).phase)] = true
		if not world.step([_joined_counter_command(world,session,coach),rival]):
			check(false,"full encounter refused ordinary paired commands")
			break
		for event: Dictionary in world.combat_events:
			var kind := String(event.get("type",""))
			if kind=="cast_started" and int(event.get("entity_id",0))==2: rival_paid += 1
			if int(event.get("owner_id",0))==2 and kind in ["projectile_spawned","spray_fired"]: rival_released += 1
			# A Spray whose paid strength is consumed in a real contact never
			# reaches spray_fired. Keep that successful counter distinct from a
			# surviving fan, while still requiring the exact released source.
			if String(row.family)=="spray" and kind=="hex_clash" and int(event.get("owner_id",0))==2 and int(event.get("source_wire_id",0))==int(row.signature_wire): rival_spray_intercepted += 1
			if int(event.get("owner_id",0))==1 and DamageEvent.target_id(event)==2: real_damage += DamageEvent.amount(event)
		session.observe(world,progress,true)
		if coach!=null:
			coach.observe(world,world.combat_events,{"challenge":true,"earned":bool(session.reward.get("ok",false)) and bool(session.reward.get("new",false)),"saved":bool(session.reward.get("saved",false))})
	check(rival_paid>0 and rival_released+rival_spray_intercepted>0,"full encounter faces paid released signature pressure: %s (paid %d, surviving release %d, intercepted Spray %d, terminal %s tick %d)" % [String(row.family),rival_paid,rival_released,rival_spray_intercepted,session.trial.phase,world.tick])
	check(real_damage>0 and session.trial.paid_casts>0,"full encounter owns actual paid player damage")
	check(phases.has("windup") and phases.has("pressure") and phases.has("recover"),"full encounter exercises readable tell, pressure and recovery")
	check(world.projectiles.size()<=SimConfig.MAX_ACTIVE_PROJECTILES,"complete pattern preserves the shared projectile budget")
	return {"phase":session.trial.phase,"reward":session.reward.duplicate(true),"world_hash":world.state_hash(),"paid":rival_paid,"released":rival_released,"intercepted_spray":rival_spray_intercepted,"district_id":String(prepared.anchors.district_id) if use_district else "small-court"}


func _test_learned_paid_cast(row: Dictionary, progress: SignatureProgression) -> void:
	var world := _world(row)
	var actor := world.player()
	var wire := int(row.signature_wire)
	check(progress.can_equip(wire) and actor.place_proven_spell(0,wire),"reloaded learned signature enters an ordinary slot")
	var paid := false
	var released := false
	for tick: int in range(240):
		var target := world.player(2)
		var aim := Vector2i(target.position_x-actor.position_x,target.position_y-actor.position_y)
		var pressed := SimCommand.PRESSED_SPELL_1 if tick==0 else 0
		check(world.step([SimCommand.new(world.tick,1,0,0,0,pressed,aim.x,aim.y,target.position_x,target.position_y),SimCommand.new(world.tick,2)]),"earned spell uses the ordinary paid cast path")
		for event: Dictionary in world.combat_events:
			var kind := String(event.get("type",""))
			if kind=="cast_started" and int(event.get("entity_id",0))==1 and int(event.get("wire_id",0))==wire: paid = true
			if int(event.get("owner_id",0))==1 and int(event.get("wire_id",event.get("source_wire_id",0)))==wire and kind in ["projectile_spawned","spray_fired"]: released = true
		if released: break
	check(paid and released,"earned signature actually pays and releases after save reload: "+String(row.id))


func _test_full_delivery_encounters() -> void:
	# Three route families above already reach genuine victory and a reload.
	# Complete one real encounter for each remaining authored delivery too.
	var seen := {"rapid":true,"fuse":true,"rebound":true}
	for id: String in ["leaf_hidden","red_baron","grace_reava","ba_djoh","steezo"]:
		var row := Challenges.definition(id,champions,abilities)
		var progress := _fresh("full-"+id+".json")
		var result := _complete_encounter(row,progress)
		equal(result.phase,"victory","complete paid encounter has a reachable counter route: "+String(row.family))
		check(bool(result.reward.get("ok",false)),"clean full delivery encounter admits its owned earned result")
		seen[String(row.family)] = true
	equal(seen.size(),8,"full paid encounter coverage reaches all eight delivery families")
