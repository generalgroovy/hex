extends FluxTestSuite

const Loom = preload("res://src/presentation/spell_loom_presenter.gd")
const Stations = preload("res://src/presentation/wellspring_interaction_presenter.gd")
const Steam = preload("res://src/presentation/hex_court_presenter.gd")


func run() -> int:
	_test_slot_availability()
	_test_effective_slot_labels()
	_test_station_labels()
	_test_source_bounded_steam_marks()
	return finish("hex-handoff-presentation")


func _test_effective_slot_labels() -> void:
	var preferences := PlayerPreferences.new()
	preferences.keyboard_bindings[&"spell_1"] = KEY_Q
	preferences.keyboard_bindings[&"spell_2"] = KEY_W
	preferences.keyboard_bindings[&"spell_3"] = KEY_E
	preferences.keyboard_bindings[&"spell_4"] = KEY_R
	preferences.keyboard_bindings[&"spell_layer_ctrl"] = KEY_SHIFT
	preferences.keyboard_bindings[&"spell_layer_alt"] = KEY_ALT
	var before := preferences.keyboard_bindings.duplicate()
	var keys := ["Q", "W", "E", "R"]
	for index: int in range(12):
		var prefix := "" if index < 4 else "Shift+" if index < 8 else "Alt+"
		equal(Loom.slot_binding_label(index, preferences), prefix + keys[index % 4], "all twelve slots resolve current keyboard settings")
	equal(preferences.keyboard_bindings, before, "viewing bindings does not rewrite player settings")
	preferences.keyboard_bindings[&"spell_1"] = KEY_T
	for index: int in [0, 4, 8]:
		check(Loom.slot_binding_label(index, preferences).ends_with("T"), "one key rebind propagates across its three layers")
	preferences.keyboard_bindings[&"spell_layer_ctrl"] = 0
	equal(Loom.slot_binding_label(4, preferences), "Not bound", "unbound modifier cannot advertise a usable layered chord")
	equal(Loom.slot_binding_label(0, preferences), "T", "unbound modifier does not hide plain slot binding")
	preferences.keyboard_bindings[&"spell_1"] = 0
	for index: int in [0, 4, 8]:
		equal(Loom.slot_binding_label(index, preferences), "Not bound", "unbound spell button stays unbound in each layer")
	equal(Loom.slot_binding_label(0, null), "Binding unavailable", "missing settings differ from confirmed unbound")
	equal(Loom.slot_binding_label(-1, preferences), "Invalid slot", "invalid slot cannot alias a real binding")
	equal(Loom.slot_binding_label(12, preferences), "Invalid slot", "out of range slot is rejected")


func _test_station_labels() -> void:
	equal(Stations.resolved_interact_label(""), "Not bound", "empty station input never fabricates F")
	equal(Stations.resolved_interact_label("\u2014"), "Not bound", "confirmed unbound sentinel remains explicit")
	equal(Stations.resolved_interact_label("  Mouse 4  "), "Mouse 4", "supplied effective station label is retained")
	equal(Stations.resolved_interact_label("UNBOUND"), "UNBOUND", "root supplied unbound state remains explicit")


func _test_source_bounded_steam_marks() -> void:
	# Use the same convex complete-hex shape required by the source region adapter.
	var polygon := PackedVector2Array([Vector2(24, 0), Vector2(12, 21), Vector2(-12, 21), Vector2(-24, 0), Vector2(-12, -21), Vector2(12, -21)])
	var before := polygon.duplicate()
	var active := Steam.steam_vent_marks(polygon, true, "active")
	var terminal := Steam.steam_vent_marks(polygon, true, "decaying")
	equal(active.size(), 2, "dangerous Steam keeps paired hot vent bases")
	equal(terminal.size(), 3, "source decay adds a terminal bracket without removing hot bases")
	equal(Steam.steam_vent_marks(polygon, false, "active").size(), 0, "harmless source does not gain hot vent bases")
	equal(Steam.steam_vent_marks(polygon, false, "decaying").size(), 1, "harmless decay retains terminal shape without danger bases")
	equal(Steam.steam_vent_marks(PackedVector2Array(), true, "active").size(), 0, "removed occupancy produces no ghost geometry")
	for mark: PackedVector2Array in terminal:
		for index: int in range(mark.size()):
			check(Geometry2D.is_point_in_polygon(mark[index], polygon), "Steam mark points stay inside supplied whole hex")
			if index > 0:
				check(Geometry2D.is_point_in_polygon(mark[index - 1].lerp(mark[index], 0.5), polygon), "Steam mark segments stay inside supplied whole hex")
	equal(polygon, before, "Steam marks never mutate authoritative coverage")


func _test_slot_availability() -> void:
	equal(Loom.slot_display_name(0, {}), "Empty", "zero wire is an actually empty slot")
	equal(Loom.slot_display_name(176, {}), "Unavailable spell #176", "missing positive wire stays visible as unavailable identity")
	equal(Loom.slot_display_name(176, {"display_name": ""}), "Unavailable spell #176", "missing display name does not become empty")
	var playable := {"display_name": "Water Bolt", "runtime_status": "playable", "material_runtime_enabled": false}
	var before := playable.duplicate(true)
	equal(Loom.slot_display_name(176, playable), "Water Bolt", "material-operation gate does not disable playable spell")
	equal(playable, before, "slot display does not rewrite catalog availability")
	equal(Loom.slot_display_name(176, {"display_name": "Water Bolt", "runtime_status": "catalog_only"}), "Water Bolt (unavailable #176)", "catalog-only entry carries an explicit unavailable identity")
