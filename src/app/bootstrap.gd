extends Node2D


const MAX_CATCH_UP_STEPS: int = 8
const RuntimeContentSummaryScript = preload("res://src/app/runtime_content_summary.gd")
const PlayerCompendiumScript = preload("res://src/presentation/player_compendium.gd")
const ElementExpansion = preload("res://src/app/element_expansion_controller.gd")
const ElementStatusPresenter = preload("res://src/presentation/element_status_presenter.gd")
const CharacterSelectionGridScript = preload("res://src/presentation/character_selection_grid.gd")
const ChampionAttunementScript = preload("res://src/app/champion_attunement.gd")
const ChemistryCoach = preload("res://src/presentation/chemistry_practice_coach.gd")
const MovementCoach = preload("res://src/presentation/movement_practice_coach.gd")
const DistrictCoach = preload("res://src/presentation/district_practice_coach.gd")
const ReadingPolicy = preload("res://src/presentation/ui_reading_policy.gd")
const DamageEvent = preload("res://src/sim/combat/combat_damage_event.gd")
const ElementAudioScript = preload("res://src/presentation/element_audio.gd")
const CastStartupWitnessScript = preload("res://src/presentation/cast_startup_witness.gd")
const ReadableLoom = preload("res://src/presentation/readable_spell_loom.gd")
const ReadableControls = preload("res://src/presentation/readable_controls.gd")
const ReadableChemistryDemo = preload("res://src/presentation/readable_chemistry_demo.gd")
const ReconciliationOrderBufferScript = preload("res://src/net/reconciliation_order_buffer.gd")
const SoloDuelTrial = preload("res://src/app/solo_duel_trial.gd")
const SoloDuelRival = preload("res://src/app/solo_duel_rival.gd")
const SoloTrialPanel = preload("res://src/presentation/solo_duel_trial_panel.gd")
const RoundLabel = preload("res://src/presentation/session_round_label.gd")
const TeamPresentation = preload("res://src/presentation/team_match_presentation.gd")
const DemoResultCard = preload("res://src/presentation/hex_demo_result_card.gd")
const SOLO_TRIAL_STATION := "local-solo-duel-trial"
const SOUND_DOWN_RECT := Rect2(960, 144, 40, 30)
const SOUND_UP_RECT := Rect2(1008, 144, 40, 30)
const SOUND_MUTE_RECT := Rect2(1056, 144, 76, 30)
const DIRECTION_ARROW_RECT := Rect2(650, 144, 182, 30)
const SNAPSHOT_RATE: int = 60
const EMOTE_COOLDOWN_MS: int = 1200
const STEWARD_CONFIRMATION_MS: int = 3000
const SAFE_QUIT_GRACE_MS: int = 500
const GUEST_RELEASE_REASON: String = "The host released you from the Farflow company."
const COMPANY_CLOSE_REASON: String = "The host closed the Farflow company."
const APPLICATION_CLOSE_REASON: String = "The host safely closed H.E.X."
const HUB_DEFINITION_PATH: String = "res://content/maps/sanctum_hub_v1.json"
const CAMPUS_LAYOUT_PATH: String = "res://content/maps/sanctum_campus_g2_v1.json"
const ABILITY_CATALOG_PATH: String = "res://content/abilities/foundation_abilities_v1.json"
const REACTION_CATALOG_PATH: String = ReactionCatalog.DEFAULT_PATH
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
const POV_TERRAIN_SHADE := Color(0.66, 0.66, 0.66, 1.0)
const PovTerrainBackdrop = preload("res://src/presentation/pov_terrain_backdrop.gd")
const PovTerrainBatch = preload("res://src/presentation/pov_terrain_batch.gd")
const RenderQuality = preload("res://src/presentation/render_quality.gd")
const RetainedCampus = preload("res://src/presentation/retained_campus_canvas.gd")
var retained_campus: RetainedCampus
var retained_campus_ready := false
var retained_campus_enabled := false
var pov_terrain_batch := PovTerrainBatch.new()
var terrain_loading: bool = false
var terrain_loading_error: String = ""
var element_garden_arrival_pending := false
var element_garden_arrival_error := ""
var _element_garden_arrival_world_id := 0
var _element_garden_arrival_generation := 0
var diagnostic_render_profile := false
var diagnostic_draw_stages_us: Dictionary = {}
var _visibility_frame_active := false
var _visibility_frame_bounds_ready := false
var _visibility_frame_bounds: Array[Rect2] = []
var _visibility_frame_sight_range := -1.0
var _visibility_bounds_builds := 0

