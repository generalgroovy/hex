extends FluxTestSuite


const Elements = preload("res://src/content/element_rules.gd")
const Release = preload("res://src/presentation/hex_cast_release.gd")
const Library = preload("res://src/presentation/pixel_magic_library.gd")
const Harness = preload("res://tests/support/chemistry_coach_harness.gd")
var library := Library.new()
var catalog := AbilityCatalog.new()
var presenter: RefCounted


func run() -> int:
	check(library.load_from_file(), "release reuses the verified existing atlas: " + library.last_error)
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "release matrix uses the live spell catalog")
	if library.asset_count() == 0 or catalog.runtime_wire_ids.is_empty(): return finish("hex-cast-release")
	presenter = Release.new(library)
	_test_matrix_and_finite_sequence()
	_test_derived_archive_styles()
	_test_invalid_and_expired()
	_test_real_ingestion_and_visibility()
	_test_shared_art_and_isolation()
	return finish("hex-cast-release")


func _cue(age: int = 0) -> Dictionary:
	return {"kind": "pixel_release", "position": Vector2(412.125, 298.875),
		"age_ticks": age, "duration": 0.20, "remaining": 0.20 - float(age) / 120.0}


func _definition(element: String, family: String) -> Dictionary:
	var ability := catalog.ability(catalog.spell_id_at(element, family))
	return CombatTuning.cast_definition(int(ability.get("wire_id", 0)))


func _test_matrix_and_finite_sequence() -> void:
	var count := 0
	var identities := {}
	for element: String in Elements.IDS:
		for family: String in ["bolt", "heavy", "rapid", "spray"]:
			var definition := _definition(element, family)
			var definition_before := var_to_bytes(definition)
			var normal: Dictionary = presenter.sample(_cue(), definition, false)
			check(not normal.is_empty(), "every retained baseline element/delivery has its original release")
			if normal.is_empty(): continue
			count += 1
			identities[normal.asset_id] = true
			for reduced: bool in [false, true]:
				var seen_frames := {}
				for age: int in range(27):
					var cue := _cue(age)
					var source_before := var_to_bytes(cue)
					var model: Dictionary = presenter.sample(cue, definition, reduced)
					check(model.handled, "finite sequence remains handled through expiry")
					equal(model.visible, age < 24, "release never exceeds its existing twenty-four ticks")
					equal(model.position, cue.position, "release keeps its exact fractional hand anchor")
					equal(model.scale, {"rapid":1.0,"bolt":1.25,"heavy":1.5,"spray":1.25}[family], "bounded delivery emphasis is not strength, damage or radius")
					for key: String in ["position", "family", "element_wire_id", "scale", "duration_ticks", "sample_age_ticks"]:
						equal(model[key], presenter.sample(cue, definition, false)[key], "reduced mode preserves release information: " + key)
					equal(model.asset_id, "magic.%s.hand_release.%s" % [element,"reduced" if reduced else "normal"], "six live materials retain their own normal/reduced silhouettes")
					var expected_age := floori(float(age * 30) / 24.0) if age < 24 else 30
					equal(model.sample_age_ticks, expected_age, "complete thirty-tick authored sequence fits existing cue without a new timer")
					equal(model.frame, library.sample(model.asset_id, expected_age), "release uses the exact prepared authored frame")
					if model.visible: seen_frames[library.frame_index(model.asset_id, model.sample_age_ticks)] = true
					equal(var_to_bytes(cue), source_before, "sampling never mutates the release cue")
					check(not model.has("radius") and not model.has("damage") and not model.has("strength"), "cosmetic emphasis cannot fabricate attack properties")
				check(seen_frames.size() == 5, "every authored release pose survives playback fitting")
			equal(var_to_bytes(definition), definition_before, "sampling never changes compiled spell authority")
	equal(count, 24, "all24 retained baseline releases covered; expanded sectors are independently tested by element-delivery-presentation")
	equal(identities.size(), 6, "every active element has a separately identified sequence")


# Synthetic art primitives only: never a compiled live spell or network event.
func _test_derived_archive_styles() -> void:
	for wire: int in [5,6]:
		for family: String in ["bolt","heavy","rapid","spray"]:
			var definition := {"family":family,"shape":"spray" if family=="spray" else "projectile","element_wire_id":wire}
			for reduced: bool in [false,true]:
				for age: int in range(27):
					var model: Dictionary=presenter.sample(_cue(age),definition,reduced)
					check(not model.is_empty(),"derived Ice/Charge effect style remains available as a harmless art primitive")
					equal(model.visible,age<24,"archive release primitive retains exact finite visual lifetime")
					equal(model.asset_id,Library.element_asset_id(wire,"hand_release",reduced),"archive primitive cannot borrow a live material identity")
	for wire: int in [170,101,187,189,188,190,171,167]:
		check(CombatTuning.cast_definition(wire).is_empty(),"retained art does not restore a retired compiled spell")

