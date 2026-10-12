extends SceneTree
## Bounded headless diagnostic. Never host, join, render, or touch player saves.
## The reference preserves the preceding consume body; all checks and byte
## comparisons remain outside timers. This does not measure gameplay FPS.
const Codec = preload("res://src/net/hex_chemistry_snapshot.gd")
const SAMPLES := 7
const SOURCE_PATHS := ["res://scripts/profile-producer-size-witness.gd", "res://src/net/hex_chemistry_snapshot.gd", "res://src/net/hex_world_snapshot.gd", "res://src/net/session_transport.gd", "res://src/sim/hex/hex_chemistry_world.gd", "res://src/sim/hex/hex_canonical_state.gd", "res://src/sim/core/sim_world.gd", "res://content/maps/sanctum_campus_g2_v1.json"]

class ReferenceProducer extends HexChemistrySnapshot.ProducerRoundtrip:
	func _init(source: HexChemistryWorld) -> void:
		super(source)
	# Frozen preceding body, including its second complete encoded_size call.
	func consume(snapshot_value: Dictionary, source: HexChemistryWorld) -> HexChemistryWorld:
		if _consumed: return null
		_consumed = true
		var local_source := _source
		_source = null
		var prepared := _blank
		_blank = null
		if source != local_source or local_source == null or _snapshot.is_empty(): return null
		if local_source.origin != _origin or local_source.current_tick != _tick or local_source.cell_count() != _ordered.size(): return null
		if _topology != null and HexChemistrySnapshot._owned_immutable_topology(local_source) != _topology: return null
		if snapshot_value != _snapshot or not HexChemistrySnapshot._snapshot_shape_valid(snapshot_value): return null
		var size := HexChemistrySnapshot.encoded_size(snapshot_value)
		if size < 0 or size > HexChemistrySnapshot.MAX_ENCODED_BYTES or snapshot_value.topology_hash != _fingerprint: return null
		if not HexChemistrySnapshot._hash_string_valid(snapshot_value.authority_hash): return null
		if prepared == null: return null
		return HexChemistrySnapshot._decode_prepared_state(snapshot_value, prepared, _ordered)

var abilities := AbilityCatalog.new()
var champions := ChampionCatalog.new()
var layout := SanctumCampusLayout.new()
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.substr(9)
		elif argument != "--no-lan-discovery": fail("Unknown argument: " + argument); return
	var absolute := ProjectSettings.globalize_path(output).replace("\\", "/").simplify_path()
	var scope := ProjectSettings.globalize_path("res://.godot/").replace("\\", "/").simplify_path().trim_suffix("/") + "/"
	if output.is_empty() or not absolute.to_lower().begins_with(scope.to_lower()) or not absolute.ends_with(".json") or FileAccess.file_exists(absolute): fail("Use a fresh JSON under this repository's .godot directory."); return
	var source_before := sources()
	if not abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json") or not champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities) or not layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"): fail("Current production fixture admission failed."); return
	var rows: Array[Dictionary] = []
	for scenario: Dictionary in [{"actors": 2, "paid_ticks": 0}, {"actors": 2, "paid_ticks": 180}, {"actors": 8, "paid_ticks": 180}]:
		var session := fixture(int(scenario.actors), int(scenario.paid_ticks))
		if session == null: return
		var world := session.world
		var original_hash := world.state_hash()
		var current_times: Array[int] = []
		var reference_times: Array[int] = []
		var publication_times: Array[int] = []
		var snapshot_sha := ""
		var publication_sha := ""
		var encoded_bytes := 0
		for index: int in SAMPLES + 1:
			# One unrecorded warmup, then alternating order in every pair. Each
			# operation constructs its own equality witness outside consume time.
			for use_reference: bool in ([false, true] if index % 2 == 0 else [true, false]):
				var operation: HexChemistrySnapshot.ProducerRoundtrip = ReferenceProducer.new(world.hex_court) if use_reference else Codec.ProducerRoundtrip.new(world.hex_court)
				var input := operation.snapshot()
				var before := var_to_bytes(input)
				var started := Time.get_ticks_usec()
				var prepared := operation.consume(input, world.hex_court)
				var elapsed := Time.get_ticks_usec() - started
				if prepared == null or prepared.state_hash() != world.hex_court.state_hash() or var_to_bytes(input) != before or world.state_hash() != original_hash: fail("Producer/reference changed authority or caller input."); return
				var sha := CanonicalBytes.sha256_hex(before)
				if snapshot_sha.is_empty(): snapshot_sha = sha
				elif snapshot_sha != sha: fail("Alternating producers emitted different snapshot bytes."); return
				encoded_bytes = Codec.encoded_size(input)
				if index > 0:
					if use_reference: reference_times.append(elapsed)
					else: current_times.append(elapsed)
			var started := Time.get_ticks_usec()
			var publication := SessionTransport._capture_session_packets(session)
			var elapsed := Time.get_ticks_usec() - started
			if publication.is_empty() or publication.packets.is_empty(): fail("Actual publication factory refused fixture."); return
			var public_envelope := session.capture_envelope()
			var public_packets := SessionTransport._envelope_wire_packets(public_envelope)
			var wire_bytes := var_to_bytes(publication.packets)
			if var_to_bytes(publication.envelope) != var_to_bytes(public_envelope) or wire_bytes != var_to_bytes(public_packets) or world.state_hash() != original_hash: fail("Owned publication differs from strict public packet composition."); return
			var sha := CanonicalBytes.sha256_hex(wire_bytes)
			if publication_sha.is_empty(): publication_sha = sha
			elif publication_sha != sha: fail("Unchanged workload emitted different packet bytes."); return
			if index > 0: publication_times.append(elapsed)
		var row := {"actors": scenario.actors, "paid_ticks": scenario.paid_ticks, "tick": world.tick, "topology_cells": world.hex_court.cell_count(), "dynamic_cells": world.hex_court.dynamic_cell_keys().size(), "casts": world.hex_court.casts.size(), "products": world.hex_court.products.size(), "metrics": world.hex_court.metrics.duplicate(true), "state_sha256": original_hash, "snapshot_sha256": snapshot_sha, "packet_array_sha256": publication_sha, "encoded_chemistry_bytes": encoded_bytes, "producer_consume": stats(current_times), "preceding_consume": stats(reference_times), "actual_publication_factory": stats(publication_times)}
		rows.append(row)
		print("PRODUCER_SIZE_CASE ", JSON.stringify(row))
	var source_after := sources()
	if source_before != source_after: fail("Scoped source changed during diagnostic."); return
	var receipt := {"schema": "hex-producer-size-witness-v1", "complete": true, "failures": failures, "samples": SAMPLES, "engine": Engine.get_version_info(), "source_before": source_before, "source_after": source_after, "rows": rows,
		"scope": "Headless fixed current full-map authority, two/eight actors, actual paid Rapid commands with no refill. One warmup and seven alternating consume pairs. Fresh operation construction, input copies, source/state/byte validation and bookkeeping stay outside consume timers. Factory timer includes concrete production capture/pack, but excludes ENet, fanout, test impairment and gameplay rendering. Consumes and factory are overlapping diagnostics, never additive. Seven samples cannot qualify tails, real-time frame pacing or multiplayer acceptance.", "performance_acceptance": "NOT_ESTABLISHED"}
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK: fail("Output directory creation failed."); return
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null: fail("Output open failed."); return
	var text := JSON.stringify(receipt, "\t") + "\n"
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or FileAccess.get_file_as_string(absolute) != text: fail("Output readback failed."); return
	print("PRODUCER_SIZE_COMPLETE ", absolute)
	quit(0)

