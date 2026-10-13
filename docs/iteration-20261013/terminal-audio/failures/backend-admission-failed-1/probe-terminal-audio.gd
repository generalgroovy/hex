extends SceneTree
@warning_ignore_start("integer_division")
## Ignored source reproduction: real paid result; Dummy voice commands, not sound quality.
const Progress = preload("res://src/app/signature_progression.gd")
const Challenges = preload("res://src/content/signature_challenge_catalog.gd")
const Challenge = preload("res://src/app/signature_challenge_session.gd")
const Mixtures = preload("res://src/content/mixture_catalog.gd")
const Arenas = preload("res://src/content/signature_arena_catalog.gd")
const RivalPolicy = preload("res://src/app/signature_rival_policy.gd")
const DamageEvent = preload("res://src/sim/combat/combat_damage_event.gd")
const Packet = preload("res://src/net/hex_world_snapshot.gd")
const ROOT := "res://.godot/iteration-20261013/terminal-audio/"
const ROUTE_SOURCE := "res://tests/unit/test_signature_progression.gd"
const MAX_STEPS := 8641

class TrackedAudio:
	extends "res://src/presentation/element_audio.gd"
	var stop_calls := 0
	var stop_rows: Array[Dictionary] = []
	var confirmed_started_us := -1
	func silence() -> void:
		stop_calls += 1
		var playing: Array[bool] = []
		for voice: AudioStreamPlayer in players: playing.append(voice.playing)
		stop_rows.append({"at_us":Time.get_ticks_usec(),"playing_before":playing,"occupied_before":occupied_until.duplicate(),"last_clip":last_clip_key})
		super.silence()
	func consequence(kind: String, tick: int, allowed: bool = true) -> bool:
		var attempted_us := Time.get_ticks_usec()
		var admitted := super.consequence(kind,tick,allowed)
		if admitted and kind=="confirmed": confirmed_started_us=attempted_us
		return admitted
	func playing_count() -> int:
		var count := 0
		for voice: AudioStreamPlayer in players:
			if voice.playing: count+=1
		return count

class FreezeHarness:
	extends "res://src/app/bootstrap.gd"
	var true_freeze_calls := 0
	func _ready() -> void: set_process(false)
	func _draw() -> void: pass
	func _advance_player_camera(_delta: float, _blocked: bool) -> void: pass
	func _solo_trial_frozen() -> bool:
		var actual := super._solo_trial_frozen()
		if actual: true_freeze_calls+=1
		return actual

class NoSavePreferences:
	extends PlayerPreferences
	var saves := 0
	func save_to_file(_path: String = DEFAULT_PATH) -> bool:
		saves+=1
		return true

var abilities := AbilityCatalog.new()
var champions := ChampionCatalog.new()
var campus := SanctumCampusLayout.new()
var campus_hex: HexWorldDefinition
var failures: Array[String] = []
var checks := 0
var output := ""
var output_authorized := false
var sources: Dictionary = {}
var result: Dictionary = {"reproduced":false,"reason":"encounter has not run","terminal":{},"controls":[]}
var node: FreezeHarness
var audio: TrackedAudio
var original_mouse_mode := Input.MOUSE_MODE_VISIBLE
var original_actions: Dictionary = {}
var original_deadzones: Dictionary = {}
var finished := false

func _initialize() -> void: _run.call_deferred()

func check(condition: bool, message: String) -> bool:
	checks+=1
	if not condition: failures.append(message)
	return condition

