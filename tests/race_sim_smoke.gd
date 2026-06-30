extends SceneTree

const TIME_EPSILON := 0.05
const STAT_EPSILON := 0.15

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_data = root.get_node("/root/GameData")
	var summary: Dictionary = game_data.get_summary()
	var errors: Array = summary.get("errors", [])
	if not errors.is_empty():
		_fail("GameData reported validation errors: %s" % errors)
		return

	var power_setup: Dictionary = game_data.calculate_engine_setup("v4", "na", "titanium")
	if power_setup.has("error"):
		_fail("Power setup failed: %s" % power_setup.get("error", ""))
		return

	var boost_setup: Dictionary = game_data.calculate_engine_setup("v8", "twin_turbo", "titanium")
	if boost_setup.has("error"):
		_fail("Boost setup failed: %s" % boost_setup.get("error", ""))
		return

	var technical_setup: Dictionary = game_data.calculate_engine_setup("inline_4", "supercharger", "aluminum")
	if technical_setup.has("error"):
		_fail("Technical setup failed: %s" % technical_setup.get("error", ""))
		return

	var baseline: Dictionary = game_data.calculate_race_result(power_setup, "power_ring")
	if not _assert_race_result(baseline, "Power Ring baseline"):
		return
	if not _assert_has_window(baseline, "Straight Attack", "Power Ring baseline"):
		return

	var boost_result: Dictionary = game_data.calculate_race_result(boost_setup, "power_ring")
	if not _assert_race_result(boost_result, "Boosted Power Ring baseline"):
		return
	if not _assert_has_window(boost_result, "Boost Spike", "Boosted Power Ring baseline"):
		return

	var aggressive: Dictionary = game_data.calculate_race_result(power_setup, "power_ring", _decision_map(baseline, "last"))
	if not _assert_race_result(aggressive, "Power Ring aggressive"):
		return
	if float(aggressive.get("total_time", 0.0)) >= float(baseline.get("total_time", 0.0)):
		_fail("Aggressive decisions should improve total time. Baseline=%s aggressive=%s effects=%s heat=%s->%s reliability=%s->%s" % [baseline.get("total_time", "?"), aggressive.get("total_time", "?"), aggressive.get("decision_effects", {}), baseline.get("effective_heat", "?"), aggressive.get("effective_heat", "?"), baseline.get("effective_reliability", "?"), aggressive.get("effective_reliability", "?")])
		return
	if float(aggressive.get("effective_heat", 0.0)) <= float(baseline.get("effective_heat", 0.0)):
		_fail("Aggressive decisions should increase heat.")
		return
	if float(aggressive.get("effective_reliability", 0.0)) >= float(baseline.get("effective_reliability", 0.0)):
		_fail("Aggressive decisions should spend reliability.")
		return

	var conservative: Dictionary = game_data.calculate_race_result(power_setup, "power_ring", _decision_map(baseline, "first"))
	if not _assert_race_result(conservative, "Power Ring conservative"):
		return
	if float(conservative.get("total_time", 0.0)) <= float(baseline.get("total_time", 0.0)):
		_fail("Conservative decisions should cost total time.")
		return
	if float(conservative.get("effective_heat", 999.0)) >= float(baseline.get("effective_heat", 0.0)):
		_fail("Conservative decisions should reduce heat.")
		return
	if float(conservative.get("effective_reliability", 0.0)) <= float(baseline.get("effective_reliability", 0.0)):
		_fail("Conservative decisions should protect reliability.")
		return

	var technical: Dictionary = game_data.calculate_race_result(technical_setup, "technical_loop")
	if not _assert_race_result(technical, "Technical Loop baseline"):
		return
	if not _assert_has_window(technical, "Corner Map", "Technical Loop baseline"):
		return

	var invalid_track: Dictionary = game_data.calculate_race_result(power_setup, "missing_track")
	if not invalid_track.has("error"):
		_fail("Invalid track id should return a data contract error.")
		return
	if str(invalid_track.get("error", "")).find("res://data/tracks.json") == -1:
		_fail("Invalid track error should name res://data/tracks.json.")
		return

	print("RACE_SIM_SMOKE_OK power_lap=%ss aggressive_delta=%+0.2fs conservative_delta=%+0.2fs technical_windows=%s" % [
		baseline.get("lap_time", "?"),
		float(aggressive.get("total_time", 0.0)) - float(baseline.get("total_time", 0.0)),
		float(conservative.get("total_time", 0.0)) - float(baseline.get("total_time", 0.0)),
		technical.get("windows", []).size()
	])
	quit(0)