var world: SimWorld
var cast_startup_witness := CastStartupWitnessScript.new()
var element_expansion := ElementExpansion.new()
var local_navigation := preload("res://src/app/local_navigation_controller.gd").new()
var element_garden := preload("res://src/app/element_garden_exhibition.gd").new()
var element_garden_presenter := preload("res://src/presentation/element_garden_presenter.gd").new()
var element_audio: ElementAudioScript
var readable_loom := ReadableLoom.new()
var readable_chemistry_demo := ReadableChemistryDemo.new()
var input_router: InputRouter
var hub_definition: HubDefinition
var campus_layout: SanctumCampusLayout
var campus_renderer: SanctumCampusRenderer
var pov_terrain_backdrop: SubViewport
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
var character_movement_trail := preload("res://src/presentation/character_movement_trail.gd").new()
var player_camera := PlayerCameraRig.new()
var service_focus := WellspringServiceBuildings.new()
var service_details_visible := false
var service_directory := WellspringServiceDirectory.new()
var directory_return_group := ""
var directory_return_station := ""
var camera_focus_entity := -1
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
var district_practice := DistrictCoach.new()
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
var last_client_world_epoch: int = -1
var client_reconciliation_buffer := ReconciliationOrderBufferScript.new()
var trusted_hex_template: SimWorld = null
var network_projectile_overflow: int = 0
var network_event_overflow: int = 0
var network_event_overflow_notice_seconds: float = 0.0
var combat_cues: Array[Dictionary] = []
var interception_feedback := InterceptionFeedback.new()
var hex_playground_open := false
var hex_playground_pair := Vector2i(3, 2)
var hex_playground_demo := HexPlaygroundDemo.new()
const HEX_PLAYGROUND_RECT := Rect2(190, 130, 900, 530)
var interception_practice_active := false
var solo_trial := SoloDuelTrial.new()
var solo_trial_menu_open := false
var solo_trial_action_index := 0
var solo_trial_error := ""
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
var requested_team_smoke: bool = false
var team_smoke_seen: Dictionary = {}
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
	_apply_performance_preferences()
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
	if not element_garden.configure(campus_layout.element_garden_plots()) or not element_garden_presenter.configure(visual_language):
		push_error("Element Garden requires validated plots and the shared ground renderer")
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
	# Pixel correctness passed; measured benefit still needs an admitted native
	# comparison. Keep the established renderer as the ordinary launch default.
	retained_campus_enabled = OS.get_cmdline_user_args().has("--retained-campus") and not OS.get_cmdline_user_args().has("--reference-campus")
	retained_campus = RetainedCampus.new()
	add_child(retained_campus)
	_configure_pov_terrain_backdrop()
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
	var pixel_body_pilot := OS.get_cmdline_user_args().has("--pixel-body-pilot")
	var pixel_cast := OS.get_cmdline_user_args().has("--pixel-cast")
	var fullbody_requested := OS.get_cmdline_user_args().has("--fullbody-art") or pixel_body_pilot or pixel_cast
	var characters_ready := cartoon_champion_presenter.configure_fullbody_startup(visual_language, pixel_body_pilot, pixel_cast) if fullbody_requested else cartoon_champion_presenter.configure(visual_language)
	if not characters_ready:
		push_error(cartoon_champion_presenter.last_error)
		get_tree().quit(1)
		return
	if fullbody_requested:
		print("H.E.X. fullbody art candidate: 30 identity skins; shared-head calibration; gameplay unchanged")
		if pixel_cast:
			print("H.E.X. fixed-pixel cast: ", cartoon_champion_presenter.fullbody_art.pixel_pilot.entries.size(), " identities; ground/cast frames; advanced-action fallback retained")
			var action_bank: RefCounted = cartoon_champion_presenter.fullbody_art.pixel_pilot.action_bank
			if action_bank != null:
				print("H.E.X. fixed-pixel action keys: ", action_bank.entries.size(), " identities; held jump keys, not complete cycles")
			elif not cartoon_champion_presenter.fullbody_art.pixel_pilot.action_bank_error.is_empty():
				print("H.E.X. optional action keys unavailable; established art retained: ", cartoon_champion_presenter.fullbody_art.pixel_pilot.action_bank_error)
		elif pixel_body_pilot:
			print("H.E.X. fixed-pixel pilot: three identities; ground/cast frames only; advanced-action fallback retained")
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
	element_expansion.configure(self)
	local_navigation.configure(self)
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
	requested_team_smoke = OS.get_cmdline_user_args().has("--farflow-smoke-team")
	requested_round_smoke = _requested_round_smoke()
	requested_rematch_smoke = _requested_rematch_smoke()
	requested_steward_smoke = _requested_steward_smoke()
	requested_spectator_smoke = _requested_spectator_smoke()
	requested_safe_quit_smoke = _requested_safe_quit_smoke()
	session_transport = SessionTransport.new()
	if _ensure_runtime_identity():
		print("FLUX2 runtime build: %s | %s" % [session_transport.build_id, session_transport.runtime_source_sha256])
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
			_open_spell_loom_editor()
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
		"FLUX2 bootstrap: %d Hz, protocol %d, movement %s, transitions %s, controls %s, POV %s/%d/%d, camera %d%%, visual %s, accessibility %s/%s/%s, HUD %s, interactions %s, spells %s/skeleton %s/directions %s, bursts %s, cartoon recipes %s/atlas %s, Sanctum districts %d, travel nodes %d, campus %s, ability catalog %s, reactions %s/bounded-combinations, champions %s, build %d/13, materials %s, yard %s"
		% [
			tick_rate,
			SimConfig.PROTOCOL_VERSION,
			MovementTuning.compatibility_hash().left(12),
			world.transition_policy.content_hash.left(12),
			player_preferences.movement_reference,
			player_preferences.pov_mode,
			player_preferences.pov_angle_degrees,
			player_preferences.pov_range,
			PlayerCameraRig.ZOOM_PERCENT,
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
	if input_router != null and player_preferences != null:
		var changed := input_router.observe_prompt_device(event)
		player_preferences.prompt_device = input_router.prompt_device
		if changed and element_expansion != null and element_expansion.guide.active: element_expansion.refresh_guide_bindings()
	if input_router != null and _gameplay_input_blocked():
		input_router.observe_input_event(event)
		input_router.discard_transient_movement_input()
	if not application_input_active:
		return
	if element_garden_arrival_pending:
		# Loading input must not open hidden menus, Range or developer routes.
		# Window-close requests remain handled by _notification.
		get_viewport().set_input_as_handled()
		return
	if local_navigation.blocks_gameplay() and local_navigation.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if element_expansion.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if _handle_solo_trial_input(event):
		return
	if _handle_demo_result_input(event):
		return
	if local_navigation.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if service_directory.is_open:
		_handle_service_directory_input(event)
		return
	if hex_playground_open:
		_handle_hex_playground_input(event)
		return
	if not _gameplay_input_blocked():
		_observe_station_activation_device(event)
		_observe_movement_practice_device(event)
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
			if _readable_ui():
				var pointer := get_viewport().get_mouse_position() / _ui_scale()
				if event is InputEventMouse: pointer = event.position / _ui_scale()
				player_compendium.handle_readable_event(event, pointer, get_viewport_rect().size / _ui_scale())
			else:
				player_compendium.handle_event(event, ThemeDB.fallback_font, get_viewport().get_mouse_position() / _compendium_scale())
			if player_compendium.consume_map_request():
				player_compendium.close_panel()
				local_navigation.open_map()
			controls_input_guard_frames = 2
			get_viewport().set_input_as_handled()
			queue_redraw()
			return
		var open_keyboard: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4
		var open_controller: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK
		if open_keyboard or open_controller:
			if open_controller:
				local_navigation.open_menu()
			else:
				_open_player_compendium(PlayerCompendiumScript.MOVEMENT, ControlBindingEditor.DEVICE_KEYBOARD)
			get_viewport().set_input_as_handled()
			return
	if controls_editor == null or not controls_editor.is_open:
		if input_router != null and controls_input_guard_frames <= 0:
			input_router.observe_input_event(event)
		return
	var handled := false
	var bindings_changed := false
	if _readable_ui() and not controls_editor.capturing and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var action := ReadableControls.pointer_action(event.position/_ui_scale(),get_viewport_rect().size/_ui_scale(),controls_editor)
		match action:
			"bind": controls_editor.begin_capture()
			"unbind": bindings_changed = controls_editor.unbind_selected(player_preferences)
			"restore": controls_editor.reset_bindings(player_preferences); bindings_changed = true
			"close": _close_controls_editor()
			"effects": _toggle_reduced_effects_preference()
			"contrast": _toggle_high_contrast_preference()
			"sound_down": _adjust_sound_volume(-10)
			"sound_up": _adjust_sound_volume(10)
			"mute": _adjust_sound_volume(0,true)
			"aim": _toggle_direction_indicator()
		if bindings_changed: _commit_control_bindings()
		controls_input_guard_frames = 2
		get_viewport().set_input_as_handled()
		queue_redraw()
		return
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
				KEY_I:
					_toggle_direction_indicator()
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
				if DIRECTION_ARROW_RECT.has_point(pointer):
					_toggle_direction_indicator()
				elif SOUND_DOWN_RECT.has_point(pointer):
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
	if _readable_ui():
		readable_loom.handle_input(self,event)
		return
	if not pending_weave_request.is_empty():
		var close_requested: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE
		close_requested = close_requested or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
		close_requested = close_requested or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and SpellLoomEditor.CLOSE_RECT.has_point(event.position / _loom_scale()))
		if close_requested:
			# Closing the view cannot revoke a request already accepted by authority.
			spell_loom_editor.cancel_starter_preview(false)
			_close_spell_loom_editor()
			station_notice = "Spell setup closed; confirmation is still pending."
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
			var pointer: Vector2 = event.position / _loom_scale()
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
		match key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode:
			KEY_ESCAPE:
				_close_spell_loom_editor()
			KEY_UP, KEY_W:
				spell_loom_editor.navigate_grid(0, -1)
			KEY_DOWN, KEY_S:
				spell_loom_editor.navigate_grid(0, 1)
			KEY_LEFT, KEY_A:
				spell_loom_editor.navigate_grid(-1, 0)
			KEY_RIGHT, KEY_D:
				spell_loom_editor.navigate_grid(1, 0)
			KEY_TAB:
				spell_loom_editor.cycle_focus()
			KEY_PAGEUP:
				spell_loom_editor.cycle_element_filter(-1)
			KEY_PAGEDOWN:
				spell_loom_editor.cycle_element_filter(1)
			KEY_Q:
				spell_loom_editor.cycle_family_filter(-1)
			KEY_E:
				spell_loom_editor.cycle_family_filter(1)
			KEY_ENTER, KEY_KP_ENTER:
				_submit_spell_loom_choice()
			KEY_HOME:
				spell_loom_editor.prepare_starter_preview(_local_player_state(), champion_catalog, ability_catalog)
			KEY_C:
				spell_loom_editor.compare_equipped = not spell_loom_editor.compare_equipped
		handled = true
	elif event is InputEventMouseMotion:
		spell_loom_editor.pointer_move((event as InputEventMouseMotion).position / _loom_scale())
		handled = true
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		var pointer := mouse_event.position / _loom_scale()
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			spell_loom_editor.navigate_wheel(-1, pointer)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			spell_loom_editor.navigate_wheel(1, pointer)
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
				spell_loom_editor.navigate_grid(0, -1)
			JOY_BUTTON_DPAD_DOWN:
				spell_loom_editor.navigate_grid(0, 1)
			JOY_BUTTON_DPAD_LEFT:
				spell_loom_editor.navigate_grid(-1, 0)
			JOY_BUTTON_DPAD_RIGHT:
				spell_loom_editor.navigate_grid(1, 0)
			JOY_BUTTON_Y:
				spell_loom_editor.cycle_focus()
			JOY_BUTTON_LEFT_SHOULDER:
				spell_loom_editor.cycle_element_filter(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				spell_loom_editor.cycle_element_filter(1)
			JOY_BUTTON_A:
				_submit_spell_loom_choice()
			JOY_BUTTON_X:
				spell_loom_editor.prepare_starter_preview(_local_player_state(), champion_catalog, ability_catalog)
			JOY_BUTTON_RIGHT_STICK:
				spell_loom_editor.compare_equipped = not spell_loom_editor.compare_equipped
			JOY_BUTTON_B:
				_close_spell_loom_editor()
		handled = true
	if handled:
		controls_input_guard_frames = 2
		get_viewport().set_input_as_handled()
		queue_redraw()


func _exit_tree() -> void:
	_cancel_element_garden_arrival()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Final teardown consumes the at-most-two outstanding background resources.
	# Normal movement and Range transitions only poll completed requests.
	if campus_renderer != null:
		campus_renderer.finish_terrain_shutdown()
	if element_audio != null:
		element_audio.silence()
	if player_preferences != null and not _save_player_preferences_if_persistent():
		push_warning(player_preferences.last_error)
	if session_transport != null:
		session_transport.stop()
	client_reconciliation_buffer.reset()


func _process(delta: float) -> void:
	if world == null:
		_cancel_element_garden_arrival()
		if retained_campus != null: retained_campus.deactivate()
		retained_campus_ready = false
		return
	element_garden.begin_frame()
	element_garden_presenter.begin_frame()
	if session_transport != null:
		session_transport.poll()
		_sync_session_transport()
	_update_team_smoke()
	_complete_pending_weave()
	_reconcile_character_attunement()
	_reconcile_demo_result()
	_update_network_feedback_notice(delta)
	if requested_safe_quit_smoke and not safe_quit_pending:
		safe_quit_smoke_seconds += delta
		if safe_quit_smoke_seconds >= 0.25:
			_request_safe_quit("smoke")
			return
	if safe_quit_pending:
		_advance_safe_quit()
		return
	_prepare_terrain_frame()
	_prepare_element_garden_arrival_frame()
	# Offline arrival waits for exact ground, without a catch-up burst afterward.
	# Hosting and clients continue authority even if local art is still loading.
	if _area_loading() and session_transport != null and session_transport.mode == SessionTransport.Mode.OFFLINE:
		accumulator_seconds = 0.0
		input_router.discard_transient_movement_input()
		if element_audio != null: element_audio.silence()
		_prepare_retained_campus()
		queue_redraw()
		return
	_update_reconnect_smoke(delta)
	if player_compendium != null and player_compendium.is_open:
		player_compendium.refresh_status(_local_player_state())
	var controls_blocking := _gameplay_input_blocked()
	character_movement_trail.begin_frame(delta, not controls_blocking and not _reduced_effects_enabled())
	if element_audio != null and _audio_tails_blocked(controls_blocking):
		element_audio.silence()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if controls_blocking or not get_window().has_focus() else Input.MOUSE_MODE_HIDDEN
	if controls_input_guard_frames > 0:
		controls_input_guard_frames -= 1
	if not controls_blocking and not interception_practice_active:
		_handle_preference_actions()
		if Input.is_action_just_pressed(&"practice_trace"):
			movement_trace.toggle(world.tick, _player_position(), _local_player_state().champion_wire_id)
		if Input.is_action_just_pressed(&"practice_retry"):
			movement_trace.begin(world.tick, _player_position(), _local_player_state().champion_wire_id)
	if not controls_blocking and Input.is_action_just_pressed(&"toggle_debug_overlay"):
		show_debug_overlay = not show_debug_overlay
	if not controls_blocking and not interception_practice_active and Input.is_action_just_pressed(&"reset_match"):
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
	_update_service_directory(delta)
	controls_blocking = controls_blocking or _gameplay_input_blocked()
	_update_service_details(delta)
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
			player_camera.clear()
			camera_focus_entity = -1
			station_notice = "Following %s." % _spectator_name(next_focus_id)
			station_notice_seconds = 1.5
	if not controls_blocking and Input.is_action_just_pressed(InputRouter.INTERACT_ACTION) and not _is_spectating():
		_open_focused_service_directory()
		# A station can open a modal during this frame; never sample the same
		# interaction press as a movement or spell command afterwards.
		controls_blocking = controls_blocking or _gameplay_input_blocked()
	if controls_blocking:
		input_router.discard_transient_movement_input()
	if not controls_blocking and not interception_practice_active and Input.is_action_just_pressed(InputRouter.EMOTE_ACTION):
		_submit_session_request(SessionTransport.REQUEST_EMOTE)

	# Only a completed, explicitly offline trial freezes its final authority.
	# Menus and focus loss during a live attempt still submit neutral commands.
	if _solo_trial_frozen():
		accumulator_seconds = 0.0
		_prepare_active_character_pages()
		_advance_player_camera(delta, controls_blocking)
		_prepare_retained_campus()
		queue_redraw()
		return
	var fixed_delta: float = 1.0 / float(tick_rate)
	clamped_frame_time_seconds += maxf(0.0, delta - 0.1)
	accumulator_seconds += minf(delta, 0.1)
	var steps: int = 0
	while accumulator_seconds >= fixed_delta and steps < MAX_CATCH_UP_STEPS and not _solo_trial_frozen():
		# Frame-start already services tick zero. During a long host frame, admit
		# newly arrived commands before the next existing authority tick. Client
		# snapshot/prediction synchronization remains at the frame boundary.
		if steps > 0 and session_transport != null and session_transport.is_host():
			var catch_up_world := world
			session_transport.poll()
			_sync_session_transport()
			if world != catch_up_world or not session_transport.is_host():
				_advance_player_camera(delta, controls_blocking)
				_prepare_retained_campus()
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
		var pointer_world_position := Vector2(capture_pointer_world) if capture_pointer_world.x >= 0 else PlayerCameraRig.screen_to_world(get_viewport().get_mouse_position(), camera_origin)
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
		if hex_playground_demo.is_active() and not session_transport.is_connected_client():
			var guided_command := hex_playground_demo.command(world)
			if guided_command != null: command = guided_command
		if session_transport.is_connected_client():
			if _client_world_ready() and not _is_spectating():
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
			element_expansion.before_step()
			if interception_practice_active:
				var practice_command := _solo_rival_command()
				if practice_command != null:
					commands.append(practice_command)
			elif element_expansion.training.active:
				var range_command: SimCommand = element_expansion.range_target_command()
				if range_command != null: commands.append(range_command)
			if session_transport.is_host():
				commands = authoritative_session.commands_for_tick(command)
			var step_started_tick := world.tick
			if not world.step(commands):
				push_error(world.last_error)
				set_process(false)
				break
			# Only this synchronous authority boundary can witness the paid total.
			# Replica event ingestion may arrive after startup has already advanced.
			cast_startup_witness.observe_local_step(world, world.combat_events, step_started_tick)
			element_expansion.after_paid_step(commands)
			element_expansion.after_step()
			_update_element_garden()
			if interception_practice_active and solo_trial.is_running() and not element_expansion.challenge_active:
				solo_trial.observe(world)
				if solo_trial.is_finished():
					solo_trial_action_index = 0
					_solo_trial_input_handoff()
			if session_transport.is_host() and authoritative_session.practice_countdown_completed():
				if _begin_shared_practice():
					_prepare_retained_campus()
					queue_redraw()
					return
				push_error("Shared practice could not begin")
				set_process(false)
				return
			if session_transport.is_host():
				var round_events := authoritative_session.advance_round(world.combat_events)
				_ingest_session_feedback(round_events)
				if requested_rematch_smoke and (world.tick % 30 == 0 or not round_events.is_empty()):
					print("HEX trace round ms=%d tick=%d phase=%d result_end=%d due=%s" % [Time.get_ticks_msec(), world.tick, authoritative_session.session_round.phase, authoritative_session.session_round.result_end_tick, authoritative_session.round_return_due()])
				_update_steward_smoke()
				if authoritative_session.round_return_due():
					if _return_to_hearth():
						_prepare_retained_campus()
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
				var snapshot_started := Time.get_ticks_usec() if requested_rematch_smoke else 0
				var snapshot_sent := session_transport.broadcast_session(authoritative_session)
				if requested_rematch_smoke and world.tick % 30 == 0:
					print("HEX trace snapshot ms=%d tick=%d capture_send_us=%d sent=%s" % [Time.get_ticks_msec(), world.tick, Time.get_ticks_usec() - snapshot_started, snapshot_sent])
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
	if _solo_trial_frozen():
		accumulator_seconds = 0.0
		previous_position = current_position
		_reset_motion_history()
	_prepare_active_character_pages()
	_update_character_gaits(delta)
	# Follow the same interpolated sample that _draw will present. Advancing the
	# camera before the fixed steps made it follow the previous frame's feet,
	# introducing a changing screen-space offset during catch-up and acceleration.
	_advance_player_camera(delta, controls_blocking)
	_prepare_retained_campus()
	queue_redraw()


func _prepare_retained_campus() -> void:
	retained_campus_ready = false
	if retained_campus == null: return
	if not retained_campus_enabled or world == null or _area_loading() or _is_hex_practice():
		retained_campus.deactivate()
		return
	var alpha := clampf(accumulator_seconds * float(tick_rate), 0.0, 1.0)
	var focus := _camera_focus_position(previous_position.lerp(current_position, alpha))
	var origin := _camera_origin(focus)
	var visual_tick := MinimalChampionMotion.tick_at_visual_rate(world.tick, tick_rate, alpha)
	var context := _campus_court_context()
	var world_transform := Transform2D(0.0, Vector2.ONE * _camera_zoom_scale(), 0.0, PixelPresentation.snapped_canvas_origin(origin, PlayerCameraRig.ZOOM_PERCENT))
	retained_campus.profile_enabled = diagnostic_render_profile
	retained_campus_ready = retained_campus.present(campus_renderer, campus_layout, roundi(visual_tick), focus, _reduced_effects_enabled(), true, Rect2(origin, get_viewport_rect().size / _camera_zoom_scale()), true, context, world_transform)


func _campus_court_context() -> String:
	if element_expansion.challenge_active:
		var proving := SanctumCampusLayout._parse_bounds(campus_layout.arena_definition.bounds)
		var fixed_proving := Rect2i(proving.position * SimConfig.FIXED_SCALE, proving.size * SimConfig.FIXED_SCALE)
		return SanctumCampusRenderer.SIGNATURE_CHALLENGE_CONTEXT if element_expansion.challenge.trial.court == fixed_proving else ""
	return SanctumCampusRenderer.SOLO_DUEL_CONTEXT if interception_practice_active else ""


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
	if _character_gallery_open():
		var inspected: Dictionary = character_selection_grid.model.selected_entry()
		var inspected_id := String(inspected.get("id", ""))
		if not inspected_id.is_empty() and inspected_id not in active_ids: active_ids.append(inspected_id)
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


func _element_garden_available() -> bool:
	return world != null and session_transport != null and session_transport.mode == SessionTransport.Mode.OFFLINE and not _is_hex_practice() and not interception_practice_active and int(_current_round_state().get("phase", SessionRound.Phase.HEARTH)) == SessionRound.Phase.HEARTH

func _update_element_garden() -> void:
	if not _element_garden_available():
		element_garden.clear()
		_cancel_element_garden_arrival()
		return
	var observer := _player_position()
	var origin := _camera_origin(_camera_focus_position(observer))
	element_garden.step(Rect2(origin, get_viewport_rect().size / _camera_zoom_scale()), observer)
	_element_garden_arrival_world_id = 0
	_element_garden_arrival_generation = 0

func _draw() -> void:
	if world == null:
		return
	if _area_loading():
		_draw_terrain_loading()
		return
	_begin_visibility_frame()
	var stage_started := Time.get_ticks_usec() if diagnostic_render_profile else 0
	if diagnostic_render_profile: diagnostic_draw_stages_us.clear()
	var alpha: float = clampf(accumulator_seconds * float(tick_rate), 0.0, 1.0)
	var rendered_position: Vector2 = previous_position.lerp(current_position, alpha)
	var camera_focus_position := _camera_focus_position(rendered_position)
	var camera_origin: Vector2 = _camera_origin(camera_focus_position)
	if not _is_hex_practice() and pov_terrain_backdrop != null:
		pov_terrain_backdrop.prepare_view(Rect2(camera_origin, get_viewport_rect().size / _camera_zoom_scale()))
	var visual_tick := MinimalChampionMotion.tick_at_visual_rate(world.tick, tick_rate, alpha)
	PixelMagicLibrary.default_library().begin_frame(_reduced_effects_enabled())
	if _is_hex_practice():
		draw_rect(get_viewport_rect(), Color("25331f"))
	_set_world_transform(camera_origin)
	if not _is_hex_practice() and not retained_campus_ready:
		var court_context := _campus_court_context()
		campus_renderer.draw(self, campus_layout, roundi(visual_tick), camera_focus_position, _reduced_effects_enabled(), true, Rect2(camera_origin, get_viewport_rect().size / _camera_zoom_scale()), true, court_context)
	stage_started = _record_draw_stage("campus_and_setup", stage_started)
	if _element_garden_available():
		element_garden_presenter.draw_ground(self, element_garden.render_entries(), _reduced_effects_enabled())
	stage_started = _record_draw_stage("garden", stage_started)
	# Genuine paid material remains above harmless exhibits, including on a plot.
	if world.hex_court != null:
		hex_court_presenter.draw_ground_in_view(self, world.hex_court, float(world.tick) + alpha, _reduced_effects_enabled(), _is_hex_practice(), Rect2(camera_origin, get_viewport_rect().size / _camera_zoom_scale()))
	stage_started = _record_draw_stage("paid_ground", stage_started)
	if interception_practice_active and solo_trial.court.has_area():
		# An administrative trial boundary, never an invisible wall or damage area.
		var trial_bounds := Rect2(Vector2(solo_trial.court.position) / SimConfig.FIXED_SCALE, Vector2(solo_trial.court.size) / SimConfig.FIXED_SCALE)
		draw_rect(trial_bounds.grow(-1.0), Color("b88438"), false, 2.0)
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
	stage_started = _record_draw_stage("projectiles_targets_cues", stage_started)
	var state: PlayerState = _local_player_state()
	if state == null:
		character_movement_trail.end_frame()
		draw_set_transform(Vector2.ZERO)
		_draw_pov_terrain(SightOcclusion.rectangle_polygon(get_viewport_rect()), camera_origin)
		_end_visibility_frame()
		return
	var spectating := _is_spectating()
	var observed_state: PlayerState = _spectator_state() if spectating else state
	if observed_state == null:
		observed_state = state
	var team_markers := TeamPresentation.marker_lookup(_current_round_state(), state.entity_id)
	_draw_remote_travellers(camera_origin, state.entity_id, visual_tick, team_markers, -1, rendered_position.y)
	var local_label_position := Vector2(INF, INF)
	var presentation_state: PlayerState = client_prediction.predicted_state if session_transport.is_connected_client() and client_prediction.is_ready() else state
	var local_cast_timing := _cast_timing_for(state)
	if _chemistry_actor_visible(state):
		var presentation := JumpPresentation.sample(presentation_state, world.config, alpha, _reduced_effects_enabled(), previous_air_height)
		var landing := LandingPresentation.sample(presentation_state, world.config, alpha, _reduced_effects_enabled())
		var player_radius: float = float(MovementTuning.PLAYER_RADIUS) / 1000.0
		var shadow_center := rendered_position + Vector2(0.0, player_radius * 0.58)
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
			_draw_character_movement_trail(state, presentation_state, presentation_champion_id, sprite_anchor)
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
				actor_motion_history.wall_travel(presentation_state.entity_id),
				local_cast_timing,
			)
		if not sprite_drawn:
			draw_circle(body_position, player_radius + 5.0, Color(ATTUNEMENT_COLOR, 0.18))
			draw_circle(body_position, player_radius, PLAYER_COLOR)
			draw_arc(body_position, player_radius + 2.0, 0.0, TAU, 24, PARCHMENT_COLOR, 2.0)
		if show_debug_overlay:
			_draw_actor_hitbox_diagnostic(body_position, float(presentation_state.radius) / 1000.0, presentation_champion_id)
		_draw_spell_startup(presentation_state, sprite_anchor, roundi(visual_tick), local_cast_timing)
		ElementStatusPresenter.draw(self, state, body_position, world.config, visual_language, _reduced_effects_enabled())
		local_label_position = body_position
		if state.spawn_protection_ticks > 0:
			var protection_ratio := clampf(float(state.spawn_protection_ticks) / float(maxi(1, world.config.milliseconds_to_ticks(1200))), 0.0, 1.0)
			draw_arc(body_position, player_radius + 9.0, 0.0, TAU, 28, Color(ATTUNEMENT_COLOR, 0.32 + protection_ratio * 0.42), 2.0)
	_draw_remote_travellers(camera_origin, state.entity_id, visual_tick, team_markers, 1, rendered_position.y)
	character_movement_trail.end_frame()
	_draw_social_bubbles(camera_origin)
	stage_started = _record_draw_stage("actors", stage_started)
	draw_set_transform(Vector2.ZERO)
	var pov_position := _pov_observer_ground_position(observed_state, spectating, rendered_position)
	var pov_aim_state := observed_state if spectating else presentation_state
	_draw_pov_mask(pov_position * _camera_zoom_scale() + PixelPresentation.snapped_canvas_origin(camera_origin, PlayerCameraRig.ZOOM_PERCENT), Vector2(CartoonChampionPresenter.presentation_facing_vector(pov_aim_state)), camera_origin)
	_draw_pov_observer_body(camera_origin, visual_tick, alpha)
	stage_started = _record_draw_stage("visibility", stage_started)
	# Only the living owned actor is exempt from the POV mask. Remote labels
	# stay beneath it; never reveal an occluded opponent through this overlay.
	if not spectating and state.health > 0 and local_label_position.is_finite() and _chemistry_actor_visible(state):
		_set_world_transform(camera_origin)
		_draw_team_identity(team_markers.get(state.entity_id, {}), local_label_position)
		draw_set_transform(Vector2.ZERO)
	if player_preferences.direction_indicator and not spectating and presentation_state.health > 0:
		_set_world_transform(camera_origin)
		var arrow := player_camera.ground_arrow(rendered_position + Vector2(0, 10.44), Vector2(presentation_state.aim_x, presentation_state.aim_y))
		if arrow.size() == 3:
			draw_colored_polygon(arrow, Color("f2e4b7"))
			draw_line(arrow[0], arrow[1], Color("202831"), 1.5)
			draw_line(arrow[1], arrow[2], Color("202831"), 1.5)
			draw_line(arrow[2], arrow[0], Color("202831"), 1.5)
		draw_set_transform(Vector2.ZERO)
	_draw_station_bubble(camera_origin) # Local UI is never part of world occlusion.
	draw_set_transform(Vector2.ZERO)
	if not spectating and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN and not input_router.is_controller_aim_active():
		var aim_direction := Vector2(presentation_state.aim_x, presentation_state.aim_y).normalized()
		var reticle_position := get_viewport().get_mouse_position()
		if capture_pointer_world.x >= 0:
			reticle_position = (Vector2(capture_pointer_world) - camera_origin) * _camera_zoom_scale()
		AimReticlePresenter.draw(self, reticle_position, aim_direction)
	var observed_champion_id := _champion_visual_id(observed_state)
	var champion_data: Dictionary = champion_catalog.champion(observed_champion_id)
	var champion_name := String(champion_data.get("display_name", observed_champion_id))
	var location_name := "PROVING COURT" if int(_current_round_state().get("phase", SessionRound.Phase.HEARTH)) != SessionRound.Phase.HEARTH else "THE WELLSPRING"
	if _is_hex_practice():
		location_name = "HEX CHEMISTRY COURT"
	_draw_station_notice(location_name)
	var active_layer: int = 2 if Input.is_action_pressed(InputRouter.SPELL_ALT_LAYER_ACTION) else (1 if Input.is_action_pressed(InputRouter.SPELL_CTRL_LAYER_ACTION) else 0)
	stage_started = _record_draw_stage("local_labels_reticle", stage_started)
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
			player_preferences,
			local_cast_timing if observed_state == state else _cast_timing_for(observed_state),
		)
		draw_set_transform(Vector2.ZERO)
	stage_started = _record_draw_stage("combat_hud", stage_started)
	if show_debug_overlay and (dropped_time_seconds > 0.0 or clamped_frame_time_seconds > 0.0):
		draw_string(ThemeDB.fallback_font, Vector2(32, 132), "FRAME CLAMP %.3fs / CATCH-UP DROPPED %.3fs" % [clamped_frame_time_seconds, dropped_time_seconds], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, FIRE_COLOR)
	if show_debug_overlay:
		_draw_material_yard_preview()
	_draw_practice_coach()
	stage_started = _record_draw_stage("practice_coach", stage_started)
	if _element_garden_available() and not _gameplay_input_blocked() and not element_expansion.guide.active:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _ui_scale())
		var garden_info: Dictionary = element_garden.nearest_info(rendered_position)
		var inspected_center: Vector2 = garden_info.get("center", rendered_position)
		var inspected_screen := (inspected_center - camera_origin) * _camera_zoom_scale() / _ui_scale()
		element_garden_presenter.draw_info(self, garden_info, get_viewport_rect().size / _ui_scale(), ThemeDB.fallback_font, inspected_screen, 118.0 * _camera_zoom_scale() / _ui_scale())
		draw_set_transform(Vector2.ZERO)
	stage_started = _record_draw_stage("garden_inspection", stage_started)
	# Controller aim must stay above nonmodal HUD panels at a clamped edge, but
	# never leak across a modal or focus handoff. Mouse placement/order is unchanged.
	if not spectating and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN and input_router.is_controller_aim_active() and not _gameplay_input_blocked() and not show_visual_specimen:
		var aim_direction := Vector2(presentation_state.aim_x, presentation_state.aim_y).normalized()
		var requested := (rendered_position + aim_direction * 320.0 - camera_origin) * _camera_zoom_scale()
		var reticle_position := AimReticlePresenter.controller_position((rendered_position - camera_origin) * _camera_zoom_scale(), requested, get_viewport_rect())
		AimReticlePresenter.draw(self, reticle_position, aim_direction)
	if controls_editor != null and controls_editor.is_open:
		var controls_ui_scale := _ui_scale()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * controls_ui_scale)
		_draw_controls_editor()
		draw_set_transform(Vector2.ZERO)
	elif spell_loom_editor != null and spell_loom_editor.is_open:
		var loom_ui_scale := _loom_scale()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * loom_ui_scale)
		_draw_spell_loom_editor()
		draw_set_transform(Vector2.ZERO)
	if hex_playground_open:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _ui_scale())
		_draw_hex_playground_panel()
		draw_set_transform(Vector2.ZERO)
	if show_visual_specimen:
		VisualSpecimen.draw(self, visual_language, get_viewport_rect().size, world.tick)
	if player_compendium != null and player_compendium.is_open:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (_ui_scale() if _readable_ui() else _compendium_scale()))
		if _readable_ui(): player_compendium.draw_readable(self, get_viewport_rect().size / _ui_scale())
		else: player_compendium.draw(self, ThemeDB.fallback_font)
		draw_set_transform(Vector2.ZERO)
	if _character_gallery_open():
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (_ui_scale() if _readable_ui() else _compendium_scale()))
		if _readable_ui(): character_selection_grid.draw_readable(self, get_viewport_rect().size / _ui_scale(), _gallery_selection_availability(_local_player_state()))
		else: character_selection_grid.draw(self, ThemeDB.fallback_font, _gallery_selection_availability(_local_player_state()))
		draw_set_transform(Vector2.ZERO)
	if service_directory.is_open:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _ui_scale())
		service_directory.draw(self, get_viewport_rect().size / _ui_scale())
		draw_set_transform(Vector2.ZERO)
	if solo_trial_menu_open or (interception_practice_active and solo_trial.is_finished() and not element_expansion.challenge_active):
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _ui_scale())
		SoloTrialPanel.draw_modal(self, get_viewport_rect().size / _ui_scale(), solo_trial.view() if interception_practice_active else {}, _solo_trial_kit_lines(), solo_trial_action_index, solo_trial_error)
		draw_set_transform(Vector2.ZERO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _ui_scale())
	element_expansion.draw(self, ThemeDB.fallback_font, get_viewport_rect().size / _ui_scale())
	local_navigation.draw(self, ThemeDB.fallback_font, get_viewport_rect().size / _ui_scale())
	draw_set_transform(Vector2.ZERO)
	_record_draw_stage("panels", stage_started)
	_end_visibility_frame()


func _record_draw_stage(label: String, started: int) -> int:
	if not diagnostic_render_profile: return 0
	var now := Time.get_ticks_usec()
	diagnostic_draw_stages_us[label] = now - started
	return now


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
	if world.hex_court != null:
		return ChemistryCoach.sample_hex(state.entity_id, Vector2i(state.position_x, state.position_y),
			world.tick, world.config, group.get("bounds", []), world.hex_court)
	return ChemistryCoach.sample(state.entity_id, Vector2i(state.position_x, state.position_y),
		world.tick, world.config, group.get("bounds", []), world.deposits, world.reactions)


func _movement_practice_view() -> Dictionary:
	var state := _free_practice_actor()
	if state == null or player_preferences == null:
		return {}
	for activity: Dictionary in campus_layout.data.get("activity_areas", []):
		if String(activity.get("id", "")) == "south-movement-loop":
			var south := MovementCoach.sample(state, player_preferences,
				SanctumCampusLayout._parse_bounds(activity.get("bounds", [])), movement_practice_device)
			if not south.is_empty(): return south
	return district_practice.view(state,player_preferences)


