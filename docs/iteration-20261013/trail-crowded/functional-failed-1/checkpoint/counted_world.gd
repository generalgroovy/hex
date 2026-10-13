extends "res://.godot/iteration-20261013/trail-crowded/trial_world.gd"
## Separate work-count pass only; no timings use this extra observer.
const Classifier = preload("res://.godot/iteration-20261013/trail-crowded/candidate_emitter.gd")
var emitter_input: Dictionary = {}

func _trial_emit() -> void:
	var owners := {}
	var unrelated := 0
	var sampled := 0
	var first := -1
	var sampled_owner_cap := 0
	var counts := Classifier._live_trail_counts(hex_court, tick)
	for index: int in projectiles.size():
		var shot: ProjectileState = projectiles[index]
		if HexChemistryWorld.family(shot.source_wire_id) != "mantle":
			unrelated += 1
			continue
		owners[shot.owner_id] = true
		var owner := player(shot.owner_id)
		if owner == null or owner.air_height > 0 or not Classifier._delivery_eligible(shot) or posmod(tick + shot.entity_id, Classifier.SAMPLE_TICKS) != 0: continue
		sampled += 1
		if first < 0: first = index
		if int(counts.owners.get(shot.owner_id, 0)) >= Classifier.MAX_OWNER_TRAILS: sampled_owner_cap += 1
	emitter_input = {"tick":tick, "flights":projectiles.size(), "mantle_owners":owners.size(), "unrelated_flights":unrelated, "sampled_candidates":sampled, "first_sampled_index":first, "live_trails":int(counts.global), "sampled_at_owner_cap":sampled_owner_cap, "global_cap":int(counts.global)>=Classifier.MAX_TRAILS}
	super._trial_emit()
