extends FluxTestSuite


func run() -> int:
	_test_repository_catalog()
	_test_race_matrix()
	_test_champion_packages()
	_test_wellspring_identity_and_districts()
	_test_support_catalogs()
	_test_archive_subset_boundary()
	_test_invalid_catalog_fails_closed()
	return finish("wellspring-visual-catalog")


func _test_repository_catalog() -> void:
	var catalog := WellspringVisualCatalog.new()
	check(catalog.load_from_file(), "Wellspring visual catalog validates: %s" % catalog.last_error)
	equal(WellspringVisualCatalog.CANONICAL_BODY_TYPES, ["small", "middle", "large"], "legacy catalog exposes exactly three canonical body types")
	equal(WellspringVisualCatalog.canonical_body_type("size_1_tiny"), "small", "tiny legacy path migrates to small")
	equal(WellspringVisualCatalog.canonical_body_type("size_3_medium"), "middle", "medium legacy path migrates to middle")
	equal(WellspringVisualCatalog.canonical_body_type("size_5_huge"), "large", "huge legacy path migrates to large")
	equal(catalog.races.size(), 21, "the historical archive retains its twenty-one race foundations")
	equal((catalog.data["champions"] as Dictionary).size(), 24, "the raw historical archive retains its twenty-four champion packages")
	equal(catalog.champions.size(), 23, "the canonical index excludes only the retired placeholder from the historical archive")
	equal(catalog.districts.size(), 9, "all Wellspring district packages are registered")


func _test_race_matrix() -> void:
	var catalog := WellspringVisualCatalog.new()
	check(catalog.load_from_file(), "catalog loads for race matrix tests")
	for required_race: String in ["human", "dwarf", "gnome", "hobbit", "elf", "orc", "troll", "minotaur", "seakin", "wyrmborn", "stoneborn", "treefolk", "sylph", "undead", "goblin", "nymph", "arachnoid", "vampire", "demon", "angel", "werewolf"]:
		var race: Dictionary = catalog.race(required_race)
		check(not race.is_empty(), "%s race foundation resolves" % required_race)
		equal((race.get("supported_sizes", []) as Array).size(), 5, "%s exposes all five visual sizes" % required_race)
		equal((race.get("presentations", []) as Array).size(), 2, "%s exposes masculine and feminine foundations" % required_race)
		check(not (race.get("exemplar", {}) as Dictionary).is_empty(), "%s has a named complete exemplar" % required_race)
	var arachnoid: Dictionary = catalog.race("arachnoid")
	equal((arachnoid.get("subtypes", []) as Array).size(), 3, "Arachnoid retains three extensible subtype hooks")


func _test_champion_packages() -> void:
	var catalog := WellspringVisualCatalog.new()
	check(catalog.load_from_file(), "catalog loads for champion tests")
	for champion_id: String in catalog.champions:
		var champion: Dictionary = catalog.champion(champion_id)
		check(bool(champion.get("all_keyframes_included", false)), "%s includes every canonical keyframe" % champion_id)
		equal(int(champion.get("animation_count", 0)), 25, "%s includes all canonical animations" % champion_id)
		equal(int(champion.get("direction_count", 0)), 8, "%s includes all directions" % champion_id)
	check(catalog.champion("s_wayne").get("ancestry") == "hobbit", "S. Wayne uses the current Hobbit foundation")
	equal(str(catalog.champion("s_wayne").get("size", "")), "size_2_small", "S. Wayne uses the small Hobbit silhouette")
	equal(catalog.champion("oll_i").get("ancestry"), "werewolf", "Oll' I uses the canonical Werewolf identity")
	equal(catalog.champion("wa_bidi").get("ancestry"), "goblin", "Wa Bidi uses the canonical Goblin identity")
	equal(catalog.champion("spai_si").get("ancestry"), "demon", "Spai Si uses the canonical Demon identity")
	equal(catalog.champion("haara").get("ancestry"), "nymph", "Haara uses the canonical Nymph identity")
	equal(catalog.champion("hesus_christo").get("ancestry"), "elf", "Hesus Christo uses the canonical Elf identity")
	equal(catalog.champion("djonah_thaan").get("ancestry"), "vampire", "Djonah Thaan uses the canonical Vampire identity")
	equal(catalog.champion("nico_lai").get("display_name"), "Waka Aren Si", "compatibility ID uses the current display name")
	equal(catalog.champion("donnok").get("display_name"), "Don Doko Don", "Don Doko Don preserves the asset compatibility ID")
	equal(catalog.champion("s_wayne").get("body_type"), "small", "current authoring exposes a canonical body role")
	equal(catalog.champion("wa_bidi").get("archive_ancestry"), "sylph", "archived pixels retain their original provenance")
	equal(catalog.champion("wa_bidi").get("availability"), "playable", "validated goblin kit promotes Wa Bidi independently of archived sylph pixels")
	equal(catalog.champion("grimm_bow").get("availability"), "playable", "Grimm Bow is promoted by current gameplay data, not archive existence")
	equal(catalog.champion("grimm_bow").get("asset_authority"), "legacy_visual_archive", "Grimm Bow archive pixels remain explicitly non-authoritative")
	equal(catalog.champion("grimm_bow").get("elements"), ["earth", "water"], "reserved Chaos is not silently replaced by Dark")
	var archived_angel: Dictionary = (catalog.data["champions"] as Dictionary).get("unnamed_angel", {})
	equal(str(archived_angel.get("status", "")), "placeholder_unapproved", "retired Angel artwork retains its historical unapproved status")
	check(FileAccess.file_exists(str(archived_angel.get("atlas", ""))), "retired Angel atlas remains on disk")
	check(FileAccess.file_exists(str(archived_angel.get("hero_portrait", ""))), "retired Angel hero portrait remains on disk")
	check(catalog.champion("unnamed_angel").is_empty(), "retired Angel has no canonical visual entry")
	check(catalog.roster_plan.entry("unnamed_angel").is_empty(), "retired Angel is absent from the current champion roster")


