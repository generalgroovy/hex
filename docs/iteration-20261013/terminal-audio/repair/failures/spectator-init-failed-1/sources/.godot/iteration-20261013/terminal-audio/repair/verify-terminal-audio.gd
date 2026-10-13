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
const ROOT := "res://.godot/iteration-20261013/terminal-audio/repair/"
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
	extends "res://.godot/iteration-20261013/terminal-audio/repair/native/bootstrap.gd"
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
var result: Dictionary = {"reproduced":false,"repair_passed":false,"reason":"encounter has not run","terminal":{},"controls":[]}
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
	var actual_audio_driver := AudioServer.get_driver_name()
	result.audio_driver = actual_audio_driver
	if not check(actual_audio_driver=="Dummy","Actual Dummy backend required"):
		_finish(); return
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"source-pins.json"))
	if not check(manifest is Dictionary and manifest.get("sources") is Dictionary,"Reviewed source pins readable"):
		_finish(); return
	for path: String in manifest.sources:
		sources[path]=FileAccess.get_sha256(path)
		check(sources[path]==manifest.sources[path],"Exact pinned source: "+path)
	sources[ROOT+"verify-terminal-audio.gd"]=FileAccess.get_sha256(ROOT+"verify-terminal-audio.gd")
	sources[ROOT+"source-pins.json"]=FileAccess.get_sha256(ROOT+"source-pins.json")
	for method: String in ["_campus_encounter","_counter_command"]:
		check(_method(FileAccess.get_file_as_string(ROOT+"verify-terminal-audio.gd"),method)==_method(FileAccess.get_file_as_string(ROUTE_SOURCE),method),"Exact existing paid-route method: "+method)
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
	check(bool(result.repair_passed),"Paid terminal repair witness reached and passed")
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
	var pre_bind_hash := world.state_hash()
	var pre_bind_teams: Array[int] = [world.player(1).team_id,world.player(2).team_id]
	var bound := node.authoritative_session.bind(world,champions,prepared.anchors.player_spawn_px,"Audio probe")
	var post_bind_teams: Array[int] = [world.player(1).team_id,world.player(2).team_id]
	result.session_binding={"name":"Audio probe","bound":bound,"last_error":node.authoritative_session.last_error,"teams_before":pre_bind_teams,"teams_after":post_bind_teams,"state_unchanged":world.state_hash()==pre_bind_hash}
	if not check(bound,"Actual local session binds: "+node.authoritative_session.last_error): return
	if not check(world.state_hash()==pre_bind_hash and pre_bind_teams==post_bind_teams and pre_bind_teams==[1,2],"Session binding preserves actual hostile encounter teams and all authority"): return
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
			audio.silence() # Declared prepared occupancy; never changes paid authority.
			check(audio.consequence("refused",world.tick,true),"One actual finite secondary voice precedes earned confirmation")
			node.application_input_active=true
			node.controls_input_guard_frames=0
		node.element_expansion.after_step()
		if terminal_candidate and challenge.trial.phase=="victory" and bool(challenge.reward.get("ok",false)):
			# Observe audio immediately; expensive authority/file checks follow callbacks.
			await _terminal_probe(world,challenge,save_path,before_hash,before_events,before_metrics)
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
	var stops_before := audio.stop_calls
	var calls_before := node.true_freeze_calls
	var all_admitted_before := audio.admitted_count
	var clip_us := roundi(audio.consequence_clips.confirmed.get_length()*1000000.0)
	var longest_us := 0
	for voice: AudioStreamPlayer in audio.players:
		if voice.playing: longest_us=maxi(longest_us,roundi(voice.stream.get_length()*1000000.0))
	var begin_us := Time.get_ticks_usec()
	check(not node._area_loading() and node._gameplay_input_blocked(),"Paid finished result is the actual sole input block")
	node._process(1.0/60.0)
	var playing_after_first := audio.playing_count()
	check(admitted==1 and playing_before==2 and playing_after_first==2,"Paid confirmation and prepared real secondary voice survive first frozen callback")
	check(audio.players[3].playing and audio.players[3].stream==audio.consequence_clips.confirmed,"Original reserved confirmation voice remains playing without replacement")
	for frame: int in 2: node._process(1.0/60.0)
	check(node.true_freeze_calls==calls_before+6,"Three callbacks each check audio exception and enter actual finished-trial freeze")
	check(audio.stop_calls==stops_before and audio.admitted_count==all_admitted_before,"Frozen callbacks neither stop nor admit/replay/steal a voice")
	var observed_frames := 3
	# Real finite clips run on the Dummy mixer clock; declared callback dt is
	# not a measured rendering cadence. Bound both wall time and await count.
	while Time.get_ticks_usec()-begin_us<longest_us+100000 and observed_frames<240 and Time.get_ticks_usec()-begin_us<2000000:
		await create_timer(0.01).timeout
		node._process(1.0/60.0)
		observed_frames+=1
	var elapsed_us := Time.get_ticks_usec()-begin_us
	check(elapsed_us>=longest_us and elapsed_us<2000000,"Native witness passes actual longest clip length inside bounded watchdog")
	check(audio.playing_count()==0 and audio.stop_calls==stops_before,"Both original finite clips finish naturally without silence calls")
	check(audio.admitted_count==all_admitted_before and audio.players.size()==4,"Result observation preserves admission count and four-voice cap")
	check(world.state_hash()==expected_hash and world.combat_events==expected_events and world.hex_court.metrics==expected_metrics,"All frozen observations preserve real terminal authority, events and paid pools")
	check(challenge.reward==reward and FileAccess.get_file_as_bytes(save_path)==saved_bytes,"Natural tails preserve earned reward and exact save bytes")
	var packet := Packet.capture(world)
	check(not packet.is_empty(),"Actual repaired terminal retains strict complete packet")
	var reloaded := Progress.new()
	check(reloaded.configure(champions,abilities,save_path,true) and reloaded.learned_ids()==["wa_bidi"],"Actual earned signature reloads once")
	result.terminal={"tick":world.tick,"reward":reward,"admitted_confirmed":admitted,"playing_before":playing_before,"playing_after_first":playing_after_first,"playing_after_natural_expiry":audio.playing_count(),"stop_calls_delta":audio.stop_calls-stops_before,"observed_callbacks":observed_frames,"elapsed_us":elapsed_us,"longest_clip_us":longest_us,"confirmation_clip_us":clip_us,"world_hash":expected_hash,"packet_sha256":_sha(var_to_bytes(packet)),"save_sha256":_sha(saved_bytes),"prepared_secondary":"one real finite refused clip, presentation-only occupancy control before actual earned confirmation"}
	# These are explicitly synthetic presentation-only stop/admission controls
	# over the same genuinely earned result, never a replayed encounter.
	for mode: String in ["focus_lost","menu","guard","spectator","muted","trial_handoff_reset"]:
		audio.silence()
		audio.set_volume(30)
		node.application_input_active=true
		node.controls_input_guard_frames=0
		node.controls_editor.close_editor()
		node.session_transport.mode=SessionTransport.Mode.OFFLINE
		node.spectator_focus.reset()
		check(audio.consequence("refused",world.tick,true) and audio.playing_count()==1,"Prepared actual finite stop-control voice: "+mode)
		if mode=="focus_lost": node._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		if mode=="menu": node.controls_editor.open_editor()
		if mode=="guard": node.controls_input_guard_frames=2
		if mode=="spectator":
			node.session_transport.mode=SessionTransport.Mode.CLIENT
			node.session_transport.accepted=true
			node.spectator_focus.active=true
			node.spectator_focus.focus_entity_id=1
		if mode=="muted": audio.set_volume(0)
		if mode=="trial_handoff_reset": node._solo_trial_input_handoff()
		node.element_expansion._last_reward=""
		var count_before := int(audio.diagnostics().admitted_by_kind.confirmed)
		node.element_expansion.after_step()
		var delta := int(audio.diagnostics().admitted_by_kind.confirmed)-count_before
		check(delta==0 and not node.element_expansion._last_reward.is_empty(),"Blocked/terminal admission is denied and its notice consumed: "+mode)
		if mode=="spectator":
			# Avoid a fabricated connected-client transport process. Exercise
			# the exact production audio policy and its unchanged stop call.
			if node._audio_tails_blocked(node._gameplay_input_blocked()): audio.silence()
		else: node._process(1.0/60.0)
		check(audio.playing_count()==0,"Existing external stop clears real playback: "+mode)
		node.session_transport.mode=SessionTransport.Mode.OFFLINE
		node.spectator_focus.reset()
		node._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		node.controls_editor.close_editor()
		node.controls_input_guard_frames=0
		audio.set_volume(30)
		node.element_expansion.after_step()
		check(int(audio.diagnostics().admitted_by_kind.confirmed)==count_before,"Regain never replays denied terminal notice: "+mode)
		check(world.state_hash()==expected_hash and world.combat_events==expected_events and world.hex_court.metrics==expected_metrics and challenge.reward==reward and FileAccess.get_file_as_bytes(save_path)==saved_bytes,"Stop controls preserve real paid authority and earned save: "+mode)
		result.controls.append({"mode":mode,"synthetic_presentation_rearm":true,"confirmed_admitted_delta":delta,"playing_after_stop":audio.playing_count(),"spectator_policy_only":mode=="spectator"})
	result.repair_passed=failures.is_empty()
	result.reason="Actual earned confirmation and a prepared finite secondary voice finish naturally; external stop and denial controls preserve authority"


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
	var receipt := {"schema":"hex.terminal-audio-repair-native.v1","repair_passed":bool(result.repair_passed),"integrity_passed":failures.is_empty(),"reproduced":bool(result.reproduced),"checks":checks,"failures":failures,"sources":sources,"result":result,"scope":"One existing ordinary paid district encounter; direct minimal Bootstrap binding, real after_step and inherited frozen process callbacks, live Dummy AudioStreamPlayers. One prepared finite secondary voice plus actual earned confirmation; alternate eligibility/stop branches explicitly rearm presentation notice only. Spectator invokes the same stop policy without a fabricated client transport process. Natural expiry is wall-clock playback, not rendered cadence. No full boot/menu-navigation/physical focus, rendered frame rate, listening comfort or mix quality claim."}
	if output_authorized:
		var path := output.path_join("receipt.json")
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file==null: push_error("Cannot write owned terminal audio receipt"); quit(1); return
		var encoded := JSON.stringify(receipt,"\t")+"\n"
		file.store_string(encoded)
		file.close()
		var readback := FileAccess.get_file_as_string(path)
		if readback!=encoded or not JSON.parse_string(readback) is Dictionary: push_error("Terminal audio receipt readback differs"); quit(1); return
	print("%s terminal audio: %d checks; repair_passed=%s" % ["PASS" if failures.is_empty() else "FAIL",checks,str(bool(result.repair_passed))])
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
