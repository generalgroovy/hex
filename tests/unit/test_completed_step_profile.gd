extends FluxTestSuite
## Proposed diagnostic regression. This suite does not measure performance.
## Synthetic stage durations test accounting only; paid equivalence and frame
## catch-up fixtures execute the ordinary production simulation separately.

const Profile = preload("res://scripts/profile-gameplay.gd")
const HexSnapshot = preload("res://src/net/hex_world_snapshot.gd")
const ORIGIN := Vector2i(600_000, 500_000)
const STAGES: Array[String] = [
	"surfaces_expiry", "command_order", "movement_cast_admission",
	"spray_contacts", "projectile_contacts", "terminal_deposits",
	"actor_product_effects", "chemistry_exposure", "finalize",
]
var abilities := AbilityCatalog.new()
var champions := ChampionCatalog.new()


class SyntheticStageWorld:
	extends SimWorld
	func _profile_stage(label: String, started: int) -> int:
		if not profile_enabled: return 0
		# No wait or timing threshold: this deterministic early spike challenges
		# loss of earlier catch-up work while the final-step value stays small.
		profile_stages_us[label] = 1000 if tick == 0 and label == "movement_cast_admission" else 1
		return started


class ResetDuringStepWorld:
	extends SimWorld
	var reset_pending := true
	func _profile_stage(label: String, started: int) -> int:
		var next := super._profile_stage(label, started)
		if reset_pending and label == "command_order":
			reset_pending = false
			profile_cumulative_reset()
		return next


class FrameHarness:
	extends Profile.TimedGame
	var camera_ticks: Array[int] = []
	func _ready() -> void:
		set_process(false)
	func _draw() -> void:
		pass
	func _advance_player_camera(_delta: float, _blocked: bool) -> void:
		camera_ticks.append(world.tick)


class NoSavePreferences:
	extends PlayerPreferences
	var saves := 0
	func save_to_file(_path: String = DEFAULT_PATH) -> bool:
		saves += 1
		return true


func run() -> int:
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "stage fixture loads actual abilities")
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "stage fixture loads finite authored champions")
	if not abilities.last_error.is_empty() or not champions.last_error.is_empty():
		return finish("completed-step-profile")
	equal(SimWorld.PROFILE_CUMULATIVE_STAGES, STAGES, "only the nine existing production stages are admitted")
	_test_opt_in_and_detachment()
	for hex: bool in [false, true]:
		_test_actual_stage_counts(hex)
		_test_paid_authority_equivalence(hex)
	_test_failed_partial()
	_test_reset_and_world_boundaries()
	_test_early_spike()
	_test_real_frame_policy_and_catch_up()
	return finish("completed-step-profile")


func _configure(world: SimWorld, hex: bool, target: bool = false) -> SimWorld:
	if hex:
		var court := HexChemistryWorld.new()
		check(court.configure_geometry(ORIGIN, HexGrid.disk(Vector2i.ZERO, 8)), "diagnostic uses finite real Hex topology")
		court.chemistry_enabled = true
		world.hex_court = court
	check(champions.apply_to_player(world.player(), "oh_tipi"), "diagnostic actor uses normal authored resources")
	world.player().reset_for_spawn(ORIGIN)
	world.player().spawn_protection_ticks = 0
	check(world.player().place_proven_spell(0, MixtureCatalog.wire_for(2, "bolt")), "ordinary Fire occupies a real slot")
	if target:
		var receiver := PlayerState.new(2)
		check(champions.apply_to_player(receiver, "s_wayne"), "target uses an actual champion profile")
		receiver.team_id = 2
		receiver.reset_for_spawn(ORIGIN + Vector2i(180_000, 0))
		receiver.spawn_protection_ticks = 0
		world.players.append(receiver)
	return world


func _world(hex: bool, target: bool = false) -> SimWorld:
	return _configure(SimWorld.new(120, 2718, CollisionWorld.new(2_000_000, 2_000_000)), hex, target)


func _zero_lanes(row: Dictionary, label: String) -> void:
	for stage: String in STAGES:
		equal(int(row.elapsed_us[stage]), 0, label + " zero elapsed " + stage)
		equal(int(row.executions[stage]), 0, label + " zero execution " + stage)


