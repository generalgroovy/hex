extends SceneTree
## Diagnostic only: unchanged HUD panels, observed submission versus plain.
const Witness = preload("res://src/presentation/cast_startup_witness.gd")
const Packet = preload("res://src/net/hex_world_snapshot.gd")
const PAIRS := 32
const WARMUPS := 4
const PANEL_SOURCE := """func _draw_panel(canvas: CanvasItem, rectangle: Rect2, opacity: float) -> void:
	var step := float((data.get("layout", {}) as Dictionary).get("panel_corner_step", 6))
	var geometry := _panel_geometry(rectangle, step)
	var fill := Color(language.ui_color("panel_fill"), opacity)
	if geometry.mesh != null:
		canvas.draw_mesh(geometry.mesh, null, Transform2D.IDENTITY, fill)
	else:
		canvas.draw_colored_polygon(geometry.points, fill)
	canvas.draw_polyline(geometry.outline, Color(language.ramp_color("aged_brass", 2), 0.72 * opacity), 1.0, false)"""
const SOURCES := ["res://.godot/iteration-20261013/profile-hud-panels.gd",
	"res://src/presentation/compact_combat_hud.gd", "res://src/presentation/compact_hud_layout_cache.gd",
	"res://src/presentation/cast_startup_witness.gd", "res://src/presentation/element_glyph_renderer.gd",
	"res://src/presentation/visual_language.gd", "res://src/presentation/cartoon_champion_presenter.gd",
	"res://src/presentation/fullbody_cast_presenter.gd", "res://src/sim/core/sim_world.gd",
	"res://src/sim/combat/combat_system.gd", "res://src/sim/entities/identity_perk_policy.gd",
	"res://src/sim/entities/player_state.gd", "res://src/net/hex_world_snapshot.gd",
	"res://src/content/runtime_build_identity.gd", "res://content/abilities/foundation_abilities_v1.json",
	"res://content/champions/foundation_champions_v1.json", "res://content/visual/compact_hud_v1.json"]

class ObservedHud extends CompactCombatHud:
	# Fixed scalar buckets. No per-panel diagnostic dictionaries or history.
	var geometry_us := 0
	var fill_color_us := 0
	var fill_us := 0
	var outline_color_us := 0
	var outline_us := 0
	var panel_us := 0
	var panels := 0
	var mesh_fills := 0
	var polygon_fills := 0
	func reset_observer() -> void:
		geometry_us=0;fill_color_us=0;fill_us=0;outline_color_us=0;outline_us=0
		panel_us=0;panels=0;mesh_fills=0;polygon_fills=0
	func _draw_panel(canvas: CanvasItem, rectangle: Rect2, opacity: float) -> void:
		var panel_started := Time.get_ticks_usec()
		var began := Time.get_ticks_usec()
		var step := float((data.get("layout", {}) as Dictionary).get("panel_corner_step", 6))
		var geometry := _panel_geometry(rectangle, step)
		geometry_us += Time.get_ticks_usec()-began
		began=Time.get_ticks_usec()
		var fill := Color(language.ui_color("panel_fill"), opacity)
		fill_color_us += Time.get_ticks_usec()-began
		began=Time.get_ticks_usec()
		if geometry.mesh != null:
			canvas.draw_mesh(geometry.mesh, null, Transform2D.IDENTITY, fill)
		else:
			canvas.draw_colored_polygon(geometry.points, fill)
		fill_us += Time.get_ticks_usec()-began
		began=Time.get_ticks_usec()
		var outline_color := Color(language.ramp_color("aged_brass", 2), 0.72 * opacity)
		outline_color_us += Time.get_ticks_usec()-began
		began=Time.get_ticks_usec()
		canvas.draw_polyline(geometry.outline, outline_color, 1.0, false)
		outline_us += Time.get_ticks_usec()-began
		panel_us += Time.get_ticks_usec()-panel_started
		panels+=1
		if geometry.mesh != null: mesh_fills+=1
		else: polygon_fills+=1
	func observation() -> Dictionary:
		return {"geometry_us":geometry_us,"fill_color_us":fill_color_us,"fill_us":fill_us,
			"outline_color_us":outline_color_us,"outline_us":outline_us,"panel_us":panel_us,
			"panels":panels,"mesh_fills":mesh_fills,"polygon_fills":polygon_fills,"outlines":panels}

