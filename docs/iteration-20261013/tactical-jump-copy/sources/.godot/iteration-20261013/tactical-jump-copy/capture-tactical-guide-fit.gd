extends SceneTree
## Four guide-only native fit contexts; no gameplay or performance claim.
const ROOT := "res://.godot/iteration-20261013/tactical-jump-copy/"
const Guide = preload("res://.godot/iteration-20261013/tactical-jump-copy/native/optional_introduction.gd")
const Bootstrap = preload("res://src/app/bootstrap.gd")
const Bindings = preload("res://src/presentation/spell_binding_labels.gd")
const WATCHED: Array[String] = [
	ROOT+"capture-tactical-guide-fit.gd",ROOT+"manifest.json",ROOT+"tactical-jump-copy.patch",
	ROOT+"native/optional_introduction.gd",ROOT+"before/src/app/optional_introduction.gd",ROOT+"proposed/src/app/optional_introduction.gd",
	"res://src/app/optional_introduction.gd","res://src/app/bootstrap.gd","res://src/app/player_preferences.gd",
	"res://src/presentation/spell_binding_labels.gd","res://src/presentation/spell_testing_panel.gd",
	"res://src/sim/core/sim_world.gd","res://src/sim/core/sim_config.gd",
	"res://content/abilities/foundation_abilities_v1.json","res://content/runtime/runtime_build_identity_v1.json",
]
class Board:
	extends Node2D
	var guide = Guide.new()
	var world := SimWorld.new()
	var scale_value := 1.0
	var active := false
	var draws := 0
	var pure := true
	func _draw() -> void:
		draw_rect(get_viewport_rect(),Color("283e37"))
		if not active: return
		var before := world.state_hash()
		draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE*scale_value)
		guide.draw(self,ThemeDB.fallback_font,get_viewport_rect().size/scale_value)
		draw_set_transform(Vector2.ZERO)
		pure=pure and before==world.state_hash()
		draws+=1

var output := ""
var output_authorized := false
var finished := false
var checks := 0
var errors: Array[String] = []
var sources: Dictionary = {}
var cases: Array[Dictionary] = []
var board: Board
var view: SubViewport
var original_mouse := Input.MOUSE_MODE_VISIBLE

func _initialize() -> void:
	original_mouse=Input.mouse_mode
	_run.call_deferred()

func check(okay: bool, message: String) -> bool:
	checks+=1
	if not okay: errors.append(message)
	return okay

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if not check(DisplayServer.get_name()!="headless" and OS.get_cmdline_user_args().has("--no-lan-discovery") and output.get_base_dir()==ROOT+"runs" and output.get_file().begins_with("fit-") and output.get_file().is_valid_filename() and not output.contains("..") and not output.contains("\\") and not FileAccess.file_exists(output) and not DirAccess.dir_exists_absolute(output),"Fresh owned native output required"): _finish(); return
	if not check(DirAccess.make_dir_recursive_absolute(output)==OK,"Owned output created"): _finish(); return
	output_authorized=true
	for path: String in WATCHED:
		sources[path]=FileAccess.get_sha256(path)
		if not check(String(sources[path]).length()==64,"Watched input exists: "+path): _finish(); return
	var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
	if not check(manifest is Dictionary and FileAccess.get_sha256(ROOT+"tactical-jump-copy.patch")==manifest.patch_sha256 and FileAccess.get_sha256("res://"+String(manifest.path))==manifest.before_sha256 and FileAccess.get_sha256(ROOT+"before/"+String(manifest.path))==manifest.before_sha256 and FileAccess.get_sha256(ROOT+"proposed/"+String(manifest.path))==manifest.proposed_sha256,"Exact unapplied one-literal proposal"): _finish(); return
	var before := FileAccess.get_file_as_string(ROOT+"before/src/app/optional_introduction.gd")
	var proposed := FileAccess.get_file_as_string(ROOT+"proposed/src/app/optional_introduction.gd")
	if not check(proposed.replace("then press and release %s to jump.","then release %s to jump.")==before,"Only omitted press gesture changes"): _finish(); return
	if not check(FileAccess.get_file_as_string(ROOT+"native/optional_introduction.gd")==proposed.replace("class_name OptionalIntroduction\n","").replace("class_name OptionalIntroduction\r\n",""),"Native adapter removes only global class registration"): _finish(); return
	var catalog := AbilityCatalog.new()
	if not check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"),"Actual ability catalog loads"): _finish(); return
	board=Board.new()
	view=SubViewport.new();view.size=Vector2i(1280,720);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view);view.add_child(board)
	create_timer(90).timeout.connect(func()->void:
		if not finished: errors.append("Native guide watchdog expired"); _finish())
	for size: Vector2i in [Vector2i(960,540),Vector2i(1280,720)]:
		for percent: int in [100,200]:
			if not await _case(size,percent): _finish(); return
	_finish()

