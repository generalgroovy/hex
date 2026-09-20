extends Node2D


const MAX_CATCH_UP_STEPS: int = 8
const RuntimeContentSummaryScript = preload("res://src/app/runtime_content_summary.gd")
const PlayerCompendiumScript = preload("res://src/presentation/player_compendium.gd")
const CharacterSelectionGridScript = preload("res://src/presentation/character_selection_grid.gd")
const ChampionAttunementScript = preload("res://src/app/champion_attunement.gd")
const ChemistryCoach = preload("res://src/presentation/chemistry_practice_coach.gd")
const MovementCoach = preload("res://src/presentation/movement_practice_coach.gd")
const ElementAudioScript = preload("res://src/presentation/element_audio.gd")
const SOUND_DOWN_RECT := Rect2(960, 144, 40, 30)
const SOUND_UP_RECT := Rect2(1008, 144, 40, 30)
const SOUND_MUTE_RECT := Rect2(1056, 144, 76, 30)
const SNAPSHOT_RATE: int = 60
const EMOTE_COOLDOWN_MS: int = 1200
const STEWARD_CONFIRMATION_MS: int = 3000
const SAFE_QUIT_GRACE_MS: int = 500
const GUEST_RELEASE_REASON: String = "The host released you from the Farflow company."
const COMPANY_CLOSE_REASON: String = "The host closed the Farflow company."
const APPLICATION_CLOSE_REASON: String = "The host safely closed FLUX 2."
const HUB_DEFINITION_PATH: String = "res://content/maps/sanctum_hub_v1.json"
const CAMPUS_LAYOUT_PATH: String = "res://content/maps/sanctum_campus_g2_v1.json"
const ABILITY_CATALOG_PATH: String = "res://content/abilities/foundation_abilities_v1.json"
const REACTION_CATALOG_PATH: String = "res://content/reactions/first_eight_element_reactions_v1.json"
const CHAMPION_CATALOG_PATH: String = "res://content/champions/foundation_champions_v1.json"
const LOADOUT_PATH: String = "res://content/loadouts/foundation_practitioner_v1.json"
const MATERIAL_CATALOG_PATH: String = "res://content/materials/foundation_materials_v1.json"
const MATERIAL_YARD_PATH: String = "res://content/maps/sanctum_material_yard_v1.json"
const VISUAL_LANGUAGE_PATH: String = "res://content/visual/visual_language_v1.json"
const COMPACT_HUD_PATH: String = "res://content/visual/compact_hud_v1.json"
const WATER_COLOR := Color("153c4a")
const WATER_HIGHLIGHT_COLOR := Color("28677a")
const FOREST_SHADOW_COLOR := Color("17261b")
const GRASS_COLOR := Color("304b27")
const MOSS_COLOR := Color("66834a")
const PATH_COLOR := Color("8b7045")
const PALE_STONE_COLOR := Color("b6a477")
const WORLDBONE_COLOR := Color("26282a")
const TIMBER_COLOR := Color("4b3226")
const BRASS_COLOR := Color("b88438")
const ATTUNEMENT_COLOR := Color("55dbe0")
const FLUX_COLOR := Color("9b65d9")
const FIRE_COLOR := Color("e58a38")
const PARCHMENT_COLOR := Color("e2d8b2")
const PANEL_COLOR := Color("11130ee6")
const PLAYER_COLOR := ATTUNEMENT_COLOR
const POV_MASK_COLOR := Color("090d0be8")
const POV_EDGE_COLOR := Color("6f8c72a8")

var world: SimWorld
var element_audio: ElementAudioScript
var input_router: InputRouter
var hub_definition: HubDefinition
var campus_layout: SanctumCampusLayout
var campus_renderer: SanctumCampusRenderer
var visual_language: VisualLanguage
var visual_accessibility_filter: VisualAccessibilityFilter
var compact_hud: CompactCombatHud
var interaction_presenter: WellspringInteractionPresenter
var cartoon_champion_presenter: CartoonChampionPresenter
var _character_page_preparation_key := ""
var _character_pages_ready := false
var _character_page_preparation_error := ""
var foundation_spell_presenter: FoundationSpellPresenter
var burst_projectile_presenter: BurstProjectilePresenter
var heavy_blast_presenter := preload("res://src/presentation/heavy_blast_presenter.gd").new()
var element_chemistry_presenter: ElementChemistryPresenter
var ability_catalog: AbilityCatalog
var runtime_content_summary: Dictionary = {}
var runtime_content_lines: Array[String] = []
var reaction_catalog: ReactionCatalog
var reaction_definitions: ReactionDefinitionTable
var champion_catalog: ChampionCatalog
var loadout: LoadoutDefinition
var material_registry: MaterialRegistry
var material_yard: MaterialYardDefinition
var material_grid: MaterialGrid
var material_preview_texture: ImageTexture
var player_preferences: PlayerPreferences
var controls_editor: ControlBindingEditor
var spell_loom_editor: SpellLoomEditor
var player_compendium: PlayerCompendiumScript
var character_selection_grid: CharacterSelectionGridScript
var session_transport: SessionTransport
var session_steward: SessionSteward
var spectator_focus: SpectatorFocus
var authoritative_session: AuthoritativeSession
var client_prediction: ClientPrediction
var session_event_inbox: SessionEventInbox
var session_names_by_entity: Dictionary[int, String] = {}
var tick_rate: int = 120
var accumulator_seconds: float = 0.0
var previous_position := Vector2.ZERO
var current_position := Vector2.ZERO
var previous_prediction_position := Vector2.ZERO
var previous_air_height: int = 0
var actor_motion_history := preload("res://src/presentation/actor_motion_history.gd").new()
var remote_snapshot_age_seconds: float = 0.0
var dropped_time_seconds: float = 0.0
var clamped_frame_time_seconds: float = 0.0
var show_debug_overlay: bool = false
var movement_trace := MovementPracticeTrace.new()
var capture_pointer_world := Vector2i(-1, -1)
var capture_spawn_world := Vector2i(-1, -1)
var capture_expanded_station_id: String = ""
var requested_capture_active_cast: bool = false
var requested_capture_spell_slot: int = 0
var requested_capture_chain_spell_slot: int = 0
var requested_capture_spell_sequence := PackedInt32Array()
var requested_capture_spell_wires := PackedInt32Array()
var requested_capture_wait_for_peer: bool = false
var requested_capture_movement: String = ""
var requested_capture_movement_direction: Vector2i = Vector2i.RIGHT
var requested_capture_social_bubble: bool = false
var requested_capture_visual_profile: String = ""
var requested_capture_reduced_effects: bool = false
var capture_active_cast_sent: bool = false
var capture_chain_cast_sent: bool = false
var capture_spell_sequence_index: int = 0
var focused_station_id: String = ""
var expanded_station_id: String = ""
var station_notice: String = ""
var station_notice_seconds: float = 0.0
var selected_champion_id: String = "oh_tipi"
var station_activation_device := ControlBindingEditor.DEVICE_KEYBOARD
var movement_practice_device := ControlBindingEditor.DEVICE_KEYBOARD
var join_address: String = "127.0.0.1"
var join_address_editor_open: bool = false
var join_address_editor_text: String = ""
var join_address_editor_replace_on_type: bool = false
var join_address_editor_error: String = ""
var session_port: int = SessionTransport.DEFAULT_PORT
var local_player_name: String = "Traveller"
var selected_charter_id: String = SessionCharter.DEFAULT_ID
var session_hearth_values := PackedInt32Array()
var session_round_values := PackedInt32Array()
var requested_farflow_mode: String = ""
var client_input_sequence: int = 0
var client_replica_active: bool = false
var last_client_snapshot_tick: int = -1
var network_projectile_overflow: int = 0
var network_event_overflow: int = 0
var network_event_overflow_notice_seconds: float = 0.0
var combat_cues: Array[Dictionary] = []
var interception_feedback := InterceptionFeedback.new()
var interception_practice_active := false
var hex_court_presenter := preload("res://src/presentation/hex_court_presenter.gd").new()
const HEX_START_RECT := Rect2(20, 160, 226, 30)
const HEX_LOOM_RECT := Rect2(20, 220, 226, 30)
const HEX_CONTROLS_RECT := Rect2(20, 256, 226, 30)
const HEX_GALLERY_RECT := Rect2(20, 292, 226, 30)
var interception_practice_setup: Dictionary = {}
const INTERCEPTION_START_RECT := Rect2(20, 88, 226, 30)
const INTERCEPTION_LEAVE_RECT := Rect2(20, 124, 226, 30)
var client_request_sequence: int = 0
var emote_ready_tick_by_entity: Dictionary[int, int] = {}
var social_bubbles: Array[Dictionary] = []
var requested_emote_smoke: bool = false
var emote_smoke_sent: bool = false
var requested_prediction_smoke: bool = false
var prediction_smoke_started: bool = false
var prediction_smoke_inputs_sent: int = 0
var prediction_smoke_start_x: float = 0.0
var prediction_smoke_reported: bool = false
var requested_reconnect_smoke: bool = false
var reconnect_smoke_stage: int = 0
var reconnect_smoke_delay_seconds: float = 0.0
var reconnect_smoke_entity_id: int = 0
var requested_hearth_smoke: bool = false
var hearth_smoke_ready_sent: bool = false
var hearth_smoke_started_reported: bool = false
var requested_round_smoke: bool = false
var round_smoke_active_reported: bool = false
var requested_rematch_smoke: bool = false
var rematch_smoke_ready_sent: bool = false
var rematch_smoke_active_reported: bool = false
var requested_steward_smoke: bool = false
var steward_smoke_due_tick: int = -1
var steward_smoke_sent: bool = false
var requested_spectator_smoke: bool = false
var spectator_smoke_active_reported: bool = false
var spectator_smoke_handoff_reported: bool = false
var spectator_smoke_round_reported: bool = false
var host_close_pending: bool = false
var requested_safe_quit_smoke: bool = false
var safe_quit_smoke_seconds: float = 0.0
var safe_quit_pending: bool = false
var safe_quit_deadline_ms: int = 0
var controls_input_guard_frames: int = 0
var application_input_active: bool = true
var show_visual_specimen: bool = false
var preference_overrides_are_transient: bool = false
var preferences_persistence_allowed: bool = true
var character_weaves := CharacterWeaveCoordinator.new()
var pending_weave_request: Dictionary = {}
var client_weave_restore_champion := 0


func _ready() -> void:
	get_tree().auto_accept_quit = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_preferences = PlayerPreferences.new()
	var preferences_existed: bool = FileAccess.file_exists(PlayerPreferences.DEFAULT_PATH)
	var preferences_loaded: bool = player_preferences.load_from_file()
	preferences_persistence_allowed = preferences_loaded or not preferences_existed
	if not preferences_loaded:
		push_warning("%s; using safe defaults" % player_preferences.last_error)
		player_preferences.reset_to_defaults()
	if preferences_persistence_allowed and not player_preferences.save_to_file():
		preferences_persistence_allowed = false
		push_warning(player_preferences.last_error)
	controls_editor = ControlBindingEditor.new()
	controls_editor.set_migration_notices(player_preferences.migration_notices)
	spell_loom_editor = SpellLoomEditor.new()
	player_compendium = PlayerCompendiumScript.new()
	character_selection_grid = CharacterSelectionGridScript.new()
	_apply_preference_overrides()
	if DisplayServer.get_name() != "headless":
		element_audio = ElementAudioScript.new()
		add_child(element_audio)
		element_audio.prepare()
		element_audio.set_volume(player_preferences.sound_volume_percent)
	hub_definition = HubDefinition.new()
	if not hub_definition.load_from_file(HUB_DEFINITION_PATH):
		push_error(hub_definition.last_error)
		get_tree().quit(1)
		return
	campus_layout = SanctumCampusLayout.new()
	if not campus_layout.load_from_file(CAMPUS_LAYOUT_PATH):
		push_error(campus_layout.last_error)
		get_tree().quit(1)
		return
	visual_language = VisualLanguage.new()
	if not visual_language.load_from_file(VISUAL_LANGUAGE_PATH):
		push_error(visual_language.last_error)
		get_tree().quit(1)
		return
	visual_accessibility_filter = VisualAccessibilityFilter.new()
	if not hex_court_presenter.configure(visual_language):
		push_error("Hex court requires the validated shared visual language")
		get_tree().quit(1)
		return
	if not visual_accessibility_filter.configure():
		push_error(visual_accessibility_filter.last_error)
		get_tree().quit(1)
		return
	add_child(visual_accessibility_filter)
	requested_capture_visual_profile = _requested_capture_visual_profile()
	requested_capture_reduced_effects = _requested_capture_reduced_effects()
	if not _apply_visual_accessibility_profile():
		push_error(visual_accessibility_filter.last_error)
		get_tree().quit(1)
		return
	campus_renderer = SanctumCampusRenderer.new()
	if not campus_renderer.configure(visual_language):
		push_error(campus_renderer.last_error)
		get_tree().quit(1)
		return
	if not campus_renderer.configure_campus(campus_layout):
		push_error("Wellspring illustrated campus could not load: %s" % campus_renderer.last_error)
		get_tree().quit(1)
		return
	interaction_presenter = WellspringInteractionPresenter.new()
	if not interaction_presenter.configure(visual_language, campus_layout):
		push_error(interaction_presenter.last_error)
		get_tree().quit(1)
		return
	compact_hud = CompactCombatHud.new()
	if not compact_hud.configure(visual_language, COMPACT_HUD_PATH):
		push_error(compact_hud.last_error)
		get_tree().quit(1)
		return
	cartoon_champion_presenter = CartoonChampionPresenter.new()
	if not cartoon_champion_presenter.configure(visual_language):
		push_error(cartoon_champion_presenter.last_error)
		get_tree().quit(1)
		return
	compact_hud.champion_art = cartoon_champion_presenter
	show_visual_specimen = OS.get_cmdline_user_args().has("--visual-specimen")
	show_debug_overlay = OS.get_cmdline_user_args().has("--debug-overlay")
	capture_pointer_world = _requested_capture_pointer()
	capture_spawn_world = _requested_capture_spawn()
	capture_expanded_station_id = _requested_capture_expanded_station()
	requested_capture_active_cast = OS.get_cmdline_user_args().has("--capture-cast-active")
	requested_capture_spell_slot = _requested_capture_spell_slot()
	requested_capture_chain_spell_slot = _requested_capture_chain_spell_slot()
	requested_capture_spell_sequence = _requested_capture_spell_sequence()
	requested_capture_spell_wires = _requested_capture_spell_wires()
	requested_capture_wait_for_peer = OS.get_cmdline_user_args().has("--capture-wait-for-peer")
	requested_capture_movement = _requested_capture_movement()
	requested_capture_movement_direction = _requested_capture_direction()
	requested_capture_social_bubble = OS.get_cmdline_user_args().has("--capture-social-bubble")
	ability_catalog = AbilityCatalog.new()
	if not ability_catalog.load_from_file(ABILITY_CATALOG_PATH):
		push_error(ability_catalog.last_error)
		get_tree().quit(1)
		return
	reaction_catalog = ReactionCatalog.new()
	if not reaction_catalog.load_from_file(REACTION_CATALOG_PATH):
		push_error(reaction_catalog.last_error)
		get_tree().quit(1)
		return
	reaction_definitions = ReactionDefinitionTable.new()
	if not reaction_definitions.compile(reaction_catalog, ability_catalog):
		push_error(reaction_definitions.last_error)
		get_tree().quit(1)
		return
	foundation_spell_presenter = FoundationSpellPresenter.new()
	if not foundation_spell_presenter.configure(visual_language, ability_catalog):
		push_error(foundation_spell_presenter.last_error)
		get_tree().quit(1)
		return
	burst_projectile_presenter = BurstProjectilePresenter.new()
	if not burst_projectile_presenter.configure(visual_language, ability_catalog):
		push_error(burst_projectile_presenter.last_error)
		get_tree().quit(1)
		return
	if burst_projectile_presenter.direction_contract_hash != foundation_spell_presenter.direction_contract_hash:
		push_error("Spell presenters resolved different direction contracts")
		get_tree().quit(1)
		return
	element_chemistry_presenter = ElementChemistryPresenter.new()
	if not element_chemistry_presenter.configure(visual_language):
		push_error(element_chemistry_presenter.last_error)
		get_tree().quit(1)
		return
	champion_catalog = ChampionCatalog.new()
	if not champion_catalog.load_from_file(CHAMPION_CATALOG_PATH, ability_catalog):
		push_error(champion_catalog.last_error)
		get_tree().quit(1)
		return
	_ensure_character_weaves()
	var compendium_roster := ChampionRosterPlan.new()
	if not compendium_roster.load_from_files() or not player_compendium.configure(champion_catalog, compendium_roster):
		push_error("Compendium catalog validation failed: %s / %s" % [compendium_roster.last_error, player_compendium.overview.get("error", "")])
		get_tree().quit(1)
		return
	if not character_selection_grid.configure(champion_catalog, compendium_roster, cartoon_champion_presenter):
		push_error(character_selection_grid.last_error)
		get_tree().quit(1)
		return
	selected_champion_id = _requested_champion_id()
	runtime_content_summary = RuntimeContentSummaryScript.build(ability_catalog, champion_catalog, reaction_catalog)
	runtime_content_lines = RuntimeContentSummaryScript.spell_loom_lines(runtime_content_summary)
	join_address = _requested_join_address()
	session_port = _requested_session_port()
	local_player_name = _requested_player_name()
	selected_charter_id = _requested_session_charter_id()
	requested_farflow_mode = _requested_farflow_mode()
	requested_emote_smoke = _requested_emote_smoke()
	requested_prediction_smoke = _requested_prediction_smoke()
	requested_reconnect_smoke = _requested_reconnect_smoke()
	requested_hearth_smoke = _requested_hearth_smoke()
	requested_round_smoke = _requested_round_smoke()
	requested_rematch_smoke = _requested_rematch_smoke()
	requested_steward_smoke = _requested_steward_smoke()
	requested_spectator_smoke = _requested_spectator_smoke()
	requested_safe_quit_smoke = _requested_safe_quit_smoke()
	session_transport = SessionTransport.new()
	if _ensure_runtime_identity():
		print("FLUX2 runtime build: %s · %s" % [session_transport.build_id, session_transport.runtime_source_sha256])
	session_steward = SessionSteward.new()
	spectator_focus = SpectatorFocus.new()
	authoritative_session = AuthoritativeSession.new()
	client_prediction = ClientPrediction.new()
	session_event_inbox = SessionEventInbox.new()
	loadout = LoadoutDefinition.new()
	if not loadout.load_from_file(LOADOUT_PATH, ability_catalog):
		push_error(loadout.last_error)
		get_tree().quit(1)
		return
	material_registry = MaterialRegistry.new()
	if not material_registry.load_from_file(MATERIAL_CATALOG_PATH):
		push_error(material_registry.last_error)
		get_tree().quit(1)
		return
	material_yard = MaterialYardDefinition.new()
	if not material_yard.load_from_file(MATERIAL_YARD_PATH, material_registry):
		push_error(material_yard.last_error)
		get_tree().quit(1)
		return
	tick_rate = _requested_tick_rate()
	if not _start_match(tick_rate):
		get_tree().quit(1)
		return
	if OS.get_cmdline_user_args().has("--capture-practice-trace"):
		movement_trace.begin(world.tick, _player_position(), _local_player_state().champion_wire_id)
	if OS.get_cmdline_user_args().has("--interception-trial") and requested_farflow_mode.is_empty():
		_start_interception_trial()
	if OS.get_cmdline_user_args().has("--hex-court") and requested_farflow_mode.is_empty():
		_start_hex_court()
	if not requested_capture_spell_wires.is_empty() and not apply_capture_spell_wires(_local_player_state(), requested_capture_spell_wires):
		push_error("Capture-only spell weave could not be applied")
		get_tree().quit(1)
		return
	if requested_capture_social_bubble:
		social_bubbles.append({"entity_id": SessionTransport.SERVER_PEER_ID, "text": "HELLO!", "remaining": 120.0, "duration": 120.0})
	_start_requested_farflow()
	if not _prepare_active_character_pages():
		push_error(_character_page_preparation_error)
		get_tree().quit(1)
		return
	if not capture_expanded_station_id.is_empty():
		focused_station_id = capture_expanded_station_id
		expanded_station_id = capture_expanded_station_id
		station_notice = ""
		station_notice_seconds = 0.0
		if capture_expanded_station_id == "controls-lectern":
			controls_editor.open_editor()
		elif capture_expanded_station_id == "spell-loom":
			spell_loom_editor.open_editor(_local_player_state(), ability_catalog)
		elif capture_expanded_station_id == "champion-loom":
			_open_character_gallery()
		elif capture_expanded_station_id == "farflow-join":
			_open_join_address_editor()
	for argument: String in OS.get_cmdline_user_args():
		if argument in ["--capture-compendium=movement", "--capture-compendium=characters"]:
			_open_player_compendium(PlayerCompendiumScript.CHARACTERS if argument.ends_with("=characters") else PlayerCompendiumScript.MOVEMENT)
		elif argument == "--capture-compendium=chemistry":
			_open_player_compendium(PlayerCompendiumScript.CHEMISTRY)
	print(
		"FLUX2 bootstrap: %d Hz, protocol %d, movement %s, transitions %s, controls %s, POV %s/%d/%d, camera %d%%, visual %s, accessibility %s/%s/%s, HUD %s, interactions %s, spells %s/skeleton %s/directions %s, bursts %s, cartoon recipes %s/atlas %s, Sanctum districts %d, travel nodes %d, campus %s, ability catalog %s, reactions %s/bounded-level-one, champions %s, build %d/13, materials %s, yard %s"
		% [
			tick_rate,
			SimConfig.PROTOCOL_VERSION,
			MovementTuning.compatibility_hash().left(12),
			world.transition_policy.content_hash.left(12),
			player_preferences.movement_reference,
			player_preferences.pov_mode,
			player_preferences.pov_angle_degrees,
			player_preferences.pov_range,
			player_preferences.camera_zoom_percent,
			visual_language.content_hash().left(12),
			visual_accessibility_filter.content_hash.left(12),
			visual_accessibility_filter.current_profile_id,
			"reduced" if _reduced_effects_enabled() else "full",
			compact_hud.content_hash.left(12),
			interaction_presenter.content_hash.left(12),
			foundation_spell_presenter.content_hash.left(12),
			foundation_spell_presenter.animation_skeleton_hash.left(12),
			foundation_spell_presenter.direction_contract_hash.left(12),
			burst_projectile_presenter.content_hash.left(12),
			cartoon_champion_presenter.content_hash.left(12),
			cartoon_champion_presenter.atlas_hash.left(12),
			hub_definition.districts_by_id.size(),
			hub_definition.travel_nodes_by_id.size(),
			campus_layout.content_hash.left(12),
			ability_catalog.content_hash.left(12),
			reaction_definitions.content_hash.left(12),
			champion_catalog.content_hash.left(12),
			loadout.active_points,
			material_registry.content_hash.left(12),
			material_yard.content_hash.left(12),
		]
	)
	set_process(true)
	print("FLUX2 illustrated campus: %s, art elevation 55deg/cardinal, setup %d ms, %d decorations" % [
		campus_renderer.illustrated_kit.content_hash.left(12),
		campus_renderer.illustrated_kit.ground_generation_ms,
		campus_renderer.illustrated_kit.decorations.size(),
	])
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_safe_quit("window")
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		application_input_active = false
		if element_audio != null:
			element_audio.silence()
		if input_router != null:
			input_router.discard_transient_movement_input()
		if spell_loom_editor != null:
			spell_loom_editor.cancel_drag()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		application_input_active = true
		controls_input_guard_frames = 2
		if input_router != null:
			input_router.discard_transient_movement_input()


func _unhandled_input(event: InputEvent) -> void:
	if world == null:
		return
	if input_router != null and _gameplay_input_blocked():
		input_router.observe_input_event(event)
		input_router.discard_transient_movement_input()
	if not application_input_active:
		return
	if not _gameplay_input_blocked():
		_observe_station_activation_device(event)
		_observe_movement_practice_device(event)
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and session_transport.mode == SessionTransport.Mode.OFFLINE:
			var point: Vector2 = event.position / _ui_scale()
			if world.hex_court != null:
				var opened := false
				if HEX_LOOM_RECT.has_point(point):
					spell_loom_editor.open_editor(_local_player_state(), ability_catalog)
					opened = true
				elif HEX_CONTROLS_RECT.has_point(point):
					controls_editor.open_editor()
					opened = true
				elif HEX_GALLERY_RECT.has_point(point):
					_open_character_gallery()
					opened = true
				if opened:
					controls_input_guard_frames = 2
					input_router.discard_transient_movement_input()
					get_viewport().set_input_as_handled()
					return
			if world.hex_court == null and HEX_START_RECT.has_point(point):
				_start_hex_court()
				get_viewport().set_input_as_handled()
				return
			if INTERCEPTION_START_RECT.has_point(point):
				if world.hex_court != null:
					_start_hex_court()
				else:
					_start_interception_trial()
				get_viewport().set_input_as_handled()
				return
			if (interception_practice_active or world.hex_court != null) and INTERCEPTION_LEAVE_RECT.has_point(point):
				_start_match(tick_rate)
				get_viewport().set_input_as_handled()
				return
	if join_address_editor_open:
		_handle_join_address_input(event)
		return
	if spell_loom_editor != null and spell_loom_editor.is_open:
		_handle_spell_loom_input(event)
		return
	if _character_gallery_open():
		_handle_character_gallery_input(event)
		return
	# Binding capture and the other editors retain priority over fixed UI keys.
	if controls_editor != null and not controls_editor.is_open:
		if player_compendium.is_open:
			player_compendium.handle_event(event, ThemeDB.fallback_font, get_viewport().get_mouse_position() / _compendium_scale())
			controls_input_guard_frames = 2
			get_viewport().set_input_as_handled()
			queue_redraw()
			return
		var open_keyboard: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4
		var open_controller: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK
		if open_keyboard or open_controller:
			_open_player_compendium(PlayerCompendiumScript.MOVEMENT, ControlBindingEditor.DEVICE_CONTROLLER if open_controller else ControlBindingEditor.DEVICE_KEYBOARD)
			get_viewport().set_input_as_handled()
			return
	if controls_editor == null or not controls_editor.is_open:
		if input_router != null and controls_input_guard_frames <= 0:
			input_router.observe_input_event(event)
		return
	var handled := false
	var bindings_changed := false
	if controls_editor.capturing:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			controls_editor.cancel_capture()
			handled = true
		elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK:
			controls_editor.cancel_capture()
			handled = true
		else:
			bindings_changed = controls_editor.capture_event(event, player_preferences)
			handled = bindings_changed or event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventJoypadMotion
	else:
		if event is InputEventKey and event.pressed and not event.echo:
			var key_event := event as InputEventKey
			match key_event.keycode:
				KEY_ESCAPE:
					_close_controls_editor()
				KEY_UP:
					controls_editor.move_selection(-1, 0)
				KEY_DOWN:
					controls_editor.move_selection(1, 0)
				KEY_LEFT:
					controls_editor.move_selection(0, -1)
				KEY_RIGHT:
					controls_editor.move_selection(0, 1)
				KEY_ENTER, KEY_KP_ENTER:
					controls_editor.begin_capture()
				KEY_BACKSPACE, KEY_DELETE:
					bindings_changed = controls_editor.unbind_selected(player_preferences)
				KEY_R:
					controls_editor.reset_bindings(player_preferences)
					bindings_changed = true
				KEY_M:
					_toggle_reduced_effects_preference()
				KEY_H:
					_toggle_high_contrast_preference()
				KEY_BRACKETLEFT:
					_adjust_sound_volume(-10)
				KEY_BRACKETRIGHT:
					_adjust_sound_volume(10)
				KEY_0:
					_adjust_sound_volume(0, true)
			handled = true
		elif event is InputEventMouseButton and event.pressed:
			var mouse_event := event as InputEventMouseButton
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				controls_editor.move_selection(-1, 0)
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				controls_editor.move_selection(1, 0)
			elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
				var pointer := mouse_event.position / _ui_scale()
				if SOUND_DOWN_RECT.has_point(pointer):
					_adjust_sound_volume(-10)
				elif SOUND_UP_RECT.has_point(pointer):
					_adjust_sound_volume(10)
				elif SOUND_MUTE_RECT.has_point(pointer):
					_adjust_sound_volume(0, true)
				else:
					controls_editor.select_cell(pointer)
			handled = true
		elif event is InputEventJoypadButton and event.pressed:
			var joy_event := event as InputEventJoypadButton
			match joy_event.button_index:
				JOY_BUTTON_DPAD_UP:
					controls_editor.move_selection(-1, 0)
				JOY_BUTTON_DPAD_DOWN:
					controls_editor.move_selection(1, 0)
				JOY_BUTTON_DPAD_LEFT:
					controls_editor.move_selection(0, -1)
				JOY_BUTTON_DPAD_RIGHT:
					controls_editor.move_selection(0, 1)
				JOY_BUTTON_A:
					controls_editor.begin_capture()
				JOY_BUTTON_B:
					_close_controls_editor()
				JOY_BUTTON_X:
					bindings_changed = controls_editor.unbind_selected(player_preferences)
				JOY_BUTTON_Y:
					controls_editor.reset_bindings(player_preferences)
					bindings_changed = true
				JOY_BUTTON_LEFT_STICK:
					_toggle_reduced_effects_preference()
				JOY_BUTTON_RIGHT_STICK:
					_toggle_high_contrast_preference()
				JOY_BUTTON_LEFT_SHOULDER:
					_adjust_sound_volume(-10)
				JOY_BUTTON_RIGHT_SHOULDER:
					_adjust_sound_volume(10)
				JOY_BUTTON_START:
					_adjust_sound_volume(0, true)
			handled = true
	if bindings_changed:
		_commit_control_bindings()
	if handled:
		controls_input_guard_frames = 2
		get_viewport().set_input_as_handled()
		queue_redraw()


