extends SceneTree
## Arranged live fields through production drawing, not a simulated battle.

const Effects = preload("res://src/presentation/pixel_spell_effects.gd")
const Status = preload("res://src/presentation/element_status_presenter.gd")
const SOURCES := ["res://src/presentation/foundation_spell_presenter.gd", "res://src/presentation/pixel_spell_effects.gd",
	"res://src/presentation/element_status_presenter.gd", "res://src/presentation/pixel_effect_geometry.gd",
	"res://src/presentation/element_glyph_renderer.gd", "res://src/sim/combat/spell_status_policy.gd",
	"res://src/sim/hex/hex_expanded_delivery.gd", "res://src/sim/combat/combat_definition_table.gd",
	"res://content/abilities/foundation_abilities_v1.json", "res://content/abilities/element_mixtures_v1.json",
	"res://tests/visual/capture_element_delivery_readability.gd"]
var output := ""

class Board:
	extends Node2D
	var presenter: FoundationSpellPresenter
	var characters: CartoonChampionPresenter
	var language: VisualLanguage
	var catalog: ChampionCatalog
	var config := SimConfig.new(120)
	var fixtures: Array[Dictionary] = []
	var actors: Array[Dictionary] = []
	var size := Vector2i(1280, 900)
	var title := ""
	var reduced := false
	var failed := false

	func add_shot(mask: int, family: String, at: Vector2, phase: int = 0, ticks: int = 0, pool_ratio: float = 1.0, height: int = 0) -> void:
		var wire := MixtureCatalog.wire_for(mask, family)
		var definition := CombatTuning.cast_definition_view(wire)
		if definition.is_empty(): failed = true; return
		if family == "spray":
			var cue := {"kind": "spray", "source_wire_id": wire, "start": at - Vector2(120, 0), "end": at + Vector2(120, 0), "duration": 0.20, "remaining": 0.15, "range": 240000}
			cue.spray_geometry = HexCourtPresenter.prepare_spray_cue(cue, CollisionWorld.new(1280000, 900000))
			fixtures.append({"cue": cue, "before": cue.duplicate(true), "at": at, "label": "SPRAY / mask%d / real clipped pulse" % mask})
			return
		var shot := ProjectileState.new(fixtures.size() + 1, 1, 1, wire, int(definition.element_wire_id), Vector2i(at * 1000.0), Vector2i(280000, -180000), int(definition.radius), int(definition.damage), config.milliseconds_to_ticks(int(definition.lifetime_ms)))
		shot.source_cast_id = fixtures.size() + 1
		shot.initial_strength = int(definition.reaction_strength); shot.remaining_strength = shot.initial_strength
		shot.delivery_phase = phase; shot.delivery_ticks = ticks
		shot.delivery_damage_remaining = roundi(float(shot.damage) * pool_ratio)
		shot.remaining_bounces = int(definition.get("remaining_bounces", 0))
		var owner := PlayerState.new(1)
		owner.air_height = height
		fixtures.append({"shot": shot, "owner": owner, "before": shot.canonical_values(), "owner_before": owner.canonical_values(),
			"label": "%s / mask%d / phase%d" % [family.to_upper(), mask, phase], "at": at})

	func add_actor(mask: int, at: Vector2, remaining: int = 120) -> void:
		var actor := PlayerState.new(actors.size() + 2)
		if not catalog.apply_to_player(actor, "s_wayne"): failed = true; return
		actor.team_id = 2; actor.spawn_protection_ticks = 0
		SpellStatusPolicy.apply_hit(actor, MixtureCatalog.wire_for(mask, "bolt"), 700 + actor.entity_id, 1, 1, 4000, config, Vector2i.ZERO)
		for channel: int in 6:
			if actor.spell_status_values[channel * 8] > 0: actor.spell_status_values[channel * 8] = remaining
		actors.append({"actor": actor, "at": at, "mask": mask, "before": actor.canonical_values()})

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(size)), Color("36463f"))
		for y: int in range(70, size.y, 40): draw_line(Vector2(0, y), Vector2(size.x, y), Color("3d4e46"), 1)
		draw_string(ThemeDB.fallback_font, Vector2(16, 26), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("e0d5b2"))
		draw_string(ThemeDB.fallback_font, Vector2(16, 45), "Live fields arranged for native review; no simulated paid battle, balance, motion or performance claim", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("bac7b8"))
		for fixture: Dictionary in fixtures:
			if fixture.has("cue"):
				if not presenter.draw_expanded_cue(self, fixture.cue, reduced): failed = true
				if fixture.cue != fixture.before: failed = true
				draw_string(ThemeDB.fallback_font, fixture.at + Vector2(-100, 131), fixture.label, HORIZONTAL_ALIGNMENT_LEFT, 285, 10, Color("e0d5b2"))
				continue
			var shot: ProjectileState = fixture.shot
			var definition := CombatTuning.cast_definition_view(shot.source_wire_id)
			var model := Effects.expanded_projectile_model(shot, definition, fixture.at, config, fixture.owner, reduced)
			if model.is_empty() or not presenter.pixel_effects.draw_expanded_projectile(self, model, language): failed = true
			if shot.canonical_values() != fixture.before or fixture.owner.canonical_values() != fixture.owner_before: failed = true
			draw_string(ThemeDB.fallback_font, fixture.at + Vector2(-63, 131 if title.contains("PHASES") or title.contains("DELIVERIES") else 28), fixture.label, HORIZONTAL_ALIGNMENT_LEFT, 285, 10, Color("e0d5b2"))
		for fixture: Dictionary in actors:
			var actor: PlayerState = fixture.actor
			if not characters.draw(self, actor, "s_wayne", fixture.at, 9000, config, reduced, fixture.at, 0.0): failed = true
			Status.draw(self, actor, fixture.at, config, language, reduced)
			if actor.canonical_values() != fixture.before: failed = true
			var names: Array[String] = []
			for badge: Dictionary in Status.model(actor, config, language): names.append(String(badge.label))
			draw_string(ThemeDB.fallback_font, fixture.at + Vector2(-110, 32), " / ".join(names) if not names.is_empty() else "EXPIRED: NO BADGES", HORIZONTAL_ALIGNMENT_LEFT, 225, 11, Color("e0d5b2"))


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/element-delivery-native-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("Native backend and fresh --output=res://.godot/element-delivery-native-NAME required"); return
	if DirAccess.make_dir_recursive_absolute(output) != OK: _fail("Cannot create capture directory"); return
	var hashes := {}
	for path: String in SOURCES:
		hashes[path] = FileAccess.get_sha256(path)
		if String(hashes[path]).length() != 64: _fail("Missing capture source " + path); return
	var abilities := AbilityCatalog.new()
	var catalog := ChampionCatalog.new()
	var language := VisualLanguage.new()
	var presenter := FoundationSpellPresenter.new()
	var characters := CartoonChampionPresenter.new()
	if not abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json") or not catalog.load_from_file("res://content/champions/foundation_champions_v1.json", abilities) or not language.load_from_file() or not presenter.configure(language, abilities) or not characters.configure(language, CartoonChampionPresenter.DEFAULT_PATH, CartoonChampionPresenter.DEFAULT_OVERRIDE_PATH, false) or not characters.enable_fullbody_art(true, true):
		_fail("Production presentation admission failed"); return
	root.visible = true; root.mode = Window.MODE_MINIMIZED
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	board.presenter = presenter; board.characters = characters; board.language = language; board.catalog = catalog
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(board)
	var images: Array[Dictionary] = []
	for kind: String in ["MIXTURES", "DELIVERIES", "PHASES", "STATUS"]:
		board.fixtures.clear(); board.actors.clear()
		board.size = Vector2i(1280, 900)
		if kind == "MIXTURES":
			for mask: int in range(1, 64): board.add_shot(mask, "heavy", Vector2(73 + ((mask - 1) % 9) * 140, 120 + ((mask - 1) / 9) * 110))
		elif kind == "DELIVERIES":
			for index: int in MixtureCatalog.FAMILIES.size():
				var family: String = MixtureCatalog.FAMILIES[index]
				board.add_shot(63, family, Vector2(160 + (index % 4) * 320, 230 + (index / 4) * 360), 1 if family == "fuse" else 0, 72 if family == "fuse" else 30)
		elif kind == "PHASES":
			board.add_shot(7, "fuse", Vector2(160, 230), 0, 0)
			board.add_shot(7, "fuse", Vector2(480, 230), 1, 72)
			board.add_shot(7, "fuse", Vector2(800, 230), 1, 36)
			board.add_shot(7, "fuse", Vector2(1120, 230), 1, 1)
			board.add_shot(21, "mantle", Vector2(160, 590), 0, 0, 1.0, 0)
			board.add_shot(21, "mantle", Vector2(480, 590), 0, 0, 0.5, 40000)
			board.add_shot(42, "split", Vector2(800, 590), 0, 30)
			board.add_shot(42, "split", Vector2(1120, 590), 2, 0)
		else:
			for channel: int in 6: board.add_actor(1 << channel, Vector2(210 + (channel % 3) * 420, 250 + (channel / 3) * 240))
			board.add_actor(63, Vector2(300, 750)); board.add_actor(63, Vector2(940, 750), 0)
		for reduced: bool in [false, true]:
			board.reduced = reduced
			presenter.begin_frame(board.config, null)
			for zoom: float in [1.0, 0.75]:
				board.title = kind + " / reduced=" + str(reduced) + " / zoom=" + str(zoom)
				viewport.size = Vector2i(Vector2(board.size) * zoom)
				viewport.canvas_transform = Transform2D.IDENTITY.scaled(Vector2.ONE * zoom)
				board.queue_redraw()
				await process_frame; await process_frame
				RenderingServer.force_draw(false)
				if board.failed: _fail("Production draw or authority immutability failed"); return
				var leaf := "%s-reduced-%d-zoom-%d.png" % [kind.to_lower(), int(reduced), roundi(zoom * 100)]
				var pixels := viewport.get_texture().get_image()
				if pixels == null or pixels.save_png(output.path_join(leaf)) != OK: _fail("Cannot save native pixels"); return
				images.append({"path": leaf, "sha256": FileAccess.get_sha256(output.path_join(leaf)), "shots": board.fixtures.size(), "actors": board.actors.size()})
	for path: String in hashes:
		if FileAccess.get_sha256(path) != hashes[path]: _fail("Source changed during capture: " + path); return
	var file := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if file == null: _fail("Cannot write capture receipt"); return
	file.store_string(JSON.stringify({"status": "captured_needs_visual_review", "source_hashes": hashes, "images": images, "authority_unchanged": true,
		"scope": "63 ingredient sectors,8delivery shapes,actual Fuse deadlines/Mantle pool and height/Split phases,six ailment badges,normal/reduced,1x/0.75x",
		"limitations": "Arranged replicated fields; no physical input/battle, live map occlusion, networking, dense performance or human acceptance."}, "\t") + "\n")
	file.close(); print("PASS element delivery native capture: ", images.size(), " images require independent review"); quit(0)


func _fail(message: String) -> void:
	push_error(message); quit(1)