func _same_totals(left: Dictionary, right: Dictionary, label: String) -> void:
	for key: String in ["attempted_steps", "completed_steps", "failed_steps", "elapsed_us", "executions"]:
		equal(left[key], right[key], label + " " + key)


func _test_opt_in_and_detachment() -> void:
	var world := _world(true)
	var initial := world.profile_cumulative_snapshot()
	equal(String(initial.schema), "hex.sim.completed-stages.v1", "cumulative snapshot declares its independent diagnostic schema")
	check(not bool(initial.enabled) and not bool(initial.profile_enabled), "new worlds have no diagnostic instrumentation enabled")
	_zero_lanes(initial, "never enabled")
	check(not world.profile_cumulative_begin(), "cumulative instrumentation cannot enable legacy timers implicitly")
	check(world.step([]), "ordinary default world steps normally")
	_same_totals(world.profile_cumulative_snapshot(), initial, "default adds no new counters")
	check(world.profile_stages_us.is_empty(), "default has no legacy timer samples either")
	world.profile_enabled = true
	check(world.step([]), "pre-existing last-step observer still works independently")
	check(not world.profile_stages_us.is_empty(), "legacy observation remains available without cumulative opt-in")
	_same_totals(world.profile_cumulative_snapshot(), initial, "legacy last-step mode adds no new counters")
	check(world.profile_cumulative_begin(), "explicit full observer can start a diagnostic epoch")
	var baseline := world.profile_cumulative_snapshot()
	check(bool(baseline.enabled) and int(baseline.epoch) > int(initial.epoch), "explicit begin owns a fresh enabled generation")
	var detached := world.profile_cumulative_snapshot()
	detached.elapsed_us[STAGES[0]] = 12345
	detached.executions[STAGES[1]] = 999
	detached.completed_steps = 999
	equal(world.profile_cumulative_snapshot(), baseline, "returned diagnostics never expose mutable cumulative authority")
	check(world.step([]), "instrumented fixed step succeeds")
	var completed := world.profile_cumulative_snapshot()
	equal(int(completed.completed_steps), 1, "one complete step is counted once")
	world.profile_cumulative_end()
	var ended := world.profile_cumulative_snapshot()
	check(not bool(ended.enabled), "end disables accumulation")
	check(world.step([]), "ending diagnostics does not stop ordinary authority")
	_same_totals(world.profile_cumulative_snapshot(), completed, "ended observation preserves rather than extends completed totals")
	check(not world.profile_stages_us.is_empty(), "ending new totals does not silently disable existing last-step observation")


func _test_actual_stage_counts(hex: bool) -> void:
	var world := _world(hex)
	world.profile_enabled = true
	check(world.profile_cumulative_begin(), "stage-count case begins explicitly")
	var before := world.profile_cumulative_snapshot()
	var zero := Profile.TimedGame.completed_stage_delta(before, before, 0)
	check(bool(zero.valid), "a real zero-step process interval is valid")
	_zero_lanes(zero, "zero-step interval")
	for count: int in [1, 3, 8]:
		var tick_before := world.tick
		before = world.profile_cumulative_snapshot()
		var started := Time.get_ticks_usec()
		for unused: int in count:
			check(world.step([]), "all counted steps use the real simulation")
		var after := world.profile_cumulative_snapshot()
		var delta := Profile.TimedGame.completed_stage_delta(before, after, Time.get_ticks_usec() - started)
		check(bool(delta.valid), "actual stage delta is complete for Hex=%s steps=%d: %s" % [hex, count, String(delta.error)])
		equal(int(delta.completed_steps), count, "every completed catch-up step is represented")
		equal(world.tick - tick_before, count, "count corresponds to actual fixed authority ticks")
		for stage: String in STAGES:
			var expected := 0 if not hex and stage == "actor_product_effects" else count
			equal(int(delta.executions[stage]), expected, "only applicable stages execute: Hex=%s/%s" % [hex, stage])
			check(int(delta.elapsed_us[stage]) >= 0, "elapsed values retain real nonnegative clock readings")
			if expected == 0: equal(int(delta.elapsed_us[stage]), 0, "legacy cannot claim unexecuted Hex actor product work")


func _paid_commands(world: SimWorld) -> Array[SimCommand]:
	var pressed := SimCommand.PRESSED_SPELL_1 if world.tick == 0 else 0
	return [SimCommand.new(world.tick, 1, 0, 0, 0, pressed, 1000, 0), SimCommand.new(world.tick, 2)]