func _handle_join_address_input(event: InputEvent) -> void:
	var handled := false
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		match key_event.keycode:
			KEY_ESCAPE:
				_close_join_address_editor("Join cancelled.")
			KEY_ENTER, KEY_KP_ENTER:
				_commit_join_address_and_seek()
			KEY_BACKSPACE:
				join_address_editor_replace_on_type = false
				join_address_editor_text = join_address_editor_text.left(maxi(0, join_address_editor_text.length() - 1))
				join_address_editor_error = ""
			KEY_DELETE:
				join_address_editor_text = ""
				join_address_editor_replace_on_type = false
				join_address_editor_error = ""
			KEY_V when key_event.ctrl_pressed:
				var pasted := DisplayServer.clipboard_get().strip_edges()
				if PlayerPreferences.is_valid_farflow_join_address(pasted):
					join_address_editor_text = pasted
					join_address_editor_replace_on_type = false
					join_address_editor_error = ""
				else:
					join_address_editor_error = "Clipboard is not one safe host/IP address."
			_:
				if key_event.unicode >= 33 and key_event.unicode <= 126:
					var character := String.chr(key_event.unicode)
					if character not in "/\\" and join_address_editor_text.length() < 255:
						if join_address_editor_replace_on_type:
							join_address_editor_text = ""
							join_address_editor_replace_on_type = false
						join_address_editor_text += character
						join_address_editor_error = ""
		handled = true
	elif event is InputEventJoypadButton and event.pressed:
		var joy_event := event as InputEventJoypadButton
		if joy_event.button_index == JOY_BUTTON_A:
			_commit_join_address_and_seek()
			handled = true
		elif joy_event.button_index in [JOY_BUTTON_B, JOY_BUTTON_BACK]:
			_close_join_address_editor("Join cancelled.")
			handled = true
	if handled:
		controls_input_guard_frames = 2
		get_viewport().set_input_as_handled()
		queue_redraw()


func _handle_spell_loom_input(event: InputEvent) -> void:
	if not pending_weave_request.is_empty():
		controls_input_guard_frames = 2
		get_viewport().set_input_as_handled()
		return
	if spell_loom_editor.starter_preview_active():
		var apply := false
		var cancel := false
		if event is InputEventKey and event.pressed and not event.echo:
			apply = event.keycode in [KEY_ENTER, KEY_KP_ENTER]
			cancel = event.keycode == KEY_ESCAPE
		elif event is InputEventJoypadButton and event.pressed:
			apply = event.button_index == JOY_BUTTON_A
			cancel = event.button_index == JOY_BUTTON_B
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var pointer: Vector2 = event.position / _ui_scale()
			apply = SpellLoomEditor.STARTER_PREVIEW_APPLY_RECT.has_point(pointer)
			cancel = SpellLoomEditor.STARTER_PREVIEW_CANCEL_RECT.has_point(pointer)
		if cancel: spell_loom_editor.cancel_starter_preview()
		elif apply: _submit_starter_weave()
		controls_input_guard_frames = 2
		get_viewport().set_input_as_handled()
		queue_redraw()
		return
	var handled := false
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		match key_event.keycode:
			KEY_ESCAPE:
				_close_spell_loom_editor()
			KEY_UP:
				spell_loom_editor.move_selection(-1, 0)
			KEY_DOWN:
				spell_loom_editor.move_selection(1, 0)
			KEY_LEFT:
				spell_loom_editor.move_selection(0, -1)
			KEY_RIGHT:
				spell_loom_editor.move_selection(0, 1)
			KEY_ENTER, KEY_KP_ENTER:
				_submit_spell_loom_choice()
			KEY_HOME:
				spell_loom_editor.prepare_starter_preview(_local_player_state(), champion_catalog, ability_catalog)
		handled = true
	elif event is InputEventMouseMotion:
		spell_loom_editor.pointer_move((event as InputEventMouseMotion).position / _ui_scale())
		handled = true
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		var pointer := mouse_event.position / _ui_scale()
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			spell_loom_editor.move_selection(-1, 0)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			spell_loom_editor.move_selection(1, 0)
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				if SpellLoomEditor.CLOSE_RECT.has_point(pointer):
					_close_spell_loom_editor()
				elif SpellLoomEditor.STARTER_BUTTON_RECT.has_point(pointer):
					spell_loom_editor.prepare_starter_preview(_local_player_state(), champion_catalog, ability_catalog)
				elif SpellLoomEditor.ASSIGN_RECT.has_point(pointer):
					_submit_spell_loom_choice()
				else:
					spell_loom_editor.pointer_down(pointer, _local_player_state())
			elif spell_loom_editor.pointer_up(pointer):
				_submit_spell_loom_choice()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			spell_loom_editor.cancel_drag()
		handled = true
	elif event is InputEventJoypadButton and event.pressed:
		var joy_event := event as InputEventJoypadButton
		match joy_event.button_index:
			JOY_BUTTON_DPAD_UP:
				spell_loom_editor.move_selection(-1, 0)
			JOY_BUTTON_DPAD_DOWN:
				spell_loom_editor.move_selection(1, 0)
			JOY_BUTTON_DPAD_LEFT:
				spell_loom_editor.move_selection(0, -1)
			JOY_BUTTON_DPAD_RIGHT:
				spell_loom_editor.move_selection(0, 1)
			JOY_BUTTON_A:
				_submit_spell_loom_choice()
			JOY_BUTTON_X:
				spell_loom_editor.prepare_starter_preview(_local_player_state(), champion_catalog, ability_catalog)
			JOY_BUTTON_B:
				_close_spell_loom_editor()
		handled = true
	if handled:
		controls_input_guard_frames = 2
		get_viewport().set_input_as_handled()
		queue_redraw()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if element_audio != null:
		element_audio.silence()
	if player_preferences != null and not _save_player_preferences_if_persistent():
		push_warning(player_preferences.last_error)
	if session_transport != null:
		session_transport.stop()


func _process(delta: float) -> void:
	if world == null:
		return
	if session_transport != null:
		session_transport.poll()
		_sync_session_transport()
	_update_network_feedback_notice(delta)
	if requested_safe_quit_smoke and not safe_quit_pending:
		safe_quit_smoke_seconds += delta
		if safe_quit_smoke_seconds >= 0.25:
			_request_safe_quit("smoke")
	if safe_quit_pending:
		_advance_safe_quit()
		return
	_update_reconnect_smoke(delta)
	if player_compendium != null and player_compendium.is_open:
		player_compendium.refresh_status(_local_player_state())
	var controls_blocking := _gameplay_input_blocked()
	if element_audio != null and (controls_blocking or _is_spectating()):
		element_audio.silence()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if controls_blocking or not get_window().has_focus() else Input.MOUSE_MODE_HIDDEN
	if controls_input_guard_frames > 0:
		controls_input_guard_frames -= 1
	if not controls_blocking:
		_handle_preference_actions()
		if Input.is_action_just_pressed(&"practice_trace"):
			movement_trace.toggle(world.tick, _player_position(), _local_player_state().champion_wire_id)
		if Input.is_action_just_pressed(&"practice_retry"):
			movement_trace.begin(world.tick, _player_position(), _local_player_state().champion_wire_id)
	if not controls_blocking and Input.is_action_just_pressed(&"toggle_debug_overlay"):
		show_debug_overlay = not show_debug_overlay
	if not controls_blocking and Input.is_action_just_pressed(&"reset_match"):
		if session_transport.is_connected_client():
			station_notice = "Only the Farflow host can restore the shared court."
			station_notice_seconds = 2.5
		elif session_transport.is_host() and int(_current_round_state().get("phase", SessionRound.Phase.HEARTH)) != SessionRound.Phase.HEARTH:
			station_notice = "The live court resolves before the Hearth can be restored."
			station_notice_seconds = 2.5
		elif not _restart_shared_seed(tick_rate):
			set_process(false)
			return
	_update_station_focus()
	if session_steward != null and world != null:
		session_steward.expire(world.tick)
	station_notice_seconds = maxf(0.0, station_notice_seconds - delta)
	remote_snapshot_age_seconds = minf(0.1, remote_snapshot_age_seconds + maxf(0.0, delta))
	_update_combat_cues(delta)
	interception_feedback.advance(delta)
	_update_social_bubbles(delta)
	if client_prediction != null:
		client_prediction.advance_visual(delta)
		if session_transport.is_connected_client() and client_prediction.is_ready():
			current_position = client_prediction.presented_position_pixels()
	if not controls_blocking and Input.is_action_just_pressed(InputRouter.SPECTATE_NEXT_ACTION) and _is_spectating():
		var next_focus_id := spectator_focus.cycle_next()
		if next_focus_id > 0:
			station_notice = "Following %s." % _spectator_name(next_focus_id)
			station_notice_seconds = 1.5
	if not controls_blocking and Input.is_action_just_pressed(InputRouter.INTERACT_ACTION) and not _is_spectating():
		_activate_focused_station()
		# A station can open a modal during this frame; never sample the same
		# interaction press as a movement or spell command afterwards.
		controls_blocking = controls_blocking or _gameplay_input_blocked()
	if controls_blocking:
		input_router.discard_transient_movement_input()
	if not controls_blocking and Input.is_action_just_pressed(InputRouter.EMOTE_ACTION):
		_submit_session_request(SessionTransport.REQUEST_EMOTE)

	var fixed_delta: float = 1.0 / float(tick_rate)
	clamped_frame_time_seconds += maxf(0.0, delta - 0.1)
	accumulator_seconds += minf(delta, 0.1)
	var steps: int = 0
	while accumulator_seconds >= fixed_delta and steps < MAX_CATCH_UP_STEPS:
		# Frame-start already services tick zero. During a long host frame, admit
		# newly arrived commands before the next existing authority tick. Client
		# snapshot/prediction synchronization remains at the frame boundary.
		if steps > 0 and session_transport != null and session_transport.is_host():
			var catch_up_world := world
			session_transport.poll()
			_sync_session_transport()
			if world != catch_up_world or not session_transport.is_host():
				queue_redraw()
				return
		previous_position = current_position
		if session_transport.is_connected_client() and client_prediction.is_ready():
			previous_prediction_position = client_prediction.raw_position_pixels()
		var prior_motion_state: PlayerState = client_prediction.predicted_state if session_transport.is_connected_client() and client_prediction.is_ready() else _local_player_state()
		previous_air_height = prior_motion_state.air_height if prior_motion_state != null else 0
		if requested_capture_movement in ["hit", "impact_recovery"] and world.tick == 4 and not session_transport.is_connected_client():
			MovementSystem.apply_control_state(
				_local_player_state(), PlayerState.ControlState.LAUNCHED, 180,
				requested_capture_movement_direction, 540_000, world.config,
			)
		var camera_origin := _camera_origin(_camera_focus_position(current_position))
		var pointer_world_position := Vector2(capture_pointer_world) if capture_pointer_world.x >= 0 else camera_origin + get_viewport().get_mouse_position() / _camera_zoom_scale()
		var command := _sample_gameplay_command(world.tick, current_position, pointer_world_position, controls_blocking)
		if not requested_capture_movement.is_empty() and not session_transport.is_connected_client():
			command = capture_movement_command(requested_capture_movement, world.tick, input_router.entity_id, requested_capture_movement_direction)
		# Capture-only casts wait for one ordinary command so the requested pointer
		# establishes continuous aim before CombatSystem snapshots cast direction.
		if (requested_capture_active_cast or requested_capture_spell_slot > 0) and not capture_active_cast_sent and world.tick >= 1 and not session_transport.is_connected_client():
			var capture_pressed := SimCommand.PRESSED_ACTIVE_1 if requested_capture_spell_slot == 0 else SimCommand.SPELL_PRESSED_BITS[requested_capture_spell_slot - 1]
			var capture_aim := Vector2(command.aim_x, command.aim_y)
			if capture_pointer_world.x >= 0:
				var requested_aim := pointer_world_position - current_position
				if requested_aim.length_squared() > 0.01:
					capture_aim = requested_aim
			command = SimCommand.new(world.tick, input_router.entity_id, 0, 0, 0, capture_pressed, roundi(capture_aim.x), roundi(capture_aim.y), roundi(pointer_world_position.x * 1000.0), roundi(pointer_world_position.y * 1000.0))
			print("FLUX2 spell capture aim: %d,%d" % [command.aim_x, command.aim_y])
			capture_active_cast_sent = true
		if (
			requested_capture_chain_spell_slot > 0
			and capture_active_cast_sent
			and not capture_chain_cast_sent
			and not session_transport.is_connected_client()
			and _local_player_state().pending_cast_wire_id != 0
		):
			var chain_pressed := SimCommand.SPELL_PRESSED_BITS[requested_capture_chain_spell_slot - 1]
			command = SimCommand.new(world.tick, input_router.entity_id, command.move_x, command.move_y, command.held_actions, chain_pressed, command.aim_x, command.aim_y, command.aim_target_x, command.aim_target_y)
			capture_chain_cast_sent = true
		if (
			capture_spell_sequence_index < requested_capture_spell_sequence.size()
			and world.tick >= 1
			and (not requested_capture_wait_for_peer or world.players.size() >= 2)
		):
			var capture_state := _local_player_state()
			var sequence_slot := int(requested_capture_spell_sequence[capture_spell_sequence_index])
			var sequence_wire := capture_state.spell_wire_id(sequence_slot)
			if (
				capture_state.pending_cast_wire_id == 0
				and capture_state.cast_recovery_ticks == 0
				and sequence_wire > 0
				and capture_state.spell_cooldown_for_wire(sequence_wire) == 0
			):
				var sequence_aim := Vector2(command.aim_x, command.aim_y)
				if capture_pointer_world.x >= 0:
					var requested_sequence_aim := pointer_world_position - current_position
					if requested_sequence_aim.length_squared() > 0.01:
						sequence_aim = requested_sequence_aim
				command = SimCommand.new(
					world.tick, input_router.entity_id,
					command.move_x, command.move_y, command.held_actions,
					SimCommand.SPELL_PRESSED_BITS[sequence_slot - 1],
					roundi(sequence_aim.x), roundi(sequence_aim.y),
					roundi(pointer_world_position.x * 1000.0), roundi(pointer_world_position.y * 1000.0),
				)
				capture_spell_sequence_index += 1
		if session_transport.is_connected_client() and requested_prediction_smoke and last_client_snapshot_tick >= 0 and prediction_smoke_inputs_sent < 18:
			command = SimCommand.new(world.tick, input_router.entity_id, 1000, 0, 0, 0, 1000, 0)
			prediction_smoke_inputs_sent += 1
		# Gallery capture uses the same modal safety as interactive selection;
		# no diagnostic movement/cast override may leak through its open panel.
		command = gallery_modal_command(command, _character_gallery_open() or not application_input_active)
		if session_transport.is_connected_client():
			if not _is_spectating():
				client_input_sequence += 1
				if not session_transport.send_input(client_input_sequence, command):
					station_notice = "Farflow input could not reach the host."
					station_notice_seconds = 1.0
				if client_prediction.queue_input(client_input_sequence, command):
					current_position = client_prediction.presented_position_pixels()
			if (
				requested_prediction_smoke
				and prediction_smoke_started
				and not prediction_smoke_reported
				and client_prediction.last_acknowledged_sequence >= 1
				and client_prediction.last_authoritative_position_pixels.x > prediction_smoke_start_x + 4.0
			):
				prediction_smoke_reported = true
				print("FLUX2 farflow prediction smoke: authoritative movement confirmed at sequence %d" % client_prediction.last_acknowledged_sequence)
		else:
			var commands: Array[SimCommand] = [command]
			if interception_practice_active:
				var practice_command := InterceptionPractice.command_for_tick(world.tick, int(interception_practice_setup.start_tick), world.player(2), world.player(1), interception_practice_setup.opponent_profile.slots)
				if practice_command != null:
					commands.append(practice_command)
			if session_transport.is_host():
				commands = authoritative_session.commands_for_tick(command)
			if not world.step(commands):
				push_error(world.last_error)
				set_process(false)
				break
			if session_transport.is_host() and authoritative_session.practice_countdown_completed():
				if _begin_shared_practice():
					queue_redraw()
					return
				push_error("Shared practice could not begin")
				set_process(false)
				return
			if session_transport.is_host():
				var round_events := authoritative_session.advance_round(world.combat_events)
				_ingest_session_feedback(round_events)
				_update_steward_smoke()
				if authoritative_session.round_return_due():
					if _return_to_hearth():
						queue_redraw()
						return
					push_error("Shared round could not return to the Hearth")
					set_process(false)
					return
			_ingest_combat_cues(world.combat_events)
			if not requested_capture_spell_sequence.is_empty():
				for capture_event: Dictionary in world.combat_events:
					if String(capture_event.get("type", "")) == "chemistry_formed":
						print("FLUX2 paid chemistry capture: tick %d %s" % [world.tick, JSON.stringify(capture_event)])
			if (requested_capture_active_cast or requested_capture_spell_slot > 0) and not world.combat_events.is_empty():
				print(
					"FLUX2 spell capture: tick %d pending %d/%d projectiles %d fields %d events %s"
					% [
						world.tick,
						_local_player_state().pending_cast_wire_id,
						_local_player_state().pending_cast_ticks,
						world.projectiles.size(),
						world.fields.size(),
						JSON.stringify(world.combat_events),
					]
				)
			if session_transport.is_host() and world.tick % snapshot_tick_interval(tick_rate) == 0:
				authoritative_session.record_combat_events(world.combat_events)
				var snapshot_sent := session_transport.broadcast_snapshot(authoritative_session.capture_snapshot())
				_send_host_reconciliations()
				if snapshot_sent:
					authoritative_session.acknowledge_snapshot()
			elif session_transport.is_host():
				authoritative_session.record_combat_events(world.combat_events)
			current_position = _player_position()
		if not session_transport.is_connected_client():
			actor_motion_history.capture(world.players)
		movement_trace.record(world.tick, current_position, command, _local_player_state().champion_wire_id, _local_player_state())
		accumulator_seconds -= fixed_delta
		steps += 1
	if accumulator_seconds >= fixed_delta:
		dropped_time_seconds += accumulator_seconds - fmod(accumulator_seconds, fixed_delta)
		accumulator_seconds = fmod(accumulator_seconds, fixed_delta)
	_prepare_active_character_pages()
	_update_character_gaits(delta)
	queue_redraw()


func _update_character_gaits(delta: float) -> void:
	if world == null or cartoon_champion_presenter == null:
		return
	var alpha := clampf(accumulator_seconds * float(tick_rate), 0.0, 1.0)
	var remote_alpha := clampf(remote_snapshot_age_seconds * 60.0 if session_transport.is_connected_client() else accumulator_seconds * float(tick_rate), 0.0, 1.0)
	var local := _local_player_state()
	var states: Array[PlayerState] = []
	var points: Dictionary = {}
	var heights: Dictionary = {}
	var predicted_motion: Dictionary = {}
	for actor: PlayerState in world.players:
		if actor.actor_kind != PlayerState.ActorKind.CHAMPION:
			continue
		if local != null and actor.entity_id == local.entity_id:
			if session_transport.is_connected_client() and client_prediction.is_ready():
				predicted_motion[actor.entity_id] = client_prediction.predicted_state
				# The visual correction tail is not locomotion. The sprite may
				# ease back to authority without inventing or suppressing steps.
				points[actor.entity_id] = previous_prediction_position.lerp(client_prediction.raw_position_pixels(), alpha)
			else:
				points[actor.entity_id] = previous_position.lerp(current_position, alpha)
		else:
			var point: Vector3 = actor_motion_history.sample(actor, remote_alpha)
			points[actor.entity_id] = Vector2(point.x, point.y)
		states.append(actor)
		var champion_id := champion_catalog.champion_id_from_wire(actor.champion_wire_id)
		heights[actor.entity_id] = float(cartoon_champion_presenter.champions.get(champion_id, {}).get("height", 68.0))
	actor_motion_history.capture_gaits(states, points, heights, delta, predicted_motion)


func _prepare_active_character_pages() -> bool:
	if world == null or champion_catalog == null or cartoon_champion_presenter == null:
		return true
	var active_ids: Array[String] = []
	for actor: PlayerState in world.players:
		if actor.actor_kind != PlayerState.ActorKind.CHAMPION:
			continue
		var champion_id := champion_catalog.champion_id_from_wire(actor.champion_wire_id)
		if not champion_id.is_empty() and champion_id not in active_ids:
			active_ids.append(champion_id)
	active_ids.sort()
	var key := "%d/%d/%s" % [cartoon_champion_presenter.get_instance_id(), cartoon_champion_presenter.configuration_generation, ",".join(active_ids)]
	if key == _character_page_preparation_key:
		return _character_pages_ready
	_character_page_preparation_key = key
	_character_pages_ready = cartoon_champion_presenter.prepare_override_pages(active_ids)
	_character_page_preparation_error = "" if _character_pages_ready else cartoon_champion_presenter.last_error
	if not _character_pages_ready:
		# Keep the verified old set/fallback and shared simulation running. Do not
		# retry disk I/O each frame after a failure; identity/reload changes retry.
		station_notice = "Character art could not be prepared; retaining verified fallback. " + _character_page_preparation_error
		station_notice_seconds = 8.0
	return _character_pages_ready


func _champion_visual_id(authority: PlayerState) -> String:
	return champion_catalog.champion_id_from_wire(authority.champion_wire_id) if authority != null and champion_catalog != null else ""


func _send_host_reconciliations() -> void:
	for roster_entry: Dictionary in session_transport.host_roster():
		var peer_id := int(roster_entry.get("peer_id", 0))
		var entity_id := int(roster_entry.get("entity_id", 0))
		if authoritative_session.input_locked(entity_id):
			continue
		var reconciliation := authoritative_session.capture_reconciliation(entity_id)
		if reconciliation.is_empty() or not session_transport.send_reconciliation(peer_id, reconciliation):
			push_warning("Farflow could not send reconciliation for entity %d" % entity_id)