class Board extends Node2D:
	var hud: CompactCombatHud
	var world: SimWorld
	var catalog: AbilityCatalog
	var preferences: PlayerPreferences
	var context: Dictionary={}
	var trace: Array[String]=[]
	var role := ""
	var active := false
	var serial := 0
	var scale_factor := 1.0
	var layer := 0
	var card_only := false
	var pointer := Vector2(-1000,-1000)
	var last: Dictionary={}
	func _draw() -> void:
		serial+=1
		draw_rect(get_viewport_rect(),Color("283e37"))
		if not active or world==null: return
		trace.append(role)
		var actor := world.player()
		var before := world.state_hash()
		var observed := hud as ObservedHud
		if observed!=null: observed.reset_observer()
		var capacity := world.available_cast_offer(actor.entity_id)
		var gate := world.transition_policy.cast_gate_reason(actor)
		draw_set_transform(Vector2(48,48) if card_only else Vector2.ZERO,0,Vector2.ONE*scale_factor)
		var began := Time.get_ticks_usec()
		if card_only:
			hud._draw_spell_cell(self,Rect2(0,0,142,70),actor,catalog,0,0,120,hud.data.copy,capacity,gate,preferences,context)
		else:
			hud.draw(self,get_viewport_rect().size/scale_factor,actor,catalog,"oh_tipi","Oh Tipi","Element Garden","PRACTICE",layer,120,false,capacity,gate,pointer,"",preferences,context)
		var duration := Time.get_ticks_usec()-began
		draw_set_transform(Vector2.ZERO)
		last={"hud_us":duration,"authority_unchanged":before==world.state_hash(),
			"panel":observed.observation() if observed!=null else {}}

