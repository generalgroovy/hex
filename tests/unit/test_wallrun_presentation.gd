extends FluxTestSuite

const Fullbody = preload("res://src/presentation/fullbody_cast_presenter.gd")
const WallPose = preload("res://src/presentation/pixel_wallrun_pose.gd")
const NORMALS := [Vector2i(1000, 0), Vector2i(-1000, 0), Vector2i(0, 1000), Vector2i(0, -1000),
	Vector2i(866, 500), Vector2i(866, -500), Vector2i(-866, 500), Vector2i(-866, -500)]


func run() -> int:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "wall presentation loads live spell roster")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "wall presentation loads actual thirty identities")
	var ids := champions.ordered_champion_ids()
	var presenter := Fullbody.new()
	check(presenter.configure(ids) and presenter.enable_pixel_pilot(ids, true), "original full-body and native banks remain admitted")
	if presenter.pixel_pilot == null: return finish("wallrun-presentation")
	var config := SimConfig.new(120)
	for id: String in ids:
		var state := PlayerState.new(1)
		check(champions.apply_to_player(state, id), "wall test uses current identity without changing size or flight permission")
		state.spawn_protection_ticks = 0
		for normal: Vector2i in NORMALS:
			for sign_value: int in [-1, 1]:
				_prepare_wall(state, normal, sign_value, config)
				var travel := EightDirectionResolver.classify_index(state.wall_skim_x, state.wall_skim_y)
				var n := Vector2(normal).normalized()
				for reduced: bool in [false, true]:
					for sample: int in 4:
						var phase: float = [0.0, 0.25, 0.5, 0.75][sample]
						var aim := posmod(travel + sample + 2, 8)
						state.aim_x = EightDirectionResolver.FIXED_VECTORS[aim].x
						state.aim_y = EightDirectionResolver.FIXED_VECTORS[aim].y
						var before := state.canonical_values()
						var frame: Dictionary = presenter.frame(id, state, 9999, config, phase, reduced)
						check(frame.get("wallrun_pose", false), "actual attached wallrun uses the dedicated whole-body contact route")
						if not frame.get("wallrun_pose", false): continue
						var expected_row: int = 0 if reduced else [1, 0, 2, 0][sample]
						equal(frame.source_region, Rect2(travel * 128, expected_row * 128, 128, 128), "entire native contact key keeps the true wall tangent facing")
						equal(frame.texture, presenter.pixel_pilot.textures[id], "wall support preserves exactly this character's original body texture")
						equal(frame.aim_index, aim, "independent immediate spell aim is still exposed while body faces travel")
						equal(frame.travel_index, travel, "all mirrored cardinals and hex faces retain actual tangent travel")
						check(absf(float(frame.wall_lean_radians) + n.x * deg_to_rad(11.0)) < 0.00001, "rigid body lean is bounded and directed toward this wall, never toward the cursor")
						equal(frame.pivot, Vector2(64, 104), "wall lean retains the exact original foot pivot")
						equal(frame.offset, Vector2.ZERO, "wall presentation never translates the physical foot anchor")
						check(not frame.has("mesh") and not frame.has("pixel_parts") and frame.components.is_empty(), "wall body has no mesh deformation or hidden upright duplicate")
						equal(frame.wall_parts.size(),3,"torso and two native foot regions partition the contact key")
						equal(frame.wall_contact_offset,(-n*3).round(),"all wall normals have a visible planted foot offset")
						check((frame.wall_contact_offset as Vector2).length()>0,"north/south walls cannot collapse to an ordinary running silhouette")
						check(not frame.all_action_art_complete and not frame.independent_cast_pose, "reused contact art explicitly retains its authored-animation and casting-hand limitations")
						var bounds: Rect2 = frame.body_bounds
						for corner: Vector2 in [Vector2(-64, -104), Vector2(64, -104), Vector2(64, 24), Vector2(-64, 24)]:
							check(bounds.grow(0.001).has_point(corner.rotated(float(frame.wall_lean_radians))), "declared wall bounds enclose every transformed native cell corner")
						var unrelated_clock: Dictionary = presenter.frame(id, state, -500, config, phase, reduced)
						equal(unrelated_clock, frame, "global render time cannot restart a distance-owned wall pose")
						equal(state.canonical_values(), before, "wall frame leaves all authority, resources and timers unchanged")
				_test_contact(state, config)
		_test_blocked_and_exit(presenter, id, state, config)
	equal(ids.size(), 30, "wall matrix includes the entire live identity roster")
	_test_invalid(presenter, ids[0], config)
	return finish("wallrun-presentation")


func _prepare_wall(state: PlayerState, normal: Vector2i, sign_value: int, config: SimConfig) -> void:
	state.health = state.health_maximum
	state.control_state = PlayerState.ControlState.FREE
	state.movement_mode = PlayerState.MovementMode.WALL_SKIM
	state.hop_mode = PlayerState.MovementMode.WALL_SKIM
	state.wall_skim_ticks = config.milliseconds_to_ticks(MovementTuning.WALL_SKIM_DURATION_MS)
	state.wall_skim_surface_id = 7
	state.wall_x = normal.x
	state.wall_y = normal.y
	state.wall_skim_x = -normal.y * sign_value
	state.wall_skim_y = normal.x * sign_value
	state.velocity_x = state.wall_skim_x * 300
	state.velocity_y = state.wall_skim_y * 300
	state.air_height = 40_000
	state.air_vertical_velocity = 0
	state.air_dodge_ticks = 0
	state.impact_recovery_ticks = 0
	state.jumpsquat_active = false


