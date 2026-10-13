extends RefCounted
## Read-only normalization for authoritative loss events. Ground pressure keeps
## its established event schema; observers must not mistake it for zero damage.
const GROUND_TYPES := ["hex_pressure", "hex_conflagration"]


static func amount(event: Dictionary) -> int:
	return maxi(0,int(event.get("amount",0))) if String(event.get("type","")) in GROUND_TYPES else maxi(0,int(event.get("damage",0)))


static func target_id(event: Dictionary) -> int:
	return int(event.get("entity_id",0)) if String(event.get("type","")) in GROUND_TYPES else int(event.get("target_id",0))


static func element_mask(event: Dictionary, world: SimWorld) -> int:
	# A product can have several paid parents; report its canonical ingredients,
	# never invent one parent spell wire for the whole interaction.
	var wire := int(event.get("source_wire_id",event.get("wire_id",0)))
	if CombatTuning.is_runtime_wire_id(wire): return int(CombatTuning.cast_definition_view(wire).get("element_mask",0))
	if world == null or world.hex_court == null: return 0
	var owner := int(event.get("owner_id",0))
	var cast_id := int(event.get("cast_id",0))
	if cast_id<=0: cast_id = int(world.hex_court.sources.get(int(event.get("source_id",0)),0))
	var record: Dictionary = world.hex_court.casts.get(cast_id,{})
	if not record.is_empty() and bool(record.get("paid",false)) and int(record.get("owner",0))==owner:
		return int(record.get("element_mask",0))
	var product_id := int(event.get("product_id",event.get("reaction_id",0)))
	var product: Dictionary = world.hex_court.products.get(product_id,{})
	if product.is_empty() or int(product.get("owner",product.get("owner_id",0)))!=owner: return 0
	return HexRecipePolicy.mask_for_wire(int(product.get("recipe_wire_id",0)))
