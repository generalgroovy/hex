extends SceneTree
## Ordinary paid worlds, sampled for native visual inspection. No measured FPS.
const Timing = preload("res://src/presentation/cast_startup_witness.gd")
const Perks = preload("res://src/sim/entities/identity_perk_policy.gd")
const ORIGIN := Vector2i(600000, 600000)
const AIMS: Array[Vector2i] = [Vector2i(0,1000),Vector2i(707,707),Vector2i(1000,0),Vector2i(707,-707),Vector2i(0,-1000),Vector2i(-707,-707),Vector2i(-1000,0),Vector2i(-707,707)]
const SOURCES := ["res://.godot/iteration-20261013/E13-native/capture-startup-witness.gd", "res://src/app/bootstrap.gd",
	"res://src/presentation/cast_startup_witness.gd", "res://src/presentation/compact_combat_hud.gd",
	"res://src/presentation/cartoon_champion_presenter.gd", "res://src/presentation/fullbody_cast_presenter.gd",
	"res://src/presentation/pixel_cast_hands.gd", "res://src/presentation/foundation_spell_presenter.gd",
	"res://src/sim/combat/combat_system.gd", "res://src/sim/entities/identity_perk_policy.gd",
	"res://content/abilities/foundation_abilities_v1.json", "res://content/champions/foundation_champions_v1.json"]
var output := ""
var finished := false
var errors: Array[String] = []
var hashes: Dictionary = {}
var frames: Array[Dictionary] = []
var trajectories: Array[Dictionary] = []
var checks := 0

