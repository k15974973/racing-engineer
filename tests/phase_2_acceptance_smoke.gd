extends SceneTree

const TIME_EPSILON := 0.05

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_data = root.get_node("/root/GameData")
	var summary: Dictionary = game_data.get_summary()
	var errors: Array = summary.get("errors", [])
	if not errors.is_empty():
		_fail("GameData reported validation errors: %s" % errors)
		return

	var setup: Dictionary = game_data.calculate_engine_setup("inline_4", "supercharger", "aluminum")
	if setup.has("error"):
		_fail("Builder setup failed: %s" % setup.get("error", ""))
		return

	var power_result: Dictionary = game_data.calculate_race_result(setup, "power_ring")
	if not _assert_phase_2_result(power_result, "power_ring"):
		return

	var technical_result: Dictionary = game_data.calculate_race_result(setup, "technical_loop")
	if not _assert_phase_2_result(technical_result, "technical_loop"):
		return

	if str(power_result.get("track", {}).get("id", "")) == str(technical_result.get("track", {}).get("id", "")):
		_fail("Phase 2 should run two distinct tracks.")
		return

	if int(power_result.get("laps", 0)) == int(technical_result.get("laps", 0)):
		_fail("Phase 2 tracks should expose distinct lap counts.")
		return

	if _window_types(power_result) == _window_types(technical_result):
		_fail("Phase 2 tracks should produce distinct tactical window mixes.")
		return

	var power_analysis: Dictionary = game_data.analyze_race_result(power_result)
	if power_analysis.has("error"):
		_fail("Power Ring result should be analyzable: %s" % power_analysis.get("error", ""))
		return

	var technical_analysis: Dictionary = game_data.analyze_race_result(technical_result)
	if technical_analysis.has("error"):
		_fail("Technical Loop result should be analyzable: %s" % technical_analysis.get("error", ""))
		return

	print("PHASE_2_ACCEPTANCE_OK tracks=%s/%s windows=%s/%s totals=%ss/%ss" % [
		power_result.get("track", {}).get("id", "?"),
		technical_result.get("track", {}).get("id", "?"),
		_window_types(power_result),
		_window_types(technical_result),
		power_result.get("total_time", "?"),
		technical_result.get("total_time", "?")
	])
	quit(0)

func _assert_phase_2_result(result: Dictionary, expected_track_id: String) -> bool:
	if result.has("error"):
		_fail("%s race failed: %s" % [expected_track_id, result.get("error", "")])
		return false

	var track: Dictionary = result.get("track", {})
	if str(track.get("id", "")) != expected_track_id:
		_fail("Expected track %s, got %s." % [expected_track_id, track.get("id", "")])
		return false

	var laps := int(result.get("laps", 0))
	var lap_time := float(result.get("lap_time", 0.0))
	var total_time := float(result.get("total_time", 0.0))
	if laps <= 0 or lap_time <= 0.0 or total_time <= 0.0:
		_fail("%s should have positive timing values." % expected_track_id)
		return false

	if absf(total_time / float(laps) - lap_time) > TIME_EPSILON:
		_fail("%s timing should stay internally consistent." % expected_track_id)
		return false

	for key in ["sectors", "windows", "timeline", "save_preview", "race_overview", "setup_notes", "decision_effects"]:
		var value: Variant = result.get(key)
		if value == null:
			_fail("%s result missing %s." % [expected_track_id, key])
			return false
		if value is Array and value.is_empty():
			_fail("%s result %s should not be empty." % [expected_track_id, key])
			return false
		if value is Dictionary and value.is_empty():
			_fail("%s result %s should not be empty." % [expected_track_id, key])
			return false

	if result.get("sectors", []).size() != 3:
		_fail("%s should report 3 sector scores." % expected_track_id)
		return false

	var windows: Array = result.get("windows", [])
	if windows.size() < 3 or windows.size() > 4:
		_fail("%s should report 3 to 4 tactical windows." % expected_track_id)
		return false

	if result.get("timeline", []).size() != windows.size():
		_fail("%s timeline should match window count." % expected_track_id)
		return false

	return true

func _window_types(result: Dictionary) -> String:
	var names: Array = []
	for item in result.get("windows", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var window: Dictionary = item
		names.append(str(window.get("type", "Window")))
	return ",".join(names)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