func _packet(world: SimWorld, hex: bool) -> Dictionary:
	return HexSnapshot.capture(world) if hex else SessionSnapshot.capture(world, {1: "Caster", 2: "Target"}, world.combat_events)


func _test_paid_authority_equivalence(hex: bool) -> void:
	var plain := _world(hex, true)
	var observed := _world(hex, true)
	observed.profile_enabled = true
	check(observed.profile_cumulative_begin(), "paid comparison explicitly enables only the observed world's totals")
	var initial_flux := plain.player().flux
	var target_health := plain.player(2).health
	var paid := false
	var flight := false
	var hit := false
	for index: int in 120:
		check(plain.step(_paid_commands(plain)), "unobserved finite paid sequence advances")
		check(observed.step(_paid_commands(observed)), "observed finite paid sequence advances")
		if index == 0:
			equal(initial_flux - plain.player().flux, int(CombatTuning.cast_definition_view(MixtureCatalog.wire_for(2, "bolt")).flux_cost), "the comparison really pays authored Flux once")
			paid = plain.player().pending_cast_wire_id != 0
		flight = flight or not plain.projectiles.is_empty()
		hit = hit or plain.player(2).health < target_health
		equal(observed.state_hash(), plain.state_hash(), "diagnostics cannot alter complete deterministic authority")
		equal(observed.combat_events, plain.combat_events, "diagnostics preserve event ordering and source attribution")
		var expected_packet := _packet(plain, hex)
		var actual_packet := _packet(observed, hex)
		check(not expected_packet.is_empty() and not actual_packet.is_empty(), "real paid current packets are admitted")
		equal(var_to_bytes(actual_packet), var_to_bytes(expected_packet), "diagnostics never change exact serialized gameplay payloads")
	check(paid and flight and hit, "equivalence includes ordinary paid startup, released flight and actual target damage")
	equal(int(observed.profile_cumulative_snapshot().completed_steps), 120, "paid diagnostic completed count equals real ticks")
	_zero_lanes(plain.profile_cumulative_snapshot(), "unobserved paid world")
	if hex:
		equal(int(plain.hex_court.metrics.matter_paid), 600, "one paid cast owns finite original matter")
		check(plain.hex_court.conservation_valid() and observed.hex_court.conservation_valid(), "both paid trajectories conserve matter")


func _test_failed_partial() -> void:
	var world := _world(true)
	world.profile_enabled = true
	check(world.profile_cumulative_begin(), "failure control starts an epoch")
	check(world.step([]), "failure control first has real completed work")
	var before := world.profile_cumulative_snapshot()
	check(not world.step([SimCommand.new(world.tick + 1, 1)]), "wrong-tick command fails after the actual surfaces phase")
	var after := world.profile_cumulative_snapshot()
	equal(world.tick, int(before.tick), "failed command does not increment completed authority tick")
	equal(int(after.attempted_steps), int(before.attempted_steps) + 1, "failed partial attempt remains accounted")
	equal(int(after.failed_steps), int(before.failed_steps) + 1, "failed partial step is explicit")
	equal(int(after.completed_steps), int(before.completed_steps), "failed partial is never promoted to completion")
	equal(after.elapsed_us, before.elapsed_us, "early failed-stage timings cannot contaminate successful elapsed totals")
	equal(after.executions, before.executions, "early failed-stage executions cannot contaminate completed counts")
	check(world.profile_stages_us.has("surfaces_expiry"), "the failed case actually executed an early measured stage")
	check(not bool(Profile.TimedGame.completed_stage_delta(before, after, 1_000_000).valid), "frame delta fails closed on partial work")
	check(not bool(Profile.TimedGame.completed_stage_delta(after, after, 0).valid), "failed-generation zero-step frame cannot masquerade as a clean sample")


