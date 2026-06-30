extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_data = root.get_node("/root/GameData")
	var summary: Dictionary = game_data.get_summary()
	var errors: Array = summary.get("errors", [])
	if not errors.is_empty():
		_fail("GameData reported validation errors: %s" % errors)
		return

	var report: Dictionary = game_data.get_contract_report()
	for key in ["blocks", "inductions", "materials"]:
		var contract: Dictionary = report.get(key, {})
		if contract.is_empty():
			_fail("Missing contract report for %s." % key)
			return
		if not bool(contract.get("ok", false)):
			_fail("%s did not pass contract validation." % contract.get("label", key))
			return
		if int(contract.get("count", 0)) <= 0:
			_fail("%s loaded no records." % contract.get("label", key))
			return

	var setup: Dictionary = game_data.calculate_engine_setup("v8", "na", "aluminum")
	if setup.has("error"):
		_fail("Health setup failed: %s" % setup.get("error", ""))
		return

	var block: Dictionary = setup.get("block", {})
	var induction: Dictionary = setup.get("induction", {})
	var material: Dictionary = setup.get("material", {})
	var expected_health := snappedf(clampf(100.0 * float(block.get("reliability_factor", 1.0)) * float(induction.get("reliability_mult", 1.0)) * float(material.get("durability_mult", 1.0)), 0.0, 120.0), 0.1)
	var actual_health := float(setup.get("engine_health_score", -1.0))
	if not is_equal_approx(actual_health, expected_health):
		_fail("Engine health mismatch. Expected %s, got %s." % [expected_health, actual_health])
		return

	print("DATA_CONTRACT_SMOKE_OK blocks=%s inductions=%s materials=%s health=%s" % [summary.get("blocks", 0), summary.get("inductions", 0), summary.get("materials", 0), actual_health])
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
