extends FluxTestSuite
## Presentation continuity only; the real paid chain remains simulation-owned.

const Fullbody = preload("res://src/presentation/fullbody_cast_presenter.gd")
const Pixels = preload("res://src/presentation/pixel_flipbook_presenter.gd")
const Actions = preload("res://src/presentation/pixel_action_bank.gd")
const AerialChecks = preload("res://tests/support/native_aerial_assertions.gd")
const CATALOG := "res://content/champions/foundation_champions_v1.json"
const BODY_IDS := ["s_wayne", "oh_tipi", "red_baron"]


func run() -> int:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var ids: Array = []
	for champion: Dictionary in catalog.champions:
		ids.append(champion.id)
	var presenter := Fullbody.new()
	var admitted := presenter.configure(ids)
	check(admitted, "cast continuity admits the unchanged fullbody fallback: " + presenter.last_error)
	if not admitted: return finish("pixel-cast-continuity")
	admitted = presenter.enable_pixel_pilot(ids, true)
	check(admitted, "cast continuity admits the live fixed-pixel bank: " + presenter.last_error)
	if not admitted: return finish("pixel-cast-continuity")
	_test_paid_chain(presenter)
	_test_pose_matrix(presenter)
	_test_interruptions_and_fallback(presenter)
	_test_action_keys(presenter)
	_test_rigid_action_transitions(presenter)
	_test_full_roster_registration(presenter, ids)
	_test_missing_action_bank(presenter)
	return finish("pixel-cast-continuity")


func _test_paid_chain(presenter: RefCounted) -> void:
	var world := SimWorld.new(120)
	var state := world.player()
	var abilities := AbilityCatalog.new()
	var champions := ChampionCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "paid chain loads canonical abilities")
	check(champions.load_from_file(CATALOG, abilities), "paid chain loads canonical champions")
	check(champions.apply_to_player(state, "oh_tipi"), "paid chain applies the actual Oh Tipi kit")
	var first_wire := state.spell_wire_id(1)
	var next_wire := state.spell_wire_id(2)
	check(first_wire != next_wire and first_wire > 0 and next_wire > 0, "chain uses two distinct equipped spells")
	var before_flux := state.flux
	check(world.step([SimCommand.new(world.tick, state.entity_id, 0, 0, 0, SimCommand.PRESSED_SPELL_1)]), "first paid startup steps")
	equal(state.pending_cast_wire_id, first_wire, "actual first spell owns startup")
	equal(state.flux, before_flux - int(CombatTuning.cast_definition(first_wire).flux_cost), "first cast pays its ordinary Flux cost")
	var frame: Dictionary = presenter.frame("oh_tipi", state, float(world.tick), world.config, 0.25)
	check(not frame.get("cast_frame", true), "fresh first startup keeps its existing zero-weight ordinary upper row")
	for _step_index: int in 240:
		if state.pending_cast_wire_id == 0: break
		check(world.step([SimCommand.new(world.tick, state.entity_id)]), "first startup advances through the real combat pipeline")
	check(state.pending_cast_wire_id == 0 and state.cast_recovery_ticks > 1, "real release supplies a live recovery window")
	if state.pending_cast_wire_id != 0 or state.cast_recovery_ticks <= 1: return
	frame = presenter.frame("oh_tipi", state, float(world.tick), world.config, 0.25)
	check(frame.get("cast_frame", false), "released cast holds the authored recovery row")
	var recovery := state.cast_recovery_ticks
	before_flux = state.flux
	check(world.step([SimCommand.new(world.tick, state.entity_id, 0, 0, 0, SimCommand.PRESSED_SPELL_2)]), "next paid cast legally starts during recovery")
	equal(state.pending_cast_wire_id, next_wire, "next actual spell owns startup without a global recovery lock")
	equal(state.pending_cast_ticks, _startup_ticks(next_wire, world.config), "overlap is the exact zero-phase startup sample")
	equal(state.cast_recovery_ticks, recovery - 1, "combat alone advances the prior recovery timer")
	equal(state.flux, before_flux - int(CombatTuning.cast_definition(next_wire).flux_cost), "chained cast pays its ordinary Flux cost")
	check(world.combat_events.any(func(event: Dictionary) -> bool: return event.get("type") == "cast_started" and event.get("wire_id") == next_wire), "ordinary admission emits the next real cast start")
	var before := state.canonical_values()
	frame = presenter.frame("oh_tipi", state, float(world.tick), world.config, 0.25)
	check(frame.get("cast_frame", false), "uninterrupted recovery-to-startup handoff has no ordinary upper-row flash")
	equal(state.canonical_values(), before, "presentation cannot spend Flux, extend recovery or advance startup")
	check(world.step([SimCommand.new(world.tick, state.entity_id)]), "next startup advances normally after the handoff")
	frame = presenter.frame("oh_tipi", state, float(world.tick), world.config, 0.25)
	check(frame.get("cast_frame", false), "the next positive startup sample keeps the same authored cast row")


