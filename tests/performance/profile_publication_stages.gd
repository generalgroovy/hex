extends "res://tests/performance/profile_snapshot_canonical.gd"

# Diagnostic only: no sockets, sends, simulation changes or global class name.
# The inherited builder supplies the same independently replayed legacy/sealed
# twins used by the canonical profile, not a synthetic dictionary workload.
const PublicationEnvelope = preload("res://src/net/world_snapshot_envelope.gd")
const PUBLICATION_PROFILE_VERSION := "publication-stages-v2"
const PUBLICATION_SAMPLES := 7
const PUBLICATION_STAGES: Array[String] = [
	"world_capture", "session_capture_envelope", "wrap_hex", "envelope_validate",
	"transport_packetize", "transport_encode", "capture_to_encoded_packets",
]
const PUBLICATION_PROBE_PATH := "tests/performance/profile_publication_stages.gd"
const PUBLICATION_PAIR_ARMS: Array[String] = ["public", "owned"]


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
		else: _check(false, "unknown publication probe argument")
	_check(_publication_path_valid(output_path) and not FileAccess.file_exists(output_path), "fresh scoped publication receipt")
	if failures > 0:
		quit(1)
		return
	var sources_before: Dictionary = _publication_sources()
	_check(_hashes_valid(sources_before), "all publication dependencies hash")
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "actual abilities load")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "actual champions load")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "actual campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null and definition.eligible_cells.size() == EXPECTED_TOPOLOGY_CELLS, "actual 11337-cell campus")
	if failures > 0:
		quit(1)
		return
	var records: Array[Dictionary] = []
	for index: int in CASE_LABELS.size():
		records.append(_publication_case(CASE_LABELS[index], index))
	var complete: bool = _publication_records_complete(records)
	_check(complete, "all publication cases/stages/evidence are complete")
	var sources_after: Dictionary = _publication_sources()
	var unchanged: bool = _hashes_valid(sources_after) and sources_before == sources_after
	_check(unchanged, "no source changes during publication profile")
	var receipt: Dictionary = {
		"profile_version": PUBLICATION_PROFILE_VERSION, "engine": Engine.get_version_info().get("string", ""),
		"source_sha256_before": sources_before, "source_sha256_after": sources_after, "sources_unchanged": unchanged,
		"samples_per_stage": PUBLICATION_SAMPLES, "stage_names": PUBLICATION_STAGES.duplicate(),
		"publication_pairs": PUBLICATION_SAMPLES, "pair_arms": PUBLICATION_PAIR_ARMS.duplicate(),
		"paired_outer_admission_included": true,
		"records": records, "receipt_complete": complete,
		"scope": "Four actual 11337-cell/eight-champion fixtures inherited unchanged from profile_snapshot_canonical: empty, distributed-paid40, dense-paid40, active Rampart. Seven warm samples per stage in a rotated stage order. Session metadata uses actual final-tick events, eight names and real hearth/round capture; no synthetic queue saturation or accumulated publication history.",
		"timers": "Only the named operation plus dispatch/return runs inside a stage timer. Assertion, source/input hashes, equivalence checks, sample recording and receipt construction are outside. diagnostic_bookkeeping_us counts per-sample checks/recording only, not fixture setup, oracle creation, warmups or final receipt work.",
		"stage_meaning": "world_capture is HexWorldSnapshot.capture. session_capture_envelope includes world capture, metadata and strict wrapping. wrap_hex uses fixed detached inputs. envelope_validate is a fixed-envelope strict check. transport_packetize calls the public envelope packetizer (validation, serialization, compression, fragmentation). transport_encode calls the actual concrete transport encoder once per prepared packet. capture_to_encoded_packets includes public session capture plus packetization plus packet encoding, without sends.",
		"paired_comparison": "Seven alternating case-counterbalanced pairs on the same current source. public is literal session.capture_envelope() followed by SessionTransport._envelope_wire_packets(envelope). owned first executes broadcast_session's concrete-transport/eligibility admission gate, then SessionTransport._capture_session_packets(session), including that factory's own admission; an ineligible source uses the literal public composition. Both include outgoing encoding once per packet with the same concrete encoder and result retention. Preparation excludes host/epoch checks and socket dispatch. No receipt/equivalence/assertion work runs inside these timers. The strict public composition remains the baseline; it is not a historical timing or an old hash implementation.",
		"equivalence": "Frozen E8 world capture on the independently replayed legacy twin, explicit reference session lanes/envelope and frozen packet construction define exact expected bytes. Actual receiver reassembly and public world preparation must restore those bytes and full authority hash. Live world/session and detached stage inputs remain unchanged.",
		"limits": "Inclusive stages overlap and must not be summed. Warm diagnostic samples do not establish sustained percentiles, rendered performance, fanout/send costs, physical network, 60Hz publication or eight-player capacity. Memory is process-global. Paired medians describe only these bounded prepared states and final-tick metadata loads.",
		"performance_acceptance": "NOT_ESTABLISHED",
	}
	# Validate the serialized form too: JSON represents integer samples as floats.
	receipt.diagnostic_status = "PASS" if failures == 0 else "FAIL"
	receipt.failures = failures
	_check(_publication_receipt_valid(JSON.parse_string(JSON.stringify(receipt))), "serialized receipt retains all evidence")
	_publication_receipt_guards(receipt)
	var output: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	_check(output != null, "publication receipt opens")
	if output != null:
		receipt.assertions = assertions
		receipt.failures = failures
		receipt.diagnostic_status = "PASS" if failures == 0 else "FAIL"
		output.store_string(JSON.stringify(receipt, "\t") + "\n")
		output.close()
	print("%s: publication-stages; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)


func _publication_case(label: String, offset: int) -> Dictionary:
	print("PUBLICATION_FIXTURE " + label)
	var fixture: Dictionary = _collision_fixture(label)
	if fixture.is_empty(): return {}
	var world: SimWorld = fixture.worlds.sealed
	var legacy: SimWorld = fixture.worlds.legacy
	var original_hash: String = world.state_hash()
	var session: AuthoritativeSession = _publication_session(world)
	var reference_session: AuthoritativeSession = _publication_session(legacy)
	_check(world.state_hash() == original_hash and legacy.state_hash() == original_hash, "binding publication observers preserves paid authority")
	var owned_path_eligible: bool = SessionTransport._owned_publication_eligible(session)
	_check(owned_path_eligible, "actual sealed publication fixture reaches owned fast path, not extension fallback")
	var authority: Dictionary = BeforeE9.capture(legacy)
	var metadata: Dictionary = _publication_reference_metadata(reference_session)
	if authority.is_empty() or metadata.is_empty():
		_check(false, "reference authority and metadata are nonempty")
		return {}
	var envelope: Dictionary = {
		"schema": PublicationEnvelope.SCHEMA_VERSION, "world_kind": PublicationEnvelope.WORLD_HEX,
		"world_epoch": reference_session.world_epoch, "tick": world.tick,
		"authority": authority.duplicate(true), "session": metadata.duplicate(true),
	}
	var expected_packets: Array[Dictionary] = _publication_reference_packets(envelope)
	var expected_encoded: Array[PackedByteArray] = []
	for packet: Dictionary in expected_packets: expected_encoded.append(var_to_bytes(packet))
	_check(PublicationEnvelope.validate(envelope) and not expected_packets.is_empty(), "reference complete envelope and packets validate")
	var authority_bytes: PackedByteArray = var_to_bytes(authority)
	var envelope_bytes: PackedByteArray = var_to_bytes(envelope)
	var packet_bytes: PackedByteArray = var_to_bytes(expected_packets)
	var encoder := SessionTransport.new()
	# One untimed actual capture establishes the documented pending-ack effect.
	var first_capture: Dictionary = session.capture_envelope()
	_check(var_to_bytes(first_capture) == envelope_bytes and session.snapshot_capture_pending_ack, "public capture exactly matches independent reference and sets pending ack")
	var source_before: PackedByteArray = _publication_source_bytes(session)
	var input_before: PackedByteArray = var_to_bytes([authority, metadata, envelope, expected_packets])
	var samples: Dictionary = {}
	for stage: String in PUBLICATION_STAGES:
		samples[stage] = PackedInt64Array()
		var warm: Variant = _publication_operation(stage, session, encoder, authority, metadata, envelope, expected_packets)
		_check(_publication_result_valid(stage, warm, authority_bytes, envelope_bytes, packet_bytes, expected_encoded), label + " " + stage + " untimed warmup")
	_check(_publication_source_bytes(session) == source_before, "warmups preserve source")
	var rows: Array[Dictionary] = []
	var diagnostic_us: int = 0
	var memory_before: Dictionary = _memory()
	for sample_index: int in PUBLICATION_SAMPLES:
		var order: Array[String] = _publication_order(sample_index + offset)
		var row: Dictionary = {"sample": sample_index, "order": order.duplicate(), "samples_us": {}}
		for stage: String in order:
			var started: int = Time.get_ticks_usec()
			var value: Variant = _publication_operation(stage, session, encoder, authority, metadata, envelope, expected_packets)
			var elapsed: int = Time.get_ticks_usec() - started
			var diagnostic_started: int = Time.get_ticks_usec()
			var stage_samples: PackedInt64Array = samples[stage]
			stage_samples.append(elapsed)
			samples[stage] = stage_samples
			row.samples_us[stage] = elapsed
			_check(_publication_result_valid(stage, value, authority_bytes, envelope_bytes, packet_bytes, expected_encoded), label + " " + stage + " exact bytes/result")
			_check(_publication_source_bytes(session) == source_before, "sample preserves live authority and session")
			_check(var_to_bytes([authority, metadata, envelope, expected_packets]) == input_before, "sample preserves detached stage inputs")
			diagnostic_us += Time.get_ticks_usec() - diagnostic_started
		rows.append(row)
	var stages: Dictionary = {}
	for stage: String in PUBLICATION_STAGES:
		stages[stage] = _stats(samples[stage])
		print("PUBLICATION_STAGE %s %s p50_us=%d p95_us=%d" % [label, stage, stages[stage].statistics_us.p50, stages[stage].statistics_us.p95])
	var paired: Dictionary = _publication_pairs(session, encoder, authority, metadata, envelope, expected_packets, expected_encoded, source_before, input_before, offset)
	var paired_complete: bool = _publication_pairs_complete(paired, offset)
	_check(paired_complete, "paired publication completes before statistics reporting")
	if paired_complete:
		print("PUBLICATION_PAIRED %s public_p50_us=%d owned_p50_us=%d" % [label, paired.public.statistics_us.p50, paired.owned.statistics_us.p50])
	var receiver := SessionTransport.new()
	receiver.mode = SessionTransport.Mode.CLIENT
	receiver.world_epoch = session.world_epoch
	for encoded: PackedByteArray in expected_encoded: receiver._handle_packet(SessionTransport.SERVER_PEER_ID, encoded)
	var received: Array[Dictionary] = receiver.poll_envelopes()
	var received_exact: bool = received.size() == 1 and var_to_bytes(received[0]) == envelope_bytes
	_check(received_exact, "real receiver exactly reassembles reference packets")
	var restored: SimWorld = HexWorldSnapshot.prepare(received[0].authority, world) if received_exact else null
	var restored_exact: bool = restored != null and restored.state_hash() == original_hash
	_check(restored_exact, "received public preparation restores full authority hash")
	var source_unchanged: bool = _publication_source_bytes(session) == source_before and _storage_modes_valid(fixture.worlds)
	var inputs_unchanged: bool = var_to_bytes([authority, metadata, envelope, expected_packets]) == input_before
	_check(source_unchanged and inputs_unchanged, "complete publication diagnostic preserves source/inputs/ownership")
	return {
		"case": label, "tick": world.tick, "actors": world.players.size(), "topology_cells": world.hex_court.cell_count(),
		"paid_steps": fixture.paid_steps, "paid_metrics": world.hex_court.metrics.duplicate(true),
		"active_ramparts": _active_ramparts(world.hex_court, world.tick), "state_hash": original_hash, "trace_sha256": fixture.trace_sha256,
		"authority_bytes": authority_bytes.size(), "authority_sha256": CanonicalBytes.sha256_hex(authority_bytes),
		"envelope_bytes": envelope_bytes.size(), "envelope_sha256": CanonicalBytes.sha256_hex(envelope_bytes),
		"session_sha256": CanonicalBytes.sha256_hex(var_to_bytes(metadata)), "published_events": metadata.events.size(),
		"pending_events": session.pending_combat_events.size(), "overflow_count": session.pending_combat_event_overflow_count,
		"wire": _publication_wire_evidence(expected_encoded), "source_unchanged": source_unchanged, "inputs_unchanged": inputs_unchanged,
		"receiver_exact": received_exact, "prepared_hash_exact": restored_exact,
		"owned_path_eligible": owned_path_eligible,
		"stages": stages, "sample_rows": rows, "diagnostic_bookkeeping_us": diagnostic_us, "paired_publication": paired,
		"memory_before": memory_before, "memory_after": _memory(),
	}


func _publication_session(world: SimWorld) -> AuthoritativeSession:
	var session := AuthoritativeSession.new()
	var host: PlayerState = world.player(1)
	@warning_ignore("integer_division")
	var spawn_pixels := Vector2i(host.position_x / SimConfig.FIXED_SCALE, host.position_y / SimConfig.FIXED_SCALE)
	_check(session.bind(world, champions, spawn_pixels, "Profile 1"), "real authoritative session binds actual paid fixture")
	for actor: PlayerState in world.players:
		session.names_by_entity[actor.entity_id] = "Profile %d" % actor.entity_id
		_check(session.hearth.connect_entity(actor.entity_id), "real hearth connects champion")
	session.record_combat_events(world.combat_events)
	return session


func _publication_reference_metadata(session: AuthoritativeSession) -> Dictionary:
	# Frozen public-lane assembly, deliberately independent of capture_envelope.
	var names: Array = []
	var actors: Array[PlayerState] = session.world.players.duplicate()
	actors.sort_custom(func(left: PlayerState, right: PlayerState) -> bool: return left.entity_id < right.entity_id)
	for actor: PlayerState in actors:
		if actor.actor_kind != PlayerState.ActorKind.CHAMPION: continue
		names.append([actor.entity_id, SessionSnapshot._safe_name(session.names_by_entity[actor.entity_id]), SessionSnapshot._safe_event_name(actor.last_event)])
	var events: Array[PackedInt64Array] = []
	for index: int in range(maxi(0, session.pending_combat_events.size() - SessionSnapshot.MAX_EVENTS), session.pending_combat_events.size()):
		events.append(SessionSnapshot.encode_event(session.pending_combat_events[index]))
	return {
		"names": names, "events": events,
		"hearth": session.hearth.capture(session.world.tick, SessionCharter.maximum_players(session.charter_id)),
		"round": session.session_round.capture(session.world),
		"overflow": PackedInt32Array([0, 0, session.pending_combat_event_overflow_count, 0]),
	}


func _publication_operation(stage: String, session: AuthoritativeSession, encoder: SessionTransport, authority: Dictionary, metadata: Dictionary, envelope: Dictionary, packets: Array[Dictionary]) -> Variant:
	match stage:
		"world_capture": return HexWorldSnapshot.capture(session.world)
		"session_capture_envelope": return session.capture_envelope()
		"wrap_hex": return PublicationEnvelope.wrap_hex(authority, metadata, session.world_epoch)
		"envelope_validate": return PublicationEnvelope.validate(envelope)
		"transport_packetize": return SessionTransport._envelope_wire_packets(envelope)
		"transport_encode": return _publication_encode(encoder, packets)
		"capture_to_encoded_packets": return _publication_encode(encoder, SessionTransport._envelope_wire_packets(session.capture_envelope()))
	return null


func _publication_encode(encoder: SessionTransport, packets: Array[Dictionary]) -> Array[PackedByteArray]:
	var encoded: Array[PackedByteArray] = []
	for packet: Dictionary in packets: encoded.append(encoder._encode_outgoing_packet(packet))
	return encoded


func _publication_pipeline(session: AuthoritativeSession, encoder: SessionTransport, arm: String) -> Dictionary:
	var publication: Dictionary
	# Mirror broadcast_session's outer admission inside timed preparation. The
	# factory retains its own guard, so this includes both production scans.
	var use_owned: bool = arm != "public" and encoder.get_script() == load("res://src/net/session_transport.gd") \
		and SessionTransport._owned_publication_eligible(session)
	if not use_owned:
		# Literal unchanged public composition; no owned-factory call or trust flag.
		var envelope: Dictionary = session.capture_envelope()
		publication = {"envelope": envelope, "packets": SessionTransport._envelope_wire_packets(envelope)}
	else:
		publication = SessionTransport._capture_session_packets(session)
	if publication.is_empty(): return {}
	publication["encoded"] = _publication_encode(encoder, publication.packets)
	return publication


func _publication_pair_result_valid(value: Dictionary, envelope_bytes: PackedByteArray, packets_bytes: PackedByteArray, encoded: Array[PackedByteArray]) -> bool:
	return value.size() == 3 and value.get("envelope") is Dictionary and value.get("packets") is Array and value.get("encoded") is Array \
		and var_to_bytes(value.envelope) == envelope_bytes and var_to_bytes(value.packets) == packets_bytes and value.encoded == encoded


func _publication_pairs(session: AuthoritativeSession, encoder: SessionTransport, authority: Dictionary, metadata: Dictionary, envelope: Dictionary, packets: Array[Dictionary], encoded: Array[PackedByteArray], source_before: PackedByteArray, input_before: PackedByteArray, offset: int) -> Dictionary:
	var envelope_bytes: PackedByteArray = var_to_bytes(envelope)
	var packets_bytes: PackedByteArray = var_to_bytes(packets)
	var samples: Dictionary = {"public": PackedInt64Array(), "owned": PackedInt64Array()}
	var all_exact: bool = true
	for arm: String in PUBLICATION_PAIR_ARMS:
		var warm: Dictionary = _publication_pipeline(session, encoder, arm)
		_check(_publication_pair_result_valid(warm, envelope_bytes, packets_bytes, encoded), "paired publication untimed warmup " + arm)
	var rows: Array[Dictionary] = []
	var diagnostic_us: int = 0
	for index: int in PUBLICATION_SAMPLES:
		var order: Array[String] = _publication_pair_order(index + offset)
		var row: Dictionary = {"pair": index, "order": order.duplicate(), "samples_us": {}}
		var results: Dictionary = {}
		for arm: String in order:
			var started: int = Time.get_ticks_usec()
			var value: Dictionary = _publication_pipeline(session, encoder, arm)
			var elapsed: int = Time.get_ticks_usec() - started
			var diagnostic_started: int = Time.get_ticks_usec()
			results[arm] = value
			var arm_samples: PackedInt64Array = samples[arm]
			arm_samples.append(elapsed)
			samples[arm] = arm_samples
			row.samples_us[arm] = elapsed
			var exact: bool = _publication_pair_result_valid(value, envelope_bytes, packets_bytes, encoded)
			all_exact = exact and all_exact
			_check(exact, "paired publication exact envelope/packet/encoded bytes " + arm)
			_check(_publication_source_bytes(session) == source_before, "paired publication preserves live source " + arm)
			_check(var_to_bytes([authority, metadata, envelope, packets]) == input_before, "paired publication preserves detached inputs " + arm)
			diagnostic_us += Time.get_ticks_usec() - diagnostic_started
		rows.append(row)
		_check(results.public == results.owned, "both paired publication results match directly")
	return {"public": _stats(samples.public), "owned": _stats(samples.owned), "pairs": rows, "exact_results": all_exact, "diagnostic_bookkeeping_us": diagnostic_us}


func _publication_pair_order(index: int) -> Array[String]:
	var order: Array[String] = ["public", "owned"]
	if index % 2 != 0: order.reverse()
	return order


func _publication_result_valid(stage: String, value: Variant, authority_bytes: PackedByteArray, envelope_bytes: PackedByteArray, packet_bytes: PackedByteArray, encoded: Array[PackedByteArray]) -> bool:
	match stage:
		"world_capture": return value is Dictionary and var_to_bytes(value) == authority_bytes
		"session_capture_envelope", "wrap_hex": return value is Dictionary and var_to_bytes(value) == envelope_bytes
		"envelope_validate": return typeof(value) == TYPE_BOOL and value
		"transport_packetize": return value is Array and var_to_bytes(value) == packet_bytes
		"transport_encode", "capture_to_encoded_packets": return value is Array and value == encoded
	return false


func _publication_reference_packets(envelope: Dictionary) -> Array[Dictionary]:
	# Frozen current packet format; production packetization is not its own oracle.
	var raw: PackedByteArray = var_to_bytes(envelope)
	if raw.is_empty() or raw.size() > SessionTransport.MAX_SNAPSHOT_UNCOMPRESSED_BYTES: return []
	var compressed: PackedByteArray = raw.compress(FileAccess.COMPRESSION_FASTLZ)
	if compressed.is_empty(): return []
	var single: Dictionary = {"kind": SessionTransport.PACKET_SNAPSHOT, "world_epoch": int(envelope.world_epoch), "tick": int(envelope.tick), "raw_size": raw.size(), "payload": compressed}
	if var_to_bytes(single).size() <= SessionTransport.ENET_MTU_BYTES: return [single]
	@warning_ignore("integer_division")
	var count: int = (compressed.size() + SessionTransport.SNAPSHOT_FRAGMENT_PAYLOAD_BYTES - 1) / SessionTransport.SNAPSHOT_FRAGMENT_PAYLOAD_BYTES
	if count > SessionTransport.MAX_SNAPSHOT_FRAGMENTS: return []
	var packets: Array[Dictionary] = []
	for index: int in count:
		var packet: Dictionary = {
			"kind": SessionTransport.PACKET_SNAPSHOT_FRAGMENT, "world_epoch": int(envelope.world_epoch), "tick": int(envelope.tick),
			"raw_size": raw.size(), "count": count, "index": index,
			"payload": compressed.slice(index * SessionTransport.SNAPSHOT_FRAGMENT_PAYLOAD_BYTES, (index + 1) * SessionTransport.SNAPSHOT_FRAGMENT_PAYLOAD_BYTES),
		}
		if var_to_bytes(packet).size() > SessionTransport.ENET_MTU_BYTES: return []
		packets.append(packet)
	return packets


func _publication_source_bytes(session: AuthoritativeSession) -> PackedByteArray:
	return var_to_bytes({
		"authority_hash": session.world.state_hash(), "canonical_chemistry": session.world.hex_court._state_hash_bytes(),
		"events": session.world.combat_events, "names": session.names_by_entity, "input": session.latest_input_by_entity,
		"processed": session.last_processed_input_sequence_by_entity, "pending": session.pending_combat_events,
		"next_event_id": session.next_event_id, "overflow": session.pending_combat_event_overflow_count,
		"overflow_remaining": session.pending_combat_event_overflow_remaining_snapshots,
		"pending_ack": session.snapshot_capture_pending_ack, "epoch": session.world_epoch, "charter": session.charter_id,
		"hearth": session.hearth.capture(session.world.tick, SessionCharter.maximum_players(session.charter_id)),
		"round": session.session_round.capture(session.world),
	})


func _publication_wire_evidence(encoded: Array[PackedByteArray]) -> Dictionary:
	var sizes: Array[int] = []
	var hashes: Array[String] = []
	var total: int = 0
	for packet: PackedByteArray in encoded:
		sizes.append(packet.size())
		hashes.append(CanonicalBytes.sha256_hex(packet))
		total += packet.size()
	return {"packet_count": encoded.size(), "packet_bytes": sizes, "packet_sha256": hashes, "total_bytes": total}


func _publication_order(index: int) -> Array[String]:
	var result: Array[String] = []
	for position: int in PUBLICATION_STAGES.size(): result.append(PUBLICATION_STAGES[(position + index) % PUBLICATION_STAGES.size()])
	return result


func _publication_integer(value: Variant, minimum: int = 0) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and float(value) == float(int(value)) and value >= minimum


func _publication_records_complete(records: Variant) -> bool:
	if not records is Array or records.size() != CASE_LABELS.size(): return false
	for offset: int in CASE_LABELS.size():
		var record: Variant = records[offset]
		if not record is Dictionary or record.get("case") != CASE_LABELS[offset] or record.get("actors") != 8 or record.get("topology_cells") != EXPECTED_TOPOLOGY_CELLS: return false
		for key: String in ["source_unchanged", "inputs_unchanged", "receiver_exact", "prepared_hash_exact", "owned_path_eligible"]:
			if record.get(key) != true: return false
		for key: String in ["state_hash", "trace_sha256", "authority_sha256", "envelope_sha256", "session_sha256"]:
			if not _hash_valid(record.get(key)): return false
		for key: String in ["tick", "paid_steps", "active_ramparts", "published_events", "pending_events", "overflow_count", "diagnostic_bookkeeping_us"]:
			if not _publication_integer(record.get(key)): return false
		for key: String in ["authority_bytes", "envelope_bytes"]:
			if not _publication_integer(record.get(key), 1) or record[key] > PublicationEnvelope.MAX_RAW_BYTES: return false
		if record.tick != WARMUP_TICKS + record.paid_steps: return false
		if record.published_events != record.pending_events or record.published_events > SessionSnapshot.MAX_EVENTS: return false
		if not record.get("paid_metrics") is Dictionary: return false
		if offset == 0 and record.paid_steps != 0: return false
		if offset in [1, 2] and record.paid_steps != 40: return false
		if offset == 3 and (record.paid_steps < 1 or record.paid_steps > RAMPART_STEP_LIMIT or record.active_ramparts < 1): return false
		if offset > 0 and (record.paid_metrics.get("admitted", 0) <= 0 or record.paid_metrics.get("matter_paid", 0) <= 0): return false
		if not _publication_wire_complete(record.get("wire")): return false
		if not _publication_pairs_complete(record.get("paired_publication"), offset): return false
		var stages: Variant = record.get("stages")
		var rows: Variant = record.get("sample_rows")
		if not stages is Dictionary or stages.size() != PUBLICATION_STAGES.size() or not rows is Array or rows.size() != PUBLICATION_SAMPLES: return false
		for stage: String in PUBLICATION_STAGES:
			var observation: Variant = stages.get(stage)
			if not observation is Dictionary or not observation.get("samples_us") is Array or observation.samples_us.size() != PUBLICATION_SAMPLES: return false
			for sample: Variant in observation.samples_us:
				if not _publication_integer(sample): return false
			if not _publication_statistics_complete(observation.get("statistics_us"), observation.samples_us): return false
		for index: int in PUBLICATION_SAMPLES:
			var row: Variant = rows[index]
			if not row is Dictionary or row.get("sample") != index or row.get("order") != _publication_order(index + offset): return false
			if not row.get("samples_us") is Dictionary or row.samples_us.size() != PUBLICATION_STAGES.size(): return false
			for stage: String in PUBLICATION_STAGES:
				if row.samples_us.get(stage, -1) != stages[stage].samples_us[index]: return false
	return true


func _publication_pairs_complete(value: Variant, offset: int) -> bool:
	if not value is Dictionary or value.get("exact_results") != true or not _publication_integer(value.get("diagnostic_bookkeeping_us")): return false
	for arm: String in PUBLICATION_PAIR_ARMS:
		var observation: Variant = value.get(arm)
		if not observation is Dictionary or not observation.get("samples_us") is Array or observation.samples_us.size() != PUBLICATION_SAMPLES: return false
		for sample: Variant in observation.samples_us:
			if not _publication_integer(sample): return false
		if not _publication_statistics_complete(observation.get("statistics_us"), observation.samples_us): return false
	var pairs: Variant = value.get("pairs")
	if not pairs is Array or pairs.size() != PUBLICATION_SAMPLES: return false
	for index: int in PUBLICATION_SAMPLES:
		var pair: Variant = pairs[index]
		if not pair is Dictionary or pair.get("pair") != index or pair.get("order") != _publication_pair_order(index + offset): return false
		if not pair.get("samples_us") is Dictionary or pair.samples_us.size() != PUBLICATION_PAIR_ARMS.size(): return false
		for arm: String in PUBLICATION_PAIR_ARMS:
			if pair.samples_us.get(arm, -1) != value[arm].samples_us[index]: return false
	return true


func _publication_statistics_complete(value: Variant, samples: Array) -> bool:
	# JSON numbers are floats, but Dictionary equality uses type-strict Variant
	# comparison. Check every exact statistic after proving it is an integer;
	# do not truncate fractional evidence or accept a missing/extra field.
	var expected: Dictionary = _percentiles(PackedInt64Array(samples))
	if not value is Dictionary or value.size() != expected.size(): return false
	for key: String in expected:
		if not _publication_integer(value.get(key)) or int(value[key]) != int(expected[key]): return false
	return true


func _publication_wire_complete(wire: Variant) -> bool:
	if not wire is Dictionary or not _publication_integer(wire.get("packet_count"), 1) or wire.packet_count > SessionTransport.MAX_SNAPSHOT_FRAGMENTS: return false
	if not wire.get("packet_bytes") is Array or not wire.get("packet_sha256") is Array: return false
	if wire.packet_bytes.size() != wire.packet_count or wire.packet_sha256.size() != wire.packet_count: return false
	var total: int = 0
	for index: int in wire.packet_bytes.size():
		if not _publication_integer(wire.packet_bytes[index], 1) or wire.packet_bytes[index] > SessionTransport.ENET_MTU_BYTES or not _hash_valid(wire.packet_sha256[index]): return false
		total += int(wire.packet_bytes[index])
	return wire.get("total_bytes") == total


func _publication_receipt_valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("profile_version") != PUBLICATION_PROFILE_VERSION or value.get("samples_per_stage") != PUBLICATION_SAMPLES or value.get("stage_names") != PUBLICATION_STAGES: return false
	if value.get("publication_pairs") != PUBLICATION_SAMPLES or value.get("pair_arms") != PUBLICATION_PAIR_ARMS: return false
	if value.get("paired_outer_admission_included") != true: return false
	if value.get("diagnostic_status") != "PASS" or value.get("failures") != 0 or value.get("receipt_complete") != true or value.get("sources_unchanged") != true: return false
	if not value.get("source_sha256_before") is Dictionary or not value.get("source_sha256_after") is Dictionary: return false
	if not _hashes_valid(value.source_sha256_before) or value.source_sha256_before != value.source_sha256_after: return false
	if not value.source_sha256_before.has(PUBLICATION_PROBE_PATH): return false
	return _publication_records_complete(value.get("records"))


func _publication_receipt_guards(receipt: Dictionary) -> void:
	if not _publication_receipt_valid(receipt):
		_check(false, "valid receipt required before negative guard tests")
		return
	for mutation: String in ["case", "sample", "statistic", "statistic-fractional", "statistic-bool", "statistic-missing", "statistic-extra", "order", "hash", "ownership", "wire", "metadata", "source", "pair", "pair-order", "pair-result", "outer-admission"]:
		var broken: Dictionary = receipt.duplicate(true)
		match mutation:
			"case": broken.records.pop_back()
			"sample": broken.records[0].stages.world_capture.samples_us.pop_back()
			"statistic": broken.records[0].stages.world_capture.statistics_us.p50 = -1
			"statistic-fractional": broken.records[0].stages.world_capture.statistics_us.p50 += 0.5
			"statistic-bool": broken.records[0].stages.world_capture.statistics_us.p50 = true
			"statistic-missing": broken.records[0].stages.world_capture.statistics_us.erase("p95")
			"statistic-extra": broken.records[0].stages.world_capture.statistics_us["extra"] = 0
			"order": broken.records[0].sample_rows[0].order.reverse()
			"hash": broken.records[0].authority_sha256 = "malformed"
			"ownership": broken.records[0].source_unchanged = false
			"wire": broken.records[0].wire.total_bytes = -1
			"metadata": broken.records[0].published_events = -1
			"source": broken.source_sha256_after[PUBLICATION_PROBE_PATH] = "0".repeat(64)
			"pair": broken.records[0].paired_publication.owned.samples_us.pop_back()
			"pair-order": broken.records[0].paired_publication.pairs[0].order.reverse()
			"pair-result": broken.records[0].paired_publication.exact_results = false
			"outer-admission": broken.paired_outer_admission_included = false
		_check(not _publication_receipt_valid(broken), "publication receipt refuses missing/corrupt " + mutation)
		_check(not _publication_receipt_valid(JSON.parse_string(JSON.stringify(broken))), "serialized publication receipt refuses missing/corrupt " + mutation)


func _publication_sources() -> Dictionary:
	var result: Dictionary = _canonical_sources()
	result[PUBLICATION_PROBE_PATH] = FileAccess.get_sha256("res://" + PUBLICATION_PROBE_PATH)
	return result


func _publication_path_valid(path: String) -> bool:
	return path.begins_with("res://.godot/publication-stages-") and path.ends_with(".json") and path.get_base_dir() == "res://.godot" and not ".." in path
