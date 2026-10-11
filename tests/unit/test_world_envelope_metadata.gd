extends "res://tests/unit/test_world_snapshot_envelope.gd"

const Bootstrap = preload("res://src/app/bootstrap.gd")
const PublicationFixtures = preload("res://tests/unit/test_world_publication_edges.gd")

class OverrideHarness:
	extends "res://src/app/bootstrap.gd"
	var apply_calls := 0
	var spectator_calls := 0
	var refuse_context := false
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _draw() -> void: pass
	func _apply_world_envelope(envelope: Dictionary) -> bool:
		apply_calls += 1
		return super._apply_world_envelope(envelope)
	func _incoming_spectator_state(candidate: SimWorld, envelope: Dictionary) -> bool:
		spectator_calls += 1
		return super._incoming_spectator_state(candidate, envelope)
	func _prepare_client_hex_context(predictor: ClientPrediction, candidate: SimWorld) -> Dictionary:
		return {} if refuse_context else super._prepare_client_hex_context(predictor, candidate)


class MutatingPrediction:
	extends ClientPrediction
	var envelope_alias: Dictionary = {}
	var mutation_stage := "prepare"
	var malformed := false
	var mutations := 0
	func prepare_hex_context(candidate: SimWorld) -> Dictionary:
		var result := super.prepare_hex_context(candidate)
		if mutation_stage == "prepare": _mutate_envelope()
		return result
	func publish_hex_context(prepared: Dictionary) -> void:
		super.publish_hex_context(prepared)
		if mutation_stage == "publish": _mutate_envelope()
	func _mutate_envelope() -> void:
		mutations += 1
		if malformed:
			envelope_alias.session.names[0][0] = 99
		else:
			envelope_alias.session.names[0][1] = "After " + mutation_stage
			var overflow: PackedInt32Array = envelope_alias.session.overflow
			overflow[0] = 37
			envelope_alias.session.overflow = overflow


class RefusedLaneHarness:
	extends OverrideHarness
	var overflow_calls := 0
	var observed_overflow := PackedInt32Array()
	func _apply_snapshot_overflow(values: PackedInt32Array) -> void:
		# Observe the unchanged getter's empty refusal without intentionally
		# indexing an empty array in the production sink during this test.
		overflow_calls += 1
		observed_overflow = values.duplicate()
		if not values.is_empty(): super._apply_snapshot_overflow(values)


class MutatingMotionHistory:
	extends ActorMotionHistory
	var envelope_alias: Dictionary = {}
	var mutations := 0
	func capture(states: Array[PlayerState]) -> void:
		super.capture(states)
		mutations += 1
		envelope_alias.session.names[0][1] = "After motion"
		var overflow: PackedInt32Array = envelope_alias.session.overflow
		overflow[0] = 37
		envelope_alias.session.overflow = overflow


func run() -> int:
	var legacy := Envelope.wrap_legacy(_legacy_snapshot(7, 1), 4)
	_assert_projection(legacy, "legacy")
	_test_mutations(legacy, "legacy")
	_test_detachment(legacy, "legacy")
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "metadata tests load unchanged abilities")
	if not catalog.last_error.is_empty(): return finish("world-envelope-metadata")
	var world := SimWorld.new()
	check(HexCourtPractice.configure(world, catalog, false), "metadata fixture configures trusted hex court")
	var authority_value := HexSnapshot.capture(world)
	var envelope := Envelope.wrap_hex(authority_value, _hex_session(world), 6)
	check(not envelope.is_empty(), "metadata fixture captures real hex envelope")
	if not envelope.is_empty():
		_assert_projection(envelope, "hex")
		_test_mutations(envelope, "hex")
		_test_detachment(envelope, "hex")
	_test_complete_sync()
	_test_failed_publication()
	_test_callback_mutations()
	return finish("world-envelope-metadata")


