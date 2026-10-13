extends SceneTree
## E13 steady process and model cost only. Shared current simulation, no drawing.
const OldBoot = preload("res://.godot/iteration-20261013/E13-before/src/app/bootstrap.gd")
const NewBoot = preload("res://src/app/bootstrap.gd")
const OldHud = preload("res://.godot/iteration-20261013/E13-native/previous_hud.gd")
const Packet = preload("res://src/net/hex_world_snapshot.gd")
const Witness = preload("res://src/presentation/cast_startup_witness.gd")
const CENTER := Vector2i(800000,800000)
const GROUPS: Array[int]=[0,1,8]
const CYCLES := 34
const WARMUPS := 2
const MODEL_REPEATS := 16
const WATCHED := ["res://.godot/iteration-20261013/E13-native/compare-startup-cost.gd",
	"res://.godot/iteration-20261013/E13-native/previous_hud.gd",
	"res://.godot/iteration-20261013/E13-before/src/app/bootstrap.gd",
	"res://.godot/iteration-20261013/E13-before/src/presentation/compact_combat_hud.gd",
	"res://src/app/bootstrap.gd","res://src/presentation/cast_startup_witness.gd",
	"res://src/presentation/compact_combat_hud.gd","res://src/sim/core/sim_world.gd",
	"res://src/sim/combat/combat_system.gd","res://src/net/hex_world_snapshot.gd",
	"res://content/abilities/foundation_abilities_v1.json","res://content/champions/foundation_champions_v1.json",
	"res://.godot/iteration-20261013/E13-before/manifest.json"]
class Before extends OldBoot:
	func _ready() -> void:set_process(false)
	func _draw() -> void:pass
	func _prepare_terrain_frame() -> void:terrain_loading=false
	func _advance_player_camera(_delta:float,_blocked:bool) -> void:pass
class After extends NewBoot:
	func _ready() -> void:set_process(false)
	func _draw() -> void:pass
	func _prepare_terrain_frame() -> void:terrain_loading=false
	func _advance_player_camera(_delta:float,_blocked:bool) -> void:pass
class NeutralRouter extends InputRouter:
	func sample(tick:int,_at:Vector2,_pointer:Vector2)->SimCommand:return SimCommand.new(tick,entity_id,0,0,0,0,0,-1000)
class NoSave extends PlayerPreferences:
	var saves:=0
	func save_to_file(_path:String=DEFAULT_PATH)->bool:saves+=1;return true
var output:=""
var reverse:=false
var errors:Array[String]=[]
var checks:=0
var sources:Dictionary={}
var rows:Array[Dictionary]=[]
var abilities:=AbilityCatalog.new()
var champions:=ChampionCatalog.new()
var finished:=false

func _initialize()->void:_run.call_deferred()
func _check(ok:bool,message:String)->bool:
	checks+=1
	if not ok:errors.append(message)
	return ok

func _run()->void:
	for argument:String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	reverse=OS.get_cmdline_user_args().has("--reverse")
	if not _check(DisplayServer.get_name()!="headless" and output.begins_with("res://.godot/iteration-20261013/E13-native/cost-") and not ".." in output and not FileAccess.file_exists(output),"Fresh owned native receipt required"):_finish();return
	var before_text:=FileAccess.get_file_as_string(WATCHED[3]).replace("\r\n","\n")
	if not _check(FileAccess.get_file_as_string(WATCHED[1])==before_text.trim_prefix("class_name CompactCombatHud\n"),"Old HUD differs only by removed global class declaration"):_finish();return
	var manifest:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/iteration-20261013/E13-before/manifest.json"))
	if not _check(manifest is Dictionary,"Before manifest required"):_finish();return
	for file:Dictionary in manifest.files:
		if file.path in ["src/app/bootstrap.gd","src/presentation/compact_combat_hud.gd"]:
			if not _check(FileAccess.get_sha256("res://.godot/iteration-20261013/E13-before/"+String(file.path))==file.sha256,"Pinned exact predecessor"): _finish();return
	for path:String in WATCHED:
		sources[path]=FileAccess.get_sha256(path)
		if not _check(String(sources[path]).length()==64,"Missing watched source"): _finish();return
	if not _check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json") and champions.load_from_file("res://content/champions/foundation_champions_v1.json",abilities),"Real catalogs"):_finish();return
	InputRouter.ensure_input_map()
	root.hide()
	create_timer(240).timeout.connect(func()->void:
		if not finished:errors.append("Bounded cost watchdog");_finish())
	var mouse_mode:=Input.mouse_mode
	for count:int in [1,8]:
		for cycle:int in CYCLES:
			await process_frame
			_case(count,cycle)
			if not errors.is_empty():Input.mouse_mode=mouse_mode;_finish();return
	Input.mouse_mode=mouse_mode
	_finish()

