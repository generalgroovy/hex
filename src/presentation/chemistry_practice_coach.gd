class_name ChemistryPracticeCoach
extends RefCounted

const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")
const Guide = preload("res://src/presentation/chemistry_guide_model.gd")

# Compact effect/counter summaries of ChemistryGuideModel, not the historical
# reaction catalog's aspirational lore. Simulation still owns every outcome.
const CUES: Array = [
	["Active stone blocks movement, shots and rays.", "Wallrun/kick from it; go around, break or wait."],
	["The moving hot lane damages grounded enemies.", "Counter: jump across or leave the front."],
	["Grounded enemies are slowed while inside.", "Counter: jump across or leave the patch."],
	["Dust conceals at distance and shoves grounded enemies.", "Counter: close in to see; jump clear of the shove."],
	["Brittle cover stops shots and rays, not walking.", "Counter: attack the ridge or wait for decay."],
	["Shot cover absorbs Charge using a finite reserve.", "Counter: exhaust its Charge reserve or destroy it."],
	["The plane reflects shots and rays of every element.", "Counter: change angle, go around or wait for decay."],
	["Enemy resource recovery is blocked inside; no drain.", "Counter: leave the patch to resume recovery."],
	["The fire ring pulses damage, including against jumps.", "Counter: use the centre hole or leave the ring."],
	["Steam conceals distant silhouettes; no damage or wet.", "Counter: Light + Light makes revealing Radiance."],
	["The travelling flame lane pulses damage, even in air.", "Counter: cross its narrow side between pulses."],
	["One fracture damages active constructs, not actors.", "Use against reaction cover; worldbone stays intact."],
	["A damaging arc requires a separate live Charge link.", "Counter: leave the line or let its source expire."],
	["One pulse reveals actors, without damage or healing.", "Counter: leave during formation to avoid the mark."],
	["Mist conceals; enemies dwelling 0.5s can take damage.", "Counter: leave before the dwell threshold."],
	["The shallow current pushes grounded enemies only.", "Counter: jump over its push or leave sideways."],
	["Travelling mist conceals; no damage or forced motion.", "Counter: close distance or step outside the lane."],
	["The growing strip briefly slows grounded entrants.", "Counter: jump across; it does not freeze actors."],
	["Damage pulses locally or along separate Water links.", "Counter: leave the area/path or let its links expire."],
	["Entry and movement reveal actors; no healing/damage.", "Counter: stop moving or leave to stop refreshing it."],
	["Mist conceals, but moving actors are revealed.", "Counter: stay still until reveal expires, or leave."],
	["The ring pushes grounded enemies sideways; no damage.", "Counter: jump or cross toward its safe centre."],
	["An icy damage pulse repeatedly travels down the lane.", "Counter: pass behind the moving pulse."],
	["The drifting disk pulses damage; no stun or chaining.", "Counter: leave its radius before the next pulse."],
	["Only Light shots and rays bend by 15 degrees.", "Counter: adjust aim or use a non-Light shot."],
	["The drifting lane alternates concealment on and off.", "Counter: leave the lane or use its visible interval."],
	["Both teams: walk 75%; physical shots travel 65%.", "Slide or jump across; leave or wait. No cover."],
	["A damage path requires separate live Ice links.", "Counter: leave the path or let a link expire."],
	["Light can split with shared damage; others hit cover.", "Shots need spare capacity and damage; break or bypass cover."],
	["Entry reveals; grounded enemies slow after 0.35s.", "Counter: leave or jump before the dwell threshold."],
	["Both teams accelerate; final discharge moves enemies.", "Leave sideways or jump before release; no stun."],
	["One line pulse reveals actors; no damage or stun.", "Counter: leave the lane during formation."],
	["Mist conceals, but entry/exit briefly reveals actors.", "Counter: do not rely on concealment while crossing."],
	["Actors inside are revealed; no healing or damage.", "Counter: leave or put worldbone across its sightline."],
	["Entering/leaving marks actors; no concealment/damage.", "Counter: avoid crossing if you want to stay unmarked."],
	["Mist conceals; movement reveals; 1s dwell risks damage.", "Counter: leave before 1s; standing still is not safe."],
]


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
		var strength_copy := "Match reaction strength %d with %s." % [latest_deposit.reaction_strength, "separate terminal matter" if trail else "a separate cast"]
		return {
			"kind": "matter", "title": "%s %s" % [Guide.ELEMENTS[latest_deposit.element_wire_id], "TRAIL" if trail else "MATTER"],
			"phase": "HARMLESS / %.2fs LEFT" % _seconds(latest_deposit.expiry_tick - tick, config),
			"entity_id": latest_deposit.entity_id, "recipe_wire_id": 0,
			"remaining_ticks": latest_deposit.expiry_tick - tick,
			"lines": PackedStringArray(["Narrow trail: no direct damage or status.", strength_copy, "Trail + trail never reacts; sustained results are shorter."]) if trail else PackedStringArray(["Plain terminal matter causes no damage or status.", strength_copy, "Overlap before expiry; unequal strength stays matter."]),
		}
	return {
		"kind": "invitation", "title": "CRUCIBLE / TRY A PAIR", "phase": "FREE EXPERIMENT",
		"entity_id": 0, "recipe_wire_id": 0, "remaining_ticks": 0,
		"lines": PackedStringArray(["Use separate casts with matching reaction strength.", "Cross-element pairs use one family: Bolt, Heavy or Rapid.", "Spray leaves no chemistry matter; it cannot supply a pair."]),
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
	var cue: Array = CUES[reaction.recipe_wire_id - 301]
	var effect := String(cue[0])
	var counter := String(cue[1])
	if tick < reaction.active_tick:
		phase = "FORMING / HARMLESS WARNING"
		end_tick = reaction.active_tick
		effect = "Then: " + effect
	elif tick >= reaction.decay_tick:
		phase = "HARMLESS DECAY"
		end_tick = reaction.expiry_tick
		effect = "This reaction's decay does not apply effects."
		counter = "Try another pair after it clears; Bell resets the court."
	elif reaction.recipe_wire_id == 310 and not Chemistry._concealing(reaction, tick, config):
		effect = "Steam has thinned; it no longer conceals silhouettes."
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
