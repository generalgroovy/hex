extends FluxTestSuite


const CATALOG_PATH: String = "res://content/abilities/foundation_abilities_v1.json"
const LOADOUT_PATH: String = "res://content/loadouts/foundation_practitioner_v1.json"
const EXPECTED_RUNTIME_WIRE_IDS: Array[int] = [
	140, 181, 182, 141,
	145, 179, 180, 154,
	163, 185, 186, 164,
	159, 183, 184, 160,
	173, 191, 192, 174,
	142, 193, 194, 176,
]
const EXPECTED_REACTION_STRENGTH_BY_FAMILY: Dictionary = {
	"rapid": 1,
	"spray": 3,
	"bolt": 5,
	"heavy": 15,
	"mantle": 8, "fuse": 10, "split": 8, "rebound": 6,
}


func run() -> int:
	_test_catalog()
	_test_spell_matrix()
	_test_reaction_strength_contract()
	_test_loadout()
	_test_invalid_content_fails_closed()
	_test_single_element_gate()
	_test_retired_element_archive()
	return finish("ability-content")


func _test_single_element_gate() -> void:
	# Alternate ambiguous schemas remain refused; explicit element_mask is the sole composition authority.
	for value: Variant in [0,64,4.5,"4",null]:
		var bad:=_catalog()
		_base_ability(bad,"rillshot").element_mask=value
		check(not bad.validate(),"malformed authored masks fail closed before coercion")
	for key: String in ["elements", "secondary_element", "dual_element", "element_combination", "hybrid_elements"]:
		var catalog := _catalog()
		(catalog.data["abilities"][1] as Dictionary)[key] = ["fire", "water"]
		check(not catalog.validate(), "hybrid metadata fails closed: " + key)
	var array_element := _catalog()
	(array_element.data["abilities"][1] as Dictionary)["element"] = ["fire", "water"]
	check(not array_element.validate(), "array cannot bypass one-element schema")
	var empty_element := _catalog()
	_base_ability(empty_element, "rillshot")["element"] = ""
	check(not empty_element.validate(), "playable spell needs one named element")


func _catalog() -> AbilityCatalog:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(CATALOG_PATH), "foundation ability catalog validates: %s" % catalog.last_error)
	return catalog


func _test_retired_element_archive() -> void:
	var catalog := _catalog()
	equal(AbilityCatalog.RETIRED_ABILITY_WIRES.size(), 16, "all sixteen old Ice and Charge records remain recoverable")
	for id: String in AbilityCatalog.RETIRED_ABILITY_WIRES:
		var record := catalog.ability(id)
		equal(int(record.get("wire_id", 0)), int(AbilityCatalog.RETIRED_ABILITY_WIRES[id]), "archive preserves exact historical spell identity: " + id)
		equal(String(record.get("runtime_status", "")), "catalog_only", "retired element spell is inspectable only: " + id)
		check(not catalog.runtime_wire_ids.has(int(record.wire_id)), "retired wire cannot enter the selectable runtime")
		check(CombatTuning.cast_definition(int(record.wire_id)).is_empty(), "retired wire cannot cast through runtime lookup")
	for element: String in ["ice", "charge"]:
		check(catalog.spell_id_at(element, "bolt").is_empty(), "retired element has no selectable matrix row")
		var promoted := _catalog()
		for row: Dictionary in promoted.data.elements:
			if String(row.id) == element: row.runtime_enabled = true
		check(not promoted.validate(), "archive cannot re-enable an extra live ingredient")
	var invented := _catalog()
	var archive := _base_ability(invented, "arc-primary")
	archive.id = "invented-archive"
	check(not invented.validate(), "archive exception requires the exact historical ID and wire")
	var retagged := _catalog()
	_base_ability(retagged, "arc-primary").element = "ice"
	check(not retagged.validate(), "archive exception cannot retag Charge as a different historical element")


