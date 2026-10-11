extends FluxTestSuite

const Elements = preload("res://src/content/element_rules.gd")
const Audio = preload("res://src/presentation/element_audio.gd")
const Harness = preload("res://tests/support/element_audio_harness.gd")
const CONTACTS := {"bolt": "projectile_hit", "spray": "spray_hit", "field": "field_triggered", "beam": "beam_fired"}
const LIVE_CONTACTS := {"bolt": "projectile_hit", "heavy": "projectile_hit", "rapid": "projectile_hit", "spray": "spray_hit"}
var catalog := AbilityCatalog.new()
var cached_clips: Dictionary = {}


func run() -> int:
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "audio tests load the production ability catalog")
	_test_pcm_contract()
	_test_catalog_admission()
	_test_variant_rotation_and_contact_reservation()
	_test_rate_pool_and_reset()
	_test_playback_clock_occupancy()
	_test_owned_voice_cleanup()
	_test_inherited_bootstrap_gates()
	_test_controls_header_and_sound_input()
	_test_real_paid_casts_and_contacts()
	return finish("element-audio")


func _test_pcm_contract() -> void:
	var audio := Audio.new()
	audio.prepare(false)
	equal(audio.players.size(), 0, "silent preparation creates no playback nodes")
	equal(audio.clips.size(), 8 * 2 * Audio.VARIANTS, "every retained style caches three cast and contact variations before gameplay")
	equal(audio.volume_percent, 30, "elemental sound starts at conservative 30 percent gain")
	check(Audio.PEAK * Audio.VOICES <= 0.88, "four worst-case coherent voices retain full-volume headroom")
	check(Audio.PEAK * Audio.VOICES * 0.30 <= 0.264, "default four-voice mix stays below 26.4 percent full scale")
	var signatures := {}
	var pcm_bytes := 0
	for element: String in Audio.ELEMENTS:
		for contact: bool in [false, true]:
			for variant: int in Audio.VARIANTS:
				var key := Audio._key(element, contact, variant)
				var clip: AudioStreamWAV = audio.clips[key]
				pcm_bytes += clip.data.size()
				equal(clip.format, AudioStreamWAV.FORMAT_16_BITS, key + " is signed 16-bit PCM")
				equal(clip.mix_rate, 22050, key + " uses the bounded fixed sample rate")
				check(not clip.stereo and clip.loop_mode == AudioStreamWAV.LOOP_DISABLED, key + " is a non-looping mono cue")
				check(clip.data.size() > 2 and clip.data.size() % 2 == 0, key + " has complete nonempty PCM samples")
				check(is_finite(clip.get_length()) and clip.get_length() > 0.08 and clip.get_length() <= 0.311, key + " duration is short and finite")
				@warning_ignore("integer_division")
				var samples := clip.data.size() / 2
				equal(clip.data.decode_s16(0), 0, key + " starts exactly at silence")
				equal(clip.data.decode_s16((samples - 1) * 2), 0, key + " ends exactly at silence")
				var peak := 0.0
				var sum := 0.0
				var energy := 0.0
				var max_step := 0.0
				var first_ms_peak := 0.0
				var tail_ms_peak := 0.0
				var previous := 0.0
				for index: int in range(samples):
					var sample := float(clip.data.decode_s16(index * 2)) / 32767.0
					peak = maxf(peak, absf(sample))
					sum += sample
					energy += sample * sample
					max_step = maxf(max_step, absf(sample - previous))
					previous = sample
					if index < 22:
						first_ms_peak = maxf(first_ms_peak, absf(sample))
					if index >= samples - 22:
						tail_ms_peak = maxf(tail_ms_peak, absf(sample))
				var mean := sum / samples
				var rms := sqrt(energy / samples)
				check(is_finite(peak) and is_finite(mean) and is_finite(rms), key + " decoded signal metrics are finite")
				check(peak > 0.005 and peak <= Audio.PEAK + 1.0 / 32767.0, key + " has audible content without full-scale clipping")
				check(absf(mean) < 0.004 and absf(mean) < rms * 0.12, key + " has negligible DC offset, not a sustained bias")
				# Ice's authored 2.7x harmonic has a smooth high-frequency slope;
				# distinguish that from an abrupt full-height onset/cutoff above.
				check(max_step < 0.16, key + " has bounded adjacent-sample change including its high harmonic")
				check(first_ms_peak < 0.045 and tail_ms_peak < 0.002, key + " ramps at both ends rather than hard-starting or cutting off")
				var signature := clip.data.hex_encode().sha256_text()
				check(not signatures.has(signature), key + " is distinct from every other element and event clip")
				signatures[signature] = true
				equal(Audio.make_clip(element, contact, variant).data, clip.data, key + " synthesis is repeatable independent of process randomness")
				print("PCM %s peak=%.5f rms=%.5f mean=%.6f max_step=%.5f" % [key, peak, rms, mean, max_step])
		var cast: AudioStreamWAV = audio.clips[Audio._key(element, false)]
		var hit: AudioStreamWAV = audio.clips[Audio._key(element, true)]
		check(cast.get_length() < hit.get_length(), element + " startup is shorter than confirmed contact")
	check(pcm_bytes <= Audio.MAX_PCM_BYTES, "entire deterministic variation bank stays below one MiB")
	cached_clips = audio.clips.duplicate()
	audio.prepare(false)
	for key: String in cached_clips:
		equal(audio.clips[key], cached_clips[key], "preparation reuses cached resources: " + key)
	check(Audio.make_clip("unreleased_element", false) == null, "unknown element cannot fabricate a clip")
	audio.free()