func equal(actual: Variant, expected: Variant, message: String) -> bool:
	return check(actual==expected,message)

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if not check(output.get_base_dir()==ROOT+"runs" and output.get_file().begins_with("probe-") and output.get_file().is_valid_filename() and not ".." in output and not FileAccess.file_exists(output) and not DirAccess.dir_exists_absolute(output),"Fresh direct owned output required"):
		_finish(); return
	if not check(DirAccess.make_dir_recursive_absolute(output)==OK,"Owned output creates"):
		_finish(); return
	output_authorized=true
	var args := OS.get_cmdline_args()
	var driver_index := args.find("--audio-driver")
	if not check(driver_index>=0 and driver_index+1<args.size() and args[driver_index+1]=="Dummy","Explicit Dummy backend required"):
		_finish(); return
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"source-pins.json"))
	if not check(manifest is Dictionary and manifest.get("sources") is Dictionary,"Reviewed source pins readable"):
		_finish(); return
	for path: String in manifest.sources:
		sources[path]=FileAccess.get_sha256(path)
		check(sources[path]==manifest.sources[path],"Exact pinned source: "+path)
	sources[ROOT+"probe-terminal-audio.gd"]=FileAccess.get_sha256(ROOT+"probe-terminal-audio.gd")
	sources[ROOT+"source-pins.json"]=FileAccess.get_sha256(ROOT+"source-pins.json")
	for method: String in ["_campus_encounter","_counter_command"]:
		check(_method(FileAccess.get_file_as_string(ROOT+"probe-terminal-audio.gd"),method)==_method(FileAccess.get_file_as_string(ROUTE_SOURCE),method),"Exact existing paid-route method: "+method)
	if not failures.is_empty(): _finish(); return
	if not check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json") and champions.load_from_file("res://content/champions/foundation_champions_v1.json",abilities) and campus.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"),"Current catalogs and real campus load"):
		_finish(); return
	campus_hex=HexWorldDefinition.from_campus(campus)
	if not check(campus_hex!=null,"Complete campus topology builds"): _finish(); return
	original_mouse_mode=Input.mouse_mode
	for action: StringName in InputMap.get_actions():
		original_actions[action]=InputMap.action_get_events(action).duplicate()
		original_deadzones[action]=InputMap.action_get_deadzone(action)
	InputRouter.ensure_input_map()
	await _encounter()
	_finish()

func _encounter() -> void:
	var row := Challenges.definition("wa_bidi",champions,abilities)
	var prepared := _campus_encounter(row)
	if not failures.is_empty(): return
	var world: SimWorld = prepared.world
	var challenge := Challenge.new()
	if not check(challenge.begin(world,prepared.anchors.bounds,row,true),"Existing first lesson encounter binds"): return
	var save_path := output.path_join("earned-progress.json")
	var progress := Progress.new()
	if not check(progress.configure(champions,abilities,save_path,true),"Fresh owned progression configures"): return
	var preferences := NoSavePreferences.new()
	node=FreezeHarness.new()
	node.preference_overrides_are_transient=true
	node.player_preferences=preferences
	node.world=world
	node.input_router=InputRouter.new(1)
	node.controls_editor=ControlBindingEditor.new()
	node.session_steward=SessionSteward.new()
	node.campus_layout=campus
	node.ability_catalog=abilities
	node.champion_catalog=champions
	node.authoritative_session=AuthoritativeSession.new()
	if not check(node.authoritative_session.bind(world,champions,prepared.anchors.player_spawn_px,"Terminal audio probe"),"Actual local session binds"): return
	node.session_transport=SessionTransport.new()
	node.element_expansion.game=node
	node.element_expansion.progression=progress
	node.element_expansion.challenge=challenge
	node.element_expansion.challenge_active=true
	node.interception_practice_active=true
	node.solo_trial=challenge.trial
	node.application_input_active=true # Explicit synthetic eligibility, not window focus proof.
	node.controls_input_guard_frames=0
	node.current_position=Vector2(world.player().position_x,world.player().position_y)/1000.0
	node.previous_position=node.current_position
	audio=TrackedAudio.new()
	node.element_audio=audio
	node.add_child(audio)
	root.add_child(node)
	audio.prepare(true)
	audio.set_volume(30)
	check(audio.players.size()==4,"Actual ElementAudio creates exactly four Dummy-backed players")
	check(not Packet.capture(world).is_empty(),"Initial full-health encounter has strict complete packet")
	var player_paid := 0
	var rival_paid := 0
	var owned_damage := 0
	var trace: Array[Dictionary] = []
	result["initial_health"]=[world.player(1).health,world.player(2).health]
	result["reason"]="bounded existing route did not reach a paid victory"
	for unused: int in MAX_STEPS:
		if not failures.is_empty() or challenge.trial.is_finished(): break
		var rival := challenge.command(world)
		if not check(rival!=null,"Ordinary rival command remains available"): break
		var command := _counter_command(world,challenge)
		if not check(world.step([command,rival]),"Unmodified ordinary paid commands step"): break
		for event: Dictionary in world.combat_events:
			if String(event.get("type",""))=="cast_started":
				if int(event.get("entity_id",0))==1: player_paid+=1
				if int(event.get("entity_id",0))==2: rival_paid+=1
			if int(event.get("owner_id",0))==1 and DamageEvent.target_id(event)==2: owned_damage+=DamageEvent.amount(event)
		var before_hash := world.state_hash()
		var before_events := world.combat_events.duplicate(true)
		var before_metrics: Dictionary = world.hex_court.metrics.duplicate(true)
		var terminal_candidate := world.player(2).health<=0 and world.player(1).health>0
		if terminal_candidate:
			audio.silence() # Declared empty-pool control; never changes paid authority.
			node.application_input_active=true
			node.controls_input_guard_frames=0
		node.element_expansion.after_step()
		if terminal_candidate and challenge.trial.phase=="victory" and bool(challenge.reward.get("ok",false)):
			# Observe audio immediately; expensive authority/file checks follow callbacks.
			_terminal_probe(world,challenge,save_path,before_hash,before_events,before_metrics)
		check(world.state_hash()==before_hash and world.combat_events==before_events and world.hex_court.metrics==before_metrics,"Controller/audio preserve completed authority, events and paid ledger")
		if not world.combat_events.is_empty(): trace.append({"tick":world.tick,"events":world.combat_events.duplicate(true)})
		if unused%120==119: await process_frame
	result["final_tick"]=world.tick
	result["final_phase"]=challenge.trial.phase
	result["actual_admissions"]={"player":player_paid,"rival":rival_paid}
	result["owned_damage"]=owned_damage
	result["events"]=trace
	result["paid_metrics"]=world.hex_court.metrics.duplicate(true)
	check(not Packet.capture(world).is_empty() and world.hex_court.conservation_valid(),"Final bounded route has strict conserved paid authority")
	check(preferences.saves==0,"Ordinary preferences remain untouched")
	if challenge.trial.phase=="victory": check(player_paid>0 and rival_paid>0 and owned_damage>0,"Reached victory faces a paid rival and owns positive paid damage")