func _test_catalog() -> void:
	var first: AbilityCatalog = _catalog()
	var second: AbilityCatalog = _catalog()
	equal(first.content_hash.length(), 64, "catalog has a SHA-256 content hash")
	equal(first.content_hash, second.content_hash, "catalog hash is stable across reloads")
	equal(first.elements_by_id.size(), 12, "all twelve thematic element families are declared")
	equal(first.active_element_ids(), ["dark", "earth", "fire", "light", "water", "wind"], "only six canonical families are runtime-enabled")
	equal(AbilityCatalog.DISPLAY_ELEMENT_IDS, ["water", "fire", "wind", "earth", "light", "dark"], "display and development order is explicit")
	equal(AbilityCatalog.DISPLAY_ELEMENT_WIRE_IDS, [3, 2, 4, 1, 7, 8], "display order does not renumber stable element wires")
	equal(AbilityCatalog.DISPLAY_ELEMENT_IDS, ["water", "fire", "wind", "earth", "light", "dark"], "live iteration has exactly the canonical six display elements")
	equal(AbilityCatalog.element_display_name("wind"), "Air", "internal Wind is player-facing Air")
	equal(AbilityCatalog.element_display_name("water"), "Water", "other element display names retain their identity")
	equal(first.playable_spell_ids().size(), 504, "all63 named masks across8 families enter the playable selector")
	equal(first.runtime_wire_ids.slice(0,24), EXPECTED_RUNTIME_WIRE_IDS, "original24 wires preserve their exact stable row-major prefix")
	check(not first.playable_spell_ids().has("vector-lance"), "Vector Lance is retained outside the playable selector")
	equal(String(first.ability("vector-lance").get("runtime_status", "")), "catalog_only", "Vector Lance keeps recoverable catalog metadata")
	for gated_id: String in ["ice", "charge", "spirit", "chaos", "gravity", "time"]:
		check(not bool((first.elements_by_id[gated_id] as Dictionary)["runtime_enabled"]), "%s remains explicitly gated" % gated_id)
	equal(String(first.data.get("affinity_rule", "")), "aligned_active_cost_discount_capped_by_affinity_strength", "ability catalog declares weighted affinity discount rule")
	equal(int(first.economy["recovery_delay_ms"]), PlayerTuning.FLUX_RECOVERY_DELAY_MS, "catalog owns the compiled Flux recovery delay")
	equal((first.economy["cadence_tiers_ms"] as Dictionary).keys().size(), 4, "economy declares four bounded cadence tiers including Rapid")
	equal(int(first.ability("cinderbolt")["flux_cost"]) * 1000, int(CombatTuning.cast_definition(CombatTuning.PRIMARY_WIRE_ID)["flux_cost"]), "foundation primary has exact positive Flux cost")
	equal(int(first.ability("cinderbolt")["wire_id"]), CombatTuning.PRIMARY_WIRE_ID, "compiled primary wire matches catalog")
	equal(int(first.ability("cinderbolt")["cooldown_ms"]), int(CombatTuning.cast_definition(CombatTuning.PRIMARY_WIRE_ID)["cooldown_ms"]), "compiled primary cooldown matches catalog")
	equal(int(first.ability("vector-lance")["wire_id"]), CombatTuning.VECTOR_LANCE_WIRE_ID, "historical Vector Lance wire remains stable")
	check(CombatTuning.cast_definition(CombatTuning.VECTOR_LANCE_WIRE_ID).is_empty(), "disabled Vector Lance has no authoritative cast definition")
	equal(CombatTuning.ACTIVE_1_WIRE_ID, CombatTuning.RILLSHOT_WIRE_ID, "new authored Active 1 defaults to retained Rillshot")
	equal(int(first.ability("rillshot")["wire_id"]), CombatTuning.RILLSHOT_WIRE_ID, "Rillshot wire matches compiled Oh Tipi kit")
	equal(int(first.ability("rillshot")["flux_cost"]) * 1000, int(CombatTuning.cast_definition(CombatTuning.RILLSHOT_WIRE_ID)["flux_cost"]), "Oh Tipi primary has exact positive Flux cost")
	equal(int(first.ability("cinderbolt")["wire_id"]), CombatTuning.CINDERBOLT_WIRE_ID, "Cinderbolt wire matches compiled Red Baron kit")
	equal(int(first.ability("cinderbolt")["flux_cost"]) * 1000, int(CombatTuning.cast_definition(CombatTuning.CINDERBOLT_WIRE_ID)["flux_cost"]), "Red Baron primary has exact positive Flux cost")
	equal(int(first.ability("cinderbolt")["cooldown_ms"]), int(CombatTuning.cast_definition(CombatTuning.CINDERBOLT_WIRE_ID)["cooldown_ms"]), "Cinderbolt cadence matches compiled behavior")
	equal(int(first.ability("cinder-fan")["wire_id"]), CombatTuning.CINDERFAN_WIRE_ID, "Cinder Fan wire matches the compiled pattern")
	var content_fan_angles: Array[int] = []
	for angle: Variant in first.ability("cinder-fan")["projectile_angles_degrees"]:
		content_fan_angles.append(int(angle))
	equal(content_fan_angles, [-24, -12, 0, 12, 24], "Cinder Fan content retains the exact symmetric five-lane contract")
	check(CombatTuning.cast_definition(CombatTuning.CINDERFAN_WIRE_ID).is_empty(), "disabled Wave has no authoritative cast definition")
	var expected_bursts := {
		"earth": "stone-burst", "fire": "cinder-fan", "water": "rill-burst", "wind": "gale-burst",
		"ice": "rime-burst", "charge": "arc-burst", "light": "prism-burst", "dark": "eclipse-burst",
	}
	for element_id: String in AbilityCatalog.ARCHIVED_EIGHT_ELEMENTS:
		var burst: Dictionary = first.ability(expected_bursts[element_id])
		var burst_angles: Array[int] = []
		for angle: Variant in burst.get("projectile_angles_degrees", []):
			burst_angles.append(int(angle))
		equal(String(burst.get("element", "")), element_id, "%s owns one Burst identity" % element_id)
		equal(String(burst.get("delivery_kernel", "")), "burst", "%s uses the shared Burst delivery kernel" % element_id)
		equal(String(burst.get("runtime_status", "")), "catalog_only", "%s Wave remains retained but disabled" % element_id)
		equal(int(burst.get("flux_cost", 0)), 16, "%s Wave keeps its historical positive Flux cost" % element_id)
		equal(burst_angles, [-24, -12, 0, 12, 24], "%s Burst keeps the shared five-lane geometry" % element_id)
	equal(int(first.ability("tideline")["wire_id"]), CombatTuning.TIDELINE_WIRE_ID, "Tideline wire matches compiled Oh Tipi kit")
	equal(int(first.ability("tideline")["flux_cost"]) * 1000, int(CombatTuning.cast_definition(CombatTuning.TIDELINE_WIRE_ID)["flux_cost"]), "Tideline Flux cost matches compiled behavior")
	equal(int(first.ability("tideline")["startup_ms"]), int(CombatTuning.cast_definition(CombatTuning.TIDELINE_WIRE_ID)["startup_ms"]), "Tideline startup matches compiled behavior")
	equal(String(first.ability("tideline")["shape"]), "spray", "Tideline is the first promoted spray shape")
	equal(String(CombatTuning.cast_definition(CombatTuning.TIDELINE_WIRE_ID).get("shape")), "spray", "compiled Tideline uses the spray resolver")
	check(CombatTuning.projectile_definition(CombatTuning.TIDELINE_WIRE_ID).is_empty(), "Tideline cannot silently re-enter projectile simulation")
	equal(int(first.ability("rimewake")["wire_id"]), CombatTuning.RIMEWAKE_WIRE_ID, "Rimewake wire matches compiled Oh Tipi kit")
	check(int(first.ability("rimewake")["flux_cost"]) > 0, "Rimewake retains its historical positive Flux cost")
	check(int(first.ability("rimewake")["startup_ms"]) > 0, "Rimewake retains its historical startup")
	equal(String(first.ability("rimewake")["shape"]), "field", "Rimewake is the first promoted field shape")
	check(CombatTuning.cast_definition(CombatTuning.RIMEWAKE_WIRE_ID).is_empty(), "disabled Rimewake Field has no authoritative cast definition")
	check(CombatTuning.projectile_definition(CombatTuning.RIMEWAKE_WIRE_ID).is_empty(), "Rimewake cannot silently re-enter projectile simulation")
	check(not bool(first.ability("rimewake")["material_runtime_enabled"]), "Rimewake keeps its planned cooling mutation sealed")
	equal(int(first.ability("eclipse-disc")["wire_id"]), CombatTuning.ECLIPSE_DISC_WIRE_ID, "Eclipse Disc wire matches compiled S. Wayne kit")
	equal(int(first.ability("eclipse-disc")["flux_cost"]) * 1000, int(CombatTuning.cast_definition(CombatTuning.ECLIPSE_DISC_WIRE_ID)["flux_cost"]), "S. Wayne primary has exact positive Flux cost")
	equal(int(first.ability("pocket-eclipse")["wire_id"]), CombatTuning.POCKET_ECLIPSE_WIRE_ID, "Pocket Eclipse wire matches compiled S. Wayne kit")
	check(int(first.ability("pocket-eclipse")["flux_cost"]) > 0, "Pocket Eclipse retains its historical positive Flux cost")
	check(int(first.ability("pocket-eclipse")["startup_ms"]) > 0, "Pocket Eclipse retains its historical startup")
	equal(String(first.ability("pocket-eclipse")["shape"]), "beam", "Pocket Eclipse is the first promoted non-projectile shape")
	check(CombatTuning.cast_definition(CombatTuning.POCKET_ECLIPSE_WIRE_ID).is_empty(), "disabled Pocket Eclipse Beam has no authoritative cast definition")
	check(CombatTuning.projectile_definition(CombatTuning.POCKET_ECLIPSE_WIRE_ID).is_empty(), "Pocket Eclipse cannot silently re-enter projectile simulation")
	for playable_id: String in first.playable_spell_ids():
		var playable: Dictionary = first.ability(playable_id)
		check(AbilityCatalog.SHAPES.has(String(playable.get("shape", ""))), "%s declares a legal spell shape" % playable_id)
		check(not bool(playable.get("material_runtime_enabled", true)), "%s keeps material mutation truthfully gated" % playable_id)
		check(int(playable.get("flux_cost", 0)) > 0, "%s cannot create free runtime pressure" % playable_id)
		check(AbilityCatalog.CADENCE_TIER_IDS.has(String(playable.get("cadence_tier", ""))), "%s declares a bounded cadence tier" % playable_id)
	equal(String(first.ability("prism-ward").get("shape")), "defense", "Prism Ward declares its future defense shape")
	equal(String(first.ability("stone-channel").get("residue")), "construct", "Stone Channel declares intended persistent geometry")
	var disabled_family_ids: Array[String] = [
		"vector-lance",
		"cinder-fan", "stone-burst", "rill-burst", "gale-burst", "rime-burst", "arc-burst", "prism-burst", "eclipse-burst",
		"cinderline", "undertow-line", "faultline", "pressure-line", "voltline", "frostline", "pocket-eclipse", "nightline",
		"hearthring", "springwell", "stonehold", "updraft", "static-snare", "rimewake", "halo-ground", "umbral-pool",
	]
	for disabled_id: String in disabled_family_ids:
		var disabled: Dictionary = first.ability(disabled_id)
		check(not disabled.is_empty(), "%s remains available for saved-slot recovery and historical reference" % disabled_id)
		equal(String(disabled.get("runtime_status", "")), "catalog_only", "%s is explicitly disabled" % disabled_id)
		check(CombatTuning.cast_definition(int(disabled.get("wire_id", 0))).is_empty(), "%s cannot acquire an authoritative cast definition" % disabled_id)
	for active_id: String in ["vector-lance", "prism-ward", "stone-channel", "tideline", "rimewake", "pocket-eclipse"]:
		var active: Dictionary = first.ability(active_id)
		check(int(active["points"]) > 0, "%s has positive build cost" % active_id)
		check(int(active["flux_cost"]) > 0, "%s has positive Flux cost" % active_id)
		check(not (active["counterplay"] as Array).is_empty(), "%s declares counterplay" % active_id)


