extends SceneTree
## Native production Bootstrap journey. Root owns engine execution and review.

const Scene = preload("res://scenes/bootstrap/bootstrap.tscn")
const Expansion = preload("res://src/app/element_expansion_controller.gd")
const Navigation = preload("res://src/app/local_navigation_controller.gd")
const TestingPanelScript = preload("res://src/presentation/spell_testing_panel.gd")
const Mixtures = preload("res://src/content/mixture_catalog.gd")
const Signatures = preload("res://src/content/signature_challenge_catalog.gd")
const Progression = preload("res://src/app/signature_progression.gd")
const Introduction = preload("res://src/app/optional_introduction.gd")
const Weaves = preload("res://src/app/character_weave_library.gd")
const SIZES := [Vector2i(1280, 720), Vector2i(960, 540)]
const SOURCES := [
	"res://scenes/bootstrap/bootstrap.tscn", "res://src/app/bootstrap.gd",
	"res://src/app/local_navigation_controller.gd", "res://src/app/wellspring_map_model.gd",
	"res://src/presentation/wellspring_map_panel.gd", "res://src/presentation/wellspring_district_style.gd",
	"res://src/presentation/player_compendium.gd", "res://src/content/sanctum_campus_layout.gd",
	"res://content/maps/sanctum_campus_g2_v1.json",
	"res://src/app/element_expansion_controller.gd", "res://src/app/signature_progression.gd",
	"res://src/app/signature_challenge_session.gd", "res://src/content/signature_challenge_catalog.gd",
	"res://src/app/spell_training_range.gd", "res://src/app/developer_testing_session.gd",
	"res://src/app/optional_introduction.gd", "res://src/presentation/spell_testing_panel.gd",
	"res://src/app/spell_loom_editor.gd", "res://src/presentation/spell_loom_presenter.gd",
	"res://src/app/character_weave_coordinator.gd", "res://src/content/mixture_catalog.gd",
	"res://src/content/ability_catalog.gd", "res://src/sim/combat/combat_system.gd",
	"res://src/sim/hex/hex_projectile_combat.gd", "res://src/sim/hex/hex_court_practice.gd",
	"res://src/sim/hex/hex_expanded_delivery.gd", "res://src/sim/combat/spell_status_policy.gd",
	"res://src/presentation/element_status_presenter.gd", "res://src/presentation/pixel_spell_effects.gd",
	"res://src/presentation/compact_combat_hud.gd",
	"res://src/presentation/sanctum_campus_renderer.gd", "res://src/presentation/pov_terrain_backdrop.gd",
	"res://content/abilities/foundation_abilities_v1.json",
	"res://content/abilities/element_mixtures_v1.json",
	"res://content/runtime/runtime_build_identity_v1.json",
	"res://tests/visual/capture_element_teaching_journey.gd",
]

