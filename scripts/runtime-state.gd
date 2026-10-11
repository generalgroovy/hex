extends SceneTree


const SummaryScript = preload("res://src/app/runtime_content_summary.gd")


func _initialize() -> void:
	var abilities := AbilityCatalog.new()
	var champions := ChampionCatalog.new()
	var reactions := ReactionCatalog.new()
	if not abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"):
		_fail(abilities.last_error)
		return
	if not champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities):
		_fail(champions.last_error)
		return
	if not reactions.load_from_file(ReactionCatalog.DEFAULT_PATH):
		_fail(reactions.last_error)
		return
	var summary: Dictionary = SummaryScript.build(abilities, champions, reactions)
	if summary.is_empty():
		_fail("validated runtime content summary is empty")
		return
	var identity := RuntimeBuildIdentity.load_current(SimConfig.PROTOCOL_VERSION, SessionSnapshot.SCHEMA_VERSION)
	if not bool(identity.get("ok", false)):
		_fail(String(identity.get("error", "runtime build identity unavailable")))
		return
	summary["runtime"]["build_identity"] = identity["manifest"]
	print("FLUX_RUNTIME_STATE=" + JSON.stringify(summary))
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
