extends HexChemistryWorld
## Derived selection reuse belongs only to one harmless Garden. Live chemistry
## keeps its ordinary selector, payment, ownership, lifetime and collision rules.
const TOPOLOGY_RADIUS := 4
const MAX_SELECTIONS := 64
const MAX_SELECTION_CELLS := 61

class SelectionMemo extends RefCounted:
	var _selections: Dictionary = {}
	var hits := 0
	var misses := 0
	var fallbacks := 0

	func clear() -> void:
		_selections.clear()
		hits = 0
		misses = 0
		fallbacks = 0

	func find(key: Array) -> Variant:
		if _selections.has(key):
			hits += 1
			return _selections[key]
		misses += 1
		return null

	func remember(key: Array, selected: Array[Vector2i]) -> void:
		if _selections.size() >= MAX_SELECTIONS or selected.size() > MAX_SELECTION_CELLS: return
		var owned_key := key.duplicate()
		var owned_cells := selected.duplicate()
		owned_key.make_read_only()
		owned_cells.make_read_only()
		_selections[owned_key] = owned_cells

	func stats() -> Dictionary:
		return {"resident": _selections.size(), "hits": hits, "misses": misses, "fallbacks": fallbacks}


var _selection_memo: SelectionMemo
var _selection_topology: HexCellTopology = null
var _selection_origin := Vector2i.ZERO


func _init(memo: SelectionMemo = null) -> void:
	_selection_memo = memo


func configure_geometry(requested_origin: Vector2i, eligible_cells: Array[Vector2i]) -> bool:
	_selection_topology = null
	if not super.configure_geometry(requested_origin, eligible_cells): return false
	var expected := HexGrid.disk(Vector2i.ZERO, TOPOLOGY_RADIUS)
	expected.sort()
	# Base construction seals every member. A same-size edited/translated disk
	# is not sufficient; the entire canonical relative topology must match.
	if _cell_topology != null and _cell_topology.get_script() == CellTopology and _cell_topology.numeric_cells() == expected:
		_selection_topology = _cell_topology
		_selection_origin = origin
	return true


func select_cells(shape: Dictionary, eligible: Variant = null) -> Array[Vector2i]:
	if _selection_memo == null or get_script().resource_path != "res://src/app/element_garden_court.gd" \
			or eligible != null or collision != null or _selection_topology == null \
			or _cell_topology != _selection_topology or origin != _selection_origin:
		return _ordinary_selection(shape, eligible)
	# Check absolute world bounds before deriving a translation-invariant key.
	# Only integer primitives whose base predicates use origin-relative values
	# are memoized; unknown/additional fields and composite/sector paths fall back.
	if not HexFootprint.validate(shape): return _ordinary_selection(shape, eligible)
	var key := _selection_key(shape)
	if key.is_empty(): return _ordinary_selection(shape, eligible)
	var resident: Variant = _selection_memo.find(key)
	if resident != null:
		var detached: Array[Vector2i] = resident.duplicate()
		return detached
	var selected := super.select_cells(shape)
	_selection_memo.remember(key, selected)
	return selected


func _ordinary_selection(shape: Dictionary, eligible: Variant) -> Array[Vector2i]:
	if _selection_memo != null: _selection_memo.fallbacks += 1
	return super.select_cells(shape, eligible)


func _selection_key(shape: Dictionary) -> Array:
	match String(shape.get("kind", "")):
		HexFootprint.KIND_DISK:
			if shape.size() == 3 and typeof(shape.get("radius")) == TYPE_INT:
				return [HexFootprint.KIND_DISK, Vector2i(shape.center) - origin, int(shape.radius)]
		HexFootprint.KIND_CAPSULE:
			if shape.size() == 4:
				return [HexFootprint.KIND_CAPSULE, Vector2i(shape.start) - origin, Vector2i(shape.end) - origin, int(shape.radius)]
		HexFootprint.KIND_ANNULUS:
			if shape.size() == 4:
				return [HexFootprint.KIND_ANNULUS, Vector2i(shape.center) - origin, int(shape.inner_radius), int(shape.outer_radius)]
	return []
