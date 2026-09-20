extends SceneTree

const Harness = preload("res://tests/support/melee_capture_harness.gd")

const CHAMPIONS := [
	{"id": "s_wayne", "body": "small", "height": 58},
	{"id": "oh_tipi", "body": "middle", "height": 63},
	{"id": "red_baron", "body": "large", "height": 68},
]
const DIRECTIONS := [
	{"name": "south", "aim": Vector2i(0, 1000)},
	{"name": "south-east", "aim": Vector2i(707, 707)},
	{"name": "east", "aim": Vector2i(1000, 0)},
	{"name": "north-east", "aim": Vector2i(707, -707)},
	{"name": "north", "aim": Vector2i(0, -1000)},
	{"name": "north-west", "aim": Vector2i(-707, -707)},
	{"name": "west", "aim": Vector2i(-1000, 0)},
	{"name": "south-west", "aim": Vector2i(-707, 707)},
]
const ATTACKS := [
	{"kind": PhysicalAttackSystem.Kind.PUNCH, "name": "punch", "attachment": "hand_r"},
	{"kind": PhysicalAttackSystem.Kind.KICK, "name": "kick", "attachment": "toe_r"},
]
const EXACT_PROFILES := {
	PhysicalAttackSystem.Kind.PUNCH: {"stamina_cost": 14_000, "damage": 6000, "startup_ticks": 6, "active_ticks": 4, "recovery_ticks": 16},
	PhysicalAttackSystem.Kind.KICK: {"stamina_cost": 35_000, "damage": 12_000, "startup_ticks": 12, "active_ticks": 6, "recovery_ticks": 28},
}

