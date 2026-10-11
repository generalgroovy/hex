extends FluxTestSuite


func run() -> int:
	_test_existing_building_services()
	_test_purpose_first_labels()
	_test_card_layout_and_delay()
	return finish("wellspring-service-buildings")


func _test_existing_building_services() -> void:
	var campus := SanctumCampusLayout.new()
	check(campus.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "live campus loads")
	var original := CanonicalContent.sha256(campus.data)
	var service_buildings := {}
	var group_outlines := {}
	equal(WellspringServiceBuildings.DEFINITIONS.size(), 12, "all twelve existing commands have directory presentation")
	equal(WellspringServiceBuildings.GROUPS.size(), 4, "services share four existing campus buildings")
	for station: Dictionary in campus.stations_by_id.values():
		var definition := WellspringServiceBuildings.definition_for(station)
		check(not definition.is_empty(), "known command has a service card")
		var group := WellspringServiceBuildings.group_definition(WellspringServiceBuildings.group_for_station(station))
		check(campus.buildings_by_id.has(int(group["building_id"])), "directory belongs to a pre-existing campus building")
		var point := WellspringServiceBuildings.position_of(station)
		var threshold := WellspringServiceBuildings.door_threshold(station)
		var outline := WellspringServiceBuildings.door_outline(station)
		var building_id := int(group["building_id"])
		var building: Dictionary = campus.buildings_by_id[building_id]
		var bounds := Rect2(SanctumCampusLayout._parse_bounds(building["bounds"]))
		check(threshold.has_point(point) and Geometry2D.is_point_in_polygon(point, outline), "flat approach contains the unchanged actual interaction point")
		equal(threshold.size, Vector2(36, 27), "door approach has one small fixed pixel footprint")
		equal(Vector2(threshold.get_center().x, threshold.position.y), Vector2(bounds.get_center().x, bounds.end.y + 4), "paving starts exactly at the existing doorway foot")
		check(not threshold.grow(1).intersects(bounds), "even the outline stays outside the authoritative solid facade")
		equal(outline.size(), 6, "flat approach retains six-sided visual language without new architecture")
		equal(outline, WellspringServiceBuildings.door_outline(station), "approach geometry is deterministic without state or animation")
		equal(Geometry2D.triangulate_polygon(outline).size(), 12, "six-point paving is a simple filled polygon")
		for index: int in outline.size():
			var a := outline[index]
			var b := outline[(index + 1) % outline.size()]
			var c := outline[(index + 2) % outline.size()]
			check((b - a).cross(c - b) > 0.0, "every paving corner is convex, with no crossing or decorative notch")
		var group_id := WellspringServiceBuildings.group_for_station(station)
		if group_outlines.has(group_id):
			equal(outline, group_outlines[group_id], "commands sharing a building share exactly one approach")
		else:
			group_outlines[group_id] = outline
		service_buildings[building_id] = true
	equal(service_buildings.size(), 4, "twelve station aliases advertise only four real service entrances")
	var unmarked_doors := 0
	for building: Dictionary in campus.buildings_by_id.values():
		if String(building.get("style", "")) == "practice_wall": continue
		if service_buildings.has(int(building["id"])): continue
		unmarked_doors += 1
		check(WellspringServiceBuildings.group_for_station(building).is_empty(), "non-service architecture cannot advertise an entry through service drawing")
	equal(unmarked_doors, 4, "the four decorative doors do not gain false interaction markers")
	var commands: Array[Dictionary] = []
	for group: String in ["training", "academy", "farflow", "practice"]:
		commands.append_array(WellspringServiceBuildings.commands_for_group(group, campus.data["stations"]))
	equal(commands.size(), 12, "compact directories preserve all twelve actions exactly once")
	var seen := {}
	for command: Dictionary in commands:
		check(not seen.has(command["command"]), "grouped commands are unique")
		seen[command["command"]] = true
		var source: Dictionary = campus.stations_by_id[command["id"]]
		equal(command["authority"], source["authority"], "grouping does not change authority")
		equal(command["position"], source["position"], "grouping does not move an action")
	check(WellspringServiceBuildings.definition_for({"command": "invented_action"}).is_empty(), "unknown commands never advertise fake functionality")
	equal(WellspringServiceBuildings.commands_for_group("farflow", campus.data["stations"]).size(), 6, "all session choices share one deliberate six-card directory")
	equal(CanonicalContent.sha256(campus.data), original, "entry presentation cannot alter geometry, interaction radii, commands or authority")
	var script_source: String = String(WellspringServiceBuildings.new().get_script().source_code).replace("\r", "")
	var draw_source := script_source.get_slice("static func draw_service(", 1).get_slice("\n\nstatic func ", 0)
	check(draw_source.contains("group.is_empty()"), "service drawing still refuses buildings without a real service group")
	equal(draw_source.count("canvas.draw_colored_polygon("), 1, "approach uses the existing single fill draw")
	equal(draw_source.count("canvas.draw_polyline("), 1, "approach uses the existing single thin outline draw")
	for forbidden: String in ["for ", "while ", "Image.create", "ImageTexture.create", "draw_texture", "draw_circle"]:
		check(not draw_source.contains(forbidden), "approach draw adds no loops, textures, props or effects: " + forbidden)


