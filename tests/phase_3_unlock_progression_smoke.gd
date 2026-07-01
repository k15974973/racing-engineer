extends SceneTree

var _game_data: Node
var _original_unlocked: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_game_data = root.get_node("/root/GameData")
	_original_unlocked = _game_data.unlocked.duplicate(true)
	var summary: Dictionary = _game_data.get_summary()
	var errors: Array = summary.get("errors", [])
	if not errors.is_empty():
		_fail("GameData reported validation errors: %s" % errors)
		return

	var setup: Dictionary = _game_data.calculate_engine_setup("v8", "na", "aluminum")
	var power_baseline: Dictionary = _game_data.calculate_race_result(setup, "power_ring")
	var technical_baseline: Dictionary = _game_data.calculate_race_result(setup, "technical_loop")
	var power_par: float = _game_data.get_par_time("power_ring")
	var technical_par: float = _game_data.get_par_time("technical_loop")
	if absf(power_par - snappedf(float(power_baseline.get("total_time", 0.0)) * 0.93, 0.01)) > 0.01:
		_fail("Power Ring par_time should equal V8 NA Aluminum baseline * 0.93. Par=%s baseline=%s" % [power_par, power_baseline.get("total_time", "?")])
		return
	if absf(technical_par - snappedf(float(technical_baseline.get("total_time", 0.0)) * 0.93, 0.01)) > 0.01:
		_fail("Technical Loop par_time should equal V8 NA Aluminum baseline * 0.93. Par=%s baseline=%s" % [technical_par, technical_baseline.get("total_time", "?")])
		return

	_game_data.reset_unlock_state(true)
	if _game_data.is_unlocked("material", "ceramic"):
		_fail("Ceramic should start locked after reset.")
		return
	if _game_data.is_unlocked("induction", "compound"):
		_fail("Compound should start locked after reset.")
		return
	if not _game_data.is_unlocked("block", "v8"):
		_fail("Block with no unlock condition should always be open.")
		return

	var fast_setup: Dictionary = _game_data.calculate_engine_setup("v8", "na", "ceramic")
	var fast_result: Dictionary = _game_data.calculate_race_result(fast_setup, "technical_loop")
	fast_result["total_time"] = snappedf(technical_par * 0.90, 0.01)
	var newly: Array = _game_data.check_and_apply_unlocks(fast_result)
	if newly.is_empty():
		_fail("Ceramic should unlock when beating Technical Loop par.")
		return
	if not _game_data.is_unlocked("material", "ceramic"):
		_fail("Ceramic should be true immediately after unlock.")
		return

	_game_data.unlocked = {}
	_game_data.load_unlock_state()
	if not _game_data.is_unlocked("material", "ceramic"):
		_fail("Ceramic unlock should persist after reload.")
		return

	_game_data.reset_unlock_state(true)
	var slow_result := fast_result.duplicate(true)
	slow_result["total_time"] = snappedf(technical_par * 1.05, 0.01)
	var nothing: Array = _game_data.check_and_apply_unlocks(slow_result)
	if not nothing.is_empty():
		_fail("No unlock should fire when not beating par.")
		return
	if _game_data.is_unlocked("material", "ceramic"):
		_fail("Ceramic should remain locked after a slower-than-par result.")
		return

	_restore_unlock_state()
	print("PHASE_3_UNLOCK_PROGRESSION_OK power_baseline=%s power_par=%s technical_baseline=%s technical_par=%s unlocked=%s" % [
		power_baseline.get("total_time", "?"),
		power_par,
		technical_baseline.get("total_time", "?"),
		technical_par,
		newly.size()
	])
	quit(0)

func _restore_unlock_state() -> void:
	if _game_data == null:
		return

	_game_data.unlocked = _original_unlocked.duplicate(true)
	_game_data.save_unlock_state()

func _fail(message: String) -> void:
	_restore_unlock_state()
	push_error(message)
	quit(1)