func _terminal_probe(world: SimWorld, challenge: SignatureChallengeSession, save_path: String, expected_hash: String, expected_events: Array[Dictionary], expected_metrics: Dictionary) -> void:
	var reward := challenge.reward.duplicate(true)
	var saved_bytes := FileAccess.get_file_as_bytes(save_path)
	var admitted := int(audio.diagnostics().admitted_by_kind.confirmed)
	var playing_before := audio.playing_count()
	var calls_before := audio.stop_calls
	var age_before := Time.get_ticks_usec()-audio.confirmed_started_us
	var freezes_before := node.true_freeze_calls
	var no_loading := not node._area_loading()
	node._process(1.0/60.0)
	var playing_after := audio.playing_count()
	var stops_after := audio.stop_calls
	var first_stop: Dictionary = audio.stop_rows[calls_before] if audio.stop_rows.size()>calls_before else {}
	var stop_age := int(first_stop.get("at_us",-1))-audio.confirmed_started_us
	var stopped_voices: Array = first_stop.get("playing_before",[])
	var confirmed_was_playing := stopped_voices.size()==4 and bool(stopped_voices[3]) and String(first_stop.get("last_clip",""))=="result_confirmed"
	var clip_us := roundi(audio.consequence_clips.confirmed.get_length()*1000000.0)
	for frame: int in 2: node._process(1.0/60.0)
	check(no_loading and node.true_freeze_calls==freezes_before+3,"Three inherited callbacks reach the actual finished-trial freeze")
	check(world.state_hash()==expected_hash and world.combat_events==expected_events and world.hex_court.metrics==expected_metrics,"Frozen callbacks preserve world, events and payment")
	check(challenge.reward==reward and FileAccess.get_file_as_bytes(save_path)==saved_bytes,"Frozen callbacks preserve actual reward and exact earned save bytes")
	check(bool(reward.get("saved",false)) and not saved_bytes.is_empty(),"Actual paid reward saved to owned path")
	var reloaded := Progress.new()
	check(reloaded.configure(champions,abilities,save_path,true) and reloaded.learned_ids()==["wa_bidi"],"Actual saved earned signature reloads once")
	var packet := Packet.capture(world)
	check(not packet.is_empty(),"Terminal authority has complete strict packet")
	result.terminal={"tick":world.tick,"reward":reward,"admitted_confirmed":admitted,"playing_before":playing_before,"playing_after_first":playing_after,"stop_calls_delta":stops_after-calls_before,"age_before_first_us":age_before,"first_stop":first_stop,"stop_age_us":stop_age,"confirmed_voice_playing_at_stop":confirmed_was_playing,"intended_clip_us":clip_us,"freeze_callbacks":node.true_freeze_calls-freezes_before,"world_hash":str(expected_hash),"packet_sha256":_sha(var_to_bytes(packet)),"save_sha256":_sha(saved_bytes),"empty_pool_prepared":true}
	result.reproduced=admitted==1 and playing_before>0 and playing_after==0 and stops_after>calls_before and confirmed_was_playing and stop_age>=0 and stop_age<clip_us
	result.reason="Actual earned cue was stopped by the next inherited frozen-result callback" if bool(result.reproduced) else "Paid victory reached, but playing/early-stop witness was not established"
	# Synthetic presentation eligibility controls over this same genuine saved result.
	# Re-arm only the controller's notice de-duplication marker, never challenge/world/reward.
	for mode: String in ["focus_lost","menu","muted","trial_handoff_reset"]:
		audio.silence()
		audio.set_volume(0 if mode=="muted" else 30)
		node.application_input_active=true
		node.controls_input_guard_frames=0
		node.controls_editor.close_editor()
		if mode=="focus_lost": node._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		if mode=="menu": node.controls_editor.open_editor()
		node.element_expansion._last_reward=""
		var count_before := int(audio.diagnostics().admitted_by_kind.confirmed)
		node.element_expansion.after_step()
		var delta := int(audio.diagnostics().admitted_by_kind.confirmed)-count_before
		var playing := audio.playing_count()
		if mode=="trial_handoff_reset": node._solo_trial_input_handoff()
		else: node._process(1.0/60.0)
		var after_stop := audio.playing_count()
		# Regain must not replay a consumed terminal notice or rewrite its reward.
		node._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		node.controls_editor.close_editor()
		node.element_expansion.after_step()
		check(int(audio.diagnostics().admitted_by_kind.confirmed)==count_before+delta,"Regain does not duplicate terminal cue: "+mode)
		check(world.state_hash()==expected_hash and world.combat_events==expected_events and world.hex_court.metrics==expected_metrics and challenge.reward==reward and FileAccess.get_file_as_bytes(save_path)==saved_bytes,"Eligibility control preserves actual authority/reward/save: "+mode)
		if mode=="muted": check(delta==0 and playing==0,"Master mute blocks even direct confirmation")
		check(after_stop==0,"Existing external stop/reset clears active voices: "+mode)
		result.controls.append({"mode":mode,"synthetic_presentation_rearm":true,"admitted_delta":delta,"playing_after_admission":playing,"playing_after_stop":after_stop})