var output := ""
var game: Node
var viewport: SubViewport
var controller: RefCounted
var frames: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var source_hashes := {}
var startup_files := {}
var saved_files := {}
var original_weave := PackedInt32Array()
var original_library := {}
var paid_events: Array[Dictionary] = []
var failed := false
var output_created := false
var steps := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/element-teaching-native-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("A fresh native res://.godot/element-teaching-native-* output is required."); return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Cannot create native journey output."); return
	output_created = true
	for path: String in SOURCES:
		source_hashes[path] = FileAccess.get_sha256(path)
		if String(source_hashes[path]).length() != 64:
			_fail("Missing reviewed source: " + path); return
	for path: String in [PlayerPreferences.DEFAULT_PATH, Weaves.DEFAULT_PATH, Weaves.DEFAULT_PATH + Weaves.BACKUP_SUFFIX, Progression.DEFAULT_PATH, Progression.DEFAULT_PATH + Progression.BACKUP_SUFFIX]:
		startup_files[path] = _file_hash(path)
	root.visible = true
	root.mode = Window.MODE_MINIMIZED
	viewport = SubViewport.new()
	viewport.size = SIZES[0]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game = Scene.instantiate()
	game.preferences_persistence_allowed = false
	game.preference_overrides_are_transient = true
	game.set_process(false)
	viewport.add_child(game)
	# _ready owns normal first-run initialization. From this point the harness
	# steps authority explicitly and disables persistence at all owning seams.
	game.set_process(false)
	game.set_process_unhandled_input(false)
	game.preferences_persistence_allowed = false
	game.preference_overrides_are_transient = true
	game.application_input_active = true
	game.character_weaves.persistence_allowed = false
	controller = game.element_expansion
	controller.progression.persistence_allowed = false
	if game.element_audio != null:
		game.element_audio.silence()
		game.element_audio.set_process(false)
	await process_frame
	if not _check(game.world != null and game.world.hex_court != null and controller.configured and controller.offline(), "production_bootstrap", {"note": "Real Bootstrap, catalogs, campus, controller and offline authority admitted."}): return
	for path: String in startup_files:
		var initialized := _file_hash(path)
		if initialized != startup_files[path] and not (path == PlayerPreferences.DEFAULT_PATH and startup_files[path] == "ABSENT" and initialized != "ABSENT"):
			_fail("Initialization changed an existing profile or created a weave/progression file: " + path); return
		saved_files[path] = initialized
	original_weave = game._local_player_state().spell_wire_ids.duplicate()
	original_library = game.character_weaves.library.weaves_by_champion.duplicate(true)
	if not await _intro_journey(): return
	if not await _range_journey(): return
	if not await _challenge_journey(): return
	if not _saved_unchanged(): return
	for path: String in source_hashes:
		if not _check(FileAccess.get_sha256(path) == source_hashes[path], "source_stable", {"path": path}): return
	_write_receipt("passed", "")
	print("PASS element teaching journey: %d checkpoints, %d real simulation steps, %d native images; visual review required" % [checkpoints.size(), steps, frames.size()])
	game.queue_free()
	await process_frame
	quit(0)


func _intro_journey() -> bool:
	if not _click_entry(0) or not _check(controller.guide.active and controller.guide.step == 0, "intro_started_from_visible_entry"): return false
	if not await _capture_sizes("01-introduction-start", {"kind": "introduction", "lesson": controller.guide.view()}): return false
	# Choose an unobstructed short lane; every travelled unit still comes from
	# ordinary movement commands, never a relocated actor or synthetic event.
	var actor: PlayerState = game._local_player_state()
	var direction := Vector2i.ZERO
	for candidate: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var clear := true
		for distance: int in [40, 80, 120]:
			if not game.world.collision.can_occupy(Vector2i(actor.position_x, actor.position_y) + candidate * distance * 1000, actor.radius): clear = false
		if clear:
			direction = candidate * 1000
			break
	if not _check(direction != Vector2i.ZERO, "intro_short_lane_available"): return false
	for unused: int in 240:
		if controller.guide.step > 0: break
		if not _step(direction): return false
	if not _check(controller.guide.step == 1, "intro_observed_real_travel"): return false
	for tick: int in 12:
		if not _step(Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP if tick == 0 else 0): return false
	for unused: int in 120:
		if controller.guide.step > 1: break
		if not _step(): return false
	if not _check(controller.guide.step == 2, "intro_observed_real_rising_jump"): return false
	if not _paid_cast(1): return false
	if not _check(controller.guide.step >= 3, "intro_observed_admitted_paid_cast"): return false
	if not await _capture_sizes("02-introduction-paid-cast", {"kind": "introduction", "lesson": controller.guide.view()}): return false
	for unused: int in 1200:
		if controller.guide.step >= 4: break
		if not _step(): return false
	if not _check(controller.guide.step == 4, "intro_observed_actual_flux_recovery"): return false
	return true


