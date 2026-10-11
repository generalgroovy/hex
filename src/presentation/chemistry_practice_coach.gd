class_name ChemistryPracticeCoach
extends RefCounted

const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")
const Guide = preload("res://src/presentation/chemistry_guide_model.gd")
const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const Elements = preload("res://src/content/element_rules.gd")

# Current play path. Only snapshot observations are returned; no authority field is
# updated and no source is promoted to a reaction by this presenter.
static func sample_hex(actor_id: int, position_fixed: Vector2i, tick: int, config: SimConfig, bounds_pixels: Array, court: HexChemistryWorld, allowed: bool = true) -> Dictionary:
	if not allowed or actor_id <= 0 or tick < 0 or config == null or config.tick_rate <= 0 or court == null or not court.chemistry_enabled:
		return {}
	var bounds := _fixed_bounds(bounds_pixels)
	if not bounds.has_area() or not bounds.has_point(position_fixed):
		return {}
	var selected: Dictionary = {}
	for value: Variant in court.products.values():
		if not value is Dictionary: continue
		var product: Dictionary = value
		if int(product.get("owner", 0)) != actor_id or int(product.get("quantity", 0)) <= 0 or tick < int(product.get("created", 0)) or tick >= int(product.get("expiry_tick", 0)):
			continue
		if Policy.definition(int(product.get("recipe_wire_id", 0))).is_empty() or not _inside_practice(product.get("coverage", {}), court.origin, bounds):
			continue
		if selected.is_empty() or _newer(int(product.created), int(product.id), int(selected.created), int(selected.id)):
			selected = product
	if not selected.is_empty():
		return _hex_product_view(selected, tick, config)
	var matter: Dictionary = {}
	var part: Dictionary = {}
	for value: Variant in court.casts.values():
		if not value is Dictionary: continue
		var cast: Dictionary = value
		if int(cast.get("owner", 0)) != actor_id or not bool(cast.get("paid", false)) or not Elements.is_active_wire(int(cast.get("element", 0))): continue
		for part_value: Variant in (cast.get("ground_parts", {}) as Dictionary).values():
			if not part_value is Dictionary: continue
			var candidate: Dictionary = part_value
			if int(candidate.get("quantity", 0)) <= 0 or tick < int(candidate.get("created", 0)) or tick >= int(candidate.get("expiry_tick", 0)) or not _inside_practice(candidate.get("coverage", {}), court.origin, bounds): continue
			if matter.is_empty() or _newer(int(candidate.created), int(cast.id), int(part.created), int(matter.id)):
				matter = cast
				part = candidate
	if not matter.is_empty():
		return _hex_matter_view(matter, part, tick, config)
	return {"kind": "invitation", "title": "CRUCIBLE / COMBINE ELEMENTS", "phase": "SIX ELEMENTS / 63 RESULTS", "entity_id": 0, "recipe_wire_id": 0, "remaining_ticks": 0,
		"lines": _card_lines(["Overlap separate paid casts to form a reaction.", "Add distinct elements to build larger combinations.", "Help: exact purpose, damage triggers and counters."])}


static func _hex_matter_view(matter: Dictionary, part: Dictionary, tick: int, config: SimConfig) -> Dictionary:
	var name: String = Elements.NAMES[Elements.id_from_wire(int(matter.element))]
	var phase := "HARMLESS"
	var end_tick := int(part.expiry_tick)
	var effect := "Paid ground matter; no direct damage or status."
	var counter := "Add distinct elements to products; Help lists counters."
	if int(matter.element) == 2:
		var ignition := int(part.created) + HexChemistryWorld.IGNITION_TICKS
		var cooling := int(part.expiry_tick) - HexChemistryWorld.COOLING_TICKS
		if tick < ignition:
			phase = "IGNITING / HARMLESS"
			end_tick = ignition
			effect = "Fire will burn grounded actors after ignition."
		elif tick < cooling:
			phase = "ACTIVE FIRE"
			end_tick = cooling
			effect = "Fire burns grounded actors on pressure pulses."
		else:
			phase = "COOLING / HARMLESS"
			effect = "Fire is cooling; its ground pressure has ended."
		counter = "Counter: leave its occupied hexes or clear the ground."
	return {"kind": "matter", "title": name.to_upper() + " MATTER", "phase": "%s / %.2fs LEFT" % [phase, _seconds(end_tick - tick, config)],
		"entity_id": int(matter.id), "recipe_wire_id": 0, "remaining_ticks": end_tick - tick,
		"quantity": int(part.quantity), "lines": _card_lines([effect, "Overlap a separate paid cast before expiry.", counter])}