func _cast(wire: int, owner: int = 1) -> Dictionary:
	return {"type": "cast_started", "entity_id": owner, "wire_id": wire}


func _contact(wire: int, kind: String, owner: int = 1, target: int = 2) -> Dictionary:
	return {"type": kind, "owner_id": owner, "source_wire_id": wire, "target_id": target}


func _wire(element: String, family: String = "bolt") -> int:
	return int(catalog.ability(catalog.spell_id_at(element, family)).wire_id)


func _silent_audio() -> Audio:
	var audio := Audio.new()
	audio.clips = cached_clips.duplicate()
	audio.prepare(false)
	return audio


func _test_catalog_admission() -> void:
	var seen_elements := {}
	for wire: int in catalog.runtime_wire_ids:
		var ability := catalog.ability_from_wire(wire)
		var element := String(ability.element)
		var event := _cast(wire)
		equal(Audio.describe(event, 1, catalog), {"element": element, "contact": false}, "playable own startup uses catalog element for wire %d" % wire)
		equal(Audio.describe(SessionSnapshot.decode_event(SessionSnapshot.encode_event(event)), 1, catalog), Audio.describe(event, 1, catalog), "snapshot startup preserves audio identity for wire %d" % wire)
		check(Audio.describe(event, 2, catalog).is_empty(), "remote startup stays silent for wire %d" % wire)
		seen_elements[element] = true
		for family: String in CONTACTS:
			var kind := String(CONTACTS[family])
			var shape := "projectile" if family == "bolt" else family
			var hit := _contact(wire, kind)
			var cue := Audio.describe(hit, 1, catalog)
			if String(ability.shape) == shape:
				equal(cue, {"element": element, "contact": true}, "confirmed matching family is admitted for wire %d" % wire)
				equal(Audio.describe(SessionSnapshot.decode_event(SessionSnapshot.encode_event(hit)), 1, catalog), cue, "guest event preserves contact identity without invented damage for wire %d" % wire)
			else:
				check(cue.is_empty(), "wrong contact family is refused for wire %d/%s" % [wire, kind])
			check(Audio.describe(hit, 2, catalog).is_empty(), "remote contact is never a local cue")
			check(Audio.describe(_contact(wire, kind, 1, 0), 1, catalog).is_empty(), "miss/absent target is not confirmed contact")
	equal(seen_elements.size(), 6, "production playable catalog covers exactly six active audio elements")
	for element: String in Elements.IDS: check(seen_elements.has(element), "canonical live audio identity is present")
	for retired: int in [170,101,187,189]:
		check(Audio.describe(_cast(retired),1,catalog).is_empty(),"retained audio style cannot authorize a retired spell")
		check(Audio.describe(_contact(retired,"projectile_hit"),1,catalog).is_empty(),"retired spell has no live contact cue")
	var wire := _wire("fire")
	for event: Dictionary in [{}, _cast(0), _cast(999999), _cast(wire, 0), _contact(wire, "projectile_hit", 0), _contact(wire, "projectile_hit", 1, -1), {"type": "cast_started", "owner_id": 1, "wire_id": wire}]:
		check(Audio.describe(event, 1, catalog).is_empty(), "unknown or incomplete event cannot create local sound")
	for kind: String in ["cast_refused", "cast_blocked", "projectile_spawned", "projectile_bounced", "projectile_exploded", "spray_fired", "field_spawned", "field_expired", "champion_defeated", "chemistry_reaction"]:
		check(Audio.describe(_contact(wire, kind), 1, catalog).is_empty(), kind + " cannot masquerade as contact")
	check(Audio.describe(_cast(wire), 0, catalog).is_empty(), "missing local identity is silent")
	check(Audio.describe(_cast(wire), 1, null).is_empty(), "missing catalog is silent")
	check(Audio.describe(_cast(wire), 1, AbilityCatalog.new()).is_empty(), "unvalidated catalog is silent")