func _range_journey() -> bool:
	if not _click_entry(1) or not _check(controller.training.active and controller.panel.is_open and game.world.map_id == "hex-court-v1", "range_opened_from_visible_entry"): return false
	# Both page keys and delivery arrows go through the actual controller/panel.
	for unused: int in 9:
		if not _key(KEY_PAGEDOWN): return false
	if not _check(int(controller.panel.view().selection.element_mask) == 63, "range_reached_six_element_last_page"): return false
	if not _key(KEY_RIGHT): return false
	for unused: int in 4:
		if not _key(KEY_DOWN): return false
	if not _check(String(controller.panel.view().family) == "mantle", "range_selected_mantle_with_keyboard"): return false
	if not await _capture_sizes("03-range-six-element-mantle", {"kind": "range", "selection": controller.panel.view()}): return false
	var paid_before := paid_events.size()
	if not _key(KEY_ENTER): return false
	if not _check(not controller.panel.is_open and game._local_player_state().spell_wire_id(1) == Mixtures.wire_for(63, "mantle") and paid_events.size() == paid_before, "range_equip_did_not_cast_or_save"): return false
	if not _check(game.pending_weave_request.is_empty(), "first_loaner_ack_completed_without_save") or not _saved_unchanged(): return false
	# Step once to observe the explicit Range context before the paid mixture.
	if not _step() or not _check(controller.guide.step == 5, "intro_preserved_progress_across_range_world"): return false
	if not _paid_cast(1): return false
	if not _check(controller.guide.complete and not controller.guide.active, "intro_completed_only_after_real_mixed_paid_cast"): return false
	if not await _capture_sizes("04-mantle-paid-release", {"kind": "paid_mantle", "wire": Mixtures.wire_for(63, "mantle"), "lesson": controller.guide.view()}): return false
	if not _click_entry(1): return false
	# Deliberate visible Range controls retire this sample and its cooldown.
	if not _click_utility(2) or not _click_utility(0) or not _click_button(3): return false
	if not _key(KEY_RIGHT) or not _key(KEY_DOWN): return false
	if not _check(String(controller.panel.view().family) == "fuse", "range_selected_fuse_with_keyboard"): return false
	if not await _capture_sizes("05-range-six-element-fuse", {"kind": "range", "selection": controller.panel.view()}): return false
	var recovering_actor: PlayerState = game._local_player_state()
	var before_refusal := recovering_actor.canonical_values()
	var refusal_tick: int = game.world.tick
	var paid_at_refusal := paid_events.size()
	if not _key(KEY_ENTER): return false
	if not _check(controller.panel.is_open and controller.panel.message == "Finish the active action before changing your weave." and game.pending_weave_request.is_empty() and recovering_actor.canonical_values() == before_refusal and game.world.tick == refusal_tick and paid_events.size() == paid_at_refusal, "range_refusal_visible_inside_modal_preserves_authority", {"message": controller.panel.message, "recovery_ticks": recovering_actor.cast_recovery_ticks}): return false
	if not _saved_unchanged(): return false
	if not await _capture_sizes("05b-range-action-recovery-refusal", {"kind": "range_refusal", "message": controller.panel.message, "selection": controller.panel.view()}): return false
	# Captures and paused menus do not advance this manually stepped world.
	# Close normally, let real recovery expire, then retry the retained choice.
	if not _key(KEY_ESCAPE) or not _settle_cast_action() or not _click_entry(1): return false
	if not _check(int(controller.panel.view().selection.element_mask) == 63 and String(controller.panel.view().family) == "fuse" and controller.panel.message.is_empty(), "range_reopened_same_loaner_without_stale_refusal"): return false
	if not _key(KEY_RIGHT): return false
	if not _key(KEY_ENTER) or not _check(game._local_player_state().spell_wire_id(1) == Mixtures.wire_for(63, "fuse"), "range_fuse_loaner_equipped"): return false
	var target: PlayerState = game.world.player(2)
	if not _paid_cast(1, Vector2i(target.position_x, target.position_y)): return false
	var armed := false
	for unused: int in 480:
		for projectile: ProjectileState in game.world.projectiles:
			if projectile.source_wire_id == Mixtures.wire_for(63, "fuse") and projectile.delivery_phase == 1 and projectile.delivery_ticks > 0: armed = true
		if armed: break
		if not _step(): return false
	if not _check(armed, "fuse_reached_real_harmless_warning_without_effect_injection"): return false
	if not await _capture_sizes("06-fuse-real-warning", {"kind": "paid_fuse_warning", "wire": Mixtures.wire_for(63, "fuse")}): return false
	if not _click_entry(1) or not _key(KEY_ESCAPE): return false
	game._open_spell_loom_editor()
	var editor: SpellLoomEditor = game.spell_loom_editor
	if editor.basic_forms_only: editor.select_at(SpellLoomEditor.MORE_FORMS_RECT.get_center())
	if not _check(editor.set_element_mask(63) and editor.set_family_filter("") and editor.filtered_spell_indices().size() == 8, "loom_six_element_all_eight_forms"): return false
	editor.selected_spell_index = editor.available_wire_ids.find(Mixtures.wire_for(63, "fuse"))
	if not await _capture_sizes("07-loom-six-element-eight-deliveries", {"kind": "loom", "mask": 63, "selected_wire": editor.selected_wire_id(), "visible_count": editor.visible_spell_indices().size()}): return false
	editor.close_editor()
	if not _check(game._start_match(game.tick_rate), "range_exit_through_normal_world_transition"): return false
	if not _check(game._local_player_state().spell_wire_ids == original_weave and not controller.training.active and game.character_weaves.library.weaves_by_champion == original_library, "range_restored_ordinary_weave_and_preserved_library"): return false
	if not _saved_unchanged(): return false
	# Start and skip once more through the same visible actions: completion is
	# never a compulsory gate for returning to play.
	if not _click_entry(0) or not _click(controller.guide.skip_rect(_logical_viewport(), ThemeDB.fallback_font).get_center()):
		return false
	return _check(not controller.guide.active, "intro_visible_skip_is_immediate")


