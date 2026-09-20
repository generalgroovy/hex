extends FluxTestSuite


func run() -> int:
	_test_repository_catalog()
	_test_catalog_lookups()
	_test_status_boundaries()
	_test_archive_subset_boundary()
	_test_invalid_catalog_fails_closed()
	return finish("complete-visual-catalog")


func _test_repository_catalog() -> void:
	var catalog := CompleteVisualCatalog.new()
	check(catalog.load_from_file(), "complete visual catalog validates: %s" % catalog.last_error)
	equal(catalog.ancestries.size(), 23, "all ancestry/body-plan slots are registered")
	equal((catalog.data["champions"] as Dictionary).size(), 24, "the raw historical archive retains its twenty-four champion visual slots")
	equal(catalog.champions.size(), 23, "the canonical index excludes only the retired placeholder from the historical archive")
	equal(catalog.districts.size(), 9, "all Sanctum district visual packages are registered")
	equal((catalog.props.get("order", []) as Array).size(), 16, "all typed prop families are registered")
	equal((catalog.props.get("states", []) as Array).size(), 8, "all interaction presentation states are registered")
	equal((catalog.element_vfx.get("elements", []) as Array).size(), 8, "all enabled element VFX families are registered")
	equal((catalog.element_vfx.get("phases", []) as Array).size(), 6, "all element presentation phases are registered")


func _test_catalog_lookups() -> void:
	var catalog := CompleteVisualCatalog.new()
	check(catalog.load_from_file(), "catalog loads for lookup tests")
	check(not catalog.champion("oh_tipi").is_empty(), "Oh Tipi visual definition resolves")
	equal(catalog.champion("nico_lai").get("display_name"), "Waka Aren Si", "compatibility asset resolves the canonical name")
	equal(catalog.champion("oll_i").get("ancestry"), "werewolf", "current roster identity overrides archive metadata")
	equal(catalog.champion("red_baron").get("body_type"), "large", "Red Baron has the canonical large role")
	equal(catalog.champion("steezo").get("availability"), "playable", "current playable availability derives from canonical promotion, not archived art")
	equal(catalog.champion("steezo").get("asset_authority"), "legacy_visual_archive", "metadata migration never certifies old pixels as current art")
	check(not catalog.ancestry("weaverkin").is_empty(), "provisional Weaverkin body plan resolves")
	check(not catalog.district("movement_conservatory").is_empty(), "Movement Conservatory visual package resolves")
	check(catalog.champion("missing").is_empty(), "unknown champion fails closed")


func _test_status_boundaries() -> void:
	var catalog := CompleteVisualCatalog.new()
	check(catalog.load_from_file(), "catalog loads for status tests")
	var archived_angel: Dictionary = (catalog.data["champions"] as Dictionary).get("unnamed_angel", {})
	equal(str(archived_angel.get("status", "")), "placeholder_unapproved", "retired Angel artwork retains its historical unapproved status")
	check(FileAccess.file_exists(str(archived_angel.get("atlas", ""))), "retired Angel atlas remains on disk")
	check(FileAccess.file_exists(str(archived_angel.get("portrait", ""))), "retired Angel portrait remains on disk")
	check(catalog.champion("unnamed_angel").is_empty(), "retired Angel has no canonical visual entry")
	check(catalog.roster_plan.entry("unnamed_angel").is_empty(), "retired Angel is absent from the current champion roster")
	equal(str(catalog.ancestry("weaverkin").get("status", "")), "body_plan_candidate", "Weaverkin remains provisional")
	equal(str(catalog.ancestry("scorpionkin").get("status", "")), "body_plan_candidate", "Scorpionkin remains provisional")
	equal(str(catalog.ancestry("harvestkin").get("status", "")), "body_plan_candidate", "Harvestkin remains provisional")
	for district_id: String in catalog.districts:
		equal(str(catalog.district(district_id).get("status", "")), "presentation_only", "%s cannot claim map authority" % district_id)


func _test_invalid_catalog_fails_closed() -> void:
	var catalog := CompleteVisualCatalog.new()
	catalog.data = {
		"schema_version": 1,
		"character_contract": {"cell_size": [32, 32], "pivot": [16, 28], "directions": [], "animations": []},
		"ancestries": {},
		"champions": {},
		"districts": {},
	}
	check(not catalog.validate(), "incomplete visual catalog fails closed")
	check(not catalog.last_error.is_empty(), "complete catalog failure is diagnosable")


func _test_archive_subset_boundary() -> void:
	var catalog := CompleteVisualCatalog.new()
	check(catalog.load_from_file(), "historical complete archive accepts an expanded canonical roster")
	for champion_id: String in ["luuh_i_zeh", "juul_i_yaina", "faab_i_yaina", "joh_haynes", "sai_laas"]:
		check(not catalog.roster_plan.entry(champion_id).is_empty(), "new identity exists canonically: " + champion_id)
		check(catalog.champion(champion_id).is_empty(), "new identity receives no fabricated archive art: " + champion_id)
	for champion_id: String in catalog.champions:
		var entry := catalog.champion(champion_id)
		equal(entry["asset_authority"], "legacy_visual_archive", "runtime promotion cannot certify archived pixels: " + champion_id)
		equal(entry["availability"], catalog.roster_plan.entry(champion_id)["availability"], "availability remains source-derived: " + champion_id)
	var archive: Dictionary = (catalog.data["champions"] as Dictionary).duplicate(true)
	var original: Dictionary = archive["steezo"]
	archive.erase("steezo")
	archive["unknown_archive_identity"] = original
	catalog.data["champions"] = archive
	check(not catalog.validate(), "unknown archived identity fails even while historical package count stays 24")
	check(catalog.last_error.contains("unknown canonical champion ID"), "archive identity refusal is actionable")
	check(catalog.champions.is_empty(), "failed projection cannot expose a partially canonicalized archive")
