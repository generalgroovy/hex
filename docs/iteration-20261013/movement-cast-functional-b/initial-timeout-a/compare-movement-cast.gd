extends SceneTree
## Functional checkpoint first. This helper does not authorize a timing claim.
const Plain = preload("res://src/sim/core/sim_world.gd")
const Observed = preload("res://.godot/iteration-20261013/movement-cast-attribution/observed_world.gd")
const Fixtures = preload("res://.godot/iteration-20261013/movement-cast-attribution/functional_fixtures.gd")
const Packet = preload("res://src/net/hex_world_snapshot.gd")
const BASE := "res://.godot/iteration-20261013/movement-cast-attribution/"
const SELF := BASE + "compare-movement-cast.gd"
const NAMES: Array[String] = ["setup_resources_status", "reaction_contact_ratios", "hex_pre_movement", "movement", "admission_offer", "combat_player", "release_store"]
const MAX_CASES := 16
const MAX_TICKS_PER_CASE := 2000
const MAX_RECEIPT_BYTES := 16 * 1024 * 1024
var output := ""
var output_authorized := false
var functional := false
var reverse := false
var finished := false
var checks := 0
var errors: Array[String] = []
var hashes: Dictionary = {}
var cases: Array[Dictionary] = []
var active_worlds: Array[SimWorld] = []
var serial := 0
var cleanup_ended := 0
var fixture := Fixtures.new()


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> bool:
	checks += 1
	if not value: errors.append(message)
	return value


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
		elif argument == "--functional-only": functional=true
		elif argument == "--reverse-order": reverse=true
	if not _check(output.begins_with(BASE+"runs/") and not output.contains("..") and not output.ends_with("/")
		and not output.contains("\\") and not DirAccess.dir_exists_absolute(output) and not FileAccess.file_exists(output), "Fresh owned output directory required"):
		_finish();return
	if not _check(DirAccess.make_dir_recursive_absolute(output)==OK, "Create fresh owned output"):
		_finish();return
	output_authorized=true
	if not _check(functional, "Timing extension is not implemented or qualified at this functional checkpoint"):
		_finish();return
	var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string(BASE+"manifest.json"))
	if not _check(manifest is Dictionary and manifest.get("source_sha256",null) is Dictionary, "Frozen source manifest must exist"):
		_finish();return
	for path: String in manifest.source_sha256:
		if not _check(path.begins_with("res://") and not path.contains("..") and String(manifest.source_sha256[path]).length()==64, "Valid in-project source pin"):
			_finish();return
		hashes[path]=FileAccess.get_sha256(path)
		if not _check(hashes[path]==manifest.source_sha256[path], "Source pin differs: "+path): _finish();return
	hashes[BASE+"manifest.json"]=FileAccess.get_sha256(BASE+"manifest.json")
	if not _source_guard(): _finish();return
	if not _check(fixture.configure(), "Actual fixture content loads: "+fixture.last_error): _finish();return
	var specifications: Array[Dictionary]=fixture.specs()
	if not _check(not specifications.is_empty() and specifications.size()<=MAX_CASES, "Bounded functional case inventory"):
		_finish();return
	create_timer(540.0).timeout.connect(func() -> void:
		if not finished: errors.append("Functional watchdog expired");_finish())
	if not _group_control(): _finish();return
	for specification: Dictionary in specifications:
		if not await _case(specification): _finish();return
	_finish()


func _source_guard() -> bool:
	var before := FileAccess.get_file_as_string(BASE+"sim_world.before.gd").replace("\r\n","\n")
	var live := FileAccess.get_file_as_string("res://src/sim/core/sim_world.gd").replace("\r\n","\n")
	var observed := FileAccess.get_file_as_string(BASE+"observed_world.gd").replace("\r\n","\n")
	var proof: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BASE+"source-transform.json"))
	if not _check(FileAccess.get_sha256("res://src/sim/core/sim_world.gd")==proof.source_sha256
		and FileAccess.get_sha256(BASE+"sim_world.before.gd")==proof.source_sha256, "Exact predecessor/current source bytes"):
		return false
	var stripped := PackedStringArray()
	var insertions := 0
	for line: String in _method(observed,"step").split("\n"):
		if line.contains("# MC_OBSERVER"): insertions+=1
		else: stripped.append(line)
	if not _check(insertions==int(proof.inserted_lines) and insertions==22, "Exactly the declared observer lines"):
		return false
	if not _check("\n".join(stripped).strip_edges()==_method(before,"step") and _method(before,"step")==_method(live,"step"), "Strip-to-original exact step guard"):
		return false
	var identity: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://content/runtime/runtime_build_identity_v1.json"))
	return _check(String(identity.build_id)=="p61-500be306a26a" and int(identity.record_count)==3444
		and String(identity.runtime_source_sha256)=="500be306a26ab82390d69f129d3be51e43b2513dd339dc03cfd0a470b5e9fd19", "Frozen candidate identity")


