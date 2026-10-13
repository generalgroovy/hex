extends SceneTree
## Prepared compatibility controls only. Ordinary paid coverage is a separate gate.
const Reference = preload("res://src/presentation/hex_court_presenter.gd")
const Candidate = preload("res://.godot/iteration-20261013/occupied-render-membership/candidate_court.gd")
const Grid = preload("res://src/sim/hex/hex_grid.gd")
const Quality = preload("res://src/presentation/render_quality.gd")
const ROOT := "res://.godot/iteration-20261013/occupied-render-membership/"
const PINS := ROOT + "functional-source-pins.json"
const SIZE := Vector2i(480,360)
const BACKGROUND := Color("283e37")
const TICK := 50.25
const EXPECTED_CASES := 10

class DerivedCourt:
	extends HexChemistryWorld
	func view(cell: Vector2i, tick: float) -> Dictionary:
		var result := super.view(cell,tick)
		result["derived_marker"]="actual override"
		return result

class GenericCourt:
	extends RefCounted
	var cells := {Vector2i.ZERO:{}}
	var origin := Vector2i(240000,180000)
	var render_revision := 1
	func view(_cell: Vector2i,_tick: float) -> Dictionary:
		return {"fire_phase":"none","steam_heat":1000,"water_quantity":3,"water_present":true}
	func render_regions(cell: Vector2i, material: String,_tick: float) -> Array:
		if cell!=Vector2i.ZERO or material!="water": return []
		var polygon := PackedVector2Array()
		for point: Vector2i in Grid.vertices(cell): polygon.append(Vector2(point+origin))
		return [{"footprint_id":41,"polygon":polygon,"phase":"active","danger":false,
			"intensity":1000,"quantity":3,"owner":7,"source_ids":[91],"expiry_tick":200,
			"recipe_wire_id":0,"direction":Vector2i(0,-1000),"material":material}]

class BundleHook:
	extends RefCounted
	var entered := false
	var calls := 0
	var seen_tokens: Array[int] = []
	var nested_court: HexChemistryWorld
	var nested_result: Dictionary = {}
	func run(presenter: HexCourtPresenter,court: RefCounted,tick: float,candidate: bool) -> void:
		calls+=1
		seen_tokens.append(int(presenter.get("_prepared_occupied_court_id")) if candidate else 0)
		if entered: return
		entered=true
		(court as HexChemistryWorld).casts[11].coverage={}
		nested_result=presenter._prepare_draw_bundle(nested_court,tick)
		entered=false

class ReferenceDerived:
	extends HexCourtPresenter
	var hook := BundleHook.new()
	func _prepare_draw_bundle(court: RefCounted,tick: float) -> Dictionary:
		hook.run(self,court,tick,false)
		return super._prepare_draw_bundle(court,tick)

class CandidateDerived:
	extends "res://.godot/iteration-20261013/occupied-render-membership/candidate_court.gd"
	var hook := BundleHook.new()
	func _prepare_draw_bundle(court: RefCounted,tick: float) -> Dictionary:
		hook.run(self,court,tick,true)
		return super._prepare_draw_bundle(court,tick)

class Board:
	extends Node2D
	var presenter: HexCourtPresenter
	var court: RefCounted
	var other: HexChemistryWorld
	var active := false
	var base := false
	var reduced := false
	var callback_mutates := false
	var callback_armed := false
	var callback_count := 0
	var callback_nested: Dictionary = {}
	var callback_tokens: Array[int] = []
	var candidate := false
	var serial := 0
	var okay := false
	var view := Rect2(0,0,480,360)
	var before: PackedByteArray
	var after: PackedByteArray
	var before_token := 0
	var after_token := 0
	func on_property_list_changed() -> void:
		if not callback_armed: return
		callback_count+=1
		callback_tokens.append(int(presenter.get("_prepared_occupied_court_id")) if candidate else 0)
		if callback_mutates:
			callback_armed=false
			(court as HexChemistryWorld).casts[11].coverage={}
			callback_nested=presenter._prepare_draw_bundle(other,TICK)
	func _draw() -> void:
		serial+=1
		draw_rect(Rect2(Vector2.ZERO,SIZE),BACKGROUND)
		if not active: return
		before=authority_bytes(court)
		before_token=int(presenter.get("_prepared_occupied_court_id")) if candidate else 0
		okay=presenter.draw_ground_in_view(self,court,TICK,reduced,base,view)
		after_token=int(presenter.get("_prepared_occupied_court_id")) if candidate else 0
		after=authority_bytes(court)
	static func authority_bytes(value: RefCounted) -> PackedByteArray:
		if value is HexChemistryWorld:
			var world: HexChemistryWorld=value
			return var_to_bytes([world.cells,world.casts,world.products,world.origin,world.current_tick,world.render_revision,world.metrics])
		return var_to_bytes([value.get("cells"),value.get("origin"),value.get("render_revision")])