func _test_spell_matrix() -> void:
	var catalog := _catalog()
	equal(AbilityCatalog.KNOWN_SPELL_FAMILIES, ["bolt", "heavy", "rapid", "burst", "spray", "beam", "field", "mantle", "fuse", "split", "rebound"], "retained family vocabulary is independent of selectable columns")
	equal(AbilityCatalog.SPELL_MATRIX_FAMILIES, ["bolt", "heavy", "rapid", "spray", "mantle", "fuse", "split", "rebound"], "selector exposes eight distinct deliveries")
	equal(catalog.spell_matrix_ids.size(), 504, "spell matrix has exactly63 nonempty payloads by8 deliveries")
	equal(catalog.spell_matrix_wire_ids.slice(0,24), EXPECTED_RUNTIME_WIRE_IDS, "matrix prefix preserves all twenty-four stable spell wires")
	equal(catalog.spell_matrix_wire_ids, catalog.runtime_wire_ids, "runtime order is exactly the stable complete selector catalog")
	var claimed: Dictionary = {}
	for element_id: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		for family_id: String in AbilityCatalog.SPELL_MATRIX_FAMILIES:
			var ability_id := catalog.spell_id_at(element_id, family_id)
			check(not ability_id.is_empty(), "%s/%s matrix cell resolves" % [element_id, family_id])
			check(not claimed.has(ability_id), "%s/%s matrix cell is unique" % [element_id, family_id])
			claimed[ability_id] = true
			var ability := catalog.ability(ability_id)
			equal(String(ability.get("element", "")), element_id, "%s remains in its element row" % ability_id)
			check(int(ability.get("flux_cost", 0)) > 0, "%s remains a paid attack" % ability_id)
	var missing := AbilityCatalog.new()
	missing.data = catalog.data.duplicate(true)
	missing.data["spell_matrix"]["cells"]["fire"].pop_back()
	check(not missing.validate(), "incomplete matrix row fails closed")
	check(missing.last_error.contains("every attack family"), "incomplete row failure is diagnosable")
	var crossed := AbilityCatalog.new()
	crossed.data = catalog.data.duplicate(true)
	# Use a retained Water spell outside the selectable matrix so this fixture
	# reaches the row/column validator instead of the earlier uniqueness guard.
	crossed.data["spell_matrix"]["cells"]["fire"][0] = "rill-burst"
	check(not crossed.validate(), "cross-element matrix cell fails closed")
	check(crossed.last_error.contains("row or column"), "cross-element failure is diagnosable")
	var implicit_extension_status := AbilityCatalog.new()
	implicit_extension_status.data = catalog.data.duplicate(true)
	(implicit_extension_status.data["spell_matrix"]["extensions"][0] as Dictionary).erase("runtime_status")
	check(not implicit_extension_status.validate(), "extension cannot be forced playable by omitting its runtime status")
	check(implicit_extension_status.last_error.contains("explicit runtime status"), "missing extension status is diagnosable")
	var gated_runtime_wire := AbilityCatalog.new()
	gated_runtime_wire.data = catalog.data.duplicate(true)
	gated_runtime_wire.data["runtime_wire_ids"].append(CombatTuning.VECTOR_LANCE_WIRE_ID)
	check(not gated_runtime_wire.validate(), "disabled wire cannot enter authoritative runtime order")
	check(gated_runtime_wire.last_error.contains("gated ability"), "disabled runtime-wire failure is diagnosable")
	var reordered_elements := AbilityCatalog.new()
	reordered_elements.data = catalog.data.duplicate(true)
	var elements: Array = reordered_elements.data["elements"]
	var first_element: Variant = elements[0]
	elements[0] = elements[1]
	elements[1] = first_element
	check(not reordered_elements.validate(), "authored element order cannot drift from display/development order")
	check(reordered_elements.last_error.contains("canonical display order"), "element-order failure is diagnosable")


