extends "res://.godot/iteration-20261013/movement-cast-attribution/compare-movement-cast.gd"
## Separate timing contract. Original thirteen functional partitions are immutable.
## Contiguous SimWorld groups, not inherited Bootstrap process/frame scheduling.
const BootstrapFactory = preload("res://src/app/bootstrap.gd")
const TIMING_ROOT := "res://.godot/iteration-20261013/movement-cast-timing/"
const TIMING_CASES: Array[String] = ["garden_idle", "fire_close", "bootstrap_roster_mantle"]
const BRANCH_NAMES: Array[String] = ["actors_entered", "dead_at_entry", "dead_after_status", "missing_command", "admission_offers", "release_results"]
var factory_node: Node
var qualification_path := ""
var qualification_sha := ""
var qualification_rows: Array = []
var qualification_record: Dictionary = {}
var qualification_initial: Dictionary = {}
var initial_boundary: Dictionary = {}
var roster_proof: Dictionary = {}
var group_serial := 0


func _run() -> void:
	run_started_ms=Time.get_ticks_msec()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
		elif argument=="--functional-only": functional=true
		elif argument=="--reverse-order": reverse=true
		elif argument.begins_with("--case="):
			selected_case=argument.trim_prefix("--case=");case_arguments+=1
		elif argument.begins_with("--functional-receipt="): qualification_path=argument.trim_prefix("--functional-receipt=")
		elif argument.begins_with("--functional-sha256="): qualification_sha=argument.trim_prefix("--functional-sha256=")
	if not _check(output.get_base_dir()==TIMING_ROOT+"runs" and output.get_file().begins_with("probe-")
		and output.get_file().is_valid_filename() and not output.contains("..") and not output.contains("\\")
		and not FileAccess.file_exists(output) and not DirAccess.dir_exists_absolute(output), "Fresh direct owned timing output required"):
		_finish();return
	if not _check(DirAccess.make_dir_recursive_absolute(output)==OK, "Create fresh timing output"): _finish();return
	output_authorized=true
	if not _check(case_arguments==1 and selected_case in TIMING_CASES, "Exactly one declared timing-companion case required"): _finish();return
	if not _check(not functional or selected_case=="bootstrap_roster_mantle", "New functional mode qualifies only the additional roster; original thirteen remain separate"): _finish();return
	if not _check(functional or DisplayServer.get_name()!="headless", "Native display required for timing; no foreground or presentation claim"): _finish();return
	var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string(TIMING_ROOT+"manifest.json"))
	if not _check(manifest is Dictionary and manifest.get("source_sha256") is Dictionary, "Reviewed timing manifest exists"): _finish();return
	for path: String in manifest.source_sha256:
		if not _check(path.begins_with("res://") and not path.contains("..") and _is_digest(str(manifest.source_sha256[path])), "Valid source pin"): _finish();return
		hashes[path]=FileAccess.get_sha256(path)
		if not _check(hashes[path]==manifest.source_sha256[path], "Timing source differs: "+path): _finish();return
	hashes[TIMING_ROOT+"manifest.json"]=FileAccess.get_sha256(TIMING_ROOT+"manifest.json")
	if not _source_guard() or not _check(fixture.configure(), "Actual fixture catalogs configure: "+fixture.last_error): _finish();return
	if not functional and not _load_qualification(): _finish();return
	if functional:
		if not _check(qualification_path.is_empty() and qualification_sha.is_empty(), "New roster functional trace has no substituted qualification"): _finish();return
		await _roster_functional()
	else: await _timing_case()
	_finish()


func _is_digest(value: String) -> bool:
	if value.length()!=64: return false
	for character: String in value:
		if character not in "0123456789abcdef": return false
	return true


func _case_ticks() -> int:
	return 240 if selected_case=="garden_idle" else 480


func _workload_label() -> String:
	return "mantle" if selected_case=="bootstrap_roster_mantle" else selected_case