func _method(source: String, name: String) -> String:
	var start := source.find("func "+name+"(")
	if start<0: return ""
	var end := source.find("\nfunc ",start+1)
	return source.substr(start,end-start if end>=0 else -1).strip_edges()


func _enable(world: SimWorld) -> bool:
	active_worlds.append(world)
	world.profile_enabled=true
	return _check(world.profile_cumulative_begin(), "Both arms use the existing full nine-stage/cumulative observer")


func _command_bytes(commands: Array[SimCommand]) -> PackedByteArray:
	var bytes := PackedByteArray()
	for command: SimCommand in commands: bytes.append_array(command.canonical_bytes())
	return bytes


func _copy_commands(commands: Array[SimCommand]) -> Array[SimCommand]:
	var copied: Array[SimCommand]=[]
	for command: SimCommand in commands: copied.append(command.copy())
	return copied


func _attempt(plain: SimWorld, observed: Observed, commands: Array[SimCommand], expected_success: bool) -> Dictionary:
	var before_tick := plain.tick
	var initial_commands := _command_bytes(commands)
	var plain_commands := _copy_commands(commands)
	var observed_commands := _copy_commands(commands)
	var before_plain := plain.profile_cumulative_snapshot()
	var before_observed := observed.profile_cumulative_snapshot()
	var candidate_first := (serial%4==0)!=reverse
	var order: Array=["observed","plain"] if candidate_first else ["plain","observed"]
	var actual_order: Array[String]=[]
	var results: Dictionary={}
	for side: String in order:
		actual_order.append(side)
		serial+=1
		var world: SimWorld=observed if side=="observed" else plain
		var inputs: Array[SimCommand]=observed_commands if side=="observed" else plain_commands
		# These functional clocks are diagnostic witnesses, not accepted cost samples.
		var started := Time.get_ticks_usec()
		var success := world.step(inputs)
		var elapsed := Time.get_ticks_usec()-started
		results[side]={"success":success,"whole_step_us":elapsed,"serial":serial}
		_check(_command_bytes(inputs)==initial_commands, "Authority does not mutate command inputs")
	var snapshot := observed.mc_snapshot()
	var parent := int(observed.profile_stages_us.get("movement_cast_admission",0))
	var child_total := 0
	for value: int in snapshot.elapsed_us: child_total+=value
	_check(actual_order==order, "Actual invocation order recorded")
	_check(bool(results.plain.success)==expected_success and bool(results.observed.success)==expected_success, "Both attempts match the declared success/failure branch")
	_check(plain.tick==observed.tick and plain.tick==before_tick+(1 if expected_success else 0), "Actual completed-tick boundary matches")
	_check(plain.last_error==observed.last_error, "Actual failure diagnostics match without rollback assumptions")
	_check(plain.state_hash()==observed.state_hash(), "Every attempted boundary has exact canonical authority")
	_check(plain.combat_events==observed.combat_events, "Every attempted boundary has exact event order/ownership")
	_check(initial_commands==_command_bytes(commands), "Shared original commands remain immutable")
	_check(child_total<=parent and parent<=int(results.observed.whole_step_us), "Disjoint children are contained in inclusive parent and outer step")
	_check(not bool(snapshot.unfinished_interval), "No failed or successful branch leaves a child interval open")
	var entered := int(snapshot.actors_entered)
	var survived := entered-int(snapshot.dead_at_entry)-int(snapshot.dead_after_status)
	_check(survived>=0 and int(snapshot.executions[0])==entered, "Setup counted for every entered actor, including both death exits")
	for index: int in [1,3,4,5,6]:
		_check(int(snapshot.executions[index])==survived, "Actual surviving-actor child execution count: "+NAMES[index])
	_check(int(snapshot.executions[2])==(survived if observed.hex_court!=null else 0), "Hex-only child execution remains absent in legacy")
	_check(int(snapshot.admission_offers)<=int(snapshot.executions[4]) and int(snapshot.release_results)<=int(snapshot.executions[6]), "Conditional offers and Hex releases remain bounded by actual branches")
	var after_plain := plain.profile_cumulative_snapshot()
	var after_observed := observed.profile_cumulative_snapshot()
	for key: String in ["attempted_steps","completed_steps","failed_steps","executions"]:
		_check(after_plain[key]==after_observed[key], "Existing cumulative accounting matches: "+key)
	_check(int(after_observed.attempted_steps)-int(before_observed.attempted_steps)==1, "One attempted step counted")
	_check(int(after_observed.completed_steps)-int(before_observed.completed_steps)==(1 if expected_success else 0), "Only successful steps commit completed counters")
	if not expected_success:
		_check(after_plain.elapsed_us==before_plain.elapsed_us and after_observed.elapsed_us==before_observed.elapsed_us, "Failed prefixes remain excluded from both committed stage totals")
	var packet_sha := ""
	if expected_success and observed.hex_court!=null:
		var packet_plain := Packet.capture(plain)
		var packet_observed := Packet.capture(observed)
		_check(not packet_plain.is_empty() and not packet_observed.is_empty(), "Every completed Hex boundary is strictly capturable")
		var raw_plain := var_to_bytes(packet_plain)
		var raw_observed := var_to_bytes(packet_observed)
		_check(raw_plain==raw_observed, "Exact complete Hex packet bytes match outside clocks")
		var packet_hasher := HashingContext.new();packet_hasher.start(HashingContext.HASH_SHA256);packet_hasher.update(raw_observed)
		packet_sha=packet_hasher.finish().hex_encode()
		_check(plain.hex_court.conservation_valid() and observed.hex_court.conservation_valid(), "Actual finite material conserves in both arms")
	return {"tick_before":before_tick,"tick_after":observed.tick,"expected_success":expected_success,"actual_order":actual_order,
		"plain":results.plain,"observed_cost":results.observed,"observation":snapshot,"parent_us":parent,"parent_residual_us":parent-child_total,
		"state_hash":str(observed.state_hash()),"packet_sha256":packet_sha,"last_error":observed.last_error,
		"existing_last_step_us":observed.profile_stages_us.duplicate(),
		"commands_hex":initial_commands.hex_encode(),"events":observed.combat_events.duplicate(true)}


