extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var scene: PackedScene = load("res://scenes/bootstrap/bootstrap.tscn")
	var game: Node = scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	var world: SimWorld = game.world
	var snapshot := HexWorldSnapshot.capture(world)
	var chemistry := HexChemistrySnapshot.capture(world.hex_court)
	var envelope: Dictionary = game.authoritative_session.capture_envelope() if game.authoritative_session != null else {}
	var actors: Array = []
	for actor: PlayerState in world.players:
		actors.append({"id":actor.entity_id,"kind":actor.actor_kind,"champion":actor.champion_wire_id,"position":[actor.position_x,actor.position_y],"health":actor.health,"row_valid":HexWorldSnapshot._valid_player_values(actor.canonical_values()),"canonical":Array(actor.canonical_values())})
	print("BOOTSTRAP_CAPTURE_PROBE ",JSON.stringify({"tick":world.tick,"hex_tick":world.hex_court.current_tick,"trusted_world":HexWorldSnapshot._trusted_world_valid(world),"actor_set":HexWorldSnapshot._validate_actor_set(world.players),"relations":HexWorldSnapshot._validate_relations(world),"world_snapshot_empty":snapshot.is_empty(),"chemistry_snapshot_empty":chemistry.is_empty(),"envelope_empty":envelope.is_empty(),"actors":actors,"legacy_sizes":[world.fields.size(),world.deposits.size(),world.reactions.size()],"map":world.map_id,"session":game.authoritative_session!=null}))
	game.queue_free()
	await process_frame
	quit(0)