func _load_qualification() -> bool:
	if not _check(qualification_path.begins_with("res://.godot/iteration-20261013/") and not qualification_path.contains("..")
		and not qualification_path.contains("\\") and _is_digest(qualification_sha), "Explicit pinned functional receipt required"): return false
	if not _check(FileAccess.get_sha256(qualification_path)==qualification_sha, "Functional receipt exact bytes"): return false
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(qualification_path))
	var expected_schema := "hex-movement-cast-contiguous-timing-v1" if selected_case=="bootstrap_roster_mantle" else "hex-movement-cast-attribution-v1"
	if not _check(parsed is Dictionary and parsed.get("passed")==true and parsed.get("mode")=="functional"
		and parsed.get("schema")==expected_schema and parsed.get("cleanup") is Dictionary
		and parsed.cleanup.get("ended_worlds")==2 and parsed.cleanup.get("remaining_worlds")==0
		and parsed.get("errors") is Array and parsed.errors.is_empty() and parsed.get("cases") is Array
		and parsed.cases.size()==1 and parsed.get("selected_case")==selected_case and parsed.get("source_hashes") is Dictionary,
		"Passed single-case functional receipt required"): return false
	for path: String in parsed.source_hashes:
		if not _check(path.begins_with("res://") and not path.contains("..") and FileAccess.get_sha256(path)==parsed.source_hashes[path], "Qualification input remains exact: "+path): return false
	var qualified_case: Dictionary=parsed.cases[0]
	if not _check(qualified_case.get("label")==selected_case and qualified_case.get("rows") is Array
		and qualified_case.get("record") is Dictionary
		and qualified_case.rows.size()==_case_ticks() and int(qualified_case.get("completed_ticks",-1))==_case_ticks()
		and int(qualified_case.get("actual_recorded_attempts",-1))==_case_ticks(), "Qualification covers complete declared trajectory"): return false
	qualification_rows=qualified_case.rows
	qualification_record=qualified_case.record
	qualification_initial=qualified_case.get("initial_boundary",{})
	for index: int in qualification_rows.size():
		var row: Dictionary=qualification_rows[index]
		if not _check(int(row.tick_before)==index and int(row.tick_after)==index+1 and row.expected_success==true
			and row.plain.success==true and row.observed_cost.success==true and String(row.last_error).is_empty()
			and _is_digest(str(row.packet_sha256)) and _is_digest(str(row.state_hash)) and row.events is Array,
			"Each qualified tick is successful, strictly capturable and ordered"): return false
	hashes[qualification_path]=qualification_sha
	return true


func _paired_worlds() -> Dictionary:
	if selected_case!="bootstrap_roster_mantle":
		var plain: SimWorld=fixture.world(Plain,selected_case)
		var observed: Observed=fixture.world(Observed,selected_case) as Observed
		if not _check(plain!=null and observed!=null, "Original paired workload configures"): return {}
		return {"plain":plain,"observed":observed}
	# Actual production factory/target methods, without entering the scene tree.
	var game := BootstrapFactory.new()
	factory_node=game
	game.campus_layout=fixture.layout
	game.ability_catalog=fixture.abilities
	game.champion_catalog=fixture.champions
	var plain: SimWorld=game._new_wellspring_world(120)
	if not _check(plain!=null and plain.is_valid(), "Actual Bootstrap world factory configures"): return {}
	game.world=plain
	var actor := plain.player()
	actor.position_x=fixture.layout.spawn.x*SimConfig.FIXED_SCALE
	actor.position_y=fixture.layout.spawn.y*SimConfig.FIXED_SCALE
	if not _check(fixture.champions.apply_to_player(actor,"oh_tipi"), "Actual champion applies before weave/targets/session"): return {}
	var weave_path := output+"/absent-character-weaves.json"
	if not _check(not FileAccess.file_exists(weave_path) and game.character_weaves.configure(fixture.champions,fixture.abilities,false,weave_path)
		and game.character_weaves.restore_actor(actor,true), "Fresh nonpersistent ordinary starter-weave restore"): return {}
	# Declared initial loadout choice at the ordinary weave seam; no later grants.
	if not _check(actor.place_proven_spell(0,MixtureCatalog.wire_for(63,"mantle")), "Initial proven all-six Mantle replaces only starter slot zero"): return {}
	game._spawn_practice_targets(plain)
	game.authoritative_session=AuthoritativeSession.new()
	if not _check(game.authoritative_session.bind(plain,fixture.champions,fixture.layout.spawn,"Timing probe"), "Actual default-charter session binds after targets"): return {}
	var roster := _roster(plain)
	if not _check(plain.players.size()==5 and fixture.layout.practice_targets_by_id.size()==4, "Actual authored four-target roster plus local champion"): return {}
	for target_id: String in fixture.layout.practice_targets_by_id:
		var definition: Dictionary=fixture.layout.practice_targets_by_id[target_id]
		var target := plain.player(int(definition.entity_id))
		var position: Array=definition.position
		if not _check(target!=null and target.actor_kind==PlayerState.ActorKind.TRAINING_TARGET and target.team_id==target.entity_id
			and target.position_x==int(position[0])*1000 and target.position_y==int(position[1])*1000
			and target.health==int(definition.health) and target.health==target.health_maximum
			and target.flux==0 and target.stamina==0, "Unmodified authored target identity/team/position/resources"): return {}
	var packet := Packet.capture(plain)
	var observed: Observed=Observed.new(120,plain.seed,fixture.layout.build_collision_world(),plain.map_id,plain.map_hash)
	if not _check(fixture.definition.bind_world(observed) and not packet.is_empty() and Packet.restore(packet,observed), "Fresh observed court strictly restores actual factory packet"): return {}
	if not _check(plain.hex_court!=observed.hex_court and _roster(observed)==roster and plain.state_hash()==observed.state_hash()
		and var_to_bytes(Packet.capture(observed))==var_to_bytes(packet), "Detached court and complete initial authority/roster/packet match"): return {}
	roster_proof={"actors":roster,"seed":plain.seed,"default_spawn":[fixture.layout.spawn.x,fixture.layout.spawn.y],
		"initial_slot_override":MixtureCatalog.wire_for(63,"mantle"),"weave_file_created":FileAccess.file_exists(weave_path),
		"scope":"Actual never-entered Bootstrap factory, fresh starter-weave restore, explicit initial Mantle slot, authored targets, default charter. No full ready/render/exhibition/process scheduling or user-profile persistence."}
	_check(not bool(roster_proof.weave_file_created), "No character profile file is written")
	game.free();factory_node=null
	return {"plain":plain,"observed":observed}


