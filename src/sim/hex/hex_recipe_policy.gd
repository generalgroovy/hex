class_name HexRecipePolicy
extends RefCounted

@warning_ignore_start("integer_division")

const Composite = preload("res://src/sim/hex/hex_composite_policy.gd")
const Footprint = preload("res://src/sim/hex/hex_footprint.gd")

const TICK_RATE := 120
const FIRST_RECIPE_WIRE := 301
const LAST_RECIPE_WIRE := 336
const DIRECTIONAL_COSINE_SQUARED := 820_000
const MAX_EFFECT_HEIGHT := 256_000
const REACTION_EXTENT_PERMILLE := 750 # Linear extents, after authored overrides; not ingredient fields.
const MEDIUM_RADIUS := 64_000 * REACTION_EXTENT_PERMILLE / 1000
const PENDING_CAPSULE_KIND := Footprint.KIND_CAPSULE

const INGREDIENT_LAYERS := {1: "earth", 2: "fire", 3: "water", 4: "wind", 7: "light", 8: "dark"}
const ACTIVE_RECIPE_WIRES: Array[int] = [301, 302, 303, 304, 307, 308, 309, 310, 311, 314, 315, 316, 317, 320, 321, 322, 325, 326, 334, 335, 336, 407, 411, 413, 414, 415, 419, 421, 422, 423, 425, 426, 427, 428, 429, 430, 431, 435, 437, 438, 439, 441, 442, 443, 444, 445, 446, 447, 449, 450, 451, 452, 453, 454, 455, 456, 457, 458, 459, 460, 461, 462, 463]

# Explicit triangular matrix. Zero entries are invalid; every stable first-eight
# unordered pair appears exactly once and is symmetric through recipe_wire().
const PAIR_WIRES: Array = [
	[301, 302, 303, 304, 305, 306, 307, 308],
	[0, 309, 310, 311, 312, 313, 314, 315],
	[0, 0, 316, 317, 318, 319, 320, 321],
	[0, 0, 0, 322, 323, 324, 325, 326],
	[0, 0, 0, 0, 327, 328, 329, 330],
	[0, 0, 0, 0, 0, 331, 332, 333],
	[0, 0, 0, 0, 0, 0, 334, 335],
	[0, 0, 0, 0, 0, 0, 0, 336],
]