func _reference_metadata(envelope: Dictionary) -> Dictionary:
	# The existing public getters are unchanged and independently retain their
	# original complete validation on every call.
	if not Envelope.validate(envelope): return {}
	return {
		"world_kind": int(envelope.world_kind), "world_epoch": int(envelope.world_epoch), "tick": int(envelope.tick),
		"names": Envelope.names(envelope), "events": Envelope.events(envelope),
		"hearth": Envelope.hearth(envelope), "round": Envelope.round_state(envelope), "overflow": Envelope.overflow(envelope),
	}


func _assert_projection(envelope: Dictionary, label: String) -> void:
	var before := var_to_bytes(envelope)
	var expected := _reference_metadata(envelope)
	var actual := Envelope.metadata(envelope)
	check(not actual.is_empty() and actual == expected, label + " one-call projection equals all unchanged validated getters")
	check(var_to_bytes(actual) == var_to_bytes(expected), label + " typed metadata bytes and key order match the reference")
	equal(actual.size(), 8, label + " projection exposes only eight declared metadata fields")
	check(not actual.has("authority") and not actual.has("session"), label + " projection carries no reusable authority or envelope trust")
	check(Envelope.metadata(actual).is_empty(), label + " projection cannot be submitted as a validated envelope")
	check(var_to_bytes(envelope) == before, label + " projection leaves caller-owned envelope untouched")


func _test_mutations(envelope: Dictionary, label: String) -> void:
	for key: String in Envelope.ENVELOPE_KEYS:
		var missing: Dictionary = envelope.duplicate(true)
		missing.erase(key)
		_assert_refused(missing, label + " missing " + key)
	var extra: Dictionary = envelope.duplicate(true)
	extra.extra = true
	_assert_refused(extra, label + " extra envelope key")
	for key: String in ["schema", "world_kind", "world_epoch", "tick"]:
		var malformed: Dictionary = envelope.duplicate(true)
		malformed[key] = "1"
		_assert_refused(malformed, label + " wrong scalar type " + key)
	for key: String in ["world_epoch", "tick"]:
		for value: int in [-1, Envelope.MAX_EPOCH + 1]:
			var malformed: Dictionary = envelope.duplicate(true)
			malformed[key] = value
			_assert_refused(malformed, label + " out-of-range " + key)
	var mismatch: Dictionary = envelope.duplicate(true)
	mismatch.tick += 1
	_assert_refused(mismatch, label + " outer and authority tick mismatch")
	var bad_authority: Dictionary = envelope.duplicate(true)
	bad_authority.authority = {}
	_assert_refused(bad_authority, label + " malformed authority is not hidden by valid metadata")
	var lane_name := "session" if int(envelope.world_kind) == Envelope.WORLD_HEX else "authority"
	for key: String in ["events", "hearth", "round", "overflow"]:
		var malformed: Dictionary = envelope.duplicate(true)
		malformed[lane_name][key] = "wrong"
		_assert_refused(malformed, label + " wrong session lane " + key)
	var bad_names: Dictionary = envelope.duplicate(true)
	if lane_name == "session": bad_names.session.names[0][0] = 2
	else: bad_names.authority.players[0][0] = 0
	_assert_refused(bad_names, label + " broken actor/name relationship")
	if lane_name == "session":
		var unknown_lane: Dictionary = envelope.duplicate(true)
		unknown_lane.session.extra = 1
		_assert_refused(unknown_lane, label + " undeclared session field")
	else:
		var oversized: Dictionary = envelope.duplicate(true)
		var padding := PackedByteArray()
		padding.resize(Envelope.MAX_RAW_BYTES)
		oversized.authority._metadata_probe = padding
		check(SessionSnapshot.validate(oversized.authority), "oversized metadata fixture remains valid legacy authority")
		_assert_refused(oversized, label + " unchanged complete raw-size limit")
	var reused: Dictionary = envelope.duplicate(true)
	check(not Envelope.metadata(reused).is_empty(), label + " mutable envelope initially accepted")
	var saved_tick: int = reused.tick
	reused.tick += 1
	_assert_refused(reused, label + " mutation of previously accepted envelope")
	reused.tick = saved_tick
	check(Envelope.metadata(reused) == _reference_metadata(reused), label + " repaired same object is freshly validated")