func _test_reset_and_world_boundaries() -> void:
	var world := _world(true)
	world.profile_enabled = true
	check(world.profile_cumulative_begin(), "reset case begins")
	check(world.step([]), "reset case completes ordinary work")
	var before := world.profile_cumulative_snapshot()
	var hash_before := world.state_hash()
	world.profile_cumulative_reset()
	var reset := world.profile_cumulative_snapshot()
	equal(world.state_hash(), hash_before, "diagnostic reset cannot reset gameplay")
	equal(int(reset.epoch), int(before.epoch) + 1, "reset advances the observer generation")
	check(bool(reset.enabled), "enabled reset preserves explicit observation policy")
	equal(int(reset.completed_steps), 0, "reset has no inherited completions")
	_zero_lanes(reset, "reset generation")
	check(not bool(Profile.TimedGame.completed_stage_delta(before, reset, 1_000_000).valid), "cross-generation subtraction cannot invent a frame")
	var replacement := _world(true)
	replacement.profile_enabled = true
	check(replacement.profile_cumulative_begin(), "replacement owns a separate observer generation")
	check(typeof(reset.world_id) == TYPE_STRING and typeof(replacement.profile_cumulative_snapshot().world_id) == TYPE_STRING, "opaque world identities never use JSON numeric precision")
	check(String(replacement.profile_cumulative_snapshot().world_id) != String(reset.world_id), "world identity is not inferred from matching tick or epoch")
	var decoded: Variant = JSON.parse_string(JSON.stringify(reset))
	check(decoded is Dictionary and decoded.get("world_id") == reset.world_id, "actual object identity survives JSON round-trip byte-for-byte")
	check(not bool(Profile.TimedGame.completed_stage_delta(reset, replacement.profile_cumulative_snapshot(), 1_000_000).valid), "replacement world cannot bridge old totals")
	world.profile_cumulative_end()
	var disabled_epoch := int(world.profile_cumulative_snapshot().epoch)
	world.profile_cumulative_reset()
	var disabled := world.profile_cumulative_snapshot()
	check(not bool(disabled.enabled), "reset never re-enables an ended observer")
	equal(int(disabled.epoch), disabled_epoch + 1, "disabled reset still records a fresh boundary")
	var mid_step: ResetDuringStepWorld = ResetDuringStepWorld.new(120, 2718, CollisionWorld.new(2_000_000, 2_000_000))
	_configure(mid_step, true)
	mid_step.profile_enabled = true
	check(mid_step.profile_cumulative_begin(), "mid-step invalidation control begins")
	before = mid_step.profile_cumulative_snapshot()
	check(mid_step.step([]), "diagnostic invalidation does not veto a valid simulation step")
	var invalidated := mid_step.profile_cumulative_snapshot()
	equal(mid_step.tick, 1, "authority step survives diagnostic reset")
	equal(int(invalidated.attempted_steps), 0, "old attempt is excluded from the reset generation")
	equal(int(invalidated.completed_steps), 0, "old completion cannot enter a new generation")
	_zero_lanes(invalidated, "mid-step reset")
	check(not bool(Profile.TimedGame.completed_stage_delta(before, invalidated, 1_000_000).valid), "mid-frame epoch switch is explicit invalid data")
	check(mid_step.step([]), "subsequent ordinary step uses the new generation")
	equal(int(mid_step.profile_cumulative_snapshot().completed_steps), 1, "new generation resumes only on its next complete step")


func _test_early_spike() -> void:
	var world: SyntheticStageWorld = SyntheticStageWorld.new(120, 2718, CollisionWorld.new(2_000_000, 2_000_000))
	_configure(world, true)
	world.profile_enabled = true
	check(world.profile_cumulative_begin(), "synthetic clock fixture begins")
	var before := world.profile_cumulative_snapshot()
	for unused: int in 8: check(world.step([]), "synthetic duration fixture retains real authority step execution")
	var delta := Profile.TimedGame.completed_stage_delta(before, world.profile_cumulative_snapshot(), 10_000)
	check(bool(delta.valid), "bounded independently specified synthetic elapsed data is coherent")
	equal(int(world.profile_stages_us.movement_cast_admission), 1, "last-step observer alone misses the early spike")
	equal(int(delta.elapsed_us.movement_cast_admission), 1007, "all-step total retains the exact early spike and seven later stages")
	equal(int(delta.executions.movement_cast_admission), 8, "all eight successful stages retain their count")
	check(not bool(Profile.TimedGame.completed_stage_delta(before, world.profile_cumulative_snapshot(), 1006).valid), "stage time cannot exceed its enclosing process interval")