func _draw() -> void:
	if world == null:
		return
	var alpha: float = clampf(accumulator_seconds * float(tick_rate), 0.0, 1.0)
	var rendered_position: Vector2 = previous_position.lerp(current_position, alpha)
	var camera_focus_position := _camera_focus_position(rendered_position)
	var camera_origin: Vector2 = _camera_origin(camera_focus_position)
	var visual_tick := MinimalChampionMotion.tick_at_visual_rate(world.tick, tick_rate, alpha)
	PixelMagicLibrary.default_library().begin_frame(_reduced_effects_enabled())
	if world.hex_court != null:
		draw_rect(get_viewport_rect(), Color("25331f"))
	_set_world_transform(camera_origin)
	if world.hex_court != null:
		hex_court_presenter.draw_ground(self, world.hex_court, float(world.tick) + alpha, _reduced_effects_enabled())
	else:
		campus_renderer.draw(self, campus_layout, roundi(visual_tick), camera_focus_position, _reduced_effects_enabled())
	foundation_spell_presenter.begin_frame(world.config, world.collision)
	movement_trace.draw(self, rendered_position, _reduced_effects_enabled())
	if show_debug_overlay:
		for obstacle: CollisionWorld.Obstacle in world.collision.obstacle_view():
			var rectangle := Rect2(
				Vector2(float(obstacle.minimum_x) / 1000.0, float(obstacle.minimum_y) / 1000.0),
				Vector2(float(obstacle.maximum_x - obstacle.minimum_x) / 1000.0, float(obstacle.maximum_y - obstacle.minimum_y) / 1000.0),
			)
			draw_rect(rectangle, Color(BRASS_COLOR if obstacle.vaultable else ATTUNEMENT_COLOR, 0.18), true)
			draw_rect(rectangle, BRASS_COLOR if obstacle.vaultable else ATTUNEMENT_COLOR, false, 2.0)
	for field: FieldState in world.fields:
		_draw_field(field)
	_draw_element_chemistry(float(world.tick) + alpha, camera_origin)
	for projectile: ProjectileState in world.projectiles:
		var projectile_position := ProjectilePresentationMotion.interpolated_position(projectile, alpha)
		var projectile_color: Color = _projectile_color(projectile.element_wire_id)
		_draw_projectile(projectile, projectile_position, projectile_color, alpha)
	_draw_practice_targets(camera_origin)
	_draw_combat_cues(camera_origin)
	var state: PlayerState = _local_player_state()
	if state == null:
		return
	var spectating := _is_spectating()
	var observed_state: PlayerState = _spectator_state() if spectating else state
	if observed_state == null:
		observed_state = state
	_draw_remote_travellers(camera_origin, state.entity_id, visual_tick)
	var presentation_state: PlayerState = client_prediction.predicted_state if session_transport.is_connected_client() and client_prediction.is_ready() else state
	var presentation := JumpPresentation.sample(presentation_state, world.config, alpha, _reduced_effects_enabled(), previous_air_height)
	var landing := LandingPresentation.sample(presentation_state, world.config, alpha, _reduced_effects_enabled())
	var player_radius: float = float(MovementTuning.PLAYER_RADIUS) / 1000.0
	var shadow_center := rendered_position + Vector2(0.0, player_radius * 0.58)
	if campus_renderer.natural_kit != null and world.hex_court == null:
		campus_renderer.natural_kit.draw_actor_contact(self, campus_layout, presentation_state, shadow_center, roundi(visual_tick), _reduced_effects_enabled())
	var shadow_scale: Vector2 = landing.shadow_scale if landing.active else presentation.shadow_scale
	_draw_receiving_surface_shadow(
		shadow_center,
		Vector2(player_radius * shadow_scale.x, player_radius * shadow_scale.y),
		presentation.shadow_opacity,
		camera_origin,
	)
	if landing.active:
		_draw_landing_cue(shadow_center, landing)
	var body_position := rendered_position + Vector2(0.0, -float(presentation.body_lift_pixels))
	var sprite_drawn: bool = false
	# Movement prediction has no champion identity field; world art and HUD must
	# resolve the same authoritative identity while motion stays immediate.
	var presentation_champion_id := _champion_visual_id(state)
	var sprite_anchor := shadow_center + Vector2(0.0, -float(presentation.body_lift_pixels))
	if cartoon_champion_presenter != null:
		sprite_drawn = cartoon_champion_presenter.draw(
			self,
			presentation_state,
			presentation_champion_id,
			sprite_anchor,
			visual_tick,
			world.config,
			_reduced_effects_enabled(),
			shadow_center,
			actor_motion_history.gait_phase(presentation_state.entity_id),
		)
	if not sprite_drawn:
		draw_circle(body_position, player_radius + 5.0, Color(ATTUNEMENT_COLOR, 0.18))
		draw_circle(body_position, player_radius, PLAYER_COLOR)
		draw_arc(body_position, player_radius + 2.0, 0.0, TAU, 24, PARCHMENT_COLOR, 2.0)
	if show_debug_overlay:
		_draw_actor_hitbox_diagnostic(body_position, float(presentation_state.radius) / 1000.0, presentation_champion_id)
	_draw_spell_startup(presentation_state, sprite_anchor, roundi(visual_tick))
	if state.spawn_protection_ticks > 0:
		var protection_ratio := clampf(float(state.spawn_protection_ticks) / float(maxi(1, world.config.milliseconds_to_ticks(1200))), 0.0, 1.0)
		draw_arc(body_position, player_radius + 9.0, 0.0, TAU, 28, Color(ATTUNEMENT_COLOR, 0.32 + protection_ratio * 0.42), 2.0)
	_draw_social_bubbles(camera_origin)
	_draw_station_bubble(camera_origin)
	draw_set_transform(Vector2.ZERO)
	var pov_position := _pov_observer_ground_position(observed_state, spectating, rendered_position)
	var pov_aim_state := observed_state if spectating else presentation_state
	_draw_pov_mask((pov_position - camera_origin) * _camera_zoom_scale(), Vector2(CartoonChampionPresenter.presentation_facing_vector(pov_aim_state)), camera_origin)
	_draw_pov_observer_body(camera_origin, visual_tick, alpha)
	if not spectating and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		var aim_direction := Vector2(presentation_state.aim_x, presentation_state.aim_y).normalized()
		var reticle_position := get_viewport().get_mouse_position()
		if capture_pointer_world.x >= 0:
			reticle_position = (Vector2(capture_pointer_world) - camera_origin) * _camera_zoom_scale()
		if input_router.is_controller_aim_active():
			reticle_position = (rendered_position + aim_direction * 320.0 - camera_origin) * _camera_zoom_scale()
		AimReticlePresenter.draw(self, reticle_position, aim_direction)
	var observed_champion_id := _champion_visual_id(observed_state)
	var champion_data: Dictionary = champion_catalog.champion(observed_champion_id)
	var champion_name := String(champion_data.get("display_name", observed_champion_id))
	var location_name := "PROVING COURT" if int(_current_round_state().get("phase", SessionRound.Phase.HEARTH)) != SessionRound.Phase.HEARTH else "THE WELLSPRING"
	if world.hex_court != null:
		location_name = "HEX CHEMISTRY COURT"
	_draw_station_notice(location_name)
	var active_layer: int = 2 if Input.is_action_pressed(InputRouter.SPELL_ALT_LAYER_ACTION) else (1 if Input.is_action_pressed(InputRouter.SPELL_CTRL_LAYER_ACTION) else 0)
	if compact_hud != null:
		var ui_scale := _ui_scale()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ui_scale)
		compact_hud.draw(
			self,
			get_viewport_rect().size / ui_scale,
			observed_state,
			ability_catalog,
			observed_champion_id,
			champion_name,
			location_name,
			_session_label(),
			active_layer,
			world.config.tick_rate,
			spectating,
			world.available_cast_offer(observed_state.entity_id),
			world.transition_policy.cast_gate_reason(observed_state),
			get_viewport().get_mouse_position() / ui_scale,
			_session_feedback_label(),
		)
		draw_set_transform(Vector2.ZERO)
	if show_debug_overlay and (dropped_time_seconds > 0.0 or clamped_frame_time_seconds > 0.0):
		draw_string(ThemeDB.fallback_font, Vector2(32, 132), "FRAME CLAMP %.3fs / CATCH-UP DROPPED %.3fs" % [clamped_frame_time_seconds, dropped_time_seconds], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, FIRE_COLOR)
	if show_debug_overlay:
		_draw_material_yard_preview()
	_draw_practice_coach()
	if player_compendium != null and not player_compendium.is_open and not controls_editor.is_open and not spell_loom_editor.is_open and not join_address_editor_open and not _character_gallery_open():
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _ui_scale())
		draw_string(ThemeDB.fallback_font, Vector2(20, 68), "F4 / Back  COMPENDIUM", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, PARCHMENT_COLOR)
		draw_set_transform(Vector2.ZERO)
	if controls_editor != null and controls_editor.is_open:
		var controls_ui_scale := _ui_scale()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * controls_ui_scale)
		_draw_controls_editor()
		draw_set_transform(Vector2.ZERO)
	elif spell_loom_editor != null and spell_loom_editor.is_open:
		var loom_ui_scale := _ui_scale()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * loom_ui_scale)
		_draw_spell_loom_editor()
		draw_set_transform(Vector2.ZERO)
	if show_visual_specimen:
		VisualSpecimen.draw(self, visual_language, get_viewport_rect().size, world.tick)
	if player_compendium != null and player_compendium.is_open:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _compendium_scale())
		player_compendium.draw(self, ThemeDB.fallback_font)
		draw_set_transform(Vector2.ZERO)
	if _character_gallery_open():
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _compendium_scale())
		character_selection_grid.draw(self, ThemeDB.fallback_font)
		draw_set_transform(Vector2.ZERO)


func _free_practice_actor() -> PlayerState:
	var state := _local_player_state()
	if world == null or state == null or campus_layout == null or state.health <= 0:
		return null
	# The general HUD can fall back to the host while a guest snapshot arrives;
	# personal practice feedback must never attribute that fallback to the guest.
	if session_transport != null and session_transport.is_connected_client():
		if session_transport.local_entity_id <= 0 or state.entity_id != session_transport.local_entity_id:
			return null
	var allowed := not _gameplay_input_blocked() and not _is_spectating() and not show_visual_specimen
	allowed = allowed and int(_current_round_state().get("phase", SessionRound.Phase.HEARTH)) == SessionRound.Phase.HEARTH
	return state if allowed else null


func _chemistry_practice_view() -> Dictionary:
	var state := _free_practice_actor()
	if state == null:
		return {}
	var group: Dictionary = campus_layout.practice_groups_by_id.get("crucible-experiment", {})
	return ChemistryCoach.sample(state.entity_id, Vector2i(state.position_x, state.position_y),
		world.tick, world.config, group.get("bounds", []), world.deposits, world.reactions)


func _movement_practice_view() -> Dictionary:
	var state := _free_practice_actor()
	if state == null or player_preferences == null:
		return {}
	for activity: Dictionary in campus_layout.data.get("activity_areas", []):
		if String(activity.get("id", "")) == "south-movement-loop":
			return MovementCoach.sample(state, player_preferences,
				SanctumCampusLayout._parse_bounds(activity.get("bounds", [])), movement_practice_device)
	return {}


func _draw_practice_coach() -> void:
	var trial_scale := _ui_scale()
	if world.hex_court != null:
		_draw_hex_court_help()
		return
	if not _gameplay_input_blocked() and session_transport.mode == SessionTransport.Mode.OFFLINE:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * trial_scale)
		draw_rect(INTERCEPTION_START_RECT, PANEL_COLOR)
		draw_string(ThemeDB.fallback_font, INTERCEPTION_START_RECT.position + Vector2(10, 20), "RETRY 72s ENCOUNTER" if interception_practice_active else "PLAY 72s INTERCEPTION TRIAL", HORIZONTAL_ALIGNMENT_LEFT, 208, 12, PARCHMENT_COLOR)
		draw_rect(HEX_START_RECT, PANEL_COLOR)
		draw_string(ThemeDB.fallback_font, HEX_START_RECT.position + Vector2(10, 20), "ENTER HEX CHEMISTRY COURT", HORIZONTAL_ALIGNMENT_LEFT, 208, 12, PARCHMENT_COLOR)
		if interception_practice_active:
			draw_rect(INTERCEPTION_LEAVE_RECT, PANEL_COLOR)
			draw_string(ThemeDB.fallback_font, INTERCEPTION_LEAVE_RECT.position + Vector2(10, 20), "RETURN TO WELLSPRING", HORIZONTAL_ALIGNMENT_LEFT, 208, 12, PARCHMENT_COLOR)
		draw_set_transform(Vector2.ZERO)
	var view := InterceptionPracticeCard.view(world.tick, int(interception_practice_setup.start_tick), interception_practice_setup.player_profile, interception_practice_setup.opponent_profile) if interception_practice_active else _chemistry_practice_view()
	if interception_practice_active and world.player().health <= 0:
		view.title = "TRY ANOTHER APPROACH"
		view.lines = PackedStringArray(["Retry the encounter. Intercept small shots; evade large ones."])
	if view.is_empty():
		view = _movement_practice_view()
	if view.is_empty():
		return
	var scale_factor := _ui_scale()
	var viewport_size := get_viewport_rect().size / scale_factor
	var card := PracticeCoachCard.model(view, viewport_size, get_viewport().get_mouse_position() / scale_factor)
	if card.is_empty():
		return
	var lines: PackedStringArray = card.lines
	var panel: Rect2 = card.panel
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_factor)
	draw_rect(panel, Color("111b20c8"), true)
	draw_rect(Rect2(panel.position, Vector2(3.0, panel.size.y)), ATTUNEMENT_COLOR, true)
	var left := panel.position + Vector2(14.0, 23.0)
	var text_width := panel.size.x - 28.0
	draw_string(ThemeDB.fallback_font, left, String(view.title), HORIZONTAL_ALIGNMENT_LEFT, text_width if bool(card.expanded) else text_width - 75.0, 14, PARCHMENT_COLOR)
	var phase_label := "PHASE %ds · ENCOUNTER %ds" % [ceili(float(view.remaining_ticks) / tick_rate), ceili(float(view.total_remaining_ticks) / tick_rate)] if interception_practice_active else String(view.phase)
	draw_string(ThemeDB.fallback_font, left + Vector2(0, 18), phase_label, HORIZONTAL_ALIGNMENT_LEFT, text_width, 11, ATTUNEMENT_COLOR)
	for index: int in range(lines.size()):
		draw_string(ThemeDB.fallback_font, left + Vector2(0, 43 + index * 18), lines[index], HORIZONTAL_ALIGNMENT_LEFT, text_width, 12, PALE_STONE_COLOR)
	if not bool(card.expanded):
		draw_string(ThemeDB.fallback_font, panel.position + Vector2(panel.size.x - 83, 18), "HOVER / F4", HORIZONTAL_ALIGNMENT_RIGHT, 69, 9, PALE_STONE_COLOR)
	draw_set_transform(Vector2.ZERO)


func _draw_controls_editor() -> void:
	var panel := ControlBindingEditor.PANEL_RECT
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color("060907a8"), true)
	draw_rect(panel, Color(PANEL_COLOR, 0.97), true)
	draw_rect(panel, Color(BRASS_COLOR, 0.92), false, 3.0)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(38, 42), "CONTROLS LECTERN", HORIZONTAL_ALIGNMENT_LEFT, 500.0, 25, PARCHMENT_COLOR)
	draw_string(ThemeDB.fallback_font, Vector2(846, 165), "SOUND %d%%" % player_preferences.sound_volume_percent, HORIZONTAL_ALIGNMENT_LEFT, 110, 12, ATTUNEMENT_COLOR)
	for button: Rect2 in [SOUND_DOWN_RECT, SOUND_UP_RECT, SOUND_MUTE_RECT]:
		draw_rect(button, Color("26352fe6"), true)
		draw_rect(button, Color(BRASS_COLOR, 0.6), false, 1.0)
		var label := "-" if button == SOUND_DOWN_RECT else ("+" if button == SOUND_UP_RECT else ("UNMUTE" if player_preferences.sound_volume_percent == 0 else "MUTE"))
		draw_string(ThemeDB.fallback_font, button.position + Vector2(5, 20), label, HORIZONTAL_ALIGNMENT_CENTER, button.size.x - 10.0, 11, PARCHMENT_COLOR)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(38, 68), "Bindings stay on this device and are saved immediately.", HORIZONTAL_ALIGNMENT_LEFT, 800.0, 14, PALE_STONE_COLOR)
	draw_string(
		ThemeDB.fallback_font,
		panel.position + Vector2(500, 68),
		"FX %s · CONTRAST %s" % ["REDUCED" if _reduced_effects_enabled() else "FULL", "HIGH" if visual_accessibility_filter.current_profile_id == "high_contrast" else "STANDARD"],
		HORIZONTAL_ALIGNMENT_RIGHT,
		280.0,
		12,
		ATTUNEMENT_COLOR,
	)
	var visible_indices: Array[int] = controls_editor.visible_action_indices()
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(840, 68), "ACTIONS %d–%d / %d" % [visible_indices.front() + 1, visible_indices.back() + 1, ControlBindingEditor.ACTIONS.size()], HORIZONTAL_ALIGNMENT_RIGHT, 160.0, 12, ATTUNEMENT_COLOR)
	for device: int in range(ControlBindingEditor.DEVICE_COUNT):
		var column_x: float = ControlBindingEditor.DEVICE_X + float(device) * ControlBindingEditor.DEVICE_WIDTH
		draw_string(ThemeDB.fallback_font, Vector2(column_x + 12, 205), ControlBindingEditor.DEVICE_LABELS[device], HORIZONTAL_ALIGNMENT_LEFT, ControlBindingEditor.DEVICE_WIDTH - 24.0, 13, ATTUNEMENT_COLOR)
	for display_row: int in range(visible_indices.size()):
		var row: int = visible_indices[display_row]
		var action: StringName = ControlBindingEditor.ACTIONS[row]
		var y: float = ControlBindingEditor.FIRST_ROW_Y + float(display_row) * ControlBindingEditor.ROW_HEIGHT
		if row % 2 == 0:
			draw_rect(Rect2(142, y, 996, ControlBindingEditor.ROW_HEIGHT - 2.0), Color(PARCHMENT_COLOR, 0.035), true)
		draw_string(ThemeDB.fallback_font, Vector2(ControlBindingEditor.ACTION_X, y + 21), ControlBindingEditor.ACTION_LABELS[action], HORIZONTAL_ALIGNMENT_LEFT, ControlBindingEditor.ACTION_WIDTH, 13, PARCHMENT_COLOR)
		for device: int in range(ControlBindingEditor.DEVICE_COUNT):
			var cell := Rect2(ControlBindingEditor.DEVICE_X + float(device) * ControlBindingEditor.DEVICE_WIDTH, y, ControlBindingEditor.DEVICE_WIDTH - 8.0, ControlBindingEditor.ROW_HEIGHT - 3.0)
			var selected: bool = row == controls_editor.selected_action_index and device == controls_editor.selected_device
			if selected:
				draw_rect(cell, Color(ATTUNEMENT_COLOR, 0.16 if not controls_editor.capturing else 0.27), true)
				draw_rect(cell, ATTUNEMENT_COLOR, false, 2.0)
			var binding := controls_editor.binding_label(action, device, player_preferences)
			draw_string(ThemeDB.fallback_font, cell.position + Vector2(10, 20), binding, HORIZONTAL_ALIGNMENT_LEFT, cell.size.x - 20.0, 12, Color.WHITE if selected else PALE_STONE_COLOR)
	var footer_y := panel.end.y - 64.0
	draw_line(Vector2(panel.position.x + 28, footer_y - 18), Vector2(panel.end.x - 28, footer_y - 18), Color(BRASS_COLOR, 0.5), 1.0)
	var selected_notice := controls_editor.selected_migration_notice()
	var footer_notice: String = selected_notice if not controls_editor.capturing and not selected_notice.is_empty() else controls_editor.status_message
	draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 38, footer_y), footer_notice, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 76.0, 13, ATTUNEMENT_COLOR if controls_editor.capturing else PARCHMENT_COLOR)
	var help := "PRESS THE CHOSEN INPUT · ESC / BACK CANCELS" if controls_editor.capturing else "ARROWS / DPAD SELECT · ENTER / A BIND · M / L3 EFFECTS · H / R3 CONTRAST · ESC / B CLOSE"
	draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 38, footer_y + 27), help, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 76.0, 12, PALE_STONE_COLOR)
	if not controls_editor.capturing:
		draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 38, footer_y + 45), "SOUND: [ / ] or LB / RB adjust  |  0 / START mute  |  Click header buttons", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 76.0, 11, PALE_STONE_COLOR)


func _draw_spell_loom_editor() -> void:
	SpellLoomPresenter.draw_panel(self, spell_loom_editor, _local_player_state(), ability_catalog, visual_language)


func _ingest_combat_cues(events: Array[Dictionary]) -> void:
	for event: Dictionary in events:
		# The optional cone mask has no shared point-visibility query. Keep
		# contact labels local and fail closed under that mask, as audio does.
		if String(event.get("type", "")) == "spray_intercepted" and player_preferences != null and player_preferences.pov_mode != PlayerPreferences.POV_CONE:
			var contact_point := Vector2(int(event.get("x", 0)), int(event.get("y", 0))) / 1000.0
			var contact_view := Rect2(_camera_origin(_camera_focus_position(current_position)), get_viewport_rect().size / _camera_zoom_scale())
			if contact_view.has_point(contact_point):
				interception_feedback.ingest(event, ability_catalog)
		_ingest_element_audio(event)
		_ingest_magic_release(event)
		var kind := String(event.get("type", ""))
		if kind == "hex_clash" and world.hex_court != null:
			var clash := event.duplicate(true)
			clash.event_type = kind
			clash.position = Vector2(int(event.get("x", 0)), int(event.get("y", 0))) / 1000.0
			clash.remaining = 0.15
			clash.duration = 0.15
			clash.label = ""
			combat_cues.append(clash)
			continue
		if kind not in ["projectile_hit", "beam_fired", "spray_fired", "spray_hit", "field_triggered", "edgeweave", "cast_refused", "cast_blocked", "projectile_bounced"]:
			continue
		var anchor := _combat_event_anchor(event)
		if anchor.is_empty():
			continue
		var feedback := preload("res://src/presentation/combat_feedback_model.gd").describe(event, ability_catalog)
		var label := String(feedback.get("label", ""))
		var element := String(feedback.get("element", ""))
		var color: Color = visual_language.element_color(element, "bright") if visual_language != null and visual_language.elements.has(element) else PARCHMENT_COLOR
		match kind:
			"edgeweave":
				label = "EDGE +%d" % (int(event.get("stamina", 0)) / 1000)
				color = ATTUNEMENT_COLOR
			"cast_refused":
				var refusal_reason := String(event.get("reason", ""))
				if refusal_reason == "flux":
					label = "NO FLUX"
				elif refusal_reason == "empty_slot":
					label = "SLOT %d EMPTY" % int(event.get("slot", 0))
				elif refusal_reason == "cooldown":
					label = "COOLDOWN"
				elif refusal_reason == "capacity":
					label = "SPELL LIMIT · LET ONE FADE"
				elif refusal_reason == "hex_capacity":
					label = "COURT FULL · LET MATTER FADE"
				elif refusal_reason == "hex_water_fire_only":
					label = "THIS COURT: WATER + FIRE"
				elif refusal_reason == "startup_commitment":
					label = "FINISH WEAVE"
				elif refusal_reason.begins_with("control_"):
					label = "NO CAST · %s" % refusal_reason.trim_prefix("control_").to_upper()
				else:
					label = "CAST REFUSED"
				color = FLUX_COLOR
			"cast_blocked":
				label = "BLOCKED"
				color = PALE_STONE_COLOR
			"projectile_bounced":
				label = "RICOCHET"
				color = PARCHMENT_COLOR
		var cue: Dictionary = {
			"position": anchor["position"],
			"label": label,
			"color": color,
			"event_type": kind,
			"source_wire_id": int(event.get("source_wire_id", event.get("wire_id", 0))),
			"remaining": 0.20 if kind in ["beam_fired", "spray_fired"] else 0.55,
			"duration": 0.20 if kind in ["beam_fired", "spray_fired"] else 0.55,
		}
		if kind == "beam_fired":
			var owner: PlayerState = world.player(int(event.get("owner_id", 0)))
			cue["kind"] = "beam"
			cue["start"] = Vector2(float(owner.position_x) / 1000.0, float(owner.position_y) / 1000.0) if owner != null else anchor["position"]
			if event.has("origin_x") and event.has("origin_y"):
				cue["start"] = Vector2(float(event["origin_x"]), float(event["origin_y"])) / 1000.0
			cue["end"] = anchor["position"]
		elif kind == "spray_fired":
			var spray_owner: PlayerState = world.player(int(event.get("owner_id", 0)))
			cue["kind"] = "spray"
			cue["range"] = int(event.get("range", -1))
			cue["start"] = Vector2(float(spray_owner.position_x) / 1000.0, float(spray_owner.position_y) / 1000.0) if spray_owner != null else anchor["position"]
			cue["end"] = anchor["position"]
		combat_cues.append(cue)
	while combat_cues.size() > 24:
		combat_cues.pop_front()


func _ingest_element_audio(event: Dictionary) -> void:
	if element_audio == null or element_audio.volume_percent <= 0 or world == null or _gameplay_input_blocked() or _is_spectating():
		return
	var actor := _local_player_state()
	if actor == null or actor.health <= 0:
		return
	if session_transport != null and session_transport.is_connected_client() and actor.entity_id != session_transport.local_entity_id:
		return
	# Reject irrelevant/remote events before the more expensive visibility check.
	if ElementAudioScript.describe(event, actor.entity_id, ability_catalog).is_empty():
		return
	if String(event.get("type", "")) == "spray_intercepted":
		if player_preferences == null or player_preferences.pov_mode == PlayerPreferences.POV_CONE:
			return
		var contact_point := Vector2(int(event.get("x", 0)), int(event.get("y", 0))) / 1000.0
		var contact_view := Rect2(_camera_origin(_camera_focus_position(current_position)), get_viewport_rect().size / _camera_zoom_scale())
		if not contact_view.has_point(contact_point):
			return
	elif String(event.get("type", "")) != "cast_started":
		# The optional cone/building mask has no shared point-visibility query.
		# Fail closed until exact presentation-mask parity is available.
		if player_preferences == null or player_preferences.pov_mode == PlayerPreferences.POV_CONE:
			return
		var target := world.player(int(event.get("target_id", 0)))
		if target == null or not _chemistry_actor_visible(target):
			return # No extra information about concealed or absent targets.
		var target_position := Vector2(target.position_x, target.position_y) / SimConfig.FIXED_SCALE
		var visible_world := Rect2(_camera_origin(_camera_focus_position(current_position)), get_viewport_rect().size / _camera_zoom_scale())
		if not visible_world.has_point(target_position):
			return # Off-screen hits do not become an extra source of information.
	element_audio.ingest(event, world.tick, actor.entity_id, ability_catalog, true)


func _ingest_magic_release(event: Dictionary) -> void:
	# Field snapshots already carry exact remaining lifetime on host and guest;
	# their short release cue is drawn from that state instead of an absent RPC.
	if String(event.get("type", "")) == "field_spawned":
		return
	var admission := PixelSpellEffects.accepted_release(event)
	if admission.is_empty():
		return
	var actor := world.player(int(admission.owner_id))
	if actor == null or not _chemistry_actor_visible(actor):
		return
	var key := "%d:%s" % [world.tick, String(admission.dedup_key)]
	for existing: Dictionary in combat_cues:
		if String(existing.get("release_key", "")) == key:
			return
	var lift := JumpPresentation.sample(actor, world.config, 0.0, _reduced_effects_enabled())
	var body := Vector2(actor.position_x, actor.position_y) / 1000.0 - Vector2(0.0, float(lift.body_lift_pixels))
	body.y += float(MovementTuning.PLAYER_RADIUS) / 1000.0 * 0.58
	combat_cues.append({
		"kind": "pixel_release", "release_key": key,
		"source_wire_id": int(admission.wire_id),
		"position": CartoonChampionPresenter.hand_cast_origin(body, Vector2(actor.aim_x, actor.aim_y)),
		"remaining": 0.20, "duration": 0.20,
	})


func _combat_event_anchor(event: Dictionary) -> Dictionary:
	if event.get("contact_position") is Vector2i:
		return {"position": Vector2(event.contact_position) / 1000.0}
	var kind := String(event.get("type", ""))
	if kind == "beam_fired":
		return {"position": Vector2(float(event.get("end_x", 0)) / 1000.0, float(event.get("end_y", 0)) / 1000.0)}
	if kind == "spray_fired":
		return {"position": Vector2(float(event.get("end_x", 0)) / 1000.0, float(event.get("end_y", 0)) / 1000.0)}
	var entity_id: int = 0
	if kind in ["projectile_hit", "spray_hit", "field_triggered"]:
		entity_id = int(event.get("target_id", 0))
	elif kind in ["edgeweave", "cast_refused", "cast_blocked"]:
		entity_id = int(event.get("entity_id", 0))
	if entity_id > 0:
		var state: PlayerState = world.player(entity_id)
		if state != null:
			return {"position": Vector2(float(state.position_x) / 1000.0, float(state.position_y) / 1000.0)}
	var projectile_id := int(event.get("projectile_id", 0))
	for projectile: ProjectileState in world.projectiles:
		if projectile.entity_id == projectile_id:
			return {"position": Vector2(float(projectile.position_x) / 1000.0, float(projectile.position_y) / 1000.0)}
	return {}


func _update_combat_cues(delta: float) -> void:
	for index: int in range(combat_cues.size() - 1, -1, -1):
		var cue: Dictionary = combat_cues[index]
		cue["remaining"] = float(cue.get("remaining", 0.0)) - delta
		if float(cue["remaining"]) <= 0.0:
			combat_cues.remove_at(index)
		else:
			combat_cues[index] = cue


