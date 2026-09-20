class_name CombatFeedbackModel
extends RefCounted


# Presentation only. Read existing semantic events and validated identity; never
# infer an applied control effect or a damage amount from a spell's base stats.
const EVENT_SHAPES := {
	"projectile_hit": "projectile", "beam_fired": "beam",
	"spray_fired": "spray", "spray_hit": "spray", "field_triggered": "field",
}


static func describe(event: Dictionary, catalog: AbilityCatalog) -> Dictionary:
	var kind := String(event.get("type", ""))
	if not EVENT_SHAPES.has(kind):
		return {}
	var shape := String(EVENT_SHAPES[kind])
	var ability: Dictionary = {}
	var wire_id := int(event.get("source_wire_id", 0))
	if catalog != null and not catalog.content_hash.is_empty() and wire_id in catalog.runtime_wire_ids:
		ability = catalog.ability_from_wire(wire_id)
		if String(ability.get("shape", "")) != shape:
			ability = {}
	var element := String(ability.get("element", ""))
	var identity := String(ability.get("display_name", shape)).strip_edges().to_upper()
	# Live names fit this bound. Future overlong/invalid copy gets the explicit
	# element/family fallback, not a clipped or invented spell name.
	if identity.is_empty() or identity.length() > 20 or "\n" in identity or "\r" in identity:
		identity = (element + " " + shape).strip_edges().to_upper()
	var label := ""
	match kind:
		"projectile_hit":
			label = _reported_damage(event)
		"beam_fired":
			# Beam damage is not in the existing guest wire event. Optical splits
			# also make base damage incorrect. Use identical contact copy on peers.
			label = identity + (" · HIT" if int(event.get("target_id", 0)) > 0 else "")
		"spray_fired":
			label = "%s ×%d" % [identity, maxi(0, int(event.get("hit_count", 0)))]
		"spray_hit":
			label = "%s · %s" % [identity, _reported_damage(event)]
		"field_triggered":
			# Contact does not guarantee Slow: forced movement can reject it.
			label = identity + " · CONTACT"
	return {"label": label, "element": element}


static func _reported_damage(event: Dictionary) -> String:
	var amount := int(event.get("damage", 0))
	if amount <= 0:
		return "HIT"
	# Keep sub-point optical/projectile damage; do not round it to a false -0.
	return "-" + ("%.3f" % (float(amount) / 1000.0)).trim_suffix("0").trim_suffix("0").trim_suffix("0").trim_suffix(".")