func _test_pose_matrix(presenter: RefCounted) -> void:
	var config := SimConfig.new(120)
	var wire := CombatTuning.RILLSHOT_WIRE_ID
	var startup := _startup_ticks(wire, config)
	check(startup > 1, "continuity fixture has separate zero and positive startup samples")
	for id: String in BODY_IDS:
		for action: String in ["idle", "walk", "sprint"]:
			for aim: int in 8:
				for step: int in 4:
					for reduced: bool in [false, true]:
						var state := _state(action, aim)
						var phase := float(step) / 4.0
						var plain: Dictionary = presenter.frame(id, state, 40.0, config, phase, reduced)
						state.pending_cast_wire_id = wire
						state.pending_cast_ticks = startup
						var fresh: Dictionary = presenter.frame(id, state, 40.0, config, phase, reduced)
						equal(fresh, plain, "fresh zero-weight startup remains byte-for-byte the same frame description")
						state.cast_recovery_ticks = 1
						var before := state.canonical_values()
						var chained: Dictionary = presenter.frame(id, state, 40.0, config, phase, reduced)
						check(chained.get("cast_frame", false), "even the final live recovery tick bridges the zero-phase startup")
						equal(chained.get("components", [])[0], plain.get("components", [])[0], "handoff preserves the exact distance-owned lower-body blit")
						equal(chained.components[1].source_region, Rect2(aim * 128, 384, 128, int(presenter.pixel_pilot.entries[id].waist_y)), "handoff selects existing cast pixels in the current live aim column")
						for key: String in ["action", "aim_index", "travel_index", "motion_phase", "sample_phase", "gait_mode", "lower_facing", "cell_size", "pivot", "offset", "display_height"]:
							equal(chained.get(key), plain.get(key), "cast continuity leaves movement and registration untouched: " + key)
						for forbidden: String in ["mesh", "render_mesh", "scale", "rotation", "pose_blend"]:
							check(not chained.has(forbidden), "the handoff cannot add body deformation: " + forbidden)
						equal(state.canonical_values(), before, "repeated direction/phase/reduced-motion queries preserve authority")
						state.cast_recovery_ticks = 0
						equal(presenter.frame(id, state, 40.0, config, phase, reduced), fresh, "expired recovery cannot latch a cast row onto zero-weight startup")
						state.pending_cast_ticks = startup - 1
						var advanced: Dictionary = presenter.frame(id, state, 40.0, config, phase, reduced)
						check(advanced.get("cast_frame", false), "ordinary positive startup remains visible without recovery")
						state.pending_cast_wire_id = 0
						state.pending_cast_ticks = 0
						equal(presenter.frame(id, state, 40.0, config, phase, reduced), plain, "both authoritative windows ending restores the exact ordinary frame")
	# The historical six-row pilot shares the fix without changing its schema.
	var live_bank: RefCounted = presenter.pixel_pilot
	var pilot := Pixels.new()
	check(pilot.configure(BODY_IDS, false), "historical pilot still admits independently")
	presenter.pixel_pilot = pilot
	var state := _state("walk", 6)
	state.pending_cast_wire_id = wire
	state.pending_cast_ticks = startup
	state.cast_recovery_ticks = 1
	var historical: Dictionary = presenter.frame("s_wayne", state, 40.0, config, 0.25)
	check(historical.get("cast_frame", false), "historical pilot also bridges only the live overlap")
	equal(historical.components[1].source_region.position.y, 640.0, "historical pilot retains its existing sixth cast row")
	presenter.pixel_pilot = live_bank


