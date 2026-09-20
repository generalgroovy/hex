extends FluxTestSuite


const BootstrapScript: Script = preload("res://src/app/bootstrap.gd")


# No-auto fixture: exercise the production client envelope and presentation
# methods without running Bootstrap._ready(), opening sockets, or touching the
# player profile.
class FeedbackHarness:
	extends "res://src/app/bootstrap.gd"

	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func _draw() -> void:
		pass


func run() -> int:
	_test_remote_clash_is_decoded_ingested_and_deduplicated()
	return finish("hex-clash-feedback")


func _test_remote_clash_is_decoded_ingested_and_deduplicated() -> void:
	var node := FeedbackHarness.new()
	node.preference_overrides_are_transient = true
	node.preferences_persistence_allowed = false
	node.campus_layout = SanctumCampusLayout.new()
	check(node.campus_layout.load_from_file(BootstrapScript.CAMPUS_LAYOUT_PATH), "remote clash fixture loads the trusted Wellspring campus")
	node.ability_catalog = AbilityCatalog.new()
	check(node.ability_catalog.load_from_file(BootstrapScript.ABILITY_CATALOG_PATH), "remote clash fixture loads current runtime spells")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file(BootstrapScript.CHAMPION_CATALOG_PATH, node.ability_catalog), "remote clash fixture loads current champions")
	if node.campus_layout.last_error != "" or node.ability_catalog.last_error != "" or champions.last_error != "":
		node.free()
		return

	var authority: SimWorld = node._new_wellspring_world(120)
	var trusted_template: SimWorld = node._new_wellspring_world(120)
	check(authority != null and trusted_template != null, "remote clash fixture builds independent production topology and trust template")
	if authority == null or trusted_template == null:
		node.free()
		return
	var spawn_fixed: Vector2i = node.campus_layout.spawn * SimConfig.FIXED_SCALE
	check(champions.apply_to_player(authority.player(), champions.default_champion_id), "remote clash authority applies the host champion")
	check(champions.apply_to_player(trusted_template.player(), champions.default_champion_id), "remote clash trust template remains a valid complete world")
	authority.player().reset_for_spawn(spawn_fixed)
	trusted_template.player().reset_for_spawn(spawn_fixed)

	var host := AuthoritativeSession.new()
	check(host.bind(authority, champions, node.campus_layout.spawn, "Clash Host", [{"entity_id": 2, "name": "Clash Guest"}]), "remote clash fixture binds a host and actual guest roster")
	if authority.player(2) == null:
		node.free()
		return
	var source_wire: int = authority.player().spell_wire_ids[0]
	var other_wire: int = authority.player().spell_wire_ids[1]
	var contact := Vector2i(1_640_125, 1_279_875)
	var clash: Dictionary = {
		"type": "hex_clash",
		"source_wire_id": source_wire,
		"other_wire_id": other_wire,
		"x": contact.x,
		"y": contact.y,
		"first_remaining": 10,
		"second_remaining": 0,
	}
	equal(host.record_combat_events([clash]), 1, "remote clash enters production event retention")
	var first_envelope: Dictionary = host.capture_envelope()
	check(WorldSnapshotEnvelope.validate(first_envelope), "first remote clash envelope validates through the production unified codec")
	if first_envelope.is_empty():
		node.free()
		return

	node.trusted_hex_template = trusted_template
	node.session_transport = SessionTransport.new()
	node.session_transport.local_entity_id = 2
	node.client_prediction = ClientPrediction.new()
	node.session_event_inbox = SessionEventInbox.new()
	var first_applied: bool = node._apply_world_envelope(first_envelope)
	check(first_applied, "actual client apply decodes the first remote clash envelope")
	if not first_applied or node.world == null:
		node.free()
		return
	node.last_client_snapshot_tick = int(first_envelope.tick)
	equal(node.world.combat_events.size(), 1, "actual client world receives one decoded clash event")
	var first_events: Array[Dictionary] = node.session_event_inbox.take_unseen(node.world.combat_events)
	node.world.combat_events = first_events
	equal(first_events.size(), 1, "event inbox admits the clash identity exactly once")
	if first_events.is_empty():
		node.free()
		return
	var decoded: Dictionary = first_events[0]
	check(int(decoded.get("event_id", 0)) > 0, "decoded remote clash retains its stable redundancy identity")
	for key: String in ["source_wire_id", "other_wire_id", "x", "y", "first_remaining", "second_remaining"]:
		equal(decoded.get(key), clash.get(key), "actual client decode preserves exact clash %s" % key)
	node._ingest_combat_cues(first_events)
	equal(node.combat_cues.size(), 1, "actual client ingestion creates one remote clash cue")
	if node.combat_cues.is_empty():
		node.free()
		return
	var cue: Dictionary = node.combat_cues[0]
	equal(String(cue.get("event_type", "")), "hex_clash", "remote cue retains its clash presentation semantic")
	equal(cue.get("position"), Vector2(contact) / SimConfig.FIXED_SCALE, "remote cue uses the exact authoritative contact point")
	equal(int(cue.get("source_wire_id", 0)), source_wire, "remote cue retains the first spell identity")
	equal(int(cue.get("other_wire_id", 0)), other_wire, "remote cue retains the opposing spell identity")
	equal(int(cue.get("first_remaining", -1)), 10, "remote cue retains first post-contact strength")
	equal(int(cue.get("second_remaining", -1)), 0, "remote cue retains second post-contact strength")
	equal(float(cue.get("remaining", 0.0)), 0.15, "remote clash cue starts with the production finite lifetime")
	equal(float(cue.get("duration", 0.0)), 0.15, "remote clash cue exposes the exact production duration")

	host.acknowledge_snapshot()
	check(authority.step([]), "authority advances to a later redundancy snapshot without fabricating another clash")
	var redundant_envelope: Dictionary = host.capture_envelope()
	check(WorldSnapshotEnvelope.validate(redundant_envelope), "later envelope carries the retained clash redundancy copy")
	if redundant_envelope.is_empty():
		node.free()
		return
	var redundant_applied: bool = node._apply_world_envelope(redundant_envelope)
	check(redundant_applied, "actual client applies the later redundancy envelope")
	if not redundant_applied:
		node.free()
		return
	node.last_client_snapshot_tick = int(redundant_envelope.tick)
	equal(node.world.combat_events.size(), 1, "later client world decodes the retained redundancy copy")
	var redundant_events: Array[Dictionary] = node.session_event_inbox.take_unseen(node.world.combat_events)
	node.world.combat_events = redundant_events
	equal(redundant_events.size(), 0, "event inbox suppresses the already presented clash identity")
	node._ingest_combat_cues(redundant_events)
	equal(node.combat_cues.size(), 1, "redundant envelope cannot create a second clash cue")
	equal(int(node.combat_cues[0].get("event_id", 0)), int(decoded.event_id), "the sole retained cue keeps the first exact event identity")
	node.free()
