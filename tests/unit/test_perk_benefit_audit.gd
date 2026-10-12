extends FluxTestSuite

const Probe = preload("res://scripts/balance-audit-perks.gd")


func run() -> int:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"),"real ability catalog loads for consumer probes")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json",abilities),"real champion catalog loads for consumer probes")
	var rows := Probe.build(champions)
	equal(rows.size(),51,"every ancestry and personal perk receives a condition-specific consumer probe")
	var kinds := {"ancestry":0,"character":0}
	var identities := {}
	for row: Dictionary in rows:
		check(not row.has("error"),"prepared consumer is admitted: "+String(row.get("error","")))
		if row.has("error"): continue
		check(not identities.has(row.id),"each authored perk has exactly one diagnostic")
		identities[row.id] = true
		kinds[String(row.kind)] += 1
		check(int(row.champion_wire_id)>0,"probe uses a real applied champion")
		check(not row.observations.is_empty(),"all listed effects reach actual consumers")
		check(int(row.favorable_consumer_deltas)>0,"prepared window produces a useful real consumer difference: "+String(row.id))
		equal(bool(row.needs_followup),int(row.favorable_consumer_deltas)==0,"unobserved usefulness remains an explicit follow-up")
		for observation: Dictionary in row.observations:
			equal(int(observation.delta),int(observation.enabled)-int(observation.control),"reported delta is the paired consumer difference")
			check(int(observation.enabled)>=0 and int(observation.control)>=0,"consumer refusal cannot masquerade as a useful negative timing or cost")
			if int(observation.delta)==0:
				equal(observation.result,"zero_or_suppressed_in_this_context","quantized or cancelled effect remains visible")
		check(String(row.scope).contains("not individual causal attribution or natural gameplay activation"),"fixture diagnostic does not claim a natural playtest")
	equal(kinds.ancestry,21,"all ancestry perks are represented")
	equal(kinds.character,30,"all personal perks are represented")
	equal(CanonicalContent.stringify(Probe.build(champions)),CanonicalContent.stringify(rows),"prepared paired consumers are deterministic")
	return finish("perk-benefit-audit")