func fixture(count: int, paid_ticks: int) -> AuthoritativeSession:
	var world := SimWorld.new(120, 8675309, layout.build_collision_world(), String(layout.data.id), layout.content_hash)
	if not HexWorldDefinition.from_campus(layout).bind_world(world) or not champions.apply_to_player(world.player(), "oh_tipi"): fail("World admission failed."); return null
	world.player().reset_for_spawn(layout.spawn * SimConfig.FIXED_SCALE)
	var roster: Array[Dictionary] = []
	for id: int in range(2, count + 1): roster.append({"entity_id": id, "name": "Probe %d" % id})
	var session := AuthoritativeSession.new()
	if not session.bind(world, champions, layout.spawn, "Probe Host", roster) or not SessionTransport._owned_publication_eligible(session): fail("Actual owned publication eligibility failed."); return null
	for actor: PlayerState in world.players:
		if not actor.place_proven_spell(0, MixtureCatalog.wire_for(2, "rapid")): fail("Ordinary paid slot placement refused."); return null
	for tick: int in maxi(1, paid_ticks):
		var commands: Array[SimCommand] = []
		for actor: PlayerState in world.players: commands.append(SimCommand.new(world.tick, actor.entity_id, 0, 0, SimCommand.SPELL_HELD_BITS[0] if paid_ticks > 0 else 0, 0, 0, -1000))
		if not world.step(commands): fail("Ordinary fixed-step workload failed."); return null
	if paid_ticks > 0 and int(world.hex_court.metrics.matter_paid) <= 0: fail("Paid fixture has no payment witness."); return null
	return session

static func stats(values: Array[int]) -> Dictionary:
	var ordered := values.duplicate()
	ordered.sort()
	return {"raw_us": values.duplicate(), "count": values.size(), "mean_us": float(values.reduce(func(sum: int, value: int) -> int: return sum + value, 0)) / values.size(), "median_us": ordered[ordered.size() >> 1], "max_us": ordered.back()}

static func sources() -> Dictionary:
	var result := {}
	for path: String in SOURCE_PATHS: result[path] = FileAccess.get_sha256(path)
	return result

func fail(message: String) -> void:
	failures += 1
	printerr("PRODUCER_SIZE_FAILED: ", message)
	quit(1)