func _test_interruptions_and_fallback(presenter: RefCounted) -> void:
	var config := SimConfig.new(120)
	var live_bank: RefCounted = presenter.pixel_pilot
	for action: String in ["hit", "stunned", "defeated", "slide"]:
		var state := _state("walk", 2)
		state.pending_cast_wire_id = CombatTuning.RILLSHOT_WIRE_ID
		state.pending_cast_ticks = _startup_ticks(state.pending_cast_wire_id, config)
		state.cast_recovery_ticks = 5
		match action:
			"hit": state.control_state = PlayerState.ControlState.LAUNCHED
			"stunned": state.control_state = PlayerState.ControlState.STUNNED
			"defeated": state.health = 0
			"slide":
				state.movement_mode = PlayerState.MovementMode.SLIDE
				state.slide_ticks = 12
				state.slide_x = 1000
		var before := state.canonical_values()
		var fallback: Dictionary = presenter.frame("oh_tipi", state, 40.0, config, 0.25)
		check(fallback.get("rigid_pose_fallback", false) and not fallback.has("mesh") and not fallback.has("render_mesh"), "unpainted interruption/slide stays in fixed-pixel anatomy")
		equal(fallback.get("action"), action, "actual interruption or unsupported action remains immediate")
		check(not fallback.get("independent_cast_pose", true), "reused low keys never invent independent casting hands")
		equal(fallback.get("cast_overlay_requested"), action == "slide", "hit, stun and defeat still suppress cast presentation requests")
		presenter.pixel_pilot = null
		var legacy: Dictionary = presenter.frame("oh_tipi", state, 40.0, config, 0.25)
		check(legacy.has("mesh") and legacy.has("render_mesh"), "explicit non-pixel mode still retains its original legacy renderer")
		equal(legacy.get("cast_weight"), 0.0, "explicit legacy mode keeps the original zero-phase startup envelope")
		presenter.pixel_pilot = live_bank
		equal(state.canonical_values(), before, "interruptions and fallback sampling leave authority unchanged")


func _test_action_keys(presenter: RefCounted) -> void:
	var bank: RefCounted = presenter.pixel_pilot.action_bank
	check(bank != null, "continuity fixture retains admitted authored jump keys")
	if bank == null: return
	var config := SimConfig.new(120)
	for id: String in BODY_IDS:
		var state := _state("walk", 4)
		state.movement_mode = PlayerState.MovementMode.HOP
		state.hop_mode = PlayerState.MovementMode.HOP
		state.hop_ticks = 12
		state.air_height = 24000
		state.air_vertical_velocity = 30000
		state.pending_cast_wire_id = CombatTuning.RILLSHOT_WIRE_ID
		state.pending_cast_ticks = _startup_ticks(state.pending_cast_wire_id, config)
		var before: Dictionary = presenter.frame(id, state, 40.0, config, 0.25)
		state.cast_recovery_ticks = 1
		var authority := state.canonical_values()
		var overlap: Dictionary = presenter.frame(id, state, 40.0, config, 0.25)
		equal(overlap, before, "native aerial assembly priority and pixels are unchanged by cast overlap")
		AerialChecks.assert_frame(self, overlap, presenter.pixel_pilot, id, "jump", 4)
		check(not overlap.get("independent_cast_pose", false), "continuity does not invent an airborne upper-body pose")
		check(not overlap.get("all_action_art_complete", true), "held keys do not claim complete animation coverage")
		equal(state.canonical_values(), authority, "air-key query cannot alter actual airborne exposure")