func _test_reaction_strength_contract() -> void:
	var catalog := _catalog()
	var checked := 0
	for element_id: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		for family_id: String in AbilityCatalog.SPELL_MATRIX_FAMILIES:
			var ability_id := catalog.spell_id_at(element_id, family_id)
			var ability := catalog.ability(ability_id)
			equal(int(ability.get("reaction_strength", 0)), int(EXPECTED_REACTION_STRENGTH_BY_FAMILY[family_id]), "%s authors the current %s reaction strength" % [ability_id, family_id])
			checked += 1
	equal(checked, 48, "all six singleton elements across eight families declare exact reaction strength")
	for wire: int in catalog.runtime_wire_ids:
		var ability:=catalog.ability_from_wire(wire)
		equal(int(ability.reaction_strength),int(EXPECTED_REACTION_STRENGTH_BY_FAMILY[AbilityCatalog._spell_family(ability)]),"all504 mixtures retain one family strength without arity multiplication")

	var missing := _catalog()
	_base_ability(missing, "rillshot").erase("reaction_strength")
	check(not missing.validate(), "missing runtime reaction strength fails closed")
	check(missing.last_error.contains("rillshot/reaction_strength"), "missing reaction strength identifies its authored spell")

	var zero := _catalog()
	_base_ability(zero, "rillshot")["reaction_strength"] = 0
	check(not zero.validate(), "zero reaction strength fails closed")
	check(zero.last_error.contains("1 through 15"), "zero reaction strength reports its bounded contract")

	var fractional := _catalog()
	_base_ability(fractional, "rillshot")["reaction_strength"] = 1.5
	check(not fractional.validate(), "fractional reaction strength fails closed")
	check(fractional.last_error.contains("reaction_strength"), "fractional reaction strength is diagnosable")

	var excessive := _catalog()
	_base_ability(excessive, "rillshot")["reaction_strength"] = 16
	check(not excessive.validate(), "reaction strength above fifteen fails closed")
	check(excessive.last_error.contains("1 through 15"), "excessive reaction strength reports its bounded contract")

	var missing_template := _catalog()
	(missing_template.data["spell_matrix"]["family_templates"]["heavy"] as Dictionary).erase("reaction_strength")
	check(not missing_template.validate(), "playable expansion cannot omit its template reaction strength")
	check(missing_template.last_error.contains("cinder-shell/reaction_strength"), "missing template strength identifies the first affected expansion")

	var mismatching_expansion := _catalog()
	(mismatching_expansion.data["spell_matrix"]["extensions"][0] as Dictionary)["reaction_strength"] = 14
	check(not mismatching_expansion.validate(), "an extension cannot silently override its authored template strength")
	check(mismatching_expansion.last_error.contains("contradicts its family template"), "expanded strength mismatch is diagnosable")

	var future_custom := _catalog()
	_base_ability(future_custom, "arc-primary")["reaction_strength"] = 7
	check(future_custom.validate(), "catalog validation permits another deterministic strength inside one through fifteen")

	var invalid_values: Array[Dictionary] = [
		{"label": "boolean", "value": true},
		{"label": "string", "value": "3"},
		{"label": "NaN", "value": NAN},
		{"label": "positive infinity", "value": INF},
		{"label": "negative infinity", "value": -INF},
		{"label": "negative integer", "value": -1},
	]
	for fixture: Dictionary in invalid_values:
		var base_invalid := _catalog()
		_base_ability(base_invalid, "rillshot")["reaction_strength"] = fixture["value"]
		check(not base_invalid.validate(), "%s base reaction strength fails closed" % fixture["label"])
		check(base_invalid.last_error.contains("reaction_strength"), "%s base reaction strength is diagnosable" % fixture["label"])

		var template_invalid := _catalog()
		(template_invalid.data["spell_matrix"]["family_templates"]["spray"] as Dictionary)["reaction_strength"] = fixture["value"]
		check(not template_invalid.validate(), "%s template reaction strength fails closed" % fixture["label"])
		check(template_invalid.last_error.contains("reaction_strength"), "%s template reaction strength is diagnosable" % fixture["label"])

		var extension_invalid := _catalog()
		_matrix_extension(extension_invalid, "ember-sweep")["reaction_strength"] = fixture["value"]
		check(not extension_invalid.validate(), "%s extension reaction strength fails closed" % fixture["label"])
		check(extension_invalid.last_error.contains("reaction strength"), "%s extension reaction strength is diagnosable" % fixture["label"])

		var matching_invalid := _catalog()
		(matching_invalid.data["spell_matrix"]["family_templates"]["spray"] as Dictionary)["reaction_strength"] = fixture["value"]
		_matrix_extension(matching_invalid, "ember-sweep")["reaction_strength"] = fixture["value"]
		check(not matching_invalid.validate(), "matching %s template and extension values still fail closed" % fixture["label"])
		check(matching_invalid.last_error.contains("reaction strength"), "matching malformed %s values are rejected before comparison" % fixture["label"])

	var whole_float := _catalog()
	_base_ability(whole_float, "tideline")["reaction_strength"] = 3.0
	_matrix_extension(whole_float, "ember-sweep")["reaction_strength"] = 3.0
	check(whole_float.validate(), "whole-number float 3.0 remains compatible with JSON numeric decoding")


