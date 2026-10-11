extends FluxTestSuite

const Fullbody = preload("res://src/presentation/fullbody_cast_presenter.gd")

class StartupProbe:
	extends CartoonChampionPresenter
	var skipped_wireframe_before_fullbody := false
	func enable_fullbody_art(use_pixel_pilot: bool = false, use_full_cast: bool = false, bounded_residency: bool = false) -> bool:
		skipped_wireframe_before_fullbody = champions.size() == 30 and wireframe_body.content_hash.is_empty() and wireframe_body.base_textures.is_empty() and wireframe_body.locomotion_textures.is_empty() and wireframe_body.sprint_textures.is_empty() and _wireframe_portraits.is_empty()
		return super.enable_fullbody_art(use_pixel_pilot, use_full_cast, bounded_residency)

class RejectedStartup:
	extends CartoonChampionPresenter
	func enable_fullbody_art(_use_pixel_pilot: bool = false, _use_full_cast: bool = false, _bounded_residency: bool = false) -> bool:
		last_error = "Synthetic late Fullbody refusal" if champions.size() == 30 else "Unexpected metadata failure"
		return false

func run() -> int:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "residency uses the real visual language")
	_test_failed_startup(language)
	var presenter := StartupProbe.new()
	check(presenter.configure(language), "original verified fallback is admitted first")
	check(not presenter.wireframe_body.base_textures.is_empty(), "original fallback is present before replacement")
	var fallback: Texture2D = presenter.wireframe_body.base_texture("small")
	var original_hash := presenter.content_hash
	var generation := presenter.configuration_generation
	check(not presenter.configure_fullbody_startup(null, false, true), "invalid startup metadata refuses before replacing eager fallback")
	check(presenter.wireframe_body.base_texture("small") == fallback and presenter.fullbody_art == null, "metadata refusal preserves the original verified fallback")
	equal(presenter.content_hash, original_hash, "failed metadata preserves published configuration identity")
	equal(presenter.configuration_generation, generation, "failed metadata does not signal a new published renderer")
	fallback = null
	check(presenter.configure_fullbody_startup(language, false, true), "dedicated bounded complete character startup activates")
	check(presenter.skipped_wireframe_before_fullbody, "successful startup reaches Fullbody with all metadata but zero wireframe pages or portraits loaded")
	equal(presenter.configuration_generation, generation + 1, "atomic startup publishes exactly one new renderer generation")
	if presenter.fullbody_art == null: return finish("character-page-residency")
	var body: RefCounted = presenter.fullbody_art
	var pixel: RefCounted = body.pixel_pilot
	check(pixel != null and pixel.action_bank != null, "real pixel and optional action metadata are admitted")
	if pixel == null or pixel.action_bank == null: return finish("character-page-residency")
	var actions: RefCounted = pixel.action_bank
	var ids: Array[String] = []
	ids.assign(body.entries.keys())
	equal(ids.size(), 30, "all character identities remain admitted")
	equal(body.residency_stats().native_rgba_bytes, 0, "initial validation does not retain large pages")
	check(presenter.wireframe_body.base_textures.is_empty() and presenter.wireframe_body.locomotion_textures.is_empty() and presenter.wireframe_body.sprint_textures.is_empty(), "unreachable wireframe page banks release after successful activation")
	var loads := _loads(body)
	check(not presenter.can_present("not-a-character"), "unknown identity remains unavailable")
	for id: String in ids:
		check(presenter.can_present(id), "verified identity remains discoverable before body residency")
		var portrait: Dictionary = presenter.portrait_frame(id)
		check(portrait.get("texture") is Texture2D, "every unprepared Gallery identity retains its own portrait")
		equal(portrait.texture.get_size(), Vector2(32, 32), "all retained faces are tiny independent textures")
		equal(portrait.visual_mode, "pixel_cast", "unprepared portrait still identifies its actual art source")
		equal(body.inspection_frame(id, 0), {}, "unprepared inspection cannot borrow another identity")
	equal(_loads(body), loads, "portrait and inspection queries perform no page loading")
	var config := SimConfig.new(120)
	var state := PlayerState.new(1)
	equal(presenter.movement_frame(ids[0], state, 0.0, config), {}, "unprepared actor has explicit empty presentation")
	var first: Array[String] = [ids[0]]
	check(presenter.prepare_override_pages(first), "existing preparation hook admits one active identity")
	check(presenter.can_present(ids[0]), "prepared identity remains discoverable with released wireframe pages")
	var prepared_before := _published(body)
	check(not presenter.configure_fullbody_startup(null, false, true), "failed reload cannot revoke a working bounded renderer")
	check(presenter.fullbody_art == body, "failed reload retains the exact verified Fullbody owner")
	equal(_published(body), prepared_before, "failed reload preserves all current active pages")
	prepared_before.clear()
	var body_ref: WeakRef = weakref(body.textures[ids[0]])
	var pixel_ref: WeakRef = weakref(pixel.textures[ids[0]])
	var action_ref: WeakRef = weakref(actions.textures[ids[0]])
	loads = _loads(body)
	check(presenter.prepare_override_pages(first), "warm identical preparation succeeds")
	equal(_loads(body), loads, "warm identical preparation reuses validated pages")
	for index: int in ids.size():
		var requested: Array[String] = [ids[index]]
		check(presenter.prepare_override_pages(requested), "every live character is reachable through bounded preparation")
		var stats: Dictionary = body.residency_stats()
		check(stats.body_pages <= 3 and stats.pixel_pages <= 3 and stats.action_pages <= 3, "one active identity retains at most two recent identities in every bank")
		equal(pixel.aerial_profiles.size(), actions.textures.size(), "aerial profiles cannot pin evicted action pages")
		for resident: String in stats.resident_ids:
			check(body.textures.has(resident) and pixel.textures.has(resident), "all published banks agree on active identity residency")
		loads = _loads(body)
		for aim: int in 8:
			var frame: Dictionary = body.inspection_frame(ids[index], aim)
			check(frame.texture == pixel.textures[ids[index]], "inspection selects the exact active identity texture")
			equal(frame.region, Rect2(aim*128, 0, 128, 128), "inspection keeps original aim-facing pixels")
			for action: String in ["idle", "walk", "sprint", "cast", "rooted", "jump", "fall", "land", "jumpsquat"]:
				var pose: Dictionary = pixel.frame(ids[index], action, aim, aim, 0.25, false, 0.0, false)
				check(not pose.is_empty(), "ground and authored advanced keys stay available")
				if not pose.is_empty():
					check(pose.texture == pixel.textures[ids[index]] or pose.texture == actions.textures[ids[index]], "advanced pose never substitutes another character")
			for action: String in ["crouch", "slide", "wavedash", "roll", "air_dodge", "wallrun", "fly", "hit", "stunned", "defeated"]:
				var pose: Dictionary = pixel.rigid_fallback_frame(ids[index], action, aim, aim, 0.25, false)
				check(not pose.is_empty(), "unpainted actions preserve the same-identity explicit fallback")
		check(not presenter.movement_frame(ids[index], state, 0.0, config).is_empty(), "prepared actor reaches the real presentation path")
		equal(_loads(body), loads, "all frame and action sampling stays free of page loading")
		if index == 3:
			check(body_ref.get_ref() == null and pixel_ref.get_ref() == null and action_ref.get_ref() == null, "eviction releases body, pixel and action textures, including profile references")
	var active: Array[String] = []
	for index: int in Fullbody.MAX_ACTIVE_IDENTITIES: active.append(ids[index])
	check(presenter.prepare_override_pages(active), "twelve actors plus one Gallery preview fit the request bound")
	equal(body.resident_order.size(), Fullbody.MAX_RESIDENT_IDENTITIES, "two most recent inactive identities remain bounded beside the full active set")
	var published := _published(body)
	var invalid := active.duplicate()
	invalid.append(ids[13])
	check(not presenter.prepare_override_pages(invalid), "fourteenth active identity refuses before loading")
	equal(_published(body), published, "capacity refusal preserves all current verified banks")
	var unknown: Array[String] = ["not-a-character"]
	check(not presenter.prepare_override_pages(unknown), "unknown identity refuses")
	equal(_published(body), published, "unknown identity cannot displace resident art")
	var duplicate: Array[String] = [ids[0], ids[0]]
	check(not presenter.prepare_override_pages(duplicate), "duplicate identity refuses")
	equal(_published(body), published, "duplicate identity cannot change recency or pages")
	# An existing real page with a wrong digest exercises failure after actual IO,
	# without a missing-resource engine error or a partial visible replacement.
	var candidate: String = ids[20]
	var request: Array[String] = [candidate]
	for bank: RefCounted in [body, pixel, actions]:
		var definition: Dictionary = bank.entries[candidate]
		if bank == body: definition = definition.detail
		var digest: String = definition.rgba_sha256
		definition.rgba_sha256 = "0".repeat(64)
		check(not presenter.prepare_override_pages(request), "bad body, pixel or action page fails atomic preparation")
		equal(_published(body), published, "later page failure retains every old bank and profile")
		definition.rgba_sha256 = digest
	check(presenter.prepare_override_pages(request), "repaired requested identity can prepare normally")
	check(not pixel.configure_actions(null), "optional action bank can be explicitly unavailable")
	loads = _loads(body)
	for action: String in ["jump", "fall", "slide", "roll", "fly", "stunned", "defeated"]:
		var pose: Dictionary = pixel.rigid_fallback_frame(candidate, action, 2, 2, 0.0, false)
		check(not pose.is_empty() and pose.texture == pixel.textures[candidate], "missing action extension falls back to this identity's original pixel page")
	equal(_loads(body), loads, "optional-bank fallback never loads art while sampling")
	return finish("character-page-residency")