func _challenge_journey() -> bool:
	if not _click_entry(2) or not _check(controller.panel.mode == "challenges" and controller.panel.view().count == 30, "challenges_opened_with_all_thirty_rivals"): return false
	if not await _capture_sizes("08-signature-challenge-menu", {"kind": "challenges", "selection": controller.panel.view()}): return false
	var selected: Dictionary = controller.panel.view().selection.duplicate(true)
	if not _key(KEY_ENTER): return false
	var actor: PlayerState = game._local_player_state()
	var rival: PlayerState = game.world.player(2)
	if not _check(controller.challenge_active and rival.champion_wire_id == int(selected.champion_wire_id) and rival.spell_wire_id(1) == int(selected.signature_wire), "challenge_bound_actual_rival_and_signature", {"challenge": selected}): return false
	if not _check(game.pov_terrain_backdrop != null and game.pov_terrain_backdrop._court_context == SanctumCampusRenderer.SIGNATURE_CHALLENGE_CONTEXT and game.pov_terrain_backdrop._terrain != null and game.pov_terrain_backdrop._terrain.court_context == SanctumCampusRenderer.SIGNATURE_CHALLENGE_CONTEXT and SanctumCampusRenderer.arena_label(game.campus_layout.arena_definition, SanctumCampusRenderer.SIGNATURE_CHALLENGE_CONTEXT) == "SIGNATURE CHALLENGE", "signature_arena_uses_actual_mode_context_not_generic_named_rival"): return false
	if not await _capture_sizes("09-signature-challenge-ready", {"kind": "challenge", "challenge": controller.challenge.view()}): return false
	var learned_before: Array[String] = controller.progression.learned_ids()
	var tick_before: int = game.world.tick
	if not _check_hidden_challenge_entries(): return false
	if not _key(KEY_F5, true) or not _check(controller.developer.active and controller.challenge.tainted and controller.blocks_gameplay(), "developer_shortcut_taints_while_menu_pauses_steps"): return false
	if not await _capture_sizes("10-developer-menu", {"kind": "developer", "session": controller.developer.view()}): return false
	# Actual visible list input chooses refill (after the six toggle rows).
	for unused: int in 6:
		if not _key(KEY_DOWN): return false
	if not _check(String(controller.panel.view().selection.id) == "refill", "developer_selected_actual_refill_action"): return false
	if not _key(KEY_ENTER) or not _click_button(3): return false
	if not _check(game.world.tick == tick_before and not controller.developer.active and controller.challenge.tainted and not controller.panel.is_open, "paused_refill_then_leave_retains_sticky_taint"): return false
	# Deterministic reward-negative endpoint: use the real campus/champion and
	# paid casting, but suppress rival commands. This isolates reward integrity;
	# it makes no claim that these commands beat the actual challenge tactics.
	var fire_wire := Mixtures.wire_for(2, "bolt")
	var fire_slot := actor.spell_slot_index_for_wire(fire_wire) + 1
	if not _check(fire_slot > 0, "ordinary_starter_contains_paid_fire_bolt"): return false
	var initial_health := rival.health
	var observed_owned_damage := 0
	var observed_owned_defeat := false
	for unused: int in InterceptionPractice.DURATION_TICKS + 1:
		if controller.challenge.trial.is_finished(): break
		var delta := Vector2i(rival.position_x - actor.position_x, rival.position_y - actor.position_y)
		var ready: bool = game.world.tick - controller.challenge.trial.start_tick >= InterceptionPractice.READY_END
		var move := SimCommand._normalized_direction(delta.x, delta.y) if ready and delta.length_squared() > 200000 * 200000 else Vector2i.ZERO
		var held: int = SimCommand.SPELL_HELD_BITS[fire_slot - 1] if ready and move == Vector2i.ZERO else 0
		if not _step(move, held, 0, delta): return false
		for event: Dictionary in game.world.combat_events:
			if int(event.get("owner_id", 0)) == 1 and int(event.get("target_id", 0)) == 2:
				observed_owned_damage += maxi(0, int(event.get("damage", 0)))
				observed_owned_defeat = observed_owned_defeat or String(event.get("type", "")) == "champion_defeated"
	if not _check(controller.challenge.trial.phase == "victory" and rival.health <= 0 and initial_health > 0 and observed_owned_damage > 0 and observed_owned_defeat, "tainted_attempt_reached_real_paid_damage_victory", {"owned_damage": observed_owned_damage, "initial_rival_health": initial_health, "paid_casts": controller.challenge.trial.paid_casts, "rival_commands": "suppressed for this integrity regression only"}): return false
	if not _check(not bool(controller.challenge.reward.get("ok", false)) and controller.progression.learned_ids() == learned_before and not controller.progression.dirty, "real_victory_after_paused_cheat_cannot_award_or_dirty_progress", {"reward": controller.challenge.reward}): return false
	if not await _capture_sizes("11-tainted-victory-no-reward", {"kind": "challenge_result", "result": controller.challenge.view()}): return false
	if not _key(KEY_ESCAPE): return false
	return _check(not controller.challenge_active and game._local_player_state().spell_wire_ids == original_weave, "challenge_escape_returns_to_original_ordinary_weave")