func _draw_combat_cues(camera_origin: Vector2) -> void:
	_set_world_transform(camera_origin)
	interception_feedback.draw(self, visual_language, _reduced_effects_enabled())
	for cue: Dictionary in combat_cues:
		var remaining := float(cue.get("remaining", 0.0))
		var duration := maxf(0.001, float(cue.get("duration", 0.55)))
		cue["age_ticks"] = maxi(0, roundi((duration - remaining) * float(tick_rate)))
		if world.hex_court != null:
			hex_court_presenter.draw_cue(self, cue, _reduced_effects_enabled())
			var court_label := String(cue.get("label", ""))
			if not court_label.is_empty():
				draw_string(ThemeDB.fallback_font, (cue.position as Vector2) + Vector2(-30, -30), court_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, cue.get("color", PARCHMENT_COLOR))
			continue
		if String(cue.get("kind", "")) == "pixel_release":
			foundation_spell_presenter.draw_release(self, int(cue.source_wire_id), cue.position, int(cue.age_ticks), _reduced_effects_enabled())
			continue
		var phase := clampf(1.0 - remaining / duration, 0.0, 1.0)
		var position: Vector2 = cue.get("position", Vector2.ZERO)
		var color: Color = cue.get("color", ATTUNEMENT_COLOR)
		var opacity := 1.0 - phase
		if foundation_spell_presenter != null and foundation_spell_presenter.draw_cue(self, cue, phase, _reduced_effects_enabled()):
			var spell_label := String(cue.get("label", ""))
			if not spell_label.is_empty():
				var spell_label_width := ThemeDB.fallback_font.get_string_size(spell_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
				var label_lift := 48.0 if String(cue.get("event_type", "")) in ["projectile_hit", "spray_hit", "field_triggered"] else 24.0
				draw_string(ThemeDB.fallback_font, position + Vector2(-spell_label_width * 0.5, -label_lift - phase * 16.0), spell_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(color, opacity))
			continue
		if String(cue.get("kind", "")) == "beam":
			var start: Vector2 = cue.get("start", position)
			var endpoint: Vector2 = cue.get("end", position)
			draw_line(start, endpoint, Color(color, opacity * 0.18), 12.0)
			draw_line(start, endpoint, Color(color, opacity * 0.78), 4.0)
			draw_line(start, endpoint, Color(Color.WHITE, opacity * 0.72), 1.0)
			draw_circle(endpoint, 13.0 + phase * 7.0, Color(color, opacity * 0.16))
			draw_arc(endpoint, 9.0 + phase * 8.0, 0.0, TAU, 16, Color(color, opacity), 2.0)
			var beam_label := String(cue.get("label", ""))
			var beam_width := ThemeDB.fallback_font.get_string_size(beam_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(ThemeDB.fallback_font, endpoint + Vector2(-beam_width * 0.5, -22.0), beam_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(color, opacity))
			continue
		if String(cue.get("kind", "")) == "spray":
			var start: Vector2 = cue.get("start", position)
			var endpoint: Vector2 = cue.get("end", position)
			var lane := endpoint - start
			var perpendicular := Vector2(-lane.y, lane.x).normalized()
			var fan_width := lane.length() * 0.46
			var fan := PackedVector2Array([start, endpoint + perpendicular * fan_width, endpoint - perpendicular * fan_width])
			draw_colored_polygon(fan, Color(color, opacity * 0.13))
			for offset: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
				draw_line(start, endpoint + perpendicular * fan_width * offset, Color(color, opacity * (0.34 if offset != 0.0 else 0.78)), 2.0 if offset != 0.0 else 4.0)
			draw_arc(start, minf(90.0, lane.length() * 0.34), lane.angle() - 0.43, lane.angle() + 0.43, 18, Color(color, opacity * 0.8), 2.0)
			continue
		draw_arc(position, 10.0 + phase * 22.0, 0.0, TAU, 20, Color(color, opacity * 0.8), 2.0)
		var label := String(cue.get("label", ""))
		var label_width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(ThemeDB.fallback_font, position + Vector2(-label_width * 0.5, -28.0 - phase * 18.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(color, opacity))


func _draw_remote_travellers(camera_origin: Vector2, local_entity_id: int, visual_tick: float) -> void:
	var motion_alpha := clampf(remote_snapshot_age_seconds * 60.0 if session_transport.is_connected_client() else accumulator_seconds * float(tick_rate), 0.0, 1.0)
	for remote_state: PlayerState in world.players:
		if remote_state.actor_kind != PlayerState.ActorKind.CHAMPION or remote_state.entity_id == local_entity_id:
			continue
		if not _chemistry_actor_visible(remote_state):
			continue
		var motion_point: Vector3 = actor_motion_history.sample(remote_state, motion_alpha)
		var position := Vector2(motion_point.x, motion_point.y)
		var presentation := JumpPresentation.sample(remote_state, world.config, motion_alpha, _reduced_effects_enabled(), actor_motion_history.previous_height(remote_state))
		var landing := LandingPresentation.sample(remote_state, world.config, 0.0, _reduced_effects_enabled())
		var radius := float(MovementTuning.PLAYER_RADIUS) / 1000.0
		var shadow_center := position + Vector2(0.0, radius * 0.58)
		if campus_renderer.natural_kit != null:
			campus_renderer.natural_kit.draw_actor_contact(self, campus_layout, remote_state, shadow_center, roundi(visual_tick), _reduced_effects_enabled())
		var shadow_scale: Vector2 = landing.shadow_scale if landing.active else presentation.shadow_scale
		_draw_receiving_surface_shadow(
			shadow_center,
			Vector2(radius * shadow_scale.x, radius * shadow_scale.y),
			presentation.shadow_opacity,
			camera_origin,
		)
		if landing.active:
			_draw_landing_cue(shadow_center, landing)
		var body_position := position + Vector2(0.0, -float(presentation.body_lift_pixels))
		var sprite_drawn: bool = false
		var champion_id := champion_catalog.champion_id_from_wire(remote_state.champion_wire_id)
		var sprite_anchor := shadow_center + Vector2(0.0, -float(presentation.body_lift_pixels))
		if cartoon_champion_presenter != null:
			sprite_drawn = cartoon_champion_presenter.draw(
				self,
				remote_state,
				champion_id,
				sprite_anchor,
				visual_tick,
				world.config,
				_reduced_effects_enabled(),
				shadow_center,
				actor_motion_history.gait_phase(remote_state.entity_id),
			)
		if not sprite_drawn:
			var body_color := FLUX_COLOR if remote_state.champion_wire_id == 2 else ATTUNEMENT_COLOR
			draw_circle(body_position, radius + 5.0, Color(body_color, 0.18))
			draw_circle(body_position, radius, body_color)
			draw_arc(body_position, radius + 2.0, 0.0, TAU, 24, PARCHMENT_COLOR, 2.0)
		if show_debug_overlay:
			_draw_actor_hitbox_diagnostic(body_position, radius, champion_id)
		_draw_spell_startup(remote_state, sprite_anchor, roundi(visual_tick))
		if remote_state.spawn_protection_ticks > 0:
			var protection_ratio := clampf(float(remote_state.spawn_protection_ticks) / float(maxi(1, world.config.milliseconds_to_ticks(1200))), 0.0, 1.0)
			draw_arc(body_position, radius + 9.0, 0.0, TAU, 28, Color(ATTUNEMENT_COLOR, 0.32 + protection_ratio * 0.42), 2.0)
		draw_line(body_position, body_position + Vector2(remote_state.aim_x, remote_state.aim_y) * 0.032, Color(PARCHMENT_COLOR, 0.9), 2.0)
		var display_name := String(session_names_by_entity.get(remote_state.entity_id, "TRAVELLER %d" % remote_state.entity_id)).to_upper()
		var name_width := ThemeDB.fallback_font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var label_position := body_position + Vector2(-name_width * 0.5, -43.0)
		draw_string(ThemeDB.fallback_font, label_position, display_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, PARCHMENT_COLOR)
		var health_bar := Rect2(body_position + Vector2(-22.0, -37.0), Vector2(44.0, 4.0))
		draw_rect(health_bar, Color(FOREST_SHADOW_COLOR, 0.9), true)
		var health_ratio := clampf(float(remote_state.health) / float(maxi(1, remote_state.health_maximum)), 0.0, 1.0)
		draw_rect(Rect2(health_bar.position + Vector2.ONE, Vector2((health_bar.size.x - 2.0) * health_ratio, 2.0)), Color("d9634f"), true)
	_set_world_transform(camera_origin)


func _draw_receiving_surface_shadow(center: Vector2, radii: Vector2, opacity: float, camera_origin: Vector2) -> void:
	var sample: Dictionary = {}
	if campus_renderer != null and campus_renderer.natural_kit != null:
		sample = campus_renderer.natural_kit.receiving_shadow_sample(campus_layout, center)
	var fill_color := FOREST_SHADOW_COLOR
	var opacity_scale := 1.0
	var rim_color := Color.TRANSPARENT
	var rim_opacity := 0.0
	if not sample.is_empty():
		fill_color = sample.get("fill_color", fill_color)
		opacity_scale = float(sample.get("opacity_scale", 1.0))
		rim_color = sample.get("rim_color", rim_color)
		rim_opacity = float(sample.get("rim_opacity", 0.0))
	_set_world_local_transform(center, radii, camera_origin)
	draw_circle(Vector2.ZERO, 1.0, Color(fill_color, clampf(opacity * opacity_scale, 0.0, 1.0)))
	if rim_opacity > 0.0:
		draw_arc(Vector2.ZERO, 0.92, 0.0, TAU, 18, Color(rim_color, rim_opacity), 0.08)
	_set_world_transform(camera_origin)


func _draw_spell_startup(state: PlayerState, position: Vector2, visual_tick: int) -> void:
	if foundation_spell_presenter == null or state == null or state.pending_cast_wire_id <= 0 or state.pending_cast_ticks <= 0:
		return
	var ability := ability_catalog.ability_from_wire(state.pending_cast_wire_id)
	if ability.is_empty():
		return
	var full_ticks := maxi(1, world.config.milliseconds_to_ticks(int(ability.get("startup_ms", 0))))
	var phase := clampf(1.0 - float(state.pending_cast_ticks) / float(full_ticks), 0.0, 1.0)
	var hand_origin := CartoonChampionPresenter.hand_cast_origin(position, Vector2(state.aim_x, state.aim_y))
	foundation_spell_presenter.draw_startup(
		self,
		state.pending_cast_wire_id,
		hand_origin,
		Vector2(state.aim_x, state.aim_y),
		phase,
		visual_tick,
		_reduced_effects_enabled(),
	)


func _draw_actor_hitbox_diagnostic(center: Vector2, radius: float, champion_id: String) -> void:
	draw_circle(center, radius, Color(visual_language.ui_color("danger"), 0.08))
	draw_arc(center, radius, 0.0, TAU, 32, visual_language.ui_color("danger"), 2.0)
	draw_line(center + Vector2(-radius, 0.0), center + Vector2(radius, 0.0), Color(PARCHMENT_COLOR, 0.72), 1.0)
	draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, radius), Color(PARCHMENT_COLOR, 0.72), 1.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(radius + 4.0, 4.0), "%s HITBOX" % champion_id.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, visual_language.ui_color("danger"))


func _readable_event(state: PlayerState) -> String:
	for prefix: String in ["cast_start_", "cast_release_", "cast_blocked_"]:
		if state.last_event.begins_with(prefix):
			var wire_text := state.last_event.trim_prefix(prefix)
			var ability_id := String(ability_catalog.ability_ids_by_wire.get(wire_text.to_int(), ""))
			var ability_name := String(ability_catalog.ability(ability_id).get("display_name", "SPELL")).to_upper()
			if prefix == "cast_start_":
				return "CHANNEL %s" % ability_name
			if prefix == "cast_blocked_":
				return "%s BLOCKED" % ability_name
			return ability_name
	if state.last_event.begins_with("champion_"):
		return "ATTUNED"
	return state.last_event.replace("_", " ").to_upper()


func _active_hint(state: PlayerState, ability_name: String, ability: Dictionary) -> String:
	if state.active_1_cooldown_ticks > 0:
		return "%s %.1fs" % [ability_name.to_upper(), float(state.active_1_cooldown_ticks) / float(world.config.tick_rate)]
	return "%s %d FLUX" % [ability_name.to_upper(), int(ability.get("flux_cost", 0))]


func _draw_landing_cue(center: Vector2, landing: LandingPresentation.Sample) -> void:
	LandingPresentation.draw(self, center, landing, visual_language)


func _draw_station_bubble(camera_origin: Vector2) -> void:
	if interaction_presenter == null or station_notice_seconds > 0.0:
		return
	if focused_station_id.is_empty() or not campus_layout.stations_by_id.has(focused_station_id):
		return
	if int(_current_round_state().get("phase", SessionRound.Phase.HEARTH)) != SessionRound.Phase.HEARTH:
		return
	var station: Dictionary = campus_layout.stations_by_id[focused_station_id]
	var values: Array = station.get("position", [])
	var station_position := Vector2(float(values[0]), float(values[1]))
	var expanded: bool = expanded_station_id == focused_station_id
	var lines: Array = _station_lines(station) if expanded else [String(station.get("prompt", "F  INTERACT"))]
	var ui_scale := _ui_scale()
	var actor_feet := PixelPresentation.world_to_screen(current_position, camera_origin, player_preferences.camera_zoom_percent) / ui_scale
	var actor_scale := float(player_preferences.camera_zoom_percent) / 100.0 / ui_scale
	# Reserve all three body sizes plus jump lift, in the same UI coordinates.
	var actor_bounds := Rect2(actor_feet - Vector2(48, 160) * actor_scale, Vector2(96, 176) * actor_scale)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ui_scale)
	interaction_presenter.draw_station(
		self,
		get_viewport_rect().size / ui_scale,
		PixelPresentation.world_to_screen(station_position, camera_origin, player_preferences.camera_zoom_percent) / ui_scale,
		station,
		lines,
		expanded,
		_station_interact_label(),
		actor_bounds,
	)


func _draw_station_notice(location_name: String) -> void:
	if interaction_presenter == null or station_notice_seconds <= 0.0 or station_notice.is_empty():
		return
	var ui_scale := _ui_scale()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ui_scale)
	interaction_presenter.draw_notice(
		self,
		get_viewport_rect().size / ui_scale,
		"COURT" if location_name == "PROVING COURT" else String((interaction_presenter.data.get("copy", {}) as Dictionary).get("notice_title", "WELLSPRING")),
		station_notice,
	)


func _station_lines(station: Dictionary) -> Array:
	var command := String(station.get("command", ""))
	if command == "host_session":
		var closing_armed := session_transport.is_host() and session_steward.is_armed(SessionSteward.Action.CLOSE_COMPANY, 0, world.tick)
		var action_line := _station_interact_instruction("opens a direct friend gate")
		if closing_armed:
			action_line = _station_interact_instruction("CONFIRMS CLOSING THE COMPANY")
		elif session_transport.is_host():
			action_line = _station_interact_instruction("arms a three-second close")
		return [session_transport.status_detail, "UDP %d · %d/%d travellers" % [session_port, session_transport.player_count(), _selected_session_capacity()], "CHARTER: %s" % SessionCharter.display_name(selected_charter_id), action_line]
	if command == "join_session":
		if join_address_editor_open:
			return [
				"TYPE OR CTRL+V THE HOST ADDRESS",
				"> %s%s" % [join_address_editor_text, "_" if Time.get_ticks_msec() % 1000 < 600 else ""],
				join_address_editor_error if not join_address_editor_error.is_empty() else "ENTER SEEKS · ESC CANCELS · PORT %d" % session_port,
				"The address is saved only on this PC",
			]
		var charter_line := "HOST CHARTER APPEARS AFTER JOIN" if not session_transport.is_connected_client() else "CHARTER: %s · %d PLACES" % [SessionCharter.display_name(selected_charter_id), session_transport.player_capacity()]
		return [session_transport.status_detail, "%s:%d" % [join_address, session_port], charter_line, _station_interact_instruction("closes the gate") if session_transport.mode != SessionTransport.Mode.OFFLINE else _station_interact_instruction("enters or confirms the friend address")]
	if command == "session_charter":
		var charter := SessionCharter.definition(selected_charter_id)
		var locked := session_transport.is_online()
		return [
			"SEALED WHILE FARFLOW IS OPEN" if locked else _station_interact_instruction("turns to %s" % SessionCharter.display_name(SessionCharter.next_id(selected_charter_id))),
			"%s · %d TRAVELLERS" % [String(charter.get("display_name", "")), int(charter.get("maximum_players", 0))],
			"TRAVELLER DAMAGE %s" % ("ON" if bool(charter.get("player_damage", false)) else "OFF"),
			"PRACTICE RESET: %s" % ("HOST ONLY" if String(charter.get("practice_reset", "")) == SessionCharter.RESET_HOST_ONLY else "ANY TRAVELLER"),
		]
	if command == "session_hearth":
		return _session_hearth_lines()
	if command == "session_ledger":
		return _session_ledger_lines()
	if command == "session_parting":
		return _session_parting_lines()
	if command != "champion_switch":
		return station.get("lines", [])
	var current: Dictionary = champion_catalog.champion(selected_champion_id)
	var stats: Dictionary = current.get("stats", {})
	return [
		"ATTUNED: %s · %s" % [String(current.get("display_name", "")).to_upper(), String(current.get("ancestry", "")).to_upper()],
		"HP %d · FLUX %d · STAMINA %d · SPEED %d%%" % [int(stats.get("health_maximum", 0)) / 1000, int(stats.get("flux_maximum", 0)) / 1000, int(stats.get("stamina_maximum", 0)) / 1000, int(stats.get("movement_speed_ratio", 0)) / 10],
		"Interact: preview, then choose your champion.",
	]


func _sync_session_transport() -> void:
	if session_transport.is_host():
		var joined := session_transport.take_joined_peers()
		if not joined.is_empty():
			var join_cancelled_countdown := authoritative_session.practice_countdown_active()
			authoritative_session.register_peers(joined)
			if requested_hearth_smoke and authoritative_session.session_round.phase == SessionRound.Phase.HEARTH:
				_arrange_hearth_roster()
				if not authoritative_session.hearth.is_ready(SessionTransport.SERVER_PEER_ID):
					_handle_session_requests([{
						"entity_id": SessionTransport.SERVER_PEER_ID,
						"action": SessionTransport.REQUEST_READY_TOGGLE,
					}])
				print("FLUX2 farflow hearth smoke: roster gathered and host ready")
			if join_cancelled_countdown:
				_publish_session_event({"type": "practice_cancelled", "entity_id": SessionTransport.SERVER_PEER_ID, "reason": 1})
			session_names_by_entity = authoritative_session.names_by_entity.duplicate()
			for event: Dictionary in joined:
				print("FLUX2 farflow host: %s entity %d (%s)" % ["returned" if bool(event.get("resumed", false)) else "joined", int(event.get("entity_id", 0)), String(event.get("name", "Traveller"))])
				if requested_rematch_smoke and bool(event.get("resumed", false)) and authoritative_session.session_round.active():
					authoritative_session.session_round.round_end_tick = world.tick + world.config.milliseconds_to_ticks(250)
					print("FLUX2 farflow rematch smoke: closing round 1 after exact-actor return")
		var disconnected := session_transport.take_disconnected_peers()
		if not disconnected.is_empty():
			var disconnect_cancelled_countdown := authoritative_session.practice_countdown_active()
			var suspended: Array[Dictionary] = []
			var removed: Array[Dictionary] = []
			for event: Dictionary in disconnected:
				if bool(event.get("reserved", false)):
					suspended.append(event)
					print("FLUX2 farflow host: return reserved for entity %d (%s)" % [int(event.get("entity_id", 0)), String(event.get("name", "Traveller"))])
				else:
					removed.append(event)
					print("FLUX2 farflow host: %s entity %d (%s)" % ["return expired for" if bool(event.get("expired", false)) else "left", int(event.get("entity_id", 0)), String(event.get("name", "Traveller"))])
					if requested_steward_smoke and bool(event.get("administrative", false)) and not bool(event.get("reserved", true)):
						print("FLUX2 farflow steward smoke: guest removed without reservation")
			authoritative_session.suspend_peers(suspended)
			authoritative_session.remove_peers(removed)
			if disconnect_cancelled_countdown:
				_publish_session_event({"type": "practice_cancelled", "entity_id": SessionTransport.SERVER_PEER_ID, "reason": 1})
			session_names_by_entity = authoritative_session.names_by_entity.duplicate()
		if session_steward != null:
			session_steward.reconcile_roster(session_transport.host_roster())
		if host_close_pending and session_transport.host_roster().is_empty():
			_finish_host_close()
			return
		authoritative_session.ingest_inputs(session_transport.take_inputs())
		_handle_session_requests(session_transport.take_requests())
		return
	if session_transport.is_connected_client():
		if SessionCharter.is_valid_id(session_transport.session_charter_id):
			selected_charter_id = session_transport.session_charter_id
		client_replica_active = true
		input_router.entity_id = session_transport.local_entity_id
		if not _is_spectating() and client_prediction.local_entity_id != session_transport.local_entity_id:
			if not client_prediction.configure(world.config, world.collision, session_transport.local_entity_id):
				push_error("Farflow prediction could not bind the local traveller")
				return
		var snapshots := session_transport.take_snapshots()
		var first_snapshot: bool = last_client_snapshot_tick < 0
		if not snapshots.is_empty():
			var snapshot: Dictionary = snapshots.back()
			if int(snapshot.get("tick", -1)) > last_client_snapshot_tick and SessionSnapshot.apply_to_world(snapshot, world):
				last_client_snapshot_tick = int(snapshot["tick"])
				actor_motion_history.capture(world.players)
				remote_snapshot_age_seconds = 0.0
				var overflow: PackedInt32Array = snapshot.get("overflow", PackedInt32Array([0, 0, 0]))
				_apply_snapshot_overflow(overflow)
				session_names_by_entity = SessionSnapshot.names(snapshot)
				session_hearth_values = SessionSnapshot.hearth_values(snapshot)
				session_round_values = SessionSnapshot.round_values(snapshot)
				_reconcile_spectator_focus()
				var unseen_events := session_event_inbox.take_unseen(world.combat_events)
				world.combat_events = unseen_events
				_ingest_combat_cues(unseen_events)
				_ingest_session_feedback(unseen_events)
				var local_state := _local_player_state()
				_complete_pending_weave()
				if local_state != null:
					if first_snapshot:
						print("FLUX2 farflow replica: local entity %d, snapshot tick %d, travellers %d" % [local_state.entity_id, world.tick, session_names_by_entity.size()])
						var first_round := _current_round_state()
						var local_entered_round: bool = (first_round.get("entries", []) as Array).any(
							func(entry_value: Variant) -> bool:
								return int((entry_value as Dictionary).get("entity_id", 0)) == local_state.entity_id
						)
						if int(first_round.get("phase", SessionRound.Phase.HEARTH)) == SessionRound.Phase.ACTIVE and not local_entered_round:
							station_notice = "The court is underway. You join the next gathering."
							station_notice_seconds = 4.0
					var replicated_champion_id := champion_catalog.champion_id_from_wire(local_state.champion_wire_id)
					if not replicated_champion_id.is_empty() and replicated_champion_id != selected_champion_id:
						selected_champion_id = replicated_champion_id
						character_selection_grid.confirm_equipped(replicated_champion_id)
						client_weave_restore_champion = local_state.champion_wire_id
					if first_snapshot: client_weave_restore_champion = local_state.champion_wire_id
					_try_restore_client_weave(local_state)
					if not client_prediction.is_ready():
						var replicated_position := _player_position()
						previous_position = replicated_position if first_snapshot else current_position
						current_position = replicated_position
				if first_snapshot and requested_emote_smoke and not emote_smoke_sent:
					emote_smoke_sent = true
					_submit_session_request(SessionTransport.REQUEST_EMOTE)
					print("FLUX2 farflow social: guest emote request sent")
				if first_snapshot and requested_hearth_smoke and not hearth_smoke_ready_sent:
					hearth_smoke_ready_sent = true
					_submit_session_request(SessionTransport.REQUEST_READY_TOGGLE)
					print("FLUX2 farflow hearth smoke: guest readiness sent")
				if first_snapshot and requested_reconnect_smoke:
					if reconnect_smoke_stage == 0:
						reconnect_smoke_entity_id = session_transport.local_entity_id
						reconnect_smoke_stage = 1
						# Leave enough time for the maintained third-process smoke to join
						# the live court before this original traveller tests reconnection.
						reconnect_smoke_delay_seconds = 2.0
					elif reconnect_smoke_stage == 3 and session_transport.local_entity_id == reconnect_smoke_entity_id:
						reconnect_smoke_stage = 4
						print("FLUX2 farflow reconnect smoke: returned entity %d" % reconnect_smoke_entity_id)
				var replicated_round := _current_round_state()
				if (
					requested_rematch_smoke
					and not rematch_smoke_ready_sent
					and int(replicated_round.get("phase", SessionRound.Phase.HEARTH)) == SessionRound.Phase.HEARTH
					and int(replicated_round.get("serial", 0)) == 1
				):
					rematch_smoke_ready_sent = true
					_submit_session_request(SessionTransport.REQUEST_READY_TOGGLE)
					print("FLUX2 farflow rematch smoke: guest gathered and ready for round 2")
		var reconciliations := session_transport.take_reconciliations()
		if not reconciliations.is_empty() and not _is_spectating():
			var local_authority := _local_player_state()
			var authority_event := local_authority.last_event if local_authority != null else "network_snapshot"
			if client_prediction.reconcile(reconciliations.back(), authority_event, _reduced_effects_enabled()):
				if client_prediction.last_correction_pixels > 0.01:
					actor_motion_history.rebase_gait(client_prediction.predicted_state.entity_id)
				previous_position = current_position
				current_position = client_prediction.presented_position_pixels()
				previous_prediction_position = client_prediction.raw_position_pixels()
				# Reconciliation is a new authority sample, never a delayed protection
				# state or a blend from an unrelated pre-respawn airborne arc.
				previous_air_height = client_prediction.predicted_state.air_height
				if requested_prediction_smoke and not prediction_smoke_started:
					prediction_smoke_started = true
					prediction_smoke_start_x = client_prediction.last_authoritative_position_pixels.x
				if client_prediction.last_acknowledged_sequence < 1:
					print("FLUX2 farflow prediction: entity %d reconciles at tick %d" % [session_transport.local_entity_id, client_prediction.last_authoritative_tick])
		return
	if client_replica_active and session_transport.mode == SessionTransport.Mode.OFFLINE:
		var disconnect_message := session_transport.last_error
		var steward_release_received := requested_steward_smoke and disconnect_message == GUEST_RELEASE_REASON and not session_transport.can_reconnect()
		client_replica_active = false
		client_input_sequence = 0
		client_request_sequence = 0
		client_prediction.reset()
		last_client_snapshot_tick = -1
		network_projectile_overflow = 0
		session_hearth_values = PackedInt32Array()
		session_round_values = PackedInt32Array()
		spectator_focus.reset()
		if _start_match(tick_rate):
			station_notice = disconnect_message if not disconnect_message.is_empty() else "The Farflow gate is closed."
			station_notice_seconds = 3.0
			if steward_release_received:
				print("FLUX2 farflow steward smoke: guest received release reason and return revoked")


func _update_reconnect_smoke(delta: float) -> void:
	if not requested_reconnect_smoke:
		return
	if reconnect_smoke_stage == 1:
		if not session_transport.is_connected_client() or not reconnect_smoke_prerequisites_met(
			requested_emote_smoke,
			emote_smoke_sent,
			requested_prediction_smoke,
			prediction_smoke_reported,
			requested_hearth_smoke,
			hearth_smoke_started_reported,
		):
			return
		reconnect_smoke_delay_seconds = maxf(0.0, reconnect_smoke_delay_seconds - delta)
		if reconnect_smoke_delay_seconds <= 0.0:
			session_transport.stop()
			reconnect_smoke_stage = 2
			reconnect_smoke_delay_seconds = 0.75
			print("FLUX2 farflow reconnect smoke: left entity %d" % reconnect_smoke_entity_id)
		return
	if reconnect_smoke_stage != 2 or session_transport.mode != SessionTransport.Mode.OFFLINE:
		return
	reconnect_smoke_delay_seconds = maxf(0.0, reconnect_smoke_delay_seconds - delta)
	if reconnect_smoke_delay_seconds > 0.0:
		return
	if session_transport.start_join(join_address, session_port, _session_compatibility_signature(), local_player_name):
		reconnect_smoke_stage = 3
		print("FLUX2 farflow reconnect smoke: seeking reserved identity")
	else:
		reconnect_smoke_stage = 5
		push_error("FLUX2 farflow reconnect smoke failed: %s" % session_transport.last_error)