func _test_invalid_and_expired() -> void:
	var definition := _definition("fire", "bolt")
	var invalid: Array[Dictionary] = [{}]
	for field: String in ["age_ticks", "duration", "remaining"]:
		for value: Variant in ["1", null, true, [], {}]:
			var cue := _cue()
			cue[field] = value
			invalid.append(cue)
	for value: Variant in [-1, 0.5]:
		var cue := _cue()
		cue.age_ticks = value
		invalid.append(cue)
	for field: String in ["duration", "remaining"]:
		for value: float in [NAN, INF, -INF]:
			var cue := _cue()
			cue[field] = value
			invalid.append(cue)
	for value: Variant in [Vector2(NAN,0),Vector2(INF,0),Vector2i(1,2),null]:
		var cue := _cue()
		cue.position = value
		invalid.append(cue)
	for kind: String in ["impact", "spray", "cast_started", "cast_refused", "projectile_hit"]:
		var cue := _cue()
		cue.kind = kind
		invalid.append(cue)
	var extended := _cue()
	extended.duration = 0.55
	invalid.append(extended)
	for cue: Dictionary in invalid:
		check(presenter.sample(cue, definition, false).is_empty(), "invalid or unrelated cue retains existing fallback")
	for wrong: Dictionary in [{}, {"family":"beam","shape":"beam","element_wire_id":2}, {"family":"bolt","shape":"projectile","element_wire_id":9}]:
		check(presenter.sample(_cue(), wrong, false).is_empty(), "unavailable family or element cannot borrow release art")
	check(not presenter.draw(null, _cue(), definition, false), "missing canvas is unsupported")
	var empty := Release.new(Library.new())
	check(empty.sample(_cue(), definition, false).is_empty(), "missing art retains working old cross")
	var old := _cue()
	old.age_ticks = 0x7fffffffffffffff
	check(not presenter.sample(old, definition, false).visible, "ancient age expires before scaling arithmetic")
	var cancelled := _cue()
	cancelled.remaining = 0.0
	check(not presenter.sample(cancelled, definition, false).visible, "owning cue expiry hides release even with stale age")
	var canvas := Node2D.new()
	check(presenter.draw(canvas, _cue(24), definition, false), "valid expiry suppresses old cross without issuing a draw")
	canvas.free()


func _test_real_ingestion_and_visibility() -> void:
	var node := Harness.new()
	check(node.configure_fixture(), "release fixture configures inherited Bootstrap ingestion and visibility")
	var actor: PlayerState = node.world.player()
	var before := actor.canonical_values()
	for element: String in Elements.IDS:
		for family: String in ["bolt", "heavy", "rapid", "spray"]:
			var ability := catalog.ability(catalog.spell_id_at(element, family))
			var event := {"type":"spray_fired" if family == "spray" else "projectile_spawned", "owner_id":actor.entity_id,"wire_id":int(ability.wire_id),"source_wire_id":int(ability.wire_id),"lane_index":0}
			node.combat_cues.clear()
			node._ingest_magic_release(event)
			node._ingest_magic_release(event)
			equal(node.combat_cues.size(), 1, "production admits one release per accepted tick/owner/wire despite duplicate events")
			if node.combat_cues.size() != 1: continue
			var cue: Dictionary = node.combat_cues[0]
			equal(cue.duration, 0.20, "production release retains its existing lifetime")
			check(node._combat_cue_visible(cue), "actual local release anchor passes production POV visibility")
			check(presenter.sample(cue, _definition(element,family), false).visible, "real ingested cue is usable without rewriting its fields")
			node._update_combat_cues(0.201)
			check(node.combat_cues.is_empty(), "production update retires release without another timer")
	var remote := PlayerState.new(2)
	remote.position_x = actor.position_x + 900_000
	remote.position_y = actor.position_y
	node.world.players.append(remote)
	node._reset_motion_history()
	var hidden := {"type":"projectile_spawned","owner_id":2,"wire_id":145,"lane_index":0}
	node._ingest_magic_release(hidden)
	check(node.combat_cues.is_empty(), "hidden caster cannot leak release through actual production range gating")
	for event: Dictionary in [{"type":"cast_started","owner_id":1,"wire_id":145}, {"type":"cast_refused","owner_id":1,"wire_id":145}, {"type":"projectile_spawned","owner_id":1,"wire_id":145,"lane_index":1}]:
		node._ingest_magic_release(event)
	check(node.combat_cues.is_empty(), "startup refusal and duplicate burst lanes do not create accepted release art")
	equal(actor.canonical_values(), before, "release ingestion and visibility never alter gameplay authority")
	node.free()


func _test_shared_art_and_isolation() -> void:
	var definition := _definition("earth", "heavy")
	var cue := _cue(4)
	var first: Dictionary = presenter.sample(cue, definition, false)
	var stats := library.decoration_stats()
	for _index: int in range(64):
		var current: Dictionary = presenter.sample(cue, definition, false)
		equal(current.frame, first.frame, "release reuses immutable prepared frames")
		equal(current.frame.texture.get_instance_id(), first.frame.texture.get_instance_id(), "release allocates no new texture")
	equal(library.decoration_stats(), stats, "guaranteed replacement stamp cannot reset or consume optional decoration")
	first.position = Vector2.ZERO
	first.scale = 99.0
	equal(presenter.sample(cue, definition, false).position, cue.position, "escaped model cannot poison another release anchor")
	equal(presenter.sample(cue, definition, false).scale, 1.5, "escaped model cannot enlarge another release")
	var source := FileAccess.get_file_as_string("res://src/presentation/hex_cast_release.gd")
	check(not source.contains("Image.create") and not source.contains("ImageTexture.create") and not source.contains("load_from_file("), "release draw path does not generate or load images")
	equal(source.count("library.draw_stamp("), 1, "one release owns one replacement stamp draw site")