func _test_variant_rotation_and_contact_reservation() -> void:
	var audio := _silent_audio()
	var cast := _cast(_wire("light"))
	var contact := _contact(_wire("light"), "projectile_hit")
	for variant: int in range(Audio.VARIANTS * 2):
		check(audio.ingest(cast, variant * 120, 1, catalog, true), "well-spaced repeated casts are admitted")
		equal(audio.last_clip_key, Audio._key("light", false, variant % Audio.VARIANTS), "adjacent repeats rotate cached PCM deterministically")
	var cursor := audio.variant_cursor.duplicate()
	check(not audio.ingest(cast, (Audio.VARIANTS * 2 - 1) * 120, 1, catalog, true), "same-tick duplicate is refused")
	equal(audio.variant_cursor, cursor, "refusal cannot silently consume an audio variation")
	audio.silence()
	for tick: int in [0, 8, 16]:
		check(audio.ingest(cast, tick, 1, catalog, true), "three cast tails may share the non-reserved voices")
	check(not audio.ingest(cast, 24, 1, catalog, true), "startup chatter cannot take the contact reservation")
	equal(audio.occupied_until[Audio.CONTACT_VOICE], 0, "reserved voice remains free before confirmed contact")
	check(audio.ingest(contact, 24, 1, catalog, true), "confirmed contact remains audible under sustained startup chatter")
	check(audio.occupied_until[Audio.CONTACT_VOICE] > 24, "confirmed contact uses its reserved voice")
	equal(audio.last_clip_key, Audio._key("light", true, 0), "reset and contact use an independent variation sequence")
	check(Audio.make_clip("light", true, -1) == null and Audio.make_clip("light", true, Audio.VARIANTS) == null, "out-of-budget variation cannot allocate PCM")
	audio.silence()
	check(audio.variant_cursor.is_empty(), "silence resets the variation sequence for the next session")
	equal(audio.clips, cached_clips, "sound priority and variation never regenerate resources")
	audio.free()