func _test_rigid_action_transitions(presenter: RefCounted) -> void:
	var config := SimConfig.new(120)
	var mesh_count: int = presenter.meshes.size()
	var stream_count: int = presenter.render_meshes.size()
	var actions := ["idle", "walk", "sprint", "crouch", "jumpsquat", "jump",
		"double_jump", "walljump", "slide_jump", "fall", "fast_fall", "land",
		"slide", "wavedash", "roll", "air_dodge", "wallrun", "fly", "cast",
		"rooted", "hit", "stunned", "defeated"]
	for id: String in BODY_IDS:
		for aim: int in 8:
			for travel: int in 8:
				for reduced: bool in [false, true]:
					var ordinary := _motion_state("walk", aim, travel)
					var reference: Dictionary = presenter.frame(id, ordinary, 60.0, config, 0.375, reduced)
					for action: String in actions:
						var state := _motion_state(action, aim, travel)
						var authority := state.canonical_values()
						var frame: Dictionary = presenter.frame(id, state, 60.0, config, 0.375, reduced)
						equal(frame.get("action"), action, "every actual state remains immediate through pixel transitions")
						equal(frame.get("visual_mode"), "pixel_cast", "all states preserve the admitted pixel identity and style")
						equal(frame.get("aim_index"), aim, "all-state rendering retains instantaneous independent aim B")
						equal(frame.get("travel_index"), aim if action in ["idle", "land"] else travel, "all-state rendering retains independent travel A")
						for forbidden: String in ["mesh", "render_mesh", "pose_blend", "rotation", "scale"]:
							check(not frame.has(forbidden), "pixel-state transitions never introduce body deformation: " + forbidden)
						var aerial := action == "fly" or action in AerialChecks.BALL_ACTIONS
						if aerial:
							AerialChecks.assert_frame(self, frame, presenter.pixel_pilot, id, action, aim)
						else:
							equal(frame.get("pivot"), Pixels.PIVOT, "native atlas states share one unshifted ground anchor")
						equal(frame.get("offset"), Vector2.ZERO, "state changes add no procedural bob or camera-relative displacement")
						for component: Dictionary in frame.get("components", []):
							equal(component.source_region.size, component.destination_region.size, "every body pixel keeps its native aspect and size")
						if aerial:
							var held: Dictionary = presenter.frame(id, state, 69.999, config, 0.875, reduced)
							equal(held.pixel_parts, frame.pixel_parts, "unchanged physical authority holds exact native aerial geometry despite unrelated global time")
							var later: Dictionary = presenter.frame(id, state, 7000.0, config, 0.875, reduced)
							equal(later.pixel_parts, frame.pixel_parts, "even distant rendering time cannot restart or rotate a held aerial state")
							var original_velocity := state.air_vertical_velocity
							var original_budget := state.float_ticks
							var phase_start := frame
							if action == "fly":
								var duration := config.milliseconds_to_ticks(state.float_max_duration_ms)
								state.float_ticks = duration
								phase_start = presenter.frame(id, state, 60.0, config, 0.375, reduced)
								state.float_ticks = duration - config.milliseconds_to_ticks(200)
							else:
								state.air_vertical_velocity = -700_000
							var progressed_authority := state.canonical_values()
							var progressed: Dictionary = presenter.frame(id, state, 60.0, config, 0.375, reduced)
							if reduced:
								equal(int(progressed.pose_key), 1 if action == "fly" else 0, "reduced motion holds its declared key while real height or flight budget progresses")
							elif action == "fast_fall":
								equal(int(progressed.pose_key), 3, "fastfall retains its deliberate fixed descent key rather than cycling on time")
							else:
								check(progressed.pose_key != phase_start.pose_key, "actual vertical velocity or paid flight budget advances the distinct native key at constant rendering time")
								check(progressed.pixel_parts != phase_start.pixel_parts, "physical pose progress has visible native geometry rather than metadata alone")
							equal(state.canonical_values(), progressed_authority, "querying progressed pose authority never mutates the arranged state")
							state.air_vertical_velocity = original_velocity
							state.float_ticks = original_budget
						elif Pixels.RIGID_FALLBACK_POSES.has(action):
							var facing: int = travel if action in Pixels.TRAVEL_FACING_ACTIONS else aim
							check(frame.get("rigid_pose_fallback", false), "unsupported action explicitly discloses its reused pose")
							equal(frame.get("source_pose"), Pixels.RIGID_FALLBACK_POSES[action], "fallback source is an existing state-appropriate whole-body key")
							equal(frame.get("pose_facing_index"), facing, "travel-led actions use real eight-heading keys, never sprite rotation")
							equal(frame.components[0].source_region.position.x, float(facing * 128), "selected atlas column agrees with the physical pose heading")
							check(not frame.get("all_action_art_complete", true) and not frame.get("pixel_action_key", true), "reused keys are not passed off as completed action art")
							var later: Dictionary = presenter.frame(id, state, 150.0, config, 0.875, reduced)
							equal(later.components, frame.components, "timer and gait phase cannot morph or cycle an unsupported held pose")
							state.pending_cast_wire_id = CombatTuning.RILLSHOT_WIRE_ID
							state.pending_cast_ticks = 0
							var casting_authority := state.canonical_values()
							var casting: Dictionary = presenter.frame(id, state, 150.0, config, 0.875, reduced)
							equal(casting.components, frame.components, "unpainted casting overlay cannot split or warp the rigid action key")
							check(not casting.get("independent_cast_pose", true), "a cast request does not claim independently painted hands")
							equal(state.canonical_values(), casting_authority, "cast-overlay queries cannot change authority")
							state.pending_cast_wire_id = 0
							state.pending_cast_ticks = 0
						else:
							check(not frame.get("rigid_pose_fallback", false), "existing authored coverage is never downgraded to a fallback")
						equal(state.canonical_values(), authority, "all-state repeated queries leave simulation untouched")
						equal(presenter.frame(id, ordinary, 60.0, config, 0.375, reduced), reference, "each action-to-walk return restores the exact same distance-owned frame")
	equal(presenter.meshes.size(), mesh_count, "all-state pixel matrix creates no legacy source meshes")
	equal(presenter.render_meshes.size(), stream_count, "all-state pixel matrix creates no dynamic mesh streams")


