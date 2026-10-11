extends "res://src/app/bootstrap.gd"


# No boot, socket, disk preferences, audio or automatic simulation side effects.
# Coach gating and (for capture) the entire gameplay _draw remain inherited.
var fixture_anchor := Vector2i.ZERO
var fixture_target := Vector2i.ZERO
var paid_casts := 0
var hide_chemistry_for_visual_probe := false

func _draw_element_chemistry(visual_tick: float, camera_origin: Vector2) -> void:
	if not hide_chemistry_for_visual_probe:
		super._draw_element_chemistry(visual_tick, camera_origin)


func _init() -> void:
	# Keep inherited teardown/resource cleanup, but never persist fixture settings.
	preference_overrides_are_transient = true


func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	pass


func _input(_event: InputEvent) -> void:
	pass


func _notification(_what: int) -> void:
	pass


func configure_fixture(render: bool = false) -> bool:
	ability_catalog = AbilityCatalog.new()
	champion_catalog = ChampionCatalog.new()
	campus_layout = SanctumCampusLayout.new()
	if not ability_catalog.load_from_file(ABILITY_CATALOG_PATH) or not champion_catalog.load_from_file(CHAMPION_CATALOG_PATH, ability_catalog) or not campus_layout.load_from_file(CAMPUS_LAYOUT_PATH):
		return false
	var group: Dictionary = campus_layout.practice_groups_by_id["crucible-experiment"]
	var authored: Array = group.firing_anchors[0]
	fixture_anchor = Vector2i(int(authored[0]), int(authored[1])) * SimConfig.FIXED_SCALE
	fixture_target = fixture_anchor + Vector2i(0, -100000)
	world = SimWorld.new(120, 909, campus_layout.build_collision_world())
	var actor := world.player()
	if not champion_catalog.apply_to_player(actor, "oh_tipi"):
		return false
	actor.position_x = fixture_anchor.x
	actor.position_y = fixture_anchor.y
	actor.aim_x = 0
	actor.aim_y = -1000
	actor.flux_recovery_per_second = 0
	actor.health_recovery_per_second = 0
	actor.spawn_protection_ticks = 0
	if not actor.place_proven_spell(0, 145) or not actor.place_proven_spell(1, 140):
		return false
	previous_position = Vector2(fixture_anchor) / 1000.0
	current_position = previous_position
	previous_air_height = 0
	session_transport = SessionTransport.new()
	authoritative_session = AuthoritativeSession.new()
	authoritative_session.world = world
	session_round_values = authoritative_session.session_round.capture(world)
	spectator_focus = SpectatorFocus.new()
	controls_editor = ControlBindingEditor.new()
	spell_loom_editor = SpellLoomEditor.new()
	player_compendium = PlayerCompendiumScript.new()
	character_selection_grid = CharacterSelectionGridScript.new()
	player_preferences = PlayerPreferences.new()
	player_preferences.set_camera_zoom_percent(100)
	if not render:
		return world.is_valid()
	input_router = InputRouter.new(1)
	visual_language = VisualLanguage.new()
	campus_renderer = SanctumCampusRenderer.new()
	foundation_spell_presenter = FoundationSpellPresenter.new()
	burst_projectile_presenter = BurstProjectilePresenter.new()
	element_chemistry_presenter = ElementChemistryPresenter.new()
	cartoon_champion_presenter = CartoonChampionPresenter.new()
	compact_hud = CompactCombatHud.new()
	if not visual_language.load_from_file() or not campus_renderer.configure(visual_language) or not campus_renderer.configure_campus(campus_layout):
		return false
	if not foundation_spell_presenter.configure(visual_language, ability_catalog) or not burst_projectile_presenter.configure(visual_language, ability_catalog) or not element_chemistry_presenter.configure(visual_language):
		return false
	if not hex_court_presenter.configure(visual_language):
		return false
	if not cartoon_champion_presenter.configure(visual_language) or not compact_hud.configure(visual_language):
		return false
	_configure_pov_terrain_backdrop()
	compact_hud.champion_art = cartoon_champion_presenter
	return cartoon_champion_presenter.prepare_override_pages(["oh_tipi"])


func paid_cast(slot: int, actor_id: int = 1) -> bool:
	var actor := world.player(actor_id)
	var wire_id := actor.spell_wire_id(slot)
	var cost := int(CombatTuning.cast_definition(wire_id).get("flux_cost", 0))
	var before := actor.flux
	var command := SimCommand.new(world.tick, actor_id, 0, 0, 0, SimCommand.SPELL_PRESSED_BITS[slot - 1], 0, -1000, fixture_target.x, fixture_target.y)
	if cost <= 0 or not world.step([command]) or actor.flux != before - cost or actor.pending_cast_wire_id != wire_id:
		return false
	paid_casts += 1
	return true


func advance_until(kind: String, maximum_ticks: int = 480) -> bool:
	for unused: int in range(maximum_ticks):
		var view := _chemistry_practice_view()
		if kind == "terminal" and String(view.get("kind", "")) == "matter":
			for deposit: ElementDepositState in world.deposits:
				if deposit.entity_id == int(view.get("entity_id", 0)) and not deposit.is_trail():
					return true
		if String(view.get("kind", "")) == kind:
			return true
		if not world.step([]):
			return false
	return false


func advance_to(tick: int) -> bool:
	while world.tick < tick:
		if not world.step([]):
			return false
	return true