func _test_rate_pool_and_reset() -> void:
	var audio := _silent_audio()
	var cast := _cast(_wire("light"))
	var contact := _contact(_wire("light"), "projectile_hit")
	var unprepared := Audio.new()
	check(not unprepared.ingest(cast, 0, 1, catalog, true), "unprepared audio fails closed")
	unprepared.free()
	check(not audio.ingest(cast, -1, 1, catalog, true), "negative tick is rejected")
	check(not audio.ingest(cast, 0, 1, catalog, false), "caller denial is respected")
	equal(audio.last_tick, -1, "denied input does not advance audio time")
	check(audio.ingest(cast, 0, 1, catalog, true), "first own cast is admitted")
	check(audio.ingest(contact, 0, 1, catalog, true), "separate contact gate permits same-tick confirmation")
	for tick: int in range(1, 6):
		check(not audio.ingest(cast, tick, 1, catalog, true) and not audio.ingest(contact, tick, 1, catalog, true), "same-kind bursts are refractory")
	check(audio.ingest(contact, 6, 1, catalog, true), "contact gate opens at exactly six ticks")
	check(not audio.ingest(cast, 7, 1, catalog, true), "cast gate remains closed through seven ticks")
	check(audio.ingest(cast, 8, 1, catalog, true), "cast gate opens at exactly eight ticks")
	equal(audio.occupied_until.filter(func(until: int) -> bool: return until > 8).size(), 4, "exactly four logical voices may be occupied")
	var before := audio.admitted_count
	check(not audio.ingest(contact, 12, 1, catalog, true), "full pool drops an otherwise eligible contact")
	equal(audio.admitted_count, before, "a dropped contact does not count as playback")
	check(audio.ingest(cast, audio.occupied_until[0], 1, catalog, true), "a finished short cue releases its voice without allocating")
	check(audio.ingest(cast, 0, 1, catalog, true), "backward world tick starts a fresh session gate")
	equal(audio.last_tick, 0, "reset retains no future tick")
	equal(audio.last_kind_tick.size(), 1, "backward time removes previous contact gate")
	equal(audio.occupied_until.filter(func(until: int) -> bool: return until > 0).size(), 1, "reset removes old overlapping occupancy")
	audio.set_volume(0)
	equal(audio.occupied_until, [0, 0, 0, 0], "mute releases every logical voice immediately")
	check(audio.last_kind_tick.is_empty() and audio.last_tick == -1, "mute clears timing gates")
	check(not audio.ingest(contact, 1, 1, catalog, true), "mute cannot admit new sounds")
	audio.set_volume(999)
	equal(audio.volume_percent, 100, "gain cannot exceed full scale")
	audio.set_volume(-1)
	equal(audio.volume_percent, 0, "negative gain clamps to mute")
	audio.set_volume(30)
	var cast_ticks: Array[int] = []
	var hit_ticks: Array[int] = []
	for tick: int in range(120):
		if audio.ingest(cast, tick, 1, catalog, true):
			cast_ticks.append(tick)
		if audio.ingest(contact, tick, 1, catalog, true):
			hit_ticks.append(tick)
		equal(audio.occupied_until.size(), 4, "sustained burst cannot grow the voice pool")
		equal(audio.players.size(), 0, "silent stress fixture never produces actual sound")
	check(cast_ticks.size() <= 15 and hit_ticks.size() <= 20, "120 Hz barrage respects both per-second admission ceilings")
	for sequence: Array in [cast_ticks, hit_ticks]:
		for index: int in range(1, sequence.size()):
			check(int(sequence[index]) - int(sequence[index - 1]) >= (8 if sequence == cast_ticks else 6), "sustained accepted sounds retain their exact minimum spacing")
	audio.silence()
	equal(audio.occupied_until, [0, 0, 0, 0], "explicit silence cleans every voice reservation")
	equal(audio.clips, cached_clips, "admission, mute and reset never regenerate or mutate PCM")
	audio.free()


