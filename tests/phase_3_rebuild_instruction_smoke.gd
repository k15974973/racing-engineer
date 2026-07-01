extends SceneTree

const MIN_SCORE_GAIN := 5.0

var _lag_check: Dictionary = {}
var _affinity_check: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_data = root.get_node("/root/GameData")
	var summary: Dictionary = game_data.get_summary()
	var errors: Array = summary.get("errors", [])
	if not errors.is_empty():
		_fail("GameData reported validation errors: %s" % errors)
		return

	if not _assert_lag_penalty_shape(game_data):
		return

	if not _assert_report_card_affinity(game_data):
		return

	var case: Dictionary = _find_induction_rebuild_case(game_data)
	if case.is_empty():
		_fail("No real setup produced an induction rebuild instruction for Technical Loop.")
		return

	var baseline_result: Dictionary = case.get("result", {})
	var analysis: Dictionary = case.get("analysis", {})
	var instruction: Dictionary = case.get("instruction", {})
	if str(instruction.get("issue", "")) == "" or str(instruction.get("direction", "")) == "":
		_fail("Instruction should include readable issue and direction fields.")
		return
	if str(instruction.get("target_field", "")) != "induction":
		_fail("Expected induction target_field, got %s." % instruction.get("target_field", ""))
		return
	if not _assert_weakest_matches_instruction(analysis, instruction):
		return

	var improved_result: Dictionary = _best_induction_rebuild(game_data, case)
	if improved_result.is_empty():
		_fail("Could not rebuild according to induction instruction.")
		return

	var baseline_score := float(baseline_result.get("technical_score", 0.0))
	var improved_score := float(improved_result.get("technical_score", 0.0))
	var score_gain := improved_score - baseline_score
	if score_gain < MIN_SCORE_GAIN:
		_fail("Rebuilding from instruction should improve technical_score by at least %0.1f. Baseline=%0.1f improved=%0.1f instruction=%s" % [MIN_SCORE_GAIN, baseline_score, improved_score, instruction])
		return

	print("PHASE_3_REBUILD_INSTRUCTION_OK target=%s score_gain=%+0.1f lag_na=%s lag_twin=%s v8_fit=%s inline4_fit=%s baseline=%s/%s/%s improved=%s/%s/%s" % [
		instruction.get("target_field", "?"),
		score_gain,
		_lag_check.get("na_score", "?"),
		_lag_check.get("twin_score", "?"),
		_affinity_check.get("v8_best_fit", "?"),
		_affinity_check.get("inline_best_fit", "?"),
		baseline_result.get("setup", {}).get("block", {}).get("id", "?"),
		baseline_result.get("setup", {}).get("induction", {}).get("id", "?"),
		baseline_result.get("setup", {}).get("material", {}).get("id", "?"),
		improved_result.get("setup", {}).get("block", {}).get("id", "?"),
		improved_result.get("setup", {}).get("induction", {}).get("id", "?"),
		improved_result.get("setup", {}).get("material", {}).get("id", "?")
	])
	quit(0)

func _assert_lag_penalty_shape(game_data: Node) -> bool:
	var na_result := _race_setup(game_data, "v8", "na", "aluminum", "technical_loop")
	if not _assert_valid_result(na_result, "V8 NA Technical Loop"):
		return false

	var twin_result := _race_setup(game_data, "v8", "twin_turbo", "aluminum", "technical_loop")
	if not _assert_valid_result(twin_result, "V8 Twin Turbo Technical Loop"):
		return false

	var na_score := float(na_result.get("technical_score", 0.0))
	var twin_score := float(twin_result.get("technical_score", 0.0))
	_lag_check = {
		"na_score": snappedf(na_score, 0.1),
		"twin_score": snappedf(twin_score, 0.1)
	}
	if na_score < 60.0:
		_fail("NA has zero lag and should not fall under the technical instruction threshold. Score=%0.1f" % na_score)
		return false
	if twin_score >= na_score:
		_fail("Twin Turbo should score lower than NA on Technical Loop after lag penalty. NA=%0.1f twin=%0.1f" % [na_score, twin_score])
		return false

	return true