func _draw_practice_coach() -> void:
	var trial_scale := _ui_scale()
	if element_expansion.challenge_active or element_expansion.guide.active: return
	if interception_practice_active and solo_trial.phase != SoloDuelTrial.IDLE:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * trial_scale)
		SoloTrialPanel.draw_live(self, solo_trial, SoloDuelRival.status(world.tick, int(interception_practice_setup.start_tick)))
		draw_set_transform(Vector2.ZERO)
		return
	if _is_hex_practice():
		_draw_hex_court_help()
		return
	if hex_playground_demo.is_active():
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * trial_scale)
		draw_string(ThemeDB.fallback_font, Vector2(24, 102), hex_playground_demo.status(), HORIZONTAL_ALIGNMENT_LEFT, 1100, 14, PARCHMENT_COLOR)
		draw_set_transform(Vector2.ZERO)
	else:
		var result_view := _demo_result_view()
		if not result_view.is_empty():
			DemoResultCard.draw(self, result_view, get_viewport_rect().size, get_viewport().get_mouse_position())
			return # One teaching card, not two overlapping practice explanations.
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
	var phase_label := "PHASE %ds | ENCOUNTER %ds" % [ceili(float(view.remaining_ticks) / tick_rate), ceili(float(view.total_remaining_ticks) / tick_rate)] if interception_practice_active else String(view.phase)
	draw_string(ThemeDB.fallback_font, left + Vector2(0, 18), phase_label, HORIZONTAL_ALIGNMENT_LEFT, text_width, 11, ATTUNEMENT_COLOR)
	for index: int in range(lines.size()):
		draw_string(ThemeDB.fallback_font, left + Vector2(0, 43 + index * 18), lines[index], HORIZONTAL_ALIGNMENT_LEFT, text_width, 12, PALE_STONE_COLOR)
	if not bool(card.expanded):
		draw_string(ThemeDB.fallback_font, panel.position + Vector2(panel.size.x - 83, 18), "HOVER / F4", HORIZONTAL_ALIGNMENT_RIGHT, 69, 9, PALE_STONE_COLOR)
	draw_set_transform(Vector2.ZERO)


func _draw_controls_editor() -> void:
	if _readable_ui():
		ReadableControls.draw(self,get_viewport_rect().size/_ui_scale(),controls_editor,player_preferences)
		return
	var panel := ControlBindingEditor.PANEL_RECT
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color("060907a8"), true)
	draw_rect(panel, Color(PANEL_COLOR, 0.97), true)
	draw_rect(panel, Color(BRASS_COLOR, 0.92), false, 3.0)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(38, 42), "CONTROLS", HORIZONTAL_ALIGNMENT_LEFT, 450.0, 25, PARCHMENT_COLOR)
	draw_rect(DIRECTION_ARROW_RECT, Color("26352fe6"), true)
	draw_rect(DIRECTION_ARROW_RECT, Color(BRASS_COLOR, 0.6), false, 1.0)
	draw_string(ThemeDB.fallback_font, DIRECTION_ARROW_RECT.position + Vector2(6,20), "[I] AIM ARROW: %s" % ("ON" if player_preferences.direction_indicator else "OFF"), HORIZONTAL_ALIGNMENT_CENTER, 170, 11, PARCHMENT_COLOR)
	draw_string(ThemeDB.fallback_font, Vector2(846, 165), "SOUND %d%%" % player_preferences.sound_volume_percent, HORIZONTAL_ALIGNMENT_LEFT, 110, 12, ATTUNEMENT_COLOR)
	for button: Rect2 in [SOUND_DOWN_RECT, SOUND_UP_RECT, SOUND_MUTE_RECT]:
		draw_rect(button, Color("26352fe6"), true)
		draw_rect(button, Color(BRASS_COLOR, 0.6), false, 1.0)
		var label := "-" if button == SOUND_DOWN_RECT else ("+" if button == SOUND_UP_RECT else ("UNMUTE" if player_preferences.sound_volume_percent == 0 else "MUTE"))
		draw_string(ThemeDB.fallback_font, button.position + Vector2(5, 20), label, HORIZONTAL_ALIGNMENT_CENTER, button.size.x - 10.0, 11, PARCHMENT_COLOR)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(38, 68), "Saved on this device.", HORIZONTAL_ALIGNMENT_LEFT, 410.0, 14, PALE_STONE_COLOR)
	draw_string(
		ThemeDB.fallback_font,
		panel.position + Vector2(500, 68),
		"FX %s | CONTRAST %s" % ["REDUCED" if _reduced_effects_enabled() else "FULL", "HIGH" if visual_accessibility_filter.current_profile_id == "high_contrast" else "STANDARD"],
		HORIZONTAL_ALIGNMENT_RIGHT,
		280.0,
		12,
		ATTUNEMENT_COLOR,
	)
	var visible_indices: Array[int] = controls_editor.visible_action_indices()
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(840, 68), "ACTIONS %d-%d / %d" % [visible_indices.front() + 1, visible_indices.back() + 1, ControlBindingEditor.ACTIONS.size()], HORIZONTAL_ALIGNMENT_RIGHT, 160.0, 12, ATTUNEMENT_COLOR)
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
	var help := "PRESS THE CHOSEN INPUT | ESC / BACK CANCELS" if controls_editor.capturing else "ARROWS / DPAD SELECT | ENTER / A BIND | M / L3 EFFECTS | H / R3 CONTRAST | ESC / B CLOSE"
	draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 38, footer_y + 27), help, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 76.0, 12, PALE_STONE_COLOR)
	if not controls_editor.capturing:
		draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 38, footer_y + 45), "SOUND: [ / ] or LB / RB adjust  |  0 / START mute  |  Click header buttons", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 76.0, 11, PALE_STONE_COLOR)


func _draw_spell_loom_editor() -> void:
	var state := _local_player_state()
	var requested := _loom_presented_request(state)
	if _readable_ui():
		readable_loom.draw(self,get_viewport_rect().size/_loom_scale(),spell_loom_editor,state,ability_catalog,player_preferences,_loom_assignment_availability(state,requested,spell_loom_editor.starter_preview_active()),readable_loom.page)
		return
	SpellLoomPresenter.draw_panel(self, spell_loom_editor, state, ability_catalog, visual_language, player_preferences, _loom_assignment_availability(state, requested, spell_loom_editor.starter_preview_active()))


func _ingest_combat_cues(events: Array[Dictionary]) -> void:
	if element_audio != null and world != null: element_audio.begin_batch(world.tick)
	# Consequences get the first admission opportunity before cast chatter.
	for event: Dictionary in events: _ingest_consequence_audio(event)
	for event: Dictionary in events:
		if String(event.get("type", "")) == "spray_intercepted":
			var contact_point := Vector2(int(event.get("x", 0)), int(event.get("y", 0))) / 1000.0
			var contact_view := Rect2(_camera_origin(_camera_focus_position(current_position)), get_viewport_rect().size / _camera_zoom_scale())
			if contact_view.has_point(contact_point) and _pov_point_visible(contact_point):
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
					label = "SPELL LIMIT | LET ONE FADE"
				elif refusal_reason == "hex_capacity":
					label = "COURT FULL | LET MATTER FADE"
				elif refusal_reason == "hex_water_fire_only":
					label = "THIS COURT: WATER + FIRE"
				elif refusal_reason == "startup_commitment":
					label = "FINISH WEAVE"
				elif refusal_reason.begins_with("control_"):
					label = "NO CAST | %s" % refusal_reason.trim_prefix("control_").to_upper()
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
			"visibility_entity_id": int(event.get("target_id", event.get("entity_id", 0))),
			"label": label,
			"color": color,
			"event_type": kind,
			"source_wire_id": int(event.get("source_wire_id", event.get("wire_id", 0))),
			"remaining": 0.20 if kind in ["beam_fired", "spray_fired"] else 0.55,
			"duration": 0.20 if kind in ["beam_fired", "spray_fired"] else 0.55,
		}
		# Cosmetic emphasis is based only on reported hit damage, never inferred
		# spell strength or a fabricated fallback for missing event fields.
		if kind in ["projectile_hit", "spray_hit"] and typeof(event.get("damage")) == TYPE_INT and int(event.damage) >= 0:
			cue["damage"] = int(event.damage)
		if kind == "beam_fired":
			var owner: PlayerState = world.player(int(event.get("owner_id", 0)))
			cue["kind"] = "beam"
			cue["visibility_source_id"] = int(event.get("owner_id", 0))
			cue["start"] = _pov_actor_ground_position(owner) if owner != null else anchor["position"]
			if event.has("origin_x") and event.has("origin_y"):
				cue["start"] = Vector2(float(event["origin_x"]), float(event["origin_y"])) / 1000.0
			cue["end"] = anchor["position"]
		elif kind == "spray_fired":
			var spray_owner: PlayerState = world.player(int(event.get("owner_id", 0)))
			cue["kind"] = "spray"
			cue["visibility_source_id"] = int(event.get("owner_id", 0))
			cue["range"] = int(event.get("range", -1))
			cue["start"] = _pov_actor_ground_position(spray_owner) if spray_owner != null else anchor["position"]
			cue["end"] = anchor["position"]
			if world.hex_court != null:
				# Resolve known cover once, not during every frame of this finite cue.
				cue["spray_geometry"] = HexCourtPresenter.prepare_spray_cue(cue, world.collision)
		combat_cues.append(cue)
	while combat_cues.size() > 24:
		combat_cues.pop_front()
	if element_audio != null: element_audio.end_batch()


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
		var contact_point := Vector2(int(event.get("x", 0)), int(event.get("y", 0))) / 1000.0
		var contact_view := Rect2(_camera_origin(_camera_focus_position(current_position)), get_viewport_rect().size / _camera_zoom_scale())
		if not contact_view.has_point(contact_point) or not _pov_point_visible(contact_point):
			return
	elif String(event.get("type", "")) != "cast_started":
		var target := world.player(int(event.get("target_id", 0)))
		if target == null or not _chemistry_actor_visible(target):
			return # No extra information about concealed or absent targets.
		var target_position := _pov_actor_ground_position(target)
		var visible_world := Rect2(_camera_origin(_camera_focus_position(current_position)), get_viewport_rect().size / _camera_zoom_scale())
		if not visible_world.has_point(target_position):
			return # Off-screen hits do not become an extra source of information.
	element_audio.ingest(event, world.tick, actor.entity_id, ability_catalog, true)