func _step(move: Vector2i = Vector2i.ZERO, held: int = 0, pressed: int = 0, aim: Vector2i = Vector2i(1000, 0), target: Vector2i = Vector2i(-1, -1)) -> bool:
	if controller.panel.is_open:
		_fail("Harness attempted to advance gameplay behind an open modal."); return false
	controller.before_step()
	var world: SimWorld = game.world
	if not world.step([SimCommand.new(world.tick, 1, move.x, move.y, held, pressed, aim.x, aim.y, target.x, target.y)]):
		_fail("Ordinary simulation command failed: " + world.last_error); return false
	steps += 1
	for event: Dictionary in world.combat_events:
		if String(event.get("type", "")) == "cast_started" and int(event.get("entity_id", 0)) == 1:
			paid_events.append({"tick": world.tick - 1, "wire": int(event.get("wire_id", 0)), "flux_after": world.player(1).flux, "map": world.map_id})
	controller.after_step()
	if not world.hex_court.conservation_valid():
		_fail("Paid journey violated matter conservation."); return false
	_sync()
	return true


func _paid_cast(slot: int, target: Vector2i = Vector2i(-1, -1)) -> bool:
	var actor: PlayerState = game._local_player_state()
	var wire := actor.spell_wire_id(slot)
	var flux_before := actor.flux
	var count_before := paid_events.size()
	var matter_before := int(game.world.hex_court.metrics.get("matter_paid", 0))
	var aim := target - Vector2i(actor.position_x, actor.position_y) if target.x >= 0 else Vector2i(1000, 0)
	if not _step(Vector2i.ZERO, SimCommand.SPELL_HELD_BITS[slot - 1], SimCommand.SPELL_PRESSED_BITS[slot - 1], aim, target): return false
	if not _check(paid_events.size() == count_before + 1 and int(paid_events.back().wire) == wire and actor.flux < flux_before and int(game.world.hex_court.metrics.get("matter_paid", 0)) == matter_before + 600, "ordinary_cast_paid_flux_and_finite_matter", {"wire": wire, "flux_before": flux_before, "flux_after": actor.flux}): return false
	for unused: int in 240:
		if actor.pending_cast_ticks <= 0: break
		if not _step(Vector2i.ZERO, 0, 0, aim, target): return false
	return _check(actor.pending_cast_ticks <= 0, "paid_cast_completed_ordinary_startup", {"wire": wire})