func _test_full_roster_registration(presenter: RefCounted, ids: Array) -> void:
	# These are draw/registration guarantees, not anatomical measurements.
	# Equal native blit sizes cannot certify that separately painted heads,
	# necks and torsos match. Never infer those landmarks from opaque bounds.
	var config := SimConfig.new(120)
	var heights := {"small": 58, "middle": 63, "large": 68}
	equal(Pixels.BODY_HEIGHTS, heights, "pixel ground bank uses the modest shared display-height ladder")
	equal(Actions.HEIGHTS, heights, "authored action bank cannot silently retain the old 58/68/76 source heights")
	equal(WireframeBodyPresenter.DISPLAY_HEIGHTS, heights, "shared skeleton display calibration agrees with native pixel sizes without applying its baked scale twice")
	var sizes := {}
	var samples := 0
	var actions := ["idle", "walk", "sprint", "cast", "rooted", "crouch",
		"jumpsquat", "jump", "double_jump", "walljump", "slide_jump", "fall",
		"fast_fall", "land", "slide", "wavedash", "roll", "air_dodge",
		"wallrun", "fly", "hit", "stunned", "defeated"]
	var bank: RefCounted = presenter.pixel_pilot
	check(bank.action_bank != null, "full-roster registration matrix requires the actual current action bank")
	if bank.action_bank == null: return
	equal(ids.size(), 30, "registration contract covers the complete thirty-identity roster")
	for id: String in ids:
		var body: String = bank.entries[id].body
		sizes[body] = true
		for aim: int in 8:
			var travel := (aim + 2) % 8
			for action: String in actions:
				var state := _motion_state(action, aim, travel)
				var authority := state.canonical_values()
				for phase: float in [0.0, 0.5]:
					var frame: Dictionary = presenter.frame(id, state, 71.0 + phase, config, phase, phase > 0.0)
					samples += 1
					equal(frame.get("action"), action, "all roster actions retain their actual movement state")
					var aerial := action == "fly" or action in AerialChecks.BALL_ACTIONS
					if aerial:
						AerialChecks.assert_frame(self, frame, bank, id, action, aim)
					else:
						equal(frame.get("body_type"), body, "native atlas actions never exchange the identity's body-size tier")
						equal(frame.get("display_height"), heights[body], "native atlas height metadata remains identity-owned")
						equal(frame.get("pivot"), Vector2(64, 104), "native atlas states share exact support registration")
						equal(frame.get("cell_size"), Vector2(128, 128), "native atlas states retain the same calibrated cell")
					equal(frame.get("offset"), Vector2.ZERO, "pose or reduced-motion mode cannot add an unreviewed registration correction")
					check(not frame.has("mesh") and not frame.has("render_mesh") and not frame.has("scale") and not frame.has("rotation"), "full-roster pixel proportions are never repaired by runtime deformation")
					var components: Array = frame.get("components", [])
					check(not components.is_empty() or (aerial and not frame.get("pixel_parts", []).is_empty()), "every roster action has actual native pixels")
					for component: Dictionary in components:
						var source: Rect2 = component.source_region
						var destination: Rect2 = component.destination_region
						equal(source.size, destination.size, "all roster body parts preserve their native painted aspect and pixel size")
						equal(Vector2(fposmod(source.position.x, 128.0), fposmod(source.position.y, 128.0)), destination.position, "all native regions retain their exact within-cell registration without per-facing fitting")
						check(component.texture == bank.textures[id] or component.texture == bank.action_bank.textures[id], "state changes use only this identity's admitted ground or action pixels")
						check(Rect2(0, 0, 128, 128).encloses(destination), "complete native body regions stay inside their fixed template")
					if action in ["walk", "sprint", "cast"]:
						state.pending_cast_wire_id = CombatTuning.RILLSHOT_WIRE_ID
						state.pending_cast_ticks = 1
						var cast_authority := state.canonical_values()
						var casting: Dictionary = presenter.frame(id, state, 71.0 + phase, config, phase)
						equal(casting.components[0], components[0], "moving or standing cast cannot resize or re-register the identity's lower body")
						equal(casting.get("display_height"), heights[body], "cast overlays cannot redefine the body-size template")
						equal(state.canonical_values(), cast_authority, "all-roster cast registration remains presentation-only")
						state.pending_cast_wire_id = 0
						state.pending_cast_ticks = 0
					equal(state.canonical_values(), authority, "all-roster registration sampling leaves physics, stats and authority untouched")
	equal(sizes.size(), 3, "the full-roster matrix actually covers every size tier")
	equal(samples, 30 * 8 * 23 * 2, "every full-roster state/heading/phase/reduced-motion registration sample executes")


