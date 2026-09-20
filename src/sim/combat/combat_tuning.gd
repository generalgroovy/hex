class_name CombatTuning
extends RefCounted


# Stable wire IDs are protocol adapters. All spell economy, timing, geometry,
# damage, control, and runtime ordering are authored in the ability catalog and
# compiled once by CombatDefinitionTable.
const PRIMARY_WIRE_ID: int = 101
const VECTOR_LANCE_WIRE_ID: int = 110
const RILLSHOT_WIRE_ID: int = 140
# New authored profiles use retained Rillshot for Active 1. Known retired
# authored IDs remain inspectable through LoadoutDefinition and are never
# rewritten through this alias.
const ACTIVE_1_WIRE_ID: int = RILLSHOT_WIRE_ID
const TIDELINE_WIRE_ID: int = 141
const ECLIPSE_DISC_WIRE_ID: int = 142
const POCKET_ECLIPSE_WIRE_ID: int = 143
const RIMEWAKE_WIRE_ID: int = 144
const CINDERBOLT_WIRE_ID: int = 145
const CINDERFAN_WIRE_ID: int = 146
const EARTH_BURST_WIRE_ID: int = 147
const WATER_BURST_WIRE_ID: int = 148
const WIND_BURST_WIRE_ID: int = 149
const ICE_BURST_WIRE_ID: int = 150
const CHARGE_BURST_WIRE_ID: int = 151
const LIGHT_BURST_WIRE_ID: int = 152
const DARK_BURST_WIRE_ID: int = 153

# Historical Wave wires retain their original fixture order. They are not a
# runtime or display-order list and do not compile to cast definitions.
const ELEMENTAL_BURST_WIRE_IDS: Array[int] = [
	CINDERFAN_WIRE_ID,
	WATER_BURST_WIRE_ID,
	EARTH_BURST_WIRE_ID,
	WIND_BURST_WIRE_ID,
	CHARGE_BURST_WIRE_ID,
	ICE_BURST_WIRE_ID,
	LIGHT_BURST_WIRE_ID,
	DARK_BURST_WIRE_ID,
]

# Cross-spell combat rules remain code-owned because they are not authored
# properties of any one ability.
const NO_HIT_CONTROL_STATE: int = 0
const PROJECTILE_SPAWN_CLEARANCE: int = 4_000
const EDGEWEAVE_MARGIN: int = 16_000
const EDGEWEAVE_MINIMUM_SPEED: int = 260_000
const EDGEWEAVE_REWARD: int = 9_000
const EDGEWEAVE_COOLDOWN_MS: int = 220


static func is_runtime_wire_id(wire_id: int) -> bool:
	return CombatDefinitionTable.default_table().is_runtime_wire_id(wire_id)


static func runtime_wire_ids() -> Array[int]:
	return CombatDefinitionTable.default_table().runtime_wire_ids()


static func is_elemental_burst(wire_id: int) -> bool:
	return ELEMENTAL_BURST_WIRE_IDS.has(wire_id)


static func projectile_definition(wire_id: int) -> Dictionary:
	return CombatDefinitionTable.default_table().projectile_definition(wire_id)


static func cast_definition(wire_id: int) -> Dictionary:
	return CombatDefinitionTable.default_table().definition(wire_id)
