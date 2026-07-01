extends SceneTree

const MIN_SCORE_GAIN := 5.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_data = root.get_node("/root/GameData")
	var summary: Dictionary = game_data.get_summary()
	var errors: Array = summary.get("errors", [])
	if not errors.is_empty():
		_fail("GameData reported validation errors: %s" % errors)
		return

	var case: Dictionary = _find_induction_rebuild_case(game_data)
	if case.is_empty():
		_fail("No real setup produced an induction rebuild instruction for Technical Loop.")
		return

	var baseline_result: Dictionary = case.get("result", {})
	var instruction: Dictionary = case.get("instruction", {})
	if str(instruction.get("issue", "")) == "" or str(instruction.get("direction", "")) == "":
		_fail("Instruction should include readable issue and direction fields.")
		return
	if str(instruction.get("target_field", "")) != "induction":
		_fail("Expected induction target_field, got %s." % instruction.get("target_field", ""))
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

	print("PHASE_3_REBUILD_INSTRUCTION_OK target=%s score_gain=%+0.1f baseline=%s/%s/%s improved=%s/%s/%s" % [
		instruction.get("target_field", "?"),
		score_gain,
		baseline_result.get("setup", {}).get("block", {}).get("id", "?"),
		baseline_result.get("setup", {}).get("induction", {}).get("id", "?"),
		baseline_result.get("setup", {}).get("material", {}).get("id", "?"),
		improved_result.get("setup", {}).get("block", {}).get("id", "?"),
		improved_result.get("setup", {}).get("induction", {}).get("id", "?"),
		improved_result.get("setup", {}).get("material", {}).get("id", "?")
	])
	quit(0)

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
