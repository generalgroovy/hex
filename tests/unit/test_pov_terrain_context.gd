extends FluxTestSuite

const Backdrop = preload("res://src/presentation/pov_terrain_backdrop.gd")
const TrialHarness = preload("res://tests/support/solo_trial_harness.gd")
const TrialRun = preload("res://src/app/solo_duel_trial.gd")


class RendererSpy:
	extends SanctumCampusRenderer
	var calls: Array[Dictionary] = []
	var prepared := true
	var prepared_renderer: SanctumCampusRenderer
	func terrain_ready_for(visible: Rect2) -> bool:
		return prepared_renderer.terrain_ready_for(visible) if prepared_renderer != null else prepared
	func draw(
		canvas: CanvasItem,
		layout: SanctumCampusLayout,
		presentation_tick: int,
		focus_world_position: Vector2 = Vector2(-1000000.0, -1000000.0),
		reduced_effects: bool = false,
		station_titles: bool = true,
		visible_world_rect: Rect2 = Rect2(),
		practice_details: bool = true,
		court_context: String = "",
	) -> void:
		calls.append({"canvas": canvas, "layout": layout, "tick": presentation_tick,
			"focus": focus_world_position, "reduced": reduced_effects,
			"titles": station_titles, "visible_rect": visible_world_rect,
			"details": practice_details, "context": court_context,
			"label": arena_label(layout.arena_definition, court_context)})


func run() -> int:
	_test_context_transitions()
	_test_context_before_configuration()
	_test_signature_context_transitions()
	_test_production_trial_lifecycle()
	_test_atomic_capture_handoff()
	return finish("pov-terrain-context")


func _layout() -> SanctumCampusLayout:
	var layout := SanctumCampusLayout.new()
	layout.canvas_size = Vector2i(128, 128)
	layout.arena_definition = {"score_limit": 3, "bounds": [0, 0, 128, 128]}
	return layout


func _complete_capture_sample(backdrop: SubViewport) -> void:
	# A deterministic completion seam checks ownership/state only. The native
	# transition capture separately verifies pixels across real post-draw frames.
	var target: SubViewport = backdrop._pending_view
	if target != null: target.render_target_update_mode = SubViewport.UPDATE_DISABLED
	backdrop._complete_capture(backdrop._revision)