func _test_purpose_first_labels() -> void:
	var campus := SanctumCampusLayout.new()
	check(campus.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "purpose labels use real service doors")
	var expected := {"training": "MOVEMENT + CONTROLS", "academy": "CHAMPIONS + SPELLS", "farflow": "FRIENDS + MATCHES", "practice": "RECOVER + PRACTICE"}
	for station: Dictionary in campus.stations_by_id.values():
		var group_id := WellspringServiceBuildings.group_for_station(station)
		var group := WellspringServiceBuildings.group_definition(group_id)
		equal(String(group["purpose"]), String(expected[group_id]), "each service door states its actual purpose first")
		var building: Dictionary = campus.buildings_by_id[int(group["building_id"])]
		equal(String(group["title"]), String(building["name"]).to_upper(), "second line retains the real building identity")
		var label := WellspringServiceBuildings.service_label_rect(station)
		check(SanctumCampusRenderer.station_visual_bounds(station).encloses(label), "both service label lines remain in conservative render bounds")
		equal(label.size.y, 31.0, "two service lines use a compact fixed label height")
		check(label.size.x <= 256.0, "purpose and identity fit one bounded compact directory label")
		check(not label.intersects(WellspringServiceBuildings.door_threshold(station)), "service text does not overlap the actual door approach")
		if group_id == "training":
			check(label.end.y < 368.0, "Lodge's two lines fit the real narrow lane before the practice wall")
		for field: String in ["purpose", "title"]:
			var font_size := 12 if field == "purpose" else 10
			check(ThemeDB.fallback_font.get_string_size(String(group[field]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= label.size.x - 16.0, "each full label fits its actual font without clipping")
	equal(WellspringServiceBuildings.service_label_rect({"command": "fake"}), Rect2(), "unknown services cannot create a building label")


func _test_card_layout_and_delay() -> void:
	for width: float in [360.0, 640.0, 960.0, 1200.0]:
		var area := Rect2(24, 40, width, 300)
		var cards := WellspringServiceBuildings.card_rectangles(area, 4)
		equal(cards.size(), 4, "all cards fit the supported panel")
		for index: int in range(cards.size()):
			check(area.encloses(cards[index]), "card remains inside its panel")
			equal(WellspringServiceBuildings.hit_card(cards[index].get_center(), cards), index, "pointer and rendered card share hit geometry")
			for other: int in range(index):
				check(not cards[index].intersects(cards[other]), "compact cards never overlap")
	equal(WellspringServiceBuildings.card_rectangles(Rect2(0, 0, 180, 60), 12).size(), 0, "too small viewport requires paging instead of clipped content")
	var hover := WellspringServiceBuildings.new()
	check(not hover.update_focus("spells", 0.10), "details wait on first hover")
	check(not hover.update_focus("spells", 0.10), "details do not flash while traversing")
	check(hover.update_focus("spells", 0.09), "details appear after short stable hover")
	check(not hover.update_focus("controls", 0.01), "another card restarts the delay")
	check(hover.update_focus("controls", 0.0, true), "keyboard/controller explicit focus can reveal details immediately")
	check(not hover.update_focus("", 1.0), "leaving cards clears details")
	equal(hover.focused_id, "", "cleared focus has no stale card")
	check(not hover.update_focus("spells", -1.0), "negative delta does not advance details")
