class_name InterceptionPracticeCard
extends RefCounted


const Practice = preload("res://src/sim/combat/interception_practice.gd")


static func view(world_tick: int, start_tick: int, player_profile: Dictionary = {}, opponent_profile: Dictionary = {}) -> Dictionary:
	var state := Practice.status(world_tick, start_tick)
	if state.is_empty():
		return {}
	var phase := String(state["phase"])
	var lines := PackedStringArray()
	var title := "SPRAY INTERCEPTION"
	match phase:
		Practice.PHASE_READY:
			lines.append("Move and aim normally. Meet each shot in front of you.")
			lines.append("Catch small shots with Spray. Dodge the larger ones.")
		Practice.PHASE_RAPID_SINGLE:
			lines.append("SMALL SHOT INCOMING · Aim Spray across its path.")
			lines.append("Cast as it reaches you. Move if the line is wrong.")
		Practice.PHASE_MUD_BREAK:
			title = "PRESSURE BREAK · MAKE MUD"
			lines.append("Water Spray then Earth Spray at the same spot makes Mud.")
			lines.append("Use the quiet beat to recover Flux and change position.")
		Practice.PHASE_RAPID_PRESSURE:
			lines.append("SMALL SHOT STRING · Sweep one Spray through the close group.")
			lines.append("Reposition during each pause instead of standing in the lane.")
		Practice.PHASE_STRONGER_WARNING:
			title = "STRONGER SHOTS NEXT"
			lines.append("Catch small shots with Spray. Dodge the larger ones.")
			lines.append("Read the warning, then move or use the court's cover.")
		Practice.PHASE_BOLT_READ:
			lines.append("LARGE SHOT NEXT · Keep Spray for the small shots.")
			lines.append("Sidestep, then re-center for the next read.")
		Practice.PHASE_RECENTER:
			title = "PRESSURE BREAK"
			lines.append("Use the quiet beat to recover Flux and change position.")
			lines.append("The final read mixes Rapid, Bolt, and one Heavy warning.")
		Practice.PHASE_FINAL_MIX:
			var warning := String(state.get("telegraph", ""))
			lines.append("%s · %s" % [_warning_label(warning), _warning_response(warning)])
			lines.append("Catch the small shots with Spray. Dodge the larger ones.")
		Practice.PHASE_CLEAR:
			title = "LANE CLEAR"
			lines.append("Pressure has ended. Cross the court and review your remaining Flux.")
			lines.append("Use the quiet beat to recover Flux and change position.")
		_:
			title = "CIRCUIT COMPLETE"
			lines.append("Try again: catch more shots, take fewer hits, experiment with Mud.")
	return {
		"kind": "interception_practice",
		"title": title,
		"phase": phase,
		"lines": lines,
		"telegraph": state.get("telegraph", ""),
		"progress_milli": state["progress_milli"],
		"remaining_ticks": state["remaining_ticks"],
		"total_remaining_ticks": state["total_remaining_ticks"],
		"complete": state["complete"],
		"action": "retry" if bool(state["complete"]) else "continue",
		"opponent": String(opponent_profile.get("champion_id", Practice.OPPONENT_CHAMPION_ID)),
		"slot_hints": PackedStringArray([
			"1  %s" % _name(player_profile, "water_spray", "Water Spray"),
			"2  %s" % _name(player_profile, "earth_spray", "Earth Spray"),
		]),
	}


static func _name(profile: Dictionary, role: String, fallback: String) -> String:
	var names: Dictionary = profile.get("spell_names", {})
	return String(names.get(role, fallback))


static func _warning_label(warning: String) -> String:
	match warning:
		"rapid": return "RAPID INCOMING"
		"bolt": return "BOLT WARNING"
		"heavy": return "HEAVY WARNING"
		_: return "MOVE AND RE-CENTER"


static func _warning_response(warning: String) -> String:
	return "meet it with Spray" if warning == "rapid" else "sidestep or take cover" if warning in ["bolt", "heavy"] else "watch the next release"