# Stable compiled recipe rows retained locally so this pure policy never calls
# the legacy formation loop. Values are id, elements, effect geometry, phase ms,
# radius/length before the existing 1.25 extent, historical motion, pulse ms and
# health k. The current compact/stationary override is applied after authoring.
const COMPILED_ROWS: Array = [
	["fortify", 1, 1, "cover", 180, 3125, 400, 18000, 64000, 0, 0, 32],
	["magma", 1, 2, "front", 350, 2750, 500, 24000, 80000, 30000, 400, 0],
	["mud", 1, 3, "disk", 200, 3250, 350, 62000, 0, 0, 0, 0],
	["dustfront", 1, 4, "corridor", 250, 2250, 350, 28000, 120000, 38000, 0, 0],
	["permafrost", 1, 5, "cover", 240, 3000, 650, 14000, 80000, 0, 0, 18],
	["grounding_network", 1, 6, "node", 250, 3250, 300, 38000, 0, 0, 0, 16],
	["crystal_prism", 1, 7, "plane", 400, 2750, 400, 8000, 70000, 0, 0, 18],
	["blightsoil", 1, 8, "disk", 300, 3000, 400, 54000, 0, 0, 0, 0],
	["conflagration", 2, 2, "ring", 400, 3000, 400, 72000, 24000, 0, 600, 0],
	["steam", 2, 3, "expanding_veil", 240, 2625, 500, 90000, 0, 0, 0, 0],
	["firestorm", 2, 4, "corridor", 350, 2250, 350, 18000, 130000, 68000, 350, 0],
	["thermal_shock", 2, 5, "fracture", 600, 100, 550, 90000, 0, 0, 0, 0],
	["plasma_arc", 2, 6, "branch", 450, 120, 400, 10000, 180000, 0, 0, 0],
	["solar_flare", 2, 7, "reveal_pulse", 220, 100, 650, 100000, 0, 0, 0, 0],
	["cinderveil", 2, 8, "ember_veil", 300, 3000, 400, 56000, 0, 0, 350, 0],
	["flood", 3, 3, "flow", 220, 3125, 350, 64000, 0, 0, 0, 0],
	["mistcurrent", 3, 4, "corridor", 220, 2750, 400, 25000, 160000, 25000, 0, 0],
	["freeze", 3, 5, "growing_strip", 300, 2500, 350, 16000, 140000, 0, 0, 0],
	["conductive_flood", 3, 6, "water_path", 500, 2625, 350, 20000, 180000, 0, 600, 0],
	["mirrorwater", 3, 7, "observation", 220, 3250, 350, 55000, 0, 0, 0, 0],
	["blackwater", 3, 8, "motion_veil", 260, 3000, 400, 62000, 0, 0, 0, 0],
	["vortex", 4, 4, "annulus", 400, 2750, 400, 72000, 24000, 0, 0, 0],
	["hailstream", 4, 5, "pulse_lane", 400, 2813, 350, 14000, 180000, 0, 450, 0],
	["ion_storm", 4, 6, "drifting_node", 450, 2625, 400, 40000, 0, 22000, 700, 0],
	["lightbend", 4, 7, "bend", 250, 3000, 300, 45000, 0, 0, 0, 0],
	["shadowdraft", 4, 8, "bands", 300, 3000, 350, 30000, 150000, 30000, 300, 0],
	["glacier", 5, 5, "corridor", 650, 3500, 600, 24000, 160000, 0, 0, 0],
	["superconduct", 5, 6, "frost_path", 500, 2250, 350, 8000, 260000, 0, 900, 0],
	["crystal_lens", 5, 7, "lens", 450, 2875, 400, 18000, 60000, 0, 0, 20],
	["black_ice", 5, 8, "entry_mark", 300, 3125, 400, 54000, 0, 0, 0, 0],
	["overload", 6, 6, "corridor", 650, 2000, 450, 24000, 160000, 0, 0, 0],
	["arcflash", 6, 7, "reveal_line", 300, 140, 400, 12000, 180000, 0, 0, 0],
	["static_shroud", 6, 8, "entry_veil", 320, 2750, 400, 58000, 0, 0, 0, 0],
	["radiance", 7, 7, "reveal_area", 300, 3125, 400, 78000, 0, 0, 0, 0],
	["penumbra", 7, 8, "border", 220, 3000, 250, 66000, 0, 0, 0, 0],
	["umbral_field", 8, 8, "attrition_veil", 350, 3500, 450, 74000, 0, 0, 600, 0],
]

const PURPOSES: Array[String] = [
	"temporary six-face hex pillar cover", "grounded damage and route denial", "ground acceleration and braking choice", "transparent lateral positioning front",
	"temporary brittle cover", "charge-draining ground node", "predictable reflection plane", "growth and recovery suppression surface",
	"committed concentrated ground burn", "visible capped scald pressure", "stationary route-cutting fire sector", "grounded shatter burst and structure fracture",
	"conductor burst; extra Charge extends its reach", "damaging reveal and glare pulse", "concealing delayed ember pressure", "directional grounded route steering",
	"visible wet steering and finite suppression", "grounded entry slow", "connected wet charge path", "moving and entry disturbance reveal",
	"concealing water with movement reveal", "rotational redirection and slingshot utility", "repeated pressure across a stationary hail lane", "stationary charged field",
	"predictable optical bend", "stationary pulsing concealment bands", "ground movement and projectile slowdown lane; slide and air movement unchanged", "charge pulses; extra Ice extends their reach",
	"split and redirect light", "entry reveal and delayed grounded slow", "Capacitor movement lane and terminal discharge", "damaging revealing conductive line",
	"entry and exit silhouette veil", "persistent reveal and searing light pulses", "crossing reveal and light-dark pressure", "bounded concealment and delayed attrition",
]