func _roster(world: SimWorld) -> Array[Dictionary]:
	var rows: Array[Dictionary]=[]
	for actor: PlayerState in world.players:
		rows.append({"id":actor.entity_id,"kind":actor.actor_kind,"team":actor.team_id,"champion":actor.champion_wire_id,
			"position":[actor.position_x,actor.position_y],"health":actor.health,"radius":actor.radius,"flux":actor.flux,"stamina":actor.stamina})
	rows.sort_custom(func(left: Dictionary,right: Dictionary)->bool:return int(left.id)<int(right.id))
	return rows


func _initial_pair(plain: SimWorld, observed: Observed) -> bool:
	var packet_plain := Packet.capture(plain)
	var packet_observed := Packet.capture(observed)
	initial_boundary={"tick":plain.tick,"state_hash":plain.state_hash(),"packet_sha256":CanonicalBytes.sha256_hex(var_to_bytes(packet_plain)),"roster":_roster(plain)}
	if not _check(plain.tick==0 and observed.tick==0 and not packet_plain.is_empty() and not packet_observed.is_empty()
		and plain.state_hash()==observed.state_hash() and var_to_bytes(packet_plain)==var_to_bytes(packet_observed), "Initial strict paired boundary"): return false
	if not qualification_initial.is_empty():
		if not _check(JSON.parse_string(JSON.stringify(initial_boundary))==qualification_initial, "Additional roster initial boundary matches its frozen functional trace"): return false
	return _enable(plain) and _enable(observed)


func _roster_functional() -> bool:
	_progress(selected_case,"begin",0,0)
	var pair := _paired_worlds()
	if pair.is_empty(): return false
	var plain: SimWorld=pair.plain
	var observed: Observed=pair.observed
	if not _initial_pair(plain,observed): return false
	var record: Dictionary=fixture.initial_record("mantle")
	var rows: Array[Dictionary]=[]
	var result: Dictionary={"label":selected_case,"kind":"additional-roster-functional","rows":rows,"record":record,"initial_boundary":initial_boundary,"roster_proof":roster_proof}
	cases.append(result)
	for index: int in 480:
		var row := _attempt(plain,observed,fixture.commands(plain,"mantle",record),true)
		rows.append(row)
		fixture.observe(observed,"mantle",record,row.observation)
		if not errors.is_empty(): break
		if index%32==31:
			_progress(selected_case,"batch",rows.size(),observed.tick)
			if not _deadline("roster functional batch"): break
			await process_frame
		if finished: return false
	for problem: String in fixture.validate("mantle",record): _check(false,problem)
	result.actual_recorded_attempts=rows.size();result.completed_ticks=observed.tick;result.final_state_hash=observed.state_hash()
	_end(plain);_end(observed)
	_progress(selected_case,"end",rows.size(),observed.tick)
	return _deadline("roster functional end") and errors.is_empty()


