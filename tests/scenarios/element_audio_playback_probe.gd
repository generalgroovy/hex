extends SceneTree


# Exercise the actual AudioStreamPlayer route through Dummy, never user speakers.
# Numerical/device/human hearing acceptance remain separate.
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if AudioServer.get_driver_name() != "Dummy":
		push_error("Audio probe requires --audio-driver Dummy")
		quit(1)
		return
	var catalog := AbilityCatalog.new()
	if not catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"):
		quit(1)
		return
	var feedback := ElementAudio.new()
	root.add_child(feedback)
	feedback.prepare()
	feedback.set_volume(30)
	var admissions := 0
	for element: String in ElementAudio.ELEMENTS:
		var wire := int(catalog.ability(catalog.spell_id_at(element, "bolt")).wire_id)
		for contact: bool in [false, true]:
			feedback.silence()
			var event := {"type": "projectile_hit", "owner_id": 1, "target_id": 2, "source_wire_id": wire} if contact else {"type": "cast_started", "entity_id": 1, "wire_id": wire}
			if not feedback.ingest(event, admissions * 30, 1, catalog, true) or not feedback.players[0].playing:
				push_error("Actual voice did not start: " + element)
				quit(1)
				return
			admissions += 1
			await process_frame
			feedback.set_volume(0)
			for voice: AudioStreamPlayer in feedback.players:
				if voice.playing:
					push_error("Mute did not stop actual voice")
					quit(1)
					return
			feedback.set_volume(30)
	feedback.queue_free()
	await process_frame
	# The audio server retires stopped playback handles on its mixer cycle.
	await create_timer(0.25).timeout
	print("PASS: 16 actual AudioStreamPlayer starts/mutes;4 owned nodes;Dummy output only;no listening claim")
	quit(0)
