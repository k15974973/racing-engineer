extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const PROGRESSION_PATH := "user://progression.json"

var _game_data: Node
var _main: Control
var _original_game_unlocked: Dictionary = {}
var _had_progression := false
var _original_progression_text := ""

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_game_data = root.get_node("/root/GameData")
	_original_game_unlocked = _game_data.unlocked.duplicate(true)
	_snapshot_progression()

	_game_data.reset_unlock_state(true)
	var main_scene: PackedScene = load(MAIN_SCENE_PATH)
	if main_scene == null:
		_fail("Could not load Main scene.")
		return

	_main = main_scene.instantiate()
	_main._progression = _main._default_progression()

	if _game_data.is_unlocked("material", "ceramic"):
		_fail("Ceramic should start locked in GameData after reset.")
		return
	if _main._builder_option_unlocked("material", "ceramic"):
		_fail("Ceramic should start locked in the builder bridge.")
		return
	if not _main._builder_option_unlocked("block", "v8"):
		_fail("V8 should stay open at start because no canonical GameData unlock rule gates it.")
		return

	var result := _find_thermal_mastery_result()
	if result.is_empty():
		_fail("No legal setup satisfied thermal_mastery conditions without already using Ceramic or Compound.")
		return

	_main._race_result = result
	var messages: Array = _main._apply_progression_after_race(false)
	if messages.is_empty():
		_fail("thermal_mastery should produce at least one progression message.")
		return

	var progression_unlocked: Dictionary = _main._progression.get("unlocked", {})
	var materials: Array = progression_unlocked.get("materials", [])
	if not materials.has("ceramic"):
		_fail("thermal_mastery should add Ceramic to progression materials.")
		return
	if _game_data.is_unlocked("material", "ceramic"):
		_fail("GameData should remain locked; this smoke test covers the builder bridge.")
		return
	if not _main._builder_option_unlocked("material", "ceramic"):
		_fail("Builder should treat progression-unlocked Ceramic as selectable.")
		return

	var setup: Dictionary = result.get("setup", {})
	_restore_state()
	print("PHASE_3_BUILDER_UNLOCK_BRIDGE_OK case=%s/%s/%s track=%s fit=%s heat=%s reliability=%s" % [
		_setup_part_id(setup, "block"),
		_setup_part_id(setup, "induction"),
		_setup_part_id(setup, "material"),
		result.get("track_id", result.get("track", {}).get("id", "?")),
		snappedf(float(result.get("fit_score", 0.0)), 0.1),
		snappedf(float(result.get("effective_heat", 0.0)), 0.1),
		snappedf(float(result.get("effective_reliability", 0.0)), 0.1)
	])
	quit(0)

func _find_thermal_mastery_result() -> Dictionary:
	for track in _game_data.tracks:
		if typeof(track) != TYPE_DICTIONARY:
			continue

		var track_id := str(track.get("id", ""))
		for block in _game_data.blocks:
			if typeof(block) != TYPE_DICTIONARY:
				continue

			var block_id := str(block.get("id", ""))
			if not _game_data.is_unlocked("block", block_id):
				continue

			for induction in _game_data.inductions:
				if typeof(induction) != TYPE_DICTIONARY:
					continue

				var induction_id := str(induction.get("id", ""))
				if not _game_data.is_unlocked("induction", induction_id):
					continue

				for material in _game_data.materials:
					if typeof(material) != TYPE_DICTIONARY:
						continue

					var material_id := str(material.get("id", ""))
					if not _game_data.is_unlocked("material", material_id):
						continue

					var setup: Dictionary = _game_data.calculate_engine_setup(block_id, induction_id, material_id)
					if setup.has("error"):
						continue

					var result: Dictionary = _game_data.calculate_race_result(setup, track_id)
					if result.has("error"):
						continue
					if _meets_thermal_mastery(result):
						return result

	return {}

func _meets_thermal_mastery(result: Dictionary) -> bool:
	return (
		float(result.get("fit_score", 0.0)) >= 82.0
		and float(result.get("effective_heat", 999.0)) <= 95.0
		and float(result.get("effective_reliability", 0.0)) >= 75.0
	)

func _setup_part_id(setup: Dictionary, key: String) -> String:
	var part: Dictionary = setup.get(key, {})
	return str(part.get("id", "?"))

func _snapshot_progression() -> void:
	_had_progression = FileAccess.file_exists(PROGRESSION_PATH)
	if _had_progression:
		_original_progression_text = FileAccess.get_file_as_string(PROGRESSION_PATH)

func _restore_state() -> void:
	if is_instance_valid(_main):
		_main.free()
		_main = null

	if _game_data != null:
		_game_data.unlocked = _original_game_unlocked.duplicate(true)
		_game_data.save_unlock_state()

	if _had_progression:
		var file := FileAccess.open(PROGRESSION_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(_original_progression_text)
	elif FileAccess.file_exists(PROGRESSION_PATH):
		var dir := DirAccess.open("user://")
		if dir != null:
			dir.remove("progression.json")

func _fail(message: String) -> void:
	_restore_state()
	push_error(message)
	quit(1)