func _test_atomic_capture_handoff() -> void:
	var renderer := RendererSpy.new()
	var backdrop := Backdrop.new()
	backdrop.configure(renderer, _layout())
	var first := Rect2(100, 100, 320, 240)
	check(not backdrop.prepare_view(first) and not backdrop.ready_for(first), "first view stays unready until its pixels finish")
	check(backdrop.backdrop_texture() == null, "no unfinished viewport texture is published")
	var first_completion: Callable = backdrop._pending_completion
	check(RenderingServer.frame_post_draw.is_connected(first_completion), "pending capture owns one renderer completion callback")
	_complete_capture_sample(backdrop)
	check(not RenderingServer.frame_post_draw.is_connected(first_completion) and not backdrop._pending_completion.is_valid(), "completion releases its callback even when invoked through the deterministic test seam")
	check(backdrop.ready_for(first), "completed first view publishes readiness")
	var first_rect := backdrop.world_rect
	var first_texture := backdrop.backdrop_texture()
	var first_revision: int = backdrop._revision
	for query: int in 100:
		check(backdrop.prepare_view(first), "unchanged view remains warm")
	equal(backdrop._revision, first_revision, "stationary frames schedule zero additional captures")
	equal(backdrop.get_child_count(), 1, "stationary view has not allocated a spare render target")

	# Approach the edge while the old captured image still covers all pixels.
	var edge := Rect2(230, 100, 320, 240)
	check(first_rect.encloses(edge) and not first_rect.encloses(edge.grow(Backdrop.REFRESH_GUARD)), "control reaches refresh guard before exposing missing pixels")
	check(backdrop.prepare_view(edge), "ordinary motion keeps completed terrain available during proactive capture")
	equal(backdrop.world_rect, first_rect, "capture cannot publish new UV origin against old pixels")
	equal(backdrop.backdrop_texture(), first_texture, "committed texture survives until replacement has rendered")
	check(backdrop._pending_view != backdrop._committed_view, "capture renders only the inactive target")
	var next_rect: Rect2 = backdrop._pending_rect
	var pending_revision: int = backdrop._revision
	for query: int in 100:
		check(backdrop.prepare_view(edge), "pending replacement cannot blank a still-covered view")
	equal(backdrop._revision, pending_revision, "same pending view does not queue duplicate captures")
	backdrop._complete_capture(first_revision)
	equal(backdrop.world_rect, first_rect, "stale completion cannot change published geometry")
	_complete_capture_sample(backdrop)
	equal(backdrop.world_rect, next_rect, "completion publishes exact pending world coordinates")
	check(backdrop.backdrop_texture() != first_texture and backdrop.ready_for(edge), "completion swaps pixels and readiness together")
	equal(backdrop.get_child_count(), 2, "moving views retain exactly one spare target")

	var committed_rect := backdrop.world_rect
	var committed_texture := backdrop.backdrop_texture()
	var destination := Rect2(4200, 3800, 320, 240)
	check(not backdrop.prepare_view(destination), "teleport beyond committed pixels remains safely unready")
	check(not backdrop.ready_for(destination), "old origin is never passed off as destination terrain")
	equal(backdrop.world_rect, committed_rect, "teleport staging does not mutate committed UVs")
	equal(backdrop.backdrop_texture(), committed_texture, "teleport staging does not resize or overwrite sampled target")
	var superseded: int = backdrop._revision
	var superseded_completion: Callable = backdrop._pending_completion
	check(backdrop.prepare_view(edge), "return to already covered view can reuse original pixels immediately")
	check(backdrop._pending_view == null, "return cancels irrelevant pending capture")
	check(not RenderingServer.frame_post_draw.is_connected(superseded_completion), "cancellation releases obsolete completion ownership before any subsequent capture")
	backdrop._complete_capture(superseded)
	equal(backdrop.world_rect, committed_rect, "late abandoned capture cannot replace useful current pixels")
	equal(backdrop.backdrop_texture(), committed_texture, "abandoned completion never causes a one-frame texture swap")

	# A return may sit inside the old texture but outside its refresh guard,
	# while the tiles needed for the next recapture have become unavailable.
	backdrop.prepare_view(destination)
	var cold_return_revision: int = backdrop._revision
	var cold_edge := Rect2(committed_rect.end.x - 325.0, 100, 320, 240)
	check(committed_rect.encloses(cold_edge) and not committed_rect.encloses(cold_edge.grow(Backdrop.REFRESH_GUARD)), "cold-return control occupies the narrow completed edge")
	renderer.prepared = false
	check(backdrop.prepare_view(cold_edge), "completed edge stays usable while its requested refresh tiles are cold")
	check(backdrop._pending_view == null, "cold edge return cancels unrelated pending destination before checking terrain readiness")
	backdrop._complete_capture(cold_return_revision)
	check(backdrop.ready_for(cold_edge), "late distant completion cannot blank cold edge coverage")
	equal(backdrop.backdrop_texture(), committed_texture, "cold edge cancellation retains the same completed texture")

	renderer.prepared = false
	check(not backdrop.prepare_view(destination), "cold destination cannot schedule incomplete terrain")
	check(backdrop.ready_for(edge), "unready destination leaves original completed coverage intact")
	renderer.prepared = true
	for index: int in 8:
		var distant := Rect2(4200 if index % 2 == 0 else 100, 3800 if index % 2 == 0 else 100, 320, 240)
		backdrop.prepare_view(distant)
		_complete_capture_sample(backdrop)
		check(backdrop.ready_for(distant), "successive arrivals become ready only on completion")
		equal(backdrop.get_child_count(), 2, "repeated movement alternates the same pair without unbounded allocation")
		for target: SubViewport in [backdrop, backdrop._spare_view]:
			check(target.size.x <= Backdrop.MAX_VIEWPORT.x and target.size.y <= Backdrop.MAX_VIEWPORT.y, "each retained render target respects explicit pixel bound")
	var wide := Rect2(-500, -500, 9000, 6000)
	backdrop.prepare_view(wide)
	_complete_capture_sample(backdrop)
	check(backdrop.ready_for(wide), "very large view has bounded-resolution coverage rather than cropped pixels")
	check(backdrop._committed_view.size.x <= Backdrop.MAX_VIEWPORT.x and backdrop._committed_view.size.y <= Backdrop.MAX_VIEWPORT.y, "ultrawide capture cannot exceed allocation cap")
	backdrop.set_court_context(SanctumCampusRenderer.SOLO_DUEL_CONTEXT)
	var previous_completion: Callable = backdrop._pending_completion
	check(RenderingServer.frame_post_draw.is_connected(previous_completion), "context refresh owns a pending completion")
	backdrop.set_court_context(SanctumCampusRenderer.SIGNATURE_CHALLENGE_CONTEXT)
	check(RenderingServer.frame_post_draw.is_connected(backdrop._pending_completion), "replacement owns exactly its current completion")
	var completion_count := 0
	for connection: Dictionary in RenderingServer.frame_post_draw.get_connections():
		var connected: Callable = connection.callable
		if connected.get_object() == backdrop:
			completion_count += 1
			equal(connected.get_bound_arguments(), [backdrop._revision], "context replacement retains only the current completion revision")
	equal(completion_count, 1, "context replacement does not accumulate renderer callbacks")
	var last_completion: Callable = backdrop._pending_completion
	backdrop._exit_tree()
	check(not RenderingServer.frame_post_draw.is_connected(last_completion) and backdrop._pending_view == null, "teardown leaves no owned completion or queued capture")
	backdrop.free()


