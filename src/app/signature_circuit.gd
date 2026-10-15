extends RefCounted
## Ephemeral route bookkeeping. The bound challenge owns combat and rewards;
## callers admit a leg only after its real fresh-world transition succeeds.

const Trial = preload("res://src/app/solo_duel_trial.gd")
const ROUTE: Array[String] = ["wa_bidi", "oh_tipi", "s_wayne"]
const TERMINAL: Array[String] = [Trial.VICTORY, Trial.DEFEATED, Trial.TIMEOUT, Trial.LEFT_COURT, Trial.UNAVAILABLE]

var _state := "idle"
var _stage := 0
var _attempt := 0
var _run := 0
var _total_elapsed_ticks := 0
var _result: Dictionary = {}


func begin() -> bool:
	reset()
	_run += 1
	_state = "ready"
	return true


func reset() -> void:
	_state = "idle"
	_stage = 0
	_attempt = 0
	_total_elapsed_ticks = 0
	_result.clear()


func current_id() -> String:
	return "" if _state == "idle" else ROUTE[_stage]


func admit_current(id: String) -> bool:
	if _state != "ready" or id != current_id(): return false
	_admit()
	return true


func next_id() -> String:
	return ROUTE[_stage + 1] if _state == "result" and bool(_result.get("qualified", false)) and _stage + 1 < ROUTE.size() else ""


func retry_id() -> String:
	return current_id() if _state == "result" and not bool(_result.get("qualified", false)) else ""


func admit_next(id: String) -> bool:
	if id.is_empty() or id != next_id(): return false
	_stage += 1
	_admit()
	return true


func admit_retry(id: String) -> bool:
	if id.is_empty() or id != retry_id(): return false
	_admit()
	return true


func ticket() -> Vector2i:
	return Vector2i(_run, _attempt)


func observe_result(challenge_view: Dictionary, expected_ticket: Vector2i = Vector2i(-1, -1)) -> bool:
	# Current synchronous controller calls may omit the ticket. Deferred callers
	# must capture it at admission; a previous run/attempt cannot finish this one.
	if expected_ticket != Vector2i(-1, -1) and expected_ticket != ticket(): return false
	if _state != "active" or not bool(challenge_view.get("finished", false)): return false
	var definition: Dictionary = challenge_view.get("challenge", {})
	var phase := String(challenge_view.get("phase", ""))
	if String(definition.get("id", "")) != current_id() or phase not in TERMINAL: return false
	var reward: Dictionary = challenge_view.get("reward", {})
	var qualified := phase == Trial.VICTORY and bool(reward.get("ok", false)) and not bool(challenge_view.get("developer", false)) \
		and int(reward.get("wire", 0)) > 0 and int(reward.get("wire", 0)) == int(definition.get("signature_wire", 0))
	# Bounded detached presentation values, never old worlds or event histories.
	_result = {
		"phase": phase, "qualified": qualified,
		"elapsed_ticks": maxi(0, int(challenge_view.get("elapsed_ticks", 0))),
		"health": int(challenge_view.get("health", 0)),
		"health_maximum": int(challenge_view.get("health_maximum", 0)),
		"paid_casts": maxi(0, int(challenge_view.get("paid_casts", 0))),
		"interceptions": maxi(0, int(challenge_view.get("interceptions", 0))),
		"name": String(definition.get("name", current_id())),
		"spell_name": String(definition.get("spell_name", "Signature")),
		"signature_wire": int(definition.get("signature_wire", 0)),
		"reward": {"ok": bool(reward.get("ok", false)), "new": bool(reward.get("new", false)), "saved": bool(reward.get("saved", false)), "wire": int(reward.get("wire", 0)), "notice": String(reward.get("notice", ""))},
	}
	_total_elapsed_ticks += int(_result.elapsed_ticks)
	_state = "complete" if qualified and _stage == ROUTE.size() - 1 else "result"
	return true


func refresh_reward(reward: Dictionary) -> bool:
	# Recovery can update persistence presentation, never turn an unearned or
	# tainted result into a win. Actual reward ownership stays in progression.
	if _state not in ["result", "complete"] or not bool(_result.get("qualified", false)): return false
	var existing: Dictionary = _result.reward
	if not bool(reward.get("ok", false)) or int(reward.get("wire", 0)) != int(existing.wire): return false
	existing.saved = bool(reward.get("saved", false))
	existing.notice = String(reward.get("notice", ""))
	return true


func view() -> Dictionary:
	return {"active": _state != "idle", "state": _state, "stage": _stage, "total": ROUTE.size(), "current_id": current_id(),
		"complete": _state == "complete", "can_next": not next_id().is_empty(), "can_retry": not retry_id().is_empty(),
		"run": _run, "attempt": _attempt, "total_elapsed_ticks": _total_elapsed_ticks, "result": _result.duplicate(true)}


func _admit() -> void:
	_attempt += 1
	_state = "active"
	_result.clear()