func _test_failed_startup(language: VisualLanguage) -> void:
	var rejected := RejectedStartup.new()
	check(not rejected.configure_fullbody_startup(language, false, true), "late failure on fresh startup publishes no metadata-only presenter")
	equal(rejected.last_error, "Synthetic late Fullbody refusal", "failure fixture actually reached the post-metadata Fullbody stage")
	check(rejected.champions.is_empty() and rejected.fullbody_art == null and rejected.wireframe_body.base_textures.is_empty(), "fresh failed startup leaves no apparently present characters")
	check(rejected.configure(language), "default eager configure remains an available real fallback after failed Fullbody request")
	var frame: Dictionary = rejected.movement_frame("oh_tipi", PlayerState.new(1), 0.0, SimConfig.new(120))
	check(not frame.is_empty() and bool(frame.get("wireframe_body", false)), "explicit eager fallback still renders real registered wireframe art")
	var texture: Texture2D = rejected.wireframe_body.base_texture("small")
	var before := rejected.content_hash
	var generation := rejected.configuration_generation
	check(not rejected.configure_fullbody_startup(language, false, true), "late failure during replacement refuses atomically")
	equal(rejected.last_error, "Synthetic late Fullbody refusal", "replacement failure comes from actual requested admission stage")
	check(rejected.wireframe_body.base_texture("small") == texture and rejected.fullbody_art == null, "late refusal preserves exact previous fallback texture")
	equal(rejected.content_hash, before, "late refusal preserves existing presentation identity")
	equal(rejected.configuration_generation, generation, "late refusal cannot invalidate working page preparation")
	check(rejected.can_present("oh_tipi"), "previous fallback remains available after late refusal")

func _loads(body: RefCounted) -> Array[int]:
	var pixel: RefCounted = body.pixel_pilot
	var result: Array[int] = []
	result.append(int(body.page_load_count))
	result.append(int(pixel.page_load_count))
	result.append(0 if pixel.action_bank == null else int(pixel.action_bank.page_load_count))
	return result

func _published(body: RefCounted) -> Dictionary:
	return {"body":body.textures.duplicate(), "keys":body.key_textures.duplicate(),
		"pixel":body.pixel_pilot.textures.duplicate(), "action":body.pixel_pilot.action_bank.textures.duplicate(),
		"profiles":body.pixel_pilot.aerial_profiles.duplicate(), "order":body.resident_order.duplicate()}
