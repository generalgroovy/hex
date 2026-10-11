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
var players: Array[AudioStreamPlayer] = []
var occupied_until: Array[int] = [0, 0, 0, 0]
var last_kind_tick: Dictionary = {}
var variant_cursor: Dictionary = {}
var last_clip_key := ""
var last_tick := -1
var admitted_count := 0


func prepare(playback: bool = true) -> void:
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


func ingest(event: Dictionary, tick: int, actor_id: int, catalog: AbilityCatalog, allowed: bool) -> bool:
	if not allowed or volume_percent <= 0 or tick < 0:
		return false
	var cue := describe(event, actor_id, catalog)
	if cue.is_empty() or clips.is_empty():
		return false
	if tick < last_tick:
		silence() # A reset/rejoin never retains a future voice or refractory gate.
	last_tick = tick
	var contact: bool = cue.contact
	var kind := "contact" if contact else "cast"
	var gap := 6 if contact else 8
	if last_kind_tick.has(kind) and tick - int(last_kind_tick[kind]) < gap:
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
		return false # Never allocate more nodes or restart a loud overlapping pile.
	var base_key := _key(String(cue.element), contact)
	var variant := int(variant_cursor.get(base_key, 0)) % VARIANTS
	var clip_key := _key(String(cue.element), contact, variant)
	var clip: AudioStreamWAV = clips.get(clip_key)
	if clip == null:
		return false
	occupied_until[selected] = tick + ceili(clip.get_length() * 120.0)
	last_kind_tick[kind] = tick
	variant_cursor[base_key] = (variant + 1) % VARIANTS
	last_clip_key = clip_key
	admitted_count += 1
	if not players.is_empty() and is_inside_tree():
		var voice := players[selected]
		voice.stop()
		voice.stream = clip
		voice.volume_db = linear_to_db(float(volume_percent) / 100.0)
		voice.play()
	return true


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
