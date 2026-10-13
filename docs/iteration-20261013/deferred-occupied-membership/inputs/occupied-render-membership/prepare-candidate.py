from pathlib import Path
import json, hashlib

repo=Path(__file__).resolve().parents[3]
base=Path(__file__).resolve().parent
source=repo/'src/presentation/hex_court_presenter.gd'
before=base/'hex_court_presenter.before.gd'
if not before.exists(): before.write_bytes(source.read_bytes())
assert before.read_bytes()==source.read_bytes()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def method(s,n):
    start=s.index('func '+n+'(');end=s.find('\nfunc ',start+1)
    return s[start:end if end>=0 else None].strip()
text=source.read_text(encoding='utf-8').replace('\r\n','\n')
old_draw=method(text,'draw_ground')
old_bundle=method(text,'_prepare_draw_bundle')
changes=[
 {'method':'draw_ground','old':'\tcanvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST',
  'new':'\t# A changed native setter can emit a synchronous property-list signal.\n\tvar occupied_filter_unchanged := canvas.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST\n\tcanvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST'},
 {'method':'draw_ground','old':'\tvar frame: Dictionary = _prepare_draw_bundle(court, tick)',
  'new':'\tvar previous_occupied_court_id := _prepared_occupied_court_id\n\t_prepared_occupied_court_id = int(court.get_instance_id()) if occupied_filter_unchanged and not draw_district_base and get_script().resource_path == OCCUPIED_MEMBERSHIP_SCRIPT_PATH and (court.get_script() == HexChemistryWorldScript or court.get_script() == HexCourtScript) else 0\n\tvar frame: Dictionary = _prepare_draw_bundle(court, tick)\n\t_prepared_occupied_court_id = previous_occupied_court_id'},
 {'method':'_prepare_draw_bundle','old':'func _prepare_draw_bundle(court: RefCounted, tick: float) -> Dictionary:\n\tvar previous := _compact_draw_bundle',
  'new':'func _prepare_draw_bundle(court: RefCounted, tick: float) -> Dictionary:\n\t# Consume before downstream virtual work; direct/nested calls get no token.\n\tvar prepared_occupied_court_id := _prepared_occupied_court_id\n\t_prepared_occupied_court_id = 0\n\tvar previous := _compact_draw_bundle'},
 {'method':'_prepare_draw_bundle','old':'\t\tif aggregate_coverage:',
  'new':'\t\tif aggregate_coverage and prepared_occupied_court_id != int(court.get_instance_id()):'}]
methods={'draw_ground':old_draw,'_prepare_draw_bundle':old_bundle}
for c in changes:
    assert methods[c['method']].count(c['old'])==1
    methods[c['method']]=methods[c['method']].replace(c['old'],c['new'])
header='''extends HexCourtPresenter
## Ignored same-call membership reuse; derived presenters retain the old path.
const OCCUPIED_MEMBERSHIP_SCRIPT_PATH := "res://.godot/iteration-20261013/occupied-render-membership/candidate_court.gd"
var _prepared_occupied_court_id: int = 0

'''
(base/'candidate-header.txt').write_text(header,encoding='utf-8',newline='\n')
(base/'transformations.json').write_text(json.dumps(changes,indent=2)+'\n',encoding='utf-8',newline='\n')
(base/'candidate_court.gd').write_text(header+methods['draw_ground']+'\n\n'+methods['_prepare_draw_bundle']+'\n',encoding='utf-8',newline='\n')

reference=repo/'.godot/iteration-20261013/prefix-key-shape/compare-prefix-key-shape.gd'
driver=reference.read_text(encoding='utf-8').replace('\r\n','\n')
driver=driver.replace('prefix-key-shape','occupied-render-membership').replace('compare-prefix-key-shape','compare-occupied-membership')
# The generic path replacement above affects the filename first.
driver=driver.replace('compare-occupied-render-membership','compare-occupied-membership')
driver=driver.replace('## Ignored key-shape experiment. Pristine whole-draw timers; no nested attribution.',
 '## Ignored same-call occupied membership experiment. Pristine whole-draw timers.')
driver=driver.replace('"res://.godot/iteration-20261013/occupied-render-membership/original-key.txt", "res://.godot/iteration-20261013/occupied-render-membership/replacement-key.txt",',
 '"res://.godot/iteration-20261013/occupied-render-membership/transformations.json", "res://.godot/iteration-20261013/occupied-render-membership/candidate-header.txt",\n\t"res://.godot/iteration-20261013/prefix-key-shape/compare-prefix-key-shape.gd",')