const COUNTERS: Array[String] = [
	"break, go around, or wait", "leave or jump before the next pulse", "leave for immediate full movement", "jump or leave laterally",
	"break the cover or wait", "break with non-Charge impacts or exhaust its capacity", "use Spray to break the cover", "leave the recovery-suppression surface",
	"leave or jump during warning", "exit or cool with a fresh Water cast", "leave laterally or use solid cover", "jump or exit during the fracture warning",
	"leave during formation or break an added Charge link", "exit during the forming flash", "leave before the delayed ember pulse", "jump or leave the current",
	"jump or leave the wet corridor", "leave and let the brief entry slow expire", "leave or break the Water links", "stand still after the entry reveal fades",
	"movement reveals concealed actors", "use the center opening, jump, or exit", "leave the marked hail lane", "leave the marked charged field",
	"change the Light approach angle", "use the transparent interval between bands", "slide, jump, or leave", "leave the frost path or break added Ice links",
	"break with non-Light impacts or Spray", "leave before the delayed slow", "leave before the terminal discharge", "exit the line during its warning",
	"entry and exit briefly reveal actors", "leave between searing light pulses", "cross quickly and let the mark fade", "move to reveal or leave before attrition",
]

const FIRST_TEN_WIRES: Array[int] = [301, 302, 303, 304, 309, 310, 311, 316, 317, 322]


static func ingredient_layer(element: int) -> String:
	return String(INGREDIENT_LAYERS.get(element, ""))


static func product_layer(wire: int) -> String:
	if wire not in ACTIVE_RECIPE_WIRES:
		return ""
	return "compound_%02d" % (wire - 400) if wire > 400 else String(COMPILED_ROWS[wire - FIRST_RECIPE_WIRE][0])


static func recipe_wire(element_a: int, element_b: int) -> int:
	if not INGREDIENT_LAYERS.has(element_a) or not INGREDIENT_LAYERS.has(element_b):
		return 0
	var low := mini(element_a, element_b)
	var high := maxi(element_a, element_b)
	return int(PAIR_WIRES[low - 1][high - 1])


static var _runtime_definitions: Dictionary = {}


# Simulation readers share a recursively immutable compiled contract. The
# public definition() factory remains detached/mutable for authoring callers.
static func runtime_definition(wire: int) -> Dictionary:
	if _runtime_definitions.has(wire): return _runtime_definitions[wire]
	var result := definition(wire)
	_freeze_contract(result)
	if wire in ACTIVE_RECIPE_WIRES:
		_runtime_definitions[wire] = result
	return result


static func _freeze_contract(value: Variant) -> void:
	if value is Dictionary:
		for child: Variant in value.values(): _freeze_contract(child)
		value.make_read_only()
	elif value is Array:
		for child: Variant in value: _freeze_contract(child)
		value.make_read_only()