func _test_wellspring_identity_and_districts() -> void:
	var catalog := WellspringVisualCatalog.new()
	check(catalog.load_from_file(), "catalog loads for Wellspring tests")
	equal(str(catalog.wellspring.get("name", "")), "The Wellspring", "central hub uses the confirmed player-facing name")
	check((catalog.wellspring.get("legacy_aliases", []) as Array).has("sanctum"), "deprecated Sanctum alias remains loadable during migration")
	var source_court: Dictionary = catalog.district("source_court")
	check(not source_court.is_empty(), "Source Court resolves")
	equal(str(source_court.get("landmark", "")), "Cosmic Wellspring", "Source Court is built around the cosmic Flux source")
	for district_id: String in catalog.districts:
		equal(str(catalog.district(district_id).get("status", "")), "integrated_candidate", "%s is an integrated modular district candidate" % district_id)


func _test_support_catalogs() -> void:
	var catalog := WellspringVisualCatalog.new()
	check(catalog.load_from_file(), "catalog loads for support asset tests")
	equal((catalog.materials.get("materials", []) as Array).size(), 11, "all foundation materials are represented")
	equal((catalog.materials.get("states", []) as Array).size(), 12, "material presentation includes all required state families")
	equal((catalog.props.get("props", []) as Array).size(), 20, "all planned prop families are represented")
	equal((catalog.props.get("states", []) as Array).size(), 11, "all prop interaction states are represented")
	equal((catalog.element_vfx.get("elements", []) as Array).size(), 8, "all enabled elements are represented")
	equal((catalog.element_vfx.get("phases", []) as Array).size(), 8, "all VFX presentation phases are represented")
	equal((catalog.ui.get("surfaces", []) as Array).size(), 20, "all planned UI surfaces are represented")


func _test_invalid_catalog_fails_closed() -> void:
	var catalog := WellspringVisualCatalog.new()
	catalog.data = {
		"schema_version": 2,
		"id": "wellspring-visual-catalog-v2",
		"character_contract": {
			"cell_size": [64, 64],
			"pivot": [32, 56],
			"atlas_size": [1920, 2560],
			"directions": [],
			"animations": [],
		},
		"races": {},
		"champions": {},
		"wellspring": {"districts": {}},
	}
	check(not catalog.validate(), "incomplete Wellspring catalog fails closed")
	check(not catalog.last_error.is_empty(), "Wellspring catalog failure is diagnosable")


func _test_archive_subset_boundary() -> void:
	var catalog := WellspringVisualCatalog.new()
	check(catalog.load_from_file(), "historical Wellspring archive accepts an expanded canonical roster")
	for champion_id: String in ["luuh_i_zeh", "juul_i_yaina", "faab_i_yaina", "joh_haynes", "sai_laas"]:
		check(not catalog.roster_plan.entry(champion_id).is_empty(), "new identity exists canonically: " + champion_id)
		check(catalog.champion(champion_id).is_empty(), "new identity receives no fabricated archive package: " + champion_id)
	check(catalog.race("spiderkin").is_empty() and not catalog.race("arachnoid").is_empty(), "canonical Spiderkin does not rewrite historical Arachnoid archive art")
	for champion_id: String in catalog.champions:
		var entry := catalog.champion(champion_id)
		equal(entry["asset_authority"], "legacy_visual_archive", "runtime promotion cannot certify archived pixels: " + champion_id)
		equal(entry["availability"], catalog.roster_plan.entry(champion_id)["availability"], "availability remains source-derived: " + champion_id)
	var archive: Dictionary = (catalog.data["champions"] as Dictionary).duplicate(true)
	var original: Dictionary = archive["grimm_bow"]
	archive.erase("grimm_bow")
	archive["unknown_archive_identity"] = original
	catalog.data["champions"] = archive
	check(not catalog.validate(), "unknown archived identity fails even while historical package count stays 24")
	check(catalog.last_error.contains("unknown canonical champion ID"), "archive identity refusal is actionable")
	check(catalog.champions.is_empty(), "failed projection cannot expose a partially canonicalized archive")