var output := ""
var output_authorized := false
var finished := false
var checks := 0
var errors: Array[String] = []
var cases: Array[Dictionary] = []
var images: Array[Dictionary] = []
var hashes: Dictionary = {}
var pins_sha256 := ""
var viewports_created := 0
var viewports_freed := 0
var language := VisualLanguage.new()
var a: Board
var b: Board
var av: SubViewport
var bv: SubViewport

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	var prefix := ROOT+"runs/verify-"
	var suffix := output.trim_prefix(prefix)
	if not _check(DisplayServer.get_name()!="headless" and OS.get_cmdline_user_args().has("--no-lan-discovery")
		and output.begins_with(prefix) and not suffix.is_empty() and not "/" in suffix and not "\\" in suffix and not ".." in suffix
		and not FileAccess.file_exists(output) and not DirAccess.dir_exists_absolute(output),"Fresh one-child owned native output/no LAN"): _finish();return
	if not _check(DirAccess.make_dir_recursive_absolute(output)==OK,"Create fresh owned output"): _finish();return
	output_authorized=true
	pins_sha256=FileAccess.get_sha256(PINS)
	var pins: Variant=JSON.parse_string(FileAccess.get_file_as_string(PINS))
	if not _check(pins is Dictionary and pins.get("source_hashes") is Dictionary,"Read exact functional source pins"): _finish();return
	hashes=pins.source_hashes.duplicate()
	for path: String in hashes:
		if not _check(FileAccess.get_sha256(path)==String(hashes[path]) and String(hashes[path]).length()==64,"Current source pin: "+path): _finish();return
	if not _check(FileAccess.get_sha256("res://src/presentation/hex_court_presenter.gd")=="3190aa2683205bfdd1ebcc297e1002b3f3e624e4b59a61ecf64b76889733b92c"
		and FileAccess.get_sha256(ROOT+"candidate_court.gd")=="22376c664780c244249dc0ed5285d67cd0d677e7f69151e594845dfa2a67da6a","Exact reviewed predecessor/candidate"): _finish();return
	if not _check(language.load_from_file() and Quality.set_profile("low"),"Actual visual language and low quality admitted"): _finish();return
	create_timer(120).timeout.connect(func() -> void:
		if not finished: errors.append("120-second functional watchdog expired");_finish())
	if not _direct_controls(): _finish();return
	var labels: Array[String]=["exact_nonbase","compatibility_court","standalone_base","missing_aggregate","generic","derived_court","derived_presenter_reentry","changed_filter_callback","same_count_mutations"]
	for label: String in labels:
		if not await _native_case(label): _finish();return
	for path: String in hashes:
		if not _check(FileAccess.get_sha256(path)==String(hashes[path]),"Source unchanged: "+path): _finish();return
	_finish()

func _court(kind: String="exact",product: bool=false) -> HexChemistryWorld:
	var result: HexChemistryWorld
	if kind=="compatibility": result=HexCourt.new()
	elif kind=="derived": result=DerivedCourt.new()
	else: result=HexChemistryWorld.new()
	var cells: Array[Vector2i]=[Vector2i.ZERO,Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP]
	if not _check(result.configure_geometry(Vector2i(240000,180000),cells),"Independent prepared court geometry"): return null
	_install(result,Vector2i.ZERO,Vector2i.RIGHT,product)
	return result