func _commands_from_trace(row: Dictionary) -> Array[SimCommand]:
	var raw := String(row.commands_hex).hex_decode()
	var commands: Array[SimCommand]=[]
	if not _check(raw.size()==80, "Priority traces contain exactly one actual local command; targets use normal fallback"): return commands
	var values := PackedInt64Array()
	for index: int in 10: values.append(raw.decode_s64(index*8))
	commands.append(SimCommand.new(values[0],values[1],values[2],values[3],values[4],values[5],values[6],values[7],values[8],values[9]))
	_check(commands[0].tick==int(row.tick_before) and commands[0].entity_id==1 and _command_bytes(commands)==raw, "Prebuilt trace commands round-trip exact canonical bytes")
	return commands


func _schedule() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for cycle: int in (26 if selected_case=="garden_idle" else 52):
		for count: int in [0,1,8]: result.append({"phase":"warmup" if cycle<2 else "measured","cycle":cycle,"steps":count})
	var tail: Array=[6] if selected_case=="garden_idle" else [8,4]
	for count: int in tail: result.append({"phase":"verification_tail","cycle":-1,"steps":count})
	return result


func _run_group(world: SimWorld, inputs: Array, observed: bool) -> Dictionary:
	# Buffer creation is outside the timed loop. Fixed slot writes are inside it.
	var prepare_started := Time.get_ticks_usec()
	var count := inputs.size()
	var event_refs: Array=[];event_refs.resize(count)
	var step_errors := PackedStringArray();step_errors.resize(count)
	var success := PackedInt32Array();success.resize(count)
	var ticks := PackedInt64Array();ticks.resize(count)
	var parents := PackedInt64Array();parents.resize(count)
	var child := PackedInt64Array();child.resize(count*7)
	var executions := PackedInt64Array();executions.resize(count*7)
	var branches := PackedInt64Array();branches.resize(count*6)
	var unfinished := PackedInt32Array();unfinished.resize(count)
	var observed_world: Observed=world as Observed if observed else null
	var attempted := 0
	var started := Time.get_ticks_usec()
	for index: int in count:
		var commands: Array[SimCommand]=inputs[index]
		var okay := world.step(commands)
		attempted+=1
		success[index]=1 if okay else 0
		ticks[index]=world.tick
		step_errors[index]=world.last_error
		# Source replaces the array; later equality against every functional row
		# verifies this workload's payload lifetime. No deep copies in the loop.
		event_refs[index]=world.combat_events
		parents[index]=int(world.profile_stages_us.get("movement_cast_admission",0))
		if observed:
			for lane: int in 7:
				child[index*7+lane]=observed_world.mc_elapsed_us[lane]
				executions[index*7+lane]=observed_world.mc_executions[lane]
			branches[index*6]=observed_world.mc_actors_entered
			branches[index*6+1]=observed_world.mc_dead_at_entry
			branches[index*6+2]=observed_world.mc_dead_after_status
			branches[index*6+3]=observed_world.mc_missing_command
			branches[index*6+4]=observed_world.mc_admission_offers
			branches[index*6+5]=observed_world.mc_release_results
			unfinished[index]=1 if observed_world._mc_active else 0
		if not okay: break
	var ended := Time.get_ticks_usec()
	return {"loop_elapsed_us":ended-started,"buffer_prepare_us":started-prepare_started,"attempted":attempted,"events":event_refs,
		"success":success,"ticks":ticks,"errors":step_errors,"parent_us":parents,"child_us":child,"executions":executions,"branches":branches,"unfinished":unfinished}


func _event_equal(current: Array, frozen: Array) -> bool:
	# Both sides cross JSON's number representation, outside all measured loops.
	return JSON.parse_string(JSON.stringify(current))==frozen