static func definition(wire: int) -> Dictionary:
	if wire not in ACTIVE_RECIPE_WIRES:
		return {}
	if wire > 400:
		var compound := Composite.definition(wire - 400)
		compound.visual_material = String(COMPILED_ROWS[int(compound.archive_recipe_wire) - 301][0])
		return compound
	var index := wire - FIRST_RECIPE_WIRE
	var row: Array = COMPILED_ROWS[index]
	var result := {
		"wire_id": wire,
		"id": String(row[0]),
		"name": _display_name(wire, String(row[0])),
		"elements": [int(row[1]), int(row[2])],
		"ingredient_layers": [ingredient_layer(int(row[1])), ingredient_layer(int(row[2]))],
		"product_layer": product_layer(wire),
		"geometry_kind": String(row[3]),
		"selection_kind": _selection_kind(String(row[3])),
		"formation_ticks": _ticks(int(row[4])),
		"active_ticks": _ticks(int(row[5])),
		"decay_ticks": _ticks(int(row[6])),
		"radius": _extent(int(row[7])),
		"length": _extent(int(row[8])),
		"quantity_policy": "paid_source_transfer",
		"pulse_ticks": _ticks(int(row[10])),
		"pulse_damage": _compiled_damage(wire),
		"ground_only": wire in [302, 303, 304, 316, 317, 318, 322, 327, 330, 331],
		"maximum_height": 0 if wire in [302, 303, 304, 316, 317, 318, 322, 327, 330, 331] else MAX_EFFECT_HEIGHT,
		"respects_protection": true,
		"flow_speed": _compiled_flow_speed(wire),
		"flow_kind": _compiled_flow_kind(wire),
		"slow_ratio": _compiled_slow_ratio(wire),
		"health": int(row[11]) * 1000,
		"capacity": 36_000 if wire == 306 else 0,
		"motion_speed": 0,
		"footprint_motion": "stationary",
		"counter": COUNTERS[index],
		"purpose": PURPOSES[index],
		"trigger_eligibility": "distinct_paid_sources",
		"trigger_modes": ["same_cell_deposit", "instant_spray", "ordered_flight_contact"],
		"implementation_status": "runtime_implemented",
	}
	_apply_first_ten_contract(result)
	_apply_combat_options(result)
	_apply_six_element_contract(result)
	result.archive_recipe_wire = int({311:313,316:327,317:323,321:330}.get(wire, wire))
	result.visual_material = String(COMPILED_ROWS[int(result.archive_recipe_wire) - 301][0])
	result.element_mask = mask_for_wire(wire)
	result.arity = 2
	# One authority for compact footprints, including Rampart's explicit disk.
	# Phase times, pulses, paid quantities and actor flow are deliberately separate.
	for extent: String in ["radius", "length", "selection_radius"]:
		if result.has(extent):
			result[extent] = int(result[extent]) * REACTION_EXTENT_PERMILLE / 1000
	result.requires_canonical_capsule = false
	result.selection_activation_ready = String(result.selection_kind) in [Footprint.KIND_DISK, Footprint.KIND_SECTOR, Footprint.KIND_CAPSULE, Footprint.KIND_ANNULUS]
	if String(result.selection_kind) == Footprint.KIND_CAPSULE:
		result.selection_proposal = "canonical_capsule"
	elif String(result.selection_kind) == Footprint.KIND_ANNULUS:
		result.selection_proposal = "canonical_annulus"
	elif wire in [302, 304, 311, 317]:
		result.selection_proposal = "first_four_directional_sector"
	else:
		result.selection_proposal = "canonical_disk"
	result.phase_ticks = PackedInt64Array([int(result.formation_ticks), int(result.active_ticks), int(result.decay_ticks)])
	return result


static func selection_shape(wire: int, exact_point: Vector2i, normalized_aim: Vector2i) -> Dictionary:
	var contract := runtime_definition(wire)
	if contract.is_empty() or not _aim_valid(normalized_aim):
		return {}
	if String(contract.selection_kind) == Footprint.KIND_SECTOR:
		var sector := Footprint.sector(exact_point, normalized_aim, int(contract.length), DIRECTIONAL_COSINE_SQUARED)
		return sector if Footprint.validate(sector) else {}
	if String(contract.selection_kind) == Footprint.KIND_DISK:
		var disk := Footprint.disk(exact_point, int(contract.get("selection_radius", contract.radius)))
		return disk if Footprint.validate(disk) else {}
	if String(contract.selection_kind) == Footprint.KIND_CAPSULE:
		var direction := normalized_aim
		var start := exact_point
		var end := exact_point + ElementChemistrySystem.scaled(direction, int(contract.length))
		if String(contract.geometry_kind) in ["cover", "plane", "lens"]:
			var side := ElementChemistrySystem.scaled(Vector2i(-direction.y, direction.x), int(contract.length) / 2)
			start = exact_point - side
			end = exact_point + side
		var capsule := Footprint.capsule(start, end, int(contract.radius))
		return capsule if Footprint.validate(capsule) else {}
	if String(contract.selection_kind) == Footprint.KIND_ANNULUS:
		return Footprint.annulus(exact_point, int(contract.length), int(contract.radius))
	return {}


