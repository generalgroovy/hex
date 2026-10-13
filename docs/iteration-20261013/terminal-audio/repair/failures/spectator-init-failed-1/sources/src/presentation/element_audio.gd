class_name ElementAudio
extends Node

# Local, non-positional feedback only: never a source of enemy positions or rules.
# Editable synthesis recipes generate short cached PCM clips once, not per shot.
const RATE := 22050
const VOICES := 4
const PEAK := 0.22 # Four coincident full-volume voices stay below unity.
const VARIANTS := 3
const CONTACT_VOICE := VOICES - 1
const MAX_PCM_BYTES := 1024 * 1024
# Explicit voice priority and a bounded admission batch follow middleware voice
# limiting practice; no stealing, deferred stale cue, new mixer voice or PCM.
# https://www.audiokinetic.com/en/public-library/2024.1.8_8893/?id=optimizing_cpu&source=Help
const MAX_QUEUED_CUES := 8
const ELEMENTS := ["earth", "fire", "water", "wind", "ice", "charge", "light", "dark"]
# Fundamental, end/start pitch ratio, filtered noise, harmonic weight, duration.
const RECIPES := [
	[115.0, 0.42, 0.32, 0.18, 0.25], # Earth: tumbling knock and granular afterfall.
	[260.0, 0.65, 0.68, 0.10, 0.23], # Fire: dry ignition, crackle, cooling hiss.
	[610.0, 0.38, 0.10, 0.18, 0.27], # Water: rounded drop with a second ripple.
	[320.0, 1.25, 0.88, 0.00, 0.28], # Wind: airy attack and soft filtered breath.
	[1450.0, 0.96, 0.04, 0.38, 0.29], # Ice: glass attack and a fine upper ring.
	[780.0, 0.48, 0.26, 0.32, 0.21], # Charge: bright snap and electric chatter.
	[880.0, 1.13, 0.02, 0.36, 0.31], # Light: clear attack with a rising fifth.
	[160.0, 0.55, 0.10, 0.34, 0.30], # Dark: hollow onset and low beating tail.
]
var volume_percent := 30
var clips: Dictionary = {}
var consequence_clips: Dictionary = {}
const CONSEQUENCES := {"damage":[180.0,0.5,0.18],"refused":[230.0,0.8,0.10],"landed":[120.0,0.6,0.12],"wall_exit":[380.0,1.25,0.14],"confirmed":[660.0,1.5,0.22]}
var _movement_tick := -1
var _was_airborne := false
var _was_attached := false
var players: Array[AudioStreamPlayer] = []
var occupied_until: Array[int] = [0, 0, 0, 0]
var last_kind_tick: Dictionary = {}
var variant_cursor: Dictionary = {}
var last_clip_key := ""
var last_tick := -1
var admitted_count := 0
var _batch_tick := -1
var _queue_serial := 0
var _queued: Array[Dictionary]=[]
var _counters := {"requested":0,"admitted":0,"refractory":0,"pool_full":0,"coalesced":0,"queue_full":0,"muted_denied":0,"invalid":0,"peak_queued":0}
var _category_admissions := {"damage":0,"confirmed":0,"contact":0,"cast":0,"refused":0,"landed":0,"wall_exit":0}


func prepare(playback: bool = true) -> void:
	if consequence_clips.is_empty():
		for kind: String in CONSEQUENCES: consequence_clips[kind] = make_consequence_clip(kind)
	if clips.is_empty():
		for element: String in ELEMENTS:
			for contact: bool in [false, true]:
				for variant: int in VARIANTS:
					clips[_key(element, contact, variant)] = make_clip(element, contact, variant)
	if playback and players.is_empty():
		for index: int in range(VOICES):
			var voice := AudioStreamPlayer.new()
			voice.max_polyphony = 1
			add_child(voice)
			players.append(voice)


func set_volume(percent: int) -> void:
	volume_percent = clampi(percent, 0, 100)
	if volume_percent == 0:
		silence()
	else:
		for voice: AudioStreamPlayer in players:
			voice.volume_db = linear_to_db(float(volume_percent) / 100.0)