func _test_playback_clock_occupancy() -> void:
	# Exercise real playback state through Dummy only. Looping, all-zero PCM
	# holds voices active without mixer scheduling races or wall-clock sleeps.
	check(AudioServer.get_driver_name() == "Dummy", "playback occupancy regression requires the silent Dummy driver")
	if AudioServer.get_driver_name() != "Dummy":
		return
	var audio := _silent_audio()
	var silent_clip := AudioStreamWAV.new()
	silent_clip.format = AudioStreamWAV.FORMAT_16_BITS
	silent_clip.mix_rate = Audio.RATE
	silent_clip.loop_mode = AudioStreamWAV.LOOP_FORWARD
	silent_clip.loop_end = Audio.RATE
	var bytes := PackedByteArray()
	bytes.resize(Audio.RATE * 2)
	bytes.fill(0)
	silent_clip.data = bytes
	var cast := _cast(_wire("light"))
	for variant: int in Audio.VARIANTS:
		audio.clips[Audio._key("light", false, variant)] = silent_clip
		audio.clips[Audio._key("light", true, variant)] = silent_clip
	audio.prepare(true)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(audio)
	for index: int in range(Audio.CONTACT_VOICE):
		check(audio.ingest(cast, index * 120, 1, catalog, true), "tick jumps use a free real voice without restarting an active one")
		check(audio.players[index].playing, "each tick jump occupies a distinct actual playback voice")
	check(audio.ingest(_contact(_wire("light"), "projectile_hit"), 360, 1, catalog, true), "confirmed contact occupies its reserved real voice")
	check(audio.players[Audio.CONTACT_VOICE].playing, "reserved contact voice plays in the bounded pool")
	var before := audio.admitted_count
	var reservations := audio.occupied_until.duplicate()
	check(not audio.ingest(cast, 480, 1, catalog, true), "expired logical reservations cannot reclaim four still-playing voices")
	equal(audio.admitted_count, before, "real playback saturation drops without counting an admission")
	equal(audio.occupied_until, reservations, "real playback saturation preserves every existing reservation")
	equal(audio.last_kind_tick.cast, 240, "dropped playback leaves the successful cast gate unchanged")
	audio.players[2].stop()
	check(audio.ingest(cast, 480, 1, catalog, true), "an actually stopped voice is reusable after its logical reservation")
	equal(audio.occupied_until[2], 600, "reuse reserves only the stopped voice for the new clip")
	equal(audio.players.size(), Audio.VOICES, "tick jumps never grow the actual playback pool")
	audio.silence()
	for voice: AudioStreamPlayer in audio.players:
		check(not voice.playing, "explicit silence clears actual playback as well as reservations")
	check(audio.ingest(cast, 0, 1, catalog, true), "silence resets both clocks for the next session")
	audio.players[0].stop()
	check(audio.ingest(cast, 8, 1, catalog, true), "another voice admits a cue after the unchanged eight-tick cast gap")
	check(not audio.players[0].playing and audio.players[1].playing, "stopping early does not bypass the first voice's logical reservation")
	audio.silence()
	audio.free()


func _test_owned_voice_cleanup() -> void:
	# Unattached Node: prepare allocates the pool, but no event is ever ingested
	# and no tree is entered, so AudioStreamPlayer.play cannot be called.
	var audio := _silent_audio()
	audio.prepare(true)
	audio.prepare(true)
	equal(audio.players.size(), 4, "real playback pool is allocated once at four voices")
	equal(audio.get_child_count(), 4, "idempotent preparation owns exactly four audio children")
	audio.set_volume(30)
	var voices := audio.players.duplicate()
	for voice: AudioStreamPlayer in voices:
		equal(voice.max_polyphony, 1, "each child has a single bounded voice")
		check(not voice.playing and voice.get_parent() == audio, "prepared voice is silent and owned by the audio node")
		check(absf(db_to_linear(voice.volume_db) - 0.30) < 0.00001, "actual child gain matches conservative preference")
	audio.set_volume(0)
	for voice: AudioStreamPlayer in voices:
		check(not voice.playing, "muting stops every real child")
	audio.free()
	for voice: Variant in voices:
		check(not is_instance_valid(voice), "freeing audio cleans up each owned playback child")