func _case(size: Vector2i, percent: int) -> bool:
	board.active=false
	view.size=size
	var preferences := PlayerPreferences.new()
	preferences.ui_text_percent=percent
	var jump := Bindings.action_label(&"jump",preferences)
	board.guide.configure_bindings({"jump":jump if not jump.is_empty() else "Jump (unbound)"})
	if not check(board.guide.start_tactical(board.world),"Public independent tactical entry starts without assigned progress"): return false
	board.scale_value=Bootstrap.ui_scale_for(Vector2(size))*float(percent)/100.0
	var logical := Vector2(size)/board.scale_value
	var font := ThemeDB.fallback_font
	var data: Dictionary=board.guide.view()
	var geometry: Dictionary=board.guide.geometry(logical,font)
	var box: Rect2=geometry.box
	var lines: Array[String]=board.guide.body_lines(font,logical)
	var widths: Array[float]=[]
	check(String(data.instruction)=="Sprint, Slide, then press and release %s to jump. Watch the Stamina cost." % (jump if not jump.is_empty() else "Jump (unbound)"),"Current bound Jump label and exact instruction")
	check(Rect2(Vector2.ZERO,logical).encloses(box),"Actual wrapped panel fits logical viewport")
	check(font.get_string_size("1/4  "+String(data.title),HORIZONTAL_ALIGNMENT_LEFT,-1,15).x<=box.size.x-24,"Actual unchanged title fits draw width")
	for key: String in ["skip","details"]: check(box.encloses(geometry[key]),"Existing pointer geometry stays inside panel: "+key)
	if logical.x<900: check(not Rect2(geometry.skip).intersects(geometry.details),"Visible Skip and Details controls do not overlap")
	for line: String in lines:
		widths.append(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x)
		check(widths.back()<=box.size.x-24,"Actual wrapped line fits existing draw width")
	check(box.position.y+46+(lines.size()-1)*18+font.get_descent(12)<=Rect2(geometry.skip).position.y-8,"Final body ink clears reserved action row")
	if not errors.is_empty(): return false
	var before := board.world.state_hash()
	var draws_before := board.draws
	board.active=true;board.queue_redraw()
	await process_frame;await process_frame;RenderingServer.force_draw(false)
	if finished: return false
	check(board.draws>draws_before and board.pure and board.world.state_hash()==before,"Actual guide draw preserves world and uses current geometry")
	var pixels := view.get_texture().get_image()
	if not check(pixels!=null and not pixels.is_empty() and pixels.get_size()==size,"Native pixels exist at exact physical size"): return false
	pixels.convert(Image.FORMAT_RGBA8)
	var path := output.path_join("guide-%d-%d.png" % [size.x,percent])
	if not check(pixels.save_png(path)==OK,"Owned native PNG saves"): return false
	cases.append({"physical_size":[size.x,size.y],"text_percent":percent,"scale":board.scale_value,"logical_size":[logical.x,logical.y],"instruction":data.instruction,"title":data.title,"lines":lines,"line_widths":widths,"line_limit":box.size.x-24,"box":[box.position.x,box.position.y,box.size.x,box.size.y],"skip":[geometry.skip.position.x,geometry.skip.position.y,geometry.skip.size.x,geometry.skip.size.y],"details":[geometry.details.position.x,geometry.details.position.y,geometry.details.size.x,geometry.details.size.y],"world_hash":before,"png":path,"png_sha256":FileAccess.get_sha256(path)})
	board.active=false
	return errors.is_empty()

func _finish() -> void:
	if finished: return
	finished=true
	for path: String in sources: check(FileAccess.get_sha256(path)==sources[path],"Watched source unchanged: "+path)
	check(Input.mouse_mode==original_mouse,"No global mouse mutation")
	if is_instance_valid(view): view.free();view=null;board=null
	var record := {"schema":"hex.tactical-guide-fit.native.v1","passed":errors.is_empty() and cases.size()==4,"checks":checks,"errors":errors,"source_hashes":sources,"cases":cases,"png_count":cases.size(),"scope":"Offscreen native guide-only SubViewport, exact proposed one-literal text with production ui_scale/wrap/draw/buttons. Public start_tactical on a valid prepared world, no command sampling or lesson advancement. Four default keyboard-label contexts; no full HUD/boot/physical input/movement/accessibility certification/performance claim. No InputMap/profile mutation."}
	if output_authorized:
		var encoded := JSON.stringify(record,"\t")+"\n"
		var path := output.path_join("receipt.json")
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file==null: errors.append("Receipt open failed")
		else:
			file.store_string(encoded);file.close()
			if FileAccess.get_file_as_string(path)!=encoded: errors.append("Receipt readback differs")
	var passed: bool=bool(record.passed) and errors.is_empty()
	print("PASS tactical guide fit: %d checks,4contexts,4PNG" % checks if passed else "FAIL: "+JSON.stringify(errors))
	quit(0 if passed else 1)

func _finalize() -> void:
	if not finished: errors.append("Unexpected enclosing quit before native fit completed"); _finish()