var output := ""
var finished := false
var reverse_order := false
var checks := 0
var errors: Array[String]=[]
var hashes: Dictionary={}
var results: Array[Dictionary]=[]
var paid_sequences: Array[Dictionary]=[]
var trace: Array[String]=[]
var language := VisualLanguage.new()
var catalog := AbilityCatalog.new()
var champions := ChampionCatalog.new()
var portraits := CartoonChampionPresenter.new()
var preferences := PlayerPreferences.new()
var witness := Witness.new()
var plain: Board
var observed: Board
var plain_view: SubViewport
var observed_view: SubViewport

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	reverse_order=OS.get_cmdline_user_args().has("--reverse-order")
	if not _check(DisplayServer.get_name()!="headless" and OS.get_cmdline_user_args().has("--no-lan-discovery")
		and output.begins_with("res://.godot/iteration-20261013/hud-panels-") and not ".." in output
		and not DirAccess.dir_exists_absolute(output),"Fresh owned native output and no-LAN required"): _finish();return
	if not _check(DirAccess.make_dir_recursive_absolute(output)==OK,"Output creation"): _finish();return
	for path: String in SOURCES:
		hashes[path]=FileAccess.get_sha256(path)
		if not _check(String(hashes[path]).length()==64,"Missing watched source: "+path): _finish();return
	var source := FileAccess.get_file_as_string("res://src/presentation/compact_combat_hud.gd").replace("\r\n","\n")
	var start := source.find("func _draw_panel(")
	var end := source.find("\n\nfunc _panel_geometry(",start)
	if not _check(start>=0 and end>start and source.substr(start,end-start).strip_edges()==PANEL_SOURCE,"Copied panel operations match exact production method"): _finish();return
	if not _check(language.load_from_file() and catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json")
		and champions.load_from_file("res://content/champions/foundation_champions_v1.json",catalog)
		and portraits.configure_fullbody_startup(language,true,true),"Actual content admission"): _finish();return
	var ids: Array[String]=["oh_tipi"]
	if not _check(portraits.prepare_override_pages(ids) and not portraits.portrait_frame("oh_tipi").is_empty(),"Actual portrait admitted"): _finish();return
	plain=Board.new();observed=Board.new();plain.hud=CompactCombatHud.new();observed.hud=ObservedHud.new()
	for board: Board in [plain,observed]:
		if not _check(board.hud.configure(language),"HUD configured"): _finish();return
		board.hud.champion_art=portraits;board.catalog=catalog;board.preferences=preferences;board.trace=trace
		board.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	plain.role="plain";observed.role="observed"
	plain_view=_viewport(plain);observed_view=_viewport(observed)
	create_timer(180).timeout.connect(func() -> void:
		if not finished: errors.append("Bounded HUD watchdog expired");_finish())
	await process_frame;await process_frame;RenderingServer.force_draw(false)
	var world := _world()
	if world==null: _finish();return
	if not await _case("idle_1280",world,Vector2i(1280,720)): _finish();return
	if not _paid_cast(world): _finish();return
	if not await _case("paid_known_1280",world,Vector2i(1280,720)): _finish();return
	if not await _case("paid_unknown_1280",world,Vector2i(1280,720),1.0,false): _finish();return
	if not await _case("paid_hidden_960",world,Vector2i(960,540),1.0,true,1): _finish();return
	if not await _case("paid_known_960",world,Vector2i(960,540)): _finish();return
	if not await _case("paid_known_1280_125",world,Vector2i(1280,720),1.25): _finish();return
	preferences.prompt_device=ControlBindingEditor.DEVICE_CONTROLLER
	if not await _case("paid_known_1280_150_pad",world,Vector2i(1280,720),1.5): _finish();return
	if not await _case("paid_card_200_pad",world,Vector2i(960,540),2.0,true,0,true): _finish();return
	for tick: int in 4:
		if not _step(world): _finish();return
	if not _check(world.player().pending_cast_ticks>0 and int(witness.describe(world,world.player()).get("elapsed_ticks",0))==4,"Actual later paid startup"): _finish();return
	if not await _case("paid_later_resize_return",world,Vector2i(1280,720)): _finish();return
	for tick: int in 120:
		if world.player().pending_cast_wire_id==0: break
		if not _step(world): _finish();return
	if not _check(world.player().pending_cast_wire_id==0 and world.player().spell_cooldown_for_wire(MixtureCatalog.wire_for(2,"heavy"))>0,"Actual paid release and cooldown"): _finish();return
	if not await _case("paid_cooldown_hover",world,Vector2i(1280,720),1.0,true,0,false,Vector2(40,630)): _finish();return
	for path: String in hashes:
		if not _check(hashes[path]==FileAccess.get_sha256(path),"No watched source drift: "+path): _finish();return
	_finish()

func _world() -> SimWorld:
	var world := SimWorld.new(120,771,CollisionWorld.new(2000000,2000000))
	var court := HexChemistryWorld.new()
	if not _check(world.is_valid() and court.configure_geometry(Vector2i(800000,800000),HexGrid.disk(Vector2i.ZERO,10)),"Concrete world/court admission"): return null
	court.chemistry_enabled=true;world.hex_court=court
	var actor := world.player()
	if not _check(champions.apply_to_player(actor,"oh_tipi"),"Actual champion"): return null
	actor.position_x=800000;actor.position_y=800000
	var wires: Array[int]=[MixtureCatalog.wire_for(2,"heavy"),MixtureCatalog.wire_for(63,"mantle"),MixtureCatalog.wire_for(8,"split"),MixtureCatalog.wire_for(4,"bolt")]
	for slot: int in wires.size():
		if not _check(actor.place_proven_spell(slot,wires[slot]),"Prepared legal loadout"): return null
	return world

func _step(world: SimWorld, pressed: int=0) -> bool:
	var tick := world.tick
	var commands: Array[SimCommand]=[SimCommand.new(tick,1,0,0,0,pressed,1000,0)]
	if not _check(world.step(commands),"Ordinary successful world step"): return false
	witness.observe_local_step(world,world.combat_events,tick)
	return _check(world.hex_court.conservation_valid() and not Packet.capture(world).is_empty(),"Finite conserved complete paid state")

