extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const VIEW_ENGINE_BUILDER := "engine_builder"

var _main: Control
var _game_data: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_game_data = root.get_node("/root/GameData")
	var main_scene: PackedScene = load(MAIN_SCENE_PATH)
	if main_scene == null:
		_fail("Could not load Main scene.")
		return

	_main = main_scene.instantiate()
	_main._progression = _main._default_progression()
	_main._build_shell()
	_main._show_view(VIEW_ENGINE_BUILDER)

	if not _assert_entry_cta():
		return
	if not _assert_builder_steps():
		return
	if not _assert_post_race_cta():
		return

	_restore()
	print("PHASE_3_UI_CLARITY_OK build_cta=top builder_steps=1/2/3 post_race_cta=Analyze")
	quit(0)

func _assert_entry_cta() -> bool:
	var build_button: Button = _main._nav_buttons.get(VIEW_ENGINE_BUILDER)
	if build_button == null:
		_fail("Build Engine nav button is missing.")
		return false
	if build_button.text != "Build Engine":
		_fail("Primary entry CTA should read Build Engine, got %s." % build_button.text)
		return false
	if build_button.custom_minimum_size.y < 44.0:
		_fail("Build Engine CTA should be the largest top nav element.")
		return false
	if build_button.get_parent().get_index() != 0:
		_fail("Build Engine CTA should be in the top shell row.")
		return false
	if _has_label_text(_main, "Engine Builder prototype with future-phase race, analysis, and garage systems clearly separated in docs."):
		_fail("Production shell should not show the old explanatory header text.")
		return false
	return true

func _assert_builder_steps() -> bool:
	for marker in ["1 ->", "2 ->", "3"]:
		if not _has_label_text(_main, marker):
			_fail("Builder should show step marker %s." % marker)
			return false
	return true

func _assert_post_race_cta() -> bool:
	var setup: Dictionary = _game_data.calculate_engine_setup("v4", "na", "aluminum")
	var result: Dictionary = _game_data.calculate_race_result(setup, "technical_loop")
	if result.has("error"):
		_fail("Could not build race result for UI CTA smoke: %s" % result.get("error", ""))
		return false

	_main._race_result = result
	var panel: PanelContainer = _main._race_result_panel()
	var analyze_button := _find_button(panel, "Analyze")
	if analyze_button == null:
		_fail("Race result should expose a primary Analyze CTA.")
		return false
	if analyze_button.custom_minimum_size.y < 42.0:
		_fail("Analyze CTA should have stronger visual weight than normal buttons.")
		return false
	if not analyze_button.has_theme_stylebox_override("normal"):
		_fail("Analyze CTA should have its own accent style.")
		return false
	var save_button := _find_button(panel, "Save Race")
	if save_button == null:
		_fail("Save Race should remain available beside Analyze.")
		return false
	panel.free()
	return true

func _has_label_text(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _has_label_text(child, text):
			return true
	return false

func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child in node.get_children():
		var result := _find_button(child, text)
		if result != null:
			return result
	return null

func _restore() -> void:
	if is_instance_valid(_main):
		_main.free()
		_main = null

func _fail(message: String) -> void:
	_restore()
	push_error(message)
	quit(1)