func _frame_node(mode: String) -> FrameHarness:
	var node := FrameHarness.new()
	node.preference_overrides_are_transient = true
	node.world = _world(true)
	node.input_router = InputRouter.new(1)
	node.player_preferences = NoSavePreferences.new()
	node.session_steward = SessionSteward.new()
	node.campus_layout = SanctumCampusLayout.new()
	node.ability_catalog = abilities
	node.champion_catalog = champions
	node.authoritative_session = AuthoritativeSession.new()
	check(node.authoritative_session.bind(node.world, champions, Vector2i(600, 500), "Stage Host"), "frame fixture binds ordinary authority")
	node.session_transport = SessionTransport.new()
	node.observation_budget = Profile.ObservationBudget.new()
	node.light_observer = mode in ["light", "forbidden"]
	node.all_fixed_steps = mode in ["full", "forbidden"]
	node.world.profile_enabled = not node.light_observer
	node.recording = true
	node.casting = true
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	node.expected_window_size = node.get_window().size
	return node


func _test_real_frame_policy_and_catch_up() -> void:
	InputRouter.ensure_input_map()
	var mouse_before := Input.mouse_mode
	for mode: String in ["default", "light", "full", "forbidden"]:
		for count: int in [0, 1, 8]:
			var node := _frame_node(mode)
			var before := node.world.profile_cumulative_snapshot()
			var admitted := node.begin_completed_stage_case()
			equal(admitted, mode != "forbidden", "light plus all-step instrumentation is rejected at the actual case boundary")
			var cumulative_before := node.world.profile_cumulative_snapshot()
			equal(bool(cumulative_before.enabled), mode == "full", "only explicit full observer enables new counters")
			if mode != "full":
				_same_totals(cumulative_before, before, "noninstrumented setup adds no new counters")
				equal(int(cumulative_before.epoch), int(before.epoch), "noninstrumented setup does not reset diagnostics")
			var flux_before := node.world.player().flux
			var elapsed := 0.001 if count == 0 else 1.0 / 120.0 if count == 1 else 0.1
			node._process(elapsed)
			equal(node.world.tick, count, "actual Bootstrap catch-up completes0/1/8 steps for " + mode)
			equal(node.camera_ticks, [count], "diagnostic frame still presents the completed state once")
			equal(node.process_ms.size(), 1, "one admitted process creates exactly one process observation")
			if count > 0:
				equal(flux_before - node.world.player().flux, int(CombatTuning.cast_definition_view(MixtureCatalog.wire_for(2, "bolt")).flux_cost), "frame loop retains one ordinary paid cast without refills")
			else:
				equal(node.world.player().flux, flux_before, "zero-step frame invents no paid work")
			if mode == "full":
				equal(node.all_fixed_step_samples.size(), 1, "new raw row exists even for a zero-step process")
				if node.all_fixed_step_samples.size() == 1:
					var row: Dictionary = node.all_fixed_step_samples[0]
					equal(int(row.process_index), 0, "new row aligns with the process observation")
					equal(row.before, cumulative_before, "row starts at the real pre-process counters")
					equal(row.after, node.world.profile_cumulative_snapshot(), "row ends at actual post-process authority")
					check(bool(row.delta.valid), "real catch-up interval is admitted: " + String(row.delta.error))
					equal(int(row.delta.completed_steps), count, "all real catch-up work is counted")
					for stage: String in STAGES:
						equal(int(row.delta.executions[stage]), count, "Hex frame records every applicable stage exactly once per successful step")
				if count > 0:
					equal(node.world_stage_samples.size(), 1, "old last-step record remains independently available")
					equal(int(node.world_stage_samples[0].steps_this_frame), count, "old row remains explicitly scoped to its last step")
			else:
				equal(node.all_fixed_step_samples.size(), 0, "default/light add no new cumulative snapshots or history")
				_same_totals(node.world.profile_cumulative_snapshot(), before, "default/light frame adds no new counters")
			node.end_completed_stage_case()
			var ended := node.world.profile_cumulative_snapshot()
			check(not bool(ended.enabled), "case completion disables new accumulation")
			node.recording = false
			node.casting = false
			node._process(1.0 / 120.0)
			_same_totals(node.world.profile_cumulative_snapshot(), ended, "unrecorded inter-case step cannot leak into completed-case totals")
			var preferences: NoSavePreferences = node.player_preferences
			node.session_transport.stop()
			node.free()
			equal(preferences.saves, 0, "diagnostic fixture does not persist player settings")
	Input.mouse_mode = mouse_before