func _install(court: HexChemistryWorld,cast_cell: Vector2i,product_cell: Vector2i,product: bool) -> void:
	# Direct renderer fixture, explicitly not a complete paid simulation ledger.
	for cell: Vector2i in court.cells:
		court.cells[cell].erase("fire");court.cells[cell].erase("steam")
	court.casts[11]={"owner":2,"source":101,"aim":Vector2i(1000,0),"coverage":{cast_cell:1},"ground_parts":{
		301:{"created":0,"expiry_tick":200,"coverage":{cast_cell:1},"cells":{cast_cell:12}}}}
	court.cells[cast_cell].fire={11:12}
	court.products.clear()
	if product:
		court.products[21]={"active_tick":20,"decay_tick":120,"expiry_tick":200,"intensity":1400,
			"coverage":{product_cell:1},"cells":{product_cell:5},"owner":4,"source_ids":[101,102],
			"recipe_wire_id":310,"flow_aim":Vector2i(0,-1000),"damage_budget_remaining":100}
		court.cells[product_cell].steam={21:5}

func _presenter(candidate: bool,derived: bool=false) -> HexCourtPresenter:
	var result: HexCourtPresenter
	if derived:
		if candidate: result=CandidateDerived.new()
		else: result=ReferenceDerived.new()
	else:
		if candidate: result=Candidate.new()
		else: result=Reference.new()
	if not _check(result.configure(language) and int(result.material_surface.stats().textures)>0 and result.water_material.ready(),"Configure actual presenter with admitted material banks"): return null
	return result

func _direct_controls() -> bool:
	var left := _court();var right := _court()
	var plain := _presenter(false);var trial := _presenter(true)
	if left==null or right==null or plain==null or trial==null: return false
	for presenter: HexCourtPresenter in [plain,trial]:
		if not _check(presenter._prepare_court(left if presenter==plain else right,true),"Direct helper starts with complete prepared floor"): return false
	var original: Dictionary=plain._prepare_draw_bundle(left,TICK)
	if not _check(var_to_bytes(original)==var_to_bytes(trial._prepare_draw_bundle(right,TICK)) and original.views.size()==1,"Direct helper baseline exact one live cell"): return false
	left.casts[11].coverage={};right.casts[11].coverage={}
	var before_left := Board.authority_bytes(left);var before_right := Board.authority_bytes(right)
	var removed: Dictionary=plain._prepare_draw_bundle(left,TICK)
	if not _check(removed.views.is_empty() and var_to_bytes(removed)==var_to_bytes(trial._prepare_draw_bundle(right,TICK)),"Direct call freshly sees removed coverage despite raw ground and old prepared floor"): return false
	if not _check(Board.authority_bytes(left)==before_left and Board.authority_bytes(right)==before_right and int(trial.get("_prepared_occupied_court_id"))==0,"Direct query is source-pure and leaves no token"): return false
	_install(left,Vector2i.RIGHT,Vector2i.ZERO,false);_install(right,Vector2i.RIGHT,Vector2i.ZERO,false)
	var replaced: Dictionary=plain._prepare_draw_bundle(left,TICK)
	if not _check(replaced.views.keys()==[Vector2i.RIGHT] and var_to_bytes(replaced)==var_to_bytes(trial._prepare_draw_bundle(right,TICK)),"Direct query observes replacement without reprepare/revision change"): return false
	var detached: Dictionary=trial._prepare_draw_bundle(right,TICK)
	detached.views.clear()
	if not _check(var_to_bytes(trial._prepare_draw_bundle(right,TICK))==var_to_bytes(replaced),"Returned bundle does not alias subsequent output"): return false
	cases.append({"label":"direct_helper_refresh","prepared_control":true,"exact_bundle_bytes":true,"no_simulation_or_payment_claim":true})
	return true

func _viewport(board: Board) -> SubViewport:
	var result := SubViewport.new();result.size=SIZE;result.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(result);result.add_child(board)
	viewports_created+=1
	return result