func _test_inherited_bootstrap_gates() -> void:
	var node := Harness.new()
	check(node.configure_fixture(catalog, cached_clips), "silent fixture uses inherited production bootstrap path")
	var cast := _cast(_wire("fire"))
	var contact := _contact(_wire("fire"), "projectile_hit")
	equal(node.ingest_fresh(cast), 1, "combat-cue hook actually routes local startup into audio")
	equal(node.ingest_fresh(contact), 1, "visible confirmed contact passes inherited guard")
	node.player_preferences.set_pov_mode(PlayerPreferences.POV_CONE)
	equal(node.ingest_fresh(contact), 1, "unified relative sight admits an actually visible contact after a legacy mode input")
	equal(node.ingest_fresh(cast), 1, "own startup does not depend on cone target visibility")
	node.player_preferences.set_pov_mode(PlayerPreferences.POV_FULL)
	node.world.player(2).position_x = 1_900_000
	equal(node.ingest_fresh(contact), 0, "legacy full input cannot reveal an off-screen contact")
	equal(node.ingest_fresh(cast), 1, "off-screen target does not suppress own startup")
	node.world.player(2).position_x = 420_000
	equal(node.ingest_fresh(contact), 1, "returning target to actual viewport restores contact")
	for panel: RefCounted in [node.controls_editor, node.spell_loom_editor, node.player_compendium, node.character_selection_grid]:
		panel.set("is_open", true)
		equal(node.ingest_fresh(cast), 0, "open production menu suppresses startup audio")
		equal(node.ingest_fresh(contact), 0, "open production menu suppresses contact audio")
		panel.set("is_open", false)
	node.join_address_editor_open = true
	equal(node.ingest_fresh(cast), 0, "join-address modal blocks sound")
	node.join_address_editor_open = false
	node.controls_input_guard_frames = 2
	equal(node.ingest_fresh(cast), 0, "menu rearm guard blocks sound")
	node.controls_input_guard_frames = 0
	node._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	equal(node.element_audio.occupied_until, [0, 0, 0, 0], "real focus loss clears existing sound reservations")
	equal(node.ingest_fresh(cast), 0, "unfocused application admits no audio")
	node._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	equal(node.ingest_fresh(cast), 0, "focus regain must finish its input guard")
	node.controls_input_guard_frames = 0
	node.world.player().health = 0
	equal(node.ingest_fresh(cast), 0, "defeated local actor cannot start sound")
	equal(node.ingest_fresh(contact), 0, "defeated local actor cannot confirm delayed contact sound")
	node.world.player().health = node.world.player().health_maximum
	equal(node.ingest_fresh(_contact(_wire("fire"), "projectile_hit", 1, 999)), 0, "absent target cannot leak a contact")
	equal(node.ingest_fresh(_cast(_wire("fire"), 2)), 0, "other player startup stays silent")
	var veil := ElementReactionState.new()
	veil.entity_id = 4000
	veil.recipe_wire_id = 310
	veil.owner_id = 1
	veil.team_id = 1
	veil.source_a = 3000
	veil.source_b = 3001
	veil.position_x = 360_000
	veil.position_y = 360_000
	veil.active_tick = 1
	veil.decay_tick = 240
	veil.expiry_tick = 300
	veil.radius = 40_000
	check(veil.validate(), "concealment fixture is a valid existing Steam reaction")
	node.world.reactions.append(veil)
	node.world.tick = 30
	check(not node._chemistry_actor_visible(node.world.player(2)), "real chemistry visibility conceals the distant target")
	equal(node.ingest_fresh(contact), 0, "hidden target contact produces no extra information")
	node.world.player(2).chemistry_reveal_ticks = 10
	equal(node.ingest_fresh(contact), 1, "authoritative reveal restores an otherwise visible local confirmation")
	node.world.reactions.clear()
	node.session_transport.mode = SessionTransport.Mode.CLIENT
	node.session_transport.accepted = true
	node.session_transport.local_entity_id = 2
	equal(node.ingest_fresh(_cast(_wire("water"), 2)), 1, "connected guest hears its own startup")
	equal(node.ingest_fresh(cast), 0, "connected guest never adopts host-owned cast sound")
	node.spectator_focus.active = true
	node.spectator_focus.focus_entity_id = 1
	check(node._is_spectating(), "spectator fixture reaches real inherited focus")
	equal(node.ingest_fresh(_cast(_wire("water"), 2)), 0, "spectating remains silent")
	node.spectator_focus.reset()
	node.session_transport.local_entity_id = 999
	equal(node._local_player_state().entity_id, 1, "missing guest fixture reaches existing host fallback")
	equal(node.ingest_fresh(cast), 0, "audio explicitly rejects missing-guest host fallback")
	node.session_transport.mode = SessionTransport.Mode.OFFLINE
	node._adjust_sound_volume(10)
	equal(node.player_preferences.sound_volume_percent, 40, "production header control adjusts the actual preference")
	equal(node.element_audio.volume_percent, 40, "production header control updates runtime gain")
	node._adjust_sound_volume(0, true)
	equal(node.ingest_fresh(cast), 0, "production mute control prevents sound")
	node._adjust_sound_volume(0, true)
	equal(node.element_audio.volume_percent, 30, "unmute restores conservative default, not full gain")
	node._adjust_sound_volume(1000)
	equal(node.element_audio.volume_percent, 100, "production volume control clamps its upper bound")
	node._adjust_sound_volume(-1000)
	equal(node.element_audio.volume_percent, 0, "production volume control clamps its lower bound")
	check(node.element_audio.players.is_empty(), "all inherited guard tests remain silent")
	var audio := node.element_audio
	node.cleanup_fixture()
	check(not is_instance_valid(audio), "bootstrap owns and cleans up its audio component")