func _settle_cast_action() -> bool:
	var actor: PlayerState = game._local_player_state()
	var tick_before: int = game.world.tick
	var steps_before := steps
	var paid_before := paid_events.size()
	var recovery_before := actor.cast_recovery_ticks
	var wires_before := actor.spell_wire_ids.duplicate()
	if not _check(not controller.panel.is_open and actor.pending_cast_ticks <= 0 and recovery_before > 0, "released_cast_still_owns_recovery_before_next_loaner", {"tick": tick_before, "recovery_ticks": recovery_before}): return false
	for unused: int in game.world.config.milliseconds_to_ticks(2000):
		if actor.pending_cast_ticks <= 0 and actor.cast_recovery_ticks <= 0: break
		if not _step(): return false
	var elapsed: int = game.world.tick - tick_before
	if not _check(actor.pending_cast_ticks <= 0 and actor.cast_recovery_ticks <= 0 and elapsed == recovery_before and steps - steps_before == elapsed and paid_events.size() == paid_before and actor.spell_wire_ids == wires_before, "loaner_wait_advanced_ordinary_recovery_without_cast_or_weave_mutation", {"tick_before": tick_before, "tick_after": game.world.tick, "simulation_steps": elapsed, "initial_recovery_ticks": recovery_before, "remaining_recovery_ticks": actor.cast_recovery_ticks}): return false
	return _saved_unchanged()


func _logical_viewport() -> Vector2:
	return Vector2(viewport.size) / float(game._ui_scale())


func _click_entry(index: int) -> bool:
	if index < 0 or index >= Expansion.ENTRIES.size(): return false
	var tick_before: int = game.world.tick
	var state_before: String = game.world.state_hash()
	# Automatic process is disabled for deterministic screenshots. Complete the
	# normal frame handoff, without clearing its guard or advancing simulation.
	for unused: int in 4:
		if game.controls_input_guard_frames <= 0: break
		game._process(0.0)
	if not _check(game.controls_input_guard_frames == 0 and game.world.tick == tick_before and game.world.state_hash() == state_before, "menu_handoff_completes_through_ordinary_zero_delta_frames"): return false
	if not _click(Navigation.MENU_ENTRY.get_center()): return false
	var rows: Array[Dictionary] = game.local_navigation.entries()
	if not _check(game.local_navigation.menu_open, "compact_menu_opens_from_visible_entry"): return false
	var id := String(Expansion.ENTRIES[index][0])
	for row: int in rows.size():
		if String(rows[row].id) == id:
			return _click(Navigation.row_rect(_logical_viewport(), rows.size(), row).get_center())
	_fail("Compact menu omits required journey action: " + id)
	return false