func _ingest_consequence_audio(event: Dictionary) -> void:
	if element_audio == null or world == null or _gameplay_input_blocked() or _is_spectating(): return
	var actor := _local_player_state()
	if actor == null: return
	if session_transport != null and session_transport.is_connected_client() and actor.entity_id != session_transport.local_entity_id: return
	if DamageEvent.target_id(event) == actor.entity_id and DamageEvent.amount(event) > 0:
		element_audio.consequence("damage",world.tick)
	elif String(event.get("type","")) == "cast_refused" and int(event.get("entity_id",0)) == actor.entity_id:
		element_audio.consequence("refused",world.tick)


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
	var body := _pov_actor_ground_position(actor) - Vector2(0.0, float(lift.body_lift_pixels))
	body.y += float(MovementTuning.PLAYER_RADIUS) / 1000.0 * 0.58
	combat_cues.append({
		"kind": "pixel_release", "release_key": key,
		"visibility_entity_id": actor.entity_id,
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
			return {"position": _pov_actor_ground_position(state)}
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
	interception_feedback.draw(self, visual_language, _reduced_effects_enabled(), _pov_point_visible)
	for retained_cue: Dictionary in combat_cues:
		var cue: Dictionary = retained_cue
		if world.hex_court != null and String(cue.get("kind", "")) == "spray":
			# Resolve current observer visibility once. Cached physical spokes remain
			# unchanged when the observer, chemistry or Reduced Effects changes.
			cue = _spray_cue_draw_view(retained_cue)
			if cue.is_empty(): continue
		elif not _combat_cue_visible(cue):
			continue
		var remaining := float(cue.get("remaining", 0.0))
		var duration := maxf(0.001, float(cue.get("duration", 0.55)))
		cue["age_ticks"] = maxi(0, roundi((duration - remaining) * float(tick_rate)))
		if world.hex_court != null:
			if not foundation_spell_presenter.draw_expanded_cue(self, cue, _reduced_effects_enabled()):
				hex_court_presenter.draw_cue(self, cue, _reduced_effects_enabled())
			preload("res://src/presentation/hex_combat_label.gd").draw(self, cue, _reduced_effects_enabled(), visual_language.ramp_color("worldbone", 0))
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


func _draw_remote_travellers(camera_origin: Vector2, local_entity_id: int, visual_tick: float, team_markers: Dictionary = {}, draw_side: int = 0, local_y: float = 0.0) -> void:
	var viewport_policy = preload("res://src/presentation/character_viewport_policy.gd")
	var body_viewport := get_viewport_rect()
	var motion_alpha := clampf(remote_snapshot_age_seconds * 60.0 if session_transport.is_connected_client() else accumulator_seconds * float(tick_rate), 0.0, 1.0)
	var depth_order := world.players.duplicate()
	depth_order.sort_custom(func(a: PlayerState, b: PlayerState) -> bool: return a.position_y < b.position_y or (a.position_y == b.position_y and a.entity_id < b.entity_id))
	for remote_state: PlayerState in depth_order:
		if remote_state.actor_kind != PlayerState.ActorKind.CHAMPION or remote_state.entity_id == local_entity_id:
			continue
		if not _chemistry_actor_visible(remote_state):
			continue
		var position := _pov_actor_ground_position(remote_state)
		var behind_local := position.y < local_y or (is_equal_approx(position.y, local_y) and remote_state.entity_id < local_entity_id)
		if (draw_side < 0 and not behind_local) or (draw_side > 0 and behind_local): continue
		var presentation := JumpPresentation.sample(remote_state, world.config, motion_alpha, _reduced_effects_enabled(), actor_motion_history.previous_height(remote_state))
		var landing := LandingPresentation.sample(remote_state, world.config, 0.0, _reduced_effects_enabled())
		var radius := float(MovementTuning.PLAYER_RADIUS) / 1000.0
		var shadow_center := position + Vector2(0.0, radius * 0.58)
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
		var remote_cast_timing := _cast_timing_for(remote_state)
		if viewport_policy.can_skip_body(cartoon_champion_presenter, champion_id, remote_state, world.config, sprite_anchor, shadow_center, camera_origin, body_viewport, PlayerCameraRig.ZOOM_PERCENT):
			sprite_drawn = true # Only the bounded presenter body is skipped.
		elif cartoon_champion_presenter != null:
			_draw_character_movement_trail(remote_state, remote_state, champion_id, sprite_anchor)
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
				actor_motion_history.wall_travel(remote_state.entity_id),
				remote_cast_timing,
			)
		if not sprite_drawn:
			var body_color := FLUX_COLOR if remote_state.champion_wire_id == 2 else ATTUNEMENT_COLOR
			draw_circle(body_position, radius + 5.0, Color(body_color, 0.18))
			draw_circle(body_position, radius, body_color)
			draw_arc(body_position, radius + 2.0, 0.0, TAU, 24, PARCHMENT_COLOR, 2.0)
		if show_debug_overlay:
			_draw_actor_hitbox_diagnostic(body_position, radius, champion_id)
		_draw_spell_startup(remote_state, sprite_anchor, roundi(visual_tick), remote_cast_timing)
		ElementStatusPresenter.draw(self, remote_state, body_position, world.config, visual_language, _reduced_effects_enabled())
		if remote_state.spawn_protection_ticks > 0:
			var protection_ratio := clampf(float(remote_state.spawn_protection_ticks) / float(maxi(1, world.config.milliseconds_to_ticks(1200))), 0.0, 1.0)
			draw_arc(body_position, radius + 9.0, 0.0, TAU, 28, Color(ATTUNEMENT_COLOR, 0.32 + protection_ratio * 0.42), 2.0)
		draw_line(body_position, body_position + Vector2(remote_state.aim_x, remote_state.aim_y) * 0.032, Color(PARCHMENT_COLOR, 0.9), 2.0)
		SoloTrialPanel.draw_world_tell(self, body_position, _solo_rival_world_tell(remote_state))
		var marker: Dictionary = team_markers.get(remote_state.entity_id, {})
		var display_name := String(marker.get("label", session_names_by_entity.get(remote_state.entity_id, "TRAVELLER %d" % remote_state.entity_id))).to_upper()
		var identity_color := _team_color(int(marker.get("team_id", 0)))
		_draw_actor_identity_label(display_name, body_position, identity_color)
		var health_bar := Rect2(body_position + Vector2(-22.0, -37.0), Vector2(44.0, 4.0))
		draw_rect(health_bar, Color(FOREST_SHADOW_COLOR, 0.9), true)
		var health_ratio := clampf(float(remote_state.health) / float(maxi(1, remote_state.health_maximum)), 0.0, 1.0)
		draw_rect(Rect2(health_bar.position + Vector2.ONE, Vector2((health_bar.size.x - 2.0) * health_ratio, 2.0)), identity_color if not marker.is_empty() else Color("d9634f"), true)
	_set_world_transform(camera_origin)


func _draw_character_movement_trail(authority: PlayerState, motion: PlayerState, champion_id: String, sprite_anchor: Vector2) -> void:
	# Observed only for an admitted visible body, never a portrait, hidden actor
	# or velocity-projected future position. The normal POV mask remains on top.
	if _gameplay_input_blocked() or _reduced_effects_enabled():
		character_movement_trail.clear()
		return
	var champion: Dictionary = cartoon_champion_presenter.champions.get(champion_id, {})
	var height := float(champion.get("height", 68.0))
	var art: RefCounted = cartoon_champion_presenter.fullbody_art
	if art != null and art.entries.has(champion_id):
		height = float(preload("res://src/presentation/pixel_flipbook_presenter.gd").BODY_HEIGHTS.get(art.entries[champion_id].body, 68))
	elif cartoon_champion_presenter.wireframe_mode:
		height = float(preload("res://src/presentation/wireframe_body_presenter.gd").DISPLAY_HEIGHTS.get(champion.get("body_type", "middle"), 63))
	character_movement_trail.observe(authority, motion, sprite_anchor, height)
	character_movement_trail.draw_actor(self, authority.entity_id, _pov_point_visible)


func _solo_rival_heavy_tell_segments(actor: PlayerState) -> int:
	var tell := _solo_rival_world_tell(actor)
	return int(tell.get("segments", 0)) if String(tell.get("kind", "")) == "heavy" else 0


func _solo_rival_world_tell(actor: PlayerState) -> Dictionary:
	if element_expansion.challenge_active: return {}
	if world == null or session_transport == null or not interception_practice_active:
		return {}
	if session_transport.mode != SessionTransport.Mode.OFFLINE or actor == null or actor.actor_kind != PlayerState.ActorKind.CHAMPION:
		return {}
	if actor != world.player(2) or not _chemistry_actor_visible(actor):
		return {}
	var rival_status := SoloDuelRival.status(world.tick, int(interception_practice_setup.get("start_tick", -1)))
	var inside_court := solo_trial.court.has_point(Vector2i(actor.position_x, actor.position_y))
	var cast_busy := actor.pending_cast_wire_id > 0 or actor.cast_recovery_ticks > 0
	return SoloTrialPanel.world_tell(solo_trial.phase, rival_status, inside_court, actor.health > 0, cast_busy)


func _draw_receiving_surface_shadow(center: Vector2, radii: Vector2, opacity: float, camera_origin: Vector2) -> void:
	var sample: Dictionary = {}
	if campus_renderer != null and campus_renderer.natural_kit != null:
		var ground_family := ""
		var illustrated := campus_renderer.illustrated_kit
		if not _is_hex_practice() and illustrated != null and illustrated.ground_ready() and illustrated.campus == campus_layout:
			ground_family = WellspringIllustratedKit.pixel_family(illustrated.surface_at(center))
		sample = campus_renderer.natural_kit.receiving_shadow_sample(campus_layout, center, ground_family)
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


func _cast_timing_for(state: PlayerState) -> Dictionary:
	if world == null or state == null or state.pending_cast_wire_id <= 0 or state.pending_cast_ticks <= 0:
		return {}
	if session_transport != null and session_transport.is_connected_client():
		return {}
	return cast_startup_witness.describe(world, state)


func _draw_spell_startup(state: PlayerState, position: Vector2, visual_tick: int, cast_timing: Dictionary = {}) -> void:
	if foundation_spell_presenter == null or state == null or state.pending_cast_wire_id <= 0 or state.pending_cast_ticks <= 0:
		return
	var ability := ability_catalog.ability_from_wire(state.pending_cast_wire_id)
	if ability.is_empty():
		return
	var timing := CastStartupWitnessScript.for_state(state, world.config, cast_timing)
	if timing.is_empty(): return
	# Unknown totals retain the authored release-proximity animation coordinate;
	# only a witnessed admission supplies a completion fraction or elapsed age.
	var phase := float(timing.get("animation_progress", 0.0))
	var hand_origin := CartoonChampionPresenter.hand_cast_origin(position, Vector2(state.aim_x, state.aim_y))
	foundation_spell_presenter.draw_startup(
		self,
		state.pending_cast_wire_id,
		hand_origin,
		Vector2(state.aim_x, state.aim_y),
		phase,
		visual_tick,
		_reduced_effects_enabled(),
		timing,
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


func _update_service_details(delta: float) -> void:
	var hovered := ""
	if not focused_station_id.is_empty() and interaction_presenter != null:
		var station: Dictionary = campus_layout.stations_by_id[focused_station_id]
		var origin := _camera_origin(_camera_focus_position(current_position))
		var scale_factor := _ui_scale()
		var feet := PixelPresentation.world_to_screen(current_position, origin, PlayerCameraRig.ZOOM_PERCENT) / scale_factor
		var actor_scale := PlayerCameraRig.ZOOM / scale_factor
		var protected := Rect2(feet - Vector2(48,160) * actor_scale, Vector2(96,176) * actor_scale)
		var anchor := PixelPresentation.world_to_screen(WellspringServiceBuildings.position_of(station), origin, PlayerCameraRig.ZOOM_PERCENT) / scale_factor
		var panel := interaction_presenter.station_rect(get_viewport_rect().size / scale_factor, anchor, false, 0, protected)
		var pointer := get_viewport().get_mouse_position() / scale_factor
		var inside := panel.has_point(pointer)
		if service_details_visible:
			inside = inside or interaction_presenter.station_rect(get_viewport_rect().size / scale_factor, anchor, true, _station_lines(station).size(), protected).has_point(pointer)
		if inside or input_router.is_controller_aim_active():
			hovered = focused_station_id
	service_details_visible = service_focus.update_focus(hovered, delta)


func _draw_station_bubble(camera_origin: Vector2) -> void:
	if interaction_presenter == null or station_notice_seconds > 0.0 or service_directory.is_open or _directory_child_open():
		return
	if focused_station_id.is_empty() or not campus_layout.stations_by_id.has(focused_station_id):
		return
	if int(_current_round_state().get("phase", SessionRound.Phase.HEARTH)) != SessionRound.Phase.HEARTH:
		return
	var station: Dictionary = campus_layout.stations_by_id[focused_station_id].duplicate()
	var group := WellspringServiceBuildings.group_definition(WellspringServiceBuildings.group_for_station(station))
	station["directory_title"] = group.get("title", station["title"])
	var values: Array = station.get("position", [])
	var station_position := Vector2(float(values[0]), float(values[1]))
	var expanded: bool = expanded_station_id == focused_station_id or service_details_visible
	var lines: Array = [String(group.get("hint", "Choose a service inside.")), "Open the directory to choose an action."] if expanded else ["Open directory"]
	var ui_scale := _ui_scale()
	var actor_feet := PixelPresentation.world_to_screen(current_position, camera_origin, PlayerCameraRig.ZOOM_PERCENT) / ui_scale
	var actor_scale := float(PlayerCameraRig.ZOOM_PERCENT) / 100.0 / ui_scale
	# Reserve all three body sizes plus jump lift, in the same UI coordinates.
	var actor_bounds := Rect2(actor_feet - Vector2(48, 160) * actor_scale, Vector2(96, 176) * actor_scale)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ui_scale)
	interaction_presenter.draw_station(
		self,
		get_viewport_rect().size / ui_scale,
		PixelPresentation.world_to_screen(station_position, camera_origin, PlayerCameraRig.ZOOM_PERCENT) / ui_scale,
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
	var practice_lines := WellspringInteractionPresenter.practice_station_lines(station, player_preferences, station_activation_device)
	if not practice_lines.is_empty():
		return practice_lines
	var command := String(station.get("command", ""))
	if command == "host_session":
		var closing_armed := session_transport.is_host() and session_steward.is_armed(SessionSteward.Action.CLOSE_COMPANY, 0, world.tick)
		var action_line := _station_interact_instruction("opens a direct friend gate")
		if closing_armed:
			action_line = _station_interact_instruction("CONFIRMS CLOSING THE COMPANY")
		elif session_transport.is_host():
			action_line = _station_interact_instruction("arms a three-second close")
		return [session_transport.status_detail, "UDP %d | %d/%d travellers" % [session_port, session_transport.player_count(), _selected_session_capacity()], "CHARTER: %s" % SessionCharter.display_name(selected_charter_id), action_line]
	if command == "join_session":
		if join_address_editor_open:
			return [
				"TYPE OR CTRL+V THE HOST ADDRESS",
				"> %s%s" % [join_address_editor_text, "_" if Time.get_ticks_msec() % 1000 < 600 else ""],
				join_address_editor_error if not join_address_editor_error.is_empty() else "ENTER SEEKS | ESC CANCELS | PORT %d" % session_port,
				"The address is saved only on this PC",
			]
		var charter_line := "HOST CHARTER APPEARS AFTER JOIN" if not session_transport.is_connected_client() else "CHARTER: %s | %d PLACES" % [SessionCharter.display_name(selected_charter_id), session_transport.player_capacity()]
		return [session_transport.status_detail, "%s:%d" % [join_address, session_port], charter_line, _station_interact_instruction("closes the gate") if session_transport.mode != SessionTransport.Mode.OFFLINE else _station_interact_instruction("enters or confirms the friend address")]
	if command == "session_charter":
		var charter := SessionCharter.definition(selected_charter_id)
		var locked := session_transport.is_online()
		var charter_lines: Array[String] = [
			"SEALED WHILE FARFLOW IS OPEN" if locked else _station_interact_instruction("turns to %s" % SessionCharter.display_name(SessionCharter.next_id(selected_charter_id))),
			"%s | %d TRAVELLERS" % [String(charter.get("display_name", "")), int(charter.get("maximum_players", 0))],
			"TRAVELLER DAMAGE %s" % ("ON" if bool(charter.get("player_damage", false)) else "OFF"),
			"PRACTICE RESET: %s" % ("HOST ONLY" if String(charter.get("practice_reset", "")) == SessionCharter.RESET_HOST_ONLY else "ANY TRAVELLER"),
		]
		if SessionCharter.required_players(selected_charter_id) > 0:
			charter_lines.resize(1)
			charter_lines.append_array(TeamPresentation.damage_policy_lines())
		return charter_lines
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
		"ATTUNED: %s | %s" % [String(current.get("display_name", "")).to_upper(), String(current.get("ancestry", "")).to_upper()],
		"HP %d | FLUX %d | STAMINA %d | SPEED %d%%" % [int(stats.get("health_maximum", 0)) / 1000, int(stats.get("flux_maximum", 0)) / 1000, int(stats.get("stamina_maximum", 0)) / 1000, int(stats.get("movement_speed_ratio", 0)) / 10],
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
					print("HEX trace close ms=%d tick=%d phase=%d end=%d" % [Time.get_ticks_msec(), world.tick, authoritative_session.session_round.phase, authoritative_session.session_round.round_end_tick])
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
		# Epoch and prediction configuration follow an accepted complete world,
		# not transport metadata that can arrive ahead of its valid snapshot.
		var snapshots := session_transport.poll_envelopes()
		var first_snapshot: bool = last_client_snapshot_tick < 0
		if not snapshots.is_empty():
			var snapshot: Dictionary = snapshots.back()
			if _apply_world_envelope(snapshot):
				last_client_snapshot_tick = int(snapshot["tick"])
				actor_motion_history.capture(world.players)
				remote_snapshot_age_seconds = 0.0
				# Projection starts AFTER publication and motion callbacks. Only the
				# concrete script has no extensible call between these adjacent lane
				# reads; extensions and refusal retain each original getter in order.
				var metadata := WorldSnapshotEnvelope.metadata(snapshot) if get_script() == load("res://src/app/bootstrap.gd") else {}
				if not metadata.is_empty():
					_apply_snapshot_overflow(metadata.overflow)
					session_names_by_entity = {}
					for row: Array in metadata.names: session_names_by_entity[int(row[0])] = String(row[1])
					session_hearth_values = metadata.hearth
					session_round_values = metadata.round
				else:
					var overflow: PackedInt32Array = WorldSnapshotEnvelope.overflow(snapshot)
					_apply_snapshot_overflow(overflow)
					session_names_by_entity = _envelope_names(snapshot)
					session_hearth_values = WorldSnapshotEnvelope.hearth(snapshot)
					session_round_values = WorldSnapshotEnvelope.round_state(snapshot)
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
								return int((entry_value as Dictionary).get("entity_id", 0)) == local_state.entity_id and bool(entry_value.get("present", true))
						)
						if int(first_round.get("phase", SessionRound.Phase.HEARTH)) == SessionRound.Phase.ACTIVE and not local_entered_round:
							station_notice = "The court is underway. You join the next gathering."
							station_notice_seconds = 4.0
					var replicated_champion_id := champion_catalog.champion_id_from_wire(local_state.champion_wire_id)
					if not replicated_champion_id.is_empty() and replicated_champion_id != selected_champion_id:
						selected_champion_id = replicated_champion_id
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
		var reconciliations: Array[Dictionary] = session_transport.take_reconciliations()
		if _client_world_ready(): client_reconciliation_buffer.offer_many(reconciliations)
		var reconciliation: Dictionary = {} if _is_spectating() or not _client_world_ready() else client_reconciliation_buffer.take_exact(last_client_world_epoch, world.tick)
		if not reconciliation.is_empty():
			cast_startup_witness.clear()
			var local_authority := _local_player_state()
			var authority_event := local_authority.last_event if local_authority != null else "network_snapshot"
			if client_prediction.reconcile(reconciliation, authority_event, _reduced_effects_enabled()):
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
		client_reconciliation_buffer.reset()
		client_prediction.reset()
		last_client_snapshot_tick = -1
		last_client_world_epoch = -1
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
			client_reconciliation_buffer.reset()
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
		if not _client_world_ready():
			station_notice = "Synchronizing the world. Try again when ready."
			station_notice_seconds = 1.5
			if action == SessionTransport.REQUEST_CHAMPION_SELECT and character_selection_grid != null: character_selection_grid.refuse(station_notice)
			return
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
		var refusal_reason := _session_request_refusal_reason(action, state, ready_tick)
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
					SanctumStationModel.impact_launch_direction(campus_layout, Vector2i(state.position_x, state.position_y)), 540_000, world.config,
				):
					_publish_session_event({"type": "request_refused", "entity_id": entity_id, "action": action, "sequence": int(request.get("sequence", 0)), "champion_wire_id": state.champion_wire_id, "reason": SessionRequestPolicy.REFUSED_UNAVAILABLE})
					continue
				_publish_session_event({"type": "station_confirmed", "entity_id": entity_id, "action": action, "sequence": int(request.get("sequence", 0)), "champion_wire_id": state.champion_wire_id})
			SessionTransport.REQUEST_CHAMPION_NEXT, SessionTransport.REQUEST_CHAMPION_SELECT:
				var requested_wire := request_value
				var resume_range := element_expansion.prepare_character_change() if state == _local_player_state() else false
				if action == SessionTransport.REQUEST_CHAMPION_NEXT:
					var current_id := champion_catalog.champion_id_from_wire(state.champion_wire_id)
					requested_wire = int(champion_catalog.champion(champion_catalog.next_champion_id(current_id)).get("wire_id", 0))
				if not _is_hex_practice() and not element_expansion.temporary_session(): character_weaves.remember_actor(state)
				var attunement := ChampionAttunementScript.apply(champion_catalog, state, requested_wire)
				if attunement == ChampionAttunementScript.REFUSED:
					if state == _local_player_state(): element_expansion.finish_character_change(resume_range)
					_publish_session_event({"type": "request_refused", "entity_id": entity_id, "action": action, "sequence": int(request.get("sequence", 0)), "champion_wire_id": state.champion_wire_id, "reason": SessionRequestPolicy.REFUSED_UNAVAILABLE})
					continue
				if attunement == ChampionAttunementScript.CHANGED:
					character_weaves.restore_actor(state, state == _local_player_state())
				if state == _local_player_state(): element_expansion.finish_character_change(resume_range)
				if entity_id == SessionTransport.SERVER_PEER_ID and attunement == ChampionAttunementScript.CHANGED:
					selected_champion_id = champion_catalog.champion_id_from_wire(state.champion_wire_id)
				_publish_session_event({"type": "champion_attuned", "entity_id": entity_id, "champion_wire_id": state.champion_wire_id})
			SessionTransport.REQUEST_WEAVE_APPLY:
				if state == _local_player_state() and not element_expansion.allows_weave(PackedInt32Array(request.get("wires", []))):
					_publish_session_event({"type": "request_refused", "entity_id": entity_id, "action": action, "sequence": int(request.get("sequence", 0)), "champion_wire_id": state.champion_wire_id, "reason": SessionRequestPolicy.REFUSED_UNAVAILABLE})
					continue
				if request_value != state.champion_wire_id or not SessionTransport._valid_weave_wires(request.get("expected"), true) or not SessionTransport._valid_weave_wires(request.get("wires")) or PackedInt32Array(request.expected) != state.spell_wire_ids or not CharacterWeavePolicy.apply(state, PackedInt32Array(request.wires)):
					_publish_session_event({"type": "request_refused", "entity_id": entity_id, "action": action, "sequence": int(request.get("sequence", 0)), "champion_wire_id": state.champion_wire_id, "reason": SessionRequestPolicy.REFUSED_UNAVAILABLE})
					continue
				if not element_expansion.temporary_session(): character_weaves.remember_actor(state)
				_publish_session_event({"type": "station_confirmed", "entity_id": entity_id, "action": action, "sequence": int(request.get("sequence", 0)), "champion_wire_id": state.champion_wire_id})
			SessionTransport.REQUEST_SPELL_EQUIP:
				var slot_index: int = SpellLoomEditor.decode_slot_index(request_value)
				var library_index: int = SpellLoomEditor.decode_library_index(request_value)
				var wire_id: int = SpellLoomEditor.wire_id_for_library_index(library_index)
				if state == _local_player_state() and not element_expansion.can_equip(wire_id):
					_publish_session_event({"type": "request_refused", "entity_id": entity_id, "action": action, "sequence": int(request.get("sequence", 0)), "champion_wire_id": state.champion_wire_id, "reason": SessionRequestPolicy.REFUSED_UNAVAILABLE})
					continue
				var requested_wires := state.spell_wire_ids.duplicate()
				if slot_index >= 0 and slot_index < requested_wires.size() and wire_id > 0:
					var previous_slot := requested_wires.find(wire_id)
					if previous_slot >= 0: requested_wires[previous_slot] = requested_wires[slot_index]
					requested_wires[slot_index] = wire_id
				if slot_index < 0 or wire_id == 0 or not ChampionAttunementScript.is_available(state) or not CharacterWeavePolicy.apply(state, requested_wires):
					_publish_session_event({"type": "request_refused", "entity_id": entity_id, "action": action, "sequence": int(request.get("sequence", 0)), "champion_wire_id": state.champion_wire_id, "reason": SessionRequestPolicy.REFUSED_UNAVAILABLE})
					continue
				if not element_expansion.temporary_session(): character_weaves.remember_actor(state)
				if state == _local_player_state() and spell_loom_editor != null and spell_loom_editor.is_open:
					spell_loom_editor.status_message = "%s was sealed by the host." % PlayerState.spell_slot_label(slot_index)
				station_notice = "%s rewove %s." % [String(session_names_by_entity.get(entity_id, "A traveller")), PlayerState.spell_slot_label(slot_index)]
				station_notice_seconds = 1.5
				if state == _local_player_state(): _save_confirmed_weave(state, CharacterWeaveLibrary.MODE_CUSTOM)
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


func _session_request_refusal_reason(action: int, state: PlayerState, ready_tick: int = 0) -> int:
	var refusal_reason := SessionRequestPolicy.validate(
		action,
		state,
		campus_layout.stations_by_id,
		world.tick,
		ready_tick,
		int(_current_round_state().get("phase", SessionRound.Phase.HEARTH)),
	)
	# The isolated solo practice court exposes its Loom without a campus station.
	if _is_hex_practice() and session_transport.mode == SessionTransport.Mode.OFFLINE and action in [SessionTransport.REQUEST_SPELL_EQUIP, SessionTransport.REQUEST_WEAVE_APPLY, SessionTransport.REQUEST_CHAMPION_SELECT] and ChampionAttunementScript.is_available(state):
		return SessionRequestPolicy.ACCEPTED
	return refusal_reason


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
			character_weaves.restore_actor(state, state == _local_player_state())


func _ingest_session_feedback(events: Array[Dictionary]) -> void:
	# Published authority, not delayed/unsequenced feedback, owns the equipped badge.
	_reconcile_character_attunement()
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
					if not _matches_pending_weave_feedback(event): continue
					pending_weave_request.acknowledged = true
					_complete_pending_weave()
				elif confirmed_action == SessionTransport.REQUEST_IMPACT_PRACTICE:
					station_notice = "%s struck the Momentum Chime: steer, then V to tech." % String(session_names_by_entity.get(entity_id, "A traveller"))
				else:
					station_notice = "%s restored the practice court." % String(session_names_by_entity.get(entity_id, "A traveller"))
				station_notice_seconds = 2.5
			"champion_attuned":
				var champion_id := champion_catalog.champion_id_from_wire(int(event.get("champion_wire_id", 0)))
				var local_state := _local_player_state()
				if local_state != null and local_state.entity_id == entity_id:
					if not character_selection_grid.confirm_attunement_feedback(champion_id, _weave_session_context()):
						continue
				var champion_name := String(champion_catalog.champion(champion_id).get("display_name", champion_id))
				station_notice = "%s attuned to %s." % [String(session_names_by_entity.get(entity_id, "A traveller")), champion_name]
				station_notice_seconds = 2.5
			"request_refused":
				var local_state := _local_player_state()
				if local_state != null and local_state.entity_id == entity_id:
					var refused_action := int(event.get("action", 0))
					if refused_action == SessionTransport.REQUEST_WEAVE_APPLY and not _matches_pending_weave_feedback(event):
						continue
					var reason := int(event.get("reason", 0))
					station_notice = "Wait a breath." if reason == 1 else ("Stand beside the station." if reason == 2 else "That request is unavailable.")
					station_notice_seconds = 2.0
					if refused_action == SessionTransport.REQUEST_WEAVE_APPLY:
						pending_weave_request.clear()
						spell_loom_editor.complete_starter_apply(false)
						spell_loom_editor.status_message = station_notice + " Your previous weave remains usable; wait for active actions and cooldowns before replacing a spell."
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
							return int((entry_value as Dictionary).get("entity_id", 0)) == session_transport.local_entity_id and bool(entry_value.get("present", true))
					)
					if int(spectator_round.get("phase", SessionRound.Phase.HEARTH)) == SessionRound.Phase.ACTIVE and int(spectator_round.get("serial", 0)) == 2 and local_is_participant:
						spectator_smoke_round_reported = true
						print("FLUX2 farflow spectator smoke: joined Proving Court serial 2 as entity %d" % session_transport.local_entity_id)
			"practice_cancelled":
				station_notice = "The Hearth waits for the changed roster."
				station_notice_seconds = 2.0
			"round_knockout":
				station_notice = RoundLabel.knockout_notice(int(event.get("owner_id", 0)), int(event.get("target_id", 0)), _current_round_state().get("entries", []), session_names_by_entity, _current_round_state(), event)
				station_notice_seconds = 1.5
			"round_respawned":
				station_notice = "%s returns under ward." % String(session_names_by_entity.get(entity_id, "A traveller"))
				station_notice_seconds = 1.5
			"round_finished":
				var winner_id := int(event.get("winner_id", 0))
				var winner_team := int(event.get("winner_team_id", 0))
				station_notice = "%s wins the court." % TeamPresentation.team_name(winner_team) if winner_team > 0 else ("The court is drawn." if winner_id == 0 else "%s wins the court." % String(session_names_by_entity.get(winner_id, "A traveller")))
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
		var world_position := _pov_actor_ground_position(state)
		var entity_id := int(bubble.get("entity_id", 0))
		interaction_presenter.draw_social(
			self,
			get_viewport_rect().size / ui_scale,
			PixelPresentation.world_to_screen(world_position, camera_origin, PlayerCameraRig.ZOOM_PERCENT) / ui_scale,
			String(session_names_by_entity.get(entity_id, "TRAVELLER")),
			String(bubble.get("text", "HELLO!")),
			clampf(float(bubble.get("remaining", 0.0)) / maxf(float(bubble.get("duration", 2.0)), 0.01), 0.0, 1.0),
		)


func _update_station_focus() -> void:
	if _is_hex_practice() or interception_practice_active or solo_trial_menu_open:
		focused_station_id = ""
		return
	if world == null:
		focused_station_id = ""
		return
	var state: PlayerState = _local_player_state()
	if state == null:
		focused_station_id = ""
		return
	var next_focus := SanctumStationModel.nearest_station_id(
		campus_layout.stations_by_id,
		Vector2i(state.position_x, state.position_y),
	)
	var retained := service_directory.selected_station_id() if service_directory.is_open else directory_return_station
	if not retained.is_empty() and SanctumStationModel.station_in_reach(campus_layout.stations_by_id, retained, Vector2i(state.position_x, state.position_y)):
		next_focus = retained
	if not next_focus.is_empty():
		var door := WellspringServiceBuildings.position_of(campus_layout.stations_by_id[next_focus])
		if float(state.position_y) / SimConfig.FIXED_SCALE < door.y - 16.0:
			next_focus = "" # Approach the door, not the back of the solid facade.
	if not expanded_station_id.is_empty() and expanded_station_id != next_focus:
		expanded_station_id = ""
	if join_address_editor_open and next_focus != focused_station_id:
		join_address_editor_open = false
		join_address_editor_error = ""
	focused_station_id = next_focus


func _directory_child_open() -> bool:
	return local_navigation.blocks_gameplay() or element_expansion.panel.is_open or join_address_editor_open or (controls_editor != null and controls_editor.is_open) or (spell_loom_editor != null and spell_loom_editor.is_open) or (player_compendium != null and player_compendium.is_open) or _character_gallery_open()