func _test_controls_header_and_sound_input() -> void:
	var node := Harness.new()
	check(node.configure_fixture(catalog, cached_clips), "sound controls use the inherited modal input route")
	var buttons: Array[Rect2] = [node.SOUND_DOWN_RECT, node.SOUND_UP_RECT, node.SOUND_MUTE_RECT]
	for index: int in range(buttons.size()):
		check(ControlBindingEditor.PANEL_RECT.encloses(buttons[index]), "sound header button is wholly inside the actual Controls panel")
		check(buttons[index].end.y < ControlBindingEditor.FIRST_ROW_Y, "sound header stays clear of binding rows")
		for other: int in range(index + 1, buttons.size()):
			check(not buttons[index].intersects(buttons[other]), "sound header buttons have disjoint hit targets")
	var original_preferences := node.player_preferences.to_dictionary().duplicate(true)
	var original_world := node.world.state_hash()
	node.controls_editor.open_editor()
	for step: Array in [[KEY_BRACKETRIGHT, 40], [KEY_BRACKETLEFT, 30], [KEY_0, 0], [KEY_0, 30]]:
		var key := InputEventKey.new()
		key.keycode = step[0]
		key.pressed = true
		node._unhandled_input(key)
		equal(node.player_preferences.sound_volume_percent, step[1], "modal keyboard sound action reaches the actual preference")
		equal(node.element_audio.volume_percent, step[1], "modal keyboard sound action updates runtime gain")
		equal(node.controls_input_guard_frames, 2, "sound input retains the gameplay rearm guard")
		key.echo = true
		node._unhandled_input(key)
		equal(node.element_audio.volume_percent, step[1], "key repeat cannot repeat a sound adjustment or toggle")
		key.echo = false
		key.pressed = false
		node._unhandled_input(key)
		equal(node.element_audio.volume_percent, step[1], "key release cannot adjust sound")
	for index: int in range(buttons.size()):
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = buttons[index].get_center()
		node._unhandled_input(click)
		equal(node.element_audio.volume_percent, [20, 30, 0][index], "corrected header target reaches its matching sound action")
	var after_sound := node.player_preferences.to_dictionary()
	after_sound["sound_volume_percent"] = original_preferences["sound_volume_percent"]
	equal(after_sound, original_preferences, "sound controls preserve all keyboard, mouse, controller and other preferences")
	equal(node.binding_commit_count, 0, "sound controls never commit a gameplay binding")
	node._adjust_sound_volume(0, true)
	# Capture is the real editor branch; only its final global InputMap commit
	# is observed by the silent harness, so this suite cannot change user controls.
	node.controls_editor.selected_action_index = ControlBindingEditor.ACTIONS.find(&"jump")
	node.controls_editor.selected_device = ControlBindingEditor.DEVICE_KEYBOARD
	for keycode: int in [KEY_BRACKETLEFT, KEY_BRACKETRIGHT, KEY_0]:
		node.controls_editor.begin_capture()
		var key := InputEventKey.new()
		key.keycode = keycode
		key.pressed = true
		node._unhandled_input(key)
		equal(node.player_preferences.keyboard_bindings[&"jump"], keycode, "fixed sound shortcut remains capturable as a gameplay binding")
		equal(node.element_audio.volume_percent, 30, "binding capture never executes the fixed sound shortcut")
		check(not node.controls_editor.capturing, "accepted sound-key binding completes real capture")
	equal(node.binding_commit_count, 3, "only successful binding captures reach the isolated commit boundary")
	equal(node.world.state_hash(), original_world, "sound UI and binding capture do not advance or mutate gameplay")
	check(node.element_audio.players.is_empty(), "header input tests never access a playback device")
	node.cleanup_fixture()


