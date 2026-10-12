extends FluxTestSuite

const Progress = preload("res://src/app/signature_progression.gd")

class FailedSave:
	extends SignatureProgression
	var fail_primary := false
	var fail_rolling := false
	func _replace_staged(staged: String, target: String) -> Error:
		if fail_primary and target == path: return ERR_CANT_CREATE
		if fail_rolling and target == path + ROLLING_SUFFIX: return ERR_CANT_CREATE
		return super._replace_staged(staged, target)

func run() -> int:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "recovery catalog")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "recovery roster")
	var folder := "user://signature-recovery-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) == OK, "owned recovery fixture directory")
	var path := folder + "/progress.json"
	var progress := FailedSave.new()
	check(progress.configure(champions, abilities, path, true), "new progress configures")
	check(bool(progress.record_victory("oh_tipi").saved), "first earned spell persisted")
	var first := FileAccess.get_file_as_bytes(path)
	progress.fail_primary = true
	check(not bool(progress.record_victory("s_wayne").saved), "injected failure retains earned second spell")
	check(bool(progress.view().can_retry_save), "unsaved progress exposes explicit retry")
	check(not bool(progress.retry_save().ok), "failed retry remains honest")
	equal(FileAccess.get_file_as_bytes(path), first, "failed retry preserves primary bytes")
	progress.fail_primary = false
	check(bool(progress.retry_save().saved), "restored storage saves without another victory")
	check(not bool(progress.view().can_retry_save), "retry clears after successful persistence")
	var restarted := Progress.new()
	check(restarted.configure(champions, abilities, path, true), "restart opens saved records")
	equal(restarted.learned_ids(), ["oh_tipi", "s_wayne"], "both earned records survive restart")
	var second := FileAccess.get_file_as_bytes(path)
	progress.fail_rolling = true
	check(not bool(progress.record_victory("red_baron").saved), "failed rolling replacement blocks primary replacement")
	equal(FileAccess.get_file_as_bytes(path), second, "rolling failure leaves valid primary byte-exact")
	equal(FileAccess.get_file_as_bytes(path + Progress.ROLLING_SUFFIX), first, "rolling failure preserves earlier generation")
	progress.fail_rolling = false
	check(bool(progress.retry_save().saved), "retry advances third earned record")
	equal(FileAccess.get_file_as_bytes(path + Progress.ROLLING_SUFFIX), second, "rolling backup advances to previous validated primary")
	equal(FileAccess.get_file_as_bytes(path + Progress.BACKUP_SUFFIX), first, "original backup never advances")
	check(progress.save(), "idempotent save succeeds")
	equal(FileAccess.get_file_as_bytes(path + Progress.ROLLING_SUFFIX), second, "idempotent save cannot consume previous generation")
	var corrupt := "future or damaged progress; never discard".to_utf8_buffer()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(corrupt)
	file.close()
	check(not restarted.configure(champions, abilities, path, true), "invalid primary refuses without repair")
	equal(FileAccess.get_file_as_bytes(path), corrupt, "load never alters invalid bytes")
	check(bool(restarted.view().can_recover_backup), "valid backup offers explicit recovery")
	equal(int(restarted.view().recovery_count), 2, "recovery preview reports actual rolling records")
	var recovery := restarted.recover_backup()
	check(bool(recovery.ok), "explicit recovery succeeds")
	equal(FileAccess.get_file_as_bytes(String(recovery.get("recovery_copy_path", ""))), corrupt, "exact invalid primary survives as separate recovery copy")
	equal(FileAccess.get_file_as_bytes(path + Progress.BACKUP_SUFFIX), first, "known-good original backup remains byte-exact")
	var final_reload := Progress.new()
	check(final_reload.configure(champions, abilities, path, true), "restored record survives restart")
	equal(final_reload.learned_ids(), ["oh_tipi", "s_wayne"], "recovery prefers newer rolling records over first backup")
	check(not bool(final_reload.recover_backup().ok), "recovery cannot overwrite a valid current save")
	# External repair while the game is open must retire the stale recovery action
	# without silently importing records or pretending that this action saved them.
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(corrupt)
	file.close()
	check(not final_reload.configure(champions, abilities, path, true), "external repair starts from refused configuration")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(first)
	file.close()
	var external_repair := final_reload.recover_backup()
	check(not bool(external_repair.ok) and not bool(external_repair.saved), "external repair is not a recovery save")
	check(not bool(final_reload.view().can_recover_backup) and not final_reload.configured, "valid external primary retires stale recovery without silent admission")
	check(String(external_repair.notice).contains("Restart H.E.X."), "unconfigured external repair explains reload action")
	equal(FileAccess.get_file_as_bytes(path), first, "external repair remains byte-exact")
	# A transient failure followed by external corruption must not discard the
	# additional spell already earned legitimately in the running session.
	check(progress.configure(champions, abilities, path, true), "earned session reopens restored profile")
	progress.fail_primary = true
	progress.record_victory("s_wayne")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(corrupt)
	file.close()
	progress.fail_primary = false
	check(not bool(progress.retry_save().ok), "retry never overwrites newly invalid primary")
	check(bool(progress.view().can_recover_backup), "failed retry discovers explicit recovery")
	check(bool(progress.recover_backup().ok), "verified backup and session earnings recover together")
	check(final_reload.configure(champions, abilities, path, true), "merged recovery survives restart")
	equal(final_reload.learned_ids(), ["oh_tipi", "s_wayne"], "recovery preserves session-earned additions")
	var oversized := PackedByteArray()
	oversized.resize(Progress.MAX_RECOVERY_BYTES + 1)
	oversized.fill(65)
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(oversized)
	file.close()
	var oversized_hash := FileAccess.get_sha256(path)
	check(not final_reload.configure(champions, abilities, path, true), "oversized corrupt file refuses during bounded load")
	check(not bool(final_reload.recover_backup().ok), "in-game recovery refuses oversized preservation")
	equal(FileAccess.get_sha256(path), oversized_hash, "oversized original remains exact")
	equal(FileAccess.get_file_as_bytes(path + Progress.BACKUP_SUFFIX), first, "oversized recovery refusal retains verified backup")
	var session_only := Progress.new()
	check(session_only.configure(champions, abilities, folder + "/session.json", false), "isolated temporary session configures")
	session_only.record_victory("oh_tipi")
	check(not bool(session_only.view().can_retry_save) and not bool(session_only.retry_save().saved), "temporary sessions cannot persist through retry")
	check(not bool(session_only.recover_backup().ok), "temporary sessions cannot restore persistent progress")
	check(not FileAccess.file_exists(folder + "/session.json"), "temporary actions create no progress file")
	_test_missing_and_damaged_backups(champions, abilities, folder)
	var directory := DirAccess.open(folder)
	for name: String in directory.get_files(): DirAccess.remove_absolute(ProjectSettings.globalize_path(folder + "/" + name))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	return finish("signature-recovery")