func _assert_refused(envelope: Dictionary, label: String) -> void:
	var before := var_to_bytes(envelope)
	check(not Envelope.validate(envelope), label + " unchanged validator rejects")
	check(Envelope.metadata(envelope).is_empty(), label + " new metadata result rejects")
	check(Envelope.names(envelope).is_empty() and Envelope.events(envelope).is_empty(), label + " public array getters retain refusal")
	check(Envelope.hearth(envelope).is_empty() and Envelope.round_state(envelope).is_empty() and Envelope.overflow(envelope).is_empty(), label + " public packed getters retain refusal")
	check(var_to_bytes(envelope) == before, label + " rejection does not mutate caller data")


func _test_detachment(envelope: Dictionary, label: String) -> void:
	var owned: Dictionary = envelope.duplicate(true)
	var lane_name := "session" if int(owned.world_kind) == Envelope.WORLD_HEX else "authority"
	owned[lane_name].events.append(SessionSnapshot.encode_event({"type": "social_emote", "event_id": 43, "entity_id": 1, "emote_id": 1}))
	check(Envelope.validate(owned), label + " alias fixture includes a valid nested packed event")
	var before := var_to_bytes(owned)
	var first := Envelope.metadata(owned)
	var second := Envelope.metadata(owned)
	first.names[0][1] = "Locally changed"
	var event: PackedInt64Array = first.events[0]
	event[0] += 1
	first.events[0] = event
	first.events.append(PackedInt64Array([123]))
	for lane: String in ["hearth", "round", "overflow"]:
		var values: PackedInt32Array = first[lane]
		values[0] += 1
		first[lane] = values
	first.tick += 1
	check(var_to_bytes(owned) == before, label + " returned row/array/packed mutation cannot reach envelope")
	equal(second, _reference_metadata(owned), label + " independent metadata result cannot alias sibling")
	var second_before := var_to_bytes(second)
	if lane_name == "session": owned.session.names[0][1] = "Caller changed"
	else: owned.authority.players[0][1] = "Caller changed"
	owned[lane_name].events.append(PackedInt64Array([456]))
	check(var_to_bytes(second) == second_before, label + " later source mutations cannot change detached result")


func _application_fixture(node: Node2D) -> Dictionary:
	var builder := PublicationFixtures.new()
	var fixture: Dictionary = builder._fixture()
	check(builder.failures == 0 and not fixture.is_empty(), "metadata publication fixture admits real host and guest worlds")
	if fixture.is_empty():
		node.free()
		return {}
	var original: Node2D = fixture.node
	for field: String in ["preference_overrides_are_transient", "preferences_persistence_allowed", "campus_layout", "ability_catalog", "champion_catalog", "spell_loom_editor", "trusted_hex_template", "session_transport", "client_prediction", "spectator_focus"]:
		node.set(field, original.get(field))
	original.free()
	fixture.node = node
	node.set("input_router", InputRouter.new())
	node.set("session_event_inbox", SessionEventInbox.new())
	var authority: SimWorld = fixture.authority
	var champions: ChampionCatalog = fixture.champions
	# Exercise ordinary subsequent synchronization, avoiding first-join profile
	# restoration. No scene startup, sockets, persistence or presentation runs.
	node.set("last_client_snapshot_tick", 0)
	node.set("selected_champion_id", champions.champion_id_from_wire(authority.player(2).champion_wire_id))
	return fixture


