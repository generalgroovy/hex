extends RefCounted
## Read-only spell facts shared by Loom and Range. Reproject current conditions;
## never cache a PlayerState identity as a substitute for its changing values.
## Precedent: Riot's clarity hierarchy (threat/purpose before decoration):
## https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/
## Exact costs and comparisons are H.E.X. rules, not borrowed balance numbers.
const Perks = preload("res://src/sim/entities/identity_perk_policy.gd")
const Mixtures = preload("res://src/content/mixture_catalog.gd")

static func inspect(wire: int, state: PlayerState = null) -> Dictionary:
	var definition := CombatTuning.cast_definition(wire)
	if definition.is_empty(): return {}
	var config := SimConfig.new()
	var startup := config.milliseconds_to_ticks(int(definition.get("startup_ms", 0)))
	var cooldown := config.milliseconds_to_ticks(int(definition.get("cooldown_ms", 0)))
	var timing := {"startup_ticks":startup,"cooldown_ticks":cooldown,"suppressed_pairs":[]}
	if state != null: timing = Perks.spell_timing(state, definition, config, SpellStatusPolicy.startup_ratio(state))
	var speed := int(definition.get("speed", 0))
	var reach := float(definition.get("range", 0)) / 1000.0
	if reach <= 0: reach = float(speed) * float(definition.get("lifetime_ms", 0)) / 1000000.0
	return {"wire":wire,"family":String(definition.get("family", "")),
		"flux":float(definition.get("flux_cost",0))/1000.0,"damage":float(definition.get("damage",0))/1000.0,
		"strength":int(definition.get("reaction_strength",0)),"speed":float(speed)/1000.0,"reach":reach,
		"duration":float(definition.get("lifetime_ms",0))/1000.0,
		"base_startup":float(startup)/config.tick_rate,"base_cooldown":float(cooldown)/config.tick_rate,
		"startup":float(timing.startup_ticks)/config.tick_rate,"cooldown":float(timing.cooldown_ticks)/config.tick_rate,
		"startup_ticks":int(timing.startup_ticks),"cooldown_ticks":int(timing.cooldown_ticks),
		"cycle":float(int(timing.startup_ticks)+int(timing.cooldown_ticks))/config.tick_rate,
		"current":state!=null,"suppressed_pairs":timing.suppressed_pairs,
		"mixture":Mixtures.definition(Mixtures.mask_for_wire(wire))}

static func metrics(wire: int, state: PlayerState = null) -> Array[Dictionary]:
	var row := inspect(wire,state)
	if row.is_empty(): return []
	return [
		{"label":"FLUX / CAST","value":String.num(row.flux,3).trim_suffix(".0")},
		{"label":"STRENGTH","value":str(row.strength)},
		{"label":"SPEED","value":"Follows caster" if row.family=="mantle" else String.num(row.speed,1)+" px/s" if row.speed>0 else "Instant fan"},
		{"label":"FIRE EVERY","value":"%.2f s min" % row.cycle},
		{"label":"SHARED POOL" if row.family in ["mantle","fuse","split"] else "DIRECT HIT","value":String.num(row.damage,2)+" HP"},
		{"label":"DURATION" if row.family=="mantle" else "NOM. REACH","value":"%.2f s" % row.duration if row.family=="mantle" else "%.0f px" % row.reach},
	]

static func timing_note(wire: int, state: PlayerState = null) -> String:
	var row := inspect(wire,state)
	if row.is_empty(): return "Choose a playable spell."
	var result := "%s: %.2fs prepare / %.2fs cooldown." % ["Now" if row.current else "Base",row.startup,row.cooldown]
	if row.current:
		result += " Preparation checks before payment; cooldown checks at release."
		if not row.suppressed_pairs.is_empty(): result += " %s: paired timing has no tick benefit." % ", ".join(row.suppressed_pairs)
	return result

static func paragraphs(wire: int, state: PlayerState = null) -> Array[String]:
	var row := inspect(wire,state)
	if row.is_empty(): return []
	var values: Array[String] = []
	if not row.mixture.is_empty():
		values.append(("Two matching paid sources: " if (int(row.mixture.element_mask) & (int(row.mixture.element_mask)-1))==0 else "Payload field: ")+String(row.mixture.purpose))
		values.append("Counter: "+String(row.mixture.counter))
	var pool := "shared damage pool" if row.family in ["mantle","fuse","split"] else "direct hit"
	values.append("%.2f Flux per cast; %.2f HP %s. Strength %d." % [row.flux,row.damage,pool,row.strength])
	values.append("Base: %.2fs prepare / %.2fs cooldown." % [row.base_startup,row.base_cooldown])
	if row.current: values.append(timing_note(wire,state))
	values.append("Follows you for %.2fs." % row.duration if row.family=="mantle" else "Nominal reach %.0fpx; cover and your aim can shorten it." % row.reach)
	return values

static func comparison(chosen_wire: int, equipped_wire: int, state: PlayerState = null) -> Array[String]:
	var chosen := inspect(chosen_wire,state)
	var equipped := inspect(equipped_wire,state)
	if chosen.is_empty() or equipped.is_empty(): return ["Choose two playable spells to compare."]
	if chosen_wire==equipped_wire: return ["Already equipped: no value or battlefield role changes."]
	var basis := "current conditions" if state!=null else "base values"
	var values: Array[String] = ["Equipped -> selected (%s):" % basis,
		"Flux %.2f -> %.2f; cast cycle %.2fs -> %.2fs." % [equipped.flux,chosen.flux,equipped.cycle,chosen.cycle],
		"%s %.2f HP -> %s %.2f HP." % ["Pool" if equipped.family in ["mantle","fuse","split"] else "Hit",equipped.damage,"pool" if chosen.family in ["mantle","fuse","split"] else "hit",chosen.damage],
		"Strength %d -> %d; %s -> %s." % [equipped.strength,chosen.strength,equipped.family.capitalize(),chosen.family.capitalize()]]
	if not equipped.mixture.is_empty(): values.append("Equipped field: "+String(equipped.mixture.purpose))
	if not chosen.mixture.is_empty():
		values.append("Selected field: "+String(chosen.mixture.purpose))
		values.append("Selected counter: "+String(chosen.mixture.counter))
	values.append("Pool and hit values are not sustained damage rates. Field damage is separate; current timing can change before release.")
	return values
