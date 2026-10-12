extends RefCounted
## Observe real route actions in the four existing districts. No rewards or input.
const KINDS := {
	"tideglass-quays":"shore-approach", "verdant-reaches":"brake-and-rejoin",
	"basalt-foundry":"corner-and-cover", "starward-terraces":"cross-and-recover",
}
const GOALS := {
	"shore-approach":["Sprint into the shore approach.","Hold Jump while moving along the wall.","Release Jump to leave the wall."],
	"brake-and-rejoin":["Build speed along the grove route.","Brake below walking speed while grounded.","Rejoin the loop at a controlled walk."],
	"corner-and-cover":["Hold Jump along the marked foundry wall.","Leave the wall in a different travel direction.","Round the corner, land behind solid cover and finish recovery."],
	"cross-and-recover":["Use Slide across the terrace.","Release Jump to launch from the slide.","Land, slow down and recover some Stamina."],
}
var district := ""
var step := 0
var _world: SimWorld
var _tick := -1
var _position := Vector2i.ZERO
var _wall_direction := Vector2.ZERO
var _stamina := 0
var _lowest_stamina := 0
var _stage_origin := Vector2i.ZERO
var _wall_entry := Vector2i.ZERO
var _course: Dictionary = {}
var _champion_wire := 0
var _layout_hash := ""

func reset() -> void:
	district = ""
	step = 0
	_world = null
	_tick = -1
	_wall_direction = Vector2.ZERO
	_course = {}
	_champion_wire = 0
	_layout_hash = ""

func observe(world: SimWorld, layout: SanctumCampusLayout, allowed: bool = true) -> void:
	if not allowed or world == null or layout == null or world.player(1) == null or world.player(1).health <= 0:
		reset()
		return
	var actor := world.player(1)
	var point := Vector2i(actor.position_x,actor.position_y)
	var current := ""
	for id: String in KINDS:
		var row: Dictionary = layout.districts_by_id.get(id,{})
		if not row.is_empty() and MovementPracticeCoach.inside_area(actor,SanctumCampusLayout._parse_bounds(row.bounds)):
			current = id
			break
	if _world != world or current != district or actor.champion_wire_id != _champion_wire or layout.content_hash != _layout_hash or world.tick < _tick or point.distance_to(_position) > 16000.0 * maxi(1,world.tick-_tick):
		reset()
		_world = world
		district = current
		_tick = world.tick
		_position = point
		_stamina = actor.stamina
		_lowest_stamina = actor.stamina
		_champion_wire = actor.champion_wire_id
		_layout_hash = layout.content_hash
		for course: Dictionary in layout.data.get("movement_courses",[]):
			if String(course.get("district","")) == district:
				_course = course.duplicate(true)
				break
		return
	if district.is_empty() or _course.is_empty() or world.tick <= _tick: return
	var speed := Vector2(actor.velocity_x,actor.velocity_y).length()
	var walking_speed := float(MovementTuning.BASE_SPEED)*float(actor.movement_speed_ratio)/1000.0
	var grounded := not actor.is_airborne() and actor.air_height <= 0
	var own_wall := actor.wall_skim_ticks > 0 and actor.wall_skim_surface_id == int(_course.wall_id)
	_lowest_stamina = mini(_lowest_stamina,actor.stamina)
	var achieved := false
	match String(KINDS[district]):
		"shore-approach":
			if step == 0: achieved = actor.sprinting and speed > walking_speed
			elif step == 1: achieved = own_wall
			elif step == 2: achieved = actor.is_airborne() and actor.hop_mode == PlayerState.MovementMode.WALL_KICK and actor.wall_lockout_id == int(_course.wall_id)
		"brake-and-rejoin":
			if step == 0: achieved = grounded and speed > walking_speed
			elif step == 1: achieved = grounded and speed < walking_speed * 0.5
			elif step == 2: achieved = grounded and speed > walking_speed * 0.6 and speed <= walking_speed and not actor.sprinting and (point-_stage_origin).length_squared() >= 64000*64000
		"corner-and-cover":
			if step == 0 and own_wall:
				_wall_direction = Vector2(actor.velocity_x,actor.velocity_y).normalized()
				_wall_entry = point
				achieved = not _wall_direction.is_zero_approx()
			elif step == 1:
				var direction := Vector2(actor.velocity_x,actor.velocity_y).normalized()
				achieved = actor.is_airborne() and actor.wall_skim_ticks == 0 and not direction.is_zero_approx() and direction.dot(_wall_direction) < 0.7
			elif step == 2:
				# Cover must be an actual swept solid between the entry lane and
				# the finish, not a district label or a cosmetic floor feature.
				var cover := ContinuousContact.wall_contact(_wall_entry,point,0,world.collision)
				achieved = grounded and not cover.is_empty() and actor.pending_cast_wire_id == 0 and actor.movement_commitment_ticks == 0 and actor.impact_recovery_ticks == 0 and actor.control_state == PlayerState.ControlState.FREE
		"cross-and-recover":
			if step == 0: achieved = actor.slide_ticks > 0 and actor.movement_chain_count > 0
			elif step == 1: achieved = actor.is_airborne() and actor.hop_mode == PlayerState.MovementMode.SLIDE_JUMP
			elif step == 2: achieved = grounded and speed <= walking_speed and actor.stamina >= _lowest_stamina+1000 and actor.stamina_recovery_delay_ticks == 0
	if achieved:
		step = mini(3,step+1)
		_stage_origin = point
	_tick = world.tick
	_position = point
	_stamina = actor.stamina

func view(state: PlayerState, preferences: PlayerPreferences) -> Dictionary:
	if district.is_empty() or state == null or preferences == null: return {}
	var kind := String(KINDS[district])
	var title := district.replace("-"," ").to_upper()
	var instruction := "Route complete. Try a different approach." if step >= 3 else String(GOALS[kind][step])
	var bindings := preload("res://src/presentation/spell_binding_labels.gd")
	for pair: Array in [["Jump",&"jump"],["Sprint",&"sprint"],["Slide",&"slide"]]:
		var label: String = bindings.action_label(pair[1],preferences)
		instruction = instruction.replace(pair[0],label if not label.is_empty() else String(pair[0])+" (unbound)")
	var note := "No refill or reward. Leave the district to restart."
	if step<3 and String(GOALS[kind][step]).contains("Hold Jump") and MovementPracticeCoach._wheel_jump(preferences,preferences.prompt_device):
		note = "A wheel pulse cannot hold Jump; bind a button at Controls."
	return {"kind":"district","title":title,"phase":"ROUTE %d/3 · optional; walking bypass stays open" % mini(3,step+1),"completed":step>=3,"step":step,"practice_kind":kind,
		"lines":PackedStringArray([instruction,note])}