func _submit_session_request(action: int, value: int = 0) -> void:
	if session_transport.is_connected_client():
		client_request_sequence += 1
		if session_transport.send_request(client_request_sequence, action, value):
			station_notice = "Request sent through Farflow."
		else:
			station_notice = "Farflow could not carry that request."
			if action in [SessionTransport.REQUEST_SPELL_EQUIP, SessionTransport.REQUEST_WEAVE_APPLY]: pending_weave_request.clear()
			if action == SessionTransport.REQUEST_CHAMPION_SELECT:
				character_selection_grid.refuse(station_notice)
		station_notice_seconds = 1.5
		return
	_handle_session_requests([{
		"entity_id": SessionTransport.SERVER_PEER_ID,
		"action": action,
		"value": value,
	}])


func _handle_session_requests(requests: Array[Dictionary]) -> void:
	_ensure_character_weaves()
	for request: Dictionary in requests:
		var entity_id := int(request.get("entity_id", 0))
		var action := int(request.get("action", 0))
		var request_value := int(request.get("value", 0))
		var state: PlayerState = world.player(entity_id)
		if state == null or state.actor_kind != PlayerState.ActorKind.CHAMPION:
			continue
		var ready_tick: int = emote_ready_tick_by_entity.get(entity_id, 0)
		var refusal_reason := SessionRequestPolicy.validate(
			action,
			state,
			campus_layout.stations_by_id,
			world.tick,
			ready_tick,
			int(_current_round_state().get("phase", SessionRound.Phase.HEARTH)),
		)
		# The isolated solo practice court exposes its Loom without a campus station.
		if world.hex_court != null and session_transport.mode == SessionTransport.Mode.OFFLINE and action in [SessionTransport.REQUEST_SPELL_EQUIP, SessionTransport.REQUEST_WEAVE_APPLY, SessionTransport.REQUEST_CHAMPION_SELECT] and ChampionAttunementScript.is_available(state):
			refusal_reason = SessionRequestPolicy.ACCEPTED
		if refusal_reason != SessionRequestPolicy.ACCEPTED:
			_publish_session_event({"type": "request_refused", "entity_id": entity_id, "action": action, "sequence": int(request.get("sequence", 0)), "champion_wire_id": state.champion_wire_id, "reason": refusal_reason})
			continue
		match action:
			SessionTransport.REQUEST_EMOTE:
				emote_ready_tick_by_entity[entity_id] = world.tick + world.config.milliseconds_to_ticks(EMOTE_COOLDOWN_MS)
				_publish_session_event({"type": "social_emote", "entity_id": entity_id, "emote_id": 1})
			SessionTransport.REQUEST_TRAINING_RESET:
				if not SessionCharter.can_reset_practice(selected_charter_id, entity_id):
					_publish_session_event({"type": "request_refused", "entity_id": entity_id, "action": action, "sequence": int(request.get("sequence", 0)), "champion_wire_id": state.champion_wire_id, "reason": SessionRequestPolicy.REFUSED_UNAVAILABLE})
					continue
				if not _restart_shared_seed(tick_rate):
					_publish_session_event({"type": "request_refused", "entity_id": entity_id, "action": action, "sequence": int(request.get("sequence", 0)), "champion_wire_id": state.champion_wire_id, "reason": SessionRequestPolicy.REFUSED_UNAVAILABLE})
					continue
				_publish_session_event({"type": "station_confirmed", "entity_id": entity_id, "action": action, "sequence": int(request.get("sequence", 0)), "champion_wire_id": state.champion_wire_id})
			SessionTransport.REQUEST_IMPACT_PRACTICE:
				if not MovementSystem.apply_control_state(
					state, PlayerState.ControlState.LAUNCHED, 320,
					Vector2i.UP, 540_000, world.config,
				):
					_publish_session_event({"type": "request_refused", "entity_id": entity_id, "action": action, "sequence": int(request.get("sequence", 0)), "champion_wire_id": state.champion_wire_id, "reason": SessionRequestPolicy.REFUSED_UNAVAILABLE})
					continue
				_publish_session_event({"type": "station_confirmed", "entity_id": entity_id, "action": action, "sequence": int(request.get("sequence", 0)), "champion_wire_id": state.champion_wire_id})
			SessionTransport.REQUEST_CHAMPION_NEXT, SessionTransport.REQUEST_CHAMPION_SELECT:
				var requested_wire := request_value
				if action == SessionTransport.REQUEST_CHAMPION_NEXT:
					var current_id := champion_catalog.champion_id_from_wire(state.champion_wire_id)
					requested_wire = int(champion_catalog.champion(champion_catalog.next_champion_id(current_id)).get("wire_id", 0))
				if world.hex_court == null: character_weaves.remember_actor(state)
				var attunement := ChampionAttunementScript.apply(champion_catalog, state, requested_wire)
				if attunement == ChampionAttunementScript.REFUSED:
					_publish_session_event({"type": "request_refused", "entity_id": entity_id, "action": action, "sequence": int(request.get("sequence", 0)), "champion_wire_id": state.champion_wire_id, "reason": SessionRequestPolicy.REFUSED_UNAVAILABLE})
					continue
				if attunement == ChampionAttunementScript.CHANGED:
					character_weaves.restore_actor(state, entity_id == session_transport.local_entity_id)
				if entity_id == SessionTransport.SERVER_PEER_ID and attunement == ChampionAttunementScript.CHANGED:
					selected_champion_id = champion_catalog.champion_id_from_wire(state.champion_wire_id)
				_publish_session_event({"type": "champion_attuned", "entity_id": entity_id, "champion_wire_id": state.champion_wire_id})
			SessionTransport.REQUEST_WEAVE_APPLY:
				if request_value != state.champion_wire_id or not SessionTransport._valid_weave_wires(request.get("expected"), true) or not SessionTransport._valid_weave_wires(request.get("wires")) or PackedInt32Array(request.expected) != state.spell_wire_ids or not CharacterWeavePolicy.apply(state, PackedInt32Array(request.wires)):
					_publish_session_event({"type": "request_refused", "entity_id": entity_id, "action": action, "sequence": int(request.get("sequence", 0)), "champion_wire_id": state.champion_wire_id, "reason": SessionRequestPolicy.REFUSED_UNAVAILABLE})
					continue
				character_weaves.remember_actor(state)
				_publish_session_event({"type": "station_confirmed", "entity_id": entity_id, "action": action, "sequence": int(request.get("sequence", 0)), "champion_wire_id": state.champion_wire_id})
			SessionTransport.REQUEST_SPELL_EQUIP:
				var slot_index: int = SpellLoomEditor.decode_slot_index(request_value)
				var library_index: int = SpellLoomEditor.decode_library_index(request_value)
				var wire_id: int = SpellLoomEditor.wire_id_for_library_index(library_index)
				if slot_index < 0 or wire_id == 0 or not state.place_proven_spell(slot_index, wire_id):
					_publish_session_event({"type": "request_refused", "entity_id": entity_id, "action": action, "sequence": int(request.get("sequence", 0)), "champion_wire_id": state.champion_wire_id, "reason": SessionRequestPolicy.REFUSED_UNAVAILABLE})
					continue
				character_weaves.remember_actor(state)
				if entity_id == session_transport.local_entity_id: _save_confirmed_weave(state, CharacterWeaveLibrary.MODE_CUSTOM)
				if entity_id == session_transport.local_entity_id and spell_loom_editor != null and spell_loom_editor.is_open:
					spell_loom_editor.status_message = "%s was sealed by the host." % PlayerState.spell_slot_label(slot_index)
				station_notice = "%s rewove %s." % [String(session_names_by_entity.get(entity_id, "A traveller")), PlayerState.spell_slot_label(slot_index)]
				station_notice_seconds = 1.5
			SessionTransport.REQUEST_READY_TOGGLE:
				if not authoritative_session.toggle_ready(entity_id):
					_publish_session_event({"type": "request_refused", "entity_id": entity_id, "action": action, "sequence": int(request.get("sequence", 0)), "champion_wire_id": state.champion_wire_id, "reason": SessionRequestPolicy.REFUSED_UNAVAILABLE})
					continue
				_publish_session_event({"type": "ready_changed", "entity_id": entity_id, "ready": authoritative_session.hearth.is_ready(entity_id)})
				if (
					requested_hearth_smoke
					and entity_id != SessionTransport.SERVER_PEER_ID
					and authoritative_session.can_start_practice()
					and authoritative_session.start_practice_countdown(SessionTransport.SERVER_PEER_ID)
				):
					_publish_session_event({"type": "practice_countdown", "entity_id": SessionTransport.SERVER_PEER_ID, "duration_ticks": world.config.milliseconds_to_ticks(3000)})
					print("FLUX2 farflow hearth smoke: all ready; countdown started")
			SessionTransport.REQUEST_PRACTICE_START:
				if not authoritative_session.start_practice_countdown(entity_id):
					_publish_session_event({"type": "request_refused", "entity_id": entity_id, "action": action, "sequence": int(request.get("sequence", 0)), "champion_wire_id": state.champion_wire_id, "reason": SessionRequestPolicy.REFUSED_UNAVAILABLE})
					continue
				_publish_session_event({"type": "practice_countdown", "entity_id": entity_id, "duration_ticks": world.config.milliseconds_to_ticks(3000)})


func _publish_session_event(event: Dictionary) -> void:
	authoritative_session.record_combat_events([event])
	_ingest_session_feedback([event])


func _champion_attunements() -> Dictionary[int, String]:
	var result: Dictionary[int, String] = {}
	for state: PlayerState in world.players:
		if state.actor_kind == PlayerState.ActorKind.CHAMPION:
			result[state.entity_id] = champion_catalog.champion_id_from_wire(state.champion_wire_id)
	return result


func _restore_champion_attunements(attunements: Dictionary[int, String]) -> void:
	for entity_id: int in attunements:
		var state: PlayerState = world.player(entity_id)
		if state != null:
			champion_catalog.apply_to_player(state, attunements[entity_id])
			character_weaves.restore_actor(state, entity_id == session_transport.local_entity_id)


func _ingest_session_feedback(events: Array[Dictionary]) -> void:
	for event: Dictionary in events:
		var kind := String(event.get("type", ""))
		var entity_id := int(event.get("entity_id", 0))
		match kind:
			"social_emote":
				for index: int in range(social_bubbles.size() - 1, -1, -1):
					if int(social_bubbles[index].get("entity_id", 0)) == entity_id:
						social_bubbles.remove_at(index)
				social_bubbles.append({"entity_id": entity_id, "text": "HELLO!", "remaining": 2.0, "duration": 2.0})
				print("FLUX2 farflow social: shared emote entity %d" % entity_id)
			"station_confirmed":
				var confirmed_action := int(event.get("action", 0))
				if confirmed_action == SessionTransport.REQUEST_WEAVE_APPLY:
					if entity_id == session_transport.local_entity_id:
						if pending_weave_request.is_empty() or int(event.get("sequence", -1)) != int(pending_weave_request.sequence) or int(event.get("champion_wire_id", 0)) != int(pending_weave_request.champion):
							continue
						pending_weave_request.acknowledged = true
						_complete_pending_weave()
					station_notice = "Twelve spell positions applied."
				elif confirmed_action == SessionTransport.REQUEST_IMPACT_PRACTICE:
					station_notice = "%s struck the Momentum Chime: steer, then V to tech." % String(session_names_by_entity.get(entity_id, "A traveller"))
				else:
					station_notice = "%s restored the practice court." % String(session_names_by_entity.get(entity_id, "A traveller"))
				station_notice_seconds = 2.5
			"champion_attuned":
				var champion_id := champion_catalog.champion_id_from_wire(int(event.get("champion_wire_id", 0)))
				var local_state := _local_player_state()
				if local_state != null and local_state.entity_id == entity_id:
					character_selection_grid.confirm_equipped(champion_id)
				var champion_name := String(champion_catalog.champion(champion_id).get("display_name", champion_id))
				station_notice = "%s attuned to %s." % [String(session_names_by_entity.get(entity_id, "A traveller")), champion_name]
				station_notice_seconds = 2.5
			"request_refused":
				var local_state := _local_player_state()
				if local_state != null and local_state.entity_id == entity_id:
					var refused_action := int(event.get("action", 0))
					if refused_action == SessionTransport.REQUEST_WEAVE_APPLY and (pending_weave_request.is_empty() or int(event.get("sequence", -1)) != int(pending_weave_request.sequence)):
						continue
					var reason := int(event.get("reason", 0))
					station_notice = "Wait a breath." if reason == 1 else ("Stand beside the station." if reason == 2 else "That request is unavailable.")
					station_notice_seconds = 2.0
					if refused_action == SessionTransport.REQUEST_WEAVE_APPLY:
						pending_weave_request.clear()
						spell_loom_editor.complete_starter_apply(false)
					if refused_action == SessionTransport.REQUEST_SPELL_EQUIP and spell_loom_editor != null and spell_loom_editor.is_open:
						spell_loom_editor.status_message = station_notice
					if refused_action == SessionTransport.REQUEST_CHAMPION_SELECT:
						character_selection_grid.refuse("Stand beside the Gallery." if reason == SessionRequestPolicy.REFUSED_DISTANCE else "Attune during Wellspring free practice, alive and grounded with no active action.")
			"ready_changed":
				station_notice = "%s is %s." % [String(session_names_by_entity.get(entity_id, "A traveller")), "ready" if bool(event.get("ready", false)) else "waiting"]
				station_notice_seconds = 1.5
			"practice_countdown":
				station_notice = "The Hearth kindles. The Proving Court opens in three."
				station_notice_seconds = 2.5
			"practice_started":
				station_notice = "The Proving Court opens."
				station_notice_seconds = 2.0
				if requested_hearth_smoke and session_transport.is_connected_client() and not hearth_smoke_started_reported:
					hearth_smoke_started_reported = true
					print("FLUX2 farflow hearth smoke: guest received shared practice start")
				if requested_round_smoke and session_transport.is_connected_client() and not round_smoke_active_reported:
					var state := _current_round_state()
					if int(state.get("phase", SessionRound.Phase.HEARTH)) == SessionRound.Phase.ACTIVE:
						round_smoke_active_reported = true
						print("FLUX2 farflow round smoke: guest active in Proving Court serial %d" % int(state.get("serial", 0)))
				if requested_rematch_smoke and session_transport.is_connected_client() and not rematch_smoke_active_reported:
					var rematch_state := _current_round_state()
					if int(rematch_state.get("phase", SessionRound.Phase.HEARTH)) == SessionRound.Phase.ACTIVE and int(rematch_state.get("serial", 0)) == 2:
						rematch_smoke_active_reported = true
						print("FLUX2 farflow rematch smoke: guest active in Proving Court serial 2")
				if requested_spectator_smoke and session_transport.is_connected_client() and not spectator_smoke_round_reported:
					var spectator_round := _current_round_state()
					var local_is_participant := (spectator_round.get("entries", []) as Array).any(
						func(entry_value: Variant) -> bool:
							return int((entry_value as Dictionary).get("entity_id", 0)) == session_transport.local_entity_id
					)
					if int(spectator_round.get("phase", SessionRound.Phase.HEARTH)) == SessionRound.Phase.ACTIVE and int(spectator_round.get("serial", 0)) == 2 and local_is_participant:
						spectator_smoke_round_reported = true
						print("FLUX2 farflow spectator smoke: joined Proving Court serial 2 as entity %d" % session_transport.local_entity_id)
			"practice_cancelled":
				station_notice = "The Hearth waits for the changed roster."
				station_notice_seconds = 2.0
			"round_knockout":
				station_notice = "%s scores against %s." % [String(session_names_by_entity.get(int(event.get("owner_id", 0)), "A traveller")), String(session_names_by_entity.get(int(event.get("target_id", 0)), "a rival"))]
				station_notice_seconds = 1.5
			"round_respawned":
				station_notice = "%s returns under ward." % String(session_names_by_entity.get(entity_id, "A traveller"))
				station_notice_seconds = 1.5
			"round_finished":
				var winner_id := int(event.get("winner_id", 0))
				station_notice = "The court is drawn." if winner_id == 0 else "%s wins the court." % String(session_names_by_entity.get(winner_id, "A traveller"))
				station_notice_seconds = 3.0
			"round_returning":
				station_notice = "The company returns to the Hearth."
				station_notice_seconds = 2.5


func _update_social_bubbles(delta: float) -> void:
	for index: int in range(social_bubbles.size() - 1, -1, -1):
		var bubble: Dictionary = social_bubbles[index]
		bubble["remaining"] = float(bubble.get("remaining", 0.0)) - delta
		if float(bubble["remaining"]) <= 0.0 or world.player(int(bubble.get("entity_id", 0))) == null:
			social_bubbles.remove_at(index)
		else:
			social_bubbles[index] = bubble


func _draw_social_bubbles(camera_origin: Vector2) -> void:
	if interaction_presenter == null:
		return
	var ui_scale := _ui_scale()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ui_scale)
	for bubble: Dictionary in social_bubbles:
		var state: PlayerState = world.player(int(bubble.get("entity_id", 0)))
		if state == null:
			continue
		if not _chemistry_actor_visible(state):
			continue
		var world_position := Vector2(float(state.position_x), float(state.position_y)) / SimConfig.FIXED_SCALE
		var entity_id := int(bubble.get("entity_id", 0))
		interaction_presenter.draw_social(
			self,
			get_viewport_rect().size / ui_scale,
			PixelPresentation.world_to_screen(world_position, camera_origin, player_preferences.camera_zoom_percent) / ui_scale,
			String(session_names_by_entity.get(entity_id, "TRAVELLER")),
			String(bubble.get("text", "HELLO!")),
			clampf(float(bubble.get("remaining", 0.0)) / maxf(float(bubble.get("duration", 2.0)), 0.01), 0.0, 1.0),
		)


func _update_station_focus() -> void:
	if world != null and world.hex_court != null:
		focused_station_id = ""
		return
	if world == null:
		focused_station_id = ""
		return
	var state: PlayerState = _local_player_state()
	var next_focus := SanctumStationModel.nearest_station_id(
		campus_layout.stations_by_id,
		Vector2i(state.position_x, state.position_y),
	)
	if not expanded_station_id.is_empty() and expanded_station_id != next_focus:
		expanded_station_id = ""
	if join_address_editor_open and next_focus != focused_station_id:
		join_address_editor_open = false
		join_address_editor_error = ""
	focused_station_id = next_focus


func _activate_focused_station() -> void:
	if focused_station_id.is_empty() or not campus_layout.stations_by_id.has(focused_station_id):
		return
	var station: Dictionary = campus_layout.stations_by_id[focused_station_id]
	match String(station.get("command", "")):
		"movement_guide":
			var guide_device := ControlBindingEditor.DEVICE_CONTROLLER if station_activation_device == ControlBindingEditor.DEVICE_CONTROLLER else ControlBindingEditor.DEVICE_KEYBOARD
			_open_player_compendium(PlayerCompendiumScript.MOVEMENT, guide_device)
		"configure_controls":
			controls_editor.open_editor()
			expanded_station_id = focused_station_id
		"configure_spells":
			spell_loom_editor.open_editor(_local_player_state(), ability_catalog)
			expanded_station_id = focused_station_id
		"training_reset":
			_submit_session_request(SessionTransport.REQUEST_TRAINING_RESET)
		"impact_practice":
			_submit_session_request(SessionTransport.REQUEST_IMPACT_PRACTICE)
		"champion_switch":
			_open_character_gallery()
		"host_session":
			_toggle_host_session()
		"join_session":
			_toggle_join_session()
		"session_charter":
			_cycle_session_charter()
		"session_hearth":
			_activate_session_hearth()
		"session_ledger":
			_activate_session_ledger()
		"session_parting":
			_activate_session_parting()


func _observe_station_activation_device(event: InputEvent) -> void:
	if event == null or not event.is_action_pressed(InputRouter.INTERACT_ACTION) or event.is_echo():
		return
	# Follow the actual mapped activation, not the last unrelated motion. The
	# movement guide still treats keyboard/mouse as one setup, while the station
	# badge and confirmations name the exact input that performed Interact.
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		station_activation_device = ControlBindingEditor.DEVICE_CONTROLLER
	elif event is InputEventMouseButton:
		station_activation_device = ControlBindingEditor.DEVICE_MOUSE
	else:
		station_activation_device = ControlBindingEditor.DEVICE_KEYBOARD


func _station_interact_label() -> String:
	if controls_editor == null or player_preferences == null:
		return "UNBOUND"
	var label := controls_editor.binding_label(&"interact", station_activation_device, player_preferences)
	return "UNBOUND" if label == "—" else label


func _station_interact_instruction(instruction: String) -> String:
	var label := _station_interact_label().to_upper()
	if label == "UNBOUND":
		return "Bind Interact at Controls Lectern."
	return "%s %s" % [label, instruction.strip_edges()]


func _observe_movement_practice_device(event: InputEvent) -> void:
	# Hints follow deliberate device activity, not mouse motion, key echoes or
	# idle stick noise. This only selects labels; it never changes commands/binds.
	if event is InputEventKey and event.pressed and not event.echo:
		movement_practice_device = ControlBindingEditor.DEVICE_KEYBOARD
	elif event is InputEventMouseButton and event.pressed:
		movement_practice_device = ControlBindingEditor.DEVICE_KEYBOARD
	elif event is InputEventJoypadButton and event.pressed:
		movement_practice_device = ControlBindingEditor.DEVICE_CONTROLLER
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= InputRouter.AIM_DEADZONE:
		movement_practice_device = ControlBindingEditor.DEVICE_CONTROLLER


func _open_player_compendium(selected_tab: int, device: int = ControlBindingEditor.DEVICE_KEYBOARD) -> void:
	if player_compendium == null or join_address_editor_open or controls_editor.is_open or spell_loom_editor.is_open or _character_gallery_open():
		return
	player_compendium.open_panel(selected_tab, player_preferences, _local_player_state(), device)
	expanded_station_id = ""
	controls_input_guard_frames = 2
	queue_redraw()


func _character_gallery_open() -> bool:
	return character_selection_grid != null and character_selection_grid.is_open


func _gameplay_input_blocked() -> bool:
	return not application_input_active or join_address_editor_open or (controls_editor != null and controls_editor.is_open) or (spell_loom_editor != null and spell_loom_editor.is_open) or (player_compendium != null and player_compendium.is_open) or _character_gallery_open() or controls_input_guard_frames > 0


func _sample_gameplay_command(tick: int, player_position: Vector2, pointer_position: Vector2, controls_blocking: bool) -> SimCommand:
	if controls_blocking or not application_input_active:
		input_router.discard_transient_movement_input()
		return SimCommand.new(tick, input_router.entity_id, 0, 0, 0, 0, input_router.last_quantized_aim.x, input_router.last_quantized_aim.y)
	return input_router.sample(tick, player_position, pointer_position)


static func gallery_modal_command(command: SimCommand, gallery_open: bool) -> SimCommand:
	if not gallery_open:
		return command
	return SimCommand.new(command.tick, command.entity_id, 0, 0, 0, 0, command.aim_x, command.aim_y)


func _open_character_gallery() -> void:
	if character_selection_grid == null or join_address_editor_open or controls_editor.is_open or spell_loom_editor.is_open or player_compendium.is_open:
		return
	var state := _local_player_state()
	if state == null:
		return
	character_selection_grid.open_panel(champion_catalog.champion_id_from_wire(state.champion_wire_id))
	expanded_station_id = ""
	controls_input_guard_frames = 2
	input_router.discard_transient_movement_input()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	queue_redraw()


func _handle_character_gallery_input(event: InputEvent) -> void:
	var pointer := get_viewport().get_mouse_position() / _compendium_scale()
	if event is InputEventMouse:
		pointer = event.position / _compendium_scale()
	var requested_wire := character_selection_grid.handle_event(event, ThemeDB.fallback_font, pointer)
	if requested_wire > 0:
		_submit_session_request(SessionTransport.REQUEST_CHAMPION_SELECT, requested_wire)
	controls_input_guard_frames = 2
	input_router.discard_transient_movement_input()
	get_viewport().set_input_as_handled()
	queue_redraw()


func _compendium_scale() -> float:
	# A small window still fits the full reading page; the gameplay HUD keeps
	# its independent scaling policy.
	var viewport_size := get_viewport_rect().size
	return maxf(0.25, minf(viewport_size.x / 1280.0, viewport_size.y / 720.0))


func _close_controls_editor() -> void:
	if controls_editor == null:
		return
	controls_editor.close_editor()
	controls_input_guard_frames = 2
	station_notice = "Controls saved."
	station_notice_seconds = 1.5


func _submit_spell_loom_choice() -> void:
	if spell_loom_editor == null or not spell_loom_editor.is_open or not pending_weave_request.is_empty(): return
	var actor := _local_player_state()
	if actor == null: return
	var request_value := spell_loom_editor.request_value()
	var slot := SpellLoomEditor.decode_slot_index(request_value)
	var wire := SpellLoomEditor.wire_id_for_library_index(SpellLoomEditor.decode_library_index(request_value))
	if slot < 0 or wire <= 0: return
	var requested := actor.spell_wire_ids.duplicate()
	var previous := requested.find(wire)
	if previous >= 0: requested[previous] = requested[slot]
	requested[slot] = wire
	_submit_whole_weave(actor, actor.spell_wire_ids, requested, CharacterWeaveLibrary.MODE_CUSTOM, true)


func _close_spell_loom_editor() -> void:
	if spell_loom_editor == null:
		return
	spell_loom_editor.close_editor()
	controls_input_guard_frames = 2
	station_notice = "Spell setup closed."
	station_notice_seconds = 1.5


func _commit_control_bindings() -> void:
	var applied := (
		input_router.configure_keyboard_bindings(player_preferences.keyboard_bindings)
		and input_router.configure_mouse_bindings(player_preferences.mouse_bindings)
		and input_router.configure_controller_bindings(player_preferences.controller_bindings)
	)
	if not applied:
		controls_editor.status_message = "Binding rejected; safe runtime map retained."
		return
	if not _save_player_preferences_if_persistent():
		controls_editor.status_message = "Binding works now but could not be saved."
		push_warning(player_preferences.last_error)


func _adjust_sound_volume(delta: int, toggle_mute: bool = false) -> void:
	if player_preferences == null:
		return
	var requested := player_preferences.sound_volume_percent + delta
	if toggle_mute:
		requested = 30 if player_preferences.sound_volume_percent == 0 else 0
	player_preferences.sound_volume_percent = clampi(requested, 0, 100)
	if element_audio != null:
		element_audio.set_volume(player_preferences.sound_volume_percent)
	controls_editor.status_message = "Local elemental sound %d%%. No positional enemy audio." % player_preferences.sound_volume_percent
	if not _save_player_preferences_if_persistent():
		controls_editor.status_message = "Sound changed now but could not be saved."


func _toggle_reduced_effects_preference() -> void:
	player_preferences.reduced_motion = not player_preferences.reduced_motion
	controls_editor.status_message = "Reduced effects %s; spell shape and timing stay complete." % ("on" if player_preferences.reduced_motion else "off")
	_commit_accessibility_preferences()


func _toggle_high_contrast_preference() -> void:
	player_preferences.high_contrast = not player_preferences.high_contrast
	controls_editor.status_message = "High contrast %s." % ("on" if player_preferences.high_contrast else "off")
	_commit_accessibility_preferences()


