extends FluxTestSuite

const Sources = preload("res://addons/pixel_assets_export/atlas_source_contract.gd")


func run() -> int:
	var export_config := ConfigFile.new()
	equal(export_config.load("res://export_presets.cfg"), OK, "export configuration is inspectable")
	for section: String in export_config.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		var excluded := String(export_config.get_value(section, "exclude_filter", ""))
		for workbench: String in ["art_batches/character_motion_v1/*","art_batches/character_cast_v1/*","art_batches/character_volume_v1/*"]:
			check(workbench in excluded.split(","), "character workbench stays outside portable: " + workbench)
		check("assets/sprites/fullbody_cast_v1/*.json" in String(export_config.get_value(section,"include_filter","")).split(","), "compact art metadata is explicitly exported")
		for draft: String in ["art_batches/character_style_v1/*", "content/champions/full_cast_candidate_v1.json", "scripts/build_character_style_pack.gd", "scripts/test_character_style_pack.gd", "scripts/capture_character_style_sources.gd"]:
			check(draft in excluded.split(","), "character production drafts never become release assets: " + draft)
	var result := Sources.collect_sources()
	equal(result.error, "", "all eight reviewed source atlases are available to the exporter")
	equal(result.files.size(), 8, "export hook adds only eight live raw atlas files")
	equal(result.total_bytes, Sources.TOTAL_BYTES, "accepted eight-atlas raw payload stays bounded to138230 bytes after Frostway floor revision")
	var seen: Dictionary = {}
	for index: int in range(Sources.SOURCES.size()):
		var source: Dictionary = Sources.SOURCES[index]
		var path: String = source.path
		check(not seen.has(path), "each export virtual path is unique")
		seen[path] = true
		check(((path.begins_with("res://art_batches/pixel_v1/") and path.contains("/export/")) or path == "res://art_batches/wellspring_style_v2/runtime/terrain.png") and path.ends_with(".png") and not path.contains(".."), "allowlist excludes source documents and path escapes")
		var bytes := FileAccess.get_file_as_bytes(path)
		check(Sources.validate_bytes(index, bytes), "exported bytes have pinned source size and SHA256")
		var changed := bytes.duplicate()
		changed[changed.size() - 1] ^= 1
		check(not Sources.validate_bytes(index, changed), "same-size mutation cannot pass export validation")
		changed = bytes.slice(0, bytes.size() - 1)
		check(not Sources.validate_bytes(index, changed), "truncated atlas cannot pass export validation")
		check(not Sources.validate_bytes(index, PackedByteArray()), "missing atlas cannot pass export validation")
	check(not Sources.validate_bytes(-1, PackedByteArray()), "negative source index is rejected")
	check(not Sources.validate_bytes(8, PackedByteArray()), "unknown source index is rejected")
	var missing := Sources.collect_sources(func(_path: String) -> PackedByteArray: return PackedByteArray())
	check(not String(missing.error).is_empty(), "missing source is reported clearly")
	equal(missing.files.size(), 0, "missing first source never produces a partial export list")
	var last_path: String = Sources.SOURCES[7].path
	var partial := Sources.collect_sources(func(path: String) -> PackedByteArray:
		return PackedByteArray() if path == last_path else FileAccess.get_file_as_bytes(path)
	)
	check(not String(partial.error).is_empty(), "missing last source fails after validating preceding files")
	equal(partial.files.size(), 0, "late failure discards the complete pending export list")
	equal(partial.total_bytes, 0, "late failure cannot report a usable partial byte count")
	var steam_page: String = Sources.SOURCES[1].path
	var altered_steam := Sources.collect_sources(func(path: String) -> PackedByteArray:
		var bytes := FileAccess.get_file_as_bytes(path)
		if path == steam_page:
			bytes[bytes.size() - 1] ^= 1
		return bytes
	)
	check(String(altered_steam.error).contains(steam_page), "same-size changed Steam atlas names the exact refused source")
	equal(altered_steam.files.size(), 0, "changed Steam atlas discards all earlier pending raw files")
	equal(altered_steam.total_bytes, 0, "changed Steam atlas cannot publish a partial payload")
	return finish("pixel-assets-export")