func silence() -> void:
	for voice: AudioStreamPlayer in players:
		voice.stop()
	occupied_until.fill(0)
	last_kind_tick.clear()
	variant_cursor.clear()
	last_clip_key = ""
	last_tick = -1
	_movement_tick = -1
	_batch_tick = -1
	_queued.clear()


func ingest(event: Dictionary, tick: int, actor_id: int, catalog: AbilityCatalog, allowed: bool) -> bool:
	_counters.requested+=1
	if not allowed or volume_percent <= 0 or tick < 0:
		_counters.muted_denied+=1
		return false
	var cue := describe(event, actor_id, catalog)
	if cue.is_empty() or clips.is_empty():
		_counters.invalid+=1
		return false
	if _batch_tick==tick:
		_queue_cue({"kind":"element","cue":cue,"key":("contact/" if cue.contact else "cast/")+String(cue.element),"priority":2 if cue.contact else 1})
		return false # queued is not an admitted playback
	return _admit_element(cue,tick)


func _admit_element(cue: Dictionary,tick: int) -> bool:
	if tick < last_tick:
		silence() # A reset/rejoin never retains a future voice or refractory gate.
	last_tick = tick
	var contact: bool = cue.contact
	var kind := "contact" if contact else "cast"
	var gap := 6 if contact else 8
	if last_kind_tick.has(kind) and tick - int(last_kind_tick[kind]) < gap:
		_counters.refractory+=1
		return false
	var selected := -1
	# Keep one voice available for paid contact confirmation. No voice stealing:
	# cutting a real-time tail produces clicks when simulation catches up.
	for offset: int in range(VOICES if contact else CONTACT_VOICE):
		var index := (CONTACT_VOICE + offset) % VOICES if contact else offset
		# Simulation can catch up or jump ahead of the audio mixer. A logical
		# expiry must not cut off a voice that is still finishing in real time.
		if occupied_until[index] <= tick and (players.is_empty() or not players[index].playing):
			selected = index
			break
	if selected < 0:
		_counters.pool_full+=1
		return false # Never allocate more nodes or restart a loud overlapping pile.
	var base_key := _key(String(cue.element), contact)
	var variant := int(variant_cursor.get(base_key, 0)) % VARIANTS
	var clip_key := _key(String(cue.element), contact, variant)
	var clip: AudioStreamWAV = clips.get(clip_key)
	if clip == null:
		_counters.invalid+=1
		return false
	occupied_until[selected] = tick + ceili(clip.get_length() * 120.0)
	last_kind_tick[kind] = tick
	variant_cursor[base_key] = (variant + 1) % VARIANTS
	last_clip_key = clip_key
	admitted_count += 1
	_counters.admitted+=1
	_category_admissions[kind]+=1
	if not players.is_empty() and is_inside_tree():
		var voice := players[selected]
		voice.stop()
		voice.stream = clip
		voice.volume_db = linear_to_db(float(volume_percent) / 100.0)
		voice.play()
	return true


func consequence(kind: String, tick: int, allowed: bool = true) -> bool:
	_counters.requested+=1
	if not allowed or volume_percent <= 0 or tick < 0:
		_counters.muted_denied+=1
		return false
	if not consequence_clips.has(kind):
		_counters.invalid+=1
		return false
	if _batch_tick==tick:
		_queue_cue({"kind":"result","result":kind,"key":kind,"priority":4 if kind=="damage" else 3 if kind=="confirmed" else 0})
		return false
	if tick < last_tick: silence()
	last_tick = tick
	var gate := "result_"+kind
	if last_kind_tick.has(gate) and tick-int(last_kind_tick[gate]) < (24 if kind == "damage" else 36):
		_counters.refractory+=1
		return false
	var critical := kind in ["damage","confirmed"]
	for offset: int in (VOICES if critical else CONTACT_VOICE):
		var index := (CONTACT_VOICE+offset)%VOICES if critical else offset
		if occupied_until[index] > tick or (not players.is_empty() and players[index].playing): continue
		var clip: AudioStreamWAV = consequence_clips[kind]
		occupied_until[index] = tick+ceili(clip.get_length()*120)
		last_kind_tick[gate] = tick
		last_clip_key = gate
		admitted_count += 1
		_counters.admitted+=1
		_category_admissions[kind]+=1
		if not players.is_empty() and is_inside_tree():
			players[index].stream = clip
			players[index].volume_db = linear_to_db(float(volume_percent)/100)
			players[index].play()
		return true
	_counters.pool_full+=1
	return false


