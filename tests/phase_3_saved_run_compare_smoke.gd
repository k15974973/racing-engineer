extends SceneTree

const TRACK_ID := "technical_loop"
const RUN_LIMIT := 3

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_data = root.get_node("/root/GameData")
	var summary: Dictionary = game_data.get_summary()
	var errors: Array = summary.get("errors", [])
	if not errors.is_empty():
		_fail("GameData reported validation errors: %s" % errors)
		return

	var candidates := _candidate_records(game_data)
	if candidates.size() < 4:
		_fail("Need at least four candidate runs for FIFO comparison test.")
		return

	var ordered := _records_sorted_by_total(candidates)
	var fastest: Dictionary = ordered[0]
	var history := [
		_named_record(ordered[ordered.size() - 1], "Race 1"),
		_named_record(ordered[ordered.size() - 2], "Race 2"),
		_named_record(ordered[ordered.size() - 3], "Race 3"),
		_named_record(fastest, "Race 4")
	]

	var trimmed: Array = game_data.trim_saved_runs_for_track(history, TRACK_ID, RUN_LIMIT)
	if trimmed.size() != RUN_LIMIT:
		_fail("After four saves, track list should keep exactly three runs. Got %d." % trimmed.size())
		return
	if _record_names(trimmed).has("Race 1"):
		_fail("FIFO trim should remove the oldest run, not a newer run. Names=%s" % _record_names(trimmed))
		return

	var grouped: Dictionary = game_data.group_saved_runs_by_track(trimmed, RUN_LIMIT)
	var grouped_runs: Array = grouped.get(TRACK_ID, [])
	if grouped_runs.size() != RUN_LIMIT:
		_fail("Grouped saved_runs[%s] should contain %d runs, got %d." % [TRACK_ID, RUN_LIMIT, grouped_runs.size()])
		return

	var comparison: Dictionary = game_data.build_saved_run_comparison(trimmed, TRACK_ID, RUN_LIMIT)
	if comparison.is_empty():
		_fail("Comparison should be available after saved runs exist.")
		return
	if int(comparison.get("count", 0)) != RUN_LIMIT:
		_fail("Comparison should expose %d runs, got %s." % [RUN_LIMIT, comparison.get("count", "?")])
		return
	if str(comparison.get("best_name", "")) != "Race 4":
		_fail("New fastest run should be best. Best=%s comparison=%s" % [comparison.get("best_name", ""), comparison])
		return

	var best_total := float(comparison.get("best_total_time", 0.0))
	for item in comparison.get("runs", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var run: Dictionary = item
		var total := float(run.get("total_time", 0.0))
		var deltas: Dictionary = run.get("deltas", {})
		var expected_delta := snappedf(total - best_total, 0.01)
		var reported_delta := float(deltas.get("total_time", 999.0))
		if absf(reported_delta - expected_delta) > 0.01:
			_fail("%s total delta should equal current.total_time - best.total_time. Expected=%0.2f reported=%0.2f" % [run.get("name", "Run"), expected_delta, reported_delta])
			return

		if bool(run.get("is_best", false)):
			if absf(reported_delta) > 0.01:
				_fail("Best run delta should be zero, got %0.2f." % reported_delta)
				return
		elif reported_delta <= 0.0:
			_fail("When the newest run is best, older kept runs should have positive slower deltas. Run=%s delta=%0.2f" % [run.get("name", "Run"), reported_delta])
			return

	print("PHASE_3_SAVED_RUN_COMPARE_OK kept=%s best=%s best_total=%s" % [
		_record_names(trimmed),
		comparison.get("best_name", "?"),
		comparison.get("best_total_time", "?")
	])
	quit(0)

func _candidate_records(game_data: Node) -> Array:
	var records: Array = []
	for block in game_data.blocks:
		if typeof(block) != TYPE_DICTIONARY:
			continue

		for induction in game_data.inductions:
			if typeof(induction) != TYPE_DICTIONARY:
				continue

			for material in game_data.materials:
				if typeof(material) != TYPE_DICTIONARY:
					continue

				var setup: Dictionary = game_data.calculate_engine_setup(str(block.get("id", "")), str(induction.get("id", "")), str(material.get("id", "")))
				if setup.has("error"):
					continue

				var result: Dictionary = game_data.calculate_race_result(setup, TRACK_ID)
				if result.has("error"):
					continue

				records.append({
					"name": "Candidate",
					"track_id": TRACK_ID,
					"selection": {
						"block": str(block.get("id", "")),
						"induction": str(induction.get("id", "")),
						"material": str(material.get("id", ""))
					},
					"tuning": setup.get("tuning", {}),
					"decisions": {},
					"result": result
				})

	return records

func _records_sorted_by_total(records: Array) -> Array:
	var remaining := records.duplicate(true)
	var sorted: Array = []
	while not remaining.is_empty():
		var best_index := 0
		for index in range(1, remaining.size()):
			var candidate: Dictionary = remaining[index]
			var best: Dictionary = remaining[best_index]
			if _record_total(candidate) < _record_total(best):
				best_index = index

		sorted.append(remaining[best_index])
		remaining.remove_at(best_index)

	return sorted

func _record_total(record: Dictionary) -> float:
	var result: Dictionary = record.get("result", {})
	return float(result.get("total_time", INF))

func _named_record(record: Dictionary, name: String) -> Dictionary:
	var copy := record.duplicate(true)
	copy["name"] = name
	return copy

func _record_names(records: Array) -> Array:
	var names: Array = []
	for item in records:
		if typeof(item) == TYPE_DICTIONARY:
			names.append(str(item.get("name", "Race")))
	return names

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