func _open_focused_service_directory() -> void:
	if interception_practice_active or solo_trial_menu_open:
		return
	if not campus_layout.stations_by_id.has(focused_station_id) or _directory_child_open():
		return
	if int(_current_round_state().get("phase", SessionRound.Phase.HEARTH)) != SessionRound.Phase.HEARTH:
		return
	var group := WellspringServiceBuildings.group_for_station(campus_layout.stations_by_id[focused_station_id])
	var returning := directory_return_group == group and not directory_return_station.is_empty()
	var preferred := directory_return_station if returning else ""
	if service_directory.open_group(group, campus_layout.data["stations"], preferred):
		if group == "practice":
			for source: Dictionary in service_directory.entries.duplicate():
				if String(source.get("command", "")) == "impact_practice":
					for entry: Array in ElementExpansion.ENTRIES:
						var expansion_entry := source.duplicate(true)
						expansion_entry["id"] = String(entry[0])
						expansion_entry["door_station_id"] = String(source.id)
						expansion_entry["compact_title"] = String(entry[1])
						expansion_entry["compact_hint"] = String(entry[2])
						expansion_entry["lines"] = [String(entry[2]), "Offline practice. Use normal controls; saved weaves are preserved."]
						service_directory.entries.append(expansion_entry)
					var trial_entry := source.duplicate(true)
					trial_entry["id"] = SOLO_TRIAL_STATION
					trial_entry["door_station_id"] = String(source.id)
					trial_entry["compact_title"] = "SOLO DUEL TRIAL"
					trial_entry["compact_hint"] = "Defeat Oh Tipi · 72 seconds · loaner kit"
					trial_entry["lines"] = ["Defeat Oh Tipi within 72 seconds using a loaner S. Wayne weave.", "Normal paid spells and movement. Stay inside the marked court.", "Your selected champion and weave are restored on return. Offline only."]
					service_directory.entries.append(trial_entry)
					break
		directory_return_group = ""
		directory_return_station = ""
		_refresh_directory_availability()
		if not returning:
			for index: int in service_directory.entries.size():
				service_directory.selected_index = index
				if service_directory.selected_available():
					break
		controls_input_guard_frames = 2
		input_router.discard_transient_movement_input()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		queue_redraw()


func _update_service_directory(delta: float) -> void:
	if not directory_return_group.is_empty() and not _directory_child_open():
		if focused_station_id == directory_return_station:
			_open_focused_service_directory()
		else:
			directory_return_group = ""
			directory_return_station = ""
	if not service_directory.is_open:
		return
	if focused_station_id.is_empty() or int(_current_round_state().get("phase", SessionRound.Phase.HEARTH)) != SessionRound.Phase.HEARTH:
		service_directory.close()
		controls_input_guard_frames = 2
		return
	_refresh_directory_availability()
	service_directory.update(delta, get_viewport().get_mouse_position() / _ui_scale(), get_viewport_rect().size / _ui_scale())
	service_directory.status_text = station_notice if station_notice_seconds > 0.0 else _session_label() if service_directory.group_id == "farflow" else ""
	service_directory.status_text = service_directory.status_text.get_slice("\n", 0)


func _refresh_directory_availability() -> void:
	var state := _local_player_state()
	var availability := {}
	var live_lines := {}
	for entry: Dictionary in service_directory.entries:
		var id := String(entry["id"])
		live_lines[id] = _station_lines(entry)
		var door_id := String(entry.get("door_station_id", id))
		var enabled := state != null and SanctumStationModel.station_in_reach(campus_layout.stations_by_id, door_id, Vector2i(state.position_x, state.position_y))
		var reason := "" if enabled else "Approach the front door."
		if (id == SOLO_TRIAL_STATION or id.begins_with("expansion-")) and session_transport.mode != SessionTransport.Mode.OFFLINE:
			enabled = false
			reason = "Leave the session first; this trial is offline only."
		match String(entry["command"]):
			"session_ledger", "session_parting":
				if not session_transport.is_host():
					enabled = false
					reason = "Host only."
			"session_charter":
				if session_transport.is_online():
					enabled = false
					reason = "Close the session before changing rules."
			"host_session":
				if session_transport.mode != SessionTransport.Mode.OFFLINE and not session_transport.is_host():
					enabled = false
					reason = "Leave the joined session first."
			"session_hearth":
				if not session_transport.is_online():
					enabled = false
					reason = "Host or join a session first."
			"champion_switch":
				var art_access := _gallery_selection_availability(state)
				if enabled:
					enabled = bool(art_access.get("enabled", false))
					reason = String(art_access.get("reason", ""))
		availability[id] = {"enabled":enabled, "reason":reason}
	service_directory.availability_by_station = availability
	service_directory.set_station_lines(live_lines)
	service_directory.card_overrides_by_station = {
		SOLO_TRIAL_STATION:{"title":"SOLO DUEL TRIAL", "hint":"72-second duel · loaner kit · offline"},
		"farflow-host":{"title":"CLOSE SESSION" if session_transport.is_host() else "HOST SESSION"},
		"farflow-join":{"title":"LEAVE SESSION" if session_transport.mode != SessionTransport.Mode.OFFLINE and not session_transport.is_host() else "JOIN SESSION"},
		"farflow-charter":{"hint":SessionCharter.display_name(selected_charter_id)},
		"session-hearth":{"title":"READY / BEGIN"},
	}


func _handle_service_directory_input(event: InputEvent) -> void:
	_refresh_directory_availability()
	var pointer := get_viewport().get_mouse_position() / _ui_scale()
	if event is InputEventMouse:
		pointer = event.position / _ui_scale()
	var requested := service_directory.handle_event(event, pointer, get_viewport_rect().size / _ui_scale())
	if not requested.is_empty():
		_dispatch_directory_station(requested)
	controls_input_guard_frames = 2
	input_router.discard_transient_movement_input()
	get_viewport().set_input_as_handled()
	queue_redraw()


func _dispatch_directory_station(station_id: String) -> void:
	if station_id.begins_with("expansion-"):
		if not service_directory.is_open or service_directory.group_id != "practice": return
		_refresh_directory_availability()
		if bool(service_directory.availability_by_station.get(station_id, {}).get("enabled", false)): element_expansion.activate(station_id)
		return
	if station_id == SOLO_TRIAL_STATION:
		if not service_directory.is_open or service_directory.group_id != "practice": return
		_refresh_directory_availability()
		if not bool(service_directory.availability_by_station.get(station_id, {}).get("enabled", false)): return
		_open_solo_trial_menu()
		return
	if not service_directory.is_open or not campus_layout.stations_by_id.has(station_id):
		return
	if world == null or int(_current_round_state().get("phase", SessionRound.Phase.HEARTH)) != SessionRound.Phase.HEARTH:
		service_directory.close()
		directory_return_group = ""
		directory_return_station = ""
		return
	_refresh_directory_availability()
	if not bool(service_directory.availability_by_station.get(station_id, {}).get("enabled", false)):
		return
	var station: Dictionary = campus_layout.stations_by_id[station_id]
	if WellspringServiceBuildings.group_for_station(station) != service_directory.group_id:
		return
	var group := service_directory.group_id
	focused_station_id = station_id
	var child_action := String(station["command"]) in ["movement_guide", "configure_controls", "configure_spells", "champion_switch", "join_session"]
	if child_action:
		service_directory.close()
		directory_return_group = group
		directory_return_station = station_id
	_activate_focused_station()
	if not _directory_child_open() and not service_directory.is_open:
		_open_focused_service_directory()
	if service_directory.is_open:
		service_directory.status_text = station_notice


func _activate_focused_station() -> void:
	if interception_practice_active or solo_trial_menu_open:
		return
	if focused_station_id.is_empty() or not campus_layout.stations_by_id.has(focused_station_id):
		return
	var actor := _local_player_state()
	if actor == null or not SanctumStationModel.station_in_reach(campus_layout.stations_by_id, focused_station_id, Vector2i(actor.position_x, actor.position_y)):
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
			_open_spell_loom_editor()
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
	return "UNBOUND" if label == "\u2014" or label.is_empty() else label


func _station_interact_instruction(instruction: String) -> String:
	if service_directory != null and service_directory.is_open:
		return "ENTER / A " + instruction
	var label := _station_interact_label().to_upper()
	if label == "UNBOUND":
		return "Bind Interact in the Lodge controls."
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


func _open_player_compendium(selected_tab: int, device: int = -1) -> void:
	if player_compendium == null or join_address_editor_open or controls_editor.is_open or spell_loom_editor.is_open or _character_gallery_open():
		return
	player_compendium.open_panel(selected_tab, player_preferences, _local_player_state(), player_preferences.prompt_device if device < 0 else device)
	expanded_station_id = ""
	controls_input_guard_frames = 2
	queue_redraw()


func _character_gallery_open() -> bool:
	return character_selection_grid != null and character_selection_grid.is_open


func _gameplay_input_blocked() -> bool:
	return _input_blocked()


func _input_blocked(allow_finished_result: bool = false) -> bool:
	return _area_loading() or local_navigation.blocks_gameplay() or element_expansion.blocks_gameplay(allow_finished_result) or solo_trial_menu_open or (interception_practice_active and solo_trial.blocks_gameplay() and not (allow_finished_result and solo_trial.is_finished())) or service_directory.is_open or hex_playground_open or hex_playground_demo.is_active() or not application_input_active or join_address_editor_open or (controls_editor != null and controls_editor.is_open) or (spell_loom_editor != null and spell_loom_editor.is_open) or (player_compendium != null and player_compendium.is_open) or _character_gallery_open() or controls_input_guard_frames > 0


func _audio_tails_blocked(controls_blocking: bool) -> bool:
	if _is_spectating(): return true
	if not controls_blocking: return false
	if not _solo_trial_frozen(): return true
	# A finished result alone lets already-admitted finite tails finish.
	# READY, loading, menus, focus and rearm guards still silence them.
	return _input_blocked(true)


func _sample_gameplay_command(tick: int, player_position: Vector2, pointer_position: Vector2, controls_blocking: bool) -> SimCommand:
	if controls_blocking or not application_input_active:
		input_router.discard_transient_movement_input()
		# This command already delivers cancellation. Do not carry a second
		# cancellation into the first valid fresh action after the guard closes.
		input_router.movement_cancel_pending = false
		return SimCommand.new(tick, input_router.entity_id, 0, 0, 0, SimCommand.PRESSED_CANCEL_MOVEMENT, input_router.last_quantized_aim.x, input_router.last_quantized_aim.y)
	return input_router.sample(tick, player_position, pointer_position)


static func gallery_modal_command(command: SimCommand, gallery_open: bool) -> SimCommand:
	if not gallery_open:
		return command
	return SimCommand.new(command.tick, command.entity_id, 0, 0, 0, SimCommand.PRESSED_CANCEL_MOVEMENT, command.aim_x, command.aim_y)


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
	_reconcile_character_attunement()
	var gallery_scale := _ui_scale() if _readable_ui() else _compendium_scale()
	var pointer := get_viewport().get_mouse_position() / gallery_scale
	if event is InputEventMouse:
		pointer = event.position / gallery_scale
	var availability: Dictionary = _gallery_selection_availability(_local_player_state())
	var requested_wire: int = character_selection_grid.handle_readable_event(event, pointer, get_viewport_rect().size / gallery_scale, availability) if _readable_ui() else character_selection_grid.handle_event(event, ThemeDB.fallback_font, pointer, availability)
	if requested_wire > 0:
		# Recheck at the submit boundary. The host remains authoritative, while a
		# local state transition cannot leave a synthetic pending selection behind.
		var submit_availability: Dictionary = _gallery_selection_availability(_local_player_state())
		if bool(submit_availability.get("enabled", false)):
			if character_selection_grid.bind_pending_attunement(_weave_session_context(), Time.get_ticks_msec()):
				_submit_session_request(SessionTransport.REQUEST_CHAMPION_SELECT, requested_wire)
			else:
				character_selection_grid.refuse("Attunement could not be tracked. Check your current character before retrying.")
		else:
			character_selection_grid.refuse(String(submit_availability.get("reason", "Attunement is unavailable.")))
	controls_input_guard_frames = 2
	input_router.discard_transient_movement_input()
	get_viewport().set_input_as_handled()
	queue_redraw()


func _reconcile_character_attunement() -> void:
	if character_selection_grid == null or champion_catalog == null or session_transport == null:
		return
	# Never use the camera's host fallback as proof of a missing client's identity.
	# Offline transports use ID zero; their authoritative solo actor is server ID1.
	var remote_context := session_transport.mode in [SessionTransport.Mode.CLIENT, SessionTransport.Mode.CONNECTING]
	var entity_id := session_transport.local_entity_id if remote_context else SessionTransport.SERVER_PEER_ID
	var state: PlayerState = world.player(entity_id) if world != null else null
	var authority_ready := state != null and session_transport.mode != SessionTransport.Mode.CONNECTING \
		and (not session_transport.is_connected_client() or _client_world_ready())
	var champion_id := champion_catalog.champion_id_from_wire(state.champion_wire_id) if authority_ready else ""
	character_selection_grid.reconcile_attunement(_weave_session_context(), champion_id, Time.get_ticks_msec(), authority_ready)


func _gallery_selection_availability(state: PlayerState) -> Dictionary:
	if client_request_sequence >= 0x7fffffff:
		return {"enabled": false, "reason": "Restart the session before sending another attunement request."}
	if state == null or world == null or campus_layout == null or session_transport == null:
		return {"enabled": false, "reason": "Character attunement is unavailable."}
	if session_transport.is_connected_client() and not _client_world_ready():
		return {"enabled": false, "reason": "Synchronizing the world. Try again when ready."}
	var round_phase: int = int(_current_round_state().get("phase", SessionRound.Phase.HEARTH))
	var refusal_reason: int = _session_request_refusal_reason(SessionTransport.REQUEST_CHAMPION_SELECT, state)
	if refusal_reason == SessionRequestPolicy.ACCEPTED:
		return {"enabled": true, "reason": ""}
	if round_phase != SessionRound.Phase.HEARTH:
		return {"enabled": false, "reason": "Return to Wellspring free practice before attuning."}
	if state.health <= 0:
		return {"enabled": false, "reason": "Return alive before attuning."}
	if not ChampionAttunementScript.is_available(state):
		return {"enabled": false, "reason": "Finish the active action before attuning."}
	if refusal_reason == SessionRequestPolicy.REFUSED_DISTANCE:
		return {"enabled": false, "reason": "Stand beside the Gallery to attune."}
	return {"enabled": false, "reason": "Character attunement is unavailable."}


func _loom_scale() -> float:
	if _readable_ui():
		return _ui_scale()
	return loom_scale_for(get_viewport_rect().size)


static func loom_scale_for(viewport_size: Vector2) -> float:
	# Fixed reading layout and every pointer path use the same fitted grid.
	return clampf(minf(viewport_size.x / 1280.0, viewport_size.y / 720.0), 0.25, 1.5)


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
	if spell_loom_editor == null or not spell_loom_editor.is_open: return
	# Explicit confirmation owns this choice; a later mouse release must not
	# resurrect the preceding drag after a refusal or delayed confirmation.
	spell_loom_editor.cancel_drag()
	if not pending_weave_request.is_empty(): return
	var actor := _local_player_state()
	if actor == null: return
	var requested := spell_loom_editor.requested_wire_ids(actor)
	if requested.is_empty(): return
	if requested == actor.spell_wire_ids:
		spell_loom_editor.status_message = "Already in this slot. No changes sent."
		return
	_submit_whole_weave(actor, actor.spell_wire_ids, requested, CharacterWeaveLibrary.MODE_CUSTOM, true)


func _loom_presented_request(state: PlayerState) -> PackedInt32Array:
	if spell_loom_editor == null or state == null:
		return PackedInt32Array()
	if spell_loom_editor.starter_preview_active():
		var request := spell_loom_editor.request_starter_apply()
		var wires_value: Variant = request.get("wire_ids", PackedInt32Array())
		return wires_value.duplicate() if wires_value is PackedInt32Array else PackedInt32Array()
	return spell_loom_editor.requested_wire_ids(state)


func _loom_assignment_availability(state: PlayerState, requested: PackedInt32Array, starter_context: bool = false) -> Dictionary:
	if not pending_weave_request.is_empty():
		return {"enabled": false, "reason": "Waiting for authority confirmation."}
	if client_request_sequence >= 0x7fffffff:
		return {"enabled": false, "reason": "Restart the session before sending another weave request."}
	if state == null or world == null or campus_layout == null or session_transport == null:
		return {"enabled": false, "reason": "Spell assignment is unavailable."}
	if session_transport.is_connected_client() and not _client_world_ready():
		return {"enabled": false, "reason": "Synchronizing the world. Your weave is unchanged."}
	if starter_context:
		var starter_request: Dictionary = spell_loom_editor.request_starter_apply() if spell_loom_editor != null else {}
		var expected_value: Variant = starter_request.get("expected_wire_ids", PackedInt32Array())
		if (
			starter_request.is_empty()
			or champion_catalog == null
			or champion_catalog.champion_id_from_wire(state.champion_wire_id) != String(starter_request.get("champion_id", ""))
			or not expected_value is PackedInt32Array
			or (expected_value as PackedInt32Array) != state.spell_wire_ids
		):
			return {"enabled": false, "reason": "Character or weave changed. Cancel and reopen the starter preview."}
	if not SessionTransport._valid_weave_wires(requested):
		return {"enabled": false, "reason": "Choose a complete valid twelve-spell weave first."}
	if not element_expansion.allows_weave(requested):
		return {"enabled": false, "reason": "Learn this signature by defeating its rival, or try it in the Range."}
	var round_phase := int(_current_round_state().get("phase", SessionRound.Phase.HEARTH))
	var refusal_reason := _session_request_refusal_reason(SessionTransport.REQUEST_WEAVE_APPLY, state)
	if refusal_reason != SessionRequestPolicy.ACCEPTED:
		if round_phase != SessionRound.Phase.HEARTH:
			return {"enabled": false, "reason": "Return to Wellspring free practice before changing your weave."}
		if state.health <= 0:
			return {"enabled": false, "reason": "Return alive before changing your weave."}
		if not ChampionAttunementScript.is_available(state):
			return {"enabled": false, "reason": "Finish the active action before changing your weave."}
		if refusal_reason == SessionRequestPolicy.REFUSED_DISTANCE:
			return {"enabled": false, "reason": "Stand beside the Spell Loom or Gallery to seal changes."}
		return {"enabled": false, "reason": "Spell assignment is unavailable."}
	if not CharacterWeavePolicy.can_apply(state, requested):
		if CharacterWeavePolicy.blocking_cooling_wire(state, requested) > 0:
			return {"enabled": false, "reason": "Wait for the removed spell's cooldown before replacing it."}
		return {"enabled": false, "reason": "Choose a complete valid twelve-spell weave first."}
	if not starter_context and requested == state.spell_wire_ids:
		return {"enabled": false, "reason": "Already in this slot. Choose another spell or target slot."}
	return {"enabled": true, "reason": ""}


func _open_spell_loom_editor() -> void:
	var actor := _local_player_state()
	if actor == null or spell_loom_editor == null: return
	spell_loom_editor.open_editor(actor, ability_catalog)
	element_expansion.refresh_loom()
	_ensure_character_weaves()
	var proposal := character_weaves.migration_for_actor(actor)
	if not bool(proposal.get("required", false)): return
	if bool(proposal.get("valid", false)):
		spell_loom_editor.prepare_migration_preview(actor, ability_catalog, proposal)
	else:
		spell_loom_editor.status_message = String(proposal.get("notice", "Saved weave needs review. Its original file is preserved."))


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
	input_router.configure_accessibility(player_preferences)
	if element_expansion != null: element_expansion.refresh_guide_bindings()
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
	if interception_practice_active or _is_hex_practice() or element_expansion.temporary_session():
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
		print("FLUX2 farflow host: listening on UDP %d | %s | %d places" % [session_transport.bound_port, SessionCharter.display_name(selected_charter_id), session_transport.player_capacity()])
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
	if interception_practice_active or _is_hex_practice() or element_expansion.temporary_session():
		_start_match(tick_rate)
	var signature := _session_compatibility_signature()
	if signature.is_empty():
		station_notice = session_transport.last_error
		station_notice_seconds = 5.0
		return
	if session_transport.start_join(join_address, session_port, signature, local_player_name, SessionCharter.catalog_hash()):
		station_notice = "%s | Seeking %s:%d." % [session_transport.build_id, join_address, session_port]
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
	var terrain_drained := campus_renderer == null or campus_renderer.suspend_terrain()
	if (
		session_transport != null
		and session_transport.is_host()
		and not session_transport.host_roster().is_empty()
		and Time.get_ticks_msec() < safe_quit_deadline_ms
	):
		return
	if not terrain_drained and Time.get_ticks_msec() < safe_quit_deadline_ms:
		return
	if session_transport != null:
		session_transport.stop()
	client_reconciliation_buffer.reset()
	safe_quit_pending = false
	set_process(false)
	print("FLUX2 safe quit: local state flushed and network peer closed")
	get_tree().quit(0)


func _return_to_offline(notice: String) -> void:
	session_transport.stop()
	session_steward.reset()
	client_reconciliation_buffer.reset()
	client_replica_active = false
	client_input_sequence = 0
	client_request_sequence = 0
	last_client_snapshot_tick = -1
	last_client_world_epoch = -1
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
	var team_hearth := _team_hearth_label(hearth_state)
	if not team_hearth.is_empty():
		return team_hearth
	if countdown_ticks > 0:
		var next_round := int(_current_round_state().get("serial", 0)) + 1
		return "ROUND %d IN %.1fs | FIRST 3 | 90s" % [next_round, float(countdown_ticks) / float(maxi(1, tick_rate))]
	if session_transport.is_connected_client() and network_projectile_overflow > 0:
		return "FARFLOW LOAD +%d BOLTS" % network_projectile_overflow
	if session_transport.is_host():
		return "FARFLOW HOST %d/%d | %s" % [session_transport.player_count(), session_transport.player_capacity(), session_transport.build_id]
	if session_transport.is_connected_client():
		if not _client_world_ready(): return "FARFLOW JOINED | SYNCING WORLD"
		if client_prediction != null and client_prediction.is_ready():
			return "FARFLOW JOINED | ACK ~%dms | CORR %.1fpx" % [client_prediction.estimated_ack_delay_ms(), client_prediction.last_correction_pixels]
		return "FARFLOW JOINED | SYNCING"
	return "FARFLOW SEEKING | %s" % join_address