func _draw_sample(backdrop: SubViewport, renderer: RendererSpy) -> Dictionary:
	# Forward the cached canvas draw into a spy, without invoking RenderingServer
	# or claiming these argument/cache checks are a rendered sight-transition test.
	backdrop.get_child(0)._draw()
	return renderer.calls.back()


func _test_context_transitions() -> void:
	var renderer := RendererSpy.new()
	var layout := _layout()
	var original_definition := layout.arena_definition.duplicate(true)
	var backdrop := Backdrop.new()
	backdrop.configure(renderer, layout)
	equal(backdrop.get_child_count(), 1, "backdrop retains one static terrain canvas")
	equal(backdrop.render_target_update_mode, SubViewport.UPDATE_DISABLED, "configuration waits for a bounded actual view before allocating terrain")
	renderer.prepared = false
	check(not backdrop.prepare_view(Rect2(0, 0, 128, 128)), "cold terrain refuses a premature static capture")
	equal(backdrop.render_target_update_mode, SubViewport.UPDATE_DISABLED, "cold source cannot schedule a blank texture as authoritative background")
	check(not backdrop.world_rect.has_area(), "cold refusal publishes no captured region")
	renderer.prepared = true
	check(not backdrop.prepare_view(Rect2(0, 0, 128, 128)), "initial bounded view requests its first capture")
	equal(backdrop.render_target_update_mode, SubViewport.UPDATE_ONCE, "prepared view requests one initial capture")
	var sample := _draw_sample(backdrop, renderer)
	equal(sample.label, "PROVING COURT · FIRST 3", "ordinary cached terrain retains authored court objective")
	equal(sample.context, "", "ordinary context matches live renderer default")
	check(sample.canvas == backdrop.get_child(0) and sample.layout == layout, "backdrop draws its original canvas and layout")
	equal(sample.tick, 0, "cached terrain has no animation clock")
	equal(sample.focus, Vector2(-1000000, -1000000), "cached terrain retains remote non-player focus")
	check(sample.reduced and not sample.titles and not sample.details, "context does not enable proximity instructions or live station titles")
	equal(sample.visible_rect, backdrop.world_rect, "cached terrain forwards its exact bounded world-space region")
	check(sample.visible_rect.encloses(Rect2(0, 0, 128, 128)), "bounded static region includes the real view")

	# Model the engine's UPDATE_ONCE -> UPDATE_DISABLED completion explicitly.
	# An unchanged context must not revive this already-captured viewport.
	backdrop.render_target_update_mode = SubViewport.UPDATE_DISABLED
	check(not backdrop.set_court_context(""), "same normal context is a no-op")
	check(not backdrop.set_court_context("unknown"), "unknown context shares renderer's normal fallback")
	equal(backdrop.render_target_update_mode, SubViewport.UPDATE_DISABLED, "normal and invalid repeats cannot force per-frame rendering")

	check(backdrop.set_court_context(SanctumCampusRenderer.SOLO_DUEL_CONTEXT), "trial start changes cached objective")
	equal(backdrop.render_target_update_mode, SubViewport.UPDATE_ONCE, "trial start requests exactly one new capture")
	sample = _draw_sample(backdrop, renderer)
	equal(sample.label, "DUEL TRIAL · DEFEAT OH TIPI", "out-of-sight trial terrain forwards the live single-defeat objective")
	equal(sample.context, SanctumCampusRenderer.SOLO_DUEL_CONTEXT, "trial context is forwarded unchanged")
	backdrop.render_target_update_mode = SubViewport.UPDATE_DISABLED
	check(not backdrop.set_court_context(SanctumCampusRenderer.SOLO_DUEL_CONTEXT), "retry within the same trial needs no new static capture")
	equal(backdrop.render_target_update_mode, SubViewport.UPDATE_DISABLED, "same trial remains frozen")

	check(backdrop.set_court_context(""), "return to Wellspring restores normal objective")
	equal(backdrop.render_target_update_mode, SubViewport.UPDATE_ONCE, "return requests one ordinary terrain capture")
	equal(_draw_sample(backdrop, renderer).label, "PROVING COURT · FIRST 3", "return cannot retain stale trial copy")
	backdrop.render_target_update_mode = SubViewport.UPDATE_DISABLED
	check(backdrop.set_court_context(SanctumCampusRenderer.SOLO_DUEL_CONTEXT), "new trial can follow a completed return")
	check(backdrop.set_court_context("unsupported-session"), "unknown context leaves trial for normal renderer fallback")
	equal(_draw_sample(backdrop, renderer).label, SanctumCampusRenderer.arena_label(layout.arena_definition, "unsupported-session"), "invalid fallback exactly matches live renderer")
	backdrop.render_target_update_mode = SubViewport.UPDATE_DISABLED
	check(not backdrop.set_court_context("another-unknown"), "equivalent unknown contexts do not repeatedly dirty the cache")
	equal(backdrop.render_target_update_mode, SubViewport.UPDATE_DISABLED, "unknown context changes cannot turn the cache into a live viewport")
	equal(backdrop.get_child_count(), 1, "all transitions reuse the existing static canvas")
	equal(layout.arena_definition, original_definition, "context never rewrites the authored court or score limit")
	backdrop.free()