func _test_complete_sync() -> void:
	var concrete_fixture := _application_fixture(Bootstrap.new())
	var override_fixture := _application_fixture(OverrideHarness.new())
	if concrete_fixture.is_empty() or override_fixture.is_empty():
		if not concrete_fixture.is_empty(): concrete_fixture.node.free()
		if not override_fixture.is_empty(): override_fixture.node.free()
		return
	var concrete: Node2D = concrete_fixture.node
	var extension: OverrideHarness = override_fixture.node
	check(concrete.get_script() == Bootstrap and extension.get_script() != Bootstrap, "complete sync exercises exact concrete script and distinct extension")
	for fixture: Dictionary in [concrete_fixture, override_fixture]:
		var authority: SimWorld = fixture.authority
		check(authority.step([]), "ordinary paid-world host advances before complete synchronization")
	var host: AuthoritativeSession = concrete_fixture.host
	var envelope := host.capture_envelope()
	check(not envelope.is_empty(), "complete sync captures actual admitted world envelope")
	if envelope.is_empty():
		concrete.free()
		extension.free()
		return
	var metadata := _reference_metadata(envelope)
	var wire_before := var_to_bytes(envelope)
	for node: Node2D in [concrete, extension]:
		(node.get("session_transport") as SessionTransport)._accept_envelope(envelope)
		node.call("_sync_session_transport")
		check(node.get("world") != null, "complete synchronization publishes world")
		equal(node.get("last_client_snapshot_tick"), int(envelope.tick), "complete sync commits exact snapshot tick")
		equal(node.get("last_client_world_epoch"), int(envelope.world_epoch), "complete sync commits exact application epoch")
		equal(node.get("session_hearth_values"), metadata.hearth, "complete sync uses exact Hearth lane")
		equal(node.get("session_round_values"), metadata.round, "complete sync uses exact round lane")
		equal(node.get("network_projectile_overflow"), metadata.overflow[0], "complete sync uses exact projectile overflow")
		equal(node.get("network_event_overflow"), metadata.overflow[2], "complete sync uses exact event overflow")
		for row: Array in metadata.names:
			equal((node.get("session_names_by_entity") as Dictionary).get(int(row[0])), String(row[1]), "complete sync uses exact actor name")
	equal(extension.apply_calls, 1, "extension bool apply hook runs exactly once through sync")
	equal(extension.spectator_calls, 1, "existing incoming spectator hook runs exactly once")
	var concrete_world: SimWorld = concrete.get("world")
	if concrete_world != null and extension.world != null:
		equal(concrete_world.state_hash(), extension.world.state_hash(), "concrete reuse and extension fallback publish identical authority")
		equal((concrete.get("client_prediction") as ClientPrediction).hex_context_tick, extension.client_prediction.hex_context_tick, "concrete and extension publish matching prediction geometry")
	check(var_to_bytes(envelope) == wire_before, "complete sync cannot mutate transport-owned envelope")
	concrete.free()
	extension.free()


func _test_failed_publication() -> void:
	var fixture := _application_fixture(OverrideHarness.new())
	if fixture.is_empty(): return
	var node: OverrideHarness = fixture.node
	var host: AuthoritativeSession = fixture.host
	var authority: SimWorld = fixture.authority
	check(authority.step([]), "failure fixture advances real authority")
	var first := host.capture_envelope()
	var accepted := node._apply_world_envelope(first)
	check(accepted, "unchanged boolean application publishes initial authority")
	if not accepted:
		node.free()
		return
	var original: SimWorld = node.world
	var predictor: ClientPrediction = node.client_prediction
	var context: HexChemistryWorld = predictor.hex_authority
	var before := original.state_hash()
	var epoch := node.last_client_world_epoch
	var old_names := {2: "Retained"}
	node.session_names_by_entity.assign(old_names)
	node.session_hearth_values = PackedInt32Array([17])
	node.session_round_values = PackedInt32Array([18])
	node.combat_cues.append({"retain": true})
	var detached := Envelope.metadata(first)
	detached.names[0][2] = "Caller result mutation"
	check(node.world.state_hash() == before, "returned metadata does not alias published actor state")
	check(authority.step([]), "failure fixture advances to later valid snapshot")
	var next := host.capture_envelope()
	node.refuse_context = true
	var rejected := node._apply_world_envelope(next)
	check(not rejected, "failed prediction preparation preserves original false result")
	check(node.world == original and node.client_prediction == predictor and predictor.hex_authority == context, "failed metadata application preserves published world and prediction objects")
	check(node.world.state_hash() == before, "failed metadata application preserves exact authority")
	equal(node.last_client_world_epoch, epoch, "failed metadata application preserves application epoch")
	equal(node.session_names_by_entity, old_names, "failed metadata application does not stage session names")
	equal(node.session_hearth_values, PackedInt32Array([17]), "failed metadata application does not stage Hearth metadata")
	equal(node.session_round_values, PackedInt32Array([18]), "failed metadata application does not stage round metadata")
	equal(node.combat_cues, [{"retain": true}], "failed metadata application does not clear cues")
	node.session_transport._accept_envelope(next)
	node._sync_session_transport()
	check(node.world == original and node.client_prediction == predictor, "failed ordinary sync retains transaction objects")
	equal(node.session_names_by_entity, old_names, "failed ordinary sync cannot leak detached metadata")
	check(node.apply_calls > 0, "failed ordinary sync still invokes extension bool hook")
	node.free()


