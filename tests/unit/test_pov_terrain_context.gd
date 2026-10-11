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
	return finish("pov-terrain-context")


func _layout() -> SanctumCampusLayout:
	var layout := SanctumCampusLayout.new()
	layout.canvas_size = Vector2i(128, 128)
	layout.arena_definition = {"score_limit": 3, "bounds": [0, 0, 128, 128]}
	return layout


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