func _test_missing_and_damaged_backups(champions: ChampionCatalog, abilities: AbilityCatalog, folder: String) -> void:
	var path := folder + "/generations.json"
	var progress := Progress.new()
	check(progress.configure(champions, abilities, path), "generation fixture configures")
	progress.record_victory("oh_tipi")
	var first := FileAccess.get_file_as_bytes(path)
	progress.record_victory("s_wayne")
	var second := FileAccess.get_file_as_bytes(path)
	progress.record_victory("red_baron")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(not progress.configure(champions, abilities, path), "missing primary with backup requires explicit recovery")
	check(not FileAccess.file_exists(path), "missing primary is not silently replaced with empty progress")
	check(bool(progress.recover_backup().ok), "missing primary recovers verified rolling generation")
	equal(FileAccess.get_file_as_bytes(path), second, "missing primary recovers exact earned records")
	var damaged := "unrecognized backup; preserve me".to_utf8_buffer()
	for suffix: String in [Progress.BACKUP_SUFFIX, Progress.ROLLING_SUFFIX]:
		var file := FileAccess.open(path + suffix, FileAccess.WRITE)
		file.store_buffer(damaged)
		file.close()
	check(bool(progress.record_victory("red_baron").saved), "valid primary can advance despite damaged old backups")
	equal(FileAccess.get_file_as_bytes(path + Progress.BACKUP_SUFFIX), damaged, "damaged immutable backup is preserved exactly")
	equal(FileAccess.get_file_as_bytes(path + Progress.ROLLING_SUFFIX), second, "rolling backup regains validated prior generation")
	var preserved := 0
	for name: String in DirAccess.open(folder).get_files():
		if name.begins_with("generations.json" + Progress.ROLLING_SUFFIX + ".recovery-"):
			preserved += 1
			equal(FileAccess.get_file_as_bytes(folder + "/" + name), damaged, "damaged rolling bytes survive separately")
	equal(preserved, 1, "one damaged rolling generation creates one preservation copy")
	# If the rolling generation alone is damaged, original remains a valid fallback.
	var file := FileAccess.open(path + Progress.BACKUP_SUFFIX, FileAccess.WRITE)
	file.store_buffer(first)
	file.close()
	for suffix: String in ["", Progress.ROLLING_SUFFIX]:
		file = FileAccess.open(path + suffix, FileAccess.WRITE)
		file.store_buffer(damaged)
		file.close()
	check(not progress.configure(champions, abilities, path), "invalid generations refuse automatic loading")
	equal(int(progress.view().recovery_count), 1, "fallback previews only first backup's actual record")
	check(bool(progress.recover_backup().ok), "invalid rolling can fall back to verified original")
	equal(progress.learned_ids(), ["oh_tipi"], "fallback never manufactures later records")
	progress.record_victory("s_wayne")
	var repaired := FileAccess.get_file_as_bytes(path)
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(damaged)
	file.close()
	check(not progress.save() and bool(progress.view().can_recover_backup), "failed save discovers recovery after external damage")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(repaired)
	file.close()
	check(progress.save(), "external repair identical to session admits idempotent save")
	check(not bool(progress.view().can_recover_backup), "validated idempotent save retires stale recovery action")
	equal(String(progress.view().recovery_source), "", "successful idempotent save clears stale recovery provenance")