static func _hex_product_view(product: Dictionary, tick: int, config: SimConfig) -> Dictionary:
	var definition := Policy.definition(int(product.recipe_wire_id))
	var phase := "ACTIVE"
	var end_tick := int(product.decay_tick)
	var purpose := String(definition.purpose)
	var visible_effect := purpose
	var pool := maxi(0, int(product.get("damage_budget_remaining", 0)))
	if tick < int(product.active_tick):
		phase = "FORMING"
		end_tick = int(product.active_tick)
		visible_effect = "When active: " + purpose
	elif tick >= int(product.decay_tick):
		phase = "HARMLESS DECAY"
		end_tick = int(product.expiry_tick)
		visible_effect = "This product is fading; no new effects are applied."
	elif pool == 0:
		phase = "DAMAGE STOCK SPENT"
		visible_effect = "Damage stock spent; situational effects may remain."
	var ingredients := PackedStringArray()
	for wire: int in definition.elements:
		ingredients.append(String(Elements.NAMES[Elements.id_from_wire(wire)]))
	var source_lines := [" + ".join(ingredients), visible_effect, "Counter: " + String(definition.counter)]
	return {"kind": "reaction", "title": _fit(String(definition.name).to_upper(), 14, 337.0),
		"phase": _fit("%s / %.2fs / %.1f SHARED DAMAGE" % [phase, _seconds(end_tick - tick, config), float(pool) / 1000.0], 12, 412.0),
		"entity_id": int(product.id), "recipe_wire_id": int(product.recipe_wire_id), "remaining_ticks": end_tick - tick,
		"damage_budget_remaining": pool, "purpose": purpose, "counter": String(definition.counter),
		"full_lines": PackedStringArray(source_lines), "lines": _card_lines(source_lines)}


static func _inside_practice(coverage: Dictionary, origin: Vector2i, bounds: Rect2i) -> bool:
	for cell: Variant in coverage:
		if cell is Vector2i and int(coverage[cell]) > 0 and bounds.has_point(origin + HexGrid.center(cell)):
			return true
	return false


static func _card_lines(lines: Array) -> PackedStringArray:
	var result := PackedStringArray()
	for line: String in lines: result.append(_fit(line, 12, 412.0))
	return result


