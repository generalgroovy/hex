extends RefCounted
## Bounded provenance survives source retirement without retaining dead casts.
## Each triple is [source ID, immutable spell wire, actual consumed strength].

static func from_sources(world: HexChemistryWorld, source_ids: Array, strength: int) -> PackedInt64Array:
	var result := PackedInt64Array()
	for source: int in source_ids:
		if not world.sources.has(source): return PackedInt64Array()
		var record: Dictionary = world.casts[int(world.sources[source])]
		result = add(result, source, int(record.wire), strength)
		if result.is_empty(): return result
	return result


static func add(rows: PackedInt64Array, source: int, wire: int, strength: int) -> PackedInt64Array:
	if source <= 0 or strength <= 0 or rows.size() % 3 != 0 or rows.size() >= 36: return PackedInt64Array()
	var definition := CombatTuning.cast_definition_view(wire)
	if definition.is_empty() or strength > int(definition.get("reaction_strength", 0)): return PackedInt64Array()
	var result := PackedInt64Array()
	var inserted := false
	for index: int in range(0, rows.size(), 3):
		if rows[index] == source: return PackedInt64Array()
		if not inserted and source < rows[index]:
			result.append_array(PackedInt64Array([source, wire, strength]))
			inserted = true
		result.append_array(rows.slice(index, index + 3))
	if not inserted: result.append_array(PackedInt64Array([source, wire, strength]))
	return result


static func merge(parents: Array) -> PackedInt64Array:
	var result := PackedInt64Array()
	for parent: Dictionary in parents:
		var rows: PackedInt64Array = parent.get("source_funding", PackedInt64Array())
		if rows.is_empty() or rows.size() % 3 != 0: return PackedInt64Array()
		for index: int in range(0, rows.size(), 3):
			result = add(result, rows[index], rows[index + 1], rows[index + 2])
			if result.is_empty(): return result
	return result


static func total(rows: PackedInt64Array) -> int:
	var result := 0
	for index: int in range(2, rows.size(), 3): result += rows[index]
	return result