func _current_round_values() -> PackedInt32Array:
	if session_transport.is_host() and authoritative_session != null and authoritative_session.session_round != null:
		return authoritative_session.session_round.capture(world)
	return session_round_values


func _current_round_state() -> Dictionary:
	return SessionRound.decoded(_current_round_values())


func _round_label() -> String:
	return RoundLabel.format(_current_round_state(), session_names_by_entity, session_transport.local_entity_id, tick_rate)


func _team_hearth_label(hearth_state: Dictionary) -> String:
	var connected_ids: Array = []
	var ready_by_id: Dictionary = {}
	for entry: Dictionary in hearth_state.get("entries", []):
		if int(entry.get("status", 0)) == SessionHearth.STATUS_CONNECTED:
			connected_ids.append(int(entry.entity_id))
			ready_by_id[int(entry.entity_id)] = bool(entry.get("ready", false))
	return TeamPresentation.hearth_label(selected_charter_id, connected_ids, session_transport.local_entity_id, tick_rate, int(hearth_state.get("countdown_ticks", 0)), ready_by_id)


func _update_team_smoke() -> void:
	# Explicit diagnostic only: exercise real replicated phase transitions with a
	# shorter first deadline. No score injection, packet fabrication or gameplay
	# change when the test flag is absent.
	if not requested_team_smoke or session_transport == null or not session_transport.is_online(): return
	var state := _current_round_state()
	var serial := int(state.get("serial", 0))
	var phase := int(state.get("phase", SessionRound.Phase.HEARTH))
	var key := "%d/%d" % [serial, phase]
	if serial < 1 or team_smoke_seen.has(key): return
	if phase == SessionRound.Phase.ACTIVE:
		if not TeamPresentation.is_team_round(state): return
		var entries: Array = state.get("entries", [])
		var marker := TeamPresentation.actor_marker(state, session_transport.local_entity_id, session_transport.local_entity_id)
		if marker.is_empty(): return
		team_smoke_seen[key] = true
		print("HEX team smoke: active mode=%s participants=%d serial=%d" % [selected_charter_id, entries.size(), serial])
		print("HEX team smoke: local entity=%d team=%d serial=%d" % [session_transport.local_entity_id, int(marker.team_id), serial])
		if session_transport.is_host() and serial == 1:
			authoritative_session.session_round.round_end_tick = world.tick + world.config.milliseconds_to_ticks(8000)
	elif phase == SessionRound.Phase.RESULT:
		team_smoke_seen[key] = true
		print("HEX team smoke: result serial=%d" % serial)
	elif phase == SessionRound.Phase.HEARTH:
		team_smoke_seen[key] = true
		print("HEX team smoke: hearth after_serial=%d" % serial)


static func _team_color(team_id: int) -> Color:
	return Color("f6c765") if team_id == 1 else Color("76e0d0") if team_id == 2 else PARCHMENT_COLOR


func _draw_team_identity(marker: Dictionary, body_position: Vector2) -> void:
	if marker.is_empty(): return
	_draw_actor_identity_label(String(marker.label), body_position, _team_color(int(marker.team_id)))


func _draw_actor_identity_label(label: String, body_position: Vector2, color: Color) -> void:
	# At the fixed 75% world zoom, 14 world pixels stay above 10 screen pixels.
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var baseline := body_position + Vector2(-width * 0.5, -64)
	draw_rect(Rect2(baseline + Vector2(-3, -13), Vector2(width + 6, 17)), Color("102126dc"))
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)


func _demo_result_eligible() -> bool:
	if world == null or session_transport == null or interception_practice_active or _is_hex_practice(): return false
	return session_transport.mode in [SessionTransport.Mode.OFFLINE, SessionTransport.Mode.HOSTING] \
		and not _gameplay_input_blocked() and not _is_spectating() \
		and int(_current_round_state().get("phase", SessionRound.Phase.HEARTH)) == SessionRound.Phase.HEARTH


func _reconcile_demo_result() -> void:
	if not hex_playground_demo.has_terminal_result(): return
	var actor := _local_player_state()
	hex_playground_demo.validate_result(world, actor.entity_id if actor != null else 0, _demo_result_eligible())


func _demo_result_view() -> Dictionary:
	if not hex_playground_demo.has_terminal_result() or not _demo_result_eligible(): return {}
	return DemoResultCard.build(hex_playground_demo.terminal_result(), _local_player_state(), player_preferences)


func _has_visible_demo_result() -> bool:
	return hex_playground_demo.has_terminal_result() and _demo_result_eligible()


func _handle_demo_result_input(event: InputEvent) -> bool:
	var escape_press: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE
	var close_click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if not escape_press and not close_click: return false
	var view := _demo_result_view()
	if view.is_empty(): return false
	var dismiss := escape_press
	if close_click:
		var layout := DemoResultCard.layout(view, get_viewport_rect().size, event.position, ThemeDB.fallback_font)
		dismiss = not layout.is_empty() and (layout.close as Rect2).has_point(event.position)
	if not dismiss: return false
	hex_playground_demo.dismiss_result()
	controls_input_guard_frames = 2
	if input_router != null: input_router.discard_transient_movement_input()
	get_viewport().set_input_as_handled()
	queue_redraw()
	return true


func _current_hearth_values() -> PackedInt32Array:
	if session_transport.is_host() and authoritative_session != null and authoritative_session.hearth != null:
		return authoritative_session.hearth.capture(world.tick, session_transport.player_capacity())
	return session_hearth_values


func _session_hearth_lines() -> Array:
	if not session_transport.is_online():
		return [
			"FARFLOW IS CLOSED",
			"%s | %d PLACES" % [SessionCharter.display_name(selected_charter_id), SessionCharter.maximum_players(selected_charter_id)],
			"Open or join a friend gate first",
		]
	var values := _current_hearth_values()
	var hearth_state := SessionHearth.decoded(values)
	if hearth_state.is_empty():
		return ["HEARTH STATE UNAVAILABLE"]
	var entries: Array = hearth_state.get("entries", [])
	var team_hearth := _team_hearth_label(hearth_state)
	if not team_hearth.is_empty():
		var team_lines: Array = Array(team_hearth.split("\n"))
		if int(hearth_state.get("countdown_ticks", 0)) > 0:
			team_lines.append("TEAMS LOCK AT START")
		else:
			team_lines.append("HOST " + _station_interact_instruction("starts") if session_transport.is_host() and authoritative_session.can_start_practice() else _station_interact_instruction("toggles ready"))
		return team_lines
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
		lines.append("ROUND %d IN %.1fs | FIRST 3 | 90s" % [completed_rounds + 1, float(countdown_ticks) / float(tick_rate)])
	elif completed_rounds > 0:
		lines.append("REMATCH ROUND %d | %d/%d HERE" % [completed_rounds + 1, connected, int(hearth_state.get("maximum_players", 0))])
	else:
		lines.append("%s | %d/%d HERE%s" % [SessionCharter.display_name(selected_charter_id), connected, int(hearth_state.get("maximum_players", 0)), " | %d RETURNING" % returning if returning > 0 else ""])
	var visible_entries := mini(entries.size(), 4)
	for index: int in range(visible_entries):
		var entry: Dictionary = entries[index]
		var entity_id := int(entry.get("entity_id", 0))
		var state_label := "RETURNING" if int(entry.get("status", 0)) == SessionHearth.STATUS_RETURNING else ("READY" if bool(entry.get("ready", false)) else "WAITING")
		lines.append("%s | %s" % [String(session_names_by_entity.get(entity_id, "Traveller %d" % entity_id)).left(24), state_label])
	if entries.size() > visible_entries:
		lines.append("+%d MORE | ALL MUST READY" % (entries.size() - visible_entries))
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
	var selected_line := "NONE NAMED | %s" % _station_interact_instruction("SELECTS FIRST")
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
		return ["CONFIRM RELEASE: %s" % selected_name, _station_interact_instruction("confirms | %.1fs remain" % remaining_seconds), "No return reservation will remain"]
	return ["NAMED: %s" % selected_name, _station_interact_instruction("arms a three-second release"), "A second matching press must confirm"]


func _start_requested_farflow() -> void:
	match requested_farflow_mode:
		"host":
			_toggle_host_session()
		"join":
			_start_join_session_now()


func _configure_pov_terrain_backdrop() -> void:
	if DisplayServer.get_name() == "headless" or pov_terrain_backdrop != null:
		return
	pov_terrain_backdrop = PovTerrainBackdrop.new()
	add_child(pov_terrain_backdrop)
	pov_terrain_backdrop.configure(campus_renderer, campus_layout)
	pov_terrain_backdrop.set_court_context(SanctumCampusRenderer.SOLO_DUEL_CONTEXT if interception_practice_active else "")


func _draw_pov_mask(origin: Vector2, _aim: Vector2, camera_origin: Vector2) -> void:
	var visible := Rect2(camera_origin, get_viewport_rect().size / _camera_zoom_scale())
	var texture: Texture2D = null
	var backdrop_rect := Rect2()
	if not _is_hex_practice() and pov_terrain_backdrop != null and pov_terrain_backdrop.ready_for(visible):
		texture = pov_terrain_backdrop.backdrop_texture()
		backdrop_rect = pov_terrain_backdrop.world_rect
	pov_terrain_batch.begin(self, texture, backdrop_rect, PixelPresentation.snapped_canvas_origin(camera_origin, PlayerCameraRig.ZOOM_PERCENT), _camera_zoom_scale())
	if _pov_observer() == null:
		_draw_pov_terrain(SightOcclusion.rectangle_polygon(get_viewport_rect()), camera_origin)
		pov_terrain_batch.finish()
		return
	var zoom := _camera_zoom_scale()
	var outer_radius := SightOcclusion.projected_viewport_cover_radius(origin, get_viewport_rect())
	var shadow_reach := maxf(outer_radius, get_viewport_rect().size.length() * 2.25)
	var buildings := _pov_building_surface_polygons(camera_origin)
	var covers := _pov_hex_occluder_polygons(camera_origin)
	for polygon: PackedVector2Array in buildings + covers:
		if Geometry2D.is_point_in_polygon(origin, polygon):
			_draw_pov_terrain(SightOcclusion.rectangle_polygon(get_viewport_rect()), camera_origin)
			pov_terrain_batch.finish()
			return
	# Erase unrelated live pixels from physical Hex interiors, then restore
	# only the current structural layer. It is still shaded by other blockers.
	var world_covers: Array[PackedVector2Array] = []
	for polygon: PackedVector2Array in covers:
		_draw_pov_terrain(polygon, camera_origin, Color.WHITE)
		var world_polygon := PackedVector2Array()
		for vertex: Vector2 in polygon:
			world_polygon.append((vertex - PixelPresentation.snapped_canvas_origin(camera_origin, PlayerCameraRig.ZOOM_PERCENT)) / zoom)
		world_covers.append(world_polygon)
	if not world_covers.is_empty():
		pov_terrain_batch.flush()
		_set_world_transform(camera_origin)
		hex_court_presenter.draw_cover_surfaces(self, world_covers, float(world.tick) + clampf(accumulator_seconds * tick_rate, 0.0, 1.0), _reduced_effects_enabled())
		draw_set_transform(Vector2.ZERO)
	# Static wall surfaces replace any overdrawn live effects inside the solid.
	for polygon: PackedVector2Array in buildings:
		_draw_pov_terrain(polygon, camera_origin, Color.WHITE)
	# Sight covers every viewport corner, so there is no radial fog boundary
	# inside the screen. Only real occluders require terrain replacement. Avoid
	# rebuilding a ring of up to 192 offscreen/degenerate polygons every frame.
	# Apply blocker shadows last. Replacement does not accumulate darkness.
	for polygon: PackedVector2Array in buildings + covers:
		for region: PackedVector2Array in SightOcclusion.shadow_outside_surface(origin, polygon, shadow_reach):
			_draw_pov_terrain(region, camera_origin)
	pov_terrain_batch.finish()


func _pov_building_surface_polygons(camera_origin: Vector2) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if _is_hex_practice():
		return result
	for building_value: Variant in campus_layout.data.get("buildings", []):
		var building: Dictionary = building_value
		if String(building.get("occlusion_policy", "")) != "los_cutaway":
			continue
		var bounds := SanctumCampusLayout._parse_bounds(building.get("bounds", []))
		var screen := Rect2(Vector2(bounds.position) * _camera_zoom_scale() + PixelPresentation.snapped_canvas_origin(camera_origin, PlayerCameraRig.ZOOM_PERCENT), Vector2(bounds.size) * _camera_zoom_scale())
		result.append(SightOcclusion.rectangle_polygon(screen))
	return result


func _draw_pov_terrain(points: PackedVector2Array, camera_origin: Vector2, shade: Color = POV_TERRAIN_SHADE, feather: bool = false) -> void:
	if points.size() < 3:
		return
	if pov_terrain_batch.active:
		pov_terrain_batch.append_polygon(points, shade, POV_TERRAIN_SHADE, feather)
		return
	var colors := PackedColorArray()
	for index: int in points.size():
		colors.append(POV_TERRAIN_SHADE if feather and index in [1, 2] else shade)
	if _is_hex_practice() or pov_terrain_backdrop == null or not pov_terrain_backdrop.ready_for(Rect2(camera_origin, get_viewport_rect().size / _camera_zoom_scale())):
		# The isolated court has no campus underneath it. This opaque fallback
		# also fails closed during initialization; never expose live pixels.
		for index: int in colors.size():
			colors[index] *= Color("25331f")
		draw_polygon(points, colors)
		return
	var uv := PackedVector2Array()
	var translation := PixelPresentation.snapped_canvas_origin(camera_origin, PlayerCameraRig.ZOOM_PERCENT)
	for point: Vector2 in points:
		uv.append(((point - translation) / _camera_zoom_scale() - pov_terrain_backdrop.world_rect.position) / pov_terrain_backdrop.world_rect.size)
	draw_polygon(points, colors, uv, pov_terrain_backdrop.backdrop_texture())


func _pov_observer_ground_position(observer: PlayerState, spectating: bool, rendered_local: Vector2) -> Vector2:
	if not spectating:
		return rendered_local
	return _pov_actor_ground_position(observer)


func _pov_observer_overlay_frame(visual_tick: float, alpha: float) -> Dictionary:
	if world == null or player_preferences == null or cartoon_champion_presenter == null:
		return {}
	var spectating := _is_spectating()
	var observer := _pov_observer()
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
	var frame := cartoon_champion_presenter.movement_frame(champion_id, pose_state, visual_tick, world.config, _reduced_effects_enabled(), actor_motion_history.gait_phase(pose_state.entity_id), actor_motion_history.wall_travel(pose_state.entity_id), _cast_timing_for(observer))
	if frame.is_empty():
		return {}
	var texture: Texture2D = frame.get("texture", cartoon_champion_presenter.texture_for_champion(champion_id))
	if texture == null:
		return {}
	var anchor := shadow_center + Vector2(0.0, -float(jump.body_lift_pixels)) + (frame["offset"] as Vector2)
	if bool(frame.get("fullbody_art", false)):
		return {"fullbody_pose": frame, "anchor": anchor, "observer_id": observer.entity_id}
	return {"texture": texture, "source_region": frame["source_region"], "destination": Rect2(anchor - CartoonChampionPresenter.PIVOT, CartoonChampionPresenter.CELL_SIZE), "observer_id": observer.entity_id}


func _draw_pov_observer_body(camera_origin: Vector2, visual_tick: float, alpha: float) -> void:
	var frame := _pov_observer_overlay_frame(visual_tick, alpha)
	if frame.is_empty():
		return
	# Repaint only the exact binary-alpha owned body pixels. Ground shadows,
	# afterimages, spells and world objects stay under the range/obstacle mask.
	_set_world_transform(camera_origin)
	if frame.has("fullbody_pose"):
		CartoonChampionPresenter.FullbodyCast.draw_frame(self, frame.fullbody_pose, frame.anchor)
	else:
		draw_texture_rect_region(frame["texture"], frame["destination"], frame["source_region"])
	draw_set_transform(Vector2.ZERO)


func _pov_opaque_bounds() -> Array[Rect2]:
	# Layout cannot change between commands in one synchronous draw callback.
	# Borrow this private array only while drawing; outside queries stay fresh.
	if _visibility_frame_active and _visibility_frame_bounds_ready:
		return _visibility_frame_bounds
	var bounds: Array[Rect2] = []
	if campus_layout == null:
		return bounds
	for value: Variant in campus_layout.data.get("buildings", []):
		var building: Dictionary = value
		if String(building.get("occlusion_policy", "")) == "los_cutaway":
			bounds.append(Rect2(SanctumCampusLayout._parse_bounds(building.get("bounds", []))))
	_visibility_bounds_builds += 1
	if _visibility_frame_active:
		_visibility_frame_bounds = bounds
		_visibility_frame_bounds_ready = true
	return bounds


func _begin_visibility_frame() -> void:
	_visibility_frame_active = true
	_visibility_frame_sight_range = -1.0
	_visibility_frame_bounds_ready = false
	_visibility_frame_bounds = []


func _end_visibility_frame() -> void:
	_visibility_frame_active = false
	_visibility_frame_sight_range = -1.0
	_visibility_frame_bounds_ready = false
	_visibility_frame_bounds = []


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
		"SEED %s | WB %s" % [material_grid.seed_state_hash.left(6), material_grid.seed_worldbone_hash.left(6)],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		11,
		ATTUNEMENT_COLOR,
	)


func _restart_shared_seed(requested_tick_rate: int) -> bool:
	hex_playground_demo.cancel(null)
	hex_playground_demo.dismiss_result()
	hex_playground_open = false
	client_reconciliation_buffer.reset()
	if session_transport == null or not session_transport.is_host():
		return _start_match(requested_tick_rate)
	var candidate := _new_wellspring_world(requested_tick_rate)
	if candidate == null: return false
	_spawn_practice_targets(candidate)
	if not authoritative_session.replace_world(candidate, campus_layout.spawn): return false
	world = authoritative_session.world
	if not session_transport.configure_world_epoch(authoritative_session.world_epoch): return false
	session_names_by_entity = authoritative_session.names_by_entity.duplicate()
	session_hearth_values = authoritative_session.hearth.capture(world.tick, SessionCharter.maximum_players(selected_charter_id))
	session_round_values = authoritative_session.session_round.capture(world)
	emote_ready_tick_by_entity.clear()
	social_bubbles.clear()
	combat_cues.clear()
	input_router.discard_transient_movement_input()
	_reset_motion_history()
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
	station_notice = "The Proving Court opens. First team to three." if SessionCharter.required_players(selected_charter_id) > 0 else "The Proving Court opens. First to three."
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
	if requested_rematch_smoke: print("HEX trace Hearth begin ms=%d tick=%d" % [Time.get_ticks_msec(), world.tick])
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
	return _start_match_world(requested_tick_rate)


func _start_match_world(requested_tick_rate: int, prepared_trial_world: SimWorld = null) -> bool:
	local_navigation.close()
	var skip_temporary_weave := element_expansion.temporary_session()
	element_expansion.before_transition()
	service_directory.close()
	directory_return_group = ""
	directory_return_station = ""
	hex_playground_demo.cancel(null)
	hex_playground_demo.dismiss_result()
	hex_playground_open = false
	client_reconciliation_buffer.reset()
	_ensure_character_weaves()
	if world != null and not _is_hex_practice() and not interception_practice_active and not skip_temporary_weave:
		for previous_actor: PlayerState in world.players:
			if previous_actor.actor_kind == PlayerState.ActorKind.CHAMPION: character_weaves.remember_actor(previous_actor)
	pending_weave_request.clear()
	client_weave_restore_champion = 0
	interception_practice_active = false
	if pov_terrain_backdrop != null: pov_terrain_backdrop.set_court_context("")
	interception_practice_setup = {}
	solo_trial.reset()
	solo_trial_menu_open = false
	solo_trial_error = ""
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
	world = prepared_trial_world if prepared_trial_world != null else _new_wellspring_world(tick_rate)
	if world == null: return false
	var player_state: PlayerState = world.player()
	var initial_position := campus_layout.spawn
	if capture_spawn_world.x >= 0 and world.collision.can_occupy(capture_spawn_world * SimConfig.FIXED_SCALE, MovementTuning.PLAYER_RADIUS):
		initial_position = capture_spawn_world
	if prepared_trial_world == null:
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
	input_router.configure_accessibility(player_preferences)
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
	var candidate := _new_wellspring_world(tick_rate)
	if candidate == null: return false
	var setup := InterceptionShowcase.configure(candidate, champion_catalog, ability_catalog, campus_layout)
	var prepared_run := SoloDuelTrial.new()
	var anchors := InterceptionPractice.spawn_contract(campus_layout)
	if setup.is_empty() or anchors.is_empty() or not prepared_run.begin(candidate, anchors.bounds):
		solo_trial_error = "The practice court could not be prepared."
		return false
	if not _start_match_world(tick_rate, candidate): return false
	interception_practice_setup = setup
	interception_practice_active = true
	if pov_terrain_backdrop != null: pov_terrain_backdrop.set_court_context(SanctumCampusRenderer.SOLO_DUEL_CONTEXT)
	solo_trial = prepared_run
	solo_trial_action_index = 0
	player_compendium.close_panel()
	character_selection_grid.close_panel()
	authoritative_session.hearth.connect_entity(2)
	session_names_by_entity[2] = String(champion_catalog.champion(InterceptionPractice.OPPONENT_CHAMPION_ID).get("display_name", "Oh Tipi"))
	current_position = _player_position()
	previous_position = current_position
	_reset_motion_history()
	_solo_trial_input_handoff()
	return true