func _world(count:int)->SimWorld:
	var world:=SimWorld.new(120,713,CollisionWorld.new(3000000,3000000))
	var court:=HexChemistryWorld.new()
	_check(court.configure_geometry(CENTER,HexGrid.disk(Vector2i.ZERO,10)),"Actual finite geometry")
	court.chemistry_enabled=true;world.hex_court=court
	for index:int in count:
		var actor:=world.player() if index==0 else PlayerState.new(index+1)
		_check(champions.apply_to_player(actor,"nico_lai"),"Real identity")
		actor.reset_for_spawn(CENTER+Vector2i((index%4)*65000,(index/4)*65000))
		_check(actor.place_proven_spell(0,MixtureCatalog.wire_for(16,"heavy")),"Real paid Heavy")
		if index>0:world.players.append(actor)
	return world

func _node(world:SimWorld,old:bool)->Variant:
	var node:Variant=Before.new() if old else After.new()
	node.preference_overrides_are_transient=true
	node.world=world;node.input_router=NeutralRouter.new(1);node.player_preferences=NoSave.new()
	node.session_steward=SessionSteward.new();node.campus_layout=SanctumCampusLayout.new()
	node.ability_catalog=abilities;node.champion_catalog=champions
	node.authoritative_session=AuthoritativeSession.new()
	_check(node.authoritative_session.bind(world,champions,Vector2i(800,800),"Cost Host"),"Actual local session binding")
	node.session_transport=SessionTransport.new()
	root.add_child(node)
	return node