func _click_button(index: int) -> bool:
	var geometry := TestingPanelScript.geometry(_logical_viewport())
	return _click((geometry.buttons[index] as Rect2).get_center())


func _click_utility(index: int) -> bool:
	var geometry := TestingPanelScript.geometry(_logical_viewport())
	return _click((geometry.utilities[index] as Rect2).get_center())


func _click(point: Vector2) -> bool:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point * float(game._ui_scale())
	if not game.local_navigation.handle_input(event) and not controller.handle_input(event):
		_fail("Production controller refused a visible pointer action."); return false
	return _post_event_boundary()


func _key(code: int, shift: bool = false) -> bool:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.shift_pressed = shift
	if not game.local_navigation.handle_input(event) and not controller.handle_input(event):
		_fail("Production controller refused key " + str(code)); return false
	return _post_event_boundary()


func _check_hidden_challenge_entries() -> bool:
	var before: String = game.world.state_hash()
	var trial_before: Dictionary = controller.challenge.view().duplicate(true)
	for size: Vector2i in SIZES:
		viewport.size = size
		var menu_event := InputEventMouseButton.new()
		menu_event.button_index = MOUSE_BUTTON_LEFT
		menu_event.pressed = true
		menu_event.position = Navigation.MENU_ENTRY.get_center() * float(game._ui_scale())
		var menu_handled: bool = game.local_navigation.handle_input(menu_event)
		if not _check(not menu_handled and not game.local_navigation.menu_open and not game.local_navigation.map_panel.is_open and not controller.panel.is_open and not controller.developer.active and not controller.challenge.tainted and game.world.state_hash() == before and controller.challenge.view() == trial_before, "replacement_menu_entry_is_hidden_and_inert_during_challenge", {"size": [size.x, size.y]}): return false
		for index: int in Expansion.ENTRIES.size():
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = true
			event.position = Expansion.entry_rect(index, _logical_viewport()).get_center() * float(game._ui_scale())
			# Exercise only the modal controller. A declined click deliberately
			# does not fall through into an injected gameplay attack command.
			var handled: bool = controller.handle_input(event)
			if not _check(not handled and not controller.panel.is_open and controller.challenge_active and not controller.developer.active and not controller.challenge.tainted and game.world.state_hash() == before and controller.challenge.view() == trial_before, "hidden_challenge_entry_area_does_not_intercept_or_open_menu", {"size": [size.x, size.y], "entry_index": index}): return false
	viewport.size = SIZES[0]
	return _saved_unchanged()


func _post_event_boundary() -> bool:
	# Bootstrap._process polls this exact transaction completion after input/
	# session feedback, before advancing simulation. Automatic _process is off
	# here, so reproduce only that ordinary boundary; never clear the request.
	var pending: Dictionary = game.pending_weave_request.duplicate(true)
	var tick_before: int = game.world.tick
	game._complete_pending_weave()
	if not pending.is_empty():
		if not _check(bool(pending.get("acknowledged", false)) and not bool(pending.get("save", true)) and game.pending_weave_request.is_empty() and game.world.tick == tick_before, "ordinary_offline_weave_ack_poll_completed", {"acknowledged_request": pending}): return false
	return _saved_unchanged()


func _sync() -> void:
	game.accumulator_seconds = 0.0
	game.current_position = game._player_position()
	game.previous_position = game.current_position
	game.previous_air_height = game._local_player_state().air_height
	game._update_combat_cues(1.0 / float(game.tick_rate))
	game._ingest_combat_cues(game.world.combat_events)
	game._reset_motion_history()