var output: String = ""
var game: Node2D
var viewport: SubViewport
var records: Array[Dictionary] = []
var attack_receipts: Array[Dictionary] = []
var failed: bool = false
var paid_physical_attacks: int = 0
var infused_kick_receipt: Dictionary = {"status": "not_available"}


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	if not output.begins_with("res://.godot/gameplay-melee-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("fresh contained output required")
		return
	DirAccess.make_dir_recursive_absolute(output)
	game = Harness.new()
	if not game.configure_fixture(true):
		_fail("production fixture failed")
		return
	game.material_registry = MaterialRegistry.new()
	game.material_yard = MaterialYardDefinition.new()
	if not game.material_registry.load_from_file(game.MATERIAL_CATALOG_PATH) \
			or not game.material_yard.load_from_file(game.MATERIAL_YARD_PATH, game.material_registry):
		_fail("Hex Court material content failed")
		return
	game.player_preferences.set_camera_zoom_percent(75)
	game.preference_overrides_are_transient = true
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(game)
	if not _validate_profiles():
		return

	# Exactly 3 body sizes x 8 latched aim headings x 2 attacks. Every state is
	# reached through the real command, payment, timeline and first-contact path.
	for champion: Dictionary in CHAMPIONS:
		for direction: Dictionary in DIRECTIONS:
			for attack: Dictionary in ATTACKS:
				if not await _capture_paid_active(champion, direction, attack):
					return
	if paid_physical_attacks != 48 or attack_receipts.size() != 48 or records.size() != 48:
		_fail("the paid active matrix must contain exactly 48 authoritative states")
		return

	# Paired full/reduced gameplay frames cover the temporal and whiff/air cases
	# without inventing pose state. The before pair is the only unpaid reference.
	if not await _capture_representative_before(): return
	if not await _capture_representative_phase("startup", PhysicalAttackSystem.Phase.STARTUP): return
	if not await _capture_representative_phase("active", PhysicalAttackSystem.Phase.ACTIVE): return
	if not await _capture_representative_phase("recovery", PhysicalAttackSystem.Phase.RECOVERY): return
	if not await _capture_representative_whiff(): return
	if not await _capture_representative_air(): return
	if not await _capture_optional_infused_kick(): return
	if failed: return
	var expected_frames: int = 60 + (2 if String(infused_kick_receipt.get("status", "")) == "passed" else 0)
	if records.size() != expected_frames:
		_fail("unexpected frame total: %d instead of %d" % [records.size(), expected_frames])
		return
	var receipt: Dictionary = {
		"status": "passed",
		"scope": "native 1280x720 paid S5 physical presentation: 48 Active body-size/aim/attack states plus paired before/Startup/Active/Recovery/whiff/air normal-reduced views; optional S6 infused Kick only when the integrated authority is present",
		"boundary": "native capture and authority assertions; not human visual acceptance, rendered performance, networking, or release",
		"profile_contract": EXACT_PROFILES,
		"paid_physical_attacks": paid_physical_attacks,
		"active_matrix_receipts": attack_receipts,
		"optional_s6_infused_kick": infused_kick_receipt,
		"frames": records,
	}
	var file: FileAccess = FileAccess.open(output + "/capture-receipt.json", FileAccess.WRITE)
	if file == null:
		_fail("capture receipt could not be opened")
		return
	file.store_string(JSON.stringify(receipt, "  "))
	file.close()
	print("PASS: gameplay melee capture %d frames; %d paid physical attacks; S6 %s" % [records.size(), paid_physical_attacks, infused_kick_receipt.status])
	game.queue_free()
	await process_frame
	quit(0)


func _validate_profiles() -> bool:
	var tuning: PhysicalAttackTuning = PhysicalAttackTuning.shared()
	if not tuning.is_valid() or tuning.tick_rate != 120:
		_fail("physical attack tuning is unavailable")
		return false
	for kind: int in EXACT_PROFILES:
		var profile: Dictionary = tuning.profile(kind)
		for key: String in EXACT_PROFILES[kind]:
			if int(profile.get(key, -1)) != int(EXACT_PROFILES[kind][key]):
				_fail("physical profile drift: %d/%s" % [kind, key])
				return false
	return true


func _capture_paid_active(champion: Dictionary, direction: Dictionary, attack: Dictionary) -> bool:
	var aim: Vector2i = direction.aim
	var kind: int = int(attack.kind)
	if not game.reset_melee_fixture(String(champion.id), aim, kind, true):
		return _harness_fail("matrix reset")
	var actor: PlayerState = game.world.player(1)
	var target: PlayerState = game.world.player(game.TARGET_ID)
	var profile: Dictionary = PhysicalAttackTuning.shared().profile(kind)
	var before_hash: String = game.world.state_hash()
	var stamina_before: int = actor.stamina
	var health_before: int = target.health
	if not game.begin_physical(kind, aim):
		return _harness_fail("matrix start")
	if not _assert_started(actor, kind, aim, stamina_before, before_hash):
		return false
	var started_event: Dictionary = game.event_of_type("physical_attack_started")
	if not game.advance_to_phase(PhysicalAttackSystem.Phase.ACTIVE, aim, int(profile.startup_ticks) + 2):
		return _harness_fail("matrix Active")
	var contact: Dictionary = game.event_of_type("physical_attack_contact")
	if contact.is_empty() or int(contact.attacker_id) != actor.entity_id or int(contact.target_id) != target.entity_id \
			or int(contact.sequence_id) != actor.physical_sequence_id or int(contact.damage) != int(profile.damage) \
			or not bool(contact.first_contact) or target.health != health_before - int(profile.damage):
		_fail("real first contact failed for %s/%s/%s" % [champion.body, direction.name, attack.name])
		return false
	if actor.stamina != stamina_before - int(profile.stamina_cost):
		_fail("stamina changed again after admission")
		return false
	var frame: Dictionary = game.movement_frame(false)
	if not _assert_melee_frame(frame, champion, attack, direction, PhysicalAttackSystem.Phase.ACTIVE):
		return false
	paid_physical_attacks += 1
	var label: String = "active-%s-%s-%s" % [champion.body, direction.name, attack.name]
	attack_receipts.append({
		"file": label + ".png",
		"champion_id": champion.id,
		"body_type": champion.body,
		"display_height": champion.height,
		"direction": direction.name,
		"aim": [aim.x, aim.y],
		"attack": attack.name,
		"sequence_id": actor.physical_sequence_id,
		"press_tick": int(started_event.tick),
		"active_tick": game.world.tick,
		"stamina_before": stamina_before,
		"stamina_after": actor.stamina,
		"damage": int(contact.damage),
		"target_health_after": target.health,
		"canonical_state_hash": _canonical_state_hash(actor),
		"source_region": _rect_values(frame.source_region),
		"attachment_name": frame.attachment_name,
		"attachment_pixel": _vector2i_values(frame.attachment_pixel),
	})
	await _capture(label, false, {"case": "paid_active_matrix", "sequence_id": actor.physical_sequence_id})
	return not failed


func _capture_representative_before() -> bool:
	if not game.reset_melee_fixture("oh_tipi", Vector2i(1000, 0), PhysicalAttackSystem.Kind.PUNCH, true):
		return _harness_fail("before reset")
	var actor: PlayerState = game.world.player(1)
	if actor.physical_kind != 0 or actor.physical_phase != 0 or actor.physical_sequence_id != 0:
		_fail("before reference already owns physical state")
		return false
	await _capture_pair("representative-before", {"case": "unpaid_before_reference"})
	return not failed


func _capture_representative_phase(label: String, phase: int) -> bool:
	var kind: int = PhysicalAttackSystem.Kind.PUNCH if phase != PhysicalAttackSystem.Phase.RECOVERY else PhysicalAttackSystem.Kind.KICK
	var aim: Vector2i = Vector2i(1000, 0) if kind == PhysicalAttackSystem.Kind.PUNCH else Vector2i(0, 1000)
	if not game.reset_melee_fixture("oh_tipi" if kind == PhysicalAttackSystem.Kind.PUNCH else "red_baron", aim, kind, true):
		return _harness_fail(label + " reset")
	var actor: PlayerState = game.world.player(1)
	var stamina_before: int = actor.stamina
	if not game.begin_physical(kind, aim) or not _assert_started(actor, kind, aim, stamina_before, ""):
		return _harness_fail(label + " start") if not failed else false
	if phase != PhysicalAttackSystem.Phase.STARTUP and not game.advance_to_phase(phase, aim):
		return _harness_fail(label + " phase")
	if actor.physical_phase != phase:
		_fail("representative did not reach requested phase")
		return false
	var champion: Dictionary = CHAMPIONS[1] if kind == PhysicalAttackSystem.Kind.PUNCH else CHAMPIONS[2]
	var attack: Dictionary = ATTACKS[kind - 1]
	var direction: Dictionary = DIRECTIONS[2] if aim.x > 0 else DIRECTIONS[0]
	if not _assert_melee_frame(game.movement_frame(false), champion, attack, direction, phase):
		return false
	paid_physical_attacks += 1
	await _capture_pair("representative-" + label, {"case": "paid_" + label, "sequence_id": actor.physical_sequence_id})
	return not failed


func _capture_representative_whiff() -> bool:
	var aim: Vector2i = Vector2i(0, -1000)
	if not game.reset_melee_fixture("s_wayne", aim, PhysicalAttackSystem.Kind.KICK, false):
		return _harness_fail("whiff reset")
	var actor: PlayerState = game.world.player(1)
	var target: PlayerState = game.world.player(game.TARGET_ID)
	var health_before: int = target.health
	var stamina_before: int = actor.stamina
	if not game.begin_physical(PhysicalAttackSystem.Kind.KICK, aim) or not _assert_started(actor, PhysicalAttackSystem.Kind.KICK, aim, stamina_before, ""):
		return _harness_fail("whiff start") if not failed else false
	if not game.advance_to_phase(PhysicalAttackSystem.Phase.ACTIVE, aim):
		return _harness_fail("whiff Active")
	if not game.event_of_type("physical_attack_contact").is_empty() or target.health != health_before:
		_fail("out-of-range Kick did not remain an authoritative whiff")
		return false
	if not _assert_melee_frame(game.movement_frame(false), CHAMPIONS[0], ATTACKS[1], DIRECTIONS[4], PhysicalAttackSystem.Phase.ACTIVE):
		return false
	paid_physical_attacks += 1
	await _capture_pair("representative-whiff", {"case": "paid_whiff", "sequence_id": actor.physical_sequence_id})
	return not failed


func _capture_representative_air() -> bool:
	var aim: Vector2i = Vector2i(-707, -707)
	if not game.reset_melee_fixture("oh_tipi", aim, PhysicalAttackSystem.Kind.PUNCH, false):
		return _harness_fail("air reset")
	if not game.jump(aim):
		return _harness_fail("real jump")
	var actor: PlayerState = game.world.player(1)
	if not actor.is_airborne():
		_fail("jump command did not produce canonical air state")
		return false
	var stamina_before: int = actor.stamina
	if not game.begin_physical(PhysicalAttackSystem.Kind.PUNCH, aim) or not _assert_started(actor, PhysicalAttackSystem.Kind.PUNCH, aim, stamina_before, ""):
		return _harness_fail("air Punch start") if not failed else false
	if not game.advance_to_phase(PhysicalAttackSystem.Phase.ACTIVE, aim):
		return _harness_fail("air Punch Active")
	if not actor.is_airborne() or actor.air_height <= 0:
		_fail("paid Punch did not retain actual airborne state through Active")
		return false
	if not _assert_melee_frame(game.movement_frame(false), CHAMPIONS[1], ATTACKS[0], DIRECTIONS[5], PhysicalAttackSystem.Phase.ACTIVE):
		return false
	paid_physical_attacks += 1
	await _capture_pair("representative-air", {"case": "paid_air", "sequence_id": actor.physical_sequence_id, "air_height": actor.air_height})
	return not failed


func _capture_optional_infused_kick() -> bool:
	if not ResourceLoader.exists("res://src/sim/combat/melee_infusion_system.gd"):
		infused_kick_receipt = {"status": "not_available", "reason": "integrated S6 system resource absent"}
		return true
	if not game.reset_infusion_fixture():
		return _harness_fail("S6 fixture reset")
	var court: Variant = game.world.hex_court
	if court == null or not court.has_method("reserve_infusion") or not court.has_method("release_infusion"):
		infused_kick_receipt = {"status": "not_available", "reason": "integrated S6 Hex Court authority absent"}
		return true
	var actor: PlayerState = game.world.player(1)
	var target: PlayerState = game.world.player(game.TARGET_ID)
	var slot: int = _supported_infusion_slot(actor)
	if slot <= 0:
		_fail("integrated S6 exists but the real actor has no supported Water/Fire slot")
		return false
	var wire_id: int = actor.spell_wire_id(slot)
	var before_point: Vector2i = Vector2i(target.position_x, target.position_y)
	var pre_cell: Vector2i = HexGrid.world_to_cell(before_point - HexCourt.ORIGIN)
	var stamina_before: int = actor.stamina
	var flux_before: int = actor.flux
	var matter_before: int = int(court.metrics.matter_paid)
	var extra_pressed: int = int(SimCommand.SPELL_PRESSED_BITS[slot - 1])
	if not game.begin_physical(PhysicalAttackSystem.Kind.KICK, Vector2i(1000, 0), extra_pressed):
		return _harness_fail("combined Kick/infusion command")
	var accepted: Dictionary = game.event_of_type("melee_infusion_accepted")
	if accepted.is_empty() or actor.flux != flux_before - 4000 or int(court.metrics.matter_paid) != matter_before + 180:
		_fail("integrated S6 did not accept and pay exactly one same-tick infusion")
		return false
	if not _assert_started(actor, PhysicalAttackSystem.Kind.KICK, Vector2i(1000, 0), stamina_before, ""):
		return false
	if not game.advance_to_phase(PhysicalAttackSystem.Phase.ACTIVE, Vector2i(1000, 0)):
		return _harness_fail("infused Kick Active")
	var contact: Dictionary = game.event_of_type("physical_attack_contact")
	var released: Dictionary = game.event_of_type("melee_infusion_released")
	var post_point: Vector2i = Vector2i(target.position_x, target.position_y)
	var post_cell: Vector2i = HexGrid.world_to_cell(post_point - HexCourt.ORIGIN)
	var source_id: int = int(accepted.get("source_id", 0))
	var cast_id: int = int(court.sources.get(source_id, 0))
	var cast: Dictionary = court.casts.get(cast_id, {})
	var cast_cells: Dictionary = cast.get("cells", {})
	if contact.is_empty() or released.is_empty() or contact.get("target_position_before_knockback") != before_point \
			or int(released.get("x", -1)) != before_point.x or int(released.get("y", -1)) != before_point.y \
			or post_point == before_point or pre_cell == post_cell:
		_fail("S6 contact did not preserve a distinct pre-push Hex point")
		return false
	if cast.is_empty() or int(cast.get("budget", 0)) != 180 or int(cast.get("ground", 0)) != 180 \
			or int(cast.get("unallocated", -1)) != 0 or int(cast_cells.get(pre_cell, 0)) != 180 \
			or int(cast_cells.get(post_cell, 0)) != 0 or not court.conservation_valid():
		_fail("S6 finite material ledger did not deposit 180 at only the pre-push Hex")
		return false
	if not _assert_melee_frame(game.movement_frame(false), CHAMPIONS[1], ATTACKS[1], DIRECTIONS[2], PhysicalAttackSystem.Phase.ACTIVE):
		return false
	paid_physical_attacks += 1
	infused_kick_receipt = {
		"status": "passed",
		"slot": slot,
		"wire_id": wire_id,
		"source_id": source_id,
		"cast_id": cast_id,
		"physical_sequence_id": actor.physical_sequence_id,
		"stamina_cost": stamina_before - actor.stamina,
		"fixed_flux_cost": flux_before - actor.flux,
		"matter_paid": 180,
		"pre_push_point": [before_point.x, before_point.y],
		"post_push_point": [post_point.x, post_point.y],
		"pre_push_hex": [pre_cell.x, pre_cell.y],
		"post_push_hex": [post_cell.x, post_cell.y],
		"cells": HexCourt._stable(cast.cells),
	}
	await _capture_pair("optional-s6-infused-kick", {"case": "paid_infused_kick", "source_id": source_id, "pre_push_hex": [pre_cell.x, pre_cell.y]})
	return not failed


func _assert_started(actor: PlayerState, kind: int, aim: Vector2i, stamina_before: int, before_hash: String) -> bool:
	var profile: Dictionary = PhysicalAttackTuning.shared().profile(kind)
	var event: Dictionary = game.event_of_type("physical_attack_started")
	if event.is_empty() or actor.physical_kind != kind or actor.physical_phase != PhysicalAttackSystem.Phase.STARTUP \
			or actor.physical_phase_ticks_remaining != int(profile.startup_ticks) or actor.physical_phase_ticks_total != int(profile.startup_ticks) \
			or Vector2i(actor.physical_aim_x, actor.physical_aim_y) != aim or actor.physical_sequence_id <= 0 \
			or int(event.get("sequence_id", 0)) != actor.physical_sequence_id or int(event.get("stamina_cost", 0)) != int(profile.stamina_cost) \
			or actor.stamina != stamina_before - int(profile.stamina_cost):
		_fail("real paid physical start/canonical state mismatch")
		return false
	if not before_hash.is_empty() and game.world.state_hash() == before_hash:
		_fail("physical command did not change canonical world state")
		return false
	return true


func _assert_melee_frame(frame: Dictionary, champion: Dictionary, attack: Dictionary, direction: Dictionary, phase: int) -> bool:
	var point: Variant = frame.get("attachment_point", Vector2.INF)
	var pixel: Variant = frame.get("attachment_pixel", Vector2i(-1, -1))
	if frame.is_empty() or not bool(frame.get("melee_body", false)) or frame.get("texture") == null \
			or not (frame.get("source_region", Rect2()) as Rect2).has_area() \
			or int(frame.get("physical_kind", 0)) != int(attack.kind) or int(frame.get("physical_phase", 0)) != phase \
			or int(frame.get("aim_index", -1)) != EightDirectionResolver.classify_index(int(direction.aim.x), int(direction.aim.y)) \
			or int(frame.get("body_height", 0)) != int(champion.height) or int(frame.get("display_height", 0)) != int(champion.height) \
			or not bool(frame.get("attachment_available", false)) or String(frame.get("attachment_name", "")) != String(attack.attachment) \
			or not (point is Vector2) or not (point as Vector2).is_finite() or not (pixel is Vector2i) \
			or (pixel as Vector2i).x < 0 or (pixel as Vector2i).x >= 96 or (pixel as Vector2i).y < 0 or (pixel as Vector2i).y >= 96:
		_fail("melee body frame or exact rig attachment is unavailable")
		return false
	return true


func _capture_pair(label: String, extra: Dictionary) -> void:
	await _capture(label + "-normal", false, extra)
	if failed: return
	await _capture(label + "-reduced", true, extra)


func _capture(label: String, reduced: bool, extra: Dictionary = {}) -> void:
	game.requested_capture_reduced_effects = reduced
	game.player_preferences.reduced_motion = reduced
	var before: String = game.world.state_hash()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = viewport.get_texture().get_image()
	if frame == null or frame.is_empty() or frame.get_size() != Vector2i(1280, 720) \
			or frame.save_png(output + "/" + label + ".png") != OK or game.world.state_hash() != before:
		_fail("native capture failed or mutated authority: " + label)
		return
	var actor: PlayerState = game.world.player(1)
	var record: Dictionary = {
		"file": label + ".png",
		"tick": game.world.tick,
		"world_hash": before,
		"reduced": reduced,
		"champion_id": game.selected_champion_id,
		"physical_kind": actor.physical_kind,
		"physical_phase": actor.physical_phase,
		"physical_phase_ticks_remaining": actor.physical_phase_ticks_remaining,
		"physical_phase_ticks_total": actor.physical_phase_ticks_total,
		"latched_aim": [actor.physical_aim_x, actor.physical_aim_y],
		"stamina": actor.stamina,
		"air_height": actor.air_height,
	}
	record.merge(extra.duplicate(true), true)
	records.append(record)
	game.requested_capture_reduced_effects = false
	game.player_preferences.reduced_motion = false


func _supported_infusion_slot(actor: PlayerState) -> int:
	for slot: int in range(1, PlayerState.SPELL_SLOT_COUNT + 1):
		var definition: Dictionary = CombatTuning.cast_definition(actor.spell_wire_id(slot))
		if int(definition.get("element_wire_id", 0)) in [2, 3]:
			return slot
	return 0


static func _canonical_state_hash(actor: PlayerState) -> String:
	return JSON.stringify(actor.canonical_values()).sha256_text()


static func _rect_values(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


static func _vector2i_values(value: Vector2i) -> Array:
	return [value.x, value.y]


func _harness_fail(context: String) -> bool:
	_fail(context + ": " + str(game.last_error))
	return false


func _fail(message: String) -> void:
	if failed:
		return
	failed = true
	push_error(message)
	if game != null:
		game.queue_free()
	quit(1)