static func _apply_first_ten_contract(result: Dictionary) -> void:
	match int(result.wire_id):
		301:
			result.selection_kind = Footprint.KIND_DISK
			result.selection_radius = 34_000
			result.cover_shape = "hex_pillar"
			result.cover_faces = 6
			result.stable_face_normals = true
			result.safe_creation_escape = true
		302:
			result.selection_kind = Footprint.KIND_SECTOR
			result.pulse_damage = 5_000
			result.slow_ratio = 750
			result.slow_stacking = "lowest_ratio_once"
			result.exit_ticks = 0
			result.cooling_readable = true
		303:
			result.movement_kind = "ground_acceleration_and_braking"
			result.slow_ratio = 1000
			result.ground_acceleration_ratio = 700
			result.ground_braking_ratio = 700
			result.immobilizes = false
			result.exit_ticks = 0
		304:
			result.selection_kind = Footprint.KIND_SECTOR
			result.transparent = true
			result.flow_kind = "lateral"
			result.flow_speed = 25_000
			result.traps = false
		309:
			_apply_current_water_fire(result)
			result.pulse_ticks = 72
			result.pulse_damage = 8_000
			result.ground_only = true
			result.maximum_height = 0
		310:
			_apply_current_water_fire(result)
			result.pulse_ticks = 30
			result.pulse_damage = 12_000
			result.maximum_height = 48_000
			result.transparent = true
			result.conceals = false
			result.modifier_channels = ["heat", "cool"]
			result.modifier_uses_per_channel = 1
			result.exposure_cap = 240
			result.exposure_exit_decay = 2
			result.exposure_damage_min = 2_000
			result.exposure_damage_max = 12_000
		311:
			result.selection_kind = Footprint.KIND_SECTOR
			result.pulse_damage = 4_000
			result.obstacle_aware_motion = false
			result.refreshes_payload = false
			result.refreshes_lifetime = false
		316:
			_apply_current_water_fire(result)
			result.flow_kind = "directional"
			result.flow_speed = 40_000
			result.common_wall_clearance = 18_000
			result.ground_only = true
			result.maximum_height = 0
		317:
			result.selection_kind = Footprint.KIND_SECTOR
			result.transparent = true
			result.conceals = false
			result.flow_kind = "directional_steering"
			result.flow_speed = 25_000
			result.capacity = 600
			result.suppression_quantity = 600
			result.pulse_damage = 0
		322:
			result.flow_kind = "tangential_rotation"
			result.flow_speed = 45_000
			result.projectile_speed_ratio = 1000
			result.immobilizes = false
			result.traps = false


static func _apply_current_water_fire(result: Dictionary) -> void:
	result.selection_kind = Footprint.KIND_DISK
	result.formation_ticks = 24
	result.active_ticks = 360
	result.decay_ticks = 60
	result.radius = 64_000
	result.length = 0
	result.quantity_policy = "matched_source_quantity"


# Retain geometry, paid formation and control identities. Utility reactions
# stay useful tools; light/fracture gain bounded hostile pressure, not stun.
static func _apply_combat_options(result: Dictionary) -> void:
	match int(result.wire_id):
		312:
			result.pulse_damage = 8_000
			result.ground_only = true
			result.maximum_height = 0
		314, 332:
			result.pulse_damage = 6_000
		334, 335:
			result.pulse_damage = 3_000
			result.pulse_ticks = 72


