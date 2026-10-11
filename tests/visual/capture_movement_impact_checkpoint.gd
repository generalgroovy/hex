extends SceneTree
## Controlled production-renderer samples, not input, gameplay or feel acceptance.
## Root owns native execution/imports and an isolated APPDATA under .godot.

const SIZE := Vector2i(1280, 960)
const FAMILIES := ["rapid", "bolt", "heavy"]
const AGES := [0, 6, 48]
const MODES := ["normal", "reduced", "zero-budget"]
const MAX_PNG_BYTES := 40 * 1024 * 1024
const GroundSkid = preload("res://src/presentation/ground_skid_presentation.gd")
const Contact = preload("res://src/presentation/hex_contact_punctuation.gd")
const SOURCES := [
	"res://tests/visual/capture_movement_impact_checkpoint.gd",
	"res://src/presentation/pixel_spell_effects.gd",
	"res://src/presentation/pixel_magic_library.gd",
	"res://src/presentation/hex_contact_punctuation.gd",
	"res://src/presentation/hex_court_presenter.gd",
	"res://src/presentation/hex_projectile_facets.gd",
	"res://src/presentation/hex_magic_glow.gd",
	"res://src/presentation/projectile_presentation_motion.gd",
	"res://src/presentation/landing_presentation.gd",
	"res://src/presentation/ground_skid_presentation.gd",
	"res://src/presentation/cartoon_champion_presenter.gd",
	"res://src/presentation/pixel_movement_effects.gd",
	"res://src/presentation/heavy_blast_presenter.gd",
	"res://src/presentation/visual_language.gd",
	"res://src/sim/combat/combat_definition_table.gd",
	"res://src/sim/combat/combat_tuning.gd",
	"res://src/sim/combat/projectile_state.gd",
	"res://src/sim/chemistry/element_deposit_state.gd",
	"res://src/sim/core/sim_config.gd",
	"res://src/sim/movement/movement_tuning.gd",
	"res://src/content/ability_catalog.gd",
	"res://content/abilities/foundation_abilities_v1.json",
	"res://content/visual/visual_language_v1.json",
	"res://art_batches/pixel_v1/magic/manifest.json",
	"res://art_batches/pixel_v1/magic/export/magic_00.png",
	"res://art_batches/pixel_v1/magic/export/magic_01.png",
	"res://art_batches/pixel_v1/magic/export/magic_02.png",
	"res://assets/sprites/hex_court_v1/projectile_atlas.png",
]


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	var repo := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var roaming := OS.get_environment("APPDATA").replace("\\", "/")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/movement-impact-native-") \
			or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("Use native rendering and a fresh --output=res://.godot/movement-impact-native-NAME")
		return
	if OS.get_name() == "Windows" and not roaming.to_lower().begins_with(repo.to_lower() + "/.godot/"):
		_fail("Root must isolate APPDATA inside this checkout's .godot before capture")
		return
	var hashes := {}
	for path: String in SOURCES:
		hashes[path] = FileAccess.get_sha256(path)
		if String(hashes[path]).length() != 64:
			_fail("Missing capture source: " + path)
			return
	var board := ImpactBoard.new()
	if not board.prepare():
		_fail(board.last_error)
		board.free()
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Cannot create fresh capture directory")
		board.free()
		return
	root.visible = true
	root.mode = Window.MODE_MINIMIZED
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(board)
	var frames: Array[Dictionary] = []
	var total_bytes := 0
	var jobs: Array[Dictionary] = []
	for mode: String in MODES:
		for age: int in AGES:
			jobs.append({"mode": mode, "age": age, "blast": false})
	jobs.append({"mode": "comparison", "age": 0, "blast": true})
	for job: Dictionary in jobs:
		board.job = job
		board.queue_redraw()
		await process_frame
		# A minimized Windows root can skip frame_post_draw indefinitely.
		# Flush queued canvas work and render the offscreen viewport explicitly,
		# as the production Gallery capture does; no visible window is needed.
		await process_frame
		RenderingServer.force_draw(false)
		if not board.last_error.is_empty():
			_fail(board.last_error)
			return
		var image := viewport.get_texture().get_image()
		var name := "heavy-aftermath-authoritative-radius" if job.blast else "%s-age-%02d" % [job.mode, job.age]
		var path := output.path_join(name + ".png")
		if image == null or image.get_size() != SIZE or image.save_png(path) != OK:
			_fail("Failed native render: " + path)
			return
		var file := FileAccess.open(path, FileAccess.READ)
		var byte_count := file.get_length()
		file.close()
		total_bytes += byte_count
		if total_bytes > MAX_PNG_BYTES:
			_fail("Capture exceeded the 40MiB PNG budget; partial evidence retained")
			return
		frames.append({"path": path, "sha256": FileAccess.get_sha256(path), "bytes": byte_count,
			"job": job.duplicate(), "samples": board.records.duplicate(true), "optional_budget": board.pixels.library.decoration_stats()})
		print("RENDERED ", path)
	for path: String in hashes:
		if FileAccess.get_sha256(path) != hashes[path]:
			_fail("Capture source changed during rendering: " + path)
			return
	var receipt := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if receipt == null:
		_fail("Cannot write capture receipt")
		return
	receipt.store_string(JSON.stringify({"status": "passed", "sources": hashes, "frames": frames,
		"compiled_projectiles": board.definitions, "png_count": frames.size(), "png_bytes": total_bytes,
		"display": {"server": DisplayServer.get_name(), "size": [1280, 960], "minimized_root": true,
			"flight_world_zoom": 0.75, "impact_world_zoom": 1.0, "floor_detail_zoom": [1, 2], "image_resizing": false},
		"sequence": {"tick_rate": 120, "impact_ages": AGES, "heavy_aftermath_ages": [0, 12, 30],
			"mode_order": MODES, "realtime_playback": false},
		"method": "Native offscreen SubViewport using production HexCourt flight/cue, PixelSpellEffects contact, LandingPresentation, GroundSkid and HeavyBlastPresenter. Compiled projectile data is read at runtime. Ground states and hit cues are controlled samples, not executed actions. Before/after canonical bytes and strength projection are checked around rendering. Essential marks are also rendered after exhausting the shared optional budget.",
		"limitations": "No physical input, continuous animation/video, performance, multiplayer, collision execution, casting or human feel/readability acceptance. Point-contact artwork is not a hazard radius. The separate Heavy sheet is the existing legacy-deposit aftermath renderer in an empty collision world, not a hex damage execution. Root must inspect every image. No gameplay/profile/asset files are saved.",
	}, "\t") + "\n")
	receipt.close()
	print("PASS movement-impact native: ", frames.size(), " PNGs / ", total_bytes, " bytes; controlled production samples only")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