static func _fit(value: String, size: int, width: float) -> String:
	var font := ThemeDB.fallback_font
	if font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width: return value
	var result := value
	while not result.is_empty() and font.get_string_size(result + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		result = result.left(result.length() - 1)
	return result + "…"


# Legacy two-source compatibility view, not the current Hex play path.

# Stateless snapshot observation: no command, timer, reward or progression state.
# bounds_pixels is the live crucible-experiment practice group's bounds array.
# A reaction may combine travellers' casts: owner_id is the authoritative oldest
# deposit's owner, not proof that both casts belonged to the local actor.
static func sample(actor_id: int, position_fixed: Vector2i, tick: int, config: SimConfig, bounds_pixels: Array, deposits: Array, reactions: Array, allowed: bool = true) -> Dictionary:
	if not allowed or actor_id <= 0 or tick < 0 or config == null or config.tick_rate <= 0:
		return {}
	var bounds := _fixed_bounds(bounds_pixels)
	if not bounds.has_area() or not bounds.has_point(position_fixed):
		return {}
	var latest_reaction: ElementReactionState = null
	for value: Variant in reactions:
		if not value is ElementReactionState:
			continue
		var reaction: ElementReactionState = value
		if not reaction.validate() or reaction.owner_id != actor_id or tick < reaction.created_tick or tick >= reaction.expiry_tick:
			continue
		if not bounds.has_point(Vector2i(reaction.origin_x, reaction.origin_y)):
			continue
		if latest_reaction == null or _newer(reaction.created_tick, reaction.entity_id, latest_reaction.created_tick, latest_reaction.entity_id):
			latest_reaction = reaction
	if latest_reaction != null:
		var counter := _radiance_steam_view(latest_reaction, actor_id, tick, config, bounds, reactions)
		if not counter.is_empty():
			return counter
		return _reaction_view(latest_reaction, tick, config, deposits)
	var latest_deposit: ElementDepositState = null
	for value: Variant in deposits:
		if not value is ElementDepositState:
			continue
		var deposit: ElementDepositState = value
		if not deposit.validate() or deposit.owner_id != actor_id or tick < deposit.created_tick or tick >= deposit.expiry_tick:
			continue
		if not bounds.has_point(Vector2i(deposit.position_x, deposit.position_y)):
			continue
		if latest_deposit == null or _newer(deposit.created_tick, deposit.entity_id, latest_deposit.created_tick, latest_deposit.entity_id):
			latest_deposit = deposit
	if latest_deposit != null:
		var trail := latest_deposit.is_trail()
		var strength_copy := "Paid reaction strength %d; combine with a separate cast." % latest_deposit.reaction_strength
		return {
			"kind": "matter", "title": "%s %s" % [Guide.ELEMENTS[latest_deposit.element_wire_id], "TRAIL" if trail else "MATTER"],
			"phase": "HARMLESS / %.2fs LEFT" % _seconds(latest_deposit.expiry_tick - tick, config),
			"entity_id": latest_deposit.entity_id, "recipe_wire_id": 0,
			"remaining_ticks": latest_deposit.expiry_tick - tick,
			"lines": PackedStringArray(["Narrow trail: no direct damage or status.", strength_copy, "Trail + trail never reacts; sustained results are shorter."]) if trail else PackedStringArray(["Plain terminal matter causes no damage or status.", strength_copy, "Overlap before expiry; unmatched strength stays matter."]),
		}
	return {
		"kind": "invitation", "title": "CRUCIBLE / TRY A PAIR", "phase": "FREE EXPERIMENT",
		"entity_id": 0, "recipe_wire_id": 0, "remaining_ticks": 0,
		"lines": PackedStringArray(["Try two paid casts, or choose a mixed payload in the Range.", "Eight deliveries share finite paid stock; read each role.", "Add distinct elements to products; inspect counters in Help."]),
	}


static func _radiance_steam_view(latest: ElementReactionState, actor_id: int, tick: int, config: SimConfig, bounds: Rect2i, reactions: Array) -> Dictionary:
	if latest.recipe_wire_id not in [310, 334] or not latest.active(tick):
		return {}
	var other_wire := 334 if latest.recipe_wire_id == 310 else 310
	var partner: ElementReactionState = null
	for value: Variant in reactions:
		if not value is ElementReactionState:
			continue
		var candidate: ElementReactionState = value
		if candidate.recipe_wire_id != other_wire or not candidate.validate() or candidate.owner_id != actor_id or not candidate.active(tick):
			continue
		var origin := Vector2i(candidate.origin_x, candidate.origin_y)
		if not bounds.has_point(origin) or Chemistry.cell(origin) == Chemistry.cell(Vector2i(latest.origin_x, latest.origin_y)):
			continue # Separate admitted results, never a recursive recipe.
		var steam := candidate if other_wire == 310 else latest
		if not Chemistry._concealing(steam, tick, config):
			continue
		var distance := Vector2i(candidate.position_x - latest.position_x, candidate.position_y - latest.position_y)
		var reach := candidate.radius + latest.radius
		if distance.length_squared() > reach * reach:
			continue # Current masks, not their eventual or catalog-max radius.
		if partner == null or _newer(candidate.created_tick, candidate.entity_id, partner.created_tick, partner.entity_id):
			partner = candidate
	if partner == null:
		return {}
	var radiance := latest if latest.recipe_wire_id == 334 else partner
	var steam := latest if latest.recipe_wire_id == 310 else partner
	var end_tick := mini(radiance.decay_tick, steam.decay_tick - config.milliseconds_to_ticks(350))
	# The compact API intentionally has no actor statuses or collision world.
	# Teach the conditional relationship; never claim a particular actor was
	# revealed, that sightlines are clear, or that either reaction was consumed.
	return {
		"kind": "reaction", "title": "RADIANCE / STEAM",
		"phase": "ACTIVE OVERLAP / %.2fs" % _seconds(end_tick - tick, config),
		"entity_id": latest.entity_id, "recipe_wire_id": latest.recipe_wire_id,
		"remaining_ticks": end_tick - tick,
		"lines": PackedStringArray([
			"Two reactions: Light + Light; Fire + Water.",
			"Radiance reveals actors it can reach inside Steam.",
			"Leave Radiance or use worldbone; its reveal fades.",
		]),
	}


static func _reaction_view(reaction: ElementReactionState, tick: int, config: SimConfig, deposits: Array) -> Dictionary:
	var recipe := Chemistry.recipe(reaction.recipe_wire_id)
	if recipe.is_empty():
		return {}
	var phase := "ACTIVE"
	var end_tick := reaction.decay_tick
	var definition := Policy.definition(reaction.recipe_wire_id)
	if definition.is_empty(): return {}
	var effect := String(definition.purpose)
	var counter := "Counter: " + String(definition.counter)
	if tick < reaction.active_tick:
		phase = "FORMING / HARMLESS WARNING"
		end_tick = reaction.active_tick
		effect = "Then: " + effect
	elif tick >= reaction.decay_tick:
		phase = "HARMLESS DECAY"
		end_tick = reaction.expiry_tick
		effect = "This reaction's decay does not apply effects."
		counter = "Try another pair after it clears; Bell resets the court."
	elif reaction.recipe_wire_id in [313, 319, 328] and not _damage_links_ready(reaction, deposits, tick):
		effect = "No live linked source: this reaction cannot deal damage."
		counter = "Set separate source matter before forming another pair."
	return {
		"kind": "reaction", "title": String(recipe.name).to_upper(),
		"phase": "%s / %.2fs" % [phase, _seconds(end_tick - tick, config)],
		"entity_id": reaction.entity_id, "recipe_wire_id": reaction.recipe_wire_id,
		"remaining_ticks": end_tick - tick,
		"lines": PackedStringArray(["%s + %s" % [Guide.ELEMENTS[int(recipe.elements[0])], Guide.ELEMENTS[int(recipe.elements[1])]], effect, counter]),
	}


static func _damage_links_ready(reaction: ElementReactionState, deposits: Array, tick: int) -> bool:
	if reaction.linked_deposit_ids.is_empty():
		return reaction.recipe_wire_id == 319
	for linked_id: int in reaction.linked_deposit_ids:
		var found := false
		for value: Variant in deposits:
			if value is ElementDepositState:
				var deposit: ElementDepositState = value
				if deposit.entity_id == linked_id and deposit.validate() and tick >= deposit.created_tick and tick < deposit.expiry_tick:
					found = true
					break
		if not found:
			return false
	return true


static func _newer(created_tick: int, entity_id: int, other_tick: int, other_id: int) -> bool:
	return created_tick > other_tick or (created_tick == other_tick and entity_id > other_id)


static func _seconds(ticks: int, config: SimConfig) -> float:
	return float(maxi(0, ticks)) / float(config.tick_rate)


static func _fixed_bounds(values: Array) -> Rect2i:
	if values.size() != 4:
		return Rect2i()
	for value: Variant in values:
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)) or float(value) < 0.0 or float(value) > 100000.0:
			return Rect2i()
	return Rect2i(int(values[0]) * SimConfig.FIXED_SCALE, int(values[1]) * SimConfig.FIXED_SCALE, int(values[2]) * SimConfig.FIXED_SCALE, int(values[3]) * SimConfig.FIXED_SCALE)