class Board extends Node2D:
	var art: CartoonChampionPresenter
	var spells: FoundationSpellPresenter
	var hud: CompactCombatHud
	var catalog: AbilityCatalog
	var preferences := PlayerPreferences.new()
	var worlds: Array[SimWorld] = []
	var contexts: Array[Dictionary] = []
	var champion := ""
	var reduced := false
	var mode := "motion"
	var layer := 0
	var known := true
	var failed := false
	var samples: Array[Dictionary] = []
	func _draw() -> void:
		PixelMagicLibrary.default_library().begin_frame(reduced)
		draw_rect(Rect2(Vector2.ZERO,get_viewport_rect().size),Color("283e37"))
		samples.clear()
		if mode != "motion":
			var actor := worlds[2].player()
			var context: Dictionary = contexts[2] if known else {}
			var before := worlds[2].state_hash()
			if mode == "card200":
				draw_string(ThemeDB.fallback_font,Vector2(12,22),"200% isolated spell card; whole HUD reflow is outside this fixture",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
				draw_set_transform(Vector2(80,80),0,Vector2(2,2))
				hud._draw_spell_cell(self,Rect2(0,0,124,68),actor,catalog,0,0,120,hud.data.copy,Vector2i(-1,-1),"",preferences,context)
				draw_set_transform(Vector2.ZERO)
			else:
				hud.draw(self,get_viewport_rect().size,actor,catalog,champion,champion,"PAID STARTUP FIXTURE","LOCAL",layer,120,false,Vector2i(-1,-1),"",Vector2(-1000,-1000),"",preferences,context)
			var ability := catalog.ability_from_wire(actor.spell_wire_id(1))
			samples.append({"display":hud.spell_display_status(actor,ability,120,Vector2i(-1,-1),"",context),"hidden":hud.hidden_cast_status(actor,catalog,layer,preferences,120,context)})
			if worlds[2].state_hash()!=before: failed=true
			return
		draw_string(ThemeDB.fallback_font,Vector2(12,22),champion+" / actual paid movement / known left, unknown right / reduced="+str(reduced),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("eadfc3"))
		for index: int in worlds.size():
			var world := worlds[index]
			var actor := world.player()
			var before := world.state_hash()
			var world_at := Vector2(actor.position_x,actor.position_y)/1000.0
			var jump := JumpPresentation.sample(actor,world.config,0,reduced)
			var floor := Vector2(80+(index%4)*320,235+(index/4)*285)
			for unknown: bool in [false,true]:
				var context: Dictionary = {} if unknown else contexts[index]
				var offset := floor+Vector2(155 if unknown else 0,0)-Vector2(ORIGIN)/1000.0
				draw_set_transform(offset)
				draw_line(Vector2(ORIGIN)/1000.0+Vector2(-65,3),Vector2(ORIGIN)/1000.0+Vector2(65,3),Color("758d80"),1)
				var shadow := world_at+Vector2(0,10.44)
				var sprite := shadow-Vector2(0,jump.body_lift_pixels)
				if not art.draw(self,actor,champion,sprite,float(world.tick)/2.0,world.config,reduced,shadow,-1.0,Vector2i.ZERO,context): failed=true
				if actor.pending_cast_wire_id>0 and actor.pending_cast_ticks>0:
					spells.begin_frame(world.config,world.collision)
					var validated := Timing.for_state(actor,world.config,context)
					if not spells.draw_startup(self,actor.pending_cast_wire_id,CartoonChampionPresenter.hand_cast_origin(sprite,Vector2(actor.aim_x,actor.aim_y)),Vector2(actor.aim_x,actor.aim_y),float(validated.animation_progress),world.tick,reduced,validated): failed=true
				draw_set_transform(Vector2.ZERO)
				var frame := art.movement_frame(champion,actor,float(world.tick)/2.0,world.config,reduced,-1.0,Vector2i.ZERO,context)
				samples.append({"index":index,"unknown":unknown,"tick":world.tick,"pending":actor.pending_cast_ticks,"recovery":actor.cast_recovery_ticks,"position":[actor.position_x,actor.position_y],"action":frame.get("action",""),"cast_phase":frame.get("cast_pose_phase",""),"timing":Timing.for_state(actor,world.config,context)})
				draw_string(ThemeDB.fallback_font,floor+Vector2(-65+(155 if unknown else 0),35),str(index)+" / "+str(actor.pending_cast_ticks)+" ticks",HORIZONTAL_ALIGNMENT_LEFT,145,12,Color("eadfc3"))
			if world.state_hash()!=before: failed=true

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> bool:
	checks+=1
	if not ok: errors.append(message)
	return ok

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	if not _check(DisplayServer.get_name()!="headless" and output.begins_with("res://.godot/iteration-20261013/E13-native/output-") and not ".." in output and not DirAccess.dir_exists_absolute(output),"Fresh owned native output required"):
		_finish();return
	if not _check(DirAccess.make_dir_recursive_absolute(output)==OK,"Output directory creation"):
		_finish();return
	for path: String in SOURCES:
		hashes[path]=FileAccess.get_sha256(path)
		if not _check(String(hashes[path]).length()==64,"Missing source "+path): _finish();return
	var abilities := AbilityCatalog.new()
	var champions := ChampionCatalog.new()
	var language := VisualLanguage.new()
	var art := CartoonChampionPresenter.new()
	var spells := FoundationSpellPresenter.new()
	var hud := CompactCombatHud.new()
	if not _check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json") and champions.load_from_file("res://content/champions/foundation_champions_v1.json",abilities) and language.load_from_file(),"Actual content admission"):
		_finish();return
	if not _check(art.configure_fullbody_startup(language,true,true) and spells.configure(language,abilities) and hud.configure(language),"Actual presentation admission"):
		_finish();return
	var ids: Array[String]=["nico_lai","urzh"]
	if not _check(art.prepare_override_pages(ids),"Admitted body art"):
		_finish();return
	hud.champion_art=art
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1280,600)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	board.art=art;board.spells=spells;board.hud=hud;board.catalog=abilities
	viewport.add_child(board)
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(960,540);root.show()
	create_timer(180).timeout.connect(func() -> void:
		if not finished: errors.append("Native bounded watchdog expired");_finish())
	for champion: String in ids:
		await _route(champion,champions,viewport,board)
		if not errors.is_empty(): _finish();return
	_finish()

