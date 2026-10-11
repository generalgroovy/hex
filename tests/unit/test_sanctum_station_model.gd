extends FluxTestSuite


const CAMPUS_PATH: String = "res://content/maps/sanctum_campus_g2_v1.json"


func run() -> int:
	_test_repository_stations()
	_test_requested_group_actions()
	_test_range_and_tie_breaking()
	_test_invalid_station_entries_are_ignored()
	return finish("sanctum-station-model")


func _test_repository_stations() -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file(CAMPUS_PATH), "campus loads for station focus")
	equal(layout.stations_by_id.size(), 12, "walk-up slice exposes movement practice, controls, spells, Farflow and host-stewardship stations")
	var group_focus := {"training": "controls-lectern", "practice": "momentum-chime", "academy": "champion-loom", "farflow": "company-ledger"}
	for station_id: String in layout.stations_by_id:
		var station: Dictionary = layout.stations_by_id[station_id]
		var anchor := SanctumCampusLayout._parse_point(station["position"]) * SimConfig.FIXED_SCALE
		equal(SanctumStationModel.nearest_station_id(layout.stations_by_id, anchor), group_focus[String(station["service_group"])], "colocated building focus has one stable lexical identity, not twelve ambiguous doors")
		check(SanctumStationModel.station_in_reach(layout.stations_by_id, station_id, anchor), "every actual action remains independently reachable at its group's door")
	equal(
		SanctumStationModel.nearest_station_id(layout.stations_by_id, layout.spawn * SimConfig.FIXED_SCALE),
		"",
		"current authored spawn begins free of an automatic station focus",
	)


func _test_requested_group_actions() -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file(CAMPUS_PATH), "grouped service action checks load canonical entrances")
	var before := CanonicalContent.sha256(layout.data)
	var collision := layout.build_collision_world()
	for station_id: String in layout.stations_by_id:
		var station: Dictionary = layout.stations_by_id[station_id]
		var anchor := SanctumCampusLayout._parse_point(station["position"]) * SimConfig.FIXED_SCALE
		# Lodge's retained practice wall makes its immediate front lane shallower.
		var front_offset := 16000 if int(station["building_id"]) == 101 else 32000
		for offset: Vector2i in [Vector2i.ZERO, Vector2i(0, front_offset), Vector2i(-36000, 0), Vector2i(36000, 0)]:
			check(collision.can_occupy(anchor + offset, MovementTuning.PLAYER_RADIUS), "group action front approach is outside its physical building")
			check(SanctumStationModel.station_in_reach(layout.stations_by_id, station_id, anchor + offset), "all colocated group actions remain available from four legal front approaches")
		var radius := int(station["interaction_radius"]) * SimConfig.FIXED_SCALE
		check(SanctumStationModel.station_in_reach(layout.stations_by_id, station_id, anchor + Vector2i(0, radius)), "requested action admits its exact own distance boundary")
		check(not SanctumStationModel.station_in_reach(layout.stations_by_id, station_id, anchor + Vector2i(0, radius + 1)), "requested action rejects one unit outside its own radius")
		check(not SanctumStationModel.station_in_reach(layout.stations_by_id, station_id, anchor - Vector2i(0, 17000)), "grouped building rejects rear-door requests even within radial distance")
		for other_id: String in layout.stations_by_id:
			if String(layout.stations_by_id[other_id]["service_group"]) != String(station["service_group"]):
				check(not SanctumStationModel.station_in_reach(layout.stations_by_id, other_id, anchor), "standing at one building cannot authorize another group's action")
	var practice := SanctumCampusLayout._parse_point(layout.stations_by_id["momentum-chime"]["position"]) * SimConfig.FIXED_SCALE
	check(SanctumStationModel.station_in_reach(layout.stations_by_id, "training-reset", practice + Vector2i(0, 80000)), "Restore retains its own longer 96 px reach at the shared practice entrance")
	check(not SanctumStationModel.station_in_reach(layout.stations_by_id, "momentum-chime", practice + Vector2i(0, 80000)), "Restore's 96 px radius cannot extend Momentum's 72 px admission")
	equal(CanonicalContent.sha256(layout.data), before, "focus/range checks do not modify canonical service definitions")


func _test_range_and_tie_breaking() -> void:
	var stations := {
		"zeta": {"position": [20, 0], "interaction_radius": 30},
		"alpha": {"position": [-20, 0], "interaction_radius": 30},
	}
	equal(
		SanctumStationModel.nearest_station_id(stations, Vector2i.ZERO),
		"alpha",
		"equal-distance focus uses stable lexical station identity",
	)
	equal(
		SanctumStationModel.nearest_station_id(stations, Vector2i(49_999, 0)),
		"zeta",
		"closer in-range station wins before lexical order",
	)
	equal(
		SanctumStationModel.nearest_station_id(stations, Vector2i(50_001, 0)),
		"",
		"focus ends immediately outside every authored radius",
	)


func _test_invalid_station_entries_are_ignored() -> void:
	var stations := {
		"missing-position": {"interaction_radius": 100},
		"wrong-position-type": {"position": "0,0", "interaction_radius": 100},
		"zero-radius": {"position": [0, 0], "interaction_radius": 0},
	}
	equal(
		SanctumStationModel.nearest_station_id(stations, Vector2i.ZERO),
		"",
		"malformed runtime station data fails closed",
	)
	for station_id: String in stations:
		check(not SanctumStationModel.station_in_reach(stations, station_id, Vector2i.ZERO), "requested-action helper also rejects malformed station data")
	check(not SanctumStationModel.station_in_reach(stations, "missing-id", Vector2i.ZERO), "requested-action helper rejects unknown station identity")
