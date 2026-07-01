extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_data = root.get_node("/root/GameData")
	var defaults: Dictionary = game_data.get_default_builder_selection()
	var setup: Dictionary = game_data.calculate_engine_setup(str(defaults.get("block", "")), str(defaults.get("induction", "")), str(defaults.get("material", "")))
	if setup.has("error"):
		_fail("Default setup failed: %s" % setup.get("error", ""))
		return

	var result: Dictionary = game_data.calculate_race_result(setup, "power_ring")
	if result.has("error"):
		_fail("Default Power Ring result failed: %s" % result.get("error", ""))
		return

	var analysis: Dictionary = game_data.analyze_race_result(result)
	if analysis.has("error"):
		_fail("Default Power Ring analysis failed: %s" % analysis.get("error", ""))
		return

	var instructions: Array = analysis.get("rebuild_instructions", [])
	for item in instructions:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var instruction: Dictionary = item
		if str(instruction.get("target_field", "")) == "block":
			print("PHASE_3_DEFAULT_GUIDANCE_OK setup=%s/%s/%s power_score=%s target=block" % [
				setup.get("block", {}).get("id", "?"),
				setup.get("induction", {}).get("id", "?"),
				setup.get("material", {}).get("id", "?"),
				result.get("power_score", "?")
			])
			quit(0)
			return

	_fail("Default Power Ring run should teach a block rebuild. setup=%s/%s/%s power_score=%s instructions=%s" % [
		setup.get("block", {}).get("id", "?"),
		setup.get("induction", {}).get("id", "?"),
		setup.get("material", {}).get("id", "?"),
		result.get("power_score", "?"),
		instructions
	])

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