func _base_ability(catalog: AbilityCatalog, ability_id: String) -> Dictionary:
	for ability: Dictionary in catalog.data.get("abilities", []):
		if String(ability.get("id", "")) == ability_id:
			return ability
	return {}


func _matrix_extension(catalog: AbilityCatalog, ability_id: String) -> Dictionary:
	for extension: Dictionary in catalog.data["spell_matrix"].get("extensions", []):
		if String(extension.get("id", "")) == ability_id:
			return extension
	return {}


func _test_loadout() -> void:
	var catalog: AbilityCatalog = _catalog()
	var first := LoadoutDefinition.new()
	var second := LoadoutDefinition.new()
	check(first.load_from_file(LOADOUT_PATH, catalog), "foundation loadout validates: %s" % first.last_error)
	check(second.load_from_file(LOADOUT_PATH, catalog), "foundation loadout reload validates")
	equal(first.active_points, 9, "affinity-adjusted four-delivery actives use nine of thirteen available points")
	equal(first.spell_slot_ids, ["cinderbolt", "cinder-shell", "ember-stream", "ember-sweep", "dawn-needle", "dawn-shell", "glint-stream", "radiant-veil", "", "", "", ""], "foundation loadout exposes only retained four-delivery IDs")
	equal(first.spell_slot_wire_ids, PackedInt32Array([145, 179, 180, 154, 173, 191, 192, 174, 0, 0, 0, 0]), "foundation loadout projects the exact twelve authoritative wire positions")
	check(first.disabled_spell_slots.is_empty(), "new authored foundation loadout contains no disabled saved slots")
	equal(first.affinity_strength("fire"), 2, "foundation loadout folds primary Charge into Fire strength 2")
	equal(first.affinity_strength("light"), 1, "foundation loadout exposes secondary Light strength 1")
	equal(first.affinity_strength("earth"), 0, "unaligned Earth has affinity strength 0")
	equal(first.content_hash.length(), 64, "loadout has a SHA-256 compatibility hash")
	equal(first.content_hash, second.content_hash, "loadout hash is stable across reloads")