func _paid_cast(world: SimWorld) -> bool:
	var before := world.player().flux
	if not _step(world,SimCommand.PRESSED_SPELL_1): return false
	var actor := world.player()
	var context: Dictionary=witness.describe(world,actor)
	if not _check(actor.pending_cast_wire_id==MixtureCatalog.wire_for(2,"heavy") and actor.pending_cast_ticks>0
		and bool(context.get("known_total",false)) and before-actor.flux==int(CombatTuning.cast_definition_view(actor.pending_cast_wire_id).flux_cost)
		and int(world.hex_court.metrics.matter_paid)>0,"Actual paid admission and exact witnessed duration"): return false
	paid_sequences.append({"tick":world.tick,"flux_before":before,"flux_after":actor.flux,"context":context,
		"events":world.combat_events.duplicate(true),"matter_paid":world.hex_court.metrics.matter_paid})
	return true

func _viewport(board: Board) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1280,720);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport);viewport.add_child(board)
	return viewport

func _case(label: String,world: SimWorld,size: Vector2i,scale_factor: float=1.0,known: bool=true,layer: int=0,card: bool=false,pointer: Vector2=Vector2(-1000,-1000)) -> bool:
	var before := world.state_hash()
	var packet := var_to_bytes(Packet.capture(world))
	var events := var_to_bytes(world.combat_events)
	var context: Dictionary=witness.describe(world,world.player()) if known else {}
	if world.player().pending_cast_wire_id>0 and known:
		if not _check(bool(context.get("known_total",false)),"Paid observed context remains known"): return false
	if layer==1 and not _check(not CompactCombatHud.hidden_cast_status(world.player(),catalog,layer,preferences,120,context).is_empty(),"Actual hidden cast banner"): return false
	for board: Board in [plain,observed]:
		board.active=false;board.world=world;board.context=context.duplicate();board.scale_factor=scale_factor
		board.layer=layer;board.card_only=card;board.pointer=pointer
	plain_view.size=size;observed_view.size=size
	# Drain automatic viewport resize draws before measured queue-order checks.
	await process_frame;await process_frame;RenderingServer.force_draw(false)
	var prep_before := {"plain":plain.hud.preparation_stats(),"observed":observed.hud.preparation_stats()}
	for board: Board in [plain,observed]: board.active=true
	var warmups: Array[Dictionary]=[]
	var rows: Array[Dictionary]=[]
	for index: int in PAIRS+WARMUPS:
		trace.clear()
		var serial_plain := plain.serial
		var serial_observed := observed.serial
		var observed_first := (index%2==0)!=reverse_order
		var first: Board=observed if observed_first else plain
		var second: Board=plain if observed_first else observed
		root.move_child(observed_view if observed_first else plain_view,0)
		first.queue_redraw();second.queue_redraw()
		await process_frame;await process_frame;RenderingServer.force_draw(false)
		var expected: Array=[first.role,second.role]
		if not _check(plain.serial==serial_plain+1 and observed.serial==serial_observed+1 and trace==expected,"Actual paired callback count/order: "+label): return false
		if not _check(bool(plain.last.authority_unchanged) and bool(observed.last.authority_unchanged) and world.state_hash()==before,"Draws preserve actual paid authority"): return false
		var panel: Dictionary=observed.last.panel
		if not _check(int(panel.panels)>0 and int(panel.panels)==int(panel.mesh_fills)+int(panel.polygon_fills)
			and int(panel.panels)==int(panel.outlines),"Every real panel submits one fill and outline"): return false
		var row := {"index":index,"actual_order":trace.duplicate(),"plain":plain.last.duplicate(true),"observed":observed.last.duplicate(true)}
		if index<WARMUPS: warmups.append(row)
		else: rows.append(row)
		if index==0 and not _pixels_equal(size): return false
	if not _check(var_to_bytes(Packet.capture(world))==packet and var_to_bytes(world.combat_events)==events,"Draw sequence preserves packet and events"): return false
	if not _check(plain.hud.preparation_stats()==observed.hud.preparation_stats(),"Observer preserves production cache/build counts"): return false
	if not _pixels_equal(size): return false
	var images := {}
	for role: String in ["plain","observed"]:
		var pixels: Image=(plain_view if role=="plain" else observed_view).get_texture().get_image()
		pixels.convert(Image.FORMAT_RGBA8)
		var path := output.path_join(label+"-"+role+".png")
		if not _check(pixels.save_png(path)==OK,"Saved representative PNG"): return false
		images[role]={"path":path,"sha256":FileAccess.get_sha256(path)}
	results.append({"label":label,"physical_size":[size.x,size.y],"scale":scale_factor,"isolated_card":card,
		"layer":layer,"context":context,"tick":world.tick,"pending_ticks":world.player().pending_cast_ticks,
		"state_hash":before,"exact_rgba_cold_and_final":true,"warmups":warmups,"rows":rows,"images":images,
		"preparation_before":prep_before,"preparation_after":{"plain":plain.hud.preparation_stats(),"observed":observed.hud.preparation_stats()}})
	return true