func _test_contact(state: PlayerState, config: SimConfig) -> void:
	var before := state.canonical_values()
	var floor_anchor := Vector2(200, 300)
	var body_anchor := Vector2(200, 260)
	var contact := CartoonChampionPresenter.wall_attachment_contract(state, config, body_anchor, floor_anchor)
	check(not contact.is_empty(), "real attachment has a surface contact and finite-budget strip")
	if contact.is_empty(): return
	var normal := Vector2(state.wall_x, state.wall_y).normalized()
	check((contact.contact as Vector2).distance_to(body_anchor - normal * 18.0) < 0.00001, "wall contact sits on the same elevated plane as the actual body at common18px wall clearance")
	check(((contact.floor_contact as Vector2) - (contact.contact as Vector2)).distance_to(Vector2(0, 40)) <= 0.001, "ground projection preserves forty pixels of height within subpixel arithmetic tolerance")
	equal(contact.segments, 3, "fresh paid attachment exposes all three finite wall-budget segments")
	state.wall_skim_ticks = 1
	var last := CartoonChampionPresenter.wall_attachment_contract(state, config, body_anchor, floor_anchor)
	equal(last.segments, 1, "last positive wall tick retains one segment without a visual tail")
	state.wall_skim_ticks = 0
	check(CartoonChampionPresenter.wall_attachment_contract(state, config, body_anchor, floor_anchor).is_empty(), "exact attachment expiry removes contact, brace and budget")
	state.wall_skim_ticks = config.milliseconds_to_ticks(MovementTuning.WALL_SKIM_DURATION_MS)
	equal(state.canonical_values(), before, "contact queries and restored boundary fixtures preserve complete authority")


func _test_blocked_and_exit(presenter: RefCounted, id: String, state: PlayerState, config: SimConfig) -> void:
	_prepare_wall(state, Vector2i(1000, 0), 1, config)
	state.velocity_x = 0
	state.velocity_y = 0
	var facing := Vector2i(state.wall_skim_x, state.wall_skim_y)
	var first: Dictionary = presenter.frame(id, state, 0, config, 0.15, false, facing)
	check(first.get("wall_braced", false), "blocked attachment is explicitly a braced pose")
	for phase: float in [0.0, 0.25, 0.5, 0.75]:
		var blocked: Dictionary = presenter.frame(id, state, 999, config, phase, false, facing)
		equal(blocked.source_region, first.source_region, "zero physical travel cannot march even if an inspection phase changes")
		equal(blocked.wall_lean_radians, first.wall_lean_radians, "blocked body holds one stable wall-directed brace")
	for control: int in [PlayerState.ControlState.LAUNCHED, PlayerState.ControlState.GRAPPLED, PlayerState.ControlState.STUNNED, PlayerState.ControlState.ROOTED, PlayerState.ControlState.CHARGING]:
		state.control_state = control
		check(not presenter.frame(id, state, 0, config, 0.0).get("wallrun_pose", false), "forced control wins immediately over stale attachment timers")
		check(CartoonChampionPresenter.wall_contact_geometry(state).is_empty(), "forced control cannot retain a misleading wall-contact cue")
	state.control_state = PlayerState.ControlState.FREE
	state.health = 0
	check(not presenter.frame(id, state, 0, config, 0.0).get("wallrun_pose", false), "defeat removes attached body presentation immediately")
	state.health = state.health_maximum
	state.wall_skim_ticks = 0
	state.hop_mode = PlayerState.MovementMode.WALL_KICK
	state.movement_mode = PlayerState.MovementMode.WALL_KICK
	state.air_vertical_velocity = 520_000
	check(not presenter.frame(id, state, 0, config, 0.0).get("wallrun_pose", false), "wall jump immediately returns to the actual aerial identity policy")
	check(not CartoonChampionPresenter.protection_contract(state, config).active, "wall contact and release never advertise new invulnerability")


func _test_invalid(presenter: RefCounted, id: String, config: SimConfig) -> void:
	var state := PlayerState.new(1)
	_prepare_wall(state, Vector2i(1000, 0), 1, config)
	state.wall_skim_surface_id = 0
	check(not presenter.frame(id, state, 0, config, 0.0).get("wallrun_pose", false), "timer alone cannot manufacture an attachment without its real surface")
	state.wall_skim_surface_id = 1
	state.wall_x = 0
	state.wall_y = 0
	check(not presenter.frame(id, state, 0, config, 0.0).get("wallrun_pose", false), "missing contact normal cannot manufacture wall-side lean")
	check(presenter.pixel_pilot.wallrun_frame(id, 0, 0, NAN, Vector2.RIGHT, true, false).is_empty(), "nonfinite inspection phase fails closed")
	check(presenter.pixel_pilot.wallrun_frame(id, 0, 0, 0, Vector2(INF, 0), true, false).is_empty(), "nonfinite wall normal fails closed")
	check(CartoonChampionPresenter.wall_attachment_contract(state, SimConfig.new(0), Vector2.ZERO, Vector2.ZERO).is_empty(), "invalid tick rate cannot fabricate budget segments")
