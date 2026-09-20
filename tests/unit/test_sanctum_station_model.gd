extends FluxTestSuite


const CAMPUS_PATH: String = "res://content/maps/sanctum_campus_g2_v1.json"


func run() -> int:
	_test_repository_stations()
	_test_range_and_tie_breaking()
	_test_invalid_station_entries_are_ignored()
	return finish("sanctum-station-model")


func _test_repository_stations() -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file(CAMPUS_PATH), "campus loads for station focus")
	equal(layout.stations_by_id.size(), 12, "walk-up slice exposes movement practice, controls, spells, Farflow and host-stewardship stations")
	equal(
		SanctumStationModel.nearest_station_id(layout.stations_by_id, SanctumCampusLayout._parse_point(layout.stations_by_id["movement-guide"]["position"]) * SimConfig.FIXED_SCALE),
		"movement-guide",
		"movement guide focuses at its world anchor",
	)
	equal(
		SanctumStationModel.nearest_station_id(layout.stations_by_id, SanctumCampusLayout._parse_point(layout.stations_by_id["controls-lectern"]["position"]) * SimConfig.FIXED_SCALE),
		"controls-lectern",
		"Controls Lectern focuses at its world anchor",
	)
	equal(
		SanctumStationModel.nearest_station_id(layout.stations_by_id, SanctumCampusLayout._parse_point(layout.stations_by_id["training-reset"]["position"]) * SimConfig.FIXED_SCALE),
		"training-reset",
		"practice bell focuses at its world anchor",
	)
	equal(
		SanctumStationModel.nearest_station_id(layout.stations_by_id, SanctumCampusLayout._parse_point(layout.stations_by_id["momentum-chime"]["position"]) * SimConfig.FIXED_SCALE),
		"momentum-chime",
		"Momentum Chime focuses at its collision-cleared Conservatory anchor",
	)
	equal(
		SanctumStationModel.nearest_station_id(layout.stations_by_id, SanctumCampusLayout._parse_point(layout.stations_by_id["champion-loom"]["position"]) * SimConfig.FIXED_SCALE),
		"champion-loom",
		"champion loom focuses at its world anchor",
	)
	equal(
		SanctumStationModel.nearest_station_id(layout.stations_by_id, SanctumCampusLayout._parse_point(layout.stations_by_id["spell-loom"]["position"]) * SimConfig.FIXED_SCALE),
		"spell-loom",
		"Spell Loom focuses at its world anchor",
	)
	equal(
		SanctumStationModel.nearest_station_id(layout.stations_by_id, SanctumCampusLayout._parse_point(layout.stations_by_id["farflow-host"]["position"]) * SimConfig.FIXED_SCALE),
		"farflow-host",
		"Farflow host focuses at its world anchor",
	)
	equal(
		SanctumStationModel.nearest_station_id(layout.stations_by_id, SanctumCampusLayout._parse_point(layout.stations_by_id["farflow-join"]["position"]) * SimConfig.FIXED_SCALE),
		"farflow-join",
		"Farflow join focuses at its world anchor",
	)
	equal(
		SanctumStationModel.nearest_station_id(layout.stations_by_id, SanctumCampusLayout._parse_point(layout.stations_by_id["farflow-charter"]["position"]) * SimConfig.FIXED_SCALE),
		"farflow-charter",
		"Farflow Charter focuses at its world anchor",
	)
	equal(
		SanctumStationModel.nearest_station_id(layout.stations_by_id, SanctumCampusLayout._parse_point(layout.stations_by_id["session-hearth"]["position"]) * SimConfig.FIXED_SCALE),
		"session-hearth",
		"Session Hearth focuses at its world anchor",
	)
	equal(
		SanctumStationModel.nearest_station_id(layout.stations_by_id, SanctumCampusLayout._parse_point(layout.stations_by_id["company-ledger"]["position"]) * SimConfig.FIXED_SCALE),
		"company-ledger",
		"Company Ledger focuses at its world anchor",
	)
	equal(
		SanctumStationModel.nearest_station_id(layout.stations_by_id, SanctumCampusLayout._parse_point(layout.stations_by_id["parting-bell"]["position"]) * SimConfig.FIXED_SCALE),
		"parting-bell",
		"Parting Bell focuses at its world anchor",
	)
	equal(
		SanctumStationModel.nearest_station_id(layout.stations_by_id, layout.spawn * SimConfig.FIXED_SCALE),
		"",
		"current authored spawn begins free of an automatic station focus",
	)


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
