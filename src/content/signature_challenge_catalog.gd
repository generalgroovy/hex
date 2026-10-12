class_name SignatureChallengeCatalog
extends RefCounted
## Authored rival identities. Wire allocation belongs to MixtureCatalog.

const Mixtures = preload("res://src/content/mixture_catalog.gd")
const TELLS := {
	"bolt":"Bolt line: sidestep its committed aim, then punish the pause.",
	"heavy":"Heavy shell: leave the facing line and its splash; cover stops the flight.",
	"rapid":"Three short Rapid bursts: read each new facing line and cross during the gaps.",
	"spray":"Close Spray fan: leave the cone or put solid cover between you.",
	"mantle":"Contact Mantle: keep space from the approach and avoid the paid trail.",
	"fuse":"Ground Fuse: leave the committed landing point before its delayed blast.",
	"split":"Split pattern: read the parent line, then weave between its finite branches.",
	"rebound":"Rebound: watch the wall-facing bank line as well as the direct lane.",
}
const ASSIGNMENTS := [
	["oh_tipi", 6, "fuse"], ["s_wayne", 48, "rebound"],
	["red_baron", 6, "heavy"], ["grace_reava", 28, "mantle"],
	["wa_bidi", 10, "rapid"], ["steezo", 18, "split"],
	["treevor_mason", 11, "mantle"], ["oll_i", 19, "heavy"],
	["fluup", 14, "split"], ["nico_lai", 18, "fuse"],
	["spai_si", 25, "rebound"], ["leaf_hidden", 21, "bolt"],
	["ha_rekt", 14, "rebound"], ["dr_apex", 21, "split"],
	["haara", 24, "rapid"], ["hesus_christo", 5, "heavy"],
	["grimm_bow", 5, "fuse"], ["biggy_bob", 19, "split"],
	["jan_wicked", 38, "fuse"], ["ba_djoh", 7, "spray"],
	["urzh", 3, "mantle"], ["donnok", 7, "heavy"],
	["djonah_thaan", 34, "split"], ["luuh_i_zeh", 36, "mantle"],
	["juul_i_yaina", 12, "rebound"], ["faab_i_yaina", 18, "mantle"],
	["joh_haynes", 3, "rebound"], ["h_le_ne", 11, "fuse"],
	["fimu_yashiha", 28, "spray"], ["sai_laas", 10, "split"],
]


static func rows(champions: ChampionCatalog, abilities: AbilityCatalog) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := {}
	for assignment: Array in ASSIGNMENTS:
		var row := definition(String(assignment[0]), champions, abilities)
		if row.is_empty() or seen.has(int(row.signature_wire)): return []
		seen[int(row.signature_wire)] = true
		result.append(row)
	return result


static func definition(champion_id: String, champions: ChampionCatalog, abilities: AbilityCatalog) -> Dictionary:
	if champions == null or abilities == null: return {}
	var champion := champions.champion(champion_id)
	if champion.is_empty(): return {}
	for assignment: Array in ASSIGNMENTS:
		if String(assignment[0]) != champion_id: continue
		var mask := int(assignment[1])
		var family := String(assignment[2])
		var wire := Mixtures.wire_for(mask, family)
		var spell_id := abilities.ability_id_from_wire(wire)
		var spell := abilities.ability(spell_id)
		var mixture := Mixtures.definition(mask)
		if spell.is_empty() or mixture.is_empty() or not CombatTuning.is_runtime_wire_id(wire): return {}
		var warning := String(TELLS.get(family, ""))
		return {"id": champion_id, "champion_id": champion_id,
			"champion_wire_id": int(champion.wire_id), "name": String(champion.display_name),
			"signature_wire": wire, "signature_id": spell_id,
			"mask": mask, "family": family,
			"spell_name": String(spell.get("display_name", mixture.display_name + " " + family.capitalize())),
			"tell": warning, "counter": String(mixture.get("counter", "Leave the affected cells; read the current phase."))}
	return {}