func _solo_rival_command() -> SimCommand:
	if element_expansion.challenge_active: return element_expansion.rival_command()
	if not interception_practice_active or not solo_trial.is_running(): return null
	return SoloDuelRival.command_for_tick(world.tick, int(interception_practice_setup.start_tick), world.player(2), world.player(1), interception_practice_setup.opponent_profile.slots, solo_trial.court)


func _solo_trial_frozen() -> bool:
	return interception_practice_active and solo_trial.is_finished() and session_transport != null and session_transport.mode == SessionTransport.Mode.OFFLINE


func _open_solo_trial_menu() -> bool:
	if world == null or session_transport == null or session_transport.mode != SessionTransport.Mode.OFFLINE or interception_practice_active or _is_hex_practice():
		return false
	if _directory_child_open() or hex_playground_open or hex_playground_demo.is_active() or not application_input_active:
		return false
	if int(_current_round_state().get("phase", SessionRound.Phase.HEARTH)) != SessionRound.Phase.HEARTH:
		return false
	service_directory.close()
	directory_return_group = ""
	directory_return_station = ""
	solo_trial_menu_open = true
	solo_trial_action_index = 0
	solo_trial_error = ""
	_solo_trial_input_handoff()
	queue_redraw()
	return true


func _solo_trial_input_handoff() -> void:
	controls_input_guard_frames = 2
	if input_router != null:
		input_router.discard_transient_movement_input()
	if element_audio != null:
		element_audio.silence()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _handle_solo_trial_input(event: InputEvent) -> bool:
	if element_expansion.challenge_active: return false
	if not solo_trial_menu_open and not interception_practice_active:
		return false
	var pointer := Vector2(-1, -1)
	if event is InputEventMouse: pointer = event.position / _ui_scale()
	if solo_trial_menu_open or solo_trial.is_finished():
		var intent := SoloTrialPanel.intent(event, pointer, get_viewport_rect().size / _ui_scale(), solo_trial_action_index)
		match intent:
			"toggle": solo_trial_action_index = 1 - solo_trial_action_index
			"primary":
				if not _start_interception_trial(): solo_trial_error = "Trial unavailable. Leave online play and try again."
			"secondary", "cancel":
				if interception_practice_active:
					_start_match(tick_rate)
				else:
					solo_trial_menu_open = false
		_solo_trial_input_handoff()
		get_viewport().set_input_as_handled()
		queue_redraw()
		return true
	var leave: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE
	leave = leave or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK)
	leave = leave or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and SoloTrialPanel.LEAVE.has_point(pointer))
	if leave:
		_start_match(tick_rate)
		_solo_trial_input_handoff()
		get_viewport().set_input_as_handled()
	elif input_router != null and not _gameplay_input_blocked():
		# Trial owns the modal surface; F4, chemistry/reset and nearby station
		# actions cannot open another tool or alter the run. Paid inputs stay normal.
		_observe_movement_practice_device(event)
		input_router.observe_input_event(event)
	return true


func _solo_trial_kit_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	var profile := InterceptionPractice.player_profile(ability_catalog)
	if profile.is_empty(): return lines
	var editor := ControlBindingEditor.new()
	for role: String in ["water_spray", "earth_spray", "fire_bolt", "fire_rapid"]:
		var slot := int(profile.slots[role])
		var key := SpellLoomPresenter.slot_binding_label(slot - 1, player_preferences)
		var pad := editor.binding_label(StringName("spell_%d" % slot), ControlBindingEditor.DEVICE_CONTROLLER, player_preferences)
		lines.append("%s / %s   %s" % [key, pad, String(profile.spell_names[role])])
	return lines


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
	if _gameplay_input_blocked(): return
	var exposure_ticks := int(world.hex_court.exposure.get(_local_player_state().entity_id, 0))
	if exposure_ticks <= 0: return
	# Explain this hazard only while it matters. Navigation lives in Menu.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _ui_scale())
	draw_rect(Rect2(20, 88, 226, 40), PANEL_COLOR)
	draw_string(ThemeDB.fallback_font, Vector2(30, 106), "STEAM EXPOSURE %.1f / 2.0s" % (float(exposure_ticks) / 120.0), HORIZONTAL_ALIGNMENT_LEFT, 206, 12, PARCHMENT_COLOR)
	draw_rect(Rect2(30, 115, 206, 4), Color("4b524d"))
	draw_rect(Rect2(30, 115, 206.0 * float(exposure_ticks) / 240.0, 4), Color("f1c1a5"))
	draw_set_transform(Vector2.ZERO)

func _spawn_practice_targets(destination: SimWorld = null) -> void:
	if destination == null: destination = world
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
		destination.players.append(target)


func _draw_practice_targets(camera_origin: Vector2) -> void:
	var target_definitions: Array[Dictionary] = []
	if _is_hex_practice():
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
		ElementStatusPresenter.draw(self, state, position, world.config, visual_language, _reduced_effects_enabled())
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


func _pov_observer() -> PlayerState:
	if world == null:
		return null
	var spectating := _is_spectating()
	var observer := _spectator_state() if spectating else _local_player_state()
	if observer == null or observer.health <= 0:
		return null
	if not spectating and session_transport.is_connected_client() and observer.entity_id != session_transport.local_entity_id:
		return null # A missing guest must not inherit the host's view.
	return observer


func _pov_actor_ground_position(actor: PlayerState) -> Vector2:
	if actor.entity_id == session_transport.local_entity_id:
		var alpha := clampf(accumulator_seconds * float(tick_rate), 0.0, 1.0)
		return previous_position.lerp(current_position, alpha)
	if actor.actor_kind == PlayerState.ActorKind.CHAMPION:
		var alpha := clampf(remote_snapshot_age_seconds * 60.0 if session_transport.is_connected_client() else accumulator_seconds * float(tick_rate), 0.0, 1.0)
		var point := actor_motion_history.sample(actor, alpha)
		return Vector2(point.x, point.y)
	return Vector2(actor.position_x, actor.position_y) / SimConfig.FIXED_SCALE


# Shared presentation authority: character feet, contact marks and the fog mask
# use the same viewed actor, ground metric and authored opaque geometry.
# Network snapshots still contain complete state; this is not packet redaction.
func _pov_sight_range(observer: PlayerState) -> float:
	if observer == null: return 0.0
	# Detached simulation fixtures have no rendered viewport to cover.
	if not is_inside_tree(): return float(PlayerPreferences.RELATIVE_SIGHT_RANGE)
	if _visibility_frame_active and _visibility_frame_sight_range >= 0.0:
		return _visibility_frame_sight_range
	var origin := _pov_actor_ground_position(observer)
	var camera_origin := _camera_origin(_camera_focus_position(origin))
	var visible := PlayerCameraRig.visible_world_rect(get_viewport_rect(), camera_origin, _camera_zoom_scale())
	var radius := SightOcclusion.viewport_sight_range(origin, visible, float(PlayerPreferences.RELATIVE_SIGHT_RANGE))
	if _visibility_frame_active: _visibility_frame_sight_range = radius
	return radius


func _pov_point_visible(point: Vector2, chemical_reveal: bool = false) -> bool:
	var observer := _pov_observer()
	if observer == null or not point.is_finite():
		return false
	var origin := _pov_actor_ground_position(observer)
	if not SightOcclusion.point_visible(origin, point, Vector2.RIGHT, 360.0, _pov_sight_range(observer), _pov_opaque_bounds()):
		return false
	var start := Vector2i(roundi(origin.x * SimConfig.FIXED_SCALE), roundi(origin.y * SimConfig.FIXED_SCALE))
	var finish := Vector2i(roundi(point.x * SimConfig.FIXED_SCALE), roundi(point.y * SimConfig.FIXED_SCALE))
	if world.collision is HexCollisionWorld and not world.collision.hex_pillar_segment_clear(start, finish):
		return false
	if chemical_reveal:
		return true # Reveal can defeat chemistry, never opaque geometry or range.
	if world.hex_court != null:
		return not HexProductEffects.blocks_sight(world.hex_court, start, finish, world.tick, world.config)
	return not ElementChemistrySystem.blocks_sight(start, finish, world.reactions, world.tick)


func _chemistry_actor_visible(target: PlayerState) -> bool:
	var observer := _pov_observer()
	if target == null or observer == null:
		return false
	if target.entity_id == observer.entity_id:
		return true
	return _pov_point_visible(_pov_actor_ground_position(target), target.chemistry_reveal_ticks > 0 or SpellStatusPolicy.active(target, 4))


func _combat_cue_visible(cue: Dictionary) -> bool:
	if world != null and world.hex_court != null and String(cue.get("kind", "")) == "spray":
		return not _spray_cue_draw_view(cue).is_empty()
	if cue.has("visibility_source_id") and not _chemistry_actor_visible(world.player(int(cue.visibility_source_id))):
		return false
	var entity_id := int(cue.get("visibility_entity_id", 0))
	if entity_id > 0 and not _chemistry_actor_visible(world.player(entity_id)):
		return false
	if not _pov_point_visible(cue.get("position", Vector2(INF, INF))):
		return false
	# A visible endpoint never reveals the hidden caster at the other end.
	if cue.has("start") and not _pov_point_visible(cue.start):
		return false
	return not cue.has("end") or _pov_point_visible(cue.end)


func _spray_cue_draw_view(cue: Dictionary) -> Dictionary:
	# This is a detached presentation view, never a new geometry/authority cache.
	# In particular, the full center envelope may be hidden behind a pillar while
	# the already physically clipped outer spokes remain visible around it.
	if world == null or world.hex_court == null or _pov_observer() == null:
		return {}
	if cue.has("visibility_source_id") and not _chemistry_actor_visible(world.player(int(cue.visibility_source_id))): return {}
	var entity_id := int(cue.get("visibility_entity_id", 0))
	if entity_id > 0 and not _chemistry_actor_visible(world.player(entity_id)): return {}
	var raw_geometry: Variant = cue.get("spray_geometry")
	if not raw_geometry is Dictionary: return {}
	var geometry: Dictionary = raw_geometry
	if not geometry.get("start") is Vector2 or not geometry.get("endpoints") is PackedVector2Array or not geometry.get("brace") is PackedVector2Array: return {}
	var start: Vector2 = geometry.start
	var endpoints: PackedVector2Array = geometry.endpoints
	var brace: PackedVector2Array = geometry.brace
	var definition := CombatTuning.cast_definition(int(cue.get("source_wire_id", 0)))
	if String(definition.get("family", "")) != "spray" or endpoints.size() != 5 or brace.size() != 2 \
		or not cue.get("start") is Vector2 or cue.start != start or not _pov_point_visible(start): return {}
	# From the observer itself, endpoint LOS covers every shorter ray prefix.
	# Otherwise a conservative chemistry broadphase rejects a whole spoke when
	# any active product bounds overlap its observer/start/endpoint triangle's
	# bounds. False positives are intentional; no pixel steps can miss grazing
	# concealment. Exact physical shadows still use the existing final POV mask.
	if world.hex_court.products.size() > HexChemistryWorld.MAX_PRODUCTS: return {}
	var observer_point := _pov_actor_ground_position(_pov_observer())
	var concealment_bounds: Array[Rect2] = []
	if observer_point != start: concealment_bounds = _spray_concealment_bounds()
	var stats := {"probes":0,"box_checks":0}
	var filtered := endpoints.duplicate()
	var visible_indices := PackedInt32Array()
	for index: int in endpoints.size():
		if not endpoints[index].is_finite() or start.distance_to(endpoints[index]) > float(definition.range) / 1000.0 + 0.001: return {}
		if endpoints[index] != start and _spray_spoke_visible(start, endpoints[index], observer_point, concealment_bounds, stats):
			visible_indices.append(index)
		else:
			filtered[index] = start
	if visible_indices.is_empty(): return {}
	var result := cue.duplicate(true)
	var draw_geometry: Dictionary = result.spray_geometry
	draw_geometry.endpoints = filtered
	# Optional near-origin decoration gets the same conservative treatment, not
	# a separate filled shape that could cross an untested chemical shadow.
	if visible_indices.size() != 5 or not _pov_point_visible(brace[0]) or not _pov_point_visible(brace[1]) \
		or not _pov_point_visible((brace[0] + brace[1]) * 0.5):
		draw_geometry.brace = PackedVector2Array([start, start])
	if not _pov_point_visible(cue.get("position", Vector2(INF, INF))): result.label = ""
	result.spray_visible_indices = visible_indices
	result.spray_visibility_probes = int(stats.probes)
	result.spray_chemical_broadphase = not concealment_bounds.is_empty()
	result.spray_chemical_box_checks = int(stats.box_checks)
	result.spray_concealer_count = concealment_bounds.size()
	return result


func _spray_concealment_bounds() -> Array[Rect2]:
	# Existing effect policy owns activation/cadence/coverage, not a duplicated
	# recipe list. Each finite product's whole-cell bounds are built once/view.
	var result: Array[Rect2] = []
	var half_size := Vector2(HexGrid.HALF_WIDTH, HexGrid.HALF_HEIGHT) / 1000.0
	for product: Dictionary in world.hex_court.products.values():
		if not HexProductEffects._active(product, world.tick) \
			or not HexProductEffects._concealing(product, int(product.get("recipe_wire_id", 0)), world.tick, world.config): continue
		var coverage := HexProductEffects._coverage(product)
		var bounds := Rect2()
		var found := false
		for cell: Vector2i in coverage:
			if not HexFootprint._selected_cell_active(coverage, cell): continue
			var center := Vector2(world.hex_court.origin + HexGrid.center(cell)) / 1000.0
			var cell_bounds := Rect2(center - half_size, half_size * 2.0)
			bounds = bounds.merge(cell_bounds) if found else cell_bounds
			found = true
		# One fixed-unit expansion prevents float conversion from losing a face.
		if found: result.append(bounds.grow(0.001))
	return result


func _spray_spoke_visible(start: Vector2, endpoint: Vector2, observer_point: Vector2, concealment_bounds: Array[Rect2], stats: Dictionary) -> bool:
	# Maximum authored Spray is380px. Work is one endpoint query and at most32
	# product-AABB comparisons, independent of spoke length or frame resolution.
	const MAX_SPRAY_PIXELS := 380.0
	var distance := start.distance_to(endpoint)
	if not start.is_finite() or not endpoint.is_finite() or distance > MAX_SPRAY_PIXELS + 0.001: return false
	stats.probes += 1
	if not _pov_point_visible(endpoint): return false
	var triangle_bounds := Rect2(observer_point,Vector2.ZERO).expand(start).expand(endpoint)
	for bounds: Rect2 in concealment_bounds:
		stats.box_checks += 1
		if triangle_bounds.intersects(bounds,true): return false
	return true


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
			var body := _pov_actor_ground_position(owner) + Vector2(0.0, float(MovementTuning.PLAYER_RADIUS) / 1000.0 * 0.58 - float(lift.body_lift_pixels))
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
	if foundation_spell_presenter != null and foundation_spell_presenter.draw_expanded_projectile(self, projectile, world.tick, _reduced_effects_enabled(), interpolation_alpha, world.player(projectile.owner_id)):
		return
	if world.hex_court != null:
		hex_court_presenter.draw_projectile(self, projectile, world.tick, interpolation_alpha, _reduced_effects_enabled())
		return
	if burst_projectile_presenter != null and burst_projectile_presenter.draw_projectile(self, projectile, world.tick, _reduced_effects_enabled(), interpolation_alpha):
		return
	if foundation_spell_presenter != null and foundation_spell_presenter.draw_projectile(self, projectile, world.tick, _reduced_effects_enabled(), interpolation_alpha):
		return
	var radius: float = float(projectile.radius) / 1000.0
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
	# Direct callers have not necessarily used the command-line parser. Admit the
	# entire request before a first valid spell can rearrange the existing weave.
	if not state.has_valid_spell_slots():
		return false
	var proven := state.proven_spell_wire_ids()
	var seen := {}
	for wire_id: int in wire_ids:
		if not CombatTuning.is_runtime_wire_id(wire_id) or not proven.has(wire_id) or seen.has(wire_id):
			return false
		seen[wire_id] = true
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
	# F8/F9/F10 metadata remains load-compatible; sight is no longer a setting.
	if Input.is_action_just_pressed(&"adjust_camera_zoom"):
		# Retain old profiles without exposing an ineffective zoom choice.
		station_notice = "Camera framing is fixed at 75%. Aim arrow: Controls > I."
		station_notice_seconds = 2.5
	if changed and not _save_player_preferences_if_persistent():
		push_warning(player_preferences.last_error)


func _save_player_preferences_if_persistent() -> bool:
	if preference_overrides_are_transient:
		return true
	if not preferences_persistence_allowed:
		player_preferences.last_error = "Preferences remain in memory; the existing profile and recovery copy were kept unchanged."
		return false
	return player_preferences.save_to_file()


func _apply_performance_preferences() -> void:
	if player_preferences == null: return
	RenderQuality.set_profile(player_preferences.render_quality)
	Engine.max_fps = player_preferences.frame_limit
	element_garden_presenter.set_render_detail(RenderQuality.garden_sample_limit(), false)
	if input_router != null: input_router.configure_accessibility(player_preferences)


func _change_performance_preferences(changes: Dictionary) -> bool:
	var candidate := player_preferences.to_dictionary()
	for key: String in changes:
		if key not in ["render_quality", "frame_limit", "ui_text_percent", "movement_deadzone_percent", "aim_deadzone_percent"]: return false
		candidate[key] = changes[key]
	if not player_preferences.apply_dictionary(candidate): return false
	_apply_performance_preferences()
	queue_redraw()
	return _save_player_preferences_if_persistent()


func _area_loading() -> bool:
	return terrain_loading or element_garden_arrival_pending


func _request_element_garden_arrival() -> void:
	_cancel_element_garden_arrival()
	if not _element_garden_available() or element_expansion.challenge_active or hex_playground_demo.is_active(): return
	element_garden_arrival_pending = true
	_element_garden_arrival_world_id = world.get_instance_id()
	_element_garden_arrival_generation = element_garden.configuration_generation()
	# Establish exact required counts before the first possible overlay draw.
	var observer := _player_position()
	var origin := _camera_origin(_camera_focus_position(current_position))
	if not element_garden.request_arrival(Rect2(origin, get_viewport_rect().size / _camera_zoom_scale()), observer):
		var failure: String = element_garden.last_error
		_cancel_element_garden_arrival()
		element_garden_arrival_error = failure


func _cancel_element_garden_arrival() -> void:
	element_garden_arrival_pending = false
	element_garden_arrival_error = ""
	_element_garden_arrival_world_id = 0
	_element_garden_arrival_generation = 0
	element_garden.cancel_arrival()
	element_garden_presenter.cancel_arrival(element_garden.render_entries())


func _prepare_element_garden_arrival_frame() -> void:
	if _element_garden_arrival_world_id != 0:
		if not _element_garden_available() or element_expansion.challenge_active or hex_playground_demo.is_active() or world.get_instance_id() != _element_garden_arrival_world_id or element_garden.configuration_generation() != _element_garden_arrival_generation:
			_cancel_element_garden_arrival()
			return
	if not element_garden_arrival_pending: return
	var observer := _player_position()
	var origin := _camera_origin(_camera_focus_position(current_position))
	var view := Rect2(origin, get_viewport_rect().size / _camera_zoom_scale())
	if not element_garden.request_arrival(view, observer) or not element_garden.prepare_arrival():
		# A failed exhibit cannot keep an endless loading overlay. The ordinary
		# step retains its existing error/fallback path; no ground error is forged.
		var failure: String = element_garden.last_error
		_cancel_element_garden_arrival()
		element_garden_arrival_error = failure
		return
	var arrival: Dictionary = element_garden.arrival_status()
	if not element_garden_presenter.prepare_arrival(element_garden.arrival_render_entries(), int(arrival.required), _reduced_effects_enabled()):
		var failure := String(element_garden_presenter.arrival_status().error)
		_cancel_element_garden_arrival()
		element_garden_arrival_error = failure
		return
	# A ready Garden stays detached while ground is still loading. Resize and
	# zoom changes can then rekey the final view before any exhibit is published.
	if not terrain_loading and bool(arrival.ready) and bool(element_garden_presenter.arrival_status().ready):
		if element_garden.publish_arrival():
			element_garden_arrival_pending = false


func _prepare_terrain_frame() -> void:
	terrain_loading = false
	terrain_loading_error = ""
	# Non-rendering tests and dedicated headless runs do not need GPU resources.
	if campus_renderer == null or DisplayServer.get_name() == "headless": return
	if _is_hex_practice():
		campus_renderer.suspend_terrain()
		return
	var origin := _camera_origin(_camera_focus_position(current_position))
	var visible := Rect2(origin, get_viewport_rect().size / _camera_zoom_scale())
	var ready := campus_renderer.prepare_terrain_view(visible, 2)
	terrain_loading = not ready
	if terrain_loading: terrain_loading_error = String(campus_renderer.terrain_status().get("error", ""))