func begin_batch(tick: int) -> void:
	# Root calls this only around one visible/local event batch. No cue survives
	# a tick handoff, mute, modal boundary or rejoin.
	if tick<0 or volume_percent<=0: return
	if tick<last_tick: silence()
	_queued.clear()
	_batch_tick=tick
	_queue_serial=0


func end_batch() -> void:
	var tick := _batch_tick
	_batch_tick=-1
	var pending := _queued
	_queued=[]
	if tick<0 or volume_percent<=0: return
	pending.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.order)<int(b.order) if int(a.priority)==int(b.priority) else int(a.priority)>int(b.priority))
	for cue: Dictionary in pending:
		if String(cue.kind)=="element": _admit_element(cue.cue,tick)
		else:
			_counters.requested-=1 # already counted when the event entered the batch
			consequence(String(cue.result),tick)


func _queue_cue(cue: Dictionary) -> void:
	for previous: Dictionary in _queued:
		if previous.key==cue.key:
			_counters.coalesced+=1
			return
	if _queued.size()>=MAX_QUEUED_CUES:
		var lowest := -1
		for index: int in _queued.size():
			if int(_queued[index].priority)<int(cue.priority) and (lowest<0 or int(_queued[index].priority)<int(_queued[lowest].priority)): lowest=index
		_counters.queue_full+=1
		if lowest<0: return
		_queued.remove_at(lowest)
	cue["order"]=_queue_serial
	_queue_serial+=1
	_queued.append(cue)
	_counters.peak_queued=maxi(int(_counters.peak_queued),_queued.size())


func diagnostics() -> Dictionary:
	return {"counters":_counters.duplicate(true),"admitted_by_kind":_category_admissions.duplicate(true),"queued":_queued.size(),"queue_limit":MAX_QUEUED_CUES,"voice_limit":VOICES,"playback_nodes":players.size(),"stealing":false}


func observe_movement(state: PlayerState, tick: int, allowed: bool) -> void:
	if state == null or not allowed or tick < _movement_tick:
		_movement_tick = -1
		return
	if tick == _movement_tick: return
	var airborne := state.is_airborne()
	var attached := state.wall_skim_ticks > 0 and state.wall_skim_surface_id > 0
	if _movement_tick >= 0:
		if _was_airborne and not airborne and state.last_event in ["land","wave_dash"]: consequence("landed",tick)
		elif _was_attached and not attached and state.last_event == "wall_kick": consequence("wall_exit",tick)
	_movement_tick = tick
	_was_airborne = airborne
	_was_attached = attached


static func make_consequence_clip(kind: String) -> AudioStreamWAV:
	if not CONSEQUENCES.has(kind): return null
	var recipe: Array = CONSEQUENCES[kind]
	var count := ceili(float(recipe[2])*RATE)
	var data := PackedByteArray()
	data.resize(count*2)
	var phase := 0.0
	for index: int in count:
		var progress := float(index)/float(count-1)
		phase += TAU*float(recipe[0])*lerpf(1.0,float(recipe[1]),progress)/RATE
		var signal_value := sin(phase)*0.72+sin(phase*1.5)*0.28
		var envelope := minf(1.0,float(index)/(RATE*0.008))*pow(1-progress,1.7)
		data.encode_s16(index*2,roundi(signal_value*envelope*PEAK*0.7*32767))
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = RATE
	clip.data = data
	return clip


static func describe(event: Dictionary, actor_id: int, catalog: AbilityCatalog) -> Dictionary:
	if actor_id <= 0 or catalog == null or catalog.content_hash.is_empty():
		return {}
	var kind := String(event.get("type", ""))
	var contact := kind in ["projectile_hit", "spray_hit", "field_triggered", "beam_fired", "spray_intercepted"]
	if kind != "cast_started" and not contact:
		return {}
	if int(event.get("entity_id" if kind == "cast_started" else "owner_id", 0)) != actor_id:
		return {}
	if contact and kind != "spray_intercepted" and int(event.get("target_id", 0)) <= 0:
		return {}
	var wire := int(event.get("wire_id" if kind == "cast_started" else "source_wire_id", 0))
	if not wire in catalog.runtime_wire_ids:
		return {}
	var ability: Dictionary = catalog.ability_from_wire(wire)
	var shapes := {"projectile_hit": "projectile", "spray_hit": "spray", "field_triggered": "field", "beam_fired": "beam", "spray_intercepted": "spray"}
	if contact and String(ability.get("shape", "")) != String(shapes[kind]):
		return {}
	var element := String(ability.get("element", ""))
	return {"element": element, "contact": contact} if element in ELEMENTS else {}


