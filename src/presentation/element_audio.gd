class_name ElementAudio
extends Node

# Local, non-positional feedback only: never a source of enemy positions or rules.
# Editable synthesis recipes generate short cached PCM clips once, not per shot.
const RATE := 22050
const VOICES := 4
const PEAK := 0.22 # Four coincident full-volume voices stay below unity.
const ELEMENTS := ["earth", "fire", "water", "wind", "ice", "charge", "light", "dark"]
# Fundamental, end/start pitch ratio, filtered noise, harmonic weight, duration.
const RECIPES := [
	[115.0, 0.42, 0.32, 0.18, 0.18], # Earth: low tumbling knock.
	[260.0, 0.65, 0.68, 0.10, 0.15], # Fire: dry crackling puff.
	[610.0, 0.38, 0.10, 0.18, 0.18], # Water: rounded descending drop.
	[320.0, 1.25, 0.88, 0.00, 0.20], # Wind: filtered breath.
	[1450.0, 0.96, 0.04, 0.38, 0.18], # Ice: short glass chime.
	[780.0, 0.48, 0.26, 0.32, 0.13], # Charge: descending electric chirp.
	[880.0, 1.13, 0.02, 0.36, 0.22], # Light: rising clear bell.
	[160.0, 0.55, 0.10, 0.34, 0.22], # Dark: low hollow wobble.
]
var volume_percent := 30
var clips: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var occupied_until: Array[int] = [0, 0, 0, 0]
var last_kind_tick: Dictionary = {}
var last_tick := -1
var admitted_count := 0


func prepare(playback: bool = true) -> void:
	if clips.is_empty():
		for element: String in ELEMENTS:
			for contact: bool in [false, true]:
				clips[_key(element, contact)] = make_clip(element, contact)
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
	for index: int in range(VOICES):
		# Simulation can catch up or jump ahead of the audio mixer. A logical
		# expiry must not cut off a voice that is still finishing in real time.
		if occupied_until[index] <= tick and (players.is_empty() or not players[index].playing):
			selected = index
			break
	if selected < 0:
		return false # Never allocate more nodes or restart a loud overlapping pile.
	var clip: AudioStreamWAV = clips[_key(String(cue.element), contact)]
	occupied_until[selected] = tick + ceili(clip.get_length() * 120.0)
	last_kind_tick[kind] = tick
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


static func make_clip(element: String, contact: bool) -> AudioStreamWAV:
	var element_index := ELEMENTS.find(element)
	if element_index < 0:
		return null
	var recipe: Array = RECIPES[element_index]
	var duration := float(recipe[4]) * (1.0 if contact else 0.65)
	var count := ceili(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase := 0.0
	var noise := 0.0
	var seed_value: int = 7411 + element_index * 1777
	for index: int in range(count):
		var progress := float(index) / float(count - 1)
		seed_value = (seed_value * 1664525 + 1013904223) & 0x7fffffff
		noise = lerpf(noise, float(seed_value) / 1073741823.5 - 1.0, 0.16)
		var frequency := float(recipe[0]) * lerpf(1.0, float(recipe[1]), progress)
		if not contact:
			frequency *= 0.80
		phase += TAU * frequency / RATE
		var harmonic := float(recipe[3])
		var tone := sin(phase) * (1.0 - harmonic) + sin(phase * 2.7) * harmonic
		if element == "dark":
			tone *= 0.78 + 0.22 * sin(progress * TAU * 3.0)
		var signal_value := lerpf(tone, noise, float(recipe[2]))
		var attack := minf(1.0, float(index) / (RATE * 0.005))
		var envelope := attack * pow(1.0 - progress, 1.4)
		var value := roundi(signal_value * envelope * PEAK * (1.0 if contact else 0.60) * 32767.0)
		bytes.encode_s16(index * 2, value)
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = RATE
	clip.stereo = false
	clip.loop_mode = AudioStreamWAV.LOOP_DISABLED
	clip.data = bytes
	return clip


static func _key(element: String, contact: bool) -> String:
	return element + ("_contact" if contact else "_cast")