func _test_callback_mutations() -> void:
	for stage: String in ["prepare", "publish", "motion", "invalid-prepare", "invalid-publish"]:
		var invalid := stage.begins_with("invalid-")
		var node: Node2D = RefusedLaneHarness.new() if invalid else Bootstrap.new()
		var fixture := _application_fixture(node)
		if fixture.is_empty(): continue
		var host: AuthoritativeSession = fixture.host
		var authority: SimWorld = fixture.authority
		check(authority.step([]), stage + " fixture advances actual world")
		var first := host.capture_envelope()
		check(bool(node.call("_apply_world_envelope", first)), stage + " first world publishes before retaining a predictor subclass")
		if node.get("world") == null:
			node.free()
			continue
		var published: SimWorld = node.get("world")
		var predictor := MutatingPrediction.new()
		check(predictor.configure(published.config, published.collision, 2), stage + " mutable predictor configures for the actual local guest")
		predictor.mutation_stage = stage.trim_prefix("invalid-")
		predictor.malformed = invalid
		node.set("client_prediction", predictor)
		node.set("last_client_snapshot_tick", int(first.tick))
		check(authority.step([]), stage + " host advances a same-epoch envelope")
		var next := host.capture_envelope()
		predictor.envelope_alias = next
		var motion: MutatingMotionHistory = null
		if stage == "motion":
			motion = MutatingMotionHistory.new()
			motion.envelope_alias = next
			node.set("actor_motion_history", motion)
		(node.get("session_transport") as SessionTransport)._accept_envelope(next)
		node.call("_sync_session_transport")
		equal(predictor.mutations, 0 if stage == "motion" else 1, stage + " retained prediction callback mutation count matches")
		if motion != null: equal(motion.mutations, 1, "motion metadata mutation runs once after publication")
		check(node.get("client_prediction") == predictor, stage + " fixture exercises retained subclass rather than replacement")
		if invalid:
			var observer: RefusedLaneHarness = node
			check(Envelope.metadata(next).is_empty(), stage + " post-callback envelope projection refuses malformed relationship")
			equal(observer.overflow_calls, 1, stage + " individual fallback sink still runs after successful application")
			check(observer.observed_overflow.is_empty(), stage + " unchanged overflow getter exposes its empty refusal")
			check(observer.session_names_by_entity.is_empty() and observer.session_hearth_values.is_empty() and observer.session_round_values.is_empty(), stage + " individual post-apply getters retain original refusal outputs")
			equal(observer.last_client_snapshot_tick, int(next.tick), stage + " original successful-apply cursor semantics are not replaced with an all-or-nothing projection gate")
		else:
			check(node.get_script() == Bootstrap and predictor.get_script() != ClientPrediction, stage + " exact bootstrap is tested with extensible predictor")
			check(Envelope.validate(next), stage + " callback keeps its new metadata valid")
			equal((node.get("session_names_by_entity") as Dictionary).get(1), "After " + stage, stage + " projection reads names after callback mutation")
			equal(node.get("network_projectile_overflow"), 37, stage + " projection reads overflow after callback mutation")
		node.free()