class ImpactBoard:
	extends Node2D
	var pixels := PixelSpellEffects.new()
	var contact := Contact.new()
	var court := HexCourtPresenter.new()
	var blast := HeavyBlastPresenter.new()
	var language := VisualLanguage.new()
	var config := SimConfig.new()
	var definitions: Array[Dictionary] = []
	var records: Array[Dictionary] = []
	var last_error := ""
	var job := {"mode": "normal", "age": 0, "blast": false}

	func prepare() -> bool:
		if not pixels.ready() or not language.load_from_file() or not court.configure(language):
			last_error = "Production pixel assets/visual language did not configure"
			return false
		for element: String in PixelSpellEffects.ELEMENTS:
			for family: String in FAMILIES:
				var found := false
				for wire: int in CombatTuning.runtime_wire_ids():
					var definition := CombatTuning.projectile_definition(wire)
					if String(definition.get("family", "")) != family or int(definition.get("element_wire_id", 0)) != int(HexCourtPresenter.ELEMENT_WIRES[element]): continue
					definitions.append({"element": element, "family": family, "wire": wire, "definition": definition})
					found = true
					break
				if not found:
					last_error = "Missing compiled projectile: " + element + "/" + family
					return false
		return true

	func _budget(mode: String) -> void:
		var reduced := mode == "reduced"
		pixels.library.begin_frame(reduced)
		if mode == "zero-budget":
			for element: String in PixelSpellEffects.ELEMENTS:
				for unused: int in 192:
					pixels.library.take_decoration(PixelSpellEffects.asset_id(element, "field_tile", reduced))
			if pixels.library.decoration_remaining() != 0:
				last_error = "Could not exhaust shared optional decoration budget"

	func _draw() -> void:
		records.clear()
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color("182528"))
		if bool(job.blast):
			_draw_blast_sheet()
			return
		var reduced: bool = job.mode == "reduced"
		var age: int = job.age
		_budget(job.mode)
		label(Vector2(18, 28), "H.E.X / MOVEMENT + CONTACT / %s / AGE %d OF 120Hz" % [String(job.mode).to_upper(), age], 21)
		label(Vector2(18, 50), "Each cell: full / strength1 flight at75% | radius contact at1x | damage contact at1x. Fixed contact ticks disclose the unchanged collider.", 13)
		for column: int in 3:
			label(Vector2(140 + column * 366, 76), FAMILIES[column].to_upper() + " / compiled radius, speed, damage, strength", 13)
		for index: int in definitions.size():
			var entry: Dictionary = definitions[index]
			@warning_ignore("integer_division")
			var row := index / 3
			var column := index % 3
			var x := 140.0 + float(column) * 366.0
			var y := 89.0 + float(row) * 90.0
			if column == 0: label(Vector2(14, y + 49), String(entry.element).to_upper(), 14, pixels.material_color(entry.element, 4))
			draw_rect(Rect2(x, y, 352, 86), Color("263a33"))
			_draw_projectile_cell(entry, Vector2(x, y), age, reduced, index)
		_draw_floor_strip(age, reduced)
		label(Vector2(18, 945), "Point contacts are cosmetic, not attack area. No bodies are warped. Still samples do not certify continuous animation, gameplay or human feel.", 12)

	func _draw_projectile_cell(entry: Dictionary, origin: Vector2, age: int, reduced: bool, index: int) -> void:
		var definition: Dictionary = entry.definition
		var radius := float(definition.radius) / 1000.0
		var speed := float(definition.speed) / 1000.0
		var damage := int(definition.damage)
		var strength := int(definition.reaction_strength)
		label(origin + Vector2(8, 16), "r%.1f | %.0fpx/s | d%.1f | s%d | wire%d" % [radius, speed, float(damage) / 1000.0, strength, entry.wire], 11)
		var shot := ProjectileState.new(100 + index, 1, 1, int(entry.wire), int(definition.element_wire_id),
			Vector2i.ZERO, Vector2i(int(definition.speed), 0), int(definition.radius), damage, config.milliseconds_to_ticks(int(definition.lifetime_ms)))
		shot.initial_strength = strength
		shot.reaction_strength = strength
		var flight_handled := true
		var flight_unchanged := true
		for sample_index: int in 2:
			var remaining := strength if sample_index == 0 else 1
			shot.entity_id = 100 + index * 2 + sample_index
			shot.remaining_strength = remaining
			var before := shot.canonical_values()
			draw_set_transform(origin + Vector2(35 + sample_index * 62, 56), 0.0, Vector2.ONE * 0.75)
			flight_handled = court.draw_projectile(self, shot, float(age), 0.0, reduced) and flight_handled
			draw_set_transform(Vector2.ZERO)
			flight_unchanged = flight_unchanged and shot.canonical_values() == before and shot.initial_strength == strength and shot.remaining_strength == remaining
			label(origin + Vector2(22 + sample_index * 62, 81), "full" if sample_index == 0 else "s1", 9)
		var radius_anchor := origin + Vector2(192, 56)
		var damage_anchor := origin + Vector2(299, 56)
		var impact_handled := pixels.impact(self, entry.element, radius_anchor, age, reduced, radius)
		var cue := {"event_type": "projectile_hit", "source_wire_id": int(entry.wire), "position": damage_anchor,
			"damage": damage, "age_ticks": age, "duration": 0.55, "remaining": maxf(0.0, 0.55 - float(age) / 120.0)}
		var cue_before := var_to_bytes(cue)
		var hit_handled := court.draw_cue(self, cue, reduced)
		var model: Dictionary = contact.sample(cue, entry.element, reduced)
		if not flight_handled or not impact_handled or not hit_handled or model.is_empty() or not model.visible \
				or not flight_unchanged or var_to_bytes(cue) != cue_before:
			last_error = "Production renderer admission/authority mismatch: " + String(entry.element) + "/" + String(entry.family)
		records.append({"kind": "projectile_and_contact", "wire": entry.wire, "element": entry.element, "family": entry.family,
			"radius_px": radius, "speed_px_s": speed, "damage": damage, "strength": strength,
			"blast_radius_px": float(definition.get("blast_radius", 0)) / 1000.0, "age": age,
			"flight_remaining_strengths": [strength, 1], "collision_radius_unchanged": true,
			"full_art_diameter_px": HexCourtPresenter.projectile_full_size(entry.family, int(definition.radius)),
			"strength1_core_diameter_px": HexCourtPresenter.strength_scaled_size(HexCourtPresenter.projectile_full_size(entry.family, int(definition.radius)), 1, strength),
			"hit_scale": model.get("render_scale", 0.0), "hit_opacity": model.get("render_opacity", 0.0),
			"hit_asset": model.get("asset_id", ""), "hit_frame": (model.get("frame", {}) as Dictionary).get("index", -1),
			"authority_unchanged": flight_unchanged and var_to_bytes(cue) == cue_before})

	func _draw_floor_strip(age: int, reduced: bool) -> void:
		label(Vector2(18, 827), "FLOOR CONTACTS ONLY / each pair: native1x then2x detail / landing follows age; skid cadence follows disclosed distance phase", 13)
		for index: int in 5:
			var state := PlayerState.new()
			state.velocity_x = 270000
			state.facing_x = -1000
			state.facing_y = 0
			var x := 18.0 + index * 250.0
			var phase := fposmod(float(age) * 0.035, 1.0)
			var landing_case := index < 2
			var descriptor := ""
			if landing_case:
				state.landing_ticks = maxi(0, config.milliseconds_to_ticks(MovementTuning.LANDING_WINDOW_MS) - age)
				state.landing_intensity = 250 if index == 0 else 1000
				descriptor = "LAND / force%d / tick%d" % [state.landing_intensity, age]
			else:
				state.velocity_x = [80000, MovementTuning.BASE_SPEED, MovementTuning.BASE_SPEED * MovementTuning.SPRINT_MULTIPLIER / 1000][index - 2]
				state.slide_ticks = 0 if index == 4 else 8
				state.wave_dash_ticks = 8 if index == 4 else 0
				state.movement_mode = PlayerState.MovementMode.WAVE_DASH if index == 4 else PlayerState.MovementMode.SLIDE
				phase *= float(state.velocity_x) / 594000.0
				descriptor = "%s / %.0fpx/s / phase%.2f" % ["WAVEDASH" if index == 4 else "SLIDE", float(state.velocity_x) / 1000.0, phase]
			label(Vector2(x, 849), descriptor, 11)
			var before := state.canonical_values()
			for zoom: int in [1, 2]:
				var anchor := Vector2(x + (60 if zoom == 1 else 175), 892)
				draw_line(anchor + Vector2(-42, 5), anchor + Vector2(42, 5), Color("657460"), 1.0)
				draw_set_transform(anchor, 0.0, Vector2.ONE * zoom)
				if landing_case:
					LandingPresentation.draw(self, Vector2.ZERO, LandingPresentation.sample(state, config, 0.0, reduced), language)
				else:
					GroundSkid.draw(self, Vector2.ZERO, GroundSkid.sample(state, phase, reduced), language)
				draw_set_transform(Vector2.ZERO)
				label(anchor + Vector2(-8, 28), "%dx" % zoom, 10)
			if before != state.canonical_values(): last_error = "Ground renderer changed controlled authority"
			records.append({"kind": "landing" if landing_case else "skid", "age": age, "velocity_x": state.velocity_x,
				"slide_ticks": state.slide_ticks, "wave_dash_ticks": state.wave_dash_ticks, "movement_mode": state.movement_mode,
				"landing_ticks": state.landing_ticks, "landing_intensity": state.landing_intensity, "distance_phase": phase,
				"authority_unchanged": before == state.canonical_values()})

	func _draw_blast_sheet() -> void:
		var entry: Dictionary = definitions[5] # Fire Heavy; chosen by compiled element/family, not a wire constant.
		var definition: Dictionary = entry.definition
		label(Vector2(18, 28), "HEAVY AFTERMATH / COMPILED %.0fpx RADIAL FOOTPRINT / FIRE wire%d" % [float(definition.blast_radius) / 1000.0, entry.wire], 22)
		label(Vector2(18, 51), "Existing HeavyBlastPresenter, empty collision world,1x. Already-resolved aftermath, not a new area telegraph or played cast.", 14)
		var world := CollisionWorld.new(2000000, 2000000)
		for row: int in 3:
			var mode: String = MODES[row]
			var reduced := mode == "reduced"
			_budget(mode)
			for column: int in 3:
				var age: int = [0, 12, 30][column]
				var deposit := ElementDepositState.new()
				deposit.entity_id = 3000 + row * 3 + column
				deposit.source_cast_id = 1000
				deposit.source_wire_id = entry.wire
				deposit.owner_id = 1
				deposit.team_id = 1
				deposit.element_wire_id = definition.element_wire_id
				deposit.position_x = 500000
				deposit.position_y = 500000
				deposit.created_tick = 50
				deposit.expiry_tick = 290
				deposit.reaction_strength = definition.reaction_strength
				var before := deposit.canonical_values()
				var model := blast.model(deposit, 50 + age, config, world, [], reduced)
				var anchor := Vector2(226 + column * 407, 226 + row * 285)
				label(anchor + Vector2(-175, -130), "%s / tick%d / direct%.0f / radial%.0f" % [mode.to_upper(), age, float(definition.damage) / 1000.0, float(definition.blast_damage) / 1000.0], 13)
				draw_set_transform(anchor - Vector2(500, 500))
				blast.draw(self, deposit, 50 + age, config, world, [], reduced)
				pixels.impact(self, "fire", Vector2(500, 500), age, reduced, float(definition.radius) / 1000.0)
				draw_set_transform(Vector2.ZERO)
				if model.is_empty() or float(model.radius) != float(definition.blast_radius) / 1000.0 or before != deposit.canonical_values():
					last_error = "Heavy aftermath radius/authority mismatch"
				records.append({"kind": "heavy_aftermath", "wire": entry.wire, "age": age, "mode": mode,
					"radius_px": model.get("radius", 0.0), "opacity": model.get("opacity", 0.0),
					"authority_unchanged": before == deposit.canonical_values()})
		label(Vector2(18, 945), "Broken boundary is the actual authored Heavy radius; central element contact is separate cosmetic emphasis. Normal/reduced preserve identical area.", 12)

	func label(at: Vector2, value: String, size: int, color: Color = Color("e9ddbc")) -> void:
		draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
