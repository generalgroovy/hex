extends FluxTestSuite

const Progress = preload("res://src/app/signature_progression.gd")
const Challenges = preload("res://src/content/signature_challenge_catalog.gd")
const Challenge = preload("res://src/app/signature_challenge_session.gd")
const Mixtures = preload("res://src/content/mixture_catalog.gd")

class FailedSave:
	extends SignatureProgression
	var fail_primary := false
	func _replace_staged(staged: String, target: String) -> Error:
		if fail_primary and not target.ends_with(BACKUP_SUFFIX): return ERR_CANT_CREATE
		return super._replace_staged(staged, target)

var abilities: AbilityCatalog
var champions: ChampionCatalog
var folder := ""


func run() -> int:
	abilities = AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "progression loads live catalog")
	champions = ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "progression loads roster")
	folder = "user://signature-tests-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) == OK, "owned progress folder created")
	_test_catalog_and_access()
	_test_persistence()
	_test_bound_reward()
	var directory := DirAccess.open(folder)
	if directory != null:
		for file: String in directory.get_files(): DirAccess.remove_absolute(ProjectSettings.globalize_path(folder + "/" + file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	return finish("signature-progression")


func _fresh(path_suffix: String = "missing.json") -> SignatureProgression:
	var progress := Progress.new()
	check(progress.configure(champions, abilities, folder + "/" + path_suffix, false), "fresh profile is read-only until an earned save")
	return progress


func _test_catalog_and_access() -> void:
	var rows := Challenges.rows(champions, abilities)
	equal(rows.size(), 30, "every current rival has one authored signature")
	var wires := {}
	var families := {}
	var progress := _fresh()
	for row: Dictionary in rows:
		check(not wires.has(int(row.signature_wire)), "signature pair is unique: %s" % row.id)
		wires[int(row.signature_wire)] = true
		families[String(row.family)] = true
		equal(Mixtures.wire_for(int(row.mask), String(row.family)), int(row.signature_wire), "catalog alone owns wire lookup")
		check(not progress.can_equip(int(row.signature_wire)), "unearned signature starts locked")
		check(progress.can_equip(int(row.signature_wire), true), "temporary override can inspect every signature")
		equal(progress.learned_ids().size(), 0, "override never grants progress")
		check(not String(row.tell).is_empty() and not String(row.counter).is_empty(), "signature teaches tell and counter")
	equal(families.size(), 8, "signature set demonstrates every delivery family")
	for wire: int in CombatTuning.runtime_wire_ids():
		equal(progress.can_equip(wire), not wires.has(wire), "only explicit thirty signatures lock; all other live spells remain free")
	check(not progress.can_equip(999999, true), "override never admits an unknown spell")
	var preserved := int(rows[0].signature_wire)
	progress.preserve_existing(PackedInt32Array([preserved]))
	check(progress.can_equip(preserved), "existing valid saved spell survives new progression")
	equal(progress.learned_ids().size(), 0, "preservation is not a fabricated victory")
	check(String(progress.view().characters).contains("already available"), "no invented character grind")


func _test_persistence() -> void:
	var path := folder + "/earned.json"
	var progress := FailedSave.new()
	check(progress.configure(champions, abilities, path, true), "missing profile configures")
	check(not FileAccess.file_exists(path), "configure does not create or normalize profile")
	var reward := progress.record_victory("oh_tipi")
	check(bool(reward.ok) and bool(reward.new) and bool(reward.saved), "earned victory persists")
	var original := FileAccess.get_file_as_bytes(path)
	reward = progress.record_victory("oh_tipi")
	check(not bool(reward.new), "duplicate victory is idempotent")
	equal(FileAccess.get_file_as_bytes(path), original, "duplicate victory does not rewrite bytes")
	progress.fail_primary = true
	reward = progress.record_victory("s_wayne")
	check(bool(reward.ok) and not bool(reward.saved) and progress.dirty, "failed replacement retains session unlock and dirty status")
	equal(FileAccess.get_file_as_bytes(path), original, "failed replacement keeps exact original")
	equal(FileAccess.get_file_as_bytes(path + Progress.BACKUP_SUFFIX), original, "first replacement keeps byte-exact backup")
	progress.fail_primary = false
	check(progress.save(), "explicit retry saves pending earned progress")
	var reloaded := Progress.new()
	check(reloaded.configure(champions, abilities, path, true), "earned profile reloads")
	equal(reloaded.learned_ids(), ["oh_tipi", "s_wayne"], "canonical rival IDs survive reload")
	for bad: Variant in [{"schema_version": 2, "defeated": []}, {"schema_version": 1, "defeated": ["unknown"]}, {"schema_version": 1, "defeated": ["oh_tipi", "oh_tipi"]}, {"schema_version": 1, "defeated": [], "all_spells": true}, {"schema_version": 1, "defeated": "all"}]:
		var bad_path := folder + "/invalid.json"
		var bytes := JSON.stringify(bad).to_utf8_buffer()
		var file := FileAccess.open(bad_path, FileAccess.WRITE)
		file.store_buffer(bytes)
		file.close()
		check(not reloaded.configure(champions, abilities, bad_path, true), "unknown or malformed profile refuses atomically")
		check(not bool(reloaded.record_victory("oh_tipi").ok), "invalid profile cannot silently overwrite history")
		equal(FileAccess.get_file_as_bytes(bad_path), bytes, "invalid/future source retained exactly")


func _world(row: Dictionary) -> SimWorld:
	var world := SimWorld.new()
	check(champions.apply_to_player(world.player(), "oh_tipi"), "player receives real champion profile")
	check(HexCourtPractice.configure(world, abilities), "actual paid Hex court configures")
	var rival := world.player(2)
	check(champions.apply_to_player(rival, String(row.champion_id)), "rival receives authored champion")
	rival.actor_kind = PlayerState.ActorKind.CHAMPION
	rival.team_id = 2
	check(rival.place_proven_spell(0, int(row.signature_wire)), "signature occupies an ordinary slot")
	return world


func _test_bound_reward() -> void:
	var row := Challenges.definition("oh_tipi", champions, abilities)
	for contaminated: bool in [false, true]:
		var progress := _fresh("reward-%s.json" % contaminated)
		var world := _world(row)
		var challenge := Challenge.new()
		check(not challenge.begin(world, Rect2i(0, 0, 1280, 960), row, false), "network worlds cannot open signature challenges")
		check(challenge.begin(world, Rect2i(0, 0, 1280, 960), row, true, contaminated), "bound local attempt begins")
		var before := world.state_hash()
		check(challenge.command(world) != null, "rival command is ordinary and available")
		equal(world.state_hash(), before, "AI command planning never changes authority")
		# Real paid Fire Bolts against the actual champion: no health injection,
		# cooldown resets, resource grants or fabricated defeat events in this path.
		var spent := false
		for unused: int in 8641:
			if challenge.trial.is_finished(): break
			var player := world.player(1)
			var target := world.player(2)
			var delta := Vector2i(target.position_x - player.position_x, target.position_y - player.position_y)
			var held := SimCommand.SPELL_HELD_BITS[1] if world.tick >= 480 else 0
			check(world.step([SimCommand.new(world.tick, 1, 0, 0, held, 0, delta.x, delta.y)]), "ordinary paid command steps")
			spent = spent or player.flux < player.flux_maximum
			challenge.observe(world, progress, true, false)
		check(spent, "real encounter spent Flux")
		equal(challenge.trial.phase, "victory", "real paid damage produces victory")
		equal(bool(challenge.reward.get("ok", false)), not contaminated, "only clean victory learns; turning off dev cannot untaint")
		equal(progress.learned_ids().size(), 0 if contaminated else 1, "earned count matches clean actual result")
		var count := progress.learned_ids().size()
		challenge.observe(world, progress, true, false)
		equal(progress.learned_ids().size(), count, "duplicate observation never repeats grant")
	var progress := _fresh("no-event.json")
	var world := _world(row)
	var challenge := Challenge.new()
	check(challenge.begin(world, Rect2i(0, 0, 1280, 960), row, true), "negative health-edit fixture binds")
	world.player(2).health = 0
	world.tick += 1
	check(challenge.observe(world, progress, true), "bare health change reaches terminal bookkeeping")
	check(not bool(challenge.reward.ok), "bare health edit without real owned hit/defeat events grants nothing")
	check(progress.learned_ids().is_empty(), "synthetic terminal state does not fabricate progress")