func _assert_report_card_affinity(game_data: Node) -> bool:
	var v8_result := _race_setup(game_data, "v8", "na", "aluminum", "power_ring")
	if not _assert_valid_result(v8_result, "V8 NA Power Ring"):
		return false

	var v8_analysis: Dictionary = game_data.analyze_race_result(v8_result)
	if not _assert_report_card(v8_analysis, "V8 NA Power Ring"):
		return false

	var v8_report: Dictionary = v8_analysis.get("report_card", {})
	var v8_scores: Dictionary = v8_report.get("scores", {})
	if float(v8_scores.get("power", 0.0)) < float(v8_scores.get("technical", 0.0)) or float(v8_scores.get("power", 0.0)) < float(v8_scores.get("endurance", 0.0)):
		_fail("V8 NA should expose power as its strongest report card score: %s" % v8_scores)
		return false

	var v8_affinity: Dictionary = v8_report.get("track_affinity", {})
	if str(v8_affinity.get("best_fit", "")) != "power_ring":
		_fail("V8 NA should prefer Power Ring, got %s with report %s." % [v8_affinity.get("best_fit", ""), v8_report])
		return false

	var inline_result := _race_setup(game_data, "inline_4", "supercharger", "aluminum", "technical_loop")
	if not _assert_valid_result(inline_result, "Inline-4 SC Technical Loop"):
		return false

	var inline_analysis: Dictionary = game_data.analyze_race_result(inline_result)
	if not _assert_report_card(inline_analysis, "Inline-4 SC Technical Loop"):
		return false

	var inline_report: Dictionary = inline_analysis.get("report_card", {})
	var inline_scores: Dictionary = inline_report.get("scores", {})
	if float(inline_scores.get("technical", 0.0)) < float(inline_scores.get("power", 0.0)) or float(inline_scores.get("technical", 0.0)) < float(inline_scores.get("endurance", 0.0)):
		_fail("Inline-4 SC should expose technical as its strongest report card score: %s" % inline_scores)
		return false

	var inline_affinity: Dictionary = inline_report.get("track_affinity", {})
	if str(inline_affinity.get("best_fit", "")) != "technical_loop":
		_fail("Inline-4 SC should prefer Technical Loop, got %s with report %s." % [inline_affinity.get("best_fit", ""), inline_report])
		return false

	_affinity_check = {
		"v8_best_fit": str(v8_affinity.get("best_fit", "")),
		"inline_best_fit": str(inline_affinity.get("best_fit", ""))
	}
	return true

func _assert_report_card(analysis: Dictionary, label: String) -> bool:
	if analysis.has("error"):
		_fail("%s analysis failed: %s" % [label, analysis.get("error", "")])
		return false

	var report: Dictionary = analysis.get("report_card", {})
	if report.is_empty():
		_fail("%s analysis should include report_card." % label)
		return false

	var scores: Dictionary = report.get("scores", {})
	for axis in ["power", "technical", "endurance"]:
		var score := float(scores.get(axis, -1.0))
		if score < 0.0 or score > 100.0:
			_fail("%s report_card score %s should be 0-100, got %s." % [label, axis, score])
			return false

	if not (str(report.get("weakest", "")) in ["block", "induction", "material"]):
		_fail("%s report_card weakest should target a builder slot, got %s." % [label, report.get("weakest", "")])
		return false

	var affinity: Dictionary = report.get("track_affinity", {})
	if str(affinity.get("best_fit", "")) == "" or str(affinity.get("reason", "")) == "":
		_fail("%s report_card should include track affinity best_fit and reason." % label)
		return false

	return true

func _assert_weakest_matches_instruction(analysis: Dictionary, instruction: Dictionary) -> bool:
	if not _assert_report_card(analysis, "Instruction case"):
		return false

	var report: Dictionary = analysis.get("report_card", {})
	if str(report.get("weakest", "")) != str(instruction.get("target_field", "")):
		_fail("Report card weakest should match instruction target_field. weakest=%s instruction=%s" % [report.get("weakest", ""), instruction])
		return false

	return true

func _race_setup(game_data: Node, block_id: String, induction_id: String, material_id: String, track_id: String) -> Dictionary:
	var setup: Dictionary = game_data.calculate_engine_setup(block_id, induction_id, material_id)
	if setup.has("error"):
		return setup
	return game_data.calculate_race_result(setup, track_id)

func _assert_valid_result(result: Dictionary, label: String) -> bool:
	if result.has("error"):
		_fail("%s failed: %s" % [label, result.get("error", "")])
		return false
	return true

func _find_induction_rebuild_case(game_data: Node) -> Dictionary:
	var worst_seen := {"score": INF, "setup": ""}
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

				var result: Dictionary = game_data.calculate_race_result(setup, "technical_loop")
				if result.has("error"):
					continue

				var technical_score := float(result.get("technical_score", 0.0))
				if technical_score < float(worst_seen.get("score", INF)):
					worst_seen = {
						"score": technical_score,
						"setup": "%s/%s/%s" % [block.get("id", ""), induction.get("id", ""), material.get("id", "")]
					}

				var analysis: Dictionary = game_data.analyze_race_result(result)
				var instructions: Array = analysis.get("rebuild_instructions", [])
				if instructions.size() > 2:
					_fail("Analysis should return at most 2 rebuild instructions.")
					return {}

				for item in instructions:
					if typeof(item) != TYPE_DICTIONARY:
						continue

					var instruction: Dictionary = item
					if str(instruction.get("target_field", "")) == "induction":
						return {
							"setup": setup,
							"result": result,
							"analysis": analysis,
							"instruction": instruction
						}

	push_warning("Worst Technical Loop score seen: %s from %s." % [worst_seen.get("score", "?"), worst_seen.get("setup", "?")])
	return {}

func _best_induction_rebuild(game_data: Node, case: Dictionary) -> Dictionary:
	var setup: Dictionary = case.get("setup", {})
	var block: Dictionary = setup.get("block", {})
	var material: Dictionary = setup.get("material", {})
	var best_result: Dictionary = {}
	var best_score := -INF
	for induction_id in ["na", "supercharger"]:
		var rebuild_setup: Dictionary = game_data.calculate_engine_setup(str(block.get("id", "")), induction_id, str(material.get("id", "")))
		if rebuild_setup.has("error"):
			continue

		var result: Dictionary = game_data.calculate_race_result(rebuild_setup, "technical_loop")
		if result.has("error"):
			continue

		var score := float(result.get("technical_score", 0.0))
		if score > best_score:
			best_score = score
			best_result = result

	return best_result

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