func _method(text: String, method: String) -> String:
	text=text.replace("\r\n","\n")
	var start := text.find("func "+method+"(")
	if start<0: return ""
	var end := text.find("\nfunc ",start+1)
	return (text.substr(start) if end<0 else text.substr(start,end-start)).strip_edges()

func _sha(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()

func _finish() -> void:
	if finished: return
	finished=true
	if is_instance_valid(node):
		if node.session_transport!=null: node.session_transport.stop()
		node.free()
	if not original_actions.is_empty():
		for action: StringName in InputMap.get_actions():
			if not original_actions.has(action): InputMap.erase_action(action)
		for action: StringName in original_actions:
			if not InputMap.has_action(action): InputMap.add_action(action)
			InputMap.action_erase_events(action)
			for event: InputEvent in original_actions[action]: InputMap.action_add_event(action,event)
			InputMap.action_set_deadzone(action,float(original_deadzones[action]))
		Input.mouse_mode=original_mouse_mode
	for path: String in sources: check(FileAccess.get_sha256(path)==sources[path],"Watched source unchanged: "+path)
	var receipt := {"schema":"hex.terminal-audio-reproduction.v1","integrity_passed":failures.is_empty(),"reproduced":bool(result.reproduced),"checks":checks,"failures":failures,"sources":sources,"result":result,"scope":"One existing ordinary paid district encounter; direct minimal Bootstrap binding, real after_step and inherited frozen process callbacks, live Dummy AudioStreamPlayers. Empty-pool primary control; alternate eligibility branches explicitly rearm presentation notice only. No full boot/menu-navigation/physical focus, rendered frame rate, listening comfort or mix quality claim."}
	if output_authorized:
		var path := output.path_join("receipt.json")
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file==null: push_error("Cannot write owned terminal audio receipt"); quit(1); return
		var encoded := JSON.stringify(receipt,"\t")+"\n"
		file.store_string(encoded)
		file.close()
		var readback := FileAccess.get_file_as_string(path)
		if readback!=encoded or not JSON.parse_string(readback) is Dictionary: push_error("Terminal audio receipt readback differs"); quit(1); return
	print("%s terminal audio: %d checks; reproduced=%s" % ["PASS" if failures.is_empty() else "FAIL",checks,str(bool(result.reproduced))])
	for failure: String in failures: print("FAIL: "+failure)
	quit(0 if failures.is_empty() else 1)

func _finalize() -> void:
	if not finished:
		failures.append("Unexpected enclosing quit before completed terminal-audio probe")
		_finish()


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