func _native_case(label: String) -> bool:
	a=Board.new();b=Board.new();b.candidate=true
	var derived := label=="derived_presenter_reentry"
	a.presenter=_presenter(false,derived);b.presenter=_presenter(true,derived)
	if a.presenter==null or b.presenter==null: return false
	for board: Board in [a,b]:
		if label=="generic": board.court=GenericCourt.new()
		else:
			board.court=_court("compatibility" if label=="compatibility_court" else "derived" if label=="derived_court" else "exact",label=="same_count_mutations")
		if board.court==null: return false
		board.base=label in ["standalone_base","missing_aggregate"]
		if label=="missing_aggregate": (board.court as HexChemistryWorld).casts[11].erase("coverage")
		board.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR if label=="changed_filter_callback" else CanvasItem.TEXTURE_FILTER_NEAREST
		board.property_list_changed.connect(board.on_property_list_changed)
		board.callback_mutates=label=="changed_filter_callback"
		board.other=_court()
		if derived:
			var hook: BundleHook=board.presenter.get("hook")
			hook.nested_court=board.other
	if label=="exact_nonbase": b.presenter.set("_prepared_occupied_court_id",-777)
	av=_viewport(a);bv=_viewport(b)
	await process_frame
	if finished: return false
	await process_frame
	if finished: return false
	RenderingServer.force_draw(false)
	var rows: Array[Dictionary]=[]
	var previous_pixels := PackedByteArray()
	var stages := 3 if label=="same_count_mutations" else 1
	for stage: int in stages:
		if stage>0:
			for board: Board in [a,b]:
				var world: HexChemistryWorld=board.court
				var revision := world.render_revision
				_install(world,Vector2i.LEFT,Vector2i.UP,true)
				if stage==2:
					world.origin+=Vector2i(19000,7000)
					world.products[21].owner=9;world.products[21].source_ids=[909]
					board.view=Rect2(200,100,280,260)
					board.reduced=true
				if not _check(world.render_revision==revision and world.occupied_cells().size()==2,"Prepared same-count mutation bypasses revision but preserves finite two-cell membership"): return false
		var before_a := a.serial;var before_b := b.serial
		for board: Board in [a,b]: board.active=true;board.callback_armed=stage==0
		a.queue_redraw();b.queue_redraw()
		await process_frame
		if finished: return false
		await process_frame
		if finished: return false
		RenderingServer.force_draw(false)
		for board: Board in [a,b]: board.active=false;board.callback_armed=false
		if not _check(a.serial==before_a+1 and b.serial==before_b+1 and a.okay and b.okay,"Exactly one successful actual paired native draw: "+label): return false
		if not _check(a.before==b.before and a.after==b.after,"Independent courts have identical pre/post source bytes: "+label): return false
		var mutates := label in ["derived_presenter_reentry","changed_filter_callback"]
		if not _check((a.before!=a.after)==mutates and (b.before!=b.after)==mutates,"Only declared callback/override mutates prepared authority: "+label): return false
		if not _check(b.before_token==b.after_token and b.presenter._visible_rect==Rect2(),"Scoped token and visible rectangle restore after actual draw: "+label): return false
		var img_a := av.get_texture().get_image();var img_b := bv.get_texture().get_image()
		if not _check(img_a!=null and img_b!=null,"Actual images available"): return false
		img_a.convert(Image.FORMAT_RGBA8);img_b.convert(Image.FORMAT_RGBA8)
		if not _check(img_a.get_size()==SIZE and img_b.get_size()==SIZE and img_a.get_data()==img_b.get_data(),"Exact independent RGBA: "+label): return false
		if label=="same_count_mutations":
			if not _check(stage==0 or img_a.get_data()!=previous_pixels,"Direct same-count/origin/style mutation visibly changes the reference image"): return false
			previous_pixels=img_a.get_data()
		var ink := 0
		for y: int in range(0,SIZE.y,2):
			for x: int in range(0,SIZE.x,2):
				if img_a.get_pixel(x,y).to_rgba32()!=BACKGROUND.to_rgba32(): ink+=1
		if not _check((ink==0) if mutates else (ink>4),"Expected removed-field blank versus visible material/base positive: "+label): return false
		for role: String in ["reference","candidate"]:
			var path := output.path_join(label+"_"+str(stage)+"_"+role+".png")
			if not _check((img_a if role=="reference" else img_b).save_png(path)==OK,"Save bounded native witness"): return false
			images.append({"path":path,"sha256":FileAccess.get_sha256(path)})
		rows.append({"stage":stage,"source_before_sha256":a.before.hex_encode().sha256_text(),"source_after_sha256":a.after.hex_encode().sha256_text(),
			"ink_samples":ink,"exact_rgba":true,"token_before":b.before_token,"token_after":b.after_token,
			"reference_callbacks":a.callback_count,"candidate_callbacks":b.callback_count,"reduced":a.reduced})
	if label=="changed_filter_callback":
		if not _check(a.callback_count==1 and b.callback_count==1 and b.callback_tokens==[0],"Actual changed native setter fired one callback with no active membership token"): return false
		if not _check(not a.callback_nested.views.is_empty() and var_to_bytes(a.callback_nested)==var_to_bytes(b.callback_nested),"Callback reentry reads the independent other court exactly"): return false
	else:
		if not _check(a.callback_count==0 and b.callback_count==0,"Already-NEAREST setter has no synthetic callback: "+label): return false
	if derived:
		var ah: BundleHook=a.presenter.get("hook");var bh: BundleHook=b.presenter.get("hook")
		if not _check(ah.calls==2 and bh.calls==2 and bh.seen_tokens==[0,0] and not ah.nested_result.views.is_empty()
			and var_to_bytes(ah.nested_result)==var_to_bytes(bh.nested_result),"Derived virtual mutation/reentry stays on exact predecessor path"): return false
	if label=="derived_court":
		var ar := a.presenter._prepare_draw_bundle(a.court,TICK);var br := b.presenter._prepare_draw_bundle(b.court,TICK)
		if not _check(ar.views[Vector2i.ZERO].derived_marker=="actual override" and var_to_bytes(ar)==var_to_bytes(br),"Arbitrary court override remains visible"): return false
	if label=="standalone_base":
		if not _check(a.presenter._cells.size()==4 and b.presenter._cells.size()==4,"Standalone base retains all eligible floor membership"): return false
	if label=="missing_aggregate":
		if not _check(a.presenter._prepare_draw_bundle(a.court,TICK).views.size()==4
			and var_to_bytes(a.presenter._prepare_draw_bundle(a.court,TICK))==var_to_bytes(b.presenter._prepare_draw_bundle(b.court,TICK)),"Missing aggregate keeps complete prepared floor fallback"): return false
	if label=="exact_nonbase": b.presenter.set("_prepared_occupied_court_id",0)
	cases.append({"label":label,"prepared_control":true,"rows":rows,"no_simulation_or_payment_claim":true})
	_clear_views()
	return true