# Six live ingredients retain stable sparse wire identities. Archived rows above
# remain art/legacy identifiers, never active recipes or selectable ingredients.
static func _apply_six_element_contract(result: Dictionary) -> void:
	var wire := int(result.wire_id)
	result.effect_once_per_actor = wire in [301, 304, 307, 311, 314, 315, 316, 321, 325, 335]
	match wire:
		301:
			result.pulse_damage = 6_000
			result.purpose = "one eruption hit raises a breakable pillar that cuts a firing lane or creates a wallrun approach"
			result.counter = "break the 32-Health pillar, go around, or wait; trapped occupants can escape"
		303:
			result.name = "Quagmire"
			result.pulse_ticks = 42
			result.pulse_damage = 3_000
			result.purpose = "70% ground acceleration and braking; staying for 350 ms starts grounded attrition"
			result.counter = "jump or leave before 350 ms; movement ratios end immediately outside"
		304:
			result.name = "Sandblast"
			result.flow_speed = 0
			result.pulse_damage = 6_000
			result.purpose = "one grounded hit and 14 px sideways displacement per hostile actor"
			result.counter = "jump across or leave during formation; solid cover stops the displacement"
		307:
			result.pulse_damage = 6_000
			result.purpose = "one hostile contact cut; bank existing paid projectiles off a breakable reflection plane"
			result.counter = "change approach or break the 18-Health plane with Spray; ownership never changes"
		308:
			result.pulse_ticks = 60
			result.pulse_damage = 3_000
			result.ground_only = true
			result.maximum_height = 0
			result.purpose = "grounded pulses deny Health, Flux and Stamina recovery while occupied"
			result.counter = "jump or leave the soil; ordinary recovery waits still apply afterwards"
		311:
			result.name = "Arcstorm"
			result.geometry_kind = "branch"
			result.selection_kind = Footprint.KIND_CAPSULE
			result.radius = _extent(10_000)
			result.length = _extent(180_000)
			result.formation_ticks = 54
			result.active_ticks = 15
			result.pulse_ticks = 0
			result.pulse_damage = 9_000
			result.purpose = "one warned electrical line burst; one separate paid Fire source can extend the arc"
			result.counter = "leave the previewed line before activation or consume its optional Fire link"
		314:
			result.purpose = "one radial flash deals damage and reveals targets for 700 ms"
			result.counter = "leave the forming disk; this pulse cannot fire again"
		315:
			result.name = "Backdraft"
			result.pulse_ticks = 0
			result.pulse_damage = 12_000
			result.purpose = "concealing fuse becomes transparent for its last 600 ms, then bursts once"
			result.counter = "leave during the visible final warning; no damage before detonation"
		316:
			result.name = "Frostway"
			result.pulse_damage = 4_000
			result.ground_target_ratio = 750
			result.geometry_kind = "corridor"
			result.selection_kind = Footprint.KIND_CAPSULE
			result.radius = _extent(24_000)
			result.length = _extent(160_000)
			result.formation_ticks = 78
			result.active_ticks = 420
			result.decay_ticks = 72
			result.flow_kind = "none"
			result.flow_speed = 0
			result.quantity_policy = "paid_source_transfer"
			result.projectile_speed_ratio = 650
			result.slow_ratio = 750
			result.purpose = "one grounded freezing hit; ground travel is 75% and physical projectiles travel at 65%"
			result.counter = "slide, jump, or leave; air movement and slide speed remain unchanged"
		317:
			result.name = "Hailcurrent"
			result.geometry_kind = "pulse_lane"
			result.selection_kind = Footprint.KIND_CAPSULE
			result.radius = _extent(14_000)
			result.length = _extent(180_000)
			result.pulse_ticks = 54
			result.pulse_damage = 3_000
			result.capacity = 0
			result.suppression_quantity = 0
			result.purpose = "narrow hail pulses combine with a grounded current along the cast direction"
			result.counter = "leave laterally; jumping avoids current and ground-level hail"
		320:
			result.pulse_ticks = 60
			result.pulse_damage = 3_000
			result.purpose = "disturbing the mirror surface reveals movement and triggers damage on each pulse"
			result.counter = "stand still between pulses after the entry reveal, or leave the disk"
		321:
			result.name = "Black Ice"
			result.ground_only = true
			result.maximum_height = 0
			result.pulse_damage = 4_000
			result.purpose = "entry briefly slows; the first grounded exit fractures the ice for one hit"
			result.counter = "jump out to avoid the exit fracture; each actor can be hit only once"
		322:
			result.pulse_ticks = 54
			result.pulse_damage = 3_000
			result.purpose = "rotating ground current and pulses guard an annulus around an open center"
			result.counter = "use the center opening, jump, or leave between pulses"
		325:
			result.pulse_damage = 6_000
			result.purpose = "one hostile contact flash; bend paid Light projectiles by 15 degrees for a different attack angle"
			result.counter = "change the Light approach angle or leave the redirected firing lane"
		326:
			result.pulse_ticks = 36
			result.pulse_damage = 4_000
			result.purpose = "a stationary corridor alternates 300 ms of concealing damage and 300 ms of clear safety"
			result.counter = "cross during the transparent interval or leave laterally"
		334:
			result.purpose = "continuous reveal and regular searing pulses also threaten airborne actors"
			result.counter = "leave between 600 ms pulses; jumping alone does not escape"
		335:
			result.geometry_kind = "annulus"
			result.selection_kind = Footprint.KIND_ANNULUS
			result.length = _extent(46_000)
			result.pulse_damage = 6_000
			result.pulse_ticks = 0
			result.purpose = "one damaging revealed boundary crossing per actor, with a safe interior"
			result.counter = "avoid the marked ring or shelter inside; repeated crossings cannot repeat the hit"
		336:
			result.purpose = "concealed dwell pressure grows from 2 to 6 Health per pulse after one second"
			result.counter = "move to reveal occupants or exit before one second; exit resets dwell pressure"