func _case(count:int,cycle:int)->void:
	var before:=_world(count)
	var after:=_world(count)
	var a:Variant=_node(before,true)
	var b:Variant=_node(after,false)
	var commands:Array[SimCommand]=[]
	for id:int in range(1,count+1):commands.append(SimCommand.new(0,id,0,0,0,SimCommand.PRESSED_SPELL_1,0,-1000))
	_check(before.step(commands) and after.step(commands),"Every actor uses an actual simultaneous ordinary paid admission")
	var admissions:=0
	for event:Dictionary in after.combat_events:
		if event.get("type")=="cast_started":admissions+=1
	_check(admissions==count and int(after.hex_court.metrics.matter_paid)==600*count,"All declared actors actually paid concurrently")
	var began:=Time.get_ticks_usec()
	b.cast_startup_witness.observe_local_step(after,after.combat_events,0)
	var admission_observer_us:=Time.get_ticks_usec()-began
	for actor:PlayerState in after.players:_check(bool(b.cast_startup_witness.describe(after,actor).get("known_total",false)),"Every paid actor has a real witness")
	for phase:int in 4:
		for steps:int in GROUPS:
			var tick:=before.tick
			var pending:=0
			for actor:PlayerState in after.players:pending+=1 if actor.pending_cast_ticks>0 else 0
			var candidate_first:=((cycle*12+phase*3+GROUPS.find(steps))%2==0)!=reverse
			var order:Array=["candidate","reference"] if candidate_first else ["reference","candidate"]
			var process:Dictionary={}
			var observed:Array[String]=[]
			for name:String in order:
				observed.append(name)
				var node:Variant=b if name=="candidate" else a
				began=Time.get_ticks_usec()
				node._process(0.0 if steps==0 else 1.0/120.0 if steps==1 else 0.1)
				process[name]=Time.get_ticks_usec()-began
			_check(observed==order,"Actual whole process invocation order")
			_check(before.tick==tick+steps and after.tick==before.tick,"Actual declared0/1/8 group")
			_check(before.last_error.is_empty() and after.last_error.is_empty() and before.state_hash()==after.state_hash(),"Complete authority parity after real inherited process")
			_check(before.combat_events==after.combat_events,"Real boundary events remain identical")
			var left:=Packet.capture(before);var right:=Packet.capture(after)
			_check(not left.is_empty() and var_to_bytes(left)==var_to_bytes(right),"Strict complete snapshot parity outside timers")
			for actor:PlayerState in after.players:
				_check(bool(b.cast_startup_witness.describe(after,actor).get("known_total",false))==(actor.pending_cast_ticks>0),"Live model sampling retains each actually observed concurrent startup")
			var model:Dictionary={}
			var projection:Dictionary={}
			for name:String in order:
				var world:SimWorld=after if name=="candidate" else before
				began=Time.get_ticks_usec()
				for repeat:int in MODEL_REPEATS:
					for actor:PlayerState in world.players:
						var timing:Dictionary=b.cast_startup_witness.describe(after,actor) if name=="candidate" else {}
						for slot:int in 4:
							var ability:=abilities.ability_from_wire(actor.spell_wire_id(slot+1))
							if name=="candidate":projection=CompactCombatHud.spell_display_status(actor,ability,120,Vector2i(-1,-1),"",timing)
							else:projection=OldHud.spell_display_status(actor,ability)
						if name=="candidate":projection=CompactCombatHud.hidden_cast_status(actor,abilities,1,null,120,timing)
						else:projection=OldHud.hidden_cast_status(actor,abilities,1)
				model[name]=Time.get_ticks_usec()-began
			model.last_projection_entries=projection.size()
			_check(before.state_hash()==after.state_hash(),"Readiness and witness queries cannot alter paid authority")
			rows.append({"actors":count,"cycle":cycle,"warmup":cycle<WARMUPS,"phase":phase,"steps":steps,"pending_before":pending,"tick_before":tick,"tick_after":after.tick,"actual_order":observed,"process_us":process,"models_batch_us":model,"models_repeats":MODEL_REPEATS,"admission_observer_us":admission_observer_us if phase==0 and steps==0 else null})
			if not errors.is_empty():break
		if not errors.is_empty():break
	_check(int(after.hex_court.metrics.admitted)==count and int(after.hex_court.metrics.matter_paid)==600*count,"No further casts or grants occur in measured continuation")
	for actor:PlayerState in after.players:_check(actor.pending_cast_wire_id==0,"Measured continuation reaches natural release for every actor")
	_check(after.hex_court.conservation_valid(),"Finite paid sources conserve")
	for node:Variant in [a,b]:
		_check(node.player_preferences.saves==0,"No user preference writes")
		node.session_transport.stop();node.free()

func _finish()->void:
	if finished:return
	finished=true
	for path:String in sources:_check(FileAccess.get_sha256(path)==sources[path],"Source drift "+path)
	var receipt:Dictionary={"schema":"hex-startup-witness-cost-v1","passed":errors.is_empty(),"errors":errors,"checks":checks,"sources":sources,"rows":rows,"reverse_initial_order":reverse,"engine":Engine.get_version_info(),
		"scope":"Exact predecessor Bootstrap vs current, current SimWorld shared. Node, world and presenter construction are outside clocks, not claimed equivalent. Drawing, startup, terrain and camera suppressed equally. Fresh ordinary1/8actor simultaneous paid admissions happen outside process clocks; new admission observer measured separately, then actual0/1/8 inherited process groups through release.32measured+2warmup independent paid worlds peractor count, no poststart grants/refills. Whole process includes ongoing witness work. Fourcard+hidden readiness model batches include current projection/validation, not drawsubmission. First-call/order strata retained; no FPS/GPU/physicalinput/oldexecutable claim. Full-flight expiry and ground work are not promised by this bounded startup continuation."}
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE)
		if file==null:printerr("STARTUP_COST receipt open failed");quit(1);return
		file.store_string(JSON.stringify(receipt,"\t")+"\n");file.close()
		if not JSON.parse_string(FileAccess.get_file_as_string(output)) is Dictionary:printerr("STARTUP_COST receipt readback failed");quit(1);return
	print("STARTUP_COST passed=",receipt.passed," rows=",rows.size()," checks=",checks)
	quit(0 if errors.is_empty() else 1)