driver=driver.replace('var prefix_contract_checks := 0\n','')
driver=driver.replace('const WATCHED :=', 'const TRANSFORM_SHA := "'+sha(base/'transformations.json')+'"\nconst HEADER_SHA := "'+sha(base/'candidate-header.txt')+'"\nconst WATCHED :=')
driver=driver.replace('"res://src/content/runtime_build_identity.gd",', '"res://src/content/runtime_build_identity.gd", "res://content/runtime/runtime_build_identity_v1.json",')
driver=driver.replace('\tvar before_prefix_checks := checks\n\tif not _prefix_contract(): _finish();return\n\tprefix_contract_checks=checks-before_prefix_checks\n','')
start=driver.index('func _source_guard()');end=driver.index('func _world(')
guard='''func _source_guard() -> bool:
	if not _check(FileAccess.get_sha256(BEFORE)==BEFORE_SHA and FileAccess.get_sha256("res://src/presentation/hex_court_presenter.gd")==BEFORE_SHA,"Exact unchanged production predecessor"): return false
	if not _check(FileAccess.get_sha256("res://.godot/iteration-20261013/occupied-render-membership/transformations.json")==TRANSFORM_SHA and FileAccess.get_sha256("res://.godot/iteration-20261013/occupied-render-membership/candidate-header.txt")==HEADER_SHA,"Exact reviewed transformation and gate declarations"): return false
	var original := FileAccess.get_file_as_string(BEFORE).replace("\\r\\n","\\n")
	var actual := FileAccess.get_file_as_string("res://.godot/iteration-20261013/occupied-render-membership/candidate_court.gd").replace("\\r\\n","\\n")
	var changes: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/iteration-20261013/occupied-render-membership/transformations.json"))
	if not _check(changes is Array and changes.size()==4,"Exactly four declared surgical insertions/replacements"): return false
	var methods := {"draw_ground":_method(original,"draw_ground"),"_prepare_draw_bundle":_method(original,"_prepare_draw_bundle")}
	for change: Dictionary in changes:
		var name := String(change.method)
		if not _check(methods.has(name) and String(methods[name]).count(String(change.old))==1,"Each exact predecessor edit occurs once"): return false
		methods[name]=String(methods[name]).replace(String(change.old),String(change.new))
	var header := FileAccess.get_file_as_string("res://.godot/iteration-20261013/occupied-render-membership/candidate-header.txt")
	if not _check(actual==header+String(methods.draw_ground)+"\\n\\n"+String(methods._prepare_draw_bundle)+"\\n","Candidate consists only of two guarded methods and scalar scope/path declarations"): return false
	var prior := FileAccess.get_file_as_string("res://.godot/iteration-20261013/prefix-key-shape/compare-prefix-key-shape.gd").replace("\\r\\n","\\n")
	var current := FileAccess.get_file_as_string("res://.godot/iteration-20261013/occupied-render-membership/compare-occupied-membership.gd").replace("\\r\\n","\\n")
	for name: String in ["_world","_ready","_step","_record","_empty","_coverage","_capture","_fire_route","_mantle_route","_owners_route"]:
		if not _check(_method(prior,name)==_method(current,name),"Exact previously reviewed ordinary paid preparation: "+name): return false
	return true

func _method(source: String,name: String) -> String:
	var start := source.find("func "+name+"(")
	if start<0: return ""
	var end := source.find("\\nfunc ",start+1)
	return source.substr(start,end-start if end>=0 else -1).strip_edges()

'''
driver=driver[:start]+guard+driver[end:]
driver=driver.replace('"prefix_contract_checks":prefix_contract_checks,','')
driver=driver.replace('hex.ground.prefix-key-shape.v1','hex.ground.occupied-membership.v1')
driver=driver.replace('Only prefix key construction differs; exact-output prototype versus the same current Court, not an older whole game.',
 'Only synchronous occupied-membership reuse differs, limited to exact presenter/court/non-base/already-NEAREST draws; derived profiling presenters retain predecessor work. No cross-call authority cache.')
driver=driver.replace('Declared direct prefix/mutation/saturation controls run before native preparation and outside every clock.',
 'Separate functional compatibility/callback controls are a prerequisite and are not timed by this driver. Gate comparisons, scalar scope writes and consumption are inside each candidate draw clock.')
driver=driver.replace('GROUND_PREFIX_KEY_SHAPE','GROUND_OCCUPIED_MEMBERSHIP')
# Retain the pristine timer and paired cache/state/pixel protocol; add only an untimed scope-restoration check.
needle='\t\tvar after_stats := {"plain":plain.presenter.outline_cache_stats(),"candidate":candidate.presenter.outline_cache_stats()}'
driver=driver.replace(needle,'\t\tif not _check(int(candidate.presenter.get("_prepared_occupied_court_id"))==0,"One-call membership scope is consumed/restored after every draw"): return false\n'+needle)
(base/'compare-occupied-membership.gd').write_text(driver,encoding='utf-8',newline='\n')
for n in ['_world','_ready','_step','_record','_empty','_coverage','_capture','_fire_route','_mantle_route','_owners_route']:
    assert method(driver,n)==method(reference.read_text(encoding='utf-8').replace('\r\n','\n'),n)
manifest={'schema':'hex.occupied-membership-ignored-draft.v1','status':'UNAPPLIED; source review pending; separate functional gate required before native timing','canonical_presenter_sha256':sha(source),'candidate_sha256':sha(base/'candidate_court.gd'),'driver_sha256':sha(base/'compare-occupied-membership.gd'),'self_path_policy':'Exact get_script().resource_path comparison remains inside candidate timing; hypothetical production uses the same constant with canonical presenter path. No dynamic load. All subclasses fallback.','changes':changes,'limits':['No cross-call/tick cache or authority writes.','Texture-filter change disables reuse because the native setter can emit a synchronous callback.','Existing profiling subclasses deliberately retain predecessor work; isolated exact-class benefit would not prove full-observer improvement.','The containing bundle cost is not measured duplicated membership cost.']}
(base/'draft-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in manifest.items() if k.endswith('sha256')}))