func _group_control() -> bool:
	var plain: SimWorld=fixture.world(Plain,"garden_idle")
	var observed: Observed=fixture.world(Observed,"garden_idle") as Observed
	if not _check(plain!=null and observed!=null, "Real grouped-control worlds configure"): return false
	if not _enable(plain) or not _enable(observed): return false
	var record: Dictionary=fixture.initial_record("garden_idle")
	var rows: Array[Dictionary]=[]
	cases.append({"label":"zero_one_eight_groups","kind":"functional-group-control","rows":rows})
	for count: int in [0,1,8,0]:
		observed._mc_reset_step()
		var before := observed.profile_cumulative_snapshot()
		var actual: Array[Dictionary]=[]
		for unused: int in count:
			actual.append(_attempt(plain,observed,fixture.commands(plain,"garden_idle",record),true))
		var after := observed.profile_cumulative_snapshot()
		_check(int(after.completed_steps)-int(before.completed_steps)==count, "Declared group records actual zero/one/eight completed steps")
		if count==0:
			_check(after==before and observed.mc_snapshot().executions==PackedInt64Array([0,0,0,0,0,0,0]), "Zero-step group has zero work, no stale last-step inference")
		rows.append({"steps":count,"tick_before":int(before.tick),"tick_after":int(after.tick),"attempts":actual})
	var detached := observed.mc_snapshot()
	var retained := observed.mc_snapshot()
	detached.elapsed_us[0]=999999
	_check(observed.mc_snapshot()==retained, "Scalar observer snapshot arrays are detached")
	_end(plain);_end(observed)
	return errors.is_empty()


