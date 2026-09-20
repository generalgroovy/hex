extends "res://src/app/bootstrap.gd"

var fixture_viewport: SubViewport
var binding_commit_count := 0


# Keep the real ingestion, ownership, visibility, focus and volume controls.
# No boot, sockets, preferences file, automatic simulation, drawing or playback.
# Binding capture keeps its real editor route; commit never alters global InputMap.
func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	pass


func _draw() -> void:
	pass


func _input(_event: InputEvent) -> void:
	pass


func _ingest_magic_release(_event: Dictionary) -> void:
	pass


func _commit_control_bindings() -> void:
	binding_commit_count += 1


func configure_fixture(catalog: AbilityCatalog, cached_clips: Dictionary) -> bool:
	ability_catalog = catalog
	world = SimWorld.new(120, 929, CollisionWorld.new(2_000_000, 2_000_000))
	world.player().position_x = 300_000
	world.player().position_y = 360_000
	world.player().spawn_protection_ticks = 0
	world.player().flux_recovery_per_second = 0
	var target := PlayerState.new(2)
	target.team_id = 2
	target.position_x = 420_000
	target.position_y = 360_000
	target.spawn_protection_ticks = 0
	world.players.append(target)
	session_transport = SessionTransport.new()
	spectator_focus = SpectatorFocus.new()
	controls_editor = ControlBindingEditor.new()
	spell_loom_editor = SpellLoomEditor.new()
	player_compendium = PlayerCompendiumScript.new()
	character_selection_grid = CharacterSelectionGridScript.new()
	player_preferences = PlayerPreferences.new()
	player_preferences.set_camera_zoom_percent(100)
	campus_layout = SanctumCampusLayout.new()
	if not campus_layout.load_from_file(CAMPUS_LAYOUT_PATH):
		return false
	current_position = Vector2(world.player().position_x, world.player().position_y) / SimConfig.FIXED_SCALE
	preference_overrides_are_transient = true
	element_audio = ElementAudioScript.new()
	element_audio.clips = cached_clips.duplicate()
	element_audio.prepare(false)
	add_child(element_audio)
	fixture_viewport = SubViewport.new()
	fixture_viewport.size = Vector2i(1280, 720)
	fixture_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(fixture_viewport)
	fixture_viewport.add_child(self)
	return world.is_valid()


func ingest_fresh(event: Dictionary) -> int:
	element_audio.silence()
	var before := element_audio.admitted_count
	_ingest_combat_cues([event])
	return element_audio.admitted_count - before


func cleanup_fixture() -> void:
	fixture_viewport.free() # Also owns this bootstrap and its silent audio node.