func _workload_state(world: SimWorld) -> Dictionary:
	# Untimed scalar phase/occupancy witness, never a retained authority view.
	var ground_parts := 0
	var recipes: Dictionary={}
	for cast: Dictionary in world.hex_court.casts.values(): ground_parts+=Dictionary(cast.get("ground_parts",{})).size()
	for product: Dictionary in world.hex_court.products.values():
		var key := str(int(product.get("recipe_wire_id",0)))
		recipes[key]=int(recipes.get(key,0))+1
	var alive := 0
	for actor: PlayerState in world.players:
		if actor.health>0: alive+=1
	var local := world.player()
	return {"tick":world.tick,"actors":world.players.size(),"alive":alive,"dead":world.players.size()-alive,
		"local_pending_wire":local.pending_cast_wire_id,"local_pending_ticks":local.pending_cast_ticks,
		"local_recovery_ticks":local.cast_recovery_ticks,"local_cooldown_ticks":local.spell_cooldown_for_wire(local.spell_wire_id(1)),
		"flights":world.projectiles.size(),"casts":world.hex_court.casts.size(),"ground_parts":ground_parts,
		"products":world.hex_court.products.size(),"recipes":recipes,"matter_paid":int(world.hex_court.metrics.matter_paid),
		"matter_expired":int(world.hex_court.metrics.matter_expired)}


func _boundary(plain: SimWorld, observed: Observed, tick: int) -> Dictionary:
	var packet_plain := Packet.capture(plain)
	var packet_observed := Packet.capture(observed)
	var state := str(observed.state_hash())
	var digest := CanonicalBytes.sha256_hex(var_to_bytes(packet_observed))
	_check(plain.tick==tick and observed.tick==tick and plain.state_hash()==state and plain.last_error==observed.last_error, "Exact paired group state/tick/error boundary")
	_check(not packet_plain.is_empty() and not packet_observed.is_empty() and var_to_bytes(packet_plain)==var_to_bytes(packet_observed), "Complete strict packet bytes match at every group boundary")
	_check(plain.hex_court.conservation_valid() and observed.hex_court.conservation_valid(), "Both actual group ledgers conserve finite material")
	var expected: Dictionary=qualification_rows[tick-1] if tick>0 else initial_boundary
	_check(state==String(expected.state_hash) and digest==String(expected.packet_sha256), "Group terminal state and strict packet match frozen functional boundary")
	var paid := 0
	for index: int in tick:
		for event: Dictionary in qualification_rows[index].events:
			if String(event.get("type",""))=="cast_started": paid+=600
	_check(int(plain.hex_court.metrics.matter_paid)==paid and int(observed.hex_court.metrics.matter_paid)==paid, "Actual cumulative paid stock agrees with ordinary frozen admission events")
	return {"tick":tick,"state_hash":state,"packet_sha256":digest,"matter_paid":int(observed.hex_court.metrics.matter_paid),"matter_expired":int(observed.hex_court.metrics.matter_expired)}