func _assert_race_result(result: Dictionary, label: String) -> bool:
	if result.has("error"):
		_fail("%s failed: %s" % [label, result.get("error", "")])
		return false

	var track: Dictionary = result.get("track", {})
	if str(track.get("id", "")) == "":
		_fail("%s has no track id." % label)
		return false

	var laps := int(result.get("laps", 0))
	var lap_time := float(result.get("lap_time", 0.0))
	var total_time := float(result.get("total_time", 0.0))
	var base_lap_time := float(track.get("base_lap_time", 0.0))
	if laps <= 0 or lap_time <= 0.0 or total_time <= 0.0 or base_lap_time <= 0.0:
		_fail("%s has invalid timing values." % label)
		return false

	if absf(total_time / float(laps) - lap_time) > TIME_EPSILON:
		_fail("%s total/lap timing is inconsistent." % label)
		return false

	if absf((lap_time - base_lap_time) - float(result.get("delta_vs_base", 0.0))) > TIME_EPSILON:
		_fail("%s delta_vs_base does not match lap_time - base_lap_time." % label)
		return false

	var sectors: Array = result.get("sectors", [])
	if sectors.size() != 3:
		_fail("%s should report exactly 3 sector scores." % label)
		return false

	var windows: Array = result.get("windows", [])
	if windows.size() < 3 or windows.size() > 4:
		_fail("%s should generate 3 to 4 tactical windows, got %s." % [label, windows.size()])
		return false

	for item in windows:
		if typeof(item) != TYPE_DICTIONARY:
			_fail("%s contains a non-dictionary tactical window." % label)
			return false

		var window: Dictionary = item
		var choices: Array = window.get("choices", [])
		if str(window.get("type", "")) == "" or choices.size() < 3:
			_fail("%s contains an incomplete tactical window." % label)
			return false

	return _assert_decision_effect_totals(result, label)

func _assert_decision_effect_totals(result: Dictionary, label: String) -> bool:
	var windows: Array = result.get("windows", [])
	var effects: Dictionary = result.get("decision_effects", {})
	var log: Array = effects.get("log", [])
	if log.size() != windows.size():
		_fail("%s decision log should match tactical window count." % label)
		return false

	var time_delta := 0.0
	var heat_delta := 0.0
	var reliability_delta := 0.0
	for item in log:
		if typeof(item) != TYPE_DICTIONARY:
			_fail("%s contains a non-dictionary decision log entry." % label)
			return false

		var entry: Dictionary = item
		time_delta += float(entry.get("time_delta", 0.0))
		heat_delta += float(entry.get("heat_delta", 0.0))
		reliability_delta += float(entry.get("reliability_delta", 0.0))

	if absf(time_delta - float(effects.get("time_delta", 0.0))) > TIME_EPSILON:
		_fail("%s decision time delta does not equal log sum." % label)
		return false
	if absf(heat_delta - float(effects.get("heat_delta", 0.0))) > STAT_EPSILON:
		_fail("%s decision heat delta does not equal log sum." % label)
		return false
	if absf(reliability_delta - float(effects.get("reliability_delta", 0.0))) > STAT_EPSILON:
		_fail("%s decision reliability delta does not equal log sum." % label)
		return false

	return true

func _assert_has_window(result: Dictionary, window_type: String, label: String) -> bool:
	for item in result.get("windows", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var window: Dictionary = item
		if str(window.get("type", "")) == window_type:
			return true

	_fail("%s should include %s." % [label, window_type])
	return false

func _decision_map(result: Dictionary, pick: String) -> Dictionary:
	var decisions := {}
	for item in result.get("windows", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var window: Dictionary = item
		var choices: Array = window.get("choices", [])
		if choices.is_empty():
			continue

		var index := 0
		if pick == "last":
			index = choices.size() - 1
		elif pick == "middle":
			index = int(choices.size() / 2)

		var choice: Dictionary = choices[index]
		decisions[str(window.get("type", ""))] = str(choice.get("id", ""))
	return decisions

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