func _route(champion: String, champions: ChampionCatalog, viewport: SubViewport, board: Board) -> void:
	board.worlds.clear();board.contexts.clear();board.champion=champion
	var witnesses: Array[RefCounted]=[]
	var metrics: Array[Dictionary]=[]
	var heavy := MixtureCatalog.wire_for(16,"heavy")
	for index: int in 8:
		var world := SimWorld.new(120,813,CollisionWorld.new(2000000,2000000))
		var court := HexChemistryWorld.new()
		if not _check(court.configure_geometry(ORIGIN,HexGrid.disk(Vector2i.ZERO,10)),"Finite paid court"):return
		court.chemistry_enabled=true;world.hex_court=court
		var actor := world.player()
		if not _check(champions.apply_to_player(actor,champion),"Real identity"):return
		actor.reset_for_spawn(ORIGIN)
		actor.flux_recovery_per_second=0 # Prepared resource fixture; never grants after start.
		if not _check(actor.place_proven_spell(0,heavy),"Real Heavy equip"):return
		if champion=="nico_lai": actor.flux=actor.flux_maximum*2/3+int(CombatTuning.cast_definition_view(heavy).flux_cost)/2
		else:
			var enemy := PlayerState.new(2)
			if not _check(champions.apply_to_player(enemy,"s_wayne"),"Real Water opponent"):return
			enemy.reset_for_spawn(ORIGIN+Vector2i(80000,0));enemy.team_id=2;enemy.flux_recovery_per_second=0
			if not _check(enemy.place_proven_spell(0,MixtureCatalog.wire_for(4,"rapid")),"Real Water equip"):return
			world.players.append(enemy)
		board.worlds.append(world);board.contexts.append({});witnesses.append(Timing.new())
		metrics.append({"initial_flux":actor.flux,"admissions":0,"releases":0,"release_tick":-1,"max_displacement":0,"refusals":0,"admission_tick":-1,"total":0,"commands":[],"events":[]})
	var expired := false
	var hud_done := false
	var sampled: Array[int]=[]
	for step: int in 100:
		for index: int in 8:
			var world := board.worlds[index]
			var actor := world.player()
			var ready := champion=="nico_lai" or SpellStatusPolicy.active(actor,2)
			var request := int(metrics[index].admission_tick)<0 and ready
			var moving := int(metrics[index].admission_tick)>=0 and world.tick-int(metrics[index].admission_tick)<12
			var input := SimCommand.new(world.tick,1,1000 if moving else 0,0,0,SimCommand.PRESSED_SPELL_1 if request else 0,AIMS[index].x,AIMS[index].y)
			var commands: Array[SimCommand]=[input]
			if world.player(2)!=null: commands.append(SimCommand.new(world.tick,2,0,0,0,SimCommand.PRESSED_SPELL_1 if step==0 else 0,-1000,0))
			metrics[index].commands.append({"tick":world.tick,"move_x":input.move_x,"pressed":input.pressed_actions,"aim":[input.aim_x,input.aim_y]})
			var start := world.tick
			var admission_projection := Perks.spell_timing(actor,CombatTuning.cast_definition_view(heavy),world.config,SpellStatusPolicy.startup_ratio(actor)) if request else {}
			if not _check(world.step(commands),"Ordinary paid command step"):return
			witnesses[index].observe_local_step(world,world.combat_events,start)
			board.contexts[index]=witnesses[index].describe(world,actor)
			for event: Dictionary in world.combat_events:
				metrics[index].events.append({"tick":world.tick,"event":event.duplicate(true)})
				if event.get("type")=="cast_started" and event.get("entity_id")==1:
					metrics[index].admissions+=1;metrics[index].admission_tick=world.tick;metrics[index].total=actor.pending_cast_ticks
					if not _check(not admission_projection.is_empty() and actor.pending_cast_ticks==int(admission_projection.startup_ticks),"Native total equals actual pre-payment projection"):return
					var base_ticks := world.config.milliseconds_to_ticks(int(CombatTuning.cast_definition_view(heavy).startup_ms))
					if not _check(actor.pending_cast_ticks<base_ticks if champion=="nico_lai" else actor.pending_cast_ticks>base_ticks,"Native route actually has modified startup"):return
					if champion=="nico_lai":
						var post := Perks.spell_timing(actor,CombatTuning.cast_definition_view(heavy),world.config,SpellStatusPolicy.startup_ratio(actor))
						if not _check(int(post.startup_ticks)>actor.pending_cast_ticks,"Payment really crosses the fast-admission condition"):return
				if event.get("type")=="projectile_spawned" and event.get("owner_id")==1:
					metrics[index].releases+=1;metrics[index].release_tick=world.tick
				if event.get("type")=="cast_refused" and event.get("entity_id")==1: metrics[index].refusals+=1
			metrics[index].max_displacement=maxi(int(metrics[index].max_displacement),absi(actor.position_x-ORIGIN.x))
			if actor.pending_cast_ticks>0 and not _check(bool(board.contexts[index].get("known_total",false)),"Each live ordinary local cast has admission evidence"):return
			if not _check(world.hex_court.conservation_valid(),"Finite paid matter conserves"):return
		if int(metrics[0].admission_tick)<0:continue
		var actor := board.worlds[0].player()
		var elapsed := board.worlds[0].tick-int(metrics[0].admission_tick)
		expired=int(metrics[0].releases)>0 and actor.pending_cast_wire_id==0 and actor.cast_recovery_ticks==0
		var sample := elapsed%8==0 or elapsed==int(metrics[0].total)/2 or actor.pending_cast_ticks==1 or board.worlds[0].tick==int(metrics[0].release_tick) or expired
		if sample:
			board.mode="motion";viewport.size=Vector2i(1280,600)
			for reduced: bool in [false,true]:
				board.reduced=reduced
				if not await _capture(viewport,board,champion+"-"+str(elapsed).pad_zeros(3)+("-reduced" if reduced else "-normal")):return
			sampled.append(elapsed)
		if not hud_done and elapsed>=int(metrics[0].total)/2 and actor.pending_cast_ticks>0:
			hud_done=true;board.reduced=false
			for size: Vector2i in [Vector2i(960,540),Vector2i(1280,720)]:
				viewport.size=size;board.mode="hud"
				for layer: int in [0,1]:
					board.layer=layer;board.known=true
					if not await _capture(viewport,board,champion+"-hud-"+str(size.x)+"-layer"+str(layer)):return
			board.mode="card200";viewport.size=Vector2i(400,260)
			for known: bool in [false,true]:
				board.known=known
				if not await _capture(viewport,board,champion+"-card200-"+str(known)):return
		if expired:break
	if not _check(expired and hud_done,"Startup, release, recovery expiry and HUD midpoint reached"):return
	for index: int in 8:
		var world := board.worlds[index]
		var actor := world.player()
		if not _check(int(metrics[index].admissions)==1 and int(metrics[index].releases)==1 and int(metrics[index].refusals)==0,"Exactly one admitted/released Heavy per direction"):return
		if not _check(int(metrics[index].initial_flux)-actor.flux==int(CombatTuning.cast_definition_view(heavy).flux_cost),"Exact finite paid Heavy Flux"):return
		if not _check(int(metrics[index].max_displacement)>0,"Ordinary movement changed body world position"):return
		metrics[index].final_hash=world.state_hash();metrics[index].matter_paid=world.hex_court.metrics.matter_paid
	trajectories.append({"champion":champion,"aims":AIMS.map(func(v:Vector2i)->Array:return [v.x,v.y]),"sampled_elapsed_ticks":sampled,"worlds":metrics})