func _test_invalid_content_fails_closed() -> void:
	var catalog: AbilityCatalog = _catalog()
	var invalid_duplicate := LoadoutDefinition.new()
	invalid_duplicate.data = JSON.parse_string(FileAccess.get_file_as_string(LOADOUT_PATH))
	invalid_duplicate.data["slots"]["actives"] = ["cinder-shell", "cinder-shell", "radiant-veil"]
	check(not invalid_duplicate.validate(catalog), "duplicate active fails closed")
	check(invalid_duplicate.last_error.contains("unique"), "duplicate failure is diagnosable")

	var invalid_affinity_total := LoadoutDefinition.new()
	invalid_affinity_total.data = JSON.parse_string(FileAccess.get_file_as_string(LOADOUT_PATH))
	invalid_affinity_total.data["affinity_points"] = {"fire": 1, "light": 1}
	check(not invalid_affinity_total.validate(catalog), "loadout must spend exactly three affinity points")
	check(invalid_affinity_total.last_error.contains("must total"), "affinity-point failure is diagnosable")

	var invalid_affinity_strength := LoadoutDefinition.new()
	invalid_affinity_strength.data = JSON.parse_string(FileAccess.get_file_as_string(LOADOUT_PATH))
	invalid_affinity_strength.data["affinity_points"] = {"fire": 3, "light": 0}
	check(not invalid_affinity_strength.validate(catalog), "affinity strength outside 1..2 fails closed")
	check(invalid_affinity_strength.last_error.contains("strength"), "affinity-strength failure is diagnosable")

	var invalid_budget := LoadoutDefinition.new()
	invalid_budget.data = JSON.parse_string(FileAccess.get_file_as_string(LOADOUT_PATH))
	invalid_budget.data["active_budget"] = 12
	check(not invalid_budget.validate(catalog), "nonstandard budget fails closed")
	check(invalid_budget.last_error.contains("13"), "budget failure is diagnosable")

	var invalid_spell_count := LoadoutDefinition.new()
	invalid_spell_count.data = JSON.parse_string(FileAccess.get_file_as_string(LOADOUT_PATH))
	invalid_spell_count.data["spell_slots"] = ["cinderbolt"]
	check(not invalid_spell_count.validate(catalog), "non-twelve-position spell loadout fails closed")
	check(invalid_spell_count.last_error.contains("twelve"), "spell count failure is diagnosable")

	var invalid_duplicate_spell := LoadoutDefinition.new()
	invalid_duplicate_spell.data = JSON.parse_string(FileAccess.get_file_as_string(LOADOUT_PATH))
	invalid_duplicate_spell.data["spell_slots"][4] = "cinderbolt"
	check(not invalid_duplicate_spell.validate(catalog), "duplicate equipped spell fails closed")
	check(invalid_duplicate_spell.last_error.contains("unique"), "duplicate spell failure is diagnosable")

	var invalid_catalog := AbilityCatalog.new()
	invalid_catalog.data = catalog.data.duplicate(true)
	for ability: Dictionary in invalid_catalog.data["abilities"]:
		if ability["id"] == "vector-lance":
			ability["flux_cost"] = 0
	check(not invalid_catalog.validate(), "zero-cost catalog active fails closed")
	check(invalid_catalog.last_error.contains("positive"), "active cost failure is diagnosable")

	var free_primary := AbilityCatalog.new()
	free_primary.data = catalog.data.duplicate(true)
	for ability: Dictionary in free_primary.data["abilities"]:
		if ability["id"] == "rillshot":
			ability["flux_cost"] = 0
	check(not free_primary.validate(), "zero-cost runtime primary fails closed")
	check(free_primary.last_error.contains("positive"), "primary cost failure is diagnosable")

	var invalid_shape := AbilityCatalog.new()
	invalid_shape.data = catalog.data.duplicate(true)
	(invalid_shape.data["abilities"][1] as Dictionary)["shape"] = "hitscan"
	check(not invalid_shape.validate(), "unknown shape contract fails closed")
	check(invalid_shape.last_error.contains("shape"), "shape failure is diagnosable")

	var false_material_gate := AbilityCatalog.new()
	false_material_gate.data = catalog.data.duplicate(true)
	var arc: Dictionary = false_material_gate.data["abilities"][1]
	arc["material_operation"] = "none"
	arc["material_runtime_enabled"] = true
	check(not false_material_gate.validate(), "enabled no-op material mutation fails closed")
	check(false_material_gate.last_error.contains("cannot be none"), "material gate failure is diagnosable")

	var asymmetric_fan := AbilityCatalog.new()
	asymmetric_fan.data = catalog.data.duplicate(true)
	for ability: Dictionary in asymmetric_fan.data["abilities"]:
		if ability["id"] == "cinder-fan":
			ability["projectile_angles_degrees"] = [-24, -12, 0, 12, 25]
	check(not asymmetric_fan.validate(), "asymmetric projectile fan fails closed")
	check(asymmetric_fan.last_error.contains("projectile angles"), "projectile pattern failure is diagnosable")