func _commit_accessibility_preferences() -> void:
	if not _apply_visual_accessibility_profile():
		controls_editor.status_message = visual_accessibility_filter.last_error
		return
	if not _save_player_preferences_if_persistent():
		controls_editor.status_message = "Accessibility works now but could not be saved."
		push_warning(player_preferences.last_error)


func _cycle_session_charter() -> void:
	if session_transport.is_online():
		station_notice = "Close Farflow before turning the charter."
	else:
		selected_charter_id = SessionCharter.next_id(selected_charter_id)
		authoritative_session.set_charter(selected_charter_id)
		station_notice = "%s is ready to seal." % SessionCharter.display_name(selected_charter_id).capitalize()
	station_notice_seconds = 2.5
	expanded_station_id = focused_station_id


func _activate_session_hearth() -> void:
	if not session_transport.is_online():
		station_notice = "Open or join Farflow before readying."
		station_notice_seconds = 2.5
		expanded_station_id = focused_station_id
		return
	var local_entity_id := session_transport.local_entity_id
	var action := SessionTransport.REQUEST_READY_TOGGLE
	if session_transport.is_host() and authoritative_session.hearth.is_ready(local_entity_id) and authoritative_session.can_start_practice():
		action = SessionTransport.REQUEST_PRACTICE_START
	_submit_session_request(action)
	expanded_station_id = focused_station_id


func _activate_session_ledger() -> void:
	if not session_transport.is_host():
		station_notice = "Only the Farflow host keeps the Company Ledger."
		station_notice_seconds = 2.5
		expanded_station_id = focused_station_id
		return
	var selected_entity_id := session_steward.cycle_guest(session_transport.host_roster())
	if selected_entity_id == 0:
		station_notice = "No connected guests are in the Ledger."
	else:
		station_notice = "%s is named for review; no action taken." % _session_guest_name(selected_entity_id)
	station_notice_seconds = 2.5
	expanded_station_id = focused_station_id


func _activate_session_parting() -> void:
	if not session_transport.is_host():
		station_notice = "Only the Farflow host may ring the Parting Bell."
		station_notice_seconds = 2.5
		expanded_station_id = focused_station_id
		return
	if not session_steward.reconcile_roster(session_transport.host_roster()):
		station_notice = "Name a connected guest at the Company Ledger first."
		station_notice_seconds = 2.5
		expanded_station_id = focused_station_id
		return
	var selected_entity_id := session_steward.selected_entity_id
	var selected_name := _session_guest_name(selected_entity_id)
	var decision := session_steward.request_release(world.tick, world.config.milliseconds_to_ticks(STEWARD_CONFIRMATION_MS))
	if decision == SessionSteward.Decision.ARMED:
		station_notice = "Press %s again within three seconds to release %s." % [_station_interact_label(), selected_name]
	elif decision == SessionSteward.Decision.CONFIRMED:
		if session_transport.host_remove_entity(selected_entity_id, GUEST_RELEASE_REASON):
			station_notice = "%s is leaving the company." % selected_name
			print("FLUX2 farflow steward: host released entity %d (%s)" % [selected_entity_id, selected_name])
		else:
			station_notice = "%s could not be released; the roster changed." % selected_name
	else:
		station_notice = "The Parting Bell would not arm."
	station_notice_seconds = 3.0
	expanded_station_id = focused_station_id


func _toggle_host_session() -> void:
	if interception_practice_active or world.hex_court != null:
		_start_match(tick_rate)
	if session_transport.is_host():
		var decision := session_steward.request_close(world.tick, world.config.milliseconds_to_ticks(STEWARD_CONFIRMATION_MS))
		if decision == SessionSteward.Decision.ARMED:
			station_notice = "Press %s again within three seconds to close the company." % _station_interact_label()
		elif decision == SessionSteward.Decision.CONFIRMED:
			_begin_host_close()
		else:
			station_notice = "The Host Farflow seal would not arm."
		station_notice_seconds = 3.0
		expanded_station_id = focused_station_id
		return
	if session_transport.mode != SessionTransport.Mode.OFFLINE:
		station_notice = "Use Join Farflow to leave the host company."
		station_notice_seconds = 2.5
		expanded_station_id = focused_station_id
		return
	var signature := _session_compatibility_signature()
	if signature.is_empty():
		station_notice = session_transport.last_error
		station_notice_seconds = 5.0
		return
	session_steward.reset()
	host_close_pending = false
	if session_transport.start_host(session_port, signature, local_player_name, selected_charter_id, SessionCharter.profile_hash(selected_charter_id)):
		authoritative_session.bind(world, champion_catalog, campus_layout.spawn, local_player_name, [], selected_charter_id)
		session_names_by_entity = authoritative_session.names_by_entity.duplicate()
		station_notice = "Friend gate %s open on UDP %d." % [session_transport.build_id, session_port]
		print("FLUX2 farflow host: listening on UDP %d · %s · %d places" % [session_transport.bound_port, SessionCharter.display_name(selected_charter_id), session_transport.player_capacity()])
	else:
		station_notice = session_transport.last_error
	station_notice_seconds = 3.0
	expanded_station_id = focused_station_id


func _toggle_join_session() -> void:
	if session_transport.is_host():
		station_notice = "Use Host Farflow to close the company."
		station_notice_seconds = 2.5
		expanded_station_id = focused_station_id
		return
	if session_transport.mode != SessionTransport.Mode.OFFLINE:
		_return_to_offline("You left the Farflow company.")
	else:
		_open_join_address_editor()
	expanded_station_id = focused_station_id


func _open_join_address_editor() -> void:
	join_address_editor_open = true
	join_address_editor_text = join_address
	join_address_editor_replace_on_type = true
	join_address_editor_error = ""
	station_notice = ""
	station_notice_seconds = 0.0
	expanded_station_id = focused_station_id


func _close_join_address_editor(notice: String = "") -> void:
	join_address_editor_open = false
	join_address_editor_error = ""
	join_address_editor_replace_on_type = false
	controls_input_guard_frames = 2
	if not notice.is_empty():
		station_notice = notice
		station_notice_seconds = 1.5


func _commit_join_address_and_seek() -> void:
	var requested := join_address_editor_text.strip_edges()
	if not PlayerPreferences.is_valid_farflow_join_address(requested):
		join_address_editor_error = "Use one host name or IP; no spaces, /, or \\."
		return
	join_address = requested
	player_preferences.farflow_join_address = requested
	var persisted := _save_player_preferences_if_persistent()
	_close_join_address_editor()
	if not persisted:
		station_notice = "Seeking now; this PC could not save the address."
		station_notice_seconds = 3.0
	_start_join_session_now()


func _start_join_session_now() -> void:
	if interception_practice_active or world.hex_court != null:
		_start_match(tick_rate)
	var signature := _session_compatibility_signature()
	if signature.is_empty():
		station_notice = session_transport.last_error
		station_notice_seconds = 5.0
		return
	if session_transport.start_join(join_address, session_port, signature, local_player_name, SessionCharter.catalog_hash()):
		station_notice = "%s · Seeking %s:%d." % [session_transport.build_id, join_address, session_port]
		print("FLUX2 farflow join: seeking %s:%d" % [join_address, session_port])
	else:
		station_notice = session_transport.last_error
	station_notice_seconds = 3.0
	expanded_station_id = focused_station_id


func _begin_host_close() -> void:
	if not session_transport.is_host() or host_close_pending:
		return
	var roster := session_transport.host_roster()
	if roster.is_empty():
		_finish_host_close()
		return
	host_close_pending = true
	var requested_count := 0
	for entry: Dictionary in roster:
		if session_transport.host_remove_entity(int(entry.get("entity_id", 0)), COMPANY_CLOSE_REASON):
			requested_count += 1
	if requested_count != roster.size():
		host_close_pending = false
		station_notice = "Farflow changed while closing; confirm again."
		return
	station_notice = "The company is closing after every guest receives word."
	print("FLUX2 farflow steward: host closing company with %d guest(s)" % requested_count)


func _finish_host_close() -> void:
	host_close_pending = false
	_return_to_offline("The Farflow company is closed.")
	print("FLUX2 farflow steward: company closed cleanly")


func _request_safe_quit(source: String) -> void:
	if safe_quit_pending:
		return
	safe_quit_pending = true
	safe_quit_deadline_ms = Time.get_ticks_msec() + SAFE_QUIT_GRACE_MS
	if player_preferences != null and not _save_player_preferences_if_persistent():
		push_warning(player_preferences.last_error)
	var notified_guests: int = 0
	if session_transport != null and session_transport.is_host():
		for entry: Dictionary in session_transport.host_roster():
			if session_transport.host_remove_entity(int(entry.get("entity_id", 0)), APPLICATION_CLOSE_REASON):
				notified_guests += 1
	print("FLUX2 safe quit: %s requested; notified %d guest(s)" % [source, notified_guests])
	_advance_safe_quit()


func _advance_safe_quit() -> void:
	if not safe_quit_pending:
		return
	if (
		session_transport != null
		and session_transport.is_host()
		and not session_transport.host_roster().is_empty()
		and Time.get_ticks_msec() < safe_quit_deadline_ms
	):
		return
	if session_transport != null:
		session_transport.stop()
	safe_quit_pending = false
	set_process(false)
	print("FLUX2 safe quit: local state flushed and network peer closed")
	get_tree().quit(0)


func _return_to_offline(notice: String) -> void:
	session_transport.stop()
	session_steward.reset()
	client_replica_active = false
	client_input_sequence = 0
	client_request_sequence = 0
	last_client_snapshot_tick = -1
	network_projectile_overflow = 0
	if _start_match(tick_rate):
		station_notice = notice
		station_notice_seconds = 3.0


func _session_guest_name(entity_id: int) -> String:
	for entry: Dictionary in session_transport.host_roster():
		if int(entry.get("entity_id", 0)) == entity_id:
			return String(entry.get("name", "Traveller")).left(SessionTransport.MAX_PLAYER_NAME_LENGTH)
	return "Traveller %d" % entity_id


static func _roster_has_entity(roster: Array[Dictionary], entity_id: int) -> bool:
	if entity_id < 2 or entity_id > SessionTransport.MAX_PLAYERS:
		return false
	for entry: Dictionary in roster:
		if int(entry.get("entity_id", 0)) == entity_id and int(entry.get("peer_id", 0)) > SessionTransport.SERVER_PEER_ID:
			return true
	return false


func _session_compatibility_signature() -> String:
	if not _ensure_runtime_identity():
		return ""
	return SessionTransport.compatibility_signature(
		SimConfig.PROTOCOL_VERSION,
		tick_rate,
		campus_layout.content_hash,
		ability_catalog.content_hash,
		champion_catalog.content_hash,
		SessionCharter.catalog_hash(),
		reaction_definitions.content_hash,
		session_transport.runtime_source_sha256,
	)


func _ensure_runtime_identity() -> bool:
	if session_transport == null:
		return false
	if not session_transport.build_id.is_empty():
		return true
	var identity := RuntimeBuildIdentity.load_current(SimConfig.PROTOCOL_VERSION, SessionSnapshot.SCHEMA_VERSION)
	if not bool(identity.get("ok", false)):
		session_transport.last_error = "Build identity unavailable. Extract the same complete portable ZIP into a new folder and launch it directly."
		return false
	return session_transport.configure_runtime_identity(identity["manifest"])


func _selected_session_capacity() -> int:
	return session_transport.player_capacity() if session_transport.is_online() else SessionCharter.maximum_players(selected_charter_id)


func _session_label() -> String:
	return _session_base_label()


func _session_feedback_label() -> String:
	return "FEEDBACK BUSY" if network_event_overflow_notice_seconds > 0.0 else ""


func _apply_snapshot_overflow(overflow: PackedInt32Array) -> void:
	network_projectile_overflow = overflow[0]
	network_event_overflow = overflow[2]


func _update_network_feedback_notice(delta: float) -> void:
	if session_transport == null or not session_transport.is_online():
		network_event_overflow = 0
		network_event_overflow_notice_seconds = 0.0
		return
	network_event_overflow_notice_seconds = maxf(0.0, network_event_overflow_notice_seconds - delta)
	var queue_trims := network_event_overflow
	if session_transport.is_host() and authoritative_session != null:
		queue_trims = authoritative_session.pending_combat_event_overflow_count
	if queue_trims > 0:
		# Pressure does not prove which feedback an individual traveller missed.
		network_event_overflow_notice_seconds = 2.0


func _session_base_label() -> String:
	if session_transport == null or session_transport.mode == SessionTransport.Mode.OFFLINE:
		return "FARFLOW RETURN READY" if session_transport != null and session_transport.can_reconnect() else "FARFLOW OFFLINE"
	var round_label := _round_label()
	if not round_label.is_empty():
		return round_label
	var hearth_state := SessionHearth.decoded(_current_hearth_values())
	var countdown_ticks := int(hearth_state.get("countdown_ticks", 0))
	if countdown_ticks > 0:
		var next_round := int(_current_round_state().get("serial", 0)) + 1
		return "ROUND %d IN %.1fs · FIRST 3 · 90s" % [next_round, float(countdown_ticks) / float(maxi(1, tick_rate))]
	if session_transport.is_connected_client() and network_projectile_overflow > 0:
		return "FARFLOW LOAD +%d BOLTS" % network_projectile_overflow
	if session_transport.is_host():
		return "FARFLOW HOST %d/%d · %s" % [session_transport.player_count(), session_transport.player_capacity(), session_transport.build_id]
	if session_transport.is_connected_client():
		if client_prediction != null and client_prediction.is_ready():
			return "FARFLOW JOINED · ACK ~%dms · CORR %.1fpx" % [client_prediction.estimated_ack_delay_ms(), client_prediction.last_correction_pixels]
		return "FARFLOW JOINED · SYNCING"
	return "FARFLOW SEEKING · %s" % join_address


func _current_round_values() -> PackedInt32Array:
	if session_transport.is_host() and authoritative_session != null and authoritative_session.session_round != null:
		return authoritative_session.session_round.capture(world)
	return session_round_values


func _current_round_state() -> Dictionary:
	return SessionRound.decoded(_current_round_values())


func _round_label() -> String:
	var state := _current_round_state()
	var phase := int(state.get("phase", SessionRound.Phase.HEARTH))
	if phase == SessionRound.Phase.HEARTH:
		return ""
	var entries: Array = (state.get("entries", []) as Array).duplicate(true)
	entries.sort_custom(
		func(left_value: Variant, right_value: Variant) -> bool:
			var left: Dictionary = left_value
			var right: Dictionary = right_value
			var left_score := int(left.get("score", 0))
			var right_score := int(right.get("score", 0))
			return left_score > right_score if left_score != right_score else int(left.get("entity_id", 0)) < int(right.get("entity_id", 0))
	)
	var score_parts: Array[String] = []
	for index: int in range(mini(entries.size(), 4)):
		var entry: Dictionary = entries[index]
		var entity_id := int(entry.get("entity_id", 0))
		var name := String(session_names_by_entity.get(entity_id, "P%d" % entity_id)).left(9).to_upper()
		score_parts.append("%s %d" % [name, int(entry.get("score", 0))])
	if entries.size() > 4:
		score_parts.append("+%d" % (entries.size() - 4))
	var score_line := " · ".join(score_parts)
	var seconds := ceili(float(int(state.get("remaining_ticks", 0))) / float(maxi(1, tick_rate)))
	if phase == SessionRound.Phase.ACTIVE:
		return "COURT · %s · %ds · FIRST %d" % [score_line, seconds, int(state.get("score_limit", 0))]
	var winner_id := int(state.get("winner_entity_id", 0))
	return "DRAW · HEARTH IN %ds" % seconds if winner_id == 0 else "%s WINS · HEARTH IN %ds" % [String(session_names_by_entity.get(winner_id, "TRAVELLER")).left(12).to_upper(), seconds]


func _current_hearth_values() -> PackedInt32Array:
	if session_transport.is_host() and authoritative_session != null and authoritative_session.hearth != null:
		return authoritative_session.hearth.capture(world.tick, session_transport.player_capacity())
	return session_hearth_values


func _session_hearth_lines() -> Array:
	if not session_transport.is_online():
		return [
			"FARFLOW IS CLOSED",
			"%s · %d PLACES" % [SessionCharter.display_name(selected_charter_id), SessionCharter.maximum_players(selected_charter_id)],
			"Open or join a friend gate first",
		]
	var values := _current_hearth_values()
	var hearth_state := SessionHearth.decoded(values)
	if hearth_state.is_empty():
		return ["HEARTH STATE UNAVAILABLE"]
	var entries: Array = hearth_state.get("entries", [])
	var connected: int = 0
	var returning: int = 0
	for entry_value: Variant in entries:
		var entry: Dictionary = entry_value
		if int(entry.get("status", 0)) == SessionHearth.STATUS_CONNECTED:
			connected += 1
		else:
			returning += 1
	var countdown_ticks := int(hearth_state.get("countdown_ticks", 0))
	var completed_rounds := int(_current_round_state().get("serial", 0))
	var lines: Array = []
	if countdown_ticks > 0:
		lines.append("ROUND %d IN %.1fs · FIRST 3 · 90s" % [completed_rounds + 1, float(countdown_ticks) / float(tick_rate)])
	elif completed_rounds > 0:
		lines.append("REMATCH ROUND %d · %d/%d HERE" % [completed_rounds + 1, connected, int(hearth_state.get("maximum_players", 0))])
	else:
		lines.append("%s · %d/%d HERE%s" % [SessionCharter.display_name(selected_charter_id), connected, int(hearth_state.get("maximum_players", 0)), " · %d RETURNING" % returning if returning > 0 else ""])
	var visible_entries := mini(entries.size(), 4)
	for index: int in range(visible_entries):
		var entry: Dictionary = entries[index]
		var entity_id := int(entry.get("entity_id", 0))
		var state_label := "RETURNING" if int(entry.get("status", 0)) == SessionHearth.STATUS_RETURNING else ("READY" if bool(entry.get("ready", false)) else "WAITING")
		lines.append("%s · %s" % [String(session_names_by_entity.get(entity_id, "Traveller %d" % entity_id)).left(24), state_label])
	if entries.size() > visible_entries:
		lines.append("+%d MORE · ALL MUST READY" % (entries.size() - visible_entries))
	elif countdown_ticks <= 0:
		var action_line := _station_interact_instruction("toggles ready")
		if session_transport.is_host() and authoritative_session.can_start_practice():
			action_line = "HOST %s" % _station_interact_instruction("begins round %d" % (completed_rounds + 1))
		lines.append(action_line)
	return lines


func _session_ledger_lines() -> Array:
	if not session_transport.is_host():
		return ["HOST STEWARDSHIP ONLY", "Open Host Farflow to keep a company Ledger"]
	var roster := session_transport.host_roster()
	if roster.is_empty():
		return ["NO CONNECTED GUESTS", "Returning reservations are never selectable"]
	var selected_id := session_steward.selected_entity_id
	var selected_line := "NONE NAMED · %s" % _station_interact_instruction("SELECTS FIRST")
	if _roster_has_entity(roster, selected_id):
		selected_line = "NAMED: %s" % _session_guest_name(selected_id).to_upper()
	return [
		"%d CONNECTED GUEST%s" % [roster.size(), "" if roster.size() == 1 else "S"],
		selected_line,
		_station_interact_instruction("selects the next connected traveller"),
		"Selection alone takes no action",
	]


func _session_parting_lines() -> Array:
	if not session_transport.is_host():
		return ["HOST STEWARDSHIP ONLY", "Guests cannot ring this Bell"]
	var roster := session_transport.host_roster()
	if not _roster_has_entity(roster, session_steward.selected_entity_id):
		return ["NO TRAVELLER NAMED", "Use the Company Ledger first", "One press can never dismiss a guest"]
	var selected_id := session_steward.selected_entity_id
	var selected_name := _session_guest_name(selected_id).to_upper()
	if session_steward.is_armed(SessionSteward.Action.RELEASE_GUEST, selected_id, world.tick):
		var remaining_seconds := float(session_steward.remaining_ticks(world.tick)) / float(maxi(1, tick_rate))
		return ["CONFIRM RELEASE: %s" % selected_name, _station_interact_instruction("confirms · %.1fs remain" % remaining_seconds), "No return reservation will remain"]
	return ["NAMED: %s" % selected_name, _station_interact_instruction("arms a three-second release"), "A second matching press must confirm"]


func _start_requested_farflow() -> void:
	match requested_farflow_mode:
		"host":
			_toggle_host_session()
		"join":
			_start_join_session_now()


func _draw_pov_mask(origin: Vector2, aim: Vector2, camera_origin: Vector2) -> void:
	if player_preferences.pov_mode != PlayerPreferences.POV_CONE:
		return
	var zoom := _camera_zoom_scale()
	var sight_range: float = float(player_preferences.pov_range) * zoom
	var viewport_size: Vector2 = get_viewport_rect().size
	var segment_count: int = SightOcclusion.MASK_SEGMENTS
	var outer_radius: float = SightOcclusion.projected_viewport_cover_radius(origin, get_viewport_rect())
	# A screen-covering range needs no outer annulus. The chord margin also
	# prevents tiny corner gaps and avoids reversed inner/outer mask radii.
	if sight_range < outer_radius:
		for segment: int in range(segment_count):
			var angle_a: float = TAU * float(segment) / float(segment_count)
			var angle_b: float = TAU * float(segment + 1) / float(segment_count)
			_draw_mask_quad(origin, sight_range, outer_radius, angle_a, angle_b)

	var visible_radians: float = deg_to_rad(float(player_preferences.pov_angle_degrees))
	var aim_angle: float = SightOcclusion.ground_aim_angle(aim)
	var half_visible: float = visible_radians * 0.5
	if player_preferences.pov_angle_degrees < PlayerPreferences.MAX_POV_ANGLE_DEGREES:
		var hidden_span: float = TAU - visible_radians
		var hidden_segments: int = maxi(1, ceili(float(segment_count) * hidden_span / TAU))
		var hidden_start: float = aim_angle + half_visible
		var player_safe_radius: float = SightOcclusion.REAR_AWARENESS_RADIUS * zoom
		for segment: int in range(hidden_segments):
			var angle_a: float = hidden_start + hidden_span * float(segment) / float(hidden_segments)
			var angle_b: float = hidden_start + hidden_span * float(segment + 1) / float(hidden_segments)
			_draw_mask_quad(origin, player_safe_radius, sight_range, angle_a, angle_b)
		draw_line(origin + SightOcclusion.project_ground(Vector2.from_angle(aim_angle - half_visible) * player_safe_radius), origin + SightOcclusion.project_ground(Vector2.from_angle(aim_angle - half_visible) * sight_range), POV_EDGE_COLOR, 1.5)
		draw_line(origin + SightOcclusion.project_ground(Vector2.from_angle(aim_angle + half_visible) * player_safe_radius), origin + SightOcclusion.project_ground(Vector2.from_angle(aim_angle + half_visible) * sight_range), POV_EDGE_COLOR, 1.5)
	# Keep building shadow reach unchanged; distant walls are not radial masks.
	_draw_building_occlusion_shadows(origin, camera_origin, maxf(outer_radius, maxf(viewport_size.x, viewport_size.y) * 2.25))
	draw_polyline(SightOcclusion.projected_arc(origin, sight_range, aim_angle - half_visible, aim_angle + half_visible, maxi(12, ceili(48.0 * visible_radians / TAU))), POV_EDGE_COLOR, 1.5)


func _draw_building_occlusion_shadows(origin: Vector2, camera_origin: Vector2, outer_distance: float) -> void:
	for building_value: Variant in campus_layout.data.get("buildings", []):
		var building: Dictionary = building_value
		if String(building.get("occlusion_policy", "")) != "los_cutaway":
			continue
		var world_bounds := SanctumCampusLayout._parse_bounds(building.get("bounds", []))
		var zoom := _camera_zoom_scale()
		var screen_bounds := Rect2((Vector2(world_bounds.position) - camera_origin) * zoom, Vector2(world_bounds.size) * zoom)
		var shadow := SightOcclusion.shadow_polygon(origin, screen_bounds, outer_distance)
		if shadow.size() != 4:
			continue
		draw_colored_polygon(shadow, POV_MASK_COLOR)
		draw_line(shadow[0], shadow[1], POV_EDGE_COLOR, 1.0)
		draw_line(shadow[3], shadow[2], POV_EDGE_COLOR, 1.0)


func _draw_mask_quad(origin: Vector2, inner_radius: float, outer_radius: float, angle_a: float, angle_b: float) -> void:
	var points := SightOcclusion.projected_mask_quad(origin, inner_radius, outer_radius, angle_a, angle_b)
	draw_colored_polygon(points, POV_MASK_COLOR)


func _pov_observer_ground_position(observer: PlayerState, spectating: bool, rendered_local: Vector2) -> Vector2:
	if not spectating:
		return rendered_local
	var motion_alpha := clampf(remote_snapshot_age_seconds * 60.0 if session_transport.is_connected_client() else accumulator_seconds * float(tick_rate), 0.0, 1.0)
	var point := actor_motion_history.sample(observer, motion_alpha)
	return Vector2(point.x, point.y)


func _pov_observer_overlay_frame(visual_tick: float, alpha: float) -> Dictionary:
	if world == null or player_preferences == null or player_preferences.pov_mode != PlayerPreferences.POV_CONE or cartoon_champion_presenter == null:
		return {}
	var spectating := _is_spectating()
	var observer := _spectator_state() if spectating else _local_player_state()
	# The exemption belongs only to the living viewpoint owner. Never redraw a
	# hidden third party or the dead local avatar during spectating.
	if observer == null or observer.health <= 0 or observer.actor_kind != PlayerState.ActorKind.CHAMPION:
		return {}
	var pose_state := observer
	if not spectating and session_transport.is_connected_client() and client_prediction.is_ready():
		pose_state = client_prediction.predicted_state
	var pose_alpha := alpha
	var previous_height := previous_air_height
	if spectating:
		pose_alpha = clampf(remote_snapshot_age_seconds * 60.0 if session_transport.is_connected_client() else accumulator_seconds * float(tick_rate), 0.0, 1.0)
		previous_height = actor_motion_history.previous_height(observer)
	var ground := _pov_observer_ground_position(observer, spectating, previous_position.lerp(current_position, alpha))
	var shadow_center := ground + Vector2(0.0, float(MovementTuning.PLAYER_RADIUS) / 1000.0 * 0.58)
	var jump := JumpPresentation.sample(pose_state, world.config, pose_alpha, _reduced_effects_enabled(), previous_height)
	var champion_id := _champion_visual_id(observer)
	var frame := cartoon_champion_presenter.movement_frame(champion_id, pose_state, visual_tick, world.config, _reduced_effects_enabled(), actor_motion_history.gait_phase(pose_state.entity_id))
	if frame.is_empty():
		return {}
	var texture: Texture2D = frame.get("texture", cartoon_champion_presenter.texture_for_champion(champion_id))
	if texture == null:
		return {}
	var anchor := shadow_center + Vector2(0.0, -float(jump.body_lift_pixels)) + (frame["offset"] as Vector2)
	return {"texture": texture, "source_region": frame["source_region"], "destination": Rect2(anchor - CartoonChampionPresenter.PIVOT, CartoonChampionPresenter.CELL_SIZE), "observer_id": observer.entity_id}


func _draw_pov_observer_body(camera_origin: Vector2, visual_tick: float, alpha: float) -> void:
	var frame := _pov_observer_overlay_frame(visual_tick, alpha)
	if frame.is_empty():
		return
	# Repaint only the exact binary-alpha owned body pixels. Ground shadows,
	# afterimages, spells and world objects stay under the cone/obstacle mask.
	_set_world_transform(camera_origin)
	draw_texture_rect_region(frame["texture"], frame["destination"], frame["source_region"])
	draw_set_transform(Vector2.ZERO)