static func make_clip(element: String, contact: bool, variant: int = 0) -> AudioStreamWAV:
	var element_index := ELEMENTS.find(element)
	if element_index < 0 or variant < 0 or variant >= VARIANTS:
		return null
	var recipe: Array = RECIPES[element_index]
	var duration := float(recipe[4]) * (1.0 if contact else 0.65)
	var count := ceili(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase := 0.0
	var tail_phase := 0.0
	var noise := 0.0
	var fast_noise := 0.0
	var seed_value: int = 7411 + element_index * 1777 + variant * 2357
	var pitch: float = [1.0, 0.965, 1.035][variant]
	for index: int in range(count):
		var progress := float(index) / float(count - 1)
		var seconds := float(index) / RATE
		seed_value = (seed_value * 1664525 + 1013904223) & 0x7fffffff
		var white := float(seed_value) / 1073741823.5 - 1.0
		noise = lerpf(noise, white, 0.08 if element == "wind" else 0.16)
		fast_noise = lerpf(fast_noise, white, 0.48)
		var frequency := float(recipe[0]) * lerpf(1.0, float(recipe[1]), progress) * pitch
		if not contact:
			frequency *= 0.80
		phase += TAU * frequency / RATE
		tail_phase += TAU * frequency * (1.5 if element in ["ice", "light"] else 0.51) / RATE
		var harmonic := float(recipe[3])
		var tone := sin(phase) * (1.0 - harmonic) + sin(phase * 2.7) * harmonic
		var body := lerpf(tone, noise, float(recipe[2]))
		var transient := lerpf(sin(phase * 1.8), fast_noise, 0.55)
		var tail := lerpf(sin(tail_phase), noise, float(recipe[2]))
		match element:
			"earth":
				transient = fast_noise
				tail = lerpf(sin(tail_phase), noise, 0.40)
			"fire":
				transient = fast_noise
				body *= 0.64 + 0.36 * pow(sin(seconds * 147.0 + variant), 2.0)
				tail = noise
			"water":
				transient = sin(phase * 1.7)
				tail *= 0.48 + 0.52 * pow(sin(progress * PI), 2.0)
			"wind":
				transient = fast_noise * 0.65
				tail = noise
			"ice", "light":
				transient = sin(phase * 2.0) * 0.65
				tail = sin(tail_phase) * 0.78 + sin(tail_phase * 1.3333) * 0.22
			"charge":
				transient = fast_noise
				body *= 0.70 + 0.30 * sin(seconds * 213.0)
			"dark":
				transient = sin(phase * 0.7)
				body *= 0.76 + 0.24 * sin(progress * TAU * 2.0)
				tail *= 0.70 + 0.30 * sin(progress * TAU * 2.0 + 0.8)
		# Convex layer weights preserve the four-voice peak bound without a
		# compressor or mixer effect. End ramps prevent discontinuous stops.
		var signal_value := transient * 0.22 * exp(-seconds * 72.0) + body * 0.54 + tail * 0.24 * minf(1.0, seconds * 30.0)
		var attack := minf(1.0, float(index) / (RATE * 0.005))
		var envelope := attack * pow(1.0 - progress, 1.4)
		var value := roundi(signal_value * envelope * PEAK * (1.0 if contact else 0.52) * 32767.0)
		bytes.encode_s16(index * 2, value)
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = RATE
	clip.stereo = false
	clip.loop_mode = AudioStreamWAV.LOOP_DISABLED
	clip.data = bytes
	return clip


static func _key(element: String, contact: bool, variant: int = 0) -> String:
	return element + ("_contact" if contact else "_cast") + ("_v%d" % variant if variant > 0 else "")
