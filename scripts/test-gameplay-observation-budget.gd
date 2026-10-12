extends SceneTree
## Pure bounded-recorder tests. Loads the profiler class without instantiating
## its SceneTree or launching a game. Root runs this through the checked engine.
const Profiler = preload("res://scripts/profile-gameplay.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	var budget := Profiler.ObservationBudget.new()
	for _index: int in Profiler.ObservationBudget.CASE_STREAM_LIMIT:
		if not budget.admit(&"process"):
			check(false, "Every in-bound process group is retained")
			break
	check(budget.case_counts[&"process"] == 12000 and budget.run_groups == 12000, "Exact per-stream boundary admits every record")
	var detached: Dictionary = budget.snapshot()
	detached.case_counts[&"process"] = -1
	detached.run_counts.clear()
	check(budget.case_counts[&"process"] == 12000 and budget.run_counts[&"process"] == 12000, "Receipt mutation cannot change recorder ownership")
	check(not budget.admit(&"process") and budget.overflow and budget.run_groups == 12000, "First overflow is rejected without growing any recorded stream")
	budget.begin_case()
	check(not budget.admit(&"draw") and budget.overflow, "A new case cannot clear a failed run or silently resume collection")
	var run_budget := Profiler.ObservationBudget.new()
	for _case: int in 10:
		run_budget.begin_case()
		for _index: int in Profiler.ObservationBudget.CASE_STREAM_LIMIT:
			if not run_budget.admit(&"draw"):
				check(false, "Every in-bound run group is retained")
				break
	check(run_budget.run_groups == 120000 and not run_budget.overflow, "Case resets keep the exact accumulated run bound")
	run_budget.begin_case()
	check(not run_budget.admit(&"court") and run_budget.overflow and run_budget.run_groups == 120000, "A different stream cannot bypass the total run bound")
	var invalid := Profiler.ObservationBudget.new()
	check(not invalid.admit(&"unbounded_dynamic_key") and invalid.run_counts.is_empty(), "Unknown stream names cannot grow diagnostic dictionaries")
	print("gameplay-observation-budget: %d assertions, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