func _pov_opaque_bounds() -> Array[Rect2]:
	var bounds: Array[Rect2] = []
	if campus_layout == null:
		return bounds
	for value: Variant in campus_layout.data.get("buildings", []):
		var building: Dictionary = value
		if String(building.get("occlusion_policy", "")) == "los_cutaway":
			bounds.append(Rect2(SanctumCampusLayout._parse_bounds(building.get("bounds", []))))
	return bounds


func _draw_material_yard_preview() -> void:
	if material_preview_texture == null or material_grid == null:
		return
	var panel := Rect2(1082, 492, 174, 194)
	draw_rect(panel, PANEL_COLOR, true)
	draw_rect(panel, BRASS_COLOR.darkened(0.25), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(1094, 515), "MATERIAL YARD F1", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, PARCHMENT_COLOR)
	draw_texture_rect(material_preview_texture, Rect2(1105, 526, 128, 128), false)
	draw_rect(Rect2(1105, 526, 128, 128), PALE_STONE_COLOR.darkened(0.2), false, 2.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(1094, 675),
		"SEED %s · WB %s" % [material_grid.seed_state_hash.left(6), material_grid.seed_worldbone_hash.left(6)],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		11,
		ATTUNEMENT_COLOR,
	)


func _restart_shared_seed(requested_tick_rate: int) -> bool:
	if session_transport == null or not session_transport.is_host():
		return _start_match(requested_tick_rate)
	var attunements := _champion_attunements()
	var continuous_tick := world.tick
	var continuous_event_id := authoritative_session.next_event_id
	var continuous_round_serial := authoritative_session.session_round.serial
	if not _start_match(requested_tick_rate):
		return false
	world.tick = continuous_tick
	authoritative_session.next_event_id = continuous_event_id
	authoritative_session.session_round.serial = continuous_round_serial
	_restore_champion_attunements(attunements)
	return true


func _begin_shared_practice() -> bool:
	if not _restart_shared_seed(tick_rate):
		return false
	if not authoritative_session.begin_round(campus_layout.arena_definition):
		return false
	session_round_values = authoritative_session.session_round.capture(world)
	current_position = _player_position()
	previous_position = current_position
	_publish_session_event({"type": "practice_started", "entity_id": SessionTransport.SERVER_PEER_ID})
	_reset_motion_history()
	if requested_steward_smoke and authoritative_session.session_round.serial == 2:
		steward_smoke_due_tick = world.tick + world.config.milliseconds_to_ticks(250)
	station_notice = "The Proving Court opens. First to three."
	station_notice_seconds = 2.0
	print("FLUX2 farflow hearth: Proving Court round started at host tick %d" % world.tick)
	return true


func _update_steward_smoke() -> void:
	if not requested_steward_smoke or steward_smoke_sent or steward_smoke_due_tick < 0 or world.tick < steward_smoke_due_tick:
		return
	var roster := session_transport.host_roster()
	if roster.is_empty():
		return
	var selected_entity_id := session_steward.cycle_guest(roster)
	var confirmation_ticks := world.config.milliseconds_to_ticks(STEWARD_CONFIRMATION_MS)
	var armed := session_steward.request_release(world.tick, confirmation_ticks)
	var confirmed := session_steward.request_release(world.tick, confirmation_ticks)
	if (
		selected_entity_id > 0
		and armed == SessionSteward.Decision.ARMED
		and confirmed == SessionSteward.Decision.CONFIRMED
		and session_transport.host_remove_entity(selected_entity_id, GUEST_RELEASE_REASON)
	):
		steward_smoke_sent = true
		print("FLUX2 farflow steward smoke: confirmed release sent for entity %d" % selected_entity_id)
		return
	push_error("FLUX2 farflow steward smoke failed to confirm release")
	steward_smoke_sent = true


func _return_to_hearth() -> bool:
	if not _restart_shared_seed(tick_rate):
		return false
	if not _arrange_hearth_roster():
		return false
	session_round_values = authoritative_session.session_round.capture(world)
	current_position = _player_position()
	previous_position = current_position
	_publish_session_event({"type": "round_returning", "entity_id": SessionTransport.SERVER_PEER_ID})
	_reset_motion_history()
	if requested_rematch_smoke:
		_handle_session_requests([{
			"entity_id": SessionTransport.SERVER_PEER_ID,
			"action": SessionTransport.REQUEST_READY_TOGGLE,
		}])
		print("FLUX2 farflow rematch smoke: host gathered and ready for round 2")
	station_notice = "The company returns to the Hearth."
	station_notice_seconds = 2.5
	print("FLUX2 farflow hearth: company returned at host tick %d" % world.tick)
	return true


func _arrange_hearth_roster() -> bool:
	var station: Dictionary = campus_layout.stations_by_id.get("session-hearth", {})
	var gather_spawns: Array = station.get("gather_spawns", [])
	var ordered: Array[PlayerState] = []
	for state: PlayerState in world.players:
		if state.actor_kind == PlayerState.ActorKind.CHAMPION:
			ordered.append(state)
	ordered.sort_custom(func(left: PlayerState, right: PlayerState) -> bool: return left.entity_id < right.entity_id)
	if gather_spawns.size() < ordered.size():
		return false
	for index: int in range(ordered.size()):
		var state := ordered[index]
		var position_values: Array = gather_spawns[index]
		var gather_position := Vector2i(int(position_values[0]), int(position_values[1])) * SimConfig.FIXED_SCALE
		if not world.collision.can_occupy(gather_position, MovementTuning.PLAYER_RADIUS):
			return false
		state.position_x = gather_position.x
		state.position_y = gather_position.y
		state.velocity_x = 0
		state.velocity_y = 0
		state.last_event = "hearth_gathered"
	return true


func _start_match(requested_tick_rate: int) -> bool:
	_ensure_character_weaves()
	if world != null and world.hex_court == null and not interception_practice_active:
		for previous_actor: PlayerState in world.players:
			if previous_actor.actor_kind == PlayerState.ActorKind.CHAMPION: character_weaves.remember_actor(previous_actor)
	pending_weave_request.clear()
	client_weave_restore_champion = 0
	interception_practice_active = false
	interception_practice_setup = {}
	interception_feedback.clear()
	network_event_overflow = 0
	network_event_overflow_notice_seconds = 0.0
	_close_controls_editor()
	_close_spell_loom_editor()
	focused_station_id = ""
	expanded_station_id = ""
	station_notice = ""
	station_notice_seconds = 0.0
	if spectator_focus != null:
		spectator_focus.reset()
	emote_ready_tick_by_entity = {}
	social_bubbles = []
	combat_cues = []
	if client_prediction != null:
		client_prediction.reset()
	if session_event_inbox != null:
		session_event_inbox.reset()
	prediction_smoke_started = false
	prediction_smoke_inputs_sent = 0
	prediction_smoke_start_x = 0.0
	prediction_smoke_reported = false
	tick_rate = requested_tick_rate
	world = SimWorld.new(
		tick_rate,
		8675309,
		campus_layout.build_collision_world(),
		String(campus_layout.data.get("id", "")),
		campus_layout.content_hash,
	)
	var player_state: PlayerState = world.player()
	var initial_position := campus_layout.spawn
	if capture_spawn_world.x >= 0 and world.collision.can_occupy(capture_spawn_world * SimConfig.FIXED_SCALE, MovementTuning.PLAYER_RADIUS):
		initial_position = capture_spawn_world
	player_state.position_x = initial_position.x * SimConfig.FIXED_SCALE
	player_state.position_y = initial_position.y * SimConfig.FIXED_SCALE
	if not champion_catalog.apply_to_player(player_state, selected_champion_id):
		push_error("Selected champion could not be applied: %s" % selected_champion_id)
		return false
	character_weaves.restore_actor(player_state, true)
	_spawn_practice_targets()
	var existing_roster: Array[Dictionary] = []
	if session_transport != null and session_transport.is_host():
		existing_roster = session_transport.host_session_roster()
	if not authoritative_session.bind(world, champion_catalog, campus_layout.spawn, local_player_name, existing_roster, selected_charter_id):
		push_error(authoritative_session.last_error)
		return false
	session_names_by_entity = authoritative_session.names_by_entity.duplicate()
	session_hearth_values = authoritative_session.hearth.capture(world.tick, SessionCharter.maximum_players(selected_charter_id))
	session_round_values = authoritative_session.session_round.capture(world)
	material_grid = MaterialGrid.new()
	if not material_grid.initialize(material_yard, material_registry, world.config):
		push_error(material_grid.last_error)
		return false
	_refresh_material_preview()
	input_router = InputRouter.new(1)
	if not input_router.configure_movement_reference(player_preferences.movement_reference):
		push_error("Invalid movement reference reached match startup")
		return false
	if not input_router.configure_keyboard_bindings(player_preferences.keyboard_bindings):
		push_error("Invalid keyboard bindings reached match startup")
		return false
	if not input_router.configure_mouse_bindings(player_preferences.mouse_bindings):
		push_error("Invalid mouse bindings reached match startup")
		return false
	if not input_router.configure_controller_bindings(player_preferences.controller_bindings):
		push_error("Invalid controller bindings reached match startup")
		return false
	accumulator_seconds = 0.0
	dropped_time_seconds = 0.0
	clamped_frame_time_seconds = 0.0
	current_position = _player_position()
	previous_position = current_position
	_reset_motion_history()
	print("FLUX2 match initialized at %d Hz" % tick_rate)
	return true


func _start_interception_trial() -> bool:
	if session_transport.mode != SessionTransport.Mode.OFFLINE:
		return false
	if not _start_match(tick_rate):
		return false
	var setup := InterceptionShowcase.configure(world, champion_catalog, ability_catalog, campus_layout)
	if setup.is_empty():
		station_notice = "The practice court could not be prepared."
		station_notice_seconds = 3.0
		return false
	interception_practice_setup = setup
	interception_practice_active = true
	authoritative_session.hearth.connect_entity(2)
	current_position = _player_position()
	previous_position = current_position
	_reset_motion_history()
	station_notice = "Water Spray · Earth Spray · Fire Bolt · Fire Rapid in your first four positions."
	station_notice_seconds = 4.0
	return true


func _start_hex_court() -> bool:
	if session_transport.mode != SessionTransport.Mode.OFFLINE:
		return false
	if not _start_match(tick_rate):
		return false
	if not preload("res://src/sim/hex/hex_court_practice.gd").configure(world, ability_catalog):
		return false
	current_position = _player_position()
	previous_position = current_position
	_reset_motion_history()
	return true


func _draw_hex_court_help() -> void:
	if _gameplay_input_blocked():
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _ui_scale())
	for item: Array in [[INTERCEPTION_START_RECT, "RESET HEX COURT"], [INTERCEPTION_LEAVE_RECT, "RETURN TO WELLSPRING"], [HEX_LOOM_RECT, "SPELL LOOM / STARTER KIT"], [HEX_CONTROLS_RECT, "CONTROLS / SETTINGS"], [HEX_GALLERY_RECT, "CHARACTERS / BODY SIZES"]]:
		draw_rect(item[0], PANEL_COLOR)
		draw_string(ThemeDB.fallback_font, (item[0] as Rect2).position + Vector2(10, 20), item[1], HORIZONTAL_ALIGNMENT_LEFT, 208, 12, PARCHMENT_COLOR)
	var exposure_ticks := int(world.hex_court.exposure.get(_local_player_state().entity_id, 0))
	draw_rect(Rect2(20, 164, 226, 46), PANEL_COLOR)
	draw_string(ThemeDB.fallback_font, Vector2(30, 183), "STEAM EXPOSURE %.1f / 2.0s" % (float(exposure_ticks) / 120.0), HORIZONTAL_ALIGNMENT_LEFT, 206, 12, PARCHMENT_COLOR)
	draw_rect(Rect2(30, 194, 206, 4), Color("4b524d"))
	draw_rect(Rect2(30, 194, 206.0 * float(exposure_ticks) / 240.0, 4), Color("f1c1a5"))
	var panel := Rect2(800, 90, 460, 190)
	draw_rect(panel, PANEL_COLOR)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(12, 22), "HEX COURT · CONTINUOUS MOVEMENT", HORIZONTAL_ALIGNMENT_LEFT, 416, 14, PARCHMENT_COLOR)
	var lines := preload("res://src/sim/hex/hex_court_practice.gd").help_lines()
	for index: int in lines.size():
		draw_string(ThemeDB.fallback_font, panel.position + Vector2(12, 46 + 19 * index), lines[index], HORIZONTAL_ALIGNMENT_LEFT, 436, 12, PARCHMENT_COLOR)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(12, 176), "Solo · Return for sessions · F4 Compendium", HORIZONTAL_ALIGNMENT_LEFT, 436, 12, ATTUNEMENT_COLOR)
	draw_set_transform(Vector2.ZERO)


func _spawn_practice_targets() -> void:
	var target_ids: Array[String] = campus_layout.practice_targets_by_id.keys()
	target_ids.sort()
	for target_id: String in target_ids:
		var definition: Dictionary = campus_layout.practice_targets_by_id[target_id]
		var target := PlayerState.new(int(definition.get("entity_id", 0)))
		target.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
		# Practice actors use their stable entity as a non-champion team so every
		# traveller can exercise combat in both social and sparring charters.
		target.team_id = target.entity_id
		var position_values: Array = definition.get("position", [])
		target.position_x = int(position_values[0]) * SimConfig.FIXED_SCALE
		target.position_y = int(position_values[1]) * SimConfig.FIXED_SCALE
		target.training_spawn_x = target.position_x
		target.training_spawn_y = target.position_y
		target.radius = int(definition.get("radius", 18)) * SimConfig.FIXED_SCALE
		target.health_maximum = int(definition.get("health", 80_000))
		target.health = target.health_maximum
		target.health_recovery_per_second = 0
		target.flux_maximum = 0
		target.flux = 0
		target.flux_recovery_per_second = 0
		target.stamina_maximum = 0
		target.stamina = 0
		target.stamina_recovery_per_second = 0
		target.movement_speed_ratio = 0
		target.last_event = "target_ready"
		world.players.append(target)


func _draw_practice_targets(camera_origin: Vector2) -> void:
	var target_definitions: Array[Dictionary] = []
	if world.hex_court != null:
		target_definitions.append({"entity_id": 2, "label": "HEX PRACTICE TARGET"})
	else:
		for target_id: String in campus_layout.practice_targets_by_id:
			target_definitions.append(campus_layout.practice_targets_by_id[target_id])
	for definition: Dictionary in target_definitions:
		var state: PlayerState = world.player(int(definition.get("entity_id", 0)))
		if state == null:
			continue
		if not _chemistry_actor_visible(state):
			continue
		var position := Vector2(float(state.position_x) / 1000.0, float(state.position_y) / 1000.0)
		var alive: bool = state.health > 0
		_set_world_local_transform(position + Vector2(2, 9), Vector2(20.0, 7.0), camera_origin)
		draw_circle(Vector2.ZERO, 1.0, Color(FOREST_SHADOW_COLOR, 0.62))
		_set_world_transform(camera_origin)
		var body_color := TIMBER_COLOR if alive else Color("4f463e")
		draw_rect(Rect2(position.x - 4, position.y - 19, 8, 27), body_color, true)
		draw_line(position + Vector2(-13, -7), position + Vector2(13, -7), body_color, 5.0)
		draw_circle(position + Vector2(0, -20), 14.0, Color(WORLDBONE_COLOR, 0.96))
		draw_arc(position + Vector2(0, -20), 11.0, 0.0, TAU, 16, BRASS_COLOR, 3.0)
		if alive:
			draw_circle(position + Vector2(0, -20), 5.0, WATER_HIGHLIGHT_COLOR)
			draw_line(position + Vector2(-5, -25), position + Vector2(5, -15), PARCHMENT_COLOR, 1.5)
			draw_line(position + Vector2(5, -25), position + Vector2(-5, -15), PARCHMENT_COLOR, 1.5)
		else:
			draw_line(position + Vector2(-8, -27), position + Vector2(8, -13), Color("8b6652"), 3.0)
			draw_line(position + Vector2(8, -27), position + Vector2(-8, -13), Color("8b6652"), 3.0)
		var bar := Rect2(position.x - 30, position.y - 43, 60, 6)
		draw_rect(bar, Color(FOREST_SHADOW_COLOR, 0.9), true)
		var health_ratio: float = clampf(float(state.health) / float(state.health_maximum), 0.0, 1.0)
		draw_rect(Rect2(bar.position + Vector2.ONE, Vector2((bar.size.x - 2.0) * health_ratio, bar.size.y - 2.0)), Color("d9634f"), true)
		var label := String(definition.get("label", "TARGET"))
		if not alive and state.training_respawn_ticks > 0:
			label = "RETURNS %.1fs" % (float(state.training_respawn_ticks) / float(world.config.tick_rate))
		elif state.spawn_protection_ticks > 0:
			label = "READYING"
		var label_width: float = ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		draw_string(ThemeDB.fallback_font, Vector2(position.x - label_width * 0.5, position.y + 22), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, PARCHMENT_COLOR if alive else Color("9b8a73"))
	_set_world_transform(camera_origin)


func _refresh_material_preview() -> void:
	var image := Image.create(material_grid.width, material_grid.height, false, Image.FORMAT_RGBA8)
	for cell_y: int in range(material_grid.height):
		for cell_x: int in range(material_grid.width):
			var cell_index := cell_y * material_grid.width + cell_x
			var material_id := material_registry.material_id(material_grid.material_wire_ids[cell_index])
			var color := _material_color(material_id)
			var charge_ratio := float(material_grid.charges[cell_index]) / float(SimConfig.FIXED_SCALE)
			if charge_ratio > 0.0:
				color = color.lerp(ATTUNEMENT_COLOR, charge_ratio * 0.7)
			image.set_pixel(cell_x, cell_y, color)
	material_preview_texture = ImageTexture.create_from_image(image)


func _material_color(material_id: String) -> Color:
	match material_id:
		"worldbone":
			return WORLDBONE_COLOR
		"stone":
			return PALE_STONE_COLOR.darkened(0.28)
		"brick":
			return Color("8f5745")
		"wood":
			return TIMBER_COLOR
		"water":
			return WATER_HIGHLIGHT_COLOR
		"oil":
			return Color("342f42")
		"fire":
			return FIRE_COLOR
		"steam":
			return Color("b8c8c6")
		"ice":
			return Color("9bc7d9")
		"rubble":
			return Color("685e54")
		_:
			return Color("151711")


func _chemistry_actor_visible(target: PlayerState) -> bool:
	var observer := _spectator_state() if _is_spectating() else _local_player_state()
	if target == null:
		return false
	if observer == null or target.entity_id == observer.entity_id:
		return true
	if player_preferences != null and player_preferences.pov_mode == PlayerPreferences.POV_CONE:
		var spectating := _is_spectating()
		var alpha := clampf(accumulator_seconds * float(tick_rate), 0.0, 1.0)
		var origin := _pov_observer_ground_position(observer, spectating, previous_position.lerp(current_position, alpha))
		var aim_state := observer
		if not spectating and session_transport.is_connected_client() and client_prediction.is_ready():
			aim_state = client_prediction.predicted_state
		if not SightOcclusion.point_visible(origin, Vector2(target.position_x, target.position_y) / 1000.0, Vector2(CartoonChampionPresenter.presentation_facing_vector(aim_state)), float(player_preferences.pov_angle_degrees), float(player_preferences.pov_range), _pov_opaque_bounds()):
			return false
	# Chemical reveal never bypasses the directional/range/opaque-world test.
	if target.chemistry_reveal_ticks > 0:
		return true
	return not ElementChemistrySystem.blocks_sight(Vector2i(observer.position_x, observer.position_y), Vector2i(target.position_x, target.position_y), world.reactions, world.tick)


func _draw_element_chemistry(visual_tick: float, camera_origin: Vector2) -> void:
	if world.hex_court != null:
		return
	if element_chemistry_presenter == null:
		return
	element_chemistry_presenter.begin_frame(world.config, world.collision, Rect2(camera_origin, get_viewport_rect().size / _camera_zoom_scale()), world.deposits, _reduced_effects_enabled())
	for deposit: ElementDepositState in world.deposits:
		element_chemistry_presenter.draw_deposit(self, deposit, visual_tick, _reduced_effects_enabled())
		heavy_blast_presenter.draw(self, deposit, world.tick, world.config, world.collision, world.reactions, _reduced_effects_enabled())
		var age := maxi(0, world.tick - deposit.created_tick)
		if age < PixelSpellEffects.TERMINAL_CONTACT_TICKS:
			var source_radius := float(CombatTuning.projectile_definition(deposit.source_wire_id).get("radius", 8000)) / 1000.0
			burst_projectile_presenter.draw_impact(self, ElementChemistryPresenter.ELEMENTS[deposit.element_wire_id], Vector2(deposit.position_x, deposit.position_y) / 1000.0, Vector2(deposit.direction_x, deposit.direction_y), age, PixelSpellEffects.TERMINAL_CONTACT_TICKS, _reduced_effects_enabled(), source_radius)
	for reaction: ElementReactionState in world.reactions:
		element_chemistry_presenter.draw_reaction(self, reaction, ElementChemistrySystem.recipe(reaction.recipe_wire_id), visual_tick, _reduced_effects_enabled())


func _draw_field(field: FieldState) -> void:
	var center := Vector2(float(field.position_x) / SimConfig.FIXED_SCALE, float(field.position_y) / SimConfig.FIXED_SCALE)
	var radius := float(field.radius) / SimConfig.FIXED_SCALE
	var definition := CombatTuning.cast_definition(field.source_wire_id)
	var full_lifetime := maxi(1, world.config.milliseconds_to_ticks(int(definition.get("lifetime_ms", 1))))
	var life_ratio := clampf(float(field.lifetime_ticks) / float(full_lifetime), 0.0, 1.0)
	var release_age := full_lifetime - field.lifetime_ticks
	if release_age >= 0 and release_age < 24 and field.lifetime_ticks > 0:
		var owner := world.player(field.owner_id)
		if owner != null and _chemistry_actor_visible(owner):
			var lift := JumpPresentation.sample(owner, world.config, 0.0, _reduced_effects_enabled())
			var body := Vector2(owner.position_x, owner.position_y) / 1000.0 + Vector2(0.0, float(MovementTuning.PLAYER_RADIUS) / 1000.0 * 0.58 - float(lift.body_lift_pixels))
			var hand := CartoonChampionPresenter.hand_cast_origin(body, Vector2(owner.aim_x, owner.aim_y))
			foundation_spell_presenter.draw_release(self, field.source_wire_id, hand, release_age, _reduced_effects_enabled())
	if foundation_spell_presenter != null and foundation_spell_presenter.draw_field(self, field, life_ratio, world.tick, _reduced_effects_enabled()):
		return
	var ice_color := WATER_HIGHLIGHT_COLOR.lightened(0.36)
	draw_circle(center, radius, Color(ice_color, 0.11 + life_ratio * 0.05))
	draw_arc(center, radius, 0.0, TAU, 48, Color(ice_color, 0.64), 2.0)
	draw_arc(center, radius * 0.72, 0.0, TAU, 36, Color(PARCHMENT_COLOR, 0.24), 1.0)
	for index: int in range(8):
		var angle := float(index) * TAU / 8.0 + float((world.tick + field.entity_id) % 120) * 0.0025
		var direction := Vector2.from_angle(angle)
		var tangent := direction.orthogonal()
		var point := center + direction * radius * 0.82
		draw_colored_polygon(PackedVector2Array([
			point + direction * 6.0,
			point - direction * 4.0 + tangent * 3.0,
			point - direction * 4.0 - tangent * 3.0,
		]), Color(ice_color, 0.72))


func _projectile_color(element_wire_id: int) -> Color:
	match element_wire_id:
		3:
			return WATER_HIGHLIGHT_COLOR.lightened(0.28)
		5:
			return WATER_HIGHLIGHT_COLOR.lightened(0.42)
		6:
			return ATTUNEMENT_COLOR
		7:
			return PARCHMENT_COLOR
		8:
			return FLUX_COLOR.darkened(0.12)
		_:
			return FLUX_COLOR


func _draw_projectile(projectile: ProjectileState, position: Vector2, color: Color, interpolation_alpha: float) -> void:
	if world.hex_court != null:
		hex_court_presenter.draw_projectile(self, projectile, world.tick, interpolation_alpha, _reduced_effects_enabled())
		return
	if burst_projectile_presenter != null and burst_projectile_presenter.draw_projectile(self, projectile, world.tick, _reduced_effects_enabled(), interpolation_alpha):
		return
	if foundation_spell_presenter != null and foundation_spell_presenter.draw_projectile(self, projectile, world.tick, _reduced_effects_enabled(), interpolation_alpha):
		return
	var radius: float = float(projectile.radius) / 1000.0
	var direction := ProjectilePresentationMotion.travel_direction(projectile)
	var trail_start := position - direction * ProjectilePresentationMotion.trail_length(projectile, _reduced_effects_enabled())
	draw_line(trail_start, position - direction * radius * 0.35, Color(color, 0.42), maxf(2.0, radius * 0.65), true)
	draw_circle(position, radius + 7.0, Color(color, 0.18))
	draw_circle(position, radius, color)


func _requested_tick_rate() -> int:
	var configured: int = int(ProjectSettings.get_setting("flux/simulation/default_tick_rate", 120))
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--tick-rate="):
			configured = argument.trim_prefix("--tick-rate=").to_int()
	if not SimConfig.is_supported_tick_rate(configured):
		push_warning("Unsupported tick rate %d; falling back to 120" % configured)
		return 120
	return configured


func _requested_join_address() -> String:
	var fallback := PlayerPreferences.DEFAULT_FARFLOW_JOIN_ADDRESS
	if player_preferences != null and PlayerPreferences.is_valid_farflow_join_address(player_preferences.farflow_join_address):
		fallback = player_preferences.farflow_join_address
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--join-address="):
			var requested := argument.trim_prefix("--join-address=").strip_edges()
			if SessionTransport._valid_address(requested):
				return requested
			push_warning("Invalid join address override; using saved address")
	return fallback


func _requested_session_port() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--session-port="):
			var requested: int = argument.trim_prefix("--session-port=").to_int()
			if SessionTransport._valid_port(requested, false):
				return requested
			push_warning("Invalid session port override; using %d" % SessionTransport.DEFAULT_PORT)
	return SessionTransport.DEFAULT_PORT


func _requested_player_name() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--player-name="):
			var requested := SessionTransport._validated_player_name(argument.trim_prefix("--player-name="))
			if not requested.is_empty():
				return requested
			push_warning("Invalid player name override; using Traveller")
	return "Traveller"


func _requested_session_charter_id() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--session-charter="):
			var requested := argument.trim_prefix("--session-charter=").strip_edges().to_lower()
			if SessionCharter.is_valid_id(requested):
				return requested
			push_warning("Invalid session charter override; using %s" % SessionCharter.DEFAULT_ID)
	return SessionCharter.DEFAULT_ID


func _requested_capture_spawn() -> Vector2i:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-spawn="):
			return parse_capture_spawn(argument, campus_layout.canvas_size)
	return Vector2i(-1, -1)


func _requested_capture_expanded_station() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-expanded-station="):
			return parse_capture_expanded_station(argument, campus_layout.stations_by_id)
	return ""


func _requested_capture_spell_slot() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-cast-slot="):
			return parse_capture_spell_slot(argument)
	return 0


func _requested_capture_chain_spell_slot() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-chain-slot="):
			return parse_capture_chain_spell_slot(argument)
	return 0