func _pixels_equal(size: Vector2i) -> bool:
	var a := plain_view.get_texture().get_image()
	var b := observed_view.get_texture().get_image()
	if not _check(a!=null and b!=null,"Native images exist"): return false
	a.convert(Image.FORMAT_RGBA8);b.convert(Image.FORMAT_RGBA8)
	if not _check(a.get_size()==size and b.get_size()==size and a.get_data()==b.get_data(),"Plain/observed exact RGBA and physical size"): return false
	var non_background := 0
	for y: int in range(0,size.y,8):
		for x: int in range(0,size.x,8):
			if a.get_pixel(x,y).to_rgba32()!=Color("283e37").to_rgba32(): non_background+=1
	return _check(non_background>16,"Actual nonblank HUD pixels beyond background")

func _check(condition: bool,message: String) -> bool:
	checks+=1
	if not condition: errors.append(message)
	return condition

func _finish() -> void:
	if finished: return
	finished=true
	var record := {"schema":"hex.hud.panel-attribution.v1","passed":errors.is_empty() and results.size()==10,
		"engine":Engine.get_version_info(),"source_hashes":hashes,"checks":checks,"errors":errors,
		"cases":results,"paid_sequences":paid_sequences,"measured_pairs_per_case":PAIRS,"warmups_per_case":WARMUPS,"reverse_order":reverse_order,
		"scope":"Offscreen native SubViewport submission of current complete HUD or explicitly isolated 200% card; shared frozen real paid actor, actual admission witness and honest unknown fallback. Draw callbacks alternate with observed execution order; first/final pixels match. No render-window focus, Bootstrap overlap, GPU, wall-frame, FPS, input, whole200%layout or human readability qualification. Content construction, context/capacity/gate preparation, hashes, packet capture and image readback are outside submission clocks. No application boot, save, LAN or authority writes.",
		"attribution":"Fixed timers partition panel geometry, fill color, fill submission, outline color and outline submission. Their intervals are disjoint but nested inside panel total and complete HUD duration: never add buckets to those parent totals. Parent totals include instrumentation; plain/observed difference and actual-order strata disclose observer overhead. Existing fill/shape cache is shared production behavior; no outline optimization is implemented.",
		"boundedness":"10 cases x(32 measured+4 warmup) paired callbacks; two SubViewports at most1280x720,20savedPNGs. Authority progresses only between declared cases via ordinary finite paid commands; no mid-route resource/status/timer injection."}
	if not output.is_empty() and DirAccess.dir_exists_absolute(output):
		var file := FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
		if file!=null:
			var encoded := JSON.stringify(record,"\t")+"\n"
			file.store_string(encoded);file.flush();var error := file.get_error();file.close()
			if error!=OK or FileAccess.get_file_as_string(output.path_join("receipt.json"))!=encoded:
				errors.append("Receipt write/readback failed")
		else: errors.append("Receipt open failed")
	if bool(record.passed) and errors.is_empty(): print("HUD_PANEL_ATTRIBUTION_PASS checks=",checks," cases=",results.size());quit(0)
	else: printerr("HUD_PANEL_ATTRIBUTION_FAILED: ",errors);quit(1)