func _case(specification: Dictionary) -> bool:
	var label := String(specification.label)
	var count := int(specification.ticks)
	if not _check(count>0 and count<=MAX_TICKS_PER_CASE, "Bounded case length: "+label): return false
	var plain: SimWorld=fixture.world(Plain,label)
	var observed: Observed=fixture.world(Observed,label) as Observed
	if not _check(plain!=null and observed!=null, "Actual paired fixture configures: "+label+" "+fixture.last_error): return false
	if not _enable(plain) or not _enable(observed): return false
	_check((observed.hex_court!=null)==bool(specification.hex_mode), "Declared Hex/legacy mode matches actual fixture")
	var record: Dictionary=fixture.initial_record(label)
	var rows: Array[Dictionary]=[]
	var result: Dictionary={"label":label,"kind":"functional-trajectory","specification":specification.duplicate(true),"record":record,"rows":rows}
	cases.append(result)
	for unused: int in count:
		var commands: Array[SimCommand]=fixture.commands(plain,label,record)
		var row := _attempt(plain,observed,commands,bool(specification.expect_success))
		rows.append(row)
		if label=="wrong_tick":
			_check(row.existing_last_step_us.has("surfaces_expiry") and not row.existing_last_step_us.has("command_order"), "Wrong-tick control actually executes surface/expiry prefix before command rejection")
		fixture.observe(observed,label,record,row.observation)
		if not errors.is_empty(): break
		if unused%32==31: await process_frame
		if finished: return false
	for problem: String in fixture.validate(label,record): _check(false,label+": "+problem)
	result.final_state_hash=str(observed.state_hash())
	result.completed_ticks=observed.tick
	result.actual_recorded_attempts=rows.size()
	_end(plain);_end(observed)
	return errors.is_empty()


func _end(world: SimWorld) -> void:
	if not active_worlds.has(world): return
	world.profile_cumulative_end()
	world.profile_enabled=false
	_check(not bool(world.profile_cumulative_snapshot().enabled), "Normal/failure cleanup disables cumulative collection")
	active_worlds.erase(world)
	cleanup_ended+=1


func _cleanup() -> void:
	for world: SimWorld in active_worlds.duplicate(): _end(world)
	_check(active_worlds.is_empty(), "No diagnostic world remains enabled or owned by cleanup")


func _finish() -> void:
	if finished: return
	finished=true
	_cleanup()
	for path: String in hashes:
		_check(FileAccess.get_sha256(path)==hashes[path], "Source unchanged at final cleanup: "+path)
	var payload: Dictionary={"schema":"hex-movement-cast-attribution-v1","passed":errors.is_empty(),"errors":errors,"checks":checks,
		"mode":"functional" if functional else "timing","reverse_initial_order":reverse,"source_hashes":hashes,"cases":cases,
		"child_names":NAMES,"cleanup":{"ended_worlds":cleanup_ended,"remaining_worlds":active_worlds.size()},
		"engine":Engine.get_version_info(),"display":DisplayServer.get_name(),
		"scope":"Functional checkpoint only; local elapsed values are clock-containment witnesses, not accepted cost samples. Both arms run full nine-stage/cumulative observers; added seven disjoint intervals alter observed parent timing. Shared production constructor/helpers and exact step transform; no Bootstrap/process scheduling, exhibition, rendering, GPU, physical input/FPS or performance-improvement claim. Every attempted tick compares canonical state/events; successful Hex ticks also compare exact strict packet bytes and conservation. Failed prefix mutations/errors are compared without rollback or completed-packet assumptions. Source hashes are rechecked on normal/failure cleanup; all observed worlds are disabled. Prepared initial branch fixtures are separately labeled; persistent paid routes receive no trajectory grants."}
	if output_authorized:
		var encoded := JSON.stringify(payload,"\t")+"\n"
		if encoded.to_utf8_buffer().size()>MAX_RECEIPT_BYTES:
			errors.append("Receipt exceeded bounded output budget")
			payload.passed=false
			payload.cases=[]
			encoded=JSON.stringify(payload,"\t")+"\n"
		var path := output+"/receipt.json"
		if FileAccess.file_exists(path): print("FAIL: Refuse existing receipt");quit(1);return
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file==null: print("FAIL: Cannot write owned receipt");quit(1);return
		file.store_string(encoded);file.close()
		if FileAccess.get_file_as_string(path)!=encoded: print("FAIL: Receipt readback differs");quit(1);return
	print("MOVEMENT CAST ATTRIBUTION functional=",functional," passed=",errors.is_empty()," cases=",cases.size()," checks=",checks)
	for problem: String in errors: print("FAIL: ",problem)
	quit(0 if errors.is_empty() else 1)


func _finalize() -> void:
	if not finished:
		errors.append("Unexpected enclosing quit before functional completion")
		_finish()