static func _selection_kind(effect_geometry: String) -> String:
	if effect_geometry in ["ring", "annulus"]: return Footprint.KIND_ANNULUS
	if effect_geometry in ["front", "corridor", "growing_strip", "pulse_lane", "bands", "reveal_line", "water_path", "frost_path", "branch", "cover", "plane", "lens"]:
		return PENDING_CAPSULE_KIND
	return Footprint.KIND_DISK


static func _compiled_damage(wire: int) -> int:
	return int({302: 5_000, 309: 8_000, 311: 4_000, 313: 9_000, 315: 3_000, 319: 6_000, 323: 3_000, 324: 5_000, 328: 8_000, 336: 2_000}.get(wire, 0))


static func _compiled_flow_speed(wire: int) -> int:
	return int({304: 25_000, 316: 40_000, 322: 45_000}.get(wire, 0))


static func _compiled_flow_kind(wire: int) -> String:
	return String({304: "lateral", 316: "directional", 322: "tangential_rotation"}.get(wire, "none"))


static func _compiled_slow_ratio(wire: int) -> int:
	return int({303: 700, 318: 650, 330: 650}.get(wire, 1000))


static func _display_name(wire: int, id: String) -> String:
	if wire == 301:
		return "Rampart"
	if wire == 327:
		return "Frostway"
	if wire == 331:
		return "Capacitor"
	return id.replace("_", " ").capitalize()


static func _extent(value: int) -> int:
	return value * 1250 / 1000


static func _ticks(milliseconds: int) -> int:
	return 0 if milliseconds <= 0 else maxi(1, (milliseconds * TICK_RATE + 999) / 1000)


static func _aim_valid(aim: Vector2i) -> bool:
	var squared := aim.x * aim.x + aim.y * aim.y
	return absi(aim.x) <= 1000 and absi(aim.y) <= 1000 and squared >= 998_001 and squared <= 1_000_000


static func active_wire_ids() -> Array[int]:
	return ACTIVE_RECIPE_WIRES.duplicate()


static func element_bit(element: int) -> int:
	var index := Composite.ELEMENT_WIRES.find(element)
	return 0 if index < 0 else 1 << index


static func mask_for_wire(wire: int) -> int:
	if wire > 400: return wire - 400 if Composite.NAMES.has(wire - 400) else 0
	if wire not in ACTIVE_RECIPE_WIRES: return 0
	var row: Array = COMPILED_ROWS[wire - 301]
	return element_bit(int(row[1])) | element_bit(int(row[2]))


static func elements_for_mask(mask: int) -> Array[int]:
	return Composite.elements(mask)


static func wire_for_mask(mask: int) -> int:
	var elements := elements_for_mask(mask)
	if elements.size() >= 3: return 400 + mask if Composite.NAMES.has(mask) else 0
	return recipe_wire(elements[0], elements[-1]) if not elements.is_empty() else 0


static func recipe_wire_for_mask(mask: int) -> int:
	return wire_for_mask(mask)