func _draw_terrain_loading() -> void:
	draw_set_transform(Vector2.ZERO)
	draw_rect(get_viewport_rect(), Color("14242c"))
	var center := get_viewport_rect().size * 0.5
	var label := "Preparing this area…" if terrain_loading_error.is_empty() else "This area's ground could not load."
	draw_string(ThemeDB.fallback_font, center + Vector2(-220, -8), label, HORIZONTAL_ALIGNMENT_CENTER, 440, 20, Color("eee0b8"))
	if not terrain_loading_error.is_empty():
		draw_string(ThemeDB.fallback_font, center + Vector2(-320, 26), "Restart H.E.X. from its complete portable folder.", HORIZONTAL_ALIGNMENT_CENTER, 640, 14, Color("acbebd"))
	else:
		var status: Dictionary = campus_renderer.terrain_status() if campus_renderer != null else {}
		var ready_count := int(status.get("ready", 0))
		var required_count := int(status.get("required", 0))
		if element_garden_arrival_pending:
			var arrival: Dictionary = element_garden.arrival_status()
			var visual: Dictionary = element_garden_presenter.arrival_status()
			ready_count += int(arrival.prepared) + mini(int(arrival.required), int(visual.prepared))
			# Both prerequisites exist from the initial request, even before the
			# first visual pump has run. Completion cannot precede preparation.
			required_count += int(arrival.required) * 2
		var fraction := clampf(float(ready_count) / maxf(1.0, float(required_count)), 0.0, 1.0)
		draw_rect(Rect2(center + Vector2(-110, 20), Vector2(220, 3)), Color("305157"))
		draw_rect(Rect2(center + Vector2(-110, 20), Vector2(220 * fraction, 3)), Color("b8b780"))


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
		client_reconciliation_buffer.reset(session_transport.world_epoch)
		client_prediction.reset()
		station_notice = "The Court is underway. Follow now; join at the Hearth."
		station_notice_seconds = 4.0
		if requested_spectator_smoke and not spectator_smoke_active_reported:
			spectator_smoke_active_reported = true
			print("FLUX2 farflow spectator smoke: late guest following entity %d" % spectator_focus.focus_entity_id)
	elif was_spectating and not now_spectating:
		client_reconciliation_buffer.reset(session_transport.world_epoch)
		# The accepted handoff envelope already staged its local context. Keep it
		# so the first exact reconciliation works, not only the following snapshot.
		if client_prediction.local_entity_id != session_transport.local_entity_id or client_prediction.config == null or (world.hex_court != null and client_prediction.hex_context_tick != world.tick):
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
	cast_startup_witness.clear()
	player_camera.clear()
	camera_focus_entity = -1
	actor_motion_history.clear()
	character_movement_trail.clear()
	if cartoon_champion_presenter != null:
		cartoon_champion_presenter.clear_motion_contacts()
	actor_motion_history.capture(world.players)
	var actor := _local_player_state()
	previous_air_height = actor.air_height if actor != null else 0
	remote_snapshot_age_seconds = 0.0


func _is_spectating() -> bool:
	return _is_spectating_world(world)


func _is_spectating_world(candidate: SimWorld) -> bool:
	return session_transport != null and session_transport.is_connected_client() and spectator_focus != null and spectator_focus.active and candidate != null and candidate.player(spectator_focus.focus_entity_id) != null


func _spectator_state() -> PlayerState:
	return world.player(spectator_focus.focus_entity_id) if world != null and spectator_focus != null and spectator_focus.focus_entity_id > 0 else null


func _spectator_name(entity_id: int) -> String:
	return String(session_names_by_entity.get(entity_id, "Traveller %d" % entity_id)).left(SessionTransport.MAX_PLAYER_NAME_LENGTH)


func _camera_focus_position(local_position: Vector2) -> Vector2:
	var state := _spectator_state() if _is_spectating() else null
	return _pov_actor_ground_position(state) if state != null else local_position


func _local_player_state() -> PlayerState:
	if world == null:
		return null
	var entity_id: int = SessionTransport.SERVER_PEER_ID
	if session_transport != null and session_transport.is_connected_client() and session_transport.local_entity_id > 0:
		entity_id = session_transport.local_entity_id
	var state: PlayerState = world.player(entity_id)
	return state if state != null else world.player(SessionTransport.SERVER_PEER_ID)


func _advance_player_camera(delta: float, blocked: bool) -> void:
	if campus_layout == null and not _is_hex_practice():
		return
	var state := _spectator_state() if _is_spectating() else _local_player_state()
	if not _is_spectating() and session_transport != null and session_transport.is_connected_client() and client_prediction != null and client_prediction.is_ready():
		state = client_prediction.predicted_state
	if state == null:
		return
	var alpha := clampf(accumulator_seconds * tick_rate, 0.0, 1.0)
	var feet := _camera_focus_position(previous_position.lerp(current_position, alpha))
	var viewport := get_viewport_rect().size
	var bounds := Rect2(Vector2.ZERO, Vector2(1280, 960) if _is_hex_practice() else Vector2(campus_layout.canvas_size))
	var top := 64.0 if _is_hex_practice() else float(campus_layout.reserved_ui_top)
	var look := PlayerCameraRig.mouse_look_intent(get_viewport().get_mouse_position(), viewport, top)
	if input_router.is_controller_aim_active() or _is_spectating():
		look = Vector2(state.aim_x, state.aim_y).normalized()
	elif capture_pointer_world.x >= 0:
		look = (Vector2(capture_pointer_world) - feet).limit_length(320.0) / 320.0
	player_camera.advance(feet, Vector2(state.velocity_x,state.velocity_y) / SimConfig.FIXED_SCALE, look, delta, viewport, bounds, top, _reduced_effects_enabled(), blocked or not get_window().has_focus(), camera_focus_entity != state.entity_id)
	camera_focus_entity = state.entity_id


func _toggle_direction_indicator() -> void:
	player_preferences.direction_indicator = not player_preferences.direction_indicator
	controls_editor.status_message = "Ground aim arrow %s; camera fixed at 75%%." % ("on" if player_preferences.direction_indicator else "off")
	if not _save_player_preferences_if_persistent():
		push_warning(player_preferences.last_error)


func _camera_origin(focus_position: Vector2) -> Vector2:
	if player_camera.initialized:
		return player_camera.origin
	if _is_hex_practice():
		return camera_origin_for(focus_position, Vector2i(get_viewport_rect().size), Vector2i(1280, 960), 64, PlayerCameraRig.ZOOM_PERCENT)
	if campus_layout == null:
		return Vector2.ZERO
	return camera_origin_for(
		focus_position,
		Vector2i(get_viewport_rect().size),
		campus_layout.canvas_size,
		campus_layout.reserved_ui_top,
		PlayerCameraRig.ZOOM_PERCENT,
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
	return PlayerCameraRig.ZOOM


func _ui_scale() -> float:
	return ui_scale_for(get_viewport_rect().size) * (float(player_preferences.ui_text_percent)/100.0 if player_preferences != null else 1.0)


static func ui_scale_for(viewport_size: Vector2) -> float:
	return clampf(minf(viewport_size.x / 1280.0, viewport_size.y / 720.0), 1.0, 1.5)


func _set_world_transform(camera_origin: Vector2) -> void:
	var zoom := _camera_zoom_scale()
	draw_set_transform(PixelPresentation.snapped_canvas_origin(camera_origin, PlayerCameraRig.ZOOM_PERCENT), 0.0, Vector2(zoom, zoom))


func _set_world_local_transform(world_position: Vector2, local_scale: Vector2, camera_origin: Vector2) -> void:
	var zoom := _camera_zoom_scale()
	draw_set_transform(PixelPresentation.world_to_screen(world_position, camera_origin, PlayerCameraRig.ZOOM_PERCENT), 0.0, local_scale * zoom)



func _ensure_character_weaves() -> void:
	if character_weaves.champions != null or champion_catalog == null or ability_catalog == null: return
	if not character_weaves.configure(champion_catalog, ability_catalog, preferences_persistence_allowed and not preference_overrides_are_transient):
		station_notice = "Saved spell weaves could not load; stored file preserved."
		station_notice_seconds = 5.0


func _save_confirmed_weave(state: PlayerState, mode: String) -> void:
	if element_expansion.temporary_session():
		spell_loom_editor.status_message = "Practice weave applied for this session; original saved weave retained."
		return
	if not character_weaves.save_local(state, mode):
		spell_loom_editor.status_message = "Weave works for this session; saved file could not be updated."
		station_notice = spell_loom_editor.status_message
		station_notice_seconds = 5.0


func _submit_starter_weave() -> void:
	var request := spell_loom_editor.request_starter_apply()
	var state := _local_player_state()
	if request.is_empty() or state == null: return
	var mode := CharacterWeaveLibrary.MODE_CUSTOM if String(spell_loom_editor.starter_preview.get("kind", "starter")) == "migration" else CharacterWeaveLibrary.MODE_STARTER
	_submit_whole_weave(state, request.expected_wire_ids, request.wire_ids, mode, true, true)


func _submit_whole_weave(state: PlayerState, expected: PackedInt32Array, requested: PackedInt32Array, mode: String, save: bool, starter_context: bool = false) -> void:
	if session_transport.is_connected_client() and not _client_world_ready():
		spell_loom_editor.complete_starter_apply(false)
		spell_loom_editor.status_message = "Synchronizing the world. Your weave is unchanged."
		return
	if not pending_weave_request.is_empty() or client_request_sequence >= 0x7fffffff: return
	if not SessionTransport._valid_weave_wires(expected, true) or not SessionTransport._valid_weave_wires(requested):
		spell_loom_editor.status_message = "Choose a complete valid twelve-spell weave first."
		return
	if not bool(_loom_assignment_availability(state, requested, starter_context).get("enabled", false)):
		return
	client_request_sequence += 1
	pending_weave_request = {"champion": state.champion_wire_id, "actor": state.entity_id, "context": _weave_session_context(), "wires": requested.duplicate(), "mode": mode, "save": save,
		"sequence": client_request_sequence, "acknowledged": false, "deadline_ms": Time.get_ticks_msec() + 5000}
	spell_loom_editor.status_message = "Applying weave; waiting for authority confirmation."
	if spell_loom_editor.starter_preview_active(): spell_loom_editor.starter_preview.notice = "Apply sent. Waiting for authority; this request can no longer be cancelled."
	if session_transport.is_connected_client():
		if not session_transport.send_weave_request(client_request_sequence, state.champion_wire_id, expected, requested):
			pending_weave_request.clear()
			spell_loom_editor.complete_starter_apply(false)
			spell_loom_editor.status_message = "Request could not be sent. Your current weave is unchanged."
		return
	_handle_session_requests([{"entity_id": state.entity_id, "action": SessionTransport.REQUEST_WEAVE_APPLY, "value": state.champion_wire_id, "expected": expected, "wires": requested, "sequence": client_request_sequence}])


func _complete_pending_weave() -> void:
	if pending_weave_request.is_empty(): return
	var state := _local_player_state()
	if pending_weave_request.context != _weave_session_context() or state == null or state.entity_id != int(pending_weave_request.actor) or state.champion_wire_id != int(pending_weave_request.champion):
		pending_weave_request.clear()
		spell_loom_editor.complete_starter_apply(false)
		spell_loom_editor.status_message = "Session or character changed. Check the current weave; no local save was made."
		return
	# Confirmed matching authority wins even when the UI deadline just elapsed.
	if bool(pending_weave_request.get("acknowledged", false)) and state.spell_wire_ids == (pending_weave_request.wires as PackedInt32Array):
		var completed := pending_weave_request.duplicate(true)
		pending_weave_request.clear()
		spell_loom_editor.complete_starter_apply(true)
		spell_loom_editor.status_message = "Twelve spell positions applied."
		station_notice = spell_loom_editor.status_message
		station_notice_seconds = 2.5
		if bool(completed.get("save", false)): _save_confirmed_weave(state, String(completed.mode))
	elif Time.get_ticks_msec() >= int(pending_weave_request.deadline_ms):
		pending_weave_request.clear()
		spell_loom_editor.complete_starter_apply(false)
		spell_loom_editor.status_message = "Confirmation timed out. Check the current weave before retrying; no local save was made."
		station_notice = spell_loom_editor.status_message
		station_notice_seconds = 5.0


func _weave_session_context() -> Array:
	return [session_transport.mode, session_transport.local_entity_id, session_transport.world_epoch,
		session_transport.peer.get_instance_id() if session_transport.peer != null else 0]


func _matches_pending_weave_feedback(event: Dictionary) -> bool:
	return not pending_weave_request.is_empty() and pending_weave_request.context == _weave_session_context() \
		and int(event.get("entity_id", 0)) == int(pending_weave_request.actor) \
		and int(event.get("sequence", -1)) == int(pending_weave_request.sequence) \
		and (String(event.get("type", "")) == "request_refused" or int(event.get("champion_wire_id", 0)) == int(pending_weave_request.champion))


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


func _is_hex_practice() -> bool:
	return world != null and world.map_id == "hex-court-v1"


func _new_wellspring_world(rate: int) -> SimWorld:
	var candidate := SimWorld.new(rate, 8675309, campus_layout.build_collision_world(), String(campus_layout.data.id), campus_layout.content_hash)
	var definition := HexWorldDefinition.from_campus(campus_layout)
	if definition == null or not definition.bind_world(candidate): return null
	return candidate


func _envelope_names(envelope: Dictionary) -> Dictionary[int, String]:
	var result: Dictionary[int, String] = {}
	for row: Array in WorldSnapshotEnvelope.names(envelope): result[int(row[0])] = String(row[1])
	return result


func _client_world_ready() -> bool:
	return world != null and session_transport != null and last_client_world_epoch >= 0 and last_client_world_epoch == session_transport.world_epoch


func _incoming_spectator_state(candidate: SimWorld, envelope: Dictionary) -> bool:
	if session_transport == null or not session_transport.is_connected_client(): return false
	var available: Array[int] = []
	for actor: PlayerState in candidate.players:
		if actor.actor_kind == PlayerState.ActorKind.CHAMPION: available.append(actor.entity_id)
	var preview := SpectatorFocus.new()
	return preview.reconcile(SessionRound.decoded(WorldSnapshotEnvelope.round_state(envelope)), session_transport.local_entity_id, available)


func _apply_world_envelope(envelope: Dictionary) -> bool:
	if not WorldSnapshotEnvelope.validate(envelope): return false
	var epoch := int(envelope.world_epoch)
	var next_tick := int(envelope.tick)
	if epoch < last_client_world_epoch or (epoch == last_client_world_epoch and next_tick <= last_client_snapshot_tick): return false
	var candidate: SimWorld = null
	if int(envelope.world_kind) == WorldSnapshotEnvelope.WORLD_HEX:
		# Remote metadata only selects the trusted local campus; it supplies no topology.
		if String(envelope.authority.map_id) != String(campus_layout.data.id): return false
		if trusted_hex_template == null: trusted_hex_template = _new_wellspring_world(tick_rate)
		if trusted_hex_template == null: return false
		candidate = HexWorldSnapshot.prepare(envelope.authority, trusted_hex_template)
	else:
		candidate = SimWorld.new(tick_rate, 8675309, campus_layout.build_collision_world(), String(campus_layout.data.id), campus_layout.content_hash)
		if not SessionSnapshot.apply_to_world(envelope.authority, candidate): return false
	if candidate == null: return false
	for row: Array in WorldSnapshotEnvelope.names(envelope):
		var actor := candidate.player(int(row[0]))
		if actor == null: return false
		actor.last_event = String(row[2])
	candidate.combat_events.clear()
	for row: PackedInt64Array in WorldSnapshotEnvelope.events(envelope):
		var event := SessionSnapshot.decode_event(row)
		if not event.is_empty(): candidate.combat_events.append(event)
	var changed_epoch := epoch != last_client_world_epoch
	var next_prediction := client_prediction
	var prepared_context := {}
	var spectating := _incoming_spectator_state(candidate, envelope)
	if not spectating:
		if changed_epoch or _is_spectating() or next_prediction == null or next_prediction.local_entity_id != session_transport.local_entity_id:
			next_prediction = ClientPrediction.new()
			if not next_prediction.configure(candidate.config, candidate.collision, session_transport.local_entity_id): return false
		if candidate.hex_court != null:
			prepared_context = _prepare_client_hex_context(next_prediction, candidate)
			if prepared_context.is_empty(): return false
		elif next_prediction.hex_authority != null:
			# A world-kind replacement must not keep chemistry from the old map.
			next_prediction = ClientPrediction.new()
			if not next_prediction.configure(candidate.config, candidate.collision, session_transport.local_entity_id): return false
	elif changed_epoch or not _is_spectating():
		next_prediction = ClientPrediction.new()
	# Envelope validation already bounds epoch. Every fallible preparation above
	# precedes publication; a refused bind cannot clear history or swap replicas.
	if not client_reconciliation_buffer.configure_epoch(epoch): return false
	if not prepared_context.is_empty(): next_prediction.publish_hex_context(prepared_context)
	hex_playground_demo.cancel(null)
	hex_playground_demo.dismiss_result()
	cast_startup_witness.clear()
	world = candidate
	client_prediction = next_prediction
	last_client_world_epoch = epoch
	if changed_epoch:
		combat_cues.clear()
		social_bubbles.clear()
		emote_ready_tick_by_entity.clear()
		_reset_motion_history()
	return true


func _prepare_client_hex_context(predictor: ClientPrediction, candidate: SimWorld) -> Dictionary:
	return predictor.prepare_hex_context(candidate)


func _draw_hex_playground_panel() -> void:
	if _readable_ui():
		readable_chemistry_demo.draw(self,get_viewport_rect().size/_ui_scale(),hex_playground_pair)
	else:
		HexPlaygroundPanel.draw(self,HEX_PLAYGROUND_RECT,hex_playground_pair,_reduced_effects_enabled())


func _handle_hex_playground_input(event: InputEvent) -> void:
	var intent: Dictionary = {}
	if _readable_ui():
		var logical_event: InputEvent = event
		if event is InputEventMouseButton:
			var pointer_event: InputEventMouseButton = event.duplicate()
			pointer_event.position = event.position/_ui_scale()
			logical_event = pointer_event
		intent = readable_chemistry_demo.handle_input(logical_event,get_viewport_rect().size/_ui_scale(),hex_playground_pair)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		intent = {"action":"close_hex_playground"}
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_B, JOY_BUTTON_BACK]:
		intent = {"action":"close_hex_playground"}
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		intent = HexPlaygroundPanel.intent_at(event.position / _ui_scale(),HEX_PLAYGROUND_RECT,hex_playground_pair,_reduced_effects_enabled())
	_apply_hex_playground_intent(intent)
	controls_input_guard_frames = 2
	input_router.discard_transient_movement_input()
	get_viewport().set_input_as_handled()
	queue_redraw()


func _apply_hex_playground_intent(intent: Dictionary) -> void:
	match String(intent.get("action", "")):
		"select_hex_pair": hex_playground_pair = intent.selected_pair
		"close_hex_playground": hex_playground_open = false
		"open_chemistry_help":
			hex_playground_open = false
			_open_player_compendium(PlayerCompendiumScript.CHEMISTRY)
		"open_spell_loom":
			hex_playground_open = false
			_open_spell_loom_editor()
			spell_loom_editor.status_message = "Inspect any spell here. Stand beside the Spell Loom to seal changes."
		"launch_paid_hex_demo":
			if (session_transport.mode != SessionTransport.Mode.OFFLINE and not session_transport.is_host()) or (session_transport.is_host() and authoritative_session.session_round.phase != SessionRound.Phase.HEARTH):
				station_notice = "Guided casts are available to the host during free practice. Guests can cast their own weave."
			else:
				if hex_playground_demo.begin(world, session_transport.local_entity_id, hex_playground_pair.x, hex_playground_pair.y, ability_catalog):
					hex_playground_open = false
					_reset_motion_history()
				station_notice = hex_playground_demo.status()
			station_notice_seconds = 5.0
		"reset_hex_playground_area":
			if (session_transport.mode != SessionTransport.Mode.OFFLINE and not session_transport.is_host()) or (session_transport.is_host() and authoritative_session.session_round.phase != SessionRound.Phase.HEARTH):
				station_notice = "The host can reset Wellspring during free practice."
			elif _restart_shared_seed(tick_rate):
				station_notice = "Wellspring reset. Weaves retained; paid fields and practice targets cleared."
			station_notice_seconds = 5.0


func _pov_hex_occluder_polygons(camera_origin: Vector2) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if world == null or not (world.collision is HexCollisionWorld): return result
	for fixed_polygon: Array in world.collision.hex_occluders():
		var polygon := PackedVector2Array()
		for vertex: Vector2i in fixed_polygon:
			polygon.append(Vector2(vertex) / SimConfig.FIXED_SCALE * _camera_zoom_scale() + PixelPresentation.snapped_canvas_origin(camera_origin, PlayerCameraRig.ZOOM_PERCENT))
		result.append(polygon)
	return result


func _readable_ui() -> bool:
	return player_preferences != null and ReadingPolicy.needs_reflow(get_viewport_rect().size,player_preferences.ui_text_percent)
