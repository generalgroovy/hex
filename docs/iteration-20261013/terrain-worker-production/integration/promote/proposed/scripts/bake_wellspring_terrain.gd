extends SceneTree

# Run as an explicit asset-preparation job, before release/import qualification:
# godot --headless --path <checkout> --script res://scripts/bake_wellspring_terrain.gd
# Lossless compressed Image resources need no texture importer and are included
# by the existing all_resources export filter. Manifest is published last.
const Stream = preload("res://src/presentation/wellspring_terrain_stream.gd")
const AsyncStream = preload("res://src/presentation/wellspring_async_terrain_stream.gd")
const Manifest = preload("res://src/presentation/wellspring_terrain_manifest.gd")


func _initialize() -> void:
	call_deferred("_bake")


func _bake() -> void:
	var layout := SanctumCampusLayout.new()
	if not layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"):
		_abort(layout.last_error)
		return
	var kit := WellspringIllustratedKit.new()
	if not kit.configure(layout, WellspringIllustratedKit.PATH, false):
		_abort(kit.last_error)
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Stream.ROOT)) != OK:
		_abort("Cannot create prepared terrain directory")
		return
	var size := Vector2i(ceili(float(layout.canvas_size.x) / 4), ceili(float(layout.canvas_size.y) / 4))
	var overview := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var rows: Array[Dictionary] = []
	var started := Time.get_ticks_msec()
	for id: Vector2i in kit.ground_chunk_ids(Rect2(Vector2.ZERO, Vector2(layout.canvas_size))):
		var rect := kit.ground_chunk_rect(id)
		var sampler := kit.ground_region_sampler(rect)
		var image: Image = kit.hex_terrain.compose_region(rect, sampler.material_at, kit.ground_style, sampler.finish_at, kit.ground_surface_sources())
		if image == null:
			_abort(kit.hex_terrain.last_error)
			return
		var path := Stream.ROOT + "/chunk_%02d_%02d.res" % [id.x, id.y]
		if ResourceSaver.save(image, path, ResourceSaver.FLAG_COMPRESS) != OK:
			_abort("Could not write " + path)
			return
		rows.append({"id": [id.x, id.y], "size": [rect.size.x, rect.size.y], "path": path, "rgba_sha256": Stream.pixel_hash(image)})
		image.resize(ceili(float(rect.size.x) / 4), ceili(float(rect.size.y) / 4), Image.INTERPOLATE_NEAREST)
		overview.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), rect.position / 4)
		# Give explicit offline preparation a progress receipt, never a gameplay frame.
		if rows.size() % 12 == 0: print("TERRAIN_BAKE %d/132" % rows.size())
	var overview_path := Stream.ROOT + "/overview.res"
	if ResourceSaver.save(overview, overview_path, ResourceSaver.FLAG_COMPRESS) != OK:
		_abort("Could not save overview")
		return
	var manifest := Manifest.new()
	manifest.descriptor = {"version": Stream.VERSION, "signature": kit.bake_signature, "canvas": [layout.canvas_size.x, layout.canvas_size.y], "chunk_size": Stream.CHUNK, "chunks": rows, "overview": {"size": [size.x, size.y], "path": overview_path, "rgba_sha256": Stream.pixel_hash(overview)}}
	var provenance := {}
	for source_path: String in Stream.BAKE_SOURCE_PATHS + AsyncStream.VALIDATION_SOURCE_PATHS:
		if not FileAccess.file_exists(source_path):
			_abort("Missing bake source: " + source_path)
			return
		provenance[source_path] = FileAccess.get_sha256(source_path)
	manifest.descriptor["source_sha256"] = provenance
	var check := Stream.new()
	if not check.configure(manifest.descriptor, kit.bake_signature, layout.canvas_size):
		_abort(check.last_error)
		return
	if ResourceSaver.save(manifest, Stream.MANIFEST) != OK:
		_abort("Could not publish prepared manifest")
		return
	print("TERRAIN_BAKE_COMPLETE " + JSON.stringify({"chunks": rows.size(), "native_rgba_bytes": layout.canvas_size.x * layout.canvas_size.y * 4, "overview_size": [size.x, size.y], "signature": kit.bake_signature, "elapsed_ms": Time.get_ticks_msec() - started}))
	quit(0)


func _abort(message: String) -> void:
	printerr("TERRAIN_BAKE_FAILED: " + message)
	quit(1)