func _test_missing_action_bank(presenter: RefCounted) -> void:
	var bank: RefCounted = presenter.pixel_pilot
	var actions: RefCounted = bank.action_bank
	var profiles: Dictionary = bank.aerial_profiles.duplicate()
	check(not bank.configure_actions(null), "public optional-bank rejection is atomic")
	check(bank.action_bank == null and bank.aerial_profiles.is_empty(), "rejected optional bank revokes both native actions and derived aerial profiles")
	var config := SimConfig.new(120)
	for action: String in ["jump", "fall", "land", "slide", "roll", "hit", "defeated"]:
		var state := _motion_state(action, 6, 2)
		var before := state.canonical_values()
		var frame: Dictionary = presenter.frame("s_wayne", state, 60.0, config, 0.25)
		check(frame.get("rigid_pose_fallback", false), "missing optional action bank retains a visible rigid identity")
		equal(frame.get("source_pose"), "idle", "missing-art neutral fallback is disclosed explicitly")
		check(not frame.has("mesh") and not frame.has("render_mesh"), "missing optional art cannot silently opt the pixel cast into deformation")
		equal(frame.components[0].source_region, Rect2((2 if action in ["slide", "roll"] else 6) * 128, 0, 128, 128), "missing action art uses the real neutral heading at native size")
		equal(state.canonical_values(), before, "missing-art fallback remains read-only")
	bank.action_bank = actions
	bank.aerial_profiles = profiles


