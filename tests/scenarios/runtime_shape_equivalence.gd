extends SceneTree

# Standalone differential check for the allocation-free shape lookup. The
# reference below freezes contains() immediately before that optimization.
const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")
var failures := 0
var assertions := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := SimConfig.new(120)
	var rng := RandomNumberGenerator.new()
	rng.seed = 608120
	var wires: Array[int] = [-1, 0, 300, 337, 2147483647]
	for wire: int in range(301, 337):
		wires.append(wire)
	for wire: int in wires:
		var definition := Chemistry.recipe(wire)
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			var state := ElementReactionState.new()
			state.recipe_wire_id = wire
			state.position_x = 500000
			state.position_y = 500000
			state.direction_x = direction.x
			state.direction_y = direction.y
			state.radius = int(definition.get("radius", 18000))
			state.length = int(definition.get("length", 24000))
			state.active_tick = 30
			var origin := Vector2i(state.position_x, state.position_y)
			var endpoint := origin + Chemistry.scaled(direction, state.length)
			state.endpoint_x = endpoint.x
			state.endpoint_y = endpoint.y
			var points: Array[Vector2i] = [origin, endpoint, origin + Vector2i(state.radius, 0), origin + Vector2i(state.radius + 1, 0), origin + Vector2i(state.length, 0), origin + Vector2i(state.length - 1, 0)]
			for _sample: int in range(32):
				points.append(origin + Vector2i(rng.randi_range(-300000, 300000), rng.randi_range(-300000, 300000)))
			for linked: bool in [false, true]:
				state.path_points = PackedInt64Array([origin.x, origin.y, endpoint.x, endpoint.y, endpoint.x + 45000, endpoint.y - 30000]) if linked else PackedInt64Array()
				for tick: int in [30, 56, 83, 84, 111]:
					for point: Vector2i in points:
						assertions += 1
						if Chemistry.contains(state, point, tick, config) != _reference_contains(state, point, tick, config):
							failures += 1
							push_error("shape equivalence changed wire=%d direction=%s tick=%d point=%s linked=%s" % [wire, direction, tick, point, linked])
	print("%s: runtime-shape-equivalence; %d assertions; %d failures" % ["PASS" if failures == 0 else "FAIL", assertions, failures])
	quit(0 if failures == 0 else 1)

static func _reference_contains(result: ElementReactionState, point: Vector2i, tick: int, config: SimConfig) -> bool:
	var origin := Vector2i(result.position_x,result.position_y)
	var offset := point-origin
	var shape := String(Chemistry.recipe(result.recipe_wire_id).get("shape",""))
	var distance := offset.length_squared()
	if shape in ["annulus","ring"]:
		return distance <= result.radius*result.radius and distance >= result.length*result.length
	if shape in ["water_path","frost_path","branch"]:
		if result.path_points.size() < 4:
			return shape == "water_path" and distance <= result.radius*result.radius
		for index: int in range(0,result.path_points.size()-2,2):
			if Chemistry.segment_near(point,Vector2i(result.path_points[index],result.path_points[index+1]),Vector2i(result.path_points[index+2],result.path_points[index+3]),result.radius):
				return true
		return false
	if shape in ["corridor","front","growing_strip","pulse_lane","bands","reveal_line"]:
		if not Chemistry.segment_near(point,origin,Vector2i(result.endpoint_x,result.endpoint_y),result.radius):
			return false
		if shape == "pulse_lane":
			var period := config.milliseconds_to_ticks(450)
			var age := maxi(0,tick-result.active_tick)%period
			@warning_ignore("integer_division")
			var moving_point := origin + Chemistry.scaled(Vector2i(result.direction_x,result.direction_y),result.length*age/maxi(1,period))
			return (point-moving_point).length_squared() <= 25000*25000
		return true
	if shape in ["cover","plane","lens"]:
		var side := Vector2i(-result.direction_y,result.direction_x)
		@warning_ignore("integer_division")
		return Chemistry.segment_near(point,origin-Chemistry.scaled(side,result.length/2),origin+Chemistry.scaled(side,result.length/2),result.radius)
	return distance <= result.radius*result.radius