func _requested_capture_spell_sequence() -> PackedInt32Array:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-spell-sequence="):
			var requested := parse_capture_spell_sequence(argument)
			if requested.is_empty():
				push_warning("Invalid capture spell sequence; expected 1-12 positions separated by commas")
			return requested
	return PackedInt32Array()


func _requested_capture_spell_wires() -> PackedInt32Array:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-spell-wires="):
			var requested := parse_capture_spell_wires(argument)
			if requested.is_empty():
				push_warning("Invalid capture spell wires; expected 1-12 unique playable wire IDs")
			return requested
	return PackedInt32Array()


func _requested_capture_movement() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-movement="):
			var requested := parse_capture_movement(argument)
			if requested.is_empty():
				push_warning("Invalid movement capture; expected grounded, hit, walk, brake, reverse, sprint, slide, jump, air_dodge, technique, or impact_recovery")
			return requested
	return ""


func _requested_capture_direction() -> Vector2i:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-direction="):
			var requested := parse_capture_direction(argument)
			if requested == Vector2i.ZERO:
				push_warning("Invalid capture direction; expected south, south_east, east, north_east, north, north_west, west, or south_west")
				return Vector2i.RIGHT
			return requested
	return Vector2i.RIGHT


func _requested_capture_visual_profile() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-visual-profile="):
			var profile_id := VisualAccessibilityFilter.parse_capture_profile(argument)
			if profile_id.is_empty():
				push_warning("Invalid visual review profile; expected standard, high_contrast, grayscale, protanopia, deuteranopia, or tritanopia")
			return profile_id
	return ""


func _requested_capture_reduced_effects() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if VisualAccessibilityFilter.has_reduced_effects_capture_argument(argument):
			return true
	return false


static func parse_session_charter(argument: String) -> String:
	if not argument.begins_with("--session-charter="):
		return ""
	var requested := argument.trim_prefix("--session-charter=").strip_edges().to_lower()
	return requested if SessionCharter.is_valid_id(requested) else ""


static func parse_capture_spawn(argument: String, canvas_size: Vector2i) -> Vector2i:
	if not argument.begins_with("--capture-spawn="):
		return Vector2i(-1, -1)
	return parse_capture_pointer(argument.replace("--capture-spawn=", "--capture-pointer="), canvas_size)


static func parse_capture_expanded_station(argument: String, stations_by_id: Dictionary) -> String:
	if not argument.begins_with("--capture-expanded-station="):
		return ""
	var station_id := argument.trim_prefix("--capture-expanded-station=").strip_edges()
	return station_id if stations_by_id.has(station_id) else ""


static func parse_capture_spell_slot(argument: String) -> int:
	if not argument.begins_with("--capture-cast-slot="):
		return 0
	var value := argument.trim_prefix("--capture-cast-slot=")
	if not value.is_valid_int():
		return 0
	var slot_number := value.to_int()
	return slot_number if slot_number >= 1 and slot_number <= PlayerState.SPELL_SLOT_COUNT else 0


static func parse_capture_chain_spell_slot(argument: String) -> int:
	if not argument.begins_with("--capture-chain-slot="):
		return 0
	var value := argument.trim_prefix("--capture-chain-slot=")
	if not value.is_valid_int():
		return 0
	var slot_number := value.to_int()
	return slot_number if slot_number >= 1 and slot_number <= PlayerState.SPELL_SLOT_COUNT else 0


static func parse_capture_spell_sequence(argument: String) -> PackedInt32Array:
	var result := PackedInt32Array()
	if not argument.begins_with("--capture-spell-sequence="):
		return result
	var values := argument.trim_prefix("--capture-spell-sequence=").split(",", false)
	if values.is_empty() or values.size() > PlayerState.SPELL_SLOT_COUNT:
		return result
	for value: String in values:
		var cleaned := value.strip_edges()
		if not cleaned.is_valid_int():
			return PackedInt32Array()
		var slot_number := cleaned.to_int()
		if slot_number < 1 or slot_number > PlayerState.SPELL_SLOT_COUNT:
			return PackedInt32Array()
		result.append(slot_number)
	return result


static func parse_capture_spell_wires(argument: String) -> PackedInt32Array:
	var result := PackedInt32Array()
	if not argument.begins_with("--capture-spell-wires="):
		return result
	var values := argument.trim_prefix("--capture-spell-wires=").split(",", false)
	if values.is_empty() or values.size() > PlayerState.SPELL_SLOT_COUNT:
		return result
	for value: String in values:
		var cleaned := value.strip_edges()
		if not cleaned.is_valid_int():
			return PackedInt32Array()
		var wire_id := cleaned.to_int()
		if not CombatTuning.is_runtime_wire_id(wire_id) or result.has(wire_id):
			return PackedInt32Array()
		result.append(wire_id)
	return result


static func apply_capture_spell_wires(state: PlayerState, wire_ids: PackedInt32Array) -> bool:
	if state == null or wire_ids.is_empty() or wire_ids.size() > PlayerState.SPELL_SLOT_COUNT:
		return false
	for slot_index: int in range(wire_ids.size()):
		if not state.place_proven_spell(slot_index, int(wire_ids[slot_index])):
			return false
	return state.has_valid_spell_slots()


static func parse_capture_movement(argument: String) -> String:
	if not argument.begins_with("--capture-movement="):
		return ""
	var requested := argument.trim_prefix("--capture-movement=").strip_edges().to_lower()
	return requested if requested in ["grounded", "hit", "walk", "brake", "reverse", "sprint", "slide", "roll", "jump", "air_dodge", "air_chain", "float_release", "technique", "impact_recovery"] else ""


static func parse_capture_direction(argument: String) -> Vector2i:
	if not argument.begins_with("--capture-direction="):
		return Vector2i.ZERO
	var direction_id := argument.trim_prefix("--capture-direction=").strip_edges().to_lower()
	return EightDirectionResolver.fixed_vector(direction_id) if direction_id in EightDirectionResolver.DIRECTION_ORDER else Vector2i.ZERO


static func capture_movement_command(mode: String, tick: int, entity_id: int, direction: Vector2i = Vector2i.RIGHT) -> SimCommand:
	var held := 0
	var pressed := 0
	var normalized_direction := direction
	if direction in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]:
		normalized_direction *= 1000
	elif not EightDirectionResolver.is_fixed_vector(direction):
		normalized_direction = EightDirectionResolver.fixed_vector("east")
	var move_x := normalized_direction.x
	var move_y := normalized_direction.y
	if mode == "grounded" and tick > 0:
		move_x = 0
		move_y = 0
	if mode == "impact_recovery":
		# Preserve the historical bounded influence lane; the separate aim and
		# launch vectors still select the requested cardinal review direction.
		move_x = 0
		move_y = -1000
	if mode == "brake" and tick >= 30:
		move_x = 0
		move_y = 0
	elif mode == "reverse" and tick >= 30:
		move_x = -normalized_direction.x
		move_y = -normalized_direction.y
	if mode == "sprint" or mode == "slide":
		held |= SimCommand.HELD_SPRINT
	if mode == "slide" and tick >= 6 and tick < 42:
		# Truthful review capture holds the same C/wheel semantic that now pays
		# for the optional slide tail; the press at tick six still starts it.
		held |= SimCommand.HELD_SLIDE
	if mode == "air_chain":
		var chain_held := SimCommand.HELD_JUMP if tick >= 4 and tick < 66 and tick != 23 else 0
		var chain_pressed := SimCommand.PRESSED_JUMP if tick in [4, 24] else (SimCommand.PRESSED_EVADE if tick == 40 else 0)
		return SimCommand.new(tick, entity_id, move_x, move_y, chain_held, chain_pressed, normalized_direction.x, normalized_direction.y)
	if mode == "float_release":
		# Production input only: takeoff, fresh held Float, steer across the
		# original lane, release, fall and land. Never inject protected state.
		var float_held := SimCommand.HELD_JUMP if tick >= 4 and tick < 64 and tick != 23 else 0
		var float_pressed := SimCommand.PRESSED_JUMP if tick in [4, 24] else 0
		if tick >= 40 and tick < 64:
			move_x = -normalized_direction.y
			move_y = normalized_direction.x
		return SimCommand.new(tick, entity_id, move_x, move_y, float_held, float_pressed, move_x, move_y)
	if mode in ["jump", "air_dodge"] and tick >= 4 and tick < 30:
		held |= SimCommand.HELD_JUMP
	if mode in ["jump", "air_dodge"] and tick == 4:
		pressed |= SimCommand.PRESSED_JUMP
	if mode == "slide" and tick == 6:
		pressed |= SimCommand.PRESSED_SLIDE
	if mode == "roll" and tick == 6:
		pressed |= SimCommand.PRESSED_EVADE
	if mode == "air_dodge" and tick == 12:
		pressed |= SimCommand.PRESSED_EVADE
	if mode == "technique" and tick == 6:
		pressed |= SimCommand.PRESSED_TECHNIQUE
	return SimCommand.new(tick, entity_id, move_x, move_y, held, pressed, normalized_direction.x, normalized_direction.y)


func _requested_farflow_mode() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--farflow="):
			var requested := parse_farflow_mode(argument)
			if not requested.is_empty():
				return requested
			push_warning("Invalid Farflow override; expected --farflow=host or --farflow=join")
	return ""


func _requested_emote_smoke() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if has_emote_smoke_argument(argument):
			return true
	return false


static func has_emote_smoke_argument(argument: String) -> bool:
	return argument == "--farflow-smoke-emote"


func _requested_prediction_smoke() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if has_prediction_smoke_argument(argument):
			return true
	return false


static func has_prediction_smoke_argument(argument: String) -> bool:
	return argument == "--farflow-smoke-prediction"


func _requested_reconnect_smoke() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if has_reconnect_smoke_argument(argument):
			return true
	return false


static func has_reconnect_smoke_argument(argument: String) -> bool:
	return argument == "--farflow-smoke-reconnect"


func _requested_hearth_smoke() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if has_hearth_smoke_argument(argument):
			return true
	return false


static func has_hearth_smoke_argument(argument: String) -> bool:
	return argument == "--farflow-smoke-hearth"


func _requested_round_smoke() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if has_round_smoke_argument(argument):
			return true
	return false


static func has_round_smoke_argument(argument: String) -> bool:
	return argument == "--farflow-smoke-round"


func _requested_rematch_smoke() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if has_rematch_smoke_argument(argument):
			return true
	return false


static func has_rematch_smoke_argument(argument: String) -> bool:
	return argument == "--farflow-smoke-rematch"


func _requested_steward_smoke() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if has_steward_smoke_argument(argument):
			return true
	return false


static func has_steward_smoke_argument(argument: String) -> bool:
	return argument == "--farflow-smoke-steward"


func _requested_spectator_smoke() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if has_spectator_smoke_argument(argument):
			return true
	return false


static func has_spectator_smoke_argument(argument: String) -> bool:
	return argument == "--farflow-smoke-spectator"


func _requested_safe_quit_smoke() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if has_safe_quit_smoke_argument(argument):
			return true
	return false


static func has_safe_quit_smoke_argument(argument: String) -> bool:
	return argument == "--safe-quit-smoke"


static func reconnect_smoke_prerequisites_met(
	requested_emote: bool,
	emote_sent: bool,
	requested_prediction: bool,
	prediction_confirmed: bool,
	requested_hearth: bool = false,
	hearth_started: bool = false,
) -> bool:
	return (
		(not requested_emote or emote_sent)
		and (not requested_prediction or prediction_confirmed)
		and (not requested_hearth or hearth_started)
	)


static func snapshot_tick_interval(requested_tick_rate: int) -> int:
	if not SimConfig.is_supported_tick_rate(requested_tick_rate):
		return 0
	@warning_ignore("integer_division")
	return requested_tick_rate / SNAPSHOT_RATE


static func parse_farflow_mode(argument: String) -> String:
	if not argument.begins_with("--farflow="):
		return ""
	var requested := argument.trim_prefix("--farflow=").strip_edges().to_lower()
	return requested if requested in ["host", "join"] else ""


func _requested_champion_id() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--champion="):
			var requested := argument.trim_prefix("--champion=")
			if champion_catalog.champions_by_id.has(requested):
				return requested
			push_warning("Unknown champion %s; falling back to %s" % [requested, champion_catalog.default_champion_id])
	return champion_catalog.default_champion_id


func _requested_capture_pointer() -> Vector2i:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-pointer="):
			var parsed := parse_capture_pointer(argument, campus_layout.canvas_size)
			if parsed.x < 0:
				push_warning("Invalid capture pointer; expected --capture-pointer=X,Y inside the campus")
			return parsed
	return Vector2i(-1, -1)


static func parse_capture_pointer(argument: String, canvas_size: Vector2i) -> Vector2i:
	if not argument.begins_with("--capture-pointer="):
		return Vector2i(-1, -1)
	var components := argument.trim_prefix("--capture-pointer=").split(",", false)
	if components.size() != 2 or not components[0].is_valid_int() or not components[1].is_valid_int():
		return Vector2i(-1, -1)
	var point := Vector2i(components[0].to_int(), components[1].to_int())
	if point.x < 0 or point.y < 0 or point.x >= canvas_size.x or point.y >= canvas_size.y:
		return Vector2i(-1, -1)
	return point


func _apply_preference_overrides() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if is_transient_preference_argument(argument):
			preference_overrides_are_transient = true
		if argument.begins_with("--movement-reference="):
			var requested_reference: String = argument.trim_prefix("--movement-reference=")
			if not player_preferences.apply_control_preset(requested_reference):
				push_warning(player_preferences.last_error)
		elif argument.begins_with("--pov-mode="):
			var requested_mode: String = argument.trim_prefix("--pov-mode=")
			if not player_preferences.set_pov_mode(requested_mode):
				push_warning(player_preferences.last_error)
		elif argument.begins_with("--pov-angle="):
			var angle_text: String = argument.trim_prefix("--pov-angle=")
			if angle_text.is_valid_int():
				player_preferences.set_pov_angle_degrees(angle_text.to_int())
			else:
				push_warning("Invalid --pov-angle value: %s" % angle_text)
		elif argument.begins_with("--pov-range="):
			var range_text: String = argument.trim_prefix("--pov-range=")
			if range_text.is_valid_int():
				player_preferences.set_pov_range(range_text.to_int())
			else:
				push_warning("Invalid --pov-range value: %s" % range_text)
		elif argument.begins_with("--camera-zoom="):
			var zoom_text: String = argument.trim_prefix("--camera-zoom=")
			if zoom_text.is_valid_int():
				player_preferences.set_camera_zoom_percent(zoom_text.to_int())
			else:
				push_warning("Invalid --camera-zoom value: %s" % zoom_text)


static func is_transient_preference_argument(argument: String) -> bool:
	for prefix: String in ["--movement-reference=", "--pov-mode=", "--pov-angle=", "--pov-range=", "--camera-zoom="]:
		if argument.begins_with(prefix):
			return true
	return false


func _handle_preference_actions() -> void:
	var changed: bool = false
	if Input.is_action_just_pressed(&"toggle_movement_reference"):
		var next_reference := PlayerPreferences.MOVEMENT_AIM_RELATIVE if player_preferences.movement_reference == PlayerPreferences.MOVEMENT_WORLD_RELATIVE else PlayerPreferences.MOVEMENT_WORLD_RELATIVE
		changed = player_preferences.apply_control_preset(next_reference)
		if changed and input_router != null:
			input_router.configure_movement_reference(next_reference)
	if Input.is_action_just_pressed(&"toggle_pov_mode"):
		var next_mode := PlayerPreferences.POV_CONE if player_preferences.pov_mode == PlayerPreferences.POV_FULL else PlayerPreferences.POV_FULL
		changed = player_preferences.set_pov_mode(next_mode) or changed
	if Input.is_action_just_pressed(&"adjust_pov_angle"):
		var angle_delta: int = -15 if Input.is_key_pressed(KEY_SHIFT) else 15
		player_preferences.set_pov_angle_degrees(player_preferences.pov_angle_degrees + angle_delta)
		changed = true
	if Input.is_action_just_pressed(&"adjust_pov_range"):
		var range_delta: int = -80 if Input.is_key_pressed(KEY_SHIFT) else 80
		player_preferences.set_pov_range(player_preferences.pov_range + range_delta)
		changed = true
	if Input.is_action_just_pressed(&"adjust_camera_zoom"):
		var zoom_delta: int = -25 if Input.is_key_pressed(KEY_SHIFT) else 25
		var requested_zoom := player_preferences.camera_zoom_percent + zoom_delta
		if requested_zoom > PlayerPreferences.MAX_CAMERA_ZOOM_PERCENT:
			requested_zoom = PlayerPreferences.MIN_CAMERA_ZOOM_PERCENT
		elif requested_zoom < PlayerPreferences.MIN_CAMERA_ZOOM_PERCENT:
			requested_zoom = PlayerPreferences.MAX_CAMERA_ZOOM_PERCENT
		player_preferences.set_camera_zoom_percent(requested_zoom)
		changed = true
	if changed and not _save_player_preferences_if_persistent():
		push_warning(player_preferences.last_error)


func _save_player_preferences_if_persistent() -> bool:
	if preference_overrides_are_transient:
		return true
	if not preferences_persistence_allowed:
		player_preferences.last_error = "Preferences remain in memory; the existing profile and recovery copy were kept unchanged."
		return false
	return player_preferences.save_to_file()


func _apply_visual_accessibility_profile() -> bool:
	if visual_accessibility_filter == null:
		return false
	var profile_id := requested_capture_visual_profile
	if profile_id.is_empty():
		profile_id = VisualAccessibilityFilter.player_profile_for(player_preferences.high_contrast)
	return visual_accessibility_filter.set_profile(profile_id)


func _reduced_effects_enabled() -> bool:
	return requested_capture_reduced_effects or (player_preferences != null and player_preferences.reduced_motion)


func _player_position() -> Vector2:
	if session_transport != null and session_transport.is_connected_client() and client_prediction != null and client_prediction.is_ready():
		return client_prediction.presented_position_pixels()
	var state: PlayerState = _local_player_state()
	if state == null:
		return current_position
	return Vector2(float(state.position_x) / 1000.0, float(state.position_y) / 1000.0)


func _reconcile_spectator_focus() -> void:
	if spectator_focus == null:
		return
	var was_spectating := spectator_focus.active
	var available_ids: Array[int] = []
	for state: PlayerState in world.players:
		if state.actor_kind == PlayerState.ActorKind.CHAMPION:
			available_ids.append(state.entity_id)
	var now_spectating := spectator_focus.reconcile(
		_current_round_state(),
		session_transport.local_entity_id,
		available_ids,
	)
	if now_spectating and not was_spectating:
		client_prediction.reset()
		station_notice = "The Court is underway. Follow now; join at the Hearth."
		station_notice_seconds = 4.0
		if requested_spectator_smoke and not spectator_smoke_active_reported:
			spectator_smoke_active_reported = true
			print("FLUX2 farflow spectator smoke: late guest following entity %d" % spectator_focus.focus_entity_id)
	elif was_spectating and not now_spectating:
		client_prediction.reset()
		current_position = _player_position()
		previous_position = current_position
		_reset_motion_history()
		station_notice = "The company gathered. Your champion is active at the Hearth."
		station_notice_seconds = 4.0
		if requested_spectator_smoke and not spectator_smoke_handoff_reported:
			spectator_smoke_handoff_reported = true
			_submit_session_request(SessionTransport.REQUEST_READY_TOGGLE)
			station_notice = "Hearth handoff complete; ready for the next Court."
			station_notice_seconds = 4.0
			print("FLUX2 farflow spectator smoke: Hearth handoff ready for entity %d" % session_transport.local_entity_id)


func _reset_motion_history() -> void:
	actor_motion_history.clear()
	actor_motion_history.capture(world.players)
	var actor := _local_player_state()
	previous_air_height = actor.air_height if actor != null else 0
	remote_snapshot_age_seconds = 0.0


func _is_spectating() -> bool:
	return session_transport != null and session_transport.is_connected_client() and spectator_focus != null and spectator_focus.active and _spectator_state() != null


func _spectator_state() -> PlayerState:
	return world.player(spectator_focus.focus_entity_id) if world != null and spectator_focus != null and spectator_focus.focus_entity_id > 0 else null


func _spectator_name(entity_id: int) -> String:
	return String(session_names_by_entity.get(entity_id, "Traveller %d" % entity_id)).left(SessionTransport.MAX_PLAYER_NAME_LENGTH)


func _camera_focus_position(local_position: Vector2) -> Vector2:
	var state := _spectator_state() if _is_spectating() else null
	return Vector2(float(state.position_x) / SimConfig.FIXED_SCALE, float(state.position_y) / SimConfig.FIXED_SCALE) if state != null else local_position


func _local_player_state() -> PlayerState:
	if world == null:
		return null
	var entity_id: int = SessionTransport.SERVER_PEER_ID
	if session_transport != null and session_transport.is_connected_client() and session_transport.local_entity_id > 0:
		entity_id = session_transport.local_entity_id
	var state: PlayerState = world.player(entity_id)
	return state if state != null else world.player(SessionTransport.SERVER_PEER_ID)


func _camera_origin(focus_position: Vector2) -> Vector2:
	if world != null and world.hex_court != null:
		return camera_origin_for(focus_position, Vector2i(get_viewport_rect().size), Vector2i(1280, 960), 64, player_preferences.camera_zoom_percent)
	if campus_layout == null:
		return Vector2.ZERO
	return camera_origin_for(
		focus_position,
		Vector2i(get_viewport_rect().size),
		campus_layout.canvas_size,
		campus_layout.reserved_ui_top,
		player_preferences.camera_zoom_percent,
	)


static func camera_origin_for(focus_position: Vector2, viewport: Vector2i, canvas: Vector2i, reserved_ui_top: int, zoom_percent: int) -> Vector2:
	var zoom := float(clampi(zoom_percent, PlayerPreferences.MIN_CAMERA_ZOOM_PERCENT, PlayerPreferences.MAX_CAMERA_ZOOM_PERCENT)) / 100.0
	var viewport_size := Vector2(viewport)
	var visible_world_size := viewport_size / zoom
	var focus_screen := Vector2(viewport_size.x * 0.5, (float(reserved_ui_top) + viewport_size.y) * 0.5) / zoom
	var maximum_origin := (Vector2(canvas) - visible_world_size).max(Vector2.ZERO)
	return Vector2(
		(float(canvas.x) - visible_world_size.x) * 0.5 if visible_world_size.x > canvas.x else clampf(focus_position.x - focus_screen.x, 0.0, maximum_origin.x),
		(float(canvas.y) - visible_world_size.y) * 0.5 if visible_world_size.y > canvas.y else clampf(focus_position.y - focus_screen.y, 0.0, maximum_origin.y),
	)


func _camera_zoom_scale() -> float:
	return float(player_preferences.camera_zoom_percent) / 100.0 if player_preferences != null else 1.0


func _ui_scale() -> float:
	return ui_scale_for(get_viewport_rect().size)


static func ui_scale_for(viewport_size: Vector2) -> float:
	return clampf(minf(viewport_size.x / 1280.0, viewport_size.y / 720.0), 1.0, 1.5)


func _set_world_transform(camera_origin: Vector2) -> void:
	var zoom := _camera_zoom_scale()
	draw_set_transform(PixelPresentation.snapped_canvas_origin(camera_origin, player_preferences.camera_zoom_percent), 0.0, Vector2(zoom, zoom))


func _set_world_local_transform(world_position: Vector2, local_scale: Vector2, camera_origin: Vector2) -> void:
	var zoom := _camera_zoom_scale()
	draw_set_transform(PixelPresentation.world_to_screen(world_position, camera_origin, player_preferences.camera_zoom_percent), 0.0, local_scale * zoom)



func _ensure_character_weaves() -> void:
	if character_weaves.champions != null or champion_catalog == null or ability_catalog == null: return
	if not character_weaves.configure(champion_catalog, ability_catalog, preferences_persistence_allowed and not preference_overrides_are_transient):
		station_notice = "Saved spell weaves could not load; stored file preserved."
		station_notice_seconds = 5.0


func _save_confirmed_weave(state: PlayerState, mode: String) -> void:
	if not character_weaves.save_local(state, mode):
		spell_loom_editor.status_message = "Weave works for this session; saved file could not be updated."


func _submit_starter_weave() -> void:
	var request := spell_loom_editor.request_starter_apply()
	var state := _local_player_state()
	if request.is_empty() or state == null or champion_catalog.champion_id_from_wire(state.champion_wire_id) != String(request.champion_id): return
	_submit_whole_weave(state, request.expected_wire_ids, request.wire_ids, CharacterWeaveLibrary.MODE_STARTER, true)


func _submit_whole_weave(state: PlayerState, expected: PackedInt32Array, requested: PackedInt32Array, mode: String, save: bool) -> void:
	if not pending_weave_request.is_empty() or client_request_sequence >= 0x7fffffff: return
	if not SessionTransport._valid_weave_wires(expected, true) or not SessionTransport._valid_weave_wires(requested):
		spell_loom_editor.status_message = "Choose a complete valid twelve-spell weave first."
		return
	client_request_sequence += 1
	pending_weave_request = {"champion": state.champion_wire_id, "wires": requested.duplicate(), "mode": mode, "save": save,
		"sequence": client_request_sequence, "acknowledged": false, "deadline_tick": world.tick + 600}
	spell_loom_editor.status_message = "Applying weave; waiting for authority confirmation."
	if spell_loom_editor.starter_preview_active(): spell_loom_editor.starter_preview.notice = "Apply sent. Waiting for authority; this request can no longer be cancelled."
	if session_transport.is_connected_client():
		if not session_transport.send_weave_request(client_request_sequence, state.champion_wire_id, expected, requested):
			pending_weave_request.clear()
			spell_loom_editor.complete_starter_apply(false)
		return
	_handle_session_requests([{"entity_id": state.entity_id, "action": SessionTransport.REQUEST_WEAVE_APPLY, "value": state.champion_wire_id, "expected": expected, "wires": requested, "sequence": client_request_sequence}])


func _complete_pending_weave() -> void:
	if pending_weave_request.is_empty(): return
	if world.tick >= int(pending_weave_request.deadline_tick):
		pending_weave_request.clear()
		spell_loom_editor.complete_starter_apply(false)
		spell_loom_editor.status_message = "Confirmation timed out. Check the current weave before retrying; no local save was made."
		return
	if not bool(pending_weave_request.get("acknowledged", false)): return
	var state := _local_player_state()
	if state == null or state.champion_wire_id != int(pending_weave_request.champion) or state.spell_wire_ids != (pending_weave_request.wires as PackedInt32Array): return
	var completed := pending_weave_request.duplicate(true)
	pending_weave_request.clear()
	spell_loom_editor.complete_starter_apply(true)
	if bool(completed.get("save", false)): _save_confirmed_weave(state, String(completed.mode))


func _try_restore_client_weave(state: PlayerState) -> void:
	if client_weave_restore_champion != state.champion_wire_id or not pending_weave_request.is_empty(): return
	if SessionRequestPolicy.validate(SessionTransport.REQUEST_WEAVE_APPLY, state, campus_layout.stations_by_id, world.tick, 0, int(_current_round_state().get("phase", SessionRound.Phase.HEARTH))) != SessionRequestPolicy.ACCEPTED: return
	client_weave_restore_champion = 0
	var requested := character_weaves.preferred_weave(state, true)
	if requested.is_empty() or requested == state.spell_wire_ids: return
	if not SessionTransport._valid_weave_wires(requested):
		station_notice = "Saved weave includes an unavailable spell; stored weave preserved."
		station_notice_seconds = 5.0
		return
	_submit_whole_weave(state, state.spell_wire_ids, requested, CharacterWeaveLibrary.MODE_CUSTOM, false)