func _motion_state(action: String, aim: int, travel: int) -> PlayerState:
	var state := _state("walk", aim)
	var move: Vector2i = EightDirectionResolver.FIXED_VECTORS[travel]
	state.velocity_x = move.x * 200
	state.velocity_y = move.y * 200
	state.movement_mode = PlayerState.MovementMode.WALK
	match action:
		"idle", "land":
			state.velocity_x = 0
			state.velocity_y = 0
			state.movement_mode = PlayerState.MovementMode.IDLE
			state.landing_ticks = 6 if action == "land" else 0
		"sprint": state.movement_mode = PlayerState.MovementMode.SPRINT
		"crouch": state.crouching = true
		"jumpsquat":
			state.jumpsquat_active = true
			state.jumpsquat_ticks = 18
		"slide", "wavedash":
			state.movement_mode = PlayerState.MovementMode.SLIDE if action == "slide" else PlayerState.MovementMode.WAVE_DASH
			state.slide_ticks = 12
			state.slide_x = move.x
			state.slide_y = move.y
		"roll":
			state.movement_mode = PlayerState.MovementMode.ROLL
			state.hop_mode = PlayerState.MovementMode.ROLL
			state.air_dodge_ticks = 12
		"cast": state.control_state = PlayerState.ControlState.CHARGING
		"rooted": state.control_state = PlayerState.ControlState.ROOTED
		"hit": state.control_state = PlayerState.ControlState.LAUNCHED
		"stunned": state.control_state = PlayerState.ControlState.STUNNED
		"defeated": state.health = 0
		"walk": pass
		_:
			state.air_height = 24000
			state.air_vertical_velocity = 30000
			state.hop_ticks = 12
			state.hop_mode = PlayerState.MovementMode.HOP
			state.movement_mode = PlayerState.MovementMode.HOP
			match action:
				"double_jump": state.hop_mode = PlayerState.MovementMode.DOUBLE_JUMP
				"walljump": state.hop_mode = PlayerState.MovementMode.WALL_KICK
				"slide_jump": state.hop_mode = PlayerState.MovementMode.SLIDE_JUMP
				"fall", "fast_fall":
					state.air_vertical_velocity = -30000
					if action == "fast_fall": state.movement_mode = PlayerState.MovementMode.FAST_FALL
				"air_dodge":
					state.air_dodge_ticks = 12
					state.movement_mode = PlayerState.MovementMode.AIR_DODGE
				"wallrun":
					state.wall_skim_ticks = 12
					state.wall_skim_x = move.x
					state.wall_skim_y = move.y
				"fly":
					state.air_floating = true
					state.flight_capable = true
					state.float_ticks = 12
	return state


func _startup_ticks(wire: int, config: SimConfig) -> int:
	return config.milliseconds_to_ticks(int(CombatTuning.cast_definition(wire).get("startup_ms", 0)))


func _state(action: String, aim: int) -> PlayerState:
	var state := PlayerState.new(9781)
	var facing: Vector2i = EightDirectionResolver.FIXED_VECTORS[aim]
	state.aim_x = facing.x
	state.aim_y = facing.y
	state.facing_x = facing.x
	state.facing_y = facing.y
	if action in ["walk", "sprint"]:
		state.velocity_x = 200000
		state.movement_mode = PlayerState.MovementMode.SPRINT if action == "sprint" else PlayerState.MovementMode.WALK
	return state