func _timing_case() -> bool:
	_progress(selected_case,"begin",0,0)
	var pair := _paired_worlds()
	if pair.is_empty(): return false
	var plain: SimWorld=pair.plain
	var observed: Observed=pair.observed
	if not _initial_pair(plain,observed): return false
	var all_inputs: Array=[]
	for row: Dictionary in qualification_rows: all_inputs.append(_commands_from_trace(row))
	if not errors.is_empty(): return false
	var groups: Array[Dictionary]=[]
	var result: Dictionary={"label":selected_case,"kind":"contiguous-simworld-groups","groups":groups,"initial_boundary":initial_boundary,"roster_proof":roster_proof,"qualification_record":qualification_record}
	cases.append(result)
	var offset := 0
	for declaration: Dictionary in _schedule():
		if not _deadline("before group"): break
		var count := int(declaration.steps)
		var inputs_plain: Array=[]
		var inputs_observed: Array=[]
		for index: int in count:
			inputs_plain.append(_copy_commands(all_inputs[offset+index]))
			inputs_observed.append(_copy_commands(all_inputs[offset+index]))
		var before_plain := plain.profile_cumulative_snapshot()
		var before_observed := observed.profile_cumulative_snapshot()
		var workload_before := _workload_state(plain)
		if not _check(workload_before==_workload_state(observed), "Actual untimed workload occupancy agrees before group"): break
		var order: Array=["observed","plain"] if ((group_serial%2==0)!=reverse) else ["plain","observed"]
		var actual: Array[String]=[]
		var measured: Dictionary={}
		for side: String in order:
			actual.append(side)
			measured[side]=_run_group(observed if side=="observed" else plain,inputs_observed if side=="observed" else inputs_plain,side=="observed")
		var row: Dictionary={"phase":declaration.phase,"cycle":declaration.cycle,"steps":count,"tick_before":offset,"actual_order":actual,
			"serial":group_serial,"plain":measured.plain,"observed":measured.observed,"step_rows":[],"workload_before":workload_before,"valid":false}
		groups.append(row);group_serial+=1
		_check(actual==order, "Actual whole-arm group invocation order")
		_check(int(measured.plain.attempted)==count and int(measured.observed.attempted)==count, "Neither group failed or silently skipped a declared step")
		var valid := true
		for side: String in ["plain","observed"]:
			for index: int in int(measured[side].attempted):
				valid=_check(int(measured[side].success[index])==1 and String(measured[side].errors[index]).is_empty(), "Timing rejects a partial failed prefix without continuing that arm") and valid
		if not valid:
			row.failed_prefix={"plain_tick":plain.tick,"observed_tick":observed.tick,"plain_error":plain.last_error,"observed_error":observed.last_error,
				"plain_state":plain.state_hash(),"observed_state":observed.state_hash(),"plain_events":plain.combat_events.duplicate(true),"observed_events":observed.combat_events.duplicate(true)}
			break
		var observed_parent_sum := 0
		for index: int in count:
			var frozen: Dictionary=qualification_rows[offset+index]
			_check(_command_bytes(inputs_plain[index]).hex_encode()==frozen.commands_hex and _command_bytes(inputs_observed[index]).hex_encode()==frozen.commands_hex, "Both prebuilt command arrays remain exact after group")
			_check(int(measured.plain.ticks[index])==offset+index+1 and int(measured.observed.ticks[index])==offset+index+1, "Every actual group step preserves qualified tick order")
			_check(_event_equal(measured.plain.events[index],frozen.events) and _event_equal(measured.observed.events[index],frozen.events)
				and measured.plain.events[index]==measured.observed.events[index], "Retained per-step event references remain exact after all later group steps")
			var children: PackedInt64Array=measured.observed.child_us.slice(index*7,index*7+7)
			var executions: PackedInt64Array=measured.observed.executions.slice(index*7,index*7+7)
			var branches: PackedInt64Array=measured.observed.branches.slice(index*6,index*6+6)
			var child_total := 0
			for value: int in children: child_total+=value
			var parent := int(measured.observed.parent_us[index])
			observed_parent_sum+=parent
			_check(child_total<=parent and measured.observed.unfinished[index]==0, "Each disjoint child set is contained and closed")
			for lane: int in 7: _check(int(executions[lane])==int(frozen.observation.executions[lane]), "Each actual actor/Hex execution count matches qualified trace")
			for lane: int in 6: _check(int(branches[lane])==int(frozen.observation[BRANCH_NAMES[lane]]), "Each actual branch count matches qualified trace")
			row.step_rows.append({"tick":offset+index+1,"events":measured.observed.events[index].duplicate(true),"child_us":children,"executions":executions,"branches":branches,"parent_us":parent,"parent_residual_us":parent-child_total})
		_check(observed_parent_sum<=int(measured.observed.loop_elapsed_us), "All observed parents fit inside the contiguous loop including capture overhead")
		var after_plain := plain.profile_cumulative_snapshot()
		var after_observed := observed.profile_cumulative_snapshot()
		for key: String in ["attempted_steps","completed_steps","failed_steps","executions"]: _check(after_plain[key]==after_observed[key], "Cumulative group accounting matches: "+key)
		_check(int(after_plain.completed_steps)-int(before_plain.completed_steps)==count and int(after_observed.completed_steps)-int(before_observed.completed_steps)==count, "Actual group completion count")
		if count==0: _check(after_plain==before_plain and after_observed==before_observed, "Zero group changes no cumulative work; recorded loop elapsed is empty-call overhead only")
		offset+=count
		row.boundary=_boundary(plain,observed,offset)
		row.workload_after=_workload_state(observed)
		_check(row.workload_after==_workload_state(plain), "Actual untimed workload occupancy agrees after group")
		row.valid=errors.is_empty()
		# Deep serialization/copies are outside loop clocks and lifetime checks.
		row.plain.events=row.plain.events.duplicate(true)
		row.observed.events=row.observed.events.duplicate(true)
		if not errors.is_empty(): break
		if group_serial%8==0:
			_progress(selected_case,"group",offset,observed.tick)
			await process_frame
		if finished: return false
	result.completed_ticks=observed.tick;result.actual_recorded_attempts=offset;result.final_state_hash=observed.state_hash()
	_check(offset==_case_ticks() and plain.tick==_case_ticks() and observed.tick==_case_ticks(), "Exact complete persistent timing trajectory")
	_end(plain);_end(observed)
	_progress(selected_case,"end",offset,observed.tick)
	return _deadline("timing completed") and errors.is_empty()