func _clear_views() -> void:
	if is_instance_valid(av): av.free();viewports_freed+=1
	elif is_instance_valid(a): a.free()
	if is_instance_valid(bv): bv.free();viewports_freed+=1
	elif is_instance_valid(b): b.free()
	av=null;bv=null;a=null;b=null

func _check(condition: bool,message: String) -> bool:
	checks+=1
	if not condition: errors.append(message)
	return condition

func _finish() -> void:
	if finished: return
	finished=true
	_clear_views()
	for path: String in hashes:
		_check(FileAccess.get_sha256(path)==String(hashes[path]),"Final source unchanged: "+path)
	if not pins_sha256.is_empty(): _check(FileAccess.get_sha256(PINS)==pins_sha256,"Source-pins file unchanged")
	var passed := errors.is_empty() and cases.size()==EXPECTED_CASES and images.size()==22 and viewports_created==18 and viewports_freed==18
	var receipt := {"schema":"hex.occupied-membership-contract.v1","passed":passed,"checks":checks,"errors":errors,
		"engine":Engine.get_version_info(),"source_hashes":hashes,"source_pins_sha256":pins_sha256,"cases":cases,"images":images,
		"cleanup":{"viewports_created":viewports_created,"viewports_freed":viewports_freed,"live_viewports":viewports_created-viewports_freed},
		"scope":"At most10 prepared compatibility cases, independent paired courts/native RGBA plus direct bundle bytes; no paid commands or complete simulation ledger. Separate22 ordinary paid cases own phase/payment/performance acceptance. No timing, foreground, physical input, FPS or human readability claim.",
		"bounds":"Two480x360 SubViewports;120-second watchdog;one direct case+nine native cases;11 paired native draws/22PNG;all callback mutations are declared prepared controls;no source edits."}
	if output_authorized:
		var path := output.path_join("receipt.json");var file := FileAccess.open(path,FileAccess.WRITE)
		if file!=null:
			var encoded := JSON.stringify(receipt,"\t")+"\n";file.store_string(encoded);file.flush();var error := file.get_error();file.close()
			if error!=OK or FileAccess.get_file_as_string(path)!=encoded: errors.append("Receipt write/readback failed")
		else: errors.append("Receipt open failed")
	if passed and errors.is_empty(): print("MEMBERSHIP_CONTRACT_PASS checks=",checks," cases=",cases.size());quit(0)
	else: printerr("MEMBERSHIP_CONTRACT_FAIL: ",errors);quit(1)
