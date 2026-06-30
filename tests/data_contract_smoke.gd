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

	print("DATA_CONTRACT_SMOKE_OK blocks=%s inductions=%s materials=%s" % [summary.get("blocks", 0), summary.get("inductions", 0), summary.get("materials", 0)])
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