func _test_context_before_configuration() -> void:
	for entry: Array in [[SanctumCampusRenderer.SOLO_DUEL_CONTEXT, "DUEL TRIAL · DEFEAT OH TIPI"], [SanctumCampusRenderer.SIGNATURE_CHALLENGE_CONTEXT, "SIGNATURE CHALLENGE"]]:
		var renderer := RendererSpy.new()
		var backdrop := Backdrop.new()
		check(backdrop.set_court_context(String(entry[0])), "encounter context may be selected before native backdrop setup")
		backdrop.configure(renderer, _layout())
		backdrop.prepare_view(Rect2(0, 0, 128, 128))
		equal(_draw_sample(backdrop, renderer).label, String(entry[1]), "late configuration cannot replace either active encounter label with ordinary scoring")
		backdrop.free()


func _test_signature_context_transitions() -> void:
	var renderer := RendererSpy.new()
	var layout := _layout()
	var original_definition := layout.arena_definition.duplicate(true)
	var backdrop := Backdrop.new()
	backdrop.configure(renderer, layout)
	backdrop.prepare_view(Rect2(0, 0, 128, 128))
	for prior: String in ["", SanctumCampusRenderer.SOLO_DUEL_CONTEXT]:
		backdrop.set_court_context(prior)
		backdrop.render_target_update_mode = SubViewport.UPDATE_DISABLED
		check(backdrop.set_court_context(SanctumCampusRenderer.SIGNATURE_CHALLENGE_CONTEXT), "signature encounter replaces ordinary or Oh Tipi trial context")
		equal(backdrop.render_target_update_mode, SubViewport.UPDATE_ONCE, "signature entry requests one static terrain recapture")
		var sample := _draw_sample(backdrop, renderer)
		equal(sample.context, SanctumCampusRenderer.SIGNATURE_CHALLENGE_CONTEXT, "cached terrain forwards the exact signature context")
		equal(sample.label, "SIGNATURE CHALLENGE", "signature terrain cannot name the unrelated Oh Tipi rival or normal score rule")
		backdrop.render_target_update_mode = SubViewport.UPDATE_DISABLED
		check(not backdrop.set_court_context(SanctumCampusRenderer.SIGNATURE_CHALLENGE_CONTEXT), "retry or another signature rival retains the same correct static label")
		equal(backdrop.render_target_update_mode, SubViewport.UPDATE_DISABLED, "unchanged signature context never creates per-frame recaptures")
		check(backdrop.set_court_context(prior), "signature encounter can return to either ordinary or single-rival trial terrain")
		equal(_draw_sample(backdrop, renderer).label, SanctumCampusRenderer.arena_label(layout.arena_definition, prior), "return label exactly matches the live renderer context")
	backdrop.set_court_context(SanctumCampusRenderer.SIGNATURE_CHALLENGE_CONTEXT)
	check(backdrop.set_court_context("unknown-signature-context"), "unknown context clears a prior signature encounter to ordinary terrain")
	equal(_draw_sample(backdrop, renderer).label, "PROVING COURT · FIRST 3", "unknown signature context uses authored normal score fallback")
	backdrop.render_target_update_mode = SubViewport.UPDATE_DISABLED
	check(not backdrop.set_court_context("another-unknown"), "equivalent unknown labels remain a cache no-op")
	equal(layout.arena_definition, original_definition, "signature context never rewrites authored arena rules")
	equal(backdrop.get_child_count(), 1, "every signature transition reuses the existing static terrain canvas")
	backdrop.free()