func _capture(viewport: SubViewport, board: Board, leaf: String) -> bool:
	board.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	if not _check(not board.failed,"Native draw preserves body support and authority"):return false
	var pixels := viewport.get_texture().get_image()
	if not _check(pixels!=null and pixels.get_size()==viewport.size,"Actual native image dimensions"):return false
	pixels.convert(Image.FORMAT_RGBA8)
	var path := output.path_join(leaf+".png")
	if not _check(pixels.save_png(path)==OK,"PNG write"):return false
	frames.append({"path":leaf+".png","sha256":FileAccess.get_sha256(path),"size":[pixels.get_width(),pixels.get_height()],"mode":board.mode,"reduced":board.reduced,"samples":board.samples.duplicate(true)})
	return true

func _finish() -> void:
	if finished:return
	finished=true
	for path: String in hashes:_check(FileAccess.get_sha256(path)==hashes[path],"Source drift "+path)
	var receipt := {"schema":"hex-paid-startup-native-v1","passed":errors.is_empty(),"errors":errors,"checks":checks,"sources":hashes,"engine":Engine.get_version_info(),"frames":frames,"trajectories":trajectories,
		"scope":"Eight actual paid aim directions for threshold-crossing Nico and paid-Water-slowed Urzh, ordinary moving commands through startup/release/recovery expiry. Known-vs-unknown body/world cues, normal/reduced. Eight-tick cadence plus real phase boundaries is declared15Hz simulation sampling, not measured FPS or physical input. Compact/full100% HUD plus isolated200% card, not whole200% HUD/layout proof. No game boot/save writes/network and no latency/GPU/whole-game camera or human-feel acceptance."}
	if not output.is_empty() and DirAccess.dir_exists_absolute(output):
		var path := output.path_join("receipt.json")
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file==null:printerr("STARTUP_NATIVE receipt open failed");quit(1);return
		file.store_string(JSON.stringify(receipt,"\t")+"\n");file.close()
		if not JSON.parse_string(FileAccess.get_file_as_string(path)) is Dictionary:printerr("STARTUP_NATIVE receipt readback failed");quit(1);return
	print("STARTUP_NATIVE passed=",receipt.passed," frames=",frames.size()," checks=",checks)
	quit(0 if errors.is_empty() else 1)