func _cleanup() -> void:
	super._cleanup()
	if is_instance_valid(factory_node): factory_node.free()
	factory_node=null


func _finish() -> void:
	if finished: return
	finished=true
	_cleanup()
	for path: String in hashes: _check(FileAccess.get_sha256(path)==hashes[path], "Watched timing input unchanged: "+path)
	var payload: Dictionary={"schema":"hex-movement-cast-contiguous-timing-v1","passed":errors.is_empty(),"errors":errors,"checks":checks,
		"mode":"functional" if functional else "timing","selected_case":selected_case,"cases":cases,"source_hashes":hashes,
		"qualification":{"path":qualification_path,"sha256":qualification_sha},"reverse_initial_order":reverse,"child_names":NAMES,"branch_names":BRANCH_NAMES,
		"cleanup":{"ended_worlds":cleanup_ended,"remaining_worlds":active_worlds.size(),"factory_owned":is_instance_valid(factory_node)},
		"wall_elapsed_ms":Time.get_ticks_msec()-run_started_ms,"wall_deadline_ms":WALL_DEADLINE_MS,"engine":Engine.get_version_info(),"display":DisplayServer.get_name(),
		"scope":"Additional roster functional mode retains every-step original strict proof. Timing separately replays prequalified persistent commands in actual contiguous zero/one/eight SimWorld groups; strict state/packet/conservation/payment proof occurs at EVERY group boundary, not each interior step. All ordered per-step event arrays and actor/branch counts match the frozen functional trace after the group, verifying retained-array lifetime. Both arms include bounded event/tick/error/parent reference storage; observed loop also includes seven-lane/branch copying. Buffer allocation, source/command preparation, packet/hash/JSON and cleanup are outside loop clocks. Both arms retain the same nine-stage/cumulative observers. Empty group elapsed is real empty-loop overhead with zero simulation calls. No Bootstrap catch-up/process, rendering, GPU, thread CPU counter, physical input, FPS or performance-improvement claim. Boundary verification still alters between-group cache/thermal history; report order/process/phase and outliers."}
	if output_authorized:
		var encoded := JSON.stringify(payload,"\t")+"\n"
		if encoded.to_utf8_buffer().size()>MAX_RECEIPT_BYTES:
			errors.append("Timing receipt exceeds bounded output");payload.passed=false;payload.cases=[];encoded=JSON.stringify(payload,"\t")+"\n"
		var path := output+"/receipt.json"
		if FileAccess.file_exists(path): print("FAIL: Existing timing receipt");quit(1);return
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file==null: print("FAIL: Timing receipt cannot open");quit(1);return
		file.store_string(encoded);file.close()
		if FileAccess.get_file_as_string(path)!=encoded: print("FAIL: Timing receipt readback differs");quit(1);return
	print("MOVEMENT CAST CONTIGUOUS passed=",errors.is_empty()," selected_case=",selected_case," mode=","functional" if functional else "timing"," checks=",checks)
	for problem: String in errors: print("FAIL: ",problem)
	quit(0 if errors.is_empty() else 1)


func _finalize() -> void:
	if not finished:
		errors.append("Unexpected enclosing quit before timing companion completion")
		_finish()