func _test_production_trial_lifecycle() -> void:
	var node := TrialHarness.new()
	var configured := node.configure_trial_fixture()
	check(configured, "terrain lifecycle configures actual Bootstrap without saved preference writes")
	if not configured:
		node.free()
		return
	# The default authority harness intentionally omits all native presenters.
	# Configure just the real terrain dependency; the label spy still owns draw.
	node.visual_language = VisualLanguage.new()
	node.campus_renderer = SanctumCampusRenderer.new()
	var terrain_configured := node.visual_language.load_from_file() and node.campus_renderer.configure(node.visual_language) and node.campus_renderer.configure_campus(node.campus_layout)
	check(terrain_configured, "headless lifecycle configures its real terrain readiness dependency")
	if not terrain_configured:
		node.free()
		return
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	var renderer := RendererSpy.new()
	var backdrop := Backdrop.new()
	renderer.prepared_renderer = node.campus_renderer
	var view := Rect2(1400, 600, 1280, 720)
	var terrain_prepared := node.campus_renderer.illustrated_kit.prepare_ground_view(SanctumCampusRenderer.terrain_preparation_rect(view))
	check(terrain_prepared, "headless lifecycle explicitly prepares the actual baked view before capture")
	if not terrain_prepared:
		backdrop.free()
		node.free()
		return
	# Native setup is intentionally bypassed in this headless-capable fixture.
	# The real backdrop and all production start/return hooks remain in use.
	backdrop.configure(renderer, node.campus_layout)
	backdrop.prepare_view(view)
	node.pov_terrain_backdrop = backdrop
	node.add_child(backdrop)
	var normal_label := SanctumCampusRenderer.arena_label(node.campus_layout.arena_definition)
	var original_champion: String = node.selected_champion_id
	var original_weave: PackedInt32Array = node.world.player().spell_wire_ids.duplicate()
	var preferences: Dictionary = node.player_preferences.to_dictionary().duplicate(true)
	equal(_draw_sample(backdrop, renderer).label, normal_label, "production fixture starts with the ordinary cached objective")
	backdrop.render_target_update_mode = SubViewport.UPDATE_DISABLED
	check(node._open_solo_trial_menu(), "normal offline trial entry opens the production briefing")
	equal(_draw_sample(backdrop, renderer).label, normal_label, "briefing alone does not relabel the ordinary world")
	equal(backdrop.render_target_update_mode, SubViewport.UPDATE_DISABLED, "opening briefing does not recapture static terrain")
	check(node._handle_solo_trial_input(_key(KEY_ENTER)), "production confirmation consumes trial start input")
	check(node.interception_practice_active and node.solo_trial.phase == TrialRun.READY, "production input starts the real ready trial")
	if not node.interception_practice_active:
		node.free()
		return
	equal(_draw_sample(backdrop, renderer).label, "DUEL TRIAL · DEFEAT OH TIPI", "successful production startup updates the existing cached terrain")
	equal(backdrop.render_target_update_mode, SubViewport.UPDATE_ONCE, "production startup requests a bounded recapture")
	backdrop.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var first_world: SimWorld = node.world

	# This is a terminal bookkeeping boundary fixture, not paid encounter proof.
	# It verifies that showing a result keeps the trial objective until leaving.
	node.world.tick = InterceptionPractice.DURATION_TICKS
	check(node.solo_trial.observe(node.world), "terminal boundary is observed through actual trial bookkeeping")
	equal(node.solo_trial.phase, TrialRun.TIMEOUT, "boundary fixture enters the real timeout result")
	check(node._solo_trial_frozen(), "actual terminal offline result remains frozen")
	equal(_draw_sample(backdrop, renderer).label, "DUEL TRIAL · DEFEAT OH TIPI", "terminal result retains trial objective rather than ordinary scoring")
	equal(backdrop.render_target_update_mode, SubViewport.UPDATE_DISABLED, "result alone does not wake the terrain cache")
	check(node._handle_solo_trial_input(_key(KEY_ENTER)), "production result confirmation consumes retry input")
	check(node.world != first_world and node.world.tick == 0 and node.solo_trial.phase == TrialRun.READY, "retry actually creates a fresh trial through production input")
	equal(_draw_sample(backdrop, renderer).label, "DUEL TRIAL · DEFEAT OH TIPI", "retry's internal ordinary reset cannot leave stale cached score copy")
	equal(backdrop.render_target_update_mode, SubViewport.UPDATE_ONCE, "synchronous retry ends with one pending static capture")
	backdrop.render_target_update_mode = SubViewport.UPDATE_DISABLED
	check(not backdrop.set_court_context(SanctumCampusRenderer.SOLO_DUEL_CONTEXT), "completed retry cache is stable under repeated active context")
	equal(backdrop.render_target_update_mode, SubViewport.UPDATE_DISABLED, "unchanged retried context cannot start continuous viewport rendering")
	check(node._handle_solo_trial_input(_key(KEY_ESCAPE)), "production leave input returns to Wellspring")
	check(not node.interception_practice_active and node.solo_trial.phase == TrialRun.IDLE, "production leave releases trial ownership")
	equal(_draw_sample(backdrop, renderer).label, normal_label, "production return restores ordinary objective in the same backdrop")
	equal(backdrop.render_target_update_mode, SubViewport.UPDATE_ONCE, "production return requests one ordinary recapture")
	equal(node.selected_champion_id, original_champion, "terrain lifecycle leaves selected champion restoration intact")
	equal(node.world.player().spell_wire_ids, original_weave, "terrain lifecycle leaves pretrial weave restoration intact")
	equal(node.player_preferences.to_dictionary(), preferences, "trial terrain transitions never change user preferences")
	check(node.pov_terrain_backdrop == backdrop and backdrop.get_child_count() == 1, "all production transitions reuse the same backdrop and canvas")
	node.free()


func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event