func _capture_sizes(stem: String, metadata: Dictionary) -> bool:
	for size: Vector2i in SIZES:
		viewport.size = size
		_sync()
		var before: String = game.world.state_hash()
		game.queue_redraw()
		await process_frame
		await process_frame
		RenderingServer.force_draw(false)
		if not _check(game.world.state_hash() == before, "native_draw_did_not_mutate_authority", {"view": stem, "size": [size.x, size.y]}) or not _saved_unchanged(): return false
		var pixels := viewport.get_texture().get_image()
		var leaf := "%s-%dx%d.png" % [stem, size.x, size.y]
		if pixels == null or pixels.get_size() != size or pixels.save_png(output.path_join(leaf)) != OK:
			_fail("Native image failed: " + leaf); return false
		var frame := metadata.duplicate(true)
		frame.merge({"image": leaf, "pixels": [size.x, size.y], "sha256": FileAccess.get_sha256(output.path_join(leaf)), "world_hash": before, "world_tick": game.world.tick, "map": game.world.map_id, "saved_files_unchanged": true})
		frames.append(frame)
	viewport.size = SIZES[0]
	return true


func _saved_unchanged() -> bool:
	for path: String in saved_files:
		if _file_hash(path) != saved_files[path]:
			_fail("Journey changed persisted bytes: " + path); return false
	return true


func _file_hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"


func _check(condition: bool, id: String, details: Dictionary = {}) -> bool:
	if not condition: details["diagnostics"] = _failure_details()
	checkpoints.append({"id": id, "passed": condition, "details": details})
	if not condition: _fail("Checkpoint failed: " + id)
	return condition


func _failure_details() -> Dictionary:
	if game == null or controller == null or game.world == null: return {}
	var actor: PlayerState = game._local_player_state()
	var requested := actor.spell_wire_ids.duplicate() if actor != null else PackedInt32Array()
	var panel: Dictionary = controller.panel.view()
	if actor != null and String(panel.mode) == "range" and not (panel.selection as Dictionary).is_empty():
		var wire := Mixtures.wire_for(int(panel.selection.get("element_mask", 0)), String(panel.family))
		if wire > 0:
			var previous := requested.find(wire)
			if previous >= 0: requested[previous] = requested[0]
			requested[0] = wire
	return {"training_error": controller.training.last_error, "loom_availability": game._loom_assignment_availability(actor, requested) if actor != null else {}, "pending_weave_request": game.pending_weave_request.duplicate(true), "loom_status": game.spell_loom_editor.status_message, "notice": controller.notice, "panel": panel, "actual_wires": Array(actor.spell_wire_ids) if actor != null else [], "world_tick": game.world.tick}


func _write_receipt(status: String, error: String) -> void:
	if not output_created: return
	var file := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify({
		"schema": 1, "status": status, "error": error, "failure_details": _failure_details() if status == "failed" else {},
		"scope": "Native production Bootstrap/controller/menu paths, actual introductory movement/jump/payment/recovery, full-six Mantle and Fuse Range loaners, visible Fuse warning, eight-form mixed Loom, thirty-rival menu, correct signature binding, paused Developer refill/leave and sticky reward refusal after real paid damage victory.",
		"limitations": "Scripted SimCommands and menu events, not physical device input, human acceptance, frame performance, networking or all30 rival balance. The reward-negative battle suppresses rival commands to isolate progression integrity; no health/resource/effect/projectile injection is used to force its victory. Native images require individual visual review.",
		"initialization": "Only first-run creation of absent default preferences is permitted before the journey. Existing bytes cannot change. Persistence is disabled at Bootstrap, weave coordinator and progression owner; failure to taint is still detected through actual in-memory reward/dirty checks.",
		"display_server": DisplayServer.get_name(), "native_sizes": [[1280, 720], [960, 540]],
		"source_hashes": source_hashes, "startup_file_hashes": startup_files,
		"saved_file_hashes_before_and_after": saved_files, "original_ordinary_weave": Array(original_weave),
		"simulation_steps": steps, "paid_events": paid_events, "checkpoints": checkpoints, "frames": frames,
	}, "\t") + "\n")
	file.close()


func _fail(message: String) -> void:
	if failed: return
	failed = true
	_write_receipt("failed", message)
	push_error(message)
	quit(1)