func _test_real_paid_casts_and_contacts() -> void:
	for element: String in Elements.IDS:
		for family: String in LIVE_CONTACTS:
			var node := Harness.new()
			check(node.configure_fixture(catalog, cached_clips), "real cast fixture starts valid")
			var wire := _wire(element, family)
			var caster := node.world.player()
			var target := node.world.player(2)
			if family == "field":
				# Existing fields place at their fixed authored aim range, not
				# the command's pointer target. Put the enemy on that real center.
				target.position_x = caster.position_x + int(CombatTuning.cast_definition(wire).range)
			check(caster.place_proven_spell(0, wire), "%s/%s equips a real paid spell" % [element, family])
			var initial_flux := caster.flux
			check(node.world.step([SimCommand.new(0, 1, 0, 0, 0, SimCommand.PRESSED_SPELL_1, 1000, 0, target.position_x, target.position_y)]), "real semantic command advances")
			equal(caster.flux, initial_flux - int(CombatTuning.cast_definition(wire).flux_cost), "audio proof preserves actual cast economy")
			var saw_start := false
			var saw_contact := false
			for unused: int in range(120):
				var before := node.world.state_hash()
				for event: Dictionary in node.world.combat_events:
					if String(event.get("type", "")) == "cast_started":
						saw_start = true
						equal(node.ingest_fresh(event), 1, "%s/%s real paid startup reaches sound hook" % [element, family])
					if String(event.get("type", "")) == String(LIVE_CONTACTS[family]) and int(event.get("target_id", 0)) == 2:
						saw_contact = true
						equal(node.ingest_fresh(event), 1, "%s/%s authoritative contact reaches sound hook" % [element, family])
						var decoded := SessionSnapshot.decode_event(SessionSnapshot.encode_event(event))
						equal(node.ingest_fresh(decoded), 1, "wire-decoded confirmation needs no invented event data")
					equal(node.world.state_hash(), before, "audio presentation does not mutate authoritative simulation")
				if saw_contact:
					break
				check(node.world.step([]), "real startup/contact advances on authoritative 120 Hz ticks")
			check(saw_start and saw_contact, "%s/%s obtains both real startup and target confirmation" % [element, family])
			check(node.element_audio.players.is_empty(), "real gameplay evidence uses no playback device")
			node.cleanup_fixture()
