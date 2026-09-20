from pathlib import Path
p=Path(__file__).parent/'src/sim/hex/hex_chemistry_world.gd'
s=p.read_text(encoding='utf-8')
a=s.index('func conservation_valid(');b=s.index('\nstatic func _layer',a)
s=s[:a]+r'''func conservation_valid() -> bool:
	if casts.size() > MAX_CASTS or products.size() > MAX_PRODUCTS or cells.size() > MAX_CELLS or reserved_products() > MAX_PRODUCTS: return false
	for cell: Vector2i in cells:
		for element: int in range(1, 9):
			var layer := Policy.ingredient_layer(element)
			for id: int in cells[cell][layer]:
				if not casts.has(id) or int(casts[id].element) != element or not casts[id].cells.has(cell) or int(casts[id].cells[cell]) != int(cells[cell][layer][id]): return false
		for wire: int in range(301, 337):
			var layer := Policy.product_layer(wire)
			for id: int in cells[cell][layer]:
				if not products.has(id) or int(products[id].recipe_wire_id) != wire or not products[id].cells.has(cell) or int(products[id].cells[cell]) != int(cells[cell][layer][id]): return false
	var live := 0
	for id: int in casts:
		var record: Dictionary = casts[id]
		if record.ledger.is_empty():
			if int(record.source) != 0 or not record.cells.is_empty() or int(record.ground) != 0 or int(record.unallocated) + int(record.consumed) + int(record.expired) != int(record.budget): return false
		else:
			if not Parts.validate(record): return false
			if int(record.ground) != int(record.ledger.deposited_quantity) or int(record.unallocated) != int(record.ledger.flight_quantity) or int(record.consumed) != int(record.ledger.consumed_quantity) or int(record.expired) != int(record.ledger.expired_quantity): return false
			for cell: Vector2i in record.cells:
				if not cells.has(cell) or not cells[cell][_layer(record)].has(id) or int(cells[cell][_layer(record)][id]) != int(record.cells[cell]): return false
		if bool(record.paid): live += int(record.unallocated) + int(record.ground)
	var product_total := 0
	for id: int in products:
		var product: Dictionary = products[id]
		var total := 0
		if int(product.quantity) <= 0 or product.cells.size() != product.coverage.size() or product.cells.is_empty(): return false
		for cell: Vector2i in product.cells:
			if not cells.has(cell) or int(product.cells[cell]) < 0 or int(product.coverage.get(cell, 0)) != 1 or not cells[cell][product.material].has(id) or int(cells[cell][product.material][id]) != int(product.cells[cell]): return false
			total += int(product.cells[cell])
		if total != int(product.quantity): return false
		product_total += total
	return live + int(metrics.matter_consumed) + int(metrics.matter_expired) == int(metrics.matter_paid) and product_total <= int(metrics.matter_consumed)

''' +s[b:]
# Remove obsolete pre-partition cell mutation helpers; all live changes use Parts.
for name,next_name in [('_retile_cast_proportionally','_expire_live'),('_take_ground','_expire_unallocated')]:
    a=s.index('func '+name+'('); b=s.index('\nfunc '+next_name+'(',a)
    s=s[:a]+s[b+1:]
# Independent ground part IDs are dictionary keys, not redundant schema fields.
s=s.replace('for part: Dictionary in record.get("ground_parts", {}).values():\n\t\t\t\tif not part.coverage', 'for part_id: int in record.get("ground_parts", {}):\n\t\t\t\tvar part: Dictionary = record.ground_parts[part_id]\n\t\t\t\tif not part.coverage')
s=s.replace('"footprint_id": int(part.id)', '"footprint_id": part_id')
p.write_text(s,encoding='utf-8',newline='\n')
